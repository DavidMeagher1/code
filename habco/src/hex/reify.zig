const std = @import("std");
const testing = std.testing;
const constants = @import("_constants.zig");

const Type = std.builtin.Type;

const ReifyError = error{
    NotHex,
    TypeTooSmall,
};

const lowercase_adujstment: u8 = 'a' - 'A';

pub fn is_numeric(char: u8) bool {
    return char >= constants.Zero and char <= constants.Nine;
}

pub fn is_alphabetic(char: u8) bool {
    return (char >= constants.A and char <= constants.F) or (char >= constants.A + lowercase_adujstment and char <= constants.F + lowercase_adujstment);
}

pub fn is_hex(char: u8) bool {
    return is_numeric(char) or is_alphabetic(char);
}

pub fn is_lowercase(char: u8) bool {
    if (is_alphabetic(char)) {
        return char > constants.F;
    }
    return false;
}

pub fn to_uppercase(char: u8) u8 {
    if (is_lowercase(char)) {
        return char - constants.lowercase_distance;
    } else {
        return char;
    }
}

pub fn reify_char(comptime T: type, char: u8) ReifyError!T {
    var working_char: u8 = char;
    if (is_hex(working_char)) {
        if (is_lowercase(char)) {
            working_char = working_char - lowercase_adujstment;
        }
        const opt_index: ?usize = std.mem.indexOf(u8, &constants.digits, &[1]u8{working_char});
        if (opt_index) |index| {
            return @intCast(index);
        }
    }
    return ReifyError.NotHex;
}

pub fn to_bytes(hex_characters: []const u8, output_buffer: []u8) ReifyError!usize {
    var i: usize = 0;
    var j: usize = 0;
    while (i < hex_characters.len) {
        output_buffer[j] = try to_byte([2]u8{ hex_characters[i], hex_characters[i + 1] });
        j += 1;
        i += 2;
    }
    return j;
}

pub fn to_byte(hex_characters: [2]u8) ReifyError!u8 {
    const idxa: ?usize = std.mem.indexOf(u8, &constants.digits, &[1]u8{to_uppercase(hex_characters[0])});
    const idxb: ?usize = std.mem.indexOf(u8, &constants.digits, &[1]u8{to_uppercase(hex_characters[1])});
    if (idxa) |a| {
        if (idxb) |b| {
            return @as(u8, @intCast((@shlExact(a, 4) | b)));
        }
    }
    return error.NotHex;
}

pub fn reify(comptime T: type, chars: []const u8) ReifyError!T {
    const type_info: Type = @typeInfo(T);
    const signedness = type_info.Int.signedness;
    comptime var unsigned_type_info: Type = type_info;
    unsigned_type_info.Int.signedness = .unsigned;
    const Unsigned = @Type(unsigned_type_info);
    if (chars.len > @sizeOf(T) * 2) {
        return ReifyError.TypeTooSmall;
    }
    var result: Unsigned = 0;
    for (0..chars.len) |i| {
        const j = chars.len - 1 - i;
        const x: Unsigned = std.math.pow(Unsigned, 16, @as(Unsigned, @intCast(i)));
        const hex_val = try reify_char(Unsigned, chars[j]);
        result += hex_val * x;
    }
    if (signedness == .unsigned) {
        return result;
    } else {
        return @as(T, @bitCast(result));
    }
}

test "reify_hex_char" {
    try testing.expectEqual(try reify_char(u8, 'A'), 10);
    try testing.expectEqual(try reify_char(u8, 'a'), 10);
    try testing.expectEqual(try reify_char(u8, '3'), 3);
    try testing.expectError(ReifyError.NotHex, reify_char(u8, 'G'));
}

test "reify_hex" {
    const cs: []const u8 = "aa00";
    const signed: i16 = try reify(i16, cs);
    const unsigned: u16 = try reify(u16, cs);
    try std.testing.expectEqual(signed, -22016);
    try std.testing.expectEqual(unsigned, 43520);
    try std.testing.expectError(ReifyError.TypeTooSmall, reify(u8, cs));
}
