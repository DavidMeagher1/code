const std = @import("std");
const constants = @import("./_constants.zig");

const MarshallError = error{NotAnInteger};

pub fn marshall_nibble(hex_val: u4) u8 {
    return constants.digits[hex_val];
}

pub fn marshall_byte(hex_val: u8) [2]u8 {
    const upper_nibble: u4 = @intCast(@shrExact(hex_val & 240, 4));
    const lower_nibble: u4 = @intCast(hex_val & 15);
    return .{ constants.digits[upper_nibble], constants.digits[lower_nibble] };
}

pub fn marshall_integer(hex_val: anytype) MarshallError![@sizeOf(@TypeOf(hex_val)) * 2]u8 {
    //just going to crash if its not a number
    const type_info = @typeInfo(@TypeOf(hex_val));
    const size = @sizeOf(@TypeOf(hex_val)) * 2;
    var result: [size]u8 = std.mem.zeroes([size]u8);
    if (type_info != .Int) {
        if (type_info == .ComptimeInt) {
            @compileError("Error: cannot marshall a comptime_int value as its size is not known, please use a type that has a known size");
        }
        return MarshallError.NotAnInteger;
    }
    const bytes = std.mem.asBytes(&hex_val);
    for (0..bytes.len) |i| {
        const upper_index = i * 2;
        const lower_index = i * 2 + 1;
        const j = bytes.len - 1 - i;
        const hex = marshall_byte(bytes[j]);
        result[upper_index] = hex[0];
        result[lower_index] = hex[1];
    }
    return result;
}

test "marshall_nibble" {
    std.debug.print("\nTODO actually make a test: {c}\n", .{marshall_nibble(10)});
}

test "marshall_byte" {
    std.debug.print("\nTODO actually make a test: {s}\n", .{marshall_byte(160)});
}

test "marshall" {
    const hex = try marshall_integer(@as(usize, 43520));
    std.debug.print("\nTODO actually make a test: {s}\n", .{hex});
}
