const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    } else {
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
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var info: std.os.windows.RTL_OSVERSIONINFOW = undefined;
    info.dwOSVersionInfoSize = @sizeOf(std.os.windows.RTL_OSVERSIONINFOW);
    _ = std.os.windows.ntdll.RtlGetVersion(&info);

    const value = try std.fmt.allocPrint(ctx.allocator, "{d}.{d}.{d}", .{
        info.dwMajorVersion,
        info.dwMinorVersion,
        info.dwBuildNumber,
    });

    try list.append(ctx.allocator, .{
        .key = "Kernel",
        .value = value,
    });
}
