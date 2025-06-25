const std = @import("std");
const httpz = @import("httpz");

const App = struct {
    url_map: *std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const gpa_alloc = gpa.allocator();

    var url_map = std.StringHashMap([]const u8).init(gpa_alloc);
    defer {
        var iterator = url_map.iterator();
        while (iterator.next()) |entry| {
            gpa_alloc.free(entry.key_ptr.*);
            gpa_alloc.free(entry.value_ptr.*);
        }
        url_map.deinit();
    }

    var app = App{
        .url_map = &url_map,
        .allocator = gpa_alloc,
    };

    var server = try httpz.Server(*App).init(gpa_alloc, .{ .port = 8080 }, &app);
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});

    router.get("/:rurl", redirecturl, .{});
    router.post("/createUrl", shorturl, .{});
    router.delete("/:durl", deleteurl, .{});

    try server.listen();
}

fn redirecturl(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const rurl = req.param("rurl").?;

    if (app.url_map.get(rurl)) |url| {
        const url_copy = try res.arena.dupe(u8, url);
        res.status = 302;
        res.header("location", url_copy);
        res.body = "Redirecting...";
    } else {
        res.status = 404;
        res.body = "URL not found";
    }
}

fn shorturl(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const b = req.body().?;

    const data = try std.json.parseFromSlice(std.json.Value, app.allocator, b, .{});
    defer data.deinit();
    if (data.value != .object) return error.InvalidJson;
    const obj = data.value.object;
    const url = obj.get("url").?.string;
    const url_persistent = try app.allocator.dupe(u8, url);

    var short_url_buff: [500]u8 = undefined;
    const h = std.hash.Wyhash.hash(50, url);
    _ = try std.fmt.bufPrint(&short_url_buff, "{x}", .{h});
    const url_code_temp = short_url_buff[0..6];
    const url_code = try app.allocator.dupe(u8, url_code_temp);

    var buff: [500]u8 = undefined;
    const short_url = try std.fmt.bufPrint(&buff, "http://localhost/{s}", .{url_code});

    try app.url_map.put(url_code, url_persistent);

    res.status = 200;
    try res.json(.{
        .key = url_code,
        .url = url,
        .short_url = short_url,
    }, .{});
}

fn deleteurl(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const durl = req.param("durl").?;

    if (app.url_map.fetchRemove(durl)) |removed| {
        app.allocator.free(removed.key);
        app.allocator.free(removed.value);

        res.status = 200;
        res.body = "URL deleted successfully";
    } else {
        res.status = 404;
        res.body = "URL not found";
    }
}
