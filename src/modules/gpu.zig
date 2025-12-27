const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }
    var seen = std.ArrayList([]const u8).empty;
    defer seen.deinit(ctx.allocator);

    const next_idx = try appendNvidia(ctx, list, &seen, 1);
    const summary = try appendLspci(ctx, list, &seen, next_idx);
    if (!summary.found_integrated) {
        try appendCpuHint(ctx, list, &seen, summary.next_index);
    }
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    // Use wmic path win32_VideoController get Name
    const result = std.process.Child.run(.{
        .allocator = ctx.allocator,
        .argv = &[_][]const u8{ "wmic", "path", "win32_VideoController", "get", "Name" },
        .max_output_bytes = 64 * 1024,
    }) catch return;
    defer ctx.allocator.free(result.stdout);
    defer ctx.allocator.free(result.stderr);

    var lines = std.mem.tokenizeScalar(u8, result.stdout, '\n');
    _ = lines.next(); // Skip Header "Name"

    var idx: usize = 0;
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;

        const value = try std.fmt.allocPrint(ctx.allocator, "{d}: {s}", .{ idx, line });
        try list.append(ctx.allocator, .{
            .key = "GPU",
            .value = value,
        });
        idx += 1;
    }
}

fn appendNvidia(ctx: *types.Context, list: *std.ArrayList(types.InfoField), seen: *std.ArrayList([]const u8), start_idx: usize) !usize {
    const out = std.process.Child.run(.{
        .allocator = ctx.allocator,
        .argv = &[_][]const u8{ "nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader" },
        .max_output_bytes = 64 * 1024,
    }) catch return start_idx;
    defer ctx.allocator.free(out.stdout);
    defer ctx.allocator.free(out.stderr);

    var idx: usize = start_idx;
    var lines = std.mem.tokenizeScalar(u8, std.mem.trim(u8, out.stdout, " \t\r\n"), '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r\n");
        if (line.len == 0) continue;

        const parts_idx = std.mem.indexOfScalar(u8, line, ',') orelse continue;
        const name = std.mem.trim(u8, line[0..parts_idx], " \t");
        const mem_str = std.mem.trim(u8, line[parts_idx + 1 ..], " \t");
        const gib = parseMemGiB(mem_str) catch null;
        const value = if (gib) |g|
            try std.fmt.allocPrint(ctx.allocator, "{d}: {s} ({d:.2} GiB) [Discrete]", .{ idx, name, g })
        else
            try std.fmt.allocPrint(ctx.allocator, "{d}: {s} [Discrete]", .{ idx, name });

        try list.append(ctx.allocator, .{ .key = "GPU", .value = value });
        try seen.append(ctx.allocator, value);
        idx += 1;
    }
    return idx;
}

const LspciSummary = struct {
    next_index: usize,
    found_integrated: bool,
};

fn appendLspci(ctx: *types.Context, list: *std.ArrayList(types.InfoField), seen: *std.ArrayList([]const u8), start_idx: usize) !LspciSummary {
    const out = std.process.Child.run(.{
        .allocator = ctx.allocator,
        .argv = &[_][]const u8{ "sh", "-c", "lspci -nn | grep -iE 'vga|3d|display'" },
        .max_output_bytes = 64 * 1024,
    }) catch return .{ .next_index = start_idx, .found_integrated = false };
    defer ctx.allocator.free(out.stdout);
    defer ctx.allocator.free(out.stderr);

    var lines = std.mem.tokenizeScalar(u8, std.mem.trim(u8, out.stdout, " \t\r\n"), '\n');
    var idx: usize = start_idx;
    var found_integrated = false;
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, "Basic Render Driver") != null) continue;
        if (std.mem.indexOf(u8, line, "1414:008e") != null) continue;
        const desc = parseLspciLine(line) orelse line;
        if (alreadySeen(seen.items, desc)) continue;

        const value = try std.fmt.allocPrint(ctx.allocator, "GPU {d}: {s}", .{ idx, desc });
        idx += 1;

        try list.append(ctx.allocator, .{ .key = "GPU", .value = value });
        try seen.append(ctx.allocator, value);

        if (isIntegrated(desc)) found_integrated = true;
    }

    return .{ .next_index = idx, .found_integrated = found_integrated };
}

fn parseMemGiB(mem_str: []const u8) !?f64 {
    // e.g. "8192 MiB"
    var parts = std.mem.tokenizeAny(u8, mem_str, " \t");
    const num_str = parts.next() orelse return null;
    const unit = parts.next() orelse return null;
    const val = try std.fmt.parseFloat(f64, num_str);
    if (std.ascii.eqlIgnoreCase(unit, "MiB")) {
        return val / 1024.0;
    } else if (std.ascii.eqlIgnoreCase(unit, "GiB")) {
        return val;
    }
    return null;
}

fn parseLspciLine(line: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, line, "controller:")) |idx| {
        const desc = std.mem.trim(u8, line[idx + "controller:".len ..], " \t");
        return desc;
    }
    return null;
}

fn alreadySeen(seen: []const []const u8, candidate: []const u8) bool {
    for (seen) |s| {
        if (std.ascii.eqlIgnoreCase(s, candidate)) return true;
    }
    return false;
}

fn isIntegrated(desc: []const u8) bool {
    if (std.mem.indexOf(u8, desc, "Intel") != null) return true;
    if (std.mem.indexOf(u8, desc, "AMD") != null) return true;
    if (std.mem.indexOf(u8, desc, "Radeon") != null) return true;
    if (std.mem.indexOf(u8, desc, "Integrated") != null) return true;
    return false;
}

fn appendCpuHint(ctx: *types.Context, list: *std.ArrayList(types.InfoField), seen: *std.ArrayList([]const u8), start_idx: usize) !void {
    var file = std.fs.openFileAbsolute("/proc/cpuinfo", .{}) catch return;
    defer file.close();
    const data = try file.readToEndAlloc(ctx.allocator, 32 * 1024);
    defer ctx.allocator.free(data);

    if (std.mem.indexOf(u8, data, "Radeon")) |p| {
        _ = p;
    } else {
        return;
    }

    const value = try std.fmt.allocPrint(ctx.allocator, "{d}: AMD Radeon Graphics [Integrated]", .{start_idx});
    if (alreadySeen(seen.items, value)) {
        ctx.allocator.free(value);
        return;
    }
    try list.append(ctx.allocator, .{ .key = "GPU", .value = value });
    try seen.append(ctx.allocator, value);
}
