const std = @import("std");

const Io = std.Io;

const READ_BUF_SIZE = 512 * 1024;
const WRITE_BUF_SIZE = 256;

const Config = struct {
    show_lines: bool = false,
    show_words: bool = false,
    show_chars: bool = false,
    show_bytes: bool = false,
    filename: ?[]const u8 = null,

    fn init(args: std.process.Args) !Config {
        var config: Config = .{};
        var arg_iter = args.iterate();
        _ = arg_iter.skip();

        var has_options: bool = false;

        while (arg_iter.next()) |arg| {
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

    fn count(r: *Io.Reader, comptime show_chars: bool) !Wc {
        const UTF8_CONTINUATION_MASK: u8 = comptime 0xc0;
        const UTF8_CONTINUATION_BYTE: u8 = comptime 0x80;
        var wc = Wc{};
        var in_word: bool = false;

        while (try r.takeDelimiter('\n')) |l| {
            wc.lines += 1;
            wc.bytes += l.len + 1;

            for (l) |char| {
                if (show_chars) {
                    if ((char & UTF8_CONTINUATION_MASK) != UTF8_CONTINUATION_BYTE) wc.chars += 1;
                }

                const ws: bool = std.ascii.isWhitespace(char);
                if (!ws and !in_word) {
                    wc.words += 1;
                    in_word = true;
                } else if (ws) {
                    in_word = false;
                }
            }
            wc.chars += 1;
            in_word = false;
        }
        return wc;
    }
};

pub fn main(init: std.process.Init.Minimal) !void {
    const args: std.process.Args = init.args;

    const config = try Config.init(args);

    var threaded_io: Io.Threaded = .init_single_threaded;
    defer threaded_io.deinit();
    const io: Io = threaded_io.io();

    var wbuff: [WRITE_BUF_SIZE]u8 = undefined;
    var fwr: Io.File.Writer = .init(.stdout(), io, &wbuff);
    const wr: *Io.Writer = &fwr.interface;

    var file_name: []const u8 = undefined;
    if (config.filename) |f| file_name = f;

    const file = try Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var buff: [READ_BUF_SIZE]u8 = undefined;
    var fr: Io.File.Reader = .init(file, io, &buff);
    const r = &fr.interface;

    const count = if (config.show_chars) try Wc.count(r, true) else try Wc.count(r, false);

    if (config.show_lines) {
        try wr.print("{d} ", .{count.lines});
    }
    if (config.show_words) {
        try wr.print("{d} ", .{count.words});
    }
    if (config.show_chars) {
        try wr.print("{d} ", .{count.chars});
    }
    if (config.show_bytes) {
        try wr.print("{d} ", .{count.bytes});
    }

    if (config.filename) |f| {
        try wr.print("{s}\n", .{f});
    } else {
        try wr.print("\n", .{});
    }

    try wr.flush();
}
