const std = @import("std");

const Config = struct {
    options: ?[]const u8 = null,
    filename: ?[]const u8 = null,

    fn init() !Config {
        var args = std.process.args();
        _ = args.skip();
        var cliargs = Config{};

        while (args.next()) |arg| {
            if (arg.len >= 2 and std.mem.startsWith(u8, arg, "-")) {
                cliargs.options = arg[1..arg.len];
            } else {
                cliargs.filename = arg;
            }
        }

        return cliargs;
    }
};

const Wc = struct {
    lines: usize = 0,
    words: usize = 0,
    chars: usize = 0,
    bytes: usize = 0,

    fn count(config: Config) !Wc {
        var wc = Wc{};
        var in_word: bool = false;
        var fd: std.posix.fd_t = std.posix.STDIN_FILENO;

        if (config.filename) |f_name| {
            fd = try std.posix.open(f_name, .{ .ACCMODE = .RDONLY }, 0);
        }
        defer if (config.filename != null) std.posix.close(fd);

        const stat = try std.posix.fstat(fd);
        const is_regular: bool = (stat.mode & std.posix.S.IFMT) == std.posix.S.IFREG;

        if (is_regular) {
            _ = std.os.linux.fadvise(fd, 0, 0, std.os.linux.POSIX_FADV.SEQUENTIAL);
        }
        var buff: [256 * 1024]u8 = undefined;

        while (true) {
            const n: usize = try std.posix.read(fd, &buff);
            if (n == 0) break;

            const data: []const u8 = buff[0..n];
            wc.bytes += data.len;

            for (data) |char| {
                if ((char <= 0x7f) or (char >= 0xc0 and char <= 0xf7)) wc.chars += 1;

                if (char == '\n') wc.lines += 1;

                if (std.ascii.isWhitespace(char)) {
                    if (in_word) in_word = false;
                } else {
                    if (!in_word) {
                        in_word = true;
                        wc.words += 1;
                    }
                }
            }
        }
        return wc;
    }
};

pub fn main() !void {
    const config: Config = try .init();

    const count: Wc = try .count(config);
    const options: ?[]const u8 = config.options;

    if (options) |opts| {
        for (opts) |opt| {
            switch (opt) {
                'c' => std.debug.print("{d} ", .{count.bytes}),
                'l' => std.debug.print("{d} ", .{count.lines}),
                'w' => std.debug.print("{d} ", .{count.words}),
                'm' => std.debug.print("{d} ", .{count.chars}),
                else => {},
            }
        }
        std.debug.print("{s}\n", .{config.filename.?});
    } else {
        if (config.filename) |f_name| {
            std.debug.print("{d} {d} {d} {s}\n", .{ count.lines, count.words, count.bytes, f_name });
        } else {
            std.debug.print("{d} {d} {d}\n", .{ count.lines, count.words, count.bytes });
        }
    }
}
