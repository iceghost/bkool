const std = @import("std");
const List = @import("List.zig");

pub const Program = struct {
    instrs: Instr.Head,
    var_homes: std.StringHashMapUnmanaged(usize) = .{},

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
        sw: struct { rs: Reg, dst: Arg.Ref },
        lw: struct { rd: Reg, src: Arg.Ref },
        add: struct { rd: Reg, rs: Reg, rt: Reg },
        addi: struct { rd: Reg, rs: Reg, imm: i32 },
        jal: []const u8,

        // non-patched instructions
        movev: [2]Arg,
        addv: [3]Arg,
    },

    node: List.Node,
    pub const Head = List.Head(Instr, "node");

    pub fn format(self: Instr, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.kind) {
            .label => |label| try writer.print("{s}:", .{label}),
            .move => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rd, args.rs }),
            .sw => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rs, args.dst }),
            .lw => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rd, args.src }),
            .li => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args.rd, args.imm }),
            .add => |args| try writer.print(" " ** 4 ++ "{s} {}, {}, {}", .{ @tagName(self.kind), args.rd, args.rs, args.rt }),
            .addi => |args| try writer.print(" " ** 4 ++ "{s} {}, {}, {}", .{ @tagName(self.kind), args.rd, args.rs, args.imm }),
            .jal => |label| try writer.print(" " ** 4 ++ "jal {s}", .{label}),
            .movev => |args| try writer.print(" " ** 4 ++ "{s} {}, {}", .{ @tagName(self.kind), args[0], args[1] }),
            .addv => |args| try writer.print(" " ** 4 ++ "{s} {}, {}, {}", .{ @tagName(self.kind), args[0], args[1], args[2] }),
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
    // scratch register
    t8,
    t9,
    // arguments
    a0,
    // special
    fp,
    sp,

    pub fn format(self: Reg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("${s}", .{@tagName(self)});
    }
};
