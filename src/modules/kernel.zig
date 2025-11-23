const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const uts = std.posix.uname();
    const sysname = std.mem.sliceTo(&uts.sysname, 0);
    const release = std.mem.sliceTo(&uts.release, 0);
    const version = std.mem.sliceTo(&uts.version, 0);

    const value = try std.fmt.allocPrint(
        ctx.allocator,
        "{s} {s} ({s})",
        .{ sysname, release, version },
    );

    try list.append(ctx.allocator, .{
        .key = "Kernel",
        .value = value,
    });
}
