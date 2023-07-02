const std = @import("std");
const Lexer = @import("./Lexer.zig");
const Parser = @This();
const ast = @import("./ast.zig");

lexer: Lexer,
current: Lexer.Token,
next: Lexer.Token,
allocator: std.mem.Allocator,

const Error = error{
    OutOfMemory,
    UnexpectedToken,
};

pub fn parse(src: []const u8, allocator: std.mem.Allocator) Error!*ast.Program {
    var parser = Parser{
        .lexer = Lexer{ .src = src },
        .current = undefined,
        .next = undefined,
        .allocator = allocator,
    };
    parser.next = parser.lexer.next();
    return try parser.parseProgram();
}

fn parseProgram(self: *Parser) Error!*ast.Program {
    var class = try self.parseClass();
    var program = try self.allocator.create(ast.Program);
    program.class = class;
    return program;
}

fn parseClass(self: *Parser) Error!*ast.Class {
    try self.eatAndExpect(.class);
    try self.eatAndExpect(.identifier);
    var name = self.current.identifier;
    try self.eatAndExpect(.left_brace);
    var method = try self.parseMethod();
    try self.eatAndExpect(.right_brace);

    var class = try self.allocator.create(ast.Class);
    class.name = name;
    class.method = method;
    return class;
}

fn parseMethod(self: *Parser) Error!*ast.Method {
    try self.eatAndExpect(.static);
    try self.eatAndExpect(.void);
    try self.eatAndExpect(.identifier);
    var name = self.current.identifier;
    try self.eatAndExpect(.left_paren);
    // TODO: parameters
    try self.eatAndExpect(.right_paren);
    try self.eatAndExpect(.left_brace);

    // fake head
    var head = ast.Stmt{ .kind = undefined, .next = null };
    var ptr: *ast.Stmt = &head;
    while (self.next != .right_brace) {
        ptr.next = try self.parseStmt();
        ptr = ptr.next.?;
    }
    try self.eatAndExpect(.right_brace);

    var method = try self.allocator.create(ast.Method);
    method.name = name;
    // remove fake head
    method.body = head.next;
    return method;
}

fn parseStmt(self: *Parser) Error!*ast.Stmt {
    try self.eatAndExpect(.identifier);
    const obj = self.current.identifier;
    try self.eatAndExpect(.dot);
    try self.eatAndExpect(.identifier);
    const method = self.current.identifier;
    try self.eatAndExpect(.left_paren);
    try self.eatAndExpect(.integer);
    var int = self.current.integer;
    var arg = try self.allocator.create(ast.Expr);
    arg.kind = .{ .integer = int };
    arg.next = null;
    try self.eatAndExpect(.right_paren);
    try self.eatAndExpect(.semicolon);

    var call = try self.allocator.create(ast.Expr);
    call.kind = .{ .call = .{
        .obj = obj,
        .method = method,
        .args = arg,
    } };
    call.next = null;

    var stmt = try self.allocator.create(ast.Stmt);
    stmt.kind = .{ .call = &call.kind.call };
    stmt.next = null;

    return stmt;
}

fn eat(self: *Parser) void {
    self.current = self.next;
    self.next = self.lexer.next();
}

fn eatAndExpect(self: *Parser, expected: Lexer.TokenTag) Error!void {
    self.eat();
    if (self.current != expected)
        return error.UnexpectedToken;
}

test "simple program" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const raw: []const u8 =
        \\class Main {
        \\    static void main() {
        \\        io.writeInt(1);
        \\    }
        \\}
    ;
    var program = try parse(raw, allocator);

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try ast.print(stream.writer(), program);

    try std.testing.expectEqualStrings(
        \\class Main
        \\    method main
        \\        io.writeInt 1
    , stream.getWritten());
}
