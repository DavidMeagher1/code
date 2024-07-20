const windows = @import("./windows_extended.zig");

pub const HGDIOBJ = *opaque {};
pub const HBITMAP = *opaque {};

pub extern "gdi32" fn GetStockObject(i: c_int) callconv(.C) HGDIOBJ;

// bitmaps
pub extern "gdi32" fn CreateBitmap(nWidth: c_int, nHeight: c_int, nPlanes: windows.UINT, nBitCount: windows.UINT, lpBits: windows.LPVOID) callconv(.C) HBITMAP;
