const std = @import("std");
const Lexer = @This();

start: usize = 0,
cur: usize = 0,
src: []const u8,

pub const Token = union(enum) {
    left_brace,
    right_brace,
    left_paren,
    right_paren,
    dot,
    semicolon,
    class,
    static,
    void,
    identifier: []const u8,
    integer: i32,
    eof,
};
pub const TokenTag = std.meta.Tag(Token);

pub fn next(self: *Lexer) Token {
    var cur_c: u8 = undefined;
    while (true) {
        cur_c = self.eat();
        if (std.ascii.isWhitespace(cur_c)) {
            continue;
        }
        break;
    }

    self.start = self.cur - 1;
    return switch (cur_c) {
        0 => .eof,
        '{' => .left_brace,
        '}' => .right_brace,
        '(' => .left_paren,
        ')' => .right_paren,
        '.' => .dot,
        ';' => .semicolon,
        else => |c| if (std.ascii.isDigit(c))
            self.number()
        else if (std.ascii.isAlphabetic(c) or c == '_')
            self.identifier()
        else
            std.debug.panic("not implemented yet...: '{c}' at {}", .{ c, self.cur }),
    };
}

pub fn number(self: *Lexer) Token {
    while (std.ascii.isDigit(self.eat())) {}
    self.cur -= 1;
    const int = std.fmt.parseInt(i32, self.src[self.start..self.cur], 0) catch |err| switch (err) {
        error.Overflow => std.debug.panic("integer overflow: '{s}'", .{self.src[self.start..self.cur]}),
        else => unreachable,
    };
    return .{ .integer = int };
}

pub fn identifier(self: *Lexer) Token {
    while (true) {
        var c = self.eat();
        if (std.ascii.isAlphanumeric(c) or c == '_') {
            continue;
        }
        break;
    }
    self.cur -= 1;
    var ident = self.src[self.start..self.cur];

    // TODO: replace with a hashmap or-so...
    inline for (.{ .class, .static, .void }) |kw| {
        if (std.mem.eql(u8, ident, @tagName(kw))) {
            return kw;
        }
    }

    return .{ .identifier = ident };
}

pub fn eat(self: *Lexer) u8 {
    if (self.cur == self.src.len) {
        return 0;
    }
    var c = self.src[self.cur];
    self.cur += 1;
    return c;
}

pub fn peek(self: *Lexer) u8 {
    return self.src[self.cur];
}

test "all symbols" {
    const raw: []const u8 = "{ } ( ) . ;";
    var lexer = Lexer{ .src = raw };
    const expecteds: []const TokenTag = &[_]TokenTag{
        .left_brace,
        .right_brace,
        .left_paren,
        .right_paren,
        .dot,
        .semicolon,
    };
    for (expecteds) |expected| {
        const got = lexer.next();
        try std.testing.expectEqual(expected, got);
    }
    try std.testing.expectEqual(@as(TokenTag, .eof), lexer.next());
}

test "simple program?" {
    // checking the specs...
    const raw: []const u8 =
        \\class Main {
        \\    static void main() {
        \\        io.writeInt(1);
        \\    }      
        \\}
    ;
    var lexer = Lexer{ .src = raw };
    const expecteds: []const TokenTag = &[_]TokenTag{
        .class,
        .identifier,
        .left_brace,
        .static,
        .void,
        .identifier,
        .left_paren,
        .right_paren,
        .left_brace,
        .identifier,
        .dot,
        .identifier,
        .left_paren,
        .integer,
        .right_paren,
        .semicolon,
        .right_brace,
        .right_brace,
    };
    for (expecteds) |expected| {
        const got = lexer.next();
        try std.testing.expectEqual(expected, got);
    }
    try std.testing.expectEqual(@as(TokenTag, .eof), lexer.next());
}
