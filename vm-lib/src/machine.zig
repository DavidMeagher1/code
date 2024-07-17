const Machine = @This();
const Memory = @import("./memory.zig");
const Register = @import("./register.zig");

memory: Memory,
registers: []Register,
setup_fn: *const fn (ctx: *Machine) void,
step_fn: *const fn (ctx: *Machine) void,

pub fn setup(self: *Machine) void {
    self.setup_fn();
}

pub fn step(self: *Machine) void {
    self.step();
}
