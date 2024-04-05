const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub fn Register(comptime bits: u16) type {
    const tinfo = std.builtin.Type{
        .Int = .{
            .bits = bits,
            .signedness = .unsigned,
        },
    };

    const T = @Type(tinfo);
    return struct {
        const Self = @This();
        pub const size: u16 = bits;
        const bytes_amount = @ceil(@as(f32, size) / 8);
        const word_amount = @ceil(@as(f32, bytes_amount) / @sizeOf(usize));
        //doesnt need to be packed as it has one field
        data: T,

        pub fn inner(self: Self) T {
            return self.data;
        }

        pub fn innerRef(self: *Self) *T {
            return &self.data;
        }

        pub fn asWordArray(self: Self) [word_amount]usize {
            var word_array: [word_amount]usize = mem.zeroes([word_amount]usize);
            var bytes: [bytes_amount]u8 = mem.zeroes([bytes_amount]u8);
            @memcpy(&bytes, mem.asBytes(&self.data));
            var i: usize = 0;
            var j: usize = 0;
            while (i < bytes.len) {
                const val = mem.bytesToValue(usize, bytes[i .. i + @sizeOf(usize)]);
                word_array[j] = val;
                i += @sizeOf(usize);
                j += 1;
            }
            return word_array;
        }

        pub fn assignFromWordArray(self: *Self, word_array: [word_amount]usize) void {
            var byte_array: [bytes_amount]u8 = mem.zeroes([bytes_amount]u8);
            var i: usize = 0;
            var j: usize = 0;
            while (i < word_array.len) {
                const bytes = mem.toBytes(word_array[i]);
                @memcpy(byte_array[j .. j + @sizeOf(usize)], &bytes);
                i += 1;
                j += @sizeOf(usize);
            }

            const _data = mem.bytesToValue(T, &byte_array);
            self.data = _data;
        }

        pub fn assignFromBytes(self: *Self, bytes: []const u8) void {
            if (bytes.len > bytes_amount) {
                @panic("FIX ME");
            }
            var new_bytes: [bytes_amount]u8 = mem.zeroes([bytes_amount]u8);
            @memcpy(new_bytes[0..bytes.len], bytes);
            self.data = mem.bytesToValue(T, &new_bytes);
        }

        pub fn fromWordArray(word_array: []const usize) Self {
            var result = Self{ .data = 0 };
            result.assignFromWordArray(word_array);
            return result;
        }

        pub fn fromBytes(bytes: []const usize) Self {
            var result = Self{ .data = 0 };
            result.assignFromBytes(bytes);
            return result;
        }

        pub fn from(comptime NT: type, val: NT) Self {
            return Self.fromBytes(&mem.toBytes(val));
        }
    };
}

fn bitmask(size: u16) u16 {
    //65535
    _ = size;
    const b: u655 = 1_000000000000000000000000000000000000000000000_000_000_000_000;
    std.debug.print("\n\n{b}\n\n", .{b});
    return 0;
}

test "bitmask" {
    _ = bitmask(0);
}

test "Register" {
    const RegU128 = Register(128);
    const RegU32 = Register(32);
    const dat = RegU128{ .data = 0xFF_FF_FF_FF_AA_AA_AA_AA_FF_FF_FF_FF_AA_AA_AA };
    const wao = dat.asWordArray();
    try testing.expectEqual(dat.inner(), RegU128.fromWordArray(wao).inner());

    const dat2 = RegU32{ .data = 0xFF_AA_FF_AA };
    const wao2 = dat2.asWordArray();
    std.debug.print("\n\ninner:{d}, wao:{any}\n\n", .{ dat2.inner(), wao2 });

    const dat3 = RegU128.from(u16, 65535);
    std.debug.print("\n\ninner:{d}\n\n", .{dat3.inner()});
}
