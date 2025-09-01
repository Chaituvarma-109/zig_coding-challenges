const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var paths_arr: std.ArrayList([]const u8) = .empty;
    defer paths_arr.deinit(alloc);

    const paths = std.posix.getenv("PATH") orelse return error.patherror;
    var path_iter = std.mem.tokenizeAny(u8, paths, ":");
    while (path_iter.next()) |path| {
        try paths_arr.append(alloc, path);
    }

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const commands = args[1..];

    for (commands) |command| {
        for (paths_arr.items) |dir| {
            const full_path = std.fs.path.join(alloc, &[_][]const u8{ dir, command }) catch continue;
            defer alloc.free(full_path);

            // you can also use std.fs.cwd().access(full_path, .{}) catch continue; and std.fs.accessAbsolute(full_path, .{}) catch continue;
            std.posix.access(full_path, std.posix.X_OK) catch continue;
            std.debug.print("{s}\n", .{full_path});
            break;
        }
    }
}
