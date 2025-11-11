const std = @import("std");
const assert = std.debug.assert;
pub const Absolute = u32;

pub const Optional = enum(u32) {
    none = std.math.maxInt(u32),

    pub fn unwrap(oi: Optional) ?Absolute {
        return if (oi == .none) null else @intFromEnum(oi);
    }

    pub fn fromIndex(i: Absolute) Optional {
        return @enumFromInt(i);
    }

    pub fn fromOptional(oi: ?Absolute) Optional {
        return if (oi) |i| @enumFromInt(i) else .none;
    }
};

pub const Offset = enum(i32) {
    zero = 0,
    _,

    pub fn init(base: Absolute, destination: Absolute) Offset {
        const base_i64: i64 = base;
        const destination_i64: i64 = destination;
        return @enumFromInt(destination_i64 - base_i64);
    }

    pub fn toOptional(o: Offset) Optional {
        const result: Optional = @enumFromInt(@intFromEnum(o));
        assert(result != .none);
        return result;
    }

    pub fn toAbsolute(offset: Offset, base: Absolute) Absolute {
        return @intCast(@as(i64, base) + @intFromEnum(offset));
    }
};
