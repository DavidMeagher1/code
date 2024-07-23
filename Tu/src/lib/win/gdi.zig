const std = @import("std");
const windows = @import("./windows_extended.zig");

pub const SRCCOPY = 0xcc0020;

pub const PAINTSTRUCT = struct {
    hdc: ?windows.HDC = null,
    fErase: windows.BOOL = windows.FALSE,
    rcPaint: windows.RECT = .{
        .bottom = 0,
        .left = 0,
        .right = 0,
        .top = 0,
    },
    fRestore: windows.BOOL = windows.FALSE,
    fIncUpdate: windows.BOOL = windows.FALSE,
    rgbReserved: [32]windows.BYTE = std.mem.zeroes([32]windows.BYTE),
};

pub const HGDIOBJ = *opaque {};
pub const HBITMAP = *opaque {};

pub extern "gdi32" fn GetStockObject(i: c_int) callconv(.C) HGDIOBJ;

// bitmaps

pub const BITMAP = packed struct {
    bmType: windows.LONG = 0,
    bmWidth: windows.LONG = 0,
    bmHeight: windows.LONG = 0,
    bmWidthBytes: windows.LONG = 0,
    bmPlanes: windows.WORD = 0,
    bmBitsPixel: windows.WORD = 0,
    bmBits: ?windows.LPVOID = null,
};

pub extern "user32" fn LoadBitmap(hInstance: windows.HINSTANCE, lpBitmapName: windows.LPCSTR) callconv(.C) HBITMAP;

pub extern "user32" fn GetDC(hWnd: windows.HWND) callconv(.C) windows.HDC;

pub extern "gdi32" fn CreateBitmap(nWidth: c_int, nHeight: c_int, nPlanes: windows.UINT, nBitCount: windows.UINT, lpBits: windows.LPVOID) callconv(.C) HBITMAP;
pub extern "gdi32" fn BitBlt(hdc: windows.HDC, x: c_int, y: c_int, cx: c_int, cy: c_int, hdcSrc: windows.HDC, x1: c_int, y1: c_int, rop: windows.DWORD) callconv(.C) windows.BOOL;
pub extern "user32" fn BeginPaint(hWnd: windows.HWND, lpPaint: *PAINTSTRUCT) callconv(.C) windows.HDC;
pub extern "gdi32" fn EndPaint(hWnd: windows.HWND, lpPaint: *PAINTSTRUCT) callconv(.C) windows.BOOL;
pub extern "gdi32" fn CreateCompatibleDC(hdc: windows.HDC) callconv(.C) windows.HDC;
pub extern "gdi32" fn SelectObject(hdc: windows.HDC, h: ?HGDIOBJ) callconv(.C) HGDIOBJ;
pub extern "gdi32" fn GetObjectA(h: windows.HANDLE, c: c_int, pv: windows.LPVOID) callconv(.C) c_int;
pub extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.C) windows.BOOL;
pub extern "gdi32" fn DeleteDC(hdc: windows.HDC) callconv(.C) windows.BOOL;
