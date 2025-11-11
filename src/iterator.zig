pub fn Iterator(comptime T: type) type {
    return struct {
        const Error = error{
            OutOfBounds,
        };

        const Self = @This();
        index: u32 = 0,
        context: *opaque {},
        has_fn: *const fn (context: anytype, index: u32) bool,
        get_fn: *const fn (context: anytype, index: u32) ?T,

        pub fn has(self: *Self) bool {
            return self.has_fn(self.context, self.index);
        }

        pub fn advance(self: *Self) ?T {
            if (!self.has()) return null;
            const value = self.get_fn(self.context, self.index);
            self.index += 1;
            return value;
        }

        pub fn retreat(self: *Self) ?T {
            if (self.index == 0) return null;
            self.index -= 1;
            return self.get_fn(self.context, self.index);
        }

        pub fn current(self: *Self) ?T {
            if (!self.has()) return null;
            return self.get_fn(self.context, self.index);
        }

        pub fn ahead(self: *Self, amount: u32) ?T {
            const new_index = self.index + amount;
            if (!self.has_fn(self.context, new_index)) return null;
            return self.get_fn(self.context, new_index);
        }

        pub fn behind(self: *Self, amount: u32) ?T {
            if (!self.has_fn(self.context, self.index - amount)) return null;
            const new_index = self.index - amount;
            return self.get_fn(self.context, new_index);
        }

        pub fn goto(self: *Self, position: u32) Error!void {
            if (!self.has_fn(self.context, position)) {
                return error.OutOfBounds;
            }
            self.index = position;
        }
    };
}
