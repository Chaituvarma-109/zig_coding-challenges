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
    _ = std.os.linux.fadvise(fd, 0, 0, std.os.linux.POSIX_FADV.SEQUENTIAL);
    _ = std.os.linux.fadvise(fd, 0, 0, std.os.linux.POSIX_FADV.NOREUSE);
    defer if (file_name != null) std.posix.close(fd);

    const stat = try std.posix.fstat(fd);
    const is_regular: bool = (stat.mode & std.posix.S.IFMT) == std.posix.S.IFREG;

    if (is_regular) {
        const size: usize = @intCast(stat.size);
        if (size > 0) {
            const chunk_size = 128 * 1024 * 1024;
            var offset: usize = 0;

            while (offset < size) {
                const to_map: usize = @min(chunk_size, size - offset);
                const flags: std.posix.MAP = .{ .TYPE = .PRIVATE };

                const data: []u8 = try std.posix.mmap(null, to_map, std.posix.PROT.READ, flags, fd, offset);
                defer std.posix.munmap(data);

                const slice: []const u8 = data[0..to_map];
                bytes = slice.len;

                try count(slice, bytes);

                offset += to_map;
            }

            _ = std.os.linux.fadvise(fd, 0, 0, std.os.linux.POSIX_FADV.DONTNEED);
        }
    } else {
        var buff: [65536]u8 = undefined;
        while (true) {
            const n: usize = try std.posix.read(fd, &buff);
            if (n == 0) break;
            bytes += n;
            try count(&buff, n);
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

fn count(buff: []u8, n: usize) !void {
    const data: []const u8 = buff[0..n];

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
