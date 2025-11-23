const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const hostname = try readHostname(ctx.allocator);
    const model = try readTrimmed(ctx.allocator, "/sys/devices/virtual/dmi/id/product_name");
    const vendor = try readTrimmed(ctx.allocator, "/sys/devices/virtual/dmi/id/sys_vendor");

    const value = blk: {
        if (model != null or vendor != null) {
            const vendor_part = vendor orelse "";
            const model_part = model orelse "";
            break :blk try std.fmt.allocPrint(ctx.allocator, "{s} ({s} {s})", .{
                hostname,
                vendor_part,
                model_part,
            });
        }
        break :blk try ctx.allocator.dupe(u8, hostname);
    };

    ctx.allocator.free(hostname);
    if (model) |m| ctx.allocator.free(m);
    if (vendor) |v| ctx.allocator.free(v);

    try list.append(ctx.allocator, .{
        .key = "Host",
        .value = value,
    });
}

fn readHostname(allocator: std.mem.Allocator) ![]const u8 {
    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const slice = try std.posix.gethostname(&buf);
    return try allocator.dupe(u8, slice);
}

fn readTrimmed(allocator: std.mem.Allocator, path: []const u8) !?[]const u8 {
    var file = std.fs.openFileAbsolute(path, .{}) catch return null;
    defer file.close();
    const max_size: usize = 512;
    const contents = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(contents);

    const trimmed = std.mem.trim(u8, contents, " \t\r\n");
    if (trimmed.len == 0) return null;

    return try allocator.dupe(u8, trimmed);
}
