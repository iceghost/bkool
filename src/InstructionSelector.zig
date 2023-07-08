const std = @import("std");
const Self = @This();
const ast = @import("./ast.zig");
const mips = @import("./mips.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,

const Error = error{OutOfMemory};

pub fn select(allocator: std.mem.Allocator, program: *ast.Program) Error!*mips.Program {
    var self = Self{
        .allocator = allocator,
    };
    return try self.selectClass(program.class);
}

fn selectClass(self: Self, class: *ast.Class) Error!*mips.Program {
    return try self.selectMethod(class.method);
}

fn selectMethod(self: Self, method: *ast.Method) Error!*mips.Program {
    var program = try self.allocator.create(mips.Program);
    program.instrs.init();

    var it = method.body.iterator();
    while (it.next()) |s| {
        try self.selectStmt(s, &program.instrs);
    }
    return program;
}

fn selectStmt(self: Self, stmt: *ast.Stmt, instrs: *mips.Instr.Head) Error!void {
    var instr: *mips.Instr = undefined;
    switch (stmt.kind) {
        .call => |call| {
            instr = try self.allocator.create(mips.Instr);
            instr.kind = .{
                .li = .{
                    .{ .reg = mips.Reg.A0 },
                    .{ .imm = call.args.kind.integer },
                },
            };
            List.insertPrev(&instrs.node, &instr.node);

            instr = try self.allocator.create(mips.Instr);
            instr.kind = .{
                .jal = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ call.obj, call.method }),
            };
            List.insertPrev(&instrs.node, &instr.node);
        },
        .noop => {},
    }
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
        \\    li $a0, 1
        \\    jal io_writeInt
        \\
    , stream.getWritten());
}
