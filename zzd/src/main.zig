const std = @import("std");
const Writer = std.Io.Writer;

const Config = struct {
    linelen: ?usize = null,
    chunklen: usize = 2,
    endian: bool = false,
    columns: usize = 16,
    seek: usize = 0,
};

pub fn main() !void {
    const pga = std.heap.page_allocator;
    const args = try std.process.argsAlloc(pga);
    defer std.process.argsFree(pga, args);

    var i: usize = 1;
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
        }
    }

    const file = try std.fs.cwd().openFile("files.tar", .{});
    defer file.close();
    var buff: [4096]u8 = undefined;
    const n = try file.read(&buff);

    const limit: usize = @min(cliargs.linelen orelse n, n);
    const start: usize = cliargs.seek;
    const end = @max(limit, limit + cliargs.seek);

    var wbuff: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&wbuff);

    try dumpHex(&stdout.interface, buff[start..end], cliargs);
}

fn dumpHex(bw: *Writer, bytes: []const u8, args: Config) !void {
    const chunklen: usize = args.chunklen;
    const columns: usize = args.columns;

    var chunks = std.mem.window(u8, bytes, columns, columns);
    var line_offset: usize = 0;

    while (chunks.next()) |window| {
        // 1. Print the address.
        line_offset += 1;
        try bw.print("{x:0>8}  ", .{(line_offset - 1) * columns + args.seek});

        // 2. Print the bytes.
        var lit = std.mem.window(u8, window, chunklen, chunklen);
        while (lit.next()) |chunk| {
            if (args.endian) {
                var iter = std.mem.reverseIterator(chunk);
                while (iter.next()) |byte| {
                    try bw.print("{x:0>2}", .{byte});
                }
            } else {
                try bw.printHex(chunk, .lower);
            }
            try bw.writeByte(' ');
        }

        // print spaces
        for (1..(columns - window.len + 2)) |i| {
            try bw.print("{c: >2}", .{' '});
            if (i % chunklen == 0) {
                try bw.print(" ", .{});
            }
        }

        // 3. Print the characters.
        for (window) |byte| {
            if (std.ascii.isPrint(byte)) {
                try bw.writeByte(byte);
            } else {
                try bw.writeByte('.');
            }
        }
        try bw.writeByte('\n');
    }
    try bw.flush();
}
