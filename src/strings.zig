const std = @import("std");
const expect = std.testing.expect;
test "concat" {
    const b = try concat("hello,", "world");
    try expect(std.mem.eql(u8, "hello,world", b));
}
fn concat(a: []const u8, b: []const u8) ![]const u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var al = std.ArrayList(u8).init(allocator);
    defer al.deinit();
    try al.appendSlice(a);
    try al.appendSlice(b);
    return try allocator.dupe(u8, al.items);
}
test "String" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var str = String.init(allocator);
    defer str.deinit();
    try str.append("hello,");
    try str.append("world");
    try expect(std.mem.eql(u8, "hello,world", str.items()));
}
const String = struct {
    al: std.mem.Allocator,
    arr: std.ArrayList(u8),
    pub fn init(al: std.mem.Allocator) String {
        return .{ .al = al, .arr = std.ArrayList(u8).init(al) };
    }
    pub fn deinit(self: String) void {
        self.arr.deinit();
    }
    pub fn append(self: *String, str: []const u8) !void {
        if (str.len == 0) return;
        try self.arr.appendSlice(str);
    }
    pub fn items(self: String) []u8 {
        return self.arr.items;
    }
};
