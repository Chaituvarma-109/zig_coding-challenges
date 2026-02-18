const std = @import("std");
const mem = std.mem;
const Io = std.Io;

const Modes = union(enum) {
    lines: usize,
    bytes: usize,
};

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var mode: Modes = .{ .lines = 10 };
    var file: Io.File = undefined;
    var file_name: std.ArrayList([]const u8) = .empty;
    defer file_name.deinit(arena);

    var args = try init.minimal.args.iterateAllocator(arena);
    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-n")) {
            const val = args.next() orelse return error.InvalidArgument;
            mode = .{ .lines = try std.fmt.parseInt(usize, val, 10) };
        } else if (mem.eql(u8, arg, "-c")) {
            const val = args.next() orelse return error.InvalidArgument;
            mode = .{ .bytes = try std.fmt.parseInt(usize, val, 10) };
        } else {
            try file_name.append(arena, arg);
        }
    }

    if (file_name.items.len == 0) {
        file = .stdin();
        defer file.close(io);
        try printText(io, file, mode, stdout_writer);
    } else if (file_name.items.len == 1) {
        file = try Io.Dir.cwd().openFile(io, file_name.items[0], .{});
        defer file.close(io);
        try printText(io, file, mode, stdout_writer);
    } else {
        for (file_name.items) |f| {
            file = try Io.Dir.cwd().openFile(io, f, .{});
            defer file.close(io);
            try stdout_writer.print("==> {s} <==\n", .{f});
            try printText(io, file, mode, stdout_writer);
        }
    }

    try stdout_writer.flush(); // Don't forget to flush!
}

fn printText(io: Io, file: Io.File, mode: Modes, wr: *Io.Writer) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var file_reader = file.reader(io, &stdin_buffer);
    const r = &file_reader.interface;

    switch (mode) {
        .lines => |n| {
            var line_count: usize = 0;
            while (line_count < n) {
                line_count += 1;
                const l = try r.takeDelimiter('\n') orelse break;
                try wr.print("{s}\n", .{l});
                try wr.flush();
            }
        },
        .bytes => |n| {
            const bytes = try r.peek(n);

            try wr.print("{s}\n", .{bytes});
            try wr.flush();
        },
    }
}
