const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }

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

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const product_name = getWindowsProductName(ctx.allocator) catch try ctx.allocator.dupe(u8, "Windows");

    ctx.setOsId("windows") catch {};

    try list.append(ctx.allocator, .{
        .key = "OS",
        .value = product_name,
    });
}

fn getWindowsProductName(allocator: std.mem.Allocator) ![]const u8 {
    var hKey: std.os.windows.HKEY = undefined;
    const path = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion";

    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, path, 0, KEY_READ, &hKey) != 0) {
        return error.RegistryError;
    }
    defer _ = RegCloseKey(hKey);

    var buf: [256]u8 = undefined;
    var len: u32 = buf.len;

    if (RegQueryValueExA(hKey, "ProductName", null, null, &buf, &len) != 0) {
        return error.RegistryError;
    }

    const slice = std.mem.sliceTo(buf[0..len], 0);
    return try allocator.dupe(u8, std.mem.trim(u8, slice, " "));
}

const HKEY_LOCAL_MACHINE: std.os.windows.HKEY = @ptrFromInt(0x80000002);
const KEY_READ: u32 = 0x20019;

extern "advapi32" fn RegOpenKeyExA(
    hKey: std.os.windows.HKEY,
    lpSubKey: [*:0]const u8,
    ulOptions: u32,
    samDesired: u32,
    phkResult: *std.os.windows.HKEY,
) callconv(.winapi) std.os.windows.LSTATUS;

extern "advapi32" fn RegQueryValueExA(
    hKey: std.os.windows.HKEY,
    lpValueName: [*:0]const u8,
    lpReserved: ?*u32,
    lpType: ?*u32,
    lpData: ?[*]u8,
    lpcbData: ?*u32,
) callconv(.winapi) std.os.windows.LSTATUS;

extern "advapi32" fn RegCloseKey(
    hKey: std.os.windows.HKEY,
) callconv(.winapi) std.os.windows.LSTATUS;

fn collectFallback(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag != .windows) {
        const uts = std.posix.uname();
        const sysname = std.mem.sliceTo(&uts.sysname, 0);
        const release = std.mem.sliceTo(&uts.release, 0);
        const value = try std.fmt.allocPrint(ctx.allocator, "{s} {s}", .{ sysname, release });
        try list.append(ctx.allocator, .{
            .key = "OS",
            .value = value,
        });
    }
}
