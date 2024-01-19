const std = @import("std");
const builtin = @import("builtin");
/// Constants
pub const MAX_PATH: usize = 260;
pub const TH32CS_SNAPPROCESS: DWORD = 0x00_00_00_02;
/// Types
pub const CHAR = u8;
pub const LONG = i32;
pub const DWORD = u32;
pub const ULONG_PTR = usize;
pub const HANDLE = *anyopaque;
pub const PROCESSENTRY32 = extern struct {
    size: DWORD = @sizeOf(@This()),
    cntUsage: DWORD = 0,
    th32ProcessID: DWORD = 0,
    th32DefaultHeapID: ULONG_PTR = 0,
    th32ModuleID: DWORD = 0,
    cntThreads: DWORD = 0,
    th32ParentProcessID: DWORD = 0,
    pcPriClassBase: LONG = 0,
    flags: DWORD = 0,
    szExeFile: [MAX_PATH]CHAR = std.mem.zeroes([MAX_PATH]CHAR),
};

/// External Functions
pub extern fn CloseHandle(handle: HANDLE) bool;

pub extern fn GetCurrentProcessId() DWORD; //processthreadsapi.h

pub extern fn GetProcessId(handle: HANDLE) DWORD; // ||

pub extern fn CreateToolhelp32Snapshot(flags: DWORD, th32ProcessID: DWORD) HANDLE;

pub extern fn Process32Next(handle: HANDLE, pentry: *PROCESSENTRY32) bool;

pub extern fn Process32First(handle: HANDLE, pentry: *PROCESSENTRY32) bool;

test "b" {
    var pid: DWORD = @as(DWORD, 0) -% 1;
    pid = GetCurrentProcessId();
    const handle: HANDLE = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    var processEntry: PROCESSENTRY32 = undefined;
    processEntry = PROCESSENTRY32{};

    if (Process32First(handle, &processEntry)) {
        while (true) {
            if (processEntry.th32ProcessID == pid) {
                std.debug.print("\n pid: {any} has parent {any}\n", .{ pid, processEntry.th32ParentProcessID });
            }
            if (!Process32Next(handle, &processEntry)) {
                break;
            }
        }
    }
    _ = CloseHandle(handle);
}
