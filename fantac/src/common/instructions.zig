const std = @import("std");

pub const OpCode = enum(u8) {
    move_im_reg,
    move_reg_reg,
    move_addr_reg,
    move_im_addr,
    move_reg_addr,
    move_indirect_reg_reg,

    add_im_reg,
    add_reg_reg,

    jump,
    jump_eq,
    jump_lth,
    jump_gth,

    push,
    pop,

    SIZE,
};

pub const MAX_ARGUMENTS: u4 = 4;

pub const ArgumentType = enum(u4) {
    register,
    immediate,
    address,
};

pub const OpCodeSignature = struct {
    op_code: OpCode,
    arguments: []const ArgumentType,

    pub fn init(op_code: OpCode, arguments: []const ArgumentType) OpCodeSignature {
        if (arguments.len <= MAX_ARGUMENTS) {
            return OpCodeSignature{ .op_code = op_code, .arguments = arguments };
        }
        std.debug.panic("OpCodeFmt has too many arguments! Max Arguments are {}!", .{MAX_ARGUMENTS});
    }
};

pub const Argument = union(ArgumentType) {
    register: u8,
    immediate: u16,
    address: u16,

    pub fn activeSize(self: *Argument) u16 {
        const info = @typeInfo(Argument);
        const fields = info.@"union".fields;
        inline for (fields, 0..fields.len) |field, i| {
            if (@intFromEnum(self.*) == i) {
                return @sizeOf(field.type);
            }
        }
        return 0;
    }
};

pub const signatures = [_]OpCodeSignature{
    OpCodeSignature.init(
        OpCode.move_im_reg,
        &[_]ArgumentType{ .register, .immediate },
    ),
    OpCodeSignature.init(
        OpCode.move_reg_reg,
        &[_]ArgumentType{ .register, .register },
    ),
    OpCodeSignature.init(
        OpCode.move_addr_reg,
        &[_]ArgumentType{ .register, .address },
    ),
    OpCodeSignature.init(
        OpCode.move_im_addr,
        &[_]ArgumentType{ .address, .immediate },
    ),
    OpCodeSignature.init(
        OpCode.move_reg_addr,
        &[_]ArgumentType{ .address, .register },
    ),
    OpCodeSignature.init(
        OpCode.move_indirect_reg_reg,
        &[_]ArgumentType{ .register, .register },
    ),

    OpCodeSignature.init(
        OpCode.add_im_reg,
        &[_]ArgumentType{ .register, .immediate },
    ),
    OpCodeSignature.init(
        OpCode.add_reg_reg,
        &[_]ArgumentType{ .register, .register },
    ),
};
