const std = @import("std");
const Command = @import("cli/Command.zig").Command;

pub const App = struct {
    cmd_map: std.StringHashMap(Command),

    pub fn init(
        alloc: std.mem.Allocator,
    ) App {
        return .{
            .cmd_map = std.StringHashMap(Command).init(alloc),
        };
    }

    pub fn deinit(self: *App) void {
        self.cmd_map.deinit();
    }

    pub fn addCommand(self: *App, name: []const u8, cmd: Command) !void {
        try self.cmd_map.put(name, cmd);
    }

    pub fn runCommand(self: *App, name: []const u8, args: std.ArrayList([]const u8)) !void {
        var cmd = self.cmd_map.get(name).?;
        try cmd.run(args);
    }
};
