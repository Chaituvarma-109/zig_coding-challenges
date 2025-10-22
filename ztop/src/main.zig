const std = @import("std");
const vaxis = @import("vaxis");
const zeit = @import("zeit");

const mem = std.mem;
const fs = std.fs;
const time = std.time;

// /proc/loadavg - 15bytes.
// /proc/uptime - total uptime of the system in seconds , total idle time summed across all cpu cores.
// /proc/meminfo - total, free, available, buffer, cached.

const Uptime = struct {
    seconds: f64,
    hours: u64,
    minutes: u64,
    days: u64,

    fn readUptime() !Uptime {
        const f = try fs.openFileAbsolute("/proc/uptime", .{});
        defer f.close();

        var buff: [256]u8 = undefined;
        const n: usize = try f.read(&buff);

        var iter = mem.tokenizeAny(u8, buff[0..n], " ");
        const seconds_str: []const u8 = iter.next() orelse return error.ParseError;
        const seconds: f64 = try std.fmt.parseFloat(f64, seconds_str);

        const total_secs = @as(u64, @intFromFloat(seconds));
        const days = total_secs / 86400;
        const hours = (total_secs % 86400) / 3600;
        const minutes = (total_secs % 3600) / 60;

        return .{
            .seconds = seconds,
            .hours = hours,
            .minutes = minutes,
            .days = days,
        };
    }
};

const MemInfo = struct {
    total: u64,
    free: u64,
    available: u64,
    buffers: u64,
    cached: u64,

    fn init() MemInfo {
        return .{
            .total = 0,
            .free = 0,
            .available = 0,
            .buffers = 0,
            .cached = 0,
        };
    }

    fn readMemStats() !MemInfo {
        const f = try fs.openFileAbsolute("/proc/meminfo", .{});
        defer f.close();

        var buff: [256]u8 = undefined;
        var fr = f.reader(&buff);
        var stats: MemInfo = .init();

        while (try fr.interface.takeDelimiter('\n')) |line| {
            var iter = mem.tokenizeAny(u8, line, ": ");
            const key: []const u8 = iter.next() orelse continue;
            const value_str: []const u8 = iter.next() orelse continue;
            const value: u64 = std.fmt.parseInt(u64, value_str, 10) catch continue;

            if (mem.eql(u8, key, "MemTotal")) {
                stats.total = value;
            } else if (mem.eql(u8, key, "MemFree")) {
                stats.free = value;
            } else if (mem.eql(u8, key, "MemAvailable")) {
                stats.available = value;
            } else if (mem.eql(u8, key, "Buffers")) {
                stats.buffers = value;
            } else if (mem.eql(u8, key, "Cached")) {
                stats.cached = value;
            }
        }

        return stats;
    }
};

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub fn main() !void {
    var alloc: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = alloc.deinit();
    const gpa: mem.Allocator = alloc.allocator();

    var buff: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(&buff);
    defer tty.deinit();

    const tty_writer = tty.writer();
    var vx = try vaxis.init(gpa, .{ .kitty_keyboard_flags = .{ .report_events = true } });
    defer vx.deinit(gpa, tty_writer);

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty_writer);
    try vx.queryTerminal(tty_writer, 1 * time.ns_per_ms);

    var last_update: i64 = 0;

    while (true) {
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true })) return;
                },
                .winsize => |ws| try vx.resize(gpa, tty_writer, ws),
            }
        }
        const now = time.milliTimestamp();

        if (now - last_update >= 1000) {
            last_update = now;

            const win = vx.window();
            win.clear();

            // Header
            // up time
            const instant = try zeit.instant(.{});
            const local = try zeit.local(gpa, null);
            defer local.deinit();

            const now_local = instant.in(&local);
            const dt = now_local.time();

            const uptime: Uptime = try .readUptime();
            const uptime_header = try std.fmt.allocPrint(gpa, "ztop - {d:0>2}:{d:0>2}:{d:0>2} | uptime: {d:0>2}:{d:0>2}", .{ dt.hour, dt.minute, dt.second, uptime.hours, uptime.minutes });
            defer gpa.free(uptime_header);

            var row: u16 = 0;
            _ = win.printSegment(.{ .text = uptime_header, .style = .{ .fg = .{ .index = 6 }, .bold = true } }, .{ .row_offset = row });
            row += 1;

            // get load avg
            const ld: [3]f64 = try getLoadAvg();
            const load_avg = try std.fmt.allocPrint(gpa, "load avg: {d:.2}, {d:.2}, {d:.2}", .{ ld[0], ld[1], ld[2] });
            defer gpa.free(load_avg);

            _ = win.printSegment(.{ .text = load_avg, .style = .{ .fg = .{ .index = 5 }, .bold = true } }, .{ .row_offset = row });
            row += 1;

            // meminfo
            const mem_stats: MemInfo = try .readMemStats();
            const used: u64 = mem_stats.total - mem_stats.free;
            const mem_info = try std.fmt.allocPrint(gpa, "Memory: Total: {d:.2}, Free: {d:.2}, Used: {d:.2}, Available: {d:.2}", .{ mem_stats.total, mem_stats.free, used, mem_stats.available });
            defer gpa.free(mem_info);

            _ = win.printSegment(.{ .text = mem_info, .style = .{ .fg = .{ .index = 5 }, .bold = true } }, .{ .row_offset = row });
            row += 1;

            try vx.render(tty_writer);
        }
        std.Thread.sleep(100 * time.ns_per_ms);
    }
}

fn getLoadAvg() ![3]f64 {
    const f = try fs.openFileAbsolute("/proc/loadavg", .{});
    defer f.close();

    var buff: [2048]u8 = undefined;
    const n: usize = try f.read(&buff);

    var iter = mem.tokenizeAny(u8, buff[0..n], " ");
    const avg1 = try std.fmt.parseFloat(f64, iter.next() orelse "0");
    const avg2 = try std.fmt.parseFloat(f64, iter.next() orelse "0");
    const avg3 = try std.fmt.parseFloat(f64, iter.next() orelse "0");

    return [3]f64{ avg1, avg2, avg3 };
}
