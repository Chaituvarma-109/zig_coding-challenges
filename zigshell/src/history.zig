const std: type = @import("std");

const Io: type = std.Io;
const mem: type = std.mem;
const fs: type = std.fs;

var last_written_idx: usize = 0;
var hst_arr: std.ArrayList([]u8) = .empty;

pub fn get_len() !usize {
    return hst_arr.items.len;
}

pub fn get_item_at_index(idx: usize) ![]const u8 {
    return hst_arr.items[idx];
}

pub fn append_hst(alloc: mem.Allocator, cmd: []u8) !void {
    try hst_arr.append(alloc, cmd);
}

pub fn handleHistory(argv: [][]const u8, stdout: *Io.Writer) !void {
    var limit: usize = 1000;
    const hst_len: usize = hst_arr.items.len;
    if (argv.len > 1) {
        limit = @intCast(try std.fmt.parseInt(u32, argv[1], 10));
    }
    const start_idx = @max(0, hst_len - @min(limit, hst_len));

    for (hst_arr.items[start_idx..], start_idx + 0..) |value, i| {
        try stdout.print("{d:>5}  {s}\n", .{ i, value });
    }
    try stdout.flush();
}

pub fn readHistory(alloc: mem.Allocator, io: Io, hst_file_path: []const u8) !void {
    const bytes: []u8 = try Io.Dir.readFileAlloc(.cwd(), io, hst_file_path, alloc, .unlimited);
    defer alloc.free(bytes);

    var bytes_iter = mem.splitScalar(u8, bytes, '\n');

    while (bytes_iter.next()) |val| {
        if (val.len == 0) continue;
        const val_dup: []u8 = try alloc.dupe(u8, val);
        hst_arr.append(alloc, val_dup) catch {
            alloc.free(val_dup);
            continue;
        };
    }
}

pub fn writeHistory(io: Io, hst_file_path: []const u8, append: bool) !void {
    const f = try Io.Dir.createFile(.cwd(), io, hst_file_path, .{ .truncate = !append });
    defer f.close(io);

    var rbuff: [1024]u8 = undefined;
    var reader = f.reader(io, &rbuff);

    if (append) _ = &reader.seekTo(0);

    var buff: [1024]u8 = undefined;
    var wr = f.writerStreaming(io, &buff);

    const idx: usize = if (append) last_written_idx else 0;

    for (hst_arr.items[idx..]) |value| {
        try wr.interface.writeAll(value);
        try wr.interface.writeAll("\n");
    }

    try wr.interface.flush();

    last_written_idx = hst_arr.items.len;
}
