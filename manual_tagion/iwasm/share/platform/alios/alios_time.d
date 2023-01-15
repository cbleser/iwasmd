module alios_time;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

ulong os_time_get_boot_microsecond() {
    return cast(ulong)aos_now_ms() * 1000;
}
