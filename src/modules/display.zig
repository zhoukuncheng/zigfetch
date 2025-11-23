const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const result = std.process.Child.run(.{
        .allocator = ctx.allocator,
        .argv = &[_][]const u8{ "xrandr", "--listmonitors" },
        .max_output_bytes = 32 * 1024,
    }) catch return;
    defer ctx.allocator.free(result.stdout);
    defer ctx.allocator.free(result.stderr);

    var lines = std.mem.tokenizeScalar(u8, result.stdout, '\n');
    _ = lines.next(); // skip header
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;
        const parsed = parseMonitor(ctx.allocator, line) catch null;
        if (parsed == null) continue;
        defer ctx.allocator.free(parsed.?);

        try list.append(ctx.allocator, .{
            .key = "Display",
            .value = try ctx.allocator.dupe(u8, parsed.?),
        });
    }
}

fn parseMonitor(allocator: std.mem.Allocator, line: []const u8) !?[]const u8 {
    // Example: " 0: +*rdp-0 3840/1016x2160/571+0+0  rdp-0"
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    const rest = std.mem.trim(u8, line[colon + 1 ..], " \t");
    var tokens = std.mem.tokenizeAny(u8, rest, " \t");
    _ = tokens.next() orelse return null; // +/- flags with name
    const name = tokens.next() orelse return null;

    var res: ?[]const u8 = null;
    var refresh: ?[]const u8 = null;
    var res_tokens = std.mem.tokenizeAny(u8, rest, " \t");
    while (res_tokens.next()) |t| {
        if (std.mem.indexOfScalar(u8, t, 'x')) |_| {
            res = t;
            break;
        }
    }

    // Try to find refresh via xrandr verbose token "60.00*+"
    var detailed_tokens = std.mem.tokenizeAny(u8, rest, " \t");
    while (detailed_tokens.next()) |t| {
        if (std.mem.indexOfScalar(u8, t, '.') != null and std.mem.endsWith(u8, t, "*")) {
            refresh = t;
            break;
        }
    }

    if (res == null) return null;

    if (refresh) |hz| {
        return try std.fmt.allocPrint(allocator, "{s}: {s} @ {s} Hz", .{ name, res.?, trimSuffix(hz, "*") });
    }
    return try std.fmt.allocPrint(allocator, "{s}: {s}", .{ name, res.? });
}

fn trimSuffix(val: []const u8, suffix: []const u8) []const u8 {
    if (std.mem.endsWith(u8, val, suffix)) return val[0 .. val.len - suffix.len];
    return val;
}
