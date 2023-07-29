const Parser = @import("Parser.zig");
const Snap = @import("snaptest/snaptest.zig").Snap;
const snap = Snap.snap;
const std = @import("std");
const InstructionSelector = @import("InstructionSelector.zig");
const HomeAssigner = @import("HomeAssigner.zig");
const InstructionPatcher = @import("InstructionPatcher.zig");
const PreludeConclusionGenerator = @import("PreludeConclusionGenerator.zig");
const ComplexOperandRemover = @import("ComplexOperandRemover.zig");

comptime {
    _ = @import("ast.zig");
    _ = @import("Lexer.zig");
    _ = @import("List.zig");
    _ = @import("main.zig");
    _ = @import("mips.zig");
}

fn skipRemaining() !void {
    return error.SkipZigTest;
}

test "simple program" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
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
    try snap(@src(),
        \\class Main
        \\    method main
        \\        io.writeInt 1
        \\
    ).diffFmt("{}", .{program});

    try ComplexOperandRemover.remove(allocator, program);
    try snap(@src(),
        \\class Main
        \\    method main
        \\        io.writeInt 1
        \\
    ).diffFmt("{}", .{program});

    var mips_prog = try InstructionSelector.select(allocator, program);
    try snap(@src(),
        \\    move $a0, 1
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try HomeAssigner.assign(allocator, mips_prog);
    try snap(@src(),
        \\    move $a0, 1
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try InstructionPatcher.patch(allocator, mips_prog);
    try snap(@src(),
        \\    li $a0, 1
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try PreludeConclusionGenerator.generate(allocator, mips_prog);
    try snap(@src(),
        \\main:
        \\    li $a0, 1
        \\    jal io_writeInt
        \\    jal exit
        \\
    ).diffFmt("{}", .{mips_prog});
}

test "simple variables" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
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
    try snap(@src(),
        \\class Main
        \\    method main
        \\        a: int = 8
        \\        b: int
        \\        b := 2
        \\        io.writeInt a
        \\
    ).diffFmt("{}", .{program});

    try ComplexOperandRemover.remove(allocator, program);
    try snap(@src(),
        \\class Main
        \\    method main
        \\        a: int = 8
        \\        b: int
        \\        b := 2
        \\        io.writeInt a
        \\
    ).diffFmt("{}", .{program});

    var mips_prog = try InstructionSelector.select(allocator, program);
    try snap(@src(),
        \\    move a, 8
        \\    move b, 2
        \\    move $a0, a
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try HomeAssigner.assign(allocator, mips_prog);
    try snap(@src(),
        \\    move 0($fp), 8
        \\    move 4($fp), 2
        \\    move $a0, 0($fp)
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try InstructionPatcher.patch(allocator, mips_prog);
    try snap(@src(),
        \\    li $t0, 8
        \\    sw $t0, 0($fp)
        \\    li $t0, 2
        \\    sw $t0, 4($fp)
        \\    lw $a0, 0($fp)
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try PreludeConclusionGenerator.generate(allocator, mips_prog);
    try snap(@src(),
        \\main:
        \\    li $t0, 8
        \\    sw $t0, 0($fp)
        \\    li $t0, 2
        \\    sw $t0, 4($fp)
        \\    lw $a0, 0($fp)
        \\    jal io_writeInt
        \\    jal exit
        \\
    ).diffFmt("{}", .{mips_prog});
}

test "variables with addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const raw: []const u8 =
        \\class Main {
        \\    static void main() {
        \\        int a = 8, b;
        \\        b := 2;
        \\        io.writeInt(a + 1);
        \\        io.writeInt(b + a);
        \\    }
        \\}
    ;

    var program = try Parser.parse(raw, allocator);
    try snap(@src(),
        \\class Main
        \\    method main
        \\        a: int = 8
        \\        b: int
        \\        b := 2
        \\        io.writeInt (+ a 1)
        \\        io.writeInt (+ b a)
        \\
    ).diffFmt("{}", .{program});

    try ComplexOperandRemover.remove(allocator, program);
    try snap(@src(),
        \\class Main
        \\    method main
        \\        a: int = 8
        \\        b: int
        \\        b := 2
        \\        tmp$0: int = (+ a 1)
        \\        io.writeInt tmp$0
        \\        tmp$1: int = (+ b a)
        \\        io.writeInt tmp$1
        \\
    ).diffFmt("{}", .{program});

    var mips_prog = try InstructionSelector.select(allocator, program);
    try snap(@src(),
        \\    move a, 8
        \\    move b, 2
        \\    addv tmp$0, a, 1
        \\    move $a0, tmp$0
        \\    jal io_writeInt
        \\    addv tmp$1, b, a
        \\    move $a0, tmp$1
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try skipRemaining();

    try HomeAssigner.assign(allocator, mips_prog);
    try snap(@src(),
        \\
    ).diffFmt("{}", .{mips_prog});

    try InstructionPatcher.patch(allocator, mips_prog);
    try snap(@src(),
        \\
    ).diffFmt("{}", .{mips_prog});

    try PreludeConclusionGenerator.generate(allocator, mips_prog);
    try snap(@src(),
        \\
    ).diffFmt("{}", .{mips_prog});
}

test "associative addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const raw: []const u8 =
        \\class Main {
        \\    static void main() {
        \\        io.writeInt(1 + 2 + 3);
        \\    }
        \\}
    ;

    var program = try Parser.parse(raw, allocator);
    try snap(@src(),
        \\class Main
        \\    method main
        \\        io.writeInt (+ (+ 1 2) 3)
        \\
    ).diffFmt("{}", .{program});

    try ComplexOperandRemover.remove(allocator, program);
    try snap(@src(),
        \\class Main
        \\    method main
        \\        tmp$0: int = (+ 1 2)
        \\        tmp$1: int = (+ tmp$0 3)
        \\        io.writeInt tmp$1
        \\
    ).diffFmt("{}", .{program});

    var mips_prog = try InstructionSelector.select(allocator, program);
    try snap(@src(),
        \\    addv tmp$0, 1, 2
        \\    addv tmp$1, tmp$0, 3
        \\    move $a0, tmp$1
        \\    jal io_writeInt
        \\
    ).diffFmt("{}", .{mips_prog});

    try skipRemaining();

    try HomeAssigner.assign(allocator, mips_prog);
    try snap(@src(),
        \\
    ).diffFmt("{}", .{mips_prog});

    try InstructionPatcher.patch(allocator, mips_prog);
    try snap(@src(),
        \\
    ).diffFmt("{}", .{mips_prog});

    try PreludeConclusionGenerator.generate(allocator, mips_prog);
    try snap(@src(),
        \\
    ).diffFmt("{}", .{mips_prog});
}
