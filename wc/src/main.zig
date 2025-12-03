const std = @import("std");

var lines: usize = 0;
var words: usize = 0;
var chars: usize = 0;
var bytes: usize = 0;
var in_word: bool = false;

pub fn main() !void {
    var options: u8 = undefined;
    var file_name: ?[]const u8 = null;

    var args = std.process.args();
    _ = args.skip();

    while (args.next()) |arg| {
        if (arg.len > 1 and std.mem.startsWith(u8, arg, "-")) {
            options = arg[1];
        } else {
            file_name = arg;
        }
    }

    var fd: std.posix.fd_t = std.posix.STDIN_FILENO;
    if (file_name) |f_name| {
        fd = std.posix.open(f_name, .{ .ACCMODE = .RDONLY }, 0) catch |err| {
            std.debug.print("Error in opening file: {any}\n", .{err});
            return;
        };
    }
    defer if (file_name != null) std.posix.close(fd);

    const stat = try std.posix.fstat(fd);
    const is_regular: bool = (stat.mode & std.posix.S.IFMT) == std.posix.S.IFREG;

    if (is_regular) _ = std.os.linux.fadvise(fd, 0, 0, std.os.linux.POSIX_FADV.SEQUENTIAL);

    var buff: [256 * 1024]u8 = undefined;

    while (true) {
        const n: usize = try std.posix.read(fd, &buff);
        if (n == 0) break;

        const data: []const u8 = buff[0..n];
        bytes += data.len;

        for (data) |char| {
            if ((char <= 0x7f) or (char >= 0xc0 and char <= 0xf7)) chars += 1;

            if (char == '\n') lines += 1;

            if (std.ascii.isWhitespace(char)) {
                if (in_word) in_word = false;
            } else {
                in_word = true;
                words += 1;
            }
        }
    }

    switch (options) {
        'c' => std.debug.print("{d} \n", .{bytes}),
        'l' => std.debug.print("{d} \n", .{lines}),
        'w' => std.debug.print("{d} \n", .{words}),
        'm' => std.debug.print("{d} \n", .{chars}),
        else => {
            if (file_name) |f_name| {
                std.debug.print("{d} {d} {d} {s}\n", .{ lines, words, bytes, f_name });
            } else {
                std.debug.print("{d} {d} {d}\n", .{ lines, words, bytes });
            }
        },
    }
}
