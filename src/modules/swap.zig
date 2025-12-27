const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    if (builtin.os.tag == .windows) {
        return collectWindows(ctx, list);
    }
    var file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch return;
    defer file.close();

    const content = try file.readToEndAlloc(ctx.allocator, 16 * 1024);
    defer ctx.allocator.free(content);

    var total_kb: u64 = 0;
    var free_kb: u64 = 0;

    var lines = std.mem.tokenizeScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "SwapTotal:")) {
            total_kb = parseValue(line) catch total_kb;
        } else if (std.mem.startsWith(u8, line, "SwapFree:")) {
            free_kb = parseValue(line) catch free_kb;
        }
    }

    if (total_kb == 0) return;
    const used_kb = if (free_kb < total_kb) total_kb - free_kb else 0;
    const pct = if (total_kb == 0) 0 else (used_kb * 100) / total_kb;

    const value = try std.fmt.allocPrint(ctx.allocator, "{d:.2} GiB / {d:.2} GiB ({d}%)", .{
        @as(f64, @floatFromInt(used_kb)) / (1024.0 * 1024.0),
        @as(f64, @floatFromInt(total_kb)) / (1024.0 * 1024.0),
        pct,
    });

    try list.append(ctx.allocator, .{
        .key = "Swap",
        .value = value,
    });
}

fn collectWindows(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    var status: MEMORYSTATUSEX = undefined;
    status.dwLength = @sizeOf(MEMORYSTATUSEX);
    if (GlobalMemoryStatusEx(&status) == 0) return;

    // Windows PageFile usage
    // ullTotalPageFile is the commit limit (Physical + PageFile).
    // ullAvailPageFile is available commit.
    // This isn't exactly "Swap" in Linux terms (which is usually just the swap partition),
    // but it's the closest analogue for "Virtual Memory".
    // Alternatively, we can calculate Swap = TotalCommit - TotalPhys?
    // Usually people want to see PageFile size.
    // status.ullTotalPageFile includes physical memory.
    // Real Swap size ~ status.ullTotalPageFile - status.ullTotalPhys

    // Let's just report the numbers given as "Virtual Memory" roughly.
    // Or strictly (TotalPage - TotalPhys).

    const total_phys = status.ullTotalPhys;
    const total_page = status.ullTotalPageFile;

    if (total_page <= total_phys) return; // No swap file likely

    const swap_total = total_page - total_phys;
    const avail_page = status.ullAvailPageFile;
    const avail_phys = status.ullAvailPhys;

    // Approximate swap available is hard because Windows manages them together.
    // Let's just use the whole "PageFile" metric which users often confuse with Swap.
    // Correct way:
    // Swap Used = (TotalPage - AvailPage) - (TotalPhys - AvailPhys) ?
    const commited = total_page - avail_page;
    const phys_used = total_phys - avail_phys;
    const swap_used = if (commited > phys_used) commited - phys_used else 0;

    const pct = if (swap_total == 0) 0 else (swap_used * 100) / swap_total;

    const value = try std.fmt.allocPrint(ctx.allocator, "{d:.2} GiB / {d:.2} GiB ({d}%)", .{
        @as(f64, @floatFromInt(swap_used)) / (1024.0 * 1024.0 * 1024.0),
        @as(f64, @floatFromInt(swap_total)) / (1024.0 * 1024.0 * 1024.0),
        pct,
    });

    try list.append(ctx.allocator, .{
        .key = "Swap",
        .value = value,
    });
}

const MEMORYSTATUSEX = extern struct {
    dwLength: u32,
    dwMemoryLoad: u32,
    ullTotalPhys: u64,
    ullAvailPhys: u64,
    ullTotalPageFile: u64,
    ullAvailPageFile: u64,
    ullTotalVirtual: u64,
    ullAvailVirtual: u64,
    ullAvailExtendedVirtual: u64,
};
extern "kernel32" fn GlobalMemoryStatusEx(lpBuffer: *MEMORYSTATUSEX) callconv(.winapi) c_int;

fn parseValue(line: []const u8) !u64 {
    const idx = std.mem.indexOfScalar(u8, line, ':') orelse return error.ParseFailed;
    const rest = std.mem.trim(u8, line[idx + 1 ..], " \t");
    const sp = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
    return std.fmt.parseInt(u64, rest[0..sp], 10);
}
