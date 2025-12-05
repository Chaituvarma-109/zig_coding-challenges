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
    fd: std.os.linux.fd_t = std.os.linux.STDIN_FILENO,

    fn count(config: Config) !Wc {
        var wc = Wc{};
        var in_word: bool = false;

        if (config.filename) |f_name| {
            const file_name: [*:0]const u8 = @ptrCast(f_name);
            wc.fd = @intCast(std.os.linux.open(file_name, .{ .ACCMODE = .RDONLY }, 0));
        }
        defer _ = std.os.linux.close(wc.fd);

        _ = std.os.linux.fadvise(wc.fd, 0, 0, std.os.linux.POSIX_FADV.SEQUENTIAL);
        var buff: [512 * 1024]u8 = undefined;

        while (true) {
            const n: usize = std.os.linux.read(wc.fd, &buff, buff.len);
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

// FIX: print at 92.
pub fn main() !void {
    const config: Config = try .init();

    const count: Wc = try .count(config);
    const options: ?[]const u8 = config.options;

    var wr = std.fs.File.Writer.initInterface(&.{});

    if (options) |opts| {
        for (opts) |opt| {
            switch (opt) {
                'c' => try wr.print("{d} ", .{count.bytes}),
                'l' => try wr.print("{d} ", .{count.lines}),
                'w' => try wr.print("{d} ", .{count.words}),
                'm' => try wr.print("{d} ", .{count.chars}),
                else => {},
            }
        }
        try wr.print("{s}\n", .{config.filename.?});
    } else {
        if (config.filename) |f_name| {
            try wr.print("{d} {d} {d} {s}\n", .{ count.lines, count.words, count.bytes, f_name });
        } else {
            try wr.print("{d} {d} {d}\n", .{ count.lines, count.words, count.bytes });
        }
    }

    try wr.flush();
}
