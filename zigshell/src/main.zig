const std = @import("std");

const stdout = std.io.getStdOut().writer();
const hst_path: []const u8 = ".shell_history";

fn runExternalCmd(alloc: std.mem.Allocator, cmd: []const u8, args: []const u8) !void {
    if (try typeBuilt(alloc, cmd)) |p| {
        defer alloc.free(p);
        const res = try std.process.Child.run(.{ .allocator = alloc, .argv = &[_][]const u8{ p, args } });
        try stdout.print("{s}", .{res.stdout});
    } else {
        try stdout.print("{s}: command not found\n", .{cmd});
    }
}

fn typeBuilt(alloc: std.mem.Allocator, args: []const u8) !?[]const u8 {
    const env_path = std.posix.getenv("PATH");
    var folders = std.mem.tokenizeAny(u8, env_path.?, ":");

    while (folders.next()) |folder| {
        const full_path = try std.fs.path.join(alloc, &[_][]const u8{ folder, args });
        std.fs.accessAbsolute(full_path, .{ .mode = .read_only }) catch continue;
        return full_path;
    }

    return null;
}

fn writeToFile(file: std.fs.File, cmd: []const u8) !void {
    try file.seekFromEnd(0);
    try file.writeAll(cmd);
    try file.writeAll("\n");
}

fn loadHistory(alloc: std.mem.Allocator) !std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8).init(alloc);
    errdefer lines.deinit();

    const buff = try std.fs.cwd().readFileAlloc(alloc, hst_path, std.math.maxInt(usize));
    defer alloc.free(buff);
    var splitIterator = std.mem.splitScalar(u8, buff, '\n');

    while (splitIterator.next()) |line| {
        try lines.append(line);
    }

    return lines;
}

fn executePipeCmds() !void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    std.posix.access(hst_path, 0) catch {
        const file = try std.fs.cwd().createFile(hst_path, .{ .read = true });
        file.close();
    };

    const file = try std.fs.cwd().openFile(hst_path, .{ .mode = .read_write });
    defer file.close();

    var history = try loadHistory(alloc);
    defer {
        // Free all history strings
        for (history.items) |item| {
            alloc.free(item);
        }
        history.deinit();
    }

    while (true) {
        try stdout.print("ccshell> ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        const trim_inp = std.mem.trim(u8, user_input, "\r\n");
        try writeToFile(file, trim_inp);
        var token_iter = std.mem.tokenizeSequence(u8, trim_inp, "|");

        const cmds = token_iter.next().?;
        const rest_cmds = token_iter.rest();

        if (rest_cmds.len != 0) {
            try executePipeCmds();
        }

        var cmds_iter = std.mem.tokenizeScalar(u8, cmds, ' ');

        const cmd = cmds_iter.next().?;
        var args = cmds_iter.rest();

        if (std.mem.eql(u8, cmd, "exit")) {
            std.posix.exit(0);
        } else if (std.mem.eql(u8, cmd, "cd")) {
            const home: []const u8 = "HOME";
            if (std.mem.eql(u8, args, "~")) {
                args = std.posix.getenv(home) orelse "";
            }
            std.posix.chdir(args) catch {
                try stdout.print("{s}: No such file or directory\n", .{args});
            };
        } else if (std.mem.eql(u8, cmd, "pwd")) {
            var buff: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const pwd = try std.process.getCwd(&buff);

            try stdout.print("{s}\n", .{pwd});
        } else if (std.mem.eql(u8, cmd, "ls")) {
            if (args.len == 0) {
                var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
                var iter = dir.iterate();

                while (try iter.next()) |entry| {
                    if (entry.name.len > 0 and entry.name[0] == '.') {
                        continue;
                    }
                    try stdout.print("{s} ", .{entry.name});
                }
                try stdout.print("\n", .{});
            } else {
                try runExternalCmd(alloc, cmd, args);
            }
        } else if (std.mem.eql(u8, cmd, "history")) {
            const buff = try std.fs.cwd().readFileAlloc(alloc, hst_path, std.math.maxInt(usize));
            defer alloc.free(buff);

            try stdout.print("{s}\n", .{buff});
        } else {
            try runExternalCmd(alloc, cmd, args);
        }
    }
}
