module platform_init;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

int os_thread_sys_init();

void os_thread_sys_destroy();

int init_winsock();

void deinit_winsock();

int bh_platform_init() {
    if (init_winsock() != 0) {
        return -1;
    }

    return os_thread_sys_init();
}

void bh_platform_destroy() {
    deinit_winsock();

    os_thread_sys_destroy();
}

int os_printf(const(char)* format, ...) {
    int ret = 0;
    va_list ap = void;

    va_start(ap, format);
version (BH_VPRINTF) {} else {
    ret += vprintf(format, ap);
} version (BH_VPRINTF) {
    ret += BH_VPRINTF(format, ap);
}
    va_end(ap);

    return ret;
}

int os_vprintf(const(char)* format, va_list ap) {
version (BH_VPRINTF) {} else {
    return vprintf(format, ap);
} version (BH_VPRINTF) {
    return BH_VPRINTF(format, ap);
}
}

uint os_getpagesize() {
    SYSTEM_INFO sys_info = void;
    GetNativeSystemInfo(&sys_info);
    return cast(uint)sys_info.dwPageSize;
}

void os_dcache_flush() {}
