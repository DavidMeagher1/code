const std = @import("std");
const Allocator = std.mem.Allocator;
const Parse = @This();
const AST = @import("ast.zig");
const Node = @import("node.zig");

const Error = error{ParseError} || Allocator.Error;

gpa: Allocator,
source: []const u8,
tokens: AST.TokenList.Slice,
nodes: AST.NodeList,

pub fn tokenTag(p: *const Parse, index: AST.TokenIndex) AST.Token.Tag {
    return p.tokens.items(.tag)[index];
}

pub fn addNode(self: *Parse, node: AST.Node) Allocator.Error!AST.NodeIndex {
    const result: Node.NodeIndex = self.nodes.len;
    try self.nodes.append(self.gpa, node);
    return result;
}

pub fn setNode(self: *Parse, index: AST.NodeIndex, node: AST.Node) Node.NodeIndex {
    self.nodes.set(index, node);
    return index;
}

pub fn parse(self: *Parse) !void {
    self.nodes.appendAssumeCapacity(.{
        .tag = .root,
        .main_token = 0,
        .data = undefined,
    });
    const body = try self.parseBody();
    if (self.tokenTag(self.tok_index) != .eof) {
        try self.warnExpected(.eof);
    }
    _ = body;
    @compileError("TODO");
}

pub fn parseBody(self: *Parse) Allocator.Error!Node.NodeIndex {
    _ = self;
    @compileError("TODO");
}
