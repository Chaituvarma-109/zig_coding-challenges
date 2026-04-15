const std = @import("std");
const dcode = @import("bencode/decode.zig");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    const alloc: std.mem.Allocator = gpa.allocator();

    const args: [][:0]u8 = try std.process.argsAlloc(alloc);
    defer alloc.free(args);

    const torrent_file: [:0]u8 = args[1];

    const f = try std.fs.openFileAbsolute(torrent_file, .{});
    defer f.close();

    var buff: [1024]u8 = undefined;
    const n: usize = try f.read(&buff);

    dcode.decode(alloc, buff[0..n]);
}
