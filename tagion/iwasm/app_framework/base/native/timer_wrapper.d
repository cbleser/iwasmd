module timer_wrapper;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_platform;
public import app_manager_export;
public import ...app-manager.module_wasm_app;
public import timer_native_api;

struct _Timer_ctx_node_t {
    bh_list_link l;
    timer_ctx_t timer_ctx;
}alias timer_ctx_node_t = _Timer_ctx_node_t;

private bool timer_thread_run = true;

private bh_list g_timer_ctx_list;
private korp_cond g_timer_ctx_list_cond;
private korp_mutex g_timer_ctx_list_mutex;

void wasm_timer_callback(timer_id_t id, uint mod_id) {
    module_data* module_ = module_data_list_lookup_id(mod_id);
    if (module_ == null)
        return;

    // !!! the length parameter must be 0, so the receiver will
    //     not free the payload pointer.
    bh_post_msg(module_.queue, TIMER_EVENT_WASM, cast(char*)cast(uintptr_t)id, 0);
}

/**
 * why we create a separate link for module timer contexts
 * rather than traverse the module list?
 * It helps to reduce the lock frequency for the module list.
 * Also when we lock the module list and then call the callback for
 * timer expire, the callback is request the list lock again for lookup
 * the module from module id. It is for avoiding that situation.
 */

void* thread_modulers_timer_check(void* arg) {
    uint ms_to_expiry = void;
    ulong us_to_wait = void;

    while (timer_thread_run) {
        ms_to_expiry = (uint32)-1;
        os_mutex_lock(&g_timer_ctx_list_mutex);
        timer_ctx_node_t* elem = cast(timer_ctx_node_t*)bh_list_first_elem(&g_timer_ctx_list);
        while (elem) {
            uint next = check_app_timers(elem.timer_ctx);
            if (next != (uint32)-1) {
                if (ms_to_expiry == (uint32)-1 || ms_to_expiry > next)
                    ms_to_expiry = next;
            }

            elem = cast(timer_ctx_node_t*)bh_list_elem_next(elem);
        }
        os_mutex_unlock(&g_timer_ctx_list_mutex);

        if (ms_to_expiry == (uint32)-1)
            us_to_wait = BHT_WAIT_FOREVER;
        else
            us_to_wait = cast(ulong)ms_to_expiry * 1000;
        os_mutex_lock(&g_timer_ctx_list_mutex);
        os_cond_reltimedwait(&g_timer_ctx_list_cond, &g_timer_ctx_list_mutex,
                             us_to_wait);
        os_mutex_unlock(&g_timer_ctx_list_mutex);
    }

    return null;
}

void wakeup_modules_timer_thread(timer_ctx_t ctx) {
    os_mutex_lock(&g_timer_ctx_list_mutex);
    os_cond_signal(&g_timer_ctx_list_cond);
    os_mutex_unlock(&g_timer_ctx_list_mutex);
}

bool init_wasm_timer() {
    korp_tid tm_tid = void;
    bh_list_init(&g_timer_ctx_list);

    if (os_cond_init(&g_timer_ctx_list_cond) != 0) {
        return false;
    }
    /* temp solution for: thread_modulers_timer_check thread
       would recursive lock the mutex */
    if (os_recursive_mutex_init(&g_timer_ctx_list_mutex) != 0) {
        goto fail1;
    }

    if (0
        != os_thread_create(&tm_tid, &thread_modulers_timer_check, null,
                            BH_APPLET_PRESERVED_STACK_SIZE)) {
        goto fail2;
    }

    return true;

fail2:
    os_mutex_destroy(&g_timer_ctx_list_mutex);

fail1:
    os_cond_destroy(&g_timer_ctx_list_cond);

    return false;
}

void exit_wasm_timer() {
    timer_thread_run = false;
}

timer_ctx_t create_wasm_timer_ctx(uint module_id, int prealloc_num) {
    timer_ctx_t ctx = create_timer_ctx(&wasm_timer_callback, &wakeup_modules_timer_thread,
                         prealloc_num, module_id);

    if (ctx == null)
        return null;

    timer_ctx_node_t* node = cast(timer_ctx_node_t*)wasm_runtime_malloc(timer_ctx_node_t.sizeof);
    if (node == null) {
        destroy_timer_ctx(ctx);
        return null;
    }
    memset(node, 0, typeof(*node).sizeof);
    node.timer_ctx = ctx;

    os_mutex_lock(&g_timer_ctx_list_mutex);
    bh_list_insert(&g_timer_ctx_list, node);
    os_mutex_unlock(&g_timer_ctx_list_mutex);

    return ctx;
}

void destroy_module_timer_ctx(uint module_id) {
    timer_ctx_node_t* elem = void;

    os_mutex_lock(&g_timer_ctx_list_mutex);
    elem = cast(timer_ctx_node_t*)bh_list_first_elem(&g_timer_ctx_list);
    while (elem) {
        if (timer_ctx_get_owner(elem.timer_ctx) == module_id) {
            bh_list_remove(&g_timer_ctx_list, elem);
            destroy_timer_ctx(elem.timer_ctx);
            wasm_runtime_free(elem);
            break;
        }

        elem = cast(timer_ctx_node_t*)bh_list_elem_next(elem);
    }
    os_mutex_unlock(&g_timer_ctx_list_mutex);
}

timer_ctx_t get_wasm_timer_ctx(wasm_module_inst_t module_inst) {
    module_data* m = app_manager_get_module_data(Module_WASM_App, module_inst);
    if (m == null)
        return null;
    return m.timer_ctx;
}

timer_id_t wasm_create_timer(wasm_exec_env_t exec_env, int interval, bool is_period, bool auto_start) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    timer_ctx_t timer_ctx = get_wasm_timer_ctx(module_inst);
    bh_assert(timer_ctx);
    return sys_create_timer(timer_ctx, interval, is_period, auto_start);
}

void wasm_timer_destroy(wasm_exec_env_t exec_env, timer_id_t timer_id) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    timer_ctx_t timer_ctx = get_wasm_timer_ctx(module_inst);
    bh_assert(timer_ctx);
    sys_timer_destroy(timer_ctx, timer_id);
}

void wasm_timer_cancel(wasm_exec_env_t exec_env, timer_id_t timer_id) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    timer_ctx_t timer_ctx = get_wasm_timer_ctx(module_inst);
    bh_assert(timer_ctx);
    sys_timer_cancel(timer_ctx, timer_id);
}

void wasm_timer_restart(wasm_exec_env_t exec_env, timer_id_t timer_id, int interval) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    timer_ctx_t timer_ctx = get_wasm_timer_ctx(module_inst);
    bh_assert(timer_ctx);
    sys_timer_restart(timer_ctx, timer_id, interval);
}

uint wasm_get_sys_tick_ms(wasm_exec_env_t exec_env) {
    return cast(uint)bh_get_tick_ms();
}
