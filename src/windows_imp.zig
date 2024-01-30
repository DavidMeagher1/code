const std = @import("std");
const builtin = @import("builtin");
const win = @import("./windows/windows.zig");

test "get_parent_process_id" {
    var pid: win.DWORD = @as(win.DWORD, 0) -% 1;
    pid = win.GetCurrentProcessId();
    const handle: win.HANDLE = win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0);
    var processEntry: win.PROCESSENTRY32 = undefined;
    processEntry = win.PROCESSENTRY32{};

    if (win.Process32First(handle, &processEntry)) {
        while (true) {
            if (processEntry.th32ProcessID == pid) {
                std.debug.print("\n pid: {any} has parent {any}\n", .{ pid, processEntry.th32ParentProcessID });
            }
            if (!win.Process32Next(handle, &processEntry)) {
                break;
            }
        }
    }
    _ = win.CloseHandle(handle);
}
