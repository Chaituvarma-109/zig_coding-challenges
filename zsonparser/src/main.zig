const std = @import("std");
const parser = @import("parser.zig");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io: Io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer: *Io.Writer = &stdout_file_writer.interface;

    var file_name: []const u8 = undefined;

    var args = init.minimal.args.iterate();
    _ = args.skip();

    file_name = args.next() orelse {
        std.log.err("Invalid arg, maybe filename missing", .{});
        return;
    };

    const file = try Io.Dir.openFile(.cwd(), io, file_name, .{});
    defer file.close(io);

    var buff: [1024]u8 = undefined;
    var fr = file.reader(io, &buff);
    const r = &fr.interface;

    parser.parse(r) catch {
        try stdout_writer.print("{s}: invalid\n", .{file_name});
        try stdout_writer.flush();
        std.process.exit(1);
    };

    try stdout_writer.print("{s} is valid json\n", .{file_name});
    try stdout_writer.flush();
}
