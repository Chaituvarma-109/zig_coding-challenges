const std = @import("std");
const c = @cImport({
    @cInclude("x86_64-linux-gnu/sys/user.h");
});
const syscall = @import("syscallmappings.zig");

const posix = std.posix;
const linux = std.os.linux;

pub fn main() !void {
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();
    const gpa = alloc.allocator();

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
            var in_syscall = false;
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

                        const sysname_name: []const u8 = syscall.getSysCallName(curr_syscall);
                        std.debug.print("[{s}] (", .{sysname_name});

                        in_syscall = true;
                    } else {
                        try printSysArgs(gpa, pid, syscall_args, curr_syscall);
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

// mmap, openat, ioctl, access, rseq
fn printSysArgs(gpa: std.mem.Allocator, pid: i32, rargs: [6]u64, syscall_num: i64) !void {
    switch (syscall_num) {
        @intFromEnum(linux.SYS.read), @intFromEnum(linux.SYS.write) => {
            // read(fd, buf, count) / write(fd, buf, count)
            std.debug.print("{d}, 0x{x}, {d}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2] });
        },
        @intFromEnum(linux.SYS.open), @intFromEnum(linux.SYS.openat) => {
            // open(pathname, flags, mode) / openat(dirfd, pathname, flags, mode)
            if (syscall_num == @intFromEnum(linux.SYS.openat)) {
                const dirfd: i32 = @truncate(@as(i64, @bitCast(rargs[0])));
                if (dirfd == linux.AT.FDCWD) {
                    std.debug.print("AT_FDCWD, ", .{});
                } else {
                    std.debug.print("{d}, ", .{dirfd});
                }
                if (rargs[1] != 0) {
                    const path = readStringFromProcess(gpa, pid, rargs[1]) catch {
                        std.debug.print("0x{x}, {s}", .{ rargs[1], try syscall.openFlagsToString(rargs[2]) });
                        return;
                    };
                    defer gpa.free(path);
                    std.debug.print("\"{s}\", {s}", .{ path, try syscall.openFlagsToString(rargs[2]) });
                } else {
                    std.debug.print("0x{x}, {s}", .{ rargs[1], try syscall.openFlagsToString(rargs[2]) });
                }
            } else {
                if (rargs[0] != 0) {
                    const path = readStringFromProcess(gpa, pid, rargs[0]) catch {
                        std.debug.print("0x{x}, {s}", .{ rargs[0], try syscall.openFlagsToString(rargs[1]) });
                        return;
                    };
                    defer gpa.free(path);
                    std.debug.print("\"{s}\", {s}", .{ path, try syscall.openFlagsToString(rargs[1]) });
                } else {
                    std.debug.print("0x{x}, {s}", .{ rargs[0], try syscall.openFlagsToString(rargs[1]) });
                }
            }
        },
        @intFromEnum(linux.SYS.close) => {
            // close(fd)
            std.debug.print("{d}", .{@as(i32, @bitCast(@as(u32, @truncate(rargs[0]))))});
        },
        @intFromEnum(linux.SYS.fstat), @intFromEnum(linux.SYS.stat), @intFromEnum(linux.SYS.lstat) => {
            // fstat(fd, statbuf) / stat(pathname, statbuf) / lstat(pathname, statbuf)
            if (syscall_num == @intFromEnum(linux.SYS.fstat)) {
                std.debug.print("{d}, 0x{x}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1] });
            } else {
                const path = try readStringFromProcess(gpa, pid, rargs[0]);
                defer gpa.free(path);
                std.debug.print("\"{s}\", 0x{x}", .{ path, rargs[1] });
            }
        },
        @intFromEnum(linux.SYS.mmap) => {
            // mmap(addr, length, prot, flags, fd, offset)
            var buff: [1024]u8 = undefined;
            const addr_str = if (rargs[0] == 0) "NULL" else try std.fmt.bufPrint(&buff, "0x{x}", .{rargs[0]});
            const z_hex = if (rargs[5] == 0) "0" else try std.fmt.bufPrint(&buff, "0x{x}", .{rargs[0]});
            std.debug.print("{s}, {d}, {s}, {s}, {d}, {s}", .{ addr_str, rargs[1], syscall.mmapProtToString(rargs[2]), syscall.mmapFlagsToString(rargs[3]), @as(i32, @bitCast(@as(u32, @truncate(rargs[4])))), z_hex });
        },
        @intFromEnum(linux.SYS.mprotect) => {
            // mprotect(addr, len, prot)
            std.debug.print("0x{x}, {d}, {s}", .{ rargs[0], rargs[1], syscall.mmapProtToString(rargs[2]) });
        },
        @intFromEnum(linux.SYS.munmap) => {
            // munmap(addr, length)
            std.debug.print("0x{x}, {d}", .{ rargs[0], rargs[1] });
        },
        @intFromEnum(linux.SYS.brk) => {
            // brk(addr)
            if (rargs[0] == 0) {
                std.debug.print("NULL", .{});
            } else {
                std.debug.print("0x{x}", .{rargs[0]});
            }
        },
        @intFromEnum(linux.SYS.getpid), @intFromEnum(linux.SYS.getuid), @intFromEnum(linux.SYS.getgid), @intFromEnum(linux.SYS.geteuid), @intFromEnum(linux.SYS.getegid), @intFromEnum(linux.SYS.gettid) => {},
        @intFromEnum(linux.SYS.access) => {
            // access(pathname, mode)
            if (rargs[0] != 0) {
                const path = readStringFromProcess(gpa, pid, rargs[0]) catch {
                    std.debug.print("0x{x}, {s}", .{ rargs[0], try syscall.accessModeToString(rargs[1]) });
                    return;
                };
                defer gpa.free(path);
                std.debug.print("\"{s}\", {s}", .{ path, try syscall.accessModeToString(rargs[1]) });
            } else {
                std.debug.print("0x{x}, {s}", .{ rargs[0], try syscall.accessModeToString(rargs[1]) });
            }
        },
        @intFromEnum(linux.SYS.faccessat) => {
            // faccessat(dirfd, pathname, mode, flags)
            const dirfd: i32 = @truncate(@as(i64, @bitCast(rargs[0])));
            if (dirfd == linux.AT.FDCWD) {
                std.debug.print("AT_FDCWD, ", .{});
            } else {
                std.debug.print("{d}, ", .{dirfd});
            }
            if (rargs[1] != 0) {
                // for see linux.AT
                const path = readStringFromProcess(gpa, pid, rargs[1]) catch {
                    std.debug.print("0x{x}, {s}, {d}", .{ rargs[1], try syscall.accessModeToString(rargs[2]), rargs[3] });
                    return;
                };
                defer gpa.free(path);
                std.debug.print("\"{s}\", {s}, {d}", .{ path, try syscall.accessModeToString(rargs[2]), rargs[3] });
            } else {
                std.debug.print("0x{x}, {s}, {d}", .{ rargs[1], try syscall.accessModeToString(rargs[2]), rargs[3] });
            }
        },
        @intFromEnum(linux.SYS.execve) => {
            // execve(pathname, argv, envp)
            const path = try readStringFromProcess(gpa, pid, rargs[0]);
            defer gpa.free(path);
            std.debug.print("\"{s}\", ..., ...", .{path});
        },
        @intFromEnum(linux.SYS.getdents64) => {
            // getdents64(fd, dirp, count)
            std.debug.print("{d}, 0x{x}, {d}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2] });
        },
        @intFromEnum(linux.SYS.pread64), @intFromEnum(linux.SYS.pwrite64) => {
            // pread64(fd, buf, count, offset) / pwrite64(fd, buf, count, offset)
            std.debug.print("{d}, 0x{x}, {d}, {d}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2], rargs[3] });
        },
        @intFromEnum(linux.SYS.ioctl) => {
            // ioctl(fd, request, ...)
            std.debug.print("{d}, 0x{x}, 0x{x}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2] });
        },
        @intFromEnum(linux.SYS.arch_prctl) => {
            // arch_prctl(option, addr)
            var buff: [1024]u8 = undefined;
            const option = if (rargs[0] == 0x1002) "ARCH_SET_FS" else try std.fmt.bufPrint(&buff, "0x{x}", .{rargs[0]});
            std.debug.print("{s}, 0x{x}", .{ option, rargs[1] });
        },
        @intFromEnum(linux.SYS.set_tid_address) => {
            // set_tid_address(tidptr)
            std.debug.print("0x{x}", .{rargs[0]});
        },
        @intFromEnum(linux.SYS.set_robust_list) => {
            // set_robust_list(head, len)
            std.debug.print("0x{x}, {d}", .{ rargs[0], rargs[1] });
        },
        @intFromEnum(linux.SYS.rseq) => {
            // rseq(rseq, rseq_len, flags, sig)
            std.debug.print("0x{x}, 0x{x}, {d}, 0x{x}", .{ rargs[0], rargs[1], rargs[2], rargs[3] });
        },
        @intFromEnum(linux.SYS.prlimit64) => {
            // prlimit64(pid, resource, new_limit, old_limit)
            const rlimit = syscall.mapRlimittoString(rargs[1]);
            std.debug.print("{d}, RLIMIT_{s}, 0x{x}, 0x{x}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rlimit, rargs[2], rargs[3] });
        },
        @intFromEnum(linux.SYS.prctl) => {
            // prctl(option, arg2, arg3, arg4, arg5)
            std.debug.print("{d}, 0x{x}, 0x{x}, 0x{x}, 0x{x}", .{ rargs[0], rargs[1], rargs[2], rargs[3], rargs[4] });
        },
        @intFromEnum(linux.SYS.statfs) => {
            // statfs(path, buf)
            if (rargs[0] != 0) {
                const path = readStringFromProcess(gpa, pid, rargs[0]) catch {
                    std.debug.print("0x{x}, 0x{x}", .{ rargs[0], rargs[1] });
                    return;
                };
                defer gpa.free(path);
                std.debug.print("\"{s}\", 0x{x}", .{ path, rargs[1] });
            } else {
                std.debug.print("0x{x}, 0x{x}", .{ rargs[0], rargs[1] });
            }
        },
        @intFromEnum(linux.SYS.getrandom) => {
            // getrandom(buf, buflen, flags)
            std.debug.print("0x{x}, {d}, GRND_NONBLOCK", .{ rargs[0], rargs[1] });
        },
        @intFromEnum(linux.SYS.exit_group) => {
            // exit_group(status)
            std.debug.print("{d}", .{@as(i32, @bitCast(@as(u32, @truncate(rargs[0]))))});
        },
        else => {
            // Default: print raw arguments
            std.debug.print("0x{x}, 0x{x}, 0x{x}, 0x{x}, 0x{x}, 0x{x}", .{ rargs[0], rargs[1], rargs[2], rargs[3], rargs[4], rargs[5] });
        },
    }
}

fn printEscapedString(str: []const u8) !void {
    for (str) |ch| {
        switch (ch) {
            '\n' => std.debug.print("\\n", .{}),
            '\r' => std.debug.print("\\r", .{}),
            '\t' => std.debug.print("\\t", .{}),
            '\\' => std.debug.print("\\\\", .{}),
            '"' => std.debug.print("\\\"", .{}),
            0x20...0x21 => std.debug.print("{c}", .{ch}),
            0x23...0x5b => std.debug.print("{c}", .{ch}),
            0x5d...0x7e => std.debug.print("{c}", .{ch}),
            else => std.debug.print("\\x{x:0>2}", .{ch}),
        }
    }
}

fn readStringFromProcess(allocator: std.mem.Allocator, pid: i32, addr: u64) ![]u8 {
    if (addr == 0) return try allocator.dupe(u8, "NULL");

    var result = std.ArrayList(u8).empty;
    errdefer result.deinit(allocator);

    var current_addr = addr;
    var consecutive_failures: u32 = 0;

    while (result.items.len < 4096) { // Max 4KB strings
        const val = linux.ptrace(linux.PTRACE.PEEKDATA, pid, current_addr, 0, 0);

        // If we get -1 and have already started reading, we might have hit the end
        if (val == -1) {
            consecutive_failures += 1;
            if (consecutive_failures > 2 or result.items.len == 0) {
                // Failed to read, return address as hex if we got nothing
                if (result.items.len == 0) {
                    return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
                }
                break;
            }
            current_addr += 8;
            continue;
        }

        consecutive_failures = 0;
        const word: u64 = @bitCast(val);

        // Read 8 bytes at a time
        for (0..8) |i| {
            const byte: u8 = @truncate((word >> @intCast(i * 8)) & 0xFF);
            if (byte == 0) {
                const owned = try result.toOwnedSlice(allocator);
                // If string is empty or has only non-printables, return address
                if (owned.len == 0) {
                    allocator.free(owned);
                    return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
                }
                return owned;
            }

            // Only add printable ASCII characters
            if ((byte >= 32 and byte <= 126) or byte == '\t' or byte == '\n' or byte == '\r') {
                try result.append(allocator, byte);
            } else {
                // Hit a non-printable, likely not a valid string
                // But keep going in case it's UTF-8 or similar
                if (i == 0 and result.items.len == 0) {
                    // Very first byte is non-printable, probably not a string
                    return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
                }
            }

            // Limit string length
            if (result.items.len >= 256) {
                try result.appendSlice(allocator, "...");
                return try result.toOwnedSlice(allocator);
            }
        }
        current_addr += 8;
    }

    if (result.items.len == 0) {
        return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
    }

    return try result.toOwnedSlice(allocator);
}

fn readMemoryFromProcess(allocator: std.mem.Allocator, pid: i32, addr: u64, len: usize) ![]u8 {
    var result = try allocator.alloc(u8, len);
    errdefer allocator.free(result);

    var offset: usize = 0;
    while (offset < len) {
        const word_addr = addr +% offset;
        const word = linux.ptrace(linux.PTRACE.PEEKDATA, pid, @intCast(word_addr), 0, 0);

        if (word == -1) {
            return error.ReadFailed;
        }

        const bytes = std.mem.asBytes(&word);
        const to_copy = @min(bytes.len, len - offset);
        @memcpy(result[offset..][0..to_copy], bytes[0..to_copy]);
        offset += to_copy;
    }

    return result;
}

fn readArgvArray(allocator: std.mem.Allocator, pid: c_int, argv_ptr: u64) ![]u8 {
    var result = std.ArrayList(u8).empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, "[");

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const ptr_addr = argv_ptr +% (i * @sizeOf(usize));
        const ptr_val = linux.ptrace(linux.PTRACE.PEEKDATA, pid, @intCast(ptr_addr), 0, 0);

        if (ptr_val == 0 or ptr_val == -1) break;

        if (i > 0) try result.appendSlice(allocator, ", ");

        const str = readStringFromProcess(allocator, pid, @intCast(ptr_val)) catch {
            try result.appendSlice(allocator, "\"...\"");
            continue;
        };
        defer allocator.free(str);

        try result.append(allocator, '"');
        try result.appendSlice(allocator, str);
        try result.append(allocator, '"');
    }

    try result.appendSlice(allocator, "]");
    return result.toOwnedSlice(allocator);
}
