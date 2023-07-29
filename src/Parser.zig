const std = @import("std");
const Lexer = @import("Lexer.zig");
const Parser = @This();
const ast = @import("ast.zig");
const List = @import("List.zig");

lexer: Lexer,
current: Lexer.Token,
next: Lexer.Token,
allocator: std.mem.Allocator,

const Error = error{
    OutOfMemory,
    UnexpectedToken,
    NonAssociative,
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
    try self.eatAndExpect(.kw_class);
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
    try self.eatAndExpect(.kw_static);
    try self.eatAndExpect(.kw_void);
    try self.eatAndExpect(.identifier);
    var name = self.current.identifier;
    try self.eatAndExpect(.left_paren);
    // TODO: parameters
    try self.eatAndExpect(.right_paren);
    try self.eatAndExpect(.left_brace);

    var method = try self.allocator.create(ast.Method);
    method.name = name;
    method.body.init();

    while (self.next != .right_brace) {
        try self.parseStmt(&method.body);
    }
    try self.eatAndExpect(.right_brace);

    return method;
}

fn parseStmt(self: *Parser, stmts: *ast.Stmt.Head) Error!void {
    var stmt: *ast.Stmt = undefined;

    switch (self.next) {
        // declarations
        .kw_int => return try self.parseVarDecl(stmts),
        else => {},
    }

    var expr = try self.parseExpr();
    switch (self.next) {
        .colon_equal => {
            self.eat();
            var rhs = try self.parseExpr();
            stmt = try self.allocator.create(ast.Stmt);
            stmt.kind = .{ .assign = .{ .lhs = expr, .rhs = rhs } };
        },
        .semicolon => switch (expr.kind) {
            .call => |*call| {
                stmt = try self.allocator.create(ast.Stmt);
                stmt.kind = .{ .call = call };
            },
            else => std.debug.panic("only call exprs can be statements", .{}),
        },
        else => return error.UnexpectedToken,
    }
    try self.eatAndExpect(.semicolon);
    List.insertPrev(&stmts.node, &stmt.node);
}

fn parseVarDecl(self: *Parser, stmts: *ast.Stmt.Head) Error!void {
    try self.eatAndExpect(.kw_int);
    while (true) {
        try self.eatAndExpect(.identifier);
        var name = self.current.identifier;
        var initializer: ?*ast.Expr = null;

        if (self.next == .equal) {
            self.eat();
            initializer = try self.parseExpr();
        }

        var stmt = try self.allocator.create(ast.Stmt);
        stmt.kind = .{ .var_decl = .{ .name = name, .initializer = initializer } };
        List.insertPrev(&stmts.node, &stmt.node);

        if (self.next == .semicolon)
            return try self.eatAndExpect(.semicolon)
        else
            try self.eatAndExpect(.comma);
    }

    try self.eatAndExpect(.semicolon);
}

fn parseExpr(self: *Parser) Error!*ast.Expr {
    return try parseExprHelp(self, 0);
}

fn parseExprHelp(self: *Parser, left_bp: u8) Error!*ast.Expr {
    var expr: *ast.Expr = undefined;

    if (PRATT.PREFIX.get(self.next)) |e| {
        expr = try e.parse_fn(self, undefined, e.right_bp);
    } else return error.UnexpectedToken;

    loop: while (true) {
        inline for (.{ PRATT.INFIX, PRATT.POSTFIX }) |table|
            if (table.get(self.next)) |e| {
                if (left_bp == e.left_bp)
                    return error.NonAssociative;
                if (left_bp > e.left_bp)
                    break :loop;

                expr = try e.parse_fn(self, expr, e.right_bp);

                continue :loop;
            };

        break;
    }

    return expr;
}

const PRATT = blk: {
    var p = Pratt{};
    p.add(&p.INFIX, .plus, parseBinary, .l);
    p.bump();
    p.add(&p.POSTFIX, .dot, parseField, .n);
    p.bump();
    p.add(&p.PREFIX, .identifier, parseVariable, .n);
    p.add(&p.PREFIX, .integer, parseInteger, .n);
    break :blk p;
};

const Pratt = struct {
    const ParseFn = *const fn (*Parser, *ast.Expr, u8) Error!*ast.Expr;
    const Map = std.EnumMap(Lexer.TokenTag, Entry);
    const Entry = struct {
        parse_fn: ParseFn,
        left_bp: u8,
        right_bp: u8,
    };

    INFIX: Map = .{},
    PREFIX: Map = .{},
    POSTFIX: Map = .{},

    bp: u8 = 1,

    pub fn add(self: *Pratt, comptime m: *Map, t: Lexer.TokenTag, comptime p_fn: ParseFn, ass: enum { l, n, r }) void {
        switch (ass) {
            .l => m.put(t, .{ .parse_fn = p_fn, .left_bp = self.bp, .right_bp = self.bp + 1 }),
            .n => m.put(t, .{ .parse_fn = p_fn, .left_bp = self.bp, .right_bp = self.bp }),
            .r => m.put(t, .{ .parse_fn = p_fn, .left_bp = self.bp + 1, .right_bp = self.bp }),
        }
    }

    pub fn bump(self: *Pratt) void {
        self.bp += 2;
    }
};

fn parseBinary(self: *Parser, left: *ast.Expr, bp: u8) Error!*ast.Expr {
    var bin_expr = try self.allocator.create(ast.Expr);
    self.eat();
    switch (self.current) {
        .plus => {
            var right = try self.parseExprHelp(bp);
            bin_expr.kind = .{ .binary = .{
                .left = left,
                .right = right,
                .op = .add,
            } };
        },
        else => unreachable,
    }
    return bin_expr;
}

fn parseField(self: *Parser, receiver: *ast.Expr, _: u8) Error!*ast.Expr {
    self.eatAndExpect(.dot) catch unreachable;
    try self.eatAndExpect(.identifier);
    var field = self.current.identifier;

    if (self.next == .left_paren)
        return try self.parseCall(receiver, field);

    std.debug.panic("no field yet", .{});
}

fn parseCall(self: *Parser, receiver: *ast.Expr, method: []const u8) Error!*ast.Expr {
    var call = try self.allocator.create(ast.Expr);
    call.kind = .{ .call = .{ .receiver = receiver, .method = method, .args = undefined } };
    call.kind.call.args.init();
    self.eatAndExpect(.left_paren) catch unreachable;
    while (self.next != .right_paren) {
        var a = try self.parseExpr();
        List.insertPrev(&call.kind.call.args.node, &a.node);
        switch (self.next) {
            .comma => self.eat(),
            .right_paren => break,
            else => return error.UnexpectedToken,
        }
    }
    try self.eatAndExpect(.right_paren);
    return call;
}

fn parseVariable(self: *Parser, _: *ast.Expr, _: u8) Error!*ast.Expr {
    self.eatAndExpect(.identifier) catch unreachable;
    var name = self.current.identifier;
    var expr = try self.allocator.create(ast.Expr);
    expr.kind = .{ .variable = name };
    return expr;
}

fn parseInteger(self: *Parser, _: *ast.Expr, _: u8) Error!*ast.Expr {
    self.eatAndExpect(.integer) catch unreachable;
    var int = self.current.integer;
    var expr = try self.allocator.create(ast.Expr);
    expr.kind = .{ .integer = int };
    return expr;
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
