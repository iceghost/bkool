const std = @import("std");
const List = @import("List.zig");

pub const Program = struct {
    class: *Class,
};

pub const Class = struct {
    name: []const u8,
    method: *Method,
};

pub const Method = struct {
    name: []const u8,
    body: Stmt.Head,
};

pub const Stmt = struct {
    kind: union(enum) {
        call: *Expr.Call,
        var_decl: VarDecl,
        assign: Assign,
    },

    node: List.Node = .{},
    pub const Head = List.Head(Stmt, "node");

    pub const VarDecl = struct {
        name: []const u8,
        initializer: ?*Expr,
    };

    pub const Assign = struct {
        lhs: *Expr,
        rhs: *Expr,
    };
};

pub const Expr = struct {
    kind: union(enum) {
        call: Call,
        integer: i32,
        variable: []const u8,
    },
    node: List.Node = .{},
    const Head = List.Head(Expr, "node");

    pub const Call = struct {
        receiver: *Expr,
        method: []const u8,
        args: Expr.Head,
    };

    pub const Field = struct {
        receiver: *Expr,
        field: []const u8,
    };
};

pub fn print(writer: anytype, program: *Program) !void {
    try printClass(writer, program.class);
}

fn printClass(writer: anytype, class: *Class) !void {
    try writer.print("class {s}\n", .{class.name});
    try printMethod(writer, class.method);
}

fn printMethod(writer: anytype, method: *Method) !void {
    try writer.print(" " ** 4 ++ "method {s}\n", .{method.name});
    var it = method.body.iterator();
    while (it.next()) |s| {
        try printStmt(writer, s);
        try writer.print("\n", .{});
    }
}

fn printStmt(writer: anytype, stmt: *Stmt) !void {
    switch (stmt.kind) {
        .call => |call| {
            try writer.print(" " ** 8, .{});
            try printExpr(writer, call.receiver);
            try writer.print(".{s}", .{call.method});
            var it = call.args.iterator();
            while (it.next()) |a| {
                try writer.print(" ", .{});
                try printExpr(writer, a);
            }
        },
        .var_decl => |var_decl| {
            try writer.print(" " ** 8 ++ "{s}: int", .{var_decl.name});
            if (var_decl.initializer) |init| {
                try writer.print(" = ", .{});
                try printExpr(writer, init);
            }
        },
        .assign => |assign| {
            try writer.print(" " ** 8, .{});
            try printExpr(writer, assign.lhs);
            try writer.print(" := ", .{});
            try printExpr(writer, assign.rhs);
        },
    }
}

fn printExpr(writer: anytype, expr: *Expr) !void {
    switch (expr.kind) {
        .call => |*call| {
            try writer.print("(", .{});
            try printExpr(writer, call.receiver);
            try writer.print(".{s}", .{call.method});
            var it = call.args.iterator();
            while (it.next()) |a| {
                try writer.print(" ", .{});
                try printExpr(writer, a);
            }
            try writer.print(")", .{});
        },
        .integer => |int| {
            try writer.print("{}", .{int});
        },
        .variable => |v| {
            try writer.print("{s}", .{v});
        },
    }
}
