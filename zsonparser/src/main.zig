const std = @import("std");
const Io = std.Io;

const lex = @import("lexer.zig");
const parse = @import("parser.zig");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const io: Io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer: *Io.Writer = &stdout_file_writer.interface;

    var file_name: []const u8 = undefined;

    const args: []const [:0]const u8 = try init.minimal.args.toSlice(arena);
    if (args.len <= 1) {
        std.log.err("Invalid arg, maybe filename missing\n", .{});
        return;
    }
    file_name = args[1];

    var buff: [1024]u8 = undefined;
    const content: []u8 = try Io.Dir.cwd().readFile(io, file_name, &buff);

    if (content.len == 0) {
        try stdout_writer.print("empty file.\n", .{});
        try stdout_writer.flush();
        return;
    }

    var r = try lex.lexe(arena, content);
    defer r.deinit(arena);

    if (r.len == 0) {
        try stdout_writer.print("Invalid json\n", .{});
        try stdout_writer.flush();
    }

    const res: [][]const u8 = try parse.parse(arena, r, content, stdout_writer);

    for (res) |val| {
        try stdout_writer.print("{s}", .{val});
    }
    try stdout_writer.writeAll("\n");
    try stdout_writer.flush();
}
