const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }

    var file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch return;
    defer file.close();

    const content = try file.readToEndAlloc(ctx.allocator, 16 * 1024);
    defer ctx.allocator.free(content);

    var reader = std.mem.tokenizeScalar(u8, content, '\n');
    var total_kb: u64 = 0;
    var avail_kb: u64 = 0;

    while (reader.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            total_kb = parseValue(line) catch total_kb;
        } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
            avail_kb = parseValue(line) catch avail_kb;
        }
    }

    if (total_kb == 0) return;
    const used_kb = if (avail_kb > 0 and avail_kb < total_kb) total_kb - avail_kb else 0;

    const value = try std.fmt.allocPrint(
        ctx.allocator,
        "{d:.2} GiB / {d:.2} GiB",
        .{
            @as(f64, @floatFromInt(used_kb)) / (1024.0 * 1024.0),
            @as(f64, @floatFromInt(total_kb)) / (1024.0 * 1024.0),
        },
    );

    try list.append(ctx.allocator, .{
        .key = "Memory",
        .value = value,
    });
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var status: MEMORYSTATUSEX = undefined;
    status.dwLength = @sizeOf(MEMORYSTATUSEX);
    if (GlobalMemoryStatusEx(&status) == 0) return;

    const total = status.ullTotalPhys;
    const avail = status.ullAvailPhys;
    const used = total - avail;

    const value = try std.fmt.allocPrint(
        ctx.allocator,
        "{d:.2} GiB / {d:.2} GiB",
        .{
            @as(f64, @floatFromInt(used)) / (1024.0 * 1024.0 * 1024.0),
            @as(f64, @floatFromInt(total)) / (1024.0 * 1024.0 * 1024.0),
        },
    );

    try list.append(ctx.allocator, .{
        .key = "Memory",
        .value = value,
    });
}

const MEMORYSTATUSEX = extern struct {
    dwLength: u32,
    dwMemoryLoad: u32,
    ullTotalPhys: u64,
    ullAvailPhys: u64,
    ullTotalPageFile: u64,
    ullAvailPageFile: u64,
    ullTotalVirtual: u64,
    ullAvailVirtual: u64,
    ullAvailExtendedVirtual: u64,
};

extern "kernel32" fn GlobalMemoryStatusEx(lpBuffer: *MEMORYSTATUSEX) callconv(.winapi) c_int;

fn parseValue(line: []const u8) !u64 {
    const idx = std.mem.indexOfScalar(u8, line, ':') orelse return error.ParseFailed;
    var value_part = std.mem.trim(u8, line[idx + 1 ..], " \t");
    const space_idx = std.mem.indexOfScalar(u8, value_part, ' ') orelse value_part.len;
    value_part = value_part[0..space_idx];
    return std.fmt.parseInt(u64, value_part, 10);
}
