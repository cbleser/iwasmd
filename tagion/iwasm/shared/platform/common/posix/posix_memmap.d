module posix_memmap;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

version (BH_ENABLE_TRACE_MMAP) {} else {
enum BH_ENABLE_TRACE_MMAP = 0;
}

static if (BH_ENABLE_TRACE_MMAP != 0) {
private size_t total_size_mmapped = 0;
private size_t total_size_munmapped = 0;
}

enum HUGE_PAGE_SIZE = (2 * 1024 * 1024);

static if (!HasVersion!"OSX" && !HasVersion!"__NuttX__" && HasVersion!"MADV_HUGEPAGE") {
pragma(inline, true) private uintptr_t round_up(uintptr_t v, uintptr_t b) {
    uintptr_t m = b - 1;
    return (v + m) & ~m;
}

pragma(inline, true) private uintptr_t round_down(uintptr_t v, uintptr_t b) {
    uintptr_t m = b - 1;
    return v & ~m;
}
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    int map_prot = PROT_NONE;
    int map_flags = MAP_ANONYMOUS | MAP_PRIVATE;
    ulong request_size = void, page_size = void;
    ubyte* addr = MAP_FAILED;
    uint i = void;

    page_size = cast(ulong)getpagesize();
    request_size = (size + page_size - 1) & ~(page_size - 1);

static if (!HasVersion!"OSX" && !HasVersion!"__NuttX__" && HasVersion!"MADV_HUGEPAGE") {
    /* huge page isn't supported on MacOS and NuttX */
    if (request_size >= HUGE_PAGE_SIZE)
        /* apply one extra huge page */
        request_size += HUGE_PAGE_SIZE;
}

    if (cast(size_t)request_size < size)
        /* integer overflow */
        return null;

    if (request_size > 16 * cast(ulong)UINT32_MAX)
        /* at most 16 G is allowed */
        return null;

    if (prot & MMAP_PROT_READ)
        map_prot |= PROT_READ;

    if (prot & MMAP_PROT_WRITE)
        map_prot |= PROT_WRITE;

    if (prot & MMAP_PROT_EXEC)
        map_prot |= PROT_EXEC;

static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
version (OSX) {} else {
    if (flags & MMAP_MAP_32BIT)
        map_flags |= MAP_32BIT;
}
}

    if (flags & MMAP_MAP_FIXED)
        map_flags |= MAP_FIXED;

static if (HasVersion!"BUILD_TARGET_RISCV64_LP64D" || HasVersion!"BUILD_TARGET_RISCV64_LP64") {
    /* As AOT relocation in RISCV64 may require that the code/data mapped
     * is in range 0 to 2GB, we try to map the memory with hint address
     * (mmap's first argument) to meet the requirement.
     */
    if (!hint && !(flags & MMAP_MAP_FIXED) && (flags & MMAP_MAP_32BIT)) {
        ubyte* stack_addr = cast(ubyte*)&map_prot;
        ubyte* text_addr = cast(ubyte*)os_mmap;
        /* hint address begins with 1MB */
        static ubyte* hint_addr = cast(ubyte*)cast(uintptr_t)BH_MB;

        if ((hint_addr - text_addr >= 0 && hint_addr - text_addr < 100 * BH_MB)
            || (text_addr - hint_addr >= 0
                && text_addr - hint_addr < 100 * BH_MB)) {
            /* hint address is possibly in text section, skip it */
            hint_addr += 100 * BH_MB;
        }

        if ((hint_addr - stack_addr >= 0 && hint_addr - stack_addr < 8 * BH_MB)
            || (stack_addr - hint_addr >= 0
                && stack_addr - hint_addr < 8 * BH_MB)) {
            /* hint address is possibly in native stack area, skip it */
            hint_addr += 8 * BH_MB;
        }

        /* try 10 times, step with 1MB each time */
        for (i = 0; i < 10 && hint_addr < cast(ubyte*)cast(uintptr_t)(2ULL * BH_GB);
             i++) {
            addr = mmap(hint_addr, request_size, map_prot, map_flags, -1, 0);
            if (addr != MAP_FAILED) {
                if (addr > cast(ubyte*)cast(uintptr_t)(2ULL * BH_GB)) {
                    /* unmap and try again if the mapped address doesn't
                     * meet the requirement */
                    os_munmap(addr, request_size);
                }
                else {
                    /* success, reset next hint address */
                    hint_addr += request_size;
                    break;
                }
            }
            hint_addr += BH_MB;
        }
    }
} /* end of BUILD_TARGET_RISCV64_LP64D || BUILD_TARGET_RISCV64_LP64 */

    /* memory has't been mapped or was mapped failed previously */
    if (addr == MAP_FAILED) {
        /* try 5 times */
        for (i = 0; i < 5; i++) {
            addr = mmap(hint, request_size, map_prot, map_flags, -1, 0);
            if (addr != MAP_FAILED)
                break;
        }
    }

    if (addr == MAP_FAILED) {
static if (BH_ENABLE_TRACE_MMAP != 0) {
        os_printf("mmap failed\n");
}
        return null;
    }

static if (BH_ENABLE_TRACE_MMAP != 0) {
    total_size_mmapped += request_size;
    os_printf("mmap return: %p with size: %zu, total_size_mmapped: %zu, "
              ~ "total_size_munmapped: %zu\n",
              addr, request_size, total_size_mmapped, total_size_munmapped);
}

static if (!HasVersion!"OSX" && !HasVersion!"__NuttX__" && HasVersion!"MADV_HUGEPAGE") {
    /* huge page isn't supported on MacOS and NuttX */
    if (request_size > HUGE_PAGE_SIZE) {
        uintptr_t huge_start = void, huge_end = void;
        size_t prefix_size = 0, suffix_size = HUGE_PAGE_SIZE;

        huge_start = round_up(cast(uintptr_t)addr, HUGE_PAGE_SIZE);

        if (huge_start > cast(uintptr_t)addr) {
            prefix_size += huge_start - cast(uintptr_t)addr;
            suffix_size -= huge_start - cast(uintptr_t)addr;
        }

        /* unmap one extra huge page */

        if (prefix_size > 0) {
            munmap(addr, prefix_size);
static if (BH_ENABLE_TRACE_MMAP != 0) {
            total_size_munmapped += prefix_size;
            os_printf("munmap %p with size: %zu, total_size_mmapped: %zu, "
                      ~ "total_size_munmapped: %zu\n",
                      addr, prefix_size, total_size_mmapped,
                      total_size_munmapped);
}
        }
        if (suffix_size > 0) {
            munmap(addr + request_size - suffix_size, suffix_size);
static if (BH_ENABLE_TRACE_MMAP != 0) {
            total_size_munmapped += suffix_size;
            os_printf("munmap %p with size: %zu, total_size_mmapped: %zu, "
                      ~ "total_size_munmapped: %zu\n",
                      addr + request_size - suffix_size, suffix_size,
                      total_size_mmapped, total_size_munmapped);
}
        }

        addr = cast(ubyte*)huge_start;
        request_size -= HUGE_PAGE_SIZE;

        huge_end = round_down(huge_start + request_size, HUGE_PAGE_SIZE);
        if (huge_end > huge_start) {
            int ret = madvise(cast(void*)huge_start, huge_end - huge_start,
                              MADV_HUGEPAGE);
            if (ret) {
static if (BH_ENABLE_TRACE_MMAP != 0) {
                os_printf(
                    "warning: madvise(%p, %lu) huge page failed, return %d\n",
                    cast(void*)huge_start, huge_end - huge_start, ret);
}
            }
        }
    }
} /* end of __APPLE__ || __NuttX__ || !MADV_HUGEPAGE */

    return addr;
}

void os_munmap(void* addr, size_t size) {
    ulong page_size = cast(ulong)getpagesize();
    ulong request_size = (size + page_size - 1) & ~(page_size - 1);

    if (addr) {
        if (munmap(addr, request_size)) {
            os_printf("os_munmap error addr:%p, size:0x%" PRIx64 ~ ", errno:%d\n",
                      addr, request_size, errno);
            return;
        }
static if (BH_ENABLE_TRACE_MMAP != 0) {
        total_size_munmapped += request_size;
        os_printf("munmap %p with size: %zu, total_size_mmapped: %zu, "
                  ~ "total_size_munmapped: %zu\n",
                  addr, request_size, total_size_mmapped, total_size_munmapped);
}
    }
}

int os_mprotect(void* addr, size_t size, int prot) {
    int map_prot = PROT_NONE;
    ulong page_size = cast(ulong)getpagesize();
    ulong request_size = (size + page_size - 1) & ~(page_size - 1);

    if (!addr)
        return 0;

    if (prot & MMAP_PROT_READ)
        map_prot |= PROT_READ;

    if (prot & MMAP_PROT_WRITE)
        map_prot |= PROT_WRITE;

    if (prot & MMAP_PROT_EXEC)
        map_prot |= PROT_EXEC;

    return mprotect(addr, request_size, map_prot);
}

void os_dcache_flush() {}
