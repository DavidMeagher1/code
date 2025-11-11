const std = @import("std");
const Node = @This();
const Token = @import("token.zig");
const index = @import("index.zig");
const Lexer = @import("lexer.zig");
const Span = @import("span.zig");

pub const Tag = enum {
    // basic nodes
    // invalid node
    invalid,
    // root node
    root,
    // number literal eg: 42
    number_literal,
    // string literal eg: "Hello, World!"
    string_literal,
    // floating literal eg: 3.14
    floating_literal,
    // symbol literal eg: Foo
    identifier,
    // qualified identifier eg: Foo.Bar.Baz
    qualified_identifier,
    // symbol literal eg: `Foo or `Foo.Bar.Baz
    symbol_literal,
    // symbol as string literal eg: ,Foo which is equivalent to "Foo"
    symbol_string_literal,

    // definition nodes
    // word definition eg: :WORD #42 drop ;
    word_definition,
    // word reference eg: WORD
    word_reference,
    // constant definition eg: = CONST 42 ;
    constant_definition,
    // constant reference eg: CONST
    constant_reference,
    // label definition eg: ::LABEL
    label_definition,
    // label reference eg: LABEL
    label_reference,
    // local label definition eg: :.LOCAL_LABEL
    local_label_definition,
    // local label reference eg: .LOCAL_LABEL
    local_label_reference,

    // type nodes
    // type definition eg: :type MyType { ... } ;
    type_definition,
    // type reference eg: MyType
    type_reference,

    // math operators
    // addition operator eg: 1 2 +
    add,
    // subtraction operator eg: 1 2 -
    subtract,
    // multiplication operator eg: 1 2 *
    multiply,
    // division operator eg: 1 2 /
    divide,
    // modulo operator eg: 1 2 %
    modulo,

    // comparison operators
    // equality operator eg: 1 2 ==
    equal_equal,
    // inequality operator eg: 1 2 !=
    not_equal,
    // less than operator eg: 1 2 <
    less_than,
    // less than or equal to operator eg: 1 2 <=
    less_equal,
    // greater than operator eg: 1 2 >
    greater_than,
    // greater than or equal to operator eg: 1 2 >=
    greater_equal,
    // logical operators
    // and operator eg: true false &&
    @"and",
    // or operator eg: true false ||
    @"or",
    // not operator eg: true !
    not,
    // bitwise operators
    // and operator eg: 1 2 &
    bit_and,
    // or operator eg: 1 2 |
    bit_or,
    // xor operator eg: 1 2 ^
    bit_xor,
    // not operator eg: 1 2 ~
    bit_not,
    // shift left operator eg: 1 2 <<
    shift_left,
    // shift right operator eg: 1 2 >>
    shift_right,

    // control flow
    // call instruction eg: word_name call
    call,
    // return instruction eg: return
    @"return",
    // jump instruction eg: jmp LABEL or jmp .LOCAL_LABEL or jmp word_name all immediate jumps
    jump,
    // jump if not zero instruction eg: jnz LABEL or jnz .LOCAL_LABEL or jnz word_name all runtime jumps
    jump_if_not_zero,
    // trap instruction eg: trap calls the trap handler
    trap,
    // restore instruction eg: restore the previous state after a trap
    restore,
    // noop instruction eg: noop does nothing
    noop,
    // halt instruction eg: halt stops execution
    halt,
};

pub const TokenIndex = index.Absolute;
pub const NodeIndex = index.Absolute;
pub const OptionalTokenIndex = index.Optional;
pub const OptionalNodeIndex = index.Optional;
pub const TokenOffset = index.Offset;
pub const NodeOffset = index.Offset;

pub const Data = union {
    none: void,
    node: NodeIndex,
    token: TokenIndex,
    span: Span,
    node_and_node: struct { NodeIndex, NodeIndex },
    token_and_token: struct { TokenIndex, TokenIndex },
    node_and_token: struct { NodeIndex, TokenIndex },
    token_and_node: struct { TokenIndex, NodeIndex },
};

tag: Tag,
main_token: Token,
data: Data,
