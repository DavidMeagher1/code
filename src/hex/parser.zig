const std = @import("std");
const testing = std.testing;

const Error = error{
    NotHex,
};
//Bounds
const Zero: u8 = '0';
const Nine: u8 = '9';
const A: u8 = 'A';
const F: u8 = 'F';

// Digits list
const digits: [16]u8 = .{ Zero, '1', '2', '3', '4', '5', '6', '7', '8', Nine, A, 'B', 'C', 'D', 'E', F };

const lowercase_adujstment: u8 = 'a' - 'A';

pub fn is_numeric(char: u8) bool {
    return char >= Zero and char <= Nine;
}

pub fn is_alphabetic(char: u8) bool {
    return (char >= A and char <= F) or (char >= A + lowercase_adujstment and char <= F + lowercase_adujstment);
}

pub fn is_hex(char: u8) bool {
    return is_numeric(char) or is_alphabetic(char);
}

pub fn is_lowercase(char: u8) bool {
    if (is_alphabetic(char)) {
        return char > F;
    }
    return false;
}

pub fn parse_hex_char(comptime T: type, char: u8) Error!T {
    var working_char: u8 = char;
    if (is_hex(working_char)) {
        if (is_lowercase(char)) {
            working_char = working_char - lowercase_adujstment;
        }
        const opt_index: ?usize = std.mem.indexOf(u8, &digits, &[1]u8{working_char});
        if (opt_index) |index| {
            return @intCast(index);
        }
    }
    return Error.NotHex;
}

pub fn parse_hex(comptime T: type, chars: []u8) Error!T {
    _ = chars;
}

test "parse_hex_char" {
    try testing.expectEqual(try parse_hex_char(u8, A), 10);
    try testing.expectEqual(try parse_hex_char(u8, 'a'), 10);
    try testing.expectEqual(try parse_hex_char(u8, '3'), 3);
    try testing.expectError(Error.NotHex, parse_hex_char(u8, 'G'));
}
