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

const Comment = struct {
    singleline_comment: []const u8,
    multiline_comment: ?[]const u8,
    doc_comments: ?[]const u8,
};

const Config = struct {
    language: Language,
    comments: Comment,
};

const Total = struct {
    filename: std.ArrayList([]const u8),
    comments: usize,
    blank: usize,
    code: usize,
    doc_comments: usize,
    total_lines: usize,
    total_files: usize,

    fn init() Total {
        return .{
            .filename = .empty,
            .comments = 0,
            .blank = 0,
            .code = 0,
            .doc_comments = 0,
            .total_lines = 0,
            .total_files = 0,
        };
    }
};

/// this is doc comment.
pub fn main(init: std.process.Init) !void {
    var tot = Total.init();
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

    // open directory
    const dir = try Io.Dir.cwd().openDir(io, directory, .{ .iterate = true });
    defer dir.close(io);

    var iter = try dir.walk(arena);
    defer iter.deinit();

    // iterate over each directory
    while (try iter.next(io)) |entry| {
        switch (entry.kind) {
            .file => {
                const lang = Io.Dir.path.extension(entry.basename);
                if (lang.len == 0) continue;
                const language = std.meta.stringToEnum(Language, lang[1..]) orelse continue;

                switch (language) {
                    .zig => {
                        const f = try getFile(arena, io, &tot, directory, entry.path);
                        defer f.close(io);

                        var file_buffer: [1024]u8 = undefined;
                        var fr = f.reader(io, &file_buffer);
                        const r = &fr.interface;

                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (tln.len == 0) {
                                tot.blank += 1;
                            } else if (mem.startsWith(u8, tln, "///")) {
                                tot.doc_comments += 1;
                            } else if (mem.startsWith(u8, tln, "//")) {
                                tot.comments += 1;
                            } else {
                                tot.code += 1;
                            }
                        }
                    },
                    .py => {
                        const f = try getFile(arena, io, &tot, directory, entry.path);
                        defer f.close(io);

                        var file_buffer: [1024]u8 = undefined;
                        var fr = f.reader(io, &file_buffer);
                        const r = &fr.interface;

                        var multiline = false;
                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (mem.startsWith(u8, tln, "\"\"\"")) {
                                const count = mem.count(u8, tln, "\"\"\"");
                                tot.doc_comments += 1;
                                if (count % 2 == 1) multiline = !multiline;
                            } else if (multiline) {
                                tot.doc_comments += 1;
                            } else if (tln.len == 0) {
                                tot.blank += 1;
                            } else if (mem.startsWith(u8, tln, "#")) {
                                tot.comments += 1;
                            } else {
                                tot.code += 1;
                            }
                        }
                    },
                    .c, .cpp => {
                        const f = try getFile(arena, io, &tot, directory, entry.path);
                        defer f.close(io);

                        var file_buffer: [1024]u8 = undefined;
                        var fr = f.reader(io, &file_buffer);
                        const r = &fr.interface;

                        var multiline = false;
                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (mem.startsWith(u8, tln, "/*")) {
                                tot.doc_comments += 1;
                                if (mem.count(u8, tln, "*/") == 0) multiline = true;
                            } else if (mem.startsWith(u8, tln, "*/")) {
                                tot.doc_comments += 1;
                                multiline = false;
                            } else if (multiline) {
                                tot.doc_comments += 1;
                                if (mem.endsWith(u8, tln, "*/")) multiline = false;
                            } else if (tln.len == 0) {
                                tot.blank += 1;
                            } else if (mem.startsWith(u8, tln, "//")) {
                                tot.comments += 1;
                            } else {
                                tot.code += 1;
                                if (mem.count(u8, tln, "/*") > 0 and mem.count(u8, tln, "*/") == 0) multiline = true;
                            }
                        }
                    },
                    .txt => {
                        const f = try getFile(arena, io, &tot, directory, entry.path);
                        defer f.close(io);

                        var file_buffer: [1024]u8 = undefined;
                        var fr = f.reader(io, &file_buffer);
                        const r = &fr.interface;

                        while (try r.takeDelimiter('\n')) |ln| {
                            const tln = mem.trimStart(u8, ln, " ");
                            if (tln.len == 0) {
                                tot.blank += 1;
                            } else {
                                tot.code += 1;
                            }
                        }
                    },
                }
            },
            else => {},
        }
    }

    tot.total_lines = tot.blank + tot.code + tot.comments + tot.doc_comments;

    for (tot.filename.items) |value| try stdout_writer.print("filename: {s}\n", .{value});
    try stdout_writer.print("total: {any}\n", .{tot});

    try stdout_writer.flush();
}

fn getFile(arena: mem.Allocator, io: Io, tot: *Total, directory: []const u8, path: []const u8) !Io.File {
    var pathbuff: [Io.Dir.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&pathbuff, "{s}/{s}", .{ directory, path });
    const owned_path = try arena.dupe(u8, file_path);

    try tot.filename.append(arena, owned_path);

    const file = try Io.Dir.cwd().openFile(io, file_path, .{});

    tot.total_files += 1;

    return file;
}
