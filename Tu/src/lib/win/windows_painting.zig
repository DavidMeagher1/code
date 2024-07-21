const windows = @import("std").os.windows;
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
    rgbReserved: [32]windows.BYTE,
};
