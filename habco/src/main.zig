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

const max_path_size = 256;
//HexParser Application
//Bin to Hex as well
const fixed_buffer_size: usize = 1024 * 4;
const default_page_read_size: usize = 256;

const hex_to_binary = "h2b";
const binary_to_hex = "b2h";
const output_to_file = "o";

var mode: Mode = .H2B;
var input_file_path: ?[]u8 = null;
var output_file_path: ?[]u8 = null;
var default_output_extension = ".out";
var setting_output_file_path: bool = false;

const usage: []const u8 = "{mode: h2b or b2h} {input file path} [options]";

fn process_long_flag(arg: []const u8, allocator: mem.Allocator) !void {
    _ = allocator;
    std.debug.print("long flag : {s}\n", .{arg});
}

fn process_short_flag(arg: []const u8, allocator: mem.Allocator) !void {
    _ = allocator;
    std.debug.print("short flag : {s}\n", .{arg});
    if (mem.eql(u8, arg, output_to_file)) {
        setting_output_file_path = true;
    }
}

fn process_arg(arg: []const u8, allocator: mem.Allocator) !void {
    if (setting_output_file_path and output_file_path == null) {
        const arg_copy = try allocator.alloc(u8, arg.len);
        @memcpy(arg_copy, arg);
        output_file_path = arg_copy;
        return;
    }
    std.debug.print("argument : {s}\n", .{arg});
}

const FixedPageFileReaderIterator = struct {
    file: File,
    _buffer: []u8,
    page_index: usize = 0,

    pub fn next(self: *Self) ?[]u8 {
        self.page_index += 1;
        const amount_read: usize = self.file.read(self._buffer) catch {
            return null;
        };
        if (amount_read > 0) {
            return self._buffer[0..amount_read];
        }
        return null;
    }

    pub fn peek(self: *Self) ?[]u8 {
        const result = self.next();
        self.page_index -= 1;
        self.file.seekTo((self.page_index) * self._buffer.len) catch {
            return null;
        };
        return result;
    }

    const Self = @This();
};

pub fn process_arguments(allocator: mem.Allocator) !void {
    const stdout = io.getStdOut();
    var args_iter = try process.argsWithAllocator(allocator);
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
        const path_copy = try allocator.alloc(u8, path.len);
        @memcpy(path_copy, path);
        input_file_path = path_copy;
    } else {
        _ = try stdout.write(usage);
        process.exit(1);
        return;
    }
    while (args_iter.next()) |arg| {
        if (arg[0] == '-') {
            if (arg[1] == '-') {
                try process_long_flag(arg[2..], allocator);
                continue;
            }
            try process_short_flag(arg[1..], allocator);
            continue;
        }
        try process_arg(arg, allocator);
        arg_index += 1;
    }
}

pub fn main() !void {
    var fixed_buffer: [fixed_buffer_size]u8 = mem.zeroes([fixed_buffer_size]u8);
    var fixed_buffer_allocator: FixedBufferAllocator = FixedBufferAllocator.init(&fixed_buffer);
    defer fixed_buffer_allocator.reset();
    var allocator: mem.Allocator = fixed_buffer_allocator.allocator();
    try process_arguments(allocator);
    var cwd = fs.cwd();
    const input_real_path = blk: {
        const out_buffer = try allocator.alloc(u8, max_path_size);
        defer allocator.free(out_buffer);
        const real_path = try cwd.realpath(input_file_path.?, out_buffer);
        const result = try allocator.alloc(u8, real_path.len);
        @memcpy(result, real_path);
        break :blk result;
    };
    defer allocator.free(input_real_path);

    const output_real_path: []u8 = blk: {
        if (output_file_path) |out_fp| {
            if (mem.eql(u8, fs.path.extension(out_fp), "")) {
                break :blk try fs.path.resolve(
                    allocator,
                    &[_][]const u8{
                        fs.path.dirname(input_real_path).?,
                        try mem.join(
                            allocator,
                            "",
                            &[_][]const u8{ out_fp, default_output_extension },
                        ),
                    },
                );
            } else {
                break :blk try fs.path.resolve(
                    allocator,
                    &[_][]const u8{ fs.path.dirname(input_real_path).?, out_fp },
                );
            }
        } else {
            break :blk try fs.path.join(
                allocator,
                &[_][]const u8{
                    fs.path.dirname(input_real_path).?,
                    try std.mem.join(
                        allocator,
                        "",
                        &[_][]const u8{ fs.path.stem(input_real_path), default_output_extension },
                    ),
                },
            );
        }
    };
    defer allocator.free(output_real_path);

    std.debug.print("\n{?s}\n", .{input_real_path});
    std.debug.print("{?s}\n", .{output_real_path});

    // try to open input file
    const input_file: File = try fs.openFileAbsolute(input_real_path, .{ .mode = .read_only, .lock = .exclusive });
    defer input_file.close();
    const output_file: File = try fs.createFileAbsolute(output_real_path, .{ .read = false, .truncate = true, .lock = .exclusive });
    defer output_file.close();
    var input_iter: FixedPageFileReaderIterator = .{
        .file = input_file,
        ._buffer = try allocator.alloc(u8, default_page_read_size),
    };
    defer allocator.free(input_iter._buffer);
    switch (mode) {
        .H2B => {
            try convert_H2B(allocator, &input_iter, output_file);
        },
        .B2H => {
            try convert_B2H(allocator, &input_iter, output_file);
        },
    }
}

const whitespace: []const u8 = &[_]u8{ ' ', '\t', '\r', '\n' };
fn is_whitespace(char: u8) bool {
    for (whitespace) |ws| {
        if (char == ws) {
            return true;
        }
    }
    return false;
}

fn convert_H2B(allocator: mem.Allocator, input_iter: *FixedPageFileReaderIterator, output_file: File) !void {
    var hex_pair: [2]u8 = .{ '0', '0' };
    var k: usize = 0;
    var line: usize = 1;
    var col: usize = 0;
    while (input_iter.next()) |text| {
        var bytes: []u8 = try allocator.alloc(u8, input_iter._buffer.len);
        @memset(bytes, 0);
        defer allocator.free(bytes);

        var i: usize = 0;
        //remove whitespaces
        var j: usize = 0;
        while (j < text.len) {
            if (!is_whitespace(text[j])) {
                hex_pair[k] = text[j];
                k += 1;
                if (k == 2) {
                    bytes[i] = hex.to_byte(hex_pair) catch {
                        const err_w = std.io.getStdErr().writer();
                        try std.fmt.format(err_w, "\nError: NotValidHex '{s}' at line: {d}, column: {d}\n", .{ hex_pair, line, col });
                        process.exit(1);
                        break 0;
                    };
                    hex_pair = .{ '0', '0' };
                    k = 0;
                    i += 1;
                }
            } else {
                if (text[j] == '\n') {
                    line += 1;
                    col = 0;
                }
            }
            col += 1;
            j += 1;
        }
        if (k == 1) {
            bytes[i] = try hex.to_byte(hex_pair);
            k = 0;
            i += 1;
        }
        _ = try output_file.write(bytes[0..i]);
        //std.debug.print("\n{any}\n", .{bytes[0..i]});
    }
}

fn convert_B2H(allocator: mem.Allocator, input_iter: *FixedPageFileReaderIterator, output_file: File) !void {
    while (input_iter.next()) |bin| {
        var bytes: []u8 = try allocator.alloc(u8, input_iter._buffer.len * 3);
        @memset(bytes, 0);
        defer allocator.free(bytes);

        var i: usize = 0;
        var j: usize = 0;
        while (j < bin.len) {
            const text: [2]u8 = hex.marshall_byte(bin[j]);
            bytes[i] = text[0];
            bytes[i + 1] = text[1];
            bytes[i + 2] = ' ';
            i += 3;
            j += 1;
        }
        _ = try output_file.write(bytes[0..i]);
    }
}
