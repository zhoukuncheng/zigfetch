const std = @import("std");
const types = @import("types.zig");
const render = @import("render.zig");
const logo = @import("logo.zig");

const modules = struct {
    pub const os = @import("modules/os.zig");
    pub const kernel = @import("modules/kernel.zig");
    pub const host = @import("modules/host.zig");
    pub const user = @import("modules/user.zig");
    pub const cpu = @import("modules/cpu.zig");
    pub const memory = @import("modules/memory.zig");
    pub const uptime = @import("modules/uptime.zig");
    pub const shell = @import("modules/shell.zig");
    pub const terminal = @import("modules/terminal.zig");
    pub const network = @import("modules/network.zig");
    pub const locale = @import("modules/locale.zig");
    pub const display = @import("modules/display.zig");
    pub const gpu = @import("modules/gpu.zig");
    pub const swap = @import("modules/swap.zig");
    pub const disk = @import("modules/disk.zig");
    pub const battery = @import("modules/battery.zig");
};

const Module = struct {
    name: []const u8,
    func: *const fn (*types.Context, *std.ArrayList(types.InfoField)) anyerror!void,
};

const CliOptions = struct {
    show_logo: bool = true,
    use_color: bool = true,
    show_help: bool = false,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const options = try parseArgs(args);
    if (options.show_help) {
        try printUsage();
        return;
    }

    var ctx = types.Context{ .allocator = allocator };
    var fields = std.ArrayList(types.InfoField).empty;
    defer {
        for (fields.items) |item| {
            allocator.free(item.value);
        }
        fields.deinit(allocator);
    }

    const pipeline = [_]Module{
        .{ .name = "OS", .func = modules.os.collect },
        .{ .name = "Kernel", .func = modules.kernel.collect },
        .{ .name = "Host", .func = modules.host.collect },
        .{ .name = "User", .func = modules.user.collect },
        .{ .name = "Uptime", .func = modules.uptime.collect },
        .{ .name = "Shell", .func = modules.shell.collect },
        .{ .name = "Terminal", .func = modules.terminal.collect },
        .{ .name = "Locale", .func = modules.locale.collect },
        .{ .name = "Display", .func = modules.display.collect },
        .{ .name = "GPU", .func = modules.gpu.collect },
        .{ .name = "CPU", .func = modules.cpu.collect },
        .{ .name = "Memory", .func = modules.memory.collect },
        .{ .name = "Swap", .func = modules.swap.collect },
        .{ .name = "Disk", .func = modules.disk.collect },
        .{ .name = "Battery", .func = modules.battery.collect },
        .{ .name = "Network", .func = modules.network.collect },
    };

    for (pipeline) |m| {
        m.func(&ctx, &fields) catch |err| {
            std.log.warn("module {s} failed: {s}", .{ m.name, @errorName(err) });
        };
    }

    const use_color = options.use_color and !std.process.hasEnvVarConstant("NO_COLOR");
    const selected_logo = if (options.show_logo) logo.pick(ctx.os_id) else &[_][]const u8{};

    var stdout_file = std.fs.File.stdout();
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = stdout_file.writer(&stdout_buffer);
    try render.render(&stdout.interface, selected_logo, fields.items, use_color);
    try stdout.interface.flush();

    if (ctx.os_id) |id| {
        allocator.free(id);
    }
}

fn parseArgs(args: []const [:0]const u8) !CliOptions {
    var options = CliOptions{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--no-logo")) {
            options.show_logo = false;
        } else if (std.mem.eql(u8, arg, "--no-color")) {
            options.use_color = false;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.show_help = true;
        } else {
            std.log.warn("unknown option: {s}", .{arg});
        }
    }
    return options;
}

fn printUsage() !void {
    var stdout = std.fs.File.stdout();
    try stdout.writeAll(
        \\zigfetch - a fastfetch-style system info tool written in Zig
        \\
        \\Options:
        \\  --no-logo    Disable ASCII logo
        \\  --no-color   Disable ANSI colors
        \\  -h, --help   Show this help message
        \\
    );
}
