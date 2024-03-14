const std = @import("std");
const process = std.process;
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;
const hex = @import("hex");

const Dir = fs.Dir;
const File = fs.File;

const FixedBufferAllocator = heap.FixedBufferAllocator;

const ReadPageSize = 1024;

//HexParser Application
//Bin to Hex as well

const max_args_size: usize = 1024;

const hex_to_binary = "h2b";
const binary_to_hex = "b2h";
const output_to_file = "o";

fn process_long_flag(arg: []const u8) void {
    std.debug.print("long flag : {s}\n", .{arg});
}

fn process_short_flag(arg: []const u8) void {
    std.debug.print("short flag : {s}\n", .{arg});
}

fn process_arg(arg: []const u8) void {
    std.debug.print("argument : {s}\n", .{arg});
}

pub fn process_arguments() !void {
    var args_buffer: [max_args_size]u8 = mem.zeroes([max_args_size]u8);
    var args_fba: FixedBufferAllocator = FixedBufferAllocator.init(&args_buffer);
    defer args_fba.reset();
    var args_iter = try process.argsWithAllocator(args_fba.allocator());
    defer args_iter.deinit();
    //var arg_index: usize = 0;
    _ = args_iter.skip();
    while (args_iter.next()) |arg| {
        if (arg[0] == '-') {
            if (arg[1] == '-') {
                process_long_flag(arg[2..]);
                continue;
            }
            process_short_flag(arg[1..]);
            continue;
        }
        process_arg(arg);
        //arg_index += 1;
    }
}

pub fn main() !void {
    try process_arguments();
    // var cwd: Dir = fs.cwd();
    // var test_file: File = try cwd.openFileZ("test.bsm", .{ .mode = .read_only });
    // defer test_file.close();
    // var file_buffer: [ReadPageSize]u8 = mem.zeroes([ReadPageSize]u8);
    // var working_buffer: [1024]u8 = mem.zeroes([1024]u8);

    // var fba: FixedBufferAllocator = FixedBufferAllocator.init(&working_buffer);
    // defer fba.reset();

    // var reader = test_file.reader();
    // const read: usize = try reader.read(&file_buffer);

    // std.debug.print("read {d}\n{s}   {c}\n", .{ read, &file_buffer, hex.A });
}
