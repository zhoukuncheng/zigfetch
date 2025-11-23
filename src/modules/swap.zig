const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch return;
    defer file.close();

    const content = try file.readToEndAlloc(ctx.allocator, 16 * 1024);
    defer ctx.allocator.free(content);

    var total_kb: u64 = 0;
    var free_kb: u64 = 0;

    var lines = std.mem.tokenizeScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "SwapTotal:")) {
            total_kb = parseValue(line) catch total_kb;
        } else if (std.mem.startsWith(u8, line, "SwapFree:")) {
            free_kb = parseValue(line) catch free_kb;
        }
    }

    if (total_kb == 0) return;
    const used_kb = if (free_kb < total_kb) total_kb - free_kb else 0;
    const pct = if (total_kb == 0) 0 else (used_kb * 100) / total_kb;

    const value = try std.fmt.allocPrint(ctx.allocator, "{d:.2} GiB / {d:.2} GiB ({d}%)", .{
        @as(f64, @floatFromInt(used_kb)) / (1024.0 * 1024.0),
        @as(f64, @floatFromInt(total_kb)) / (1024.0 * 1024.0),
        pct,
    });

    try list.append(ctx.allocator, .{
        .key = "Swap",
        .value = value,
    });
}

fn parseValue(line: []const u8) !u64 {
    const idx = std.mem.indexOfScalar(u8, line, ':') orelse return error.ParseFailed;
    const rest = std.mem.trim(u8, line[idx + 1 ..], " \t");
    const sp = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
    return std.fmt.parseInt(u64, rest[0..sp], 10);
}
