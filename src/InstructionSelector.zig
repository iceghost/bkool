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
                .pmove = .{
                    .{ .reg = mips.Reg.a0 },
                    try self.selectExpr(arg),
                },
            };
            List.insertPrev(&instrs.node, &instr.node);

            instr = try self.allocator.create(mips.Instr);
            instr.kind = .{
                .jal = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ call.receiver, call.method }),
            };
            List.insertPrev(&instrs.node, &instr.node);
        },
        .var_decl => |var_decl| {
            if (var_decl.initializer) |initializer| {
                instr = try self.allocator.create(mips.Instr);
                instr.kind = .{ .pmove = .{
                    .{ .vir = var_decl.name },
                    try self.selectExpr(initializer),
                } };
                List.insertPrev(&instrs.node, &instr.node);
            }
        },
        .assign => |assign| {
            instr = try self.allocator.create(mips.Instr);
            instr.kind = .{ .pmove = .{
                try self.selectExpr(assign.lhs),
                try self.selectExpr(assign.rhs),
            } };
            List.insertPrev(&instrs.node, &instr.node);
        },
    }
}

fn selectExpr(_: *Self, expr: *const ast.Expr) Error!mips.Arg {
    return switch (expr.kind) {
        .integer => |i| .{ .imm = i },
        .variable => |x| .{ .vir = x },
        else => @panic("unimplemented"),
    };
}

const Parser = @import("Parser.zig");

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
    var program = try Parser.parse(raw, allocator);
    var mips_prog = try select(allocator, program);

    try std.testing.expectEqualStrings(
        \\    move $a0, 1
        \\    jal io_writeInt
        \\
    , try std.fmt.allocPrint(allocator, "{}", .{mips_prog}));
}

test "simple variables" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const raw: []const u8 =
        \\class Main {
        \\    static void main() {
        \\        int a = 8, b;
        \\        b := 2;
        \\        io.writeInt(a);
        \\    }
        \\}
    ;
    var program = try Parser.parse(raw, allocator);
    var mips_prog = try select(allocator, program);

    try std.testing.expectEqualStrings(
        \\    move a, 8
        \\    move b, 2
        \\    move $a0, a
        \\    jal io_writeInt
        \\
    , try std.fmt.allocPrint(allocator, "{}", .{mips_prog}));
}
