module freertos_malloc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

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
