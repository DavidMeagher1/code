const mem = @import("std").mem;
const types = @import("types.zig");
const io = @import("io.zig");
const file = @import("file.zig");
// TH32CS?
pub const TH32CS_SNAPPROCESS: types.DWORD = 0x00_00_00_02;

pub const PROCESSENTRY32 = extern struct {
    size: types.DWORD = @sizeOf(@This()),
    cntUsage: types.DWORD = 0,
    th32ProcessID: types.DWORD = 0,
    th32DefaultHeapID: types.ULONG_PTR = 0,
    th32ModuleID: types.DWORD = 0,
    cntThreads: types.DWORD = 0,
    th32ParentProcessID: types.DWORD = 0,
    pcPriClassBase: types.LONG = 0,
    flags: types.DWORD = 0,
    szExeFile: [file.MAX_PATH]types.CHAR = mem.zeroes([file.MAX_PATH]types.CHAR),
};
pub extern fn GetCurrentProcessId() types.DWORD; //processthreadsapi.h

pub extern fn GetProcessId(handle: io.HANDLE) types.DWORD; // ||

pub extern fn CreateToolhelp32Snapshot(flags: types.DWORD, th32ProcessID: types.DWORD) io.HANDLE;

pub extern fn Process32Next(handle: io.HANDLE, pentry: *PROCESSENTRY32) bool;

pub extern fn Process32First(handle: io.HANDLE, pentry: *PROCESSENTRY32) bool;
