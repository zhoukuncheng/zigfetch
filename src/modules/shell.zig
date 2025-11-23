const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const shell_path = std.process.getEnvVarOwned(ctx.allocator, "SHELL") catch null;
    defer if (shell_path) |sp| ctx.allocator.free(sp);

    const shell_value = blk: {
        if (shell_path) |sp| {
            const base = std.fs.path.basename(sp);
            break :blk try std.fmt.allocPrint(ctx.allocator, "{s} ({s})", .{ base, sp });
        }
        const comm = readComm(ctx.allocator) catch null;
        if (comm) |c| {
            break :blk c;
        }
        break :blk try ctx.allocator.dupe(u8, "Unknown");
    };

    try list.append(ctx.allocator, .{
        .key = "Shell",
        .value = shell_value,
    });
}

fn readComm(allocator: std.mem.Allocator) ![]const u8 {
    var file = std.fs.openFileAbsolute("/proc/self/comm", .{}) catch return error.Missing;
    defer file.close();
    const max_size: usize = 256;
    const data = try file.readToEndAlloc(allocator, max_size);
    const trimmed = std.mem.trim(u8, data, " \t\r\n");
    if (trimmed.len == 0) {
        allocator.free(data);
        return error.Missing;
    }
    return trimmed;
}
