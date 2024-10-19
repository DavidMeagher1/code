const std = @import("std");
const testing = std.testing;
const Lexer = @This();

pub const Location = struct {
    start: usize,
    end: usize,
};

pub const Token = struct {
    tag: Tag,
    loc: Location,

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "pc", .register_pc },
        .{ "sp", .register_sp },
        .{ "bp", .register_bp },
        .{ "acu", .register_acu },
        .{ "a", .register_a },
        .{ "b", .register_b },
        .{ "c", .register_c },
        .{ "d", .register_d },
        .{ "h", .register_h },
        .{ "l", .register_l },
        .{ "hl", .register_hl },
        .{ "_", .nop },
    });

    pub fn getKeword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        eof,
        nop,
        identifier,
        number_literal,
        colon,
        hash,
        at,
        backtick,
        equal,
        l_bracket,
        r_bracket,
        l_paren,
        r_paren,
        plus,
        minus,
        back_slash,
        forward_slash,
        mod,
        asterisk,
        ampersand,
        pipe,
        angle_bracket_l,
        angle_bracket_r,
        double_angle_bracket_l,
        double_angle_bracket_r,
        caret,
        tilde,
        period,
        bang,
        bang_equ,
        bang_angle_bracket_l,
        bang_angle_bracket_r,
        bang_plus,
        bang_minus,
        semi_colon,
        comma,
        angle_bracket_l_plus,
        angle_bracket_l_angle_brack_r,
        angle_bracket_l_caret_angle_bracket_r,
        angle_bracket_l_minus,
        angle_bracket_l_caret,
        plus_angle_bracket_r,
        caret_angle_bracket_r,

        //registers
        register_pc,
        register_sp,
        register_bp,
        register_acu,
        register_a,
        register_b,
        register_c,
        register_d,
        register_h,
        register_l,
        register_hl,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .eof,
                .number_literal,
                => null,

                .colon => ":",
                .equal => "=",
                .l_bracket => "[",
                .r_bracket => "]",
                .l_paren => "(",
                .r_paren => ")",
                .plus => "+",
                .minus => "-",
                .back_slash => "\\",
                .forward_slash => "/",
                .mod => "%",
                .asterisk => "*",
                .ampersand => "&",
                .pipe => "|",
                .angle_bracket_l => "<",
                .angle_bracket_r => ">",
                .double_angle_bracket_l => "<<",
                .double_angle_bracket_r => ">>",
                .caret => "^",
                .tilde => "~",
                .period => ".",
                .bang => "!",
                .bang_equ => "!=",
                .bang_angle_bracket_l => "!<",
                .bang_angle_bracket_r => "!>",

                //registers
                .register_pc => "pc",
                .register_sp => "sp",
                .register_bp => "bp",
                .register_acu => "acu",
                .register_a => "a",
                .register_b => "b",
                .register_c => "c",
                .register_d => "d",
                .register_h => "h",
                .register_l => "l",
                .register_hl => "hl",
                // builtins
                .builtin_import => "import",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
                .identifier => "an identifier",
                .number_literal => "a number literal",
                .eof => "EOF",
                .nop => "no op '_'",
                else => unreachable,
            };
        }
    };
};

pub const Tokenizer = struct {
    index: usize = 0,
    buffer: [:0]const u8,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    pub const State = enum {
        start,
        identifier,
        invalid,
        saw_dollar,
        saw_angle_bracket_l,
        saw_angle_bracket_r,
        saw_bang,
        saw_plus,
        saw_caret,
        number_literal,
    };

    pub fn next(self: *Tokenizer) Token {
        var result: Token = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };

        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    } else {
                        continue :state .invalid;
                    }
                },
                ' ', '\t', '\n', '\r' => {
                    //skip whitespace
                    self.index += 1;
                    result.loc.start = self.index;
                    continue :state .start;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    result.tag = .identifier;
                    continue :state .identifier;
                },
                '$' => {
                    continue :state .saw_dollar;
                },
                ':' => {
                    result.tag = .colon;
                    self.index += 1;
                },
                '[' => {
                    result.tag = .l_bracket;
                    self.index += 1;
                },
                ']' => {
                    result.tag = .r_bracket;
                    self.index += 1;
                },
                '(' => {
                    result.tag = .l_paren;
                    self.index += 1;
                },
                ')' => {
                    result.tag = .r_paren;
                    self.index += 1;
                },
                '<' => {
                    continue :state .saw_angle_bracket_l;
                },
                '>' => {
                    continue :state .saw_angle_bracket_r;
                },
                '+' => {
                    continue :state .saw_plus;
                },
                '-' => {
                    result.tag = .minus;
                    self.index += 1;
                },
                '*' => {
                    result.tag = .asterisk;
                    self.index += 1;
                },
                '&' => {
                    result.tag = .ampersand;
                    self.index += 1;
                },
                '^' => {
                    continue :state .saw_caret;
                },
                '%' => {
                    result.tag = .mod;
                    self.index += 1;
                },
                '\\' => {
                    result.tag = .back_slash;
                    self.index += 1;
                },
                '/' => {
                    result.tag = .forward_slash;
                    self.index += 1;
                },
                '.' => {
                    result.tag = .period;
                    self.index += 1;
                },
                '~' => {
                    result.tag = .tilde;
                    self.index += 1;
                },
                '|' => {
                    result.tag = .pipe;
                    self.index += 1;
                },
                '=' => {
                    result.tag = .equal;
                    self.index += 1;
                },
                '!' => {
                    continue :state .saw_bang;
                },
                '#' => {
                    result.tag = .hash;
                    self.index += 1;
                },
                '`' => {
                    result.tag = .backtick;
                    self.index += 1;
                },
                ',' => {
                    result.tag = .comma;
                    self.index += 1;
                },
                ';' => {
                    result.tag = .semi_colon;
                    self.index += 1;
                },
                '@' => {
                    result.tag = .at;
                    self.index += 1;
                },
                else => continue :state .invalid,
            },
            .identifier => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                    else => {
                        const ident = self.buffer[result.loc.start..self.index];
                        if (Token.getKeword(ident)) |tag| {
                            result.tag = tag;
                        }
                    },
                }
            },
            .saw_dollar => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'f', 'A'...'F', '0'...'9' => {
                        result.tag = .number_literal;
                        result.loc.start = self.index;
                        continue :state .number_literal;
                    },
                    0, '\n' => {
                        result.tag = .invalid;
                    },
                    else => {
                        continue :state .invalid;
                    },
                }
            },
            .number_literal => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'f', 'A'...'F', '0'...'9' => {
                        continue :state .number_literal;
                    },
                    else => {},
                }
            },
            .saw_angle_bracket_l => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '<' => {
                        result.tag = .double_angle_bracket_l;
                        self.index += 1;
                    },
                    '+' => {
                        result.tag = .angle_bracket_l_plus;
                        self.index += 1;
                    },
                    '-' => {
                        result.tag = .angle_bracket_l_minus;
                        self.index += 1;
                    },
                    '>' => {
                        result.tag = .angle_bracket_l_angle_brack_r;
                        self.index += 1;
                    },
                    '^' => {
                        self.index += 1;
                        switch (self.buffer[self.index]) {
                            '>' => {
                                result.tag = .angle_bracket_l_caret_angle_bracket_r;
                                self.index += 1;
                            },
                            else => {
                                result.tag = .angle_bracket_l_caret;
                                self.index += 1;
                            },
                        }
                    },
                    else => {
                        result.tag = .angle_bracket_l;
                    },
                }
            },
            .saw_angle_bracket_r => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '>' => {
                        result.tag = .double_angle_bracket_r;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .angle_bracket_r;
                    },
                }
            },
            .saw_plus => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '>' => {
                        result.tag = .plus_angle_bracket_r;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .plus;
                    },
                }
            },
            .saw_caret => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '>' => {
                        result.tag = .caret_angle_bracket_r;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .caret;
                    },
                }
            },
            .saw_bang => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .bang_equ;
                        self.index += 1;
                    },
                    '<' => {
                        result.tag = .bang_angle_bracket_l;
                        self.index += 1;
                    },
                    '>' => {
                        result.tag = .bang_angle_bracket_r;
                        self.index += 1;
                    },
                    '+' => {
                        result.tag = .bang_plus;
                        self.index += 1;
                    },
                    '-' => {
                        result.tag = .bang_minus;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .bang;
                    },
                }
            },
            .invalid => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    },
                    '\n' => result.tag = .invalid,
                    else => continue :state .invalid,
                }
            },
        }

        result.loc.end = self.index;
        return result;
    }
};

test "empty buffer is eof" {
    const buffer: [:0]const u8 = &[_:0]u8{};
    var tokenizer = Tokenizer.init(buffer);
    try testing.expectEqual(.eof, tokenizer.next().tag);
}

test "general ident" {
    const buffer: [:0]const u8 = &[_:0]u8{ 'A', 'b', 'c', '1' };
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    try testing.expectEqual(.identifier, token.tag);
}

test "keyword_mov" {
    const buffer: [:0]const u8 = &[_:0]u8{ ' ', ' ', ' ', '=' };
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    try testing.expectEqual(.equal, token.tag);
}

test "number_literal" {
    const buffer: [:0]const u8 = &[_:0]u8{ ' ', ' ', '$', 'a', '1', 'F' };
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    try testing.expectEqual(.number_literal, token.tag);
}

// test "tokenizing small file" {
//     const buffer =
//         \\
//         \\register r1 $1
//         \\register r2 $2
//         \\= $1234 r1
//         \\= r1 r2
//     ;
//     var tokenizer = Tokenizer.init(buffer);
//     var token_list: [128]Token = undefined;
//     var current_token: Token = undefined;
//     var index: usize = 0;
//     while (current_token.tag != .eof) {
//         current_token = tokenizer.next();
//         token_list[index] = current_token;
//         index += 1;
//     }
//     //std.debug.print("\n\n{any}\n\n", .{token_list[0..index]});
// }
