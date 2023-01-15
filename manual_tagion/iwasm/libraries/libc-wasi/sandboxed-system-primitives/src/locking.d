module locking;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

 
public import ssp_config;

version (__has_extension) {} else {
enum string __has_extension(string x) = ` 0`;
}

static if (__has_extension(c_thread_safety_attributes)) {
enum string LOCK_ANNOTATE(string x) = ` __attribute__((x))`;
} else {
//#define LOCK_ANNOTATE(x)
}

/* Lock annotation macros. */

enum LOCKABLE = LOCK_ANNOTATE(lockable);

enum string LOCKS_EXCLUSIVE(...) = ` LOCK_ANNOTATE(exclusive_lock_function(__VA_ARGS__))`;
enum string LOCKS_SHARED(...) = ` LOCK_ANNOTATE(shared_lock_function(__VA_ARGS__))`;

enum string TRYLOCKS_EXCLUSIVE(...) = ` \
    LOCK_ANNOTATE(exclusive_trylock_function(__VA_ARGS__))`;
enum string TRYLOCKS_SHARED(...) = ` LOCK_ANNOTATE(shared_trylock_function(__VA_ARGS__))`;

enum string UNLOCKS(...) = ` LOCK_ANNOTATE(unlock_function(__VA_ARGS__))`;

enum string REQUIRES_EXCLUSIVE(...) = ` \
    LOCK_ANNOTATE(exclusive_locks_required(__VA_ARGS__))`;
enum string REQUIRES_SHARED(...) = ` LOCK_ANNOTATE(shared_locks_required(__VA_ARGS__))`;
enum string REQUIRES_UNLOCKED(...) = ` LOCK_ANNOTATE(locks_excluded(__VA_ARGS__))`;

enum NO_LOCK_ANALYSIS = LOCK_ANNOTATE(no_thread_safety_analysis);

/* Mutex that uses the lock annotations. */

LOCKABLE mutex {
    pthread_mutex_t object = void;
}{}

/* clang-format off */
enum MUTEX_INITIALIZER = \
    { PTHREAD_MUTEX_INITIALIZER };
/* clang-format on */

pragma(inline, true) private bool mutex_init(mutex* lock); REQUIRES_UNLOCKED* lock {
    return pthread_mutex_init(&lock.object, null) == 0 ? true : false;
}

pragma(inline, true) private void mutex_destroy(mutex* lock); REQUIRES_UNLOCKED* lock {
    pthread_mutex_destroy(&lock.object);
}

pragma(inline, true) private void mutex_lock(mutex* lock); LOCKS_EXCLUSIVE NO_LOCK_ANALYSIS {
    pthread_mutex_lock(&lock.object);
}

pragma(inline, true) private void mutex_unlock(mutex* lock); UNLOCKS NO_LOCK_ANALYSIS {
    pthread_mutex_unlock(&lock.object);
}

/* Read-write lock that uses the lock annotations. */

LOCKABLE rwlock {
    pthread_rwlock_t object = void;
}{}

pragma(inline, true) private bool rwlock_init(rwlock* lock); REQUIRES_UNLOCKED* lock {
    return pthread_rwlock_init(&lock.object, null) == 0 ? true : false;
}

pragma(inline, true) private void rwlock_rdlock(rwlock* lock); LOCKS_SHARED NO_LOCK_ANALYSIS {
    pthread_rwlock_rdlock(&lock.object);
}

pragma(inline, true) private void rwlock_wrlock(rwlock* lock); LOCKS_EXCLUSIVE NO_LOCK_ANALYSIS {
    pthread_rwlock_wrlock(&lock.object);
}

pragma(inline, true) private void rwlock_unlock(rwlock* lock); UNLOCKS NO_LOCK_ANALYSIS {
    pthread_rwlock_unlock(&lock.object);
}

pragma(inline, true) private void rwlock_destroy(rwlock* lock); UNLOCKS NO_LOCK_ANALYSIS {
    pthread_rwlock_destroy(&lock.object);
}

/* Condition variable that uses the lock annotations. */

LOCKABLE cond {
    pthread_cond_t object = void;
static if (!CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK \
    || !CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP) {
    clockid_t clock = void;
}
}{}

pragma(inline, true) private bool cond_init_monotonic(cond* cond) {
    bool ret = false;
static if (CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK) {
    pthread_condattr_t attr = void;

    if (pthread_condattr_init(&attr) != 0)
        return false;

    if (pthread_condattr_setclock(&attr, CLOCK_MONOTONIC) != 0)
        goto fail;

    if (pthread_cond_init(&cond.object, &attr) != 0)
        goto fail;

    ret = true;
fail:
    pthread_condattr_destroy(&attr);
} else {
    if (pthread_cond_init(&cond.object, null) != 0)
        return false;
    ret = true;
}

static if (!CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK \
    || !CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP) {
    cond.clock = CLOCK_MONOTONIC;
}
    return ret;
}

pragma(inline, true) private bool cond_init_realtime(cond* cond) {
    if (pthread_cond_init(&cond.object, null) != 0)
        return false;
static if (!CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK \
    || !CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP) {
    cond.clock = CLOCK_REALTIME;
}
    return true;
}

pragma(inline, true) private void cond_destroy(cond* cond) {
    pthread_cond_destroy(&cond.object);
}

pragma(inline, true) private void cond_signal(cond* cond) {
    pthread_cond_signal(&cond.object);
}

static if (!CONFIG_HAS_CLOCK_NANOSLEEP) {
pragma(inline, true) private bool cond_timedwait(cond* cond, mutex* lock, ulong timeout, bool abstime); REQUIRES_EXCLUSIVE NO_LOCK_ANALYSIS {
    int ret = void;
    timespec ts = {
        tv_sec: (time_t)(timeout / 1000000000),
        tv_nsec: cast(c_long)(timeout % 1000000000),
    };

    if (abstime) {
static if (!CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK) {
        /**
         * No native support for sleeping on monotonic clocks. Convert the
         * timeout to a relative value and then to an absolute value for the
         * realtime clock.
         */
        if (cond.clock != CLOCK_REALTIME) {
            timespec ts_monotonic = void;
            timespec ts_realtime = void;

            clock_gettime(cond.clock, &ts_monotonic);
            ts.tv_sec -= ts_monotonic.tv_sec;
            ts.tv_nsec -= ts_monotonic.tv_nsec;
            if (ts.tv_nsec < 0) {
                ts.tv_nsec += 1000000000;
                --ts.tv_sec;
            }

            clock_gettime(CLOCK_REALTIME, &ts_realtime);
            ts.tv_sec += ts_realtime.tv_sec;
            ts.tv_nsec += ts_realtime.tv_nsec;
            if (ts.tv_nsec >= 1000000000) {
                ts.tv_nsec -= 1000000000;
                ++ts.tv_sec;
            }
        }
}
    }
    else {
static if (CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP) {
        /* Implementation supports relative timeouts. */
        ret = pthread_cond_timedwait_relative_np(&cond.object, &lock.object,
                                                 &ts);
        bh_assert((ret == 0 || ret == ETIMEDOUT)
                  && "pthread_cond_timedwait_relative_np() failed");
        return ret == ETIMEDOUT;
} else {
        /* Convert to absolute timeout. */
        timespec ts_now = void;
static if (CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK) {
        clock_gettime(cond.clock, &ts_now);
} else {
        clock_gettime(CLOCK_REALTIME, &ts_now);
}
        ts.tv_sec += ts_now.tv_sec;
        ts.tv_nsec += ts_now.tv_nsec;
        if (ts.tv_nsec >= 1000000000) {
            ts.tv_nsec -= 1000000000;
            ++ts.tv_sec;
        }
}
    }

    ret = pthread_cond_timedwait(&cond.object, &lock.object, &ts);
    bh_assert((ret == 0 || ret == ETIMEDOUT)
              && "pthread_cond_timedwait() failed");
    return ret == ETIMEDOUT;
}
}

pragma(inline, true) private void cond_wait(cond* cond, mutex* lock);
    REQUIRES_EXCLUSIVE NO_LOCK_ANALYSIS {
    pthread_cond_wait(&cond.object, &lock.object);
}


