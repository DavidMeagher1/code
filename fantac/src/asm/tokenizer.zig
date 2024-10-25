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
        .{ "hault", .hault },
        .{ "_", .nop },
        .{ "st", .store },
        .{ "ld", .load },
        .{ "pop", .pop },
        .{ "swp", .swap },
        .{ "ovr", .over },
        .{ "nip", .nip },
        .{ "rot", .rot },
        .{ "stash", .stash },
        .{ "unstash", .unstash },
    });

    pub fn getKeword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        eof,
        identifier,
        nop,
        hault,
        store,
        load,
        number_literal,
        pop,
        swap,
        over,
        nip,
        rot,
        plus,
        minus,
        asterisc,
        forward_slash,
        double_forward_slash,
        ampersand,
        bar,
        caret,
        double_lbracket,
        double_rbracket,
        equal,
        lbracket,
        rbracket,
        stash,
        unstash,
        bang,
        question_mark,
        bang_plus,
        bang_minus,
        bang_bang_plus,
        bang_bang_minus,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .eof,
                .number_literal,
                .nop,
                => null,
                .hault => "hault",
                .store => "st",
                .load => "ld",
                .pop => "pop",
                .swap => "swp",
                .over => "ovr",
                .nip => "nip",
                .rot => "rot",
                .plus => "+",
                .minus => "-",
                .asterisc => "*",
                .forward_slash => "/",
                .double_forward_slash => "//",
                .ampersand => "&",
                .bar => "|",
                .caret => "^",
                .double_lbracket => "<<",
                .double_rbracket => ">>",
                .equal => "=",
                .lbracket => "<",
                .rbracket => ">",
                .stash => "stash",
                .unstash => "ustash",
                .bang => "!",
                .question_mark => "?",
                .bang_plus => "!+",
                .bang_minus => "!-",
                .bang_bang_plus => "!!+",
                .bang_bang_minus => "!!-",
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
        saw_hash,
        saw_forward_slash,
        saw_lbracket,
        saw_rbracket,
        saw_bang,
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
                '#' => {
                    continue :state .saw_hash;
                },
                '<' => {
                    continue :state .saw_angle_bracket_l;
                },
                '>' => {
                    continue :state .saw_angle_bracket_r;
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
                '/' => {
                    continue :state .saw_forward_slash;
                },
                '|' => {
                    result.tag = .bar;
                    self.index += 1;
                },
                '=' => {
                    result.tag = .equal;
                    self.index += 1;
                },
                '!' => {
                    continue :state .saw_bang;
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
            .saw_hash => {
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
            .saw_forward_slash => {
                self.index += 1;
                switch(self.buffer[self.index]){
                    '/' => {
                        result.tag = .double_forward_slash;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .forward_slash;
                    }
                }
            }
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
                    else => {
                        result.tag = .angle_bracket_l;
                    },
                }
            },
            .saw_angle_bracket_r => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '>' => {
                        result.tag = .double_rbracket;
                        self.index += 1;
                    },
                    else => {
                        result.tag = .angle_bracket_r;
                    },
                }
            },
            .saw_bang => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '+' => {
                        result.tag = .bang_plus;
                        self.index += 1;
                    },
                    '-' => {
                        result.tag = .bang_minus;
                        self.index += 1;
                    },
                    '!' => {
                        self.index += 1;
                        switch (self.buffer[self.index]) {
                            '+' => {
                                result.tag = .bang_bang_plus;
                                self.index += 1;
                            },
                            '-' => {
                                result.tag = .bang_bang_minus;
                                self.index += 1;
                            },
                            else => {
                                result.tag = .invalid;
                            },
                        }
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
