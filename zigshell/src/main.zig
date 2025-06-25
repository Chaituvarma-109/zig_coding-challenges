const std: type = @import("std");
const clib = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
});

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const redirect_syms = [6][]const u8{ ">", "1>", "2>", ">>", "1>>", "2>>" };
const builtins = [_][]const u8{ "exit", "ls", "pwd", "cd", "history" };
var completion_path: ?[]const u8 = null;
var home: ?[]const u8 = null;

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

// fn runExternalCmd(alloc: std.mem.Allocator, cmd: []const u8, argv: [][]const u8) !void {
//     if (try typeBuilt(alloc, cmd)) |p| {
//         try restoreDefaultSignalHandlers();
//         var res = std.process.Child.init(argv, alloc);
//         res.stdin_behavior = .Inherit;
//         res.stdout_behavior = .Inherit;
//         res.stderr_behavior = .Inherit;

//         if (outf) |file| {
//             res.stdout_behavior = .Pipe;
//             try res.spawn();

//             try file.writeFileAllUnseekable(res.stdout.?, .{});
//         } else if (errf) |file| {
//             res.stderr_behavior = .Pipe;

//             try res.spawn();

//             try file.writeFileAllUnseekable(res.stderr.?, .{});
//         } else {
//             res.stdout_behavior = .Inherit;

//             try res.spawn();
//         }
//         _ = try res.wait();
//         try setupSignalHandlers();
//     } else {
//         try stdout.print("{s}: command not found\n", .{cmd});
//     }
// }

fn typeBuilt(alloc: std.mem.Allocator, args: []const u8) !?[]const u8 {
    var folders = std.mem.tokenizeAny(u8, completion_path.?, ":");

    while (folders.next()) |folder| {
        const full_path = try std.fs.path.join(alloc, &[_][]const u8{ folder, args });
        std.fs.accessAbsolute(full_path, .{ .mode = .read_only }) catch {
            defer alloc.free(full_path);
            continue;
        };
        return full_path;
    }

    return null;
}

fn parseCommand(alloc: std.mem.Allocator, cmd_str: []const u8) ![][]const u8 {
    var args = std.ArrayList([]const u8).init(alloc);
    errdefer {
        for (args.items) |item| {
            alloc.free(item);
        }
        args.deinit();
    }

    var tokens_iter = std.mem.tokenizeScalar(u8, cmd_str, ' ');
    while (tokens_iter.next()) |token| {
        const arg_copy = try alloc.dupe(u8, token);
        try args.append(arg_copy);
    }

    return args.toOwnedSlice();
}

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

    for (commands.items, 0..) |cmd_str, i| {
        const args = try parseCommand(alloc, cmd_str);
        defer {
            for (args) |arg| {
                alloc.free(arg);
            }
            alloc.free(args);
        }

        if (args.len == 0) continue;
        const cmd = args[0];

        // Check if this is a builtin command
        var is_builtin = false;
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
    var arg = argv[1];
    if (std.mem.eql(u8, argv[1], "~")) {
        arg = home orelse "";
    }
    std.posix.chdir(arg) catch {
        try stdout.print("{s}: No such file or directory\n", .{arg});
    };
}

fn handlePwd() !void {
    var buff: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.process.getCwd(&buff);
    try stdout.print("{s}\n", .{cwd});
}

fn parse_inp(alloc: std.mem.Allocator, inp: []const u8) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).init(alloc);
    defer tokens.deinit();

    var pos: usize = 0;

    while (pos < inp.len) {
        if (inp[pos] == ' ') {
            pos += 1;
            continue;
        }

        var token = std.ArrayList(u8).init(alloc);
        defer token.deinit();
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
                        try token.append(inp[pos]);
                        pos += 1;
                    }
                    if (pos < inp.len) pos += 1;
                },
                '\\' => {
                    try token.append(inp[pos + 1]);
                    pos += 2;
                },
                else => {
                    try token.append(inp[pos]);
                    pos += 1;
                },
            }
        }
        if (token.items.len > 0) {
            try tokens.append(try token.toOwnedSlice());
        }
    }

    return tokens.toOwnedSlice();
}

fn completion(text: [*c]const u8, start: c_int, _: c_int) callconv(.c) [*c][*c]u8 {
    var matches: [*c][*c]u8 = null;

    if (start == 0) {
        matches = clib.rl_completion_matches(text, &custom_completion);
    }
    return matches;
}

fn custom_completion(text: [*c]const u8, state: c_int) callconv(.c) [*c]u8 {
    // Static variables to maintain state between calls
    const static = struct {
        var completion_index: usize = 0;
        var text_len: usize = 0;
        var checking_builtins: bool = true;
        var path_iterator: ?std.mem.TokenIterator(u8, .scalar) = null;
        var dir_iterator: ?std.fs.Dir.Iterator = null;
        var has_dir_iterator: bool = false;
        var current_dir: ?std.fs.Dir = null;
    };

    // Reset state when starting new completion
    if (state == 0) {
        static.completion_index = 0;
        static.text_len = std.mem.len(text);
        static.checking_builtins = true;
        static.path_iterator = null;
        static.has_dir_iterator = false;
        static.current_dir = null;
    }

    const txt = text[0..static.text_len];

    // First check built-in commands
    if (static.checking_builtins) {
        while (static.completion_index < builtins.len) {
            const builtin_name = builtins[static.completion_index];
            static.completion_index += 1;

            if (std.mem.startsWith(u8, builtin_name, txt)) {
                return clib.strdup(builtin_name.ptr);
            }
        }
        // Done with builtins, now check PATH
        static.checking_builtins = false;
        static.completion_index = 0;
        if (completion_path) |path| {
            static.path_iterator = std.mem.tokenizeScalar(u8, path, ':');
        }
    }

    // Check executables in PATH directories
    while (static.path_iterator != null) {
        // If no directory is currently being searched, open the next one
        if (!static.has_dir_iterator) {
            if (static.path_iterator.?.next()) |path_dir| {
                // Try to open the directory
                static.current_dir = std.fs.openDirAbsolute(path_dir, .{ .iterate = true }) catch continue; // Skip invalid directories

                static.dir_iterator = static.current_dir.?.iterate();
                static.has_dir_iterator = true;
            } else {
                break; // No more directories in PATH
            }
        }

        // Search current directory for matching files
        if (static.has_dir_iterator) {
            while (static.dir_iterator.?.next() catch null) |entry| {
                // Only consider regular files
                if (entry.kind == .file) {
                    if (std.mem.startsWith(u8, entry.name, txt)) {
                        return clib.strdup(entry.name.ptr);
                    }
                }
            }
            // Finished with this directory
            static.has_dir_iterator = false;
        }
    }

    // Clean up when no more matches
    static.current_dir = null;

    return null;
}

fn handleHistory(arg: [][]const u8) !void {
    const hst_len = clib.history_length;

    if (arg.len > 0) {
        const limit = std.fmt.parseInt(c_int, arg[1], 10) catch {
            try stdout.print("Invalid limit: {s}\n", .{arg[1]});
            return;
        };

        if (limit <= 0) return;
        const start_ind = @max(1, hst_len - limit + 1);
        try handleLoop(start_ind, hst_len);
    } else {
        try handleLoop(0, hst_len);
    }
}

fn handleLoop(i: c_int, hst_len: c_int) !void {
    var j = i;
    while (j <= hst_len) : (j += 1) {
        const entry = clib.history_get(j);
        if (entry != null) {
            const line = entry.*.line;
            if (line != null) {
                try stdout.print("{d:>5}  {s}\n", .{ @as(u32, @intCast(j)), line });
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc: std.mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    try setupSignalHandlers();

    home = std.posix.getenv("HOME");
    const home_path = try alloc.dupe(u8, home.?);
    defer alloc.free(home_path);
    const hst_path = try std.fs.path.join(alloc, &.{ home_path, ".shell_history" });
    defer alloc.free(hst_path);

    std.posix.access(hst_path, 0) catch {
        const file: std.fs.File = try std.fs.cwd().createFile(hst_path, .{ .read = true });
        file.close();
    };

    clib.using_history();
    _ = clib.read_history(hst_path.ptr);
    defer clib.clear_history();

    completion_path = std.posix.getenv("PATH");
    clib.rl_attempted_completion_function = &completion;

    while (true) {
        const line = clib.readline("ccshell> ");
        defer clib.free(line);
        const ln_len = std.mem.len(line);
        const user_input: []u8 = line[0..ln_len];

        const trim_inp: []const u8 = std.mem.trim(u8, user_input, "\r\n");
        clib.add_history(line);
        _ = clib.write_history(hst_path.ptr);

        if (std.mem.count(u8, trim_inp, "|") > 0) {
            try executePipeCmds(alloc, trim_inp);
            continue;
        }

        const parsed_cmds: [][]const u8 = try parse_inp(alloc, trim_inp); // { echo, Hello Maria, 1>, /tmp/foo/baz.md }
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
                if (cm.len == 2) {
                    target = cm[0] - '0';
                }
                break;
            }
        }

        var outf: ?std.fs.File = null;
        var errf: ?std.fs.File = null;
        var out = stdout;
        var argv = parsed_cmds;

        if (index) |ind| {
            argv = parsed_cmds[0..ind];
            if (target == 1) {
                outf = try std.fs.cwd().createFile(parsed_cmds[ind + 1], .{ .truncate = !append });

                if (outf) |file| {
                    if (append) try file.seekFromEnd(0);
                    out = file.writer();
                }
            } else if (target == 2) {
                errf = try std.fs.cwd().createFile(parsed_cmds[ind + 1], .{ .truncate = !append });
                if (errf) |file| {
                    if (append) try file.seekFromEnd(0);
                }
            }
        }

        defer {
            if (outf) |file| file.close();
            if (errf) |file| file.close();
        }

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
                try out.print("{s} ", .{arg});
            }
            try out.print("{s}\n", .{argv[argv.len - 1]});
        } else if (std.mem.eql(u8, cmd, "history")) {
            try handleHistory(argv);
        } else {
            if (try typeBuilt(alloc, cmd)) |_| {
                try restoreDefaultSignalHandlers();
                var res = std.process.Child.init(argv, alloc);
                res.stdin_behavior = .Inherit;
                res.stdout_behavior = .Inherit;
                res.stderr_behavior = .Inherit;

                if (outf) |file| {
                    res.stdout_behavior = .Pipe;
                    try res.spawn();

                    try file.writeFileAllUnseekable(res.stdout.?, .{});
                } else if (errf) |file| {
                    res.stderr_behavior = .Pipe;

                    try res.spawn();

                    try file.writeFileAllUnseekable(res.stderr.?, .{});
                } else {
                    res.stdout_behavior = .Inherit;

                    try res.spawn();
                }
                _ = try res.wait();
                try setupSignalHandlers();
            } else {
                try stdout.print("{s}: command not found\n", .{cmd});
            }
        }
    }
}
