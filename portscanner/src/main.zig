const std = @import("std");
const zio = @import("zio");

const mem = std.mem;
const linux = std.os.linux;
const Io = std.Io;
const ArrayList = std.ArrayList;

const BATCH_SIZE: usize = 500;
const TCP_SYN: u8 = 0x02;
const TCP_RST: u8 = 0x04;
const TCP_ACK: u8 = 0x10;

const IpHeader = extern struct {
    ver_ihl: u8,
    tos: u8,
    tot_len: u16,
    id: u16,
    frag_off: u16,
    ttl: u8,
    protocol: u8,
    check: u16,
    saddr: u32,
    daddr: u32,
};

const TcpHeader = extern struct {
    source: u16,
    dest: u16,
    seq: u32,
    ack_seq: u32,
    data_off_res: u8,
    flags: u8,
    window: u16,
    check: u16,
    urg_ptr: u16,
};

const Config = struct {
    host: []const u8 = undefined,
    port: ?u16 = null,
    timeout: u64 = 500,
    sync: bool = false,
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

    var scanner = Config{
        .wr = wr,
    };

    var args = try init.minimal.args.iterateAllocator(alloc);
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "host")) {
            scanner.host = args.next().?;
        } else if (mem.eql(u8, arg, "port")) {
            scanner.port = try std.fmt.parseUnsigned(u16, args.next().?, 10);
        } else if (mem.eql(u8, arg, "timeout")) {
            scanner.timeout = try std.fmt.parseUnsigned(u64, args.next().?, 10);
        } else if (mem.eql(u8, arg, "sync")) {
            scanner.sync = true;
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

fn vanillaScan(scanner: Config) !void {
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
}

const SWEEP_PORTS = [_]u16{
    21,  22,  23,  25,  53,   80,   110,  135,  139,  143,
    443, 445, 993, 995, 1723, 3306, 3389, 5900, 8080, 8443,
};

fn sweepScan(scanner: Config) !void {
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

fn resolveIpv4(host: []const u8) !u32 {
    if (zio.net.IpAddress.parseIp4(host, 0)) |addr| {
        return mem.bigToNative(u32, addr.ip4.addr);
    } else |_| {}

    const hostname = try zio.net.HostName.init(host);
    var results: [32]zio.net.HostName.LookupResult = undefined;
    const count = try hostname.lookup(&results, .{ .port = 0 });
    for (results[0..count]) |result| {
        switch (result) {
            .address => |ip_addr| switch (ip_addr) {
                .ip4 => |a| return mem.bigToNative(u32, a.addr),
                else => continue,
            },
            else => continue,
        }
    }
    return error.NoIpv4Address;
}

fn localIpv4(dst_ip: u32) !u32 {
    const rc_sock = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, linux.IPPROTO.IP);
    if (rc_sock > std.math.maxInt(i32)) return error.SocketFailed;

    const sock: linux.fd_t = @intCast(rc_sock);
    defer _ = linux.close(sock);

    var dst_addr = linux.sockaddr.in{
        .family = linux.AF.INET,
        .port = mem.nativeToBig(u16, 53),
        .addr = mem.nativeToBig(u32, dst_ip),
        .zero = [_]u8{0} ** 8,
    };
    const rc_conn = linux.connect(sock, @ptrCast(&dst_addr), @sizeOf(linux.sockaddr.in));
    if (rc_conn != 0) return error.ConnectFailed;

    var local_addr = linux.sockaddr.in{
        .family = linux.AF.INET,
        .port = 0,
        .addr = 0,
        .zero = [_]u8{0} ** 8,
    };
    var addr_len: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    const rc_gsn = linux.getsockname(sock, @ptrCast(&local_addr), &addr_len);
    if (rc_gsn != 0) return error.GetsocknameFailed;

    return mem.bigToNative(u32, local_addr.addr);
}

fn tcpChecksum(src_ip: u32, dst_ip: u32, tcp_hdr: *const TcpHeader, payload: []const u8) u16 {
    const tcp_len: u16 = @intCast(@sizeOf(TcpHeader) + payload.len);

    // pseudo header
    var buf: [12 + @sizeOf(TcpHeader)]u8 = undefined;
    buf[0] = @truncate(src_ip >> 24);
    buf[1] = @truncate(src_ip >> 16);
    buf[2] = @truncate(src_ip >> 8);
    buf[3] = @truncate(src_ip);
    buf[4] = @truncate(dst_ip >> 24);
    buf[5] = @truncate(dst_ip >> 16);
    buf[6] = @truncate(dst_ip >> 8);
    buf[7] = @truncate(dst_ip);
    buf[8] = 0;
    buf[9] = std.os.linux.IPPROTO.TCP;
    buf[10] = @truncate(tcp_len >> 8);
    buf[11] = @truncate(tcp_len);
    @memcpy(buf[12..], mem.asBytes(tcp_hdr));

    var sum: u32 = 0;
    var i: usize = 0;
    while (i + 1 < buf.len) : (i += 2) {
        sum += @as(u32, buf[i]) << 8 | @as(u32, buf[i + 1]);
    }
    i = 0;
    while (i + 1 < payload.len) : (i += 2) {
        sum += @as(u32, payload[i]) << 8 | @as(u32, payload[i + 1]);
    }
    if (i < payload.len) sum += @as(u32, payload[i]) << 8;
    while (sum >> 16 != 0) sum = (sum & 0xFFFF) + (sum >> 16);
    return ~@as(u16, @truncate(sum));
}

fn internetChecksum(data: []const u8) u16 {
    var sum: u32 = 0;
    var i: usize = 0;

    while (i + 1 < data.len) : (i += 2) {
        sum += @as(u32, data[i]) << 8 | @as(u32, data[i + 1]);
    }

    if (i < data.len) sum += @as(u32, data[i]) << 8;
    while (sum >> 16 != 0) sum = (sum & 0xFFFF) + (sum >> 16);

    return ~@as(u16, @truncate(sum));
}

fn sendRst(sock: zio.net.Socket, src_ip: u32, dst_ip: u32, src_port: u16, dst_port: u16, syn_ack: TcpHeader, timeout: zio.Timeout, prng: std.Random.Xoshiro256) void {
    // Our RST sequence number = the ACK number the server sent us.
    const rst_seq = mem.bigToNative(u32, syn_ack.ack_seq);

    var tcp = TcpHeader{
        .source = mem.nativeToBig(u16, src_port),
        .dest = mem.nativeToBig(u16, dst_port),
        .seq = mem.nativeToBig(u32, rst_seq),
        .ack_seq = 0,
        .data_off_res = 0x50,
        .flags = TCP_RST,
        .window = 0,
        .check = 0,
        .urg_ptr = 0,
    };
    tcp.check = mem.nativeToBig(u16, tcpChecksum(src_ip, dst_ip, &tcp, &.{}));

    var ip = IpHeader{
        .ver_ihl = 0x45,
        .tos = 0,
        .tot_len = mem.nativeToBig(u16, @sizeOf(IpHeader) + @sizeOf(TcpHeader)),
        .id = prng.random().int(u16),
        .frag_off = 0,
        .ttl = 64,
        .protocol = 6,
        .check = 0,
        .saddr = mem.nativeToBig(u32, src_ip),
        .daddr = mem.nativeToBig(u32, dst_ip),
    };
    ip.check = mem.nativeToBig(u16, internetChecksum(mem.asBytes(&ip)));

    var pkt: [@sizeOf(IpHeader) + @sizeOf(TcpHeader)]u8 = undefined;
    @memcpy(pkt[0..@sizeOf(IpHeader)], mem.asBytes(&ip));
    @memcpy(pkt[@sizeOf(IpHeader)..], mem.asBytes(&tcp));

    const dst_addr = zio.net.IpAddress{
        .in = .{
            .addr = mem.nativeToBig(u32, dst_ip),
            .port = dst_port,
        },
    };
    _ = sock.sendTo(dst_addr, &pkt, timeout) catch {};
}

fn synScan(task: Task) !void {
    const dst_ip = resolveIpv4(task.host) catch return;
    const src_ip = localIpv4(dst_ip) catch return;

    const dst_addr = zio.net.IpAddress{
        .in = .{ .addr = mem.nativeToBig(u32, dst_ip), .port = task.port },
    };

    const timeout: zio.Timeout = if (task.timeout == 0)
        .{ .duration = .fromMilliseconds(500) }
    else
        .{ .duration = .fromMilliseconds(task.timeout) };

    var prng = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.nanoTimestamp())));
    const src_port: u16 = 49152 + prng.random().intRangeAtMost(u16, 0, 16382);
    const isn: u32 = prng.random().int(u32);

    var tcp: TcpHeader = .{
        .source = mem.nativeToBig(u16, src_port),
        .dest = mem.nativeToBig(u16, task.port),
        .seq = mem.nativeToBig(u32, isn),
        .ack_seq = 0,
        .data_off_res = 0x50,
        .flags = TCP_SYN,
        .window = mem.nativeToBig(u16, 1024),
        .check = 0,
        .urg_ptr = 0,
    };
    tcp.check = mem.nativeToBig(u16, tcpChecksum(src_ip, dst_ip, &tcp, &.{}));

    var ip: IpHeader = .{
        .ver_ihl = 0x45,
        .tos = 0,
        .tot_len = mem.nativeToBig(u16, @sizeOf(IpHeader) + @sizeOf(TcpHeader)),
        .id = prng.random().int(u16),
        .frag_off = 0,
        .ttl = 64,
        .protocol = linux.IPPROTO.TCP,
        .check = 0,
        .saddr = mem.nativeToBig(u32, src_ip),
        .daddr = mem.nativeToBig(u32, dst_ip),
    };
    ip.check = mem.nativeToBig(u16, internetChecksum(mem.asBytes(&ip)));

    var syn_pkt: [@sizeOf(IpHeader) + @sizeOf(TcpHeader)]u8 = undefined;
    @memcpy(syn_pkt[0..@sizeOf(IpHeader)], mem.asBytes(&ip));
    @memcpy(syn_pkt[@sizeOf(IpHeader)..], mem.asBytes(&tcp));

    const raw_sock = zio.net.Socket.open(.raw, .ipv4, .tcp) catch |err| {
        std.log.err("synScan: bind() failed ({any}). Root / CAP_NET_RAW required.", .{err});
        return;
    };
    defer raw_sock.close();
    _ = raw_sock.sendTo(dst_addr, &syn_pkt, timeout) catch return;

    var recv_buff: [4096]u8 = undefined;
    var port_state: enum { open, closed, filtered } = .filtered;

    outer: while (true) {
        const recv_result = raw_sock.receiveFrom(&recv_buff, timeout) catch |err| switch (err) {
            error.Timeout => break :outer,
            else => break :outer,
        };

        const n = recv_result.len;
        if (n < (@sizeOf(IpHeader) + @sizeOf(TcpHeader))) continue;

        const recv_ip: IpHeader = mem.bytesToValue(IpHeader, recv_buff[0..@sizeOf(IpHeader)]);

        if (mem.bigToNative(u32, recv_ip.saddr) != dst_ip) continue;

        const ihl: usize = (recv_ip.ver_ihl & 0x0F) * 4;
        if (n < ihl + @sizeOf(TcpHeader)) continue;

        const recv_tcp: TcpHeader = mem.bytesToValue(TcpHeader, recv_buff[ihl..][0..@sizeOf(TcpHeader)]);

        if (mem.bigToNative(u16, recv_tcp.source) != task.port) continue;
        if (mem.bigToNative(u16, recv_tcp.dest) != src_port) continue;

        if ((recv_tcp.flags & TCP_SYN) != 0 and (recv_tcp.flags & TCP_ACK) != 0) {
            port_state = .open;
            sendRst(raw_sock, src_ip, dst_ip, src_port, task.port, recv_tcp, timeout);
            break :outer;
        } else if ((recv_tcp.flags & TCP_RST) != 0) {
            port_state = .closed;
            break :outer;
        }
    }
    if (port_state == .open) {
        task.wr.print("host {s} port {d} is open (SYN)\n", .{ task.host, task.port }) catch {};
        task.wr.flush() catch {};
    }
}
