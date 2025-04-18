const std: type = @import("std");

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const hst_path: []const u8 = ".shell_history";

fn sigintHandler(sig: c_int) callconv(.C) void {
    _ = sig;
    stdout.print("\nccshell> ", .{}) catch {};
}

fn setupSignalHandlers() !void {
    // Set up our custom SIGINT handler
    const act = std.posix.Sigaction{ // std.os.linux.Sigaction
        .handler = .{ .handler = sigintHandler },
        .mask = std.posix.empty_sigset, // std.os.linux.empty_sigset
        .flags = std.os.linux.SA.RESTART, // 0
    };

    // Install our handler and save the original one
    _ = std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

fn restoreDefaultSignalHandlers() !void {
    // Use SIG_DFL (default handler)
    const act = std.posix.Sigaction{ // std.os.linux.Sigaction
        .handler = .{ .handler = std.posix.SIG.DFL }, // std.os.linux.SIG.DFL
        .mask = std.posix.empty_sigset, // std.os.linux.empty_sigset
        .flags = std.os.linux.SA.RESTART, // 0
    };

    _ = std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

fn runExternalCmd(alloc: std.mem.Allocator, cmd: []const u8, args: []const u8) !void {
    if (try typeBuilt(alloc, cmd)) |p| {
        defer alloc.free(p);

        try restoreDefaultSignalHandlers();
        const res: std.process.Child.RunResult = try std.process.Child.run(.{ .allocator = alloc, .argv = &[_][]const u8{ p, args } });
        try setupSignalHandlers();

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

    const buff: []u8 = try std.fs.cwd().readFileAlloc(alloc, hst_path, std.math.maxInt(usize));
    defer alloc.free(buff);
    var splitIterator = std.mem.splitScalar(u8, buff, '\n');

    while (splitIterator.next()) |line| {
        try lines.append(line);
    }

    return lines;
}

fn parseCommand(alloc: std.mem.Allocator, command_str: []const u8) ![][]const u8 {
    var args = std.ArrayList([]const u8).init(alloc);
    errdefer {
        for (args.items) |item| {
            alloc.free(item);
        }
        args.deinit();
    }

    var tokens_iter = std.mem.tokenizeScalar(u8, command_str, ' ');
    while (tokens_iter.next()) |token| {
        const arg_copy = try alloc.dupe(u8, token);
        try args.append(arg_copy);
    }

    return args.toOwnedSlice();
}
// cat test.txt | wc -l
fn executePipeCmds(alloc: std.mem.Allocator, inp: []const u8) !void {
    var commands = std.ArrayList([]const u8).init(alloc);
    defer commands.deinit();

    var cmd_iter = std.mem.splitScalar(u8, inp, '|');
    while (cmd_iter.next()) |cmd| {
        const trimmed_cmd = std.mem.trim(u8, cmd, " \t\r\n");
        try commands.append(trimmed_cmd);
    }

    if (commands.items.len == 0) return;

    try restoreDefaultSignalHandlers();
    defer setupSignalHandlers() catch {};

    // Multiple commands with pipes
    const pipes_count = commands.items.len - 1;
    var pipes = try alloc.alloc([2]std.posix.fd_t, pipes_count);
    defer alloc.free(pipes);

    // Create all pipes
    for (0..pipes_count) |i| {
        const new_pipe = try std.posix.pipe();
        pipes[i][0] = new_pipe[0];
        pipes[i][1] = new_pipe[1];
    }

    var pids = try alloc.alloc(std.posix.pid_t, commands.items.len);
    defer alloc.free(pids);

    // Create all child processes
    for (commands.items, 0..) |cmd_str, i| {
        const pid = try std.posix.fork();

        if (pid == 0) {
            // Child process

            // Set up pipes
            if (i == 0) {
                // First command: close all read ends, and set up stdout
                for (0..pipes_count) |j| {
                    if (j != i) {
                        std.posix.close(pipes[j][1]);
                    }
                    std.posix.close(pipes[j][0]);
                }

                // Redirect stdout to write end of pipe
                std.posix.dup2(pipes[i][1], std.posix.STDOUT_FILENO) catch unreachable;
                std.posix.close(pipes[i][1]);
            } else if (i == commands.items.len - 1) {
                // Last command: close all write ends, set up stdin
                for (0..pipes_count) |j| {
                    std.posix.close(pipes[j][1]);
                    if (j != i - 1) {
                        std.posix.close(pipes[j][0]);
                    }
                }

                // Redirect stdin to read end of previous pipe
                std.posix.dup2(pipes[i - 1][0], std.posix.STDIN_FILENO) catch unreachable;
                std.posix.close(pipes[i - 1][0]);
            } else {
                // Middle command: set up stdin from previous, stdout to next
                for (0..pipes_count) |j| {
                    if (j != i) {
                        std.posix.close(pipes[j][1]);
                    }
                    if (j != i - 1) {
                        std.posix.close(pipes[j][0]);
                    }
                }

                // Redirect stdin from previous pipe
                std.posix.dup2(pipes[i - 1][0], std.posix.STDIN_FILENO) catch unreachable;
                std.posix.close(pipes[i - 1][0]);

                // Redirect stdout to next pipe
                std.posix.dup2(pipes[i][1], std.posix.STDOUT_FILENO) catch unreachable;
                std.posix.close(pipes[i][1]);
            }

            // Parse and execute the command
            const args: [][]const u8 = parseCommand(alloc, cmd_str) catch |err| {
                std.debug.print("Failed to parse command: {}\n", .{err});
                std.posix.exit(1);
            };

            if (args.len == 0) {
                std.posix.exit(1);
            }

            const exec_error = std.process.execv(alloc, args);
            if (exec_error != error.Success) {
                std.debug.print("execv failed: {}\n", .{exec_error});
                std.posix.exit(1);
            }
        } else {
            // Parent process
            pids[i] = pid;
        }
    }

    // Close all pipe ends in the parent
    for (pipes) |pipe| {
        std.posix.close(pipe[0]);
        std.posix.close(pipe[1]);
    }

    // Wait for all child processes
    for (pids) |pid| {
        const status: u32 = 0;
        _ = std.posix.waitpid(pid, status);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc: std.mem.Allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.debug.print("memory leaked", .{});
        }
    }

    try setupSignalHandlers();

    std.posix.access(hst_path, 0) catch {
        const file: std.fs.File = try std.fs.cwd().createFile(hst_path, .{ .read = true });
        file.close();
    };

    const file: std.fs.File = try std.fs.cwd().openFile(hst_path, .{ .mode = .read_write });
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

        var buffer: [1024]u8 = undefined;
        const user_input: []u8 = stdin.readUntilDelimiter(&buffer, '\n') catch {
            continue;
        };

        const trim_inp: []const u8 = std.mem.trim(u8, user_input, "\r\n");
        try writeToFile(file, trim_inp);

        if (std.mem.count(u8, trim_inp, "|") > 0) {
            try executePipeCmds(alloc, trim_inp);
            continue;
        }

        var cmds_iter = std.mem.tokenizeScalar(u8, trim_inp, ' ');

        const cmd: []const u8 = cmds_iter.next().?;
        var args: []const u8 = cmds_iter.rest();

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
            var buff: [std.fs.max_path_bytes]u8 = undefined;
            const pwd: []u8 = try std.process.getCwd(&buff);

            try stdout.print("{s}\n", .{pwd});
        } else if (std.mem.eql(u8, cmd, "ls")) {
            if (args.len == 0) {
                var dir: std.fs.Dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
                defer dir.close();
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
            const buff: []u8 = try std.fs.cwd().readFileAlloc(alloc, hst_path, std.math.maxInt(usize));
            defer alloc.free(buff);

            try stdout.print("{s}\n", .{buff[0 .. buff.len - 1]});
        } else {
            try runExternalCmd(alloc, cmd, args);
        }
    }
}
