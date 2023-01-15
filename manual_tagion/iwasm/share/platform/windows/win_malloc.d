module win_malloc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

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