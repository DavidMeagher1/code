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

const Definition = struct {
    chunk_index: u32,
    offset: u32,
    scope: *Scope,
};

const Reference = struct {
    definition_index: u32,
    after_chunk_index: u32,
};

const ReferenceList = ArrayListUnmanaged(Reference);

gpa: Allocator,
source: []const u8,
tokens: []Token,
chunks: ChunkList,
definitions: StringHashMapUnmanaged(Definition),
references: StringHashMapUnmanaged(ReferenceList),
scope_stack: ArrayListUnmanaged(*Scope),

pub fn init(allocator: Allocator, source: []const u8, tokens: []Token) !Assembler {
    const global_scope = try allocator.create(Scope);
    global_scope.* = Scope.init(".global.", null);
    var result = Assembler{
        .gpa = allocator,
        .source = source,
        .tokens = tokens,
        .chunks = .empty,
        .definitions = .empty,
        .references = .empty,
        .scope_stack = .empty,
    };
    try result.scope_stack.append(allocator, global_scope);
    return result;
}

pub fn deinit(self: *Assembler) void {
    self.chunks.deinit(self.gpa);
    self.definitions.deinit(self.gpa);
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
    // Collect labels and assume all references are long (2 bytes)
    // Implementation goes here
}
