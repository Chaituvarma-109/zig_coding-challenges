const std: type = @import("std");

const redirect_syms: [6][]const u8 = [6][]const u8{ ">", "1>", "2>", ">>", "1>>", "2>>" };
const builtins = [_][]const u8{ "exit", "ls", "pwd", "cd", "history" };
var completion_path: ?[]const u8 = null;
var home: ?[]const u8 = null;

fn sigintHandler(sig: c_int) callconv(.c) void {
    _ = sig;
    std.debug.print("\nccsh> ", .{});
}

fn setupSignalHandlers() !void {
    // Set up custom SIGINT handler
    const act = std.posix.Sigaction{ // std.os.linux.Sigaction
        .handler = .{ .handler = sigintHandler },
        .mask = std.posix.sigemptyset(), // std.os.linux.empty_sigset
        .flags = std.os.linux.SA.RESTART, // 0
    };

    // Install handler and save the original one
    _ = std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

fn restoreDefaultSignalHandlers() !void {
    // Use SIG_DFL (default handler)
    const act = std.posix.Sigaction{ // std.os.linux.Sigaction
        .handler = .{ .handler = std.posix.SIG.DFL }, // std.os.linux.SIG.DFL
        .mask = std.posix.sigemptyset(), // std.os.linux.empty_sigset
        .flags = std.os.linux.SA.RESTART, // 0
    };

    _ = std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

fn typeBuilt(alloc: std.mem.Allocator, args: []const u8) !?[]const u8 {
    var folders = std.mem.tokenizeAny(u8, completion_path.?, ":");

    while (folders.next()) |folder| {
        const full_path: []u8 = try std.fs.path.join(alloc, &[_][]const u8{ folder, args });
        defer alloc.free(full_path);
        std.fs.accessAbsolute(full_path, .{ .mode = .read_only }) catch continue;
        return full_path;
    }

    return null;
}

fn parseCommand(alloc: std.mem.Allocator, cmd_str: []const u8) ![][]const u8 {
    var args: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (args.items) |item| {
            alloc.free(item);
        }
        args.deinit(alloc);
    }

    var tokens_iter = std.mem.tokenizeScalar(u8, cmd_str, ' ');
    while (tokens_iter.next()) |token| {
        const arg_copy: []u8 = try alloc.dupe(u8, token);
        try args.append(alloc, arg_copy);
    }

    return args.toOwnedSlice(alloc);
}

fn executePipeCmds(alloc: std.mem.Allocator, inp: []const u8) !void {
    var commands: std.ArrayList([]const u8) = .empty;
    defer commands.deinit(alloc);

    var cmd_iter = std.mem.splitScalar(u8, inp, '|');
    while (cmd_iter.next()) |cmd| {
        const trimmed_cmd: []const u8 = std.mem.trim(u8, cmd, " \t\r\n");
        try commands.append(alloc, trimmed_cmd);
    }

    if (commands.items.len == 0) return;

    try restoreDefaultSignalHandlers();
    defer setupSignalHandlers() catch {};

    // Multiple commands with pipes
    const pipes_count: usize = commands.items.len - 1;
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

    for (commands.items, 0..) |cmd_str, i| {
        const args: [][]const u8 = try parseCommand(alloc, cmd_str);
        defer {
            for (args) |arg| {
                alloc.free(arg);
            }
            alloc.free(args);
        }

        if (args.len == 0) continue;
        const cmd: []const u8 = args[0];

        // Check if this is a builtin command
        var is_builtin: bool = false;
        for (builtins) |builtin| {
            if (std.mem.eql(u8, builtin, cmd)) {
                is_builtin = true;
                break;
            }
        }

        // Fork a process for both external commands and builtins
        // This ensures consistent pipeline behavior
        const pid = try std.posix.fork();

        if (pid == 0) {
            // Child process

            // Set up input from previous command if not first command
            if (i > 0) {
                try std.posix.dup2(pipes[i - 1][0], std.posix.STDIN_FILENO);
            }

            // Set up output to next command if not last command
            if (i < commands.items.len - 1) {
                try std.posix.dup2(pipes[i][1], std.posix.STDOUT_FILENO);
            }

            // Close all pipe file descriptors in child
            for (0..pipes_count) |j| {
                std.posix.close(pipes[j][0]);
                std.posix.close(pipes[j][1]);
            }

            // Execute the builtin commands
            if (is_builtin) {
                if (std.mem.eql(u8, cmd, "exit")) {
                    try handleExit();
                } else if (std.mem.eql(u8, cmd, "cd")) {
                    try handleCd(args);
                } else if (std.mem.eql(u8, cmd, "pwd")) {
                    try handlePwd();
                }
                std.posix.exit(0);
            } else {
                // Execute external command
                const exec_error = std.process.execv(alloc, args);
                if (exec_error != error.Success) {
                    std.debug.print("execv failed for {s}: {}\n", .{ cmd, exec_error });
                    std.posix.exit(1);
                }
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
        _ = std.posix.waitpid(pid, 0);
    }
}

fn handleExit() !void {
    std.posix.exit(0);
}

fn handleCd(argv: [][]const u8) !void {
    var arg: []const u8 = argv[1];
    if (std.mem.eql(u8, argv[1], "~")) {
        arg = home orelse "";
    }
    std.posix.chdir(arg) catch {
        std.debug.print("{s}: No such file or directory\n", .{arg});
    };
}

fn handlePwd() !void {
    var buff: [std.fs.max_path_bytes]u8 = undefined;
    const cwd: []u8 = try std.process.getCwd(&buff);
    std.debug.print("{s}\n", .{cwd});
}

fn parseInp(alloc: std.mem.Allocator, inp: []const u8) ![][]const u8 {
    var tokens: std.ArrayList([]const u8) = .empty;
    defer tokens.deinit(alloc);

    var pos: usize = 0;

    while (pos < inp.len) {
        if (inp[pos] == ' ') {
            pos += 1;
            continue;
        }

        var token: std.ArrayList(u8) = .empty;
        defer token.deinit(alloc);
        while (pos < inp.len and inp[pos] != ' ') {
            switch (inp[pos]) {
                '\'', '"' => {
                    const quote = inp[pos];
                    pos += 1;

                    while (inp[pos] != quote) {
                        if (quote == '"' and inp[pos] == '\\' and switch (inp[pos + 1]) {
                            '"', '\\', '$', '\n' => true,
                            else => false,
                        }) {
                            pos += 1;
                        }
                        try token.append(alloc, inp[pos]);
                        pos += 1;
                    }
                    if (pos < inp.len) pos += 1;
                },
                '\\' => {
                    try token.append(alloc, inp[pos + 1]);
                    pos += 2;
                },
                else => {
                    try token.append(alloc, inp[pos]);
                    pos += 1;
                },
            }
        }
        if (token.items.len > 0) {
            try tokens.append(alloc, try token.toOwnedSlice(alloc));
        }
    }

    return tokens.toOwnedSlice(alloc);
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const alloc: std.mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var rbuf: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&rbuf);
    const stdin = &stdin_reader.interface;

    var buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);

    var ebuff: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&ebuff);

    try setupSignalHandlers();

    completion_path = std.posix.getenv("PATH");
    home = std.posix.getenv("HOME");

    const hst_path: []u8 = try std.fs.path.join(alloc, &.{ "/tmp", ".shell_history" });
    defer alloc.free(hst_path);

    std.posix.access(hst_path, 0) catch {
        const file: std.fs.File = try std.fs.cwd().createFile(hst_path, .{ .read = true });
        file.close();
    };

    std.debug.print("ccsh> ", .{});
    while (stdin.takeDelimiter('\n')) |line| {
        const ln = line.?;
        if (std.mem.count(u8, ln, "|") > 0) {
            try executePipeCmds(alloc, ln);
            std.debug.print("ccsh> ", .{});
            continue;
        }

        const parsed_cmds: [][]const u8 = try parseInp(alloc, ln); // { echo, Hello Maria, 1>, /tmp/foo/baz.md }
        defer {
            for (parsed_cmds) |cmd| {
                alloc.free(cmd);
            }
            alloc.free(parsed_cmds);
        }

        var index: ?usize = null;
        var target: u8 = 1;
        var append: bool = false;

        for (parsed_cmds, 0..) |cm, i| {
            if (std.mem.eql(u8, cm, ">") or std.mem.eql(u8, cm, "1>") or std.mem.eql(u8, cm, "2>")) {
                index = i;
                if (cm.len == 2) {
                    target = cm[0] - '0';
                }
                break;
            }

            if (std.mem.eql(u8, cm, ">>") or std.mem.eql(u8, cm, "1>>") or std.mem.eql(u8, cm, "2>>")) {
                append = true;
                index = i;

                if (cm.len == 3) {
                    target = cm[0] - '0';
                }
                break;
            }
        }

        var outf: ?std.fs.File = null;
        var errf: ?std.fs.File = null;
        var ebuf: [1024]u8 = undefined;
        var obuff: [1024]u8 = undefined;
        var argv = parsed_cmds;

        if (index) |ind| {
            argv = parsed_cmds[0..ind];
            if (target == 1) {
                outf = try std.fs.cwd().createFile(parsed_cmds[ind + 1], .{ .truncate = !append });

                if (outf) |file| {
                    if (append) try file.seekFromEnd(0);
                    stdout_writer = file.writer(&obuff);
                }
            } else if (target == 2) {
                errf = try std.fs.cwd().createFile(parsed_cmds[ind + 1], .{ .truncate = !append });
                if (errf) |file| {
                    if (append) try file.seekFromEnd(0);
                    stderr_writer = file.writer(&ebuf);
                }
            }
        }

        defer if (outf) |file| file.close();
        defer if (errf) |file| file.close();

        const cmd: []const u8 = argv[0];

        if (std.mem.eql(u8, cmd, "exit")) {
            try handleExit();
        } else if (std.mem.eql(u8, cmd, "cd")) {
            try handleCd(argv);
        } else if (std.mem.eql(u8, cmd, "pwd")) {
            try handlePwd();
        } else if (std.mem.eql(u8, cmd, "echo")) {
            if (argv.len < 2) return;
            for (argv[1 .. argv.len - 1]) |arg| {
                try stdout_writer.interface.print("{s} ", .{arg});
            }
            try stdout_writer.interface.print("{s}\n", .{argv[argv.len - 1]});
            try stdout_writer.interface.flush();
        } else if (std.mem.eql(u8, cmd, "history")) {
            // try handleHistory(argv);
        } else {
            if (try typeBuilt(alloc, cmd)) |_| {
                try restoreDefaultSignalHandlers();

                var res = std.process.Child.init(argv, alloc);
                if (outf) |_| {
                    res.stdout_behavior = .Pipe;
                    try res.spawn();

                    var fReader = res.stdout.?.reader(&.{});
                    _ = try stdout_writer.interface.sendFileReading(&fReader, .unlimited);
                } else if (errf) |_| {
                    res.stderr_behavior = .Pipe;
                    try res.spawn();

                    var fReader = res.stderr.?.reader(&.{});
                    _ = try stderr_writer.interface.sendFileReading(&fReader, .unlimited);
                } else {
                    res.stdout_behavior = .Inherit;
                    try res.spawn();
                }
                _ = try res.wait();
                try setupSignalHandlers();
            } else {
                std.debug.print("{s}: command not found\n", .{cmd});
            }
        }
        std.debug.print("ccsh> ", .{});
    } else |err| switch (err) {
        // error.EndOfStream => {},
        else => std.debug.print("err: {}\n", .{err}),
    }
}
