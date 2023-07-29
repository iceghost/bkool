const std = @import("std");
const Self = @This();
const ast = @import("ast.zig");
const mips = @import("mips.zig");
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
        .pmove => |*args| {
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
