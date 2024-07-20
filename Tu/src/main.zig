const std = @import("std");
const windows = @import("./lib/windows.zig");

var exit: bool = false;
fn test_win_proc(hWnd: windows.HWND, uMsg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.C) windows.LRESULT {
    switch (uMsg) {
        windows.WM_CLOSE => {
            exit = true;
            return windows.FALSE;
        },
        else => {
            return windows.DefWindowProcA(hWnd, uMsg, wParam, lParam);
        },
    }
    return windows.FALSE;
}

pub fn wWinMain(hInstance: ?windows.HINSTANCE, hPrevInstance: ?windows.HINSTANCE, lpCmdLine: ?[*:0]u16, nCmdShow: c_int) callconv(.C) c_int {
    _ = hPrevInstance;
    _ = lpCmdLine;
    _ = nCmdShow;
    var wn_class = windows.WNDCLASSEXA{
        .lpszClassName = "testclass",
        .lpszMenuName = "testmenu",
        .hInstance = hInstance.?,
        .hIcon = @ptrCast(windows.LoadImageA(null, "icon.ico", 1, 32, 32, windows.LR_LOADFROMFILE | windows.LR_SHARED)),
        .lpfnWndProc = &test_win_proc,
    };
    _ = windows.RegisterClassExA(&wn_class);
    std.debug.print("\n\n{}\n\n", .{windows.GetLastError()});
    const win = windows.CreateWindowExA(1, "testclass", "TestWindow", 0, 0, 0, 640, 480, null, null, hInstance, null);
    defer _ = windows.DestroyWindow(win);
    _ = windows.ShowWindow(win, 5);
    _ = windows.UpdateWindow(win);
    var msg: windows.MSG = windows.MSG{};
    while (windows.GetMessageA(&msg, null, 0, 0) != 0 and !exit) {
        _ = windows.TranslateMessage(&msg);
        _ = windows.DispatchMessageA(&msg);
    }
    return 0;
}
