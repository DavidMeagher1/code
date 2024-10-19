const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Memory = @This();

const ReadError = error{};

pub const MemoryReader = struct {
    context: *Memory,
    pub fn readAs(self: MemoryReader, at: usize, comptime T: type) T {
        var cpy: [@sizeOf(T)]u8 = undefined;
        @memcpy(&cpy, self.context.buffer[at .. at + @sizeOf(T)]);
        if (builtin.cpu.arch.endian() != self.context.endianness) {
            std.mem.reverse(u8, &cpy);
        }
        return std.mem.bytesToValue(T, &cpy);
    }
};

pub const MemoryWriter = struct {
    context: *Memory,
    pub fn writeValue(self: MemoryWriter, at: usize, value: anytype) usize {
        const bytes = std.mem.toBytes(value);
        @memcpy(self.context.buffer[at .. at + bytes.len], &bytes);
        return bytes.len;
    }

    pub fn writeAt(self: MemoryWriter, at: usize, buffer: []const u8) usize {
        @memcpy(self.context.buffer[at .. at + buffer.len], buffer);
        return buffer.len;
    }
};
gpa: Allocator = undefined,
buffer: std.ArrayListUnmanaged(u8),
endianness: std.builtin.Endian = .little,

//TODO this is not needed
pub fn init(gpa: Allocator, size: u32) !Memory {
    return Memory{
        .gpa = gpa,
        .buffer = std.ArrayListUnmanaged(u8).initCapacity(gpa, size),
    };
}

pub fn deinit(self: *Memory) void {
    self.buffer.deinit(self.gpa);
    self.* = undefined;
}

pub fn load(self: *Memory, buffer: []u8) !void {
    self.buffer = buffer;
}

pub fn getReader(self: *Memory) MemoryReader {
    return MemoryReader{
        .context = self,
    };
}

pub fn getWriter(self: *Memory) MemoryWriter {
    return MemoryWriter{
        .context = self,
    };
}

pub const View = struct {
    parent: *Memory,
    start: u32,
    end: u32,
};
