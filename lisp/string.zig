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

    pub fn init_with_contents(allocator: std.mem.Allocator, contents: []const u8) Error!String {
        var string = init(allocator);

        try string.concat(contents);

        return string;
    }

    /// Deallocates the internal buffer
    pub fn deinit(self: *String) void {
        if (self.buffer) |buffer| self.allocator.free(buffer);
    }

    /// Returns the size of the internal buffer
    pub fn capacity(self: String) usize {
        if (self.buffer) |buffer| return buffer.len;
        return 0;
    }

    /// Allocates space for the internal buffer
    pub fn allocate(self: *String, bytes: usize) Error!void {
        if (self.buffer) |buffer| {
            if (bytes < self.size) self.size = bytes; // Clamp size to capacity
            self.buffer = self.allocator.realloc(buffer, bytes) catch {
                return Error.OutOfMemory;
            };
        } else {
            self.buffer = self.allocator.alloc(u8, bytes) catch |err| {
                return Error.OutOfMemory;
            };
        }
    }

    /// Reallocates the the internal buffer to size
    pub fn truncate(self: *String) Error!void {
        try self.allocate(self.size);
    }

    /// Appends a character onto the end of the String
    pub fn concat(self: *String, char: []const u8) Error!void {
        try self.insert(char, self.len());
    }

    /// Inserts a string literal into the String at an index
    pub fn insert(self: *String, literal: []const u8, index: usize) Error!void {
        // Make sure buffer has enough space
        if (self.buffer) |buffer| {
            if (self.size + literal.len > buffer.len) {
                try self.allocate((self.size + literal.len) * 2);
            }
        } else {
            try self.allocate((literal.len) * 2);
        }

        const buffer = self.buffer.?;

        // If the index is >= len, then simply push to the end.
        // If not, then copy contents over and insert literal.
        if (index == self.len()) {
            var i: usize = 0;
            while (i < literal.len) : (i += 1) {
                buffer[self.size + i] = literal[i];
            }
        } else {
            if (String.getIndex(buffer, index, true)) |k| {
                // Move existing contents over
                var i: usize = buffer.len - 1;
                while (i >= k) : (i -= 1) {
                    if (i + literal.len < buffer.len) {
                        buffer[i + literal.len] = buffer[i];
                    }

                    if (i == 0) break;
                }

                i = 0;
                while (i < literal.len) : (i += 1) {
                    buffer[index + i] = literal[i];
                }
            }
        }

        self.size += literal.len;
    }

    /// Removes the last character from the String
    pub fn pop(self: *String) ?[]const u8 {
        if (self.size == 0) return null;

        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (i + size >= self.size) break;
                i += size;
            }

            const ret = buffer[i..self.size];
            self.size -= (self.size - i);
            return ret;
        }

        return null;
    }

    /// Compares this String with a string literal
    pub fn cmp(self: String, literal: []const u8) bool {
        if (self.buffer) |buffer| {
            return std.mem.eql(u8, buffer[0..self.size], literal);
        }
        return false;
    }

    /// Returns the String as a string literal
    pub fn str(self: String) []const u8 {
        if (self.buffer) |buffer| return buffer[0..self.size];
        return "";
    }

    /// Returns an owned slice of this string
    pub fn toOwned(self: String) Error!?[]u8 {
        if (self.buffer != null) {
            const string = self.str();
            if (self.allocator.alloc(u8, string.len)) |newStr| {
                std.mem.copy(u8, newStr, string);
                return newStr;
            } else |_| {
                return Error.OutOfMemory;
            }
        }

        return null;
    }

    /// Returns a character at the specified index
    pub fn charAt(self: String, index: usize) ?[]const u8 {
        if (self.buffer) |buffer| {
            if (String.getIndex(buffer, index, true)) |i| {
                const size = String.getUTF8Size(buffer[i]);
                return buffer[i..(i + size)];
            }
        }
        return null;
    }

    /// Returns amount of characters in the String
    pub fn len(self: String) usize {
        if (self.buffer) |buffer| {
            var length: usize = 0;
            var i: usize = 0;

            while (i < self.size) {
                i += String.getUTF8Size(buffer[i]);
                length += 1;
            }

            return length;
        } else {
            return 0;
        }
    }

    /// Finds the first occurrence of the string literal
    pub fn find(self: String, literal: []const u8) ?usize {
        if (self.buffer) |buffer| {
            const index = std.mem.indexOf(u8, buffer[0..self.size], literal);
            if (index) |i| {
                return String.getIndex(buffer, i, false);
            }
        }

        return null;
    }

    /// Removes a character at the specified index
    pub fn remove(self: *String, index: usize) Error!void {
        try self.removeRange(index, index + 1);
    }

    /// Removes a range of character from the String
    /// Start (inclusive) - End (Exclusive)
    pub fn removeRange(self: *String, start: usize, end: usize) Error!void {
        const length = self.len();
        if (end < start or end > length) return Error.InvalidRange;

        if (self.buffer) |buffer| {
            const rStart = String.getIndex(buffer, start, true).?;
            const rEnd = String.getIndex(buffer, end, true).?;
            const difference = rEnd - rStart;

            var i: usize = rEnd;
            while (i < self.size) : (i += 1) {
                buffer[i - difference] = buffer[i];
            }

            self.size -= difference;
        }
    }

    /// Trims all whitelist characters at the start of the String.
    pub fn trimStart(self: *String, whitelist: []const u8) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) : (i += 1) {
                const size = String.getUTF8Size(buffer[i]);
                if (size > 1 or !inWhitelist(buffer[i], whitelist)) break;
            }

            if (String.getIndex(buffer, i, false)) |k| {
                self.removeRange(0, k) catch {};
            }
        }
    }

    /// Trims all whitelist characters at the end of the String.
    pub fn trimEnd(self: *String, whitelist: []const u8) void {
        self.reverse();
        self.trimStart(whitelist);
        self.reverse();
    }

    /// Trims all whitelist characters from both ends of the String
    pub fn trim(self: *String, whitelist: []const u8) void {
        self.trimStart(whitelist);
        self.trimEnd(whitelist);
    }

    /// Copies this String into a new one
    /// User is responsible for managing the new String
    pub fn clone(self: String) Error!String {
        var newString = String.init(self.allocator);
        try newString.concat(self.str());
        return newString;
    }

    /// Reverses the characters in this String
    pub fn reverse(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size > 1) std.mem.reverse(u8, buffer[i..(i + size)]);
                i += size;
            }

            std.mem.reverse(u8, buffer[0..self.size]);
        }
    }

    /// Repeats this String n times
    pub fn repeat(self: *String, n: usize) Error!void {
        try self.allocate(self.size * (n + 1));
        if (self.buffer) |buffer| {
            var i: usize = 1;
            while (i <= n) : (i += 1) {
                var j: usize = 0;
                while (j < self.size) : (j += 1) {
                    buffer[((i * self.size) + j)] = buffer[j];
                }
            }

            self.size *= (n + 1);
        }
    }

    /// Checks the String is empty
    pub inline fn isEmpty(self: String) bool {
        return self.size == 0;
    }

    /// Splits the String into a slice, based on a delimiter and an index
    pub fn split(self: *const String, delimiters: []const u8, index: usize) ?[]const u8 {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            var block: usize = 0;
            var start: usize = 0;

            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size == delimiters.len) {
                    if (std.mem.eql(u8, delimiters, buffer[i..(i + size)])) {
                        if (block == index) return buffer[start..i];
                        start = i + size;
                        block += 1;
                    }
                }

                i += size;
            }

            if (i >= self.size - 1 and block == index) {
                return buffer[start..self.size];
            }
        }

        return null;
    }

    /// Splits the String into a new string, based on delimiters and an index
    /// The user of this function is in charge of the memory of the new String.
    pub fn splitToString(self: *const String, delimiters: []const u8, index: usize) Error!?String {
        if (self.split(delimiters, index)) |block| {
            var string = String.init(self.allocator);
            try string.concat(block);
            return string;
        }

        return null;
    }

    /// Clears the contents of the String but leaves the capacity
    pub fn clear(self: *String) void {
        if (self.buffer) |buffer| {
            for (buffer) |*ch| ch.* = 0;
            self.size = 0;
        }
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toLowercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size == 1) buffer[i] = std.ascii.toLower(buffer[i]);
                i += size;
            }
        }
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toUppercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size == 1) buffer[i] = std.ascii.toUpper(buffer[i]);
                i += size;
            }
        }
    }

    /// Creates a String from a given range
    /// User is responsible for managing the new String
    pub fn substr(self: String, start: usize, end: usize) Error!String {
        var result = String.init(self.allocator);

        if (self.buffer) |buffer| {
            if (String.getIndex(buffer, start, true)) |rStart| {
                if (String.getIndex(buffer, end, true)) |rEnd| {
                    if (rEnd < rStart or rEnd > self.size)
                        return Error.InvalidRange;
                    try result.concat(buffer[rStart..rEnd]);
                }
            }
        }

        return result;
    }

    // Writer functionality for the String.
    pub usingnamespace struct {
        pub const Writer = std.io.Writer(*String, Error, appendWrite);

        pub fn writer(self: *String) Writer {
            return .{ .context = self };
        }

        fn appendWrite(self: *String, m: []const u8) !usize {
            try self.concat(m);
            return m.len;
        }
    };

    // Iterator support
    pub usingnamespace struct {
        pub const StringIterator = struct {
            string: *const String,
            index: usize,

            pub fn next(it: *StringIterator) ?[]const u8 {
                if (it.string.buffer) |buffer| {
                    if (it.index == it.string.size) return null;
                    var i = it.index;
                    it.index += String.getUTF8Size(buffer[i]);
                    return buffer[i..it.index];
                } else {
                    return null;
                }
            }
        };

        pub fn iterator(self: *const String) StringIterator {
            return StringIterator{
                .string = self,
                .index = 0,
            };
        }
    };

    /// Returns whether or not a character is whitelisted
    fn inWhitelist(char: u8, whitelist: []const u8) bool {
        var i: usize = 0;
        while (i < whitelist.len) : (i += 1) {
            if (whitelist[i] == char) return true;
        }

        return false;
    }

    /// Checks if byte is part of UTF-8 character
    inline fn isUTF8Byte(byte: u8) bool {
        return ((byte & 0x80) > 0) and (((byte << 1) & 0x80) == 0);
    }

    /// Returns the real index of a unicode string literal
    fn getIndex(unicode: []const u8, index: usize, real: bool) ?usize {
        var i: usize = 0;
        var j: usize = 0;
        while (i < unicode.len) {
            if (real) {
                if (j == index) return i;
            } else {
                if (i == index) return j;
            }
            i += String.getUTF8Size(unicode[i]);
            j += 1;
        }

        return null;
    }

    /// Returns the UTF-8 character's size
    inline fn getUTF8Size(char: u8) u3 {
        return std.unicode.utf8ByteSequenceLength(char) catch {
            return 1;
        };
    }
};
const ArenaAllocator = std.heap.ArenaAllocator;
const eql = std.mem.eql;

// const zig_string = @import("./zig-string.zig");
// const String = zig_string.String;

test "Basic Usage" {
    // Use your favorite allocator
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Create your String
    var myString = String.init(arena.allocator());
    defer myString.deinit();

    // Use functions provided
    try myString.concat("🔥 Hello!");
    _ = myString.pop();
    try myString.concat(", World 🔥");

    // Success!
    assert(myString.cmp("🔥 Hello, World 🔥"));
}

test "String Tests" {
    // Allocator for the String
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    // This is how we create the String
    var myStr = String.init(arena.allocator());
    defer myStr.deinit();

    // allocate & capacity
    try myStr.allocate(16);
    assert(myStr.capacity() == 16);
    assert(myStr.size == 0);

    // truncate
    try myStr.truncate();
    assert(myStr.capacity() == myStr.size);
    assert(myStr.capacity() == 0);

    // concat
    try myStr.concat("A");
    try myStr.concat("\u{5360}");
    try myStr.concat("💯");
    try myStr.concat("Hello🔥");

    assert(myStr.size == 17);

    // pop & length
    assert(myStr.len() == 9);
    assert(eql(u8, myStr.pop().?, "🔥"));
    assert(myStr.len() == 8);
    assert(eql(u8, myStr.pop().?, "o"));
    assert(myStr.len() == 7);

    // str & cmp
    assert(myStr.cmp("A\u{5360}💯Hell"));
    assert(myStr.cmp(myStr.str()));

    // charAt
    assert(eql(u8, myStr.charAt(2).?, "💯"));
    assert(eql(u8, myStr.charAt(1).?, "\u{5360}"));
    assert(eql(u8, myStr.charAt(0).?, "A"));

    // insert
    try myStr.insert("🔥", 1);
    assert(eql(u8, myStr.charAt(1).?, "🔥"));
    assert(myStr.cmp("A🔥\u{5360}💯Hell"));

    // find
    assert(myStr.find("🔥").? == 1);
    assert(myStr.find("💯").? == 3);
    assert(myStr.find("Hell").? == 4);

    // remove & removeRange
    try myStr.removeRange(0, 3);
    assert(myStr.cmp("💯Hell"));
    try myStr.remove(myStr.len() - 1);
    assert(myStr.cmp("💯Hel"));

    const whitelist = [_]u8{ ' ', '\t', '\n', '\r' };

    // trimStart
    try myStr.insert("      ", 0);
    myStr.trimStart(whitelist[0..]);
    assert(myStr.cmp("💯Hel"));

    // trimEnd
    _ = try myStr.concat("lo💯\n      ");
    myStr.trimEnd(whitelist[0..]);
    assert(myStr.cmp("💯Hello💯"));

    // clone
    var testStr = try myStr.clone();
    defer testStr.deinit();
    assert(testStr.cmp(myStr.str()));

    // reverse
    myStr.reverse();
    assert(myStr.cmp("💯olleH💯"));
    myStr.reverse();
    assert(myStr.cmp("💯Hello💯"));

    // repeat
    try myStr.repeat(2);
    assert(myStr.cmp("💯Hello💯💯Hello💯💯Hello💯"));

    // isEmpty
    assert(!myStr.isEmpty());

    // split
    assert(eql(u8, myStr.split("💯", 0).?, ""));
    assert(eql(u8, myStr.split("💯", 1).?, "Hello"));
    assert(eql(u8, myStr.split("💯", 2).?, ""));
    assert(eql(u8, myStr.split("💯", 3).?, "Hello"));
    assert(eql(u8, myStr.split("💯", 5).?, "Hello"));
    assert(eql(u8, myStr.split("💯", 6).?, ""));

    var splitStr = String.init(arena.allocator());
    defer splitStr.deinit();

    try splitStr.concat("variable='value'");
    assert(eql(u8, splitStr.split("=", 0).?, "variable"));
    assert(eql(u8, splitStr.split("=", 1).?, "'value'"));

    // splitToString
    var newSplit = try splitStr.splitToString("=", 0);
    assert(newSplit != null);
    defer newSplit.?.deinit();

    assert(eql(u8, newSplit.?.str(), "variable"));

    // toLowercase & toUppercase
    myStr.toUppercase();
    assert(myStr.cmp("💯HELLO💯💯HELLO💯💯HELLO💯"));
    myStr.toLowercase();
    assert(myStr.cmp("💯hello💯💯hello💯💯hello💯"));

    // substr
    var subStr = try myStr.substr(0, 7);
    defer subStr.deinit();
    assert(subStr.cmp("💯hello💯"));

    // clear
    myStr.clear();
    assert(myStr.len() == 0);
    assert(myStr.size == 0);

    // writer
    const writer = myStr.writer();
    const length = try writer.write("This is a Test!");
    assert(length == 15);

    // owned
    const mySlice = try myStr.toOwned();
    assert(eql(u8, mySlice.?, "This is a Test!"));
    arena.allocator().free(mySlice.?);

    // StringIterator
    var i: usize = 0;
    var iter = myStr.iterator();
    while (iter.next()) |ch| {
        if (i == 0) {
            assert(eql(u8, "T", ch));
        }
        i += 1;
    }

    assert(i == myStr.len());
}

test "init with contents" {
    // Allocator for the String
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    var initial_contents = "init with contents";

    // This is how we create the String with contents at the start
    var myStr = try String.init_with_contents(arena.allocator(), initial_contents);
    assert(eql(u8, myStr.str(), initial_contents));
}
test "init with empty" {
    // Allocator for the String
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    var initial_contents = "";

    // This is how we create the String with contents at the start
    var myStr = try String.init_with_contents(arena.allocator(), initial_contents);
    try myStr.concat("");
    assert(eql(u8, myStr.str(), initial_contents));
}
