const opcodes = @import("./opcodes.zig");

pub const ByteCode = struct {
    const Self = @This();
    buffer: []const u8,
    index: usize = 0,

    pub fn peek(self: Self) ?u8 {
        if (self.index >= self.buffer.len) {
            return null;
        }
        return self.buffer[self.index];
    }

    pub fn next(self: *Self) ?u8 {
        const result = self.peek();
        if (result) |res| {
            self.index += 1;
            return res;
        }
        return null;
    }

    pub fn reset(self: *Self) void {
        self.index = 0;
    }
};
