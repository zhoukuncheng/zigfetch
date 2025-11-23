const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const term = std.process.getEnvVarOwned(ctx.allocator, "TERM") catch null;
    const color_term = std.process.getEnvVarOwned(ctx.allocator, "COLORTERM") catch null;

    defer if (term) |t| ctx.allocator.free(t);
    defer if (color_term) |c| ctx.allocator.free(c);

    if (term == null and color_term == null) return;

    const value = blk: {
        if (term != null and color_term != null) {
            break :blk try std.fmt.allocPrint(ctx.allocator, "{s} ({s})", .{ term.?, color_term.? });
        } else if (term != null) {
            break :blk try ctx.allocator.dupe(u8, term.?);
        } else {
            break :blk try ctx.allocator.dupe(u8, color_term.?);
        }
    };

    try list.append(ctx.allocator, .{
        .key = "Terminal",
        .value = value,
    });
}
