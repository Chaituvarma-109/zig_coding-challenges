const std = @import("std");
const net = std.net;
const Pool = std.Thread.Pool;

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;

    var pool: std.Thread.Pool = undefined;
    try pool.init(Pool.Options{ .n_jobs = 4, .allocator = page_alloc });
    defer pool.deinit();

    const address = try net.Address.resolveIp("127.0.0.1", 8080);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    while (true) {
        const conn = listener.accept() catch |err| {
            std.debug.print("Error accepting connection: {any}\n", .{err});
            continue;
        };

        try pool.spawn(handleRequest, .{ conn, page_alloc });
    }
}

fn handleRequest(conn: net.Server.Connection, page_alloc: std.mem.Allocator) void {
    defer conn.stream.close();

    var buf = page_alloc.alloc(u8, 1024) catch |err| {
        std.debug.print("Error allocating buffer: {any}\n", .{err});
        return;
    };
    defer page_alloc.free(buf);

    const n = conn.stream.read(buf) catch |err| {
        std.debug.print("Error reading from connection: {any}\n", .{err});
        return;
    };

    var splitter = std.mem.splitSequence(u8, buf[0..n], "\r\n");
    const rqst = splitter.next().?;
    var trim_path = std.mem.splitSequence(u8, rqst, " ");
    _ = trim_path.next().?; // request method
    const rqst_path = trim_path.next().?;

    if (std.mem.eql(u8, rqst_path, "/") or std.mem.eql(u8, rqst_path, "/index.html")) {
        const http_resp = "HTTP/1.1 200 OK";
        const file_buff = std.fs.cwd().readFileAlloc(page_alloc, "./www/index.html", 1024) catch |err| {
            std.debug.print("Error reading file: {any}\n", .{err});
            return;
        };
        const resp = std.fmt.allocPrint(page_alloc, "{s}\r\n\r\n{s}", .{ http_resp, file_buff }) catch |err| {
            std.debug.print("Error formatting response: {any}\n", .{err});
            return;
        };
        conn.stream.writeAll(resp) catch |err| {
            std.debug.print("Error writing response: {any}\n", .{err});
        };
    } else {
        const http_resp = "HTTP/1.1 404 Not Found";
        const resp = std.fmt.allocPrint(page_alloc, "{s}\r\n\r\n", .{http_resp}) catch |err| {
            std.debug.print("Error formatting response: {any}\n", .{err});
            return;
        };
        conn.stream.writeAll(resp) catch |err| {
            std.debug.print("Error writing response: {any}\n", .{err});
        };
    }
}
