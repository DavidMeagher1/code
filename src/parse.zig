const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
const Token = @import("token.zig");
const Scope = @import("scope.zig");
const Opcodes = @import("opcodes.zig").Opcodes;
const Assembler = @This();

const Error = error{
    InvalidToken,
    UnexpectedEOF,
    ExpectedNumberAfterTrap,
    InvalidPaddingAddress,
    BackwardPadding,
    NegativeRelativePadding,
    UndefinedLabel,
    OffsetOutOfRange,
    RelativeJumpOutOfRange,
} || Allocator.Error || std.fmt.ParseIntError;

const Chunk = union(enum) {
    instructions: ArrayListUnmanaged(u8),
    absolute_padding: u32,
    relative_padding: u32,

    fn deinit(self: *Chunk, allocator: Allocator) void {
        switch (self.*) {
            .instructions => self.instructions.deinit(allocator),
            .absolute_padding, .relative_padding => {},
        }
    }
};

const ChunkList = ArrayListUnmanaged(Chunk);

const Reference = struct {
    label_name: []const u8,
    after_chunk_index: u32,
    is_relative: bool,
};

const ReferenceList = ArrayListUnmanaged(Reference);

gpa: Allocator,
source: []const u8,
tokens: []Token,
chunks: ChunkList,
references: ArrayListUnmanaged(Reference),
external_identifiers: StringHashMapUnmanaged(u8),
scope_stack: ArrayListUnmanaged(*Scope),

pub fn init(allocator: Allocator, source: []const u8, tokens: []Token) Error!Assembler {
    const global_scope = try allocator.create(Scope);
    global_scope.* = Scope.init(".global.", null);
    var result = Assembler{
        .gpa = allocator,
        .source = source,
        .tokens = tokens,
        .chunks = .empty,
        .references = .empty,
        .external_identifiers = .empty,
        .scope_stack = .empty,
    };
    try result.scope_stack.append(allocator, global_scope);
    return result;
}

pub fn deinit(self: *Assembler) void {
    for (self.chunks.items) |*chunk| {
        chunk.deinit(self.gpa);
    }
    self.chunks.deinit(self.gpa);
    self.references.deinit(self.gpa);
    self.scope_stack.items[0].deinit(self.gpa); // this recursively deinitializes child scopes
    self.gpa.destroy(self.scope_stack.items[0]);
    self.external_identifiers.deinit(self.gpa);
    self.scope_stack.deinit(self.gpa);
    self.source = &[_]u8{};
    self.tokens = &[_]Token{};
    // self.gpa is left as-is since it's managed externally
}

fn globalScope(self: *Assembler) ?*Scope {
    if (self.scope_stack.items.len == 0) {
        return null;
    }
    return self.scope_stack.items[0];
}

fn currentScope(self: *Assembler) ?*Scope {
    if (self.scope_stack.items.len == 0) {
        return null;
    }
    return self.scope_stack.items[self.scope_stack.items.len - 1];
}

fn pushScope(self: *Assembler, scope: *Scope) Allocator.Error!void {
    try self.scope_stack.append(self.gpa, scope);
}

fn popScope(self: *Assembler) ?*Scope {
    if (self.scope_stack.items.len <= 1) { // Don't pop global scope
        return null;
    }
    return self.scope_stack.pop();
}

fn emitByte(self: *Assembler, byte: u8) Allocator.Error!void {
    if (self.chunks.items.len == 0) {
        const new_chunk = undefined;
        try self.chunks.append(self.gpa, new_chunk);
    }
    const last_index = self.chunks.items.len - 1;
    try self.chunks.items[last_index].instructions.append(self.gpa, byte);
}

fn emitBytes(self: *Assembler, bytes: []const u8) Allocator.Error!void {
    for (bytes) |b| {
        try self.emitByte(b);
    }
}

fn pass1(self: *Assembler) Error!void {
    var current_chunk = Chunk{ .instructions = .empty };
    var current_scope: *Scope = self.currentScope().?;
    var current_position: u32 = 0;
    var i: usize = 0;

    while (i < self.tokens.len) : (i += 1) {
        const tok = self.tokens[i];

        switch (tok.tag) {
            .identifier => {
                // General identifier - treat as error for now
                // TODO needs to be updated in the spec but these will be used as
                // shorthands for traps that can be registered externally
                const lexeme = self.getLexeme(tok);
                if (self.external_identifiers.get(lexeme)) |trap_id| {
                    // Emit TRAP opcode with trap_id
                    try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.trap));
                    try current_chunk.instructions.append(self.gpa, trap_id);
                } else {
                    return error.InvalidToken;
                }
            },
            .global_label => {
                // :name - create new scope
                const name = self.getLexeme(tok);

                // Record definition
                const def = Scope.Definition{
                    .address = current_position,
                };
                try current_scope.addSymbol(self.gpa, name, def);

                // Create new child scope
                const new_scope = try self.gpa.create(Scope);
                new_scope.* = Scope.init(name, self.globalScope());
                try self.globalScope().?.addChild(self.gpa, new_scope);
                try self.pushScope(new_scope);
                current_scope = self.currentScope().?;
            },

            .local_label => {
                // &name - define in current scope
                const name = self.getLexeme(tok);

                const def = Scope.Definition{
                    .address = current_position,
                };
                try current_scope.addSymbol(self.gpa, name, def);
            },

            .absolute_label_reference => {
                // @name - close chunk, record reference, start new chunk
                const name = self.getLexeme(tok);

                // Close current chunk
                try self.chunks.append(self.gpa, current_chunk);
                const chunk_idx = self.chunks.items.len - 1;

                // Record reference
                try self.references.append(self.gpa, .{
                    .label_name = name,
                    .after_chunk_index = @intCast(chunk_idx),
                    .is_relative = false,
                });

                // Start new chunk
                current_chunk = .{ .instructions = .empty };
            },

            .relative_label_reference => {
                // ;name - close chunk, record reference, start new chunk
                const name = self.getLexeme(tok);

                // Close current chunk
                try self.chunks.append(self.gpa, current_chunk);
                current_position += @as(u32, @intCast(current_chunk.instructions.items.len));
                const chunk_idx = self.chunks.items.len - 1;

                // Record reference
                try self.references.append(self.gpa, .{
                    .label_name = name,
                    .after_chunk_index = @intCast(chunk_idx),
                    .is_relative = true,
                });

                // Start new chunk
                current_chunk = Chunk{ .instructions = .empty };
            },

            .absolute_padding => {
                const addr = try self.parseNumber(tok);
                if (addr < 0 or addr > 0xFFFF) return error.InvalidPaddingAddress;
                const uaddr = @as(u32, @intCast(addr));
                if (uaddr < current_position) return error.BackwardPadding;

                // Close current chunk if any
                if (current_chunk.instructions.items.len > 0) {
                    try self.chunks.append(self.gpa, current_chunk);
                    current_position += @as(u32, @intCast(current_chunk.instructions.items.len));
                    current_chunk = Chunk{ .instructions = .empty };
                }

                try self.chunks.append(self.gpa, .{ .absolute_padding = uaddr });
                current_position = uaddr;
            },

            .relative_padding => {
                const offset = try self.parseNumber(tok);
                if (offset < 0) return error.NegativeRelativePadding;
                const uoffset = @as(u32, @intCast(offset));

                // Close current chunk if any
                if (current_chunk.instructions.items.len > 0) {
                    try self.chunks.append(self.gpa, current_chunk);
                    current_position += @as(u32, @intCast(current_chunk.instructions.items.len));
                    current_chunk = Chunk{ .instructions = .empty };
                }

                try self.chunks.append(self.gpa, .{ .relative_padding = uoffset });
                current_position += uoffset;
            },

            .hash => {
                // # - PUSH opcode
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.push1)); // PUSH1 placeholder
                i += 1;

                if (i >= self.tokens.len) return error.UnexpectedEOF;

                const operand = self.tokens[i];
                if (operand.tag == .absolute_label_reference) {
                    // # @label - close chunk for reference
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                        .is_relative = false,
                    });

                    current_chunk = .{ .instructions = .empty };
                } else if (operand.tag == .number_literal) {
                    // # 42 - immediate value
                    const val = try self.parseNumber(operand);
                    if (val <= 0xFF and val >= -128) {
                        try current_chunk.instructions.append(self.gpa, @intCast(@as(u16, @bitCast(@as(i16, @intCast(val)))) & 0xFF));
                    } else {
                        current_chunk.instructions.items[current_chunk.instructions.items.len - 1] = @intFromEnum(Opcodes.push2);
                        const bytes = std.mem.toBytes(@as(u16, @bitCast(@as(i16, @intCast(val)))));
                        try current_chunk.instructions.appendSlice(self.gpa, &bytes);
                    }
                }
            },

            .exclamation => {
                // ! - JMP opcode
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.jmps)); // JMPS placeholder
                i += 1;

                if (i >= self.tokens.len) return error.UnexpectedEOF;

                const operand = self.tokens[i];
                if (operand.tag == .absolute_label_reference) {
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                        .is_relative = false,
                    });

                    current_chunk = .{ .instructions = .empty };
                }
            },

            .question => {
                // ? - JNZ opcode
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.jnzs)); // JNZS placeholder
                i += 1;

                if (i >= self.tokens.len) return error.UnexpectedEOF;

                const operand = self.tokens[i];
                if (operand.tag == .absolute_label_reference) {
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                        .is_relative = false,
                    });

                    current_chunk = .{ .instructions = .empty };
                } else if (operand.tag == .relative_label_reference) {
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                        .is_relative = true,
                    });

                    current_chunk = .{ .instructions = .empty };
                }
            },

            // Simple opcodes
            .keyword_add => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.add1)),
            .keyword_addw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.add2)),
            .keyword_sub => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.sub1)),
            .keyword_subw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.sub2)),
            .keyword_halt => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.halt)),
            .keyword_nop => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.nop)),

            // System/Traps
            .keyword_trap => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.trap)); // TRAP
                i += 1;
                if (i >= self.tokens.len) return error.UnexpectedEOF;
                const operand = self.tokens[i];
                if (operand.tag == .number_literal) {
                    const val = try self.parseNumber(operand);
                    try current_chunk.instructions.append(self.gpa, @intCast(val & 0xFF));
                } else {
                    return error.ExpectedNumberAfterTrap;
                }
            },

            // Control Flow
            .keyword_hops => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.hops)),
            .keyword_hopl => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.hopl)),
            .keyword_calls => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.calls)),
            .keyword_calll => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.calll)),
            .keyword_rets => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.rets)),
            .keyword_retl => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.retl)),

            // Stack Manipulation
            .keyword_drop => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.drop1)),
            .keyword_dropw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.drop2)),
            .keyword_dup => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.dup1)),
            .keyword_dupw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.dup2)),
            .keyword_swap => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.swap1)),
            .keyword_swapw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.swap2)),
            .keyword_nip => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.nip1)),
            .keyword_nipw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.nip2)),
            .keyword_over => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.over1)),
            .keyword_overw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.over2)),
            .keyword_rot => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.rot1)),
            .keyword_rotw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.rot2)),
            .keyword_pick => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.pick1)),
            .keyword_pickw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.pick2)),
            .keyword_poke => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.poke1)),
            .keyword_pokew => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.poke2)),

            // Arithmetic
            .keyword_mul => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.mul1)),
            .keyword_mulw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.mul2)),
            .keyword_div => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.div1)),
            .keyword_divw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.div2)),
            .keyword_mod => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.mod1)),
            .keyword_modw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.mod2)),
            .keyword_neg => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.neg1)),
            .keyword_negw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.neg2)),
            .keyword_abs => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.abs1)),
            .keyword_absw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.abs2)),
            .keyword_inc => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.inc1)),
            .keyword_incw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.inc2)),
            .keyword_dec => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.dec1)),
            .keyword_decw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.dec2)),

            // Bitwise
            .keyword_and => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.and1)),
            .keyword_andw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.and2)),
            .keyword_or => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.or1)),
            .keyword_orw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.or2)),
            .keyword_not => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.not1)),
            .keyword_notw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.not2)),
            .keyword_xor => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.xor1)),
            .keyword_xorw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.xor2)),
            .keyword_shl => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.shl1)),
            .keyword_shlw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.shl2)),
            .keyword_shr => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.shr1)),
            .keyword_shrw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.shr2)),
            .keyword_rol => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.rol1)),
            .keyword_rolw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.rol2)),
            .keyword_ror => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.ror1)),
            .keyword_rorw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.ror2)),

            // Memory Access
            .keyword_load => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.load1)),
            .keyword_loadw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.load2)),
            .keyword_store => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.store1)),
            .keyword_storew => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.store2)),
            .keyword_iload => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.iload1)),
            .keyword_iloadw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.iload2)),
            .keyword_istore => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.istore1)),
            .keyword_istorew => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.istore2)),
            .keyword_memcpy => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.memcpy1)),
            .keyword_memcpyw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.memcpy2)),
            .keyword_memset => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.memset1)),
            .keyword_memsetw => try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.memset2)),

            // Comparison operators
            .equal_equal => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.cmpr)); // CMPR
                try current_chunk.instructions.append(self.gpa, 0x00); // ==
            },
            .not_equal => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.cmpr)); // CMPR
                try current_chunk.instructions.append(self.gpa, 0x01); // !=
            },
            .less_than => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.cmpr)); // CMPR
                try current_chunk.instructions.append(self.gpa, 0x02); // <
            },
            .greater_than => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.cmpr)); // CMPR
                try current_chunk.instructions.append(self.gpa, 0x03); // >
            },
            .less_equal => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.cmpr)); // CMPR
                try current_chunk.instructions.append(self.gpa, 0x04); // <=
            },
            .greater_equal => {
                try current_chunk.instructions.append(self.gpa, @intFromEnum(Opcodes.cmpr)); // CMPR
                try current_chunk.instructions.append(self.gpa, 0x05); // >=
            },

            .number_literal => {
                // Emit number as data
                const val = try self.parseNumber(tok);
                if (val >= -128 and val <= 255) {
                    try current_chunk.instructions.append(self.gpa, @intCast(@as(u16, @bitCast(@as(i16, @intCast(val)))) & 0xFF));
                } else {
                    const bytes = std.mem.toBytes(@as(u16, @bitCast(@as(i16, @intCast(val)))));
                    try current_chunk.instructions.appendSlice(self.gpa, &bytes);
                }
            },

            .string_literal => {
                // Emit string bytes (without quotes)
                const lexeme = self.getLexeme(tok);
                // Remove surrounding quotes
                const str = lexeme[1 .. lexeme.len - 1];
                // TODO: Handle escape sequences
                try current_chunk.instructions.appendSlice(self.gpa, str);
            },

            .character_literal => {
                // Emit character byte
                const lexeme = self.getLexeme(tok);
                // Remove surrounding quotes
                const char = lexeme[1];
                // TODO: Handle escape sequences
                try current_chunk.instructions.append(self.gpa, char);
            },

            .eof => break,
            .comment => {},
            .invalid => return error.InvalidToken,
            // else => {
            //     std.debug.print("Unhandled token: {s}\n", .{@tagName(tok.tag)});
            //     return error.UnhandledToken;
            // },
        }
    }

    // Don't forget final chunk
    if (current_chunk.instructions.items.len > 0) {
        try self.chunks.append(self.gpa, current_chunk);
    }
}

fn getLexeme(self: *Assembler, tok: Token) []const u8 {
    const start = switch (tok.tag) {
        .global_label, .local_label, .absolute_label_reference, .relative_label_reference, .absolute_padding, .relative_padding => tok.location.start_index + 1,
        else => tok.location.start_index,
    };
    return self.source[start..tok.location.end_index];
}

fn parseNumber(self: *Assembler, tok: Token) std.fmt.ParseIntError!i32 {
    const lexeme = self.getLexeme(tok);

    // Check for negative
    var is_negative = false;
    var start: usize = 0;
    if (lexeme[0] == '-') {
        is_negative = true;
        start = 1;
    }

    // Remove suffix (b or w)
    var end = lexeme.len;
    if (lexeme[end - 1] == 'b' or lexeme[end - 1] == 'w') {
        end -= 1;
    }

    // Parse hex
    const hex_str = lexeme[start..end];
    const val = try std.fmt.parseInt(u16, hex_str, 16);

    return if (is_negative) -@as(i32, val) else @as(i32, val);
}

fn pass2(self: *Assembler) Error![]u8 {
    // Step 1: Calculate chunk addresses with reference sizes
    var addr: u32 = 0;
    for (self.chunks.items, 0..) |chunk, i| {
        switch (chunk) {
            .instructions => |inst| addr += @as(u32, @intCast(inst.items.len)),
            .absolute_padding => |target| {
                if (target < addr) return error.BackwardPadding;
                addr = target;
            },
            .relative_padding => |offset| addr += offset,
        }

        // Check for references after this chunk
        for (self.references.items) |ref| {
            if (ref.after_chunk_index == i) {
                // Look up definition in scope tree
                const target = self.currentScope().?.resolveSymbol(ref.label_name) orelse return error.UndefinedLabel;
                const ref_size = if (ref.is_relative) 1 else self.calculateRefSize(&chunk, addr, target);
                addr += ref_size;
                break;
            }
        }
    }

    // Step 2: Emit bytecode with resolved references
    var output = ArrayListUnmanaged(u8){};
    defer output.deinit(self.gpa);

    var current_pos: u32 = 0;
    for (self.chunks.items, 0..) |chunk, i| {
        switch (chunk) {
            .instructions => |inst| {
                try output.appendSlice(self.gpa, inst.items);
                current_pos += @as(u32, @intCast(inst.items.len));
            },
            .absolute_padding => |target| {
                while (current_pos < target) {
                    try output.append(self.gpa, 0);
                    current_pos += 1;
                }
            },
            .relative_padding => |offset| {
                const target = current_pos + offset;
                while (current_pos < target) {
                    try output.append(self.gpa, 0);
                    current_pos += 1;
                }
            },
        }

        // Emit reference if any after this chunk
        for (self.references.items) |ref| {
            if (ref.after_chunk_index == i) {
                const target = self.currentScope().?.resolveSymbol(ref.label_name) orelse return error.UndefinedLabel;
                try self.emitReference(&output, &chunk, current_pos, target, ref.is_relative);
                const ref_size = if (ref.is_relative) 1 else self.calculateRefSize(&chunk, current_pos, target);
                current_pos += ref_size;
                break;
            }
        }
    }

    return output.toOwnedSlice(self.gpa);
}

fn calculateRefSize(self: *Assembler, chunk: *const Chunk, current_addr: u32, target_addr: u32) u32 {
    _ = self;
    const instructions = switch (chunk.*) {
        .instructions => |*list| list,
        else => &ArrayListUnmanaged(u8).empty,
    };
    if (instructions.items.len == 0) return if (target_addr <= 0xFF) 1 else 2; // Bare @label

    const last_opcode = instructions.items[instructions.items.len - 1];

    return switch (last_opcode) {
        @intFromEnum(Opcodes.push1), @intFromEnum(Opcodes.push2) => if (target_addr <= 0xFF) 1 else 2, // PUSH
        @intFromEnum(Opcodes.jmps), @intFromEnum(Opcodes.jmpl) => blk: { // JMP
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr));
            break :blk if (offset >= -128 and offset <= 127) 1 else 2;
        },
        @intFromEnum(Opcodes.jnzs), @intFromEnum(Opcodes.jnzl) => blk: { // JNZ
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr));
            break :blk if (offset >= -128 and offset <= 127) 1 else 2;
        },
        else => if (target_addr <= 0xFF) 1 else 2, // Bare @label or unknown
    };
}
fn emitReference(self: *Assembler, output: *ArrayListUnmanaged(u8), chunk: *const Chunk, current_addr: u32, target_addr: u32, is_relative: bool) Error!void {
    const instructions = switch (chunk.*) {
        .instructions => |*list| list,
        else => &ArrayListUnmanaged(u8).empty,
    };
    if (instructions.items.len == 0) {
        // Bare @label with no preceding opcode
        if (target_addr <= 0xFF) {
            try output.append(self.gpa, @intCast(target_addr));
        } else {
            const bytes = std.mem.toBytes(@as(u16, @intCast(target_addr & 0xFFFF)));
            try output.appendSlice(self.gpa, &bytes);
        }
        return;
    }

    const last_opcode = instructions.items[instructions.items.len - 1];
    const chunk_base = current_addr - instructions.items.len;

    switch (last_opcode) {
        @intFromEnum(Opcodes.push1), @intFromEnum(Opcodes.push2) => { // PUSH
            if (target_addr <= 0xFF) {
                // Update to PUSH1
                output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.push1);
                try output.append(self.gpa, @intCast(target_addr));
            } else {
                // Update to PUSH2
                output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.push2);
                const bytes = std.mem.toBytes(@as(u16, @intCast(target_addr & 0xFFFF)));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
        @intFromEnum(Opcodes.jmps), @intFromEnum(Opcodes.jmpl) => { // JMP
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr)) - 1;
            if (offset >= -128 and offset <= 127) {
                output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.jmps);
                try output.append(self.gpa, @bitCast(@as(i8, @intCast(offset))));
            } else {
                output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.jmpl);
                const bytes = std.mem.toBytes(@as(u16, @intCast(target_addr & 0xFFFF)));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
        @intFromEnum(Opcodes.jnzs), @intFromEnum(Opcodes.jnzl) => { // JNZ
            if (is_relative) {
                const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr)) - 1;
                if (offset < -128 or offset > 127) return error.RelativeJumpOutOfRange;
                output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.jnzs);
                try output.append(self.gpa, @bitCast(@as(i8, @intCast(offset))));
            } else {
                const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr)) - 1;
                if (offset >= -128 and offset <= 127) {
                    output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.jnzs);
                    try output.append(self.gpa, @bitCast(@as(i8, @intCast(offset))));
                } else {
                    output.items[chunk_base + instructions.items.len - 1] = @intFromEnum(Opcodes.jnzl);
                    const bytes = std.mem.toBytes(@as(u16, @intCast(target_addr & 0xFFFF)));
                    try output.appendSlice(self.gpa, &bytes);
                }
            }
        },
        else => { // Bare @label
            if (target_addr <= 0xFF) {
                try output.append(self.gpa, @intCast(target_addr));
            } else {
                const bytes = std.mem.toBytes(@as(u16, @intCast(target_addr & 0xFFFF)));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
    }
}

pub fn registerExternalIdentifier(self: *Assembler, name: []const u8, trap_id: u8) Error!void {
    try self.external_identifiers.put(self.gpa, name, trap_id);
}

pub fn assemble(self: *Assembler) Error![]u8 {
    try self.pass1();
    return try self.pass2();
}
