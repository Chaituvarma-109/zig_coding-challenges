const std: type = @import("std");
const process = std.process;

pub fn main(init: process.Init.Minimal) !void {
    const env: process.Environ = init.environ;
    var args: process.Args = init.args;

    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io: std.Io = io_threaded.io();

    var buff: [1024]u8 = undefined;
    var f: std.Io.File = .stdout();
    var fwr = f.writer(io, &buff);
    const wr: *std.Io.Writer = &fwr.interface;

    var arg_iter = args.iterate();
    _ = arg_iter.skip();

    const paths: [:0]const u8 = env.getPosix("PATH") orelse return error.patherror;

    while (arg_iter.next()) |command| {
        var path_iter = std.mem.tokenizeAny(u8, paths, ":");
        var path_buff: [std.os.linux.PATH_MAX]u8 = undefined;

        while (path_iter.next()) |path| {
            const full_path: []u8 = try std.fmt.bufPrint(&path_buff, "{s}/{s}", .{ path, command });

            std.Io.Dir.access(.cwd(), io, full_path, .{ .execute = true }) catch continue;
            try wr.print("{s}\n", .{full_path});
            try wr.flush();
            break;
        }
    }
}
