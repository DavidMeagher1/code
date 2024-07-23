const std = @import("std");
const windows = @import("./lib/windows.zig");

const GPA = (std.heap.GeneralPurposeAllocator(.{}));
var gpa = GPA{};
const alloc = gpa.allocator();

var exit: bool = false;
var hBitmap: ?windows.HBITMAP = null;
var hInstance: ?windows.HINSTANCE = null;

fn asExeLocalPathZ(allocator: std.mem.Allocator, path: []const u8) ![:0]u8 {
    const selfExeDir = try std.fs.selfExeDirPathAlloc(allocator);
    return try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ selfExeDir, "/", path }, 0);
}

fn test_win_proc(hWnd: windows.HWND, uMsg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.C) windows.LRESULT {
    switch (uMsg) {
        windows.WM_CREATE => {
            const bmp_path = asExeLocalPathZ(alloc, "assets/test.bmp") catch {
                return windows.FALSE;
            };
            hBitmap = @ptrCast(windows.LoadImageA(hInstance, bmp_path, windows.IMAGE_BITMAP, 0, 0, windows.LR_LOADFROMFILE | windows.LR_SHARED | windows.LR_DEFAULTSIZE));
            alloc.free(bmp_path);
            if (hBitmap == null) {
                return windows.FALSE;
            }
        },
        windows.WM_CLOSE => {
            exit = true;
            return windows.FALSE;
        },
        windows.WM_PAINT => {
            var ps: windows.PAINTSTRUCT = .{};
            var bitmap: windows.BITMAP = .{};
            const hdc: windows.HDC = windows.BeginPaint(hWnd, &ps);
            const hdcMem: windows.HDC = windows.CreateCompatibleDC(hdc);
            const oldBitmap: windows.HGDIOBJ = windows.SelectObject(hdcMem, @ptrCast(hBitmap));

            _ = windows.GetObjectA(@ptrCast(hBitmap.?), @sizeOf(@TypeOf(bitmap)), &bitmap);
            _ = windows.BitBlt(hdc, 100, 100, bitmap.bmWidth, bitmap.bmHeight, hdcMem, 0, 0, windows.SRCCOPY);

            _ = windows.SelectObject(hdcMem, @ptrCast(oldBitmap));
            _ = windows.DeleteDC(hdcMem);

            _ = windows.EndPaint(hWnd, &ps);
        },
        else => {
            return windows.DefWindowProcA(hWnd, uMsg, wParam, lParam);
        },
    }
    return windows.TRUE;
}

const ProjectData = struct {
    name: []u8,
};

pub fn main() !void {
    hInstance = @as(windows.HINSTANCE, @ptrCast(std.os.windows.peb().ImageBaseAddress));
    const icon_path = try asExeLocalPathZ(alloc, "assets/icon.ico");
    defer alloc.free(icon_path);
    var wn_class = windows.WNDCLASSEXA{
        .lpszClassName = "testclass",
        .lpszMenuName = "testmenu",
        .hInstance = hInstance.?,
        .hCursor = windows.LoadCursorA(hInstance, windows.MAKEINTRESOURCEA(32512)),
        .hIcon = @ptrCast(windows.LoadImageA(hInstance, icon_path, windows.IMAGE_ICON, 0, 0, windows.LR_LOADFROMFILE | windows.LR_SHARED | windows.LR_DEFAULTSIZE)),
        .lpfnWndProc = &test_win_proc,
    };
    _ = windows.RegisterClassExA(&wn_class);
    std.debug.print("\n\n{}\n\n", .{windows.GetLastError()});
    const win = windows.CreateWindowExA(windows.WS_EX_TRANSPARENT, "testclass", "TestWindow", windows.WS_OVERLAPPEDWINDOW, 0, 0, 640, 480, null, null, hInstance, null);
    defer _ = windows.DestroyWindow(win);
    _ = windows.ShowWindow(win, 5);
    _ = windows.UpdateWindow(win);
    var msg: windows.MSG = windows.MSG{};
    while (windows.GetMessageA(&msg, null, 0, 0) != 0 and !exit) {
        _ = windows.TranslateMessage(&msg);
        _ = windows.DispatchMessageA(&msg);
    }
}
