const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
const Scope = @This();

pub const Definition = struct {
    address: u32,
};

name: []const u8 = ".global.", // this is an invalid label name so it won't conflict
parent: ?*Scope = null,
children: ArrayListUnmanaged(*Scope),
symbols: StringHashMapUnmanaged(Definition),

pub fn init(name: []const u8, parent: ?*Scope) Scope {
    return Scope{
        .name = name,
        .parent = parent,
        .children = .empty,
        .symbols = .empty,
    };
}
pub fn deinit(self: *Scope, allocator: Allocator) void {
    for (self.children.items) |child| {
        child.deinit(allocator);
        allocator.destroy(child);
    }

    self.children.deinit(allocator);
    self.symbols.deinit(allocator);
    self.parent = null;
    self.name = &[_]u8{}; // we assume the name memory is managed elsewhere
}

pub fn addChild(self: *Scope, allocator: Allocator, child: *Scope) !void {
    try self.children.append(allocator, child);
}

pub fn addSymbol(self: *Scope, allocator: Allocator, name: []const u8, def: Definition) !void {
    try self.symbols.put(allocator, name, def);
}

pub fn getFullName(self: *Scope, allocator: Allocator) ![]const u8 {
    var parts = ArrayListUnmanaged([]const u8).empty;
    defer parts.deinit(allocator);

    var current: ?*Scope = self;
    while (current) |scope| {
        try parts.append(allocator, scope.name);
        current = scope.parent;
    }
    std.mem.reverse([]const u8, parts.items);

    const full_name = try std.mem.join(allocator, ".", parts.items);

    return full_name;
}

pub fn resolveSymbol(self: *Scope, symbol: []const u8) ?u32 {
    var current: ?*Scope = self;
    while (current) |scope| {
        if (scope.symbols.get(symbol)) |def| {
            return def.address;
        }
        current = scope.parent;
    }
    return null;
}
