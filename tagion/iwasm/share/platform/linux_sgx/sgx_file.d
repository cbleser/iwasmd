module sgx_file;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _SGX_FILE_H
version = _SGX_FILE_H;

public import sgx_time;

#ifdef __cplusplus
extern "C" {
//! #endif

enum F_DUPFD = 0;
enum F_GETFD = 1;
enum F_SETFD = 2;
enum F_GETFL = 3;
enum F_SETFL = 4;

enum FD_CLOEXEC = 1;

enum O_PATH = 010000000;
enum O_SEARCH = O_PATH;
enum O_EXEC = O_PATH;

enum O_ACCMODE = (03 | O_SEARCH);
enum O_RDONLY = 00;
enum O_WRONLY = 01;
enum O_RDWR = 02;

enum O_CREAT = 0100;
enum O_EXCL = 0200;
enum O_NOCTTY = 0400;
enum O_TRUNC = 01000;
enum O_APPEND = 02000;
enum O_NONBLOCK = 04000;
enum O_DSYNC = 010000;
enum O_SYNC = 04010000;
enum O_RSYNC = 04010000;
enum O_DIRECTORY = 0200000;
enum O_NOFOLLOW = 0400000;
enum O_CLOEXEC = 02000000;

enum O_ASYNC = 020000;
enum O_DIRECT = 040000;
enum O_LARGEFILE = 0;
enum O_NOATIME = 01000000;
enum O_PATH = 010000000;
enum O_TMPFILE = 020200000;
enum O_NDELAY = O_NONBLOCK;

enum S_IFMT = 0170000;
enum S_IFDIR = 0040000;
enum S_IFCHR = 0020000;
enum S_IFBLK = 0060000;
enum S_IFREG = 0100000;
enum S_IFIFO = 0010000;
enum S_IFLNK = 0120000;
enum S_IFSOCK = 0140000;

enum SEEK_SET = 0;
enum SEEK_CUR = 1;
enum SEEK_END = 2;

enum string S_ISDIR(string mode) = ` (((mode)&S_IFMT) == S_IFDIR)`;
enum string S_ISCHR(string mode) = ` (((mode)&S_IFMT) == S_IFCHR)`;
enum string S_ISBLK(string mode) = ` (((mode)&S_IFMT) == S_IFBLK)`;
enum string S_ISREG(string mode) = ` (((mode)&S_IFMT) == S_IFREG)`;
enum string S_ISFIFO(string mode) = ` (((mode)&S_IFMT) == S_IFIFO)`;
enum string S_ISLNK(string mode) = ` (((mode)&S_IFMT) == S_IFLNK)`;
enum string S_ISSOCK(string mode) = ` (((mode)&S_IFMT) == S_IFSOCK)`;

enum DT_UNKNOWN = 0;
enum DT_FIFO = 1;
enum DT_CHR = 2;
enum DT_DIR = 4;
enum DT_BLK = 6;
enum DT_REG = 8;
enum DT_LNK = 10;
enum DT_SOCK = 12;
enum DT_WHT = 14;

enum AT_SYMLINK_NOFOLLOW = 0x100;
enum AT_REMOVEDIR = 0x200;
enum AT_SYMLINK_FOLLOW = 0x400;

enum POLLIN = 0x001;
enum POLLPRI = 0x002;
enum POLLOUT = 0x004;
enum POLLERR = 0x008;
enum POLLHUP = 0x010;
enum POLLNVAL = 0x020;
enum POLLRDNORM = 0x040;
enum POLLRDBAND = 0x080;
enum POLLWRNORM = 0x100;
enum POLLWRBAND = 0x200;

enum FIONREAD = 0x541B;

enum PATH_MAX = 4096;

/* Special value used to indicate openat should use the current
   working directory. */
enum AT_FDCWD = -100;

alias __syscall_slong_t = c_long;

alias dev_t = c_ulong;
alias ino_t = c_ulong;
alias mode_t = uint;
alias nlink_t = c_ulong;
alias socklen_t = uint;
alias blksize_t = c_long;
alias blkcnt_t = c_long;

alias pid_t = int;
alias gid_t = uint;
alias uid_t = uint;

alias nfds_t = c_ulong;

alias DIR = uintptr_t;

struct dirent {
    ino_t d_ino;
    off_t d_off;
    ushort d_reclen;
    ubyte d_type;
    char[256] d_name = 0;
};

struct stat {
    dev_t st_dev;
    ino_t st_ino;
    nlink_t st_nlink;

    mode_t st_mode;
    uid_t st_uid;
    gid_t st_gid;
    uint __pad0;
    dev_t st_rdev;
    off_t st_size;
    blksize_t st_blksize;
    blkcnt_t st_blocks;

    timespec st_atim;
    timespec st_mtim;
    timespec st_ctim;
    c_long[3] __unused;
};

struct iovec {
    void* iov_base;
    size_t iov_len;
};

struct pollfd {
    int fd;
    short events;
    short revents;
};

int open(const(char)* pathname, int flags, ...);
int openat(int dirfd, const(char)* pathname, int flags, ...);
int close(int fd);

DIR* fdopendir(int fd);
int closedir(DIR* dirp);
void rewinddir(DIR* dirp);
void seekdir(DIR* dirp, c_long loc);
dirent* readdir(DIR* dirp);
c_long telldir(DIR* dirp);

ssize_t read(int fd, void* buf, size_t count);
ssize_t readv(int fd, const(iovec)* iov, int iovcnt);
ssize_t writev(int fd, const(iovec)* iov, int iovcnt);
ssize_t preadv(int fd, const(iovec)* iov, int iovcnt, off_t offset);
ssize_t pwritev(int fd, const(iovec)* iov, int iovcnt, off_t offset);

off_t lseek(int fd, off_t offset, int whence);
int ftruncate(int fd, off_t length);

int stat(const(char)* pathname, stat* statbuf);
int fstat(int fd, stat* statbuf);
int fstatat(int dirfd, const(char)* pathname, stat* statbuf, int flags);

int fsync(int fd);
int fdatasync(int fd);

int mkdirat(int dirfd, const(char)* pathname, mode_t mode);
int link(const(char)* oldpath, const(char)* newpath);
int linkat(int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath, int flags);
int unlinkat(int dirfd, const(char)* pathname, int flags);
ssize_t readlink(const(char)* pathname, char* buf, size_t bufsiz);
ssize_t readlinkat(int dirfd, const(char)* pathname, char* buf, size_t bufsiz);
int symlinkat(const(char)* target, int newdirfd, const(char)* linkpath);
int renameat(int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath);

int ioctl(int fd, c_ulong request, ...);
int fcntl(int fd, int cmd, ...);

int isatty(int fd);

char* realpath(const(char)* path, char* resolved_path);

int posix_fallocate(int fd, off_t offset, off_t len);

int poll(pollfd* fds, nfds_t nfds, int timeout);

int getopt(int argc, char** argv, const(char)* optstring);

int sched_yield();

ssize_t getrandom(void* buf, size_t buflen, uint flags);

int getentropy(void* buffer, size_t length);

int get_errno();

version (none) {
}
}

//! #endif /* end of _SGX_FILE_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import sgx_error;
public import sgx_file;

static if (WASM_ENABLE_SGX_IPFS != 0) {
public import sgx_ipfs;
}

version (SGX_DISABLE_WASI) {} else {

enum string TRACE_FUNC() = ` os_printf("undefined %s\n", __FUNCTION__)`;
enum string TRACE_OCALL_FAIL() = ` os_printf("ocall %s failed!\n", __FUNCTION__)`;

/** fd **/
int ocall_open(int* p_fd, const(char)* pathname, int flags, bool has_mode, uint mode);

int ocall_openat(int* p_fd, int dirfd, const(char)* pathname, int flags, bool has_mode, uint mode);

int ocall_read(ssize_t* p_ret, int fd, void* buf, size_t read_size);

int ocall_close(int* p_ret, int fd);

int ocall_lseek(off_t* p_ret, int fd, off_t offset, int whence);

int ocall_ftruncate(int* p_ret, int fd, off_t length);

int ocall_fsync(int* p_ret, int fd);

int ocall_fdatasync(int* p_ret, int fd);

int ocall_isatty(int* p_ret, int fd);
/** fd end  **/

/** DIR **/
int ocall_fdopendir(int fd, void** p_dirp);

int ocall_readdir(void** p_dirent, void* dirp);

int ocall_rewinddir(void* dirp);

int ocall_seekdir(void* dirp, c_long loc);

int ocall_telldir(c_long* p_dir, void* dirp);

int ocall_closedir(int* p_ret, void* dirp);
/** DIR end **/

/** stat **/
int ocall_stat(int* p_ret, const(char)* pathname, void* buf, uint buf_len);
int ocall_fstat(int* p_ret, int fd, void* buf, uint buf_len);
int ocall_fstatat(int* p_ret, int dirfd, const(char)* pathname, void* buf, uint buf_len, int flags);
/** stat end **/

/** link **/
int ocall_mkdirat(int* p_ret, int dirfd, const(char)* pathname, uint mode);
int ocall_link(int* p_ret, const(char)* oldpath, const(char)* newpath);
int ocall_linkat(int* p_ret, int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath, int flags);
int ocall_unlinkat(int* p_ret, int dirfd, const(char)* pathname, int flags);
int ocall_readlink(ssize_t* p_ret, const(char)* pathname, char* buf, size_t bufsiz);
int ocall_readlinkat(ssize_t* p_ret, int dirfd, const(char)* pathname, char* buf, size_t bufsiz);
int ocall_renameat(int* p_ret, int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath);
int ocall_symlinkat(int* p_ret, const(char)* target, int newdirfd, const(char)* linkpath);
/** link end **/

/** control **/
int ocall_ioctl(int* p_ret, int fd, c_ulong request, void* arg, uint arg_len);
int ocall_fcntl(int* p_ret, int fd, int cmd);
int ocall_fcntl_long(int* p_ret, int fd, int cmd, c_long arg);
/** control end **/

/** **/
int ocall_realpath(int* p_ret, const(char)* path, char* buf, uint buf_len);
int ocall_posix_fallocate(int* p_ret, int fd, off_t offset, off_t len);
int ocall_poll(int* p_ret, void* fds, uint nfds, int timeout, uint fds_len);
int ocall_getopt(int* p_ret, int argc, char* argv_buf, uint argv_buf_len, const(char)* optstring);
int ocall_sched_yield(int* p_ret);

/** struct iovec **/
ssize_t ocall_readv(ssize_t* p_ret, int fd, char* iov_buf, uint buf_size, int iovcnt, bool has_offset, off_t offset);
ssize_t ocall_writev(ssize_t* p_ret, int fd, char* iov_buf, uint buf_size, int iovcnt, bool has_offset, off_t offset);
/** iovec end **/

int ocall_get_errno(int* p_ret);

int open(const(char)* pathname, int flags, ...) {
    int fd = void;
    bool has_mode = false;
    mode_t mode = 0;

    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        va_list ap = void;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
        has_mode = true;
    }

    if (SGX_SUCCESS != ocall_open(&fd, pathname, flags, has_mode, mode)) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (fd >= 0 && (flags & O_CLOEXEC))
        fcntl(fd, F_SETFD, FD_CLOEXEC);

    if (fd == -1)
        errno = get_errno();
    return fd;
}

int openat(int dirfd, const(char)* pathname, int flags, ...) {
    int fd = void;
    bool has_mode = false;
    mode_t mode = 0;

    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        va_list ap = void;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
        has_mode = true;
    }

    if (SGX_SUCCESS
        != ocall_openat(&fd, dirfd, pathname, flags, has_mode, mode)) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (fd >= 0 && (flags & O_CLOEXEC))
        fcntl(fd, F_SETFD, FD_CLOEXEC);

    if (fd == -1)
        errno = get_errno();

static if (WASM_ENABLE_SGX_IPFS != 0) {
    stat sb = void;
    int ret = fstatat(dirfd, pathname, &sb, 0);
    if (ret < 0) {
        if (ocall_close(&ret, fd) != SGX_SUCCESS) {
            TRACE_OCALL_FAIL();
        }
        return -1;
    }

    // Ony files are managed by SGX IPFS
    if (S_ISREG(sb.st_mode)) {
        // When WAMR uses Intel SGX IPFS to enabled, it opens a second
        // file descriptor to interact with the secure file.
        // The first file descriptor opened earlier is used to interact
        // with the metadata of the file (e.g., time, flags, etc.).
        void* file_ptr = ipfs_fopen(fd, flags);
        if (file_ptr == null) {
            if (ocall_close(&ret, fd) != SGX_SUCCESS) {
                TRACE_OCALL_FAIL();
            }
            return -1;
        }
    }
}

    return fd;
}

int close(int fd) {
    int ret = void;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    // Close the IPFS file pointer in addition of the file descriptor
    ret = ipfs_close(fd);
    if (ret == -1)
        errno = get_errno();
}

    if (ocall_close(&ret, fd) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
    return ret;
}

ssize_t read(int fd, void* buf, size_t size) {
    ssize_t ret = void;
    int size_read_max = 2048, size_read = void, total_size_read = 0, count = void, i = void;
    char* p = buf;

    if (buf == null) {
        TRACE_FUNC();
        return -1;
    }

    count = (size + size_read_max - 1) / size_read_max;
    for (i = 0; i < count; i++) {
        size_read = (i < count - 1) ? size_read_max : size - size_read_max * i;

        if (ocall_read(&ret, fd, p, size_read) != SGX_SUCCESS) {
            TRACE_OCALL_FAIL();
            return -1;
        }
        if (ret == -1) {
            /* read failed */
            errno = get_errno();
            return -1;
        }

        p += ret;
        total_size_read += ret;

        if (ret < size_read)
            /* end of file */
            break;
    }
    return total_size_read;
}

DIR* fdopendir(int fd) {
    DIR* result = null;

    result = cast(DIR*)BH_MALLOC(DIR.sizeof);
    if (!result)
        return null;

    if (ocall_fdopendir(fd, cast(void**)result) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        BH_FREE(result);
        return null;
    }

    if (cast(void*)*result == null) { /* opendir failed */
        TRACE_FUNC();
        BH_FREE(result);
        errno = get_errno();
        return null;
    }

    return result;
}

dirent* readdir(DIR* dirp) {
    dirent* result = void;

    if (dirp == null)
        return null;

    if (ocall_readdir(cast(void**)&result, cast(void*)*dirp) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return null;
    }

    if (!result)
        errno = get_errno();
    return result;
}

void rewinddir(DIR* dirp) {
    if (ocall_rewinddir(cast(void*)*dirp) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
    }
}

void seekdir(DIR* dirp, c_long loc) {
    if (ocall_seekdir(cast(void*)*dirp, loc) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
    }
}

c_long telldir(DIR* dirp) {
    c_long ret = void;

    if (ocall_telldir(&ret, cast(void*)*dirp) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
    return ret;
}

int closedir(DIR* dirp) {
    int ret = void;

    if (ocall_closedir(&ret, cast(void*)*dirp) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    BH_FREE(dirp);
    if (ret == -1)
        errno = get_errno();
    return ret;
}

private ssize_t readv_internal(int fd, const(iovec)* iov, int iovcnt, bool has_offset, off_t offset) {
    ssize_t ret = void, size_left = void;
    iovec* iov1 = void;
    int i = void;
    char* p = void;
    ulong total_size = iovec.sizeof * cast(ulong)iovcnt;

    if (iov == null || iovcnt < 1)
        return -1;

    for (i = 0; i < iovcnt; i++) {
        total_size += iov[i].iov_len;
    }

    if (total_size >= UINT32_MAX)
        return -1;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    if (fd > 2) {
        return ipfs_read(fd, iov, iovcnt, has_offset, offset);
    }
}

    iov1 = BH_MALLOC(cast(uint)total_size);

    if (iov1 == null)
        return -1;

    memset(iov1, 0, cast(uint)total_size);

    p = cast(char*)cast(uintptr_t)(iovec.sizeof * iovcnt);

    for (i = 0; i < iovcnt; i++) {
        iov1[i].iov_len = iov[i].iov_len;
        iov1[i].iov_base = p;
        p += iov[i].iov_len;
    }

    if (ocall_readv(&ret, fd, cast(char*)iov1, cast(uint)total_size, iovcnt,
                    has_offset, offset)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        BH_FREE(iov1);
        return -1;
    }

    p = cast(char*)cast(uintptr_t)(iovec.sizeof * iovcnt);

    size_left = ret;
    for (i = 0; i < iovcnt; i++) {
        if (size_left > iov[i].iov_len) {
            memcpy(iov[i].iov_base, cast(uintptr_t)p + cast(char*)iov1,
                   iov[i].iov_len);
            p += iov[i].iov_len;
            size_left -= iov[i].iov_len;
        }
        else {
            memcpy(iov[i].iov_base, cast(uintptr_t)p + cast(char*)iov1, size_left);
            break;
        }
    }

    BH_FREE(iov1);
    if (ret == -1)
        errno = get_errno();
    return ret;
}

private ssize_t writev_internal(int fd, const(iovec)* iov, int iovcnt, bool has_offset, off_t offset) {
    ssize_t ret = void;
    iovec* iov1 = void;
    int i = void;
    char* p = void;
    ulong total_size = iovec.sizeof * cast(ulong)iovcnt;

    if (iov == null || iovcnt < 1)
        return -1;

    for (i = 0; i < iovcnt; i++) {
        total_size += iov[i].iov_len;
    }

    if (total_size >= UINT32_MAX)
        return -1;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    if (fd > 2) {
        return ipfs_write(fd, iov, iovcnt, has_offset, offset);
    }
}

    iov1 = BH_MALLOC(cast(uint)total_size);

    if (iov1 == null)
        return -1;

    memset(iov1, 0, cast(uint)total_size);

    p = cast(char*)cast(uintptr_t)(iovec.sizeof * iovcnt);

    for (i = 0; i < iovcnt; i++) {
        iov1[i].iov_len = iov[i].iov_len;
        iov1[i].iov_base = p;
        memcpy(cast(uintptr_t)p + cast(char*)iov1, iov[i].iov_base, iov[i].iov_len);
        p += iov[i].iov_len;
    }

    if (ocall_writev(&ret, fd, cast(char*)iov1, cast(uint)total_size, iovcnt,
                     has_offset, offset)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        BH_FREE(iov1);
        return -1;
    }

    BH_FREE(iov1);
    if (ret == -1)
        errno = get_errno();
    return ret;
}

ssize_t readv(int fd, const(iovec)* iov, int iovcnt) {
    return readv_internal(fd, iov, iovcnt, false, 0);
}

ssize_t writev(int fd, const(iovec)* iov, int iovcnt) {
    return writev_internal(fd, iov, iovcnt, false, 0);
}

ssize_t preadv(int fd, const(iovec)* iov, int iovcnt, off_t offset) {
    return readv_internal(fd, iov, iovcnt, true, offset);
}

ssize_t pwritev(int fd, const(iovec)* iov, int iovcnt, off_t offset) {
    return writev_internal(fd, iov, iovcnt, true, offset);
}

off_t lseek(int fd, off_t offset, int whence) {
    off_t ret = void;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    ret = ipfs_lseek(fd, offset, whence);
} else {
    if (ocall_lseek(&ret, fd, cast(c_long)offset, whence) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
}

    return ret;
}

int ftruncate(int fd, off_t length) {
    int ret = void;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    ret = ipfs_ftruncate(fd, length);
} else {
    if (ocall_ftruncate(&ret, fd, length) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
}

    return ret;
}

int stat(const(char)* pathname, stat* statbuf) {
    int ret = void;

    if (statbuf == null)
        return -1;

    if (ocall_stat(&ret, pathname, cast(void*)statbuf, stat.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int fstat(int fd, stat* statbuf) {
    int ret = void;

    if (statbuf == null)
        return -1;

    if (ocall_fstat(&ret, fd, cast(void*)statbuf, stat.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int fstatat(int dirfd, const(char)* pathname, stat* statbuf, int flags) {
    int ret = void;

    if (statbuf == null)
        return -1;

    if (ocall_fstatat(&ret, dirfd, pathname, cast(void*)statbuf,
                      stat.sizeof, flags)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int fsync(int fd) {
    int ret = void;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    ret = ipfs_fflush(fd);
} else {
    if (ocall_fsync(&ret, fd) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
}

    return ret;
}

int fdatasync(int fd) {
    int ret = void;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    ret = ipfs_fflush(fd);
} else {
    if (ocall_fdatasync(&ret, fd) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
}

    return ret;
}

int mkdirat(int dirfd, const(char)* pathname, mode_t mode) {
    int ret = void;

    if (ocall_mkdirat(&ret, dirfd, pathname, mode) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int link(const(char)* oldpath, const(char)* newpath) {
    int ret = void;

    if (ocall_link(&ret, oldpath, newpath) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int linkat(int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath, int flags) {
    int ret = void;

    if (ocall_linkat(&ret, olddirfd, oldpath, newdirfd, newpath, flags)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int unlinkat(int dirfd, const(char)* pathname, int flags) {
    int ret = void;

    if (ocall_unlinkat(&ret, dirfd, pathname, flags) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

ssize_t readlink(const(char)* pathname, char* buf, size_t bufsiz) {
    ssize_t ret = void;

    if (buf == null)
        return -1;

    if (ocall_readlink(&ret, pathname, buf, bufsiz) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

ssize_t readlinkat(int dirfd, const(char)* pathname, char* buf, size_t bufsiz) {
    ssize_t ret = void;

    if (buf == null)
        return -1;

    if (ocall_readlinkat(&ret, dirfd, pathname, buf, bufsiz) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int symlinkat(const(char)* target, int newdirfd, const(char)* linkpath) {
    int ret = void;

    if (ocall_symlinkat(&ret, target, newdirfd, linkpath) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int renameat(int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath) {
    int ret = void;

    if (ocall_renameat(&ret, olddirfd, oldpath, newdirfd, newpath)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int ioctl(int fd, c_ulong request, ...) {
    int ret = void;
    va_list args = void;

    switch (request) {
        case FIONREAD:
            va_start(args, request);
            int* arg = cast(int*)va_arg(args, int *);
            if (ocall_ioctl(&ret, fd, request, arg, typeof(*arg).sizeof)
                != SGX_SUCCESS) {
                TRACE_OCALL_FAIL();
                va_end(args);
                return -1;
            }
            va_end(args);
            break;

        default:
            os_printf("ioctl failed: unknown request", request);
            return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int fcntl(int fd, int cmd, ...) {
    int ret = void;
    va_list args = void;

    switch (cmd) {
        case F_GETFD:
        case F_GETFL:
            if (ocall_fcntl(&ret, fd, cmd) != SGX_SUCCESS) {
                TRACE_OCALL_FAIL();
                return -1;
            }
            break;

        case F_DUPFD:
        case F_SETFD:
        case F_SETFL:
            va_start(args, cmd);
            c_long arg_1 = cast(c_long)va_arg(args, long);
            if (ocall_fcntl_long(&ret, fd, cmd, arg_1) != SGX_SUCCESS) {
                TRACE_OCALL_FAIL();
                va_end(args);
                return -1;
            }
            va_end(args);
            break;

        default:
            os_printf("fcntl failed: unknown cmd %d.\n", cmd);
            return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int isatty(int fd) {
    int ret = void;

    if (ocall_isatty(&ret, fd) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == 0)
        errno = get_errno();
    return ret;
}

char* realpath(const(char)* path, char* resolved_path) {
    int ret = void;
    char[PATH_MAX] buf = 0;

    if (ocall_realpath(&ret, path, buf.ptr, PATH_MAX) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return cast(char*)null;
    }

    if (ret != 0)
        return cast(char*)null;

    if (resolved_path) {
        strcpy(resolved_path, buf.ptr);
    }
    else {
        resolved_path = BH_MALLOC(strlen(buf.ptr) + 1);
        if (resolved_path == null)
            return null;
        strcpy(resolved_path, buf.ptr);
    }

    return resolved_path;
}

int posix_fallocate(int fd, off_t offset, off_t len) {
    int ret = void;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    ret = ipfs_posix_fallocate(fd, offset, len);
} else {
    if (ocall_posix_fallocate(&ret, fd, offset, len) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
}

    return ret;
}

int poll(pollfd* fds, nfds_t nfds, int timeout) {
    int ret = void;

    if (fds == null)
        return -1;

    if (ocall_poll(&ret, fds, nfds, timeout, sizeof(*fds) * nfds)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();
    return ret;
}

int getopt(int argc, char** argv, const(char)* optstring) {
    int ret = void;
    char** argv1 = void;
    char* p = void;
    int i = void;
    ulong total_size = (char*).sizeof * cast(ulong)argc;

    for (i = 0; i < argc; i++) {
        total_size += strlen(argv[i]) + 1;
    }

    if (total_size >= UINT32_MAX)
        return -1;

    argv1 = BH_MALLOC(cast(uint)total_size);

    if (argv1 == null)
        return -1;

    p = cast(char*)cast(uintptr_t)((char*).sizeof * argc);

    for (i = 0; i < argc; i++) {
        argv1[i] = p;
        strcpy(cast(char*)argv1 + cast(uintptr_t)p, argv[i]);
        p += (cast(uintptr_t)strlen(argv[i]) + 1);
    }

    if (ocall_getopt(&ret, argc, cast(char*)argv1, total_size, optstring)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        BH_FREE(argv1);
        return -1;
    }

    BH_FREE(argv1);
    if (ret == -1)
        errno = get_errno();
    return ret;
}

int sched_yield() {
    int ret = void;

    if (ocall_sched_yield(&ret) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    if (ret == -1)
        errno = get_errno();
    return ret;
}

ssize_t getrandom(void* buf, size_t buflen, uint flags) {
    sgx_status_t ret = void;

    if (!buf || buflen > INT32_MAX || flags != 0) {
        errno = EINVAL;
        return -1;
    }

    ret = sgx_read_rand(buf, buflen);
    if (ret != SGX_SUCCESS) {
        errno = EFAULT;
        return -1;
    }

    return cast(ssize_t)buflen;
}

enum RDRAND_RETRIES = 3;

private int rdrand64_step(ulong* seed) {
    ubyte ok = void;
    __asm__ volatile("rdseed %0; setc %1" : "=r"(*seed), "=qm"(ok));
    return cast(int)ok;
}

private int rdrand64_retry(ulong* rand, uint retries) {
    uint count = 0;

    while (count++ <= retries) {
        if (rdrand64_step(rand)) {
            return -1;
        }
    }
    return 0;
}

private uint rdrand_get_bytes(ubyte* dest, uint n) {
    ubyte* head_start = dest, tail_start = null;
    ulong* block_start = void;
    uint count = void, ltail = void, lhead = void, lblock = void;
    ulong i = void, temp_rand = void;

    /* Get the address of the first 64-bit aligned block in the
       destination buffer. */
    if ((cast(uintptr_t)head_start & cast(uintptr_t)7) == 0) {
        /* already 8-byte aligned */
        block_start = cast(ulong*)head_start;
        lhead = 0;
        lblock = n & ~7;
    }
    else {
        /* next 8-byte aligned */
        block_start = cast(ulong*)((cast(uintptr_t)head_start + 7) & ~cast(uintptr_t)7);
        lhead = (uint32)(cast(uintptr_t)block_start - cast(uintptr_t)head_start);
        lblock = (n - lhead) & ~7;
    }

    /* Compute the number of 64-bit blocks and the remaining number
       of bytes (the tail) */
    ltail = n - lblock - lhead;
    if (ltail > 0) {
        tail_start = cast(ubyte*)block_start + lblock;
    }

    /* Populate the starting, mis-aligned section (the head) */
    if (lhead > 0) {
        if (!rdrand64_retry(&temp_rand, RDRAND_RETRIES)) {
            return 0;
        }
        memcpy(head_start, &temp_rand, lhead);
    }

    /* Populate the central, aligned blocks */
    count = lblock / 8;
    for (i = 0; i < count; i++, block_start++) {
        if (!rdrand64_retry(block_start, RDRAND_RETRIES)) {
            return i * 8 + lhead;
        }
    }

    /* Populate the tail */
    if (ltail > 0) {
        if (!rdrand64_retry(&temp_rand, RDRAND_RETRIES)) {
            return count * 8 + lhead;
        }

        memcpy(tail_start, &temp_rand, ltail);
    }

    return n;
}

int getentropy(void* buffer, size_t length) {
    uint size = void;

    if (!buffer || length > INT32_MAX) {
        errno = EINVAL;
        return -1;
    }

    if (length == 0) {
        return 0;
    }

    size = rdrand_get_bytes(buffer, cast(uint)length);
    if (size != length) {
        errno = EFAULT;
        return -1;
    }

    return 0;
}

int get_errno() {
    int ret = void;

    if (ocall_get_errno(&ret) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    return ret;
}

}
