const std = @import("std");

pub const ISA8Bit = enum {
    Imm,
    Load,
    Store,
};
