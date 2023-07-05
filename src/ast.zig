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
    body: *Stmt,
};

pub const Stmt = struct {
    kind: union(enum) {
        call: *Expr.Call,
        noop,
    },
    node: List.Node = .{},
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

pub fn print(writer: anytype, program: *const Program) !void {
    try printClass(writer, program.class);
}

fn printClass(writer: anytype, class: *const Class) !void {
    try writer.print("class {s}\n", .{class.name});
    try printMethod(writer, class.method);
}

fn printMethod(writer: anytype, method: *const Method) !void {
    try writer.print(" " ** 4 ++ "method {s}\n", .{method.name});
    var it = List.iterator(&method.body.node);
    while (it.next()) |n| {
        try printStmt(writer, @fieldParentPtr(Stmt, "node", n));
    }
}

fn printStmt(writer: anytype, stmt: *const Stmt) !void {
    switch (stmt.kind) {
        .call => |call| {
            try writer.print(" " ** 8 ++ "{s}.{s} ", .{ call.obj, call.method });
            try printExpr(writer, call.args);
        },
        .noop => {},
    }
}

fn printExpr(writer: anytype, expr: *const Expr) !void {
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
