const std = @import("std");
const zio = @import("zio");

const mem = std.mem;
const Io = std.Io;
const ArrayList = std.ArrayList;

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
    const alloc = std.heap.smp_allocator;
    const rt = try zio.Runtime.init(alloc, .{});
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

    const hosts = try parseHost(alloc, scanner.host);
    defer {
        for (hosts) |host| alloc.free(host);
        alloc.free(hosts);
    }

    const is_wildcard = mem.containsAtLeast(u8, scanner.host, 1, "*");

    if (scanner.port) |p| {
        // Port given: probe that exact port on every expanded host.
        if (hosts.len == 1) {
            // Single host, single port — direct scan, no concurrency needed.
            const task = Task{ .host = hosts[0], .port = p, .timeout = scanner.timeout, .wr = scanner.wr };
            try scan(task);
        } else {
            // Multiple hosts (comma-list or wildcard) + explicit port.
            var group: zio.Group = .init;
            defer group.cancel();
            for (hosts) |host| {
                const task = Task{ .host = host, .port = p, .timeout = scanner.timeout, .wr = scanner.wr };
                try group.spawn(scan, .{task});
            }
            try group.wait();
        }
    } else if (is_wildcard) {
        // Wildcard, no port → sweep scan (common ports) across all expanded hosts.
        var i: usize = 0;
        while (i < hosts.len) {
            const batch_end = @min(i + BATCH_SIZE, hosts.len);

            var group: zio.Group = .init;
            defer group.cancel();

            for (hosts[i..batch_end]) |host| {
                scanner.host = host;
                try group.spawn(sweepScan, .{scanner});
            }
            try group.wait();
            i = batch_end;
        }
    } else {
        // No wildcard, no port → full vanilla scan on every host.
        var group: zio.Group = .init;
        defer group.cancel();
        for (hosts) |host| {
            scanner.host = host;
            try group.spawn(vanillaScan, .{scanner});
        }
        try group.wait();
    }
}

fn parseHost(alloc: std.mem.Allocator, host: []const u8) ![][]const u8 {
    var host_lst: ArrayList([]const u8) = .empty;
    errdefer {
        for (host_lst.items) |value| alloc.free(value);
        host_lst.deinit(alloc);
    }

    if (mem.containsAtLeast(u8, host, 1, "*")) {
        if (mem.startsWith(u8, host, "*")) {
            const last = host[2..];
            for (0..255) |value| {
                const res = try std.fmt.allocPrint(alloc, "{d}.{s}", .{ value, last });
                defer alloc.free(res);
                const res_dupe = try alloc.dupe(u8, res);
                try host_lst.append(alloc, res_dupe);
            }
        } else if (mem.endsWith(u8, host, "*")) {
            const first = host[0 .. host.len - 2];
            for (0..255) |value| {
                const res = try std.fmt.allocPrint(alloc, "{s}.{d}", .{ first, value });
                defer alloc.free(res);
                const res_dupe = try alloc.dupe(u8, res);
                try host_lst.append(alloc, res_dupe);
            }
        } else {
            const idx = mem.find(u8, host, "*") orelse return error.InvalidIpAddress;
            const first = host[0 .. idx - 1];
            const last = host[idx + 2 ..];
            for (0..255) |value| {
                const res = try std.fmt.allocPrint(alloc, "{s}.{d}.{s}", .{ first, value, last });
                defer alloc.free(res);
                const res_dupe = try alloc.dupe(u8, res);
                try host_lst.append(alloc, res_dupe);
            }
        }
    } else if (mem.containsAtLeast(u8, host, 1, ",")) {
        var iter = mem.splitSequence(u8, host, ",");
        while (iter.next()) |h| {
            const host_dupe = try alloc.dupe(u8, h);
            try host_lst.append(alloc, host_dupe);
        }
    } else {
        const host_dupe = try alloc.dupe(u8, host);
        try host_lst.append(alloc, host_dupe);
    }

    return host_lst.toOwnedSlice(alloc);
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
    const timeout: zio.Timeout = if (task.timeout == 0) .none else .{ .duration = .fromMilliseconds(task.timeout) };
    var listener = address.connect(.{ .timeout = timeout }) catch return;
    defer listener.close();

    task.wr.print("host {s} port {d} is open\n", .{ task.host, task.port }) catch |err| {
        std.log.err("{any}\n", .{err});
    };
    task.wr.flush() catch |err| {
        std.log.err("{any}\n", .{err});
    };

    return;
}

const SWEEP_PORTS = [_]u16{
    21,  22,  23,  25,  53,   80,   110,  135,  139,  143,
    443, 445, 993, 995, 1723, 3306, 3389, 5900, 8080, 8443,
};

fn sweepScan(scanner: Scanner) !void {
    const ports: []const u16 = if (scanner.port) |p|
        &[_]u16{p}
    else
        &SWEEP_PORTS;

    var i: usize = 0;
    while (i < ports.len) {
        const batch_end = @min(i + BATCH_SIZE, ports.len);

        var batch: zio.Group = .init;
        defer batch.cancel();

        for (ports[i..batch_end]) |port| {
            const task = Task{
                .host = scanner.host,
                .port = port,
                .timeout = scanner.timeout,
                .wr = scanner.wr,
            };
            try batch.spawn(scan, .{task});
        }

        try batch.wait();
        i = batch_end;
    }
}
