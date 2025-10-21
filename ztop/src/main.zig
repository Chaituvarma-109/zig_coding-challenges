const std = @import("std");
const mem = std.mem;

// /proc/loadavg - 15bytes.
// /proc/uptime - total uptime of the system in seconds , total idle time summed across all cpu cores.
// /proc/swaps
// /proc/meminfo - total, free, available, buffer, cached.

const Uptime = struct {
    seconds: f64,
    hours: u64,
    minutes: u64,
    days: u64,

    fn readUptime() !Uptime {
        const f = try std.fs.openFileAbsolute("/proc/uptime", .{});
        defer f.close();

        var buff: [256]u8 = undefined;
        const n = try f.read(&buff);

        var iter = mem.tokenizeAny(u8, buff[0..n], " ");
        const seconds_str = iter.next() orelse return error.ParseError;
        const seconds = try std.fmt.parseFloat(f64, seconds_str);

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
        const f = try std.fs.openFileAbsolute("/proc/meminfo", .{});
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

fn getLoadAvg() ![]const u8 {
    const f = try std.fs.openFileAbsolute("/proc/loadavg", .{});
    defer f.close();

    var buff: [2048]u8 = undefined;
    const fr = try f.read(&buff);

    return buff[0..fr];
}

pub fn main() !void {
    const time: Uptime = try .readUptime();
    const mem_stats: MemInfo = try .readMemStats();
    const ld: []const u8 = try getLoadAvg();

    std.debug.print("{s}\n", .{ld[0..15]});
    std.debug.print("{}\n", .{mem_stats});
    std.debug.print("{}\n", .{time});
}
