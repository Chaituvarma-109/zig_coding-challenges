const std = @import("std");

const mem = std.mem;
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    _ = arena;
    const io = init.io;

    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;

    var host: []const u8 = undefined;
    var port_str: ?[]const u8 = null;

    var args = init.minimal.args.iterate();
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-host")) {
            host = args.next().?;
        } else if (mem.eql(u8, arg, "-port")) {
            port_str = args.next();
        }
    }

    if (port_str) |p| {
        const port = try std.fmt.parseInt(u16, p, 10);

        const address: Io.net.IpAddress = try .parse(host, port);
        var listener: Io.net.Stream = address.connect(io, .{ .mode = .stream, .protocol = .tcp, .timeout = .none }) catch |err| {
            std.log.err("err: {}\n", .{err});
            std.log.info("port: {d} is close\n", .{port});
            return;
        };
        defer listener.close(io);

        std.log.info("port: {d} is open\n", .{port});
    } else {
        var group: Io.Group = .init;

        try group.concurrent(io, vanillaScan, .{ io, host });
        try group.await(io);

        // var f = try io.concurrent(vanillaScan, .{ io, host });
        // try f.await(io);
    }
}

fn vanillaScan(io: Io, host: []const u8) !void {
    for (1..65536) |i| {
        const port: u16 = @intCast(i);
        const address = Io.net.IpAddress.parse(host, port) catch return;

        // const timeout_ns: i128 = 2000 * std.time.ns_per_ms;
        var listener: Io.net.Stream = address.connect(io, .{ .mode = .stream, .protocol = .tcp, .timeout = .none }) catch continue;

        std.log.info("port {d} is open", .{port});
        listener.close(io);
    }
}
