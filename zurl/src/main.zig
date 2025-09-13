const std = @import("std");
const process = std.process;
const http = std.http;
const mem = std.mem;

const body_max_size: usize = 4096;

pub fn main() !void {
    const page_alloc: mem.Allocator = std.heap.page_allocator;

    var client: http.Client = .{ .allocator = page_alloc };
    defer client.deinit();

    const args = try process.argsAlloc(page_alloc);
    defer process.argsFree(page_alloc, args);

    var method: http.Method = .GET;
    var verbose: bool = false;
    var url: []const u8 = "http://eu.httpbin.org/get";
    var headers: []const u8 = "";
    var data: ?[]u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-X")) {
            i += 1;
            if (i >= args.len) return error.MissingMethodArgument;
            const method_str = args[i];

            if (mem.eql(u8, method_str, "POST")) method = .POST;
            if (mem.eql(u8, method_str, "DELETE")) method = .DELETE;
            if (mem.eql(u8, method_str, "PUT")) method = .PUT;
        } else if (mem.eql(u8, arg, "-d")) {
            i += 1;
            if (i >= args.len) return error.MissingHeaderArgument;
            data = args[i];
        } else if (mem.eql(u8, arg, "-H")) {
            i += 1;
            if (i >= args.len) return error.MissingHeaderArgument;
            headers = args[i];
        } else if (std.mem.startsWith(u8, arg, "http://") or std.mem.startsWith(u8, arg, "https://")) {
            url = arg;
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            return error.UnknownArgument;
        }
    }

    var sep = mem.splitSequence(u8, headers, ": ");
    _ = sep.first();
    const app_type: []const u8 = sep.rest();

    const uri: std.Uri = std.Uri.parse(url) catch |err| {
        std.log.err("error: {}\n", .{err});
        return;
    };
    const path: []const u8 = uri.path.percent_encoded;
    const scheme: []const u8 = uri.scheme;

    var req_headers: http.Client.Request.Headers = .{};
    switch (method) {
        .POST, .PUT => req_headers = .{
            .host = .{ .override = uri.host.?.percent_encoded },
            .user_agent = .{ .override = "zurl" },
            .connection = .{ .override = "close" },
            .content_type = .{ .override = app_type },
        },
        else => req_headers = .{
            .host = .{ .override = uri.host.?.percent_encoded },
            .user_agent = .{ .override = "zurl" },
            .connection = .{ .override = "close" },
        },
    }

    const extra_headers = [_]http.Header{
        .{ .name = "Accept", .value = "*/*" },
    };

    var redirect_buff: [1024]u8 = undefined;

    var req: http.Client.Request = client.request(method, uri, .{
        .keep_alive = false,
        .headers = req_headers,
        .extra_headers = &extra_headers,
    }) catch |err| {
        std.debug.print("Unable to open the request: {}\n", .{err});
        return;
    };
    defer req.deinit();

    if (verbose) {
        const port: u16 = uri.port orelse (if (mem.eql(u8, scheme, "http")) @as(u16, 80) else @as(u16, 443));
        const host: []const u8 = req.headers.host.override;
        std.debug.print("* Connected to {s} port {d}\n", .{ host, port });
        std.debug.print("> {s} {s} {s}\n", .{ @tagName(method), path, @tagName(req.version) });
        std.debug.print("> Host: {s}\n", .{host});
        std.debug.print("> User-Agent: {s}\n", .{req.headers.user_agent.override});
        std.debug.print("> {s}: {s}\n", .{ req.extra_headers[0].name, req.extra_headers[0].value });
        switch (method) {
            .POST, .PUT => {
                std.debug.print("> Content-Type: {s}\n", .{req.headers.content_type.override});
                std.debug.print("> Content-Length: {d}\n", .{data.?.len});
            },
            else => {},
        }
        std.debug.print("> \n", .{});
    }

    if (data) |content| {
        req.transfer_encoding = .{ .content_length = content.len };
        var body: http.BodyWriter = try req.sendBody(&.{});
        try body.writer.writeAll(content);
        try body.end();
    } else {
        try req.sendBodiless();
    }

    var res = try req.receiveHead(&redirect_buff);

    if (res.head.status != http.Status.ok) {
        std.debug.print("{s}\n", .{res.head.status.phrase().?});
        return;
    }

    if (verbose) {
        const ver: http.Version = res.head.version;
        const status_phrase: []const u8 = res.head.status.phrase().?;
        const status: http.Status = res.head.status;

        std.debug.print("< {s} {d} {s}\n", .{ @tagName(ver), @intFromEnum(status), status_phrase });

        var iter: http.HeaderIterator = res.head.iterateHeaders();
        while (iter.next()) |header| {
            std.debug.print("< {s}:{s}\n", .{ header.name, header.value });
        }
        std.debug.print("< \n", .{});
    }

    var resp_wr: std.Io.Writer.Allocating = .init(page_alloc);
    defer resp_wr.deinit();

    var body_buff: [body_max_size]u8 = undefined;
    const body_reader = res.request.reader.bodyReader(&body_buff, req.response_transfer_encoding, res.request.response_content_length.?);

    _ = body_reader.stream(&resp_wr.writer, .limited(body_max_size)) catch |err| switch (err) {
        error.EndOfStream => {},
        else => {
            std.log.err("err: {}\n", .{err});
            return;
        },
    };
    const body: []u8 = resp_wr.written();
    std.debug.print("{s}\n", .{body});
}
