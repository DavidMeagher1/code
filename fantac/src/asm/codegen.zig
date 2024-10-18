source: [:0]const u8,
tree: Ast,
errors: std.MultiArrayList(Error),
code: Asm,
scatch: std.ArrayListUnmanaged(Ast.Node.Index),

pub const Error = struct {
    tag: Tag,

    pub const Tag = enum {};
};

pub fn generate(cg: *CodeGen, ast: Ast) Asm {
    cg.source = ast.source;
}

fn declRegister(cg: *CodeGen, decl_register: Ast.full.declRegister) !void {
    const tree = cg.tree;
    const code = cg.code;

    const main_tokens = tree.nodes.items(.main_token);

    const name_token = decl_register.ast.ident_token;
    const name_token_raw = tree.tokenSlice(name_token);
    // need to chage this to evaluate an expression
    const value = code.addScratch(.{
        .tag = .number,
        .data = .{
            .number = try parse.parse_hex(u16, tree.tokenSlice(main_tokens[decl_register.ast.value_node])),
        },
    });
    if (!code.registers.contains(name_token_raw)) {
        code.registers.put(name_token_raw, value);
    } else {
        //10-17-2024 not sure what to do here REREAD CODE
        @panic("TODO");
    }
}

fn evalOperator(cg: *CodeGen, node: Ast.Node.Index) !u16 {
    //only evaluating numbers rn
    const tree = cg.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    var lval: u16 = 0;
    var rval: u16 = 0;
    const lhs = node_data[node].lhs;
    const rhs = node_data[node].rhs;
    switch (node_tags[lhs]) {
        .identifier => @panic("not evaluating idents yet"),
        .number_literal => {
            const number_str = tree.tokenSlice(main_tokens[lhs]);
            lval = try parse.parse_hex(u16, number_str);
        },
        else => {
            lval = try cg.evalOperator(lhs);
        },
    }
    if (rhs != 0) {
        switch (node_tags[rhs]) {
            .identifier => @panic("not evaluating idents yet"),
            .number_literal => {
                const number_str = tree.tokenSlice(main_tokens[rhs]);
                rval = try parse.parse_hex(u16, number_str);
            },
            else => {
                rval = try cg.evalOperator(rhs);
            },
        }
    }
    switch (node_tags[node]) {
        .op_add => return lval + rval,
        .op_band => return lval & rval,
        .op_bnot => return ~lval,
        .op_bor => return lval | rval,
        .op_bxor => return lval ^ rval,
        .op_div => return lval / rval,
        .op_mul => return lval * rval,
        .op_mod => return lval % rval,
        .op_shl => return @shlWithOverflow(lval, rval),
        .op_shr => return @shrExact(lval, rval), // might cause an error
        .op_sub => return lval + (~rval),
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
