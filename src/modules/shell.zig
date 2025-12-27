const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }
    const shell_path = std.process.getEnvVarOwned(ctx.allocator, "SHELL") catch null;
    defer if (shell_path) |sp| ctx.allocator.free(sp);

    const shell_value = blk: {
        if (shell_path) |sp| {
            const base = std.fs.path.basename(sp);
            break :blk try std.fmt.allocPrint(ctx.allocator, "{s} ({s})", .{ base, sp });
        }
        const comm = readComm(ctx.allocator) catch null;
        if (comm) |c| {
            break :blk c;
        }
        break :blk try ctx.allocator.dupe(u8, "Unknown");
    };

    try list.append(ctx.allocator, .{
        .key = "Shell",
        .value = shell_value,
    });
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var shell_name: []const u8 = "Unknown";

    // 1. naive check: if PSModulePath exists, likely PowerShell or started from it
    const ps_module = std.process.getEnvVarOwned(ctx.allocator, "PSModulePath") catch null;
    if (ps_module) |p| {
        ctx.allocator.free(p);
        // But we might be in cmd inside PS.
        // Let's check PROMPT. PowerShell prompt usually starts with "PS "
        const prompt = std.process.getEnvVarOwned(ctx.allocator, "PROMPT") catch null;
        if (prompt) |pr| {
            if (std.mem.startsWith(u8, pr, "PS ")) {
                shell_name = "PowerShell";
            }
            ctx.allocator.free(pr);
        }
    }

    if (std.mem.eql(u8, shell_name, "Unknown")) {
        // Fallback to COMSPEC
        const comspec = std.process.getEnvVarOwned(ctx.allocator, "COMSPEC") catch null;
        if (comspec) |cs| {
            defer ctx.allocator.free(cs);
            const base = std.fs.path.basename(cs);
            const val = try std.fmt.allocPrint(ctx.allocator, "{s}", .{base});
            try list.append(ctx.allocator, .{ .key = "Shell", .value = val });
            return;
        }
        // default if comspec missing
        try list.append(ctx.allocator, .{ .key = "Shell", .value = try ctx.allocator.dupe(u8, "cmd.exe") });
        return;
    }

    const val = try std.fmt.allocPrint(ctx.allocator, "{s}", .{shell_name});
    try list.append(ctx.allocator, .{ .key = "Shell", .value = val });
}

fn readComm(allocator: std.mem.Allocator) ![]const u8 {
    var file = std.fs.openFileAbsolute("/proc/self/comm", .{}) catch return error.Missing;
    defer file.close();
    const max_size: usize = 256;
    const data = try file.readToEndAlloc(allocator, max_size);
    const trimmed = std.mem.trim(u8, data, " \t\r\n");
    if (trimmed.len == 0) {
        allocator.free(data);
        return error.Missing;
    }
    return trimmed;
}
