pub fn cast_slice_to(comptime T: type, s: anytype) []T {
    const SliceT = @TypeOf(s);
    const slice_info = @typeInfo(SliceT);
    const Child = switch (slice_info) {
        .Pointer => |ptr| ptr.child,
        else => {
            @panic("not a pointer");
        },
    };
    const child_size = @sizeOf(Child);
    const t_size = @sizeOf(T);
    if (child_size == t_size) {
        return @as([*]T, @ptrCast(@as([*]Child, @ptrCast(s))))[0..s.len];
    } else {
        const new_len = (child_size / t_size) * s.len;
        return @as([*]T, @ptrCast(@as([*]Child, @ptrCast(s))))[0..new_len];
    }
}
