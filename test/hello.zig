const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {s}!\n", .{"world"});
}
pub fn print(comptime fmt: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(fmt, args) catch {
        unreachable;
    };
}
test "test print suspend on Windows" {
    print("WTF", .{});
}
// pub fn print1(comptime fmt: []const u8, args: anytype) void {
//     std.io.getStdOut().writer().print(fmt, args) catch |err| {
//         std.debug.print("{}", .{err});
//     };
// }
// test "test print suspend1 on Windows" {
//     print1("WTF1", .{});
// }
