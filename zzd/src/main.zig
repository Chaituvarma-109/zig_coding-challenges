const std = @import("std");

const Io = std.Io;
const mem = std.mem;
const process = std.process;
const File = Io.File;
const Writer = Io.Writer;
const Reader = Io.Reader;

const Config = struct {
    file: []const u8 = undefined,
    linelen: ?usize = null,
    chunklen: usize = 2,
    endian: bool = false,
    columns: usize = 16,
    seek: usize = 0,
    revert: bool = false,

    fn init(args: process.Args, alloc: mem.Allocator) !Config {
        var arg_iter = try args.iterateAllocator(alloc);
        defer arg_iter.deinit();

        _ = arg_iter.skip();

        var cliargs = Config{};

        while (arg_iter.next()) |arg| {
            if (std.mem.eql(u8, arg, "-e")) {
                cliargs.endian = true;
                cliargs.chunklen = 4;
            } else if (std.mem.eql(u8, arg, "-g")) {
                cliargs.chunklen = try std.fmt.parseInt(usize, arg_iter.next() orelse return error.ChunklenArgMissing, 10);
            } else if (std.mem.eql(u8, arg, "-l")) {
                cliargs.linelen = try std.fmt.parseInt(usize, arg_iter.next() orelse return error.LinelenArgMissing, 10);
            } else if (std.mem.eql(u8, arg, "-c")) {
                cliargs.columns = try std.fmt.parseInt(usize, arg_iter.next() orelse return error.ColumnArgMissing, 10);
            } else if (std.mem.eql(u8, arg, "-s")) {
                cliargs.seek = try std.fmt.parseInt(usize, arg_iter.next() orelse return error.SeekArgMissing, 10);
            } else if (std.mem.eql(u8, arg, "-r")) {
                cliargs.revert = true;
            } else if (std.mem.eql(u8, arg, "-f")) {
                cliargs.file = arg_iter.next() orelse return error.fileArgumentMissing;
            }
        }

        return cliargs;
    }
};

pub fn main(init: process.Init.Minimal) !void {
    const pga: mem.Allocator = std.heap.page_allocator;

    const args: process.Args = init.args;
    const arg: Config = try Config.init(args, pga);

    var io_threaded: Io.Threaded = .init(pga, .{ .environ = init.environ });
    defer io_threaded.deinit();
    const io: Io = io_threaded.io();

    const f: File = try Io.Dir.openFile(.cwd(), io, arg.file, .{ .mode = .read_only });
    defer f.close(io);

    const stat: File.Stat = try f.stat(io);
    const size: u64 = stat.size;

    const rbuff: []u8 = try pga.alloc(u8, size);
    defer pga.free(rbuff);
    const buf: []u8 = try Io.Dir.readFile(.cwd(), io, arg.file, rbuff);

    var wbuff: [1024]u8 = undefined;
    var fw: File.Writer = .init(.stdout(), io, &wbuff);
    const fwr = &fw.interface;

    var buff: [1024]u8 = undefined;
    var fr: File.Reader = f.reader(io, &buff);

    if (arg.revert) {
        try revertdump(&fr.interface, &fw.interface);
    } else {
        try dumpHex(buf, arg, .{ .writer = fwr, .mode = .escape_codes });
    }
}

fn dumpHex(buff: []u8, args: Config, tty: Io.Terminal) !void {
    const bw = tty.writer;

    const chunklen: usize = args.chunklen;
    const columns: usize = args.columns;

    const limit: usize = @min(args.linelen orelse buff.len, buff.len);
    const start: usize = args.seek;
    const end: usize = @max(limit, limit + args.seek);

    var chunks = mem.window(u8, buff[start..end], columns, columns);
    var line_offset: usize = 0;

    while (chunks.next()) |window| {
        // 1. Print the address.
        try tty.setColor(.dim);
        try bw.print("{x:0>8}  ", .{line_offset * columns + args.seek});
        try tty.setColor(.reset);

        // 2. Print the bytes.
        var lit = mem.window(u8, window, chunklen, chunklen);
        while (lit.next()) |chunk| {
            if (args.endian) {
                var iter = mem.reverseIterator(chunk);
                while (iter.next()) |byte| {
                    try bw.print("{x:0>2}", .{byte});
                }
            } else {
                for (chunk) |value| {
                    if (std.ascii.isPrint(value)) {
                        try tty.setColor(.green);
                        try bw.print("{x:0>2}", .{value});
                        try tty.setColor(.reset);
                    } else {
                        try bw.print("{x:0>2}", .{value});
                    }
                }
            }
            try bw.writeByte(' ');
        }

        // print spaces
        if (window.len < columns) {
            const missing_bytes: usize = columns - window.len;
            const missing_chunks: usize = (missing_bytes + chunklen - 1) / chunklen;

            for (0..missing_bytes) |_| {
                try bw.writeByte(' ');
            }
            for (0..missing_chunks) |_| {
                try bw.writeByte(' ');
            }
        }
        try bw.writeByte(' ');

        // 3. Print the characters.
        for (window) |byte| {
            if (std.ascii.isPrint(byte)) {
                try tty.setColor(.green);
                try bw.writeByte(byte);
                try tty.setColor(.reset);
            } else {
                try bw.writeByte('.');
            }
        }
        try bw.writeByte('\n');
        line_offset += 1;
    }
    try bw.flush();
}

fn revertdump(rd: *Io.Reader, wr: *Writer) !void {
    while (true) {
        const ln: []u8 = try rd.takeDelimiter('\n') orelse return;
        // Split by the offset mark
        var parts = mem.tokenizeAny(u8, ln, ":");
        _ = parts.next(); // Remove offset
        var group = mem.tokenizeSequence(u8, parts.next() orelse continue, "  ");
        var hexes = mem.tokenizeAny(u8, group.next() orelse continue, " ");
        var out: [50]u8 = undefined;
        while (hexes.next()) |hexstr| {
            try wr.print("{s}", .{try std.fmt.hexToBytes(&out, hexstr)});
        }
    }
    try wr.flush();
}
