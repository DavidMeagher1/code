const std = @import("std");
const testing = std.testing;

const Type = std.builtin.Type;

const Error = error{
    NotHex,
    TypeTooSmall,
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

pub fn parse_hex(comptime T: type, chars: []const u8) Error!T {
    const type_info: Type = @typeInfo(T);
    const signedness = type_info.Int.signedness;
    comptime var unsigned_type_info: Type = type_info;
    unsigned_type_info.Int.signedness = .unsigned;
    const Unsigned = @Type(unsigned_type_info);
    if (chars.len > @sizeOf(T) * 2) {
        return Error.TypeTooSmall;
    }
    var result: Unsigned = 0;
    for (0..chars.len) |i| {
        const j = chars.len - 1 - i;
        const x: Unsigned = std.math.pow(Unsigned, 16, @as(Unsigned, @intCast(i)));
        const hex_val = try parse_hex_char(Unsigned, chars[j]);
        result += hex_val * x;
    }
    if (signedness == .unsigned) {
        return result;
    } else {
        return @as(T, @bitCast(result));
    }
}

test "parse_hex_char" {
    try testing.expectEqual(try parse_hex_char(u8, A), 10);
    try testing.expectEqual(try parse_hex_char(u8, 'a'), 10);
    try testing.expectEqual(try parse_hex_char(u8, '3'), 3);
    try testing.expectError(Error.NotHex, parse_hex_char(u8, 'G'));
}

test "parse_hex" {
    const cs: []const u8 = "aa00";
    const signed: i16 = try parse_hex(i16, cs);
    const unsigned: u16 = try parse_hex(u16, cs);
    try std.testing.expectEqual(signed, -22016);
    try std.testing.expectEqual(unsigned, 43520);
    try std.testing.expectError(Error.TypeTooSmall, parse_hex(u8, cs));
}
