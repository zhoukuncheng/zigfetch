const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }
    const term = std.process.getEnvVarOwned(ctx.allocator, "TERM") catch null;
    const color_term = std.process.getEnvVarOwned(ctx.allocator, "COLORTERM") catch null;

    defer if (term) |t| ctx.allocator.free(t);
    defer if (color_term) |c| ctx.allocator.free(c);

    if (term == null and color_term == null) return;

    const value = blk: {
        if (term != null and color_term != null) {
            break :blk try std.fmt.allocPrint(ctx.allocator, "{s} ({s})", .{ term.?, color_term.? });
        } else if (term != null) {
            break :blk try ctx.allocator.dupe(u8, term.?);
        } else {
            break :blk try ctx.allocator.dupe(u8, color_term.?);
        }
    };

    try list.append(ctx.allocator, .{
        .key = "Terminal",
        .value = value,
    });
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const term_program = std.process.getEnvVarOwned(ctx.allocator, "TERM_PROGRAM") catch null;
    defer if (term_program) |t| ctx.allocator.free(t);

    const wt_session = std.process.getEnvVarOwned(ctx.allocator, "WT_SESSION") catch null;
    defer if (wt_session) |s| ctx.allocator.free(s);

    var detected: ?[]const u8 = null;

    if (wt_session != null) {
        detected = "Windows Terminal";
    } else if (term_program) |tp| {
        detected = tp;
    } else {
        // Fallback checks
        const vscode = std.process.getEnvVarOwned(ctx.allocator, "VSCODE_IPC_HOOK_CLI") catch null;
        if (vscode != null) {
            detected = "VS Code Terminal";
            ctx.allocator.free(vscode.?);
        }
    }

    if (detected) |d| {
        try list.append(ctx.allocator, .{
            .key = "Terminal",
            .value = try ctx.allocator.dupe(u8, d),
        });
    } else {
        // Check standard TERM env var as last resort even on Windows (e.g. Git Bash)
        const term = std.process.getEnvVarOwned(ctx.allocator, "TERM") catch null;
        if (term) |t| {
            defer ctx.allocator.free(t);
            try list.append(ctx.allocator, .{
                .key = "Terminal",
                .value = try ctx.allocator.dupe(u8, t),
            });
        }
    }
}
