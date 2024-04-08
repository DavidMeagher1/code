const std = @import("std");
const mem = std.mem;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const ExecutionContext = @import("./execution_context.zig").ExecutionContext;
const memory = @import("./memory.zig");
const hex = @import("hex");
const walli = @import("walli");
const Stack = walli.stack.Stack;
const OpCode = walli.opcodes.OpCode;

const memory_size: usize = 1024 * 4;
var memory_buffer: [memory_size]u8 = mem.zeroes([memory_size]u8);
var fixed_buffer_allocator: FixedBufferAllocator = FixedBufferAllocator.init(&memory_buffer);

pub fn main() !void {
    const data_size = 128;
    var code = [_]u8{
        @intFromEnum(OpCode.Push),
        1,
        0, //  <-- Counter

        //Dup Counter
        @intFromEnum(OpCode.Dup),
        1,
        // Increment Counter
        @intFromEnum(OpCode.Push),
        1,
        1,
        @intFromEnum(OpCode.Add),
        1,
        @intFromEnum(OpCode.Push),
        8,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        @intFromEnum(OpCode.SetFar),
        1,

        // Check Counter
        @intFromEnum(OpCode.Push),
        1,
        50,

        @intFromEnum(OpCode.Push),
        8,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,

        @intFromEnum(OpCode.DupFar),
        1,
        @intFromEnum(OpCode.Equ),
        1,
        // jump to code pos 2
        @intFromEnum(OpCode.Push),
        2,
        12,
        0,

        @intFromEnum(OpCode.CJumpNear),

        @intFromEnum(OpCode.Push),
        8,
        data_size + 3,
        0,
        0,
        0,
        0,
        0,
        0,
        0,

        @intFromEnum(OpCode.JumpFar),

        @intFromEnum(OpCode.Push),
        1,
        177,
    };
    const code_size = code.len;
    const allocator = fixed_buffer_allocator.allocator();
    const data = try allocator.alloc(u8, data_size + code_size);
    @memcpy(data[0..1], &[_]u8{66});
    @memcpy(data[data_size .. data_size + code_size], &code);
    var context: ExecutionContext = try ExecutionContext.init(fixed_buffer_allocator.allocator(), .{
        .working_stack_capacity = 20,
        .code_start = data_size,
        .memory_options = .{
            .data = data,
            .sections = &[_]memory.MemorySection{ memory.MemorySection{
                .start = 0,
                .end = data_size,
                .rules = memory.MemorySectionRules{},
            }, memory.MemorySection{
                .start = data_size,
                .end = data_size + code_size,
                .rules = memory.MemorySectionRules{},
            } },
        },
    });
    allocator.free(data);
    defer context.deinit();
    try context.execute();
    std.debug.print("\n\nWorkingStack:  {any}\n\n", .{context.working_stack});
    std.debug.print("\n\nMemory:  {any}\n\n", .{context.memory.data[data_size..]});
}
