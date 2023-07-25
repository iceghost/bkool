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
        .pmove => |args| switch (args[0]) {
            .reg => |reg0| switch (args[1]) {
                .reg => |reg1| instr.kind = .{ .move = .{ .rd = reg0, .rs = reg1 } },
                .imm => |imm1| instr.kind = .{ .li = .{ .rd = reg0, .imm = imm1 } },
                .ref => |ref1| instr.kind = .{ .lw = .{ .rd = reg0, .src = ref1 } },
                else => unreachable,
            },
            .ref => |ref0| switch (args[1]) {
                .reg => |reg1| instr.kind = .{ .sw = .{ .rs = reg1, .dest = ref0 } },
                .imm => |imm1| {
                    var tmp = try self.allocator.create(mips.Instr);
                    tmp.kind = .{ .li = .{ .rd = mips.Reg.t0, .imm = imm1 } };
                    List.insertPrev(&instr.node, &tmp.node);
                    instr.kind = .{ .sw = .{ .rs = mips.Reg.t0, .dest = ref0 } };
                },
                .ref => |ref1| {
                    var tmp = try self.allocator.create(mips.Instr);
                    tmp.kind = .{ .lw = .{ .rd = mips.Reg.t0, .src = ref1 } };
                    List.insertPrev(&instr.node, &tmp.node);
                    instr.kind = .{ .sw = .{ .rs = mips.Reg.t0, .dest = ref0 } };
                },
                else => unreachable,
            },
            else => unreachable,
        },
        else => return,
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
