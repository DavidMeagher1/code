const std = @import("std");
const mem = std.mem;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const bytecode = @import("./bytecode.zig");
const ExecutionContext = @import("./execution_context.zig");
const hex = @import("hex");
const Stack = @import("./stack.zig");
const OpCode = @import("./opcodes.zig").OpCode;

const memory_size: usize = 1024;
var memory_buffer: [memory_size]u8 = mem.zeroes([memory_size]u8);
var fixed_buffer_allocator: FixedBufferAllocator = FixedBufferAllocator.init(&memory_buffer);

pub fn main() !void {
    // const code: []const u8 = &[_]u8{
    //     @intFromEnum(OpCode.Push),
    //     0, //  <-- Counter

    //     //Dup Counter
    //     @intFromEnum(OpCode.Push),
    //     0,
    //     @intFromEnum(OpCode.DupAt),
    //     // Increment Counter
    //     @intFromEnum(OpCode.Push),
    //     1,
    //     @intFromEnum(OpCode.Add),

    //     @intFromEnum(OpCode.Push),
    //     0,
    //     @intFromEnum(OpCode.SetAt),

    //     // Check Counter
    //     @intFromEnum(OpCode.Push),
    //     50,
    //     @intFromEnum(OpCode.Push),
    //     0,
    //     @intFromEnum(OpCode.DupAt),

    //     @intFromEnum(OpCode.Equ),
    //     // jump to code pos 2
    //     @intFromEnum(OpCode.Push),
    //     23,
    //     @intFromEnum(OpCode.CJump),
    //     @intFromEnum(OpCode.Push),
    //     2,
    //     @intFromEnum(OpCode.Jump),
    //     @intFromEnum(OpCode.Push),
    //     177,
    // };
    var context: ExecutionContext = try ExecutionContext.init(fixed_buffer_allocator.allocator(), 8, 8);
    defer context.deinit();

    //context.code = bytecode.ByteCode{ .buffer };
    try context.execute();
    std.debug.print("\n\nWorkingStack:  {any}\n\n", .{context.working_stack});
}
