module alios_platform;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

int os_thread_sys_init();

void os_thread_sys_destroy();

int bh_platform_init() {
    return os_thread_sys_init();
}

void bh_platform_destroy() {
    os_thread_sys_destroy();
}

void* os_malloc(uint size) {
    return null;
}

void* os_realloc(void* ptr, uint size) {
    return null;
}

void os_free(void* ptr) {}

int os_dumps_proc_mem_info(char* out_, uint size) {
    return -1;
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    if (cast(ulong)size >= UINT32_MAX)
        return null;
    return BH_MALLOC(cast(uint)size);
}

void os_munmap(void* addr, size_t size) {
    return BH_FREE(addr);
}

int os_mprotect(void* addr, size_t size, int prot) {
    return 0;
}

void os_dcache_flush() {}
