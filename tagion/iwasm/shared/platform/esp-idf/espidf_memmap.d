module espidf_memmap;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    if (prot & MMAP_PROT_EXEC) {
        // Memory allocation with MALLOC_CAP_EXEC will return 4-byte aligned
        // Reserve extra 4 byte to fixup alignment and size for the pointer to
        // the originally allocated address
        void* buf_origin = heap_caps_malloc(size + 4 + uintptr_t.sizeof, MALLOC_CAP_EXEC);
        if (!buf_origin) {
            return null;
        }
        void* buf_fixed = buf_origin + (void*).sizeof;
        if (cast(uintptr_t)buf_fixed & cast(uintptr_t)0x7) {
            buf_fixed = cast(void*)(cast(uintptr_t)(buf_fixed + 4) & (~cast(uintptr_t)7));
        }

        uintptr_t* addr_field = buf_fixed - uintptr_t.sizeof;
        *addr_field = cast(uintptr_t)buf_origin;
        return buf_fixed;
    }
    else {
        return os_malloc(size);
    }
}

void os_munmap(void* addr, size_t size) {
    // We don't need special handling of the executable allocations
    // here, free() of esp-idf handles it properly
    return os_free(addr);
}

int os_mprotect(void* addr, size_t size, int prot) {
    return 0;
}

void os_dcache_flush() {}
