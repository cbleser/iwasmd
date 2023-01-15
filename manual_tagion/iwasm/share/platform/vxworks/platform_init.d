module platform_init;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

int bh_platform_init() {
    return 0;
}

void bh_platform_destroy() {}

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
