const std = @import("std");
const Self = @This();
const ast = @import("ast.zig");
const mips = @import("mips.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,

const Error = error{OutOfMemory};

pub fn select(allocator: std.mem.Allocator, program: *ast.Program) Error!*mips.Program {
    var self = Self{
        .allocator = allocator,
    };
    return try self.selectClass(program.class);
}

fn selectClass(self: *Self, class: *ast.Class) Error!*mips.Program {
    return try self.selectMethod(class.method);
}

fn selectMethod(self: *Self, method: *ast.Method) Error!*mips.Program {
    var program = try self.allocator.create(mips.Program);
    program.instrs.init();

    var it = method.body.iterator();
    while (it.next()) |s| {
        try self.selectStmt(s, &program.instrs);
    }
    return program;
}

fn selectStmt(self: *Self, stmt: *ast.Stmt, instrs: *mips.Instr.Head) Error!void {
    var instr: *mips.Instr = undefined;
    switch (stmt.kind) {
        .call => |call| {
            instr = try self.allocator.create(mips.Instr);
            var it = call.args.constIterator();
            var arg = it.next().?;
            instr.kind = .{
                .movev = .{
                    .{ .reg = mips.Reg.a0 },
                    try self.selectExpr(arg),
                },
            };
            List.insertPrev(&instrs.node, &instr.node);

            instr = try self.allocator.create(mips.Instr);
            instr.kind = .{
                .jal = .{
                    .label = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ call.receiver, call.method }),
                    .arity = 1,
                },
            };
            List.insertPrev(&instrs.node, &instr.node);
        },
        .var_decl => |var_decl| {
            if (var_decl.initializer) |initializer| {
                try self.selectAssign(.{ .vir = var_decl.name }, initializer, instrs);
            }
        },
        .assign => |assign| {
            var lhs = try self.selectExpr(assign.lhs);
            try self.selectAssign(lhs, assign.rhs, instrs);
        },
    }
}

fn selectAssign(self: *Self, lhs: mips.Arg, rhs: *const ast.Expr, instrs: *mips.Instr.Head) Error!void {
    var instr = try self.allocator.create(mips.Instr);
    instr.kind = switch (rhs.kind) {
        .binary => |binary| blk: {
            var left = try self.selectExpr(binary.left);
            var right = try self.selectExpr(binary.right);
            break :blk switch (binary.op) {
                .add => .{ .addv = .{
                    lhs,
                    left,
                    right,
                } },
            };
        },
        else => .{ .movev = .{
            lhs,
            try self.selectExpr(rhs),
        } },
    };
    List.insertPrev(&instrs.node, &instr.node);
}

fn selectExpr(_: *Self, expr: *const ast.Expr) Error!mips.Arg {
    return switch (expr.kind) {
        .integer => |i| .{ .imm = i },
        .variable => |x| .{ .vir = x },
        else => std.debug.panic("expr kind {s}", .{@tagName(expr.kind)}),
    };
}
