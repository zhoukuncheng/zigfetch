const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }

    var file = std.fs.openFileAbsolute("/proc/uptime", .{}) catch return;
    defer file.close();

    var buf: [128]u8 = undefined;
    const n = try file.readAll(buf[0..]);
    const content = std.mem.trim(u8, buf[0..n], " \t\r\n");
    if (content.len == 0) return;

    const space_idx = std.mem.indexOfScalar(u8, content, ' ') orelse content.len;
    const uptime_str = content[0..space_idx];
    const seconds_f = std.fmt.parseFloat(f64, uptime_str) catch return;
    const seconds: u64 = @intFromFloat(seconds_f);

    const days = seconds / 86_400;
    const hours = (seconds % 86_400) / 3_600;
    const mins = (seconds % 3_600) / 60;

    const value = try std.fmt.allocPrint(ctx.allocator, "{d}d {d}h {d}m", .{ days, hours, mins });

    try list.append(ctx.allocator, .{
        .key = "Uptime",
        .value = value,
    });
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const ticks = GetTickCount64();
    const seconds = ticks / 1000;

    const days = seconds / 86_400;
    const hours = (seconds % 86_400) / 3_600;
    const mins = (seconds % 3_600) / 60;

    const value = try std.fmt.allocPrint(ctx.allocator, "{d}d {d}h {d}m", .{ days, hours, mins });

    try list.append(ctx.allocator, .{
        .key = "Uptime",
        .value = value,
    });
}

extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
