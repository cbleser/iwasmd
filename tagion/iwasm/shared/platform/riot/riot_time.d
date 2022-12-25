module riot_time;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * Copyright (C) 2020 TU Bergakademie Freiberg Karl Fessel
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import ztimer64;
public import kernel_defines;

static if (IS_USED(MODULE_ZTIMER64_USEC)) {
ulong os_time_get_boot_microsecond() {
    return ztimer64_now(ZTIMER64_USEC);
}
} else static if (IS_USED(MODULE_ZTIMER64_MSEC)) {
ulong os_time_get_boot_microsecond() {
    return ztimer64_now(ZTIMER64_MSEC) * 1000;
}
} else {
version (__GNUC__) {
ulong os_time_get_boot_microsecond();
}
ulong os_time_get_boot_microsecond() {
    static ulong times;
    return ++times;
}
}
