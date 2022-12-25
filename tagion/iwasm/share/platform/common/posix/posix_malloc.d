module posix_malloc;
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
    int ret = -1;
    FILE* f = void;
    char[128] line = 0;
    uint out_idx = 0;

    if (!out_ || !size)
        goto quit;

    f = fopen("/proc/self/status", "r");
    if (!f) {
        perror("fopen failed: ");
        goto quit;
    }

    memset(out_, 0, size);

    while (fgets(line.ptr, line.sizeof, f)) {
static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
        if (strncmp(line.ptr, "Vm", 2) == 0 || strncmp(line.ptr, "Rss", 3) == 0) {
//! #else
        if (strncmp(line, "VmRSS", 5) == 0
            || strncmp(line.ptr, "RssAnon", 7) == 0) {
//! #endif
            size_t line_len = strlen(line);
            if (line_len >= size - 1 - out_idx)
                goto close_file;

            /* copying without null-terminated byte */
            memcpy(out_ + out_idx, line.ptr, line_len);
            out_idx += line_len;
        }
    }

    if (ferror(f)) {
        perror("fgets failed: ");
        goto close_file;
    }

    ret = 0;
close_file:
    fclose(f);
quit:
    return ret;}
}