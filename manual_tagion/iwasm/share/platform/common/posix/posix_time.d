module posix_time;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

ulong os_time_get_boot_microsecond() {
    timespec ts = void;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }

    return (cast(ulong)ts.tv_sec) * 1000 * 1000 + (cast(ulong)ts.tv_nsec) / 1000;
}
