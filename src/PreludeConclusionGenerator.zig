const std = @import("std");
const mips = @import("./mips.zig");
const List = @import("List.zig");

pub fn generate(allocator: std.mem.Allocator, prog: *mips.Program) !void {
    var instr = try allocator.create(mips.Instr);
    instr.kind = .{ .label = "main" };
    List.insertPrev(&prog.instrs.node, &instr.node);
    prog.instrs = instr;

    // get last instruction
    var last_instr = blk: {
        var node: *List.Node = undefined;
        var it = List.iterator(&prog.instrs.node);
        while (it.next()) |n| {
            node = n;
        }
        break :blk @fieldParentPtr(mips.Instr, "node", node);
    };

    instr = try allocator.create(mips.Instr);
    instr.kind = .{ .jal = "exit" };
    List.insertNext(&last_instr.node, &instr.node);
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

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try mips.print(stream.writer(), mips_prog);

    try std.testing.expectEqualStrings(
        \\main:
        \\    li $a0, 1
        \\    jal io_writeInt
        \\    jal exit
        \\
    , stream.getWritten());
}
