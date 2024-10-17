pub const ParseHexError = error{
    InvalidCharacter,
    Overflow,
};

pub fn parse_hex(comptime T: type, str: []const u8) ParseHexError!T {
    const radix = 16;
    var accum: T = 0;
    if (str.len > (@sizeOf(T) * 2)) return error.Overflow;
    for (str) |char| {
        if (accum != 0) {
            accum *= radix;
        }
        accum += try charToDigit(char, radix);
    }
}

pub fn charToDigit(char: u8, base: u8) (error{InvalidCharacter}!u8) {
    const digit = switch (char) {
        '0'...'9' => char - '0',
        'A'...'Z' => char - 'A' + 10,
        'a'...'z' => char - 'a' + 10,
        else => return error.InvalidCharacter,
    };
    if (digit >= base) return error.InvalidCharacter;
    return digit;
}
