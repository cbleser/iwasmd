module posix_thread;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 

public import platform_api_vmcore;
public import platform_api_extension;

struct _Thread_wrapper_arg {
    thread_start_routine_t start;
    void* arg;
version (OS_ENABLE_HW_BOUND_CHECK) {
    os_signal_handler signal_handler;
}
}alias thread_wrapper_arg = _Thread_wrapper_arg;

version (OS_ENABLE_HW_BOUND_CHECK) {
/* The signal handler passed to os_thread_signal_init() */
private os_thread_local_attribute os_signal_handler; signal_handler;
}

private void* os_thread_wrapper(void* arg) {
    thread_wrapper_arg* targ = arg;
    thread_start_routine_t start_func = targ.start;
    void* thread_arg = targ.arg;
version (OS_ENABLE_HW_BOUND_CHECK) {
    os_signal_handler handler = targ.signal_handler;
}

version (none) {
    os_printf("THREAD CREATED %jx\n", cast(uintmax_t)cast(uintptr_t)pthread_self());
}
    BH_FREE(targ);
version (OS_ENABLE_HW_BOUND_CHECK) {
    if (os_thread_signal_init(handler) != 0)
        return null;
}
    start_func(thread_arg);
version (OS_ENABLE_HW_BOUND_CHECK) {
    os_thread_signal_destroy();
}
    return null;
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
        os_printf("Invalid thread stack size %u. Min stack size on Linux = %u",
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
version (OS_ENABLE_HW_BOUND_CHECK) {
    targ.signal_handler = signal_handler;
}

    if (pthread_create(tid, &tattr, &os_thread_wrapper, targ) != 0) {
        pthread_attr_destroy(&tattr);
        BH_FREE(targ);
        return BHT_ERROR;
    }

    pthread_attr_destroy(&tattr);
    return BHT_OK;
}

int os_thread_create(korp_tid* tid, thread_start_routine_t start, void* arg, uint stack_size) {
    return os_thread_create_with_prio(tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

korp_tid os_self_thread() {
    return cast(korp_tid)pthread_self();
}

int os_mutex_init(korp_mutex* mutex) {
    return pthread_mutex_init(mutex, null) == 0 ? BHT_OK : BHT_ERROR;
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
    int ret = void;

    assert(mutex);
    ret = pthread_mutex_destroy(mutex);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int os_mutex_lock(korp_mutex* mutex) {
    int ret = void;

    assert(mutex);
    ret = pthread_mutex_lock(mutex);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int os_mutex_unlock(korp_mutex* mutex) {
    int ret = void;

    assert(mutex);
    ret = pthread_mutex_unlock(mutex);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int os_cond_init(korp_cond* cond) {
    assert(cond);

    if (pthread_cond_init(cond, null) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int os_cond_destroy(korp_cond* cond) {
    assert(cond);

    if (pthread_cond_destroy(cond) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
    assert(cond);
    assert(mutex);

    if (pthread_cond_wait(cond, mutex) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

korp_sem* os_sem_open(const(char)* name, int oflags, int mode, int val) {
    return sem_open(name, oflags, mode, val);
}

int os_sem_close(korp_sem* sem) {
    return sem_close(sem);
}

int os_sem_wait(korp_sem* sem) {
    return sem_wait(sem);
}

int os_sem_trywait(korp_sem* sem) {
    return sem_trywait(sem);
}

int os_sem_post(korp_sem* sem) {
    return sem_post(sem);
}

int os_sem_getvalue(korp_sem* sem, int* sval) {
version (OSX) {
    /*
     * macOS doesn't have working sem_getvalue.
     * It's marked as deprecated in the system header.
     * Mock it up here to avoid compile-time deprecation warnings.
     */
    errno = ENOSYS;
    return -1;
} else {
    return sem_getvalue(sem, sval);
}
}

int os_sem_unlink(const(char)* name) {
    return sem_unlink(name);
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
    assert(cond);

    if (pthread_cond_signal(cond) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int os_cond_broadcast(korp_cond* cond) {
    assert(cond);

    if (pthread_cond_broadcast(cond) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int os_thread_join(korp_tid thread, void** value_ptr) {
    return pthread_join(thread, value_ptr);
}

int os_thread_detach(korp_tid thread) {
    return pthread_detach(thread);
}

void os_thread_exit(void* retval) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    os_thread_signal_destroy();
}
    return pthread_exit(retval);
}

version (os_thread_local_attribute) {
private os_thread_local_attribute* thread_stack_boundary = null;
}

ubyte* os_thread_get_stack_boundary() {
    pthread_t self = void;
version (linux) {
    pthread_attr_t attr = void;
    size_t guard_size = void;
}
    ubyte* addr = null;
    size_t stack_size = void, max_stack_size = void;
    int page_size = void;

version (os_thread_local_attribute) {
    if (thread_stack_boundary)
        return thread_stack_boundary;
}

    page_size = getpagesize();
    self = pthread_self();
    max_stack_size =
        cast(size_t)(APP_THREAD_STACK_SIZE_MAX + page_size - 1) & ~(page_size - 1);

    if (max_stack_size < APP_THREAD_STACK_SIZE_DEFAULT)
        max_stack_size = APP_THREAD_STACK_SIZE_DEFAULT;

version (linux) {
    if (pthread_getattr_np(self, &attr) == 0) {
        pthread_attr_getstack(&attr, cast(void**)&addr, &stack_size);
        pthread_attr_getguardsize(&attr, &guard_size);
        pthread_attr_destroy(&attr);
        if (stack_size > max_stack_size)
            addr = addr + stack_size - max_stack_size;
        if (guard_size < cast(size_t)page_size)
            /* Reserved 1 guard page at least for safety */
            guard_size = cast(size_t)page_size;
        addr += guard_size;
    }
    cast(void)stack_size;
} else static if (HasVersion!"OSX" || HasVersion!"__NuttX__") {
    if ((addr = cast(ubyte*)pthread_get_stackaddr_np(self))) {
        stack_size = pthread_get_stacksize_np(self);

        /**
         * Check whether stack_addr is the base or end of the stack,
         * change it to the base if it is the end of stack.
         */
        if (addr <= cast(ubyte*)&stack_size)
            addr = addr + stack_size;

        if (stack_size > max_stack_size)
            stack_size = max_stack_size;

        addr -= stack_size;
        /* Reserved 1 guard page at least for safety */
        addr += page_size;
    }
}

version (os_thread_local_attribute) {
    thread_stack_boundary = addr;
}
    return addr;
}

version (OS_ENABLE_HW_BOUND_CHECK) {

enum SIG_ALT_STACK_SIZE = (32 * 1024);

/**
 * Whether thread signal enviornment is initialized:
 *   the signal handler is registered, the stack pages are touched,
 *   the stack guard pages are set and signal alternate stack are set.
 */
private os_thread_local_attribute thread_signal_inited = false;

static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
/* The signal alternate stack base addr */
private os_thread_local_attribute* sigalt_stack_base_addr;

version (__clang__) {
#pragma clang optimize off
} else version (__GNUC__) {
#pragma GCC push_options
#pragma GCC optimize("O0")
private uint touch_pages(ubyte* stack_min_addr, uint page_size) {
    ubyte sum = 0;
    while (1) {
        /*volatile*/ ubyte* touch_addr = cast(/*volatile*/ ubyte*)os_alloca(page_size / 2);
        if (touch_addr < stack_min_addr + page_size) {
            sum += *(stack_min_addr + page_size - 1);
            break;
        }
        *touch_addr = 0;
        sum += *touch_addr;
    }
    return sum;
}
version (__clang__) {
#pragma clang optimize on
} else version (__GNUC__) {
#pragma GCC pop_options
}

private bool init_stack_guard_pages() {
    uint page_size = os_getpagesize();
    uint guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    ubyte* stack_min_addr = os_thread_get_stack_boundary();

    if (stack_min_addr == null)
        return false;

    /* Touch each stack page to ensure that it has been mapped: the OS
       may lazily grow the stack mapping as a guard page is hit. */
    cast(void)touch_pages(stack_min_addr, page_size);
    /* First time to call aot function, protect guard pages */
    if (os_mprotect(stack_min_addr, page_size * guard_page_count,
                    MMAP_PROT_NONE)
        != 0) {
        return false;
    }
    return true;
}

private void destroy_stack_guard_pages() {
    uint page_size = os_getpagesize();
    uint guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    ubyte* stack_min_addr = os_thread_get_stack_boundary();

    os_mprotect(stack_min_addr, page_size * guard_page_count,
                MMAP_PROT_READ | MMAP_PROT_WRITE);
}
} /* end of WASM_DISABLE_STACK_HW_BOUND_CHECK == 0 */

private void mask_signals(int how) {
    sigset_t set = void;

    sigemptyset(&set);
    sigaddset(&set, SIGSEGV);
    sigaddset(&set, SIGBUS);
    pthread_sigmask(how, &set, null);
}

private os_thread_local_attribute struct; sigaction prev_sig_act_SIGSEGV;
private os_thread_local_attribute struct; sigaction prev_sig_act_SIGBUS;

private void signal_callback(int sig_num, siginfo_t* sig_info, void* sig_ucontext) {
    void* sig_addr = sig_info.si_addr;
    sigaction* prev_sig_act = null;

    mask_signals(SIG_BLOCK);

    /* Try to handle signal with the registered signal handler */
    if (signal_handler && (sig_num == SIGSEGV || sig_num == SIGBUS)) {
        signal_handler(sig_addr);
    }

    if (sig_num == SIGSEGV)
        prev_sig_act = &prev_sig_act_SIGSEGV;
    else if (sig_num == SIGBUS)
        prev_sig_act = &prev_sig_act_SIGBUS;

    /* Forward the signal to next handler if found */
    if (prev_sig_act && (prev_sig_act.sa_flags & SA_SIGINFO)) {
        prev_sig_act.sa_sigaction(sig_num, sig_info, sig_ucontext);
    }
    else if (prev_sig_act
             && (cast(void*)prev_sig_act.sa_sigaction == SIG_DFL
                 || cast(void*)prev_sig_act.sa_sigaction == SIG_IGN)) {
        sigaction(sig_num, prev_sig_act, null);
    }
    /* Output signal info and then crash if signal is unhandled */
    else {
        switch (sig_num) {
            case SIGSEGV:
                os_printf("unhandled SIGSEGV, si_addr: %p\n", sig_addr);
                break;
            case SIGBUS:
                os_printf("unhandled SIGBUS, si_addr: %p\n", sig_addr);
                break;
            default:
                os_printf("unhandle signal %d, si_addr: %p\n", sig_num,
                          sig_addr);
                break;
        }

        abort();
    }
}

int os_thread_signal_init(os_signal_handler handler) {
    sigaction sig_act = void;
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    stack_t sigalt_stack_info = void;
    uint map_size = SIG_ALT_STACK_SIZE;
    ubyte* map_addr = void;
}

    if (thread_signal_inited)
        return 0;

static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    if (!init_stack_guard_pages()) {
        os_printf("Failed to init stack guard pages\n");
        return -1;
    }

    /* Initialize memory for signal alternate stack of current thread */
    if (((map_addr = os_mmap(null, map_size, MMAP_PROT_READ | MMAP_PROT_WRITE,
                             MMAP_MAP_NONE)) == 0)) {
        os_printf("Failed to mmap memory for alternate stack\n");
        goto fail1;
    }

    /* Initialize signal alternate stack */
    memset(map_addr, 0, map_size);
    sigalt_stack_info.ss_sp = map_addr;
    sigalt_stack_info.ss_size = map_size;
    sigalt_stack_info.ss_flags = 0;
    if (sigaltstack(&sigalt_stack_info, null) != 0) {
        os_printf("Failed to init signal alternate stack\n");
        goto fail2;
    }
}

    memset(&prev_sig_act_SIGSEGV, 0, sigaction.sizeof);
    memset(&prev_sig_act_SIGBUS, 0, sigaction.sizeof);

    /* Install signal hanlder */
    sig_act.sa_sigaction = signal_callback;
    sig_act.sa_flags = SA_SIGINFO | SA_NODEFER;
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    sig_act.sa_flags |= SA_ONSTACK;
}
    sigemptyset(&sig_act.sa_mask);
    if (sigaction(SIGSEGV, &sig_act, &prev_sig_act_SIGSEGV) != 0
        || sigaction(SIGBUS, &sig_act, &prev_sig_act_SIGBUS) != 0) {
        os_printf("Failed to register signal handler\n");
        goto fail3;
    }

static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    sigalt_stack_base_addr = map_addr;
}
    signal_handler = handler;
    thread_signal_inited = true;
    return 0;

fail3:
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    memset(&sigalt_stack_info, 0, stack_t.sizeof);
    sigalt_stack_info.ss_flags = SS_DISABLE;
    sigalt_stack_info.ss_size = map_size;
    sigaltstack(&sigalt_stack_info, null);
fail2:
    os_munmap(map_addr, map_size);
fail1:
    destroy_stack_guard_pages();
}
    return -1;
}

void os_thread_signal_destroy() {
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    stack_t sigalt_stack_info = void;
}

    if (!thread_signal_inited)
        return;

static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    /* Disable signal alternate stack */
    memset(&sigalt_stack_info, 0, stack_t.sizeof);
    sigalt_stack_info.ss_flags = SS_DISABLE;
    sigalt_stack_info.ss_size = SIG_ALT_STACK_SIZE;
    sigaltstack(&sigalt_stack_info, null);

    os_munmap(sigalt_stack_base_addr, SIG_ALT_STACK_SIZE);

    destroy_stack_guard_pages();
}

    thread_signal_inited = false;
}

bool os_thread_signal_inited() {
    return thread_signal_inited;
}

void os_signal_unmask() {
    mask_signals(SIG_UNBLOCK);
}

void os_sigreturn() {
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
version (OSX) {
enum UC_RESET_ALT_STACK = 0x80000000;
    extern int __sigreturn(void*, int);

    /* It's necessary to call __sigreturn to restore the sigaltstack state
       after exiting the signal handler. */
    __sigreturn(null, UC_RESET_ALT_STACK);
}
}
}
} /* end of OS_ENABLE_HW_BOUND_CHECK */}
