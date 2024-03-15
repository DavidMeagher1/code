const std = @import("std");
const process = std.process;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;
const hex = @import("hex");

const Dir = fs.Dir;
const File = fs.File;

const FixedBufferAllocator = heap.FixedBufferAllocator;

const Mode = enum {
    H2B,
    B2H,
};

const ReadPageSize = 1024;

//HexParser Application
//Bin to Hex as well

const max_args_size: usize = 1024;
const max_path_size: usize = 256;

const hex_to_binary = "h2b";
const binary_to_hex = "b2h";
const output_to_file = "o";

var mode: Mode = .H2B;
var input_file_path: [max_path_size]u8 = mem.zeroes([max_path_size]u8);
var output_file_path: [max_path_size]u8 = mem.zeroes([max_path_size]u8);
var setting_output_file_path: bool = false;

const usage: []const u8 = "{mode: h2b or b2h} {input file path} [options]";

fn process_long_flag(arg: []const u8) void {
    std.debug.print("long flag : {s}\n", .{arg});
}

fn process_short_flag(arg: []const u8) void {
    std.debug.print("short flag : {s}\n", .{arg});
    if (mem.eql(u8, arg, output_to_file)) {
        setting_output_file_path = true;
    }
}

fn process_arg(arg: []const u8) void {
    if (setting_output_file_path and output_file_path[0] == 0) {
        var dup: [max_path_size]u8 = mem.zeroes([max_path_size]u8);
        mem.copyForwards(u8, &dup, arg);
        @memcpy(&output_file_path, &dup);
        return;
    }
    std.debug.print("argument : {s}\n", .{arg});
}

pub fn process_arguments() !void {
    const stdout = io.getStdOut();
    var args_buffer: [max_args_size]u8 = mem.zeroes([max_args_size]u8);
    var args_fba: FixedBufferAllocator = FixedBufferAllocator.init(&args_buffer);
    defer args_fba.reset();
    var args_iter = try process.argsWithAllocator(args_fba.allocator());
    defer args_iter.deinit();
    var arg_index: usize = 0;
    _ = args_iter.skip();
    const mode_opt = args_iter.next();
    if (mode_opt) |mode_str| {
        if (mem.eql(u8, hex_to_binary, mode_str)) {
            mode = .H2B;
        } else if (mem.eql(u8, binary_to_hex, mode_str)) {
            mode = .B2H;
        } else {
            _ = try stdout.write(usage);
            process.exit(1);
            return;
        }
    }
    const in_file_path = args_iter.next();
    if (in_file_path) |path| {
        var dup: [max_path_size]u8 = mem.zeroes([max_path_size]u8);
        mem.copyForwards(u8, &dup, path);
        @memcpy(&input_file_path, &dup);
    } else {
        _ = try stdout.write(usage);
        process.exit(1);
        return;
    }
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
        arg_index += 1;
    }
}

fn get_actual_path(path: [max_path_size]u8) []const u8 {
    var len: usize = 0;
    for (path) |c| {
        if (c != 0) {
            len += 1;
        }
    }
    return path[0..len];
}

pub fn main() !void {
    try process_arguments();
    const t = blk: {
        var cwd: Dir = fs.cwd();
        var out_buffer: [max_path_size]u8 = mem.zeroes([max_path_size]u8);
        break :blk try cwd.realpath(get_actual_path(input_file_path), &out_buffer);
    };
    std.debug.print("\n{s}\n", .{t});
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
