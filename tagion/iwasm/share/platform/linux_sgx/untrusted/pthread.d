module pthread;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.stdlib;
public import core.sys.posix.pthread;

int ocall_pthread_rwlock_init(void** rwlock, void* attr) {
    int ret = 0;

    *rwlock = malloc(pthread_rwlock_t.sizeof);
    if (*rwlock == null)
        return -1;

    ret = pthread_rwlock_init(cast(pthread_rwlock_t*)*rwlock, null);
    if (ret != 0) {
        free(*rwlock);
        *rwlock = null;
    }
    cast(void)attr;
    return ret;
}

int ocall_pthread_rwlock_destroy(void* rwlock) {
    pthread_rwlock_t* lock = cast(pthread_rwlock_t*)rwlock;
    int ret = void;

    ret = pthread_rwlock_destroy(lock);
    free(lock);
    return ret;
}

int ocall_pthread_rwlock_rdlock(void* rwlock) {
    return pthread_rwlock_rdlock(cast(pthread_rwlock_t*)rwlock);
}

int ocall_pthread_rwlock_wrlock(void* rwlock) {
    return pthread_rwlock_wrlock(cast(pthread_rwlock_t*)rwlock);
}

int ocall_pthread_rwlock_unlock(void* rwlock) {
    return pthread_rwlock_unlock(cast(pthread_rwlock_t*)rwlock);
}
