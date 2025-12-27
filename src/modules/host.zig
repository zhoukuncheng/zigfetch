const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }

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

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    // 1. Hostname
    const MAX_COMPUTERNAME_LENGTH = 15;
    var buf: [MAX_COMPUTERNAME_LENGTH + 1]u8 = undefined;
    var len: u32 = buf.len;
    const hostname = if (GetComputerNameA(&buf, &len) != 0)
        try ctx.allocator.dupe(u8, buf[0..len])
    else
        try ctx.allocator.dupe(u8, "Unknown");
    defer ctx.allocator.free(hostname);

    // 2. Vendor/Model from Registry
    const vendor = getRegistryValue(ctx.allocator, "HARDWARE\\DESCRIPTION\\System\\BIOS", "SystemManufacturer") catch null;
    const model = getRegistryValue(ctx.allocator, "HARDWARE\\DESCRIPTION\\System\\BIOS", "SystemProductName") catch null;
    defer if (vendor) |v| ctx.allocator.free(v);
    defer if (model) |m| ctx.allocator.free(m);

    const value = if (vendor != null or model != null)
        try std.fmt.allocPrint(ctx.allocator, "{s} ({s} {s})", .{ hostname, vendor orelse "", model orelse "" })
    else
        try ctx.allocator.dupe(u8, hostname);

    try list.append(ctx.allocator, .{
        .key = "Host",
        .value = value,
    });
}

fn getRegistryValue(allocator: std.mem.Allocator, subkey: []const u8, value_name: []const u8) ![]const u8 {
    var hKey: std.os.windows.HKEY = undefined;

    // We need to null-terminate subkey for the API
    const subkey_z = try allocator.dupeZ(u8, subkey);
    defer allocator.free(subkey_z);

    const value_name_z = try allocator.dupeZ(u8, value_name);
    defer allocator.free(value_name_z);

    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, subkey_z, 0, KEY_READ, &hKey) != 0) {
        return error.RegistryError;
    }
    defer _ = RegCloseKey(hKey);

    var buf: [256]u8 = undefined;
    var len: u32 = buf.len;

    if (RegQueryValueExA(hKey, value_name_z, null, null, &buf, &len) != 0) {
        return error.RegistryError;
    }

    const slice = std.mem.sliceTo(buf[0..len], 0);
    return try allocator.dupe(u8, std.mem.trim(u8, slice, " "));
}

const HKEY_LOCAL_MACHINE: std.os.windows.HKEY = @ptrFromInt(0x80000002);
const KEY_READ: u32 = 0x20019;

extern "kernel32" fn GetComputerNameA(lpBuffer: [*]u8, nSize: *u32) callconv(.winapi) c_int;

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

fn readHostname(allocator: std.mem.Allocator) ![]const u8 {
    if (builtin.os.tag != .windows) {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        const slice = try std.posix.gethostname(&buf);
        return try allocator.dupe(u8, slice);
    }
    return error.Unsupported;
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
