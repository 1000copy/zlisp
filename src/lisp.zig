const expect = @import("std").testing.expect;
const std = @import("std");
const ArrayList = std.ArrayList;
const eql = std.mem.eql;
const Allocator = std.mem.Allocator;
// const print = std.debug.print;
pub fn print(comptime fmt: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(fmt, args) catch {
        unreachable;
    };
}
const LispError = error{ fnnotdef, symbolnotdef };
pub const String = struct {
    buffer: ArrayList(u8),
    pub fn toNumber(self: *String) !f64 {
        return try std.fmt.parseFloat(f64, self.buffer.items);
    }
    pub fn init(allocator: Allocator) String {
        return .{ .buffer = ArrayList(u8).init(allocator) };
    }
    pub fn deinit(self: String) void {
        self.buffer.deinit();
    }
    pub fn append(self: *String, str: []const u8) void {
        self.buffer.appendSlice(str) catch unreachable;
    }
    pub fn eql(self: String, str: []const u8) bool {
        return std.mem.eql(u8, self.buffer.items, str);
    }
    pub fn print(self: String) void {
        std.debug.print("{s}", .{self.buffer.items});
    }
    pub fn items(self: String) []u8 {
        return self.buffer.items;
    }
    pub fn len(self: String) usize {
        return self.buffer.items.len;
    }
};
pub const Env = struct {
    data: std.StringHashMap(Sexpr),
    pub fn init(allocator: Allocator) Env {
        var e = Env{
            .data = std.StringHashMap(Sexpr).init(allocator),
        };
        return e;
    }
    pub fn put(self: *Env, key: String, exp: Sexpr) !void {
        try self.data.put(key.items(), exp);
    }
    pub fn get(self: Env, key: String) ?Sexpr {
        return self.data.get(key.items());
    }
};
pub const CAtom = union(enum) {
    symbol: String,
    number: f64,
    pub fn p(self: CAtom) void {
        if (self == .symbol) {
            self.symbol.print();
        } else {
            print("{d}", .{self.number});
        }
    }
    pub fn init_number(r: f64) CAtom {
        var a = CAtom{
            .number = r,
        };
        return a;
    }
    pub fn init(allocator: Allocator, s: []const u8) CAtom {
        var t = String.init(allocator);
        // defer t.deinit();
        t.append(s);
        var a: CAtom = undefined;
        if (t.toNumber()) |b| {
            a = CAtom{ .number = b };
        } else |_| {
            a = CAtom{
                .symbol = String.init(allocator),
            };
            a.symbol = t;
        }
        return a;
    }
    pub fn deinit(self: CAtom) void {
        if (self == .symbol) {
            self.symbol.deinit();
        }
    }
};
const ListType = enum { list, tuple };
pub const Sexpr = union(enum) {
    atom: CAtom,
    list: CList,
    pub fn init_number(number: f64) Sexpr {
        const a = CAtom.init_number(number);
        const s = Sexpr{
            .atom = a,
        };
        return s;
    }
    // tbd
    pub fn print(self: Sexpr) void {
        switch (self) {
            .atom => {
                self.atom.p();
            },
            .list => {
                self.list.print();
            },
        }
    }
    pub fn eval(self: Sexpr, env: *Env) LispError!Sexpr {
        if (self == .atom) {
            if (self.atom == .number)
                return self;
            const s = env.get(self.atom.symbol);
            if (s) |s1| {
                return s1;
            } else {
                return LispError.symbolnotdef;
            }
        } else {
            return self.list.eval(env);
        }
    }
    pub fn deinit(self: Sexpr) void {
        if (self == .atom) {
            self.atom.deinit();
        } else {
            self.list.deinit();
        }
    }
};
pub const CList = struct {
    ltype: ListType,
    len: usize,
    content: ArrayList(Sexpr),
    allocator: Allocator,
    pub fn sexprs(self: CList, index: usize) Sexpr {
        return self.content.items[index];
    }
    pub fn def(self: CList, env: *Env) LispError!Sexpr {
        var i: usize = 0;
        var symbol: String = undefined;
        var value: Sexpr = undefined;
        var count: usize = 0;
        for (self.content.items) |expr| {
            if (i == 1) {
                symbol = expr.atom.symbol;
                count += 1;
            }
            if (i == 2) {
                value = try expr.eval(env);
                count += 1;
            }
            i += 1;
        }
        if (count == 2) {
            env.put(symbol, value) catch unreachable;
        }
        return value;
    }
    pub fn plus(self: CList, env: *Env) LispError!Sexpr {
        var r: f64 = 0;
        var i: usize = 0;
        for (self.content.items) |expr| {
            if (i != 0) {
                const s = try expr.eval(env);
                if (s == .atom and s.atom == .number) {
                    r += s.atom.number;
                } else {
                    // 此处需要做异常处理
                    unreachable;
                }
            }
            i += 1;
        }
        const atom = CAtom.init_number(r);
        var sexpr = Sexpr{
            .atom = atom,
        };
        return sexpr;
    }
    pub fn eval(self: CList, env: *Env) LispError!Sexpr {
        var expr = self.content.items[0];
        if (expr == .atom and expr.atom == .symbol and expr.atom.symbol.eql("+")) {
            return self.plus(env);
        }
        if (expr == .atom and expr.atom == .symbol and expr.atom.symbol.eql("def")) {
            return self.def(env);
        }
        return LispError.fnnotdef;
    }
    pub fn init(allocator: Allocator) CList {
        return CList{
            .ltype = ListType.list,
            .len = 0,
            .allocator = allocator,
            .content = ArrayList(Sexpr).init(allocator),
        };
    }
    pub fn deinit(self: CList) void {
        for (self.content.items) |item| {
            item.deinit();
        }
        self.content.deinit();
    }
    pub fn append(self: *CList, atom: Sexpr) !void {
        self.len += 1;
        try self.content.append(atom);
    }
    pub fn appendAtom(self: *CList, atom: CAtom) !void {
        self.len += 1;
        var sexpr = Sexpr{
            .atom = atom,
        };
        try self.content.append(sexpr);
    }
    pub fn appendList(self: *CList, list: CList) !void {
        self.len += 1;
        var sexpr = Sexpr{
            .list = list,
        };
        try self.content.append(sexpr);
    }
    pub fn print(self: CList) void {
        if (self.ltype == ListType.list) {
            std.debug.print("{s}", .{"("});
        }
        for (self.content.items) |item| {
            std.debug.print("{s}", .{" "});
            item.print();
            std.debug.print("{s}", .{" "});
        }
        if (self.ltype == ListType.list) {
            std.debug.print("{s}", .{")"});
        }
    }
};
pub const Parser = struct {
    code: String,
    index: usize,
    allocator: Allocator,
    pub fn init(allocator: Allocator) Parser {
        return Parser{
            .code = String.init(allocator),
            .index = 0,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: Parser) void {
        self.code.deinit();
    }
    pub fn curr(self: *Parser) u8 {
        return self.*.code.items()[self.*.index];
    }
    pub fn is_inrange(self: *Parser) bool {
        return self.*.index < self.*.code.len();
    }
    pub fn is_parentheses(self: *Parser) bool {
        return self.curr() == '(' or self.curr() == ')';
    }
    pub fn is_delimiter(self: *Parser) bool {
        return self.curr() == ' ' or self.is_parentheses();
    }
    pub fn is_list_delimiter(self: *Parser) bool {
        return self.curr() == ')';
    }
    pub fn parseAtom(self: *Parser) CAtom {
        const begin = self.*.index;
        while (self.is_inrange() and !self.is_delimiter()) : (self.*.index += 1) {}
        const s = self.*.code.items()[begin..self.*.index];
        if (self.is_inrange() and self.is_parentheses())
            self.pre();
        return CAtom.init(self.allocator, s);
    }
    pub fn parse(self: *Parser) CList {
        var list = CList.init(self.allocator);
        list.ltype = ListType.tuple;
        self.parseSexprs(&list);
        // list.print();
        return list;
    }
    pub fn eval(self: Parser, list: CList, env: *Env) LispError!Sexpr {
        _ = self;
        var a: Sexpr = undefined;
        for (list.content.items) |item| {
            a = try item.eval(env);
        }
        return a;
    }
    pub fn parseList(self: *Parser) CList {
        var list = CList.init(self.allocator);
        self.*.index += 1;
        self.parseSexprs(&list);
        return list;
    }
    fn next(self: *Parser) void {
        self.*.index += 1;
    }
    fn pre(self: *Parser) void {
        self.*.index -= 1;
    }
    pub fn parseSexprs(self: *Parser, list: *CList) void {
        while (self.*.index < self.*.code.len()) : (self.next()) {
            switch (self.curr()) {
                ' ', '\t' => {},
                '(' => {
                    list.appendList(self.parseList()) catch unreachable;
                },
                ')' => {
                    return;
                },
                else => {
                    list.appendAtom(self.parseAtom()) catch unreachable;
                },
            }
        }
    }
};

test "testtemplate" {
    try expect(1 == 1);
}
test "atom" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var list = CList.init(allocator);
    list.ltype = .tuple;
    defer list.deinit();
    try list.appendAtom(CAtom.init(allocator, "1"));
    try expect(list.sexprs(0).atom.number == 1);
}
test "cons" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var list = CList.init(allocator);
    defer list.deinit();
    try list.appendAtom(CAtom.init(allocator, "+"));
    try list.appendAtom(CAtom.init(allocator, "1"));
    try list.appendAtom(CAtom.init(allocator, "2"));
    try expect(list.sexprs(0).atom.symbol.eql("+"));
    try expect(list.sexprs(1).atom.number == 1);
    try expect(list.sexprs(2).atom.number == 2);
}
test "eval" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var e = Env.init(allocator);
    var src = Parser.init(allocator);
    src.code.append("(+ 1 2)");
    const s = try src.eval(src.parse(), &e);
    try expect(s.atom.number == 3);
}
test "eval_tuple" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var e = Env.init(allocator);
    var src = Parser.init(allocator);
    src.code.append("1");
    const s = try src.eval(src.parse(), &e);
    try expect(s.atom.number == 1);
}
test "eval_tuple_3" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var e = Env.init(allocator);
    var src = Parser.init(allocator);
    src.code.append("1 2 3");
    const s = try src.eval(src.parse(), &e);
    try expect(s.atom.number == 3);
}
test "eval_emebed" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var e = Env.init(allocator);
    var src = Parser.init(allocator);
    src.code.append("(+ 1 (+ 1 (+ 1 2)))");
    const s = try src.eval(src.parse(), &e);
    try expect(s.atom.number == 5);
}
test "cons_complex_list" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var list = CList.init(allocator);
    defer list.deinit();
    try list.appendAtom(CAtom.init(allocator, "+"));
    try list.appendAtom(CAtom.init(allocator, "1"));
    try list.appendAtom(CAtom.init(allocator, "2"));
    var list1 = CList.init(allocator);
    //defer list1.deinit();
    try list1.appendAtom(CAtom.init(allocator, "+"));
    try list1.appendAtom(CAtom.init(allocator, "3"));
    try list1.appendAtom(CAtom.init(allocator, "4"));
    try list.appendList(list1);
    try expect(list.len == 4);
    try expect(list.sexprs(3).list.len == 3);
}
test "parse_atom" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var src = Parser.init(allocator);
    src.code.append("1");

    const list = src.parse();
    try expect(list.len == 1);
    var e = Env.init(allocator);
    const s = try src.eval(list, &e);
    try expect(s == .atom);
    try expect(s.atom.number == 1);
}

test "parse_tuple_2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var src = Parser.init(allocator);
    src.code.append(" ab  cd ");
    const list = src.parse();
    defer list.deinit();
    try expect(list.ltype == .tuple);
    try expect(list.len == 2);
}
test "parse_list1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var src = Parser.init(allocator);
    src.code.append("(a b (c d))");
    const list = src.parse();
    defer list.deinit();
    try expect(list.ltype == .tuple);
    try expect(list.sexprs(0).list.len == 3);
}
test "parse_list2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var src = Parser.init(allocator);
    src.code.append("((a b) (c d))");
    const list = src.parse();
    try expect(list.ltype == .tuple);
    try expect(list.sexprs(0).list.len == 2);
    try expect(list.sexprs(0).list.sexprs(0).list.len == 2);
    try expect(list.sexprs(0).list.sexprs(1).list.len == 2);
}
test "hashmap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var my_hash_map = std.StringHashMap(Sexpr).init(allocator);
    const s = Sexpr.init_number(1);
    try my_hash_map.put("a", s);
    var value = my_hash_map.get("a");
    if (value) |v| {
        try expect(v.atom.number == 1);
    } else {
        // doesn't exist
        try expect(1 == 0);
    }
    s.deinit();
}
test "eval_with_def_symbol" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var e = Env.init(allocator);
    var src = Parser.init(allocator);
    defer src.deinit();
    src.code.append("(def a 2) (+ 1 a)");
    const list = src.parse();
    defer list.deinit();
    const s = try src.eval(list, &e);
    try expect(s.atom.number == 3);
}
test "eval with symbol" {
    // 设置Env
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var e = Env.init(allocator);
    var s1 = Sexpr.init_number(1);
    var str = String.init(allocator);
    str.append("a");
    try e.put(str, s1);
    //
    var src = Parser.init(allocator);
    src.code.append("(+ 1 a)");
    const list = src.parse();
    const s = try src.eval(list, &e);
    // print("{d}", .{s.atom.number});
    try expect(s.atom.number == 2);
    list.deinit();
    src.deinit();
    str.deinit();
}
test "parse with def symbol2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var src = Parser.init(allocator);
    src.code.append("(1)2");
    const list = src.parse();
    try expect(list.len == 2);
    list.deinit();
    src.deinit();
}
test "string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var src = String.init(allocator);
    src.append("1");
    src.append("2");
    src.append("3");
    try expect(src.eql("123"));
    try expect(try src.toNumber() == 123);
    src.deinit();
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    try stdout.print(">", .{});
    const user_input = stdin.readUntilDelimiter(buf[0..], '\n');
    if (user_input) |input| {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        var e = Env.init(allocator);
        var src = Parser.init(allocator);
        defer src.deinit();
        src.code.append(input);
        const list = src.parse();
        defer list.deinit();
        const s = src.eval(list, &e);
        if (s) |s1| {
            print("{d}", .{s1.atom.number});
        } else |err| {
            print("{}", .{err});
        }
    } else |err| {
        try stdout.print("{any}\n", .{err});
    }
}
