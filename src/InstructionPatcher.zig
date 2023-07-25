const std = @import("std");
const Self = @This();
const ast = @import("./ast.zig");
const mips = @import("./mips.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,

const Error = error{OutOfMemory};

pub fn patch(allocator: std.mem.Allocator, program: *mips.Program) Error!void {
    var self = Self{
        .allocator = allocator,
    };
    var it = program.instrs.iterator();
    while (it.next()) |instr| {
        try self.patchInstr(instr);
    }
}

fn patchInstr(self: *Self, instr: *mips.Instr) Error!void {
    switch (instr.kind) {
        .move => |*args| {
            var arg0 = args[0];
            var arg1 = args[1];

            switch (arg0) {
                .reg => switch (arg1) {
                    .reg => return,
                    .imm => instr.kind = .{ .li = args.* },
                    .ref => instr.kind = .{ .lw = .{ arg0, arg1 } },
                    else => unreachable,
                },
                .ref => switch (arg1) {
                    .reg => instr.kind = .{ .sw = .{ arg1, arg0 } },
                    .imm => {
                        var tmp = try self.allocator.create(mips.Instr);
                        tmp.kind = .{ .li = .{ .{ .reg = mips.Reg.t0 }, arg1 } };
                        List.insertPrev(&instr.node, &tmp.node);
                        instr.kind = .{ .sw = .{ .{ .reg = mips.Reg.t0 }, arg0 } };
                    },
                    .ref => {
                        var tmp = try self.allocator.create(mips.Instr);
                        tmp.kind = .{ .lw = .{ .{ .reg = mips.Reg.t0 }, arg1 } };
                        List.insertPrev(&instr.node, &tmp.node);
                        instr.kind = .{ .sw = .{ .{ .reg = mips.Reg.t0 }, arg0 } };
                    },
                    else => unreachable,
                },
                else => unreachable,
            }
        },
        else => {},
    }
}

const Parser = @import("./Parser.zig");
const InstructionSelector = @import("InstructionSelector.zig");
const HomeAssigner = @import("HomeAssigner.zig");

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
    var mips_prog = try InstructionSelector.select(allocator, program);
    try HomeAssigner.assign(allocator, mips_prog);
    try patch(allocator, mips_prog);

    try std.testing.expectEqualStrings(
        \\    li $a0, 1
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
    var mips_prog = try InstructionSelector.select(allocator, program);
    try HomeAssigner.assign(allocator, mips_prog);
    try patch(allocator, mips_prog);

    try std.testing.expectEqualStrings(
        \\    li $t0, 8
        \\    sw $t0, 0($fp)
        \\    li $t0, 2
        \\    sw $t0, 4($fp)
        \\    lw $a0, 0($fp)
        \\    jal io_writeInt
        \\
    , try std.fmt.allocPrint(allocator, "{}", .{mips_prog}));
}
