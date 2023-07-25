const std = @import("std");
const List = @import("List.zig");

pub const Program = struct {
    instrs: Instr.Head,

    pub fn format(self: *const Program, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var iter = self.instrs.constIterator();
        while (iter.next()) |instr| {
            try writer.print("{}\n", .{instr});
        }
    }
};

pub const Instr = struct {
    kind: union(enum) {
        label: []const u8,
        li: [2]Arg,
        mv: [2]Arg,
        jal: []const u8,
    },

    node: List.Node,
    pub const Head = List.Head(Instr, "node");

    pub fn format(self: Instr, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.kind) {
            .label => |label| try writer.print("{s}:", .{label}),
            .li => |args| try writer.print(" " ** 4 ++ "li {}, {}", .{ args[0], args[1] }),
            .mv => |args| try writer.print(" " ** 4 ++ "move {}, {}", .{ args[0], args[1] }),
            .jal => |label| try writer.print(" " ** 4 ++ "jal {s}", .{label}),
        }
    }
};

pub const Arg = union(enum) {
    reg: Reg,
    imm: i32,
    ref: struct {
        base: Reg,
        offset: i32,
    },
    vir: []const u8,

    pub fn format(self: Arg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .reg => |reg| try writer.print("{}", .{reg}),
            .imm => |imm| try writer.print("{}", .{imm}),
            .ref => |ref| try writer.print("{}({})", .{ ref.offset, ref.base }),
            .vir => |vir| try writer.print("{s}", .{vir}),
        }
    }
};

pub const Reg = enum {
    a0,
    fp,

    pub fn format(self: Reg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("${s}", .{@tagName(self)});
    }
};
