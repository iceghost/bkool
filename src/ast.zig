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
        noop,
    },

    node: List.Node = .{},
    pub const Head = List.Head(Stmt, "node");
};

pub const Expr = struct {
    kind: union(enum) {
        call: Call,
        integer: i32,
    },
    node: List.Node = .{},

    pub const Call = struct {
        obj: []const u8,
        method: []const u8,
        args: *Expr,
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
    }
}

fn printStmt(writer: anytype, stmt: *Stmt) !void {
    switch (stmt.kind) {
        .call => |call| {
            try writer.print(" " ** 8 ++ "{s}.{s} ", .{ call.obj, call.method });
            try printExpr(writer, call.args);
        },
        .noop => {},
    }
}

fn printExpr(writer: anytype, expr: *Expr) !void {
    switch (expr.kind) {
        .call => |call| {
            try writer.print("({s}.{s} ", .{ call.obj, call.method });
            try printExpr(writer, call.args);
        },
        .integer => |int| {
            try writer.print("{}", .{int});
        },
    }
}
