const std = @import("std");
const vm_lib = @import("vm-lib");

usingnamespace vm_lib;

const KB = 1024;

const Registers = enum(u8) {
    AB = 1,
    A = 2,
    B = 3,
    HL = 4,
    H = 5,
    L = 6,
    PC = 7,
    SP = 8,
    BP = 9,
};

fn setup_fn(ctx: *vm_lib.Machine) !void {
    try ctx.registers[@intFromEnum(Registers.A)].set(u8, 0x12);
    try ctx.registers[@intFromEnum(Registers.SP)].set(u8, 0x12);
}

fn step_fn(ctx: *vm_lib.Machine) !bool {
    _ = ctx;
    return false;
}

pub fn main() !void {
    var memory_block: [12]u8 = std.mem.zeroes([12]u8);
    const memory: vm_lib.Memory = vm_lib.Memory.init(&memory_block);
    const registers: []vm_lib.Register = @constCast(&[_]vm_lib.Register{
        vm_lib.Register.Invalid,
        vm_lib.Register{ // AB
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
