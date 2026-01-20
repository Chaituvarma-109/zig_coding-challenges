const std = @import("std");

const Io = std.Io;

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

    fn count(r: *Io.Reader) !Wc {
        var wc = Wc{};
        var in_word: bool = false;

        while (try r.takeDelimiter('\n')) |l| {
            wc.lines += 1;
            wc.bytes += l.len + 1;

            for (l) |char| {
                if ((char & 0xc0) != 0x80) wc.chars += 1;

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

pub fn main(init: std.process.Init) !void {
    const args: std.process.Args = init.minimal.args;

    const config = try Config.init(args);
    const io = init.io;

    var wbuff: [256]u8 = undefined;
    var fwr: Io.File.Writer = .init(.stdout(), io, &wbuff);
    const wr: *Io.Writer = &fwr.interface;

    var file_name: []const u8 = undefined;
    if (config.filename) |f| file_name = f;

    const file = try Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var buff: [512 * 1024]u8 = undefined;
    var fr: Io.File.Reader = .init(file, io, &buff);
    const r = &fr.interface;

    const count = try Wc.count(r);

    if (config.show_lines) {
        try wr.print("{d} ", .{count.lines});
        try wr.flush();
    }
    if (config.show_words) {
        try wr.print("{d} ", .{count.words});
        try wr.flush();
    }
    if (config.show_chars) {
        try wr.print("{d} ", .{count.chars});
        try wr.flush();
    }
    if (config.show_bytes) {
        try wr.print("{d} ", .{count.bytes});
        try wr.flush();
    }

    if (config.filename) |f| {
        try wr.print("{s}\n", .{f});
        try wr.flush();
    } else {
        try wr.print("\n", .{});
        try wr.flush();
    }
}
