const _cpu = @import("./cpu.zig");
const Register = @This();

value: u16,

pub fn get(self: Register) u16 {
    return self.value;
}

pub fn set(self: *Register, value: u16) void {
    self.value = value;
}
