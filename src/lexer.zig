const std = @import("std");
const Lexer = @This();
const Token = @import("token.zig");
const Location = @import("location.zig");

const State = enum {
    invalid,
    start,
    identifier,
    number,
    character,
    string,
    comment,
};

input: [:0]const u8,
position: u32 = 0,
line: u32 = 1,
column: u32 = 1,

pub fn next(self: *Lexer) Token {
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
    var comment_level: u32 = 0;
    state: switch (State.start) {
        .start => {
            switch (self.input[self.position]) {
                0 => {
                    token.tag = .eof;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    token.tag = .invalid;
                    continue :state .identifier;
                },
                '0'...'9', '-' => {
                    token.tag = .number_literal;
                    continue :state .number;
                },
                '"' => {
                    token.tag = .string_literal;
                    self.advance(); // skip the opening "
                    continue :state .string;
                },
                '\'' => {
                    token.tag = .character_literal;
                    self.advance(); // skip the '
                    continue :state .character;
                },
                '\n' => {
                    self.position += 1;
                    self.line += 1;
                    self.column = 1;
                    token.location.start_index = self.position;
                    token.location.start_line = self.line;
                    token.location.start_column = self.column;
                    continue :state .start;
                },
                ' ', '\t', '\r' => {
                    self.advance();
                    token.location.start_index = self.position;
                    token.location.start_line = self.line;
                    token.location.start_column = self.column;
                    continue :state .start;
                },
                '&' => {
                    token.tag = .local_label;
                    continue :state .identifier;
                },
                ':' => {
                    token.tag = .global_label;
                    continue :state .identifier;
                },
                '|' => {
                    if (self.peek()) |ch| {
                        if (std.ascii.isDigit(ch) or ch == '-') {
                            token.tag = .absolute_padding;
                            continue :state .number;
                        } else {
                            token.tag = .invalid;
                            continue :state .invalid;
                        }
                    } else {
                        token.tag = .invalid;
                        continue :state .invalid;
                    }
                },
                '$' => {
                    if (self.peek()) |ch| {
                        if (std.ascii.isDigit(ch) or ch == '-') {
                            token.tag = .relative_padding;
                            continue :state .number;
                        } else {
                            token.tag = .invalid;
                            continue :state .invalid;
                        }
                    } else {
                        token.tag = .invalid;
                        continue :state .invalid;
                    }
                },
                '(' => {
                    token.tag = .comment;
                    comment_level += 1;
                    continue :state .comment;
                },
                '@' => {
                    token.tag = .absolute_label_reference;
                    continue :state .identifier;
                },
                ';' => {
                    token.tag = .relative_label_reference;
                    continue :state .identifier;
                },
                '#' => {
                    token.tag = .hash;
                    self.advance();
                },
                '?' => {
                    token.tag = .question;
                    self.advance();
                },
                '!' => {
                    if (self.peek()) |ch| {
                        if (ch == '=') {
                            token.tag = .not_equal;
                            self.advance(); // consume '!'
                            self.advance(); // consume '='
                        } else {
                            token.tag = .exclamation;
                            self.advance(); // consume '!'
                        }
                    } else {
                        token.tag = .exclamation;
                        self.advance(); // consume '!' at EOF
                    }
                },
                '=' => {
                    if (self.peek()) |ch| {
                        if (ch == '=') {
                            token.tag = .equal_equal;
                            self.advance(); // consume '='
                            self.advance(); // consume '='
                        } else {
                            token.tag = .invalid; // single = not valid
                            self.advance(); // consume '='
                        }
                    } else {
                        token.tag = .invalid; // single = at EOF not valid
                        self.advance();
                    }
                },
                '<' => {
                    if (self.peek()) |ch| {
                        if (ch == '=') {
                            token.tag = .less_equal;
                            self.advance(); // consume '<'
                            self.advance(); // consume '='
                        } else {
                            token.tag = .less_than;
                            self.advance(); // consume '<'
                        }
                    } else {
                        token.tag = .less_than;
                        self.advance(); // consume '<' at EOF
                    }
                },
                '>' => {
                    if (self.peek()) |ch| {
                        if (ch == '=') {
                            token.tag = .greater_equal;
                            self.advance(); // consume '>'
                            self.advance(); // consume '='
                        } else {
                            token.tag = .greater_than;
                            self.advance(); // consume '>'
                        }
                    } else {
                        token.tag = .greater_than;
                        self.advance(); // consume '>' at EOF
                    }
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
                'b', 'w' => {
                    // suffix for size can be 'b' for byte or 'w' for word
                    self.advance();
                },
                '0'...'9', 'A'...'F' => continue :state .number,
                else => {},
            }
        },
        .identifier => {
            self.advance();
            switch (self.input[self.position]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => continue :state .identifier,
                else => {
                    // Check if it's a keyword
                    const lexeme = self.input[token.location.start_index..self.position];
                    if (Token.get_keyword(lexeme)) |kw_tag| {
                        token.tag = kw_tag;
                    }
                },
            }
        },
        .character => {
            switch (self.input[self.position]) {
                ' ', '\t', '\r', '\n', 0 => {
                    // Whitespace after ' is error
                    token.tag = .invalid;
                    continue :state .invalid;
                },
                else => {
                    // Successfully got one character
                    self.advance();
                },
            }
        },
        .string => {
            switch (self.input[self.position]) {
                ' ', '\t', '\r', '\n', 0 => {},
                else => {
                    self.advance();
                    continue :state .string;
                },
            }
        },
        .comment => {
            self.advance();
            switch (self.input[self.position]) {
                '(' => {
                    comment_level += 1;
                    continue :state .comment;
                },
                ')' => {
                    comment_level -= 1;
                    if (comment_level == 0) {
                        self.advance();
                    } else {
                        continue :state .comment;
                    }
                },
                0 => {},
                else => continue :state .comment,
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
    }

    self.finalize_token(&token);
    return token;
}

fn advance(self: *Lexer) void {
    if (self.position + 1 > self.input.len) return;
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
