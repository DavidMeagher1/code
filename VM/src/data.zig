//const types = @import("./types.zig");
const std = @import("std");
const mem = std.mem;

const BoundedArray = std.BoundedArray;

pub const PackedSliceKinds = enum(u4) {
    U8 = 1,
    U16 = 2,
    U32 = 4,
    U64 = 8,
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

pub fn getPackKind(slice: []u8) PackedSliceKinds {
    return @as(PackedSliceKinds, @enumFromInt(nearestPowerOfTwo(slice.len)));
}

pub fn BigNumberUnmanaged(comptime T: type) type {
    const info = @typeInfo(T).Int;
    return struct {
        const Self = @This();
        pub const BigMathError = error{
            Overflow,
            DivideByZero,
        };
        value: []T,

        pub fn init(allocator: mem.Allocator, value: []const T) !Self {
            const inital_value = try allocator.alloc(T, value.len);
            @memcpy(inital_value, value);
            return Self{
                .value = inital_value,
            };
        }

        pub fn deinit(self: Self, allocator: mem.Allocator) void {
            allocator.free(self.value);
        }

        pub fn isZero(self: Self) bool {
            for (self.value) |val| {
                if (val != 0) {
                    return false;
                }
            }
            return true;
        }

        fn sliceIsZero(slice: []T) bool {
            for (slice) |val| {
                if (val != 0) {
                    return false;
                }
            }
            return true;
        }

        fn sliceIsLessThan(a: []T, b: []T) bool {
            const largest = if (a.len < b.len) b else a;
            const smallest = if (largest == a) b else a;
            // if they have the same length
            var i = largest.len - 1;
            while (i >= 0) {
                if (i > smallest.len and largest[i] == 0) {
                    continue;
                } else {
                    return smallest == a;
                }
                if (a[i] != b[i]) {
                    return a[i] < b[i];
                }
                i -= 1;
            }
            return false;
        }

        fn sliceIsLessThanOrEqual(a: []T, b: []T) bool {
            const largest = if (a.len < b.len) b else a;
            const smallest = if (largest == a) b else a;
            // if they have the same length
            var i = largest.len - 1;
            while (i >= 0) {
                if (i > smallest.len and largest[i] == 0) {
                    continue;
                } else {
                    return smallest == a;
                }
                if (a[i] != b[i]) {
                    return a[i] <= b[i];
                }
                i -= 1;
            }
            return false;
        }

        fn sliceIsEqual(a: []T, b: []T) bool {
            if (a.len != b.len) {
                return false;
            }
            var i = a.len - 1;
            while (i >= 0) {
                if (a[i] != b[i]) {
                    return false;
                }
                i -= 1;
            }
            return true;
        }

        fn addSliceWithOverflow(a: []T, b: []T, output: []T) bool {
            const min_len = @min(a.len, b.len);
            const max_len = @max(a.len, b.len);
            const largest = if (a.len == max_len) a else b;
            //the end of the slice is the beggining after casting up
            var i: usize = 0;
            var carry: u1 = 0;
            while (i < min_len) {
                const inital_product = @addWithOverflow(a[i], b[i]);
                const with_carry = @addWithOverflow(inital_product[0], carry);
                output[i] = with_carry[0];
                carry = inital_product[1] | with_carry[1];
                i += 1;
            }
            if (min_len != max_len) {
                @memcpy(output[i..], largest[i..output.len]);
            }
            return carry == 1;
        }

        fn subSliceWithOverflow(a: []T, b: []T, output: []T) bool {
            const min_len = @min(a.len, b.len);
            const max_len = @max(a.len, b.len);
            const largest = if (a.len == max_len) a else b;
            //the end of the slice is the beggining after casting up
            var i: usize = 0;
            var carry: u1 = 0;
            while (i < min_len) {
                const inital_product = @subWithOverflow(a[i], b[i]);
                const with_carry = @subWithOverflow(inital_product[0], carry);
                output[i] = with_carry[0];
                carry = inital_product[1] | with_carry[1];
                i += 1;
            }
            if (min_len != max_len) {
                @memcpy(output[i..], largest[i..output.len]);
            }
            return carry == 1;
        }

        fn mulSliceWithOverflow(a: []T, b: []T, output: []T) bool {
            const ProductType = @Type(std.builtin.Type{ .Int = .{ .bits = info.bits * 2, .signedness = info.signedness } });
            const min_len = @min(a.len, b.len);
            const max_len = @max(a.len, b.len);
            const largest = if (a.len == max_len) a else b;
            //the end of the slice is the beggining after casting up
            var i: usize = 0;
            var carry: T = 0;
            while (i < min_len) {
                const ax: ProductType = @intCast(a[i]);
                const bx: ProductType = @intCast(b[i]);
                const inital_product = @mulWithOverflow(ax, bx);
                const inter_product: T = @truncate(inital_product[0]);
                const with_carry = @addWithOverflow(inter_product, carry);
                output[i] = @truncate(with_carry[0]);
                carry = @as(T, @truncate(@shrExact(inital_product[0] ^ inter_product, @sizeOf(T) * 8))) + with_carry[1];
                i += 1;
            }
            if (min_len != max_len) {
                @memcpy(output[i..output.len], largest[i..output.len]);
            }
            return carry > 0;
        }

        fn divSlice(dividend: []T, inital_divisor: []T, quotent: []T) !void {
            //take b and comare it to the digits of a;
            // output is assumed to be the same size as the largest of the two numbers
            if (sliceIsZero(inital_divisor)) {
                return error.DivideByZero;
            }
            if (sliceIsEqual(inital_divisor, &[_]T{1})) {
                quotent = dividend;
            }
            var i: usize = 0;
            var divisor = dividend[0..i];
        }

        pub fn addWithOverFlow(a: Self, allocator: mem.Allocator, b: Self) !struct { Self, bool } {
            const inital_value = try allocator.alloc(T, @max(a.value.len, b.value.len));
            const carry = Self.addSliceWithOverflow(a.value, b.value, inital_value);
            return .{ try Self.init(allocator, inital_value), carry };
        }

        pub fn add(a: Self, allocator: mem.Allocator, b: Self) !Self {
            var result = try a.addWithOverFlow(allocator, b);
            if (result[1] == true) {
                result[0].deinit(allocator);
                return error.Overflow;
            }
            return result[0];
        }

        pub fn subWithOverFlow(a: Self, allocator: mem.Allocator, b: Self) !struct { Self, bool } {
            const inital_value = try allocator.alloc(T, @max(a.value.len, b.value.len));
            const carry = Self.subSliceWithOverflow(a.value, b.value, inital_value);
            return .{ try Self.init(allocator, inital_value), carry };
        }

        pub fn sub(a: Self, allocator: mem.Allocator, b: Self) !Self {
            var result = try a.subWithOverFlow(allocator, b);
            if (result[1] == true) {
                result[0].deinit(allocator);
                return error.Overflow;
            }
            return result[0];
        }

        pub fn mulWithOverFlow(a: Self, allocator: mem.Allocator, b: Self) !struct { Self, bool } {
            const inital_value = try allocator.alloc(T, @max(a.value.len, b.value.len));
            const carry = Self.mulSliceWithOverflow(a.value, b.value, inital_value);
            return .{ try Self.init(allocator, inital_value), carry };
        }

        pub fn div(a: Self, allocator: mem.Allocator, b: Self) !Self {
            const largest = if (sliceIsLessThan(a.value, b.value)) b else a;
            const inital_value = try allocator.alloc(T, largest.len);
            try Self.divSlice(a.value, b.value, inital_value);
            return try Self.init(allocator, inital_value);
        }

        pub fn mul(a: Self, allocator: mem.Allocator, b: Self) !Self {
            var result = try a.mulWithOverFlow(allocator, b);
            if (result[1] == true) {
                result[0].deinit(allocator);
                return error.Overflow;
            }
            return result[0];
        }
    };
}

pub const StackNumber = struct {
    bytes: []u8,

    pub fn add() void {}
};

const testing = std.testing;

test "add" {
    var fixed_heap = try BoundedArray(u8, 1024).init(1024);
    var fba = std.heap.FixedBufferAllocator.init(fixed_heap.slice());
    const alloc = fba.allocator();
    const Big8 = BigNumberUnmanaged(u8);
    const a: Big8 = try Big8.init(alloc, &[_]u8{ 255, 0 });
    defer a.deinit(alloc);
    const b: Big8 = try Big8.init(alloc, &[_]u8{ 1, 0 });
    defer b.deinit(alloc);
    const product = try a.add(alloc, b);
    defer product.deinit(alloc);
    std.debug.print("\n\nAdd: {any}\n\n", .{product});
}

test "sub" {
    var fixed_heap = try BoundedArray(u8, 1024).init(1024);
    var fba = std.heap.FixedBufferAllocator.init(fixed_heap.slice());
    const alloc = fba.allocator();
    const Big8 = BigNumberUnmanaged(u8);
    const a: Big8 = try Big8.init(alloc, &[_]u8{ 0, 1 });
    defer a.deinit(alloc);
    const b: Big8 = try Big8.init(alloc, &[_]u8{ 1, 0 });
    defer b.deinit(alloc);
    const product = try a.sub(alloc, b);
    defer product.deinit(alloc);
    std.debug.print("\n\nSub: {any}\n\n", .{product});
}

test "mul" {
    var fixed_heap = try BoundedArray(u8, 1024).init(1024);
    var fba = std.heap.FixedBufferAllocator.init(fixed_heap.slice());
    const alloc = fba.allocator();
    const Big16 = BigNumberUnmanaged(u16);
    const x = 255;
    const a: Big16 = try Big16.init(alloc, &[_]u16{ 65535, 0 });
    defer a.deinit(alloc);
    const b: Big16 = try Big16.init(alloc, &[_]u16{ x, 0 });
    defer b.deinit(alloc);
    const product = try a.mul(alloc, b);
    defer product.deinit(alloc);
    const expected = @as(u32, 65535) * @as(u32, x);
    const actual = std.mem.bytesToValue(u32, product.value);
    std.debug.print("\n\nMul: {any}. AsBits: {b}{b:0>8}, cast:{d}, expected: {b} cast:{d} \n\n", .{
        product, product.value[1], product.value[0], actual, expected, expected,
    });
    try testing.expectEqual(expected, actual);
}

test "div" {
    var fixed_heap = try BoundedArray(u8, 1024).init(1024);
    var fba = std.heap.FixedBufferAllocator.init(fixed_heap.slice());
    const alloc = fba.allocator();
    const Big8 = BigNumberUnmanaged(u8);
    const x = 3;
    const a: Big8 = try Big8.init(alloc, &[_]u8{ 255, 255 });
    defer a.deinit(alloc);
    const b: Big8 = try Big8.init(alloc, &[_]u8{ x, 0 });
    defer b.deinit(alloc);
    const product = try a.div(alloc, b);
    defer product.deinit(alloc);
    const expected = @as(u16, 0xFFFF) / @as(u16, x);
    const actual = std.mem.bytesToValue(u16, product.value);
    std.debug.print("\n\nMul: {any}. AsBits: {b}{b:0>8}, cast:{d}, expected: {b} cast:{d} \n\n", .{
        product, product.value[1], product.value[0], actual, expected, expected,
    });
    try testing.expectEqual(expected, actual);
}
