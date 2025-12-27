const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }
    try appendPath(ctx, list, "/");
    try appendPath(ctx, list, "/mnt/c");
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var free_bytes: u64 = 0;
    var total_bytes: u64 = 0;
    const path = "C:\\";

    if (GetDiskFreeSpaceExA(path, &free_bytes, &total_bytes, null) == 0) return;

    const used_bytes = total_bytes - free_bytes;
    // Calculate percentage
    const percent = if (total_bytes > 0) (used_bytes * 100) / total_bytes else 0;

    const value = try std.fmt.allocPrint(ctx.allocator, "(C:) {d:.2} GiB / {d:.2} GiB ({d}%) - NTFS", .{ bytesToGiB(used_bytes), bytesToGiB(total_bytes), percent });

    try list.append(ctx.allocator, .{
        .key = "Disk",
        .value = value,
    });
}

extern "kernel32" fn GetDiskFreeSpaceExA(lpDirectoryName: ?[*:0]const u8, lpFreeBytesAvailableToCaller: ?*u64, lpTotalNumberOfBytes: ?*u64, lpTotalNumberOfFreeBytes: ?*u64) callconv(.winapi) c_int;

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
