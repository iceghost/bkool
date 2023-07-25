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
        li: struct { rd: Reg, imm: i32 },
        move: struct { rd: Reg, rs: Reg },
        sw: struct { rs: Reg, dest: Arg.Ref },
        lw: struct { rd: Reg, src: Arg.Ref },
        jal: []const u8,

        // non-patched instructions
        pmove: [2]Arg,
    },

    node: List.Node,
    pub const Head = List.Head(Instr, "node");

    pub fn format(self: Instr, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.kind) {
            .label => |label| try writer.print("{s}:", .{label}),
            .move => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rd, args.rs }),
            .sw => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rs, args.dest }),
            .lw => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rd, args.src }),
            .li => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rd, args.imm }),
            .jal => |label| try writer.print(" " ** 4 ++ "jal {s}", .{label}),
            .pmove => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind)[1..], args[0], args[1] }),
        }
    }
};

pub const Arg = union(enum) {
    reg: Reg,
    imm: i32,
    ref: Ref,
    vir: []const u8,

    pub const Ref = struct {
        base: Reg,
        offset: i32,

        pub fn format(self: Ref, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.print("{}({})", .{ self.offset, self.base });
        }
    };

    pub fn format(self: Arg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .reg => |reg| try writer.print("{}", .{reg}),
            .imm => |imm| try writer.print("{}", .{imm}),
            .ref => |ref| try writer.print("{}", .{ref}),
            .vir => |vir| try writer.print("{s}", .{vir}),
        }
    }
};

pub const Reg = enum {
    t0,
    a0,
    fp,

    pub fn format(self: Reg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("${s}", .{@tagName(self)});
    }
};
