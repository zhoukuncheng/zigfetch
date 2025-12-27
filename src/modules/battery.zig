const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }
    var dir = std.fs.openDirAbsolute("/sys/class/power_supply", .{ .iterate = true }) catch return;
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .directory and entry.kind != .sym_link) continue;
        if (!std.mem.startsWith(u8, entry.name, "BAT") and !std.mem.containsAtLeast(u8, entry.name, 1, "battery")) continue;
        try appendBattery(ctx, list, entry.name);
    }
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var status: SYSTEM_POWER_STATUS = undefined;
    if (GetSystemPowerStatus(&status) == 0) return;

    if (status.BatteryFlag == 128 or status.BatteryFlag == 255) return; // No battery or unknown

    const percent = status.BatteryLifePercent;

    // Status: 1=High, 2=Low, 4=Critical, 8=Charging, 128=No System Battery
    const state = if ((status.BatteryFlag & 8) != 0) "Charging" else "Discharging";

    const value = try std.fmt.allocPrint(ctx.allocator, "{d}% [{s}]", .{ percent, state });
    try list.append(ctx.allocator, .{
        .key = "Battery",
        .value = value,
    });
}

const SYSTEM_POWER_STATUS = extern struct {
    ACLineStatus: u8,
    BatteryFlag: u8,
    BatteryLifePercent: u8,
    SystemStatusFlag: u8,
    BatteryLifeTime: u32,
    BatteryFullLifeTime: u32,
};
extern "kernel32" fn GetSystemPowerStatus(lpSystemPowerStatus: *SYSTEM_POWER_STATUS) callconv(.winapi) c_int;

fn appendBattery(ctx: *types.Context, list: *std.ArrayList(types.InfoField), name: []const u8) !void {
    const base = try std.fmt.allocPrint(ctx.allocator, "/sys/class/power_supply/{s}", .{name});
    defer ctx.allocator.free(base);

    const type_path = try std.fmt.allocPrint(ctx.allocator, "{s}/type", .{base});
    defer ctx.allocator.free(type_path);
    const type_val = readFileTrim(ctx.allocator, type_path) catch return;
    if (type_val == null or !std.ascii.eqlIgnoreCase(type_val.?, "Battery")) {
        if (type_val) |t| ctx.allocator.free(t);
        return;
    }
    if (type_val) |t| ctx.allocator.free(t);

    const capacity_path = try std.fmt.allocPrint(ctx.allocator, "{s}/capacity", .{base});
    const status_path = try std.fmt.allocPrint(ctx.allocator, "{s}/status", .{base});
    const model_path = try std.fmt.allocPrint(ctx.allocator, "{s}/model_name", .{base});
    const manuf_path = try std.fmt.allocPrint(ctx.allocator, "{s}/manufacturer", .{base});

    const capacity = readFileTrim(ctx.allocator, capacity_path) catch null;
    const status = readFileTrim(ctx.allocator, status_path) catch null;
    const model = readFileTrim(ctx.allocator, model_path) catch null;
    const manuf = readFileTrim(ctx.allocator, manuf_path) catch null;

    ctx.allocator.free(capacity_path);
    ctx.allocator.free(status_path);
    ctx.allocator.free(model_path);
    ctx.allocator.free(manuf_path);

    const name_str = blk: {
        if (model != null or manuf != null) {
            break :blk try std.fmt.allocPrint(ctx.allocator, "{s} {s}", .{ manuf orelse "", model orelse "" });
        }
        break :blk try ctx.allocator.dupe(u8, name);
    };

    const value = try std.fmt.allocPrint(
        ctx.allocator,
        "{s}: {s}% [{s}]",
        .{
            std.mem.trim(u8, name_str, " "),
            capacity orelse "Unknown",
            status orelse "Unknown",
        },
    );

    try list.append(ctx.allocator, .{
        .key = "Battery",
        .value = value,
    });

    ctx.allocator.free(name_str);
    if (capacity) |c| ctx.allocator.free(c);
    if (status) |s| ctx.allocator.free(s);
    if (model) |m| ctx.allocator.free(m);
    if (manuf) |m| ctx.allocator.free(m);
}

fn readFileTrim(allocator: std.mem.Allocator, path: []const u8) !?[]const u8 {
    var file = std.fs.openFileAbsolute(path, .{}) catch return null;
    defer file.close();
    const data = try file.readToEndAlloc(allocator, 1024);
    const trimmed = std.mem.trim(u8, data, " \t\r\n");
    if (trimmed.len == 0) {
        allocator.free(data);
        return null;
    }
    return data;
}
