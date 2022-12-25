module riot_thread;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * Copyright (C) 2020 TU Bergakademie Freiberg Karl Fessel
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

public import panic;
public import sema;
public import ztimer;

/* clang-format off */
enum string bh_assert(string v) = ` do {                                   \
     if (!(v)) {                                            \
       printf("\nASSERTION FAILED: %s, at %s, line %d\n",   \
              #v, __FILE__, __LINE__);                      \
       core_panic(0, 0/*expr_string*/);                     \
       while (1);                                           \
     }                                                      \
} while (0)`;
/* clang-format on */

struct os_thread_data;
struct os_thread_wait_node {
    sema_t sem;
    void* ret;
    os_thread_wait_list next;
}

// all information for thread to cleanup it self
struct os_thread_data {
    /* Next thread data */
    os_thread_data* next;
    /* thread handle */
    kernel_pid_t tid;
    /* Thread start routine */
    thread_start_routine_t start_routine;
    /* Thread start routine argument */
    void* arg;
    /* thread local root */
    void* tlr;
    /* Lock for waiting list */
    mutex_t wait_list_lock;
    /* Waiting list of other threads who are joining this thread */
    os_thread_wait_list thread_wait_list;
    /* Thread stack size */
    uint stack_size;
    /* Thread stack */
    char[1] stack = 0;
}

struct os_thread_obj {
    korp_tid thread;
    /* Whether the thread is terminated and this thread object is to
     be freed in the future. */
    bool to_be_freed;
    os_thread_obj* next;
}

private bool is_thread_sys_inited = false;

/* Lock for thread data list */
private mutex_t thread_data_lock;

/* Thread data list */
private os_thread_data* thread_data_list = null;

private void thread_data_list_add(os_thread_data* thread_data) {
    mutex_lock(&thread_data_lock);
    if (!thread_data_list)
        thread_data_list = thread_data;
    else {
        /* If already in list, just return */
        os_thread_data* p = thread_data_list;
        while (p) {
            if (p == thread_data) {
                mutex_unlock(&thread_data_lock);
                return;
            }
            p = p.next;
        }

        /* Set as head of list */
        thread_data.next = thread_data_list;
        thread_data_list = thread_data;
    }
    mutex_unlock(&thread_data_lock);
}

private void thread_data_list_remove(os_thread_data* thread_data) {
    mutex_lock(&thread_data_lock);
    if (thread_data_list) {
        if (thread_data_list == thread_data)
            thread_data_list = thread_data_list.next;
        else {
            /* Search and remove it from list */
            os_thread_data* p = thread_data_list;
            while (p && p.next != thread_data)
                p = p.next;
            if (p && p.next == thread_data)
                p.next = p.next.next;
        }
    }
    mutex_unlock(&thread_data_lock);
}

private os_thread_data* thread_data_list_lookup(korp_tid tid) {
    mutex_lock(&thread_data_lock);
    if (thread_data_list) {
        os_thread_data* p = thread_data_list;
        while (p) {
            if (p.tid == tid) {
                /* Found */
                mutex_unlock(&thread_data_lock);
                return p;
            }
            p = p.next;
        }
    }
    mutex_unlock(&thread_data_lock);
    return null;
}

int os_thread_sys_init() {
    if (is_thread_sys_inited)
        return BHT_OK;

    mutex_init(&thread_data_lock);

    is_thread_sys_inited = true;
    return BHT_OK;
}

void os_thread_sys_destroy() {
    if (is_thread_sys_inited) {
        is_thread_sys_inited = false;
    }
}

private os_thread_data* thread_data_current() {
    kernel_pid_t tid = thread_getpid();
    return thread_data_list_lookup(tid);
}

private void os_thread_cleanup() {
    // TODO Check this (Join sema trigger, cleanup of thread_data)
    os_thread_data* thread_data = thread_data_current();
    bh_assert(thread_data != null);
    mutex_lock(&thread_data.wait_list_lock);
    if (thread_data.thread_wait_list) {
        /* Signal each joining thread */
        os_thread_wait_list head = thread_data.thread_wait_list;
        while (head) {
            os_thread_wait_list next = head.next;
            head.ret = thread_data.arg;
            sema_post(&head.sem);
            head = next;
        }
        thread_data.thread_wait_list = null;
    }
    mutex_unlock(&thread_data.wait_list_lock);

    thread_data_list_remove(thread_data);
}

private void* os_thread_wrapper(void* thread_data) {
    /* Set thread custom data */
    os_thread_data* t = cast(os_thread_data*)thread_data;
    t.tid = thread_getpid();
    thread_data_list_add(t);

    // save the return value to arg since it is not need after the call
    t.arg = (t.start_routine)(t.arg);

    os_thread_cleanup(); // internal structures and joiners

    BH_FREE(thread_data);
    sched_task_exit(); // stop thread //clean
    return null;       // never reached
}

int os_thread_create(korp_tid* p_tid, thread_start_routine_t start, void* arg, uint stack_size) {
    return os_thread_create_with_prio(p_tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

int os_thread_create_with_prio(korp_tid* p_tid, thread_start_routine_t start, void* arg, uint stack_size, int prio) {
    kernel_pid_t tid = void;
    os_thread_data* thread_data = void;
    uint thread_data_size = void;

    if (!p_tid || !stack_size)
        return BHT_ERROR;

    /* Create and initialize thread data */
    thread_data_size = os_thread_data.stack.offsetof + stack_size;
    if (((thread_data = BH_MALLOC(thread_data_size)) == 0)) {
        return BHT_ERROR;
    }

    memset(thread_data, 0, thread_data_size);
    mutex_init(&thread_data.wait_list_lock);
    thread_data.stack_size = stack_size;
    thread_data.start_routine = start;
    thread_data.arg = arg;

    /* Create the thread &*/
    if (!((tid = thread_create(thread_data.stack, stack_size, prio, 0,
                               &os_thread_wrapper, thread_data, "WASM")))) {
        BH_FREE(thread_data);
        return BHT_ERROR;
    }

    thread_data.tid = tid;

    /* Set thread custom data */
    thread_data_list_add(thread_data);
    *p_tid = tid;
    return BHT_OK;
}

korp_tid os_self_thread() {
    return cast(korp_tid)thread_getpid();
}

int os_thread_join(korp_tid thread, void** value_ptr) {
    // will test if thread is still working,
    // wait if it is
    os_thread_data* thread_data = void;
    os_thread_wait_node node = void;

    sema_create(&node.sem, 0);
    node.next = null;

    /* Get thread data */
    thread_data = thread_data_list_lookup(thread);
    if (thread_data == null) {
        // thread not found
        sema_destroy(&node.sem);
        return BHT_ERROR;
    }
    bh_assert(thread_data != null);

    mutex_lock(&thread_data.wait_list_lock);
    if (!thread_data.thread_wait_list)
        thread_data.thread_wait_list = &node;
    else {
        /* Add to end of waiting list */
        os_thread_wait_node* p = thread_data.thread_wait_list;
        while (p.next)
            p = p.next;
        p.next = &node;
    }
    mutex_unlock(&thread_data.wait_list_lock);

    sema_wait(&node.sem);
    // get the return value pointer conted may not be availible after return
    if (value_ptr)
        (*value_ptr) = node.ret;
    /* Wait some time for the thread to be actually terminated */
    //  TODO:   k_sleep(100);

    // TODO: bump target prio to make it finish and free its resources
    thread_yield();

    // node has done its job
    sema_destroy(&node.sem);

    return BHT_OK;
}

// int vm_mutex_trylock(korp_mutex *mutex)
// {
//     return mutex_trylock(mutex);
// }

int os_mutex_init(korp_mutex* mutex) {
    mutex_init(mutex);
    return BHT_OK;
}

int os_mutex_destroy(korp_mutex* mutex) {
    cast(void)mutex;
    return BHT_OK;
}

int os_mutex_lock(korp_mutex* mutex) {
    mutex_lock(mutex);
    return 0; // Riot mutexes do not return until success
}

int os_mutex_unlock(korp_mutex* mutex) {
    mutex_unlock(mutex);
    return 0; // Riot mutexes do not return until success
}

int os_cond_init(korp_cond* cond) {
    mutex_init(&cond.wait_list_lock);
    cond.thread_wait_list = null;
    return BHT_OK;
}

int os_cond_destroy(korp_cond* cond) {
    cast(void)cond;
    return BHT_OK;
}

private int os_cond_wait_internal(korp_cond* cond, korp_mutex* mutex, bool timed, ulong useconds) {
    os_thread_wait_node* node = void;

    /* Create wait node and append it to wait list */
    if (((node = BH_MALLOC(os_thread_wait_node.sizeof)) == 0))
        return BHT_ERROR;

    sema_create(&node.sem, 0);
    node.next = null;

    mutex_lock(&cond.wait_list_lock);
    if (!cond.thread_wait_list)
        cond.thread_wait_list = node;
    else {
        /* Add to end of wait list */
        os_thread_wait_node* p = cond.thread_wait_list;
        while (p.next)
            p = p.next;
        p.next = node;
    }
    mutex_unlock(&cond.wait_list_lock);

    /* Unlock mutex, wait sem and lock mutex again */
    mutex_unlock(mutex);
    if (timed)
        sema_wait(&node.sem);
    else
        sema_wait_timed_ztimer(&node.sem, ZTIMER_USEC, useconds);
    mutex_lock(mutex);

    /* Remove wait node from wait list */
    mutex_lock(&cond.wait_list_lock);
    if (cond.thread_wait_list == node)
        cond.thread_wait_list = node.next;
    else {
        /* Remove from the wait list */
        os_thread_wait_node* p = cond.thread_wait_list;
        while (p.next != node)
            p = p.next;
        p.next = node.next;
    }
    BH_FREE(node);
    mutex_unlock(&cond.wait_list_lock);

    return BHT_OK;
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
    return os_cond_wait_internal(cond, mutex, false, 0);
}

int os_cond_reltimedwait(korp_cond* cond, korp_mutex* mutex, ulong useconds) {
    return os_cond_wait_internal(cond, mutex, (useconds != BHT_WAIT_FOREVER),
                                 useconds);
}

int os_cond_signal(korp_cond* cond) {
    /* Signal the head wait node of wait list */
    mutex_lock(&cond.wait_list_lock);
    if (cond.thread_wait_list)
        sema_post(&cond.thread_wait_list.sem);
    mutex_unlock(&cond.wait_list_lock);

    return BHT_OK;
}

ubyte* os_thread_get_stack_boundary() {
static if (HasVersion!"DEVELHELP" || HasVersion!"SCHED_TEST_STACK" \
    || HasVersion!"MODULE_MPU_STACK_GUARD") {
    return cast(ubyte*)thread_get_active().stack_start;
} else {
    return null;
}
}
