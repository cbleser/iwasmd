module sgx_thread;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

version (SGX_DISABLE_PTHREAD) {} else {
struct _Thread_wrapper_arg {
    thread_start_routine_t start;
    void* arg;
}alias thread_wrapper_arg = _Thread_wrapper_arg;

private void* os_thread_wrapper(void* arg) {
    thread_wrapper_arg* targ = arg;
    thread_start_routine_t start_func = targ.start;
    void* thread_arg = targ.arg;

version (none) {
    os_printf("THREAD CREATED %p\n", &targ);
}
    BH_FREE(targ);
    start_func(thread_arg);
    return null;
}

int os_thread_create_with_prio(korp_tid* tid, thread_start_routine_t start, void* arg, uint stack_size, int prio) {
    thread_wrapper_arg* targ = void;

    assert(tid);
    assert(start);

    targ = cast(thread_wrapper_arg*)BH_MALLOC(typeof(*targ).sizeof);
    if (!targ) {
        return BHT_ERROR;
    }

    targ.start = start;
    targ.arg = arg;

    if (pthread_create(tid, null, &os_thread_wrapper, targ) != 0) {
        BH_FREE(targ);
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_thread_create(korp_tid* tid, thread_start_routine_t start, void* arg, uint stack_size) {
    return os_thread_create_with_prio(tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}
}

korp_tid os_self_thread() {
version (SGX_DISABLE_PTHREAD) {} else {
    return pthread_self();
} version (SGX_DISABLE_PTHREAD) {
    return 0;
}
}

int os_mutex_init(korp_mutex* mutex) {
version (SGX_DISABLE_PTHREAD) {} else {
    pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
    *mutex = m;
}
    return BHT_OK;
}

int os_mutex_destroy(korp_mutex* mutex) {
version (SGX_DISABLE_PTHREAD) {} else {
    pthread_mutex_destroy(mutex);
}
    return BHT_OK;
}

int os_mutex_lock(korp_mutex* mutex) {
version (SGX_DISABLE_PTHREAD) {} else {
    return pthread_mutex_lock(mutex);
} version (SGX_DISABLE_PTHREAD) {
    return 0;
}
}

int os_mutex_unlock(korp_mutex* mutex) {
version (SGX_DISABLE_PTHREAD) {} else {
    return pthread_mutex_unlock(mutex);
} version (SGX_DISABLE_PTHREAD) {
    return 0;
}
}

int os_cond_init(korp_cond* cond) {
version (SGX_DISABLE_PTHREAD) {} else {
    pthread_cond_t c = PTHREAD_COND_INITIALIZER;
    *cond = c;
}
    return BHT_OK;
}

int os_cond_destroy(korp_cond* cond) {
version (SGX_DISABLE_PTHREAD) {} else {
    pthread_cond_destroy(cond);
}
    return BHT_OK;
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
version (SGX_DISABLE_PTHREAD) {} else {
    assert(cond);
    assert(mutex);

    if (pthread_cond_wait(cond, mutex) != BHT_OK)
        return BHT_ERROR;

}
    return BHT_OK;
}

int os_cond_reltimedwait(korp_cond* cond, korp_mutex* mutex, ulong useconds) {
    os_printf("warning: SGX pthread_cond_timedwait isn't supported, "
              ~ "calling pthread_cond_wait instead!\n");
    return BHT_ERROR;
}

int os_cond_signal(korp_cond* cond) {
version (SGX_DISABLE_PTHREAD) {} else {
    assert(cond);

    if (pthread_cond_signal(cond) != BHT_OK)
        return BHT_ERROR;

}
    return BHT_OK;
}

int os_cond_broadcast(korp_cond* cond) {
version (SGX_DISABLE_PTHREAD) {} else {
    assert(cond);

    if (pthread_cond_broadcast(cond) != BHT_OK)
        return BHT_ERROR;

}
    return BHT_OK;
}

int os_thread_join(korp_tid thread, void** value_ptr) {
version (SGX_DISABLE_PTHREAD) {} else {
    return pthread_join(thread, value_ptr);
} version (SGX_DISABLE_PTHREAD) {
    return 0;
}
}

int os_thread_detach(korp_tid thread) {
    /* SGX pthread_detach isn't provided, return directly. */
    return 0;
}

void os_thread_exit(void* retval) {
version (SGX_DISABLE_PTHREAD) {} else {
    pthread_exit(retval);
} version (SGX_DISABLE_PTHREAD) {
    return;
}
}

ubyte* os_thread_get_stack_boundary() {
    /* TODO: get sgx stack boundary */
    return null;
}
