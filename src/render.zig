const std = @import("std");
const types = @import("types.zig");

const reset = "\x1b[0m";
const key_color = "\x1b[1;36m";
const value_color = "\x1b[37m";

pub fn render(
    writer: *std.Io.Writer,
    logo_lines: []const []const u8,
    fields: []const types.InfoField,
    use_color: bool,
) !void {
    // Print logo block first to avoid interleaving with text output.
    for (logo_lines) |line| {
        _ = try writeLogo(writer, line, use_color);
        try writer.writeByte('\n');
    }
    if (logo_lines.len > 0 and fields.len > 0) try writer.writeByte('\n');

    var key_width: usize = 0;
    for (fields) |f| {
        if (f.key.len > key_width) key_width = f.key.len;
    }

    for (fields) |f| {
        const key_pad = if (key_width > f.key.len) key_width - f.key.len else 0;
        if (use_color) {
            try writer.print("{s}{s}{s}", .{ key_color, f.key, reset });
        } else {
            try writer.writeAll(f.key);
        }
        if (key_pad > 0) {
            var k: usize = 0;
            while (k < key_pad) : (k += 1) {
                try writer.writeByte(' ');
            }
        }
        try writer.writeAll(": ");
        if (use_color) {
            try writer.print("{s}{s}{s}\n", .{ value_color, f.value, reset });
        } else {
            try writer.print("{s}\n", .{f.value});
        }
    }
}

fn visibleWidth(line: []const u8) usize {
    var i: usize = 0;
    var width: usize = 0;
    while (i < line.len) {
        if (line[i] == 0x1b and i + 1 < line.len and line[i + 1] == '[') {
            i += 2;
            while (i < line.len and line[i] != 'm') : (i += 1) {}
            if (i < line.len) i += 1;
            continue;
        }
        width += 1;
        i += 1;
    }
    return width;
}

fn writeLogo(writer: anytype, line: []const u8, use_color: bool) !usize {
    if (use_color) {
        try writer.writeAll(line);
        return visibleWidth(line);
    }

    var i: usize = 0;
    var width: usize = 0;
    while (i < line.len) {
        if (line[i] == 0x1b and i + 1 < line.len and line[i + 1] == '[') {
            i += 2;
            while (i < line.len and line[i] != 'm') : (i += 1) {}
            if (i < line.len) i += 1;
            continue;
        }
        try writer.writeByte(line[i]);
        width += 1;
        i += 1;
    }
    return width;
}
