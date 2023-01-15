module file;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import stdbool;
public import core.stdc.stdint;
public import core.stdc.stdio;
public import core.stdc.stdlib;
public import core.sys.posix.sys.types;
public import core.sys.posix.sys.stat;
public import core.sys.posix.sys.ioctl;
public import core.sys.posix.sys.uio;
public import core.sys.posix.fcntl;
public import core.sys.posix.unistd;
public import core.sys.posix.dirent;
public import core.sys.posix.sched;
public import core.sys.posix.poll;
public import core.stdc.errno;

int ocall_open(const(char)* pathname, int flags, bool has_mode, uint mode) {
    if (has_mode) {
        return open(pathname, flags, cast(mode_t)mode);
    }
    else {
        return open(pathname, flags);
    }
}

int ocall_openat(int dirfd, const(char)* pathname, int flags, bool has_mode, uint mode) {
    if (has_mode) {
        return openat(dirfd, pathname, flags, cast(mode_t)mode);
    }
    else {
        return openat(dirfd, pathname, flags);
    }
}

int ocall_close(int fd) {
    return close(fd);
}

ssize_t ocall_read(int fd, void* buf, size_t read_size) {
    if (buf != null) {
        return read(fd, buf, read_size);
    }
    else {
        return -1;
    }
}

off_t ocall_lseek(int fd, off_t offset, int whence) {
    return lseek(fd, offset, whence);
}

int ocall_ftruncate(int fd, off_t length) {
    return ftruncate(fd, length);
}

int ocall_fsync(int fd) {
    return fsync(fd);
}

int ocall_fdatasync(int fd) {
    return fdatasync(fd);
}

int ocall_isatty(int fd) {
    return isatty(fd);
}

void ocall_fdopendir(int fd, void** dirp) {
    if (dirp) {
        *cast(DIR**)dirp = fdopendir(fd);
    }
}

void* ocall_readdir(void* dirp) {
    DIR* p_dirp = cast(DIR*)dirp;
    return readdir(p_dirp);
}

void ocall_rewinddir(void* dirp) {
    DIR* p_dirp = cast(DIR*)dirp;
    if (p_dirp) {
        rewinddir(p_dirp);
    }
}

void ocall_seekdir(void* dirp, c_long loc) {
    DIR* p_dirp = cast(DIR*)dirp;

    if (p_dirp) {
        seekdir(p_dirp, loc);
    }
}

c_long ocall_telldir(void* dirp) {
    DIR* p_dirp = cast(DIR*)dirp;
    if (p_dirp) {
        return telldir(p_dirp);
    }
    return -1;
}

int ocall_closedir(void* dirp) {
    DIR* p_dirp = cast(DIR*)dirp;
    if (p_dirp) {
        return closedir(p_dirp);
    }
    return -1;
}

int ocall_stat(const(char)* pathname, void* buf, uint buf_len) {
    return stat(pathname, cast(stat*)buf);
}

int ocall_fstat(int fd, void* buf, uint buf_len) {
    return fstat(fd, cast(stat*)buf);
}

int ocall_fstatat(int dirfd, const(char)* pathname, void* buf, uint buf_len, int flags) {
    return fstatat(dirfd, pathname, cast(stat*)buf, flags);
}

int ocall_mkdirat(int dirfd, const(char)* pathname, uint mode) {
    return mkdirat(dirfd, pathname, cast(mode_t)mode);
}

int ocall_link(const(char)* oldpath, const(char)* newpath) {
    return link(oldpath, newpath);
}

int ocall_linkat(int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath, int flags) {
    return linkat(olddirfd, oldpath, newdirfd, newpath, flags);
}

int ocall_unlinkat(int dirfd, const(char)* pathname, int flags) {
    return unlinkat(dirfd, pathname, flags);
}

ssize_t ocall_readlink(const(char)* pathname, char* buf, size_t bufsiz) {
    return readlink(pathname, buf, bufsiz);
}

ssize_t ocall_readlinkat(int dirfd, const(char)* pathname, char* buf, size_t bufsiz) {
    return readlinkat(dirfd, pathname, buf, bufsiz);
}

int ocall_renameat(int olddirfd, const(char)* oldpath, int newdirfd, const(char)* newpath) {
    return renameat(olddirfd, oldpath, newdirfd, newpath);
}

int ocall_symlinkat(const(char)* target, int newdirfd, const(char)* linkpath) {
    return symlinkat(target, newdirfd, linkpath);
}

int ocall_ioctl(int fd, c_ulong request, void* arg, uint arg_len) {
    /* support just int *arg temporally */
    return ioctl(fd, request, cast(int*)arg);
}

int ocall_fcntl(int fd, int cmd) {
    return fcntl(fd, cmd);
}

int ocall_fcntl_long(int fd, int cmd, c_long arg) {
    return fcntl(fd, cmd, arg);
}

ssize_t ocall_readv(int fd, char* iov_buf, uint buf_size, int iovcnt, bool has_offset, off_t offset) {
    iovec* iov = cast(iovec*)iov_buf;
    ssize_t ret = void;
    int i = void;

    for (i = 0; i < iovcnt; i++) {
        iov[i].iov_base = iov_buf + cast(uint)cast(uintptr_t)iov[i].iov_base;
    }

    if (has_offset)
        ret = preadv(fd, iov, iovcnt, offset);
    else
        ret = readv(fd, iov, iovcnt);

    return ret;
}

ssize_t ocall_writev(int fd, char* iov_buf, uint buf_size, int iovcnt, bool has_offset, off_t offset) {
    iovec* iov = cast(iovec*)iov_buf;
    int i = void;
    ssize_t ret = void;

    for (i = 0; i < iovcnt; i++) {
        iov[i].iov_base = iov_buf + cast(uint)cast(uintptr_t)iov[i].iov_base;
    }

    if (has_offset)
        ret = pwritev(fd, iov, iovcnt, offset);
    else
        ret = writev(fd, iov, iovcnt);

    return ret;
}

int ocall_realpath(const(char)* path, char* buf, uint buf_len) {
    char* val = null;
    val = realpath(path, buf);
    if (val != null) {
        return 0;
    }
    return -1;
}

int ocall_posix_fallocate(int fd, off_t offset, off_t len) {
    return posix_fallocate(fd, offset, len);
}

int ocall_poll(void* fds, uint nfds, int timeout, uint fds_len) {
    return poll(cast(pollfd*)fds, cast(nfds_t)nfds, timeout);
}

int ocall_getopt(int argc, char* argv_buf, uint argv_buf_len, const(char)* optstring) {
    int ret = void;
    int i = void;
    char** argv = cast(char**)argv_buf;

    for (i = 0; i < argc; i++) {
        argv[i] = argv_buf + cast(uintptr_t)argv[i];
    }

    return getopt(argc, argv, optstring);
}

int ocall_sched_yield() {
    return sched_yield();
}

int ocall_get_errno() {
    return errno;
}
