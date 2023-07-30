const std = @import("std");
const Self = @This();
const ast = @import("ast.zig");
const mips = @import("mips.zig");
const List = @import("List.zig");

allocator: std.mem.Allocator,
use_t8: bool = false,

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
    if (try self.devirtualize(instr)) return;

    // load all sources
    switch (instr.kind) {
        .addv => |*args| {
            try self.loadIfRef(&args[1], instr);
            try self.loadIfRef(&args[2], instr);
        },
        .movev => |*args| {
            try self.loadIfRef(&args[1], instr);
        },
        else => unreachable,
    }

    if (try self.devirtualize(instr)) return;

    // store all dest
    switch (instr.kind) {
        .addv => |*args| try self.storeIfRef(&args[0], instr),
        .movev => |*args| try self.storeIfRef(&args[0], instr),
        else => unreachable,
    }

    if (try self.devirtualize(instr)) return;

    // load add immediate
    switch (instr.kind) {
        .addv => |*args| {
            try self.loadIfImm(&args[1], instr);
            try self.loadIfImm(&args[2], instr);
        },
        else => unreachable,
    }

    if (try self.devirtualize(instr)) return;

    std.debug.panic("instr not devirtualized: {}", .{instr});
}

fn loadIfRef(self: *Self, arg: *mips.Arg, instr: *mips.Instr) Error!void {
    if (arg.* != .ref) return;
    const scratch_reg = self.scratch();
    var load_instr = try self.allocator.create(mips.Instr);
    load_instr.kind = .{ .lw = .{ .rd = scratch_reg, .src = arg.ref } };
    List.insertPrev(&instr.node, &load_instr.node);
    arg.* = .{ .reg = scratch_reg };
}

fn loadIfImm(self: *Self, arg: *mips.Arg, instr: *mips.Instr) Error!void {
    if (arg.* != .imm) return;
    const scratch_reg = self.scratch();
    var load_instr = try self.allocator.create(mips.Instr);
    load_instr.kind = .{ .li = .{ .rd = scratch_reg, .imm = arg.imm } };
    List.insertPrev(&instr.node, &load_instr.node);
    arg.* = .{ .reg = scratch_reg };
}

fn storeIfRef(self: *Self, arg: *mips.Arg, instr: *mips.Instr) Error!void {
    if (arg.* != .ref) return;
    var store_instr = try self.allocator.create(mips.Instr);
    // the tmp register only lives shortly, so hardcore em
    store_instr.kind = .{ .sw = .{ .rs = .t8, .dst = arg.ref } };
    List.insertNext(&instr.node, &store_instr.node);
    arg.* = .{ .reg = .t8 };
}

fn devirtualize(_: *Self, instr: *mips.Instr) Error!bool {
    var new_instr: mips.Instr = undefined;
    new_instr.kind = switch (instr.kind) {
        .addv => |addv| if (addv[0] == .reg and addv[1] == .reg) switch (addv[2]) {
            .reg => .{ .add = .{ .rd = addv[0].reg, .rs = addv[1].reg, .rt = addv[2].reg } },
            .imm => .{ .addi = .{ .rd = addv[0].reg, .rs = addv[1].reg, .imm = addv[2].imm } },
            else => return false,
        } else return false,
        .movev => |args| switch (args[0]) {
            .reg => |rd| switch (args[1]) {
                .reg => |rs| .{ .move = .{ .rd = rd, .rs = rs } },
                .ref => |src| .{ .lw = .{ .rd = rd, .src = src } },
                .imm => |imm| .{ .li = .{ .rd = rd, .imm = imm } },
                else => unreachable,
            },
            .ref => |dst| switch (args[1]) {
                .reg => |rs| .{ .sw = .{ .rs = rs, .dst = dst } },
                else => return false,
            },
            else => return false,
        },
        else => return true,
    };
    instr.kind = new_instr.kind;
    return true;
}

fn scratch(self: *Self) mips.Reg {
    self.use_t8 = !self.use_t8;
    return if (self.use_t8)
        .t8
    else
        .t9;
}
