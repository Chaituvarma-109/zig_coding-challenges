const std = @import("std");
const mem = std.mem;
const Io = std.Io;

const Language = union(enum) {
    zig,
    python,
    c,
    cpp,
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
    comments: usize,
    blank: usize,
    code: usize,
    doc_comments: usize,
    total_lines: usize,
    total_files: usize,

    fn init() Total {
        return .{
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

    var directory: []const u8 = undefined;
    if (mem.eql(u8, args[1], ".")) {
        var pbuff: [Io.Dir.max_path_bytes]u8 = undefined;
        const n: usize = try std.process.currentPath(io, &pbuff);
        directory = pbuff[0..n];
    } else {
        directory = args[1];
    }
    const lang = args[2];

    // open directory
    const dir = try Io.Dir.cwd().openDir(io, directory, .{ .iterate = true });
    defer dir.close(io);

    var iter = try dir.walk(arena);
    defer iter.deinit();

    // iterate over directory
    while (try iter.next(io)) |entry| {
        switch (entry.kind) {
            .file => {
                if (mem.endsWith(u8, entry.basename, lang)) {
                    var pathbuff: [Io.Dir.max_path_bytes]u8 = undefined;
                    const file_path = try std.fmt.bufPrint(&pathbuff, "{s}/{s}", .{ directory, entry.path });
                    std.debug.print("path: {s}\n", .{file_path});
                    const file = Io.Dir.cwd().openFile(io, file_path, .{}) catch |err| switch (err) {
                        error.FileNotFound => {
                            std.log.err("{s} not found\n", .{file_path});
                            return;
                        },
                        else => {
                            std.log.err("err: {any}\n", .{err});
                            return;
                        },
                    };
                    defer file.close(io);
                    tot.total_files += 1;

                    var file_buffer: [1024]u8 = undefined;
                    var fr = file.reader(io, &file_buffer);
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
                }
            },
            else => {},
        }
    }

    tot.total_lines = tot.blank + tot.code + tot.comments + tot.doc_comments;

    try stdout_writer.print("total: {any}\n", .{tot});

    try stdout_writer.flush();
}
