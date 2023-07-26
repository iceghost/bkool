const std = @import("std");
const Parser = @import("Parser.zig");
const InstructionSelector = @import("InstructionSelector.zig");
const PreludeConclusionGenerator = @import("PreludeConclusionGenerator.zig");
const mips = @import("mips.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = arena.allocator();

    var src = try std.io.getStdIn().readToEndAlloc(allocator, std.math.maxInt(usize));
    var ast_prog = try Parser.parse(src, allocator);
    var mips_prog = try InstructionSelector.select(allocator, ast_prog);
    try PreludeConclusionGenerator.generate(allocator, mips_prog);
    try mips.print(std.io.getStdOut().writer(), mips_prog);
}
