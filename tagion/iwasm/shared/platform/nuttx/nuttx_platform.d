module nuttx_platform;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2020 XiaoMi Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_extension;
public import platform_api_vmcore;

version (CONFIG_ARCH_USE_TEXT_HEAP) {
public import nuttx/arch;
}

int bh_platform_init() {
    return 0;
}

void bh_platform_destroy() {}

void* os_malloc(uint size) {
    return malloc(size);
}

void* os_realloc(void* ptr, uint size) {
    return realloc(ptr, size);
}

void os_free(void* ptr) {
    free(ptr);
}

int os_dumps_proc_mem_info(char* out_, uint size) {
    return -1;
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
version (CONFIG_ARCH_USE_TEXT_HEAP) {
    if ((prot & MMAP_PROT_EXEC) != 0) {
        return up_textheap_memalign((void*).sizeof, size);
    }
}

    if (cast(ulong)size >= UINT32_MAX)
        return null;
    return malloc(cast(uint)size);
}

void os_munmap(void* addr, size_t size) {
version (CONFIG_ARCH_USE_TEXT_HEAP) {
    if (up_textheap_heapmember(addr)) {
        up_textheap_free(addr);
        return;
    }
}
    return free(addr);
}

int os_mprotect(void* addr, size_t size, int prot) {
    return 0;
}

void os_dcache_flush() {}

/* If AT_FDCWD is provided, maybe we have openat family */
static if (!HasVersion!"AT_FDCWD") {

int openat(int fd, const(char)* path, int oflags, ...) {
    errno = ENOSYS;
    return -1;
}

int fstatat(int fd, const(char)* path, stat* buf, int flag) {
    errno = ENOSYS;
    return -1;
}

int mkdirat(int fd, const(char)* path, mode_t mode) {
    errno = ENOSYS;
    return -1;
}

ssize_t readlinkat(int fd, const(char)* path, char* buf, size_t bufsize) {
    errno = ENOSYS;
    return -1;
}

int linkat(int fd1, const(char)* path1, int fd2, const(char)* path2, int flag) {
    errno = ENOSYS;
    return -1;
}

int renameat(int fromfd, const(char)* from, int tofd, const(char)* to) {
    errno = ENOSYS;
    return -1;
}
int symlinkat(const(char)* target, int fd, const(char)* path) {
    errno = ENOSYS;
    return -1;
}
int unlinkat(int fd, const(char)* path, int flag) {
    errno = ENOSYS;
    return -1;
}
int utimensat(int fd, const(char)* path, const(timespec)[2] ts, int flag) {
    errno = ENOSYS;
    return -1;
}

} /* !defined(AT_FDCWD) */

DIR* fdopendir(int fd) {
    errno = ENOSYS;
    return null;
}
