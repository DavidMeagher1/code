instructions: std.MultiArrayList(Inst).Slice,

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Ref = u32;
    pub const Tag = enum { number };
    pub const Data = union {
        move_addr_reg: struct {
            addr_node: Ast.Node.Index,
            register_ref: Ref,
        },
        number: u16,

        //not sure how to use this yet
        pl_node: struct {
            src_node: Ast.Node.Index,
            payload_index: Ref,
        },
    };
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const Ast = @import("./ast/ast.zig");
const Asm = @This();
