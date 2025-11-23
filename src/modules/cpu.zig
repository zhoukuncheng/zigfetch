const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var file = std.fs.openFileAbsolute("/proc/cpuinfo", .{}) catch return;
    defer file.close();

    const content = try file.readToEndAlloc(ctx.allocator, 64 * 1024);
    defer ctx.allocator.free(content);

    var it = std.mem.tokenizeScalar(u8, content, '\n');
    var model_name: ?[]const u8 = null;
    var cores: usize = 0;
    var threads: usize = 0;

    while (it.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, "model name")) {
            if (model_name == null) {
                if (std.mem.indexOfScalar(u8, line, ':')) |idx| {
                    const name = std.mem.trim(u8, line[idx + 1 ..], " \t");
                    model_name = try ctx.allocator.dupe(u8, name);
                }
            }
        } else if (std.mem.startsWith(u8, line, "cpu cores")) {
            if (std.mem.indexOfScalar(u8, line, ':')) |idx| {
                const num_str = std.mem.trim(u8, line[idx + 1 ..], " \t");
                cores = std.fmt.parseInt(usize, num_str, 10) catch cores;
            }
        } else if (std.mem.startsWith(u8, line, "processor")) {
            threads += 1;
        }
    }

    const value = try std.fmt.allocPrint(
        ctx.allocator,
        "{s} ({d} cores / {d} threads)",
        .{ model_name orelse "Unknown", cores, threads },
    );

    if (model_name) |m| ctx.allocator.free(m);

    try list.append(ctx.allocator, .{
        .key = "CPU",
        .value = value,
    });
}
