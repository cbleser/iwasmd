module espidf_thread;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 


public import platform_api_vmcore;
public import platform_api_extension;

struct _Thread_wrapper_arg {
    thread_start_routine_t start;
    void* arg;
}alias thread_wrapper_arg = _Thread_wrapper_arg;

private void* os_thread_wrapper(void* arg) {
    thread_wrapper_arg* targ = arg;
    thread_start_routine_t start_func = targ.start;
    void* thread_arg = targ.arg;

version (none) {
    os_printf("THREAD CREATED %jx\n", cast(uintmax_t)cast(uintptr_t)pthread_self());
}
    BH_FREE(targ);
    start_func(thread_arg);
    return null;
}

korp_tid os_self_thread() {
    /* only allowed if this is a thread, xTaskCreate is not enough look at
     * product_mini for how to use this*/
    return pthread_self();
}

int os_mutex_init(korp_mutex* mutex) {
    return pthread_mutex_init(mutex, null);
}

int os_recursive_mutex_init(korp_mutex* mutex) {
    int ret = void;

    pthread_mutexattr_t mattr = void;

    assert(mutex);
    ret = pthread_mutexattr_init(&mattr);
    if (ret)
        return BHT_ERROR;

    pthread_mutexattr_settype(&mattr, PTHREAD_MUTEX_RECURSIVE);
    ret = pthread_mutex_init(mutex, &mattr);
    pthread_mutexattr_destroy(&mattr);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int os_mutex_destroy(korp_mutex* mutex) {
    return pthread_mutex_destroy(mutex);
}

int os_mutex_lock(korp_mutex* mutex) {
    return pthread_mutex_lock(mutex);
}

int os_mutex_unlock(korp_mutex* mutex) {
    return pthread_mutex_unlock(mutex);
}

int os_thread_create_with_prio(korp_tid* tid, thread_start_routine_t start, void* arg, uint stack_size, int prio) {
    pthread_attr_t tattr = void;
    thread_wrapper_arg* targ = void;

    assert(stack_size > 0);
    assert(tid);
    assert(start);

    pthread_attr_init(&tattr);
    pthread_attr_setdetachstate(&tattr, PTHREAD_CREATE_JOINABLE);
    if (pthread_attr_setstacksize(&tattr, stack_size) != 0) {
        os_printf("Invalid thread stack size %u. Min stack size = %u",
                  stack_size, PTHREAD_STACK_MIN);
        pthread_attr_destroy(&tattr);
        return BHT_ERROR;
    }

    targ = cast(thread_wrapper_arg*)BH_MALLOC(typeof(*targ).sizeof);
    if (!targ) {
        pthread_attr_destroy(&tattr);
        return BHT_ERROR;
    }

    targ.start = start;
    targ.arg = arg;

    if (pthread_create(tid, &tattr, &os_thread_wrapper, targ) != 0) {
        pthread_attr_destroy(&tattr);
        os_free(targ);
        return BHT_ERROR;
    }

    pthread_attr_destroy(&tattr);
    return BHT_OK;
}

int os_thread_create(korp_tid* tid, thread_start_routine_t start, void* arg, uint stack_size) {
    return os_thread_create_with_prio(tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

int os_thread_join(korp_tid thread, void** retval) {
    return pthread_join(thread, retval);
}

int os_thread_detach(korp_tid tid) {
    return pthread_detach(tid);
}

void os_thread_exit(void* retval) {
    pthread_exit(retval);
}

int os_cond_init(korp_cond* cond) {
    return pthread_cond_init(cond, null);
}

int os_cond_destroy(korp_cond* cond) {
    return pthread_cond_destroy(cond);
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
    return pthread_cond_wait(cond, mutex);
}

private void msec_nsec_to_abstime(timespec* ts, ulong usec) {
    timeval tv = void;
    time_t tv_sec_new = void;
    int tv_nsec_new = void;

    gettimeofday(&tv, null);

    tv_sec_new = (time_t)(tv.tv_sec + usec / 1000000);
    if (tv_sec_new >= tv.tv_sec) {
        ts.tv_sec = tv_sec_new;
    }
    else {
        /* integer overflow */
        ts.tv_sec = BH_TIME_T_MAX;
        os_printf("Warning: os_cond_reltimedwait exceeds limit, "
                  ~ "set to max timeout instead\n");
    }

    tv_nsec_new = cast(int)(tv.tv_usec * 1000 + (usec % 1000000) * 1000);
    if (tv.tv_usec * 1000 >= tv.tv_usec && tv_nsec_new >= tv.tv_usec * 1000) {
        ts.tv_nsec = tv_nsec_new;
    }
    else {
        /* integer overflow */
        ts.tv_nsec = LONG_MAX;
        os_printf("Warning: os_cond_reltimedwait exceeds limit, "
                  ~ "set to max timeout instead\n");
    }

    if (ts.tv_nsec >= 1000000000L && ts.tv_sec < BH_TIME_T_MAX) {
        ts.tv_sec++;
        ts.tv_nsec -= 1000000000L;
    }
}

int os_cond_reltimedwait(korp_cond* cond, korp_mutex* mutex, ulong useconds) {
    int ret = void;
    timespec abstime = void;

    if (useconds == BHT_WAIT_FOREVER)
        ret = pthread_cond_wait(cond, mutex);
    else {
        msec_nsec_to_abstime(&abstime, useconds);
        ret = pthread_cond_timedwait(cond, mutex, &abstime);
    }

    if (ret != BHT_OK && ret != ETIMEDOUT)
        return BHT_ERROR;

    return ret;
}

int os_cond_signal(korp_cond* cond) {
    return pthread_cond_signal(cond);
}

int os_cond_broadcast(korp_cond* cond) {
    return pthread_cond_broadcast(cond);
}