module sgx_time;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _SGX_TIME_H
version = _SGX_TIME_H;

#ifdef __cplusplus
extern "C" {
//! #endif

enum CLOCK_REALTIME = 0;
enum CLOCK_MONOTONIC = 1;
enum CLOCK_PROCESS_CPUTIME_ID = 2;
enum CLOCK_THREAD_CPUTIME_ID = 3;

enum UTIME_NOW = 0x3fffffff;
enum UTIME_OMIT = 0x3ffffffe;
enum TIMER_ABSTIME = 1;

alias time_t = int;

alias clockid_t = int;

struct timespec {
    time_t tv_sec;
    c_long tv_nsec;
};

int clock_getres(int clock_id, timespec* res);

int clock_gettime(clockid_t clock_id, timespec* tp);

int utimensat(int dirfd, const(char)* pathname, const(timespec)[2] times, int flags);
int futimens(int fd, const(timespec)[2] times);
int clock_nanosleep(clockid_t clock_id, int flags, const(timespec)* request, timespec* remain);

version (none) {
}
}

//! #endif /* end of _SGX_TIME_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

enum string TRACE_FUNC() = ` os_printf("undefined %s\n", __FUNCTION__)`;
enum string TRACE_OCALL_FAIL() = ` os_printf("ocall %s failed!\n", __FUNCTION__)`;

int ocall_clock_gettime(int* p_ret, uint clock_id, void* tp_buf, uint tp_buf_size);
int ocall_clock_getres(int* p_ret, int clock_id, void* res_buf, uint res_buf_size);
int ocall_utimensat(int* p_ret, int dirfd, const(char)* pathname, const(void)* times_buf, uint times_buf_size, int flags);
int ocall_futimens(int* p_ret, int fd, const(void)* times_buf, uint times_buf_size);
int ocall_clock_nanosleep(int* p_ret, uint clock_id, int flags, const(void)* req_buf, uint req_buf_size, const(void)* rem_buf, uint rem_buf_size);

ulong os_time_get_boot_microsecond() {
version (SGX_DISABLE_WASI) {} else {
    timespec ts = void;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }

    return (cast(ulong)ts.tv_sec) * 1000 * 1000 + (cast(ulong)ts.tv_nsec) / 1000;
} version (SGX_DISABLE_WASI) {
    return 0;
}
}

version (SGX_DISABLE_WASI) {} else {

int clock_getres(int clock_id, timespec* res) {
    int ret = void;

    if (ocall_clock_getres(&ret, clock_id, cast(void*)res, timespec.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int clock_gettime(clockid_t clock_id, timespec* tp) {
    int ret = void;

    if (ocall_clock_gettime(&ret, clock_id, cast(void*)tp, timespec.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int utimensat(int dirfd, const(char)* pathname, const(timespec)[2] times, int flags) {
    int ret = void;

    if (ocall_utimensat(&ret, dirfd, pathname, cast(void*)times,
                        timespec.sizeof * 2, flags)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int futimens(int fd, const(timespec)[2] times) {
    int ret = void;

    if (ocall_futimens(&ret, fd, cast(void*)times, timespec.sizeof * 2)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int clock_nanosleep(clockid_t clock_id, int flags, const(timespec)* request, timespec* remain) {
    int ret = void;

    if (ocall_clock_nanosleep(&ret, clock_id, flags, cast(void*)request,
                              timespec.sizeof, cast(void*)remain,
                              timespec.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

}
