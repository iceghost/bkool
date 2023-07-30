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
        .movev => |*args| {
            try self.put(&args[0]);
            try self.get(&args[1]);
        },
        .addv => |*args| {
            try self.put(&args[0]);
            try self.get(&args[1]);
            try self.get(&args[2]);
        },
        else => {},
    }
}

fn put(self: *Self, arg: *mips.Arg) Error!void {
    if (arg.* == .vir) {
        const res = try self.var_homes.getOrPut(arg.vir);

        if (!res.found_existing)
            res.value_ptr.* = self.var_homes.count() - 1;

        arg.* = .{ .ref = .{
            .base = mips.Reg.fp,
            .offset = 4 * @as(i32, @intCast(res.value_ptr.*)),
        } };
    }
}

fn get(self: *Self, arg: *mips.Arg) Error!void {
    if (arg.* == .vir) {
        const res = try self.var_homes.getOrPut(arg.vir);

        // earlier passes should have caught this
        if (!res.found_existing) unreachable;

        arg.* = .{ .ref = .{
            .base = mips.Reg.fp,
            .offset = 4 * @as(i32, @intCast(res.value_ptr.*)),
        } };
    }
}
