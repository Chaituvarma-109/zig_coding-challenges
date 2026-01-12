const std: type = @import("std");

const linux: type = std.os.linux;

pub fn getSysCallName(num: i64) []const u8 {
    const syscall_enum = std.enums.fromInt(linux.SYS, num) orelse return "unknown";
    return @tagName(syscall_enum);
}

pub fn getErrorName(errnum: i64) []const u8 {
    const err_num: i64 = -errnum;
    const err_enum = std.enums.fromInt(linux.E, err_num) orelse return "";
    return @tagName(err_enum);
}

pub fn mapRlimittoString(limit: u64) []const u8 {
    const rlimit_enum = std.enums.fromInt(linux.rlimit_resource, limit) orelse return "";
    return @tagName(rlimit_enum);
}

pub fn mapPrToString(pr: u64) []const u8 {
    const pr_enum = std.enums.fromInt(linux.PR, pr) orelse return "";
    return @tagName(pr_enum);
}

pub fn getErrorDescription(errnum: i64) []const u8 {
    const err_num: i64 = -errnum;
    return switch (err_num) {
        @intFromEnum(linux.E.NOENT) => "No Such File or Directory",
        @intFromEnum(linux.E.ACCES) => "Permission Denied",
        @intFromEnum(linux.E.INVAL) => "Invalid Argument",
        @intFromEnum(linux.E.NOMEM) => "Cannot Allocate Memory",
        @intFromEnum(linux.E.FAULT) => "Bad Address",
        else => "",
    };
}

pub fn openFlagsToString(flags: u64) ![]const u8 {
    const O_ACCMODE: u64 = 0o3;
    const O_RDONLY: u64 = 0o0;
    const O_WRONLY: u64 = 0o1;
    const O_RDWR: u64 = 0o2;
    const O_CREAT: u64 = 0o100;
    // const O_EXCL: u64 = 0o200;
    const O_TRUNC: u64 = 0o1000;
    // const O_APPEND: u64 = 0o2000;
    const O_NONBLOCK: u64 = 0o4000;
    const O_DIRECTORY: u64 = 0o200000;
    const O_CLOEXEC: u64 = 0o2000000;

    const access_mode: u64 = flags & O_ACCMODE;

    // Check common combinations
    if (flags == O_RDONLY) return "O_RDONLY";
    if (flags == O_WRONLY) return "O_WRONLY";
    if (flags == O_RDWR) return "O_RDWR";
    if (flags == (O_RDONLY | O_CLOEXEC)) return "O_RDONLY|O_CLOEXEC";
    if (flags == (O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC)) return "O_WRONLY|O_CREAT|O_TRUNC|O_CLOEXEC";
    if (flags == (O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_DIRECTORY)) return "O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY";

    // Build string for other combinations
    if (access_mode == O_RDONLY and (flags & ~O_ACCMODE) != 0) {
        if ((flags & O_CLOEXEC) != 0 and (flags & O_NONBLOCK) != 0 and (flags & O_DIRECTORY) != 0) {
            return "O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY";
        }
        if ((flags & O_CLOEXEC) != 0) return "O_RDONLY|O_CLOEXEC";
    }
    var buff: [1024]u8 = undefined;
    const f: []u8 = try std.fmt.bufPrint(&buff, "0x{x}", .{flags});
    return f;
}

pub fn accessModeToString(mode: u64) ![]const u8 {
    switch (mode) {
        linux.F_OK => return "F_OK",
        linux.R_OK => return "R_OK",
        linux.W_OK => return "W_OK",
        linux.X_OK => return "X_OK",
        else => unreachable,
    }
    var buff: [1024]u8 = undefined;
    const f: []u8 = try std.fmt.bufPrint(&buff, "0x{x}", .{mode});
    return f;
}

pub fn mmapProtToString(prot: u64) []const u8 {
    const NONE: u64 = 0x0;
    const READ: u64 = 0x1;
    const WRITE: u64 = 0x2;
    const EXEC: u64 = 0x4;
    const SEM: u64 = 0x8;
    const GROWSDOWN: u64 = 0x01000000;
    const GROWSUP: u64 = 0x02000000;

    if (prot == NONE) return "PROT_NONE";
    if (prot == READ) return "PROT_READ";
    if (prot == WRITE) return "PROT_WRITE";
    if (prot == EXEC) return "PROT_EXEC";
    if (prot == (READ | WRITE)) return "PROT_READ|PROT_WRITE";
    if (prot == (READ | EXEC)) return "PROT_READ|PROT_EXEC";
    if (prot == (WRITE | EXEC)) return "PROT_WRITE|PROT_EXEC";
    if (prot == (READ | WRITE | EXEC)) return "PROT_READ|PROT_WRITE|PROT_EXEC";
    if (prot == (READ | WRITE | SEM)) return "PROT_READ|PROT_WRITE|PROT_SEM";
    if (prot == (READ | WRITE | EXEC | SEM)) return "PROT_READ|PROT_WRITE|PROT_EXEC|PROT_SEM";
    if (prot & GROWSDOWN != 0) return "PROT_GROWSDOWN";
    if (prot & GROWSUP != 0) return "PROT_GROWSUP";

    return "PROT_???";
}

pub fn mmapFlagsToString(flags: u64) []const u8 {
    const MAP_PRIVATE: u64 = 0x02;
    const MAP_SHARED: u64 = 0x01;
    const MAP_ANONYMOUS: u64 = 0x20;
    const MAP_DENYWRITE: u64 = 0x800;
    const MAP_FIXED: u64 = 0x10;

    if (flags & MAP_PRIVATE != 0) {
        if (flags & MAP_ANONYMOUS != 0) {
            if (flags & MAP_FIXED != 0) {
                return "MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS";
            }
            return "MAP_PRIVATE|MAP_ANONYMOUS";
        }
        if (flags & MAP_DENYWRITE != 0) {
            if (flags & MAP_FIXED != 0) {
                return "MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE";
            }
            return "MAP_PRIVATE|MAP_DENYWRITE";
        }
        return "MAP_PRIVATE";
    }
    if (flags & MAP_SHARED != 0) return "MAP_SHARED";

    return "MAP_???";
}

pub fn capToString(cap: u64) ![]const u8 {
    if (cap == linux.CAP.AUDIT_CONTROL) return "CAP_AUDIT_CONTROL";
    if (cap == linux.CAP.AUDIT_READ) return "CAP_AUDIT_READ";
    if (cap == linux.CAP.AUDIT_WRITE) return "CAP_AUDIT_WRITE";
    if (cap == linux.CAP.BLOCK_SUSPEND) return "CAP_BLOCK_SUSPEND";
    if (cap == linux.CAP.BPF) return "CAP_BPF";
    if (cap == linux.CAP.CHECKPOINT_RESTORE) return "CAP_CHECKPOINT_RESTORE";
    if (cap == linux.CAP.CHOWN) return "CAP_CHOWN";
    if (cap == linux.CAP.DAC_OVERRIDE) return "CAP_DAC_OVERRIDE";
    if (cap == linux.CAP.DAC_READ_SEARCH) return "CAP_DAC_READ_SEARCH";
    if (cap == linux.CAP.FOWNER) return "CAP_FOWNER";
    if (cap == linux.CAP.FSETID) return "CAP_FSETID";
    if (cap == linux.CAP.IPC_LOCK) return "CAP_IPC_LOCK";
    if (cap == linux.CAP.IPC_OWNER) return "CAP_IPC_OWNER";
    if (cap == linux.CAP.KILL) return "CAP_KILL";
    if (cap == linux.CAP.LAST_CAP) return "CAP_LAST_CAP";
    if (cap == linux.CAP.LEASE) return "CAP_LEASE";
    if (cap == linux.CAP.LINUX_IMMUTABLE) return "CAP_LINUX_IMMUTABLE";
    if (cap == linux.CAP.MAC_ADMIN) return "CAP_MAC_ADMIN";
    if (cap == linux.CAP.MAC_OVERRIDE) return "CAP_MAC_OVERRIDE";
    if (cap == linux.CAP.MKNOD) return "CAP_MKNOD";
    if (cap == linux.CAP.NET_ADMIN) return "CAP_NET_ADMIN";
    if (cap == linux.CAP.NET_BIND_SERVICE) return "CAP_NET_BIND_SERVICE";
    if (cap == linux.CAP.NET_BROADCAST) return "CAP_NET_BROADCAST";
    if (cap == linux.CAP.NET_RAW) return "CAP_NET_RAW";
    if (cap == linux.CAP.PERFMON) return "CAP_PERFMON";
    if (cap == linux.CAP.SETFCAP) return "CAP_SETFCAP";
    if (cap == linux.CAP.SETGID) return "CAP_SETGID";
    if (cap == linux.CAP.SETPCAP) return "CAP_SETPCAP";
    if (cap == linux.CAP.SETUID) return "CAP_SETUID";
    if (cap == linux.CAP.SYSLOG) return "CAP_SYSLOG";
    if (cap == linux.CAP.SYS_ADMIN) return "CAP_SYS_ADMIN";
    if (cap == linux.CAP.SYS_BOOT) return "CAP_SYS_BOOT";
    if (cap == linux.CAP.SYS_CHROOT) return "CAP_SYS_CHROOT";
    if (cap == linux.CAP.SYS_MODULE) return "CAP_SYS_MODULE";
    if (cap == linux.CAP.SYS_NICE) return "CAP_SYS_NICE";
    if (cap == linux.CAP.SYS_PACCT) return "CAP_SYS_PACCT";
    if (cap == linux.CAP.SYS_PTRACE) return "CAP_SYS_PTRACE";
    if (cap == linux.CAP.SYS_RAWIO) return "CAP_SYS_RAWIO";
    if (cap == linux.CAP.SYS_RESOURCE) return "CAP_SYS_RESOURCE";
    if (cap == linux.CAP.SYS_TIME) return "CAP_SYS_TIME";
    if (cap == linux.CAP.SYS_TTY_CONFIG) return "CAP_SYS_TTY_CONFIG";
    if (cap == linux.CAP.WAKE_ALARM) return "CAP_WAKE_ALARM";
    var buff: [2048]u8 = undefined;
    const cap_str: []u8 = try std.fmt.bufPrint(&buff, "0x{x} /* CAP_??? */", .{cap});
    return cap_str;
}
