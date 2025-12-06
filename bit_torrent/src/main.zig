const std = @import("std");
const dcode = @import("bencode/decode.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = try std.process.argsAlloc(alloc);
    defer alloc.free(args);

    const torrent_file = args[1];

    const f = try std.fs.openFileAbsolute(torrent_file, .{});
    defer f.close();

    const data = try f.readToEndAlloc(alloc, std.fs.max_path_bytes);

    dcode.decode(alloc, data);
}
