const std = @import("std");
const testing = std.testing;
const builtin = std.builtin;
const Enum = builtin.Type.Enum;
const EnumField = builtin.Type.EnumField;

const Register = @import("./register.zig");

const ArchWidth = enum {
    arch_width_8,
    arch_width_16,
    arch_width_32,
    arch_width_64,

    pub fn as_uint_t(comptime self: @This()) type {
        return switch (self) {
            .arch_width_8 => u8,
            .arch_width_16 => u16,
            .arch_width_32 => u32,
            .arch_width_64 => u64,
        };
    }
};

const MemoryType = enum {
    static,
};

const MemoryConfig = struct {
    type: MemoryType = .static,
    size: usize,
};

pub fn Memory(comptime config: MemoryConfig) type {
    if (config.type == .static) {
        return [config.size]u8;
    }
    return struct {};
}

const MachineConfig: type = struct {
    arch_width: ArchWidth = ArchWidth.arch_width_8,
    register_count: usize = 1,
    memory_config: MemoryConfig,
    step_fn: *const fn (ctx: *anyopaque) anyerror!void,
};

pub fn Machine(comptime config: MachineConfig) type {
    return struct {
        const Usize: type = config.arch_width.as_uint_t();
        const Self = @This();
        const MemoryT = Memory(config.memory_config);
        const step_fn = config.step_fn;

        registers: [config.register_count]Register,
        memory: MemoryT,

        pub fn init() void {
            return Self{
                .registers = [config.register_count]Register{},
                .memory = MemoryType.init(),
            };
        }

        pub fn step(self: *Self) !void {
            try Self.step_fn(self);
        }
    };
}
