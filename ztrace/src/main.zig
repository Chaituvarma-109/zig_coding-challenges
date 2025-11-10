const std = @import("std");
const c = @cImport({
    @cInclude("x86_64-linux-gnu/sys/user.h");
});
const syscall = @import("syscallmappings.zig");
const callargs = @import("syscallargs.zig");

const posix = std.posix;
const linux = std.os.linux;

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
            const err = std.process.execv(gpa, external_process);
            std.debug.print("err: {}\n", .{err});
            return;
        },
        else => {
            var status: u32 = 0;
            _ = linux.waitpid(pid, &status, 0);
            _ = linux.ptrace(linux.PTRACE.SETOPTIONS, pid, 0, linux.PTRACE.O.TRACESYSGOOD, 0);

            var curr_syscall: i64 = 0;
            var ret_val: i64 = undefined;
            var in_syscall: bool = false;
            var syscall_args: [6]u64 = undefined;
            var entry_regs: c.user_regs_struct = undefined;

            while (true) {
                _ = linux.ptrace(linux.PTRACE.SYSCALL, pid, 0, 0, 0);
                _ = linux.waitpid(pid, &status, 0);
                if (linux.W.IFEXITED(status)) {
                    const exit_code = linux.W.EXITSTATUS(status);
                    std.debug.print("++ exited with {d} ++\n", .{exit_code});
                    break;
                }

                if (linux.W.IFSIGNALED(status)) break;

                if (linux.W.IFSTOPPED(status)) {
                    const sig: u32 = linux.W.STOPSIG(status);

                    const t: u32 = @intCast(@intFromEnum(linux.SIG.TRAP) | 0x80);

                    if (sig != @intFromEnum(linux.SIG.TRAP) and sig != t) {
                        _ = linux.ptrace(linux.PTRACE.SYSCALL, pid, 0, @intCast(sig), 0);
                        continue;
                    }

                    var regs: c.user_regs_struct = undefined;
                    if (linux.ptrace(linux.PTRACE.GETREGS, pid, 0, @intFromPtr(&regs), 0) == -1) continue;

                    if (!in_syscall) {
                        curr_syscall = @intCast(regs.orig_rax);
                        ret_val = @bitCast(regs.rax);
                        syscall_args = getSysCallArgs(regs);
                        entry_regs = regs;

                        const syscall_name: []const u8 = syscall.getSysCallName(curr_syscall);
                        std.debug.print("[{s}] (", .{syscall_name});

                        in_syscall = true;
                    } else {
                        try callargs.printSysArgs(gpa, pid, syscall_args, curr_syscall);
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
                        in_syscall = false;
                    }
                }
            }
        },
    }
}

fn getSysCallArgs(regs: c.user_regs_struct) [6]u64 {
    return switch (@import("builtin").cpu.arch) {
        .x86_64 => [6]u64{
            regs.rdi,
            regs.rsi,
            regs.rdx,
            regs.r10,
            regs.r8,
            regs.r9,
        },
        .aarch64 => [6]u64{
            regs.regs[0],
            regs.regs[1],
            regs.regs[2],
            regs.regs[3],
            regs.regs[4],
            regs.regs[5],
        },
        else => [6]u64{ 0, 0, 0, 0, 0, 0 },
    };
}
