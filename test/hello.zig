const std = @import("std");
const expect = @import("std").testing.expect;
const test_allocator = std.testing.allocator;

const levelerror = error{
    no1,
    no2,
};
fn level3() !void {
    return levelerror.no2;
}
fn level2() !void {
    try level3();
}
fn level1() !void {
    try level2();
}
test "todo" {
    level1() catch |err| {
        print("{}", .{err});
    };
}
fn l3() !i32 {
    return levelerror.no2;
}
fn l2() !i32 {
    return 3;
}

// string作为函数参数的做法。
fn astring(a: []const u8) void {
    print("{s}", .{a});
}
test "string parameter of fn" {
    astring("astring");
}
