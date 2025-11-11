const Span = @This();

start: u32 = 0,
end: u32 = 0,
main: u32 = 0,

pub fn length(self: Span) u32 {
    return self.end - self.start;
}
