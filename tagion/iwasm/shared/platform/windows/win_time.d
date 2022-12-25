module win_time;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

ulong os_time_get_boot_microsecond() {
    timespec ts = void;
version (Windows) {
    // https://www.mail-archive.com/mingw-w64-public@lists.sourceforge.net/msg18361.html
    clock_gettime(CLOCK_REALTIME, &ts);
} else {
    timespec_get(&ts, TIME_UTC);
}

    return (cast(ulong)ts.tv_sec) * 1000 * 1000 + (cast(ulong)ts.tv_nsec) / 1000;
}
