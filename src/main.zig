const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = @import("token.zig");
const Assembler = @import("parse.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test Forth-like code
    const source: [:0]const u8 =
        \\|10
        \\$5
        \\:main
        \\    # 5
        \\&loop
        \\    DUP
        \\    PRINT_CHR
        \\    # 10
        \\    PRINT_CHR
        \\    DEC
        \\    DUP
        \\    ? ;loop
        \\    DROP
        \\    HALT
    ;

    std.debug.print("Source code:\n{s}\n\n", .{source});

    // Tokenize
    var lexer = Lexer{
        .input = source,
    };

    var tokens = std.ArrayListUnmanaged(Token){};
    defer tokens.deinit(allocator);
    var tok: Token = .{
        .tag = .invalid,
        .location = .{},
    };
    while (tok.tag != .eof) {
        tok = lexer.next();
        try tokens.append(allocator, tok);
        if (tok.tag == .eof) break;
    }

    // std.debug.print("Tokens:\n", .{});
    std.debug.print("Total tokens: {d}\n", .{tokens.items.len});
    // for (tokens.items) |token| {
    //     const lexeme = if (token.tag == .number_literal or token.tag == .string_literal or token.tag == .character_literal or token.tag == .global_label or token.tag == .local_label or token.tag == .label_reference)
    //         source[token.location.start_index..token.location.end_index]
    //     else
    //         Token.symbol(token);
    //     //std.debug.print("  {s}: '{s}'\n", .{ @tagName(token.tag), lexeme });
    // }
    std.debug.print("\n", .{});

    // Assemble
    var assembler = try Assembler.init(allocator, source, tokens.items);
    defer assembler.deinit();
    // Register external identifiers
    try assembler.registerExternalIdentifier("PRINT_CHR", 0x01);

    const bytecode = try assembler.assemble();
    defer allocator.free(bytecode);

    std.debug.print("Bytecode ({} bytes):\n", .{bytecode.len});
    for (bytecode, 0..) |byte, i| {
        std.debug.print("{x:0>2} ", .{byte});
        if ((i + 1) % 16 == 0) std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});

    // Save to file
    const file = try std.fs.cwd().createFile("test.bin", .{});
    defer file.close();
    try file.writeAll(bytecode);

    std.debug.print("Saved bytecode to test.bin\n", .{});
}
