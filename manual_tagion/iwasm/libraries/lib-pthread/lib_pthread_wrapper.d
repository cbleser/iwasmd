module lib_pthread_wrapper;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_common;
public import bh_log;
public import wasm_export;
public import ...interpreter.wasm;
public import ...common.wasm_runtime_common;
public import thread_manager;

static if (WASM_ENABLE_INTERP != 0) {
public import wasm_runtime;
}

static if (WASM_ENABLE_AOT != 0) {
public import aot_runtime;
}

enum WAMR_PTHREAD_KEYS_MAX = 32;

/* clang-format off */
enum string get_module(string exec_env) = ` \
    wasm_exec_env_get_module(exec_env)`;

enum string get_module_inst(string exec_env) = ` \
    wasm_runtime_get_module_inst(exec_env)`;

enum string get_thread_arg(string exec_env) = ` \
    wasm_exec_env_get_thread_arg(exec_env)`;

enum string get_wasi_ctx(string module_inst) = ` \
    wasm_runtime_get_wasi_ctx(module_inst)`;

enum string validate_app_addr(string offset, string size) = ` \
    wasm_runtime_validate_app_addr(module_inst, offset, size)`;

enum string validate_native_addr(string addr, string size) = ` \
    wasm_runtime_validate_native_addr(module_inst, addr, size)`;

enum string addr_app_to_native(string offset) = ` \
    wasm_runtime_addr_app_to_native(module_inst, offset)`;

enum string addr_native_to_app(string ptr) = ` \
    wasm_runtime_addr_native_to_app(module_inst, ptr)`;
/* clang-format on */

extern bool wasm_runtime_call_indirect(wasm_exec_env_t exec_env, uint element_indices, uint argc, uint* argv);

enum {
    T_THREAD,
    T_MUTEX,
    T_COND,
    T_SEM,
}

enum thread_status_t {
    THREAD_INIT,
    THREAD_RUNNING,
    THREAD_CANCELLED,
    THREAD_EXIT,
}
alias THREAD_INIT = thread_status_t.THREAD_INIT;
alias THREAD_RUNNING = thread_status_t.THREAD_RUNNING;
alias THREAD_CANCELLED = thread_status_t.THREAD_CANCELLED;
alias THREAD_EXIT = thread_status_t.THREAD_EXIT;


enum mutex_status_t {
    MUTEX_CREATED,
    MUTEX_DESTROYED,
}
alias MUTEX_CREATED = mutex_status_t.MUTEX_CREATED;
alias MUTEX_DESTROYED = mutex_status_t.MUTEX_DESTROYED;


enum cond_status_t {
    COND_CREATED,
    COND_DESTROYED,
}
alias COND_CREATED = cond_status_t.COND_CREATED;
alias COND_DESTROYED = cond_status_t.COND_DESTROYED;


enum sem_status_t {
    SEM_CREATED,
    SEM_CLOSED,
    SEM_DESTROYED,
}
alias SEM_CREATED = sem_status_t.SEM_CREATED;
alias SEM_CLOSED = sem_status_t.SEM_CLOSED;
alias SEM_DESTROYED = sem_status_t.SEM_DESTROYED;


struct ThreadKeyValueNode {
    bh_list_link l;
    wasm_exec_env_t exec_env;
    int[WAMR_PTHREAD_KEYS_MAX] thread_key_values;
}

struct KeyData {
    int destructor_func;
    bool is_created;
}

struct ClusterInfoNode {
    bh_list_link l;
    WASMCluster* cluster;
    HashMap* thread_info_map;
    /* Key data list */
    KeyData[WAMR_PTHREAD_KEYS_MAX] key_data_list;
    korp_mutex key_data_list_lock;
    /* Every node contains the key value list for a thread */
    bh_list thread_list_head;
    bh_list* thread_list;
}

struct ThreadInfoNode {
    wasm_exec_env_t parent_exec_env;
    wasm_exec_env_t exec_env;
    /* the id returned to app */
    uint handle;
    /* type can be [THREAD | MUTEX | CONDITION] */
    uint type;
    /* Thread status, this variable should be volatile
       as its value may be changed in different threads */
    /*volatile*/ uint status;
    bool joinable;
    union _U {
        korp_tid thread;
        korp_mutex* mutex;
        korp_cond* cond;
static if (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0) {
        korp_sem* sem;
}
        /* A copy of the thread return value */
        void* ret;
    }_U u;
}

struct _ThreadRoutineArgs {
    ThreadInfoNode* info_node;
    /* table elem index of the app's entry function */
    uint elem_index;
    /* arg of the app's entry function */
    uint arg;
    wasm_module_inst_t module_inst;
}alias ThreadRoutineArgs = _ThreadRoutineArgs;

struct _SemCallbackArgs {
    uint handle;
    ThreadInfoNode* node;
}alias SemCallbackArgs = _SemCallbackArgs;

private bh_list cluster_info_list;
static if (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0) {
private HashMap* sem_info_map;
}
private korp_mutex thread_global_lock;
private uint handle_id = 1;

private void lib_pthread_destroy_callback(WASMCluster* cluster);

private uint thread_handle_hash(void* handle) {
    return cast(uint)cast(uintptr_t)handle;
}

private bool thread_handle_equal(void* h1, void* h2) {
    return cast(uint)cast(uintptr_t)h1 == cast(uint)cast(uintptr_t)h2 ? true : false;
}

private void thread_info_destroy(void* node) {
    ThreadInfoNode* info_node = cast(ThreadInfoNode*)node;

    os_mutex_lock(&thread_global_lock);
    if (info_node.type == T_MUTEX) {
        if (info_node.status != MUTEX_DESTROYED)
            os_mutex_destroy(info_node.u.mutex);
        wasm_runtime_free(info_node.u.mutex);
    }
    else if (info_node.type == T_COND) {
        if (info_node.status != COND_DESTROYED)
            os_cond_destroy(info_node.u.cond);
        wasm_runtime_free(info_node.u.cond);
    }
static if (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0) {
    else if(info_node T_SEM) {
        if (info_node.status != SEM_DESTROYED)
            os_sem_close(info_node.u.sem);
    }
}
    wasm_runtime_free(info_node);
    os_mutex_unlock(&thread_global_lock);
}

bool lib_pthread_init() {
    if (0 != os_mutex_init(&thread_global_lock))
        return false;
    bh_list_init(&cluster_info_list);
    if (!wasm_cluster_register_destroy_callback(&lib_pthread_destroy_callback)) {
        os_mutex_destroy(&thread_global_lock);
        return false;
    }
static if (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0) {
    if (((sem_info_map = bh_hash_map_create(
              32, true, cast(HashFunc)wasm_string_hash,
              cast(KeyEqualFunc)wasm_string_equal, null, &thread_info_destroy)) == 0)) {
        os_mutex_destroy(&thread_global_lock);
        return false;
    }
}
    return true;
}

void lib_pthread_destroy() {
static if (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0) {
    bh_hash_map_destroy(sem_info_map);
}
    os_mutex_destroy(&thread_global_lock);
}

private ClusterInfoNode* get_cluster_info(WASMCluster* cluster) {
    ClusterInfoNode* node = void;

    os_mutex_lock(&thread_global_lock);
    node = bh_list_first_elem(&cluster_info_list);

    while (node) {
        if (cluster == node.cluster) {
            os_mutex_unlock(&thread_global_lock);
            return node;
        }
        node = bh_list_elem_next(node);
    }
    os_mutex_unlock(&thread_global_lock);

    return null;
}

private KeyData* key_data_list_lookup(wasm_exec_env_t exec_env, int key) {
    ClusterInfoNode* node = void;
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);

    if ((node = get_cluster_info(cluster))) {
        return (key >= 0 && key < WAMR_PTHREAD_KEYS_MAX
                && node.key_data_list[key].is_created)
                   ? &(node.key_data_list[key])
                   : null;
    }

    return null;
}

/**
 * Lookup the thread key value node for a thread, create a new one if failed
 * This design will reduce the memory usage. If the thread doesn't use the
 * local storage, it will not occupy memory space.
 */
private int* key_value_list_lookup_or_create(wasm_exec_env_t exec_env, ClusterInfoNode* info, int key) {
    KeyData* key_node = void;
    ThreadKeyValueNode* data = void;

    /* Check if the key is valid */
    key_node = key_data_list_lookup(exec_env, key);
    if (!key_node) {
        return null;
    }

    /* Find key values node */
    data = bh_list_first_elem(info.thread_list);
    while (data) {
        if (data.exec_env == exec_env)
            return data.thread_key_values;
        data = bh_list_elem_next(data);
    }

    /* If not found, create a new node for this thread */
    if (((data = wasm_runtime_malloc(ThreadKeyValueNode.sizeof)) == 0))
        return null;
    memset(data, 0, ThreadKeyValueNode.sizeof);
    data.exec_env = exec_env;

    if (bh_list_insert(info.thread_list, data) != 0) {
        wasm_runtime_free(data);
        return null;
    }

    return data.thread_key_values;
}

private void call_key_destructor(wasm_exec_env_t exec_env) {
    int i = void;
    uint destructor_index = void;
    KeyData* key_node = void;
    ThreadKeyValueNode* value_node = void;
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    ClusterInfoNode* info = get_cluster_info(cluster);

    if (!info) {
        return;
    }

    value_node = bh_list_first_elem(info.thread_list);
    while (value_node) {
        if (value_node.exec_env == exec_env)
            break;
        value_node = bh_list_elem_next(value_node);
    }

    /* This thread hasn't created key value node */
    if (!value_node)
        return;

    /* Destroy key values */
    for (i = 0; i < WAMR_PTHREAD_KEYS_MAX; i++) {
        if (value_node.thread_key_values[i] != 0) {
            int value = value_node.thread_key_values[i];
            os_mutex_lock(&info.key_data_list_lock);

            if ((key_node = key_data_list_lookup(exec_env, i)))
                destructor_index = key_node.destructor_func;
            else
                destructor_index = 0;
            os_mutex_unlock(&info.key_data_list_lock);

            /* reset key value */
            value_node.thread_key_values[i] = 0;

            /* Call the destructor func provided by app */
            if (destructor_index) {
                uint[1] argv = void;

                argv[0] = value;
                wasm_runtime_call_indirect(exec_env, destructor_index, 1, argv.ptr);
            }
        }
    }

    bh_list_remove(info.thread_list, value_node);
    wasm_runtime_free(value_node);
}

private void destroy_thread_key_value_list(bh_list* list) {
    ThreadKeyValueNode* node = void, next = void;

    /* There should be only one node for main thread */
    bh_assert(list.len <= 1);

    if (list.len) {
        node = bh_list_first_elem(list);
        while (node) {
            next = bh_list_elem_next(node);
            call_key_destructor(node.exec_env);
            node = next;
        }
    }
}

private ClusterInfoNode* create_cluster_info(WASMCluster* cluster) {
    ClusterInfoNode* node = void;
    bh_list_status ret = void;

    if (((node = wasm_runtime_malloc(ClusterInfoNode.sizeof)) == 0)) {
        return null;
    }
    memset(node, 0, ClusterInfoNode.sizeof);

    node.thread_list = &node.thread_list_head;
    ret = bh_list_init(node.thread_list);
    bh_assert(ret == BH_LIST_SUCCESS);

    if (os_mutex_init(&node.key_data_list_lock) != 0) {
        wasm_runtime_free(node);
        return null;
    }

    node.cluster = cluster;
    if (((node.thread_info_map = bh_hash_map_create(
              32, true, cast(HashFunc)thread_handle_hash,
              cast(KeyEqualFunc)thread_handle_equal, null, &thread_info_destroy)) == 0)) {
        os_mutex_destroy(&node.key_data_list_lock);
        wasm_runtime_free(node);
        return null;
    }
    os_mutex_lock(&thread_global_lock);
    ret = bh_list_insert(&cluster_info_list, node);
    bh_assert(ret == BH_LIST_SUCCESS);
    os_mutex_unlock(&thread_global_lock);

    cast(void)ret;
    return node;
}

private bool destroy_cluster_info(WASMCluster* cluster) {
    ClusterInfoNode* node = get_cluster_info(cluster);
    if (node) {
        bh_hash_map_destroy(node.thread_info_map);
        destroy_thread_key_value_list(node.thread_list);
        os_mutex_destroy(&node.key_data_list_lock);

        /* Remove from the cluster info list */
        os_mutex_lock(&thread_global_lock);
        bh_list_remove(&cluster_info_list, node);
        wasm_runtime_free(node);
        os_mutex_unlock(&thread_global_lock);
        return true;
    }
    return false;
}

private void lib_pthread_destroy_callback(WASMCluster* cluster) {
    destroy_cluster_info(cluster);
}

private void delete_thread_info_node(ThreadInfoNode* thread_info) {
    ClusterInfoNode* node = void;
    bool ret = void;
    WASMCluster* cluster = wasm_exec_env_get_cluster(thread_info.exec_env);

    if ((node = get_cluster_info(cluster))) {
        ret = bh_hash_map_remove(node.thread_info_map,
                                 cast(void*)cast(uintptr_t)thread_info.handle, null,
                                 null);
        cast(void)ret;
    }

    thread_info_destroy(thread_info);
}

private bool append_thread_info_node(ThreadInfoNode* thread_info) {
    ClusterInfoNode* node = void;
    WASMCluster* cluster = wasm_exec_env_get_cluster(thread_info.exec_env);

    if (((node = get_cluster_info(cluster)) == 0)) {
        if (((node = create_cluster_info(cluster)) == 0)) {
            return false;
        }
    }

    if (!bh_hash_map_insert(node.thread_info_map,
                            cast(void*)cast(uintptr_t)thread_info.handle,
                            thread_info)) {
        return false;
    }

    return true;
}

private ThreadInfoNode* get_thread_info(wasm_exec_env_t exec_env, uint handle) {
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    ClusterInfoNode* info = get_cluster_info(cluster);

    if (!info) {
        return null;
    }

    return bh_hash_map_find(info.thread_info_map, cast(void*)cast(uintptr_t)handle);
}

private uint allocate_handle() {
    uint id = void;
    os_mutex_lock(&thread_global_lock);
    id = handle_id++;
    os_mutex_unlock(&thread_global_lock);
    return id;
}

private void* pthread_start_routine(void* arg) {
    wasm_exec_env_t exec_env = cast(wasm_exec_env_t)arg;
    wasm_exec_env_t parent_exec_env = void;
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    ThreadRoutineArgs* routine_args = exec_env.thread_arg;
    ThreadInfoNode* info_node = routine_args.info_node;
    uint[1] argv = void;

    parent_exec_env = info_node.parent_exec_env;
    os_mutex_lock(&parent_exec_env.wait_lock);
    info_node.exec_env = exec_env;
    info_node.u.thread = exec_env.handle;
    if (!append_thread_info_node(info_node)) {
        wasm_runtime_deinstantiate_internal(module_inst, true);
        delete_thread_info_node(info_node);
        os_cond_signal(&parent_exec_env.wait_cond);
        os_mutex_unlock(&parent_exec_env.wait_lock);
        return null;
    }

    info_node.status = THREAD_RUNNING;
    os_cond_signal(&parent_exec_env.wait_cond);
    os_mutex_unlock(&parent_exec_env.wait_lock);

    wasm_exec_env_set_thread_info(exec_env);
    argv[0] = routine_args.arg;

    if (!wasm_runtime_call_indirect(exec_env, routine_args.elem_index, 1,
                                    argv.ptr)) {
        if (wasm_runtime_get_exception(module_inst))
            wasm_cluster_spread_exception(exec_env);
    }

    /* destroy pthread key values */
    call_key_destructor(exec_env);

    /* routine exit, destroy instance */
    wasm_runtime_deinstantiate_internal(module_inst, true);

    wasm_runtime_free(routine_args);

    /* if the thread is joinable, store the result in its info node,
       if the other threads join this thread after exited, then we
       can return the stored result */
    if (!info_node.joinable) {
        delete_thread_info_node(info_node);
    }
    else {
        info_node.u.ret = cast(void*)cast(uintptr_t)argv[0];
version (OS_ENABLE_HW_BOUND_CHECK) {
        if (exec_env.suspend_flags.flags & 0x08)
            /* argv[0] isn't set after longjmp(1) to
               invoke_native_with_hw_bound_check */
            info_node.u.ret = exec_env.thread_ret_value;
}
        /* Update node status after ret value was set */
        info_node.status = THREAD_EXIT;
    }

    return cast(void*)cast(uintptr_t)argv[0];
}

private int pthread_create_wrapper(wasm_exec_env_t exec_env, uint* thread, const(void)* attr, uint elem_index, uint arg) {
    wasm_module_t module_ = get_module(exec_env);
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    wasm_module_inst_t new_module_inst = null;
    ThreadInfoNode* info_node = null;
    ThreadRoutineArgs* routine_args = null;
    uint thread_handle = void;
    uint stack_size = 8192;
    int ret = -1;
static if (WASM_ENABLE_LIBC_WASI != 0) {
    WASIContext* wasi_ctx = void;
}

    bh_assert(module_);
    bh_assert(module_inst);

static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        stack_size =
            (cast(WASMModuleInstance*)module_inst).default_wasm_stack_size;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        stack_size =
            (cast(AOTModuleInstance*)module_inst).default_wasm_stack_size;
    }
}

    if (((new_module_inst = wasm_runtime_instantiate_internal(
              module_, true, stack_size, 0, null, 0)) == 0))
        return -1;

    /* Set custom_data to new module instance */
    wasm_runtime_set_custom_data_internal(
        new_module_inst, wasm_runtime_get_custom_data(module_inst));

static if (WASM_ENABLE_LIBC_WASI != 0) {
    wasi_ctx = get_wasi_ctx(module_inst);
    if (wasi_ctx)
        wasm_runtime_set_wasi_ctx(new_module_inst, wasi_ctx);
}

    if (((info_node = wasm_runtime_malloc(ThreadInfoNode.sizeof)) == 0))
        goto fail;

    memset(info_node, 0, ThreadInfoNode.sizeof);
    thread_handle = allocate_handle();
    info_node.parent_exec_env = exec_env;
    info_node.handle = thread_handle;
    info_node.type = T_THREAD;
    info_node.status = THREAD_INIT;
    info_node.joinable = true;

    if (((routine_args = wasm_runtime_malloc(ThreadRoutineArgs.sizeof)) == 0))
        goto fail;

    routine_args.arg = arg;
    routine_args.elem_index = elem_index;
    routine_args.info_node = info_node;
    routine_args.module_inst = new_module_inst;

    os_mutex_lock(&exec_env.wait_lock);
    ret = wasm_cluster_create_thread(
        exec_env, new_module_inst, &pthread_start_routine, cast(void*)routine_args);
    if (ret != 0) {
        os_mutex_unlock(&exec_env.wait_lock);
        goto fail;
    }

    /* Wait for the thread routine to assign the exec_env to
       thread_info_node, otherwise the exec_env in the thread
       info node may be NULL in the next pthread API call */
    os_cond_wait(&exec_env.wait_cond, &exec_env.wait_lock);
    os_mutex_unlock(&exec_env.wait_lock);

    if (thread)
        *thread = thread_handle;

    return 0;

fail:
    if (new_module_inst)
        wasm_runtime_deinstantiate_internal(new_module_inst, true);
    if (info_node)
        wasm_runtime_free(info_node);
    if (routine_args)
        wasm_runtime_free(routine_args);
    return ret;
}

private int pthread_join_wrapper(wasm_exec_env_t exec_env, uint thread, int retval_offset) {
    uint* ret = void;
    int join_ret = void;
    void** retval = void;
    ThreadInfoNode* node = void;
    wasm_module_inst_t module_inst = void;
    wasm_exec_env_t target_exec_env = void;

    module_inst = get_module_inst(exec_env);

    /* validate addr, we can use current thread's
       module instance here as the memory is shared */
    if (!validate_app_addr(retval_offset, int32.sizeof)) {
        /* Join failed, but we don't want to terminate all threads,
           do not spread exception here */
        wasm_runtime_set_exception(module_inst, null);
        return -1;
    }

    retval = cast(void**)addr_app_to_native(retval_offset);

    node = get_thread_info(exec_env, thread);
    if (!node) {
        /* The thread has exited and not joinable, return 0 to app */
        return 0;
    }

    target_exec_env = node.exec_env;
    bh_assert(target_exec_env);

    if (node.status != THREAD_EXIT) {
        /* if the thread is still running, call the platforms join API */
        join_ret = wasm_cluster_join_thread(target_exec_env, cast(void**)&ret);
    }
    else {
        /* if the thread has exited, return stored results */

        /* this thread must be joinable, otherwise the
           info_node should be destroyed once exit */
        bh_assert(node.joinable);
        join_ret = 0;
        ret = node.u.ret;
    }

    if (retval_offset != 0)
        *cast(uint*)retval = cast(uint)cast(uintptr_t)ret;

    return join_ret;
}

private int pthread_detach_wrapper(wasm_exec_env_t exec_env, uint thread) {
    ThreadInfoNode* node = void;
    wasm_exec_env_t target_exec_env = void;

    node = get_thread_info(exec_env, thread);
    if (!node)
        return 0;

    node.joinable = false;

    target_exec_env = node.exec_env;
    bh_assert(target_exec_env != null);

    return wasm_cluster_detach_thread(target_exec_env);
}

private int pthread_cancel_wrapper(wasm_exec_env_t exec_env, uint thread) {
    ThreadInfoNode* node = void;
    wasm_exec_env_t target_exec_env = void;

    node = get_thread_info(exec_env, thread);
    if (!node)
        return 0;

    node.status = THREAD_CANCELLED;
    node.joinable = false;

    target_exec_env = node.exec_env;
    bh_assert(target_exec_env != null);

    return wasm_cluster_cancel_thread(target_exec_env);
}

private int pthread_self_wrapper(wasm_exec_env_t exec_env) {
    ThreadRoutineArgs* args = get_thread_arg(exec_env);
    /* If thread_arg is NULL, it's the exec_env of the main thread,
       return id 0 to app */
    if (!args)
        return 0;

    return args.info_node.handle;
}

/* emcc use __pthread_self rather than pthread_self */
private int __pthread_self_wrapper(wasm_exec_env_t exec_env) {
    return pthread_self_wrapper(exec_env);
}

private void pthread_exit_wrapper(wasm_exec_env_t exec_env, int retval_offset) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    ThreadRoutineArgs* args = get_thread_arg(exec_env);
    /* Currently exit main thread is not allowed */
    if (!args)
        return;

static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && !HasVersion!"BH_PLATFORM_WINDOWS") {
    /* If hardware bound check enabled, don't deinstantiate module inst
       and thread info node here for AoT module, as they will be freed
       in pthread_start_routine */
    if (exec_env.jmpbuf_stack_top) {
        wasm_cluster_exit_thread(exec_env, cast(void*)cast(uintptr_t)retval_offset);
    }
}

    /* destroy pthread key values */
    call_key_destructor(exec_env);

    /* routine exit, destroy instance */
    wasm_runtime_deinstantiate_internal(module_inst, true);

    if (!args.info_node.joinable) {
        delete_thread_info_node(args.info_node);
    }
    else {
        args.info_node.u.ret = cast(void*)cast(uintptr_t)retval_offset;
        /* Update node status after ret value was set */
        args.info_node.status = THREAD_EXIT;
    }

    wasm_runtime_free(args);

    wasm_cluster_exit_thread(exec_env, cast(void*)cast(uintptr_t)retval_offset);
}

private int pthread_mutex_init_wrapper(wasm_exec_env_t exec_env, uint* mutex, void* attr) {
    korp_mutex* pmutex = void;
    ThreadInfoNode* info_node = void;

    if (((pmutex = wasm_runtime_malloc(korp_mutex.sizeof)) == 0)) {
        return -1;
    }

    if (os_mutex_init(pmutex) != 0) {
        goto fail1;
    }

    if (((info_node = wasm_runtime_malloc(ThreadInfoNode.sizeof)) == 0))
        goto fail2;

    memset(info_node, 0, ThreadInfoNode.sizeof);
    info_node.exec_env = exec_env;
    info_node.handle = allocate_handle();
    info_node.type = T_MUTEX;
    info_node.u.mutex = pmutex;
    info_node.status = MUTEX_CREATED;

    if (!append_thread_info_node(info_node))
        goto fail3;

    /* Return the mutex handle to app */
    if (mutex)
        *cast(uint*)mutex = info_node.handle;

    return 0;

fail3:
    delete_thread_info_node(info_node);
fail2:
    os_mutex_destroy(pmutex);
fail1:
    wasm_runtime_free(pmutex);

    return -1;
}

private int pthread_mutex_lock_wrapper(wasm_exec_env_t exec_env, uint* mutex) {
    ThreadInfoNode* info_node = get_thread_info(exec_env, *mutex);
    if (!info_node || info_node.type != T_MUTEX)
        return -1;

    return os_mutex_lock(info_node.u.mutex);
}

private int pthread_mutex_unlock_wrapper(wasm_exec_env_t exec_env, uint* mutex) {
    ThreadInfoNode* info_node = get_thread_info(exec_env, *mutex);
    if (!info_node || info_node.type != T_MUTEX)
        return -1;

    return os_mutex_unlock(info_node.u.mutex);
}

private int pthread_mutex_destroy_wrapper(wasm_exec_env_t exec_env, uint* mutex) {
    int ret_val = void;
    ThreadInfoNode* info_node = get_thread_info(exec_env, *mutex);
    if (!info_node || info_node.type != T_MUTEX)
        return -1;

    ret_val = os_mutex_destroy(info_node.u.mutex);

    info_node.status = MUTEX_DESTROYED;
    delete_thread_info_node(info_node);

    return ret_val;
}

private int pthread_cond_init_wrapper(wasm_exec_env_t exec_env, uint* cond, void* attr) {
    korp_cond* pcond = void;
    ThreadInfoNode* info_node = void;

    if (((pcond = wasm_runtime_malloc(korp_cond.sizeof)) == 0)) {
        return -1;
    }

    if (os_cond_init(pcond) != 0) {
        goto fail1;
    }

    if (((info_node = wasm_runtime_malloc(ThreadInfoNode.sizeof)) == 0))
        goto fail2;

    memset(info_node, 0, ThreadInfoNode.sizeof);
    info_node.exec_env = exec_env;
    info_node.handle = allocate_handle();
    info_node.type = T_COND;
    info_node.u.cond = pcond;
    info_node.status = COND_CREATED;

    if (!append_thread_info_node(info_node))
        goto fail3;

    /* Return the cond handle to app */
    if (cond)
        *cast(uint*)cond = info_node.handle;

    return 0;

fail3:
    delete_thread_info_node(info_node);
fail2:
    os_cond_destroy(pcond);
fail1:
    wasm_runtime_free(pcond);

    return -1;
}

private int pthread_cond_wait_wrapper(wasm_exec_env_t exec_env, uint* cond, uint* mutex) {
    ThreadInfoNode* cond_info_node = void, mutex_info_node = void;

    cond_info_node = get_thread_info(exec_env, *cond);
    if (!cond_info_node || cond_info_node.type != T_COND)
        return -1;

    mutex_info_node = get_thread_info(exec_env, *mutex);
    if (!mutex_info_node || mutex_info_node.type != T_MUTEX)
        return -1;

    return os_cond_wait(cond_info_node.u.cond, mutex_info_node.u.mutex);
}

/**
 * Currently we don't support struct timespec in built-in libc,
 * so the pthread_cond_timedwait use useconds instead
 */
private int pthread_cond_timedwait_wrapper(wasm_exec_env_t exec_env, uint* cond, uint* mutex, ulong useconds) {
    ThreadInfoNode* cond_info_node = void, mutex_info_node = void;

    cond_info_node = get_thread_info(exec_env, *cond);
    if (!cond_info_node || cond_info_node.type != T_COND)
        return -1;

    mutex_info_node = get_thread_info(exec_env, *mutex);
    if (!mutex_info_node || mutex_info_node.type != T_MUTEX)
        return -1;

    return os_cond_reltimedwait(cond_info_node.u.cond,
                                mutex_info_node.u.mutex, useconds);
}

private int pthread_cond_signal_wrapper(wasm_exec_env_t exec_env, uint* cond) {
    ThreadInfoNode* info_node = get_thread_info(exec_env, *cond);
    if (!info_node || info_node.type != T_COND)
        return -1;

    return os_cond_signal(info_node.u.cond);
}

private int pthread_cond_broadcast_wrapper(wasm_exec_env_t exec_env, uint* cond) {
    ThreadInfoNode* info_node = get_thread_info(exec_env, *cond);
    if (!info_node || info_node.type != T_COND)
        return -1;

    return os_cond_broadcast(info_node.u.cond);
}

private int pthread_cond_destroy_wrapper(wasm_exec_env_t exec_env, uint* cond) {
    int ret_val = void;
    ThreadInfoNode* info_node = get_thread_info(exec_env, *cond);
    if (!info_node || info_node.type != T_COND)
        return -1;

    ret_val = os_cond_destroy(info_node.u.cond);

    info_node.status = COND_DESTROYED;
    delete_thread_info_node(info_node);

    return ret_val;
}

private int pthread_key_create_wrapper(wasm_exec_env_t exec_env, int* key, int destructor_elem_index) {
    uint i = void;
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    ClusterInfoNode* info = get_cluster_info(cluster);

    if (!info) {
        /* The user may call pthread_key_create in main thread,
           in this case the cluster info hasn't been created */
        if (((info = create_cluster_info(cluster)) == 0)) {
            return -1;
        }
    }

    os_mutex_lock(&info.key_data_list_lock);
    for (i = 0; i < WAMR_PTHREAD_KEYS_MAX; i++) {
        if (!info.key_data_list[i].is_created) {
            break;
        }
    }

    if (i == WAMR_PTHREAD_KEYS_MAX) {
        os_mutex_unlock(&info.key_data_list_lock);
        return -1;
    }

    info.key_data_list[i].destructor_func = destructor_elem_index;
    info.key_data_list[i].is_created = true;
    *key = i;
    os_mutex_unlock(&info.key_data_list_lock);

    return 0;
}

private int pthread_setspecific_wrapper(wasm_exec_env_t exec_env, int key, int value_offset) {
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    ClusterInfoNode* info = get_cluster_info(cluster);
    int* key_values = void;

    if (!info)
        return -1;

    os_mutex_lock(&info.key_data_list_lock);

    key_values = key_value_list_lookup_or_create(exec_env, info, key);
    if (!key_values) {
        os_mutex_unlock(&info.key_data_list_lock);
        return -1;
    }

    key_values[key] = value_offset;
    os_mutex_unlock(&info.key_data_list_lock);

    return 0;
}

private int pthread_getspecific_wrapper(wasm_exec_env_t exec_env, int key) {
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    ClusterInfoNode* info = get_cluster_info(cluster);
    int ret = void; int* key_values = void;

    if (!info)
        return 0;

    os_mutex_lock(&info.key_data_list_lock);

    key_values = key_value_list_lookup_or_create(exec_env, info, key);
    if (!key_values) {
        os_mutex_unlock(&info.key_data_list_lock);
        return 0;
    }

    ret = key_values[key];
    os_mutex_unlock(&info.key_data_list_lock);

    return ret;
}

private int pthread_key_delete_wrapper(wasm_exec_env_t exec_env, int key) {
    KeyData* data = void;
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    ClusterInfoNode* info = get_cluster_info(cluster);

    if (!info)
        return -1;

    os_mutex_lock(&info.key_data_list_lock);
    data = key_data_list_lookup(exec_env, key);
    if (!data) {
        os_mutex_unlock(&info.key_data_list_lock);
        return -1;
    }

    memset(data, 0, KeyData.sizeof);
    os_mutex_unlock(&info.key_data_list_lock);

    return 0;
}

/**
 * Currently the memory allocator doesn't support alloc specific aligned
 * space, we wrap posix_memalign to simply malloc memory
 */
private int posix_memalign_wrapper(wasm_exec_env_t exec_env, void** memptr, int align_, int size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    void* p = null;

    *(cast(int*)memptr) = module_malloc(size, cast(void**)&p);
    if (!p)
        return -1;

    return 0;
}

static if (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0) {

private int sem_open_wrapper(wasm_exec_env_t exec_env, const(char)* name, int oflags, int mode, int val) {
    korp_sem* psem = null;
    ThreadInfoNode* info_node = null;

    /**
     * For RTOS, global semaphore map is safe for share the same semaphore
     * between task/pthread.
     * For Unix like system, it's dedicated for multiple processes.
     */

    if ((info_node = bh_hash_map_find(sem_info_map, cast(void*)name))) {
        return info_node.handle;
    }

    if (((psem = os_sem_open(name, oflags, mode, val)) == 0)) {
        goto fail1;
    }

    if (((info_node = wasm_runtime_malloc(ThreadInfoNode.sizeof)) == 0))
        goto fail2;

    memset(info_node, 0, ThreadInfoNode.sizeof);
    info_node.exec_env = exec_env;
    info_node.handle = allocate_handle();
    info_node.type = T_SEM;
    info_node.u.sem = psem;
    info_node.status = SEM_CREATED;

    if (!bh_hash_map_insert(sem_info_map, cast(void*)name, info_node))
        goto fail3;

    return info_node.handle;

fail3:
    wasm_runtime_free(info_node);
fail2:
    os_sem_close(psem);
fail1:
    return -1;
}

void sem_fetch_cb(void* key, void* value, void* user_data) {
    cast(void)key;
    SemCallbackArgs* args = user_data;
    ThreadInfoNode* info_node = value;
    if (args.handle == info_node.handle && info_node.status == SEM_CREATED) {
        args.node = info_node;
    }
}

private int sem_close_wrapper(wasm_exec_env_t exec_env, uint sem) {
    cast(void)exec_env;
    int ret = -1;
    SemCallbackArgs args = { sem, null };

    bh_hash_map_traverse(sem_info_map, &sem_fetch_cb, &args);

    if (args.node) {
        ret = os_sem_close(args.node.u.sem);
        if (ret == 0) {
            args.node.status = SEM_CLOSED;
        }
    }

    return ret;
}

private int sem_wait_wrapper(wasm_exec_env_t exec_env, uint sem) {
    cast(void)exec_env;
    SemCallbackArgs args = { sem, null };

    bh_hash_map_traverse(sem_info_map, &sem_fetch_cb, &args);

    if (args.node) {
        return os_sem_wait(args.node.u.sem);
    }

    return -1;
}

private int sem_trywait_wrapper(wasm_exec_env_t exec_env, uint sem) {
    cast(void)exec_env;
    SemCallbackArgs args = { sem, null };

    bh_hash_map_traverse(sem_info_map, &sem_fetch_cb, &args);

    if (args.node) {
        return os_sem_trywait(args.node.u.sem);
    }

    return -1;
}

private int sem_post_wrapper(wasm_exec_env_t exec_env, uint sem) {
    cast(void)exec_env;
    SemCallbackArgs args = { sem, null };

    bh_hash_map_traverse(sem_info_map, &sem_fetch_cb, &args);

    if (args.node) {
        return os_sem_post(args.node.u.sem);
    }

    return -1;
}

private int sem_getvalue_wrapper(wasm_exec_env_t exec_env, uint sem, int* sval) {
    int ret = -1;
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    cast(void)exec_env;
    SemCallbackArgs args = { sem, null };

    if (validate_native_addr(sval, int32.sizeof)) {

        bh_hash_map_traverse(sem_info_map, &sem_fetch_cb, &args);

        if (args.node) {
            ret = os_sem_getvalue(args.node.u.sem, sval);
        }
    }
    return ret;
}

private int sem_unlink_wrapper(wasm_exec_env_t exec_env, const(char)* name) {
    cast(void)exec_env;
    int ret_val = void;

    ThreadInfoNode* info_node = bh_hash_map_find(sem_info_map, cast(void*)name);
    if (!info_node || info_node.type != T_SEM)
        return -1;

    if (info_node.status != SEM_CLOSED) {
        ret_val = os_sem_close(info_node.u.sem);
        if (ret_val != 0) {
            return ret_val;
        }
    }

    ret_val = os_sem_unlink(name);

    if (ret_val == 0) {
        bh_hash_map_remove(sem_info_map, cast(void*)name, null, null);
        info_node.status = SEM_DESTROYED;
        thread_info_destroy(info_node);
    }
    return ret_val;
}

}

/* clang-format off */
enum string REG_NATIVE_FUNC(string func_name, string signature) = ` \
    { #func_name, func_name##_wrapper, signature, NULL }`;
/* clang-format on */

private NativeSymbol[30] native_symbols_lib_pthread = [
    REG_NATIVE_FUNC(pthread_create, "(**ii)i"),
    REG_NATIVE_FUNC(pthread_join, "(ii)i"),
    REG_NATIVE_FUNC(pthread_detach, "(i)i"),
    REG_NATIVE_FUNC(pthread_cancel, "(i)i"),
    REG_NATIVE_FUNC(pthread_self, "()i"),
    REG_NATIVE_FUNC(__pthread_self, "()i"),
    REG_NATIVE_FUNC(pthread_exit, "(i)"),
    REG_NATIVE_FUNC(pthread_mutex_init, "(**)i"),
    REG_NATIVE_FUNC(pthread_mutex_lock, "(*)i"),
    REG_NATIVE_FUNC(pthread_mutex_unlock, "(*)i"),
    REG_NATIVE_FUNC(pthread_mutex_destroy, "(*)i"),
    REG_NATIVE_FUNC(pthread_cond_init, "(**)i"),
    REG_NATIVE_FUNC(pthread_cond_wait, "(**)i"),
    REG_NATIVE_FUNC(pthread_cond_timedwait, "(**I)i"),
    REG_NATIVE_FUNC(pthread_cond_signal, "(*)i"),
    REG_NATIVE_FUNC(pthread_cond_broadcast, "(*)i"),
    REG_NATIVE_FUNC(pthread_cond_destroy, "(*)i"),
    REG_NATIVE_FUNC(pthread_key_create, "(*i)i"),
    REG_NATIVE_FUNC(pthread_setspecific, "(ii)i"),
    REG_NATIVE_FUNC(pthread_getspecific, "(i)i"),
    REG_NATIVE_FUNC(pthread_key_delete, "(i)i"),
    REG_NATIVE_FUNC(posix_memalign, "(*ii)i"),
#if WASM_ENABLE_LIB_PTHREAD_SEMAPHORE != 0
    REG_NATIVE_FUNC(sem_open, "($iii)i"),
    REG_NATIVE_FUNC(sem_close, "(i)i"),
    REG_NATIVE_FUNC(sem_wait, "(i)i"),
    REG_NATIVE_FUNC(sem_trywait, "(i)i"),
    REG_NATIVE_FUNC(sem_post, "(i)i"),
    REG_NATIVE_FUNC(sem_getvalue, "(i*)i"),
    REG_NATIVE_FUNC(sem_unlink, "($)i"),
#endif
];

uint get_lib_pthread_export_apis(NativeSymbol** p_lib_pthread_apis) {
    *p_lib_pthread_apis = native_symbols_lib_pthread;
    return native_symbols_lib_pthread.sizeof / NativeSymbol.sizeof;
}
