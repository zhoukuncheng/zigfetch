const std = @import("std");
const types = @import("../types.zig");
const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }

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

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const model_name = getCpuModel(ctx.allocator) catch try ctx.allocator.dupe(u8, "Unknown CPU");
    defer ctx.allocator.free(model_name);

    const threads = std.Thread.getCpuCount() catch 1;

    const value = try std.fmt.allocPrint(
        ctx.allocator,
        "{s} ({d} threads)",
        .{ model_name, threads },
    );

    try list.append(ctx.allocator, .{
        .key = "CPU",
        .value = value,
    });
}

fn getCpuModel(allocator: std.mem.Allocator) ![]const u8 {
    var hKey: std.os.windows.HKEY = undefined;
    const path = "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0";

    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, path, 0, KEY_READ, &hKey) != 0) {
        return error.RegistryError;
    }
    defer _ = RegCloseKey(hKey);

    var buf: [256]u8 = undefined;
    var len: u32 = buf.len;

    if (RegQueryValueExA(hKey, "ProcessorNameString", null, null, &buf, &len) != 0) {
        return error.RegistryError;
    }

    // len includes null terminator if present.
    // Remove it effectively using sliceTo or trimming
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
