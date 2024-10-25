pub fn Stack(comptime max_element_size: usize) type {
    return struct {
        buffer: []u8,
        index: usize,
        const Self = @This();

        pub const Error = error{
            Underflow,
            Overflow,
            InvalidElementSize,
        };

        pub fn init(buffer: []u8) Self {
            return Self{
                .buffer = buffer,
                .index = buffer.len,
            };
        }
        fn ensureTypeSize(comptime T: type) void {
            comptime {
                if (@sizeOf(T) > max_element_size) {
                    @compileError("Expected Type of size `" ++ max_element_size ++ "` and got `" ++ @sizeOf(T) ++ "`");
                }
            }
        }
        pub fn clear(self: *Self) void {
            self.index = @intCast(self.buffer.len & 0xFFFF);
        }

        pub fn reserve(self: *Self, comptime T: type) !void {
            ensureTypeSize(T);
            try self.reserveBytes(@sizeOf(T));
        }

        pub fn unreserve(self: *Self, comptime T: type) !void {
            ensureTypeSize(T);
            try self.unreserveBytes(@sizeOf(T));
        }

        pub fn canReserve(self: *Self, comptime T: type) bool {
            ensureTypeSize(T);
            return self.canReserveBytes(@sizeOf(T));
        }

        pub fn canUnreserve(self: *Self, comptime T: type) bool {
            ensureTypeSize(T);
            return self.canUnreserveBytes(@sizeOf(T));
        }

        pub fn push(self: *Self, value: anytype) !void {
            ensureTypeSize(@TypeOf(value));
            try self.pushBytes(std.mem.asBytes(&value));
        }

        pub fn pop(self: *Self, out: anytype) !void {
            const Ptr = @typeInfo(@TypeOf(out)).pointer;
            ensureTypeSize(@TypeOf(Ptr.child));
            var out_buf: [@sizeOf(Ptr.child)]u8 = undefined;
            try self.popBytes(@sizeOf(Ptr.child), &out_buf);
            out.* = std.mem.bytesToValue(Ptr.child, &out_buf);
        }

        pub fn peek(self: *Self, out: anytype) !void {
            const Ptr = @typeInfo(@TypeOf(out)).pointer;
            ensureTypeSize(@TypeOf(Ptr.child));
            var out_buf: [@sizeOf(Ptr.child)]u8 = undefined;
            try self.peekBytes(@sizeOf(Ptr.child), &out_buf);
            out.* = std.mem.bytesToValue(Ptr.child, &out_buf);
        }

        pub fn drop(self: *Self, comptime T: type) !void {
            ensureTypeSize(T);
            try self.dropBytes(@sizeOf(T));
        }

        pub fn swap(self: *Self, comptime T: type) !void {
            ensureTypeSize(T);
            try self.swapBytes(@sizeOf(T));
        }

        pub fn over(self: *Self, comptime T: type) !void {
            ensureTypeSize(T);
            try self.overBytes(@sizeOf(T));
        }

        pub fn nip(self: *Self, out: anytype) !void {
            const Ptr = @typeInfo(@TypeOf(out)).pointer;
            ensureTypeSize(@TypeOf(Ptr.child));
            var out_buf: [@sizeOf(Ptr.child)]u8 = undefined;
            try self.nipBytes(@sizeOf(Ptr.child), &out_buf);
            out.* = std.mem.bytesToValue(Ptr.child, &out_buf);
        }

        pub fn rot(self: *Self, comptime T: type) !void {
            ensureTypeSize(T);
            try self.rotBytes(@sizeOf(T));
        }

        // bytes
        pub fn reserveBytes(self: *Self, element_size: usize) !void {
            const target = @subWithOverflow(self.index, element_size);
            if (target[1] == 1) {
                return error.Overflow;
            }
            self.index = target[0];
        }

        pub fn unreserveBytes(self: *Self, element_size: usize) !void {
            const target = @addWithOverflow(self.index, element_size);
            if (target[0] > self.buffer.len or target[1] == 1) {
                return error.Underflow;
            }
            self.index = target[0];
        }

        pub fn canReserveBytes(self: *Self, element_size: usize) bool {
            const target = @subWithOverflow(self.index, element_size);
            if (target[1] == 1) {
                return false;
            }
            return true;
        }

        pub fn canUnreserveBytes(self: *Self, element_size: usize) bool {
            const target = @addWithOverflow(self.index, element_size);
            if (target[0] > self.buffer.len or target[1] == 1) {
                return false;
            }
            return true;
        }

        pub fn pushBytes(self: *Self, bytes: []const u8) !void {
            const element_size = bytes.len;
            try self.reserveBytes(element_size);
            @memcpy(self.buffer[self.index .. self.index + element_size], bytes);
        }

        pub fn popBytes(self: *Self, element_size: usize, output_buffer: []u8) !void {
            try self.peekBytes(element_size, output_buffer);
            try self.unreserveBytes(element_size);
        }

        pub fn peekBytes(self: *Self, element_size: usize, output_buffer: []u8) !void {
            if (!self.canUnreserveBytes(element_size)) return error.Underflow;
            @memcpy(output_buffer, self.buffer[self.index .. self.index + element_size]);
        }

        pub fn dropBytes(self: *Self, element_size: usize) !void {
            try self.unreserveBytes(element_size);
        }

        pub fn swapBytes(self: *Self, element_size: usize) !void {
            if (element_size > max_element_size) return error.InvalidElementSize;
            if (!self.canUnreserveBytes(element_size * 2)) return error.Underflow;
            var b: [max_element_size]u8 = undefined;
            @memcpy(
                &b,
                self.buffer[self.index + element_size .. self.index + (element_size * 2)],
            );
            @memcpy(
                self.buffer[self.index + element_size .. self.index + (element_size * 2)],
                self.buffer[self.index .. self.index + element_size],
            );
            @memcpy(self.buffer[self.index .. self.index + element_size], &b);
        }

        pub fn overBytes(self: *Self, element_size: usize) !void {
            if (element_size > max_element_size) return error.InvalidElementSize;
            if (!self.canReserveBytes(element_size)) return error.Overflow;
            if (!self.canUnreserveBytes(element_size * 2)) return error.Underflow;
            try self.reserveBytes(element_size);
            @memcpy(
                self.buffer[self.index .. self.index + element_size],
                self.buffer[self.index + (element_size * 2) .. self.index + (element_size * 3)],
            );
        }

        pub fn nipBytes(self: *Self, element_size: usize, out_buf: []u8) !void {
            if (element_size > max_element_size) return error.InvalidElementSize;
            if (!self.canUnreserveBytes(element_size)) return error.Underflow;
            @memcpy(
                out_buf,
                self.buffer[self.index + element_size .. self.index + (element_size * 2)],
            );
            @memcpy(
                self.buffer[self.index + element_size .. self.index + (element_size * 2)],
                self.buffer[self.index .. self.index + element_size],
            );
            try self.unreserveBytes(element_size);
        }

        pub fn rotBytes(self: *Self, element_size: usize) !void {
            if (element_size > max_element_size) return error.InvalidElementSize;
            if (!self.canUnreserveBytes(element_size * 3)) return error.Underflow;
            var c: [max_element_size]u8 = undefined;
            @memcpy(
                &c,
                self.buffer[self.index + (element_size * 2) .. self.index + (element_size * 3)],
            );
            @memcpy(
                self.buffer[self.index + (element_size * 2) .. self.index + (element_size * 3)],
                self.buffer[self.index + element_size .. self.index + (element_size * 2)],
            );
            @memcpy(
                self.buffer[self.index + element_size .. self.index + (element_size * 2)],
                self.buffer[self.index .. self.index + element_size],
            );
            @memcpy(
                self.buffer[self.index .. self.index + element_size],
                &c,
            );
        }
    };
}

const std = @import("std");
