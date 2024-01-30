const std = @import("std");

const ColorType = enum {
    RGBA,
};

const RGBAColor = packed struct(u32) {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const DefaultColorType: ColorType = ColorType.RGBA;
const Color = switch (DefaultColorType) {
    .RGBA => RGBAColor,
};
