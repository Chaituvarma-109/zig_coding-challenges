const std: type = @import("std");
const syscall: type = @import("syscallmappings.zig");
const callargs: type = @import("syscallargs.zig");

const posix: type = std.posix;
const linux: type = std.os.linux;
const Io: type = std.Io;
const process: type = std.process;

const ptrace_syscall_info: type = extern struct {
    pub const SYSCALL_INFO_ENTRY = 1;
    pub const SYSCALL_INFO_EXIT = 2;

    op: u8, // Type of system call stop
    arch: u32, // AUDIT_ARCH_* value (compiler will add 3 bytes padding before this)
    instruction_pointer: u64, // CPU instruction pointer
    stack_pointer: u64, // CPU stack pointer
    data: extern union {
        entry: extern struct {
            nr: u64, // System call number
            args: [6]u64, // System call arguments
        },
        exit: extern struct {
            rval: i64, // System call return value
            is_error: u8, // System call error flag
        },
        seccomp: extern struct {
            nr: u64, // System call number
            args: [6]u64, // System call arguments
            ret_data: u32, // SECCOMP_RET_DATA
        },
    },

    pub fn isEntry(self: *const ptrace_syscall_info) bool {
        return self.op == SYSCALL_INFO_ENTRY;
    }

    pub fn isExit(self: *const ptrace_syscall_info) bool {
        return self.op == SYSCALL_INFO_EXIT;
    }
};

const SyscallStats: type = struct {
    calls: u64 = 0,
    errors: u64 = 0,
    total_time: u64 = 0,
};

pub fn main(init: std.process.Init) !void {
    var degpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = degpa.deinit();
    const dealloc: std.mem.Allocator = degpa.allocator();

    var alloc: std.heap.ArenaAllocator = .init(dealloc);
    defer alloc.deinit();
    const gpa: std.mem.Allocator = alloc.allocator();

    var io_threaded: Io.Threaded = .init(gpa, .{ .environ = init.minimal.environ });
    defer io_threaded.deinit();
    const io: Io = io_threaded.ioBasic();

    var buff: [1024]u8 = undefined;
    const f: Io.File = .stdout();
    var fwr: Io.File.Writer = f.writer(io, &buff);
    const wr: *Io.Writer = &fwr.interface;

    const args: process.Args = init.minimal.args;
    const ar: []const [:0]const u8 = try args.toSlice(gpa);

    std.debug.assert(ar.len >= 2);

    var get_stat: [:0]const u8 = undefined;
    var print_stat: bool = false;
    var external_process: []const [:0]const u8 = undefined;

    if (std.mem.eql(u8, ar[1], "-c")) {
        get_stat = ar[1];
        print_stat = true;
        external_process = ar[2..];
    } else {
        external_process = ar[1..];
    }

    const pid: std.posix.fd_t = @intCast(linux.fork());

    switch (pid) {
        -1 => {
            try wr.print("strace error pid: {}\n", .{pid});
            try wr.flush();
            return;
        },
        0 => {
            _ = linux.ptrace(linux.PTRACE.TRACEME, pid, 0, 0, 0);
            _ = linux.kill(linux.getpid(), linux.SIG.STOP);
            return std.process.replace(io, .{ .argv = external_process });
        },
        else => {
            var status: u32 = 0;
            _ = linux.waitpid(pid, &status, 0);
            _ = linux.ptrace(linux.PTRACE.SETOPTIONS, pid, 0, linux.PTRACE.O.TRACESYSGOOD, 0);

            var curr_syscall: i64 = 0;

            var stats_map: std.AutoHashMap(i64, SyscallStats) = .init(gpa);
            defer stats_map.deinit();
            var entry_time: std.time.Instant = undefined;

            while (true) {
                _ = linux.ptrace(linux.PTRACE.SYSCALL, pid, 0, 0, 0);
                _ = linux.waitpid(pid, &status, 0);

                if (linux.W.IFEXITED(status) or linux.W.IFSIGNALED(status)) break;

                if (linux.W.IFSTOPPED(status)) {
                    const sig: u32 = linux.W.STOPSIG(status);

                    const t: u32 = @intCast(@intFromEnum(linux.SIG.TRAP) | 0x80);

                    if (sig != @intFromEnum(linux.SIG.TRAP) and sig != t) _ = linux.ptrace(linux.PTRACE.CONT, pid, 0, @intCast(sig), 0);

                    const syscall_info: *ptrace_syscall_info = try gpa.create(ptrace_syscall_info);
                    defer gpa.destroy(syscall_info);

                    _ = linux.ptrace(linux.PTRACE.GET_SYSCALL_INFO, pid, @sizeOf(ptrace_syscall_info), @intFromPtr(syscall_info), 0);

                    if (syscall_info.isEntry()) {
                        curr_syscall = @intCast(syscall_info.data.entry.nr);
                        const syscall_args: [6]u64 = syscall_info.data.entry.args;
                        entry_time = try .now();

                        if (!print_stat) {
                            const syscall_name: []const u8 = syscall.getSysCallName(curr_syscall);
                            try wr.print("[\x1b[33m{s}\x1b[0m] (", .{syscall_name});
                            try wr.flush();
                            try callargs.printSysArgs(gpa, pid, syscall_args, curr_syscall, wr);
                        }
                    } else if (syscall_info.isExit()) {
                        const ret_val: i64 = syscall_info.data.exit.rval;
                        var exit_time: std.time.Instant = try .now();

                        const duration: u64 = exit_time.since(entry_time);

                        // Update statistics
                        var stats: SyscallStats = stats_map.get(curr_syscall) orelse .{};
                        stats.calls += 1;
                        stats.total_time +%= duration;
                        if (ret_val < 0 and ret_val > -4096) stats.errors += 1;
                        try stats_map.put(curr_syscall, stats);

                        if (!print_stat) {
                            const err_name: []const u8 = syscall.getErrorName(ret_val);
                            const err_desc: []const u8 = syscall.getErrorDescription(ret_val);

                            if (ret_val < 0 and ret_val > -4096) {
                                if (err_name.len > 0) {
                                    if (err_desc.len > 0) {
                                        try wr.print(") \x1b[100m=\x1b[0m \x1b[31m{d} {s} ({s})\x1b[0m\n", .{ ret_val, err_name, err_desc });
                                    } else {
                                        try wr.print(") \x1b[100m=\x1b[0m \x1b[31m{d} {s}\x1b[0m\n", .{ ret_val, err_name });
                                    }
                                    try wr.flush();
                                } else {
                                    try wr.print(") \x1b[100m=\x1b[0m \x1b[31m{d}\x1b[0m\n", .{ret_val});
                                    try wr.flush();
                                }
                            } else {
                                if (curr_syscall == @intFromEnum(linux.SYS.mmap) or curr_syscall == @intFromEnum(linux.SYS.brk)) {
                                    try wr.print(") \x1b[100m=\x1b[0m \x1b[35m0x{x}\x1b[0m\n", .{@as(u64, @bitCast(ret_val))});
                                } else {
                                    try wr.print(") \x1b[100m=\x1b[0m \x1b[92m{d}\x1b[0m\n", .{ret_val});
                                }
                                try wr.flush();
                            }
                        }
                    }
                }
            }
            if (print_stat) try displaystat(gpa, &stats_map, wr);
        },
    }
}

fn displaystat(gpa: std.mem.Allocator, stats_map: *std.AutoHashMap(i64, SyscallStats), wr: *std.Io.Writer) !void {
    // Create a list of syscall entries
    var entries: std.ArrayList(struct { syscall_num: i64, stats: SyscallStats }) = .empty;
    defer entries.deinit(gpa);

    var total_time: u64 = 0;
    var total_calls: u64 = 0;
    var total_errors: u64 = 0;

    var it = stats_map.iterator();
    while (it.next()) |entry| {
        try entries.append(gpa, .{ .syscall_num = entry.key_ptr.*, .stats = entry.value_ptr.* });
        total_time +%= entry.value_ptr.total_time;
        total_calls +%= entry.value_ptr.calls;
        total_errors +%= entry.value_ptr.errors;
    }

    // Sort by total time descending
    std.sort.insertion(@TypeOf(entries.items[0]), entries.items, {}, struct {
        fn lessThan(_: void, a: @TypeOf(entries.items[0]), b: @TypeOf(entries.items[0])) bool {
            return a.stats.total_time > b.stats.total_time;
        }
    }.lessThan);

    // Print header
    try wr.print("\n", .{});
    try wr.print("\x1b[33m------ ----------- ----------- --------- --------- ----------------\x1b[0m\n", .{});
    try wr.print("\x1b[33m% time     seconds  usecs/call     calls    errors syscall\x1b[0m\n", .{});
    try wr.print("\x1b[33m------ ----------- ----------- --------- --------- ----------------\x1b[0m\n", .{});
    try wr.flush();

    // Print each syscall
    for (entries.items) |entry| {
        const syscall_name: []const u8 = syscall.getSysCallName(entry.syscall_num);
        const seconds: f64 = @as(f64, @floatFromInt(entry.stats.total_time)) / 1_000_000_000.0;
        const usecs_per_call: u64 = if (entry.stats.calls > 0) entry.stats.total_time / (entry.stats.calls * 1000) else 0;
        const time_percent: f64 = if (total_time > 0) (@as(f64, @floatFromInt(entry.stats.total_time)) / @as(f64, @floatFromInt(total_time))) * 100.0 else 0.0;

        if (entry.stats.errors > 0) {
            try wr.print("{d:6.2} {d:11.6} {d:11} {d:9} {d:9} {s}\n", .{
                time_percent,
                seconds,
                usecs_per_call,
                entry.stats.calls,
                entry.stats.errors,
                syscall_name,
            });
        } else {
            try wr.print("{d:6.2} {d:11.6} {d:11} {d:9}           {s}\n", .{
                time_percent,
                seconds,
                usecs_per_call,
                entry.stats.calls,
                syscall_name,
            });
        }
        try wr.flush();
    }

    // Print footer
    try wr.print("\x1b[33m------ ----------- ----------- --------- --------- ----------------\x1b[0m\n", .{});
    const total_seconds: f64 = @as(f64, @floatFromInt(total_time)) / 1_000_000_000.0;
    const total_usecs_per_call: u64 = if (total_calls > 0) total_time / (total_calls * 1000) else 0;
    if (total_errors > 0) {
        try wr.print("\x1b[36m100.00 {d:11.6} {d:11} {d:9} {d:9} total\x1b[0m\n", .{ total_seconds, total_usecs_per_call, total_calls, total_errors });
    } else {
        try wr.print("\x1b[36m100.00 {d:11.6} {d:11} {d:9}           total\x1b[0m\n", .{ total_seconds, total_usecs_per_call, total_calls });
    }
    try wr.print("\x1b[33m------ ----------- ----------- --------- --------- ----------------\x1b[0m\n", .{});
    try wr.flush();
}
