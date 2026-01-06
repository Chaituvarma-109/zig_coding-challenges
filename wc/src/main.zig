const std = @import("std");

const Io = std.Io;

const Config = struct {
    show_lines: bool = false,
    show_words: bool = false,
    show_chars: bool = false,
    show_bytes: bool = false,
    filename: ?[]const u8 = null,

    fn init() !Config {
        var config: Config = .{};
        var args = std.process.args();
        _ = args.skip();

        var has_options: bool = false;

        while (args.next()) |arg| {
            if (arg.len >= 2 and arg[0] == '-') {
                has_options = true;
                for (arg[1..]) |opt| {
                    switch (opt) {
                        'l' => config.show_lines = true,
                        'w' => config.show_words = true,
                        'c' => config.show_bytes = true,
                        'm' => config.show_chars = true,
                        else => {},
                    }
                }
            } else {
                config.filename = arg;
            }
        }

        // If no options specified, default to -lwc
        if (!has_options) {
            config.show_lines = true;
            config.show_words = true;
            config.show_bytes = true;
        }

        return config;
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
                if ((char & 0xc0) != 0x80) wc.chars += 1;

                if (char == '\n') wc.lines += 1;

                const ws: bool = std.ascii.isWhitespace(char);
                if (!ws and !in_word) {
                    wc.words += 1;
                    in_word = true;
                } else if (ws) {
                    in_word = false;
                }
            }
        }
        return wc;
    }
};

pub fn main() !void {
    const config = try Config.init();
    const count = try Wc.count(config);

    var io_threaded: Io.Threaded = .init_single_threaded;
    const io: Io = io_threaded.ioBasic();

    var wbuff: [256]u8 = undefined;
    const file = Io.File.stdout();
    var fwr = file.writer(io, &wbuff);
    const wr: *Io.Writer = &fwr.interface;

    if (config.show_lines) try wr.print("{d} ", .{count.lines});
    if (config.show_words) try wr.print("{d} ", .{count.words});
    if (config.show_chars) try wr.print("{d} ", .{count.chars});
    if (config.show_bytes) try wr.print("{d} ", .{count.bytes});

    if (config.filename) |f| {
        try wr.print("{s}\n", .{f});
    } else {
        try wr.print("\n", .{});
    }
    try wr.flush();
}
