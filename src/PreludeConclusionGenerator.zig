const std = @import("std");
const mips = @import("./mips.zig");

pub fn generate(allocator: std.mem.Allocator, prog: *mips.Program) !void {
    var instr = try allocator.create(mips.Instr);
    instr.kind = .{ .label = "main" };
    instr.next = prog.instrs;
    prog.instrs = instr;

    while (instr.next) |next| : (instr = next) {}

    instr.next = try allocator.create(mips.Instr);
    instr = instr.next.?;
    instr.kind = .{ .jal = "exit" };
    instr.next = null;
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
