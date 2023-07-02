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
};
pub const TokenTag = std.meta.Tag(Token);

pub fn next(self: *Lexer) Token {
    self.start = self.cur;
    while (std.ascii.isWhitespace(self.eat())) {}
    self.cur -= 1; // backtrack one step

    return switch (self.eat()) {
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
            std.debug.panic("not implemented yet...: '{c}'", .{c}),
    };
}

pub fn number(self: *Lexer) Token {
    _ = self;
    unreachable;
}

pub fn identifier(self: *Lexer) Token {
    _ = self;
    unreachable;
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
    const expected = .{
        .class,
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
    _ = expected;
    _ = raw;
}
