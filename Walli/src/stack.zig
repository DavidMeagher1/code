const std = @import("std");
const mem = std.mem;
pub const Stack = struct {
    const Self = @This();
    const Error = error{
        StackOverflow,
        StackUnderflow,
        OutOfStack,
        StackEmpty,
        StackSwapError,
        StackRotError,
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
        if (@addWithOverflow(self.top, amount)[1] == 1 or self.top + amount > self.capacity) {
            return error.StackUnderflow;
        }
        self.top += amount;
    }

    pub fn setStackPointer(self: *Self, value: usize) Error!void {
        if (value >= self.capacity) {
            return error.StackOverflow;
        }
        if (value < 0) {
            return error.StackUnderflow;
        }
        self.top = value;
    }

    pub fn getStackPointer(self: *Self) usize {
        return self.top;
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

    pub fn popByte(self: *Self) Error!u8 {
        if (self.top + 1 > self.capacity) {
            return error.StackUnderflow;
        }
        const byte: u8 = self.buffer[self.top];
        try self.drop(1);
        return byte;
    }

    pub fn popByteNear(self: *Self, near_index: isize) !u8 {
        const t = self.top;
        if (near_index < 0) {
            try self.drop(@abs(near_index));
        } else {
            try self.reserve(@abs(near_index));
        }
        const result = try self.popByte();
        try self.shiftStack(1);
        self.top = t;
        return result;
    }

    pub fn popByteFar(self: *Self, far_index: usize) !u8 {
        const t = self.top;
        try self.setStackPointer(self.capacity - 1 - far_index);
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

    pub fn popBytesNear(self: *Self, near_index: isize, amount: usize) ![]u8 {
        const t = self.top;
        if (near_index < 0) {
            try self.drop(@abs(near_index));
        } else {
            try self.reserve(@abs(near_index));
        }
        const result = try self.popBytes(amount);
        try self.shiftStack(amount);
        self.top = t;
        return result;
    }

    pub fn popBytesFar(self: *Self, far_index: usize, amount: usize) ![]u8 {
        const t = self.top;
        try self.setStackPointer(self.capacity - 1 - far_index);
        const result = try self.popBytes(amount);
        try self.shiftStack(amount);
        self.top = t;
        return result;
    }

    pub fn popNBytesNear(self: *Self, near_index: isize, amount: usize, n: usize) ![]u8 {
        return self.popBytesNear(near_index, amount * n);
    }

    pub fn popNBytesFar(self: *Self, far_index: usize, amount: usize, n: usize) ![]u8 {
        return self.popBytesFar(far_index, amount * n);
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

    pub fn popNear(self: *Self, near_index: isize, comptime T: type) !T {
        return mem.bytesToValue(T, try self.popBytesNear(near_index, @sizeOf(T)));
    }

    pub fn popAt(self: *Self, far_index: usize, comptime T: type) !T {
        return mem.bytesToValue(T, try self.popBytesFar(far_index, @sizeOf(T)));
    }

    pub fn popNNear(self: *Self, near_index: isize, comptime T: type, n: usize) ![]T {
        return mem.bytesAsSlice(T, self.popNBytesNear(near_index, @sizeOf(T), n));
    }

    pub fn popNFar(self: *Self, far_index: usize, comptime T: type, n: usize) ![]T {
        return mem.bytesAsSlice(T, self.popNBytesFar(far_index, @sizeOf(T), n));
    }

    pub fn peekByte(self: Self) ?*u8 {
        if (self.top + 1 > self.capacity) {
            return null;
        }
        const byte: *u8 = &self.buffer[self.top];
        return byte;
    }

    pub fn peekByteNear(self: *Self, near_index: isize) ?*u8 {
        const t = self.top;
        if (near_index < 0) {
            self.drop(@abs(near_index)) catch {
                return null;
            };
        } else {
            self.reserve(@abs(near_index)) catch {
                return null;
            };
        }
        const byte: ?*u8 = self.peekByte();
        self.top = t;
        return byte;
    }

    pub fn peekByteFar(self: *Self, far_index: usize) ?*u8 {
        const t = self.top;
        self.setStackPointer(self.capacity - 1 - far_index) catch {
            return null;
        };
        const byte: ?*u8 = self.peekByte();
        self.top = t;
        return byte;
    }

    pub fn peekBytes(self: *Self, amount: usize) ?[]u8 {
        if (self.top + amount > self.capacity) {
            return null;
        }
        const bytes: []u8 = self.buffer[self.top .. self.top + amount];
        return bytes;
    }

    pub fn peekBytesNear(self: *Self, near_index: isize, amount: usize) ?[]u8 {
        const t = self.top;
        if (near_index < 0) {
            self.drop(@abs(near_index)) catch {
                return null;
            };
        } else {
            self.reserve(@abs(near_index)) catch {
                return null;
            };
        }

        const bytes = self.peekBytes(amount);
        self.top = t;
        return bytes;
    }

    pub fn peekBytesFar(self: *Self, far_index: usize, amount: usize) ?[]u8 {
        const t = self.top;
        self.setStackPointer(self.capacity - 1 - far_index) catch {
            return null;
        };
        const bytes = self.peekBytes(amount);
        self.top = t;
        return bytes;
    }

    pub fn peekNBytes(self: *Self, amount: usize, n: usize) ?[]u8 {
        return self.peekBytes(amount * n);
    }

    pub fn peekNBytesNear(self: *Self, near_index: isize, amount: usize, n: usize) ?[]u8 {
        return self.peekBytesNear(near_index, amount * n);
    }

    pub fn peekNBytesFar(self: *Self, far_index: usize, amount: usize, n: usize) ?[]u8 {
        return self.peekBytesFar(far_index, amount * n);
    }

    pub fn peek(self: *Self, comptime T: type) ?T {
        if (self.peekBytes(@sizeOf(T))) |bytes| {
            return mem.bytesToValue(T, bytes);
        }
        return null;
    }

    pub fn peekNear(self: *Self, near_index: isize, comptime T: type) ?T {
        const t = self.top;
        if (near_index < 0) {
            self.drop(@abs(near_index)) catch {
                return null;
            };
        } else {
            self.reserve(@abs(near_index)) catch {
                return null;
            };
        }
        const result = self.peek(T);
        self.top = t;
        return result;
    }

    pub fn peekFar(self: *Self, far_index: usize, comptime T: type) ?T {
        const t = self.top;
        self.setStackPointer(self.capacity - 1 - far_index) catch {
            return null;
        };
        const result = self.peek(T);
        self.top = t;
        return result;
    }

    pub fn peekN(self: *Self, comptime T: type, n: usize) ?[]T {
        if (self.peekNBytes(@sizeOf(T), n)) |bytes| {
            return mem.bytesAsSlice(T, bytes);
        }
        return null;
    }

    pub fn peekNNear(self: *Self, near_index: isize, comptime T: type, n: usize) ?[]T {
        if (self.peekNBytesNear(near_index, @sizeOf(T), n)) |bytes| {
            return mem.bytesAsSlice(T, bytes);
        }
        return null;
    }

    pub fn peekNFar(self: *Self, far_index: usize, comptime T: type, n: usize) ?[]T {
        if (self.peekNBytesFar(far_index, @sizeOf(T), n)) |bytes| {
            return mem.bytesAsSlice(T, bytes);
        }
        return null;
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

    pub fn swapByteNear(self: *Self, near_index: isize) Error!void {
        const t = self.top;
        if (near_index < 0) {
            try self.drop(@abs(near_index));
        } else {
            try self.reserve(@abs(near_index));
        }
        try self.swapByte();
        self.top = t;
    }

    pub fn swapByteFar(self: *Self, far_index: usize) Error!void {
        const t = self.top;
        try self.setStackPointer(self.capacity - 1 - far_index);
        try self.swapByte();
        self.top = t;
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

    pub fn swapBytesNear(self: *Self, near_index: isize, amount: usize) !void {
        const t = self.top;
        if (near_index < 0) {
            try self.drop(@abs(near_index));
        } else {
            try self.reserve(near_index);
        }
        try self.swapBytes(amount);
        self.top = t;
    }

    pub fn swapBytesFar(self: *Self, far_index: usize, amount: usize) !void {
        const t = self.top;
        try self.setStackPointer(self.capacity - 1 - far_index);
        try self.swapBytes(amount);
        self.top = t;
    }

    pub fn swap(self: *Self, comptime T: type) !void {
        try self.swapBytes(@sizeOf(T));
    }

    pub fn swapNear(self: *Self, near_index: isize, comptime T: type) !void {
        try self.swapBytesNear(near_index, @sizeOf(T));
    }

    pub fn swapFar(self: *Self, far_index: usize, comptime T: type) !void {
        try self.swapBytesFar(far_index, @sizeOf(T));
    }

    pub fn rotateByte(self: *Self) !void {
        const t = self.top;
        try self.swapByte();
        try self.drop(1);
        try self.swapByte();
        self.top = t;
    }

    pub fn rotateByteNear(self: *Self, near_index: isize) !void {
        const t = self.top;
        if (near_index < 0) {
            try self.drop(@abs(near_index));
        } else {
            try self.reserve(@abs(near_index));
        }
        try self.swapByte();
        try self.drop(1);
        try self.swapByte();
        self.top = t;
    }

    pub fn rotateByteFar(self: *Self, far_index: usize) !void {
        const t = self.top;
        try self.setStackPointer(self.capacity - 1 - far_index);
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

    pub fn rotateBytesNear(self: *Self, near_index: isize, amount: usize) !void {
        const t = self.top;
        if (near_index < 0) {
            try self.drop(@abs(near_index));
        } else {
            try self.reserve(@abs(near_index));
        }
        try self.swapBytes(amount);
        try self.drop(amount);
        try self.swapBytes(amount);
        self.top = t;
    }

    pub fn rotateBytesFar(self: *Self, far_index: usize, amount: usize) !void {
        const t = self.top;
        try self.setStackPointer(self.capacity - 1 - far_index);
        try self.swapBytes(amount);
        try self.drop(amount);
        try self.swapBytes(amount);
        self.top = t;
    }

    pub fn rotate(self: *Self, comptime T: type) !void {
        try self.rotateBytes(@sizeOf(T));
    }

    pub fn rotateNear(self: *Self, near_index: isize, comptime T: type) !void {
        try self.rotateBytesNear(near_index, @sizeOf(T));
    }

    pub fn rotateFar(self: *Self, far_index: usize, comptime T: type) !void {
        try self.rotateBytesFar(far_index, @sizeOf(T));
    }
};
