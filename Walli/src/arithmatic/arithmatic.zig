//const types = @import("./types.zig");
const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const Allocator = mem.Allocator;

pub fn Pair(comptime T: type, U: type) type {
    return struct {
        T,
        U,
    };
}

pub const ArithmaticError = error{
    Overflow,
    DivideByZero,
};

pub fn nearestPowerOfTwo(bits: u16) u29 {
    return std.math.pow(u29, 2, @intFromFloat(@ceil(@log(@as(f32, @floatFromInt(bits))) / @log(2.0))));
}

pub fn isPowerOfTwo(x: u29) bool {
    return (x != 0) and (x & (x - 1)) == 0;
}

pub fn sliceCast(comptime T: type, slice: anytype) []T {
    const info = @typeInfo(@TypeOf(slice));
    const Child = info.Pointer.child;
    const child_size = @sizeOf(Child);
    const t_size = @sizeOf(T);
    const amount: usize = @intFromFloat(@as(f32, @floatFromInt(slice.len * child_size)) / t_size);
    //std.debug.print("\n\namount: {d}, t_size: {d}\n", .{ amount, t_size });
    //const blen = bytes.len;
    const res: [*]T = @alignCast(@as([*]align(@alignOf(u8)) T, @ptrCast(@constCast(slice))));
    return res[0..amount];
}

fn isZero(comptime T: type, slice: []const T) bool {
    for (slice) |val| {
        if (val != 0) {
            return false;
        }
    }
    return true;
}

fn isLessThan(comptime T: type, a: []T, b: []T) bool {
    const largest = if (@max(a.len, b.len) == a.len) a else b;
    const smallest = if (largest.ptr == a.ptr) b else a;
    // if they have the same length
    var i = largest.len;
    while (i > 0) {
        const j = i - 1;
        if (j > smallest.len - 1) {
            if (largest[j] == 0) {
                i -= 1;
                continue;
            } else {
                return smallest.ptr == a.ptr;
            }
        } else {
            // ---
            if (a[j] < b[j]) {
                return a[j] < b[j];
            }
            i -= 1;
        }
    }
    return false;
}

fn isLessThanOrEqual(comptime T: type, a: []T, b: []T) bool {
    const largest = if (@max(a.len, b.len) == a.len) a else b;
    const smallest = if (largest.ptr == a.ptr) b else a;
    // if they have the same length
    var i = largest.len;
    while (i > 0) {
        const j = i - 1;
        if (j > smallest.len - 1) {
            if (largest[j] == 0) {
                i -= 1;
                continue;
            } else {
                return smallest.ptr == a.ptr;
            }
        } else {
            // ---
            if (a[j] <= b[j]) {
                return a[j] < b[j];
            }
            i -= 1;
        }
    }
    return false;
}

fn isEqual(comptime T: type, a: []T, b: []T) bool {
    const largest = if (@max(a.len, b.len) == a.len) a else b;
    const smallest = if (&largest == &a) b else b;
    if (a.len != b.len) {
        return false;
    }
    var i = a.len - 1;
    while (i >= 0) {
        if (!(i > smallest.len - 1 and largest[0] == 0)) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        i -= 1;
    }
    return true;
}

fn trimLeadingZeros(comptime T: type, array: []T) []T {
    var length = array.len;
    while (length - 1 >= 0) {
        if (array[length - 1] != 0) {
            break;
        }
        length -= 1;
    }
    return array[0..length];
}

fn trimTrailingZeros(comptime T: type, array: []T) []T {
    var index: usize = 0;
    for (0..array.len) |i| {
        if (array[i] == 0) {
            index += 1;
        } else {
            break;
        }
    }
    return array[index..array.len];
}

pub fn twosCompliment(comptime T: type, array: []T) []T {
    for (0..array.len) |i| {
        array[i] = (~array[i]);
    }
    array[0] += 1;
    return array;
}

fn addWithOverflow(comptime T: type, alloc: Allocator, summand_a: []T, summand_b: []T) !Pair([]T, u1) {
    const max_len = @max(summand_a.len, summand_b.len) + 1;
    var tmp_sum = try alloc.alloc(T, max_len + 1);
    //TODO switch to using array lists
    //the end of the slice is the beggining after casting up
    var i: usize = 0;
    var carry: u1 = 0;
    while (i < max_len) {
        const sa: T = if (i < summand_a.len) summand_a[i] else 0;
        const sb: T = if (i < summand_b.len) summand_b[i] else 0;
        if (sa == 0 and sb == 0 and carry == 0) {
            break;
        }
        const inital_product = @addWithOverflow(sa, sb);
        const with_carry = @addWithOverflow(inital_product[0], carry);
        tmp_sum[i] = with_carry[0];
        carry = inital_product[1] | with_carry[1];
        i += 1;
    }
    const sum = try alloc.alloc(T, i);
    @memcpy(sum, tmp_sum[0..i]);
    alloc.free(tmp_sum);
    return .{ sum, carry };
}

fn subWithOverflow(comptime T: type, alloc: Allocator, minuend: []T, subtrahend: []T) !Pair([]T, u1) {
    const max_len = @max(minuend.len, subtrahend.len);
    var difference = try alloc.alloc(T, max_len); // TODO see if this needs to be this big
    @memset(difference, 0);
    var i: usize = 0;
    var carry: u1 = 0;
    while (i < max_len) {
        var min: T = 0;
        var sub: T = 0;
        if (i < minuend.len) {
            min = minuend[i];
        }
        if (i < subtrahend.len) {
            sub = subtrahend[i];
        }
        const inital_product = @subWithOverflow(min, sub);
        const with_carry = @subWithOverflow(inital_product[0], carry);
        difference[i] = with_carry[0];
        carry = inital_product[1] | with_carry[1];
        i += 1;
    }

    return .{ difference, carry };
}

test "subtraction" {
    var ba = try std.BoundedArray(u8, 1024).init(1024);
    var fba = std.heap.FixedBufferAllocator.init(ba.slice());
    // 11110000
    // 00001111
    //
    //
    const alloc = fba.allocator();
    const bytes_a = &[_]u8{ 20, 2 };
    const bytes_b = &[_]u8{ 32, 8 };
    const val_a = mem.bytesToValue(u16, bytes_a);
    const val_b = mem.bytesToValue(u16, bytes_b);
    const product = try addWithOverflow(u8, alloc, @constCast(bytes_a), twosCompliment(u8, @constCast(bytes_b)));
    std.debug.print("\n\n{b}\n\n", .{(@as(u8, 0x11))});
    std.debug.print("\n\nproduct: {b}, va: {d}, vb:{d}, product as number: {d}, val product: {d}, val bytes: {b}\n\n", .{
        product[0],
        val_a,
        val_b,
        @subWithOverflow(val_a, val_b)[0],
        mem.bytesToValue(u16, product[0]),
        mem.toBytes(@subWithOverflow(val_a, val_b)[0]),
    });
}

fn mulWithOverflow(comptime T: type, alloc: Allocator, factor_a: []T, factor_b: []T) !Pair([]T, T) {
    const info = @typeInfo(T).Int;
    const ProductType = @Type(std.builtin.Type{ .Int = .{ .bits = info.bits * 2, .signedness = info.signedness } });
    const min_len = @min(factor_a.len, factor_b.len);
    const largest = if (@max(factor_a.len, factor_b.len) == factor_a.len) factor_a else factor_b;
    var product = try alloc.alloc(T, largest.len);
    //the end of the slice is the beggining after casting up
    var i: usize = 0;
    var carry: T = 0;
    while (i < min_len) {
        const ax: ProductType = @intCast(factor_a[i]);
        const bx: ProductType = @intCast(factor_b[i]);
        const inital_product = @mulWithOverflow(ax, bx);
        const inter_product: T = @truncate(inital_product[0]);
        const with_carry = @addWithOverflow(inter_product, carry);
        product[i] = @truncate(with_carry[0]);
        carry = @as(T, @truncate(@shrExact(inital_product[0] ^ inter_product, @sizeOf(T) * 8))) + with_carry[1];
        i += 1;
    }
    if (min_len != largest.len) {
        @memcpy(product[i..product.len], largest[i..product.len]);
    }
    return .{ product, carry };
}

fn oldDivWithRemainder(comptime T: type, alloc: Allocator, initial_dividend: []T, initial_divisor: []T) !Pair([]T, []T) {
    if (isZero(T, initial_divisor)) {
        return error.DivideByZero;
    }
    var quotent = try alloc.alloc(T, initial_dividend.len);
    var quotent_position = quotent.len - 1;
    if (isEqual(T, initial_divisor, @constCast(&[_]T{1}))) {
        quotent = initial_dividend;
        return .{ quotent, @constCast(&[_]T{0}) };
    }
    var divisor_position: usize = initial_dividend.len - initial_divisor.len;
    var dividend_position = initial_dividend.len - 1;

    var divisor = try alloc.alloc(T, initial_dividend.len);
    defer alloc.free(divisor);
    @memcpy(divisor[divisor_position..divisor.len], initial_divisor);

    var dividend = try alloc.alloc(T, initial_dividend.len);
    defer alloc.free(dividend);
    @memcpy(dividend, initial_dividend);

    while (!isZero(T, dividend)) {
        if (isLessThan(T, dividend[dividend_position..dividend.len], divisor[divisor_position..divisor.len])) {
            dividend_position -= 1;
            divisor_position -= 1;
            divisor[divisor_position] = dividend[dividend_position];
            quotent[quotent_position] = 0;
        } else {
            const current_dividend = dividend[dividend_position..dividend.len];
            const q = try divGetQuotent(T, alloc, current_dividend, divisor[divisor_position..divisor.len]);
            std.debug.print("\n\n{any}\n\n", .{q});
            quotent[quotent_position] = q;
            const nearest_amount = try mulWithOverflow(T, alloc, divisor[divisor_position..divisor.len], @constCast(&[_]T{q}));
            const difference = try subWithOverflow(T, alloc, current_dividend, nearest_amount[0]);
            const new_divisor_pisition = divisor.len - difference[0].len;
            @memcpy(divisor[new_divisor_pisition..divisor.len], difference[0]);
            alloc.free(nearest_amount[0]);
            alloc.free(difference[0]);
            divisor_position = new_divisor_pisition;
            if (dividend_position == 0) {
                break;
            }
            quotent_position -= 1;
            dividend_position -= 1;
            divisor_position -= 1;
            divisor[divisor_position] = dividend[dividend_position];
        }
    }
    const actual_quotent = try alloc.alloc(T, quotent.len - quotent_position);
    @memcpy(actual_quotent, quotent[quotent_position..quotent.len]);
    alloc.free(quotent);
    const remainder = try alloc.alloc(T, divisor.len - divisor_position);
    @memcpy(remainder, divisor[initial_dividend.len - 1 - divisor_position .. divisor.len]);
    return .{ actual_quotent, remainder };
}

fn divWithRemainder(comptime T: type, alloc: Allocator, initial_dividend: []T, divisor: []T) !Pair([]T, []T) {
    if (isZero(T, divisor)) {
        return error.DivideByZero;
    }

    var dividend_container = try alloc.alloc(T, initial_dividend.len);

    var dividend_container_index = initial_dividend.len - 1;
    var dividend_index = dividend_container_index;
    dividend_container[dividend_container_index] = initial_dividend[dividend_index];

    var quotent_container = try alloc.alloc(T, initial_dividend.len);
    var quotent_index = quotent_container.len - 1;

    var dividend = dividend_container[dividend_container_index..dividend_container.len];
    while (!isZero(T, dividend)) {
        if (isLessThan(T, divisor, dividend)) {
            std.debug.print("\n\nhere\n\n", .{});
            // bottom less than top eg 4/2
            const quotent_digit = try divGetQuotent(T, alloc, dividend, divisor);
            quotent_container[quotent_index] = quotent_digit;
            const subtrahend = try mulWithOverflow(T, alloc, @constCast(&[_]T{quotent_digit}), divisor);
            const difference = try subWithOverflow(T, alloc, dividend, subtrahend[0]);
            alloc.free(subtrahend[0]);
            // divisor now becomes the difference
            dividend_container_index = dividend_container.len - difference[0].len;
            @memcpy(dividend_container[dividend_container_index..dividend_container.len], difference[0]);
            alloc.free(difference[0]);
            if (dividend_index == 0) {
                break;
            }
            quotent_index -= 1;
            dividend_container_index -= 1;
            dividend_index -= 1;
            dividend_container[dividend_container_index] = initial_dividend[dividend_index];
            dividend = dividend_container[dividend_container_index..dividend_container.len];
        } else {
            //dividend == done?
            quotent_container[quotent_index] = 0;
            if (dividend_index == 0) {
                break;
            }
            quotent_index -= 1;
            dividend_index -= 1;
            dividend_container_index -= 1;
            dividend_container[dividend_container_index] = initial_dividend[dividend_index];
            dividend = dividend_container[dividend_container_index..dividend_container.len];
        }
    }
    //TODO RETURN QUOTENT AND REMAINDER
    const remainder = try alloc.alloc(T, dividend_container.len - dividend_container_index);
    @memcpy(remainder, dividend_container[dividend_container_index..dividend_container.len]);
    alloc.free(dividend_container);
    const quotent = try alloc.alloc(T, quotent_container.len - quotent_index);
    @memcpy(quotent, quotent_container[quotent_index..quotent_container.len]);
    alloc.free(quotent_container);

    return .{ quotent, remainder };
}

fn divGetQuotent(comptime T: type, alloc: Allocator, dividend: []T, divisor: []T) !T {
    var quotent: T = 1;
    var current_dividend = try alloc.alloc(T, dividend.len);
    @memcpy(current_dividend, dividend);
    while (isLessThan(T, divisor, current_dividend)) {
        const subResult = try subWithOverflow(T, alloc, current_dividend, divisor);
        alloc.free(current_dividend);
        current_dividend = subResult[0];
        quotent += 1;
    }
    alloc.free(current_dividend);
    std.debug.print("\n\nQuotent: {d}\n\n", .{quotent});
    return quotent;
}

test "division" {
    var ba = try std.BoundedArray(u8, 1024).init(1024);
    var fba = std.heap.FixedBufferAllocator.init(ba.slice());
    const alloc = fba.allocator();
    const bytes_a = &[_]u8{ 16, 1 };
    const bytes_b = &[_]u8{2};
    const val_a = mem.bytesToValue(u16, bytes_a);
    const val_b = mem.bytesToValue(u8, bytes_b);
    const product = try divWithRemainder(u8, alloc, @constCast(bytes_a), @constCast(bytes_b));
    std.debug.print("\n\nproduct: {any}, va: {d}, vb:{d}, pn: {d}, val_p: {d}, valb: {any}\n\n", .{
        product,
        val_a,
        val_b,
        val_a / val_b,
        mem.bytesToValue(u16, product[0]),
        mem.toBytes(val_a / val_b),
    });
}
