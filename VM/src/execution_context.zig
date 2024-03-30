const Stack = @import("./stack.zig");
const StackIndex = Stack.StackIndex;
const std = @import("std");
const mem = std.mem;
const bytecode = @import("./bytecode.zig");

const ByteCode = bytecode.ByteCode;
const opcodes = @import("./opcodes.zig");
const OpCode = opcodes.OpCode;

const CodeIter = mem.TokenIterator(u8, mem.DelimiterType.scalar);

const Self = @This();

allocator: mem.Allocator,
working_stack: Stack,
return_stack: Stack,
sub_contexts: ?[]Self = null,
program_counter: usize = 0,
code: ?ByteCode,

pub fn init(allocator: mem.Allocator, working_stack_cap: usize, return_stack_cap: usize) !Self {
    return Self{
        .allocator = allocator,
        .working_stack = try Stack.init(allocator, working_stack_cap),
        .return_stack = try Stack.init(allocator, return_stack_cap),
        .code = null,
    };
}

pub fn deinit(self: *Self) void {
    self.return_stack.deinit();
    self.working_stack.deinit();
}

pub fn execute(self: *Self) !void {
    if (self.code != null) {
        var code = self.code.?;
        while (code.next()) |byte| {
            //defer std.debug.print("\n{any}, current op: {}\n", .{ self.working_stack.buffer[self.working_stack.top..self.working_stack.capacity], @as(OpCode, @enumFromInt(byte)) });

            switch (@as(OpCode, @enumFromInt(byte))) {
                OpCode.Add => {
                    const stack_val_a = try self.working_stack.popByte();
                    const stack_val_b = try self.working_stack.popByte();
                    _ = try self.working_stack.pushByte(stack_val_a + stack_val_b);
                },
                OpCode.Sub => {
                    const stack_val_a = try self.working_stack.popByte();
                    const stack_val_b = try self.working_stack.popByte();
                    _ = try self.working_stack.pushByte(stack_val_a - stack_val_b);
                },
                OpCode.Mul => {
                    const stack_val_a = try self.working_stack.popByte();
                    const stack_val_b = try self.working_stack.popByte();
                    _ = try self.working_stack.pushByte(stack_val_a * stack_val_b);
                },
                OpCode.Div => {
                    const stack_val_a = try self.working_stack.popByte();
                    const stack_val_b = try self.working_stack.popByte();
                    _ = try self.working_stack.pushByte(stack_val_a / stack_val_b);
                },
                OpCode.Push => {
                    const im_val = code.next().?;
                    _ = try self.working_stack.pushByte(im_val);
                },
                OpCode.PushR => {
                    const im_val = code.next().?;
                    _ = try self.return_stack.pushByte(im_val);
                },
                OpCode.Pop => {
                    _ = try self.working_stack.popByte();
                },
                OpCode.PopR => {
                    _ = try self.working_stack.popByte();
                },
                OpCode.MoveD => {
                    const rs_val = try self.return_stack.popByte();
                    _ = try self.working_stack.pushByte(rs_val);
                },
                OpCode.MoveR => {
                    const rs_val = try self.working_stack.popByte();
                    _ = try self.return_stack.pushByte(rs_val);
                },
                OpCode.SetAt => {
                    const pos = @as(i8, @bitCast(try self.working_stack.popByte()));
                    const val = try self.working_stack.popByte();
                    const s_index = StackIndex.from(@as(isize, pos));
                    const stack_val = try self.working_stack.refByteAt(s_index);
                    stack_val[0] = val;
                },
                OpCode.Dup => {
                    const stack_val = try self.working_stack.refByte();
                    _ = try self.working_stack.pushByte(stack_val[0]);
                },
                OpCode.DupAt => {
                    const pos = @as(i8, @bitCast(try self.working_stack.popByte()));
                    std.debug.print("\n{d}\n", .{pos});
                    const s_index = StackIndex.from(@as(isize, pos));
                    const stack_val = try self.working_stack.refByteAt(s_index);
                    _ = try self.working_stack.pushByte(stack_val[0]);
                },
                OpCode.Swap => {
                    _ = try self.working_stack.swapByte();
                },
                OpCode.Rot => {
                    _ = try self.working_stack.rotateByte();
                },
                OpCode.Equ => {
                    const a = try self.working_stack.popByte();
                    const b = try self.working_stack.popByte();
                    if (a == b) {
                        _ = try self.working_stack.pushByte(1);
                    } else {
                        _ = try self.working_stack.pushByte(0);
                    }
                },
                OpCode.NEqu => {
                    const a = try self.working_stack.popByte();
                    const b = try self.working_stack.popByte();
                    if (a != b) {
                        _ = try self.working_stack.pushByte(1);
                    } else {
                        _ = try self.working_stack.pushByte(0);
                    }
                },
                OpCode.LThn => {
                    const a = try self.working_stack.popByte();
                    const b = try self.working_stack.popByte();
                    if (a < b) {
                        _ = try self.working_stack.pushByte(1);
                    } else {
                        _ = try self.working_stack.pushByte(0);
                    }
                },
                OpCode.GThn => {
                    const a = try self.working_stack.popByte();
                    const b = try self.working_stack.popByte();
                    if (a > b) {
                        _ = try self.working_stack.pushByte(1);
                    } else {
                        _ = try self.working_stack.pushByte(0);
                    }
                },
                OpCode.Jump => {
                    const pos = @as(i8, @bitCast(try self.working_stack.popByte()));
                    const c_index = if (pos < 0) code.index - @abs(pos) else @as(u8, @abs(pos));
                    code.index = c_index;
                },
                OpCode.CJump => {
                    const pos = @as(i8, @bitCast(try self.working_stack.popByte()));
                    const condition = try self.working_stack.popByte();
                    const c_index = if (pos < 0) code.index - @abs(pos) else @as(u8, @abs(pos));
                    if (condition == 1) {
                        code.index = c_index;
                    }
                },
                OpCode.Return => {
                    const return_pos = try self.return_stack.popByte();
                    code.index = return_pos + 1;
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
}
