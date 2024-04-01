const std = @import("std");
const process = std.process;
const mem = std.mem;

pub const ArgumentType = enum {
    Long,
    Short,
    Assignment,
    Default,
};

pub const Argument = struct {
    type: ArgumentType,
    name: ?[]const u8,
    value: ?[]const u8,
};

pub fn get_arguments(arg_iter: *process.ArgIterator, allocator: mem.Allocator) ![]Argument {
    var pending_result: []Argument = try allocator.alloc(Argument, 10);
    var i: usize = 0;

    while (arg_iter.next()) |arg| {
        if (arg[0] == '-') {
            if (arg[1] == '-') {
                pending_result[i] = Argument{
                    .type = .Long,
                    .name = arg[2..arg.len],
                    .value = null,
                };
            } else {
                pending_result[i] = Argument{
                    .type = .Short,
                    .name = arg[1..arg.len],
                    .value = null,
                };
            }
        } else {
            pending_result[i] = Argument{
                .type = .Default,
                .name = null,
                .value = arg,
            };
        }
        i += 1;
    }
    const result: []Argument = try allocator.alloc(Argument, i);
    @memcpy(result, pending_result[0..i]);
    allocator.free(pending_result);
    return result;
}
