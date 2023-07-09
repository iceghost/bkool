const std = @import("std");
const List = @import("List.zig");

pub const Program = struct {
    class: *Class,

    pub fn format(self: *const Program, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.class});
    }
};

pub const Class = struct {
    name: []const u8,
    method: *Method,

    pub fn format(self: *const Class, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("class {s}\n", .{self.name});
        try writer.print("{}", .{self.method});
    }
};

pub const Method = struct {
    name: []const u8,
    body: Stmt.Head,

    pub fn format(self: *const Method, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(" " ** 4 ++ "method {s}\n", .{self.name});
        var it = self.body.constIterator();
        while (it.next()) |s| {
            try writer.print("{}\n", .{s});
        }
    }
};

pub const Stmt = struct {
    kind: union(enum) {
        call: *Expr.Call,
        var_decl: VarDecl,
        assign: Assign,
    },

    node: List.Node = .{},
    pub const Head = List.Head(Stmt, "node");

    pub const VarDecl = struct {
        name: []const u8,
        initializer: ?*Expr,
    };

    pub const Assign = struct {
        lhs: *Expr,
        rhs: *Expr,
    };

    pub fn format(self: *const Stmt, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.kind) {
            .call => |call| {
                try writer.print(" " ** 8 ++ "{}.{s}", .{ call.receiver, call.method });
                var it = call.args.iterator();
                while (it.next()) |a| {
                    try writer.print(" {}", .{a});
                }
            },
            .var_decl => |var_decl| {
                try writer.print(" " ** 8 ++ "{s}: int", .{var_decl.name});
                if (var_decl.initializer) |init| {
                    try writer.print(" = {}", .{init});
                }
            },
            .assign => |assign| {
                try writer.print(" " ** 8 ++ "{} := {}", .{ assign.lhs, assign.rhs });
            },
        }
    }
};

pub const Expr = struct {
    kind: union(enum) {
        call: Call,
        integer: i32,
        variable: []const u8,
    },
    node: List.Node = .{},
    const Head = List.Head(Expr, "node");

    pub const Call = struct {
        receiver: *Expr,
        method: []const u8,
        args: Expr.Head,
    };

    pub const Field = struct {
        receiver: *Expr,
        field: []const u8,
    };

    pub fn format(self: *const Expr, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.kind) {
            .call => |call| {
                try writer.print("({}.{s}", .{ call.receiver, call.method });
                var it = call.args.constIterator();
                while (it.next()) |a| {
                    try writer.print(" {}", .{a});
                }
                try writer.print(")", .{});
            },
            .integer => |int| {
                try writer.print("{}", .{int});
            },
            .variable => |v| {
                try writer.print("{s}", .{v});
            },
        }
    }
};
