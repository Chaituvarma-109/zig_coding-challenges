const std = @import("std");
const posix = std.posix;
const mem = std.mem;

const Types = enum(u16) {
    A,
    NS,
    MD,
    MF,
    CNAME,
    SOA,
    MB,
    MG,
    MR,
    NULL,
    WKS,
    PTR,
    HINFO,
    MINFO,
    MX,
    TXT,
};

const Class = enum(u16) {
    IN,
    CS,
    CH,
    HS,
};

const Question = struct {
    const Self = @This();

    name: []const u8,
    type: Types,
    class: Class,

    fn read(self: *Self, msg: []const u8) !usize {
        var name_len: usize = 0;
        while (msg[name_len] != 0) {
            name_len += 1;
        }
        name_len += 1;
        self.name = msg[0..name_len];
        self.type = @enumFromInt(mem.bigToNative(u16, mem.bytesToValue(u16, msg[name_len..(blk: {
            name_len += 2;
            break :blk name_len;
        })])));
        self.class = @enumFromInt(mem.bigToNative(u16, mem.bytesToValue(u16, msg[name_len..(blk: {
            name_len += 2;
            break :blk name_len;
        })])));
        return name_len;
    }

    fn write(self: Self, buf: []u8) !usize {
        var offset: usize = self.name.len;
        @memcpy(buf[0..offset], self.name);
        @memcpy(buf[offset..(blk: {
            offset += 2;
            break :blk offset;
        })], &mem.toBytes(mem.nativeToBig(u16, @intFromEnum(self.type))));
        @memcpy(buf[offset..(blk: {
            offset += 2;
            break :blk offset;
        })], &mem.toBytes(mem.nativeToBig(u16, @intFromEnum(self.class))));

        return offset;
    }
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

    fn write(self: Self, buf: *[12]u8) !void {
        buf[0..2].* = mem.toBytes(mem.nativeToBig(u16, self.h_id));
        buf[2..4].* = mem.toBytes(mem.nativeToBig(u16, @bitCast(self.flags)));
        buf[4..6].* = mem.toBytes(mem.nativeToBig(u16, self.qdcount));
        buf[6..8].* = mem.toBytes(mem.nativeToBig(u16, self.ancount));
        buf[8..10].* = mem.toBytes(mem.nativeToBig(u16, self.nscount));
        buf[10..12].* = mem.toBytes(mem.nativeToBig(u16, self.arcount));
    }
};

const DNSPKT = struct {
    const Self = @This();

    header: Header,
    questions: Question,
    // answers: u16,
    // authorities: u16,
    // additionals: u16,

    fn read(inp: []const u8) !Self {
        const header = try Header.read(inp[0..12]);
        // TODO: Rewrite for multiple questions
        const questions = try Question.read(inp[12..]);
        return Self{
            .header = header,
            .questions = questions,
        };
    }

    fn write(self: Self, buf: *[512]u8) !void {
        self.header.flags.qr = 1;
        self.header.write(buf[0..12]);
        self.questions.write(buf[12..]);
    }
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
        const n = try posix.recvfrom(sock_fd, &buf, 0, &client_addr, &client_addr_len);

        const req = try DNSPKT.read(buf[0..n]);
        const resp_h: Header = .{
            .id = req.header.id,
            .flags = .{
                .qr = 1,
                .opcode = 0,
                .aa = 0,
                .tc = 0,
                .rd = 0,
                .ra = 0,
                .z = 0,
                .rcode = 0, // no error
            },
            .qd_count = req.header.qd_count,
            .an_count = 0,
            .ns_count = 0,
            .ar_count = 0,
        };
        var dns_resp = DNSPKT{
            .header = resp_h,
            .questions = req.questions,
        };
        var resp: [512]u8 = undefined;
        try dns_resp.write(&resp);

        // std.debug.print("{any}\n", .{head.flags});
        std.debug.print("{any}\n", .{resp});

        _ = try posix.sendto(sock_fd, &resp, 0, &client_addr, client_addr_len);
    }
}
