const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
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

fn getUser(allocator: std.mem.Allocator) ![]const u8 {
    const env_keys = [_][]const u8{ "USER", "LOGNAME", "USERNAME" };
    for (env_keys) |k| {
        const val = std.process.getEnvVarOwned(allocator, k) catch continue;
        if (val.len > 0) return val;
        allocator.free(val);
    }
    const uid = std.posix.getuid();
    return try std.fmt.allocPrint(allocator, "{d}", .{uid});
}

fn readHostname(allocator: std.mem.Allocator) ![]const u8 {
    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const slice = try std.posix.gethostname(&buf);
    return try allocator.dupe(u8, slice);
}
