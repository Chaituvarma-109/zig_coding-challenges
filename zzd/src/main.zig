const std = @import("std");
const File = std.fs.File;
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;

const Config = struct {
    file: []const u8 = undefined,
    linelen: ?usize = null,
    chunklen: usize = 2,
    endian: bool = false,
    columns: usize = 16,
    seek: usize = 0,
    revert: bool = false,

    fn init(args: [][:0]u8) !Config {
        var i: usize = 0;

        var cliargs = Config{};

        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-e")) {
                cliargs.endian = true;
                cliargs.chunklen = 4;
            } else if (std.mem.eql(u8, arg, "-g")) {
                i += 1;
                cliargs.chunklen = try std.fmt.parseInt(usize, args[i], 10);
            } else if (std.mem.eql(u8, arg, "-l")) {
                i += 1;
                cliargs.linelen = try std.fmt.parseInt(usize, args[i], 10);
            } else if (std.mem.eql(u8, arg, "-c")) {
                i += 1;
                cliargs.columns = try std.fmt.parseInt(usize, args[i], 10);
            } else if (std.mem.eql(u8, arg, "-s")) {
                i += 1;
                cliargs.seek = try std.fmt.parseInt(usize, args[i], 10);
            } else if (std.mem.eql(u8, arg, "-r")) {
                cliargs.revert = true;
            } else if (std.mem.eql(u8, arg, "-f")) {
                i += 1;
                cliargs.file = args[i];
            }
        }

        return cliargs;
    }
};

pub fn main() !void {
    const pga: std.mem.Allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(pga);
    defer std.process.argsFree(pga, args);

    const arg: Config = try Config.init(args);

    const file: File = try std.fs.cwd().openFile(arg.file, .{});
    defer file.close();

    const s: File.Stat = try file.stat();
    const file_size: u64 = s.size;

    var wbuff: [500]u8 = undefined;
    var stdout: File = std.fs.File.stdout();
    defer stdout.close();
    var fw: File.Writer = stdout.writer(&wbuff);

    var buff: []u8 = try pga.alloc(u8, file_size);
    defer pga.free(buff);
    var fr: File.Reader = file.reader(buff);
    const n: usize = try fr.read(buff);

    if (arg.revert) {
        try revertdump(&fw.interface, buff[0..n]);
    } else {
        const limit: usize = @min(arg.linelen orelse n, n);
        const start: usize = arg.seek;
        const end: usize = @max(limit, limit + arg.seek);

        try dumpHex(&fw.interface, buff[start..end], arg, .escape_codes);
    }
}

fn dumpHex(bw: *Writer, bytes: []const u8, args: Config, cfg: std.Io.tty.Config) !void {
    const chunklen: usize = args.chunklen;
    const columns: usize = args.columns;

    var chunks = std.mem.window(u8, bytes, columns, columns);
    var line_offset: usize = 0;

    while (chunks.next()) |window| {
        // 1. Print the address.
        try cfg.setColor(bw, .dim);
        try bw.print("{x:0>8}  ", .{line_offset * columns + args.seek});
        try cfg.setColor(bw, .reset);

        // 2. Print the bytes.
        var lit = std.mem.window(u8, window, chunklen, chunklen);
        while (lit.next()) |chunk| {
            try cfg.setColor(bw, .green);
            if (args.endian) {
                var iter = std.mem.reverseIterator(chunk);
                while (iter.next()) |byte| {
                    try bw.print("{x:0>2}", .{byte});
                }
            } else {
                try bw.printHex(chunk, .lower);
            }
            try cfg.setColor(bw, .reset);
            try bw.writeByte(' ');
        }

        // print spaces
        if (window.len < columns) {
            const missing_bytes: usize = columns - window.len;
            const missing_chunks: usize = (missing_bytes + chunklen - 1) / chunklen;

            for (0..missing_bytes) |_| {
                try bw.print("  ", .{});
            }
            for (0..missing_chunks) |_| {
                try bw.writeByte(' ');
            }
        }
        try bw.writeByte(' ');

        // 3. Print the characters.
        for (window) |byte| {
            if (std.ascii.isPrint(byte)) {
                try cfg.setColor(bw, .green);
                try bw.writeByte(byte);
                try cfg.setColor(bw, .reset);
            } else {
                try bw.writeByte('.');
            }
        }
        try bw.writeByte('\n');
        line_offset += 1;
    }
    try bw.flush();
}

fn revertdump(wr: *Writer, hex_data: []const u8) !void {
    var lines = std.mem.tokenizeAny(u8, hex_data, "\n");
    while (lines.next()) |line| {
        // Split by the offset mark
        var parts = std.mem.tokenizeAny(u8, line, ":");
        _ = parts.next(); // Remove offset
        var group = std.mem.tokenizeSequence(u8, parts.next() orelse continue, "  ");
        var hexes = std.mem.tokenizeAny(u8, group.next() orelse continue, " ");
        var out: [50]u8 = undefined;
        while (hexes.next()) |hexstr| {
            try wr.print("{s}", .{try std.fmt.hexToBytes(&out, hexstr)});
        }
    }
    try wr.flush();
}
