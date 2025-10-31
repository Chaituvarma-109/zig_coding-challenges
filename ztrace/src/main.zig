const std = @import("std");

pub fn main() !void {
    var alloc = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = alloc.deinit();
    const gpa = alloc.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    std.debug.assert(args.len >= 2);
    const external_process = args[1];

    const pid = try std.posix.fork();

    if (pid == 0) {
        // do some
    } else {}

    std.debug.print("ep: {s}\n", .{external_process});
}
