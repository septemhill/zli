# zli
CLI library for Ziglang

# TODO

- [ ] Add Test Cases  
- [ ] Add Examples  
- [ ] Command Help  
- [ ] Refactoring  

# Example

```zig
const std = @import("std");
const cli = @import("cli.zig");
const CommandBuilder = cli.CommandBuilder;

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            @panic("memory leak");
        }
    }

    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    var argList = std.ArrayList([]const u8).init(alloc);
    defer argList.deinit();

    const cmd_one_flags = [_]cli.Flag{
        .{
            .long = "age",
            .short = null,
            .default_value = .{ .Int = 123 },
            .description = "",
        },
        .{
            .long = "married",
            .short = null,
            .default_value = .{ .Bool = true },
            .description = "",
        },
        .{
            .long = "name",
            .short = null,
            .default_value = .{ .String = "Septem" },
            .description = "",
        },
    };

    const cmd_two_flags = [_]cli.Flag{
        .{
            .long = "height",
            .short = "h",
            .default_value = .{ .Int = 9999 },
            .description = "",
        },
        .{
            .long = "weight",
            .short = "w",
            .default_value = .{ .Int = 8888 },
            .description = "",
        },
        .{
            .long = "invest",
            .short = "i",
            .default_value = .{ .Bool = true },
            .description = "",
        },
        .{
            .long = "hasCar",
            .short = "c",
            .default_value = .{ .Bool = false },
            .description = "",
        },
    };

    var app = try cli.App.init(alloc, &args);
    defer app.deinit();

    const CommandOneFlag = CommandBuilder(&cmd_one_flags);
    var cmd = CommandOneFlag.init(alloc, &cmd_one_flags, struct {
        fn handler(c1_args: CommandOneFlag.GenStruct) anyerror!void {
            println("hello world, this is command one: {}, {}, {s}", .{
                c1_args.age,
                c1_args.married,
                c1_args.name,
            });
        }
    }.handler);
    defer cmd.deinit();

    const CommandTwoFlag = CommandBuilder(&cmd_two_flags);
    var cmd2 = CommandTwoFlag.init(alloc, &cmd_two_flags, struct {
        fn handler(c2_args: CommandTwoFlag.GenStruct) anyerror!void {
            println("hello world, this is command two: {}, {}, {}, {}", .{
                c2_args.height,
                c2_args.weight,
                c2_args.invest,
                c2_args.hasCar,
            });
        }
    }.handler);
    defer cmd2.deinit();

    try app.addCommand("sample1", cmd.command());
    try app.addCommand("sample2", cmd2.command());

    // Expected command line input: ./a.out sample2 -w 444 -i false -c 
    try app.run();
}
```