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
        .{ "register", .keyword_register },
        .{ "jmp", .keyword_jmp },
        .{ "jeq", .keyword_jeq },
        .{ "jlt", .keyword_jlt },
        .{ "jgt", .keyword_jgt },
        .{ "pop", .keyword_pop },
        .{ "psh", .keyword_psh },
    });

    pub fn getKeword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        eof,
        identifier,
        number_literal,
        colon,
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
        caret,
        tilde,
        period,

        //keywords
        keyword_register,
        keyword_jmp,
        keyword_jeq,
        keyword_jlt,
        keyword_jgt,
        keyword_pop,
        keyword_psh,

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
                .caret => "^",
                .tilde => "~",
                .period => ".",
                .keyword_register => "register",
                .keyword_jmp => "jmp",
                .keyword_jeq => "jeq",
                .keyword_jgt => "jgt",
                .keyword_jlt => "jlt",
                .keyword_pop => "pop",
                .keyword_psh => "psh",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
                .identifier => "an identifier",
                .number_literal => "a number literal",
                .eof => "EOF",
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
                    result.tag = .angle_bracket_l;
                    self.index += 1;
                },
                '>' => {
                    result.tag = .angle_bracket_r;
                    self.index += 1;
                },
                '+' => {
                    result.tag = .plus;
                    self.index += 1;
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
                    result.tag = .caret;
                    self.index += 1;
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
