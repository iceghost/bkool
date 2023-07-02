const std = @import("std");
const Self = @This();
const ast = @import("./ast.zig");
const mips = @import("./mips.zig");

allocator: std.mem.Allocator,

const Error = error{OutOfMemory};

pub fn select(allocator: std.mem.Allocator, program: *const ast.Program) Error!*mips.Program {
    var self = Self{
        .allocator = allocator,
    };
    return try self.selectClass(program.class);
}

fn selectClass(self: Self, class: *const ast.Class) Error!*mips.Program {
    return try self.selectMethod(class.method);
}

fn selectMethod(self: Self, method: *const ast.Method) Error!*mips.Program {
    var instrs = try self.selectStmt(method.body.?);
    var program = try self.allocator.create(mips.Program);
    program.instrs = instrs;
    return program;
}

fn selectStmt(self: Self, stmt: *const ast.Stmt) Error!*mips.Instr {
    var ret: *mips.Instr = undefined;
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
            instr.next = try self.allocator.create(mips.Instr);
            ret = instr;

            instr = instr.next.?;
            instr.kind = .{
                .jal = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ call.obj, call.method }),
            };
            instr.next = null;
        },
    }
    return ret;
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
