module time;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
public import stdbool;
public import core.sys.posix.sys.stat;
public import core.stdc.time;
public import core.sys.posix.fcntl;

/** time clock **/
int ocall_clock_gettime(uint clock_id, void* tp_buf, uint tp_buf_size) {
    return clock_gettime(cast(clockid_t)clock_id, cast(timespec*)tp_buf);
}

int ocall_clock_getres(int clock_id, void* res_buf, uint res_buf_size) {
    return clock_getres(clock_id, cast(timespec*)res_buf);
}

int ocall_utimensat(int dirfd, const(char)* pathname, const(void)* times_buf, uint times_buf_size, int flags) {
    return utimensat(dirfd, pathname, cast(timespec*)times_buf, flags);
}

int ocall_futimens(int fd, const(void)* times_buf, uint times_buf_size) {
    return futimens(fd, cast(timespec*)times_buf);
}

int ocall_clock_nanosleep(uint clock_id, int flags, const(void)* req_buf, uint req_buf_size, const(void)* rem_buf, uint rem_buf_size) {
    return clock_nanosleep(cast(clockid_t)clock_id, flags,
                           cast(timespec*)req_buf,
                           cast(timespec*)rem_buf);
}
