pub const declRegister = struct {
    ast: Components,
    pub const Components = struct {
        ident_token: TokenIndex,
        value_node: Ast.Node.Index,
    };
};

pub const colonOp = struct {
    ast: Components,
    pub const Components = struct {
        expr_node: Ast.Node.Index,
    };
};

const Ast = @import("./ast.zig");
const TokenIndex = Ast.TokenIndex;
const Node = Ast.Node;
