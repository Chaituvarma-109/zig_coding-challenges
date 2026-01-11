const std: type = @import("std");

const mem = std.mem;
const Io = std.Io;
const posix = std.posix;
const linux = std.os.linux;
const process = std.process;

const redirect_syms: [6][]const u8 = [6][]const u8{ ">", "1>", "2>", ">>", "1>>", "2>>" };
const builtins = [_][]const u8{ "exit", "pwd", "cd", "history" };
var completion_path: ?[]const u8 = null;
var home: ?[]const u8 = null;

fn sigintHandler(sig: posix.SIG) callconv(.c) void {
    _ = sig;
    std.debug.print("\nccsh> ", .{});
}

fn setupSignalHandlers() !void {
    // Set up custom SIGINT handler
    const act = posix.Sigaction{ // linux.Sigaction
        .handler = .{ .handler = sigintHandler },
        .mask = posix.sigemptyset(), // linux.empty_sigset
        .flags = linux.SA.RESTART, // 0
    };

    // Install handler and save the original one
    _ = posix.sigaction(posix.SIG.INT, &act, null);
}

fn restoreDefaultSignalHandlers() !void {
    // Use SIG_DFL (default handler)
    const act = posix.Sigaction{ // linux.Sigaction
        .handler = .{ .handler = posix.SIG.DFL }, // linux.SIG.DFL
        .mask = posix.sigemptyset(), // linux.empty_sigset
        .flags = linux.SA.RESTART, // 0
    };

    _ = posix.sigaction(posix.SIG.INT, &act, null);
}

fn typeBuilt(alloc: mem.Allocator, io: Io, args: []const u8) !?[]const u8 {
    var folders = mem.tokenizeAny(u8, completion_path.?, ":");

    while (folders.next()) |folder| {
        const full_path: []u8 = try std.fs.path.join(alloc, &[_][]const u8{ folder, args });
        defer alloc.free(full_path);
        Io.Dir.accessAbsolute(io, full_path, .{ .read = true }) catch continue;
        return try alloc.dupe(u8, folder);
    }

    return null;
}

fn executePipeCmds(alloc: mem.Allocator, io: Io, inp: []const u8) !void {
    var commands: std.ArrayList([]const u8) = .empty;
    defer commands.deinit(alloc);

    var cmd_iter = mem.splitScalar(u8, inp, '|');
    while (cmd_iter.next()) |cmd| {
        const trimmed_cmd: []const u8 = mem.trim(u8, cmd, " \t\r\n");
        try commands.append(alloc, trimmed_cmd);
    }

    if (commands.items.len == 0) return;

    // Multiple commands with pipes
    const pipes_count: usize = commands.items.len - 1;
    var pipes = try alloc.alloc([2]posix.fd_t, pipes_count);
    defer alloc.free(pipes);

    // Create all pipes
    for (0..pipes_count) |i| {
        const new_pipe = try Io.Threaded.pipe2(.{ .CLOEXEC = true });
        pipes[i][0] = new_pipe[0];
        pipes[i][1] = new_pipe[1];
    }

    var pids = try alloc.alloc(posix.pid_t, commands.items.len);
    defer alloc.free(pids);

    for (commands.items, 0..) |cmd_str, i| {
        // changed from parseCommand to parseInp function.
        const args: [][]const u8 = try parseInp(alloc, cmd_str);
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
            if (mem.eql(u8, builtin, cmd)) {
                is_builtin = true;
                break;
            }
        }

        // Fork a process for both external commands and builtins
        // This ensures consistent pipeline behavior
        const pid: i32 = @intCast(linux.fork());

        if (pid == 0) {
            // Child process

            // Set up input from previous command if not first command
            if (i > 0) {
                try Io.Threaded.dup2(pipes[i - 1][0], posix.STDIN_FILENO);
            }

            // Set up output to next command if not last command
            if (i < commands.items.len - 1) {
                try Io.Threaded.dup2(pipes[i][1], posix.STDOUT_FILENO);
            }

            // Close all pipe file descriptors in child
            for (0..pipes_count) |j| {
                posix.close(pipes[j][0]);
                posix.close(pipes[j][1]);
            }

            // Execute the builtin commands
            if (is_builtin) {
                if (mem.eql(u8, cmd, "exit")) try handleExit();
                if (mem.eql(u8, cmd, "cd")) try handleCd(args);
                if (mem.eql(u8, cmd, "pwd")) try handlePwd();
                process.exit(0);
            } else {
                // Execute external command
                const exec_error = std.process.replace(io, .{ .argv = args });
                if (exec_error != error.Success) {
                    std.debug.print("execv failed for {s}: {}\n", .{ cmd, exec_error });
                    process.exit(1);
                }
            }
        } else {
            // Parent process
            pids[i] = pid;
        }
    }

    // Close all pipe ends in the parent
    for (pipes) |pipe| {
        posix.close(pipe[0]);
        posix.close(pipe[1]);
    }

    // Wait for all child processes
    for (pids) |pid| {
        var status: u32 = 0;
        _ = linux.waitpid(pid, &status, 0);
    }
}

fn handleExit() !void {
    process.exit(0);
}

fn handleCd(argv: [][]const u8) !void {
    var arg: []const u8 = argv[1];
    if (mem.eql(u8, argv[1], "~")) {
        arg = home orelse "";
    }
    Io.Threaded.chdir(arg) catch {
        std.debug.print("{s}: No such file or directory\n", .{arg});
    };
}

fn handlePwd() !void {
    var buff: [std.fs.max_path_bytes]u8 = undefined;
    const cwd: []u8 = try process.getCwd(&buff);
    std.debug.print("{s}\n", .{cwd});
}

fn parseInp(alloc: mem.Allocator, inp: []const u8) ![][]const u8 {
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

pub fn main(init: process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const alloc: mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var io_threaded: Io.Threaded = .init(alloc, .{ .environ = init.minimal.environ });
    const io: Io = io_threaded.io();

    var rbuf: [1024]u8 = undefined;
    const stdin_f: Io.File = .stdin();
    var stdin_reader: Io.File.Reader = stdin_f.reader(io, &rbuf);
    const stdin: *Io.Reader = &stdin_reader.interface;

    var buf: [1024]u8 = undefined;
    const stdout_f: Io.File = Io.File.stdout();
    var stdout_writer: Io.File.Writer = stdout_f.writer(io, &buf);

    var ebuff: [1024]u8 = undefined;
    const stderr_f: Io.File = .stderr();
    var stderr_writer: Io.File.Writer = stderr_f.writer(io, &ebuff);

    try setupSignalHandlers();

    completion_path = init.minimal.environ.getPosix("PATH");
    home = init.minimal.environ.getPosix("HOME");

    const hst_path: []u8 = try std.fs.path.join(alloc, &.{ "/tmp", ".shell_history" });
    defer alloc.free(hst_path);

    Io.Dir.access(.cwd(), io, hst_path, .{ .read = true, .write = true }) catch {
        const file: Io.File = try Io.Dir.createFile(.cwd(), io, hst_path, .{ .read = true });
        file.close(io);
    };

    std.debug.print("ccsh> ", .{});
    while (true) {
        const ln: []u8 = try stdin.takeDelimiter('\n') orelse continue;
        if (mem.count(u8, ln, "|") > 0) {
            try executePipeCmds(alloc, io, ln);
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
            if (mem.eql(u8, cm, ">") or mem.eql(u8, cm, "1>") or mem.eql(u8, cm, "2>")) {
                index = i;
                if (cm.len == 2) {
                    target = cm[0] - '0';
                }
                break;
            }

            if (mem.eql(u8, cm, ">>") or mem.eql(u8, cm, "1>>") or mem.eql(u8, cm, "2>>")) {
                append = true;
                index = i;

                if (cm.len == 3) {
                    target = cm[0] - '0';
                }
                break;
            }
        }

        var f: ?Io.File = null;
        // var ebuf: [1024]u8 = undefined;
        // var obuff: [1024]u8 = undefined;
        var buff: [1024]u8 = undefined;
        var argv: [][]const u8 = parsed_cmds;
        var stdout: *Io.Writer = &stdout_writer.interface;
        var stderr: *Io.Writer = &stderr_writer.interface;

        if (index) |ind| {
            argv = parsed_cmds[0..ind];
            f = try Io.Dir.createFile(.cwd(), io, parsed_cmds[ind + 1], .{ .truncate = !append });
            if (f) |file| {
                var fwr = file.writer(io, &buff);
                if (append) try fwr.seekTo(fwr.logicalPos());
                if (target == 1) stdout = &fwr.interface else stderr = &fwr.interface;
            }
            // if (target == 1) {
            //     if (f) |file| {
            //         var fwr = file.writer(io, &obuff);
            //         if (append) try fwr.seekTo(fwr.logicalPos());
            //         stdout = &fwr.interface;
            //     }
            // } else if (target == 2) {
            //     if (f) |file| {
            //         var fwr = file.writer(io, &ebuf);
            //         if (append) try fwr.seekTo(fwr.logicalPos());
            //         stderr = &fwr.interface;
            //     }
            // }
        }

        defer if (f) |file| file.close(io);

        const cmd: []const u8 = argv[0];

        if (mem.eql(u8, cmd, "exit")) {
            try handleExit();
        } else if (mem.eql(u8, cmd, "cd")) {
            try handleCd(argv);
        } else if (mem.eql(u8, cmd, "pwd")) {
            try handlePwd();
        } else if (mem.eql(u8, cmd, "echo")) {
            if (argv.len < 2) return;
            for (argv[1 .. argv.len - 1]) |arg| {
                try stdout_writer.interface.print("{s} ", .{arg});
            }
            try stdout_writer.interface.print("{s}\n", .{argv[argv.len - 1]});
            try stdout_writer.interface.flush();
        } else if (mem.eql(u8, cmd, "history")) {
            // try handleHistory(argv);
        } else {
            if (try typeBuilt(alloc, io, cmd)) |exe_dir| {
                defer alloc.free(exe_dir);
                try restoreDefaultSignalHandlers();

                const res: process.RunResult = try process.run(alloc, io, .{ .argv = argv });

                try stdout.writeAll(res.stdout);
                try stderr.writeAll(res.stderr);

                // if (outf) |_| {
                //     res.stdout_behavior = .Pipe;
                //     try res.spawn();

                //     var fReader = res.stdout.?.reader(&.{});
                //     _ = try stdout_writer.interface.sendFileReading(&fReader, .unlimited);
                // } else if (errf) |_| {
                //     res.stderr_behavior = .Pipe;
                //     try res.spawn();

                //     var fReader = res.stderr.?.reader(&.{});
                //     _ = try stderr_writer.interface.sendFileReading(&fReader, .unlimited);
                // } else {
                //     res.stdout_behavior = .Inherit;
                //     try res.spawn();
                // }
                // _ = try res.wait();
                try setupSignalHandlers();
            } else {
                std.debug.print("{s}: command not found\n", .{cmd});
            }
            try stdout.flush();
            try stderr.flush();
        }
        std.debug.print("ccsh> ", .{});
    }
}
