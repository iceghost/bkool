const std = @import("std");
const List = @import("List.zig");

pub const Program = struct {
    instrs: Instr.Head,
};

pub const Instr = struct {
    kind: union(enum) {
        label: []const u8,
        li: [2]Arg,
        jal: []const u8,
        noop,
    },

    node: List.Node,
    pub const Head = List.Head(Instr, "node");
};

pub const Arg = union(enum) {
    reg: Reg,
    imm: i32,
};

pub const Reg = enum {
    A0,
};

pub fn print(writer: anytype, prog: *Program) !void {
    var iter = prog.instrs.iterator();
    while (iter.next()) |instr| {
        try printInstr(writer, instr);
    }
}

fn printInstr(writer: anytype, instr: *Instr) !void {
    switch (instr.kind) {
        .label => |label| try writer.print("{s}:\n", .{label}),
        .li => |*args| {
            try writer.print(" " ** 4 ++ "li ", .{});
            try printArg(writer, &args[0]);
            try writer.print(", ", .{});
            try printArg(writer, &args[1]);
            try writer.print("\n", .{});
        },
        .jal => |label| try writer.print(" " ** 4 ++ "jal {s}\n", .{label}),
        .noop => {},
    }
}

fn printArg(writer: anytype, arg: *Arg) !void {
    switch (arg.*) {
        .reg => |reg| switch (reg) {
            .A0 => try writer.print("{s}", .{"$a0"}),
        },
        .imm => |imm| try writer.print("{}", .{imm}),
    }
}
