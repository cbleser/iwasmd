module riot_platform;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * Copyright (C) 2020 TU Bergakademie Freiberg Karl Fessel
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
    if (size > (cast(uint)~0))
        return null;
    return BH_MALLOC(cast(uint)size);
}

void os_munmap(void* addr, size_t size) {
    return BH_FREE(addr);
}

int os_mprotect(void* addr, size_t size, int prot) {
    return 0;
}

void os_dcache_flush() {
static if (HasVersion!"CONFIG_CPU_CORTEX_M7" && HasVersion!"CONFIG_ARM_MPU") {
    uint key = void;
    key = irq_lock();
    SCB_CleanDCache();
    irq_unlock(key);
}
}
