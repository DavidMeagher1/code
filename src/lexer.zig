const Lexer = @This();
const Token = @import("token.zig");
const Location = @import("location.zig");

const State = enum {
    invalid,
    start,
    identifier,
    qualified_dot,
    qualified_identifier,
    number,
    string,
};

input: [:0]const u8,
position: u32 = 0,
line: u32 = 1,
column: u32 = 1,

pub fn next(self: *Lexer) ?Token {
    var token = Token{
        .tag = .invalid,
        .location = Location{
            .start_index = self.position,
            .end_index = self.position,
            .start_column = self.column,
            .start_line = self.line,
            .end_column = self.column,
            .end_line = self.line,
        },
    };
    state: switch (State.start) {
        .start => {
            switch (self.input[self.position]) {
                0 => {
                    token.tag = .eof;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    token.tag = .identifier;
                    continue :state .identifier;
                },
                '0'...'9' => {
                    token.tag = .number_literal;
                    continue :state .number;
                },
                '"' => {
                    token.tag = .string_literal;
                    continue :state .string;
                },
                '\n' => {
                    self.position += 1;
                    self.line += 1;
                    self.column = 1;
                    continue :state .start;
                },
                ' ', '\t', '\r' => {
                    self.advance();
                    continue :state .start;
                },
                '.' => {
                    token.tag = .period;
                    self.advance();
                },
                ':' => {
                    token.tag = .colon;
                    if (self.peek()) |c| {
                        if (c == '.') {
                            self.advance();
                            token.tag = .colon_period;
                        }
                    }
                    self.advance();
                },
                ';' => {
                    token.tag = .semicolon;
                    self.advance();
                },
                '=' => {
                    token.tag = .equal;
                    self.advance();
                },
                '|' => {
                    token.tag = .bar;
                    if (self.peek()) |c| {
                        if (c == '|') {
                            self.advance();
                            token.tag = .double_bar;
                        }
                    }
                    self.advance();
                },
                '$' => {
                    token.tag = .dollar;
                    self.advance();
                },
                '+' => {
                    token.tag = .plus;
                    self.advance();
                },
                '-' => {
                    token.tag = .minus;
                    self.advance();
                },
                '*' => {
                    token.tag = .asterisk;
                    self.advance();
                },
                '/' => {
                    token.tag = .slash;
                    self.advance();
                },
                '%' => {
                    token.tag = .percent;
                    self.advance();
                },
                '<' => {
                    token.tag = .less_than;
                    if (self.peek()) |c| {
                        if (c == '=') {
                            self.advance();
                            token.tag = .less_equal;
                        } else if (c == '<') {
                            self.advance();
                            token.tag = .double_less_than;
                        }
                    }
                    self.advance();
                },
                '>' => {
                    token.tag = .greater_than;
                    if (self.peek()) |c| {
                        if (c == '=') {
                            self.advance();
                            token.tag = .greater_equal;
                        } else if (c == '>') {
                            self.advance();
                            token.tag = .double_greater_than;
                        }
                    }
                    self.advance();
                },
                '!' => {
                    token.tag = .exclamation;
                    if (self.peek()) |c| {
                        if (c == '=') {
                            self.advance();
                            token.tag = .not_equal;
                        }
                    }
                    self.advance();
                },
                '&' => {
                    token.tag = .ampersand;
                    if (self.peek()) |c| {
                        if (c == '&') {
                            self.advance();
                            token.tag = .double_ampersand;
                        }
                    }
                    self.advance();
                },
                '^' => {
                    token.tag = .caret;
                    self.advance();
                },
                '~' => {
                    token.tag = .tilde;
                    self.advance();
                },
                '`' => {
                    token.tag = .back_tick;
                    self.advance();
                },
                ',' => {
                    token.tag = .comma;
                    self.advance();
                },
                '(' => {
                    token.tag = .lparen;
                    self.advance();
                },
                ')' => {
                    token.tag = .rparen;
                    self.advance();
                },
                '[' => {
                    token.tag = .lbracket;
                    self.advance();
                },
                ']' => {
                    token.tag = .rbracket;
                    self.advance();
                },
                '{' => {
                    token.tag = .lbrace;
                    self.advance();
                },
                '}' => {
                    token.tag = .rbrace;
                    self.advance();
                },
                '@' => {
                    token.tag = .at;
                    self.advance();
                },
                '#' => {
                    token.tag = .hash;
                    self.advance();
                },
                '\\' => {
                    token.tag = .backslash;
                    self.advance();
                },
                '?' => {
                    token.tag = .question;
                    self.advance();
                },
                else => {
                    // Handle other single-character tokens
                    token.tag = .invalid;
                    continue :state .invalid;
                },
            }
        },
        .number => {
            self.advance();
            switch (self.input[self.position]) {
                '0'...'9', 'a'...'f', 'A'...'F' => continue :state .number,
                else => {},
            }
        },
        .identifier => {
            self.advance();
            switch (self.input[self.position]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => continue :state .identifier,
                '.' => {
                    continue :state .qualified_dot;
                },
                else => {},
            }
        },
        .qualified_dot => {
            self.advance();
            switch (self.input[self.position]) {
                'a'...'z', 'A'...'Z', '_' => {
                    token.tag = .qualified_identifier;
                    continue :state .qualified_identifier;
                },
                else => {
                    // Invalid token after dot
                    token.tag = .invalid;
                    continue :state .invalid;
                },
            }
        },
        .qualified_identifier => {
            self.advance();
            switch (self.input[self.position]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => continue :state .qualified_identifier,
                '.' => {
                    continue :state .qualified_dot;
                },
                else => {},
            }
        },
        .string => {
            self.advance();
            switch (self.input[self.position]) {
                '"' => {
                    self.advance();
                },
                0 => {
                    token.tag = .invalid;
                    continue :state .invalid;
                },
                else => continue :state .string,
            }
        },
        .invalid => {
            // go to new line or eof and return invalid token
            self.advance();
            switch (self.input[self.position]) {
                '\n', 0 => {},
                else => {
                    continue :state .invalid;
                },
            }
        },
        else => unreachable,
    }
    self.finalize_token(&token);
    return token;
}

fn advance(self: *Lexer) void {
    if (self.position + 1 >= self.input.len) return;
    self.position += 1;
    self.column += 1;
}

fn peek(self: *Lexer) ?u8 {
    if (self.position + 1 >= self.input.len) return null;
    return self.input[self.position + 1];
}

fn finalize_token(self: Lexer, token: *Token) void {
    token.location.end_index = self.position;
    token.location.end_line = self.line;
    token.location.end_column = self.column;
}

pub fn reset(self: *Lexer) void {
    self.position = 0;
}
