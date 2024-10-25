gpa: Allocator,
source: []const u8,
token_tags: []const Token.Tag,
token_starts: []const Ast.ByteOffset,
tok_i: TokenIndex,
errors: std.ArrayListUnmanaged(AstError),
nodes: Ast.NodeList,
extra_data: std.ArrayListUnmanaged(Node.Index),
scratch: std.ArrayListUnmanaged(Node.Index),

pub fn parseRoot() !void {}

fn parseContainerMembers() void {}

const Parser = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const Tokenizer = @import("./tokenizer.zig");
const Token = Tokenizer.Token;
const Ast = @import("./ast.zig");
const AstError = Ast.Error;
const TokenIndex = Ast.TokenIndex;
const Node = Ast.Node;
