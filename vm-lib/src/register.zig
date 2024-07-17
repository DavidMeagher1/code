const std = @import("std");
const testing = std.testing;
const utils = @import("./utils.zig");
const Register = @This();

const WriteError = error{
    CannotContainValue,
};

const ReadError = error{
    CannotReadValue,
};

const MaskingError = error{
    WidthError,
    OffsetError,
    OutOfBoundsError,
};

pub const Invalid: Register = Register{
    .width = 0,
    .value = @constCast(&[_]u8{}),
};

width: u8 = 8,
value: []u8,

pub fn init_masking_register(r: Register, width: u8, offset: u8) MaskingError!Register {
    if (width >= r.width) {
        return MaskingError.WidthError;
    }
    if (offset >= r.width) {
        return MaskingError.OffsetError;
    }
    if (width + offset > r.width) {
        return MaskingError.OutOfBoundsError;
    }
    return Register{
        .width = width,
        .value = r.value[offset .. width + offset],
    };
}

pub fn set(self: *Register, comptime T: type, value: T) WriteError!void {
    if (@sizeOf(T) > self.width) {
        return WriteError.CannotContainValue;
    }
    //convert value into bytes
    const bytes = std.mem.toBytes(value);
    @memcpy(self.value[0..@sizeOf(T)], &bytes);
}

pub fn get(self: *Register, comptime T: type) ReadError!T {
    if (@sizeOf(T) > self.width) {
        return ReadError.CannotReadValue;
    }
    //convert value into bytes
    const value: T = std.mem.bytesToValue(T, self.value[0..@sizeOf(T)]);
    return value;
}

pub fn clear(self: *Register) void {
    for (0..self.width) |i| {
        self.value[i] = 0;
    }
}

test "register: init" {
    const static_block: []u16 = @constCast(&[_]u16{ 256, 21, 11 });
    const r0 = Register.init(6, utils.cast_slice_to(u8, static_block));
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 21, 0, 11, 0 }, r0.value);
}

test "sub-register" {
    const static_block: []u8 = @constCast(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    const r0 = Register.init(10, static_block);
    try testing.expectEqualSlices(u8, static_block, r0.value);
    const r1 = try r0.init_masking_register(9, 1);
    try testing.expectEqualSlices(u8, static_block[1..static_block.len], r1.value);
    const r2 = try r0.init_masking_register(3, 0);
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, r2.value);
}

test "register: manual modification" {
    var static_block: [10]u8 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const r0 = Register.init(10, static_block[0..]);
    r0.value[0] = 22;
    try testing.expectEqualSlices(u8, &[_]u8{ 22, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, r0.value);
    try testing.expectEqualSlices(u8, &[_]u8{ 22, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, static_block[0..]);
}

test "sub-register: manual modification" {
    var block: [10]u8 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const r0 = Register.init(10, block[0..]);
    const r1 = try r0.init_masking_register(6, 4);
    try testing.expectEqualSlices(u8, &[_]u8{ 5, 6, 7, 8, 9, 10 }, r1.value);

    r1.value[0] = 240;

    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 240, 6, 7, 8, 9, 10 }, r0.value);
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 240, 6, 7, 8, 9, 10 }, block[0..]);
}

test "register: set" {
    var block: [2]u8 = [_]u8{ 0, 0 };
    var r0 = Register.init(2, block[0..]);
    try r0.set(u16, 0xFAFB);
    try testing.expectEqualSlices(u8, &[_]u8{ 251, 250 }, r0.value);
}

test "register: get" {
    var block: [2]u8 = [_]u8{ 0x7B, 0x42 };
    var r0 = Register.init(2, block[0..]);
    const value = try r0.get(u16);
    try testing.expectEqual(0x427B, value);
}

test "register: clear" {
    var block: [2]u8 = [_]u8{ 0x7B, 0x42 };
    var r0 = Register.init(2, block[0..]);
    r0.clear();
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0 }, r0.value);
}
