const std = @import("std");
const testing = std.testing;
const utils = @import("./utils.zig");
const Register = @This();

const RegisterWriteError = error{
    CannotContainValue,
};

const RegisterReadError = error{
    CannotReadValue,
};

const SubRegisterError = error{
    WidthError,
    OffsetError,
    OutOfBoundsError,
};

width: u8 = 8,
location: []u8,

pub fn init(width: u8, location: []u8) Register {
    return Register{
        .width = width,
        .location = location,
    };
}

pub fn sub_register(width: u8, offset: u8, r: Register) SubRegisterError!Register {
    if (width >= r.width) {
        return SubRegisterError.WidthError;
    }
    if (offset >= r.width) {
        return SubRegisterError.OffsetError;
    }
    if (width + offset > r.width) {
        return SubRegisterError.OutOfBoundsError;
    }
    return Register{
        .width = width,
        .location = r.location[offset .. width + offset],
    };
}

pub fn set(self: *Register, comptime T: type, value: T) RegisterWriteError!void {
    if (@sizeOf(T) > self.width) {
        return RegisterWriteError.CannotContainValue;
    }
    //convert value into bytes
    const bytes = std.mem.toBytes(value);
    @memcpy(self.location, &bytes);
}

pub fn get(self: *Register, comptime T: type) RegisterReadError!T {
    if (@sizeOf(T) > self.width) {
        return RegisterReadError.CannotReadValue;
    }
    //convert value into bytes
    const value: T = std.mem.bytesToValue(T, self.location[0..@sizeOf(T)]);
    return value;
}

pub fn clear(self: *Register) void {
    for (0..self.width) |i| {
        self.location[i] = 0;
    }
}

test "register: init" {
    const static_block: []u16 = @constCast(&[_]u16{ 256, 21, 11 });
    const r0 = Register.init(6, utils.cast_slice_to(u8, static_block));
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 21, 0, 11, 0 }, r0.location);
}

test "sub-register" {
    const static_block: []u8 = @constCast(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    const r0 = Register.init(10, static_block);
    try testing.expectEqualSlices(u8, static_block, r0.location);
    const r1 = try sub_register(9, 1, r0);
    try testing.expectEqualSlices(u8, static_block[1..static_block.len], r1.location);
    const r2 = try sub_register(3, 0, r0);
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, r2.location);
}

test "register: manual modification" {
    var static_block: [10]u8 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const r0 = Register.init(10, static_block[0..]);
    r0.location[0] = 22;
    try testing.expectEqualSlices(u8, &[_]u8{ 22, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, r0.location);
    try testing.expectEqualSlices(u8, &[_]u8{ 22, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, static_block[0..]);
}

test "sub-register: manual modification" {
    var block: [10]u8 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const r0 = Register.init(10, block[0..]);
    const r1 = try sub_register(6, 4, r0);
    try testing.expectEqualSlices(u8, &[_]u8{ 5, 6, 7, 8, 9, 10 }, r1.location);

    r1.location[0] = 240;

    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 240, 6, 7, 8, 9, 10 }, r0.location);
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 240, 6, 7, 8, 9, 10 }, block[0..]);
}

test "register: set" {
    var block: [2]u8 = [_]u8{ 0, 0 };
    var r0 = Register.init(2, block[0..]);
    try r0.set(u16, 0xFAFB);
    try testing.expectEqualSlices(u8, &[_]u8{ 251, 250 }, r0.location);
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
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0 }, r0.location);
}
