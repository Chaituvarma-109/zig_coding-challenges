const std = @import("std");
const process = std.process;
const http = std.http;
const mem = std.mem;
const Io = std.Io;

const body_max_size: usize = 8192;

pub fn main() !void {
    const page_alloc: mem.Allocator = std.heap.page_allocator;

    var io_threaded: Io.Threaded = .init_single_threaded;
    const io: Io = io_threaded.io();

    var wbuff: [1024]u8 = undefined;
    const f: Io.File = .stdout();
    var fwr = f.writer(io, &wbuff);
    const wr: *Io.Writer = &fwr.interface;

    var client: http.Client = .{ .allocator = page_alloc, .io = io };
    defer client.deinit();

    const args: [][:0]u8 = try process.argsAlloc(page_alloc);
    defer process.argsFree(page_alloc, args);

    var method: http.Method = .GET;
    var verbose: bool = false;
    var url: []const u8 = "http://eu.httpbin.org/get";
    var headers: []const u8 = "";
    var data: ?[]u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg: [:0]u8 = args[i];
        if (std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-X")) {
            i += 1;
            if (i >= args.len) return error.MissingMethodArgument;
            const method_str: [:0]u8 = args[i];

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
            try wr.print("Unknown argument: {s}\n", .{arg});
            try wr.flush();
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
        try wr.print("Unable to open the request: {}\n", .{err});
        try wr.flush();
        return;
    };
    defer req.deinit();

    if (verbose) {
        const path: []const u8 = uri.path.percent_encoded;
        const scheme: []const u8 = uri.scheme;
        const port: u16 = uri.port orelse (if (mem.eql(u8, scheme, "http")) @as(u16, 80) else @as(u16, 443));
        const host: []const u8 = req.headers.host.override;

        try wr.print("* Connected to {s} port {d}\n", .{ host, port });
        try wr.print("> {s} {s} {s}\n", .{ @tagName(method), path, @tagName(req.version) });
        try wr.print("> Host: {s}\n", .{host});
        try wr.print("> User-Agent: {s}\n", .{req.headers.user_agent.override});
        try wr.print("> {s}: {s}\n", .{ req.extra_headers[0].name, req.extra_headers[0].value });
        try wr.flush();
        switch (method) {
            .POST, .PUT => {
                try wr.print("> Content-Type: {s}\n", .{req.headers.content_type.override});
                try wr.print("> Content-Length: {d}\n", .{data.?.len});
                try wr.flush();
            },
            else => {},
        }
        try wr.print("> \n", .{});
        try wr.flush();
    }

    if (data) |content| {
        req.transfer_encoding = .{ .content_length = content.len };
        try req.sendBodyComplete(content);
    } else {
        try req.sendBodiless();
    }

    var res: http.Client.Response = try req.receiveHead(&redirect_buff);

    if (res.head.status != http.Status.ok) {
        try wr.print("{s}\n", .{res.head.status.phrase().?});
        try wr.flush();
        return;
    }

    if (verbose) {
        const ver: http.Version = res.head.version;
        const status_phrase: []const u8 = res.head.status.phrase().?;
        const status: http.Status = res.head.status;

        try wr.print("< {s} {d} {s}\n", .{ @tagName(ver), @intFromEnum(status), status_phrase });
        try wr.flush();

        var iter: http.HeaderIterator = res.head.iterateHeaders();
        while (iter.next()) |header| {
            try wr.print("< {s}:{s}\n", .{ header.name, header.value });
            try wr.flush();
        }
        try wr.print("< \n", .{});
        try wr.flush();
    }

    var transfer_buffer: [64]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    const body_reader: *Io.Reader = res.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer);

    var resp_wr: Io.Writer.Allocating = .init(page_alloc);
    defer resp_wr.deinit();

    _ = body_reader.streamRemaining(&resp_wr.writer) catch |err| switch (err) {
        else => return err,
    };

    const bytes: []u8 = resp_wr.written();
    try wr.print("{s}\n", .{bytes});
    try wr.flush();
}
