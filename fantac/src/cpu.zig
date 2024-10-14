const std = @import("std");
const builtin = @import("builtin");
const StaticStringMap = std.StaticStringMap;
const Register = @import("./register.zig");
const instructions = @import("./instructions.zig");
const OpCode = instructions.OpCode;

const Memory = @import("./memory.zig");

pub const CPUOptions = struct {
    register_names: []const []const u8,
    endianness: std.builtin.Endian = builtin.cpu.arch.endian(),
};

pub const Mode = enum {
    user,
    kernel,
    hardware,
};

pub const Error = error{
    unknown_register,
    no_program_counter,
    no_accumulator,
    invalid_access,
};

pub fn CPU(comptime options: CPUOptions) type {
    return struct {
        const RegisterMap = StaticStringMap(u8);
        const Self = @This();
        mode: Mode = .kernel,
        registers: [options.register_names.len]Register,
        register_map: RegisterMap,
        register_mode_map: [options.register_names.len]Mode = std.mem.zeroes([options.register_names.len]Mode),

        memory: Memory,

        pub fn init(memory: Memory) Self {
            const KVS = struct { []const u8, u8 };
            const size: usize = options.register_names.len;
            comptime var kvs_list: [size]KVS = undefined;
            comptime for (options.register_names, 0..size) |name, index| {
                kvs_list[index] = KVS{
                    name,
                    index,
                };
            };
            var result = Self{
                .registers = std.mem.zeroes([size]Register),
                .register_map = RegisterMap.initComptime(kvs_list),
                .memory = memory,
            };
            result.memory.endianness = options.endianness;
            return result;
        }

        pub fn hasRegister(self: *Self, name: []const u8) bool {
            return self.register_map.has(name);
        }

        pub fn getRegister(self: *Self, name: []const u8) Error!*Register {
            return self.getRegisterByID(try self.getRegisterID(name));
        }

        pub fn getRegisterID(self: Self, name: []const u8) Error!u8 {
            const i = self.register_map.get(name);
            if (i) |j| {
                return j;
            }
            return error.unknown_register;
        }

        pub fn getRegisterByID(self: *Self, index: u8) Error!*Register {
            if (index >= 0 and index < self.registers.len) {
                return &self.registers[index];
            }
            return error.unknown_register;
        }

        pub fn setRegister(self: *Self, name: []const u8, value: u16) Error!void {
            if (@intFromEnum(self.mode) >= @intFromEnum(self.register_mode_map[try self.getRegisterID(name)])) {
                (try self.getRegister(name)).set(value);
            } else {
                return error.invalid_access;
            }
        }

        pub fn setRegisterById(self: *Self, id: u8, value: u16) Error!void {
            if (@intFromEnum(self.mode) >= @intFromEnum(self.register_mode_map[id])) {
                (try self.getRegisterByID(id)).set(value);
            } else {
                return error.invalid_access;
            }
        }

        pub fn setRegisterMode(self: *Self, name: []const u8, value: Mode) Error!void {
            if (@intFromEnum(self.mode) >= @intFromEnum(value)) {
                const index = try self.getRegisterID(name);
                self.register_mode_map[index] = value;
            } else {
                return error.invalid_access;
            }
        }

        pub fn step(self: *Self) !void {
            var program_counter = self.getRegister("pc") catch {
                return error.no_program_counter;
            };
            const memory_reader = self.memory.getReader();
            const op_code: u8 = memory_reader.readAs(program_counter.get(), u8);
            program_counter.set(program_counter.value + 1);
            //TODO make formats auto generated
            const signature = instructions.signatures[op_code];
            var arguments: [instructions.MAX_ARGUMENTS]instructions.Argument = undefined;
            for (signature.arguments, 0..signature.arguments.len) |argument_type, index| {
                var argument: instructions.Argument = undefined;

                switch (argument_type) {
                    .register => {
                        argument = instructions.Argument{
                            .register = memory_reader.readAs(program_counter.get(), u8),
                        };
                    },
                    .immediate => {
                        argument = instructions.Argument{
                            .immediate = memory_reader.readAs(program_counter.get(), u16),
                        };
                    },
                    .address => {
                        argument = instructions.Argument{
                            .address = memory_reader.readAs(program_counter.get(), u16),
                        };
                    },
                }
                program_counter.set(program_counter.value + argument.activeSize());
                arguments[index] = argument;
            }
            try self.execute(@enumFromInt(op_code), &arguments);
        }

        fn execute(self: *Self, op_code: OpCode, arguments: []instructions.Argument) !void {
            const memory_reader = self.memory.getReader();
            const memory_writer = self.memory.getWriter();
            switch (op_code) {
                .move_im_reg => {
                    const im_val = arguments[0].immediate;
                    const r_dest = arguments[1].register;
                    try self.setRegisterById(r_dest, im_val);
                },
                .move_reg_reg => {
                    const r_source = try self.getRegisterByID(arguments[0].register);
                    const r_dest = arguments[1].register;
                    try self.setRegisterById(r_dest, r_source.get());
                },
                .move_addr_reg => {
                    const address = arguments[0].address;
                    const value = memory_reader.readAs(address, u16);
                    const r_dest = arguments[1].register;
                    try self.setRegisterById(r_dest, value);
                },
                .move_im_addr => {
                    const im_val = arguments[0].immediate;
                    const address = arguments[1].address;
                    _ = memory_writer.writeValue(address, im_val);
                },
                .move_reg_addr => {
                    const r_source = arguments[0].register;
                    const register = try self.getRegisterByID(r_source);
                    const address = arguments[1].address;
                    _ = memory_writer.writeValue(address, register.get());
                },
                .move_indirect_reg_reg => {
                    const r_source = arguments[0].register;
                    const reg_source = try self.getRegisterByID(r_source);
                    const address = reg_source.get();
                    const r_dest = arguments[1].register;
                    const value = memory_reader.readAs(address, u16);
                    try self.setRegisterById(r_dest, value);
                },
                .add_im_reg => {
                    if (self.hasRegister("acc")) {
                        const im_val = arguments[0].immediate;
                        const r = arguments[1].register;
                        const value = (try self.getRegisterByID(r)).get();
                        try self.setRegister("acc", im_val + value);
                    } else {
                        return error.no_accumulator;
                    }
                },
                .add_reg_reg => {
                    if (self.hasRegister("acc")) {
                        const ra = arguments[0].register;
                        const rb = arguments[1].register;
                        const val_a = (try self.getRegisterByID(ra)).get();
                        const val_b = (try self.getRegisterByID(rb)).get();
                        try self.setRegister("acc", val_a + val_b);
                    } else {
                        return error.no_accumulator;
                    }
                },
                else => {},
            }
        }
    };
}

const testing = std.testing;

test "creating setting getting and getting invalid registers" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    try testing.expectEqual(0, (try tcpu.getRegister("r1")).value);
    try tcpu.setRegister("r1", 420);
    try testing.expectEqual(420, (try tcpu.getRegister("r1")).value);
    try testing.expectEqual(0, (try tcpu.getRegister("r2")).value);

    try testing.expectError(error.unknown_register, tcpu.getRegister("r3"));
    try testing.expectError(error.unknown_register, tcpu.setRegister("r3", 0));
}

test "move_im_reg" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "r1" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg),
        0x24,
        0x12,
        try tcpu.getRegisterID("r1"),
    };
    tcpu.memory.load(&static_buffer);
    try testing.expectEqual(0, (try tcpu.getRegister("pc")).value);
    try tcpu.step();
    try testing.expectEqual(4, (try tcpu.getRegister("pc")).value);
    try testing.expectEqual(0x1224, (try tcpu.getRegister("r1")).value);
}

test "move_reg_reg" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg),
        0x24,
        0x12,
        try tcpu.getRegisterID("r1"),
        @intFromEnum(OpCode.move_reg_reg),
        try tcpu.getRegisterID("r1"),
        try tcpu.getRegisterID("r2"),
    };
    tcpu.memory.load(&static_buffer);
    try testing.expectEqual(0, (try tcpu.getRegister("pc")).value);
    try tcpu.step();
    try tcpu.step();
    try testing.expectEqual(7, (try tcpu.getRegister("pc")).value);
    try testing.expectEqual(0x1224, (try tcpu.getRegister("r1")).value);
    try testing.expectEqual(0x1224, (try tcpu.getRegister("r2")).value);
}

test "security" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg),
        0x24,
        0x12,
        try tcpu.getRegisterID("r1"),
        @intFromEnum(OpCode.move_reg_reg),
        try tcpu.getRegisterID("r1"),
        try tcpu.getRegisterID("r2"),
    };
    try tcpu.setRegisterMode("r2", .kernel);
    tcpu.mode = .user;
    tcpu.memory.load(&static_buffer);
    try testing.expectEqual(0, (try tcpu.getRegister("pc")).value);
    try tcpu.step();
    try testing.expectError(error.invalid_access, tcpu.step());
}

test "add_reg_reg" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "acc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg),
        0x24,
        0x12,
        try tcpu.getRegisterID("r1"),
        @intFromEnum(OpCode.move_im_reg),
        0x13,
        0x00,
        try tcpu.getRegisterID("r2"),
        @intFromEnum(OpCode.add_reg_reg),
        try tcpu.getRegisterID("r1"),
        try tcpu.getRegisterID("r2"),
    };
    tcpu.memory.load(&static_buffer);
    try tcpu.step();
    try testing.expectEqual(0x1224, (try tcpu.getRegister("r1")).get());
    try tcpu.step();
    try testing.expectEqual(0x0013, (try tcpu.getRegister("r2")).get());
    try tcpu.step();
    try testing.expectEqual(0x1237, (try tcpu.getRegister("acc")).get());
}

test "add_im_reg" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "acc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg),
        0x24,
        0x12,
        try tcpu.getRegisterID("r1"),
        @intFromEnum(OpCode.add_im_reg),
        0x13,
        0x00,
        try tcpu.getRegisterID("r1"),
    };
    tcpu.memory.load(&static_buffer);
    try tcpu.step();
    try testing.expectEqual(0x1224, (try tcpu.getRegister("r1")).get());
    try tcpu.step();
    try testing.expectEqual(0x1237, (try tcpu.getRegister("acc")).get());
}

test "move_im_addr" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "acc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_addr),
        0x24,
        0x12,
        0xE8,
        0x03,
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1224, mem_reader.readAs(0x03E8, u16));
}

test "move_reg_addr" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "acc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_reg),
        0x34,
        0x12,
        try tcpu.getRegisterID("r1"),
        @intFromEnum(OpCode.move_reg_addr),
        try tcpu.getRegisterID("r1"),
        0xE8,
        0x03,
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    try testing.expectEqual(0x1234, (try tcpu.getRegister("r1")).get());
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1234, mem_reader.readAs(0x03E8, u16));
}

test "move_addr_reg" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "acc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_addr),
        0x34,
        0x12,
        0xE8,
        0x03,
        @intFromEnum(OpCode.move_addr_reg),
        0xE8,
        0x03,
        try tcpu.getRegisterID("r1"),
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1234, mem_reader.readAs(0x03E8, u16));
    try tcpu.step();
    try testing.expectEqual(0x1234, (try tcpu.getRegister("r1")).get());
}

test "move_indirect_reg_reg" {
    const options = CPUOptions{
        .register_names = &[_][]const u8{ "pc", "acc", "r1", "r2" },
    };
    const TCPU = CPU(options);
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_addr),
        0x34,
        0x12,
        0xE8,
        0x03,
        @intFromEnum(OpCode.move_im_reg),
        0xE8,
        0x03,
        try tcpu.getRegisterID("r1"),
        @intFromEnum(OpCode.move_indirect_reg_reg),
        try tcpu.getRegisterID("r1"),
        try tcpu.getRegisterID("r2"),
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1234, mem_reader.readAs(0x03E8, u16));
    try tcpu.step();
    try testing.expectEqual(0x03E8, (try tcpu.getRegister("r1")).get());
    try tcpu.step();
    try testing.expectEqual(0x1234, (try tcpu.getRegister("r2")).get());
}
