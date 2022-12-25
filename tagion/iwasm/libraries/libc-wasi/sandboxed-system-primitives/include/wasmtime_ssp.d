module wasmtime_ssp;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Part of the Wasmtime Project, under the Apache License v2.0 with
 * LLVM Exceptions. See
 *   https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE
 * for license information.
 *
 * This file declares an interface similar to WASI, but augmented to expose
 * some implementation details such as the curfds arguments that we pass
 * around to avoid storing them in TLS.
 */

/**
 * The defitions of type, macro and structure in this file should be
 * consistent with those in wasi-libc:
 * https://github.com/WebAssembly/wasi-libc/blob/main/libc-bottom-half/headers/public/wasi/api.h
 */

#ifndef WASMTIME_SSP_H
version = WASMTIME_SSP_H;

public import stdbool;
public import core.stdc.stddef;
public import core.stdc.stdint;

/* clang-format off */

#ifdef __cplusplus
version (_Static_assert) {} else {
enum _Static_assert = static_assert;
} /* _Static_assert */

version (_Alignof) {} else {
enum _Alignof = alignof;
} /* _Alignof */

version (_Noreturn) {} else {
enum _Noreturn = [[ noreturn ]];
} /* _Noreturn */
extern "C" {
//! #endif

_Static_assert(_Alignof(int8_t) == 1, "non-wasi data layout");
_Static_assert(_Alignof(uint8_t) == 1, "non-wasi data layout");
_Static_assert(_Alignof(int16_t) == 2, "non-wasi data layout");
_Static_assert(_Alignof(uint16_t) == 2, "non-wasi data layout");
_Static_assert(_Alignof(int32_t) == 4, "non-wasi data layout");
_Static_assert(_Alignof(uint32_t) == 4, "non-wasi data layout");
version (none) {
_Static_assert(_Alignof(int64_t) == 8, "non-wasi data layout");
_Static_assert(_Alignof(uint64_t) == 8, "non-wasi data layout");
}

alias __wasi_size_t = uint;
_Static_assert(_Alignof(__wasi_size_t) == 4, "non-wasi data layout");

alias __wasi_advice_t = ubyte;
enum __WASI_ADVICE_NORMAL =     (0);
enum __WASI_ADVICE_SEQUENTIAL = (1);
enum __WASI_ADVICE_RANDOM =     (2);
enum __WASI_ADVICE_WILLNEED =   (3);
enum __WASI_ADVICE_DONTNEED =   (4);
enum __WASI_ADVICE_NOREUSE =    (5);

alias __wasi_clockid_t = uint;
enum __WASI_CLOCK_REALTIME =           (0);
enum __WASI_CLOCK_MONOTONIC =          (1);
enum __WASI_CLOCK_PROCESS_CPUTIME_ID = (2);
enum __WASI_CLOCK_THREAD_CPUTIME_ID =  (3);

alias __wasi_device_t = ulong;

alias __wasi_dircookie_t = ulong;
enum __WASI_DIRCOOKIE_START = (0);

alias __wasi_dirnamlen_t = uint;

alias __wasi_errno_t = ushort;
enum __WASI_ESUCCESS =        (0);
enum __WASI_E2BIG =           (1);
enum __WASI_EACCES =          (2);
enum __WASI_EADDRINUSE =      (3);
enum __WASI_EADDRNOTAVAIL =   (4);
enum __WASI_EAFNOSUPPORT =    (5);
enum __WASI_EAGAIN =          (6);
enum __WASI_EALREADY =        (7);
enum __WASI_EBADF =           (8);
enum __WASI_EBADMSG =         (9);
enum __WASI_EBUSY =           (10);
enum __WASI_ECANCELED =       (11);
enum __WASI_ECHILD =          (12);
enum __WASI_ECONNABORTED =    (13);
enum __WASI_ECONNREFUSED =    (14);
enum __WASI_ECONNRESET =      (15);
enum __WASI_EDEADLK =         (16);
enum __WASI_EDESTADDRREQ =    (17);
enum __WASI_EDOM =            (18);
enum __WASI_EDQUOT =          (19);
enum __WASI_EEXIST =          (20);
enum __WASI_EFAULT =          (21);
enum __WASI_EFBIG =           (22);
enum __WASI_EHOSTUNREACH =    (23);
enum __WASI_EIDRM =           (24);
enum __WASI_EILSEQ =          (25);
enum __WASI_EINPROGRESS =     (26);
enum __WASI_EINTR =           (27);
enum __WASI_EINVAL =          (28);
enum __WASI_EIO =             (29);
enum __WASI_EISCONN =         (30);
enum __WASI_EISDIR =          (31);
enum __WASI_ELOOP =           (32);
enum __WASI_EMFILE =          (33);
enum __WASI_EMLINK =          (34);
enum __WASI_EMSGSIZE =        (35);
enum __WASI_EMULTIHOP =       (36);
enum __WASI_ENAMETOOLONG =    (37);
enum __WASI_ENETDOWN =        (38);
enum __WASI_ENETRESET =       (39);
enum __WASI_ENETUNREACH =     (40);
enum __WASI_ENFILE =          (41);
enum __WASI_ENOBUFS =         (42);
enum __WASI_ENODEV =          (43);
enum __WASI_ENOENT =          (44);
enum __WASI_ENOEXEC =         (45);
enum __WASI_ENOLCK =          (46);
enum __WASI_ENOLINK =         (47);
enum __WASI_ENOMEM =          (48);
enum __WASI_ENOMSG =          (49);
enum __WASI_ENOPROTOOPT =     (50);
enum __WASI_ENOSPC =          (51);
enum __WASI_ENOSYS =          (52);
enum __WASI_ENOTCONN =        (53);
enum __WASI_ENOTDIR =         (54);
enum __WASI_ENOTEMPTY =       (55);
enum __WASI_ENOTRECOVERABLE = (56);
enum __WASI_ENOTSOCK =        (57);
enum __WASI_ENOTSUP =         (58);
enum __WASI_ENOTTY =          (59);
enum __WASI_ENXIO =           (60);
enum __WASI_EOVERFLOW =       (61);
enum __WASI_EOWNERDEAD =      (62);
enum __WASI_EPERM =           (63);
enum __WASI_EPIPE =           (64);
enum __WASI_EPROTO =          (65);
enum __WASI_EPROTONOSUPPORT = (66);
enum __WASI_EPROTOTYPE =      (67);
enum __WASI_ERANGE =          (68);
enum __WASI_EROFS =           (69);
enum __WASI_ESPIPE =          (70);
enum __WASI_ESRCH =           (71);
enum __WASI_ESTALE =          (72);
enum __WASI_ETIMEDOUT =       (73);
enum __WASI_ETXTBSY =         (74);
enum __WASI_EXDEV =           (75);
enum __WASI_ENOTCAPABLE =     (76);

alias __wasi_eventrwflags_t = ushort;
enum __WASI_EVENT_FD_READWRITE_HANGUP = (0x0001);

alias __wasi_eventtype_t = ubyte;
enum __WASI_EVENTTYPE_CLOCK =          (0);
enum __WASI_EVENTTYPE_FD_READ =        (1);
enum __WASI_EVENTTYPE_FD_WRITE =       (2);

alias __wasi_exitcode_t = uint;

alias __wasi_fd_t = uint;

alias __wasi_fdflags_t = ushort;
enum __WASI_FDFLAG_APPEND =   (0x0001);
enum __WASI_FDFLAG_DSYNC =    (0x0002);
enum __WASI_FDFLAG_NONBLOCK = (0x0004);
enum __WASI_FDFLAG_RSYNC =    (0x0008);
enum __WASI_FDFLAG_SYNC =     (0x0010);

alias __wasi_filedelta_t = long;

alias __wasi_filesize_t = ulong;

alias __wasi_filetype_t = ubyte;
enum __WASI_FILETYPE_UNKNOWN =          (0);
enum __WASI_FILETYPE_BLOCK_DEVICE =     (1);
enum __WASI_FILETYPE_CHARACTER_DEVICE = (2);
enum __WASI_FILETYPE_DIRECTORY =        (3);
enum __WASI_FILETYPE_REGULAR_FILE =     (4);
enum __WASI_FILETYPE_SOCKET_DGRAM =     (5);
enum __WASI_FILETYPE_SOCKET_STREAM =    (6);
enum __WASI_FILETYPE_SYMBOLIC_LINK =    (7);

alias __wasi_fstflags_t = ushort;
enum __WASI_FILESTAT_SET_ATIM =     (0x0001);
enum __WASI_FILESTAT_SET_ATIM_NOW = (0x0002);
enum __WASI_FILESTAT_SET_MTIM =     (0x0004);
enum __WASI_FILESTAT_SET_MTIM_NOW = (0x0008);

alias __wasi_inode_t = ulong;

alias __wasi_linkcount_t = ulong; __attribute__((aligned(8))){}

alias __wasi_lookupflags_t = uint;
enum __WASI_LOOKUP_SYMLINK_FOLLOW = (0x00000001);

alias __wasi_oflags_t = ushort;
enum __WASI_O_CREAT =     (0x0001);
enum __WASI_O_DIRECTORY = (0x0002);
enum __WASI_O_EXCL =      (0x0004);
enum __WASI_O_TRUNC =     (0x0008);

alias __wasi_riflags_t = ushort;
enum __WASI_SOCK_RECV_PEEK =    (0x0001);
enum __WASI_SOCK_RECV_WAITALL = (0x0002);

alias __wasi_rights_t = ulong;

/**
 * Observe that WASI defines rights in the plural form
 * TODO: refactor to use RIGHTS instead of RIGHT
 */
enum __WASI_RIGHT_FD_DATASYNC = ((__wasi_rights_t)(UINT64_C(1) << 0));
enum __WASI_RIGHT_FD_READ = ((__wasi_rights_t)(UINT64_C(1) << 1));
enum __WASI_RIGHT_FD_SEEK = ((__wasi_rights_t)(UINT64_C(1) << 2));
enum __WASI_RIGHT_FD_FDSTAT_SET_FLAGS = ((__wasi_rights_t)(UINT64_C(1) << 3));
enum __WASI_RIGHT_FD_SYNC = ((__wasi_rights_t)(UINT64_C(1) << 4));
enum __WASI_RIGHT_FD_TELL = ((__wasi_rights_t)(UINT64_C(1) << 5));
enum __WASI_RIGHT_FD_WRITE = ((__wasi_rights_t)(UINT64_C(1) << 6));
enum __WASI_RIGHT_FD_ADVISE = ((__wasi_rights_t)(UINT64_C(1) << 7));
enum __WASI_RIGHT_FD_ALLOCATE = ((__wasi_rights_t)(UINT64_C(1) << 8));
enum __WASI_RIGHT_PATH_CREATE_DIRECTORY = ((__wasi_rights_t)(UINT64_C(1) << 9));
enum __WASI_RIGHT_PATH_CREATE_FILE = ((__wasi_rights_t)(UINT64_C(1) << 10));
enum __WASI_RIGHT_PATH_LINK_SOURCE = ((__wasi_rights_t)(UINT64_C(1) << 11));
enum __WASI_RIGHT_PATH_LINK_TARGET = ((__wasi_rights_t)(UINT64_C(1) << 12));
enum __WASI_RIGHT_PATH_OPEN = ((__wasi_rights_t)(UINT64_C(1) << 13));
enum __WASI_RIGHT_FD_READDIR = ((__wasi_rights_t)(UINT64_C(1) << 14));
enum __WASI_RIGHT_PATH_READLINK = ((__wasi_rights_t)(UINT64_C(1) << 15));
enum __WASI_RIGHT_PATH_RENAME_SOURCE = ((__wasi_rights_t)(UINT64_C(1) << 16));
enum __WASI_RIGHT_PATH_RENAME_TARGET = ((__wasi_rights_t)(UINT64_C(1) << 17));
enum __WASI_RIGHT_PATH_FILESTAT_GET = ((__wasi_rights_t)(UINT64_C(1) << 18));
enum __WASI_RIGHT_PATH_FILESTAT_SET_SIZE = ((__wasi_rights_t)(UINT64_C(1) << 19));
enum __WASI_RIGHT_PATH_FILESTAT_SET_TIMES = ((__wasi_rights_t)(UINT64_C(1) << 20));
enum __WASI_RIGHT_FD_FILESTAT_GET = ((__wasi_rights_t)(UINT64_C(1) << 21));
enum __WASI_RIGHT_FD_FILESTAT_SET_SIZE = ((__wasi_rights_t)(UINT64_C(1) << 22));
enum __WASI_RIGHT_FD_FILESTAT_SET_TIMES = ((__wasi_rights_t)(UINT64_C(1) << 23));
enum __WASI_RIGHT_PATH_SYMLINK = ((__wasi_rights_t)(UINT64_C(1) << 24));
enum __WASI_RIGHT_PATH_REMOVE_DIRECTORY = ((__wasi_rights_t)(UINT64_C(1) << 25));
enum __WASI_RIGHT_PATH_UNLINK_FILE = ((__wasi_rights_t)(UINT64_C(1) << 26));
enum __WASI_RIGHT_POLL_FD_READWRITE = ((__wasi_rights_t)(UINT64_C(1) << 27));
enum __WASI_RIGHT_SOCK_CONNECT = ((__wasi_rights_t)(UINT64_C(1) << 28));
enum __WASI_RIGHT_SOCK_LISTEN = ((__wasi_rights_t)(UINT64_C(1) << 29));
enum __WASI_RIGHT_SOCK_BIND = ((__wasi_rights_t)(UINT64_C(1) << 30));
enum __WASI_RIGHT_SOCK_ACCEPT = ((__wasi_rights_t)(UINT64_C(1) << 31));
enum __WASI_RIGHT_SOCK_RECV = ((__wasi_rights_t)(UINT64_C(1) << 32));
enum __WASI_RIGHT_SOCK_SEND = ((__wasi_rights_t)(UINT64_C(1) << 33));
enum __WASI_RIGHT_SOCK_ADDR_LOCAL = ((__wasi_rights_t)(UINT64_C(1) << 34));
enum __WASI_RIGHT_SOCK_ADDR_REMOTE = ((__wasi_rights_t)(UINT64_C(1) << 35));
enum __WASI_RIGHT_SOCK_RECV_FROM = ((__wasi_rights_t)(UINT64_C(1) << 36));
enum __WASI_RIGHT_SOCK_SEND_TO = ((__wasi_rights_t)(UINT64_C(1) << 37));

alias __wasi_roflags_t = ushort;
enum __WASI_SOCK_RECV_DATA_TRUNCATED = (0x0001);

alias __wasi_sdflags_t = ubyte;
enum __WASI_SHUT_RD = (0x01);
enum __WASI_SHUT_WR = (0x02);

alias __wasi_siflags_t = ushort;

alias __wasi_signal_t = ubyte;
// 0 is reserved; POSIX has special semantics for kill(pid, 0).
enum __WASI_SIGHUP =    (1);
enum __WASI_SIGINT =    (2);
enum __WASI_SIGQUIT =   (3);
enum __WASI_SIGILL =    (4);
enum __WASI_SIGTRAP =   (5);
enum __WASI_SIGABRT =   (6);
enum __WASI_SIGBUS =    (7);
enum __WASI_SIGFPE =    (8);
enum __WASI_SIGKILL =   (9);
enum __WASI_SIGUSR1 =   (10);
enum __WASI_SIGSEGV =   (11);
enum __WASI_SIGUSR2 =   (12);
enum __WASI_SIGPIPE =   (13);
enum __WASI_SIGALRM =   (14);
enum __WASI_SIGTERM =   (15);
enum __WASI_SIGCHLD =   (16);
enum __WASI_SIGCONT =   (17);
enum __WASI_SIGSTOP =   (18);
enum __WASI_SIGTSTP =   (19);
enum __WASI_SIGTTIN =   (20);
enum __WASI_SIGTTOU =   (21);
enum __WASI_SIGURG =    (22);
enum __WASI_SIGXCPU =   (23);
enum __WASI_SIGXFSZ =   (24);
enum __WASI_SIGVTALRM = (25);
enum __WASI_SIGPROF =   (26);
enum __WASI_SIGWINCH =  (27);
enum __WASI_SIGPOLL =   (28);
enum __WASI_SIGPWR =    (29);
enum __WASI_SIGSYS =    (30);

alias __wasi_subclockflags_t = ushort;
enum __WASI_SUBSCRIPTION_CLOCK_ABSTIME = (0x0001);

alias __wasi_timestamp_t = ulong;

alias __wasi_userdata_t = ulong;

alias __wasi_whence_t = ubyte;
enum __WASI_WHENCE_SET = (0);
enum __WASI_WHENCE_CUR = (1);
enum __WASI_WHENCE_END = (2);

alias __wasi_preopentype_t = ubyte;
enum __WASI_PREOPENTYPE_DIR =              (0);

struct fd_table;;
struct fd_prestats;;
struct argv_environ_values;;
struct addr_pool;;

struct __wasi_dirent_t {
    __wasi_dircookie_t d_next;
    __wasi_inode_t d_ino;
    __wasi_dirnamlen_t d_namlen;
    __wasi_filetype_t d_type;
} __attribute__((aligned(8))){}
_Static_assert(__wasi_dirent_t.d_next.offsetof == 0, "non-wasi data layout");
_Static_assert(__wasi_dirent_t.d_ino.offsetof == 8, "non-wasi data layout");
_Static_assert(__wasi_dirent_t.d_namlen.offsetof == 16, "non-wasi data layout");
_Static_assert(__wasi_dirent_t.d_type.offsetof == 20, "non-wasi data layout");
_Static_assert(__wasi_dirent_t.sizeof == 24, "non-wasi data layout");
_Static_assert(_Alignof(__wasi_dirent_t) == 8, "non-wasi data layout");

struct __wasi_event_t {
    __wasi_userdata_t userdata;
    __wasi_errno_t error;
    __wasi_eventtype_t type;
    ubyte[5] __paddings;
    union __wasi_event_u {
        struct __wasi_event_u_fd_readwrite_t {
            __wasi_filesize_t nbytes;
            __wasi_eventrwflags_t flags;
            ubyte[6] __paddings;
        }__wasi_event_u_fd_readwrite_t fd_readwrite;
    }__wasi_event_u u;
} __attribute__((aligned(8))){}
_Static_assert(__wasi_event_t.userdata.offsetof == 0, "non-wasi data layout");
_Static_assert(__wasi_event_t.error.offsetof == 8, "non-wasi data layout");
_Static_assert(__wasi_event_t.type.offsetof == 10, "non-wasi data layout");
_Static_assert(
    offsetof(__wasi_event_t, u.fd_readwrite.nbytes) == 16, "non-wasi data layout");
_Static_assert(
    offsetof(__wasi_event_t, u.fd_readwrite.flags) == 24, "non-wasi data layout");
_Static_assert(__wasi_event_t.sizeof == 32, "non-wasi data layout");
_Static_assert(_Alignof(__wasi_event_t) == 8, "non-wasi data layout");

struct __wasi_prestat_t {
    __wasi_preopentype_t pr_type;
    union __wasi_prestat_u {
        struct __wasi_prestat_u_dir_t {
            size_t pr_name_len;
        }__wasi_prestat_u_dir_t dir;
    }__wasi_prestat_u u;
}
_Static_assert(__wasi_prestat_t.pr_type.offsetof == 0, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    offsetof(__wasi_prestat_t, u.dir.pr_name_len) == 4, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    offsetof(__wasi_prestat_t, u.dir.pr_name_len) == 8, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    __wasi_prestat_t.sizeof == 8, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    __wasi_prestat_t.sizeof == 16, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    _Alignof(__wasi_prestat_t) == 4, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    _Alignof(__wasi_prestat_t) == 8, "non-wasi data layout");

struct __wasi_fdstat_t {
    __wasi_filetype_t fs_filetype;
    __wasi_fdflags_t fs_flags;
    ubyte[4] __paddings;
    __wasi_rights_t fs_rights_base;
    __wasi_rights_t fs_rights_inheriting;
} __attribute__((aligned(8))){}
_Static_assert(
    __wasi_fdstat_t.fs_filetype.offsetof == 0, "non-wasi data layout");
_Static_assert(__wasi_fdstat_t.fs_flags.offsetof == 2, "non-wasi data layout");
_Static_assert(
    __wasi_fdstat_t.fs_rights_base.offsetof == 8, "non-wasi data layout");
_Static_assert(
    __wasi_fdstat_t.fs_rights_inheriting.offsetof == 16,
    "non-wasi data layout");
_Static_assert(__wasi_fdstat_t.sizeof == 24, "non-wasi data layout");
_Static_assert(_Alignof(__wasi_fdstat_t) == 8, "non-wasi data layout");

struct __wasi_filestat_t {
    __wasi_device_t st_dev;
    __wasi_inode_t st_ino;
    __wasi_filetype_t st_filetype;
    __wasi_linkcount_t st_nlink;
    __wasi_filesize_t st_size;
    __wasi_timestamp_t st_atim;
    __wasi_timestamp_t st_mtim;
    __wasi_timestamp_t st_ctim;
} __attribute__((aligned(8))){}
_Static_assert(__wasi_filestat_t.st_dev.offsetof == 0, "non-wasi data layout");
_Static_assert(__wasi_filestat_t.st_ino.offsetof == 8, "non-wasi data layout");
_Static_assert(
    __wasi_filestat_t.st_filetype.offsetof == 16, "non-wasi data layout");
_Static_assert(
    __wasi_filestat_t.st_nlink.offsetof == 24, "non-wasi data layout");
_Static_assert(
    __wasi_filestat_t.st_size.offsetof == 32, "non-wasi data layout");
_Static_assert(
    __wasi_filestat_t.st_atim.offsetof == 40, "non-wasi data layout");
_Static_assert(
    __wasi_filestat_t.st_mtim.offsetof == 48, "non-wasi data layout");
_Static_assert(
    __wasi_filestat_t.st_ctim.offsetof == 56, "non-wasi data layout");
_Static_assert(__wasi_filestat_t.sizeof == 64, "non-wasi data layout");
_Static_assert(_Alignof(__wasi_filestat_t) == 8, "non-wasi data layout");

struct __wasi_ciovec_t {
    const(void)* buf;
    size_t buf_len;
}
_Static_assert(__wasi_ciovec_t.buf.offsetof == 0, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    __wasi_ciovec_t.buf_len.offsetof == 4, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    __wasi_ciovec_t.buf_len.offsetof == 8, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    __wasi_ciovec_t.sizeof == 8, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    __wasi_ciovec_t.sizeof == 16, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    _Alignof(__wasi_ciovec_t) == 4, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    _Alignof(__wasi_ciovec_t) == 8, "non-wasi data layout");

struct __wasi_iovec_t {
    void* buf;
    size_t buf_len;
}
_Static_assert(__wasi_iovec_t.buf.offsetof == 0, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    __wasi_iovec_t.buf_len.offsetof == 4, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    __wasi_iovec_t.buf_len.offsetof == 8, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    __wasi_iovec_t.sizeof == 8, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    __wasi_iovec_t.sizeof == 16, "non-wasi data layout");
_Static_assert((void*).sizeof != 4 ||
    _Alignof(__wasi_iovec_t) == 4, "non-wasi data layout");
_Static_assert((void*).sizeof != 8 ||
    _Alignof(__wasi_iovec_t) == 8, "non-wasi data layout");

/**
 * The contents of a `subscription` when type is `eventtype::clock`.
 */
struct __wasi_subscription_clock_t {
    /**
     * The clock against which to compare the timestamp.
     */
    __wasi_clockid_t clock_id;

    ubyte[4] __paddings1;

    /**
     * The absolute or relative timestamp.
     */
    __wasi_timestamp_t timeout;

    /**
     * The amount of time that the implementation may wait additionally
     * to coalesce with other events.
     */
    __wasi_timestamp_t precision;

    /**
     * Flags specifying whether the timeout is absolute or relative
     */
    __wasi_subclockflags_t flags;

    ubyte[4] __paddings2;

} __attribute__((aligned(8))){}

_Static_assert(__wasi_subscription_clock_t.sizeof == 32, "witx calculated size");
_Static_assert(_Alignof(__wasi_subscription_clock_t) == 8, "witx calculated align");
_Static_assert(__wasi_subscription_clock_t.clock_id.offsetof == 0, "witx calculated offset");
_Static_assert(__wasi_subscription_clock_t.timeout.offsetof == 8, "witx calculated offset");
_Static_assert(__wasi_subscription_clock_t.precision.offsetof == 16, "witx calculated offset");
_Static_assert(__wasi_subscription_clock_t.flags.offsetof == 24, "witx calculated offset");

/**
 * The contents of a `subscription` when type is type is
 * `eventtype::fd_read` or `eventtype::fd_write`.
 */
struct __wasi_subscription_fd_readwrite_t {
    /**
     * The file descriptor on which to wait for it to become ready for reading or writing.
     */
    __wasi_fd_t fd;

}

_Static_assert(__wasi_subscription_fd_readwrite_t.sizeof == 4, "witx calculated size");
_Static_assert(_Alignof(__wasi_subscription_fd_readwrite_t) == 4, "witx calculated align");
_Static_assert(__wasi_subscription_fd_readwrite_t.fd.offsetof == 0, "witx calculated offset");

/**
 * The contents of a `subscription`.
 */
union __wasi_subscription_u_u_t {
    __wasi_subscription_clock_t clock;
    __wasi_subscription_fd_readwrite_t fd_readwrite;
}

struct __wasi_subscription_u_t {
    __wasi_eventtype_t type;
    __wasi_subscription_u_u_t u;
} __attribute__((aligned(8))){}

_Static_assert(__wasi_subscription_u_t.sizeof == 40, "witx calculated size");
_Static_assert(_Alignof(__wasi_subscription_u_t) == 8, "witx calculated align");
_Static_assert(__wasi_subscription_u_t.u.offsetof == 8, "witx calculated union offset");
_Static_assert(__wasi_subscription_u_u_t.sizeof == 32, "witx calculated union size");
_Static_assert(_Alignof(__wasi_subscription_u_u_t) == 8, "witx calculated union align");

/**
 * Subscription to an event.
 */
struct __wasi_subscription_t {
    /**
     * User-provided value that is attached to the subscription in the
     * implementation and returned through `event::userdata`.
     */
    __wasi_userdata_t userdata;

    /**
     * The type of the event to which to subscribe, and its contents
     */
    __wasi_subscription_u_t u;

}

_Static_assert(__wasi_subscription_t.sizeof == 48, "witx calculated size");
_Static_assert(_Alignof(__wasi_subscription_t) == 8, "witx calculated align");
_Static_assert(__wasi_subscription_t.userdata.offsetof == 0, "witx calculated offset");
_Static_assert(__wasi_subscription_t.u.offsetof == 8, "witx calculated offset");

/* keep syncing with wasi_socket_ext.h */
enum ___wasi_sock_type_t {
    SOCKET_DGRAM = 0,
    SOCKET_STREAM,
}alias __wasi_sock_type_t = ___wasi_sock_type_t;

alias __wasi_ip_port_t = ushort;

enum ___wasi_addr_type_t { IPv4 = 0, IPv6 }alias __wasi_addr_type_t = ___wasi_addr_type_t;

/* n0.n1.n2.n3 */
struct __wasi_addr_ip4_t {
    ubyte n0;
    ubyte n1;
    ubyte n2;
    ubyte n3;
}

struct __wasi_addr_ip4_port_t {
    __wasi_addr_ip4_t addr;
    __wasi_ip_port_t port;
}

struct __wasi_addr_ip6_t {
    ushort n0;
    ushort n1;
    ushort n2;
    ushort n3;
    ushort h0;
    ushort h1;
    ushort h2;
    ushort h3;
}

struct __wasi_addr_ip6_port_t {
    __wasi_addr_ip6_t addr;
    __wasi_ip_port_t port;
}

struct __wasi_addr_ip_t {
    __wasi_addr_type_t kind;
    union _Addr {
        __wasi_addr_ip4_t ip4;
        __wasi_addr_ip6_t ip6;
    }_Addr addr;
}

struct __wasi_addr_t {
    __wasi_addr_type_t kind;
    union _Addr {
        __wasi_addr_ip4_port_t ip4;
        __wasi_addr_ip6_port_t ip6;
    }_Addr addr;
}

enum ___wasi_address_family_t { INET4 = 0, INET6 }alias __wasi_address_family_t = ___wasi_address_family_t;

struct __wasi_addr_info_t {
    __wasi_addr_t addr;
    __wasi_sock_type_t type;
}

struct __wasi_addr_info_hints_t {
   __wasi_sock_type_t type;
   __wasi_address_family_t family;
   // this is to workaround lack of optional parameters
   ubyte hints_enabled;
}

version (WASMTIME_SSP_WASI_API) {
enum string WASMTIME_SSP_SYSCALL_NAME(string name) = ` \
    asm("__wasi_" #name)`;
} else {
//#define WASMTIME_SSP_SYSCALL_NAME(name)
}

__wasi_errno_t wasmtime_ssp_args_get(
#if !HasVersion!"WASMTIME_SSP_STATIC_CURFDS"
    argv_environ_values* arg_environ; argv_environ_values** argv; argv_environ_values WASMTIME_SSP_SYSCALL_NAME(args_get);

__wasi_errno_t wasmtime_ssp_args_sizes_get(
#if !HasVersion!"WASMTIME_SSP_STATIC_CURFDS"
    argv_environ_values* arg_environ, argc; argv_environ_values WASMTIME_SSP_SYSCALL_NAME(args_sizes_get);

__wasi_errno_t wasmtime_ssp_clock_res_get(__wasi_clockid_t clock_id, __wasi_timestamp_t* resolution); ;

__wasi_errno_t wasmtime_ssp_clock_time_get(__wasi_clockid_t clock_id, __wasi_timestamp_t precision, __wasi_timestamp_t* time); ;

__wasi_errno_t wasmtime_ssp_environ_get(
#if !HasVersion!"WASMTIME_SSP_STATIC_CURFDS"
    argv_environ_values* arg_environ; argv_environ_values** environ; argv_environ_values WASMTIME_SSP_SYSCALL_NAME(environ_get);

__wasi_errno_t wasmtime_ssp_environ_sizes_get(
#if !HasVersion!"WASMTIME_SSP_STATIC_CURFDS"
    argv_environ_values* arg_environ, environ_count; argv_environ_values WASMTIME_SSP_SYSCALL_NAME(environ_sizes_get);

__wasi_errno_t wasmtime_ssp_fd_prestat_get(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_prestats; *prestats,
}
    __wasi_fd_t fd, __wasi_prestat_t; *buf
) WASMTIME_SSP_SYSCALL_NAME(fd_prestat_get) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_prestat_dir_name(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_prestats; *prestats,
}
    __wasi_fd_t fd; __wasi_fd_t* path; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_prestat_dir_name);

__wasi_errno_t wasmtime_ssp_fd_close(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; fd_prestats *prestats,
}
    __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_close);

__wasi_errno_t wasmtime_ssp_fd_datasync(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_datasync);

__wasi_errno_t wasmtime_ssp_fd_pread(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; __wasi_iovec_t* iovs; __wasi_iovec_t iovs_len, __wasi_filesize_t; offset,
    size_t *nread
) WASMTIME_SSP_SYSCALL_NAME(fd_pread) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_pwrite(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; __wasi_ciovec_t* iovs; __wasi_ciovec_t iovs_len, __wasi_filesize_t; offset,
    size_t *nwritten
) WASMTIME_SSP_SYSCALL_NAME(fd_pwrite) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_read(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; __wasi_iovec_t* iovs; __wasi_iovec_t size_t; iovs_len,
    size_t *nread
) WASMTIME_SSP_SYSCALL_NAME(fd_read) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_renumber(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; fd_prestats *prestats,
}
    __wasi_fd_t from; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_renumber);

__wasi_errno_t wasmtime_ssp_fd_seek(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_filedelta_t, __wasi_whence_t; whence,
    __wasi_filesize_t *newoffset
) WASMTIME_SSP_SYSCALL_NAME(fd_seek) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_tell(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_filesize_t; *newoffset
) WASMTIME_SSP_SYSCALL_NAME(fd_tell) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_fdstat_get(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_fdstat_t; *buf
) WASMTIME_SSP_SYSCALL_NAME(fd_fdstat_get) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_fdstat_set_flags(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_fdstat_set_flags);

__wasi_errno_t wasmtime_ssp_fd_fdstat_set_rights(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_rights_t; fs_rights_base,
    __wasi_rights_t fs_rights_inheriting
) WASMTIME_SSP_SYSCALL_NAME(fd_fdstat_set_rights) __attribute__((__warn_unused_result__));

__wasi_errno_t wasmtime_ssp_fd_sync(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_sync);

__wasi_errno_t wasmtime_ssp_fd_write(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; __wasi_ciovec_t* iovs; __wasi_ciovec_t size_t; iovs_len,
    size_t *nwritten
) WASMTIME_SSP_SYSCALL_NAME(fd_write) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_advise(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_filesize_t, __wasi_filesize_t; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_advise);

__wasi_errno_t wasmtime_ssp_fd_allocate(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_filesize_t; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_allocate);

__wasi_errno_t wasmtime_ssp_path_create_directory(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; char* path; char WASMTIME_SSP_SYSCALL_NAME(path_create_directory);

__wasi_errno_t wasmtime_ssp_path_link(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; fd_prestats *prestats,
}
    __wasi_fd_t old_fd, __wasi_lookupflags_t, const; char* old_path; char old_path_len = 0, __wasi_fd_t = 0, const = 0; char* new_path; char WASMTIME_SSP_SYSCALL_NAME(path_link);

__wasi_errno_t wasmtime_ssp_path_open(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t dirfd, __wasi_lookupflags_t, const; char* path; char path_len = 0, __wasi_oflags_t = 0, __wasi_rights_t = 0; fs_rights_base,
    __wasi_rights_t fs_rights_inheriting,
    __wasi_fdflags_t fs_flags,
    __wasi_fd_t *fd
) WASMTIME_SSP_SYSCALL_NAME(path_open) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_readdir(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd; __wasi_fd_t* buf; __wasi_fd_t buf_len, __wasi_dircookie_t; cookie,
    size_t *bufused
) WASMTIME_SSP_SYSCALL_NAME(fd_readdir) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_path_readlink(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; char* path; char size_t = 0; path_len,
    char_ *buf,
    size_t buf_len,
    size_t *bufused
) WASMTIME_SSP_SYSCALL_NAME(path_readlink) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_path_rename(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t old_fd, const; char* old_path; char old_path_len = 0, __wasi_fd_t = 0, const = 0; char* new_path; char WASMTIME_SSP_SYSCALL_NAME(path_rename);

__wasi_errno_t wasmtime_ssp_fd_filestat_get(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_filestat_t; *buf
) WASMTIME_SSP_SYSCALL_NAME(fd_filestat_get) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_fd_filestat_set_times(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_timestamp_t, __wasi_timestamp_t; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_filestat_set_times);

__wasi_errno_t wasmtime_ssp_fd_filestat_set_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(fd_filestat_set_size);

__wasi_errno_t wasmtime_ssp_path_filestat_get(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_lookupflags_t, const; char* path; char size_t = 0; path_len,
    __wasi_filestat_t *buf
) WASMTIME_SSP_SYSCALL_NAME(path_filestat_get) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_path_filestat_set_times(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_lookupflags_t, const; char* path; char path_len = 0, __wasi_timestamp_t = 0, __wasi_timestamp_t = 0; char WASMTIME_SSP_SYSCALL_NAME(path_filestat_set_times);

__wasi_errno_t wasmtime_ssp_path_symlink(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; fd_prestats *prestats,
}
    const(char)* old_path; const(char) old_path_len = 0, __wasi_fd_t = 0, const = 0; char* new_path; char WASMTIME_SSP_SYSCALL_NAME(path_symlink);

__wasi_errno_t wasmtime_ssp_path_unlink_file(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; char* path; char WASMTIME_SSP_SYSCALL_NAME(path_unlink_file);

__wasi_errno_t wasmtime_ssp_path_remove_directory(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, const; char* path; char WASMTIME_SSP_SYSCALL_NAME(path_remove_directory);

__wasi_errno_t wasmtime_ssp_poll_oneoff(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    const(__wasi_subscription_t)* in_; const(__wasi_subscription_t) __wasi_event_t; *out_,
    size_t nsubscriptions,
    size_t *nevents
) WASMTIME_SSP_SYSCALL_NAME(poll_oneoff) __attribute__((__warn_unused_result__)){}

version (none) {
/**
 * We throw exception in libc-wasi wrapper function wasi_proc_exit()
 * but not call this function.
 */
_Noreturn WASMTIME_SSP_SYSCALL_NAME(proc_exit);
}

__wasi_errno_t wasmtime_ssp_proc_raise(__wasi_signal_t sig); ;

__wasi_errno_t wasmtime_ssp_random_get(void* buf, size_t buf_len); ;

__wasi_errno_t
wasi_ssp_sock_accept(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_fdflags_t; flags, __wasi_fd_t *fd_new
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_addr_local(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_addr_t; *addr
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_addr_remote(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_addr_t; *addr
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_open(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t poolfd, __wasi_address_family_t, __wasi_sock_type_t; socktype,
    __wasi_fd_t *sockfd
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_bind(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; addr_pool *addr_pool,
}
    __wasi_fd_t fd, __wasi_addr_t; *addr
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_addr_resolve(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table** ns_lookup_list; fd_table* host; fd_table const; char* service; char __wasi_addr_info_hints_t = 0; *hints, __wasi_addr_info_t *addr_info,
    __wasi_size_t addr_info_size, __wasi_size_t *max_info_size
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_connect(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; addr_pool *addr_pool,
}
    __wasi_fd_t fd, __wasi_addr_t; *addr
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_get_recv_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_size_t; *size
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_get_reuse_addr(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __warn_unused_result__;

__wasi_errno_t
wasi_ssp_sock_get_reuse_port(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __warn_unused_result__;

__wasi_errno_t
wasi_ssp_sock_get_send_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_size_t; *size
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_set_recv_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_size_t size
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_set_reuse_addr(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, uint8_t reuse
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_set_reuse_port(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, uint8_t reuse
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_set_send_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_size_t size
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t
wasi_ssp_sock_listen(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t fd, __wasi_size_t backlog
) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_recv(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t* buf; __wasi_fd_t size_t; buf_len,
    size_t *recv_len
) WASMTIME_SSP_SYSCALL_NAME(sock_recv) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_recv_from(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t* buf; __wasi_fd_t buf_len, __wasi_riflags_t; ri_flags,
    __wasi_addr_t *src_addr,
    size_t *recv_len
) WASMTIME_SSP_SYSCALL_NAME(sock_recv_from) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_send(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, const; void* buf; void size_t; buf_len,
    size_t *sent_len
) WASMTIME_SSP_SYSCALL_NAME(sock_send) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_send_to(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    fd_table* curfds; fd_table struct; addr_pool *addr_pool,
}
    __wasi_fd_t sock, const; void* buf; void buf_len, __wasi_siflags_t, const; __wasi_addr_t *dest_addr,
    size_t *sent_len
) WASMTIME_SSP_SYSCALL_NAME(sock_send_to) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_shutdown(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_shutdown);

__wasi_errno_t wasmtime_ssp_sock_set_recv_timeout(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_recv_timeout);

__wasi_errno_t wasmtime_ssp_sock_get_recv_timeout(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_recv_timeout);

__wasi_errno_t wasmtime_ssp_sock_set_send_timeout(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_send_timeout);

__wasi_errno_t wasmtime_ssp_sock_get_send_timeout(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_send_timeout);

__wasi_errno_t wasmtime_ssp_sock_set_send_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_send_buf_size);

__wasi_errno_t wasmtime_ssp_sock_get_send_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_send_buf_size);

__wasi_errno_t wasmtime_ssp_sock_set_recv_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_recv_buf_size);

__wasi_errno_t wasmtime_ssp_sock_get_recv_buf_size(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_recv_buf_size);


__wasi_errno_t wasmtime_ssp_sock_set_keep_alive(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_keep_alive);

__wasi_errno_t wasmtime_ssp_sock_get_keep_alive(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_keep_alive);

__wasi_errno_t wasmtime_ssp_sock_set_reuse_addr(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_reuse_addr);

__wasi_errno_t wasmtime_ssp_sock_get_reuse_addr(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_reuse_addr);

__wasi_errno_t wasmtime_ssp_sock_set_reuse_port(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_reuse_port);

__wasi_errno_t wasmtime_ssp_sock_get_reuse_port(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_reuse_port);

__wasi_errno_t wasmtime_ssp_sock_set_linger(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, is_enabled; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_linger);

__wasi_errno_t wasmtime_ssp_sock_get_linger(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, bool_; *is_enabled, int *linger_s
) WASMTIME_SSP_SYSCALL_NAME(sock_get_linger) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_set_broadcast(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_broadcast);

__wasi_errno_t wasmtime_ssp_sock_get_broadcast(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_broadcast);

__wasi_errno_t wasmtime_ssp_sock_set_tcp_no_delay(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_no_delay);

__wasi_errno_t wasmtime_ssp_sock_get_tcp_no_delay(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_no_delay);

__wasi_errno_t wasmtime_ssp_sock_set_tcp_quick_ack(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_quick_ack);

__wasi_errno_t wasmtime_ssp_sock_get_tcp_quick_ack(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_quick_ack);

__wasi_errno_t wasmtime_ssp_sock_set_tcp_keep_idle(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_keep_idle);

__wasi_errno_t wasmtime_ssp_sock_get_tcp_keep_idle(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_keep_idle);

__wasi_errno_t wasmtime_ssp_sock_set_tcp_keep_intvl(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_keep_intvl);

__wasi_errno_t wasmtime_ssp_sock_get_tcp_keep_intvl(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_keep_intvl);

__wasi_errno_t wasmtime_ssp_sock_set_tcp_fastopen_connect(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_tcp_fastopen_connect);

__wasi_errno_t wasmtime_ssp_sock_get_tcp_fastopen_connect(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_tcp_fastopen_connect);

__wasi_errno_t wasmtime_ssp_sock_set_ip_multicast_loop(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, bool_; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_multicast_loop);

__wasi_errno_t wasmtime_ssp_sock_get_ip_multicast_loop(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, bool_; ipv6,
    bool_ *is_enabled
) WASMTIME_SSP_SYSCALL_NAME(sock_get_ip_multicast_loop) __attribute__((__warn_unused_result__)){}

__wasi_errno_t wasmtime_ssp_sock_set_ip_add_membership(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, __wasi_addr_ip_t; *imr_multiaddr,
    uint32_t imr_interface
) WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_add_membership) __attribute__((__warn_unused_result__));

__wasi_errno_t wasmtime_ssp_sock_set_ip_drop_membership(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock, __wasi_addr_ip_t; *imr_multiaddr,
    uint32_t imr_interface
) WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_drop_membership) __attribute__((__warn_unused_result__));

__wasi_errno_t wasmtime_ssp_sock_set_ip_ttl(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_ttl);

__wasi_errno_t wasmtime_ssp_sock_get_ip_ttl(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_ip_ttl);

__wasi_errno_t wasmtime_ssp_sock_set_ip_multicast_ttl(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_ip_multicast_ttl);

__wasi_errno_t wasmtime_ssp_sock_get_ip_multicast_ttl(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_ip_multicast_ttl);

__wasi_errno_t wasmtime_ssp_sock_set_ipv6_only(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_set_ipv6_only);

__wasi_errno_t wasmtime_ssp_sock_get_ipv6_only(
static if (!HasVersion!"WASMTIME_SSP_STATIC_CURFDS") {
    struct fd_table; *curfds,
}
    __wasi_fd_t sock; __wasi_fd_t WASMTIME_SSP_SYSCALL_NAME(sock_get_ipv6_only);

__wasi_errno_t WASMTIME_SSP_SYSCALL_NAME(sched_yield);

version (none) {
}
}

/* clang-format on */

} /* end of WASMTIME_SSP_H */
