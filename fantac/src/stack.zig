const CPU = @import("./cpu.zig");
const std = @import("std");

pub fn Stack(comptime biggest_element_size: usize) type {
    return struct {
        const Self = @This();
        buffer: []u8,
        base_addr: u16,
        sp: u16,

        const Error = error{
            StackUnderflow,
            StackOverflow,
        };

        pub fn can_unreserve(self: *Self, el_size: u16) bool {
            const rsp = @addWithOverflow(self.sp, el_size);
            if (rsp[0] > self.buffer.len or rsp[1] == 1) {
                return false;
            }
            return true;
        }

        pub fn can_reserve(self: *Self, el_size: u16) bool {
            const rsp = @subWithOverflow(self.sp, el_size);
            if (rsp[1] == 1) {
                return false;
            }
            return true;
        }

        pub fn unreserve(self: *Self, el_size: u16) Error!void {
            const rsp = @addWithOverflow(self.sp, el_size);
            if (rsp[0] > self.buffer.len or rsp[1] == 1) {
                return error.StackUnderflow;
            }
            self.sp = rsp[0];
        }

        pub fn reserve(self: *Self, el_size: u16) Error!void {
            const rsp = @subWithOverflow(self.sp, el_size);
            if (rsp[1] == 1) {
                return error.StackOverflow;
            }
            self.sp = rsp[0];
        }

        pub fn push(self: *Self, bytes: []const u8) !u16 {
            const el_size: u16 = @intCast(bytes.len & 0xFFFFFFFF);
            try self.reserve(el_size);
            @memcpy(self.buffer[self.sp .. self.sp + bytes.len], bytes);
            return self.base_addr + self.sp;
        }

        pub fn pop(self: *Self, el_size: u16) !struct { []u8, u16 } {
            const result = self.buffer[self.sp .. self.sp + el_size];
            try self.unreserve(el_size);
            return .{ result, self.base_addr + self.sp };
        }

        pub fn peek(self: *Self, el_size: u16) ![]u8 {
            if (self.can_unreserve(el_size)) {
                return self.buffer[self.sp .. self.sp + el_size];
            }
            return error.StackUnderflow;
        }

        pub fn dup(self: *Self, el_size: u16) !u16 {
            if (self.can_unreserve(el_size)) {
                try self.reserve(el_size);
                @memcpy(self.buffer[self.sp .. self.sp + el_size], self.buffer[self.sp + el_size .. self.sp + (el_size * 2)]);
                return self.base_addr + self.sp;
            }
            return error.StackUnderflow;
        }

        pub fn nip(self: *Self, el_size: u16) !struct { []u8, u16 } {
            if (self.can_unreserve(el_size * 2)) {
                var result: [biggest_element_size]u8 = undefined;
                @memcpy(result[0..el_size], self.buffer[self.sp + el_size .. self.sp + (el_size * 2)]);
                @memcpy(self.buffer[self.sp + el_size .. self.sp + (el_size * 2)], self.buffer[self.sp .. self.sp + el_size]);
                try self.unreserve(el_size);
                return .{ result[0..el_size], self.base_addr + self.sp };
            }
            return error.StackUnderflow;
        }

        pub fn over(self: *Self, el_size: u16) !u16 {
            if (self.can_unreserve(el_size * 2)) {
                try self.reserve(el_size);
                @memcpy(self.buffer[self.sp .. self.sp + el_size], self.buffer[self.sp + (el_size * 2) .. self.sp + (el_size * 3)]);
                return self.base_addr + self.sp;
            }
            return error.StackUnderflow;
        }

        pub fn swap(self: *Self, el_size: u16) !void {
            if (self.can_unreserve(el_size * 2)) {
                var b: [biggest_element_size]u8 = undefined;
                @memcpy(b[0..el_size], self.buffer[self.sp + el_size .. self.sp + (el_size * 2)]);
                @memcpy(self.buffer[self.sp + el_size .. self.sp + (el_size * 2)], self.buffer[self.sp .. self.sp + el_size]);
                @memcpy(self.buffer[self.sp .. self.sp + el_size], b[0..el_size]);
            } else {
                return error.StackUnderflow;
            }
        }

        pub fn rot(self: *Self, el_size: u16) !void {
            if (self.can_unreserve(el_size * 3)) {
                var c: [biggest_element_size]u8 = undefined;
                @memcpy(c[0..el_size], self.buffer[self.sp + (el_size * 2) .. self.sp + (el_size * 3)]);
                @memcpy(self.buffer[self.sp + (el_size * 2) .. self.sp + (el_size * 3)], self.buffer[self.sp + el_size .. self.sp + (el_size * 2)]);
                @memcpy(self.buffer[self.sp + el_size .. self.sp + (el_size * 2)], self.buffer[self.sp .. self.sp + el_size]);
                @memcpy(self.buffer[self.sp .. self.sp + el_size], c[0..el_size]);
            } else {
                return error.StackUnderflow;
            }
        }
    };
}
