const std = @import("std");
const mem = std.mem;

const Self = @This();
const Error = error{
    StackOverflow,
    StackUnderflow,
    OutOfStack,
    StackEmpty,
    StackSwapError,
    StackRotError,
};

pub const StackIndexType = enum { Relative, Absolute };

pub const StackIndex = union(StackIndexType) {
    Relative: usize,
    Absolute: usize,
    pub fn to_absolute(self: StackIndex, top: usize, bottom: usize) usize {
        switch (self) {
            .Relative => |val| {
                return top + val;
            },
            .Absolute => |val| {
                return bottom - val;
            },
        }
    }

    pub fn flat(self: StackIndex) usize {
        switch (self) {
            .Relative => |val| {
                return val;
            },
            .Absolute => |val| {
                return val;
            },
        }
    }

    pub fn from(i: isize) StackIndex {
        if (i < 0) {
            return StackIndex{ .Relative = @as(usize, @abs(i)) };
        }
        return StackIndex{ .Absolute = @as(usize, @abs(i)) };
    }
};

const clear_element: u8 = 170;

top: usize, // index in stack buffer that is the current top
capacity: usize,
buffer: []u8,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, s_capacity: usize) !Self {
    var result = Self{
        .top = s_capacity,
        .capacity = s_capacity,
        .buffer = try allocator.alloc(u8, s_capacity),
        .allocator = allocator,
    };
    result.clear();
    return result;
}

pub fn deinit(self: *Self) void {
    self.top = 0;
    self.capacity = 0;
    self.allocator.free(self.buffer);
}

pub fn size(self: *Self) usize {
    return self.capacity - self.top;
}

pub fn reserve(self: *Self, amount: usize) Error!void {
    if (@subWithOverflow(self.top, amount)[1] == 1) {
        return error.StackOverflow;
    }
    self.top -= amount;
}

pub fn drop(self: *Self, amount: usize) Error!void {
    if (self.top + amount > self.capacity) {
        return error.StackUnderflow;
    }
    self.top += amount;
}

pub fn copyValuesOnStack(self: *Self, out_buffer: []u8) void {
    @memcpy(out_buffer, self.buffer[self.top..self.capacity]);
}

pub fn shiftStack(self: *Self, amount: usize) !void {
    const out_buf = try self.allocator.alloc(u8, self.size());
    defer self.allocator.free(out_buf);
    self.copyValuesOnStack(out_buf);
    try self.drop(out_buf.len);
    try self.reserve(amount);
    _ = try self.pushBytes(out_buf);
    @memset(self.buffer[self.top + out_buf.len .. self.capacity], clear_element);
}

pub fn clear(self: *Self) void {
    @memset(self.buffer, clear_element);
}

/// This will invalidate all pointers to the stack and clear it;
pub fn grow(self: *Self, amount: usize) !void {
    self.clear();
    self.buffer = try self.allocator.realloc(self.buffer, self.capacity + amount);
    self.capacity += amount;
    self.top = self.capacity;
}

pub fn growPreserveStack(self: *Self, amount: usize) !void {
    const out_buf = try self.allocator.alloc(u8, self.size());
    defer self.allocator.free(out_buf);
    self.copyValuesOnStack(out_buf);
    try self.growCapacity(amount);
    _ = try self.pushBytes(out_buf);
}

/// clears the stack and invalidates pointers;
pub fn shrink(self: *Self, amount: usize) !void {
    self.clear();
    self.buffer = try self.allocator.realloc(self.buffer, self.capacity - amount);
    self.capacity -= amount;
    self.top = self.capacity;
}

pub fn shrinkCapacityPreserveStack(self: *Self, amount: usize) !void {
    const out_buf = try self.allocator.alloc(u8, self.size());
    defer self.allocator.free(out_buf);
    self.copyValuesOnStack(out_buf);
    try self.shrinkCapacity(amount);
    if (self.top > out_buf.len) {
        _ = try self.pushBytes(out_buf);
    } else {
        _ = try self.pushBytes(out_buf[0..self.top]);
    }
}

pub fn pushByte(self: *Self, byte: u8) Error!usize {
    if (self.top - 1 < 0) {
        return error.StackOverflow;
    }
    try self.reserve(1);
    self.buffer[self.top] = byte;
    return 1;
}

pub fn pushBytes(self: *Self, bytes: []const u8) Error!usize {
    const blen = bytes.len;
    if (self.top - blen < 0) {
        return error.StackOverflow;
    }
    try self.reserve(blen);
    @memcpy(self.buffer[self.top .. self.top + blen], bytes);
    return blen;
}

pub fn pushBytesReversed(self: *Self, bytes: []const u8) !usize {
    const bytes_copy: []u8 = try self.allocator.alloc(u8, bytes.len);
    defer self.allocator.free(bytes_copy);

    @memcpy(bytes_copy, bytes);
    mem.reverse(u8, bytes_copy);
    return try self.pushBytes(bytes_copy);
}

pub fn popByte(self: *Self) Error!u8 {
    if (self.top + 1 > self.capacity) {
        return error.StackUnderflow;
    }
    const byte: u8 = self.buffer[self.top];
    try self.drop(1);
    return byte;
}

pub fn popByteAt(self: *Self, index: StackIndex) !u8 {
    const t = self.top;
    try self.drop(index.flat());
    const result = try self.popByte();
    try self.shiftStack(1);
    self.top = t;
    return result;
}

pub fn popBytes(self: *Self, amount: usize) Error![]u8 {
    if (self.top + amount > self.capacity) {
        return error.StackUnderflow;
    }
    const bytes: []u8 = self.buffer[self.top .. self.top + amount];
    try self.drop(amount);
    return bytes;
}

pub fn popNBytes(self: *Self, amount: usize, n: usize) Error![]u8 {
    return self.popBytes(amount * n);
}

pub fn popBytesAt(self: *Self, index: StackIndex, amount: usize) ![]u8 {
    const t = self.top;
    self.top = index.to_absolute(self.top, self.capacity);
    const result = try self.popBytes(amount);
    try self.shiftStack(amount);
    self.top = t;
    return result;
}

pub fn popNBytesAt(self: *Self, index: StackIndex, amount: usize, n: usize) ![]u8 {
    return self.popBytesAt(index, amount * n);
}

pub fn popBytesBeversed(self: *Self, amount: usize) ![]u8 {
    const bytes = try self.pop_bytes(amount);
    mem.reverse(u8, bytes);
    return bytes;
}

pub fn popNBytesReversed(self: *Self, amount: usize, n: usize) ![]u8 {
    return self.popBytesBeversed(amount * n);
}

pub fn popBytesReversedAt(self: *Self, index: StackIndex, amount: usize) ![]u8 {
    const t = self.top;
    self.top = index.to_absolute(self.top, self.capacity);
    const result = try self.popBytesBeversed(amount);
    try self.shiftStack(amount);
    self.top = t;
    return result;
}

pub fn popNBytesReversedAt(self: *Self, index: StackIndex, amount: usize, n: usize) ![]u8 {
    return self.popBytesReversedAt(index, amount * n);
}

pub fn refByte(self: *Self) ![]u8 {
    if (self.top + 1 > self.capacity) {
        return error.StackUnderflow;
    }
    const byte_ref: []u8 = self.buffer[self.top .. self.top + 1];
    return byte_ref;
}

pub fn refByteAt(self: *Self, index: StackIndex) ![]u8 {
    const t = self.top;
    self.top = index.to_absolute(self.top, self.capacity) - 1;
    const result = try self.refByte();
    self.top = t;
    return result;
}

pub fn push(self: *Self, comptime T: type, value: T) Error!usize {
    return self.pushBytes(&mem.toBytes(value));
}

pub fn pop(self: *Self, comptime T: type) Error!T {
    return mem.bytesToValue(T, try self.popBytes(@sizeOf(T)));
}

pub fn popN(self: *Self, comptime T: type, n: usize) Error![]T {
    return mem.bytesAsSlice(T, self.popNBytes(@sizeOf(T), n));
}

pub fn popAt(self: *Self, index: StackIndex, comptime T: type) !T {
    return mem.bytesToValue(T, try self.popBytesAt(index, @sizeOf(T)));
}

pub fn popNAt(self: *Self, index: StackIndex, comptime T: type, n: usize) ![]T {
    return mem.bytesAsSlice(T, self.popNBytesAt(index, @sizeOf(T), n));
}

pub fn peekByte(self: *Self) ?u8 {
    if (self.top + 1 > self.capacity) {
        return null;
    }
    const byte: u8 = self.buffer[self.top];
    return byte;
}

pub fn peekBytes(self: *Self, amount: usize) ?[]u8 {
    if (self.top + amount > self.capacity) {
        return null;
    }
    const bytes: []u8 = self.buffer[self.top .. self.top + amount];
    return bytes;
}

pub fn peekNBytes(self: *Self, amount: usize, n: usize) ?[]u8 {
    return self.peekBytes(amount * n);
}

pub fn peek(self: *Self, comptime T: type) ?T {
    if (self.peekBytes(@sizeOf(T))) |bytes| {
        return mem.bytesToValue(T, bytes);
    }
    return null;
}

pub fn peekN(self: *Self, comptime T: type, n: usize) ?[]T {
    if (self.peekNBytes(@sizeOf(T), n)) |bytes| {
        return mem.bytesAsSlice(T, bytes);
    }
    return null;
}

pub fn copyBytes(self: *Self, amount: usize, ouput_buffer: []u8) ?usize {
    const peeked_bytes = self.peek_bytes(amount);
    if (peeked_bytes) |bytes| {
        @memcpy(ouput_buffer[0..amount], bytes);
        return amount;
    }
    return null;
}

pub fn copyNBytes(self: *Self, amount: usize, n: usize, output_buffer: []u8) ?usize {
    return self.copyBytes(amount * n, output_buffer);
}

pub fn swapByte(self: *Self) Error!void {
    if (self.top == self.capacity) {
        return error.StackEmpty;
    }

    if (self.top + 1 == self.capacity) {
        return error.StackSwapError;
    }

    const byte = self.buffer[self.top];
    //const byte_b = self.buffer[self.top - 1];
    self.buffer[self.top] = self.buffer[self.top + 1];
    self.buffer[self.top + 1] = byte;
}

pub fn swapBytes(self: *Self, amount: usize) !void {
    if (self.top == self.capacity) {
        return error.StackEmpty;
    }
    if (self.top + (amount * 2) > self.capacity) {
        return error.StackSwapError;
    }
    const bytes = try self.allocator.alloc(u8, amount);
    defer self.allocator.free(bytes);
    @memcpy(bytes, self.buffer[self.top .. self.top + amount]);
    @memcpy(self.buffer[self.top .. self.top + amount], self.buffer[self.top + amount .. self.top + amount * 2]);
    @memcpy(self.buffer[self.top + amount .. self.top + amount * 2], bytes);
}

pub fn swap(self: *Self, comptime T: type) !void {
    try self.swap_bytes(@sizeOf(T));
}

pub fn rotateByte(self: *Self) !void {
    const t = self.top;
    try self.swapByte();
    try self.drop(1);
    try self.swapByte();
    self.top = t;
}

pub fn rotateBytes(self: *Self, amount: usize) !void {
    const t = self.top;
    try self.swapBytes(amount);
    try self.drop(amount);
    try self.swapBytes(amount);
    self.top = t;
}

pub fn rotate(self: *Self, comptime T: type) !void {
    try self.rotateBytes(@sizeOf(T));
}
