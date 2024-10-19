source: [:0]const u8,
tokens: TokenList.Slice,
nodes: NodeList.Slice,
extra_data: []Node.Index,

errors: []const Error,

pub const ByteOffset = u32;
pub const TokenIndex = u32;

pub const NodeList = std.MultiArrayList(Node);
pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: ByteOffset,
});

pub const Error = struct {
    tag: Tag,
    is_note: bool = false,
    token_is_prev: bool = false,
    token: TokenIndex,
    extra: union {
        none: void,
        expected_tag: Token.Tag,
    } = .{ .none = {} },

    pub const Tag = enum {
        expected_token,
        expected_register_decl,
        previous_token,
        expected_expression,
        expected_bracketed_expression,
        expected_instruction,
        expected_number_literal,
        expected_colon_op,
        unexpected_closing_paren,
        unexpected_token,
        operator_expected_argument,
        expected_closing_bracket,
    };
};

pub const Node = struct {
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    pub const Index = u32;

    pub const Tag = enum {
        root,
        decl_register,
        colon_op,
        op_add,
        op_sub,
        op_div,
        op_mul,
        op_mod,
        op_bxor,
        op_bor,
        op_band,
        op_bnot,
        op_shl,
        op_shr,
        move,
        add,
        jump,
        jump_equ,
        jump_lth,
        jump_gth,
        number_literal,
        identifier,
    };

    pub const Data = struct {
        lhs: Index,
        rhs: Index,
    };

    pub const SubRange = struct {
        start: Index,
        end: Index,
    };
};

pub fn parse(gpa: Allocator, source: [:0]const u8) Allocator.Error!Ast {
    var tokens = Ast.TokenList{};
    defer tokens.deinit(gpa);

    var tokizer = Tokenizer.init(source);
    while (true) {
        const token = tokizer.next();
        try tokens.append(gpa, .{
            .tag = token.tag,
            .start = @intCast(token.loc.start),
        });
        if (token.tag == .eof) break;
    }

    var parser: Parse = .{
        .source = source,
        .gpa = gpa,
        .token_tags = tokens.items(.tag),
        .token_starts = tokens.items(.start),
        .errors = .{},
        .nodes = .{},
        .extra_data = .{},
        .scratch = .{},
        .token_index = 0,
    };
    defer parser.errors.deinit(gpa);
    defer parser.nodes.deinit(gpa);
    defer parser.extra_data.deinit(gpa);
    defer parser.scratch.deinit(gpa);

    try parser.parseRoot();

    return Ast{
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extra_data = try parser.extra_data.toOwnedSlice(gpa),
        .errors = try parser.errors.toOwnedSlice(gpa),
    };
}

pub fn tokenSlice(tree: Ast, token_index: TokenIndex) []const u8 {
    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);
    const token_tag = token_tags[token_index];

    var tokenizer: Tokenizer = .{
        .buffer = tree.source,
        .index = token_starts[token_index],
    };
    const token = tokenizer.next();
    assert(token.tag == token_tag);
    return tree.source[token.loc.start..token.loc.end];
}

pub fn renderError(tree: Ast, parse_error: Error, stream: anytype) !void {
    //TODO make this so it can print other places than the debug
    const token_tags = tree.tokens.items(.tag);
    switch (parse_error.tag) {
        .expected_closing_bracket => {
            return stream.print("expected {s} got {s}", .{
                Token.Tag.r_bracket.symbol(),
                token_tags[parse_error.token + @intFromBool(parse_error.token_is_prev)].symbol(),
            });
        },
        .operator_expected_argument => {
            return stream.print("operator expected another argument got {s}", .{
                (token_tags[parse_error.token + @intFromBool(parse_error.token_is_prev)]).symbol(),
            });
        },
        .expected_token => {
            return stream.print("expected {s} got '{s}'", .{
                parse_error.extra.expected_tag.symbol(),
                (tree.tokenSlice(parse_error.token + @intFromBool(parse_error.token_is_prev))),
            });
        },
        .expected_expression => {
            const slice = tree.tokenSlice(parse_error.token + @intFromBool(parse_error.token_is_prev));
            return stream.print("expected expession got '{s}'", .{
                slice,
            });
        },
        .unexpected_token => {
            return stream.print("unexpected token {s}", .{
                (tree.tokenSlice(parse_error.token + @intFromBool(parse_error.token_is_prev))),
            });
        },
        else => {
            return stream.print("unkown error {any}", .{parse_error.tag});
        },
    }
}

pub fn deinit(tree: *Ast, gpa: Allocator) void {
    tree.tokens.deinit(gpa);
    tree.nodes.deinit(gpa);
    gpa.free(tree.extra_data);
    gpa.free(tree.errors);
    tree.* = undefined;
}

pub const full = @import("ast_full.zig");
const Ast = @This();
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parse = @import("./parser.zig");

test "simple parsing"{
    const GPA = std.heap.GeneralPurposeAllocator(.{});
    var gpa = GPA{};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();
    const source = //watchout for errant back slashes when testing
    \\:test
    \\register r1 $1
    \\! place
    \\! place
    ;
    
    var ast = try Ast.parse(alloc, source);
    defer ast.deinit(alloc);
    try testing.expectEqual(0,ast.errors.len);
    //try stdout.print("OUTPUT:\n{any}\n", .{ast.nodes.items(.tag)});
}
