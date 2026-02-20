const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const Mode = union(enum) {
    blank,
    non_blank,
    all,
};

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var mode: Mode = .all;
    var file: Io.File = undefined;
    var file_names: std.ArrayList([]const u8) = .empty;
    defer file_names.deinit(arena);

    var args = try init.minimal.args.iterateAllocator(arena);
    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-n")) {
            mode = .blank;
        } else if (mem.eql(u8, arg, "-b")) {
            mode = .non_blank;
        } else {
            try file_names.append(arena, arg);
        }
    }

    switch (file_names.items.len) {
        0 => {
            file = .stdin();
            defer file.close(io);
            try printText(io, stdout_writer, file, mode);
        },
        1 => {
            file = try Io.Dir.cwd().openFile(io, file_names.items[0], .{});
            defer file.close(io);
            try printText(io, stdout_writer, file, mode);
        },
        else => {
            for (file_names.items) |file_name| {
                file = try Io.Dir.cwd().openFile(io, file_name, .{});
                defer file.close(io);
                try printText(io, stdout_writer, file, mode);
            }
        },
    }
}

fn printText(io: Io, wr: *Io.Writer, file: Io.File, mode: Mode) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var file_reader = file.reader(io, &stdin_buffer);
    const r = &file_reader.interface;

    var count: usize = 0;

    while (true) {
        const l = r.peekDelimiterInclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        switch (mode) {
            .all => {
                try wr.writeAll(l);
            },
            .blank => {
                count += 1;
                try wr.print("{d} {s}", .{ count, l });
            },
            .non_blank => {
                if (l.len == 1) {
                    try wr.writeAll("\n");
                } else {
                    count += 1;
                    try wr.print("{d} {s}", .{ count, l });
                }
            },
        }
        r.toss(l.len);
        wr.flush() catch |err| switch (err) {
            error.WriteFailed => return,
        };
    }
}
