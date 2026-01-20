const std = @import("std");
const Io = std.Io;
const net = Io.net;

const Request = struct {
    method: []const u8,
    path: []const u8,

    fn new(buff: []u8) Request {
        var splitter = std.mem.splitSequence(u8, buff, "\r\n");
        const rqst: []const u8 = splitter.next().?;
        var trim_path = std.mem.splitSequence(u8, rqst, " ");
        const rqst_method: []const u8 = trim_path.next().?;
        const rqst_path: []const u8 = trim_path.next().?;

        return Request{
            .method = rqst_method,
            .path = rqst_path,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const io: Io = init.io;

    const address: net.IpAddress = try .parse("127.0.0.1", 8080);
    var listener: net.Server = try address.listen(io, .{
        .reuse_address = true,
    });
    defer listener.deinit(io);

    var group: Io.Group = .init;
    defer group.cancel(io);

    while (true) {
        var conn: net.Stream = listener.accept(io) catch |err| {
            std.debug.print("Error accepting connection: {any}\n", .{err});
            continue;
        };
        errdefer conn.close(io);

        try group.concurrent(io, handleRequest, .{ &conn, io });
    }
}

fn handleRequest(conn: *net.Stream, io: Io) void {
    defer conn.close(io);

    var r: Io.net.Stream.Reader = conn.*.reader(io, &.{});
    var w: Io.net.Stream.Writer = conn.*.writer(io, &.{});

    const reader: *Io.Reader = &r.interface;
    const writer: *Io.Writer = &w.interface;

    var fbuff: [1024]u8 = undefined;
    var resp_wr: Io.Writer = .fixed(&fbuff);

    _ = reader.stream(&resp_wr, .unlimited) catch |err| {
        std.log.err("err: {any}\n", .{err});
        return;
    };

    const buff: []u8 = resp_wr.buffered();
    const req: Request = .new(buff);
    var r_buff: [1024]u8 = undefined;

    if (std.mem.eql(u8, req.path, "/") or std.mem.eql(u8, req.path, "/index.html")) {
        const http_resp: []const u8 = "HTTP/1.1 200 OK";
        var f_buff: [1024]u8 = undefined;
        const contents: []u8 = Io.Dir.readFile(.cwd(), io, "./www/index.html", &f_buff) catch |err| {
            std.log.err("Error reading file: {any}\n", .{err});
            return;
        };
        const resp: []u8 = std.fmt.bufPrint(&r_buff, "{s}\r\n\r\n{s}", .{ http_resp, contents }) catch |err| {
            std.log.err("Error formatting response: {any}\n", .{err});
            return;
        };
        writer.writeAll(resp) catch |err| {
            std.log.err("err: {any}\n", .{err});
            return;
        };
        writer.flush() catch |err| {
            std.log.err("err: {any}\n", .{err});
            return;
        };
    } else {
        const http_resp: []const u8 = "HTTP/1.1 404 Not Found";
        const resp: []u8 = std.fmt.bufPrint(&r_buff, "{s}\r\n\r\n", .{http_resp}) catch |err| {
            std.log.err("Error formatting response: {any}\n", .{err});
            return;
        };
        writer.writeAll(resp) catch |err| {
            std.log.err("Error writing response: {any}\n", .{err});
            return;
        };
        writer.flush() catch |err| {
            std.log.err("err: {any}\n", .{err});
            return;
        };
    }
}
