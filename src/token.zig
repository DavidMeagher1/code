//! Token definitions for the Forth-like language lexer.
//!
//! Design Decisions:
//! -----------------
//! 1. Syntactic Sugar for Common Operations:
//!    - `#` for PUSH: Compiler infers PUSH1 vs PUSH2 from value size or b/w suffix
//!      Examples: `# 42` → PUSH1, `# FFFF` → PUSH2, `# 42w` → PUSH2
//!    - `!` for JMP: Compiler determines JMPS vs JMPL from immediate size
//!    - `?` for JNZ: Compiler determines JNZS vs JNZL from immediate size
//!
//! 2. Comparison Operators as Tokens:
//!    - `==`, `!=`, `<`, `>`, `<=`, `>=` emit CMPR opcode with appropriate immediate
//!    - More readable than `cmpr ==` keyword approach
//!    - Immediate values: == (0x00), != (0x01), < (0x02), > (0x03), <= (0x04), >= (0x05)
//!
//! 3. No `invalid` Keyword:
//!    - INVALID opcode (0x00) represents uninitialized memory, not user-writable code
//!    - VM crashes on 0x00, useful for detecting uninitialized jumps
//!
//! 4. Size Inference Philosophy:
//!    - Compiler determines operation size from operands when possible
//!    - Reduces verbosity while maintaining explicit control via suffixes
//!    - Byte operations are the default (no suffix), word operations use 'w' suffix
//!    - Examples: `# 42` (auto-byte), `# 42w` (explicit word), `! @label` (auto from offset)
//!    - Opcode keywords: All uppercase to denote reserved words
//!      `DROP` (byte), `DROPW` (word), `ADD` (byte), `ADDW` (word), etc.

const std = @import("std");
const Token = @This();
const Location = @import("location.zig");
const StaticStringMap = std.StaticStringMap;

pub const Tag = enum {
    invalid, // invalid token
    eof, // end of file

    // Literals
    number_literal, // numeric literal eg: 42, 42b, -1w
    string_literal, // string literal eg: "Hello
    character_literal, // character literal eg: 'A

    // Comments
    comment, // ( comment )

    // Symbols
    global_label, // : global label definition
    local_label, // & local label definition
    absolute_label_reference, // @ label reference
    relative_label_reference, // ; label reference
    absolute_padding, // |number absolute padding
    relative_padding, // $number relative padding
    hash, // # push (size determined by value/suffix)
    exclamation, // ! jmp (size determined by immediate)
    question, // ? jnz (size determined by immediate)

    // Comparison operators
    equal_equal, // == (emits CMPR 0x00)
    not_equal, // != (emits CMPR 0x01)
    less_than, // < (emits CMPR 0x02)
    greater_than, // > (emits CMPR 0x03)
    less_equal, // <= (emits CMPR 0x04)
    greater_equal, // >= (emits CMPR 0x05)

    // Keywords - System/Traps
    keyword_nop,
    keyword_halt,
    keyword_trap,

    // Keywords - Control Flow
    keyword_hops,
    keyword_hopl,
    keyword_calls,
    keyword_calll,
    keyword_rets,
    keyword_retl,

    // Keywords - Stack Manipulation
    keyword_drop,
    keyword_dropw,
    keyword_dup,
    keyword_dupw,
    keyword_swap,
    keyword_swapw,
    keyword_nip,
    keyword_nipw,
    keyword_over,
    keyword_overw,
    keyword_rot,
    keyword_rotw,
    keyword_pick,
    keyword_pickw,
    keyword_poke,
    keyword_pokew,

    // Keywords - Arithmetic
    keyword_add,
    keyword_addw,
    keyword_sub,
    keyword_subw,
    keyword_mul,
    keyword_mulw,
    keyword_div,
    keyword_divw,
    keyword_mod,
    keyword_modw,
    keyword_neg,
    keyword_negw,
    keyword_abs,
    keyword_absw,
    keyword_inc,
    keyword_incw,
    keyword_dec,
    keyword_decw,

    // Keywords - Bitwise
    keyword_and,
    keyword_andw,
    keyword_or,
    keyword_orw,
    keyword_not,
    keyword_notw,
    keyword_xor,
    keyword_xorw,
    keyword_shl,
    keyword_shlw,
    keyword_shr,
    keyword_shrw,
    keyword_rol,
    keyword_rolw,
    keyword_ror,
    keyword_rorw,

    // Keywords - Memory Access
    keyword_load,
    keyword_loadw,
    keyword_store,
    keyword_storew,
    keyword_iload,
    keyword_iloadw,
    keyword_istore,
    keyword_istorew,
    keyword_memcpy,
    keyword_memcpyw,
    keyword_memset,
    keyword_memsetw,
};

const KeywordMap = StaticStringMap(Tag);
pub const keywords: KeywordMap = KeywordMap.initComptime(.{
    // System/Traps
    .{ "NOP", .keyword_nop },
    .{ "HALT", .keyword_halt },
    .{ "TRAP", .keyword_trap },

    // Control Flow
    .{ "HOPS", .keyword_hops },
    .{ "HOPL", .keyword_hopl },
    .{ "CALLS", .keyword_calls },
    .{ "CALLL", .keyword_calll },
    .{ "RETS", .keyword_rets },
    .{ "RETL", .keyword_retl },

    // Stack Manipulation
    .{ "DROP", .keyword_drop },
    .{ "DROPW", .keyword_dropw },
    .{ "DUP", .keyword_dup },
    .{ "DUPW", .keyword_dupw },
    .{ "SWAP", .keyword_swap },
    .{ "SWAPW", .keyword_swapw },
    .{ "NIP", .keyword_nip },
    .{ "NIPW", .keyword_nipw },
    .{ "OVER", .keyword_over },
    .{ "OVERW", .keyword_overw },
    .{ "ROT", .keyword_rot },
    .{ "ROTW", .keyword_rotw },
    .{ "PICK", .keyword_pick },
    .{ "PICKW", .keyword_pickw },
    .{ "POKE", .keyword_poke },
    .{ "POKEW", .keyword_pokew },

    // Arithmetic
    .{ "ADD", .keyword_add },
    .{ "ADDW", .keyword_addw },
    .{ "SUB", .keyword_sub },
    .{ "SUBW", .keyword_subw },
    .{ "MUL", .keyword_mul },
    .{ "MULW", .keyword_mulw },
    .{ "DIV", .keyword_div },
    .{ "DIVW", .keyword_divw },
    .{ "MOD", .keyword_mod },
    .{ "MODW", .keyword_modw },
    .{ "NEG", .keyword_neg },
    .{ "NEGW", .keyword_negw },
    .{ "ABS", .keyword_abs },
    .{ "ABSW", .keyword_absw },
    .{ "INC", .keyword_inc },
    .{ "INCW", .keyword_incw },
    .{ "DEC", .keyword_dec },
    .{ "DECW", .keyword_decw },

    // Bitwise
    .{ "AND", .keyword_and },
    .{ "ANDW", .keyword_andw },
    .{ "OR", .keyword_or },
    .{ "ORW", .keyword_orw },
    .{ "NOT", .keyword_not },
    .{ "NOTW", .keyword_notw },
    .{ "XOR", .keyword_xor },
    .{ "XORW", .keyword_xorw },
    .{ "SHL", .keyword_shl },
    .{ "SHLW", .keyword_shlw },
    .{ "SHR", .keyword_shr },
    .{ "SHRW", .keyword_shrw },
    .{ "ROL", .keyword_rol },
    .{ "ROLW", .keyword_rolw },
    .{ "ROR", .keyword_ror },
    .{ "RORW", .keyword_rorw },

    // Memory Access
    .{ "LOAD", .keyword_load },
    .{ "LOADW", .keyword_loadw },
    .{ "STORE", .keyword_store },
    .{ "STOREW", .keyword_storew },
    .{ "ILOAD", .keyword_iload },
    .{ "ILOADW", .keyword_iloadw },
    .{ "ISTORE", .keyword_istore },
    .{ "ISTOREW", .keyword_istorew },
    .{ "MEMCPY", .keyword_memcpy },
    .{ "MEMCPYW", .keyword_memcpyw },
    .{ "MEMSET", .keyword_memset },
    .{ "MEMSETW", .keyword_memsetw },
});

tag: Tag,
location: Location,

pub fn get_keyword(word: []const u8) ?Tag {
    return keywords.get(word);
}

pub fn lexeme(self: Token) ?[]const u8 {
    return switch (self.tag) {
        .number_literal, .string_literal, .character_literal, .global_label, .local_label, .absolute_label_reference, .relative_label_reference, .absolute_padding, .relative_padding => null,
        .comment => null,
        .hash => "#",
        .exclamation => "!",
        .question => "?",

        .equal_equal => "==",
        .not_equal => "!=",
        .less_than => "<",
        .greater_than => ">",
        .less_equal => "<=",
        .greater_equal => ">=",

        .keyword_nop => "NOP",
        .keyword_halt => "HALT",
        .keyword_trap => "TRAP",

        .keyword_hops => "HOPS",
        .keyword_hopl => "HOPL",
        .keyword_calls => "CALLS",
        .keyword_calll => "CALLL",
        .keyword_rets => "RETS",
        .keyword_retl => "RETL",

        .keyword_drop => "DROP",
        .keyword_dropw => "DROPW",
        .keyword_dup => "DUP",
        .keyword_dupw => "DUPW",
        .keyword_swap => "SWAP",
        .keyword_swapw => "SWAPW",
        .keyword_nip => "NIP",
        .keyword_nipw => "NIPW",
        .keyword_over => "OVER",
        .keyword_overw => "OVERW",
        .keyword_rot => "ROT",
        .keyword_rotw => "ROTW",
        .keyword_pick => "PICK",
        .keyword_pickw => "PICKW",
        .keyword_poke => "POKE",
        .keyword_pokew => "POKEW",

        .keyword_add => "ADD",
        .keyword_addw => "ADDW",
        .keyword_sub => "SUB",
        .keyword_subw => "SUBW",
        .keyword_mul => "MUL",
        .keyword_mulw => "MULW",
        .keyword_div => "DIV",
        .keyword_divw => "DIVW",
        .keyword_mod => "MOD",
        .keyword_modw => "MODW",
        .keyword_neg => "NEG",
        .keyword_negw => "NEGW",
        .keyword_abs => "ABS",
        .keyword_absw => "ABSW",
        .keyword_inc => "INC",
        .keyword_incw => "INCW",
        .keyword_dec => "DEC",
        .keyword_decw => "DECW",

        .keyword_and => "AND",
        .keyword_andw => "ANDW",
        .keyword_or => "OR",
        .keyword_orw => "ORW",
        .keyword_not => "NOT",
        .keyword_notw => "NOTW",
        .keyword_xor => "XOR",
        .keyword_xorw => "XORW",
        .keyword_shl => "SHL",
        .keyword_shlw => "SHLW",
        .keyword_shr => "SHR",
        .keyword_shrw => "SHRW",
        .keyword_rol => "ROL",
        .keyword_rolw => "ROLW",
        .keyword_ror => "ROR",
        .keyword_rorw => "RORW",

        .keyword_load => "LOAD",
        .keyword_loadw => "LOADW",
        .keyword_store => "STORE",
        .keyword_storew => "STOREW",
        .keyword_iload => "ILOAD",
        .keyword_iloadw => "ILOADW",
        .keyword_istore => "ISTORE",
        .keyword_istorew => "ISTOREW",
        .keyword_memcpy => "MEMCPY",
        .keyword_memcpyw => "MEMCPYW",
        .keyword_memset => "MEMSET",
        .keyword_memsetw => "MEMSETW",

        .invalid, .eof => null,
    };
}

pub fn symbol(self: Token) []const u8 {
    return self.lexeme() orelse switch (self.tag) {
        .invalid => "an Invalid Token",
        .eof => "End of File",
        .number_literal => "a Number Literal",
        .string_literal => "a String Literal",
        .character_literal => "a Character Literal",
        .comment => "a Comment",
        .global_label => "a Global Label",
        .local_label => "a Local Label",
        .absolute_label_reference => "an Absolute Label Reference",
        .relative_label_reference => "a Relative Label Reference",
        .absolute_padding => "Absolute Padding",
        .relative_padding => "Relative Padding",
    };
}
