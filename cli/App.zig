const std = @import("std");
const Command = @import("cli/Command.zig").Command;

pub const App = struct {
    alloc: std.mem.Allocator,
    cmd_map: std.StringHashMap(Command),
    args: [][]const u8,

    pub fn init(alloc: std.mem.Allocator, argIter: *std.process.ArgIterator) !App {
        var args = std.ArrayList([]const u8).init(alloc);
        defer args.deinit();

        _ = argIter.skip();
        while (argIter.next()) |arg| {
            _ = try args.append(arg);
        }

        return .{
            .alloc = alloc,
            .cmd_map = std.StringHashMap(Command).init(alloc),
            .args = try args.toOwnedSlice(),
        };
    }

    pub fn deinit(self: *App) void {
        self.cmd_map.deinit();
        std.ArrayList([]const u8).fromOwnedSlice(self.alloc, self.args).deinit();
    }

    pub fn addCommand(self: *App, name: []const u8, cmd: Command) !void {
        try self.cmd_map.put(name, cmd);
    }

    pub fn run(self: *App) !void {
        var cmd = self.cmd_map.get(self.args[0]).?;
        try cmd.run(self.args[1..]);
    }
};
