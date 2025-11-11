const std = @import("std");
const Token = @This();
const Location = @import("location.zig");
const StaticStringMap = std.StaticStringMap;

pub const Tag = enum {
    invalid, // invalid token
    eof, // end of file
    identifier, // unqualified name eg: Foo
    qualified_identifier, // qualified name eg: Foo.Bar.Baz
    number_literal, // numeric literal eg: 42
    string_literal, // string literal eg: "Hello, World!"
    period,
    colon, // label definition
    colon_period, // label definition with period
    semicolon, // label terminator
    double_quote, // string delimiter
    single_quote, // character delimiter
    equal, // assignment
    bar, // absolute positioning
    dollar, // relative positioning
    plus, // addition
    minus, // subtraction
    asterisk, // multiplication
    slash, // division
    percent, // modulo
    less_than, // less than
    less_equal, // less than or equal to
    greater_than, // greater than
    greater_equal, // greater than or equal to
    double_equal, // equality
    not_equal, // inequality
    back_tick, // Symbol literal delimiter
    comma, // unknown
    lparen, // left parenthesis
    rparen, // right parenthesis
    lbracket, // left bracket
    rbracket, // right bracket
    lbrace, // left brace
    rbrace, // right brace
    ampersand, // bitwise AND
    caret, // bitwise XOR
    tilde, // bitwise NOT
    double_less_than, // bitwise left shift
    double_greater_than, // bitwise right shift
    double_bar, // logical OR
    double_ampersand, // logical AND
    exclamation, // logical NOT
    at, // special symbol
    hash, // push literal
    backslash, // line continuation
    question, // conditional

    // Add more token types as needed

    keyword_type,

    //keywords
    keyword_trap, // TRAP instruction
    keyword_restore, // RESTORE instruction
    keyword_halt, // HALT instruction
    keyword_noop, // NO OP instruction
    keyword_load, // LOAD instruction
    keyword_store, // STORE instruction
    keyword_drop, // DROP instruction
    keyword_dup, // DUP instruction
    keyword_swap, // SWAP instruction
    keyword_over, // OVER instruction
    keyword_rot, // ROT instruction
    keyword_nip, // NIP instruction
    keyword_pick, // PICK instruction
    keyword_roll, // ROLL instruction
    keyword_call, // CALL instruction
    keyword_return, // RETURN instruction
    keyword_jump, // Immediate JUMP instruction
    keyword_jump_if_not_zero, // JUMP_IF_NOT_ZERO instruction
};

const KeywordMap = StaticStringMap(Tag);
pub const keywords: KeywordMap = KeywordMap.initComptime(.{
    .{ "trap", .keyword_trap },
    .{ "halt", .keyword_halt },
    .{ "noop", .keyword_noop },
    .{ "load", .keyword_load },
    .{ "store", .keyword_store },
    .{ "drop", .keyword_drop },
    .{ "dup", .keyword_dup },
    .{ "swap", .keyword_swap },
    .{ "over", .keyword_over },
    .{ "rot", .keyword_rot },
    .{ "nip", .keyword_nip },
    .{ "pick", .keyword_pick },
    .{ "roll", .keyword_roll },
    .{ "call", .keyword_call },
    .{ "return", .keyword_return },
    .{ "restore", .keyword_restore },
    .{ "jmp", .keyword_jump },
    .{ "jnz", .keyword_jump_if_not_zero },
});

tag: Tag,
location: Location,

pub fn get_keyword(word: []const u8) ?Tag {
    return keywords.get(word);
}

pub fn lexeme(self: Token) ?[]const u8 {
    return switch (self.tag) {
        .identifier, .number_literal, .string_literal, .qualified_identifier => null,
        .period => ".",
        .colon => ":",
        .semicolon => ";",
        .double_quote => "\"",
        .single_quote => "'",
        .equal => "=",
        .bar => "|",
        .dollar => "$",
        .plus => "+",
        .minus => "-",
        .asterisk => "*",
        .slash => "/",
        .percent => "%",
        .less_than => "<",
        .less_equal => "<=",
        .greater_than => ">",
        .greater_equal => ">=",
        .double_equal => "==",
        .not_equal => "!=",
        .back_tick => "`",
        .comma => ",",
        .lparen => "(",
        .rparen => ")",
        .lbracket => "[",
        .rbracket => "]",
        .lbrace => "{",
        .rbrace => "}",
        .ampersand => "&",
        .caret => "^",
        .tilde => "~",
        .double_less_than => "<<",
        .double_greater_than => ">>",
        .double_bar => "||",
        .double_ampersand => "&&",
        .exclamation => "!",
        .at => "@",
        .hash => "#",
        .backslash => "\\",
        .question => "?",

        .keyword_trap => "trap",
        .keyword_restore => "restore",
        .keyword_halt => "halt",
        .keyword_noop => "noop",
        .keyword_load => "load",
        .keyword_store => "store",
        .keyword_drop => "drop",
        .keyword_dup => "dup",
        .keyword_swap => "swap",
        .keyword_over => "over",
        .keyword_rot => "rot",
        .keyword_nip => "nip",
        .keyword_pick => "pick",
        .keyword_roll => "roll",
        .keyword_call => "call",
        .keyword_return => "return",
    };
}

pub fn symbol(self: Token) []const u8 {
    return self.lexeme() orelse switch (self.tag) {
        .invalid => "an Invalid Token",
        .identifier => "an Identifier",
        .number_literal => "a Number Literal",
        .string_literal => "a String Literal",
        .qualified_identifier => "a Qualified Identifier",
    };
}
