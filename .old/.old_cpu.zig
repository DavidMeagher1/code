const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Stack = @import("./stack.zig").Stack(2);

const CPU = @This();

//TODO add bounds checking for jumps

pub const OpCode = enum(u8) {
    // byte ops
    move_byte_reg_im,
    move_byte_reg_reg,
    move_byte_reg_addr,
    move_byte_addr_im,
    move_byte_addr_reg,
    move_byte_indirect_rel_reg_reg,
    move_byte_indirect_zp_reg_reg,
    //math
    add_byte_reg_im,
    add_byte_reg_reg,
    sub_byte_reg_im,
    sub_byte_reg_reg,
    mul_byte_reg_im,
    mul_byte_reg_reg,
    div_byte_reg_im,
    div_byte_reg_reg,
    compare_byte_im,
    compare_byte_reg,

    //binary operations
    band_byte_im,
    band_byte_reg,
    bor_byte_im,
    bor_byte_reg,
    bxor_byte_im,
    bxor_byte_reg,

    // stack operations
    push_byte_im,
    push_byte_reg,
    pop_byte,
    peek_byte,
    swap_byte,
    rot_byte,
    drop_byte,
    nip_byte,
    dup_byte,
    over_byte,

    // short ops
    move_short_reg_im,
    move_short_reg_reg,
    move_short_reg_addr,
    move_short_addr_im,
    move_short_addr_reg,
    move_short_indirect_reg_reg,
    move_short_indirect_reg_im,
    //math
    add_short_reg_im,
    add_short_reg_reg,
    sub_short_reg_im,
    sub_short_reg_reg,
    mul_short_reg_im,
    mul_short_reg_reg,
    div_short_reg_im,
    div_short_reg_reg,
    compare_short_im,
    compare_short_reg,

    //binary operations
    band_short_im,
    band_short_reg,
    bor_short_im,
    bor_short_reg,
    bxor_short_im,
    bxor_short_reg,

    // stack operations
    push_short_im,
    push_short_reg,
    pop_short,
    peek_short,
    swap_short,
    rot_short,
    drop_short,
    nip_short,
    dup_short,
    over_short,

    short_jump,
    short_jump_eq,
    short_jump_lth,
    short_jump_gth,
    long_jump,
    long_jump_eq,
    long_jump_lth,
    long_jump_gth,

    jump_subroutine,
    return_subroutine,
    jump_software_interrupt,
    return_interrupt,
    set_carry,
    clear_carry,
    set_zero,
    clear_zero,
    set_interrupt_disable,
    clear_interrupt_disable,
    hault,
    nop, // no operation
    MAX,
};

pub const Register = enum(u8) {
    pc,
    sp,
    bp,
    st,
    im,
    a,
    al,
    ah,
    b,
    c,
    bc,
    d,
    e,
    f,
    g,
    MAX,
};

const StatusRegister = packed struct(u8) {
    negative: u1 = 0, // tells if the last operation produced a negative value
    overflow: u1 = 0, // tells if the last operation caused an overflow
    @"break": u1 = 0, // jsi sets this depending on what kind of interrupt its handeling?
    decimal: u1 = 0, // i dont need this so i will change its funcitonality
    interrupt_disable: u1 = 1,
    zero: u1 = 0, // tells if the last operation result was zero
    carry: u1 = 0, // after addition this is the carry result, after sub or compare this will be set if no borrow was the result or a greater than or equal result
    padding: u1 = 0,
};

pub const Error = error{
    UnknownRegister,
    RegisterWidthError,
    InvalidOpCode,
    InvalidAccess,
    StackOverflow,
    StackUnderflow,
};

pub const CPUOptions = struct {
    memory_size: u32,
    page_size: u16,
    stack_size: u12 = 0,
};

registers: packed struct {
    pc: u16 = 0,
    a: packed struct(u16) {
        l: u8 = 0,
        h: u8 = 0,
    } = .{},
    im: u16 = 0xFFFF,
    sp: u16 = 0, // 2
    bp: u16 = 0, // 4
    bc: packed struct(u16) {
        c: u8 = 0, // 16 // 15
        b: u8 = 0, // 15
    } = .{},
    d: u16 = 0,
    e: u16 = 0,
    f: u16 = 0,
    g: u16 = 0,
    st: StatusRegister = .{}, // 6
    // 21
} = .{},

gpa: Allocator,
endian: std.builtin.Endian = builtin.cpu.arch.endian(),
memory: []u8,
stack: Stack = undefined,
running: bool = false,

pub fn init(gpa: Allocator, options: CPUOptions) !CPU {
    var result = CPU{
        .gpa = gpa,
        .memory = try gpa.alloc(u8, options.memory_size),
    };
    const stack_position = options.page_size - options.stack_size;
    result.stack = Stack{
        .buffer = result.memory[stack_position .. stack_position + options.stack_size],
        .sp = options.stack_size,
        .base_addr = stack_position,
    };
    result.registers.sp = options.page_size;
    result.registers.bp = result.registers.sp;
    return result;
}

pub fn reset(self: *CPU) void {
    const reset_offset = std.mem.bytesToValue(u32, self.memory[0..2]);
    self.registers.pc = reset_offset;
    self.running = true;
}

/// converts a buffer to this cpu's endian
pub fn fromNativeEndian(self: CPU, comptime T: type, x: T) T {
    std.mem.nativeTo(T, x, self.endian);
}

pub fn toNativeEndian(self: CPU, comptime T: type, x: T) T {
    std.mem.toNative(T, x, self.endian);
}

inline fn getRegister(self: *CPU, id: Register) Error![]u8 {
    if (@intFromEnum(id) >= @intFromEnum(Register.MAX)) {
        return error.UnknownRegister;
    }
    return switch (id) {
        .pc => std.mem.asBytes(&self.registers.addr.pc),
        .sp => std.mem.asBytes(&self.registers.sp),
        .bp => std.mem.asBytes(&self.registers.bp),
        .st => std.mem.asBytes(&self.registers.st),
        .im => std.mem.asBytes(&self.registers.im),
        .a => std.mem.asBytes(&self.registers.a),
        .al => std.mem.asBytes(&self.registers.a.l),
        .ah => std.mem.asBytes(&self.registers.a.h),
        .bc => std.mem.asBytes(&self.registers.bc),
        .b => std.mem.asBytes(&self.registers.bc.b),
        .c => std.mem.asBytes(&self.registers.bc.c),
        .d => std.mem.asBytes(&self.registers.d),
        .e => std.mem.asBytes(&self.registers.e),
        .f => std.mem.asBytes(&self.registers.f),
        .g => std.mem.asBytes(&self.registers.g),
        else => unreachable,
    };
}

inline fn isZero(x: anytype) u1 {
    _ = @typeInfo(@TypeOf(x)).int;
    return 1 ^ @subWithOverflow(0, x)[1];
}

inline fn sign(x: anytype) u1 {
    _ = @typeInfo(@TypeOf(x)).int;
    const shift_amount = ((@sizeOf(@TypeOf(x)) * 8) - 1);
    return @intCast(@shrExact(x & @shlExact(1, shift_amount), shift_amount) & 1);
}

fn saveContext(self: *CPU) !void {
    _ = try self.stack.push(std.mem.asBytes(&self.registers.pc));
    if (self.registers.st.@"break" == 0) {
        _ = try self.stack.push(std.mem.asBytes(&self.registers.a));
    }
    _ = try self.stack.push(std.mem.asBytes(&self.registers.im));
    _ = try self.stack.push(std.mem.asBytes(&self.registers.bp));
    _ = try self.stack.push(std.mem.asBytes(&self.registers.bc));
    _ = try self.stack.push(std.mem.asBytes(&self.registers.d));
    _ = try self.stack.push(std.mem.asBytes(&self.registers.e));
    _ = try self.stack.push(std.mem.asBytes(&self.registers.f));
    _ = try self.stack.push(std.mem.asBytes(&self.registers.g));
    self.registers.sp = try self.stack.push(std.mem.asBytes(&self.registers.st));
}

fn loadContext(self: *CPU) !void {
    self.registers.st = std.mem.bytesToValue(StatusRegister, (try self.stack.pop(1))[0]);
    self.registers.g = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    self.registers.f = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    self.registers.e = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    self.registers.d = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    @as(*u16, @ptrCast(&self.registers.bc)).* = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    self.registers.bp = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    self.registers.im = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    if (self.registers.st.@"break" == 0) {
        @as(*u16, @ptrCast(&self.registers.a)).* = std.mem.bytesToValue(u16, (try self.stack.pop(2))[0]);
    }
    const last_result = try self.stack.pop(2);
    self.registers.pc = std.mem.bytesToValue(u16, last_result[0]);
    self.registers.sp = last_result[1];
}

fn interrupt(self: *CPU, irq_id: u16, maskable: bool, hardware: bool) !void {
    //all interrupts are disabled by default even non maskable ones
    // this should be turned off as soon as you are ready to handle them
    if ((maskable and self.registers.st.interrupt_disable == 1) or (maskable and self.registers.im & irq_id != irq_id)) {
        return;
    }
    if (hardware) {
        self.registers.st.@"break" = 0;
    } else {
        self.registers.st.@"break" = 1;
    }
    self.registers.st.interrupt_disable = 1;
    try self.saveContext();
    self.registers.sp = try self.stack.push(std.mem.asBytes(&irq_id));
    if (maskable) {
        self.registers.pc = std.mem.bytesToValue(u16, self.memory[4..6]);
    } else {
        self.registers.pc = std.mem.bytesToValue(u16, self.memory[2..4]);
    }
}

pub fn hardwareInterrupt(self: *CPU, irq_id: u16, maskable: bool) void {
    self.interrupt(irq_id, maskable, true);
}

pub fn step(self: *CPU) !bool {
    if (!self.running) {
        return false;
    }
    const pc: *u16 = &self.registers.pc;
    const acu: *u16 = @as(*u16, @ptrCast(&self.registers.a));
    const op_code: OpCode = @enumFromInt(self.memory[pc.*]);
    if (@intFromEnum(op_code) >= @intFromEnum(OpCode.MAX)) {
        return error.InvalidOpCode;
    }
    pc.* += 1;
    switch (op_code) {
        .nop, .MAX => {},
        .move_byte_reg_im => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;

            const im_val = self.memory[pc.* .. pc.* + 1];
            @memcpy(dest[0..1], im_val);
            pc.* += 1;
        },
        .move_byte_reg_reg => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const src = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            @memcpy(dest[0..1], src[0..1]);
        },
        .move_byte_reg_addr => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const addr = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            const payload = self.memory[addr .. addr + 1];
            pc.* += 2;
            @memcpy(dest[0..1], payload);
        },
        .move_byte_addr_im => {
            const addr = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            const dest = self.memory[addr .. addr + 1];
            pc.* += 2;
            const im_val = self.memory[pc.* .. pc.* + 1];
            pc.* += 1;
            @memcpy(dest, im_val);
        },
        .move_byte_addr_reg => {
            const addr = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            const dest = self.memory[addr .. addr + 1];
            pc.* += 2;
            const register = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            @memcpy(dest, register[0..1]);
        },
        .move_byte_indirect_reg_reg => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const addr = std.mem.bytesToValue(u16, try self.getRegister(@enumFromInt(self.memory[pc.*])));
            pc.* += 1;
            const payload = self.memory[addr .. addr + 1];
            @memcpy(dest[0..1], payload);
        },
        .move_byte_indirect_reg_im => {
            const addr = std.mem.bytesToValue(u16, try self.getRegister(@enumFromInt(self.memory[pc.*])));
            pc.* += 1;
            const im_val = self.memory[pc.* .. pc.* + 1];
            pc.* += 1;
            const memory = self.memory[addr .. addr + 1];
            @memcpy(memory, im_val);
        },
        //math // these all effect a.l
        .add_byte_reg_im => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @addWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @addWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .add_byte_reg_reg => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @addWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @addWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .sub_byte_reg_im => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @subWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @subWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .sub_byte_reg_reg => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @subWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @subWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .mul_byte_reg_im => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            const result = @mulWithOverflow(a, b);
            self.registers.st.carry = result[1];
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .mul_byte_reg_reg => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const result = @subWithOverflow(a, b);
            self.registers.st.carry = result[1];
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .div_byte_reg_im => { // division puts the product in the top byte of a and the remainder in the low byte a
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            const product: u8 = @divFloor(a, b);
            const remainder: u8 = a - product;
            self.registers.a.l = remainder;
            self.register.a.h = product;
            self.registers.st.negative = sign(product);
            self.registers.st.zero = isZero(product);
        },
        .div_byte_reg_reg => {
            const a: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const b: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const product: u8 = @divFloor(a, b);
            const remainder: u8 = a - product;
            self.registers.a.l = remainder;
            self.register.a.h = product;
            self.registers.st.negative = sign(product);
            self.registers.st.zero = isZero(product);
        },
        .compare_byte_im => {
            const im_val: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            const product = @subWithOverflow(acu.*, im_val);
            self.registers.st.carry = 1 ^ (product[1] & isZero(product[0]));
            self.registers.st.zero = isZero(product[0]);
        },
        .compare_byte_reg => {
            const register: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            const product = @subWithOverflow(acu.*, register);
            self.registers.st.carry = 1 ^ (product[1] & isZero(product[0]));
            self.registers.st.zero = isZero(product[0]);
        },

        //binary operations
        .band_byte_im => {
            const im_val: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            acu.* &= @as(u16, @intCast(im_val));
        },
        .band_byte_reg => {
            const register: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            acu.* &= @as(u16, @intCast(register));
        },
        .bor_byte_im => {
            const im_val: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            acu.* |= @as(u16, @intCast(im_val));
        },
        .bor_byte_reg => {
            const register: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            acu.* |= @as(u16, @intCast(register));
        },
        .bxor_byte_im => {
            const im_val: u8 = std.mem.bytesToValue(u8, self.memory[pc.* .. pc.* + 1]);
            pc.* += 1;
            acu.* ^= @as(u16, @intCast(im_val));
        },
        .bxor_byte_reg => {
            const register: u8 = std.mem.bytesToValue(u8, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1]);
            pc.* += 1;
            acu.* ^= @as(u16, @intCast(register));
        },

        // stack operations
        .push_byte_im => {
            const im_val = self.memory[pc.* .. pc.* + 1];
            self.registers.sp = try self.stack.push(im_val);
            pc.* += 1;
        },
        .push_byte_reg => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1];
            self.registers.sp = try self.stack.push(register);
            pc.* += 1;
        },
        .pop_byte => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1];
            const s_result = try self.stack.pop(1);
            @memcpy(register, s_result[0]);
            self.registers.sp = s_result[1];
            pc.* += 1;
        },
        .peek_byte => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1];
            const s_result = try self.stack.peek(1);
            @memcpy(register, s_result);
            pc.* += 1;
        },
        .swap_byte => {
            try self.stack.swap(1);
        },
        .rot_byte => {
            try self.stack.rot(1);
        },
        .drop_byte => {
            try self.stack.unreserve(1);
            self.registers.sp = self.stack.sp;
        },
        .nip_byte => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..1];
            const s_result = try self.stack.nip(1);
            @memcpy(register, s_result[0]);
            self.registers.sp = s_result[1];
            pc.* += 1;
        },
        .dup_byte => {
            self.registers.sp = try self.stack.dup(1);
        },
        .over_byte => {
            self.registers.sp = try self.stack.over(1);
        },

        // short ops
        .move_short_reg_im,
        => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const im_val = self.memory[pc.* .. pc.* + 2];
            @memcpy(dest[0..2], im_val);
            pc.* += 2;
        },
        .move_short_reg_reg => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const src = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            @memcpy(dest[0..2], src[0..2]);
        },
        .move_short_reg_addr => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const addr = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            const payload = self.memory[addr .. addr + 2];
            pc.* += 2;
            @memcpy(dest[0..2], payload);
        },
        .move_short_addr_im => {
            const addr = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            const dest = self.memory[addr .. addr + 2];
            pc.* += 2;
            const im_val = self.memory[pc.* .. pc.* + 2];
            pc.* += 2;
            @memcpy(dest, im_val);
        },
        .move_short_addr_reg => {
            const addr = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            const dest = self.memory[addr .. addr + 2];
            pc.* += 2;
            const register = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            @memcpy(dest, register[0..2]);
        },
        .move_short_indirect_rel_reg_reg => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const addr: u32 = @shlExact(@as(u32, self.registers.addr.bs), 16) + std.mem.bytesToValue(u16, try self.getRegister(@enumFromInt(self.memory[pc.*])));
            pc.* += 1;
            const payload = self.memory[addr .. addr + 2];
            @memcpy(dest[0..2], payload);
        },
        .move_short_indirect_zp_reg_reg => {
            const dest = try self.getRegister(@enumFromInt(self.memory[pc.*]));
            pc.* += 1;
            const addr = std.mem.bytesToValue(u16, try self.getRegister(@enumFromInt(self.memory[pc.*])));
            pc.* += 1;
            const payload = self.memory[addr .. addr + 2];
            @memcpy(dest[0..2], payload);
        },
        //math // these all effect a.l
        .add_short_reg_im => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @addWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @addWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .add_short_reg_reg => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @addWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @addWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .sub_short_reg_im => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @subWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @subWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .sub_short_reg_reg => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            var carry: u1 = self.registers.st.carry;
            const awc = blk: {
                if (carry == 1) {
                    const result = @subWithOverflow(a, 1);
                    carry = result[1];
                    break :blk result[0];
                }
                break :blk a;
            };
            const result = @subWithOverflow(awc, b);
            self.registers.st.carry = result[1] | carry;
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .mul_short_reg_im => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            const result = @mulWithOverflow(a, b);
            self.registers.st.carry = result[1];
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .mul_short_reg_reg => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const result = @subWithOverflow(a, b);
            self.registers.st.carry = result[1];
            acu.* = result[0];
            self.registers.st.negative = sign(result[0]);
            self.registers.st.zero = isZero(result[0]);
        },
        .div_short_reg_im => { // division puts the product in the top byte of a.l and the remainder in the low byte a.l
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            const product: u16 = @divFloor(a, b);
            const remainder: u16 = a - product;
            self.registers.a.h = product;
            self.registers.a.l = remainder;
            self.registers.st.negative = sign(product);
            self.registers.st.zero = isZero(product);
        },
        .div_short_reg_reg => {
            const a: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const b: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const product: u16 = @divFloor(a, b);
            const remainder: u16 = a - product;
            self.registers.a.h = product;
            self.registers.a.l = remainder;
            self.registers.st.negative = sign(product);
            self.registers.st.zero = isZero(product);
        },
        .compare_short_im => {
            const im_val: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            const product = @subWithOverflow(self.registers.a.l, im_val);
            self.registers.st.carry = 1 ^ (product[1] & isZero(product[0]));
            self.registers.st.zero = isZero(product[0]);
        },
        .compare_short_reg => {
            const register: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            const product = @subWithOverflow(self.registers.a.l, register);
            self.registers.st.carry = 1 ^ (product[1] & isZero(product[0]));
            self.registers.st.zero = isZero(product[0]);
        },

        //binary operations
        .band_short_im => {
            const im_val: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            self.registers.a.l = self.registers.a.l & im_val;
        },
        .band_short_reg => {
            const register: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            self.registers.a.l = self.registers.a.l & register;
        },
        .bor_short_im => {
            const im_val: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            self.registers.a.l = self.registers.a.l | im_val;
        },
        .bor_short_reg => {
            const register: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            self.registers.a.l = self.registers.a.l | register;
        },
        .bxor_short_im => {
            const im_val: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            self.registers.a.l = self.registers.a.l ^ im_val;
        },
        .bxor_short_reg => {
            const register: u16 = std.mem.bytesToValue(u16, (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2]);
            pc.* += 1;
            self.registers.a.l = self.registers.a.l ^ register;
        },

        // stack operations
        .push_short_im => {
            const im_val = self.memory[pc.* .. pc.* + 2];
            self.registers.sp = try self.stack.push(im_val);
            pc.* += 2;
        },
        .push_short_reg => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2];
            self.registers.sp = try self.stack.push(register);
            pc.* += 1;
        },
        .pop_short => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2];
            const s_result = try self.stack.pop(2);
            @memcpy(register, s_result[0]);
            self.registers.sp = s_result[1];
            pc.* += 1;
        },
        .peek_short => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2];
            const s_result = try self.stack.peek(2);
            @memcpy(register, s_result);
            pc.* += 1;
        },
        .swap_short => {
            try self.stack.swap(2);
        },
        .rot_short => {
            try self.stack.rot(2);
        },
        .drop_short => {
            try self.stack.unreserve(2);
            self.registers.sp = self.stack.sp;
        },
        .nip_short => {
            const register = (try self.getRegister(@enumFromInt(self.memory[pc.*])))[0..2];
            const s_result = try self.stack.nip(2);
            @memcpy(register, s_result[0]);
            self.registers.sp = s_result[1];
            pc.* += 1;
        },
        .dup_short => {
            self.registers.sp = try self.stack.dup(2);
        },
        .over_short => {
            self.registers.sp = try self.stack.over(2);
        },

        .short_jump => {
            const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            self.registers.addr.pc = low_part;
        },
        .short_jump_eq => {
            if (self.registers.st.zero == 1) {
                const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                self.registers.addr.pc = low_part;
                self.registers.st.zero = 0;
            } else {
                pc.* += 2;
            }
        },
        .short_jump_lth => {
            if (self.registers.st.zero == 0 and self.registers.st.carry == 1) {
                const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                self.registers.addr.pc = low_part;
                self.registers.st.carry = 0;
            } else {
                pc.* += 2;
            }
        },
        .short_jump_gth => {
            if (self.registers.st.zero == 0 and self.registers.st.carry == 0) {
                const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                self.registers.addr.pc = low_part;
            } else {
                pc.* += 2;
            }
        },
        .long_jump => {
            const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            const high_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            self.registers.addr.bs = high_part;
            self.registers.addr.pc = low_part;
        },
        .long_jump_eq => {
            if (self.registers.st.zero == 1) {
                const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                pc.* += 2;
                const high_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                self.registers.addr.bs = high_part;
                self.registers.addr.pc = low_part;
                self.registers.st.zero = 0;
            } else {
                pc.* += 4;
            }
        },
        .long_jump_lth => {
            if (self.registers.st.zero == 0 and self.registers.st.carry == 1) {
                const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                pc.* += 2;
                const high_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                self.registers.addr.bs = high_part;
                self.registers.addr.pc = low_part;
                self.registers.st.carry = 0;
            } else {
                pc.* += 4;
            }
        },
        .long_jump_gth => {
            if (self.registers.st.zero == 0 and self.registers.st.carry == 0) {
                const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                pc.* += 2;
                const high_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
                self.registers.addr.bs = high_part;
                self.registers.addr.pc = low_part;
            } else {
                pc.* += 4;
            }
        },
        .jump_subroutine => {
            const low_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            const high_part = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;

            // store previous base pointer
            self.registers.sp = try self.stack.push(&std.mem.toBytes(self.registers.bp)); // 2 bytes
            self.registers.bp = self.registers.sp + 2;
            //store current address we are already moved passed this instruction so no need to increment
            self.registers.sp = try self.stack.push(&std.mem.toBytes(self.registers.addr.bs)); // 2 bytes
            self.registers.sp = try self.stack.push(&std.mem.toBytes(self.registers.addr.pc));
            self.registers.addr.pc = low_part;
            self.registers.addr.bs = high_part;
        },
        .return_subroutine => {
            //grab return address off stack
            const low_part = (try self.stack.pop(2))[0];
            const high_part = (try self.stack.pop(2))[0];
            // grab previous base pointer
            const prev_bp = try self.stack.pop(2);
            //update current stack pointer after all those pops
            self.registers.sp = prev_bp[1];
            //restore bp
            self.registers.bp = std.mem.bytesToValue(u16, prev_bp[0]);
            //go to return address
            self.registers.addr.bs = std.mem.bytesToValue(u16, high_part);
            self.registers.addr.pc = std.mem.bytesToValue(u16, low_part);
        },
        .jump_software_interrupt => {
            const interrupt_id: u16 = std.mem.bytesToValue(u16, self.memory[pc.* .. pc.* + 2]);
            pc.* += 2;
            try self.interrupt(interrupt_id, true, false);
        },
        .return_interrupt => {
            //when returning from a software interrupt ignore what the break flag was set to, its only to notifiy
            // the interrupt handler
            try self.loadContext();
            self.registers.st.interrupt_disable = 0;
        },
        .set_carry => {
            self.registers.st.carry = 1;
        },
        .clear_carry => {
            self.registers.st.carry = 0;
        },
        .set_zero => {
            self.registers.st.zero = 1;
        },
        .clear_zero => {
            self.registers.st.zero = 0;
        },
        .set_interrupt_disable => {
            self.registers.st.interrupt_disable = 1;
        },
        .clear_interrupt_disable => {
            self.registers.st.interrupt_disable = 0;
        },
        .hault => {
            self.running = false;
            return false;
        },
    }
    return true;
    // after step check program register
}

const testing = std.testing;

test "move byte instructions" {
    var buffer: [0x80]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    //@compileLog(@sizeOf(std.ArrayListUnmanaged(u8)));
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0x80,
        .page_size = 0x40,
        .stack_size = 0x0,
    });
    const code: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x0, // irq vector
        0x0,
        0x0,
        0x0,
        @intFromEnum(OpCode.move_byte_reg_im),
        @intFromEnum(Register.d),
        0x7,
        @intFromEnum(OpCode.move_byte_reg_reg),
        @intFromEnum(Register.e),
        @intFromEnum(Register.d),
        @intFromEnum(OpCode.move_byte_addr_im),
        0x64,
        0x00,
        0x8,
        @intFromEnum(OpCode.move_byte_reg_addr),
        @intFromEnum(Register.d),
        0x64,
        0x00,
        @intFromEnum(OpCode.move_byte_addr_reg),
        0x64,
        0x00,
        @intFromEnum(Register.e),
    };
    @memcpy(cpu.memory[0..code.len], code);
    cpu.reset();
    _ = try cpu.step();
    try testing.expectEqual(0x7, cpu.registers.d);
    _ = try cpu.step();
    try testing.expectEqual(0x7, cpu.registers.e);
    _ = try cpu.step();
    try testing.expectEqual(0x8, cpu.memory[0x64]);
    _ = try cpu.step();
    try testing.expectEqual(0x8, cpu.registers.d);
    _ = try cpu.step();
    try testing.expectEqual(0x7, cpu.memory[0x64]);
}

test "move short instructions" {
    var buffer: [0x80]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    //@compileLog(@sizeOf(std.ArrayListUnmanaged(u8)));
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0x80,
        .page_size = 0x40,
        .stack_size = 0x0,
    });
    const code: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x0, // irq vector
        0x0,
        0x0,
        0x0,
        @intFromEnum(OpCode.move_short_reg_im),
        @intFromEnum(Register.d),
        0x07,
        0x11,
        @intFromEnum(OpCode.move_short_reg_reg),
        @intFromEnum(Register.e),
        @intFromEnum(Register.d),
        @intFromEnum(OpCode.move_short_addr_im),
        0x64,
        0x00,
        0x08,
        0x11,
        @intFromEnum(OpCode.move_short_reg_addr),
        @intFromEnum(Register.d),
        0x64,
        0x00,
        @intFromEnum(OpCode.move_short_addr_reg),
        0x64,
        0x00,
        @intFromEnum(Register.e),
    };
    @memcpy(cpu.memory[0..code.len], code);
    cpu.reset();
    _ = try cpu.step();
    try testing.expectEqual(0x1107, cpu.registers.d);
    _ = try cpu.step();
    try testing.expectEqual(0x1107, cpu.registers.e);
    _ = try cpu.step();
    try testing.expectEqual(0x1108, std.mem.bytesToValue(u16, cpu.memory[0x64..0x66]));
    _ = try cpu.step();
    try testing.expectEqual(0x1108, cpu.registers.d);
    _ = try cpu.step();
    try testing.expectEqual(0x1107, std.mem.bytesToValue(u16, cpu.memory[0x64..0x66]));
}

test "stack byte operations" {
    var buffer: [0x80]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0x80,
        .page_size = 0x40,
        .stack_size = 0x20,
    });
    const code: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x0, // irq vector
        0x0,
        0x0,
        0x0,
        @intFromEnum(OpCode.push_byte_im),
        0x01,
        @intFromEnum(OpCode.push_byte_im),
        0x02,
        @intFromEnum(OpCode.swap_byte),
        @intFromEnum(OpCode.over_byte),
        @intFromEnum(OpCode.dup_byte),
        @intFromEnum(OpCode.rot_byte),
        @intFromEnum(OpCode.drop_byte),
        @intFromEnum(OpCode.peek_byte),
        @intFromEnum(Register.b),
        @intFromEnum(OpCode.pop_byte),
        @intFromEnum(Register.c),
        @intFromEnum(OpCode.move_byte_reg_im),
        @intFromEnum(Register.b),
        0x68,
        @intFromEnum(OpCode.push_byte_reg),
        @intFromEnum(Register.b),
    };
    @memcpy(cpu.memory[0..code.len], code);
    cpu.reset();
    _ = try cpu.step();
    try testing.expectEqual(0x01, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step();
    try testing.expectEqual(0x02, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step();
    try testing.expectEqual(0x01, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step();
    try testing.expectEqual(0x02, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step();
    try testing.expectEqual(0x02, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step();
    _ = try cpu.step();
    try testing.expectEqual(0x02, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step();
    try testing.expectEqual(0x02, cpu.registers.bc.b);
    _ = try cpu.step();
    try testing.expectEqual(0x02, cpu.registers.bc.c);
    _ = try cpu.step();
    _ = try cpu.step();
    try testing.expectEqual(0x68, (try cpu.stack.peek(1))[0]);
}

test "stack short operations" {
    var buffer: [0xFF]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0xFF,
        .page_size = 0x80,
        .stack_size = 0x80,
    });
    const code: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x0, // irq vector
        0x0,
        0x0,
        0x0,
        @intFromEnum(OpCode.push_short_im),
        0x01,
        0x11,
        @intFromEnum(OpCode.push_short_im),
        0x02,
        0x22,
        @intFromEnum(OpCode.swap_short),
        @intFromEnum(OpCode.over_short),
        @intFromEnum(OpCode.dup_short),
        @intFromEnum(OpCode.rot_short),
        @intFromEnum(OpCode.drop_short),
        @intFromEnum(OpCode.peek_short),
        @intFromEnum(Register.d),
        @intFromEnum(OpCode.pop_short),
        @intFromEnum(Register.e),
        @intFromEnum(OpCode.move_short_reg_im),
        @intFromEnum(Register.d),
        0x68,
        0x32,
        @intFromEnum(OpCode.push_short_reg),
        @intFromEnum(Register.d),
    };
    @memcpy(cpu.memory[0..code.len], code);
    cpu.reset();
    _ = try cpu.step();
    try testing.expectEqual(0x1101, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
    _ = try cpu.step();
    try testing.expectEqual(0x2202, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
    _ = try cpu.step();
    try testing.expectEqual(0x1101, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
    _ = try cpu.step();
    try testing.expectEqual(0x2202, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
    _ = try cpu.step();
    try testing.expectEqual(0x2202, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
    _ = try cpu.step();
    _ = try cpu.step();
    try testing.expectEqual(0x2202, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
    _ = try cpu.step();
    try testing.expectEqual(0x2202, cpu.registers.d);
    _ = try cpu.step();
    try testing.expectEqual(0x2202, cpu.registers.e);
    _ = try cpu.step();
    _ = try cpu.step();
    try testing.expectEqual(0x3268, std.mem.bytesToValue(u16, try cpu.stack.peek(2)));
}

test "subroutines" {
    var buffer: [0x1FFFF]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0x1FFFF,
        .page_size = 0xFFFF,
        .stack_size = 0xFFF,
    });
    cpu.reset();
    const code_1: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x0, // irq vector
        0x0,
        0x0,
        0x0,
        @intFromEnum(OpCode.push_byte_im),
        0x22,
        @intFromEnum(OpCode.jump_subroutine),
        0x00,
        0xF0,
        0x01,
        0x00,
        @intFromEnum(OpCode.drop_byte),
        @intFromEnum(OpCode.move_byte_reg_im),
        @intFromEnum(Register.g),
        0x99,
    };
    @memcpy(cpu.memory[0..code_1.len], code_1);
    const code_2: []const u8 = &[_]u8{
        @intFromEnum(OpCode.move_byte_indirect_zp_reg_reg),
        @intFromEnum(Register.g),
        @intFromEnum(Register.bp),
        @intFromEnum(OpCode.return_subroutine),
    };
    @memcpy(cpu.memory[0x1F000 .. 0x1F000 + code_2.len], code_2);
    cpu.reset();
    _ = try cpu.step(); // [0x22]
    try testing.expectEqual(0x22, (try cpu.stack.peek(1))[0]);
    _ = try cpu.step(); // jsr
    _ = try cpu.step(); // g = &bp
    try testing.expectEqual(0x22, cpu.registers.g);
    _ = try cpu.step(); // return
    _ = try cpu.step();
    _ = try cpu.step();
    try testing.expectEqual(0x99, cpu.registers.g);
}

test "print opcode amount" {
    std.debug.print("Opcode count: {d}\n", .{@intFromEnum(OpCode.MAX)});
}

test "loop" {
    var buffer: [0xFF]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0xFF,
        .page_size = 0x80,
        .stack_size = 0x80,
    });
    const code: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x0, // irq vector
        0x0,
        0x0,
        0x0,
        @intFromEnum(OpCode.add_byte_reg_im),
        @intFromEnum(Register.b),
        0x01,
        @intFromEnum(OpCode.move_byte_reg_reg),
        @intFromEnum(Register.b),
        @intFromEnum(Register.al),
        @intFromEnum(OpCode.compare_byte_im),
        0xa,
        @intFromEnum(OpCode.short_jump_lth),
        0x0c,
        0x00,
        @intFromEnum(OpCode.hault),
    };
    @memcpy(cpu.memory[0..code.len], code);
    cpu.reset();
    while (true) {
        if (!(try cpu.step())) {
            break;
        }
    }
    try testing.expectEqual(0xa, cpu.registers.bc.b);
}

test "software interrupt" {
    var buffer: [0x1FFFF]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const alloc = fba.allocator();
    var cpu = try CPU.init(alloc, .{
        .memory_size = 0x1FFFF,
        .page_size = 0xFFFF,
        .stack_size = 0xFFF,
    });
    const test_interrupt: []const u8 = &[_]u8{
        @intFromEnum(OpCode.drop_short),
        @intFromEnum(OpCode.peek_byte),
        @intFromEnum(Register.al),
        @intFromEnum(OpCode.band_byte_im),
        0x10,
        @intFromEnum(OpCode.compare_byte_im),
        0x10,
        @intFromEnum(OpCode.short_jump_lth),
        0xd,
        0x0,
        @intFromEnum(OpCode.move_byte_reg_im),
        @intFromEnum(Register.al),
        0x99,
        @intFromEnum(OpCode.return_interrupt),
    };
    @memcpy(cpu.memory[0x10000 .. 0x10000 + test_interrupt.len], test_interrupt);
    const code: []const u8 = &[_]u8{
        0xc, // reset vector
        0x0,
        0x0,
        0x0,
        0x0, // nmi vector
        0x0,
        0x0,
        0x0,
        0x00, // irq vector
        0x00,
        0x01,
        0x00,
        @intFromEnum(OpCode.clear_interrupt_disable),
        @intFromEnum(OpCode.jump_software_interrupt),
        0x01,
        0x00,
        @intFromEnum(OpCode.hault),
    };
    @memcpy(cpu.memory[0..code.len], code);
    cpu.reset();
    while (true) {
        if (!(try cpu.step())) {
            break;
        }
    }

    try testing.expectEqual(0x99, cpu.registers.a.l);
}
