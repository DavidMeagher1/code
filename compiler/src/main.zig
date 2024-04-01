const std = @import("std");
const process = std.process;
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;

const FixedBufferAllocator = heap.FixedBufferAllocator;

const terr = error{
    Test,
};

const man_text: []const u8 = @embedFile("./man.txt");

pub fn main() !void {
    var mem_buf: [1024]u8 = mem.zeroes([1024]u8);
    var fba = FixedBufferAllocator.init(&mem_buf);
    const allocator = fba.allocator();
    var arg_iter = try process.argsWithAllocator(allocator);
    defer arg_iter.deinit();

    const exe_path = arg_iter.next();
    _ = exe_path;

    const arg_input_path = arg_iter.next();

    const cwd = fs.cwd();
    // first argument should be a file
    var input_file_path: []u8 = undefined;
    if (arg_input_path) |in_p| {
        input_file_path = blk: {
            const output_buffer = try allocator.alloc(u8, 256);
            defer allocator.free(output_buffer);
            const real_path = cwd.realpath(in_p, output_buffer) catch |e| {
                std.debug.print("\n\n{!}\n", .{e});
                std.debug.print("\n{s}\n", .{man_text});
                return;
            };
            const result = try allocator.alloc(u8, real_path.len);
            @memcpy(result, real_path);
            break :blk result;
        };
    } else {
        std.debug.print("\n{s}\n", .{man_text});
        return;
    }
    defer allocator.free(input_file_path);

    std.debug.print("\n{?s}\n", .{input_file_path});
}
