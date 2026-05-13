const std = @import("std");
const Io = std.Io;

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
        std.log.err("Invalid arg, maybe filename missing", .{});
        return;
    }
    file_name = args[1];

    const content: []u8 = try Io.Dir.cwd().readFileAlloc(io, file_name, arena, .unlimited);

    if (content.len == 0) {
        try stdout_writer.print("empty file.\n", .{});
        try stdout_writer.flush();
        return;
    }

    parse.parse(content) catch {
        try stdout_writer.print("{s}: invalid\n", .{file_name});
        try stdout_writer.flush();
        std.process.exit(1);
    };

    try stdout_writer.print("{s} is valid json\n", .{file_name});
    try stdout_writer.flush();
}
