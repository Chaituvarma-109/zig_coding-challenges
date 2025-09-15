const std = @import("std");
const Writer = std.Io.Writer;

pub fn main() !void {
    const pga = std.heap.page_allocator;
    const args = try std.process.argsAlloc(pga);
    defer std.process.argsFree(pga, args);

    var i: usize = 1;
    var chunklen: usize = 2;
    var little_endian: bool = false;

    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-g")) {
            i += 1;
            chunklen = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "-e")) {
            little_endian = true;
        }
    }

    const file = try std.fs.cwd().openFile("files.tar", .{});
    defer file.close();
    var buff: [4096]u8 = undefined;
    const n = try file.read(&buff);

    var stdout = std.fs.File.stdout().writer(&.{});

    try dumpHex(&stdout.interface, buff[0..n], chunklen, little_endian, pga);
}

fn dumpHex(bw: *Writer, bytes: []const u8, chunk_len: usize, little_endian: bool, alloc: std.mem.Allocator) !void {
    const linelen: usize = 16;
    const chunklen: usize = chunk_len;

    var chunks = std.mem.window(u8, bytes, linelen, linelen);

    while (chunks.next()) |window| {
        // 1. Print the address.
        const address = (@intFromPtr(bytes.ptr) + 0x10 * (std.math.divCeil(usize, chunks.index orelse bytes.len, 16) catch unreachable)) - 0x10;
        try bw.print("{x:0>[1]}  ", .{ address, @sizeOf(usize) * 2 });

        // 2. Print the bytes.
        var lit = std.mem.window(u8, window, chunklen, chunklen);
        while (lit.next()) |chunk| {
            const hexbyte = try std.fmt.allocPrint(alloc, "{x}", .{chunk});
            if (little_endian) {
                try bw.writeSliceEndian(u8, hexbyte, .little);
            } else {
                try bw.writeSliceEndian(u8, hexbyte, .big);
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
                switch (byte) {
                    '\n' => try bw.writeAll("␊"),
                    '\r' => try bw.writeAll("␍"),
                    '\t' => try bw.writeAll("␉"),
                    else => try bw.writeByte('.'),
                }
            }
        }
        try bw.writeByte('\n');
    }
    try bw.writeByte('\n');

    try bw.flush();
}
