const std = @import("std");
const builtin = @import("builtin");
const instructions = @import("./common/instructions.zig");
const OpCode = instructions.OpCode;

const Memory = @import("./memory.zig");

pub const CPUOptions = struct {
    endianness: std.builtin.Endian = builtin.cpu.arch.endian(),
};

pub const Error = error{
    unknown_register,
    invalid_access,
};

pub fn CPU(comptime options: CPUOptions) type {
    return struct {
        const Self = @This();
        pub const Register = enum {
            pc,
            sp,
            bp,
            acu,
            a,
            b,
            c,
            d,
            h,
            l,
            hl,
            MAX,

            pub const Size = enum {
                u16,
                u32,
            };
        };

        registers: [@intFromEnum(Register.MAX) - 1]u16 = std.mem.zeroes([@intFromEnum(Register.MAX) - 1]u16),
        memory: Memory,
        stack: Memory.View,

        pub fn init(memory: Memory) Self {
            var result = Self{
                .memory = memory,
            };
            result.memory.endianness = options.endianness;
            return result;
        }

        pub fn getRegister(self: *Self, comptime size: Register.Size, which: Register) Error!*switch (size) {
            .u16 => u16,
            .u32 => u32,
        } {
            if (@intFromEnum(which) >= @intFromEnum(Register.MAX)) {
                return error.unknown_register;
            }
            return switch (size) {
                .u16 => switch (which) {
                    .hl => error.unknown_register,
                    else => @ptrCast(&self.registers[@intFromEnum(which)]),
                },
                .u32 => switch (which) {
                    .hl => @ptrCast(&self.registers[@intFromEnum(which)]),
                    else => error.unknown_register,
                },
            };
        }

        pub fn step(self: *Self) !void {
            const memory_reader = self.memory.getReader();
            const pc = try self.getRegister(.u16, .pc);
            const op_code: u8 = memory_reader.readAs(pc.*, u8);
            pc.* += 1;
            //TODO make formats auto generated
            const signature = instructions.signatures[op_code];
            var arguments: [instructions.MAX_ARGUMENTS]instructions.Argument = undefined;
            for (signature.arguments, 0..signature.arguments.len) |argument_type, index| {
                var argument: instructions.Argument = undefined;

                switch (argument_type) {
                    .register => {
                        argument = instructions.Argument{
                            .register = memory_reader.readAs(pc.*, u8),
                        };
                    },
                    .immediate => {
                        argument = instructions.Argument{
                            .immediate = memory_reader.readAs(pc.*, u16),
                        };
                    },
                    .address => {
                        argument = instructions.Argument{
                            .address = memory_reader.readAs(pc.*, u16),
                        };
                    },
                }
                pc.* += argument.activeSize();
                arguments[index] = argument;
            }
            try self.execute(@enumFromInt(op_code), &arguments);
        }

        fn execute(self: *Self, op_code: OpCode, arguments: []instructions.Argument) !void {
            const memory_reader = self.memory.getReader();
            const memory_writer = self.memory.getWriter();
            switch (op_code) {
                .move_im_reg => {
                    const r_dest = (try self.getRegister(.u16, @enumFromInt(arguments[0].register)));
                    const im_val = arguments[1].immediate;
                    r_dest.* = im_val;
                },
                .move_reg_reg => {
                    const r_dest = try self.getRegister(.u16, @enumFromInt(arguments[0].register));
                    const r_source = try self.getRegister(.u16, @enumFromInt(arguments[1].register));
                    r_dest.* = r_source.*;
                },
                .move_addr_reg => {
                    const r_dest = try self.getRegister(.u16, @enumFromInt(arguments[0].register));
                    const src_address = arguments[1].address;
                    const value = memory_reader.readAs(src_address, u16);
                    r_dest.* = value;
                },
                .move_im_addr => {
                    const dest_address = arguments[0].address;
                    const im_val = arguments[1].immediate;
                    _ = memory_writer.writeValue(dest_address, im_val);
                },
                .move_reg_addr => {
                    const dest_address = arguments[0].address;
                    const r_source = try self.getRegister(.u16, @enumFromInt(arguments[1].register));
                    _ = memory_writer.writeValue(dest_address, r_source.*);
                },
                .move_indirect_reg_reg => {
                    const r_dest = try self.getRegister(.u16, @enumFromInt(arguments[0].register));
                    const reg_source = try self.getRegister(.u16, @enumFromInt(arguments[1].register));
                    const address = reg_source.*;
                    const value = memory_reader.readAs(address, u16);
                    r_dest.* = value;
                },
                .add_im_reg => {
                    const register = try self.getRegister(.u16, @enumFromInt(arguments[0].register));
                    const im_val = arguments[1].immediate;
                    const acu = try self.getRegister(.u16, .acu);
                    acu.* = register.* + im_val;
                },
                .add_reg_reg => {
                    const register_a = try self.getRegister(.u16, @enumFromInt(arguments[0].register));
                    const register_b = try self.getRegister(.u16, @enumFromInt(arguments[1].register));
                    const acu = try self.getRegister(.u16, .acu);
                    acu.* = register_a.* + register_b.*;
                },
                else => {},
            }
        }
    };
}

const testing = std.testing;

test "move_im_reg" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg), // = a $1224
        @intFromEnum(TCPU.Register.a),
        0x24,
        0x12,
    };
    tcpu.memory.load(&static_buffer);
    try testing.expectEqual(0, (try tcpu.getRegister(.u16, .pc)).*);
    try tcpu.step();
    try testing.expectEqual(4, (try tcpu.getRegister(.u16, .pc)).*);
    try testing.expectEqual(0x1224, (try tcpu.getRegister(.u16, .a)).*);
}

test "move_reg_reg" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg), // = a $1224
        @intFromEnum(TCPU.Register.a),
        0x24,
        0x12,
        @intFromEnum(OpCode.move_reg_reg), // = b a
        @intFromEnum(TCPU.Register.b),
        @intFromEnum(TCPU.Register.a),
    };
    tcpu.memory.load(&static_buffer);
    try testing.expectEqual(0, (try tcpu.getRegister(.u16, .pc)).*);
    try tcpu.step();
    try tcpu.step();
    try testing.expectEqual(7, (try tcpu.getRegister(.u16, .pc)).*);
    try testing.expectEqual(0x1224, (try tcpu.getRegister(.u16, .a)).*);
    try testing.expectEqual(0x1224, (try tcpu.getRegister(.u16, .b)).*);
}

test "add_reg_reg" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg), // = a $1224
        @intFromEnum(TCPU.Register.a),
        0x24,
        0x12,
        @intFromEnum(OpCode.move_im_reg), // = b $0013
        @intFromEnum(TCPU.Register.b),
        0x13,
        0x00,
        @intFromEnum(OpCode.add_reg_reg),
        @intFromEnum(TCPU.Register.a),
        @intFromEnum(TCPU.Register.b),
    };
    tcpu.memory.load(&static_buffer);
    try tcpu.step();
    try testing.expectEqual(0x1224, (try tcpu.getRegister(.u16, .a)).*);
    try tcpu.step();
    try testing.expectEqual(0x0013, (try tcpu.getRegister(.u16, .b)).*);
    try tcpu.step();
    try testing.expectEqual(0x1237, (try tcpu.getRegister(.u16, .acu)).*);
}

test "add_im_reg" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer = [_]u8{
        @intFromEnum(OpCode.move_im_reg), // = a $1224
        @intFromEnum(TCPU.Register.a),
        0x24,
        0x12,
        @intFromEnum(OpCode.add_im_reg), // + a $0013
        @intFromEnum(TCPU.Register.a),
        0x13,
        0x00,
    };
    tcpu.memory.load(&static_buffer);
    try tcpu.step();
    try testing.expectEqual(0x1224, (try tcpu.getRegister(.u16, .a)).*);
    try tcpu.step();
    try testing.expectEqual(0x1237, (try tcpu.getRegister(.u16, .acu)).*);
}

test "move_im_addr" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_addr), // = @$03E8 $1224
        0xE8,
        0x03,
        0x24,
        0x12,
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1224, mem_reader.readAs(0x03E8, u16));
}

test "move_reg_addr" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_reg), // = a $1234
        @intFromEnum(TCPU.Register.a),
        0x34,
        0x12,
        @intFromEnum(OpCode.move_reg_addr), // = @$03E8 a
        0xE8,
        0x03,
        @intFromEnum(TCPU.Register.a),
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    try testing.expectEqual(0x1234, (try tcpu.getRegister(.u16, .a)).*);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1234, mem_reader.readAs(0x03E8, u16));
}

test "move_addr_reg" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_addr), // = @$03E8 $1234
        0xE8,
        0x03,
        0x34,
        0x12,
        @intFromEnum(OpCode.move_addr_reg), // = a @$03E8
        @intFromEnum(TCPU.Register.a),
        0xE8,
        0x03,
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1234, mem_reader.readAs(0x03E8, u16));
    try tcpu.step();
    try testing.expectEqual(0x1234, (try tcpu.getRegister(.u16, .a)).*);
}

test "move_indirect_reg_reg" {
    const TCPU = CPU(.{});
    var tcpu = TCPU.init(Memory.init());
    var static_buffer: [1024]u8 = undefined;
    const code = [_]u8{
        @intFromEnum(OpCode.move_im_addr), // = @$03E8 $1234
        0xE8,
        0x03,
        0x34,
        0x12,
        @intFromEnum(OpCode.move_im_reg), // = a $03E8
        @intFromEnum(TCPU.Register.a),
        0xE8,
        0x03,
        @intFromEnum(OpCode.move_indirect_reg_reg), // = b a
        @intFromEnum(TCPU.Register.b),
        @intFromEnum(TCPU.Register.a),
    };
    tcpu.memory.load(&static_buffer);
    const mem_writer = tcpu.memory.getWriter();
    _ = mem_writer.writeAt(0, &code);
    try tcpu.step();
    const mem_reader = tcpu.memory.getReader();
    try testing.expectEqual(0x1234, mem_reader.readAs(0x03E8, u16));
    try tcpu.step();
    try testing.expectEqual(0x03E8, (try tcpu.getRegister(.u16, .a)).*);
    try tcpu.step();
    try testing.expectEqual(0x1234, (try tcpu.getRegister(.u16, .b)).*);
}
