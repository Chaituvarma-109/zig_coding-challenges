const std = @import("std");
const process = std.process;
const http = std.http;
const mem = std.mem;

const body_max_size: usize = 4096;

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;

    var client = http.Client{ .allocator = page_alloc };
    defer client.deinit();

    const args = try process.argsAlloc(page_alloc);
    defer process.argsFree(page_alloc, args);

    var wr = std.fs.File.stdout().writer(&.{});
    const writer = &wr.interface;

    // var resp_wr = std.Io.Writer.Allocating.init(page_alloc);
    // defer resp_wr.deinit();

    var method = http.Method.GET;
    var verbose = false;
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
            try writer.print("Unknown argument: {s}\n", .{arg});
            return error.UnknownArgument;
        }
    }

    var sep = mem.splitSequence(u8, headers, ": ");
    _ = sep.first();
    const app_type = sep.rest();

    const uri = try std.Uri.parse(url);
    const path = uri.path.percent_encoded;
    const scheme = uri.scheme;

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

    var redirect_buff: [1024]u8 = undefined;

    // _ = try client.fetch(.{
    //     .method = method,
    //     .payload = data,
    //     .keep_alive = false,
    //     .location = .{ .uri = uri },
    //     .headers = req_headers,
    //     .extra_headers = &[_]http.Header{
    //         .{ .name = "Accept", .value = "*/*" },
    //     },
    //     .redirect_buffer = &redirect_buff,
    //     .response_writer = &resp_wr.writer,
    // });

    // std.debug.print("{s}\n", .{resp_wr.written()});

    var req: http.Client.Request = client.request(method, uri, .{
        .keep_alive = false,
        .headers = req_headers,
        .extra_headers = &[_]http.Header{
            .{ .name = "Accept", .value = "*/*" },
        },
    }) catch |err| {
        try writer.print("Unable to open the request: {}\n", .{err});
        return;
    };
    defer req.deinit();

    if (verbose) {
        const port = uri.port orelse (if (mem.eql(u8, scheme, "http")) @as(u16, 80) else @as(u16, 443));
        const host = req.headers.host.override;
        try writer.print("* Connected to {s} port {d}\n", .{ host, port });
        try writer.print("> {s} {s} {s}\n", .{ @tagName(method), path, @tagName(req.version) });
        try writer.print("> Host: {s}\n", .{host});
        try writer.print("> User-Agent: {s}\n", .{req.headers.user_agent.override});
        try writer.print("> {s}: {s}\n", .{ req.extra_headers[0].name, req.extra_headers[0].value });
        switch (method) {
            .POST, .PUT => {
                try writer.print("> Content-Type: {s}\n", .{req.headers.content_type.override});
                try writer.print("> Content-Length: {d}\n", .{data.?.len});
            },
            else => {},
        }
        try writer.print("> \n", .{});
    }

    if (data) |content| {
        req.transfer_encoding = .{ .content_length = content.len };
        var body = try req.sendBody(&.{});
        try body.writer.writeAll(content);
        try body.end();
    } else {
        try req.sendBodiless();
    }

    var res = try req.receiveHead(&redirect_buff);

    if (res.head.status != http.Status.ok) {
        try writer.print("{s}\n", .{res.head.status.phrase().?});
        return;
    }

    if (verbose) {
        const ver = res.head.version;
        const status_phrase = res.head.status.phrase().?;
        const status = res.head.status;

        try writer.print("< {s} {d} {s}\n", .{ @tagName(ver), @intFromEnum(status), status_phrase });

        var iter = res.head.iterateHeaders();
        while (iter.next()) |header| {
            try writer.print("< {s}:{s}\n", .{ header.name, header.value });
        }
        try writer.print("< \n", .{});
    }

    var body_buff: [body_max_size]u8 = undefined;
    const reader = res.reader(&.{});
    const bytes_read = try reader.readSliceShort(&body_buff);
    const body = body_buff[0..bytes_read];

    try writer.print("{s}\n", .{body});
}
