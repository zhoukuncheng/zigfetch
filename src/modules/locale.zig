const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const locale = getLocale(ctx.allocator) catch return;
    defer if (locale) |loc| ctx.allocator.free(loc);

    const value = if (locale) |loc|
        try ctx.allocator.dupe(u8, loc)
    else
        try ctx.allocator.dupe(u8, "Unknown");

    try list.append(ctx.allocator, .{
        .key = "Locale",
        .value = value,
    });
}

fn getLocale(allocator: std.mem.Allocator) !?[]const u8 {
    const keys = [_][]const u8{ "LC_ALL", "LANG" };
    for (keys) |k| {
        const val = std.process.getEnvVarOwned(allocator, k) catch continue;
        if (val.len == 0) {
            allocator.free(val);
            continue;
        }
        return val;
    }
    return null;
}
