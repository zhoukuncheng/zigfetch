const std = @import("std");

pub const InfoField = struct {
    key: []const u8,
    value: []const u8,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    os_id: ?[]const u8 = null,

    pub fn setOsId(self: *Context, id: []const u8) !void {
        if (self.os_id != null) return;
        self.os_id = try self.allocator.dupe(u8, id);
    }
};
