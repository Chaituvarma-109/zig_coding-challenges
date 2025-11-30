const std = @import("std");
const syscall = @import("syscallmappings.zig");
const callargs = @import("syscallargs.zig");

const posix = std.posix;
const linux = std.os.linux;

const ptrace_syscall_info = extern struct {
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

const SyscallStats = struct {
    calls: u64 = 0,
    errors: u64 = 0,
    total_time: u64 = 0,
};

pub fn main() !void {
    var alloc: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer alloc.deinit();
    const gpa: std.mem.Allocator = alloc.allocator();

    const args = try std.process.argsAlloc(gpa);

    std.debug.assert(args.len >= 2);

    var get_stat: [:0]u8 = undefined;
    var print_stat: bool = false;
    var external_process: [][:0]u8 = undefined;

    if (std.mem.eql(u8, args[1], "-c")) {
        get_stat = args[1];
        print_stat = true;
        external_process = args[2..];
    } else {
        external_process = args[1..];
    }

    const pid = try posix.fork();

    switch (pid) {
        -1 => {
            std.debug.print("strace error pid: {}\n", .{pid});
            return;
        },
        0 => {
            _ = linux.ptrace(linux.PTRACE.TRACEME, pid, 0, 0, 0);
            _ = linux.kill(linux.getpid(), linux.SIG.STOP);
            return std.process.execv(gpa, external_process);
        },
        else => {
            var status: u32 = 0;
            _ = linux.waitpid(pid, &status, 0);
            _ = linux.ptrace(linux.PTRACE.SETOPTIONS, pid, 0, linux.PTRACE.O.TRACESYSGOOD, 0);

            var curr_syscall: i64 = 0;
            var ret_val: i64 = undefined;
            var syscall_args: [6]u64 = undefined;

            var stats_map: std.AutoHashMap(i64, SyscallStats) = .init(gpa);
            defer stats_map.deinit();
            var entry_time: std.time.Instant = undefined;

            while (true) {
                _ = linux.ptrace(linux.PTRACE.SYSCALL, pid, 0, 0, 0);
                _ = linux.waitpid(pid, &status, 0);

                if (linux.W.IFEXITED(status)) break;
                if (linux.W.IFSIGNALED(status)) break;

                if (linux.W.IFSTOPPED(status)) {
                    const sig: u32 = linux.W.STOPSIG(status);

                    const t: u32 = @intCast(@intFromEnum(linux.SIG.TRAP) | 0x80);

                    if (sig != @intFromEnum(linux.SIG.TRAP) and sig != t) {
                        _ = linux.ptrace(linux.PTRACE.CONT, pid, 0, @intCast(sig), 0);
                    }

                    const syscall_info: *ptrace_syscall_info = try gpa.create(ptrace_syscall_info);
                    defer gpa.destroy(syscall_info);

                    _ = linux.ptrace(linux.PTRACE.GET_SYSCALL_INFO, pid, @sizeOf(ptrace_syscall_info), @intFromPtr(syscall_info), 0);

                    if (syscall_info.isEntry()) {
                        curr_syscall = @intCast(syscall_info.data.entry.nr);
                        syscall_args = syscall_info.data.entry.args;
                        entry_time = try .now();

                        if (!print_stat) {
                            const syscall_name: []const u8 = syscall.getSysCallName(curr_syscall);
                            std.debug.print("[{s}] (", .{syscall_name});
                            try callargs.printSysArgs(gpa, pid, syscall_args, curr_syscall);
                        }
                    } else if (syscall_info.isExit()) {
                        ret_val = syscall_info.data.exit.rval;
                        var exit_time: std.time.Instant = try .now();

                        const duration: u64 = exit_time.since(entry_time);

                        // Update statistics
                        var stats: SyscallStats = stats_map.get(curr_syscall) orelse .{};
                        stats.calls += 1;
                        stats.total_time +%= duration;
                        if (ret_val < 0 and ret_val > -4096) {
                            stats.errors += 1;
                        }
                        try stats_map.put(curr_syscall, stats);

                        if (!print_stat) {
                            const err_name: []const u8 = syscall.getErrorName(ret_val);
                            const err_desc: []const u8 = syscall.getErrorDescription(ret_val);

                            if (ret_val < 0 and ret_val > -4096) {
                                if (err_name.len > 0) {
                                    if (err_desc.len > 0) {
                                        std.debug.print(") = {d} {s} ({s})\n", .{ ret_val, err_name, err_desc });
                                    } else {
                                        std.debug.print(") = {d} {s}\n", .{ ret_val, err_name });
                                    }
                                } else {
                                    std.debug.print(") = {d}\n", .{ret_val});
                                }
                            } else {
                                if (curr_syscall == @intFromEnum(linux.SYS.mmap) or curr_syscall == @intFromEnum(linux.SYS.brk)) {
                                    std.debug.print(") = 0x{x}\n", .{@as(u64, @bitCast(ret_val))});
                                } else {
                                    std.debug.print(") = {d}\n", .{ret_val});
                                }
                            }
                        }
                    }
                }
            }
            if (print_stat) {
                try displaystat(gpa, &stats_map);
            }
        },
    }
}

fn displaystat(gpa: std.mem.Allocator, stats_map: *std.AutoHashMap(i64, SyscallStats)) !void {
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
    std.debug.print("% time     seconds  usecs/call     calls    errors syscall\n", .{});
    std.debug.print("------ ----------- ----------- --------- --------- ----------------\n", .{});

    // Print each syscall
    for (entries.items) |entry| {
        const syscall_name: []const u8 = syscall.getSysCallName(entry.syscall_num);
        const seconds: f64 = @as(f64, @floatFromInt(entry.stats.total_time)) / 1_000_000_000.0;
        const usecs_per_call: u64 = if (entry.stats.calls > 0) entry.stats.total_time / (entry.stats.calls * 1000) else 0;
        const time_percent: f64 = if (total_time > 0) (@as(f64, @floatFromInt(entry.stats.total_time)) / @as(f64, @floatFromInt(total_time))) * 100.0 else 0.0;

        if (entry.stats.errors > 0) {
            std.debug.print("{d:6.2} {d:11.6} {d:11} {d:9} {d:9} {s}\n", .{
                time_percent,
                seconds,
                usecs_per_call,
                entry.stats.calls,
                entry.stats.errors,
                syscall_name,
            });
        } else {
            std.debug.print("{d:6.2} {d:11.6} {d:11} {d:9}           {s}\n", .{
                time_percent,
                seconds,
                usecs_per_call,
                entry.stats.calls,
                syscall_name,
            });
        }
    }

    // Print footer
    std.debug.print("------ ----------- ----------- --------- --------- ----------------\n", .{});
    const total_seconds: f64 = @as(f64, @floatFromInt(total_time)) / 1_000_000_000.0;
    const total_usecs_per_call: u64 = if (total_calls > 0) total_time / (total_calls * 1000) else 0;
    if (total_errors > 0) {
        std.debug.print("100.00 {d:11.6} {d:11} {d:9} {d:9} total\n", .{ total_seconds, total_usecs_per_call, total_calls, total_errors });
    } else {
        std.debug.print("100.00 {d:11.6} {d:11} {d:9}           total\n", .{ total_seconds, total_usecs_per_call, total_calls });
    }
}
