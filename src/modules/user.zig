const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }

    const user = getUser(ctx.allocator) catch return;
    defer ctx.allocator.free(user);

    const host = readHostname(ctx.allocator) catch null;
    defer if (host) |h| ctx.allocator.free(h);

    const value = if (host) |h|
        try std.fmt.allocPrint(ctx.allocator, "{s}@{s}", .{ user, h })
    else
        try ctx.allocator.dupe(u8, user);

    try list.append(ctx.allocator, .{
        .key = "User",
        .value = value,
    });
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const user = std.process.getEnvVarOwned(ctx.allocator, "USERNAME") catch try ctx.allocator.dupe(u8, "Unknown");
    defer ctx.allocator.free(user);

    const host = std.process.getEnvVarOwned(ctx.allocator, "COMPUTERNAME") catch try ctx.allocator.dupe(u8, "Unknown");
    defer ctx.allocator.free(host);

    const value = try std.fmt.allocPrint(ctx.allocator, "{s}@{s}", .{ user, host });

    try list.append(ctx.allocator, .{
        .key = "User",
        .value = value,
    });
}

fn getUser(allocator: std.mem.Allocator) ![]const u8 {
    if (builtin.os.tag != .windows) {
        const env_keys = [_][]const u8{ "USER", "LOGNAME", "USERNAME" };
        for (env_keys) |k| {
            const val = std.process.getEnvVarOwned(allocator, k) catch continue;
            if (val.len > 0) return val;
            allocator.free(val);
        }
        const uid = std.posix.getuid();
        return try std.fmt.allocPrint(allocator, "{d}", .{uid});
    }
    return error.Unsupported;
}

fn readHostname(allocator: std.mem.Allocator) ![]const u8 {
    if (builtin.os.tag != .windows) {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        const slice = try std.posix.gethostname(&buf);
        return try allocator.dupe(u8, slice);
    }
    return error.Unsupported;
}
