const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const locale = if (builtin.os.tag == .windows)
        getLocaleWindows(ctx.allocator) catch null
    else
        getLocale(ctx.allocator) catch null;

    defer if (locale) |loc| ctx.allocator.free(loc);

    const value = if (locale) |loc|
        try ctx.allocator.dupe(u8, loc)
    else
        try ctx.allocator.dupe(u8, "Unknown");

    try list.append(ctx.allocator, .{
        .key = "Locale",
        .value = value,
    });
}

fn getLocale(allocator: std.mem.Allocator) !?[]const u8 {
    const keys = [_][]const u8{ "LC_ALL", "LANG" };
    for (keys) |k| {
        const val = std.process.getEnvVarOwned(allocator, k) catch continue;
        if (val.len == 0) {
            allocator.free(val);
            continue;
        }
        return val;
    }
    return null;
}

fn getLocaleWindows(allocator: std.mem.Allocator) !?[]const u8 {
    var buf: [85]u16 = undefined; // LOCALE_NAME_MAX_LENGTH
    const len = GetUserDefaultLocaleName(&buf, buf.len);
    if (len > 0) {
        // len includes null terminator if successful? No, checks MSDN...
        // "Returns the number of characters retrieved in the locale name string, including the terminating null character"
        var utf8_buf: [256]u8 = undefined;
        const utf8_len = std.unicode.utf16LeToUtf8(&utf8_buf, buf[0..@intCast(len - 1)]) catch return null;
        return try allocator.dupe(u8, utf8_buf[0..utf8_len]);
    }
    return null;
}

extern "kernel32" fn GetUserDefaultLocaleName(lpLocaleName: [*]u16, cchLocaleName: c_int) callconv(.winapi) c_int;
