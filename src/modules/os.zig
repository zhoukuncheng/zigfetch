const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var file = std.fs.openFileAbsolute("/etc/os-release", .{}) catch {
        return collectFallback(ctx, list);
    };
    defer file.close();

    const content = try file.readToEndAlloc(ctx.allocator, 8 * 1024);
    defer ctx.allocator.free(content);

    var reader = std.mem.tokenizeScalar(u8, content, '\n');
    var pretty_name: ?[]const u8 = null;
    var name: ?[]const u8 = null;

    while (reader.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0 or line[0] == '#') continue;

        const eq_idx = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = line[0..eq_idx];
        var value = line[eq_idx + 1 ..];
        value = std.mem.trim(u8, value, " \t\r\n\"");

        if (std.ascii.eqlIgnoreCase(key, "PRETTY_NAME")) {
            if (pretty_name == null) {
                pretty_name = try ctx.allocator.dupe(u8, value);
            }
        } else if (std.ascii.eqlIgnoreCase(key, "NAME")) {
            if (name == null) {
                name = try ctx.allocator.dupe(u8, value);
            }
        } else if (std.ascii.eqlIgnoreCase(key, "ID")) {
            ctx.setOsId(value) catch {};
        }
    }

    const chosen = pretty_name orelse name orelse "Unknown";
    const copy = try ctx.allocator.dupe(u8, chosen);
    try list.append(ctx.allocator, .{
        .key = "OS",
        .value = copy,
    });

    if (pretty_name) |p| ctx.allocator.free(p);
    if (name) |n| ctx.allocator.free(n);
}

fn collectFallback(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const uts = std.posix.uname();
    const sysname = std.mem.sliceTo(&uts.sysname, 0);
    const release = std.mem.sliceTo(&uts.release, 0);
    const value = try std.fmt.allocPrint(ctx.allocator, "{s} {s}", .{ sysname, release });
    try list.append(ctx.allocator, .{
        .key = "OS",
        .value = value,
    });
}
