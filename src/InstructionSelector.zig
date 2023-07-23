const std = @import("std");
const Self = @This();
const ast = @import("./ast.zig");
const mips = @import("./mips.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,
var_homes: std.StringArrayHashMap(usize),

const Error = error{OutOfMemory};

pub fn select(allocator: std.mem.Allocator, program: *ast.Program) Error!*mips.Program {
    var self = Self{
        .allocator = allocator,
        .var_homes = std.StringArrayHashMap(usize).init(allocator),
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
                .mv = .{
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
            var res = try self.var_homes.getOrPut(var_decl.name);
            if (res.found_existing)
                @panic("(TODO) variable existed");
            res.value_ptr.* = self.var_homes.count() - 1;

            if (var_decl.initializer) |initializer| {
                instr = try self.allocator.create(mips.Instr);
                instr.kind = .{ .mv = .{
                    .{ .ref = .{ .base = mips.Reg.fp, .offset = -4 * @as(i32, @intCast(res.value_ptr.*)) } },
                    try self.selectExpr(initializer),
                } };
                List.insertPrev(&instrs.node, &instr.node);
            }
        },
        .assign => |assign| {
            instr = try self.allocator.create(mips.Instr);
            instr.kind = .{ .mv = .{
                try self.selectExpr(assign.lhs),
                try self.selectExpr(assign.rhs),
            } };
            List.insertPrev(&instrs.node, &instr.node);
        },
    }
}

fn selectExpr(self: *Self, expr: *const ast.Expr) Error!mips.Arg {
    return switch (expr.kind) {
        .integer => |i| .{ .imm = i },
        .variable => |x| blk: {
            const home = self.var_homes.get(x) orelse @panic("variable not found");
            break :blk .{ .ref = .{
                .base = mips.Reg.fp,
                .offset = -4 * @as(i32, @intCast(home)),
            } };
        },
        else => @panic("unimplemented"),
    };
}

const Parser = @import("./Parser.zig");

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

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try mips.print(stream.writer(), mips_prog);

    try std.testing.expectEqualStrings(
        \\    mv $a0, 1
        \\    jal io_writeInt
        \\
    , stream.getWritten());
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

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try mips.print(stream.writer(), mips_prog);

    try std.testing.expectEqualStrings(
        \\    mv 0($fp), 8
        \\    mv -4($fp), 2
        \\    mv $a0, 0($fp)
        \\    jal io_writeInt
        \\
    , stream.getWritten());
}
