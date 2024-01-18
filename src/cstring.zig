const std = @import("std");
const assert = std.debug.assert;

/// A variable length collection of characters
pub const String = struct {
    /// The internal character buffer
    buffer: ?[]u8,
    /// The allocator used for managing the buffer
    allocator: std.mem.Allocator,
    /// The total size of the String
    size: usize,

    /// Errors that may occur when using String
    pub const Error = error{
        OutOfMemory,
        InvalidRange,
    };

    /// Creates a String with an Allocator
    /// User is responsible for managing the new String
    pub fn init(allocator: std.mem.Allocator) String {
        return .{
            .buffer = null,
            .allocator = allocator,
            .size = 0,
        };
    }

    /// Deallocates the internal buffer
    pub fn deinit(self: *String) void {
        if (self.buffer) |buffer| self.allocator.free(buffer);
    }
    pub fn len(self: String) usize {
        return self.size;
    }
    pub fn capacity(self: String) usize {
        if (self.buffer) |buffer| return buffer.len;
        return 0;
    }
    pub fn resize(self: *String, bytes: usize) Error!void {
        if (self.buffer) |buffer| {
            if (bytes < self.size) self.size = bytes; // Clamp size to capacity
            self.buffer = self.allocator.realloc(buffer, bytes) catch {
                return Error.OutOfMemory;
            };
        } else {
            self.buffer = try self.allocator.alloc(u8, bytes);
        }
    }
    pub fn truncate(self: *String) Error!void {
        try self.resize(self.size);
    }
    pub fn append(self: *String, literal: []const u8) Error!void {
        if (self.buffer) |buffer| {
            if (self.size + literal.len > buffer.len) {
                try self.resize((self.size + literal.len) * 2);
            }
        } else {
            try self.resize((literal.len) * 2);
        }
        const buffer = self.buffer.?;
        var i: usize = 0;
        while (i < literal.len) : (i += 1) {
            buffer[self.size + i] = literal[i];
        }
        self.size += literal.len;
    }
    pub fn cmp(self: String, literal: []const u8) bool {
        if (self.buffer) |buffer| {
            return std.mem.eql(u8, buffer[0..self.size], literal);
        }
        return false;
    }
    pub fn str(self: String) []const u8 {
        if (self.buffer) |buffer| return buffer[0..self.size];
        return "";
    }
};
const ArenaAllocator = std.heap.ArenaAllocator;
const eql = std.mem.eql;

test "Basic Usage" {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var myString = String.init(arena.allocator());
    defer myString.deinit();
    try myString.append("abc");
    assert(myString.cmp("abc"));
    try myString.append("def");
    assert(myString.cmp("abcdef"));
}
test "init with empty" {
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();
    var myStr = String.init(arena.allocator());
    try myStr.append("");
    try myStr.append("");
    assert(eql(u8, myStr.str(), ""));
}
