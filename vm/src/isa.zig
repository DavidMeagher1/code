const std = @import("std");

const ISA8Bit = enum {
    Invalid,
    Imm,
    Load,
    Store,
};
