pub const HANDLE = *anyopaque;

pub extern fn CloseHandle(handle: HANDLE) bool;
