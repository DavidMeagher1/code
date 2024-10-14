pub const ByteOffset = u32;
pub const TokenIndex = u32;
pub const NodeList = std.MultiArrayList(Node);

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
        expected_expression,
    };
};

pub const Node = struct {
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    pub const Index = u32;

    pub const Tag = enum {
        root,
        // neight .lhs or .rhs are used,
        move,
        // lhs is where data is comming from, rhs is where data is going to
        add,
        decl_register,
        jump,
        jump_equal,
        jump_less_than,
        jump_greater_than,
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

const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;
