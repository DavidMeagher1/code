const std = @import("std");
const Allocator = std.mem.Allocator;
const MultiArrayList = std.MultiArrayList;
const AST = @This();
const index = @import("index.zig");
const Node = @import("node.zig");
const Token = @import("token.zig");
const Parse = @import("parse.zig");

const NodeList = MultiArrayList(Node);
const TokenList = MultiArrayList(Token);

nodes: NodeList.Slice,
tokens: TokenList.Slice,

pub fn parse(alloc: Allocator, source: []const u8) Allocator.Error!AST {
    const parser = Parse{
        .gpa = alloc,
        .source = source,
        .tokens = TokenList.Slice.init(),
        .nodes = NodeList.Slice.init(),
    };
    try parser.parse();
    return AST{
        .nodes = parser.nodes.toOwnedSlice(),
        .tokens = parser.tokens.toOwnedSlice(),
    };
}
