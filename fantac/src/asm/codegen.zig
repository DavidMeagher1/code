source: [:0]const u8,
tree: Ast,
errors: std.MultiArrayList(Error),
code: Asm,

pub const Error = struct {
    tag: Tag,

    pub const Tag = enum {};
};

fn declRegister(cg: *CodeGen, decl_register: Ast.full.declRegister) !void {
    const tree = cg.tree;
    const code = cg.code;

    const main_tokens = tree.nodes.items(.main_token);

    const name_token = decl_register.ast.ident_token;
    const name_token_raw = tree.tokenSlice(name_token);

    const value = code.addScratch(.{
        .tag = .number,
        .data = .{
            .number = try parse.parse_hex(u16, tree.tokenSlice(main_tokens[decl_register.ast.value_node])),
        },
    });
    if (!code.registers.contains(name_token_raw)) {
        code.registers.put(name_token_raw, value);
    } else {
        @panic("TODO");
    }
}

fn move(cg: *CodeGen, node: Ast.Node.Index) !void {
    const tree = cg.tree;
    _ = node;
    _ = tree;
}

const CodeGen = @This();
const parse = @import("../common/parse.zig");
const instructions = @import("../common/instructions.zig");
const Ast = @import("./ast.zig");
const Asm = @import("./asm.zig");
const std = @import("std");
