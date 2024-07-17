const std = @import("std");
const vm_lib = @import("vm-lib");
const isa = @import("./isa.zig");
const ISA8Bit = isa.ISA8Bit;

usingnamespace vm_lib;

const KB = 1024;

const Registers = enum(u8) {
    AB = 0,
    A = 1,
    B = 2,
    HL = 3,
    H = 4,
    L = 5,
    PC = 6,
    SP = 7,
    BP = 8,
};

fn setup_fn(ctx: *vm_lib.Machine) !void {
    try ctx.registers[@intFromEnum(Registers.A)].set(u8, 0x12);
    try ctx.registers[@intFromEnum(Registers.SP)].set(u8, 0x12);
    try ctx.load_program(ctx.register_offset, &[_]u8{ 0x00, 0x01, 0x0F });
}

fn step_fn(ctx: *vm_lib.Machine) !bool {
    const pc: *u8 = @ptrCast(ctx.registers[@intFromEnum(Registers.PC)].value.ptr);
    const byte: u8 = (ctx.memory.read(pc.* + ctx.register_offset, 1) catch return false)[0];
    pc.* += 1;
    switch (@as(ISA8Bit, @enumFromInt(byte))) {
        .Imm => {
            const register: u8 = (try ctx.memory.read(pc.* + ctx.register_offset, 1))[0];
            pc.* += 1;
            const value: u8 = (try ctx.memory.read(pc.* + ctx.register_offset, 1))[0];
            pc.* += 1;
            try ctx.registers[register].set(u8, value);
        },
        else => {
            return false;
        },
    }
    return true;
}

pub fn main() !void {
    var memory_block: [12]u8 = std.mem.zeroes([12]u8);
    const memory: vm_lib.Memory = vm_lib.Memory.init(&memory_block);
    const registers: []vm_lib.Register = @constCast(&[_]vm_lib.Register{
        vm_lib.Register{ // AB
            .is_masking = true,
            .width = 2,
            .value = memory.data[0..2],
        },
        vm_lib.Register{ // A
            .width = 1,
            .value = memory.data[0..1],
        },
        vm_lib.Register{ // B
            .width = 1,
            .value = memory.data[1..2],
        },
        vm_lib.Register{ // HL
            .is_masking = true,
            .width = 2,
            .value = memory.data[2..4],
        },
        vm_lib.Register{ // H
            .width = 1,
            .value = memory.data[2..3],
        },
        vm_lib.Register{ // L
            .width = 2,
            .value = memory.data[3..4],
        },
        vm_lib.Register{ // PC
            .width = 2,
            .value = memory.data[4..6],
        },
        vm_lib.Register{ // SP
            .width = 1,
            .value = memory.data[6..7],
        },
        vm_lib.Register{ // BP
            .width = 1,
            .value = memory.data[7..8],
        },
    });

    var machine: vm_lib.Machine = vm_lib.Machine{
        .registers = registers,
        .memory = memory,
        .setup_fn = setup_fn,
        .step_fn = step_fn,
    };
    std.debug.print("\n{any}\n", .{machine.memory});
    try machine.run();
    std.debug.print("\n{any}\n", .{machine.memory});
}
