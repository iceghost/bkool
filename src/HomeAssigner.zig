const std = @import("std");
const Self = @This();
const ast = @import("./ast.zig");
const mips = @import("./mips.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,
var_homes: std.StringHashMap(usize),

const Error = error{OutOfMemory};

pub fn assign(allocator: std.mem.Allocator, program: *mips.Program) Error!void {
    var self = Self{
        .allocator = allocator,
        .var_homes = std.StringHashMap(usize).init(allocator),
    };
    var it = program.instrs.iterator();
    while (it.next()) |instr| {
        try self.assignInstr(instr);
    }
}

fn assignInstr(self: *Self, instr: *mips.Instr) Error!void {
    switch (instr.kind) {
        .move => |*args| {
            if (args[0] == .vir) {
                const res = try self.var_homes.getOrPut(args[0].vir);

                if (!res.found_existing)
                    res.value_ptr.* = self.var_homes.count() - 1;

                args[0] = .{ .ref = .{
                    .base = mips.Reg.fp,
                    .offset = 4 * @as(i32, @intCast(res.value_ptr.*)),
                } };
            }
            if (args[1] == .vir) {
                const res = try self.var_homes.getOrPut(args[1].vir);

                // earlier passes should have caught this
                if (!res.found_existing) unreachable;

                args[1] = .{ .ref = .{
                    .base = mips.Reg.fp,
                    .offset = 4 * @as(i32, @intCast(res.value_ptr.*)),
                } };
            }
        },
        else => {},
    }
}

const Parser = @import("./Parser.zig");
const InstructionSelector = @import("InstructionSelector.zig");

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
    try assign(allocator, mips_prog);

    try std.testing.expectEqualStrings(
        \\    move 0($fp), 8
        \\    move 4($fp), 2
        \\    move $a0, 0($fp)
        \\    jal io_writeInt
        \\
    , try std.fmt.allocPrint(allocator, "{}", .{mips_prog}));
}
