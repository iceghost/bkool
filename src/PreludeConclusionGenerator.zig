const std = @import("std");
const mips = @import("./mips.zig");
const List = @import("List.zig");

pub fn generate(allocator: std.mem.Allocator, prog: *mips.Program) !void {
    var instr = try allocator.create(mips.Instr);
    instr.kind = .{ .label = "main" };
    List.insertNext(&prog.instrs.node, &instr.node);

    instr = try allocator.create(mips.Instr);
    instr.kind = .{ .jal = "exit" };
    List.insertPrev(&prog.instrs.node, &instr.node);
}

const Parser = @import("./Parser.zig");
const InstructionSelector = @import("./InstructionSelector.zig");

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
    try generate(allocator, mips_prog);

    try std.testing.expectEqualStrings(
        \\main:
        \\    li $a0, 1
        \\    jal io_writeInt
        \\    jal exit
        \\
    , try std.fmt.allocPrint(allocator, "{}", .{mips_prog}));
}
