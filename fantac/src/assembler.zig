const std = @import("std");
const Ast = @import("./asm/ast.zig");

pub fn main() !void {
    const GPA = std.heap.GeneralPurposeAllocator(.{});
    var gpa = GPA{};
    const alloc = gpa.allocator();
    const source =
        \\:test
        \\register r1 $1
        \\! place
        \\!< $2 place @
        \\+ $1 $2 deadly d 9989
        // \\ != place
        // \\ !> place
        // \\ >> place
        // \\ << place
    ;
    var ast = try Ast.parse(alloc, source);
    var stderr = std.io.getStdErr().writer();
    var stdout = std.io.getStdOut().writer();
    const esc = [_]u8{0x1b};
    const seperator = (esc ++ "[32m--" ++ esc ++ "[31m===" ++ esc ++ "[32m--" ++ esc ++ "[0m") ** 10;
    try stdout.print("{0s}\nSource file\n{0s}\n{1s}\n{0s}\n Errors\n{0s}\n", .{ seperator, source });
    for (ast.errors) |err| {
        try ast.renderError(err, stderr);
        try stderr.writeByte('\n');
    }
    try stderr.print("{0s}\n", .{seperator});
    defer ast.deinit(alloc);
    try stdout.print("OUTPUT\n{0s}\n{1any}", .{ seperator, ast.nodes.items(.tag) });
}
