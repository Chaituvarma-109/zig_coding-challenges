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

pub fn main() !void {
    var alloc: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer alloc.deinit();
    const gpa: std.mem.Allocator = alloc.allocator();

    const args = try std.process.argsAlloc(gpa);

    std.debug.assert(args.len >= 2);
    const external_process = args[1..];

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

            while (true) {
                _ = linux.ptrace(linux.PTRACE.SYSCALL, pid, 0, 0, 0);
                _ = linux.waitpid(pid, &status, 0);
                if (linux.W.IFEXITED(status)) {
                    const exit_code = linux.W.EXITSTATUS(status);
                    std.debug.print("\n++ exited with {d} ++\n", .{exit_code});
                    break;
                }

                if (linux.W.IFSIGNALED(status)) break;

                if (linux.W.IFSTOPPED(status)) {
                    const sig: u32 = linux.W.STOPSIG(status);

                    const t: u32 = @intCast(@intFromEnum(linux.SIG.TRAP) | 0x80);

                    if (sig != @intFromEnum(linux.SIG.TRAP) and sig != t) {
                        _ = linux.ptrace(linux.PTRACE.CONT, pid, 0, @intCast(sig), 0);
                    }

                    const syscall_info = try gpa.create(ptrace_syscall_info);
                    defer gpa.destroy(syscall_info);

                    _ = linux.ptrace(linux.PTRACE.GET_SYSCALL_INFO, pid, @sizeOf(ptrace_syscall_info), @intFromPtr(syscall_info), 0);

                    if (syscall_info.isEntry()) {
                        curr_syscall = @intCast(syscall_info.data.entry.nr);
                        syscall_args = syscall_info.data.entry.args;

                        const syscall_name: []const u8 = syscall.getSysCallName(curr_syscall);
                        std.debug.print("[{s}] (", .{syscall_name});
                        try callargs.printSysArgs(gpa, pid, syscall_args, curr_syscall);
                    } else if (syscall_info.isExit()) {
                        ret_val = syscall_info.data.exit.rval;
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
        },
    }
}
