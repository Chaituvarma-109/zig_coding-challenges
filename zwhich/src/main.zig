const std = @import("std");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var args = std.process.args();
    _ = args.skip();

    const paths = std.posix.getenv("PATH") orelse return error.patherror;
    var path_iter = std.mem.tokenizeAny(u8, paths, ":");

    while (args.next()) |command| {
        while (path_iter.next()) |path| {
            const full_path = std.fs.path.join(alloc, &[_][]const u8{ path, command }) catch continue;
            defer alloc.free(full_path);

            // you can also use std.fs.cwd().access(full_path, .{}) catch continue; and std.fs.accessAbsolute(full_path, .{}) catch continue;
            std.posix.access(full_path, std.posix.X_OK) catch continue;
            std.debug.print("{s}\n", .{full_path});
            break;
        }
    }
}
