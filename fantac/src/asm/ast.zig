pub const ByteOffset = u32;
pub const TokenIndex = u32;
pub const NodeList = std.MultiArrayList(Node);

pub const Error = struct {
    tag: Tag,
    is_note: bool,
    for_previous: bool,

    pub const Tag = enum {};
};

pub const Node = struct {
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    pub const Index = u32;
    pub const Tag = enum {};

    pub const Data = struct {
        lhs: Index,
        rhs: Index,
    };
};

const Ast = @This();
const std = @import("std");
