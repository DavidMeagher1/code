const std = @import("std");
const mem = std.mem;
const io = std.io;

const GenericReader = io.GenericReader;
const GenericWriter = io.GenericWriter;

pub const MemorySectionRules = packed struct(u8) {
    read: bool = true,
    write: bool = true,
    execute: bool = true,
    _padding: u5 = 0,
};

pub const MemorySection = struct {
    const Self = @This();
    start: usize,
    end: usize,
    rules: MemorySectionRules,

    pub fn contains(self: Self, u: usize) bool {
        return u >= self.start and u <= self.end;
    }
};

pub const MemorySectionContext = struct {
    pub fn lessThan(context: @This(), a: MemorySection, b: MemorySection) bool {
        _ = context;
        if (a.start < b.start) {
            return true;
        } else if (a.start == b.start) {
            return a.end < b.end;
        }
        return false;
    }
};

pub const Memory = struct {
    const Self = @This();

    pub const WriteError = error{
        InvalidPermmisions,
        OutOfMemory,
        WriteFailure,
    };
    pub const ReadError = error{
        InvalidPermmisions,
        ReadFailure,
    };

    pub const Writer = GenericWriter(Self, WriteError, write);
    pub const Reader = GenericReader(Self, ReadError, read);

    allocator: mem.Allocator,
    pc: usize = 0,
    sections: []const MemorySection,
    data: []u8,
    size: usize = 0,

    pub fn init(allocator: mem.Allocator, data: []const u8, sections: []const MemorySection) !Self {
        const result = Self{
            .allocator = allocator,
            .sections = blk: {
                const s = try allocator.alloc(MemorySection, sections.len);
                @memcpy(s, sections);
                mem.sort(MemorySection, s, MemorySectionContext{}, MemorySectionContext.lessThan);
                //merge sections that are the same and start at the same place, error on overlapping sections with different rules
                var i: usize = 0;
                for (s) |section| {
                    if (s[i].contains(section.start)) {
                        if (@as(u8, @bitCast(section.rules)) != @as(u8, @bitCast(s[i].rules))) {
                            @panic("unable to have overlapping sections");
                        }
                        s[i].end = section.end;
                    } else {
                        i += 1;
                    }
                }
                const final = try allocator.alloc(MemorySection, i + 1);
                @memcpy(final, s[0 .. i + 1]);
                allocator.free(s);
                break :blk final;
            },
            .data = blk: {
                const d = try allocator.alloc(u8, data.len);
                @memcpy(d, data);
                break :blk d;
            },
        };

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.sections);
        self.allocator.free(self.data);
        self.size = 0;
    }

    pub fn write(context: *Self, bytes: []const u8) WriteError!usize {
        const cpc = context.pc;
        for (context.sections) |section| {
            if (!section.rules.write) {
                return error.InvalidPermmisions;
            }
            if (section.contains(cpc)) {
                if (cpc + bytes.len > context.data.len) {
                    return error.OutOfMemory;
                }
                const data = context.data[cpc .. cpc + bytes.len];
                @memcpy(data, bytes);
                context.pc += bytes.len;
                return bytes.len;
            }
        }
        return error.WriteFailure;
    }

    pub fn read(context: *Self, buffer: []u8) ReadError!usize {
        const cpc = context.pc;
        for (context.sections) |section| {
            if (section.contains(cpc)) {
                if (!section.rules.read) {
                    return error.InvalidPermmisions;
                }
                var amount: usize = 0;
                if (cpc + buffer.len > context.data.len) {
                    amount = context.data.len;
                } else {
                    amount = cpc + buffer.len;
                }
                const data = context.data[cpc..amount];
                @memcpy(buffer, data);
                context.pc += amount;
                return amount;
            }
        }
        return error.ReadFailure;
    }

    pub fn writer(self: *Self) Self.Writer {
        return Writer{ .context = self };
    }
    pub fn reader(self: *Self) Self.Reader {
        return Reader{ .context = self };
    }
};

pub const MemoryIterator = struct {
    const Self = @This();
    context: *Memory,

    pub fn peek(self: Self, amount: usize) ?[]u8 {
        const cpc = self.context.pc;
        for (self.context.sections) |section| {
            if (!section.contains(cpc) or !section.rules.read or cpc + amount > self.context.data.len) {
                return null;
            }
            return self.context.data[cpc .. cpc + amount];
        }
        return null;
    }

    pub fn next(self: *Self, amount: usize) ?[]u8 {
        const opt_result = self.peek(amount);
        if (opt_result) |result| {
            self.context.pc += amount;
            return result;
        }
        return null;
    }
};
