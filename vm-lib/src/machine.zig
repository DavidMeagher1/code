const Machine = @This();
const Memory = @import("./memory.zig");
const Register = @import("./register.zig");

memory: Memory,
registers: []Register,
setup_fn: *const fn (ctx: *Machine) anyerror!void,
step_fn: *const fn (ctx: *Machine) anyerror!bool,
register_offset: usize = 0,

pub fn setup(self: *Machine) !void {
    for (self.registers) |register| {
        if (!register.is_masking) {
            self.register_offset += register.width;
        }
    }
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

pub fn load_program(self: *Machine, where: usize, program: []const u8) !void {
    try self.memory.write(where, program);
}
