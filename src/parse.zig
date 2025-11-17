const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
const Token = @import("token.zig");
const Scope = @import("scope.zig");
const Assembler = @This();

const Chunk = struct {
    instructions: ArrayListUnmanaged(u8) = .empty,

    fn deinit(self: *Chunk, allocator: Allocator) void {
        self.instructions.deinit(allocator);
        self.instructions = .empty;
    }
};

const ChunkList = ArrayListUnmanaged(Chunk);

const Reference = struct {
    label_name: []const u8,
    after_chunk_index: u32,
};

const ReferenceList = ArrayListUnmanaged(Reference);

gpa: Allocator,
source: []const u8,
tokens: []Token,
chunks: ChunkList,
references: ArrayListUnmanaged(Reference),
scope_stack: ArrayListUnmanaged(*Scope),

pub fn init(allocator: Allocator, source: []const u8, tokens: []Token) !Assembler {
    const global_scope = try allocator.create(Scope);
    global_scope.* = Scope.init(".global.", null);
    var result = Assembler{
        .gpa = allocator,
        .source = source,
        .tokens = tokens,
        .chunks = .empty,
        .references = .empty,
        .scope_stack = .empty,
    };
    try result.scope_stack.append(allocator, global_scope);
    return result;
}

pub fn deinit(self: *Assembler) void {
    self.chunks.deinit(self.gpa);
    self.references.deinit(self.gpa);
    self.scope_stack.items[0].deinit(self.gpa); // this recursively deinitializes child scopes
    self.gpa.destroy(self.scope_stack.items[0]);
    self.scope_stack.deinit(self.gpa);
    self.source = &[_]u8{};
    self.tokens = &[_]Token{};
    self.gpa = Allocator{};
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

fn pushScope(self: *Assembler, scope: *Scope) !void {
    try self.scope_stack.append(self.gpa, scope);
}

fn popScope(self: *Assembler) ?*Scope {
    if (self.scope_stack.items.len <= 1) { // Don't pop global scope
        return null;
    }
    return self.scope_stack.pop();
}

fn emitByte(self: *Assembler, byte: u8) !void {
    if (self.chunks.items.len == 0) {
        var new_chunk = Chunk{};
        try new_chunk.instructions.init(self.gpa);
        try self.chunks.append(self.gpa, new_chunk);
    }
    const last_index = self.chunks.items.len - 1;
    try self.chunks.items[last_index].instructions.append(self.gpa, byte);
}

fn emitBytes(self: *Assembler, bytes: []const u8) !void {
    for (bytes) |b| {
        try self.emitByte(b);
    }
}

fn pass1(self: *Assembler) !void {
    var current_chunk = Chunk{};
    var current_scope: *Scope = self.currentScope().?;
    var i: usize = 0;

    while (i < self.tokens.len) : (i += 1) {
        const tok = self.tokens[i];

        switch (tok.tag) {
            .global_label => {
                // :name - create new scope
                const name = self.getLexeme(tok);

                // Record definition
                const def = Scope.Definition{
                    .chunk_index = @intCast(self.chunks.items.len),
                    .offset = @intCast(current_chunk.instructions.items.len),
                };
                try current_scope.addSymbol(self.gpa, name, def);

                // Create new child scope
                const new_scope = try self.gpa.create(Scope);
                new_scope.* = Scope.init(name, self.globalScope());
                try self.globalScope().?.addChild(self.gpa, new_scope);
                try self.pushScope(new_scope);
            },

            .local_label => {
                // &name - define in current scope
                const name = self.getLexeme(tok);

                const def = Scope.Definition{
                    .chunk_index = @intCast(self.chunks.items.len),
                    .offset = @intCast(current_chunk.instructions.items.len),
                };
                try current_scope.addSymbol(self.gpa, name, def);
            },

            .label_reference => {
                // @name - close chunk, record reference, start new chunk
                const name = self.getLexeme(tok);

                // Close current chunk
                try self.chunks.append(self.gpa, current_chunk);
                const chunk_idx = self.chunks.items.len - 1;

                // Record reference
                try self.references.append(self.gpa, .{
                    .label_name = name,
                    .after_chunk_index = @intCast(chunk_idx),
                });

                // Start new chunk
                current_chunk = Chunk{};
            },

            .hash => {
                // # - PUSH opcode
                try current_chunk.instructions.append(self.gpa, 0x08); // PUSH1 placeholder
                i += 1;

                if (i >= self.tokens.len) return error.UnexpectedEOF;

                const operand = self.tokens[i];
                if (operand.tag == .label_reference) {
                    // # @label - close chunk for reference
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                    });

                    current_chunk = Chunk{};
                } else if (operand.tag == .number_literal) {
                    // # 42 - immediate value
                    const val = try self.parseNumber(operand);
                    if (val <= 0xFF and val >= -128) {
                        try current_chunk.instructions.append(self.gpa, @intCast(@as(u16, @bitCast(@as(i16, @intCast(val)))) & 0xFF));
                    } else {
                        current_chunk.instructions.items[current_chunk.instructions.items.len - 1] = 0x48;
                        const bytes = std.mem.toBytes(@as(u16, @bitCast(@as(i16, @intCast(val)))));
                        try current_chunk.instructions.appendSlice(self.gpa, &bytes);
                    }
                }
            },

            .exclamation => {
                // ! - JMP opcode
                try current_chunk.instructions.append(self.gpa, 0x02); // JMPS placeholder
                i += 1;

                if (i >= self.tokens.len) return error.UnexpectedEOF;

                const operand = self.tokens[i];
                if (operand.tag == .label_reference) {
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                    });

                    current_chunk = Chunk{};
                }
            },

            .question => {
                // ? - JNZ opcode
                try current_chunk.instructions.append(self.gpa, 0x06); // JNZS placeholder
                i += 1;

                if (i >= self.tokens.len) return error.UnexpectedEOF;

                const operand = self.tokens[i];
                if (operand.tag == .label_reference) {
                    const name = self.getLexeme(operand);

                    try self.chunks.append(self.gpa, current_chunk);
                    const chunk_idx = self.chunks.items.len - 1;

                    try self.references.append(self.gpa, .{
                        .label_name = name,
                        .after_chunk_index = @intCast(chunk_idx),
                    });

                    current_chunk = Chunk{};
                }
            },

            // Simple opcodes
            .keyword_add => try current_chunk.instructions.append(self.gpa, 0x11),
            .keyword_addw => try current_chunk.instructions.append(self.gpa, 0x51),
            .keyword_sub => try current_chunk.instructions.append(self.gpa, 0x12),
            .keyword_subw => try current_chunk.instructions.append(self.gpa, 0x52),
            .keyword_halt => try current_chunk.instructions.append(self.gpa, 0x01),
            .keyword_nop => try current_chunk.instructions.append(self.gpa, 0x40),

            // TODO: Add all other opcodes

            .eof => break,
            .comment => {},
            else => {
                std.debug.print("Unhandled token: {s}\n", .{@tagName(tok.tag)});
                return error.UnhandledToken;
            },
        }
    }

    // Don't forget final chunk
    if (current_chunk.instructions.items.len > 0) {
        try self.chunks.append(self.gpa, current_chunk);
    }
}

fn getLexeme(self: *Assembler, tok: Token) []const u8 {
    return self.source[tok.location.start_index..tok.location.end_index];
}

fn parseNumber(self: *Assembler, tok: Token) !i32 {
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

fn pass2(self: *Assembler) ![]u8 {
    // Step 1: Calculate chunk addresses with reference sizes
    var chunk_addrs = try ArrayListUnmanaged(u32).initCapacity(self.gpa, self.chunks.items.len);
    defer chunk_addrs.deinit(self.gpa);

    var addr: u32 = 0;
    for (self.chunks.items, 0..) |chunk, i| {
        try chunk_addrs.append(self.gpa, addr);
        addr += @intCast(chunk.instructions.items.len);

        // Check for references after this chunk
        for (self.references.items) |ref| {
            if (ref.after_chunk_index == i) {
                // Look up definition in scope tree
                const def = self.currentScope().?.resolveSymbol(ref.label_name) orelse return error.UndefinedLabel;
                const target = chunk_addrs.items[def.chunk_index] + def.offset;
                const ref_size = self.calculateRefSize(&chunk, addr, target);
                addr += ref_size;
                break;
            }
        }
    }

    // Step 2: Emit bytecode with resolved references
    var output = ArrayListUnmanaged(u8){};

    for (self.chunks.items, 0..) |chunk, i| {
        // Copy chunk bytes
        try output.appendSlice(self.gpa, chunk.instructions.items);

        // Emit reference if any after this chunk
        for (self.references.items) |ref| {
            if (ref.after_chunk_index == i) {
                const def = self.currentScope().?.resolveSymbol(ref.label_name) orelse return error.UndefinedLabel;
                const target = chunk_addrs.items[def.chunk_index] + def.offset;
                const current_addr: u32 = @intCast(output.items.len);

                try self.emitReference(&output, &chunk, current_addr, target);
                break;
            }
        }
    }

    return output.toOwnedSlice(self.gpa);
}

fn calculateRefSize(self: *Assembler, chunk: *const Chunk, current_addr: u32, target_addr: u32) u32 {
    _ = self;
    if (chunk.instructions.items.len == 0) return 2;

    const last_opcode = chunk.instructions.items[chunk.instructions.items.len - 1];

    return switch (last_opcode) {
        0x08, 0x48 => if (target_addr <= 0xFF) 1 else 2, // PUSH
        0x02, 0x42 => blk: { // JMP
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr));
            break :blk if (offset >= -128 and offset <= 127) 1 else 2;
        },
        0x06, 0x46 => blk: { // JNZ
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr));
            break :blk if (offset >= -128 and offset <= 127) 1 else 2;
        },
        else => 2, // Bare @label or unknown
    };
}

fn emitReference(self: *Assembler, output: *ArrayListUnmanaged(u8), chunk: *const Chunk, current_addr: u32, target_addr: u32) !void {
    if (chunk.instructions.items.len == 0) {
        // Bare @label with no preceding opcode
        if (target_addr <= 0xFF) {
            try output.append(self.gpa, @intCast(target_addr));
        } else {
            const bytes = std.mem.toBytes(@as(u16, target_addr));
            try output.appendSlice(self.gpa, &bytes);
        }
        return;
    }

    const last_opcode = chunk.instructions.items[chunk.instructions.items.len - 1];
    const chunk_base = current_addr - chunk.instructions.items.len;

    switch (last_opcode) {
        0x08, 0x48 => { // PUSH
            if (target_addr <= 0xFF) {
                // Update to PUSH1
                output.items[chunk_base + chunk.instructions.items.len - 1] = 0x08;
                try output.append(self.gpa, @intCast(target_addr));
            } else {
                // Update to PUSH2
                output.items[chunk_base + chunk.instructions.items.len - 1] = 0x48;
                const bytes = std.mem.toBytes(@as(u16, target_addr));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
        0x02, 0x42 => { // JMP
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr)) - 1;
            if (offset >= -128 and offset <= 127) {
                output.items[chunk_base + chunk.instructions.items.len - 1] = 0x02;
                try output.append(self.gpa, @bitCast(@as(i8, @intCast(offset))));
            } else {
                output.items[chunk_base + chunk.instructions.items.len - 1] = 0x42;
                const bytes = std.mem.toBytes(@as(u16, target_addr));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
        0x06, 0x46 => { // JNZ
            const offset = @as(i32, @intCast(target_addr)) - @as(i32, @intCast(current_addr)) - 1;
            if (offset >= -128 and offset <= 127) {
                output.items[chunk_base + chunk.instructions.items.len - 1] = 0x06;
                try output.append(self.gpa, @bitCast(@as(i8, @intCast(offset))));
            } else {
                output.items[chunk_base + chunk.instructions.items.len - 1] = 0x46;
                const bytes = std.mem.toBytes(@as(u16, target_addr));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
        else => { // Bare @label
            if (target_addr <= 0xFF) {
                try output.append(self.gpa, @intCast(target_addr));
            } else {
                const bytes = std.mem.toBytes(@as(u16, target_addr));
                try output.appendSlice(self.gpa, &bytes);
            }
        },
    }
}
