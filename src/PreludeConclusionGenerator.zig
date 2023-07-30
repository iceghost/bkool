const std = @import("std");
const mips = @import("mips.zig");
const List = @import("List.zig");

pub fn generate(allocator: std.mem.Allocator, prog: *mips.Program) !void {
    var main_label = try allocator.create(mips.Instr);
    main_label.kind = .{ .label = "main" };
    List.insertNext(&prog.instrs.node, &main_label.node);

    var store_frame = try allocator.create(mips.Instr);
    store_frame.kind = .{ .sw = .{ .rs = .fp, .dst = .{ .base = .sp, .offset = -4 } } };
    List.insertNext(&main_label.node, &store_frame.node);

    var frame_init = try allocator.create(mips.Instr);
    frame_init.kind = .{ .addi = .{ .rd = .fp, .rs = .sp, .imm = -4 } };
    List.insertNext(&store_frame.node, &frame_init.node);

    var stack_init = try allocator.create(mips.Instr);
    // plus 1 for space of previous frame pointer
    stack_init.kind = .{ .addi = .{ .rd = .sp, .rs = .sp, .imm = -4 * @as(i32, @intCast(prog.var_homes.count() + 1)) } };
    List.insertNext(&frame_init.node, &stack_init.node);

    var stack_deinit = try allocator.create(mips.Instr);
    stack_deinit.kind = .{ .addi = .{ .rd = .sp, .rs = .fp, .imm = 4 } };
    List.insertPrev(&prog.instrs.node, &stack_deinit.node);

    var frame_deinit = try allocator.create(mips.Instr);
    frame_deinit.kind = .{ .lw = .{ .rd = .fp, .src = .{ .base = .sp, .offset = -4 } } };
    List.insertPrev(&prog.instrs.node, &frame_deinit.node);

    var exit_call = try allocator.create(mips.Instr);
    exit_call.kind = .{ .jal = .{ .label = "exit" } };
    List.insertPrev(&prog.instrs.node, &exit_call.node);
}
