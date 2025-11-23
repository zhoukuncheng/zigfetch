const std = @import("std");
const types = @import("../types.zig");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const lan_ip = detectLanIp(ctx.allocator) catch null;
    const wan_ip = detectWanIp(ctx.allocator) catch null;
    const proxy_status = try formatProxyStatus(ctx.allocator);
    const dns = detectDns(ctx.allocator) catch null;

    try list.append(ctx.allocator, .{
        .key = "LAN IP",
        .value = try orUnknown(ctx.allocator, lan_ip),
    });

    try list.append(ctx.allocator, .{
        .key = "WAN IP",
        .value = try orUnavailable(ctx.allocator, wan_ip),
    });

    try list.append(ctx.allocator, .{
        .key = "Proxy",
        .value = proxy_status,
    });

    try list.append(ctx.allocator, .{
        .key = "DNS",
        .value = try orUnknown(ctx.allocator, dns),
    });
}

fn detectLanIp(allocator: std.mem.Allocator) !?[]const u8 {
    if (try parseIpFromCommand(allocator, &[_][]const u8{ "ip", "-o", "-4", "addr", "show", "scope", "global" })) |ip| {
        return ip;
    }
    if (try parseIpFromCommand(allocator, &[_][]const u8{ "hostname", "-I" })) |ip| {
        return ip;
    }
    return null;
}

fn detectWanIp(allocator: std.mem.Allocator) !?[]const u8 {
    const primary = &[_][]const u8{ "curl", "-fsSL", "--max-time", "2", "https://api.ipify.org" };
    if (try readCommandFirstLine(allocator, primary)) |ip| return ip;

    const fallback = &[_][]const u8{ "curl", "-fsSL", "--max-time", "2", "https://ifconfig.me" };
    if (try readCommandFirstLine(allocator, fallback)) |ip| return ip;

    return null;
}

fn parseIpFromCommand(allocator: std.mem.Allocator, argv: []const []const u8) !?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 64 * 1024,
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => return null,
    };
    if (exit_code != 0) return null;

    if (findFirstIpv4(result.stdout)) |ip| {
        return try allocator.dupe(u8, ip);
    }
    return null;
}

fn readCommandFirstLine(allocator: std.mem.Allocator, argv: []const []const u8) !?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 16 * 1024,
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const exit_code = switch (result.term) {
        .Exited => |code| code,
        else => return null,
    };
    if (exit_code != 0) return null;

    const trimmed = std.mem.trim(u8, result.stdout, " \t\r\n");
    if (trimmed.len == 0) return null;
    if (std.mem.indexOfScalar(u8, trimmed, '.')) |_| {} else return null;
    if (std.net.Address.parseIp4(trimmed, 0)) |_| {
        return try allocator.dupe(u8, trimmed);
    } else |_| {}
    return null;
}

fn findFirstIpv4(data: []const u8) ?[]const u8 {
    var it = std.mem.tokenizeAny(u8, data, " \t\r\n/");
    while (it.next()) |token| {
        if (token.len < 7 or token.len > 15) continue;
        if (std.mem.startsWith(u8, token, "127.")) continue;
        if (std.net.Address.parseIp4(token, 0)) |_| {
            return token;
        } else |_| {}
    }
    return null;
}

fn formatProxyStatus(allocator: std.mem.Allocator) ![]const u8 {
    const proxy_keys = [_][]const u8{
        "http_proxy",
        "https_proxy",
        "all_proxy",
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "ALL_PROXY",
    };

    var parts = std.ArrayList([]const u8).empty;
    defer freeParts(allocator, &parts);

    for (proxy_keys) |key| {
        const value = std.process.getEnvVarOwned(allocator, key) catch continue;
        defer allocator.free(value);
        const line = try std.fmt.allocPrint(allocator, "{s}={s}", .{ key, value });
        try parts.append(allocator, line);
    }

    if (try hasTunnelInterface()) {
        const label = try allocator.dupe(u8, "tun/wg detected");
        try parts.append(allocator, label);
    }

    if (parts.items.len == 0) {
        return try allocator.dupe(u8, "None");
    }

    return try std.mem.join(allocator, ", ", parts.items);
}

fn hasTunnelInterface() !bool {
    var dir = std.fs.openDirAbsolute("/sys/class/net", .{ .iterate = true }) catch return false;
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .directory and entry.kind != .sym_link) continue;
        if (std.mem.startsWith(u8, entry.name, "tun") or std.mem.startsWith(u8, entry.name, "wg")) {
            return true;
        }
    }
    return false;
}

fn orUnknown(allocator: std.mem.Allocator, value: ?[]const u8) ![]const u8 {
    if (value) |v| return v;
    return try allocator.dupe(u8, "Unknown");
}

fn orUnavailable(allocator: std.mem.Allocator, value: ?[]const u8) ![]const u8 {
    if (value) |v| return v;
    return try allocator.dupe(u8, "Unavailable");
}

fn freeParts(allocator: std.mem.Allocator, parts: *std.ArrayList([]const u8)) void {
    for (parts.items) |item| {
        allocator.free(item);
    }
    parts.deinit(allocator);
}

fn detectDns(allocator: std.mem.Allocator) !?[]const u8 {
    var file = std.fs.openFileAbsolute("/etc/resolv.conf", .{}) catch return null;
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 16 * 1024);
    defer allocator.free(contents);

    var servers = std.ArrayList([]const u8).empty;
    defer freeParts(allocator, &servers);

    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0 or line[0] == '#') continue;

        var parts = std.mem.tokenizeAny(u8, line, " \t");
        const first = parts.next() orelse continue;
        if (!std.ascii.eqlIgnoreCase(first, "nameserver")) continue;
        const addr = parts.next() orelse continue;
        const clean = std.mem.trim(u8, addr, " \t\r");
        if (clean.len == 0) continue;
        try servers.append(allocator, try allocator.dupe(u8, clean));
    }

    if (servers.items.len == 0) return null;

    return try std.mem.join(allocator, ", ", servers.items);
}
