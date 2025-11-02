const std = @import("std");
const c = @cImport(
    @cInclude("x86_64-linux-gnu/sys/user.h"),
);
const posix = std.posix;

// const UserRegsStruct = extern struct {
//     r15: u64,
//     r14: u64,
//     r13: u64,
//     r12: u64,
//     rbp: u64,
//     rbx: u64,
//     r11: u64,
//     r10: u64,
//     r9: u64,
//     r8: u64,
//     rax: u64,
//     rcx: u64,
//     rdx: u64,
//     rsi: u64,
//     rdi: u64,
//     orig_rax: u64,
//     rip: u64,
//     cs: u64,
//     eflags: u64,
//     rsp: u64,
//     ss: u64,
//     fs_base: u64,
//     gs_base: u64,
//     ds: u64,
//     es: u64,
//     fs: u64,
//     gs: u64,
// };

pub fn main() !void {
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = alloc.deinit();
    const gpa = alloc.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    std.debug.assert(args.len >= 2);
    const external_process = args[1..];

    const pid = try posix.fork();
    if (pid < 0) {
        std.debug.print("strace error pid: {}\n", .{pid});
        return;
    }

    switch (pid) {
        0 => {
            _ = std.os.linux.ptrace(std.os.linux.PTRACE.TRACEME, 0, 0, 0, 0);
            _ = std.os.linux.kill(std.os.linux.getpid(), std.os.linux.SIG.STOP);
            return std.process.execv(gpa, external_process);

            // const args_buf = try gpa.allocSentinel(?[*:0]const u8, args.len, null);
            // defer gpa.free(args_buf);
            // for (args, 0..) |arg, i| {
            //     args_buf[i] = (try gpa.dupeZ(u8, arg)).ptr;
            //     gpa.free(arg);
            // }
            // const envp = @as([*:null]const ?[*:0]const u8, @ptrCast(std.os.environ.ptr));
            // _ = std.os.linux.execve(args_buf.ptr[0].?, args_buf.ptr, envp);
            // std.os.linux.exit(1);
        },
        else => {
            var status: u32 = 0;
            _ = std.os.linux.waitpid(pid, &status, 0);
            _ = std.os.linux.ptrace(std.os.linux.PTRACE.SETOPTIONS, pid, 0, @intCast(std.os.linux.PTRACE.KILL), 0);

            // var in_syscall = false;

            while (true) {
                _ = std.os.linux.ptrace(std.os.linux.PTRACE.SYSCALL, pid, 0, 0, 0);
                _ = std.os.linux.waitpid(pid, &status, 0);
                if (std.os.linux.W.IFEXITED(status) or std.os.linux.W.IFSIGNALED(status)) break;

                var regs: c.user_regs_struct = undefined;
                // var regs: UserRegsStruct = undefined;
                _ = std.os.linux.ptrace(std.os.linux.PTRACE.GETREGS, pid, 0, @intFromPtr(&regs), 0);

                const syscall = regs.orig_rax;
                // if (!in_syscall) {
                std.debug.print("[{d}] ({d}, {d}, {d}, {d}, {d}, {d})\n", .{ syscall, regs.rdi, regs.rsi, regs.rdx, regs.r10, regs.r8, regs.r9 });

                _ = std.os.linux.ptrace(std.os.linux.PTRACE.SYSCALL, pid, 0, 0, 0);
                _ = std.os.linux.waitpid(pid, &status, 0);

                _ = std.os.linux.ptrace(std.os.linux.PTRACE.GETREGS, pid, 0, @intFromPtr(&regs), 0);

                std.debug.print("={}\n", .{regs.rax});
                // }
                // in_syscall = !in_syscall;
            }
        },
    }
}
