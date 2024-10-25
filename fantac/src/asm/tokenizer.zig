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
        .{ "jmp", .jmp },
        .{ "jmc", .jmc },
        .{ "jsr", .jsr },
        .{ "rsr", .rsr },
        .{ "jsi", .jsi },
        .{ "ri", .ri },
        // 8bit
        .{ "st", .store },
        .{ "ld", .load },
        .{ "pop", .pop },
        .{ "swp", .swap },
        .{ "ovr", .over },
        .{ "nip", .nip },
        .{ "rot", .rot },
        .{ "stash", .stash },
        .{ "unstash", .unstash },
        .{ "add", .add },
        .{ "sub", .sub },
        .{ "mul", .mul },
        .{ "div", .div },
        .{ "rem", .rem },
        .{ "and", .@"and" },
        .{ "or", .@"or" },
        .{ "xor", .xor },
        .{ "shl", .shl },
        .{ "shr", .shr },
        .{ "equ", .equ },
        .{ "lth", .lth },
        .{ "gth", .gth },

        // 16 bit
        .{ "st2", .store2 },
        .{ "ld2", .load2 },
        .{ "pop2", .pop2 },
        .{ "swp2", .swap2 },
        .{ "ovr2", .over2 },
        .{ "nip2", .nip2 },
        .{ "rot2", .rot2 },
        .{ "stash2", .stash2 },
        .{ "unstash2", .unstash2 },
        .{ "add2", .add2 },
        .{ "sub2", .sub2 },
        .{ "mul2", .mul2 },
        .{ "div2", .div2 },
        .{ "rem2", .rem2 },
        .{ "and2", .and2 },
        .{ "or2", .or2 },
        .{ "xor2", .xor2 },
        .{ "shl2", .shl2 },
        .{ "shr2", .shr2 },
        .{ "equ2", .equ2 },
        .{ "lth2", .lth2 },
        .{ "gth2", .gth2 },
    });

    pub fn getKeword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        eof,
        identifier,
        literal,
        immediate_literal,
        absolute_padding,
        relative_padding,
        nop,
        hault,
        colon,
        period,
        bang,
        single_quote,

        jmp,
        jmc,
        jsr,
        rsr,
        jsi,
        ri,
        //8bit
        store,
        load,
        pop,
        swap,
        over,
        nip,
        rot,
        add,
        sub,
        mul,
        div,
        rem,
        @"and",
        @"or",
        xor,
        shl,
        shr,
        equal,
        lth,
        rth,
        stash,
        unstash,

        //16 bit
        store2,
        load2,
        pop2,
        swap2,
        over2,
        nip2,
        rot2,
        add2,
        sub2,
        mul2,
        div2,
        rem2,
        and2,
        or2,
        xor2,
        shl2,
        shr2,
        equal2,
        lth2,
        rth2,
        stash2,
        unstash2,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .eof,
                .immediate_literal,
                .literal,
                .absolute_padding,
                .relative_padding,
                .nop,
                => null,

                .colon => ":",
                .bang => "!",
                .period => ".",
                .jmp => "jmp",
                .jmc => "jmc",
                .jsr => "jsr",
                .rsr => "rsr",
                .jsi => "jsi",
                .ri => "ri",
                .hault => "hault",
                //8bit
                .store => "st",
                .load => "ld",
                .pop => "pop",
                .swap => "swp",
                .over => "ovr",
                .nip => "nip",
                .rot => "rot",
                .add => "add",
                .sub => "sub",
                .mul => "mul",
                .div => "div",
                .rem => "rem",
                .@"and" => "and",
                .@"or" => "or",
                .xor => "xor",
                .shl => "shl",
                .shr => "shr",
                .equal => "equ",
                .lth => "lth",
                .gth => "gth",
                .stash => "stash",
                .unstash => "ustash",

                //16 bit
                .store2 => "st2",
                .load2 => "ld2",
                .pop2 => "pop2",
                .swap2 => "swp2",
                .over2 => "ovr2",
                .nip2 => "nip2",
                .rot2 => "rot2",
                .add2 => "add2",
                .sub2 => "sub2",
                .mul2 => "mul2",
                .div2 => "div2",
                .rem2 => "rem2",
                .and2 => "and2",
                .or2 => "or2",
                .xor2 => "xor2",
                .shl2 => "shl2",
                .shr2 => "shr2",
                .equal2 => "equ2",
                .lth2 => "lth2",
                .gth2 => "gth2",
                .stash2 => "stash2",
                .unstash2 => "ustash2",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
                .identifier => "an identifier",
                .immediate_literal => "an immediate literal",
                .literal => "a literal",
                .absolute_padding => "absolute padding marker '%'",
                .relative_padding => "relative padding marker '$'",
                .eof => "EOF",
                .nop => "no op '_'",
                else => unreachable,
            };
        }
    };
};

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
    literal,
    immediate_literal,
    saw_single_quote,
    saw_grapes,
    saw_dollar,
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
            '&' => {
                continue :state .saw_ampersand;
            },
            '!' => {
                result.tag = .bang;
                self.index += 1;
            },
            '.' => {
                result.tag = .period;
                self.index += 1;
            },
            ':' => {
                result.tag = .colon;
                self.index += 1;
            },
            '%' => {
                continue :state .saw_grapes;
            },
            '$' => {
                continue :state .saw_dollar;
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
                    result.tag = .literal;
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
        .saw_ampersand => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                'a'...'f', 'A'...'F', '0'...'9' => {
                    result.tag = .immediate_literal;
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
        .saw_grapes => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                'a'...'f', 'A'...'F', '0'...'9' => {
                    result.tag = .absolute_padding;
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
        .saw_dollar => {
            self.index += 1;
            switch (self.buffer[self.index]) {
                'a'...'f', 'A'...'F', '0'...'9' => {
                    result.tag = .relatve_padding;
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

const std = @import("std");
const testing = std.testing;
const Tokenizer = @This();
