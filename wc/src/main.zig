const std = @import("std");

pub fn main() !void {
    var options: ?u8 = null;
    var file_name: ?[]const u8 = null;
    var file: std.fs.File = undefined;

    var args = std.process.args();

    _ = args.skip();

    while (args.next()) |arg| {
        if (arg.len > 1 and std.mem.startsWith(u8, arg, "-")) {
            options = arg[1];
        } else {
            file_name = arg;
        }
    }

    if (file_name) |f_name| {
        file = std.fs.cwd().openFile(f_name, .{}) catch |err| {
            std.debug.print("Error in opening file: {any}\n", .{err});
            return;
        };
    } else {
        file = std.fs.File.stdin();
    }
    defer file.close();

    var buff: [1024]u8 = undefined;
    var file_reader = file.reader(&buff);

    var lines: usize = 0;
    var words: usize = 0;
    var chars: usize = 0;
    var bytes: usize = 0;
    var in_word: bool = false;

    while (file_reader.interface.takeByte()) |char| {
        bytes += 1;

        if ((char <= 0x7f) or (char >= 0xc0 and char <= 0xf7)) chars += 1;

        if (char == '\n') lines += 1;

        if (std.ascii.isWhitespace(char)) {
            if (in_word) {
                words += 1;
            }
            in_word = false;
        } else {
            in_word = true;
        }
    } else |_| {}

    if (options) |opt| {
        switch (opt) {
            'c' => std.debug.print("{d} \n", .{bytes}),
            'l' => std.debug.print("{d} \n", .{lines}),
            'w' => std.debug.print("{d} \n", .{words}),
            'm' => std.debug.print("{d} \n", .{chars}),
            else => {},
        }
    } else {
        if (file_name) |f_name| {
            std.debug.print("{d} {d} {d} {s}\n", .{ lines, words, bytes, f_name });
        } else {
            std.debug.print("{d} {d} {d}\n", .{ lines, words, bytes });
        }
    }
}
