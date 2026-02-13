const std = @import("std");

const mem = std.mem;
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const wr = &stdout_file_writer.interface;

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

    if (std.mem.containsAtLeast(u8, host, 1, ",")) {
        var group: Io.Group = .init;

        try group.concurrent(io, sweepScan, .{ io, host, wr });
        try group.await(io);
    } else {
        if (port_str) |p| {
            const port = try std.fmt.parseInt(u16, p, 10);

            const address: Io.net.IpAddress = try .parse(host, port);
            var listener: Io.net.Stream = address.connect(io, .{ .mode = .stream, .protocol = .tcp, .timeout = .none }) catch |err| {
                std.log.err("err: {}\n", .{err});
                std.log.info("port: {d} is close\n", .{port});
                return;
            };
            defer listener.close(io);

            try wr.print("port: {d} is open\n", .{port});
            try wr.flush();
        } else {
            var group: Io.Group = .init;

            try group.concurrent(io, vanillaScan, .{ io, host, wr });
            try group.await(io);
        }
    }
}

fn vanillaScan(io: Io, host: []const u8, wr: *Io.Writer) !void {
    for (1..65536) |port| {
        const address = Io.net.IpAddress.parse(host, @intCast(port)) catch continue;

        // const timeout_ns: i96 = 2000 * std.time.ns_per_ms;
        // const duration: Io.Clock.Duration = .{ .clock = .cpu_thread, .raw = .{ .nanoseconds = timeout_ns } };

        // const dd = Io.Clock.Timestamp.fromNow(io, duration);
        // const t: Io.Timeout = .{ .deadline = .fromNow(io, duration) };

        var listener: Io.net.Stream = address.connect(io, .{ .mode = .stream, .protocol = .tcp, .timeout = .none }) catch continue;
        defer listener.close(io);

        wr.print("host {s} port {d} is open\n", .{ host, port }) catch |err| {
            std.log.err("{any}\n", .{err});
        };
        wr.flush() catch |err| {
            std.log.err("{any}\n", .{err});
        };
    }

    return;
}

fn sweepScan(io: Io, host: []const u8, wr: *Io.Writer) !void {
    var host_iter = std.mem.splitSequence(u8, host, ",");
    while (host_iter.next()) |h| {
        vanillaScan(io, h, wr) catch continue;
    }
    return;
}
