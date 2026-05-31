const std = @import("std");
const zio = @import("zio");

const mem = std.mem;
const Io = std.Io;
const net = Io.net;

const BATCH_SIZE: usize = 500;

const Scanner = struct {
    host: []const u8 = undefined,
    port: ?u16 = null,
    timeout: u64 = 500,
    wr: *Io.Writer,
};

const Task = struct {
    host: []const u8,
    port: u16,
    timeout: u64,
    wr: *Io.Writer,
};

pub fn main(init: std.process.Init) !void {
    const rt = try zio.Runtime.init(std.heap.smp_allocator, .{});
    defer rt.deinit();
    const io = rt.io();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const wr: *Io.Writer = &stdout_file_writer.interface;

    var scanner = Scanner{
        .wr = wr,
    };

    var args = init.minimal.args.iterate();
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "host")) {
            scanner.host = args.next().?;
        } else if (mem.eql(u8, arg, "port")) {
            scanner.port = try std.fmt.parseUnsigned(u16, args.next().?, 10);
        } else if (mem.eql(u8, arg, "timeout")) {
            scanner.timeout = try std.fmt.parseUnsigned(u64, args.next().?, 10);
        }
    }

    if (scanner.port) |p| {
        const task = Task{ .host = scanner.host, .port = p, .timeout = scanner.timeout, .wr = scanner.wr };
        try scan(task);
    } else {
        var group: zio.Group = .init;
        defer group.cancel();

        if (std.mem.containsAtLeast(u8, scanner.host, 1, ",")) {
            var host_iter = mem.splitSequence(u8, scanner.host, ",");
            while (host_iter.next()) |h| {
                scanner.host = h;
                try group.spawn(vanillaScan, .{scanner});
            }
        } else if (std.mem.containsAtLeast(u8, scanner.host, 1, "*")) {
            try group.spawn(sweepScan, .{scanner.host});
        } else {
            try group.spawn(vanillaScan, .{scanner});
        }

        try group.wait();
    }
}

// TODO
fn parseHost(alloc: std.mem.Allocator, host: []const u8) !void {
    _ = alloc;
    _ = host;
}

fn vanillaScan(scanner: Scanner) !void {
    var port: u16 = 1;
    while (true) {
        const batch_end: u16 = @intCast(@min(@as(usize, port) + BATCH_SIZE, 65535));

        var batch: zio.Group = .init;
        defer batch.cancel();

        var p = port;
        while (p < batch_end) : (p += 1) {
            const task = Task{ .host = scanner.host, .port = p, .timeout = scanner.timeout, .wr = scanner.wr };
            try batch.spawn(scan, .{task});
            if (p == 65535) break;
        }

        try batch.wait();

        if (batch_end == 65535) break;
        port = batch_end + 1;
    }

    return;
}

fn scan(task: Task) !void {
    const address = zio.net.IpAddress.parseIp(task.host, task.port) catch return;
    var listener = address.connect(.{ .timeout = if (task.timeout == 0) .none else .{ .duration = .fromMilliseconds(task.timeout) } }) catch return;
    defer listener.close();

    task.wr.print("host {s} port {d} is open\n", .{ task.host, task.port }) catch |err| {
        std.log.err("{any}\n", .{err});
    };
    task.wr.flush() catch |err| {
        std.log.err("{any}\n", .{err});
    };

    return;
}

// TODO
fn sweepScan(host: []const u8) !void {
    const idx = mem.find(u8, host, "*") orelse return;
    const first = host[0..idx];
    const star = host[idx..];
    std.debug.print("first: {s}, star: {s}\n", .{ first, star });
}
