const std = @import("std");
const vaxis = @import("vaxis");
const zeit = @import("zeit");

const mem = std.mem;
const fs = std.fs;
const time = std.time;
const fmt = std.fmt;

// /proc/loadavg - 15bytes.
// /proc/uptime - total uptime of the system in seconds , total idle time summed across all cpu cores.
// /proc/meminfo - total, free, available, buffer, cached.
// /proc/stat - for cpu stats

const CpuStats = struct {
    user: f64 = 0.0,
    nice: f64 = 0.0,
    system: f64 = 0.0,
    idle: f64 = 0.0,
    iowait: f64 = 0.0,
    irq: f64 = 0.0,
    softirq: f64 = 0.0,
    steal: f64 = 0.0,

    fn readCpuStat() !CpuStats {
        const f: fs.File = try fs.openFileAbsolute("/proc/stat", .{});
        defer f.close();

        var buff: [1024]u8 = undefined;
        var fr = f.reader(&buff);

        const line = try fr.interface.takeDelimiter('\n');

        if (line) |ln| {
            var iter = mem.tokenizeScalar(u8, ln, ' ');
            _ = iter.next();

            const user = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const nice = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const system = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const idle = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const iowait = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const irq = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const softirq = try fmt.parseFloat(f64, iter.next() orelse "0.0");
            const steal = try fmt.parseFloat(f64, iter.next() orelse "0.0");

            return CpuStats{
                .user = user,
                .nice = nice,
                .system = system,
                .idle = idle,
                .iowait = iowait,
                .irq = irq,
                .softirq = softirq,
                .steal = steal,
            };
        }
        return error.InvalidCpuStats;
    }
};

const Uptime = struct {
    seconds: f64,
    hours: u64,
    minutes: u64,
    days: u64,

    fn readUptime() !Uptime {
        const f: fs.File = try fs.openFileAbsolute("/proc/uptime", .{});
        defer f.close();

        var buff: [256]u8 = undefined;
        const n: usize = try f.read(&buff);

        var iter = mem.tokenizeAny(u8, buff[0..n], " ");
        const seconds_str: []const u8 = iter.next() orelse return error.ParseError;
        const seconds: f64 = try fmt.parseFloat(f64, seconds_str);

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

const MemoryUnit = enum {
    Bytes,
    KB,
    MB,
    GB,

    fn next(self: MemoryUnit) MemoryUnit {
        return switch (self) {
            .Bytes => .KB,
            .KB => .MB,
            .MB => .GB,
            .GB => .Bytes,
        };
    }
};

const MemInfo = struct {
    total: u64 = 0,
    free: u64 = 0,
    available: u64 = 0,
    buffers: u64 = 0,
    cached: u64 = 0,

    fn readMemStats() !MemInfo {
        const f: fs.File = try fs.openFileAbsolute("/proc/meminfo", .{});
        defer f.close();

        var buff: [256]u8 = undefined;
        var fr = f.reader(&buff);
        var stats: MemInfo = .{};

        while (try fr.interface.takeDelimiter('\n')) |line| {
            var iter = mem.tokenizeAny(u8, line, ": ");
            const key: []const u8 = iter.next() orelse continue;
            const value_str: []const u8 = iter.next() orelse continue;
            const value: u64 = fmt.parseInt(u64, value_str, 10) catch continue;

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

const Process = struct {
    pid: u32,
    name: []const u8,
    state: u8,
    utime: u64,
    stime: u64,
    priority: i32,
    nice: i64,
    threads: u32,
    vsize: u64,
    rss: u64,

    const Processes = std.MultiArrayList(Process);

    fn listProcess(alloc: mem.Allocator) !Processes {
        var process = Processes{};
        errdefer {
            for (process.items(.name)) |*name| {
                alloc.free(name.*);
            }
            process.deinit(alloc);
        }

        var proc_dir = try fs.openDirAbsolute("/proc", .{ .iterate = true });
        defer proc_dir.close();

        var dir_iter = proc_dir.iterate();
        while (try dir_iter.next()) |entry| {
            if (entry.kind != .directory) continue;

            const pid = fmt.parseInt(u32, entry.name, 10) catch continue;

            var buff: [256]u8 = undefined;
            const pid_path = try fmt.bufPrint(&buff, "/proc/{d}/stat", .{pid});

            var rbuff: [1024]u8 = undefined;
            const f = fs.openFileAbsolute(pid_path, .{}) catch continue;
            defer f.close();

            const n = try f.read(&rbuff);
            const content = rbuff[0..n];

            const start_paren: usize = mem.indexOf(u8, content, "(") orelse continue;
            const last_paren: usize = mem.lastIndexOf(u8, content, ")") orelse continue;

            const name = content[start_paren + 1 .. last_paren];

            const name_cp = try alloc.dupe(u8, name);
            errdefer alloc.free(name_cp);

            const after_name = content[last_paren + 2 ..];
            var fields = mem.tokenizeScalar(u8, after_name, ' ');

            const state = (fields.next() orelse "?")[0];
            _ = fields.next(); // ppid
            _ = fields.next(); // pgrp
            _ = fields.next(); // session
            _ = fields.next(); // tty_nr
            _ = fields.next(); // tpgid
            _ = fields.next(); // flags
            _ = fields.next(); // minflt
            _ = fields.next(); // cminflt
            _ = fields.next(); // majflt
            _ = fields.next(); // cmajflt
            const utime = try fmt.parseInt(u64, fields.next() orelse "0", 10);
            const stime = try fmt.parseInt(u64, fields.next() orelse "0", 10);
            _ = fields.next(); // cutime
            _ = fields.next(); // cstime
            const priority = try fmt.parseInt(i32, fields.next() orelse "0", 10);
            const nice = try fmt.parseInt(i64, fields.next() orelse "0", 10);
            const threads = try fmt.parseInt(u32, fields.next() orelse "0", 10);
            _ = fields.next(); // itrealvalue
            _ = fields.next(); // starttime
            const vsize = try fmt.parseInt(u64, fields.next() orelse "0", 10);
            const rss = try fmt.parseInt(u64, fields.next() orelse "0", 10);

            const p: Process = .{
                .pid = pid,
                .name = name_cp,
                .state = state,
                .utime = utime,
                .stime = stime,
                .priority = priority,
                .nice = nice,
                .threads = threads,
                .vsize = vsize,
                .rss = rss * 4096,
            };

            try process.append(alloc, p);
        }
        return process;
    }
};

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

fn getLoadAvg() ![3]f64 {
    const f: fs.File = try fs.openFileAbsolute("/proc/loadavg", .{});
    defer f.close();

    var buff: [2048]u8 = undefined;
    const n: usize = try f.read(&buff);

    var iter = mem.tokenizeAny(u8, buff[0..n], " ");
    const avg1 = try fmt.parseFloat(f64, iter.next() orelse "0");
    const avg2 = try fmt.parseFloat(f64, iter.next() orelse "0");
    const avg3 = try fmt.parseFloat(f64, iter.next() orelse "0");

    return [3]f64{ avg1, avg2, avg3 };
}

fn formatMem(unit: MemoryUnit, buff: []u8, value: u64) ![]u8 {
    const val_f: f64 = @floatFromInt(value);
    return switch (unit) {
        .Bytes => try fmt.bufPrint(buff, "{d}B", .{value}),
        .KB => try fmt.bufPrint(buff, "{d:.1}KB", .{val_f}),
        .MB => try fmt.bufPrint(buff, "{d:.1}MB", .{val_f / 1024.0}),
        .GB => try fmt.bufPrint(buff, "{d:.2}GB", .{val_f / 1024.0 / 1024.0}),
    };
}

pub fn main() !void {
    var alloc: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = alloc.deinit();
    const gpa: mem.Allocator = alloc.allocator();

    var buff: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(&buff);
    defer tty.deinit();

    const tty_writer = tty.writer();
    var vx = try vaxis.init(gpa, .{});
    defer vx.deinit(gpa, tty_writer);

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty_writer);
    try vx.queryTerminal(tty_writer, 1 * time.ns_per_ms);

    const active_bg: vaxis.Cell.Color = .{ .rgb = .{ 64, 128, 255 } };
    const selected_bg: vaxis.Cell.Color = .{ .rgb = .{ 32, 64, 255 } };

    var tbl: vaxis.widgets.Table.TableContext = .{
        .selected_bg = selected_bg,
        .active_bg = active_bg,
        .header_names = .{ .custom = &.{ "PID", "COMMAND", "STATE", "UTIME", "STIME", "PRIORITY", "NICE", "THREADS", "RSS", "VSIZE" } },
        .header_borders = true,
    };
    defer if (tbl.sel_rows) |rows| gpa.free(rows);

    var last_update: i64 = 0;
    var prev_stats = CpuStats{};
    var mem_unit = MemoryUnit.MB;

    var event_arena: std.heap.ArenaAllocator = .init(gpa);
    defer event_arena.deinit();

    while (true) {
        defer _ = event_arena.reset(.retain_capacity);
        const event_alloc = event_arena.allocator();

        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) return;
                    if (key.matches('e', .{})) mem_unit = mem_unit.next();
                },
                .winsize => |ws| try vx.resize(gpa, tty_writer, ws),
            }
        }
        const now: i64 = time.milliTimestamp();

        if (now - last_update >= 1000) {
            last_update = now;

            const win = vx.window();
            win.clear();

            // Header
            // current time and up time
            const instant = try zeit.instant(.{});
            const local = try zeit.local(gpa, null);
            defer local.deinit();

            const now_local = instant.in(&local);
            const dt = now_local.time();

            const uptime: Uptime = try .readUptime();
            const uptime_header: []u8 = try fmt.allocPrint(gpa, "ztop - {d:0>2}:{d:0>2}:{d:0>2} | uptime: {d:0>2}:{d:0>2}", .{ dt.hour, dt.minute, dt.second, uptime.hours, uptime.minutes });
            defer gpa.free(uptime_header);

            var row: u16 = 0;
            _ = win.printSegment(.{ .text = uptime_header, .style = .{ .fg = .{ .index = 6 }, .bold = true } }, .{ .row_offset = row });
            row += 1;

            // get load avg
            const ld: [3]f64 = try getLoadAvg();
            const load_avg: []u8 = try fmt.allocPrint(gpa, "load avg: {d:.2}, {d:.2}, {d:.2}", .{ ld[0], ld[1], ld[2] });
            defer gpa.free(load_avg);

            _ = win.printSegment(.{ .text = load_avg, .style = .{ .fg = .{ .index = 6 }, .bold = true } }, .{ .row_offset = row });
            row += 1;

            // cpu stats
            const cpu_stats = try CpuStats.readCpuStat();

            const user_diff = cpu_stats.user - prev_stats.user;
            const system_diff = cpu_stats.system - prev_stats.system;
            const nice_diff = cpu_stats.nice - prev_stats.nice;
            const idle_diff = cpu_stats.idle - prev_stats.idle;
            const iowait_diff = cpu_stats.iowait - prev_stats.iowait;
            const irq_diff = cpu_stats.irq - prev_stats.irq;
            const softirq_diff = cpu_stats.softirq - prev_stats.softirq;
            const steal_diff = cpu_stats.steal - prev_stats.steal;
            const total_diff = user_diff + system_diff + nice_diff + idle_diff + iowait_diff + irq_diff + softirq_diff + steal_diff;

            const user_pct = (user_diff / total_diff) * 100.0;
            const sys_pct = (system_diff / total_diff) * 100.0;
            const nice_pct = (nice_diff / total_diff) * 100.0;
            const idle_pct = (idle_diff / total_diff) * 100.0;
            const iowait_pct = (iowait_diff / total_diff) * 100.0;
            const irq_pct = (irq_diff / total_diff) * 100.0;
            const softirq_pct = (softirq_diff / total_diff) * 100.0;
            const steal_pct = (steal_diff / total_diff) * 100.0;

            const cpu_stat = try std.fmt.allocPrint(gpa, "% Cpu: {d:.1} us, {d:.1} sy, {d:.1} ni, {d:.1} id, {d:.1} wa, {d:.1} hi, {d:.1} si, {d:.1} st", .{ user_pct, sys_pct, nice_pct, idle_pct, iowait_pct, irq_pct, softirq_pct, steal_pct });
            defer gpa.free(cpu_stat);

            _ = win.printSegment(.{ .text = cpu_stat, .style = .{ .fg = .{ .index = 6 }, .bold = true } }, .{ .row_offset = row });

            prev_stats = cpu_stats;
            row += 1;

            // meminfo
            const mem_stats: MemInfo = try .readMemStats();
            const used: u64 = mem_stats.total - mem_stats.available;

            var tbuff: [32]u8 = undefined;
            var fbuff: [32]u8 = undefined;
            var abuff: [32]u8 = undefined;
            var ubuff: [32]u8 = undefined;

            const total = try formatMem(mem_unit, &tbuff, mem_stats.total);
            const free = try formatMem(mem_unit, &fbuff, mem_stats.free);
            const used_str = try formatMem(mem_unit, &ubuff, used);
            const available = try formatMem(mem_unit, &abuff, mem_stats.available);

            const mem_info: []u8 = try fmt.allocPrint(gpa, "Memory: {s} Total, {s} Free, {s} Used, {s} Available", .{ total, free, used_str, available });
            defer gpa.free(mem_info);

            _ = win.printSegment(.{ .text = mem_info, .style = .{ .fg = .{ .index = 6 }, .bold = true } }, .{ .row_offset = row });
            row += 2;

            // Process listing
            var processess = try Process.listProcess(gpa);
            defer {
                for (processess.items(.name)) |*name| {
                    gpa.free(name.*);
                }
                processess.deinit(gpa);
            }

            const table_height = if (win.height > row + 3) win.height - row - 3 else 10;
            const table_win = win.child(.{
                .x_off = 0,
                .y_off = row,
                .width = win.width,
                .height = table_height,
            });
            try vaxis.widgets.Table.drawTable(event_alloc, table_win, processess, &tbl);

            row += table_height;

            // Footer
            if (win.height > 2) {
                const footer_row = win.height - 2;
                _ = win.printSegment(.{ .text = "Press 'q' to quit, 'e' to toggle memory units", .style = .{ .fg = .{ .index = 8 } } }, .{ .row_offset = footer_row });
            }

            try vx.render(tty_writer);
        }
        std.Thread.sleep(100 * time.ns_per_ms);
    }
    tty_writer.flush();
}
