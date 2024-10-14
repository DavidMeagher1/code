pub const Error = error{parse_error} || Allocator.Error;

gpa: Allocator,
source: []const u8,
errors: std.ArrayListUnmanaged(AstError),
token_tags: []const Token.tag,
token_starts: []const Ast.ByteOffset,
token_index: TokenIndex,
nodes: Ast.NodeList,
extra_data: std.ArrayListUnmanaged(Node.Index),
scratch: std.ArrayListUnmanaged(Node.Index),

const Members = struct {
    len: usize,
    lhs: Node.Index,
    rhs: Node.Index,
    trailing: bool,

    fn toSpan(self: Members, p: *Parse) !Node.SubRange {
        if (self.len <= 2) {
            const nodes = [2]Node.Index{ self.lhs, self.rhs };
            return p.listToSpan(nodes[0..self.len]);
        } else {
            return Node.SubRange{ .start = self.lhs, .end = self.rhs };
        }
    }
};

fn listToSpan(p: *Parse, list: []const Node.Index) !Node.SubRange {
    try p.extra_data.appendSlice(p.gpa, list);
    return Node.SubRange{
        .start = @as(Node.Index, @intCast(p.extra_data.items.len - list.len)),
        .end = @as(Node.Index, @intCast(p.extra_data.items.len)),
    };
}

fn addNode(p: *Parse, elem: Ast.Node) Allocator.Error!Node.Index {
    const result = @as(Node.Index, @intCast(p.nodes.len));
    try p.nodes.append(p.gpa, elem);
    return result;
}

fn warnMsg(p: *Parse, msg: AstError) Allocator.Error!void {
    switch (msg.tag) {
        .expected_expression,
        => if (msg.token != 0 and !p.tokensOnSameLine(msg.token - 1, msg.token)) {
            var copy = msg;
            copy.token_is_prev = true;
            copy.token -= 1;
            return p.errors.append(p.gpa, copy);
        },
        else => {},
    }
    try p.errors.append(p.gpa, msg);
}

fn warn(p: *Parse, error_tag: AstError.Tag) !void {
    try p.warnMsg(.{ .tag = error_tag, .token = p.token_index });
}

fn failMsg(p: *Parse, msg: AstError) error{ parse_error, OutOfMemory } {
    try p.warnMsg(msg);
    return error.parse_error;
}

fn fail(p: *Parse, tag: AstError.Tag) error{ parse_error, OutOfMemory } {
    return p.failMsg(.{
        .tag = tag,
        .token = p.token_index,
    });
}

fn failExpected(p: *Parse, expected_token: Token.Tag) error{ parse_error, OutOfMemory } {
    return p.failMsg(.{
        .tag = .expected_token,
        .token = p.token_index,
        .extra = .{ .expected_tag = expected_token },
    });
}

fn warnExpected(p: *Parse, expected_token: Token.Tag) !void {
    try p.warnMsg(.{ .tag = .expected_token, .token = p.token_index, .extra = .{ .expected_tag = expected_token } });
}

fn tokensOnSameLine(p: *Parse, token1: TokenIndex, token2: TokenIndex) bool {
    return std.mem.indexOfScalar(u8, p.source[p.token_starts[token1]..p.token_starts[token2]], '\n');
}

pub fn parseRoot(p: *Parse) !void {
    p.nodes.appendAssumeCapacity(.{
        .tag = .root,
        .main_token = 0,
        .data = undefined,
    });

    const root_members = try p.parseContainerMembers();
    const root_decls = try root_members.toSpan(p);

    if (p.token_tags[p.token_index] != .eof) {
        try p.warnExpected(.eof);
    }
    p.nodes.items(.data)[0] = .{
        .lhs = root_decls.start,
        .rhs = root_decls.end,
    };
}

fn parseContainerMembers(p: *Parse) Allocator.Error!Members {
    const scratch_top = p.scratch.items.len;
    defer p.scratch.shrinkRetainingCapacity(scratch_top);

    // var field_state: union(enum) {
    //     /// No fields have been seen.
    //     none,
    //     /// Currently parsing fields.
    //     seen,
    //     /// Saw fields and then a declaration after them.
    //     /// Payload is first token of previous declaration.
    //     end: Node.Index,
    //     /// There was a declaration between fields, don't report more errors.
    //     err,
    // } = .none;

    //var last_field: TokenIndex = undefined;

    //SUPPOSED TO BE A VAR
    const trailing = false;

    while (true) {
        switch (p.token_tags[p.token_index]) {
            .keyword_register => {
                const register_decl_node = try p.expectRegisterDecl();
                // if (field_state == .seen) {
                //     field_state = .{ .end = register_decl_node };
                // }
                try p.scratch.append(p.gpa, register_decl_node);
            },
            else => {
                // switch (field_state) {
                //     .none => field_state = .seen,
                //     .err, .seen => {},
                //     .end => {
                //         //TODO warnings for having seen a node already
                //         field_state = .err;
                //     },
                // }
            },
        }
    }

    const items = p.scratch.items[scratch_top..];
    switch (items.len) {
        0 => return Members{
            .len = 0,
            .lhs = 0,
            .rhs = 0,
            .trailing = trailing,
        },
        1 => return Members{ .len = 1, .lhs = items[0], .rhs = 0, .trailing = trailing },
        2 => return Members{
            .len = 2,
            .lhs = items[0],
            .rhs = items[1],
            .trailing = trailing,
        },
        else => {
            const span = try p.listToSpan(items);
            return Members{ .len = items.len, .lhs = span.start, .rhs = span.end, .trailing = trailing };
        },
    }
}

fn parseRegisterDecl(p: *Parse) !Node.Index {
    const ident = try p.expectToken(.identifier);
    const expr_node = p.expectExpr();
    return p.addNode(.{ .tag = .decl_register, .main_token = ident, .data = .{
        .lhs = expr_node,
        .rhs = 0,
    } });
}

fn expectRegisterDecl(p: *Parse) !Node.Index {
    const node = p.parseRegisterDecl();
    if (node == 0) {
        return p.fail(.expected_register_decl);
    } else {
        return node;
    }
}

fn parseExpr(p: *Parse) Error!Node.Index {
    return switch (p.token_tags[p.token_index]) {
        .number_literal => p.addNode(.{
            .tag = .number_literal,
            .main_token = p.nextToken(),
            .data = .{
                .rhs = undefined,
                .lhs = undefined,
            },
        }),
        .identifier => p.addNode(.{
            .tag = .identifier,
            .main_token = p.nextToken(),
            .data = .{
                .rhs = undefined,
                .lhs = undefined,
            },
        }),
        else => null_node,
    };
}

fn expectExpr(p: *Parse) Error!Node.Index {
    const node = try p.parseExpr();
    if (node == 0) {
        return p.fail(.expected_expression);
    } else {
        return node;
    }
}

fn expectToken(p: *Parse, tag: Token.Tag) Error!TokenIndex {
    if (p.token_tags[p.token_index] != tag) {
        return p.failExpected(tag);
    }
    return p.nextToken();
}

fn eatToken(p: *Parse, tag: Token.Tag) ?TokenIndex {
    return if (p.token_tags[p.token_index] == tag) p.nextToken() else null;
}

fn nextToken(p: *Parse) TokenIndex {
    const result = p.token_index;
    p.token_index += 1;
    return result;
}

const null_node: Node.Index = 0;

const Parse = @This();
const std = @import("std");
const tokenizer = @import("./tokenizer.zig");
const Ast = @import("./ast.zig");
const AstError = Ast.Error;
const TokenIndex = Ast.TokenIndex;
const Node = Ast.Node;
const Allocator = std.mem.Allocator;
const Token = tokenizer.Token;
