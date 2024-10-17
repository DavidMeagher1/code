pub const Error = error{parse_error} || Allocator.Error;

gpa: Allocator,
source: []const u8,
errors: std.ArrayListUnmanaged(AstError),
token_tags: []const Token.Tag,
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
        .expected_bracketed_expression,
        .expected_colon_op,
        .expected_instruction,
        .expected_number_literal,
        .expected_register_decl,
        .expected_token,
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
    return std.mem.indexOfScalar(u8, p.source[p.token_starts[token1]..p.token_starts[token2]], '\n') == null;
}

pub fn parseRoot(p: *Parse) !void {
    try p.nodes.append(p.gpa, .{
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

fn parseContainerMembers(p: *Parse) !Members {
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
                const register_decl_node = try p.expectRegisterDeclRecoverable();
                // if (field_state == .seen) {
                //     field_state = .{ .end = register_decl_node };
                // }
                if (register_decl_node != 0) {
                    try p.scratch.append(p.gpa, register_decl_node);
                }
            },
            .equal, // move
            .keyword_jmp,
            .keyword_jeq,
            .keyword_jlt,
            .keyword_jgt,
            .plus, // add
            .keyword_pop,
            .keyword_psh,
            => {
                const instruction_node = try p.expectInstructionRecoverable();
                if (instruction_node != 0) {
                    try p.scratch.append(p.gpa, instruction_node);
                }
            },
            .colon => {
                const colon_op_node = try p.expectColonOpRecoverable();
                if (colon_op_node != 0) {
                    try p.scratch.append(p.gpa, colon_op_node);
                }
            },
            .eof => break,
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
    _ = p.nextToken();
    const ident = try p.expectToken(.identifier);
    const node = try p.addNode(.{
        .tag = .decl_register,
        .main_token = ident,
        .data = .{
            .lhs = undefined,
            .rhs = undefined,
        },
    });
    p.nodes.items(.data)[node] = .{
        .lhs = try p.expectExpr(),
        .rhs = 0,
    };
    return node;
}

fn expectRegisterDecl(p: *Parse) !Node.Index {
    const node = try p.parseRegisterDecl();
    if (node == 0) {
        return p.fail(.expected_register_decl);
    } else {
        return node;
    }
}

fn expectRegisterDeclRecoverable(p: *Parse) Allocator.Error!Node.Index {
    return p.expectRegisterDecl() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.parse_error => {
            p.findNextContainerMember();
            return null_node;
        },
    };
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
        .l_bracket => try p.expectBracketExpression(),
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

fn parseBracketExpression(p: *Parse) Error!Node.Index {
    _ = p.nextToken();
    const main_token = p.token_index;
    return switch (p.token_tags[main_token]) {
        .plus,
        .minus,
        .asterisk,
        .ampersand,
        .caret,
        .mod,
        .tilde,
        .pipe,
        .forward_slash,
        .angle_bracket_l,
        .angle_bracket_r,
        .r_paren,
        => {
            const node = try p.parseOp();
            return node;
        },
        .number_literal => {
            const node = try p.addNode(.{
                .tag = .number_literal,
                .main_token = p.nextToken(),
                .data = .{
                    .rhs = undefined,
                    .lhs = undefined,
                },
            });
            _ = try p.expectToken(.r_bracket);
            return node;
        },
        .identifier => {
            const node = try p.addNode(.{
                .tag = .identifier,
                .main_token = p.nextToken(),
                .data = .{
                    .rhs = undefined,
                    .lhs = undefined,
                },
            });
            _ = try p.expectToken(.r_bracket);
            return node;
        },
        .r_bracket => return p.fail(.expected_expression),
        else => return null_node,
    };
}

fn expectBracketExpression(p: *Parse) Error!Node.Index {
    const node = try p.parseBracketExpression();
    if (node == 0) {
        return p.fail(.expected_bracketed_expression);
    }
    return node;
}

fn parseOp(p: *Parse) Error!Node.Index {
    const scratch_top = p.scratch.items.len;
    defer p.scratch.shrinkRetainingCapacity(scratch_top);
    const State = enum {
        start,
        operator,
        operand,
        done,
    };

    const ProcessingSide = enum {
        none,
        left,
        right,
    };

    var bracket_level: u32 = 1;
    var paren_level: u32 = 0;
    var processing_side: ProcessingSide = .none;
    var result: Node.Index = 0;

    state: switch (State.start) {
        .start => {
            switch (p.token_tags[p.token_index]) {
                .l_bracket => {
                    p.token_index += 1;
                    if (p.token_tags[p.token_index] == .r_bracket) {
                        p.token_index += 1;
                        continue :state .start;
                    } else {
                        bracket_level += 1;
                        continue :state .start;
                    }
                },
                .r_bracket => {
                    if (processing_side == .right or processing_side == .left) {
                        return p.fail(.operator_expected_argument);
                    }
                    p.token_index += 1;
                    bracket_level -= 1;
                    if (bracket_level == 0) {
                        continue :state .done;
                    }
                    continue :state .start;
                },
                .l_paren => {
                    p.token_index += 1;
                    if (p.token_tags[p.token_index] == .r_paren) {
                        p.token_index += 1;
                        continue :state .start;
                    } else {
                        paren_level += 1;
                        continue :state .start;
                    }
                },
                .r_paren => {
                    p.token_index += 1;
                    paren_level -= 1;
                    if (paren_level < 0) {
                        return p.fail(.unexpected_closing_paren);
                    }
                },
                .plus, // 2 operand operators
                .minus,
                .asterisk,
                .ampersand,
                .caret,
                .mod,
                .pipe,
                .forward_slash,
                .angle_bracket_l,
                .angle_bracket_r,
                .tilde,
                => {
                    const node = try p.addNode(.{
                        .tag = switch (p.token_tags[p.token_index]) {
                            .plus => .op_add,
                            .minus => .op_sub,
                            .asterisk => .op_mul,
                            .ampersand => .op_band,
                            .caret => .op_bxor,
                            .mod => .op_mod,
                            .pipe => .op_bor,
                            .forward_slash => .op_div,
                            .angle_bracket_l => .op_shl,
                            .angle_bracket_r => .op_shr,
                            .tilde => .op_bnot,
                            else => unreachable,
                        },
                        .main_token = p.token_index,
                        .data = .{
                            .lhs = 0,
                            .rhs = 0,
                        },
                    });
                    try p.scratch.append(p.gpa, node);
                    p.token_index += 1;
                    continue :state .operator;
                },
                .identifier, .number_literal => {
                    const node = try p.addNode(.{
                        .tag = switch (p.token_tags[p.token_index]) {
                            .identifier => .identifier,
                            .number_literal => .number_literal,
                            else => unreachable,
                        },
                        .main_token = p.token_index,
                        .data = .{
                            .lhs = 0,
                            .rhs = 0,
                        },
                    });
                    try p.scratch.append(p.gpa, node);
                    p.token_index += 1;
                    continue :state .operand;
                },
                else => {
                    //TODO might need to fail here
                    return null_node;
                },
            }
        },
        .operator => {
            side: switch (processing_side) {
                .none => {
                    processing_side = .left;
                    continue :state .start;
                },
                .left => {
                    //adding operator to left side of operator
                    if (p.nodes.items(.data)[p.scratch.items[p.scratch.items.len - 2]].lhs != 0) {
                        processing_side = .right;
                        continue :side processing_side;
                    }
                    const scratch = p.scratch.items[scratch_top..];
                    if (scratch.len > 1) {
                        switch (p.token_tags[p.nodes.items(.main_token)[scratch[scratch.len - 2]]]) {
                            .tilde => {
                                p.nodes.items(.data)[scratch[scratch.len - 2]] = .{
                                    .lhs = scratch[scratch.len - 1],
                                    .rhs = 0,
                                };
                            },
                            else => {
                                p.nodes.items(.data)[scratch[scratch.len - 2]] = .{
                                    .lhs = scratch[scratch.len - 1],
                                    .rhs = 0,
                                };
                            },
                        }
                    }
                    continue :state .start;
                },
                .right => {
                    //adding operator to right side of operator
                    const scratch = p.scratch.items[scratch_top..];
                    if (scratch.len > 1) {
                        p.nodes.items(.data)[scratch[scratch.len - 2]].rhs = scratch[scratch.len - 1];
                    }
                    processing_side = .none;
                    continue :state .start;
                },
            }
        },
        .operand => {
            side: switch (processing_side) {
                .none => {
                    processing_side = .left;
                    continue :side processing_side;
                },
                .left => {
                    //adding operand to left side of operator
                    //if operator only has one param pop it off as well
                    if (p.nodes.items(.data)[p.scratch.items[p.scratch.items.len - 2]].lhs != 0) {
                        processing_side = .right;
                        continue :side processing_side;
                    }
                    const scratch = p.scratch.items[scratch_top..];
                    if (scratch.len > 1) {
                        //std.debug.print("\n\nadding opand to left\n\n", .{});
                        p.nodes.items(.data)[scratch[scratch.len - 2]] = .{
                            .lhs = scratch[scratch.len - 1],
                            .rhs = 0,
                        };
                        _ = p.scratch.pop();
                    } else {
                        unreachable;
                    }
                    switch (p.token_tags[p.nodes.items(.main_token)[p.scratch.items[p.scratch.items.len - 1]]]) {
                        .tilde => { // one param ops
                            result = p.scratch.items[p.scratch.items.len - 1];
                            _ = p.scratch.pop();
                            processing_side = .none;
                        },
                        else => {
                            processing_side = .right;
                        },
                    }
                    continue :state .start;
                },
                .right => {
                    //adding operand to right side of operator
                    // pop off both after this nodes only have lhs and rhs
                    const scratch = p.scratch.items[scratch_top..];

                    if (scratch.len > 1) {
                        p.nodes.items(.data)[scratch[scratch.len - 2]].rhs = scratch[scratch.len - 1];
                        _ = p.scratch.pop();
                    } else {
                        try p.warnMsg(.{
                            .tag = .expected_closing_bracket,
                            .is_note = true,
                            .token = p.token_index - 1,
                        });
                        return error.parse_error;
                    }
                    if (p.scratch.items.len > 1) {
                        result = p.scratch.items[0];
                    }
                    _ = p.scratch.pop();
                    processing_side = .none;
                    continue :state .start;
                },
            }
        },
        .done => {},
    }
    return result;
}

fn parseInstruction(p: *Parse) Error!Node.Index {
    return switch (p.token_tags[p.token_index]) {
        .equal => p.parseMove(),
        .plus => p.parseAdd(),
        .keyword_jmp => p.parseUnconditionalJump(),
        .keyword_jeq,
        .keyword_jlt,
        .keyword_jgt,
        => p.parseConditionalJump(),
        else => return null_node,
    };
}

fn parseColonOp(p: *Parse) Error!Node.Index {
    const node = try p.addNode(.{
        .tag = .colon_op,
        .main_token = p.nextToken(),
        .data = .{
            .lhs = undefined,
            .rhs = undefined,
        },
    });
    p.nodes.items(.data)[node] = .{
        .lhs = try p.expectExpr(),
        .rhs = 0,
    };
    return node;
}

fn expectColonOp(p: *Parse) Error!Node.Index {
    const node = try p.parseColonOp();
    if (node == 0) {
        return p.fail(.expected_colon_op);
    }
    return node;
}

fn expectColonOpRecoverable(p: *Parse) Allocator.Error!Node.Index {
    return p.expectColonOp() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.parse_error => {
            p.findNextContainerMember();
            return null_node;
        },
    };
}

fn parseMove(p: *Parse) Error!Node.Index {
    const main_token = p.nextToken();
    const node = try p.addNode(.{
        .tag = .move,
        .main_token = main_token,
        .data = .{
            .lhs = undefined,
            .rhs = undefined,
        },
    });
    p.nodes.items(.data)[node] = .{
        .lhs = try p.expectExpr(),
        .rhs = try p.expectExpr(),
    };
    return node;
}

fn parseAdd(p: *Parse) Error!Node.Index {
    const main_token = p.nextToken();
    const node = try p.addNode(.{
        .tag = .add,
        .main_token = main_token,
        .data = undefined,
    });
    p.nodes.items(.data)[node] = .{
        .lhs = try p.expectExpr(),
        .rhs = try p.expectExpr(),
    };
    return node;
}

fn parseUnconditionalJump(p: *Parse) Error!Node.Index {
    const main_token = p.nextToken();
    const lhs = try p.expectExpr();
    return p.addNode(.{
        .tag = .jump,
        .main_token = main_token,
        .data = .{
            .lhs = lhs,
            .rhs = 0,
        },
    });
}

fn parseConditionalJump(p: *Parse) Error!Node.Index {
    const main_token = p.nextToken();
    const lhs = try p.expectExpr();
    const rhs = try p.expectExpr();
    return p.addNode(.{
        .tag = .jump,
        .main_token = main_token,
        .data = .{
            .lhs = lhs,
            .rhs = rhs,
        },
    });
}

fn expectInstruction(p: *Parse) Error!Node.Index {
    const node = try p.parseInstruction();
    if (node == 0) {
        return p.fail(.expected_instruction);
    } else {
        return node;
    }
}

fn expectInstructionRecoverable(p: *Parse) Allocator.Error!Node.Index {
    return p.expectInstruction() catch |err| switch (err) {
        error.OutOfMemory => return Error.OutOfMemory,
        error.parse_error => {
            p.findNextContainerMember();
            return null_node;
        },
    };
}

fn parseNumberLit(p: *Parse) Error!Node.Index {
    return switch (p.token_tags[p.token_index]) {
        .number_literal => p.addNode(.{
            .tag = .number_literal,
            .main_token = p.nextToken(),
            .data = .{
                .rhs = undefined,
                .lhs = undefined,
            },
        }),
        else => null_node,
    };
}

fn parseIdent(p: *Parse) Error!Node.Index {
    return switch (p.token_tags[p.token_index]) {
        .number_literal => p.addNode(.{
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

fn expectNumberLit(p: *Parse) Error!Node.Index {
    const node = try p.parseNumberLit();
    if (node == 0) {
        return p.fail(.expected_number_literal);
    }
    return node;
}

fn findNextContainerMember(p: *Parse) void {
    while (true) {
        const tok = p.nextToken();
        switch (p.token_tags[tok]) {
            .keyword_jeq,
            .keyword_jgt,
            .keyword_jlt,
            .keyword_jmp,
            .plus,
            .equal,
            .keyword_register,
            .keyword_pop,
            .keyword_psh,
            .colon,
            .eof,
            => {
                p.token_index -= 1;
                return;
            },
            else => {},
        }
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
