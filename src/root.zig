const std = @import("std");
const os = std.os;
const process = std.process;
const testing = std.testing;

pub fn get_terminal_type(allocator: std.mem.Allocator) void {
    const env = process.getEnvVarOwned(allocator, "PSMODULEPATH") catch {
        return;
    };
    std.debug.print("\n{?s}\n", .{env});
    allocator.free(env);
}

test "gettt" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("\n{any}\n", .{gpa.deinit()});
    const alloc = gpa.allocator();
    get_terminal_type(alloc);
}
