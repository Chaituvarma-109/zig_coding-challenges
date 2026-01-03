const std = @import("std");

const linux = std.os.linux;
const syscall = @import("syscallmappings.zig");

pub fn printSysArgs(gpa: std.mem.Allocator, pid: i32, rargs: [6]u64, syscall_num: i64, wr: *std.Io.Writer) !void {
    const syscall_enum = @tagName(std.enums.fromInt(linux.SYS, syscall_num).?);
    const sys_enum = std.meta.stringToEnum(linux.SYS, syscall_enum).?;

    // pending: getcwd, newfstatat, fstatat64, rt_sigaction, fcntl, faccessat2
    switch (sys_enum) {
        linux.SYS.read => {
            // read(fd, buf, count)
            try wr.print("{d}, 0x{x}, {d}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2] });
            try wr.flush();
        },
        linux.SYS.write => {
            // write(fd, buf, count)
            try wr.print("{d}, ", .{rargs[0]});
            if (rargs[1] != 0 and rargs[2] > 0 and rargs[2] < 256) {
                const str: []u8 = readMemoryFromProcess(gpa, pid, rargs[1], @intCast(rargs[2])) catch {
                    try wr.print("0x{x}, {d}", .{ rargs[1], rargs[2] });
                    try wr.flush();
                    return;
                };
                defer gpa.free(str);
                try wr.print("\"", .{});
                try printEscapedString(str, wr);
                try wr.print("\", {d}", .{rargs[2]});
                try wr.flush();
            } else {
                try wr.print("0x{x}, {d}", .{ rargs[1], rargs[2] });
                try wr.flush();
            }
        },
        linux.SYS.open => {
            // open(pathname, flags, mode)
            if (rargs[0] != 0) {
                const path: []u8 = readStringFromProcess(gpa, pid, rargs[0]) catch {
                    try wr.print("0x{x}, {s}", .{ rargs[0], try syscall.openFlagsToString(rargs[1]) });
                    try wr.flush();
                    return;
                };
                defer gpa.free(path);
                try wr.print("\"{s}\", {s}", .{ path, try syscall.openFlagsToString(rargs[1]) });
            } else {
                try wr.print("0x{x}, {s}", .{ rargs[0], try syscall.openFlagsToString(rargs[1]) });
            }
            try wr.flush();
        },
        linux.SYS.openat => {
            // openat(dirfd, pathname, flags, mode)
            const dirfd: i32 = @truncate(@as(i64, @bitCast(rargs[0])));
            if (dirfd == linux.AT.FDCWD) {
                try wr.print("AT_FDCWD, ", .{});
            } else {
                try wr.print("{d}, ", .{dirfd});
            }
            if (rargs[1] != 0) {
                const path: []u8 = readStringFromProcess(gpa, pid, rargs[1]) catch {
                    try wr.print("0x{x}, {s}", .{ rargs[1], try syscall.openFlagsToString(rargs[2]) });
                    try wr.flush();
                    return;
                };
                defer gpa.free(path);
                try wr.print("\"{s}\", {s}", .{ path, try syscall.openFlagsToString(rargs[2]) });
            } else {
                try wr.print("0x{x}, {s}", .{ rargs[1], try syscall.openFlagsToString(rargs[2]) });
            }
            try wr.flush();
        },
        linux.SYS.close => {
            // close(fd)
            try wr.print("{d}", .{@as(i32, @bitCast(@as(u32, @truncate(rargs[0]))))});
            try wr.flush();
        },
        linux.SYS.fstat, linux.SYS.stat, linux.SYS.lstat => {
            // fstat(fd, statbuf) / stat(pathname, statbuf) / lstat(pathname, statbuf)
            if (sys_enum == linux.SYS.fstat) {
                try wr.print("{d}, 0x{x}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1] });
            } else {
                const path: []u8 = try readStringFromProcess(gpa, pid, rargs[0]);
                defer gpa.free(path);
                try wr.print("\"{s}\", 0x{x}", .{ path, rargs[1] });
            }
            try wr.flush();
        },
        linux.SYS.mmap => {
            // mmap(addr, length, prot, flags, fd, offset)
            var buff: [1024]u8 = undefined;
            const addr_str = if (rargs[0] == 0) "NULL" else try std.fmt.bufPrint(&buff, "0x{x}", .{rargs[0]});
            const z_hex = if (rargs[5] == 0) "0" else try std.fmt.bufPrint(&buff, "0x{x}", .{rargs[0]});
            try wr.print("{s}, {d}, {s}, {s}, {d}, {s}", .{ addr_str, rargs[1], syscall.mmapProtToString(rargs[2]), syscall.mmapFlagsToString(rargs[3]), @as(i32, @bitCast(@as(u32, @truncate(rargs[4])))), z_hex });
            try wr.flush();
        },
        linux.SYS.mprotect => {
            // mprotect(addr, len, prot)
            try wr.print("0x{x}, {d}, {s}", .{ rargs[0], rargs[1], syscall.mmapProtToString(rargs[2]) });
            try wr.flush();
        },
        linux.SYS.munmap => {
            // munmap(addr, length)
            try wr.print("0x{x}, {d}", .{ rargs[0], rargs[1] });
            try wr.flush();
        },
        linux.SYS.brk => {
            // brk(addr)
            if (rargs[0] == 0) {
                try wr.print("NULL", .{});
            } else {
                try wr.print("0x{x}", .{rargs[0]});
            }
            try wr.flush();
        },
        linux.SYS.getpid, linux.SYS.getuid, linux.SYS.getgid, linux.SYS.geteuid, linux.SYS.getegid, linux.SYS.gettid => {},
        linux.SYS.access => {
            // access(pathname, mode)
            if (rargs[0] != 0) {
                const path: []u8 = readStringFromProcess(gpa, pid, rargs[0]) catch {
                    try wr.print("0x{x}, {s}", .{ rargs[0], try syscall.accessModeToString(rargs[1]) });
                    try wr.flush();
                    return;
                };
                defer gpa.free(path);
                try wr.print("\"{s}\", {s}", .{ path, try syscall.accessModeToString(rargs[1]) });
            } else {
                try wr.print("0x{x}, {s}", .{ rargs[0], try syscall.accessModeToString(rargs[1]) });
            }
            try wr.flush();
        },
        linux.SYS.faccessat => {
            // faccessat(dirfd, pathname, mode, flags)
            const dirfd: i32 = @truncate(@as(i64, @bitCast(rargs[0])));
            if (dirfd == linux.AT.FDCWD) {
                try wr.print("AT_FDCWD, ", .{});
            } else {
                try wr.print("{d}, ", .{dirfd});
            }
            if (rargs[1] != 0) {
                // for see linux.AT
                const path: []u8 = readStringFromProcess(gpa, pid, rargs[1]) catch {
                    try wr.print("0x{x}, {s}, {d}", .{ rargs[1], try syscall.accessModeToString(rargs[2]), rargs[3] });
                    try wr.flush();
                    return;
                };
                defer gpa.free(path);
                try wr.print("\"{s}\", {s}, {d}", .{ path, try syscall.accessModeToString(rargs[2]), rargs[3] });
            } else {
                try wr.print("0x{x}, {s}, {d}", .{ rargs[1], try syscall.accessModeToString(rargs[2]), rargs[3] });
            }
            try wr.flush();
        },
        linux.SYS.execve => {
            if (rargs[0] != 0) {
                const path: []u8 = readStringFromProcess(gpa, pid, rargs[0]) catch {
                    try wr.print("0x{x}, 0x{x}, 0x{x}", .{ rargs[0], rargs[1], rargs[2] });
                    try wr.flush();
                    return;
                };
                defer gpa.free(path);
                // Read argv array
                const argv_str = readArgvArray(gpa, pid, rargs[1]) catch "[...]";
                defer if (!std.mem.eql(u8, argv_str, "[...]")) gpa.free(argv_str);
                try wr.print("\"{s}\", {s}, 0x{x} /* {d} vars */", .{ path, argv_str, rargs[2], rargs[3] });
            } else {
                try wr.print("0x{x}, 0x{x}, 0x{x}", .{ rargs[0], rargs[1], rargs[2] });
            }
            try wr.flush();
        },
        linux.SYS.getdents64 => {
            // getdents64(fd, dirp, count)
            try wr.print("{d}, 0x{x}, {d}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2] });
            try wr.flush();
        },
        linux.SYS.pread64, linux.SYS.pwrite64 => {
            // pread64(fd, buf, count, offset) / pwrite64(fd, buf, count, offset)
            try wr.print("{d}, 0x{x}, {d}, {d}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2], rargs[3] });
            try wr.flush();
        },
        linux.SYS.ioctl => {
            // ioctl(fd, request, ...)
            try wr.print("{d}, 0x{x}, 0x{x}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rargs[1], rargs[2] });
            try wr.flush();
        },
        linux.SYS.arch_prctl => {
            // arch_prctl(option, addr)
            var buff: [1024]u8 = undefined;
            const option = if (rargs[0] == 0x1002) "ARCH_SET_FS" else try std.fmt.bufPrint(&buff, "0x{x}", .{rargs[0]});
            try wr.print("{s}, 0x{x}", .{ option, rargs[1] });
            try wr.flush();
        },
        linux.SYS.set_tid_address => {
            // set_tid_address(tidptr)
            try wr.print("0x{x}", .{rargs[0]});
            try wr.flush();
        },
        linux.SYS.set_robust_list => {
            // set_robust_list(head, len)
            try wr.print("0x{x}, {d}", .{ rargs[0], rargs[1] });
            try wr.flush();
        },
        linux.SYS.rseq => {
            // rseq(rseq, rseq_len, flags, sig)
            try wr.print("0x{x}, 0x{x}, {d}, 0x{x}", .{ rargs[0], rargs[1], rargs[2], rargs[3] });
            try wr.flush();
        },
        linux.SYS.prlimit64 => {
            // prlimit64(pid, resource, new_limit, old_limit)
            const rlimit = syscall.mapRlimittoString(rargs[1]);
            try wr.print("{d}, RLIMIT_{s}, 0x{x}, 0x{x}", .{ @as(i32, @bitCast(@as(u32, @truncate(rargs[0])))), rlimit, rargs[2], rargs[3] });
            try wr.flush();
        },
        linux.SYS.prctl => {
            // prctl(option, arg2, arg3, arg4, arg5)
            const pr = syscall.mapPrToString(rargs[0]);
            const cap = try syscall.capToString(rargs[1]);
            try wr.print("PR_{s}, {s}", .{ pr, cap });
            try wr.flush();
        },
        linux.SYS.statfs => {
            // statfs(path, buf)
            if (rargs[0] != 0) {
                const path: []u8 = readStringFromProcess(gpa, pid, rargs[0]) catch {
                    try wr.print("0x{x}, 0x{x}", .{ rargs[0], rargs[1] });
                    try wr.flush();
                    return;
                };
                defer gpa.free(path);
                try wr.print("\"{s}\", 0x{x}", .{ path, rargs[1] });
            } else {
                try wr.print("0x{x}, 0x{x}", .{ rargs[0], rargs[1] });
            }
            try wr.flush();
        },
        linux.SYS.getrandom => {
            // getrandom(buf, buflen, flags)
            try wr.print("0x{x}, {d}, GRND_NONBLOCK", .{ rargs[0], rargs[1] });
            try wr.flush();
        },
        linux.SYS.exit_group => {
            // exit_group(status)
            const exit_code = @as(i32, @bitCast(@as(u32, @truncate(rargs[0]))));
            try wr.print("{d}) = ?\n++ exited with {d} ++\n", .{ exit_code, exit_code });
            try wr.flush();
        },
        else => {
            // Default: print raw arguments
            try wr.print("0x{x}, 0x{x}, 0x{x}, 0x{x}, 0x{x}, 0x{x}", .{ rargs[0], rargs[1], rargs[2], rargs[3], rargs[4], rargs[5] });
            try wr.flush();
        },
    }
}

fn readStringFromProcess(allocator: std.mem.Allocator, pid: i32, addr: u64) ![]u8 {
    if (addr == 0) return try allocator.dupe(u8, "NULL");

    // Read a chunk of memory that should contain the string
    const max_read: usize = 4096;
    var buffer: [max_read]u8 = undefined;

    const local_iov = [_]std.posix.iovec{
        .{ .base = &buffer, .len = max_read },
    };

    const remote_iov = [_]std.posix.iovec_const{
        .{ .base = @ptrFromInt(addr), .len = max_read },
    };

    const bytes_read = linux.process_vm_readv(pid, &local_iov, &remote_iov, 0);

    if (bytes_read <= 0 or bytes_read > max_read) {
        return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
    }

    const read_size: usize = @intCast(bytes_read);

    // Find null terminator
    var str_len: usize = 0;
    for (buffer[0..read_size]) |byte| {
        if (byte == 0) break;
        str_len += 1;
    }

    // If we didn't find a null terminator and read the full buffer, truncate
    if (str_len >= 256) {
        str_len = 256; // Truncate to reasonable length
    }

    // Validate that we have printable characters
    if (str_len == 0) {
        return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
    }

    // Check if string contains mostly printable characters
    var printable_count: usize = 0;
    for (buffer[0..str_len]) |byte| {
        if ((byte >= 32 and byte <= 126) or byte == '\t' or byte == '\n' or byte == '\r') {
            printable_count += 1;
        }
    }

    // If less than 80% printable, probably not a string
    if (printable_count * 10 < str_len * 8) {
        return try std.fmt.allocPrint(allocator, "0x{x}", .{addr});
    }

    // Truncate and add ellipsis if needed
    if (str_len > 256) {
        var result = try allocator.alloc(u8, 259);
        @memcpy(result[0..256], buffer[0..256]);
        @memcpy(result[256..259], "...");
        return result;
    }

    return try allocator.dupe(u8, buffer[0..str_len]);
}

fn readArgvArray(allocator: std.mem.Allocator, pid: i32, argv_ptr: u64) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, "[");

    // Read up to 10 pointer values at once
    const max_args = 10;
    var ptrs: [max_args]u64 = undefined;

    const local_iov = [_]std.posix.iovec{
        .{ .base = @ptrCast(&ptrs), .len = max_args * @sizeOf(u64) },
    };

    const remote_iov = [_]std.posix.iovec_const{
        .{ .base = @ptrFromInt(argv_ptr), .len = max_args * @sizeOf(u64) },
    };

    const bytes_read = linux.process_vm_readv(pid, &local_iov, &remote_iov, 0);

    if (bytes_read < 0 or @as(isize, @bitCast(bytes_read)) < 0) {
        try result.appendSlice(allocator, "]");
        return result.toOwnedSlice(allocator);
    }

    const ptrs_read: usize = @intCast(@divFloor(bytes_read, @sizeOf(u64)));

    for (ptrs[0..ptrs_read], 0..) |ptr_val, i| {
        if (ptr_val == 0) break;

        if (i > 0) try result.appendSlice(allocator, ", ");

        const str = readStringFromProcess(allocator, pid, ptr_val) catch {
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

fn readMemoryFromProcess(allocator: std.mem.Allocator, pid: i32, addr: u64, len: usize) ![]u8 {
    var result = try allocator.alloc(u8, len);
    errdefer allocator.free(result);

    const local_iov = [_]std.posix.iovec{
        .{ .base = result.ptr, .len = len },
    };

    const remote_iov = [_]std.posix.iovec_const{
        .{ .base = @ptrFromInt(addr), .len = len },
    };

    const bytes_read = linux.process_vm_readv(pid, &local_iov, &remote_iov, 0);

    if (bytes_read <= 0 or @as(isize, @bitCast(bytes_read)) < 0) {
        return error.ReadFailed;
    }

    if (bytes_read != len) {
        return error.ReadFailed;
    }

    return result;
}

fn printEscapedString(str: []const u8, wr: *std.Io.Writer) !void {
    for (str) |ch| {
        switch (ch) {
            '\n' => try wr.print("\\n", .{}),
            '\r' => try wr.print("\\r", .{}),
            '\t' => try wr.print("\\t", .{}),
            '\\' => try wr.print("\\\\", .{}),
            '"' => try wr.print("\\\"", .{}),
            0x20...0x21 => try wr.print("{c}", .{ch}),
            0x23...0x5b => try wr.print("{c}", .{ch}),
            0x5d...0x7e => try wr.print("{c}", .{ch}),
            else => try wr.print("\\x{x:0>2}", .{ch}),
        }
        try wr.flush();
    }
}
