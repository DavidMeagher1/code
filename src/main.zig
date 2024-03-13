const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;

const Dir = fs.Dir;
const File = fs.File;

const FixedBufferAllocator = heap.FixedBufferAllocator;

const OPCode = enum(u8) {
    // Math
    Add = 0,
    Sub,
    Mul,
    Div,
    Inc,
    Dec,
    //Control Flow
    Jmp,
    Jmpc,
    //Stack
    Push,
    Pop,
};

const Token = enum(u8) {
    usingnamespace OPCode;
    Label = 13,
    SubLabel,
    Comptime,
};

const builtin_token_map = []const []u8{
    //Math
    "+",  "-", "*", "/", "++", "--",
    //Bitop
    "&",  "|", "^",
    //Control Flow
    "!", "?",
    //Stack
     "|>",
    "<|",
    //Labels
    ":", ".",
    //Comptime
    "@",
};

pub fn is_builtin(in: []u8, tok: Token) bool {
    _ = in;
    _ = tok;
}

const ReadPageSize = 1024;

pub fn main() !void {
    var cwd: Dir = fs.cwd();
    var test_file: File = try cwd.openFileZ("test.bsm", .{ .mode = .read_only });
    defer test_file.close();
    var file_buffer: [ReadPageSize]u8 = mem.zeroes([ReadPageSize]u8);
    var working_buffer: [1024]u8 = mem.zeroes([1024]u8);

    var fba: FixedBufferAllocator = FixedBufferAllocator.init(&working_buffer);
    defer fba.reset();

    var reader = test_file.reader();

    const read: usize = try reader.read(&file_buffer);

    std.debug.print("read {d}\n{s}\n", .{ read, &file_buffer });
}
