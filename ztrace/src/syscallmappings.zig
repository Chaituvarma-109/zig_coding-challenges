const std = @import("std");

const linux = std.os.linux;

pub fn getSysCallName(num: i64) []const u8 {
    return switch (num) {
        @intFromEnum(linux.SYS.read) => @tagName(linux.SYS.read),
        @intFromEnum(linux.SYS.write) => @tagName(linux.SYS.write),
        @intFromEnum(linux.SYS.open) => @tagName(linux.SYS.open),
        @intFromEnum(linux.SYS.close) => @tagName(linux.SYS.close),
        @intFromEnum(linux.SYS.stat) => @tagName(linux.SYS.stat),
        @intFromEnum(linux.SYS.fstat) => @tagName(linux.SYS.fstat),
        @intFromEnum(linux.SYS.lstat) => @tagName(linux.SYS.lstat),
        @intFromEnum(linux.SYS.poll) => @tagName(linux.SYS.poll),
        @intFromEnum(linux.SYS.lseek) => @tagName(linux.SYS.lseek),
        @intFromEnum(linux.SYS.mmap) => @tagName(linux.SYS.mmap),
        @intFromEnum(linux.SYS.mprotect) => @tagName(linux.SYS.mprotect),
        @intFromEnum(linux.SYS.munmap) => @tagName(linux.SYS.munmap),
        @intFromEnum(linux.SYS.brk) => @tagName(linux.SYS.brk),
        @intFromEnum(linux.SYS.rt_sigaction) => @tagName(linux.SYS.rt_sigaction),
        @intFromEnum(linux.SYS.rt_sigprocmask) => @tagName(linux.SYS.rt_sigprocmask),
        @intFromEnum(linux.SYS.rt_sigreturn) => @tagName(linux.SYS.rt_sigreturn),
        @intFromEnum(linux.SYS.ioctl) => @tagName(linux.SYS.ioctl),
        @intFromEnum(linux.SYS.pread64) => @tagName(linux.SYS.pread64),
        @intFromEnum(linux.SYS.pwrite64) => @tagName(linux.SYS.pwrite64),
        @intFromEnum(linux.SYS.readv) => @tagName(linux.SYS.readv),
        @intFromEnum(linux.SYS.writev) => @tagName(linux.SYS.writev),
        @intFromEnum(linux.SYS.access) => @tagName(linux.SYS.access),
        @intFromEnum(linux.SYS.pipe) => @tagName(linux.SYS.pipe),
        @intFromEnum(linux.SYS.select) => @tagName(linux.SYS.select),
        @intFromEnum(linux.SYS.sched_yield) => @tagName(linux.SYS.sched_yield),
        @intFromEnum(linux.SYS.mremap) => @tagName(linux.SYS.mremap),
        @intFromEnum(linux.SYS.msync) => @tagName(linux.SYS.msync),
        @intFromEnum(linux.SYS.mincore) => @tagName(linux.SYS.mincore),
        @intFromEnum(linux.SYS.madvise) => @tagName(linux.SYS.madvise),
        @intFromEnum(linux.SYS.shmget) => @tagName(linux.SYS.shmget),
        @intFromEnum(linux.SYS.shmat) => @tagName(linux.SYS.shmat),
        @intFromEnum(linux.SYS.shmctl) => @tagName(linux.SYS.shmctl),
        @intFromEnum(linux.SYS.dup) => @tagName(linux.SYS.dup),
        @intFromEnum(linux.SYS.dup2) => @tagName(linux.SYS.dup2),
        @intFromEnum(linux.SYS.pause) => @tagName(linux.SYS.pause),
        @intFromEnum(linux.SYS.nanosleep) => @tagName(linux.SYS.nanosleep),
        @intFromEnum(linux.SYS.getitimer) => @tagName(linux.SYS.getitimer),
        @intFromEnum(linux.SYS.alarm) => @tagName(linux.SYS.alarm),
        @intFromEnum(linux.SYS.setitimer) => @tagName(linux.SYS.setitimer),
        @intFromEnum(linux.SYS.getpid) => @tagName(linux.SYS.getpid),
        @intFromEnum(linux.SYS.sendfile) => @tagName(linux.SYS.sendfile),
        @intFromEnum(linux.SYS.socket) => @tagName(linux.SYS.socket),
        @intFromEnum(linux.SYS.connect) => @tagName(linux.SYS.connect),
        @intFromEnum(linux.SYS.accept) => @tagName(linux.SYS.accept),
        @intFromEnum(linux.SYS.sendto) => @tagName(linux.SYS.sendto),
        @intFromEnum(linux.SYS.recvfrom) => @tagName(linux.SYS.recvfrom),
        @intFromEnum(linux.SYS.sendmsg) => @tagName(linux.SYS.sendmsg),
        @intFromEnum(linux.SYS.recvmsg) => @tagName(linux.SYS.recvmsg),
        @intFromEnum(linux.SYS.shutdown) => @tagName(linux.SYS.shutdown),
        @intFromEnum(linux.SYS.bind) => @tagName(linux.SYS.bind),
        @intFromEnum(linux.SYS.listen) => @tagName(linux.SYS.listen),
        @intFromEnum(linux.SYS.getsockname) => @tagName(linux.SYS.getsockname),
        @intFromEnum(linux.SYS.getpeername) => @tagName(linux.SYS.getpeername),
        @intFromEnum(linux.SYS.socketpair) => @tagName(linux.SYS.socketpair),
        @intFromEnum(linux.SYS.setsockopt) => @tagName(linux.SYS.setsockopt),
        @intFromEnum(linux.SYS.getsockopt) => @tagName(linux.SYS.getsockopt),
        @intFromEnum(linux.SYS.clone) => @tagName(linux.SYS.clone),
        @intFromEnum(linux.SYS.fork) => @tagName(linux.SYS.fork),
        @intFromEnum(linux.SYS.vfork) => @tagName(linux.SYS.vfork),
        @intFromEnum(linux.SYS.execve) => @tagName(linux.SYS.execve),
        @intFromEnum(linux.SYS.exit) => @tagName(linux.SYS.exit),
        @intFromEnum(linux.SYS.wait4) => @tagName(linux.SYS.wait4),
        @intFromEnum(linux.SYS.kill) => @tagName(linux.SYS.kill),
        @intFromEnum(linux.SYS.uname) => @tagName(linux.SYS.uname),
        @intFromEnum(linux.SYS.semget) => @tagName(linux.SYS.semget),
        @intFromEnum(linux.SYS.semop) => @tagName(linux.SYS.semop),
        @intFromEnum(linux.SYS.semctl) => @tagName(linux.SYS.semctl),
        @intFromEnum(linux.SYS.shmdt) => @tagName(linux.SYS.shmdt),
        @intFromEnum(linux.SYS.msgget) => @tagName(linux.SYS.msgget),
        @intFromEnum(linux.SYS.msgsnd) => @tagName(linux.SYS.msgsnd),
        @intFromEnum(linux.SYS.msgrcv) => @tagName(linux.SYS.msgrcv),
        @intFromEnum(linux.SYS.msgctl) => @tagName(linux.SYS.msgctl),
        @intFromEnum(linux.SYS.fcntl) => @tagName(linux.SYS.fcntl),
        @intFromEnum(linux.SYS.flock) => @tagName(linux.SYS.flock),
        @intFromEnum(linux.SYS.fsync) => @tagName(linux.SYS.fsync),
        @intFromEnum(linux.SYS.fdatasync) => @tagName(linux.SYS.fdatasync),
        @intFromEnum(linux.SYS.truncate) => @tagName(linux.SYS.truncate),
        @intFromEnum(linux.SYS.ftruncate) => @tagName(linux.SYS.ftruncate),
        @intFromEnum(linux.SYS.getdents) => @tagName(linux.SYS.getdents),
        @intFromEnum(linux.SYS.getcwd) => @tagName(linux.SYS.getcwd),
        @intFromEnum(linux.SYS.chdir) => @tagName(linux.SYS.chdir),
        @intFromEnum(linux.SYS.fchdir) => @tagName(linux.SYS.fchdir),
        @intFromEnum(linux.SYS.rename) => @tagName(linux.SYS.rename),
        @intFromEnum(linux.SYS.mkdir) => @tagName(linux.SYS.mkdir),
        @intFromEnum(linux.SYS.rmdir) => @tagName(linux.SYS.rmdir),
        @intFromEnum(linux.SYS.creat) => @tagName(linux.SYS.creat),
        @intFromEnum(linux.SYS.link) => @tagName(linux.SYS.link),
        @intFromEnum(linux.SYS.unlink) => @tagName(linux.SYS.unlink),
        @intFromEnum(linux.SYS.symlink) => @tagName(linux.SYS.symlink),
        @intFromEnum(linux.SYS.readlink) => @tagName(linux.SYS.readlink),
        @intFromEnum(linux.SYS.chmod) => @tagName(linux.SYS.chmod),
        @intFromEnum(linux.SYS.fchmod) => @tagName(linux.SYS.fchmod),
        @intFromEnum(linux.SYS.chown) => @tagName(linux.SYS.chown),
        @intFromEnum(linux.SYS.fchown) => @tagName(linux.SYS.fchown),
        @intFromEnum(linux.SYS.lchown) => @tagName(linux.SYS.lchown),
        @intFromEnum(linux.SYS.umask) => @tagName(linux.SYS.umask),
        @intFromEnum(linux.SYS.gettimeofday) => @tagName(linux.SYS.gettimeofday),
        @intFromEnum(linux.SYS.getrlimit) => @tagName(linux.SYS.getrlimit),
        @intFromEnum(linux.SYS.getrusage) => @tagName(linux.SYS.getrusage),
        @intFromEnum(linux.SYS.sysinfo) => @tagName(linux.SYS.sysinfo),
        @intFromEnum(linux.SYS.times) => @tagName(linux.SYS.times),
        @intFromEnum(linux.SYS.ptrace) => @tagName(linux.SYS.ptrace),
        @intFromEnum(linux.SYS.getuid) => @tagName(linux.SYS.getuid),
        @intFromEnum(linux.SYS.syslog) => @tagName(linux.SYS.syslog),
        @intFromEnum(linux.SYS.getgid) => @tagName(linux.SYS.getgid),
        @intFromEnum(linux.SYS.setuid) => @tagName(linux.SYS.setuid),
        @intFromEnum(linux.SYS.setgid) => @tagName(linux.SYS.setgid),
        @intFromEnum(linux.SYS.geteuid) => @tagName(linux.SYS.geteuid),
        @intFromEnum(linux.SYS.getegid) => @tagName(linux.SYS.getegid),
        @intFromEnum(linux.SYS.setpgid) => @tagName(linux.SYS.setpgid),
        @intFromEnum(linux.SYS.getppid) => @tagName(linux.SYS.getppid),
        @intFromEnum(linux.SYS.getpgrp) => @tagName(linux.SYS.getpgrp),
        @intFromEnum(linux.SYS.setsid) => @tagName(linux.SYS.setsid),
        @intFromEnum(linux.SYS.setreuid) => @tagName(linux.SYS.setreuid),
        @intFromEnum(linux.SYS.setregid) => @tagName(linux.SYS.setregid),
        @intFromEnum(linux.SYS.getgroups) => @tagName(linux.SYS.getgroups),
        @intFromEnum(linux.SYS.setgroups) => @tagName(linux.SYS.setgroups),
        @intFromEnum(linux.SYS.setresuid) => @tagName(linux.SYS.setresuid),
        @intFromEnum(linux.SYS.getresuid) => @tagName(linux.SYS.getresuid),
        @intFromEnum(linux.SYS.setresgid) => @tagName(linux.SYS.setresgid),
        @intFromEnum(linux.SYS.getresgid) => @tagName(linux.SYS.getresgid),
        @intFromEnum(linux.SYS.getpgid) => @tagName(linux.SYS.getpgid),
        @intFromEnum(linux.SYS.setfsuid) => @tagName(linux.SYS.setfsuid),
        @intFromEnum(linux.SYS.setfsgid) => @tagName(linux.SYS.setfsgid),
        @intFromEnum(linux.SYS.getsid) => @tagName(linux.SYS.getsid),
        @intFromEnum(linux.SYS.capget) => @tagName(linux.SYS.capget),
        @intFromEnum(linux.SYS.capset) => @tagName(linux.SYS.capset),
        @intFromEnum(linux.SYS.rt_sigpending) => @tagName(linux.SYS.rt_sigpending),
        @intFromEnum(linux.SYS.rt_sigtimedwait) => @tagName(linux.SYS.rt_sigtimedwait),
        @intFromEnum(linux.SYS.rt_sigqueueinfo) => @tagName(linux.SYS.rt_sigqueueinfo),
        @intFromEnum(linux.SYS.rt_sigsuspend) => @tagName(linux.SYS.rt_sigsuspend),
        @intFromEnum(linux.SYS.sigaltstack) => @tagName(linux.SYS.sigaltstack),
        @intFromEnum(linux.SYS.utime) => @tagName(linux.SYS.utime),
        @intFromEnum(linux.SYS.mknod) => @tagName(linux.SYS.mknod),
        @intFromEnum(linux.SYS.uselib) => @tagName(linux.SYS.uselib),
        @intFromEnum(linux.SYS.personality) => @tagName(linux.SYS.personality),
        @intFromEnum(linux.SYS.ustat) => @tagName(linux.SYS.ustat),
        @intFromEnum(linux.SYS.statfs) => @tagName(linux.SYS.statfs),
        @intFromEnum(linux.SYS.fstatfs) => @tagName(linux.SYS.fstatfs),
        @intFromEnum(linux.SYS.sysfs) => @tagName(linux.SYS.sysfs),
        @intFromEnum(linux.SYS.getpriority) => @tagName(linux.SYS.getpriority),
        @intFromEnum(linux.SYS.setpriority) => @tagName(linux.SYS.setpriority),
        @intFromEnum(linux.SYS.sched_setparam) => @tagName(linux.SYS.sched_setparam),
        @intFromEnum(linux.SYS.sched_getparam) => @tagName(linux.SYS.sched_getparam),
        @intFromEnum(linux.SYS.sched_setscheduler) => @tagName(linux.SYS.sched_setscheduler),
        @intFromEnum(linux.SYS.sched_getscheduler) => @tagName(linux.SYS.sched_getscheduler),
        @intFromEnum(linux.SYS.sched_get_priority_max) => @tagName(linux.SYS.sched_get_priority_max),
        @intFromEnum(linux.SYS.sched_get_priority_min) => @tagName(linux.SYS.sched_get_priority_min),
        @intFromEnum(linux.SYS.sched_rr_get_interval) => @tagName(linux.SYS.sched_rr_get_interval),
        @intFromEnum(linux.SYS.mlock) => @tagName(linux.SYS.mlock),
        @intFromEnum(linux.SYS.munlock) => @tagName(linux.SYS.munlock),
        @intFromEnum(linux.SYS.mlockall) => @tagName(linux.SYS.mlockall),
        @intFromEnum(linux.SYS.munlockall) => @tagName(linux.SYS.munlockall),
        @intFromEnum(linux.SYS.vhangup) => @tagName(linux.SYS.vhangup),
        @intFromEnum(linux.SYS.modify_ldt) => @tagName(linux.SYS.modify_ldt),
        @intFromEnum(linux.SYS.pivot_root) => @tagName(linux.SYS.pivot_root),
        @intFromEnum(linux.SYS.sysctl) => @tagName(linux.SYS.sysctl),
        @intFromEnum(linux.SYS.prctl) => @tagName(linux.SYS.prctl),
        @intFromEnum(linux.SYS.arch_prctl) => @tagName(linux.SYS.arch_prctl),
        @intFromEnum(linux.SYS.adjtimex) => @tagName(linux.SYS.adjtimex),
        @intFromEnum(linux.SYS.setrlimit) => @tagName(linux.SYS.setrlimit),
        @intFromEnum(linux.SYS.chroot) => @tagName(linux.SYS.chroot),
        @intFromEnum(linux.SYS.sync) => @tagName(linux.SYS.sync),
        @intFromEnum(linux.SYS.acct) => @tagName(linux.SYS.acct),
        @intFromEnum(linux.SYS.settimeofday) => @tagName(linux.SYS.settimeofday),
        @intFromEnum(linux.SYS.mount) => @tagName(linux.SYS.mount),
        @intFromEnum(linux.SYS.umount2) => @tagName(linux.SYS.umount2),
        @intFromEnum(linux.SYS.swapon) => @tagName(linux.SYS.swapon),
        @intFromEnum(linux.SYS.swapoff) => @tagName(linux.SYS.swapoff),
        @intFromEnum(linux.SYS.reboot) => @tagName(linux.SYS.reboot),
        @intFromEnum(linux.SYS.sethostname) => @tagName(linux.SYS.sethostname),
        @intFromEnum(linux.SYS.setdomainname) => @tagName(linux.SYS.setdomainname),
        @intFromEnum(linux.SYS.iopl) => @tagName(linux.SYS.iopl),
        @intFromEnum(linux.SYS.ioperm) => @tagName(linux.SYS.ioperm),
        @intFromEnum(linux.SYS.create_module) => @tagName(linux.SYS.create_module),
        @intFromEnum(linux.SYS.init_module) => @tagName(linux.SYS.init_module),
        @intFromEnum(linux.SYS.delete_module) => @tagName(linux.SYS.delete_module),
        @intFromEnum(linux.SYS.get_kernel_syms) => @tagName(linux.SYS.get_kernel_syms),
        @intFromEnum(linux.SYS.query_module) => @tagName(linux.SYS.query_module),
        @intFromEnum(linux.SYS.quotactl) => @tagName(linux.SYS.quotactl),
        @intFromEnum(linux.SYS.nfsservctl) => @tagName(linux.SYS.nfsservctl),
        @intFromEnum(linux.SYS.getpmsg) => @tagName(linux.SYS.getpmsg),
        @intFromEnum(linux.SYS.putpmsg) => @tagName(linux.SYS.putpmsg),
        @intFromEnum(linux.SYS.afs_syscall) => @tagName(linux.SYS.afs_syscall),
        @intFromEnum(linux.SYS.tuxcall) => @tagName(linux.SYS.tuxcall),
        @intFromEnum(linux.SYS.security) => @tagName(linux.SYS.security),
        @intFromEnum(linux.SYS.gettid) => @tagName(linux.SYS.gettid),
        @intFromEnum(linux.SYS.readahead) => @tagName(linux.SYS.readahead),
        @intFromEnum(linux.SYS.setxattr) => @tagName(linux.SYS.setxattr),
        @intFromEnum(linux.SYS.lsetxattr) => @tagName(linux.SYS.lsetxattr),
        @intFromEnum(linux.SYS.fsetxattr) => @tagName(linux.SYS.fsetxattr),
        @intFromEnum(linux.SYS.getxattr) => @tagName(linux.SYS.getxattr),
        @intFromEnum(linux.SYS.lgetxattr) => @tagName(linux.SYS.lgetxattr),
        @intFromEnum(linux.SYS.fgetxattr) => @tagName(linux.SYS.fgetxattr),
        @intFromEnum(linux.SYS.listxattr) => @tagName(linux.SYS.listxattr),
        @intFromEnum(linux.SYS.llistxattr) => @tagName(linux.SYS.llistxattr),
        @intFromEnum(linux.SYS.flistxattr) => @tagName(linux.SYS.flistxattr),
        @intFromEnum(linux.SYS.removexattr) => @tagName(linux.SYS.removexattr),
        @intFromEnum(linux.SYS.lremovexattr) => @tagName(linux.SYS.lremovexattr),
        @intFromEnum(linux.SYS.fremovexattr) => @tagName(linux.SYS.fremovexattr),
        @intFromEnum(linux.SYS.tkill) => @tagName(linux.SYS.tkill),
        @intFromEnum(linux.SYS.time) => @tagName(linux.SYS.time),
        @intFromEnum(linux.SYS.futex) => @tagName(linux.SYS.futex),
        @intFromEnum(linux.SYS.sched_setaffinity) => @tagName(linux.SYS.sched_setaffinity),
        @intFromEnum(linux.SYS.sched_getaffinity) => @tagName(linux.SYS.sched_getaffinity),
        @intFromEnum(linux.SYS.set_thread_area) => @tagName(linux.SYS.set_thread_area),
        @intFromEnum(linux.SYS.io_setup) => @tagName(linux.SYS.io_setup),
        @intFromEnum(linux.SYS.io_destroy) => @tagName(linux.SYS.io_destroy),
        @intFromEnum(linux.SYS.io_getevents) => @tagName(linux.SYS.io_getevents),
        @intFromEnum(linux.SYS.io_submit) => @tagName(linux.SYS.io_submit),
        @intFromEnum(linux.SYS.io_cancel) => @tagName(linux.SYS.io_cancel),
        @intFromEnum(linux.SYS.get_thread_area) => @tagName(linux.SYS.get_thread_area),
        @intFromEnum(linux.SYS.lookup_dcookie) => @tagName(linux.SYS.lookup_dcookie),
        @intFromEnum(linux.SYS.epoll_create) => @tagName(linux.SYS.epoll_create),
        @intFromEnum(linux.SYS.epoll_ctl_old) => @tagName(linux.SYS.epoll_ctl_old),
        @intFromEnum(linux.SYS.epoll_wait_old) => @tagName(linux.SYS.epoll_wait_old),
        @intFromEnum(linux.SYS.remap_file_pages) => @tagName(linux.SYS.remap_file_pages),
        @intFromEnum(linux.SYS.getdents64) => @tagName(linux.SYS.getdents64),
        @intFromEnum(linux.SYS.set_tid_address) => @tagName(linux.SYS.set_tid_address),
        @intFromEnum(linux.SYS.restart_syscall) => @tagName(linux.SYS.restart_syscall),
        @intFromEnum(linux.SYS.semtimedop) => @tagName(linux.SYS.semtimedop),
        @intFromEnum(linux.SYS.fadvise64) => @tagName(linux.SYS.fadvise64),
        @intFromEnum(linux.SYS.timer_create) => @tagName(linux.SYS.timer_create),
        @intFromEnum(linux.SYS.timer_settime) => @tagName(linux.SYS.timer_settime),
        @intFromEnum(linux.SYS.timer_gettime) => @tagName(linux.SYS.timer_gettime),
        @intFromEnum(linux.SYS.timer_getoverrun) => @tagName(linux.SYS.timer_getoverrun),
        @intFromEnum(linux.SYS.timer_delete) => @tagName(linux.SYS.timer_delete),
        @intFromEnum(linux.SYS.clock_settime) => @tagName(linux.SYS.clock_settime),
        @intFromEnum(linux.SYS.clock_gettime) => @tagName(linux.SYS.clock_gettime),
        @intFromEnum(linux.SYS.clock_getres) => @tagName(linux.SYS.clock_getres),
        @intFromEnum(linux.SYS.clock_nanosleep) => @tagName(linux.SYS.clock_nanosleep),
        @intFromEnum(linux.SYS.exit_group) => @tagName(linux.SYS.exit_group),
        @intFromEnum(linux.SYS.epoll_wait) => @tagName(linux.SYS.epoll_wait),
        @intFromEnum(linux.SYS.epoll_ctl) => @tagName(linux.SYS.epoll_ctl),
        @intFromEnum(linux.SYS.tgkill) => @tagName(linux.SYS.tgkill),
        @intFromEnum(linux.SYS.utimes) => @tagName(linux.SYS.utimes),
        @intFromEnum(linux.SYS.vserver) => @tagName(linux.SYS.vserver),
        @intFromEnum(linux.SYS.mbind) => @tagName(linux.SYS.mbind),
        @intFromEnum(linux.SYS.set_mempolicy) => @tagName(linux.SYS.set_mempolicy),
        @intFromEnum(linux.SYS.get_mempolicy) => @tagName(linux.SYS.get_mempolicy),
        @intFromEnum(linux.SYS.mq_open) => @tagName(linux.SYS.mq_open),
        @intFromEnum(linux.SYS.mq_unlink) => @tagName(linux.SYS.mq_unlink),
        @intFromEnum(linux.SYS.mq_timedsend) => @tagName(linux.SYS.mq_timedsend),
        @intFromEnum(linux.SYS.mq_timedreceive) => @tagName(linux.SYS.mq_timedreceive),
        @intFromEnum(linux.SYS.mq_notify) => @tagName(linux.SYS.mq_notify),
        @intFromEnum(linux.SYS.mq_getsetattr) => @tagName(linux.SYS.mq_getsetattr),
        @intFromEnum(linux.SYS.kexec_load) => @tagName(linux.SYS.kexec_load),
        @intFromEnum(linux.SYS.waitid) => @tagName(linux.SYS.waitid),
        @intFromEnum(linux.SYS.add_key) => @tagName(linux.SYS.add_key),
        @intFromEnum(linux.SYS.request_key) => @tagName(linux.SYS.request_key),
        @intFromEnum(linux.SYS.keyctl) => @tagName(linux.SYS.keyctl),
        @intFromEnum(linux.SYS.ioprio_set) => @tagName(linux.SYS.ioprio_set),
        @intFromEnum(linux.SYS.ioprio_get) => @tagName(linux.SYS.ioprio_get),
        @intFromEnum(linux.SYS.inotify_init) => @tagName(linux.SYS.inotify_init),
        @intFromEnum(linux.SYS.inotify_add_watch) => @tagName(linux.SYS.inotify_add_watch),
        @intFromEnum(linux.SYS.inotify_rm_watch) => @tagName(linux.SYS.inotify_rm_watch),
        @intFromEnum(linux.SYS.migrate_pages) => @tagName(linux.SYS.migrate_pages),
        @intFromEnum(linux.SYS.openat) => @tagName(linux.SYS.openat),
        @intFromEnum(linux.SYS.mkdirat) => @tagName(linux.SYS.mkdirat),
        @intFromEnum(linux.SYS.mknodat) => @tagName(linux.SYS.mknodat),
        @intFromEnum(linux.SYS.fchownat) => @tagName(linux.SYS.fchownat),
        @intFromEnum(linux.SYS.futimesat) => @tagName(linux.SYS.futimesat),
        @intFromEnum(linux.SYS.fstatat64) => @tagName(linux.SYS.fstatat64),
        @intFromEnum(linux.SYS.unlinkat) => @tagName(linux.SYS.unlinkat),
        @intFromEnum(linux.SYS.renameat) => @tagName(linux.SYS.renameat),
        @intFromEnum(linux.SYS.linkat) => @tagName(linux.SYS.linkat),
        @intFromEnum(linux.SYS.symlinkat) => @tagName(linux.SYS.symlinkat),
        @intFromEnum(linux.SYS.readlinkat) => @tagName(linux.SYS.readlinkat),
        @intFromEnum(linux.SYS.fchmodat) => @tagName(linux.SYS.fchmodat),
        @intFromEnum(linux.SYS.faccessat) => @tagName(linux.SYS.faccessat),
        @intFromEnum(linux.SYS.pselect6) => @tagName(linux.SYS.pselect6),
        @intFromEnum(linux.SYS.ppoll) => @tagName(linux.SYS.ppoll),
        @intFromEnum(linux.SYS.unshare) => @tagName(linux.SYS.unshare),
        @intFromEnum(linux.SYS.set_robust_list) => @tagName(linux.SYS.set_robust_list),
        @intFromEnum(linux.SYS.get_robust_list) => @tagName(linux.SYS.get_robust_list),
        @intFromEnum(linux.SYS.splice) => @tagName(linux.SYS.splice),
        @intFromEnum(linux.SYS.tee) => @tagName(linux.SYS.tee),
        @intFromEnum(linux.SYS.sync_file_range) => @tagName(linux.SYS.sync_file_range),
        @intFromEnum(linux.SYS.vmsplice) => @tagName(linux.SYS.vmsplice),
        @intFromEnum(linux.SYS.move_pages) => @tagName(linux.SYS.move_pages),
        @intFromEnum(linux.SYS.utimensat) => @tagName(linux.SYS.utimensat),
        @intFromEnum(linux.SYS.epoll_pwait) => @tagName(linux.SYS.epoll_pwait),
        @intFromEnum(linux.SYS.signalfd) => @tagName(linux.SYS.signalfd),
        @intFromEnum(linux.SYS.timerfd_create) => @tagName(linux.SYS.timerfd_create),
        @intFromEnum(linux.SYS.eventfd) => @tagName(linux.SYS.eventfd),
        @intFromEnum(linux.SYS.fallocate) => @tagName(linux.SYS.fallocate),
        @intFromEnum(linux.SYS.timerfd_settime) => @tagName(linux.SYS.timerfd_settime),
        @intFromEnum(linux.SYS.timerfd_gettime) => @tagName(linux.SYS.timerfd_gettime),
        @intFromEnum(linux.SYS.accept4) => @tagName(linux.SYS.accept4),
        @intFromEnum(linux.SYS.signalfd4) => @tagName(linux.SYS.signalfd4),
        @intFromEnum(linux.SYS.eventfd2) => @tagName(linux.SYS.eventfd2),
        @intFromEnum(linux.SYS.epoll_create1) => @tagName(linux.SYS.epoll_create1),
        @intFromEnum(linux.SYS.dup3) => @tagName(linux.SYS.dup3),
        @intFromEnum(linux.SYS.pipe2) => @tagName(linux.SYS.pipe2),
        @intFromEnum(linux.SYS.inotify_init1) => @tagName(linux.SYS.inotify_init1),
        @intFromEnum(linux.SYS.preadv) => @tagName(linux.SYS.preadv),
        @intFromEnum(linux.SYS.pwritev) => @tagName(linux.SYS.pwritev),
        @intFromEnum(linux.SYS.rt_tgsigqueueinfo) => @tagName(linux.SYS.rt_tgsigqueueinfo),
        @intFromEnum(linux.SYS.perf_event_open) => @tagName(linux.SYS.perf_event_open),
        @intFromEnum(linux.SYS.recvmmsg) => @tagName(linux.SYS.recvmmsg),
        @intFromEnum(linux.SYS.fanotify_init) => @tagName(linux.SYS.fanotify_init),
        @intFromEnum(linux.SYS.fanotify_mark) => @tagName(linux.SYS.fanotify_mark),
        @intFromEnum(linux.SYS.prlimit64) => @tagName(linux.SYS.prlimit64),
        @intFromEnum(linux.SYS.name_to_handle_at) => @tagName(linux.SYS.name_to_handle_at),
        @intFromEnum(linux.SYS.open_by_handle_at) => @tagName(linux.SYS.open_by_handle_at),
        @intFromEnum(linux.SYS.clock_adjtime) => @tagName(linux.SYS.clock_adjtime),
        @intFromEnum(linux.SYS.syncfs) => @tagName(linux.SYS.syncfs),
        @intFromEnum(linux.SYS.sendmmsg) => @tagName(linux.SYS.sendmmsg),
        @intFromEnum(linux.SYS.setns) => @tagName(linux.SYS.setns),
        @intFromEnum(linux.SYS.getcpu) => @tagName(linux.SYS.getcpu),
        @intFromEnum(linux.SYS.process_vm_readv) => @tagName(linux.SYS.process_vm_readv),
        @intFromEnum(linux.SYS.process_vm_writev) => @tagName(linux.SYS.process_vm_writev),
        @intFromEnum(linux.SYS.kcmp) => @tagName(linux.SYS.kcmp),
        @intFromEnum(linux.SYS.finit_module) => @tagName(linux.SYS.finit_module),
        @intFromEnum(linux.SYS.sched_setattr) => @tagName(linux.SYS.sched_setattr),
        @intFromEnum(linux.SYS.sched_getattr) => @tagName(linux.SYS.sched_getattr),
        @intFromEnum(linux.SYS.renameat2) => @tagName(linux.SYS.renameat2),
        @intFromEnum(linux.SYS.seccomp) => @tagName(linux.SYS.seccomp),
        @intFromEnum(linux.SYS.getrandom) => @tagName(linux.SYS.getrandom),
        @intFromEnum(linux.SYS.memfd_create) => @tagName(linux.SYS.memfd_create),
        @intFromEnum(linux.SYS.kexec_file_load) => @tagName(linux.SYS.kexec_file_load),
        @intFromEnum(linux.SYS.bpf) => @tagName(linux.SYS.bpf),
        @intFromEnum(linux.SYS.execveat) => @tagName(linux.SYS.execveat),
        @intFromEnum(linux.SYS.userfaultfd) => @tagName(linux.SYS.userfaultfd),
        @intFromEnum(linux.SYS.membarrier) => @tagName(linux.SYS.membarrier),
        @intFromEnum(linux.SYS.mlock2) => @tagName(linux.SYS.mlock2),
        @intFromEnum(linux.SYS.copy_file_range) => @tagName(linux.SYS.copy_file_range),
        @intFromEnum(linux.SYS.preadv2) => @tagName(linux.SYS.preadv2),
        @intFromEnum(linux.SYS.pwritev2) => @tagName(linux.SYS.pwritev2),
        @intFromEnum(linux.SYS.pkey_mprotect) => @tagName(linux.SYS.pkey_mprotect),
        @intFromEnum(linux.SYS.pkey_alloc) => @tagName(linux.SYS.pkey_alloc),
        @intFromEnum(linux.SYS.pkey_free) => @tagName(linux.SYS.pkey_free),
        @intFromEnum(linux.SYS.statx) => @tagName(linux.SYS.statx),
        @intFromEnum(linux.SYS.io_pgetevents) => @tagName(linux.SYS.io_pgetevents),
        @intFromEnum(linux.SYS.rseq) => @tagName(linux.SYS.rseq),
        @intFromEnum(linux.SYS.uretprobe) => @tagName(linux.SYS.uretprobe),
        @intFromEnum(linux.SYS.pidfd_send_signal) => @tagName(linux.SYS.pidfd_send_signal),
        @intFromEnum(linux.SYS.io_uring_setup) => @tagName(linux.SYS.io_uring_setup),
        @intFromEnum(linux.SYS.io_uring_enter) => @tagName(linux.SYS.io_uring_enter),
        @intFromEnum(linux.SYS.io_uring_register) => @tagName(linux.SYS.io_uring_register),
        @intFromEnum(linux.SYS.open_tree) => @tagName(linux.SYS.open_tree),
        @intFromEnum(linux.SYS.move_mount) => @tagName(linux.SYS.move_mount),
        @intFromEnum(linux.SYS.fsopen) => @tagName(linux.SYS.fsopen),
        @intFromEnum(linux.SYS.fsconfig) => @tagName(linux.SYS.fsconfig),
        @intFromEnum(linux.SYS.fsmount) => @tagName(linux.SYS.fsmount),
        @intFromEnum(linux.SYS.fspick) => @tagName(linux.SYS.fspick),
        @intFromEnum(linux.SYS.pidfd_open) => @tagName(linux.SYS.pidfd_open),
        @intFromEnum(linux.SYS.clone3) => @tagName(linux.SYS.clone3),
        @intFromEnum(linux.SYS.close_range) => @tagName(linux.SYS.close_range),
        @intFromEnum(linux.SYS.openat2) => @tagName(linux.SYS.openat2),
        @intFromEnum(linux.SYS.pidfd_getfd) => @tagName(linux.SYS.pidfd_getfd),
        @intFromEnum(linux.SYS.faccessat2) => @tagName(linux.SYS.faccessat2),
        @intFromEnum(linux.SYS.process_madvise) => @tagName(linux.SYS.process_madvise),
        @intFromEnum(linux.SYS.epoll_pwait2) => @tagName(linux.SYS.epoll_pwait2),
        @intFromEnum(linux.SYS.mount_setattr) => @tagName(linux.SYS.mount_setattr),
        @intFromEnum(linux.SYS.quotactl_fd) => @tagName(linux.SYS.quotactl_fd),
        @intFromEnum(linux.SYS.landlock_create_ruleset) => @tagName(linux.SYS.landlock_create_ruleset),
        @intFromEnum(linux.SYS.landlock_add_rule) => @tagName(linux.SYS.landlock_add_rule),
        @intFromEnum(linux.SYS.landlock_restrict_self) => @tagName(linux.SYS.landlock_restrict_self),
        @intFromEnum(linux.SYS.memfd_secret) => @tagName(linux.SYS.memfd_secret),
        @intFromEnum(linux.SYS.process_mrelease) => @tagName(linux.SYS.process_mrelease),
        @intFromEnum(linux.SYS.futex_waitv) => @tagName(linux.SYS.futex_waitv),
        @intFromEnum(linux.SYS.set_mempolicy_home_node) => @tagName(linux.SYS.set_mempolicy_home_node),
        @intFromEnum(linux.SYS.cachestat) => @tagName(linux.SYS.cachestat),
        @intFromEnum(linux.SYS.fchmodat2) => @tagName(linux.SYS.fchmodat2),
        @intFromEnum(linux.SYS.map_shadow_stack) => @tagName(linux.SYS.map_shadow_stack),
        @intFromEnum(linux.SYS.futex_wake) => @tagName(linux.SYS.futex_wake),
        @intFromEnum(linux.SYS.futex_wait) => @tagName(linux.SYS.futex_wait),
        @intFromEnum(linux.SYS.futex_requeue) => @tagName(linux.SYS.futex_requeue),
        @intFromEnum(linux.SYS.statmount) => @tagName(linux.SYS.statmount),
        @intFromEnum(linux.SYS.listmount) => @tagName(linux.SYS.listmount),
        @intFromEnum(linux.SYS.lsm_get_self_attr) => @tagName(linux.SYS.lsm_get_self_attr),
        @intFromEnum(linux.SYS.lsm_set_self_attr) => @tagName(linux.SYS.lsm_set_self_attr),
        @intFromEnum(linux.SYS.lsm_list_modules) => @tagName(linux.SYS.lsm_list_modules),
        @intFromEnum(linux.SYS.mseal) => @tagName(linux.SYS.mseal),
        else => "unknown",
    };
}

pub fn getErrorName(errnum: i64) []const u8 {
    const err_num = -errnum;
    return switch (err_num) {
        @intFromEnum(linux.E.PERM) => "EPERM",
        @intFromEnum(linux.E.NOENT) => "ENOENT",
        @intFromEnum(linux.E.SRCH) => "ESRCH",
        @intFromEnum(linux.E.INTR) => "EINTR",
        @intFromEnum(linux.E.IO) => "EIO",
        @intFromEnum(linux.E.NXIO) => "ENXIO",
        @intFromEnum(linux.E.@"2BIG") => "E2BIG",
        @intFromEnum(linux.E.NOEXEC) => "ENOEXEC",
        @intFromEnum(linux.E.BADF) => "EBADF",
        @intFromEnum(linux.E.CHILD) => "ECHILD",
        @intFromEnum(linux.E.AGAIN) => "EAGAIN",
        @intFromEnum(linux.E.NOMEM) => "ENOMEM",
        @intFromEnum(linux.E.ACCES) => "EACCES",
        @intFromEnum(linux.E.FAULT) => "EFAULT",
        @intFromEnum(linux.E.NOTBLK) => "ENOTBLK",
        @intFromEnum(linux.E.BUSY) => "EBUSY",
        @intFromEnum(linux.E.EXIST) => "EEXIST",
        @intFromEnum(linux.E.XDEV) => "EXDEV",
        @intFromEnum(linux.E.NODEV) => "ENODEV",
        @intFromEnum(linux.E.NOTDIR) => "ENOTDIR",
        @intFromEnum(linux.E.ISDIR) => "EISDIR",
        @intFromEnum(linux.E.INVAL) => "EINVAL",
        @intFromEnum(linux.E.NFILE) => "ENFILE",
        @intFromEnum(linux.E.MFILE) => "EMFILE",
        @intFromEnum(linux.E.NOTTY) => "ENOTTY",
        @intFromEnum(linux.E.TXTBSY) => "ETXTBSY",
        @intFromEnum(linux.E.FBIG) => "EFBIG",
        @intFromEnum(linux.E.NOSPC) => "ENOSPC",
        @intFromEnum(linux.E.SPIPE) => "ESPIPE",
        @intFromEnum(linux.E.ROFS) => "EROFS",
        @intFromEnum(linux.E.MLINK) => "EMLINK",
        @intFromEnum(linux.E.PIPE) => "EPIPE",
        @intFromEnum(linux.E.DOM) => "EDOM",
        @intFromEnum(linux.E.RANGE) => "ERANGE",
        @intFromEnum(linux.E.DEADLK) => "EDEADLK",
        @intFromEnum(linux.E.NAMETOOLONG) => "ENAMETOOLONG",
        @intFromEnum(linux.E.NOLCK) => "ENOLCK",
        @intFromEnum(linux.E.NOSYS) => "ENOSYS",
        @intFromEnum(linux.E.NOTEMPTY) => "ENOTEMPTY",
        @intFromEnum(linux.E.LOOP) => "ELOOP",
        //c.EWOULDBLOCK => "EWOULDBLOCK",
        @intFromEnum(linux.E.NOMSG) => "ENOMSG",
        @intFromEnum(linux.E.IDRM) => "EIDRM",
        @intFromEnum(linux.E.CHRNG) => "ECHRNG",
        @intFromEnum(linux.E.L2NSYNC) => "EL2NSYNC",
        @intFromEnum(linux.E.L3HLT) => "EL3HLT",
        @intFromEnum(linux.E.L3RST) => "EL3RST",
        @intFromEnum(linux.E.LNRNG) => "ELNRNG",
        @intFromEnum(linux.E.UNATCH) => "EUNATCH",
        @intFromEnum(linux.E.NOCSI) => "ENOCSI",
        @intFromEnum(linux.E.L2HLT) => "EL2HLT",
        @intFromEnum(linux.E.BADE) => "EBADE",
        @intFromEnum(linux.E.BADR) => "EBADR",
        @intFromEnum(linux.E.XFULL) => "EXFULL",
        @intFromEnum(linux.E.NOANO) => "ENOANO",
        @intFromEnum(linux.E.BADRQC) => "EBADRQC",
        @intFromEnum(linux.E.BADSLT) => "EBADSLT",
        // c.EDEADLOCK => "EDEADLOCK",
        @intFromEnum(linux.E.BFONT) => "EBFONT",
        @intFromEnum(linux.E.NOSTR) => "ENOSTR",
        @intFromEnum(linux.E.NODATA) => "ENODATA",
        @intFromEnum(linux.E.TIME) => "ETIME",
        @intFromEnum(linux.E.NOSR) => "ENOSR",
        @intFromEnum(linux.E.NONET) => "ENONET",
        @intFromEnum(linux.E.NOPKG) => "ENOPKG",
        @intFromEnum(linux.E.REMOTE) => "EREMOTE",
        @intFromEnum(linux.E.NOLINK) => "ENOLINK",
        @intFromEnum(linux.E.ADV) => "EADV",
        @intFromEnum(linux.E.SRMNT) => "ESRMNT",
        @intFromEnum(linux.E.COMM) => "ECOMM",
        @intFromEnum(linux.E.PROTO) => "EPROTO",
        @intFromEnum(linux.E.MULTIHOP) => "EMULTIHOP",
        @intFromEnum(linux.E.DOTDOT) => "EDOTDOT",
        @intFromEnum(linux.E.BADMSG) => "EBADMSG",
        @intFromEnum(linux.E.OVERFLOW) => "EOVERFLOW",
        @intFromEnum(linux.E.NOTUNIQ) => "ENOTUNIQ",
        @intFromEnum(linux.E.BADFD) => "EBADFD",
        @intFromEnum(linux.E.REMCHG) => "EREMCHG",
        @intFromEnum(linux.E.LIBACC) => "ELIBACC",
        @intFromEnum(linux.E.LIBBAD) => "ELIBBAD",
        @intFromEnum(linux.E.LIBSCN) => "ELIBSCN",
        @intFromEnum(linux.E.LIBMAX) => "ELIBMAX",
        @intFromEnum(linux.E.LIBEXEC) => "ELIBEXEC",
        @intFromEnum(linux.E.ILSEQ) => "EILSEQ",
        @intFromEnum(linux.E.RESTART) => "ERESTART",
        @intFromEnum(linux.E.STRPIPE) => "ESTRPIPE",
        @intFromEnum(linux.E.USERS) => "EUSERS",
        @intFromEnum(linux.E.NOTSOCK) => "ENOTSOCK",
        @intFromEnum(linux.E.DESTADDRREQ) => "EDESTADDRREQ",
        @intFromEnum(linux.E.MSGSIZE) => "EMSGSIZE",
        @intFromEnum(linux.E.PROTOTYPE) => "EPROTOTYPE",
        @intFromEnum(linux.E.NOPROTOOPT) => "ENOPROTOOPT",
        @intFromEnum(linux.E.PROTONOSUPPORT) => "EPROTONOSUPPORT",
        @intFromEnum(linux.E.SOCKTNOSUPPORT) => "ESOCKTNOSUPPORT",
        @intFromEnum(linux.E.OPNOTSUPP) => "EOPNOTSUPP",
        @intFromEnum(linux.E.PFNOSUPPORT) => "EPFNOSUPPORT",
        @intFromEnum(linux.E.AFNOSUPPORT) => "EAFNOSUPPORT",
        @intFromEnum(linux.E.ADDRINUSE) => "EADDRINUSE",
        @intFromEnum(linux.E.ADDRNOTAVAIL) => "EADDRNOTAVAIL",
        @intFromEnum(linux.E.NETDOWN) => "ENETDOWN",
        @intFromEnum(linux.E.NETUNREACH) => "ENETUNREACH",
        @intFromEnum(linux.E.NETRESET) => "ENETRESET",
        @intFromEnum(linux.E.CONNABORTED) => "ECONNABORTED",
        @intFromEnum(linux.E.CONNRESET) => "ECONNRESET",
        @intFromEnum(linux.E.NOBUFS) => "ENOBUFS",
        @intFromEnum(linux.E.ISCONN) => "EISCONN",
        @intFromEnum(linux.E.NOTCONN) => "ENOTCONN",
        @intFromEnum(linux.E.SHUTDOWN) => "ESHUTDOWN",
        @intFromEnum(linux.E.TOOMANYREFS) => "ETOOMANYREFS",
        @intFromEnum(linux.E.TIMEDOUT) => "ETIMEDOUT",
        @intFromEnum(linux.E.CONNREFUSED) => "ECONNREFUSED",
        @intFromEnum(linux.E.HOSTDOWN) => "EHOSTDOWN",
        @intFromEnum(linux.E.HOSTUNREACH) => "EHOSTUNREACH",
        @intFromEnum(linux.E.ALREADY) => "EALREADY",
        @intFromEnum(linux.E.INPROGRESS) => "EINPROGRESS",
        @intFromEnum(linux.E.STALE) => "ESTALE",
        @intFromEnum(linux.E.UCLEAN) => "EUCLEAN",
        @intFromEnum(linux.E.NOTNAM) => "ENOTNAM",
        @intFromEnum(linux.E.NAVAIL) => "ENAVAIL",
        @intFromEnum(linux.E.ISNAM) => "EISNAM",
        @intFromEnum(linux.E.REMOTEIO) => "EREMOTEIO",
        @intFromEnum(linux.E.DQUOT) => "EDQUOT",
        @intFromEnum(linux.E.NOMEDIUM) => "ENOMEDIUM",
        @intFromEnum(linux.E.MEDIUMTYPE) => "EMEDIUMTYPE",
        @intFromEnum(linux.E.CANCELED) => "ECANCELED",
        @intFromEnum(linux.E.NOKEY) => "ENOKEY",
        @intFromEnum(linux.E.KEYEXPIRED) => "EKEYEXPIRED",
        @intFromEnum(linux.E.KEYREVOKED) => "EKEYREVOKED",
        @intFromEnum(linux.E.KEYREJECTED) => "EKEYREJECTED",
        @intFromEnum(linux.E.OWNERDEAD) => "EOWNERDEAD",
        @intFromEnum(linux.E.NOTRECOVERABLE) => "ENOTRECOVERABLE",
        @intFromEnum(linux.E.RFKILL) => "ERFKILL",
        @intFromEnum(linux.E.HWPOISON) => "EHWPOISON",
        // ENOTSUP = EOPNOTSUPP
        else => "",
    };
}

pub fn getErrorDescription(errnum: i64) []const u8 {
    const err_num = -errnum;
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

    const access_mode = flags & O_ACCMODE;

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
    const f = try std.fmt.bufPrint(&buff, "0x{x}", .{flags});
    return f;
}

pub fn accessModeToString(mode: u64) ![]const u8 {
    if (mode == linux.F_OK) return "F_OK";
    if (mode == linux.R_OK) return "R_OK";
    if (mode == linux.W_OK) return "W_OK";
    if (mode == linux.X_OK) return "X_OK";
    var buff: [1024]u8 = undefined;
    const f = try std.fmt.bufPrint(&buff, "0x{x}", .{mode});
    return f;
}

pub fn mapRlimittoString(limit: u64) []const u8 {
    return switch (limit) {
        @intFromEnum(linux.rlimit_resource.CPU) => @tagName(linux.rlimit_resource.CPU),
        @intFromEnum(linux.rlimit_resource.FSIZE) => @tagName(linux.rlimit_resource.FSIZE),
        @intFromEnum(linux.rlimit_resource.DATA) => @tagName(linux.rlimit_resource.DATA),
        @intFromEnum(linux.rlimit_resource.STACK) => @tagName(linux.rlimit_resource.STACK),
        @intFromEnum(linux.rlimit_resource.CORE) => @tagName(linux.rlimit_resource.CORE),
        @intFromEnum(linux.rlimit_resource.RSS) => @tagName(linux.rlimit_resource.RSS),
        @intFromEnum(linux.rlimit_resource.NPROC) => @tagName(linux.rlimit_resource.NPROC),
        @intFromEnum(linux.rlimit_resource.NOFILE) => @tagName(linux.rlimit_resource.NOFILE),
        @intFromEnum(linux.rlimit_resource.MEMLOCK) => @tagName(linux.rlimit_resource.MEMLOCK),
        @intFromEnum(linux.rlimit_resource.AS) => @tagName(linux.rlimit_resource.AS),
        @intFromEnum(linux.rlimit_resource.LOCKS) => @tagName(linux.rlimit_resource.LOCKS),
        @intFromEnum(linux.rlimit_resource.SIGPENDING) => @tagName(linux.rlimit_resource.SIGPENDING),
        @intFromEnum(linux.rlimit_resource.MSGQUEUE) => @tagName(linux.rlimit_resource.MSGQUEUE),
        @intFromEnum(linux.rlimit_resource.NICE) => @tagName(linux.rlimit_resource.NICE),
        @intFromEnum(linux.rlimit_resource.RTPRIO) => @tagName(linux.rlimit_resource.RTPRIO),
        @intFromEnum(linux.rlimit_resource.RTTIME) => @tagName(linux.rlimit_resource.RTTIME),
        else => "",
    };
}

pub fn mmapProtToString(prot: u64) []const u8 {
    if (prot == linux.PROT.NONE) return "PROT_NONE";
    if (prot == linux.PROT.READ) return "PROT_READ";
    if (prot == (linux.PROT.READ | linux.PROT.WRITE)) return "PROT_READ|PROT_WRITE";
    if (prot == (linux.PROT.READ | linux.PROT.EXEC)) return "PROT_READ|PROT_EXEC";
    if (prot == (linux.PROT.READ | linux.PROT.WRITE | linux.PROT.EXEC)) return "PROT_READ|PROT_WRITE|PROT_EXEC";
    if (prot == (linux.PROT.WRITE)) return "PROT_WRITE";
    if (prot == (linux.PROT.EXEC)) return "PROT_EXEC";
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

pub fn mapPrToString(pr: u64) []const u8 {
    return switch (pr) {
        @intFromEnum(linux.PR.SET_PDEATHSIG) => @tagName(linux.PR.SET_PDEATHSIG),
        @intFromEnum(linux.PR.GET_PDEATHSIG) => @tagName(linux.PR.GET_PDEATHSIG),
        @intFromEnum(linux.PR.GET_DUMPABLE) => @tagName(linux.PR.GET_DUMPABLE),
        @intFromEnum(linux.PR.SET_DUMPABLE) => @tagName(linux.PR.SET_DUMPABLE),
        @intFromEnum(linux.PR.GET_UNALIGN) => @tagName(linux.PR.GET_UNALIGN),
        @intFromEnum(linux.PR.SET_UNALIGN) => @tagName(linux.PR.SET_UNALIGN),
        @intFromEnum(linux.PR.GET_KEEPCAPS) => @tagName(linux.PR.GET_KEEPCAPS),
        @intFromEnum(linux.PR.SET_KEEPCAPS) => @tagName(linux.PR.SET_KEEPCAPS),
        @intFromEnum(linux.PR.GET_FPEMU) => @tagName(linux.PR.GET_FPEMU),
        @intFromEnum(linux.PR.SET_FPEMU) => @tagName(linux.PR.SET_FPEMU),
        @intFromEnum(linux.PR.GET_FPEXC) => @tagName(linux.PR.GET_FPEXC),
        @intFromEnum(linux.PR.SET_FPEXC) => @tagName(linux.PR.SET_FPEXC),
        @intFromEnum(linux.PR.GET_TIMING) => @tagName(linux.PR.GET_TIMING),
        @intFromEnum(linux.PR.SET_TIMING) => @tagName(linux.PR.SET_TIMING),
        @intFromEnum(linux.PR.SET_NAME) => @tagName(linux.PR.SET_NAME),
        @intFromEnum(linux.PR.GET_NAME) => @tagName(linux.PR.GET_NAME),
        @intFromEnum(linux.PR.GET_ENDIAN) => @tagName(linux.PR.GET_ENDIAN),
        @intFromEnum(linux.PR.SET_ENDIAN) => @tagName(linux.PR.SET_ENDIAN),
        @intFromEnum(linux.PR.GET_SECCOMP) => @tagName(linux.PR.GET_SECCOMP),
        @intFromEnum(linux.PR.SET_SECCOMP) => @tagName(linux.PR.SET_SECCOMP),
        @intFromEnum(linux.PR.CAPBSET_READ) => @tagName(linux.PR.CAPBSET_READ),
        @intFromEnum(linux.PR.CAPBSET_DROP) => @tagName(linux.PR.CAPBSET_DROP),
        @intFromEnum(linux.PR.GET_TSC) => @tagName(linux.PR.GET_TSC),
        @intFromEnum(linux.PR.SET_TSC) => @tagName(linux.PR.SET_TSC),
        @intFromEnum(linux.PR.GET_SECUREBITS) => @tagName(linux.PR.GET_SECUREBITS),
        @intFromEnum(linux.PR.SET_SECUREBITS) => @tagName(linux.PR.SET_SECUREBITS),
        @intFromEnum(linux.PR.SET_TIMERSLACK) => @tagName(linux.PR.SET_TIMERSLACK),
        @intFromEnum(linux.PR.GET_TIMERSLACK) => @tagName(linux.PR.GET_TIMERSLACK),
        @intFromEnum(linux.PR.TASK_PERF_EVENTS_DISABLE) => @tagName(linux.PR.TASK_PERF_EVENTS_DISABLE),
        @intFromEnum(linux.PR.TASK_PERF_EVENTS_ENABLE) => @tagName(linux.PR.TASK_PERF_EVENTS_ENABLE),
        @intFromEnum(linux.PR.MCE_KILL) => @tagName(linux.PR.MCE_KILL),
        @intFromEnum(linux.PR.MCE_KILL_GET) => @tagName(linux.PR.MCE_KILL_GET),
        @intFromEnum(linux.PR.SET_MM) => @tagName(linux.PR.SET_MM),
        @intFromEnum(linux.PR.SET_PTRACER) => @tagName(linux.PR.SET_PTRACER),
        @intFromEnum(linux.PR.SET_CHILD_SUBREAPER) => @tagName(linux.PR.SET_CHILD_SUBREAPER),
        @intFromEnum(linux.PR.GET_CHILD_SUBREAPER) => @tagName(linux.PR.GET_CHILD_SUBREAPER),
        @intFromEnum(linux.PR.SET_NO_NEW_PRIVS) => @tagName(linux.PR.SET_NO_NEW_PRIVS),
        @intFromEnum(linux.PR.GET_NO_NEW_PRIVS) => @tagName(linux.PR.GET_NO_NEW_PRIVS),
        @intFromEnum(linux.PR.GET_TID_ADDRESS) => @tagName(linux.PR.GET_TID_ADDRESS),
        @intFromEnum(linux.PR.SET_THP_DISABLE) => @tagName(linux.PR.SET_THP_DISABLE),
        @intFromEnum(linux.PR.GET_THP_DISABLE) => @tagName(linux.PR.GET_THP_DISABLE),
        @intFromEnum(linux.PR.MPX_ENABLE_MANAGEMENT) => @tagName(linux.PR.MPX_ENABLE_MANAGEMENT),
        @intFromEnum(linux.PR.MPX_DISABLE_MANAGEMENT) => @tagName(linux.PR.MPX_DISABLE_MANAGEMENT),
        @intFromEnum(linux.PR.SET_FP_MODE) => @tagName(linux.PR.SET_FP_MODE),
        @intFromEnum(linux.PR.GET_FP_MODE) => @tagName(linux.PR.GET_FP_MODE),
        @intFromEnum(linux.PR.CAP_AMBIENT) => @tagName(linux.PR.CAP_AMBIENT),
        @intFromEnum(linux.PR.SVE_SET_VL) => @tagName(linux.PR.SVE_SET_VL),
        @intFromEnum(linux.PR.SVE_GET_VL) => @tagName(linux.PR.SVE_GET_VL),
        @intFromEnum(linux.PR.GET_SPECULATION_CTRL) => @tagName(linux.PR.GET_SPECULATION_CTRL),
        @intFromEnum(linux.PR.SET_SPECULATION_CTRL) => @tagName(linux.PR.SET_SPECULATION_CTRL),
        else => "",
    };
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
    const cap_str = try std.fmt.bufPrint(&buff, "0x{x} /* CAP_??? */", .{cap});
    return cap_str;
}
