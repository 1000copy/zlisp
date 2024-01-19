const std = @import("std");
const expect = @import("std").testing.expect;
test "test print suspend on Windows" {
    // std.debug.print("WTF", .{});
    try expect(1 == 1);
    // try expect(1 == 2);
}
