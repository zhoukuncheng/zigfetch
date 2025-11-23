const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    try appendPath(ctx, list, "/");
    try appendPath(ctx, list, "/mnt/c");
}

fn appendPath(ctx: *types.Context, list: *std.ArrayList(types.InfoField), path: []const u8) !void {
    const cmd = try std.fmt.allocPrint(ctx.allocator, "df -PT {s}", .{path});
    defer ctx.allocator.free(cmd);

    const result = std.process.Child.run(.{
        .allocator = ctx.allocator,
        .argv = &[_][]const u8{ "sh", "-c", cmd },
        .max_output_bytes = 32 * 1024,
    }) catch return;
    defer ctx.allocator.free(result.stdout);
    defer ctx.allocator.free(result.stderr);

    var lines = std.mem.tokenizeScalar(u8, result.stdout, '\n');
    _ = lines.next(); // header
    const line = lines.next() orelse return;

    var parts = std.mem.tokenizeAny(u8, std.mem.trim(u8, line, " \t\r\n"), " \t");
    _ = parts.next() orelse return; // filesystem
    const fstype = parts.next() orelse "unknown";
    const blocks = parts.next() orelse return;
    const used = parts.next() orelse return;
    _ = parts.next() orelse return; // available
    const percent = parts.next() orelse "0%";

    const used_bytes = parseBlocks(used) catch return;
    const total_bytes = parseBlocks(blocks) catch return;

    const value = try std.fmt.allocPrint(ctx.allocator, "({s}) {d:.2} GiB / {d:.2} GiB ({s}) - {s}", .{
        path,
        bytesToGiB(used_bytes),
        bytesToGiB(total_bytes),
        percent,
        fstype,
    });

    try list.append(ctx.allocator, .{
        .key = "Disk",
        .value = value,
    });
}

fn parseBlocks(token: []const u8) !u64 {
    const blocks = try std.fmt.parseInt(u64, token, 10);
    return blocks * 1024;
}

fn bytesToGiB(bytes: u64) f64 {
    return @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0);
}
