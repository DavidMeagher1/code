gpa: std.mem.Allocator,
registers: std.AutoHashMap([]const u8, Index),
instructions: std.MultiArrayList(Inst),
scratch: std.ArrayListUnmanaged(Inst),
pub const Index = u32;

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Tag = enum { number };

    pub const Data = union {
        move_addr_reg: struct {
            addr_node: Ast.Node.Index,
            register_ref: Index,
        },
        number: u16,

        pl_node: struct {
            src_node: Ast.Node.Index,
            payload_index: Index,
        },
    };
};

fn add(self: *Asm, inst: Inst) !Index {
    const result = @as(Index, @intCast(self.instructions.len));
    try self.instructions.append(self.gpa, inst);
    return result;
}

fn addScratch(self: *Asm, inst: Inst) !Index {
    const result = @as(Index, @intCast(self.scratch.items.len));
    try self.scratch.append(self.gpa, inst);
    return result;
}

const std = @import("std");
const Ast = @import("./ast.zig");
const Asm = @This();
