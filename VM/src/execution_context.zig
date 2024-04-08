const walli = @import("walli");
const Stack = walli.stack.Stack; // might move stack here
const opcodes = walli.opcodes;
const register = @import("./register.zig");
const memory = @import("./memory.zig");
const data = @import("./data.zig");

const std = @import("std");
const mem = std.mem;

const OpCode = opcodes.OpCode;
const Register = register.Register;
const Memory = memory.Memory;

pub const ExecutionContextOptions = struct {
    working_stack_capacity: usize = 8,
    return_stack_capacity: usize = 8,
    virtual_registers_count: usize = 0,
    code_start: usize = 0,
    memory_options: struct { data: []const u8, sections: []const memory.MemorySection },
};

pub const ExecutionContext = struct {
    const Self = @This();

    allocator: mem.Allocator,
    working_stack: Stack,
    return_stack: Stack,
    register_a: Register(64) = Register(64){ .data = 0 },
    register_b: Register(64) = Register(64){ .data = 0 },
    virtual_registers: []Register(64),
    sub_contexts: ?[]Self = null,
    memory: Memory,

    pub fn init(allocator: mem.Allocator, options: ExecutionContextOptions) !Self {
        var result = Self{
            .allocator = allocator,
            .working_stack = try Stack.init(allocator, options.working_stack_capacity),
            .return_stack = try Stack.init(allocator, options.return_stack_capacity),
            .virtual_registers = try allocator.alloc(Register(64), options.virtual_registers_count),
            .memory = try Memory.init(
                allocator,
                options.memory_options.data,
                options.memory_options.sections,
            ),
        };
        result.memory.pc = options.code_start;
        return result;
    }

    pub fn deinit(self: *Self) void {
        self.return_stack.deinit();
        self.working_stack.deinit();
        self.memory.deinit();
        self.allocator.free(self.virtual_registers);
    }

    pub fn execute(self: *Self) !void {
        var memory_iter = memory.MemoryIterator{ .context = &self.memory };
        while (memory_iter.next(1)) |byte| {
            std.debug.print("\n{any}\n{}\n", .{ self.working_stack, @as(OpCode, @enumFromInt(byte[0])) });
            //switching to a 64 bit system
            switch (@as(OpCode, @enumFromInt(byte[0]))) {
                OpCode.Add => {
                    const data_width = memory_iter.next(1).?[0]; //how many bytes
                    const pack_kind = @as(data.PackedSliceKinds, @enumFromInt(data.nearestPowerOfTwo(data_width)));
                    switch (pack_kind) {
                        .U8 => {
                            const a = data.sliceCast(u8, try self.working_stack.popBytes(data_width));
                            const b = data.sliceCast(u8, try self.working_stack.popBytes(data_width));
                            _ = try self.working_stack.pushBytes(&mem.toBytes(a[0] + b[0]));
                        },
                        .U16 => {
                            const a = data.sliceCast(u16, try self.working_stack.popBytes(data_width));
                            const b = data.sliceCast(u16, try self.working_stack.popBytes(data_width));
                            _ = try self.working_stack.pushBytes(&mem.toBytes(a[0] + b[0]));
                        },
                        .U32 => {
                            const a = data.sliceCast(u32, try self.working_stack.popBytes(data_width));
                            const b = data.sliceCast(u32, try self.working_stack.popBytes(data_width));
                            _ = try self.working_stack.pushBytes(&mem.toBytes(a[0] + b[0]));
                        },
                        .U64 => {
                            const a = data.sliceCast(u64, try self.working_stack.popBytes(data_width));
                            const b = data.sliceCast(u64, try self.working_stack.popBytes(data_width));
                            _ = try self.working_stack.pushBytes(&mem.toBytes(a[0] + b[0]));
                        },
                    }
                    //self.register_a.innerRef().* = self.register_a.inner() + self.register_b.inner();
                },
                OpCode.Sub => {
                    const data_width = memory_iter.next(1).?[0]; //how many bytes
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_a.innerRef().* = self.register_a.inner() - self.register_b.inner();
                    _ = try self.working_stack.pushBytes(mem.asBytes(self.register_a.innerRef())[0..data_width]);
                },
                OpCode.Mul => {
                    const data_width = memory_iter.next(1).?[0]; //how many bytes
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_a.innerRef().* = self.register_a.inner() * self.register_b.inner();
                    _ = try self.working_stack.pushBytes(mem.asBytes(self.register_a.innerRef())[0..data_width]);
                },
                OpCode.Div => {
                    const data_width = memory_iter.next(1).?[0]; //how many bytes
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_a.innerRef().* = self.register_a.inner() / self.register_b.inner();
                    _ = try self.working_stack.pushBytes(mem.asBytes(self.register_a.innerRef())[0..data_width]);
                },
                OpCode.Push => {
                    const data_width = memory_iter.next(1).?[0];
                    self.register_a.assignFromBytes(memory_iter.next(data_width).?);
                    _ = try self.working_stack.pushBytes(mem.asBytes(self.register_a.innerRef())[0..data_width]);
                },
                OpCode.Stash => {
                    const data_width = memory_iter.next(1).?[0];
                    const rs_val = try self.working_stack.popBytes(data_width);
                    _ = try self.return_stack.pushBytes(rs_val);
                },
                OpCode.StoreNear => {
                    const data_width = memory_iter.next(1).?[0];
                    const near = try self.working_stack.pop(u16); // actually signed
                    const _data = try self.working_stack.popBytes(data_width);
                    const cpc = self.memory.pc;
                    self.memory.pc += near - 1;
                    _ = try self.memory.write(_data);
                    self.memory.pc = cpc;
                },
                OpCode.StoreFar => {
                    const data_width = memory_iter.next(1).?[0];
                    const addr = try self.working_stack.pop(usize);
                    const _data = try self.working_stack.popBytes(data_width);
                    const cpc = self.memory.pc;
                    self.memory.pc = addr;
                    _ = try self.memory.write(_data);
                    self.memory.pc = cpc;
                },
                OpCode.Pop => {
                    const data_width = memory_iter.next(1).?[0];
                    _ = try self.working_stack.popBytes(data_width);
                },
                OpCode.Nab => {
                    const data_width = memory_iter.next(1).?[0];
                    const rs_val = try self.return_stack.popBytes(data_width);
                    _ = try self.working_stack.pushBytes(rs_val);
                },
                OpCode.LoadNear => {
                    const data_width = memory_iter.next(1).?[0];
                    const near = try self.working_stack.pop(u16); // actually signed
                    try self.working_stack.reserve(data_width);
                    const cpc = self.memory.pc;
                    self.memory.pc += near - 1;
                    _ = try self.memory.read(self.working_stack.buffer[self.working_stack.top .. self.working_stack.top + data_width]);
                    self.memory.pc = cpc;
                },
                OpCode.LoadFar => {
                    const data_width = memory_iter.next(1).?[0];
                    const addr = try self.working_stack.pop(usize);
                    try self.working_stack.reserve(data_width);
                    const cpc = self.memory.pc;
                    self.memory.pc = addr;
                    _ = try self.memory.read(self.working_stack.buffer[self.working_stack.top .. self.working_stack.top + data_width]);
                    self.memory.pc = cpc;
                },
                OpCode.SetNear => {
                    const data_width = memory_iter.next(1).?[0];
                    const pos = try self.working_stack.pop(i16);
                    const val = try self.working_stack.popBytes(data_width);
                    const stack_val = self.working_stack.peekBytesNear(pos, data_width).?;
                    @memcpy(stack_val, val);
                },
                OpCode.SetFar => {
                    const data_width = memory_iter.next(1).?[0];
                    const pos = try self.working_stack.pop(usize);
                    const val = try self.working_stack.popBytes(data_width);
                    const stack_val = self.working_stack.peekBytesFar(pos, data_width).?;
                    @memcpy(stack_val, val);
                },
                OpCode.Dup => {
                    const data_width = memory_iter.next(1).?[0];
                    const stack_val = self.working_stack.peekBytes(data_width).?;
                    _ = try self.working_stack.pushBytes(stack_val);
                },
                OpCode.DupNear => {
                    const data_width = memory_iter.next(1).?[0];
                    const pos = try self.working_stack.pop(i16);
                    const stack_val = self.working_stack.peekBytesNear(pos, data_width).?;
                    _ = try self.working_stack.pushBytes(stack_val);
                },
                OpCode.DupFar => {
                    const data_width = memory_iter.next(1).?[0];
                    const pos = try self.working_stack.pop(usize);
                    const stack_val = self.working_stack.peekBytesFar(pos, data_width).?;
                    _ = try self.working_stack.pushBytes(stack_val);
                },
                OpCode.Swap => {
                    const data_width = memory_iter.next(1).?[0];
                    _ = try self.working_stack.swapBytes(data_width);
                },
                OpCode.Rot => {
                    const data_width = memory_iter.next(1).?[0];
                    _ = try self.working_stack.rotateBytes(data_width);
                },
                OpCode.Equ => {
                    const data_width = memory_iter.next(1).?[0];
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    if (self.register_a.inner() == self.register_b.inner()) {
                        _ = try self.working_stack.push(u8, 1);
                    } else {
                        _ = try self.working_stack.push(u8, 0);
                    }
                },
                OpCode.NEqu => {
                    const data_width = memory_iter.next(1).?[0];
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    if (self.register_a.inner() != self.register_b.inner()) {
                        _ = try self.working_stack.push(u8, 1);
                    } else {
                        _ = try self.working_stack.push(u8, 0);
                    }
                },
                OpCode.LThn => {
                    const data_width = memory_iter.next(1).?[0];
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    if (self.register_a.inner() < self.register_b.inner()) {
                        _ = try self.working_stack.push(u8, 1);
                    } else {
                        _ = try self.working_stack.push(u8, 0);
                    }
                },
                OpCode.GThn => {
                    const data_width = memory_iter.next(1).?[0];
                    self.register_a.assignFromBytes(try self.working_stack.popBytes(data_width));
                    self.register_b.assignFromBytes(try self.working_stack.popBytes(data_width));
                    if (self.register_a.inner() > self.register_b.inner()) {
                        _ = try self.working_stack.push(u8, 1);
                    } else {
                        _ = try self.working_stack.push(u8, 0);
                    }
                },
                OpCode.JumpNear => {
                    const pos = try self.working_stack.pop(u16);
                    self.memory.pc += pos;
                },
                OpCode.JumpFar => {
                    const pos = try self.working_stack.pop(usize);
                    std.debug.print("HERE: {d}", .{pos});
                    self.memory.pc = pos;
                    std.debug.print("HERE {d} :: {d}", .{ self.memory.pc, memory_iter.context.pc });
                },
                OpCode.CJumpNear => {
                    const pos = try self.working_stack.pop(u16);
                    const condition = try self.working_stack.popByte();
                    if (condition == 1) {
                        self.memory.pc += pos - 1;
                    }
                },
                OpCode.CJumpFar => {
                    const pos = try self.working_stack.pop(usize);
                    const condition = try self.working_stack.popByte();
                    if (condition == 1) {
                        self.memory.pc = pos;
                    }
                },
                OpCode.Return => {
                    const return_pos = try self.return_stack.pop(usize);
                    self.memory.pc += return_pos + 1;
                },
                OpCode.Quit => {
                    break;
                },
                else => {
                    @panic("FIXME");
                },
            }
        }
    }
};
