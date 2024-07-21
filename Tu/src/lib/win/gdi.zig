const windows = @import("./windows_extended.zig");

pub const HGDIOBJ = *opaque {};
pub const HBITMAP = *opaque {};

pub extern "gdi32" fn GetStockObject(i: c_int) callconv(.C) HGDIOBJ;

// bitmaps
pub extern "gdi32" fn CreateBitmap(nWidth: c_int, nHeight: c_int, nPlanes: windows.UINT, nBitCount: windows.UINT, lpBits: windows.LPVOID) callconv(.C) HBITMAP;
pub extern "gdi32" fn BitBlt(hdc: windows.HDC, x: c_int, y: c_int, cx: c_int, cy: c_int, hdcSrc: windows.HDC, x1: c_int, y1: c_int, rop: windows.DWORD) callconv(.C) windows.BOOL;
