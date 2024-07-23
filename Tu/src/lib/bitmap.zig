const builtin = @import("builtin");
const os_tag = builtin.os.tag;
const std = @import("std");
const os_unknown_msg = "unknown OS";
const impl = switch (os_tag) {
    .windows => @import("windows.zig"),
    else => {
        @compileError(os_unknown_msg);
    },
};
const BitMap = @This();

inner: switch (os_tag) {
    .windows => []impl.BITMAP,
    else => {
        @compileError(os_unknown_msg);
    },
},

const BitmapLoadError = error{
    UnImplemented,
};

pub fn loadFromFile(allocator: std.mem.Allocator, path: [*:0]const u8, shared: bool) !BitMap {
    switch (os_tag) {
        .windows => {
            var flags: impl.UINT = impl.LR_DEFAULTSIZE | impl.LR_LOADFROMFILE;
            if (shared) flags |= impl.LR_SHARED;
            const winBitmap: ?*anyopaque = impl.LoadImageA(null, path, impl.IMAGE_BITMAP, 0, 0, flags);
            if (winBitmap) |img_ptr| {
                //this way the user can own the memory instead of it just being around somewhere
                const btmp_ptr: *impl.BITMAP = @ptrCast(@as(*impl.BITMAP, @alignCast(img_ptr)));
                const new_ptr = try allocator.dupe(impl.BITMAP, &[_]impl.BITMAP{btmp_ptr.*});
                //const new_ptr = try allocator.alloc(impl.BITMAP, 1);
                _ = impl.DeleteObject(@ptrCast(img_ptr));
                return BitMap{
                    .inner = new_ptr,
                };
            } else {
                return BitmapLoadError.UnImplemented;
            }
        },
        else => {},
    }
}

pub fn deinit(self: *BitMap, allocator: std.mem.Allocator) void {
    allocator.free(self.inner);
}

test "LoadBitMap" {
    const GPA = std.heap.GeneralPurposeAllocator(.{});
    var gpa = GPA{};
    const alloc = gpa.allocator();

    //std.debug.print("\n\n\n\n", .{});
    var bm = try loadFromFile(alloc, "src/assets/test.bmp", true);
    bm.deinit(alloc);
}
