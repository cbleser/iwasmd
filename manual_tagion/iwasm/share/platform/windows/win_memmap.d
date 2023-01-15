module win_memmap;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

enum TRACE_MEMMAP = 0;

private DWORD access_to_win32_flags(int prot) {
    DWORD protect = PAGE_NOACCESS;

    if (prot & MMAP_PROT_EXEC) {
        if (prot & MMAP_PROT_WRITE)
            protect = PAGE_EXECUTE_READWRITE;
        else
            protect = PAGE_EXECUTE_READ;
    }
    else if (prot & MMAP_PROT_WRITE) {
        protect = PAGE_READWRITE;
    }
    else if (prot & MMAP_PROT_READ) {
        protect = PAGE_READONLY;
    }

    return protect;
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    DWORD alloc_type = MEM_RESERVE;
    DWORD protect = void;
    size_t request_size = void, page_size = void;
    void* addr = void;

    page_size = os_getpagesize();
    request_size = (size + page_size - 1) & ~(page_size - 1);

    if (request_size < size)
        /* integer overflow */
        return null;

static if (WASM_ENABLE_JIT != 0) {
    /**
     * Allocate memory at the highest possible address if the
     * request size is large, or LLVM JIT might report error:
     * IMAGE_REL_AMD64_ADDR32NB relocation requires an ordered
     * section layout.
     */
    if (request_size > 10 * BH_MB)
        alloc_type |= MEM_TOP_DOWN;
}

    protect = access_to_win32_flags(prot);
    if (protect != PAGE_NOACCESS) {
        alloc_type |= MEM_COMMIT;
    }

    addr = VirtualAlloc(cast(LPVOID)hint, request_size, alloc_type, protect);

static if (TRACE_MEMMAP != 0) {
    printf("Map memory, request_size: %zu, alloc_type: 0x%x, "
           ~ "protect: 0x%x, ret: %p\n",
           request_size, alloc_type, protect, addr);
}
    return addr;
}

void os_munmap(void* addr, size_t size) {
    size_t page_size = os_getpagesize();
    size_t request_size = (size + page_size - 1) & ~(page_size - 1);

    if (addr) {
        if (!VirtualFree(addr, request_size, MEM_DECOMMIT)) {
            printf("warning: os_munmap decommit pages failed, "
                   ~ "addr: %p, request_size: %zu, errno: %d\n",
                   addr, request_size, errno);
            return;
        }

        if (!VirtualFree(addr, 0, MEM_RELEASE)) {
            printf("warning: os_munmap release pages failed, "
                   ~ "addr: %p, size: %zu, errno:%d\n",
                   addr, request_size, errno);
        }
    }
static if (TRACE_MEMMAP != 0) {
    printf("Unmap memory, addr: %p, request_size: %zu\n", addr, request_size);
}
}

void* os_mem_commit(void* addr, size_t size, int flags) {
    DWORD protect = access_to_win32_flags(flags);
    size_t page_size = os_getpagesize();
    size_t request_size = (size + page_size - 1) & ~(page_size - 1);

    if (!addr)
        return null;

static if (TRACE_MEMMAP != 0) {
    printf("Commit memory, addr: %p, request_size: %zu, protect: 0x%x\n", addr,
           request_size, protect);
}
    return VirtualAlloc(cast(LPVOID)addr, request_size, MEM_COMMIT, protect);
}

void os_mem_decommit(void* addr, size_t size) {
    size_t page_size = os_getpagesize();
    size_t request_size = (size + page_size - 1) & ~(page_size - 1);

    if (!addr)
        return;

static if (TRACE_MEMMAP != 0) {
    printf("Decommit memory, addr: %p, request_size: %zu\n", addr,
           request_size);
}
    VirtualFree(cast(LPVOID)addr, request_size, MEM_DECOMMIT);
}

int os_mprotect(void* addr, size_t size, int prot) {
    DWORD protect = void;
    size_t page_size = os_getpagesize();
    size_t request_size = (size + page_size - 1) & ~(page_size - 1);

    if (!addr)
        return 0;

    protect = access_to_win32_flags(prot);
static if (TRACE_MEMMAP != 0) {
    printf("Mprotect memory, addr: %p, request_size: %zu, protect: 0x%x\n",
           addr, request_size, protect);
}
    return VirtualProtect(cast(LPVOID)addr, request_size, protect, null);
}
