const std = @import("std");
const AST = @import("ast.zig");
pub fn main() !void {
    const source = "your source code here";
    const alloc = std.heap.page_allocator;
    const ast = try AST.parse(alloc, source);
    _ = ast;
    return;
}
