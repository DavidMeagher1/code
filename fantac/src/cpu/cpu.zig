gpa: std.mem.Allocator,
working_stack: Stack,
return_stack: Stack,
scratch_stack: Stack,
memory: []u8,
reset_vector_position: u16,
nmi_vector_position: u16,
irq_vector_position: u16,
interrupt_mask_position: u16,
pc: u16 = 0,

pub const Error = error{
    invalidMicroCode,
};

pub const Stack = stack.Stack(2);

pub const MicroCode = enum(u8) {
    store,
    load,
    literal,
    pop,
    swap,
    over,
    nip,
    rot,
    add,
    sub,
    mul,
    div,
    rem,
    binary_and,
    binary_or,
    binary_xor,
    shift_left,
    shift_right,
    equal,
    less_than,
    greater_than,
    stash,
    unstash,
    jump,
    jump_im,
    jump_conditional,
    jump_subroutine,
    jump_subroutine_im,
    jump_interrupt,
    return_subroutine,
    return_interrupt,

    store2,
    load2,
    pop2,
    swap2,
    over2,
    nip2,
    rot2,
    add2,
    sub2,
    mul2,
    div2,
    rem2,
    binary_and2,
    binary_or2,
    binary_xor2,
    shift_left2,
    shift_right2,
    equal2,
    less_than2,
    greater_than2,
    stash2,
    unstash2,

    hault,
    nop,
    MAX,
};

pub const CPUOptions = struct {
    working_stack_size: u16 = 0xFF,
    return_stack_size: u16 = 0xFF,
    scratch_stack_size: u16 = 0xFF,
    memory_size: u16 = 0xFFFF,
    reset_vector_position: u16 = 0,
    nmi_vector_position: u16 = 2,
    irq_vector_position: u16 = 4,
    interrupt_mask_position: u16 = 6,
};

pub fn init(gpa: std.mem.Allocator, options: CPUOptions) !CPU {
    return CPU{
        .gpa = gpa,
        .working_stack = Stack.init(try gpa.alloc(u8, options.working_stack_size)),
        .return_stack = Stack.init(try gpa.alloc(u8, options.return_stack_size)),
        .scratch_stack = Stack.init(try gpa.alloc(u8, options.scratch_stack_size)),
        .memory = try gpa.alloc(u8, options.memory_size),
        .reset_vector_position = options.reset_vector_position,
        .nmi_vector_position = options.nmi_vector_position,
        .irq_vector_position = options.irq_vector_position,
        .interrupt_mask_position = options.interrupt_mask_position,
    };
}

pub fn reset(self: *CPU) void {
    const address = std.mem.bytesToValue(
        u16,
        self.memory[self.reset_vector_position .. self.reset_vector_position + 2],
    );
    const interrupt_mask = std.mem.bytesAsValue(
        u16,
        self.memory[self.interrupt_mask_position .. self.interrupt_mask_position + 2],
    );
    interrupt_mask.* = 0xFFFF;
    self.pc = address;
    self.working_stack.clear();
    self.return_stack.clear();
    self.scratch_stack.clear();
}

pub fn interrupt(self: *CPU, interrupt_id: u16, maskable: bool) !void {
    if (maskable) {
        const interrupt_mask = std.mem.bytesToValue(
            u16,
            self.memory[self.interrupt_mask_position .. self.interrupt_mask_position + 2],
        );
        if (interrupt_mask & interrupt_id != interrupt_id) return;
    }
    try self.scratch_stack.push(interrupt_id);
    try self.return_stack.push(self.pc);
    const ws = self.working_stack;
    self.working_stack = self.scratch_stack;
    self.scratch_stack = ws;
    if (maskable) {
        self.pc = std.mem.bytesToValue(
            u16,
            self.memory[self.irq_vector_position .. self.irq_vector_position + 2],
        );
    } else {
        self.pc = std.mem.bytesToValue(
            u16,
            self.memory[self.nmi_vector_position .. self.nmi_vector_position + 2],
        );
    }
}

pub fn loadCode(self: *CPU, code: []const u8) void {
    @memcpy(self.memory[0..code.len], code);
}

pub fn step(self: *CPU) !bool {
    const mc_val = self.memory[self.pc];
    if (mc_val >= @intFromEnum(MicroCode.MAX)) return error.invalidMicroCode;
    const mc: MicroCode = @enumFromInt(mc_val);
    self.pc += 1;
    switch (mc) {
        .MAX => unreachable,
        .nop => {},
        .hault => {
            return false;
        },
        .store => {
            var value: u8 = undefined;
            try self.working_stack.pop(&value);
            var address: u16 = undefined;
            try self.working_stack.pop(&address);
            self.memory[address] = value;
        },
        .load => {
            var address: u16 = undefined;
            try self.working_stack.pop(&address);
            try self.working_stack.push(self.memory[address]);
        },
        .literal => {
            const im_val = self.memory[self.pc];
            self.pc += 1;
            try self.working_stack.push(im_val);
        },
        .pop => {
            try self.working_stack.drop(u8);
        },
        .swap => {
            try self.working_stack.swap(u8);
        },
        .over => {
            try self.working_stack.over(u8);
        },
        .nip => {
            try self.working_stack.nip(u8);
        },
        .rot => {
            try self.working_stack.rot(u8);
        },
        .add => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@addWithOverflow(a, b)[0]);
        },
        .sub => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@subWithOverflow(a, b)[0]);
        },
        .mul => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@mulWithOverflow(a, b)[0]);
        },
        .div => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@divFloor(a, b));
        },
        .rem => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a - (b * @divFloor(a, b)));
        },
        .binary_and => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a & b);
        },
        .binary_or => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a | b);
        },
        .binary_xor => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a ^ b);
        },
        .shift_left => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a <<| b);
        },
        .shift_right => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@divTrunc(a, b * 2));
        },
        .equal => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@as(u8, @intFromBool(a == b)));
        },
        .less_than => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@as(u8, @intFromBool(a < b)));
        },
        .greater_than => {
            var a: u8 = undefined;
            var b: u8 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@as(u8, @intFromBool(a > b)));
        },
        .stash => {
            var a: u8 = undefined;
            try self.working_stack.pop(&a);
            try self.return_stack.push(a);
        },
        .unstash => {
            var a: u8 = undefined;
            try self.return_stack.pop(&a);
            try self.working_stack.push(a);
        },
        .jump => {
            var address: u16 = undefined;
            try self.working_stack.pop(&address);
            self.pc = address;
        },
        .jump_im => {
            const address: u16 = std.mem.bytesToValue(u16, self.memory[self.pc .. self.pc + 2]);
            self.pc = address;
        },
        .jump_conditional => {
            var address: u16 = undefined;
            var condition: u8 = undefined;
            try self.working_stack.pop(&address);
            try self.working_stack.pop(&condition);
            if (condition == 0) {
                self.pc = address;
            }
        },
        .jump_subroutine => {
            var address: u16 = undefined;
            try self.working_stack.pop(&address);
            try self.return_stack.push(self.pc);
            self.pc = address;
        },
        .jump_subroutine_im => {
            const address: u16 = std.mem.bytesToValue(u16, self.memory[self.pc .. self.pc + 2]);
            self.pc += 2;
            try self.return_stack.push(self.pc);
            self.pc = address;
        },
        .jump_interrupt => {
            var interrupt_id: u8 = undefined;
            try self.working_stack.pop(&interrupt_id);
            try self.interrupt(interrupt_id, true);
        },
        .return_subroutine => {
            var return_address: u16 = undefined;
            try self.return_stack.pop(&return_address);
            self.pc = return_address;
        },
        .return_interrupt => {
            const ws = self.working_stack;
            self.working_stack = self.scratch_stack;
            self.scratch_stack = ws;
            self.scratch_stack.clear();
            var address: u16 = undefined;
            try self.return_stack.pop(&address);
            self.pc = address;
        },
        .store2 => {
            var value: [2]u8 = undefined;
            try self.working_stack.popBytes(2, &value);
            var address: u16 = undefined;
            try self.working_stack.pop(&address);
            @memcpy(self.memory[address .. address + 2], &value);
        },
        .load2 => {
            var address: u16 = undefined;
            try self.working_stack.pop(&address);
            try self.working_stack.pushBytes(self.memory[address .. address + 2]);
        },
        .pop2 => {
            try self.working_stack.drop(u16);
        },
        .swap2 => {
            try self.working_stack.swap(u16);
        },
        .over2 => {
            try self.working_stack.over(u16);
        },
        .nip2 => {
            try self.working_stack.nip(u16);
        },
        .rot2 => {
            try self.working_stack.rot(u16);
        },
        .add2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@addWithOverflow(a, b)[0]);
        },
        .sub2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@subWithOverflow(a, b)[0]);
        },
        .mul2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@mulWithOverflow(a, b)[0]);
        },
        .div2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@divFloor(a, b));
        },
        .rem2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a - (b * @divFloor(a, b)));
        },
        .binary_and2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a & b);
        },
        .binary_or2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a | b);
        },
        .binary_xor2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a ^ b);
        },
        .shift_left2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(a <<| b);
        },
        .shift_right2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@divTrunc(a, b * 2));
        },
        .equal2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@as(u8, @intFromBool(a == b)));
        },
        .less_than2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@as(u8, @intFromBool(a < b)));
        },
        .greater_than2 => {
            var a: u16 = undefined;
            var b: u16 = undefined;
            try self.working_stack.pop(&b);
            try self.working_stack.pop(&a);
            try self.working_stack.push(@as(u8, @intFromBool(a > b)));
        },
        .stash2 => {
            var a: u16 = undefined;
            try self.working_stack.pop(&a);
            try self.return_stack.push(a);
        },
        .unstash2 => {
            var a: u16 = undefined;
            try self.return_stack.pop(&a);
            try self.working_stack.push(a);
        },
    }
    return true;
}

test "basic stuff" {
    var buffer: [0x102FC]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    var cpu = try CPU.init(alloc, .{});
    cpu.loadCode(&[_]u8{
        0x08,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0xFF,
        0xFF,
        @intFromEnum(MicroCode.literal),
        0x69,
        @intFromEnum(MicroCode.literal),
        0x20,
        @intFromEnum(MicroCode.rem),
        @intFromEnum(MicroCode.hault),
    });
    cpu.reset();
    while (true) {
        if (!(try cpu.step())) {
            break;
        }
    }
    var result: u8 = undefined;
    try cpu.working_stack.peek(&result);
    std.debug.print("\n.mod:{}, %:{}\n", .{ result, 0x69 % 0x20 });
    try testing.expectEqual(0x69, result);
}

const CPU = @This();
const std = @import("std");
const testing = std.testing;
const stack = @import("stack.zig");
