module sgx_pthread;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _SGX_PTHREAD_H
version = _SGX_PTHREAD_H;

#ifdef __cplusplus
extern "C" {
//! #endif

version (SGX_THREAD_LOCK_INITIALIZER) {} else { /* defined since sgxsdk-2.11 */
/* sgxsdk doesn't support pthread_rwlock related APIs until
   version 2.11, we implement them by ourselves. */
alias pthread_rwlock_t = uintptr_t;

int pthread_rwlock_init(pthread_rwlock_t* rwlock, void* attr);
int pthread_rwlock_destroy(pthread_rwlock_t* rwlock);

int pthread_rwlock_wrlock(pthread_rwlock_t* rwlock);
int pthread_rwlock_rdlock(pthread_rwlock_t* rwlock);
int pthread_rwlock_unlock(pthread_rwlock_t* rwlock);
} /* end of SGX_THREAD_LOCK_INITIALIZER */

version (none) {
}
}

//! #endif /* end of _SGX_PTHREAD_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import sgx_pthread;
public import sgx_error;

version (SGX_DISABLE_WASI) {} else {

enum string TRACE_FUNC() = ` os_printf("undefined %s\n", __FUNCTION__)`;
enum string TRACE_OCALL_FAIL() = ` os_printf("ocall %s failed!\n", __FUNCTION__)`;

version (SGX_THREAD_LOCK_INITIALIZER) {} else { /* defined since sgxsdk-2.11 */
/* sgxsdk doesn't support pthread_rwlock related APIs until
   version 2.11, we implement them by ourselves. */
int ocall_pthread_rwlock_init(int* p_ret, void** rwlock, void* attr);

int ocall_pthread_rwlock_destroy(int* p_ret, void** rwlock);

int ocall_pthread_rwlock_rdlock(int* p_ret, void** rwlock);

int ocall_pthread_rwlock_wrlock(int* p_ret, void** rwlock);

int ocall_pthread_rwlock_unlock(int* p_ret, void** rwlock);

int pthread_rwlock_init(pthread_rwlock_t* rwlock, void* attr) {
    int ret = -1;

    if (ocall_pthread_rwlock_init(&ret, cast(void**)rwlock, null) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }
    cast(void)attr;
    return ret;
}

int pthread_rwlock_destroy(pthread_rwlock_t* rwlock) {
    int ret = -1;

    if (ocall_pthread_rwlock_destroy(&ret, cast(void*)*rwlock) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
    }
    return ret;
}

int pthread_rwlock_rdlock(pthread_rwlock_t* rwlock) {
    int ret = -1;

    if (ocall_pthread_rwlock_rdlock(&ret, cast(void*)*rwlock) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
    }
    return ret;
}

int pthread_rwlock_wrlock(pthread_rwlock_t* rwlock) {
    int ret = -1;

    if (ocall_pthread_rwlock_wrlock(&ret, cast(void*)*rwlock) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
    }
    return ret;
}

int pthread_rwlock_unlock(pthread_rwlock_t* rwlock) {
    int ret = -1;

    if (ocall_pthread_rwlock_unlock(&ret, cast(void*)*rwlock) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
    }
    return ret;
}
} /* end of SGX_THREAD_LOCK_INITIALIZER */

}
