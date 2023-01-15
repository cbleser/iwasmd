module espidf_malloc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

void* os_malloc(uint size) {
    void* buf_origin = void;
    void* buf_fixed = void;
    uintptr_t* addr_field = void;

    buf_origin = malloc(size + 8 + uintptr_t.sizeof);
    if (!buf_origin) {
        return null;
    }
    buf_fixed = buf_origin + (void*).sizeof;
    if (cast(uintptr_t)buf_fixed & cast(uintptr_t)0x7) {
        buf_fixed = cast(void*)(cast(uintptr_t)(buf_fixed + 8) & (~cast(uintptr_t)7));
    }

    addr_field = buf_fixed - uintptr_t.sizeof;
    *addr_field = cast(uintptr_t)buf_origin;

    return buf_fixed;
}

void* os_realloc(void* ptr, uint size) {
    void* mem_origin = void;
    void* mem_new = void;
    void* mem_new_fixed = void;
    uintptr_t* addr_field = void;

    if (!ptr) {
        return os_malloc(size);
    }

    addr_field = ptr - uintptr_t.sizeof;
    mem_origin = cast(void*)(*addr_field);
    mem_new = realloc(mem_origin, size + 8 + uintptr_t.sizeof);
    if (!mem_new) {
        return null;
    }

    if (mem_origin != mem_new) {
        mem_new_fixed = mem_new + uintptr_t.sizeof;
        if (cast(uint)mem_new_fixed & 0x7) {
            mem_new_fixed =
                cast(void*)(cast(uintptr_t)(mem_new + 8) & (~cast(uintptr_t)7));
        }

        addr_field = mem_new_fixed - uintptr_t.sizeof;
        *addr_field = cast(uintptr_t)mem_new;

        return mem_new_fixed;
    }

    return ptr;
}

void os_free(void* ptr) {
    void* mem_origin = void;
    uintptr_t* addr_field = void;

    if (ptr) {
        addr_field = ptr - uintptr_t.sizeof;
        mem_origin = cast(void*)(*addr_field);

        free(mem_origin);
    }
}

int os_dumps_proc_mem_info(char* out_, uint size) {
    return -1;
}
