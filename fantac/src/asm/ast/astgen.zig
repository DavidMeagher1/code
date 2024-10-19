gpa: Allocator,
tree: *const Ast,
register_map: std.AutoHashMapUnmanaged([]const u8, u8),
instructions: std.MultiArrayList(Asm.Inst) = .{},
// scratch is used for keeping track of temporary data during gen, can be Node index or an instruction reference
scatch: std.ArrayListUnmanaged(u32) = .empty,

pub fn generate(gpa: Allocator, tree: Ast) Asm {
    const astgen = AstGen{
        .gpa = gpa,
        .tree = &tree,
    };
    defer astgen.deinit();

    return Asm{
        .instructions = astgen.instructions.toOwnedSlice(gpa),
    };
}

fn deinit(astgen: *AstGen, gpa: Allocator) void {
    astgen.instructions.deinit(gpa);
    astgen.scatch.deinit(gpa);
    astgen.register_map.deinit(gpa);
}
fn block(ga: *GenAsm, node: Ast.Node.Index) !Asm.Inst.Ref {}
fn declRegister(astgen: *AstGen, decl_register: Ast.full.declRegister) !void {
    const tree = astgen.tree;

    const main_tokens = tree.nodes.items(.main_token);

    const name_token = decl_register.ast.ident_token;
    const name_token_raw = tree.tokenSlice(name_token);
    // need to chage this to evaluate an expression
    const value = try parse.parse_hex(u16, tree.tokenSlice(main_tokens[decl_register.ast.value_node]));
    if (!astgen.register_map.contains(name_token_raw)) {
        astgen.register_map.put(name_token_raw, value);
    } else {
        // register has already been defined
        // also do i want defineable registers? might want to do something else for this
        @panic("TODO");
    }
}

fn evalOperator(astgen: *AstGen, node: Ast.Node.Index) !u16 {
    //only evaluating numbers rn
    const tree = astgen.tree;
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
            lval = try astgen.evalOperator(lhs);
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
                rval = try astgen.evalOperator(rhs);
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

fn move(astgen: *AstGen, node: Ast.Node.Index) !void {
    const tree = astgen.tree;
    _ = node;
    _ = tree;
}

const GenAsm = struct {};

const AstGen = @This();
//TODO should make common a root module
// will work on that after codegen
const parse = @import("../../common/parse.zig");
const Ast = @import("./ast.zig");
const Asm = @import("../asm.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
