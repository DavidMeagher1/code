const std = @import("std");
const testing = std.testing;
const windows = std.os.windows;
pub usingnamespace windows;

pub const WNDPROC = *const fn (windows.HWND, windows.UINT, windows.WPARAM, windows.LPARAM) callconv(.C) windows.LRESULT;

pub const WNDCLASSEXA = packed struct {
    cbSize: windows.UINT = @sizeOf(@This()),
    style: windows.UINT = 0,
    lpfnWndProc: ?WNDPROC,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?windows.HINSTANCE,
    hIcon: ?windows.HICON = null,
    hCursor: ?windows.HCURSOR = null,
    hbrBackground: ?windows.HBRUSH = null,
    lpszMenuName: ?windows.LPCSTR,
    lpszClassName: ?windows.LPCSTR,
    hIconSm: ?windows.HICON = null,
};

pub const WM_CREATE = 0x0001;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_PAINT = 0x00F;
pub const GWL_EXSTYLE = -20;
pub const GWLP_HINSTANCE = -6;
pub const GWLP_ID = -12;
pub const GWL_STYLE = -16;
pub const GWLP_USERDATA = -21;
pub const GWLP_WINDPROC = -4;

pub extern "kernel32" fn SetLastError(windows.DWORD) callconv(.C) void;
pub extern "kernel32" fn GetLastError() callconv(.C) windows.DWORD;
pub extern "kernel32" fn Sleep(dwMilliseconds: windows.DWORD) callconv(.C) void;

pub const MSG = struct {
    hwnd: ?windows.HWND = null,
    message: windows.UINT = 0,
    wParam: windows.WPARAM = 0,
    lParam: windows.LPARAM = 0,
    time: windows.DWORD = 0,
    pt: windows.POINT = .{ .x = 0, .y = 0 },
    lPrivate: windows.DWORD = 0,
};

pub fn MAKEINTRESOURCEA(i: windows.WORD) windows.LPSTR {
    return @ptrFromInt(i);
}

pub extern "user32" fn GetMessageA(lpMsg: *MSG, hWnd: ?windows.HWND, wMsgFilterMin: windows.UINT, wMsgFilterMax: windows.UINT) callconv(.C) windows.BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *MSG) callconv(.C) windows.BOOL;
pub extern "user32" fn DispatchMessageA(lpMsg: *MSG) callconv(.C) windows.BOOL;

pub extern "user32" fn GetWindowRect(hWnd: windows.HWND, lpRect: windows.LPRECT) callconv(windows.WINAPI) windows.BOOL;
pub extern "user32" fn SetWindowPos(hWnd: windows.HWND, hWindInsertAfter: ?windows.HWND, x: c_int, y: c_int, cx: c_int, cy: c_int, flags: windows.UINT) callconv(windows.WINAPI) windows.BOOL;
pub extern "user32" fn SetWindowLongPtrA(hWnd: windows.HWND, nIndex: c_int, dwNewLong: windows.LONG_PTR) callconv(windows.WINAPI) windows.LONG_PTR;
pub extern "user32" fn DefWindowProcA(hWnd: windows.HWND, uMsg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.C) windows.LRESULT;

pub extern "user32" fn LoadIconA(hInstance: ?windows.HINSTANCE, lpIconName: windows.LPCSTR) callconv(windows.WINAPI) windows.HICON;
pub extern "user32" fn LoadCursorA(hInstance: ?windows.HINSTANCE, lpCursorName: windows.LPCSTR) callconv(windows.WINAPI) windows.HCURSOR;

pub extern "user32" fn RegisterClassExA(lpWndClass: *const WNDCLASSEXA) windows.ATOM;
pub extern "user32" fn CreateWindowExA(dwExStyle: windows.DWORD, lpClassName: windows.LPCSTR, lpWindowName: windows.LPCSTR, dwStyle: windows.DWORD, x: c_int, y: c_int, nWidth: c_int, nHeight: c_int, hWndParent: ?windows.HWND, hMenu: ?windows.HMENU, hInstance: ?windows.HINSTANCE, lpParam: ?windows.LPVOID) callconv(windows.WINAPI) windows.HWND;
pub extern "user32" fn DestroyWindow(hWnd: windows.HWND) callconv(windows.WINAPI) windows.BOOL;
pub extern "user32" fn ShowWindow(hWnd: windows.HWND, nCmdShow: c_int) callconv(windows.WINAPI) windows.BOOL;
pub extern "user32" fn UpdateWindow(hWnd: windows.HWND) callconv(windows.WINAPI) windows.BOOL;

//Images

pub const LR_LOADFROMFILE = 0x00000010;
pub const LR_DEFAULTSIZE = 0x00000040;
pub const LR_SHARED = 0x00008000;

pub const IMAGE_BITMAP = 0x0;
pub const IMAGE_ICON = 0x1;
pub const IMAGE_CURSOR = 0x2;
pub const IMAGE_ENHMETAFILE = 0x3;

pub extern "user32" fn LoadImageA(hInstance: ?windows.HINSTANCE, name: windows.LPCSTR, type: windows.UINT, cx: c_int, cy: c_int, fuLoad: windows.UINT) callconv(.C) ?windows.HANDLE;

pub usingnamespace @import("./windows_window_styles.zig");
