const std = @import("std");
const posix = std.posix;
const mem = std.mem;

const Question = packed struct {
    const Self = @This();
    name: []u8,
    record: u16,
    class: u16,
};

const HeaderFlags = packed struct {
    qr: u1,
    opcode: u4,
    aa: u1,
    tc: u1,
    rd: u1,
    ra: u1,
    z: u3,
    rcode: u4,
};

const Header = packed struct {
    const Self = @This();
    h_id: u16,
    flags: HeaderFlags,
    qdcount: u16,
    ancount: u16,
    nscount: u16,
    arcount: u16,

    fn read(msg: []const u8) !Self {
        std.debug.print("{s}\n", .{msg[2..4]});

        return .{
            .h_id = mem.bigToNative(u16, mem.bytesToValue(u16, msg[0..2])),
            .flags = mem.bytesToValue(HeaderFlags, msg[2..4]),
            .qdcount = mem.bytesToValue(u16, msg[4..6]),
            .ancount = mem.bytesToValue(u16, msg[6..8]),
            .nscount = mem.bytesToValue(u16, msg[8..10]),
            .arcount = mem.bytesToValue(u16, msg[10..12]),
        };
    }

    fn write(self: Self, msg: *[12]u8) !void {
        msg[0..2].* = mem.toBytes(mem.nativeToBig(u16, self.h_id));
        msg[2..4].* = mem.toBytes(mem.nativeToBig(u16, @bitCast(self.flags)));
        msg[4..6].* = mem.toBytes(mem.nativeToBig(u16, self.qdcount));
        msg[6..8].* = mem.toBytes(mem.nativeToBig(u16, self.ancount));
        msg[8..10].* = mem.toBytes(mem.nativeToBig(u16, self.nscount));
        msg[10..12].* = mem.toBytes(mem.nativeToBig(u16, self.arcount));
    }
};

const DNSPKT = packed struct {
    const Self = @This();

    pkt_id: u16,
    header: Header,
    questions: Question,
    answers: u16,
    authorities: u16,
    additionals: u16,
};

pub fn main() !void {
    const sock_fd = try posix.socket(posix.AF.INET, posix.SOCK.DGRAM, posix.IPPROTO.IP);
    defer posix.close(sock_fd);

    const addr = try std.net.Address.resolveIp("127.0.0.1", 2053);
    try posix.bind(sock_fd, &addr.any, addr.getOsSockLen());

    var buf: [1024]u8 = undefined;
    while (true) {
        var client_addr: posix.sockaddr = undefined;
        var client_addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);
        _ = try posix.recvfrom(sock_fd, &buf, 0, &client_addr, &client_addr_len);

        var head = try Header.read(&buf);
        head.flags.qr = 1;
        var resp: [12]u8 = undefined;
        try head.write(&resp);

        std.debug.print("{any}\n", .{head.flags});
        std.debug.print("{any}\n", .{resp});

        _ = try posix.sendto(sock_fd, &resp, 0, &client_addr, client_addr_len);
    }
}
