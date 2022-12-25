module zephyr_thread;
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

/* clang-format off */
enum string bh_assert(string v) = ` do {                                   \
    if (!(v)) {                                             \
        printf("\nASSERTION FAILED: %s, at %s, line %d\n",  \
               #v, __FILE__, __LINE__);                     \
        abort();                                            \
    }                                                       \
} while (0)`;
/* clang-format on */

static if (HasVersion!"CONFIG_ARM_MPU" || HasVersion!"CONFIG_ARC_MPU" \
    || KERNEL_VERSION_NUMBER > 0x020300) { /* version 2.3.0 */
enum BH_ENABLE_ZEPHYR_MPU_STACK = 1;
} else static if (!HasVersion!"BH_ENABLE_ZEPHYR_MPU_STACK") {
enum BH_ENABLE_ZEPHYR_MPU_STACK = 0;
}
static if (!HasVersion!"BH_ZEPHYR_MPU_STACK_SIZE") {
enum BH_ZEPHYR_MPU_STACK_SIZE = APP_THREAD_STACK_SIZE_MIN;
}
static if (!HasVersion!"BH_ZEPHYR_MPU_STACK_COUNT") {
enum BH_ZEPHYR_MPU_STACK_COUNT = 4;
}

static if (BH_ENABLE_ZEPHYR_MPU_STACK != 0) {
private ;
private bool[BH_ZEPHYR_MPU_STACK_COUNT] mpu_stack_allocated;
private k_mutex mpu_stack_lock;

private char* mpu_stack_alloc() {
    int i = void;

    k_mutex_lock(&mpu_stack_lock, K_FOREVER);
    for (i = 0; i < BH_ZEPHYR_MPU_STACK_COUNT; i++) {
        if (!mpu_stack_allocated[i]) {
            mpu_stack_allocated[i] = true;
            k_mutex_unlock(&mpu_stack_lock);
            return cast(char*)mpu_stacks[i];
        }
    }
    k_mutex_unlock(&mpu_stack_lock);
    return null;
}

private void mpu_stack_free(char* stack) {
    int i = void;

    k_mutex_lock(&mpu_stack_lock, K_FOREVER);
    for (i = 0; i < BH_ZEPHYR_MPU_STACK_COUNT; i++) {
        if (cast(char*)mpu_stacks[i] == stack)
            mpu_stack_allocated[i] = false;
    }
    k_mutex_unlock(&mpu_stack_lock);
}
}

struct os_thread_wait_node {
    k_sem sem;
    os_thread_wait_list next;
}

struct os_thread_data {
    /* Next thread data */
    os_thread_data* next;
    /* Zephyr thread handle */
    korp_tid tid;
    /* Jeff thread local root */
    void* tlr;
    /* Lock for waiting list */
    k_mutex wait_list_lock;
    /* Waiting list of other threads who are joining this thread */
    os_thread_wait_list thread_wait_list;
    /* Thread stack size */
    uint stack_size;
static if (BH_ENABLE_ZEPHYR_MPU_STACK == 0) {
    /* Thread stack */
    char[1] stack = 0;
} else {
    char* stack;
}
}

struct os_thread_obj {
    k_thread thread;
    /* Whether the thread is terminated and this thread object is to
     be freed in the future. */
    bool to_be_freed;
    os_thread_obj* next;
}

private bool is_thread_sys_inited = false;

/* Thread data of supervisor thread */
private os_thread_data supervisor_thread_data;

/* Lock for thread data list */
private k_mutex thread_data_lock;

/* Thread data list */
private os_thread_data* thread_data_list = null;

/* Lock for thread object list */
private k_mutex thread_obj_lock;

/* Thread object list */
private os_thread_obj* thread_obj_list = null;

private void thread_data_list_add(os_thread_data* thread_data) {
    k_mutex_lock(&thread_data_lock, K_FOREVER);
    if (!thread_data_list)
        thread_data_list = thread_data;
    else {
        /* If already in list, just return */
        os_thread_data* p = thread_data_list;
        while (p) {
            if (p == thread_data) {
                k_mutex_unlock(&thread_data_lock);
                return;
            }
            p = p.next;
        }

        /* Set as head of list */
        thread_data.next = thread_data_list;
        thread_data_list = thread_data;
    }
    k_mutex_unlock(&thread_data_lock);
}

private void thread_data_list_remove(os_thread_data* thread_data) {
    k_mutex_lock(&thread_data_lock, K_FOREVER);
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
    k_mutex_unlock(&thread_data_lock);
}

private os_thread_data* thread_data_list_lookup(k_tid_t tid) {
    k_mutex_lock(&thread_data_lock, K_FOREVER);
    if (thread_data_list) {
        os_thread_data* p = thread_data_list;
        while (p) {
            if (p.tid == tid) {
                /* Found */
                k_mutex_unlock(&thread_data_lock);
                return p;
            }
            p = p.next;
        }
    }
    k_mutex_unlock(&thread_data_lock);
    return null;
}

private void thread_obj_list_add(os_thread_obj* thread_obj) {
    k_mutex_lock(&thread_obj_lock, K_FOREVER);
    if (!thread_obj_list)
        thread_obj_list = thread_obj;
    else {
        /* Set as head of list */
        thread_obj.next = thread_obj_list;
        thread_obj_list = thread_obj;
    }
    k_mutex_unlock(&thread_obj_lock);
}

private void thread_obj_list_reclaim() {
    os_thread_obj* p = void, p_prev = void;
    k_mutex_lock(&thread_obj_lock, K_FOREVER);
    p_prev = null;
    p = thread_obj_list;
    while (p) {
        if (p.to_be_freed) {
            if (p_prev == null) { /* p is the head of list */
                thread_obj_list = p.next;
                BH_FREE(p);
                p = thread_obj_list;
            }
            else { /* p is not the head of list */
                p_prev.next = p.next;
                BH_FREE(p);
                p = p_prev.next;
            }
        }
        else {
            p_prev = p;
            p = p.next;
        }
    }
    k_mutex_unlock(&thread_obj_lock);
}

int os_thread_sys_init() {
    if (is_thread_sys_inited)
        return BHT_OK;

static if (BH_ENABLE_ZEPHYR_MPU_STACK != 0) {
    k_mutex_init(&mpu_stack_lock);
}
    k_mutex_init(&thread_data_lock);
    k_mutex_init(&thread_obj_lock);

    /* Initialize supervisor thread data */
    memset(&supervisor_thread_data, 0, supervisor_thread_data.sizeof);
    supervisor_thread_data.tid = k_current_get();
    /* Set as head of thread data list */
    thread_data_list = &supervisor_thread_data;

    is_thread_sys_inited = true;
    return BHT_OK;
}

void os_thread_sys_destroy() {
    if (is_thread_sys_inited) {
        is_thread_sys_inited = false;
    }
}

private os_thread_data* thread_data_current() {
    k_tid_t tid = k_current_get();
    return thread_data_list_lookup(tid);
}

private void os_thread_cleanup() {
    os_thread_data* thread_data = thread_data_current();

    bh_assert(thread_data != null);
    k_mutex_lock(&thread_data.wait_list_lock, K_FOREVER);
    if (thread_data.thread_wait_list) {
        /* Signal each joining thread */
        os_thread_wait_list head = thread_data.thread_wait_list;
        while (head) {
            os_thread_wait_list next = head.next;
            k_sem_give(&head.sem);
            /* head will be freed by joining thread */
            head = next;
        }
        thread_data.thread_wait_list = null;
    }
    k_mutex_unlock(&thread_data.wait_list_lock);

    thread_data_list_remove(thread_data);
    /* Set flag to true for the next thread creating to
     free the thread object */
    (cast(os_thread_obj*)thread_data.tid).to_be_freed = true;
static if (BH_ENABLE_ZEPHYR_MPU_STACK != 0) {
    mpu_stack_free(thread_data.stack);
}
    BH_FREE(thread_data);
}

private void os_thread_wrapper(void* start, void* arg, void* thread_data) {
    /* Set thread custom data */
    (cast(os_thread_data*)thread_data).tid = k_current_get();
    thread_data_list_add(thread_data);

    (cast(thread_start_routine_t)start)(arg);
    os_thread_cleanup();
}

int os_thread_create(korp_tid* p_tid, thread_start_routine_t start, void* arg, uint stack_size) {
    return os_thread_create_with_prio(p_tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

int os_thread_create_with_prio(korp_tid* p_tid, thread_start_routine_t start, void* arg, uint stack_size, int prio) {
    korp_tid tid = void;
    os_thread_data* thread_data = void;
    uint thread_data_size = void;

    if (!p_tid || !stack_size)
        return BHT_ERROR;

    /* Free the thread objects of terminated threads */
    thread_obj_list_reclaim();

    /* Create and initialize thread object */
    if (((tid = BH_MALLOC(os_thread_obj.sizeof)) == 0))
        return BHT_ERROR;

    memset(tid, 0, os_thread_obj.sizeof);

    /* Create and initialize thread data */
static if (BH_ENABLE_ZEPHYR_MPU_STACK == 0) {
    if (stack_size < APP_THREAD_STACK_SIZE_MIN)
        stack_size = APP_THREAD_STACK_SIZE_MIN;
    thread_data_size = os_thread_data.stack.offsetof + stack_size;
} else {
    stack_size = BH_ZEPHYR_MPU_STACK_SIZE;
    thread_data_size = os_thread_data.sizeof;
}
    if (((thread_data = BH_MALLOC(thread_data_size)) == 0)) {
        goto fail1;
    }

    memset(thread_data, 0, thread_data_size);
    k_mutex_init(&thread_data.wait_list_lock);
    thread_data.stack_size = stack_size;
    thread_data.tid = tid;

static if (BH_ENABLE_ZEPHYR_MPU_STACK != 0) {
    if (((thread_data.stack = mpu_stack_alloc()) == 0)) {
        goto fail2;
    }
}

    /* Create the thread */
    if (!((tid = k_thread_create(tid, cast(k_thread_stack_t*)thread_data.stack,
                                 stack_size, &os_thread_wrapper, start, arg,
                                 thread_data, prio, 0, K_NO_WAIT)))) {
        goto fail3;
    }

    bh_assert(tid == thread_data.tid);

    /* Set thread custom data */
    thread_data_list_add(thread_data);
    thread_obj_list_add(cast(os_thread_obj*)tid);
    *p_tid = tid;
    return BHT_OK;

fail3:
static if (BH_ENABLE_ZEPHYR_MPU_STACK != 0) {
    mpu_stack_free(thread_data.stack);
fail2:
}
    BH_FREE(thread_data);
fail1:
    BH_FREE(tid);
    return BHT_ERROR;
}

korp_tid os_self_thread() {
    return cast(korp_tid)k_current_get();
}

int os_thread_join(korp_tid thread, void** value_ptr) {
    cast(void)value_ptr;
    os_thread_data* thread_data = void;
    os_thread_wait_node* node = void;

    /* Create wait node and append it to wait list */
    if (((node = BH_MALLOC(os_thread_wait_node.sizeof)) == 0))
        return BHT_ERROR;

    k_sem_init(&node.sem, 0, 1);
    node.next = null;

    /* Get thread data */
    thread_data = thread_data_list_lookup(thread);
    bh_assert(thread_data != null);

    k_mutex_lock(&thread_data.wait_list_lock, K_FOREVER);
    if (!thread_data.thread_wait_list)
        thread_data.thread_wait_list = node;
    else {
        /* Add to end of waiting list */
        os_thread_wait_node* p = thread_data.thread_wait_list;
        while (p.next)
            p = p.next;
        p.next = node;
    }
    k_mutex_unlock(&thread_data.wait_list_lock);

    /* Wait the sem */
    k_sem_take(&node.sem, K_FOREVER);

    /* Wait some time for the thread to be actually terminated */
    k_sleep(Z_TIMEOUT_MS(100));

    /* Destroy resource */
    BH_FREE(node);
    return BHT_OK;
}

int os_mutex_init(korp_mutex* mutex) {
    k_mutex_init(mutex);
    return BHT_OK;
}

int os_recursive_mutex_init(korp_mutex* mutex) {
    k_mutex_init(mutex);
    return BHT_OK;
}

int os_mutex_destroy(korp_mutex* mutex) {
    cast(void)mutex;
    return BHT_OK;
}

int os_mutex_lock(korp_mutex* mutex) {
    return k_mutex_lock(mutex, K_FOREVER);
}

int os_mutex_unlock(korp_mutex* mutex) {
static if (KERNEL_VERSION_NUMBER >= 0x020200) { /* version 2.2.0 */
    return k_mutex_unlock(mutex);
} else {
    k_mutex_unlock(mutex);
    return 0;
}
}

int os_cond_init(korp_cond* cond) {
    k_mutex_init(&cond.wait_list_lock);
    cond.thread_wait_list = null;
    return BHT_OK;
}

int os_cond_destroy(korp_cond* cond) {
    cast(void)cond;
    return BHT_OK;
}

private int os_cond_wait_internal(korp_cond* cond, korp_mutex* mutex, bool timed, int mills) {
    os_thread_wait_node* node = void;

    /* Create wait node and append it to wait list */
    if (((node = BH_MALLOC(os_thread_wait_node.sizeof)) == 0))
        return BHT_ERROR;

    k_sem_init(&node.sem, 0, 1);
    node.next = null;

    k_mutex_lock(&cond.wait_list_lock, K_FOREVER);
    if (!cond.thread_wait_list)
        cond.thread_wait_list = node;
    else {
        /* Add to end of wait list */
        os_thread_wait_node* p = cond.thread_wait_list;
        while (p.next)
            p = p.next;
        p.next = node;
    }
    k_mutex_unlock(&cond.wait_list_lock);

    /* Unlock mutex, wait sem and lock mutex again */
    k_mutex_unlock(mutex);
    k_sem_take(&node.sem, timed ? Z_TIMEOUT_MS(mills) : K_FOREVER);
    k_mutex_lock(mutex, K_FOREVER);

    /* Remove wait node from wait list */
    k_mutex_lock(&cond.wait_list_lock, K_FOREVER);
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
    k_mutex_unlock(&cond.wait_list_lock);

    return BHT_OK;
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
    return os_cond_wait_internal(cond, mutex, false, 0);
}

int os_cond_reltimedwait(korp_cond* cond, korp_mutex* mutex, ulong useconds) {

    if (useconds == BHT_WAIT_FOREVER) {
        return os_cond_wait_internal(cond, mutex, false, 0);
    }
    else {
        ulong mills_64 = useconds / 1000;
        int mills = void;

        if (mills_64 < cast(ulong)INT32_MAX) {
            mills = cast(int)mills_64;
        }
        else {
            mills = INT32_MAX;
            os_printf("Warning: os_cond_reltimedwait exceeds limit, "
                      ~ "set to max timeout instead\n");
        }
        return os_cond_wait_internal(cond, mutex, true, mills);
    }
}

int os_cond_signal(korp_cond* cond) {
    /* Signal the head wait node of wait list */
    k_mutex_lock(&cond.wait_list_lock, K_FOREVER);
    if (cond.thread_wait_list)
        k_sem_give(&cond.thread_wait_list.sem);
    k_mutex_unlock(&cond.wait_list_lock);

    return BHT_OK;
}

ubyte* os_thread_get_stack_boundary() {
version (CONFIG_THREAD_STACK_INFO) {
    korp_tid thread = k_current_get();
    return cast(ubyte*)thread.stack_info.start;
} else {
    return null;
}
}
