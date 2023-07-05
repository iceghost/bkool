const std = @import("std");
const Self = @This();
const ast = @import("./ast.zig");
const mips = @import("./mips.zig");
const List = @import("List.zig");

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
    var instrs = try self.selectStmt(method.body);
    var program = try self.allocator.create(mips.Program);
    program.instrs = instrs;
    return program;
}

fn selectStmt(self: Self, stmt: *const ast.Stmt) Error!*mips.Instr {
    var instrs: [2]*mips.Instr = undefined;
    switch (stmt.kind) {
        .call => |call| {
            instrs[0] = try self.allocator.create(mips.Instr);
            instrs[0].kind = .{
                .li = .{
                    .{ .reg = mips.Reg.A0 },
                    .{ .imm = call.args.kind.integer },
                },
            };
            instrs[0].node = .{};

            instrs[1] = try self.allocator.create(mips.Instr);
            instrs[1].kind = .{
                .jal = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ call.obj, call.method }),
            };
            List.insertNext(&instrs[0].node, &instrs[1].node);
        },
        .noop => {},
    }
    return instrs[0];
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
