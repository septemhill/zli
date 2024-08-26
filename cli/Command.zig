const std = @import("std");

pub const ValueType = union(enum) {
    String: []const u8,
    Int: i32,
    Bool: bool,
    Float: f32,
};

pub const Flag = struct {
    long: [:0]const u8,
    short: ?[]const u8,
    defaultValue: ValueType,
};

const Command = struct {
    ctx: *anyopaque,
    runFn: *const fn (*anyopaque, std.ArrayList([]const u8)) anyerror!void,

    pub fn run(self: *Command, args: std.ArrayList([]const u8)) anyerror!void {
        return self.runFn(self.ctx, args);
    }
};

pub fn CommandBuilder(cmd_flags: []const Flag) type {
    return struct {
        const Self = @This();

        const Context = struct {
            alloc: std.mem.Allocator,
            vmap: std.StringHashMap([]const u8),
            cmd_flags: []const Flag,
            gen_struct: generateStruct(cmd_flags),
            handler: *const fn (generateStruct(cmd_flags)) anyerror!void,
        };

        pub const GenStruct = generateStruct(cmd_flags);

        ctx: Context,

        pub fn init(alloc: std.mem.Allocator, flags: []const Flag, handler: *const fn (generateStruct(cmd_flags)) anyerror!void) Self {
            return .{
                .ctx = .{
                    .alloc = alloc,
                    .vmap = std.StringHashMap([]const u8).init(alloc),
                    .cmd_flags = flags,
                    .handler = handler,
                    .gen_struct = generateStruct(cmd_flags){},
                },
            };
        }

        fn setValue(comptime T: type, anyval: []const u8) !?T {
            // println("parse key: {s}, type: {any}", .{ anyval, T });
            switch (@typeInfo(T)) {
                .Int => {
                    return @intCast(std.fmt.parseInt(i32, anyval, 10) catch return null);
                },
                .Float => {
                    return @floatCast(std.fmt.parseFloat(f32, anyval) catch return null);
                },
                .Bool => {
                    if (std.mem.eql(u8, "true", anyval)) {
                        return true;
                    }
                    return false;
                },
                .Pointer => |p| {
                    if (p.size == .Slice and p.child == u8) {
                        return anyval;
                    }
                    return null;
                },
                else => {
                    return null;
                },
            }
        }

        fn parseArgs(map: *std.StringHashMap([]const u8), args: std.ArrayList([]const u8), flags: []const Flag) !void {
            var key: []const u8 = "";

            for (args.items) |arg| {
                if (arg[0] == '-') {
                    if (key.len > 0) {
                        _ = try map.put(try hashKey(flags, key), "true");
                    }
                    key = arg;
                } else {
                    _ = try map.put(try hashKey(flags, key), arg);
                    key = "";
                }
            }

            if (key.len > 0) {
                _ = try map.put(try hashKey(flags, key), "true");
            }
        }

        pub fn deinit(self: *Self) void {
            self.ctx.vmap.deinit();
        }

        fn hashKey(flags: []const Flag, key: []const u8) ![]const u8 {
            const keyWithoutDash = if (key.len > 0 and key[0] == '-') if (key[1] == '-') key[2..] else key[1..] else key;

            for (flags) |item| {
                if (std.mem.eql(u8, item.long, keyWithoutDash)) {
                    return item.long;
                }

                if (item.short) |short| {
                    if (std.mem.eql(u8, short, keyWithoutDash)) {
                        return item.long;
                    }
                }
            }

            return error.NoSuchArg;
        }

        fn run(ctx: *anyopaque, args: std.ArrayList([]const u8)) !void {
            var self: *Self = @ptrCast(@alignCast(ctx));

            _ = try parseArgs(&self.ctx.vmap, args, self.ctx.cmd_flags);

            inline for (std.meta.fields(generateStruct(cmd_flags))) |field| {
                @field(self.ctx.gen_struct, field.name) = (try setValue(field.type, self.ctx.vmap.get(field.name).?)).?;
            }

            try self.ctx.handler(self.ctx.gen_struct);
        }

        pub fn command(self: *Self) Command {
            return Command{ .runFn = run, .ctx = self };
        }

        fn generateStruct(flags: []const Flag) type {
            const Custom = flag: {
                var fields: []const std.builtin.Type.StructField = &.{};

                for (flags) |flag| {
                    const field: std.builtin.Type.StructField = switch (flag.defaultValue) {
                        .String => .{
                            .name = flag.long,
                            .type = []const u8,
                            .default_value = @ptrCast(&@as([]const u8, flag.defaultValue.String)),
                            .is_comptime = false,
                            .alignment = @alignOf([]const u8),
                        },
                        .Int => .{
                            .name = flag.long,
                            .type = i32,
                            .default_value = &flag.defaultValue.Int,
                            .is_comptime = false,
                            .alignment = @alignOf(i32),
                        },
                        .Bool => .{
                            .name = flag.long,
                            .type = bool,
                            .default_value = &flag.defaultValue.Bool,
                            .is_comptime = false,
                            .alignment = @alignOf(bool),
                        },
                        .Float => .{
                            .name = flag.long,
                            .type = f32,
                            .default_value = &flag.defaultValue.Float,
                            .is_comptime = false,
                            .alignment = @alignOf(f32),
                        },
                    };
                    fields = fields ++ [_]std.builtin.Type.StructField{field};
                }
                break :flag @Type(.{ .Struct = .{
                    .layout = .auto,
                    .fields = fields,
                    .decls = &.{},
                    .is_tuple = false,
                } });
            };

            return Custom;
        }
    };
}

// test "validate parseArgs" {
//     const alloc = std.testing.allocator;

//     const Args = struct {
//         const Self = @This();

//         map: std.StringHashMap([]const u8),
//         arr: std.ArrayList([]const u8),
//         flags: []const Command.Flag,
//         params: []const []const u8,

//         fn deinit(self: *Self) void {
//             self.map.deinit();
//             self.arr.deinit();
//         }
//     };

//     var tests = [_]struct {
//         name: []const u8,
//         args: Args,
//         validFn: *const fn (*Args) anyerror!void,
//     }{
//         .{
//             .name = "case-1",
//             .args = .{
//                 .map = std.StringHashMap([]const u8).init(alloc),
//                 .arr = std.ArrayList([]const u8).init(alloc),
//                 .flags = &[_]Command.Flag{
//                     .{ .long = "age", .short = null, .defauleValue = .{ .Int = 123 } },
//                     .{ .long = "married", .short = null, .defauleValue = .{ .Bool = true } },
//                     .{ .long = "name", .short = null, .defauleValue = .{ .String = "Septem" } },
//                 },
//                 .params = &.{ "--married", "false", "--name", "sample", "--age", "993" },
//             },
//             .validFn = struct {
//                 pub fn valid(args: *Args) anyerror!void {
//                     try std.testing.expectEqualStrings("993", args.map.get("age").?);
//                     try std.testing.expectEqualStrings("false", args.map.get("married").?);
//                     try std.testing.expectEqualStrings("sample", args.map.get("name").?);
//                 }
//             }.valid,
//         },
//     };

//     for (&tests) |*tt| {
//         std.debug.print("Running test case: [{s}]\n", .{tt.name});
//         defer tt.args.deinit();

//         try tt.args.arr.appendSlice(tt.args.params);
//         try Command.parseArgs(&tt.args.map, tt.args.arr, tt.args.flags);

//         try tt.validFn(&tt.args);
//     }
// }

// test "validate hashKey" {}
