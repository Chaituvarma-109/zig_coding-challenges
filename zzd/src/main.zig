const std = @import("std");
const Writer = std.Io.Writer;

const Config = struct {
    linelen: usize = 16,
    chunklen: usize = 4,
    endian: bool = false,
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
        } else if (std.mem.eql(u8, arg, "-g")) {
            i += 1;
            cliargs.chunklen = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "-l")) {
            i += 1;
            cliargs.linelen = try std.fmt.parseInt(usize, args[i], 10);
        }
    }

    const file = try std.fs.cwd().openFile("files.tar", .{});
    defer file.close();
    var buff: [4096]u8 = undefined;
    const n = try file.read(&buff);

    var stdout = std.fs.File.stdout().writer(&.{});

    try dumpHex(pga, &stdout.interface, buff[0..n], cliargs);
}

fn dumpHex(alloc: std.mem.Allocator, bw: *Writer, bytes: []const u8, args: Config) !void {
    const linelen: usize = args.linelen;
    const chunklen: usize = args.chunklen;

    var chunks = std.mem.window(u8, bytes, linelen, linelen);
    var line_offset: usize = 0;

    while (chunks.next()) |window| {
        // 1. Print the address.
        try bw.print("{x:0>8}  ", .{line_offset});

        // 2. Print the bytes.
        var lit = std.mem.window(u8, window, chunklen, chunklen);
        while (lit.next()) |chunk| {
            if (args.endian) {
                const grp = try std.mem.Allocator.dupe(alloc, u8, chunk);
                defer alloc.free(grp);
                std.mem.reverse(u8, grp);
                try bw.printHex(grp, .lower);
            } else {
                try bw.printHex(chunk, .lower);
            }
            try bw.writeByte(' ');
        }
        try bw.writeByte(' ');
        // Fix: missing columns

        // 3. Print the characters.
        for (window) |byte| {
            if (std.ascii.isPrint(byte)) {
                try bw.writeByte(byte);
            } else {
                try bw.writeByte('.');
            }
        }
        try bw.writeByte('\n');

        line_offset += window.len;
    }
    try bw.writeByte('\n');

    try bw.flush();
}
