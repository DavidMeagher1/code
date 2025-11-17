const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Scope = @This();

name: []const u8 = ".global.", // this is an invalid label name so it won't conflict
parent: ?*Scope = null,
children: ArrayListUnmanaged(*Scope),
symbols: ArrayListUnmanaged([]const u8),

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

pub fn addSymbol(self: *Scope, allocator: Allocator, symbol: []const u8) !void {
    try self.symbols.append(allocator, symbol);
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

pub fn resolveSymbol(self: *Scope, symbol: []const u8) ?*Scope {
    var current: ?*Scope = self;
    while (current) |scope| {
        for (scope.symbols.items) |sym| {
            if (std.mem.eql(u8, sym, symbol)) {
                return scope;
            }
        }
        current = scope.parent;
    }
    return null;
}
