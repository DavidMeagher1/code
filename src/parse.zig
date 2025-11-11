const std = @import("std");
const Allocator = std.mem.Allocator;
const Parse = @This();
const AST = @import("ast.zig");
const Node = @import("node.zig");
const Iterator = @import("iterator.zig").Iterator;

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
    var node = AST.Node{
        .tag = .word_definition,
        .main_token = self.tokens[self.tok_index],
        .data = .{
            .span = .{
                .start = self.nodes.len,
                .end = self.nodes.len,
            },
        },
    };

    while (self.tokenTag(self.tok_index) != .eof) {
        switch (self.tokenTag(self.tok_index)) {
            .eof => return error.ParseError,
            .number, .string => try self.parseLiteral(),
            .identifier => try self.parseIdentifier(),
            .colon => {
                self.tok_index += 1; // consume colon
                try self.parseBody(),
            },
            else => return error.ParseError,
        }
        node.data.span.end = self.nodes.len;
    }
}

fn parseLiteral(self: *Parse) Allocator.Error!void {
    // Implementation for parsing literals
    const token = self.tokens[self.tok_index];
    switch (self.tokenTag(self.tok_index)) {
        .number => {
            if (self.tokenTag(self.tok_index + 1) == .period) {
                if (self.tokenTag(self.tok_index + 2) != .number) {
                    return error.ParseError;
                }
                const float_token = self.tokens[self.tok_index + 2];
                const node = AST.Node{
                    .tag = .floating_literal,
                    .main_token = token,
                    .data = .{
                        .token = float_token,
                    },
                };
                try self.addNode(node);
                self.tok_index += 3; // Skip the period and the following number
            } else {
                const node = AST.Node{
                    .tag = .number_literal,
                    .main_token = token,
                    .data = .{
                        .none = .{},
                    },
                };
                try self.addNode(node);
                self.tok_index += 1;
            }
        },
        .string => {
            const node = AST.Node{
                .tag = .string_literal,
                .main_token = token,
                .data = .{
                    .none = .{},
                },
            };
            try self.addNode(node);
            self.tok_index += 1;
        },
        else => return error.ParseError,
    }
    return;
}

fn parseIdentifier(self: *Parse) Allocator.Error!void {
    const token = self.tokens[self.tok_index];
    const node = AST.Node{
        .tag = .identifier,
        .main_token = token,
        .data = .{
            .none = .{},
        },
    };
    try self.addNode(node);
    self.tok_index += 1;
}
