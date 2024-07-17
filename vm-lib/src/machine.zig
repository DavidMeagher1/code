const Machine = @This();
const Memory = @import("./memory.zig");
const Register = @import("./register.zig");

memory: Memory,
registers: []Register,
setup_fn: *const fn (ctx: *Machine) anyerror!void,
step_fn: *const fn (ctx: *Machine) anyerror!bool,

pub fn setup(self: *Machine) !void {
    try self.setup_fn(self);
}

pub fn step(self: *Machine) !bool {
    return try self.step_fn(self);
}

pub fn run(self: *Machine) !void {
    try self.setup();
    var do_step: bool = try self.step();
    while (do_step) {
        do_step = try self.step();
    }
}
