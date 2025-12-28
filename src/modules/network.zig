const std = @import("std");
const types = @import("../types.zig");

const builtin = @import("builtin");

pub fn collect(ctx: *types.Context, list: *std.ArrayList(types.InfoField)) !void {
    const lan_ip = if (builtin.os.tag == .windows)
        detectLanIpWindows(ctx.allocator) catch null
    else
        detectLanIp(ctx.allocator) catch null;

    const wan_ip = detectWanIp(ctx.allocator) catch null;
    const proxy_status = try formatProxyStatus(ctx.allocator);

    const dns = if (builtin.os.tag == .windows)
        detectDnsWindows(ctx.allocator) catch null
    else
        detectDns(ctx.allocator) catch null;

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

fn detectLanIpWindows(allocator: std.mem.Allocator) !?[]const u8 {
    // Quick and dirty: use ipconfig
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{"ipconfig"},
        .max_output_bytes = 64 * 1024,
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Look for "IPv4 Address" or "IPv4"
    var lines = std.mem.tokenizeScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "IPv4")) |idx| {
            if (std.mem.indexOfScalar(u8, line[idx..], ':')) |colon_rel| {
                const colon_abs = idx + colon_rel;
                if (colon_abs + 1 < line.len) {
                    const ip_part = std.mem.trim(u8, line[colon_abs + 1 ..], " \t\r");
                    // check if looks like IP (naive)
                    if (std.mem.indexOfScalar(u8, ip_part, '.')) |_| {
                        return try allocator.dupe(u8, ip_part);
                    }
                }
            }
        }
    }
    return null;
}

fn detectWanIp(allocator: std.mem.Allocator) !?[]const u8 {
    var curlCommand: []const u8 = "curl";
    if (builtin.os.tag == .windows) curlCommand = "curl.exe";
    const primary = &[_][]const u8{ curlCommand, "-fsSL", "--max-time", "5", "https://checkip.amazonaws.com" };
    if (try readCommandFirstLine(allocator, primary)) |ip| return ip;

    const fallback = &[_][]const u8{ curlCommand, "-fsSL", "--max-time", "5", "https://ifconfig.me" };
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
    // Basic validation
    if (std.mem.indexOfScalar(u8, trimmed, '.') == null) return null;

    // Check if it looks like an IP
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
    var parts = std.ArrayList([]const u8).empty;
    defer freeParts(allocator, &parts);

    // 1. Check Environment Variables (All platforms)
    const proxy_keys = [_][]const u8{
        "http_proxy", "https_proxy", "all_proxy",
        "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY",
    };
    for (proxy_keys) |key| {
        const value = std.process.getEnvVarOwned(allocator, key) catch continue;
        defer allocator.free(value);
        if (value.len > 0) {
            const line = try std.fmt.allocPrint(allocator, "{s}={s}", .{ key, value });
            try parts.append(allocator, line);
        }
    }

    // 2. Windows-Specific Registry Check
    if (builtin.os.tag == .windows) {
        if (getWindowsProxy(allocator)) |reg_proxy| {
            if (reg_proxy.len > 0) {
                // Determine if it looks enabled (registry usually has ProxyEnable=1, but we just fetched the server string)
                // Ideally we check ProxyEnable too, but getting the server string is a strong signal.
                const line = try std.fmt.allocPrint(allocator, "WinInet={s}", .{reg_proxy});
                try parts.append(allocator, line);
            }
            allocator.free(reg_proxy);
        } else |_| {}
    }

    // 3. Linux GNOME/GSettings Check (Optional, minimal effort)
    if (builtin.os.tag == .linux) {
        if (getGnomeProxy(allocator)) |gnome_proxy| {
            if (gnome_proxy.len > 0 and !std.mem.eql(u8, gnome_proxy, "none") and !std.mem.eql(u8, gnome_proxy, "''")) {
                const line = try std.fmt.allocPrint(allocator, "GNOME={s}", .{gnome_proxy});
                try parts.append(allocator, line);
            }
            allocator.free(gnome_proxy);
        } else |_| {}
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

fn getWindowsProxy(allocator: std.mem.Allocator) ![]const u8 {
    // Check HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings -> ProxyServer
    // Also ProxyEnable
    // var hKey: std.os.windows.HKEY = undefined;
    const subkey = "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
    // We need to use internal RegOpen similar to other modules, but those functions are private inside respective modules unless exported or redefined.
    // For simplicity, we can use `reg query` via CLI to avoid adding complex registry bindings here if not already present.
    // Let's use `reg query` for simplicity as we already rely on subprocesses elsewhere.

    // Check ProxyEnable
    const enable_res = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "reg", "query", "HKCU\\" ++ subkey, "/v", "ProxyEnable" },
        .max_output_bytes = 4096,
    });
    defer allocator.free(enable_res.stdout);
    defer allocator.free(enable_res.stderr);

    if (std.mem.indexOf(u8, enable_res.stdout, "0x1") == null) {
        return error.Disabled; // Proxy not enabled or command failed
    }

    // Check ProxyServer
    const server_res = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "reg", "query", "HKCU\\" ++ subkey, "/v", "ProxyServer" },
        .max_output_bytes = 4096,
    });
    defer allocator.free(server_res.stdout);
    defer allocator.free(server_res.stderr);

    var lines = std.mem.tokenizeScalar(u8, server_res.stdout, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "ProxyServer")) |_| {
            // Usually format: ... ProxyServer REG_SZ 127.0.0.1:7890
            var parts = std.mem.tokenizeAny(u8, line, " \t");
            _ = parts.next(); // HKEY... or index
            // Skip until we find REG_SZ
            while (parts.next()) |p| {
                if (std.mem.eql(u8, p, "REG_SZ")) {
                    if (parts.next()) |val| {
                        return try allocator.dupe(u8, val);
                    }
                }
            }
        }
    }
    return error.NotFound;
}

fn getGnomeProxy(allocator: std.mem.Allocator) ![]const u8 {
    // Try getting http proxy host
    const res = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "gsettings", "get", "org.gnome.system.proxy.http", "host" },
        .max_output_bytes = 1024,
    }) catch return error.Failed;
    defer allocator.free(res.stdout);
    defer allocator.free(res.stderr);

    const host = std.mem.trim(u8, res.stdout, " \t\r\n'");
    if (host.len == 0) return error.NotFound;

    const port_res = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "gsettings", "get", "org.gnome.system.proxy.http", "port" },
        .max_output_bytes = 1024,
    }) catch return error.Failed;
    defer allocator.free(port_res.stdout);
    defer allocator.free(port_res.stderr);

    const port = std.mem.trim(u8, port_res.stdout, " \t\r\n");
    return try std.fmt.allocPrint(allocator, "{s}:{s}", .{ host, port });
}

fn hasTunnelInterface() !bool {
    if (builtin.os.tag == .windows) return false; // TODO: Implement for Windows
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

fn detectDnsWindows(allocator: std.mem.Allocator) !?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "ipconfig", "/all" },
        .max_output_bytes = 64 * 1024,
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    var servers = std.ArrayList([]const u8).empty;
    defer freeParts(allocator, &servers);

    var lines = std.mem.tokenizeScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "DNS Servers")) |idx| {
            if (std.mem.indexOfScalar(u8, line[idx..], ':')) |colon_rel| {
                const colon_abs = idx + colon_rel;
                if (colon_abs + 1 < line.len) {
                    const dns = std.mem.trim(u8, line[colon_abs + 1 ..], " \t\r");
                    if (dns.len > 0) {
                        try servers.append(allocator, try allocator.dupe(u8, dns));
                        // ipconfig sometimes lists multiple DNS on subsequent lines
                        while (lines.peek()) |next_line| {
                            if (std.mem.indexOfScalar(u8, next_line, ':') != null) break; // New key
                            const next_val = std.mem.trim(u8, next_line, " \t\r");
                            if (next_val.len > 0) {
                                // Naive check if it looks like IP
                                if (std.mem.indexOfScalar(u8, next_val, '.') != null or std.mem.indexOfScalar(u8, next_val, ':') != null) {
                                    try servers.append(allocator, try allocator.dupe(u8, next_val));
                                    _ = lines.next();
                                } else {
                                    break;
                                }
                            } else {
                                _ = lines.next();
                            }
                        }
                    }
                }
            }
        }
    }

    if (servers.items.len == 0) return null;
    return try std.mem.join(allocator, ", ", servers.items);
}
