const std = @import("std");
const Self = @This();
const ast = @import("ast.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,
tmp_count: usize,

const Error = error{OutOfMemory};

pub fn remove(allocator: std.mem.Allocator, program: *ast.Program) Error!void {
    var self = Self{
        .allocator = allocator,
        .tmp_count = 0,
    };
    return try self.removeClass(program.class);
}

fn removeClass(self: *Self, class: *ast.Class) Error!void {
    return try self.removeMethod(class.method);
}

fn removeMethod(self: *Self, method: *ast.Method) Error!void {
    var it = method.body.iterator();
    while (it.next()) |s| {
        try self.removeStmt(s);
    }
}

fn removeStmt(self: *Self, stmt: *ast.Stmt) Error!void {
    switch (stmt.kind) {
        .call => |call| {
            var args = call.args.iterator();
            while (args.next()) |arg| {
                try self.removeExpr(arg, stmt, true);
            }
        },
        .var_decl => |var_decl| {
            if (var_decl.initializer) |initializer| {
                try self.removeExpr(initializer, stmt, false);
            }
        },
        .assign => |assign| {
            try self.removeExpr(assign.rhs, stmt, false);
        },
    }
}

fn removeExpr(self: *Self, expr: *ast.Expr, stmt: *ast.Stmt, should_extract: bool) Error!void {
    switch (expr.kind) {
        .integer => return,
        .variable => return,
        .binary => |binary| {
            try self.removeExpr(binary.left, stmt, true);
            try self.removeExpr(binary.right, stmt, true);
        },
        .call => |*call| {
            var args = call.args.iterator();
            while (args.next()) |arg| {
                try self.removeExpr(arg, stmt, true);
            }
        },
    }
    if (should_extract) {
        var new_expr = try self.allocator.create(ast.Expr);
        new_expr.* = expr.*;

        var tmp_name = try self.makeTmp();
        var tmp_stmt = try self.allocator.create(ast.Stmt);
        tmp_stmt.kind = .{ .var_decl = .{ .name = tmp_name, .initializer = new_expr } };
        expr.kind = .{ .variable = tmp_name };

        List.insertPrev(&stmt.node, &tmp_stmt.node);
    }
}

fn makeTmp(self: *Self) Error![]const u8 {
    const i = self.tmp_count;
    self.tmp_count += 1;
    return std.fmt.allocPrint(self.allocator, "tmp${}", .{i});
}
