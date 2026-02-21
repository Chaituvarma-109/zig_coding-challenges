const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const tar = std.tar;
const iter = tar.Iterator;

pub fn main(init: std.process.Init) !void {
    const arena: mem.Allocator = init.arena.allocator();
    const io = init.io;

    var file_name: ?[]const u8 = null;
    var file: Io.File = undefined;
    var list: bool = false;
    var extract: bool = false;
    var tar_convert: bool = false;
    var inp_files: std.ArrayList([]const u8) = .empty;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (arg.len > 0 and arg[0] == '-') {
            for (arg[1..]) |value| {
                switch (value) {
                    't' => list = true,
                    'x' => extract = true,
                    'c' => tar_convert = true,
                    'f' => file_name = args.next(),
                    else => {},
                }
            }
        } else {
            try inp_files.append(arena, arg);
        }
    }

    if (tar_convert) {
        const tar_file_name: []const u8 = file_name orelse return error.MissingInputFile;

        const f = try Io.Dir.cwd().createFile(io, tar_file_name, .{});
        defer f.close(io);

        var fbuff: [4096]u8 = undefined;
        var fwr = f.writer(io, &fbuff);
        const wr = &fwr.interface;

        var twr = tar.Writer{ .underlying_writer = wr };

        for (inp_files.items) |f_name| {
            const fi = try Io.Dir.cwd().openFile(io, f_name, .{});
            defer fi.close(io);

            const stat = try fi.stat(io);

            var fi_buff: [4096]u8 = undefined;
            var fi_r = fi.reader(io, &fi_buff);

            try twr.writeFileTimestamp(f_name, &fi_r, stat.mtime);
        }

        try twr.finishPedantically();
        try wr.flush();
        return;
    }

    if (file_name) |f| {
        file = try Io.Dir.cwd().openFile(io, f, .{});
    } else {
        file = .stdin();
    }
    defer file.close(io);

    var stdin_buffer: [1024]u8 = undefined;
    var fr = file.reader(io, &stdin_buffer);
    const r = &fr.interface;

    var tarf_buff: [1024]u8 = undefined;
    var linkn_buff: [1024]u8 = undefined;

    var tar_iter = iter.init(r, .{ .file_name_buffer = &tarf_buff, .link_name_buffer = &linkn_buff });

    if (list) {
        while (try tar_iter.next()) |f| {
            try stdout_writer.print("{s}\n", .{f.name});
        }
    } else if (extract) {
        try tar.pipeToFileSystem(io, .cwd(), r, .{});
    }

    try stdout_writer.flush();
}
