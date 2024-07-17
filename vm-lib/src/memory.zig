const Memory = @This();

pub const WriteError = error{
    OutOfBounds,
};

pub const ReadError = error{
    OutOfBounds,
};

data: []u8,

pub fn init(data: []u8) Memory {
    return Memory{
        .data = data,
    };
}

pub fn write(self: *Memory, where: usize, what: []const u8) WriteError!void {
    if (what.len == 0) {
        return;
    }
    if (where + what.len > self.data.len) {
        return WriteError.OutOfBounds;
    }
    @memcpy(self.data[where .. where + what.len], what);
}

pub fn read(self: *Memory, where: usize, amount: usize) ReadError![]u8 {
    if (amount == 0) {
        return &[0]u8{};
    }
    if (where + amount > self.data.len) {
        return ReadError.OutOfBounds;
    }
    return self.data[where .. where + amount];
}
