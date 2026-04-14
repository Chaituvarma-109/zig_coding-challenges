const std = @import("std");
const mem = std.mem;
const Io = std.Io;

const Language = enum {
    zig,
    py,
    c,
    cpp,
    txt,
};

const Stats = struct {
    filename: []const u8,
    comments: usize,
    blank: usize,
    code: usize,
    doc_comments: usize,
    total_lines: usize,
};

/// this is doc comment.
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = try init.minimal.args.toSlice(arena);

    var pbuff: [Io.Dir.max_path_bytes]u8 = undefined;
    var directory: []const u8 = undefined;
    if (mem.eql(u8, args[1], ".")) {
        const n: usize = try std.process.currentPath(io, &pbuff);
        directory = pbuff[0..n];
    } else {
        directory = args[1];
    }

    var stats: std.MultiArrayList(Stats) = .empty;
    defer {
        for (stats.items(.filename)) |*fname| {
            arena.free(fname.*);
        }
        stats.deinit(arena);
    }

    // open directory
    const dir = try Io.Dir.cwd().openDir(io, directory, .{ .iterate = true });
    defer dir.close(io);

    var iter = try dir.walk(arena);
    defer iter.deinit();

    // iterate over each directory
    while (try iter.next(io)) |entry| {
        switch (entry.kind) {
            .file => {
                var pathbuff: [Io.Dir.max_path_bytes]u8 = undefined;
                const file_path = try std.fmt.bufPrint(&pathbuff, "{s}/{s}", .{ directory, entry.path });
                const owned_path = try arena.dupe(u8, file_path);

                const f = try Io.Dir.cwd().openFile(io, file_path, .{});
                defer f.close(io);

                var file_buffer: [1024]u8 = undefined;
                var fr = f.reader(io, &file_buffer);
                const r = &fr.interface;

                var code: usize = 0;
                var comments: usize = 0;
                var doc_comments: usize = 0;
                var blank: usize = 0;

                const lang = Io.Dir.path.extension(entry.basename);
                if (lang.len == 0) continue;
                const language = std.meta.stringToEnum(Language, lang[1..]) orelse continue;

                switch (language) {
                    .zig => {
                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (tln.len == 0) {
                                blank += 1;
                            } else if (mem.startsWith(u8, tln, "///")) {
                                doc_comments += 1;
                            } else if (mem.startsWith(u8, tln, "//")) {
                                comments += 1;
                            } else {
                                code += 1;
                            }
                        }
                    },
                    .py => {
                        var multiline = false;
                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (mem.startsWith(u8, tln, "\"\"\"")) {
                                const count = mem.count(u8, tln, "\"\"\"");
                                doc_comments += 1;
                                if (count % 2 == 1) multiline = !multiline;
                            } else if (multiline) {
                                doc_comments += 1;
                            } else if (tln.len == 0) {
                                blank += 1;
                            } else if (mem.startsWith(u8, tln, "#")) {
                                comments += 1;
                            } else {
                                code += 1;
                            }
                        }
                    },
                    .c, .cpp => {
                        var multiline = false;
                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (mem.startsWith(u8, tln, "/*")) {
                                doc_comments += 1;
                                if (mem.count(u8, tln, "*/") == 0) multiline = true;
                            } else if (mem.startsWith(u8, tln, "*/")) {
                                doc_comments += 1;
                                multiline = false;
                            } else if (multiline) {
                                doc_comments += 1;
                                if (mem.endsWith(u8, tln, "*/")) multiline = false;
                            } else if (tln.len == 0) {
                                blank += 1;
                            } else if (mem.startsWith(u8, tln, "//")) {
                                comments += 1;
                            } else {
                                code += 1;
                                if (mem.count(u8, tln, "/*") > 0 and mem.count(u8, tln, "*/") == 0) multiline = true;
                            }
                        }
                    },
                    .txt => {
                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (tln.len == 0) {
                                blank += 1;
                            } else {
                                code += 1;
                            }
                        }
                    },
                }

                try stats.append(arena, .{
                    .filename = owned_path,
                    .comments = comments,
                    .blank = blank,
                    .code = code,
                    .doc_comments = doc_comments,
                    .total_lines = blank + comments + doc_comments + code,
                });
            },
            else => {},
        }
    }

    for (stats.items(.filename), stats.items(.comments), stats.items(.blank), stats.items(.code), stats.items(.doc_comments)) |*fname, *comm, *blnk, *cd, *dcomm| {
        try stdout_writer.print("{s} -------- {d} {d} {d} {d}\n", .{ fname.*, comm.*, blnk.*, cd.*, dcomm.* });
    }

    try stdout_writer.flush();
}
