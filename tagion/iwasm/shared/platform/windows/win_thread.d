module win_thread;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

enum string bh_assert(string v) = ` assert(v)`;

enum BH_SEM_COUNT_MAX = 0xFFFF;

struct os_thread_data;

struct os_thread_wait_node {
    korp_sem sem;
    void* retval;
    os_thread_wait_list next;
}

struct os_thread_data {
    /* Next thread data */
    os_thread_data* next;
    /* Thread data of parent thread */
    os_thread_data* parent;
    /* Thread Id */
    DWORD thread_id;
    /* Thread start routine */
    thread_start_routine_t start_routine;
    /* Thread start routine argument */
    void* arg;
    /* Wait node of current thread */
    os_thread_wait_node wait_node;
    /* Wait cond */
    korp_cond wait_cond;
    /* Wait lock */
    korp_mutex wait_lock;
    /* Waiting list of other threads who are joining this thread */
    os_thread_wait_list thread_wait_list;
    /* Whether the thread has exited */
    bool thread_exited;
    /* Thread return value */
    void* thread_retval;
}

private bool is_thread_sys_inited = false;

/* Thread data of supervisor thread */
private os_thread_data supervisor_thread_data;

/* Thread data list lock */
private korp_mutex thread_data_list_lock;

/* Thread data key */
private DWORD thread_data_key;

/* The GetCurrentThreadStackLimits API from "kernel32" */
private void (PULONG_PTR, PULONG_PTR);

int os_sem_init(korp_sem* sem);
int os_sem_destroy(korp_sem* sem);
int os_sem_wait(korp_sem* sem);
int os_sem_reltimed_wait(korp_sem* sem, ulong useconds);
int os_sem_signal(korp_sem* sem);

int os_thread_sys_init() {
    HMODULE module_ = void;

    if (is_thread_sys_inited)
        return BHT_OK;

    if ((thread_data_key = TlsAlloc()) == TLS_OUT_OF_INDEXES)
        return BHT_ERROR;

    /* Initialize supervisor thread data */
    memset(&supervisor_thread_data, 0, os_thread_data.sizeof);

    supervisor_thread_data.thread_id = GetCurrentThreadId();

    if (os_sem_init(&supervisor_thread_data.wait_node.sem) != BHT_OK)
        goto fail1;

    if (os_mutex_init(&supervisor_thread_data.wait_lock) != BHT_OK)
        goto fail2;

    if (os_cond_init(&supervisor_thread_data.wait_cond) != BHT_OK)
        goto fail3;

    if (!TlsSetValue(thread_data_key, &supervisor_thread_data))
        goto fail4;

    if (os_mutex_init(&thread_data_list_lock) != BHT_OK)
        goto fail5;

    if ((module_ = GetModuleHandle(cast(LPCTSTR) "kernel32"))) {
        *cast(void**)&GetCurrentThreadStackLimits_Kernel32 =
            GetProcAddress(module_, "GetCurrentThreadStackLimits");
    }

    is_thread_sys_inited = true;
    return BHT_OK;

fail5:
    TlsSetValue(thread_data_key, null);
fail4:
    os_cond_destroy(&supervisor_thread_data.wait_cond);
fail3:
    os_mutex_destroy(&supervisor_thread_data.wait_lock);
fail2:
    os_sem_destroy(&supervisor_thread_data.wait_node.sem);
fail1:
    TlsFree(thread_data_key);
    return BHT_ERROR;
}

void os_thread_sys_destroy() {
    if (is_thread_sys_inited) {
        os_thread_data* thread_data = void, thread_data_next = void;

        thread_data = supervisor_thread_data.next;
        while (thread_data) {
            thread_data_next = thread_data.next;

            /* Destroy resources of thread data */
            os_cond_destroy(&thread_data.wait_cond);
            os_sem_destroy(&thread_data.wait_node.sem);
            os_mutex_destroy(&thread_data.wait_lock);
            BH_FREE(thread_data);

            thread_data = thread_data_next;
        }

        os_mutex_destroy(&thread_data_list_lock);
        os_cond_destroy(&supervisor_thread_data.wait_cond);
        os_mutex_destroy(&supervisor_thread_data.wait_lock);
        os_sem_destroy(&supervisor_thread_data.wait_node.sem);
        memset(&supervisor_thread_data, 0, os_thread_data.sizeof);
        TlsFree(thread_data_key);
        thread_data_key = 0;
        is_thread_sys_inited = false;
    }
}

private os_thread_data* thread_data_current() {
    return cast(os_thread_data*)TlsGetValue(thread_data_key);
}

private void os_thread_cleanup(void* retval) {
    os_thread_data* thread_data = thread_data_current();

    bh_assert(thread_data != null);

    os_mutex_lock(&thread_data.wait_lock);
    if (thread_data.thread_wait_list) {
        /* Signal each joining thread */
        os_thread_wait_list head = thread_data.thread_wait_list;
        while (head) {
            os_thread_wait_list next = head.next;
            head.retval = retval;
            os_sem_signal(&head.sem);
            head = next;
        }
        thread_data.thread_wait_list = null;
    }
    /* Set thread status and thread return value */
    thread_data.thread_exited = true;
    thread_data.thread_retval = retval;
    os_mutex_unlock(&thread_data.wait_lock);
}

private uint os_thread_wrapper(void* arg) {
    os_thread_data* thread_data = arg;
    os_thread_data* parent = thread_data.parent;
    void* retval = void;
    bool result = void;

version (none) {
    os_printf("THREAD CREATED %p\n", thread_data);
}

    os_mutex_lock(&parent.wait_lock);
    thread_data.thread_id = GetCurrentThreadId();
    result = TlsSetValue(thread_data_key, thread_data);
version (OS_ENABLE_HW_BOUND_CHECK) {
    if (result)
        result = os_thread_signal_init() == 0 ? true : false;
}
    /* Notify parent thread */
    os_cond_signal(&parent.wait_cond);
    os_mutex_unlock(&parent.wait_lock);

    if (!result)
        return -1;

    retval = thread_data.start_routine(thread_data.arg);

    os_thread_cleanup(retval);
    return 0;
}

int os_thread_create_with_prio(korp_tid* p_tid, thread_start_routine_t start, void* arg, uint stack_size, int prio) {
    os_thread_data* parent = thread_data_current();
    os_thread_data* thread_data = void;

    if (!p_tid || !start)
        return BHT_ERROR;

    if (stack_size < BH_APPLET_PRESERVED_STACK_SIZE)
        stack_size = BH_APPLET_PRESERVED_STACK_SIZE;

    if (((thread_data = BH_MALLOC(os_thread_data.sizeof)) == 0))
        return BHT_ERROR;

    memset(thread_data, 0, os_thread_data.sizeof);
    thread_data.parent = parent;
    thread_data.start_routine = start;
    thread_data.arg = arg;

    if (os_sem_init(&thread_data.wait_node.sem) != BHT_OK)
        goto fail1;

    if (os_mutex_init(&thread_data.wait_lock) != BHT_OK)
        goto fail2;

    if (os_cond_init(&thread_data.wait_cond) != BHT_OK)
        goto fail3;

    os_mutex_lock(&parent.wait_lock);
    if (!_beginthreadex(null, stack_size, &os_thread_wrapper, thread_data, 0,
                        null)) {
        os_mutex_unlock(&parent.wait_lock);
        goto fail4;
    }

    /* Add thread data into thread data list */
    os_mutex_lock(&thread_data_list_lock);
    thread_data.next = supervisor_thread_data.next;
    supervisor_thread_data.next = thread_data;
    os_mutex_unlock(&thread_data_list_lock);

    /* Wait for the thread routine to set thread_data's tid
       and add thread_data to thread data list */
    os_cond_wait(&parent.wait_cond, &parent.wait_lock);
    os_mutex_unlock(&parent.wait_lock);

    *p_tid = cast(korp_tid)thread_data;
    return BHT_OK;

fail4:
    os_cond_destroy(&thread_data.wait_cond);
fail3:
    os_mutex_destroy(&thread_data.wait_lock);
fail2:
    os_sem_destroy(&thread_data.wait_node.sem);
fail1:
    BH_FREE(thread_data);
    return BHT_ERROR;
}

int os_thread_create(korp_tid* tid, thread_start_routine_t start, void* arg, uint stack_size) {
    return os_thread_create_with_prio(tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

korp_tid os_self_thread() {
    return cast(korp_tid)TlsGetValue(thread_data_key);
}

int os_thread_join(korp_tid thread, void** p_retval) {
    os_thread_data* thread_data = void, curr_thread_data = void;

    /* Get thread data of current thread */
    curr_thread_data = thread_data_current();
    curr_thread_data.wait_node.next = null;

    /* Get thread data of thread to join */
    thread_data = cast(os_thread_data*)thread;
    bh_assert(thread_data);

    os_mutex_lock(&thread_data.wait_lock);

    if (thread_data.thread_exited) {
        /* Thread has exited */
        if (p_retval)
            *p_retval = thread_data.thread_retval;
        os_mutex_unlock(&thread_data.wait_lock);
        return BHT_OK;
    }

    /* Thread is running */
    if (!thread_data.thread_wait_list)
        thread_data.thread_wait_list = &curr_thread_data.wait_node;
    else {
        /* Add to end of waiting list */
        os_thread_wait_node* p = thread_data.thread_wait_list;
        while (p.next)
            p = p.next;
        p.next = &curr_thread_data.wait_node;
    }

    os_mutex_unlock(&thread_data.wait_lock);

    /* Wait the sem */
    os_sem_wait(&curr_thread_data.wait_node.sem);
    if (p_retval)
        *p_retval = curr_thread_data.wait_node.retval;
    return BHT_OK;
}

int os_thread_detach(korp_tid thread) {
    /* Do nothing */
    return BHT_OK;
    cast(void)thread;
}

void os_thread_exit(void* retval) {
    os_thread_cleanup(retval);
    _endthreadex(0);
}

int os_thread_env_init() {
    os_thread_data* thread_data = TlsGetValue(thread_data_key);

    if (thread_data)
        /* Already created */
        return BHT_OK;

    if (((thread_data = BH_MALLOC(os_thread_data.sizeof)) == 0))
        return BHT_ERROR;

    memset(thread_data, 0, os_thread_data.sizeof);
    thread_data.thread_id = GetCurrentThreadId();

    if (os_sem_init(&thread_data.wait_node.sem) != BHT_OK)
        goto fail1;

    if (os_mutex_init(&thread_data.wait_lock) != BHT_OK)
        goto fail2;

    if (os_cond_init(&thread_data.wait_cond) != BHT_OK)
        goto fail3;

    if (!TlsSetValue(thread_data_key, thread_data))
        goto fail4;

    return BHT_OK;

fail4:
    os_cond_destroy(&thread_data.wait_cond);
fail3:
    os_mutex_destroy(&thread_data.wait_lock);
fail2:
    os_sem_destroy(&thread_data.wait_node.sem);
fail1:
    BH_FREE(thread_data);
    return BHT_ERROR;
}

void os_thread_env_destroy() {
    os_thread_data* thread_data = TlsGetValue(thread_data_key);

    /* Note that supervisor_thread_data's resources will be destroyed
       by os_thread_sys_destroy() */
    if (thread_data && thread_data != &supervisor_thread_data) {
        TlsSetValue(thread_data_key, null);
        os_cond_destroy(&thread_data.wait_cond);
        os_mutex_destroy(&thread_data.wait_lock);
        os_sem_destroy(&thread_data.wait_node.sem);
        BH_FREE(thread_data);
    }
}

bool os_thread_env_inited() {
    os_thread_data* thread_data = TlsGetValue(thread_data_key);
    return thread_data ? true : false;
}

int os_sem_init(korp_sem* sem) {
    bh_assert(sem);
    *sem = CreateSemaphore(null, 0, BH_SEM_COUNT_MAX, null);
    return (*sem != null) ? BHT_OK : BHT_ERROR;
}

int os_sem_destroy(korp_sem* sem) {
    bh_assert(sem);
    CloseHandle(*sem);
    return BHT_OK;
}

int os_sem_wait(korp_sem* sem) {
    DWORD ret = void;

    bh_assert(sem);

    ret = WaitForSingleObject(*sem, INFINITE);

    if (ret == WAIT_OBJECT_0)
        return BHT_OK;
    else if (ret == WAIT_TIMEOUT)
        return cast(int)WAIT_TIMEOUT;
    else /* WAIT_FAILED or others */
        return BHT_ERROR;
}

int os_sem_reltimed_wait(korp_sem* sem, ulong useconds) {
    ulong mseconds_64 = void;
    DWORD ret = void, mseconds = void;

    bh_assert(sem);

    if (useconds == BHT_WAIT_FOREVER)
        mseconds = INFINITE;
    else {
        mseconds_64 = useconds / 1000;

        if (mseconds_64 < (uint64)(UINT32_MAX - 1)) {
            mseconds = cast(uint)mseconds_64;
        }
        else {
            mseconds = UINT32_MAX - 1;
            os_printf("Warning: os_sem_reltimed_wait exceeds limit, "
                      ~ "set to max timeout instead\n");
        }
    }

    ret = WaitForSingleObject(*sem, mseconds);

    if (ret == WAIT_OBJECT_0)
        return BHT_OK;
    else if (ret == WAIT_TIMEOUT)
        return cast(int)WAIT_TIMEOUT;
    else /* WAIT_FAILED or others */
        return BHT_ERROR;
}

int os_sem_signal(korp_sem* sem) {
    bh_assert(sem);
    return ReleaseSemaphore(*sem, 1, null) != FALSE ? BHT_OK : BHT_ERROR;
}

int os_mutex_init(korp_mutex* mutex) {
    bh_assert(mutex);
    *mutex = CreateMutex(null, FALSE, null);
    return (*mutex != null) ? BHT_OK : BHT_ERROR;
}

int os_recursive_mutex_init(korp_mutex* mutex) {
    bh_assert(mutex);
    *mutex = CreateMutex(null, FALSE, null);
    return (*mutex != null) ? BHT_OK : BHT_ERROR;
}

int os_mutex_destroy(korp_mutex* mutex) {
    assert(mutex);
    return CloseHandle(*mutex) ? BHT_OK : BHT_ERROR;
}

int os_mutex_lock(korp_mutex* mutex) {
    int ret = void;

    assert(mutex);

    if (*mutex == null) { /* static initializer? */
        HANDLE p = CreateMutex(null, FALSE, null);

        if (!p) {
            return BHT_ERROR;
        }

        if (InterlockedCompareExchangePointer(cast(PVOID*)mutex, cast(PVOID)p, null)
            != null) {
            /* lock has been created by other threads */
            CloseHandle(p);
        }
    }

    ret = WaitForSingleObject(*mutex, INFINITE);
    return ret != WAIT_FAILED ? BHT_OK : BHT_ERROR;
}

int os_mutex_unlock(korp_mutex* mutex) {
    bh_assert(mutex);
    return ReleaseMutex(*mutex) ? BHT_OK : BHT_ERROR;
}

int os_cond_init(korp_cond* cond) {
    bh_assert(cond);
    if (os_mutex_init(&cond.wait_list_lock) != BHT_OK)
        return BHT_ERROR;

    cond.thread_wait_list = null;
    return BHT_OK;
}

int os_cond_destroy(korp_cond* cond) {
    bh_assert(cond);
    os_mutex_destroy(&cond.wait_list_lock);
    return BHT_OK;
}

private int os_cond_wait_internal(korp_cond* cond, korp_mutex* mutex, bool timed, ulong useconds) {
    os_thread_wait_node* node = &thread_data_current().wait_node;

    node.next = null;

    bh_assert(cond);
    bh_assert(mutex);
    os_mutex_lock(&cond.wait_list_lock);
    if (!cond.thread_wait_list)
        cond.thread_wait_list = node;
    else {
        /* Add to end of wait list */
        os_thread_wait_node* p = cond.thread_wait_list;
        while (p.next)
            p = p.next;
        p.next = node;
    }
    os_mutex_unlock(&cond.wait_list_lock);

    /* Unlock mutex, wait sem and lock mutex again */
    os_mutex_unlock(mutex);
    int wait_result = void;
    if (timed)
        wait_result = os_sem_reltimed_wait(&node.sem, useconds);
    else
        wait_result = os_sem_wait(&node.sem);
    os_mutex_lock(mutex);

    /* Remove wait node from wait list */
    os_mutex_lock(&cond.wait_list_lock);
    if (cond.thread_wait_list == node)
        cond.thread_wait_list = node.next;
    else {
        /* Remove from the wait list */
        os_thread_wait_node* p = cond.thread_wait_list;
        while (p.next != node)
            p = p.next;
        p.next = node.next;
    }
    os_mutex_unlock(&cond.wait_list_lock);

    return wait_result;
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
    return os_cond_wait_internal(cond, mutex, false, 0);
}

int os_cond_reltimedwait(korp_cond* cond, korp_mutex* mutex, ulong useconds) {
    if (useconds == BHT_WAIT_FOREVER) {
        return os_cond_wait_internal(cond, mutex, false, 0);
    }
    else {
        return os_cond_wait_internal(cond, mutex, true, useconds);
    }
}

int os_cond_signal(korp_cond* cond) {
    /* Signal the head wait node of wait list */
    os_mutex_lock(&cond.wait_list_lock);
    if (cond.thread_wait_list)
        os_sem_signal(&cond.thread_wait_list.sem);
    os_mutex_unlock(&cond.wait_list_lock);

    return BHT_OK;
}

int os_cond_broadcast(korp_cond* cond) {
    /* Signal all of the wait node of wait list */
    os_mutex_lock(&cond.wait_list_lock);
    if (cond.thread_wait_list) {
        os_thread_wait_node* p = cond.thread_wait_list;
        while (p) {
            os_sem_signal(&p.sem);
            p = p.next;
        }
    }

    os_mutex_unlock(&cond.wait_list_lock);

    return BHT_OK;
}

private os_thread_local_attribute* thread_stack_boundary = null;

private ULONG GetCurrentThreadStackLimits_Win7(PULONG_PTR p_low_limit, PULONG_PTR p_high_limit) {
    MEMORY_BASIC_INFORMATION mbi = void;
    NT_TIB* tib = cast(NT_TIB*)NtCurrentTeb();

    if (!tib) {
        os_printf("warning: NtCurrentTeb() failed\n");
        return -1;
    }

    *p_high_limit = cast(ULONG_PTR)tib.StackBase;

    if (VirtualQuery(tib.StackLimit, &mbi, mbi.sizeof)) {
        *p_low_limit = cast(ULONG_PTR)mbi.AllocationBase;
        return 0;
    }

    os_printf("warning: VirtualQuery() failed\n");
    return GetLastError();
}

ubyte* os_thread_get_stack_boundary() {
    ULONG_PTR low_limit = 0, high_limit = 0;
    uint page_size = void;

    if (thread_stack_boundary)
        return thread_stack_boundary;

    page_size = os_getpagesize();
    if (GetCurrentThreadStackLimits_Kernel32) {
        GetCurrentThreadStackLimits_Kernel32(&low_limit, &high_limit);
    }
    else {
        if (0 != GetCurrentThreadStackLimits_Win7(&low_limit, &high_limit))
            return null;
    }

    /* 4 pages are set unaccessible by system, we reserved
       one more page at least for safety */
    thread_stack_boundary = cast(ubyte*)cast(uintptr_t)low_limit + page_size * 5;
    return thread_stack_boundary;
}

version (OS_ENABLE_HW_BOUND_CHECK) {
private os_thread_local_attribute thread_signal_inited = false;

int os_thread_signal_init() {
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    ULONG StackSizeInBytes = 16 * 1024;
}
    bool ret = void;

    if (thread_signal_inited)
        return 0;

static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    ret = SetThreadStackGuarantee(&StackSizeInBytes);
} else {
    ret = true;
}
    if (ret)
        thread_signal_inited = true;
    return ret ? 0 : -1;
}

void os_thread_signal_destroy() {
    /* Do nothing */
}

bool os_thread_signal_inited() {
    return thread_signal_inited;
}
}
