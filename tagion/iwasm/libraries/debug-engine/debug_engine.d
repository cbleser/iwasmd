module debug_engine;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import debug_engine;
public import gdbserver;
public import handler;
public import bh_platform;
public import wasm_interp;
public import wasm_opcode;
public import wasm_runtime;

private const(ubyte)[1] break_instr = [ DEBUG_OP_BREAK ];

struct WASMDebugEngine {
    WASMDebugEngine* next;
    WASMDebugControlThread* control_thread;
    char[128] ip_addr = 0;
    int process_base_port;
    bh_list debug_instance_list;
    korp_mutex instance_list_lock;
}

void on_thread_stop_event(WASMDebugInstance* debug_inst, WASMExecEnv* exec_env) {
    os_mutex_lock(&debug_inst.wait_lock);
    debug_inst.stopped_thread = exec_env;

    if (debug_inst.current_state == DBG_LAUNCHING) {
        /* In launching phase, send a signal so that handle_threadstop_request
         * can be woken up */
        os_cond_signal(&debug_inst.wait_cond);
    }
    os_mutex_unlock(&debug_inst.wait_lock);
}

void on_thread_exit_event(WASMDebugInstance* debug_inst, WASMExecEnv* exec_env) {
    os_mutex_lock(&debug_inst.wait_lock);

    /* DBG_LAUNCHING: exit when debugger detached,
     * DBG_ERROR: exit when debugger error */
    if (debug_inst.current_state != DBG_LAUNCHING
        && debug_inst.current_state != DBG_ERROR) {
        /* only when exit normally the debugger thread will participate in
         * teardown phase */
        debug_inst.stopped_thread = exec_env;
    }

    os_mutex_unlock(&debug_inst.wait_lock);
}

private WASMDebugEngine* g_debug_engine;

private uint current_instance_id = 1;

private uint allocate_instance_id() {
    uint id = void;

    bh_assert(g_debug_engine);

    os_mutex_lock(&g_debug_engine.instance_list_lock);
    id = current_instance_id++;
    os_mutex_unlock(&g_debug_engine.instance_list_lock);

    return id;
}

private bool is_thread_running(WASMDebugControlThread* control_thread) {
    return control_thread.status == RUNNING;
}

private bool is_thread_stopped(WASMDebugControlThread* control_thread) {
    return control_thread.status == STOPPED;
}

private bool is_thread_detached(WASMDebugControlThread* control_thread) {
    return control_thread.status == DETACHED;
}

private void* control_thread_routine(void* arg) {
    WASMDebugInstance* debug_inst = cast(WASMDebugInstance*)arg;
    WASMDebugControlThread* control_thread = null;

    control_thread = debug_inst.control_thread;
    bh_assert(control_thread);

    os_mutex_lock(&debug_inst.wait_lock);

    control_thread.status = RUNNING;

    debug_inst.id = allocate_instance_id();

    control_thread.debug_engine = g_debug_engine;
    control_thread.debug_instance = debug_inst;
    bh_strcpy_s(control_thread.ip_addr, typeof(control_thread.ip_addr).sizeof,
                g_debug_engine.ip_addr);
    if (control_thread.port == -1) {
        control_thread.port =
            (g_debug_engine.process_base_port == 0)
                ? 0
                : g_debug_engine.process_base_port + debug_inst.id - 1;
    }

    LOG_WARNING("control thread of debug object %p start\n", debug_inst);

    control_thread.server =
        wasm_create_gdbserver(control_thread.ip_addr, &control_thread.port);

    if (!control_thread.server) {
        LOG_ERROR("Failed to create debug server\n");
        control_thread.port = 0;
        os_cond_signal(&debug_inst.wait_cond);
        os_mutex_unlock(&debug_inst.wait_lock);
        return null;
    }

    control_thread.server.thread = control_thread;

    /*
     * wasm gdbserver created, the execution thread
     *  doesn't need to wait for the debugger connection,
     *  so we wake up the execution thread before listen
     */
    os_cond_signal(&debug_inst.wait_cond);
    os_mutex_unlock(&debug_inst.wait_lock);

    if (!wasm_gdbserver_listen(control_thread.server)) {
        LOG_ERROR("Failed while listening for debugger\n");
        goto fail;
    }

    /* outer infinite loop: try to connect with the debugger */
    while (true) {
        /* wait lldb client to connect */
        if (!wasm_gdbserver_accept(control_thread.server)) {
            LOG_ERROR("Failed while accepting debugger connection\n");
            goto fail;
        }

        control_thread.status = RUNNING;
        /* when reattached, send signal */
        wasm_cluster_send_signal_all(debug_inst.cluster, WAMR_SIG_SINGSTEP);

        /* inner infinite loop: keep serving until detach */
        while (true) {
            os_mutex_lock(&control_thread.wait_lock);
            if (is_thread_running(control_thread)) {
                /* send thread stop reply */
                if (debug_inst.stopped_thread
                    && debug_inst.current_state == APP_RUNNING) {
                    uint status = void;
                    korp_tid tid = void;

                    status = cast(uint)debug_inst.stopped_thread.current_status
                                 .signal_flag;
                    tid = debug_inst.stopped_thread.handle;

                    if (debug_inst.stopped_thread.current_status
                            .running_status
                        == STATUS_EXIT) {
                        /* If the thread exits, report "W00" if it's the last
                         * thread in the cluster, otherwise ignore this event */
                        status = 0;

                        /* By design, all the other threads should have been
                         * stopped at this moment, so it is safe to access the
                         * exec_env_list.len without lock */
                        if (debug_inst.cluster.exec_env_list.len != 1) {
                            debug_inst.stopped_thread = null;
                            /* The exiting thread may wait for the signal */
                            os_cond_signal(&debug_inst.wait_cond);
                            os_mutex_unlock(&control_thread.wait_lock);
                            continue;
                        }
                    }

                    wasm_debug_instance_set_cur_thread(
                        debug_inst, debug_inst.stopped_thread.handle);

                    send_thread_stop_status(control_thread.server, status,
                                            tid);

                    debug_inst.current_state = APP_STOPPED;
                    debug_inst.stopped_thread = null;

                    if (status == 0) {
                        /* The exiting thread may wait for the signal */
                        os_cond_signal(&debug_inst.wait_cond);
                    }
                }

                /* Processing incoming requests */
                if (!wasm_gdbserver_handle_packet(control_thread.server)) {
                    control_thread.status = STOPPED;
                    LOG_ERROR("An error occurs when handling a packet\n");
                    os_mutex_unlock(&control_thread.wait_lock);
                    goto fail;
                }
            }
            else if (is_thread_detached(control_thread)) {
                os_mutex_unlock(&control_thread.wait_lock);
                break;
            }
            else if (is_thread_stopped(control_thread)) {
                os_mutex_unlock(&control_thread.wait_lock);
                return null;
            }
            os_mutex_unlock(&control_thread.wait_lock);
        }
    }
fail:
    wasm_debug_instance_on_failure(debug_inst);
    LOG_VERBOSE("control thread of debug object [%p] stopped with failure\n",
                debug_inst);
    return null;
}

private WASMDebugControlThread* wasm_debug_control_thread_create(WASMDebugInstance* debug_instance, int port) {
    WASMDebugControlThread* control_thread = void;

    if (((control_thread =
              wasm_runtime_malloc(WASMDebugControlThread.sizeof)) == 0)) {
        LOG_ERROR("WASM Debug Engine error: failed to allocate memory");
        return null;
    }
    memset(control_thread, 0, WASMDebugControlThread.sizeof);
    control_thread.port = port;

    if (os_mutex_init(&control_thread.wait_lock) != 0)
        goto fail;

    debug_instance.control_thread = control_thread;

    os_mutex_lock(&debug_instance.wait_lock);

    if (0
        != os_thread_create(&control_thread.tid, &control_thread_routine,
                            debug_instance, APP_THREAD_STACK_SIZE_DEFAULT)) {
        os_mutex_unlock(&debug_instance.wait_lock);
        goto fail1;
    }

    /* wait until the debug control thread ready */
    os_cond_wait(&debug_instance.wait_cond, &debug_instance.wait_lock);
    os_mutex_unlock(&debug_instance.wait_lock);
    if (!control_thread.server) {
        os_thread_join(control_thread.tid, null);
        goto fail1;
    }

    os_mutex_lock(&g_debug_engine.instance_list_lock);
    /* create control thread success, append debug instance to debug engine */
    bh_list_insert(&g_debug_engine.debug_instance_list, debug_instance);
    os_mutex_unlock(&g_debug_engine.instance_list_lock);

    /* If we set WAMR_SIG_STOP here, the VSCode debugger adaptor will raise an
     * exception in the UI. We use WAMR_SIG_SINGSTEP to avoid this exception for
     * better user experience */
    wasm_cluster_send_signal_all(debug_instance.cluster, WAMR_SIG_SINGSTEP);

    return control_thread;

fail1:
    os_mutex_destroy(&control_thread.wait_lock);
fail:
    wasm_runtime_free(control_thread);
    return null;
}

private void wasm_debug_control_thread_destroy(WASMDebugInstance* debug_instance) {
    WASMDebugControlThread* control_thread = debug_instance.control_thread;

    LOG_VERBOSE("stopping control thread of debug object [%p]\n",
                debug_instance);
    control_thread.status = STOPPED;
    os_mutex_lock(&control_thread.wait_lock);
    wasm_close_gdbserver(control_thread.server);
    os_mutex_unlock(&control_thread.wait_lock);
    os_thread_join(control_thread.tid, null);
    wasm_runtime_free(control_thread.server);

    os_mutex_destroy(&control_thread.wait_lock);
    wasm_runtime_free(control_thread);
}

private WASMDebugEngine* wasm_debug_engine_create() {
    WASMDebugEngine* engine = void;

    if (((engine = wasm_runtime_malloc(WASMDebugEngine.sizeof)) == 0)) {
        LOG_ERROR("WASM Debug Engine error: failed to allocate memory");
        return null;
    }
    memset(engine, 0, WASMDebugEngine.sizeof);

    if (os_mutex_init(&engine.instance_list_lock) != 0) {
        wasm_runtime_free(engine);
        LOG_ERROR("WASM Debug Engine error: failed to init mutex");
        return null;
    }

    /* reset current instance id */
    current_instance_id = 1;

    bh_list_init(&engine.debug_instance_list);
    return engine;
}

void wasm_debug_engine_destroy() {
    if (g_debug_engine) {
        wasm_debug_handler_deinit();
        os_mutex_destroy(&g_debug_engine.instance_list_lock);
        wasm_runtime_free(g_debug_engine);
        g_debug_engine = null;
    }
}

bool wasm_debug_engine_init(char* ip_addr, int process_port) {
    if (wasm_debug_handler_init() != 0) {
        return false;
    }

    if (g_debug_engine == null) {
        g_debug_engine = wasm_debug_engine_create();
    }

    if (g_debug_engine) {
        g_debug_engine.process_base_port =
            (process_port > 0) ? process_port : 0;
        if (ip_addr)
            snprintf(g_debug_engine.ip_addr, typeof(g_debug_engine.ip_addr).sizeof,
                     "%s", ip_addr.ptr);
        else
            snprintf(g_debug_engine.ip_addr, typeof(g_debug_engine.ip_addr).sizeof,
                     "%s", "127.0.0.1");
    }
    else {
        wasm_debug_handler_deinit();
    }

    return g_debug_engine != null ? true : false;
}

/* A debug Instance is a debug "process" in gdb remote protocol
   and bound to a runtime cluster */
WASMDebugInstance* wasm_debug_instance_create(WASMCluster* cluster, int port) {
    WASMDebugInstance* instance = void;
    WASMExecEnv* exec_env = null;
    wasm_module_inst_t module_inst = null;

    if (!g_debug_engine) {
        return null;
    }

    if (((instance = wasm_runtime_malloc(WASMDebugInstance.sizeof)) == 0)) {
        LOG_ERROR("WASM Debug Engine error: failed to allocate memory");
        return null;
    }
    memset(instance, 0, WASMDebugInstance.sizeof);

    if (os_mutex_init(&instance.wait_lock) != 0) {
        goto fail1;
    }

    if (os_cond_init(&instance.wait_cond) != 0) {
        goto fail2;
    }

    bh_list_init(&instance.break_point_list);
    bh_list_init(&instance.watch_point_list_read);
    bh_list_init(&instance.watch_point_list_write);

    instance.cluster = cluster;
    exec_env = bh_list_first_elem(&cluster.exec_env_list);
    bh_assert(exec_env);

    instance.current_tid = exec_env.handle;

    module_inst = wasm_runtime_get_module_inst(exec_env);
    bh_assert(module_inst);

    /* Allocate linear memory for evaluating expressions during debugging. If
     * the allocation failed, the debugger will not be able to evaluate
     * expressions */
    instance.exec_mem_info.size = DEBUG_EXECUTION_MEMORY_SIZE;
    instance.exec_mem_info.start_offset = wasm_runtime_module_malloc(
        module_inst, instance.exec_mem_info.size, null);
    if (instance.exec_mem_info.start_offset == 0) {
        LOG_WARNING(
            "WASM Debug Engine warning: failed to allocate linear memory for "
            ~ "execution. \n"
            ~ "Will not be able to evaluate expressions during "
            ~ "debugging");
    }
    instance.exec_mem_info.current_pos = instance.exec_mem_info.start_offset;

    if (!wasm_debug_control_thread_create(instance, port)) {
        LOG_ERROR("WASM Debug Engine error: failed to create control thread");
        goto fail3;
    }

    wasm_cluster_set_debug_inst(cluster, instance);

    return instance;

fail3:
    os_cond_destroy(&instance.wait_cond);
fail2:
    os_mutex_destroy(&instance.wait_lock);
fail1:
    wasm_runtime_free(instance);

    return null;
}

private void wasm_debug_instance_destroy_breakpoints(WASMDebugInstance* instance) {
    WASMDebugBreakPoint* breakpoint = void, next_bp = void;

    breakpoint = bh_list_first_elem(&instance.break_point_list);
    while (breakpoint) {
        next_bp = bh_list_elem_next(breakpoint);

        bh_list_remove(&instance.break_point_list, breakpoint);
        wasm_runtime_free(breakpoint);

        breakpoint = next_bp;
    }
}

private void wasm_debug_instance_destroy_watchpoints(WASMDebugInstance* instance, bh_list* watchpoints) {
    WASMDebugWatchPoint* watchpoint = void, next = void;

    watchpoint = bh_list_first_elem(watchpoints);
    while (watchpoint) {
        next = bh_list_elem_next(watchpoint);

        bh_list_remove(watchpoints, watchpoint);
        wasm_runtime_free(watchpoint);

        watchpoint = next;
    }
}

void wasm_debug_instance_destroy(WASMCluster* cluster) {
    WASMDebugInstance* instance = null;

    if (!g_debug_engine) {
        return;
    }

    instance = cluster.debug_inst;
    if (instance) {
        /* destroy control thread */
        wasm_debug_control_thread_destroy(instance);

        os_mutex_lock(&g_debug_engine.instance_list_lock);
        bh_list_remove(&g_debug_engine.debug_instance_list, instance);
        os_mutex_unlock(&g_debug_engine.instance_list_lock);

        /* destroy all breakpoints */
        wasm_debug_instance_destroy_breakpoints(instance);
        wasm_debug_instance_destroy_watchpoints(
            instance, &instance.watch_point_list_read);
        wasm_debug_instance_destroy_watchpoints(
            instance, &instance.watch_point_list_write);

        os_mutex_destroy(&instance.wait_lock);
        os_cond_destroy(&instance.wait_cond);

        wasm_runtime_free(instance);
        cluster.debug_inst = null;
    }
}

WASMExecEnv* wasm_debug_instance_get_current_env(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = null;

    if (instance) {
        exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
        while (exec_env) {
            if (exec_env.handle == instance.current_tid)
                break;
            exec_env = bh_list_elem_next(exec_env);
        }
    }
    return exec_env;
}

static if (WASM_ENABLE_LIBC_WASI != 0) {
bool wasm_debug_instance_get_current_object_name(WASMDebugInstance* instance, char* name_buffer, uint len) {
    WASMExecEnv* exec_env = void;
    WASIArguments* wasi_args = void;
    WASMModuleInstance* module_inst = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    wasi_args = &module_inst.module_.wasi_args;
    if (wasi_args && wasi_args.argc > 0) {
        char* argv_name = wasi_args.argv[0];
        uint name_len = cast(uint)strlen(argv_name);

        printf("the module name is %s\n", argv_name);
        if (len - 1 >= name_len)
            bh_strcpy_s(name_buffer, len, argv_name);
        else
            bh_strcpy_s(name_buffer, len, argv_name + (name_len + 1 - len));
        return true;
    }
    return false;
}
}

ulong wasm_debug_instance_get_pid(WASMDebugInstance* instance) {
    if (instance != null) {
        return cast(ulong)instance.id;
    }
    return cast(ulong)0;
}

korp_tid wasm_debug_instance_get_tid(WASMDebugInstance* instance) {
    if (instance != null) {
        return instance.current_tid;
    }
    return cast(korp_tid)cast(uintptr_t)0;
}

uint wasm_debug_instance_get_tids(WASMDebugInstance* instance, korp_tid* tids, uint len) {
    WASMExecEnv* exec_env = void;
    uint i = 0, threads_num = 0;

    if (!instance)
        return 0;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    while (exec_env && i < len) {
        /* Some threads may not be ready */
        if (exec_env.handle != 0) {
            tids[i++] = exec_env.handle;
            threads_num++;
        }
        exec_env = bh_list_elem_next(exec_env);
    }
    LOG_VERBOSE("find %d tids\n", threads_num);
    return threads_num;
}

uint wasm_debug_instance_get_thread_status(WASMDebugInstance* instance, korp_tid tid) {
    WASMExecEnv* exec_env = null;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    while (exec_env) {
        if (exec_env.handle == tid) {
            return cast(uint)exec_env.current_status.signal_flag;
        }
        exec_env = bh_list_elem_next(exec_env);
    }

    return 0;
}

void wasm_debug_instance_set_cur_thread(WASMDebugInstance* instance, korp_tid tid) {
    instance.current_tid = tid;
}

ulong wasm_debug_instance_get_pc(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return 0;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if ((exec_env != null) && (exec_env.cur_frame != null)
        && (exec_env.cur_frame.ip != null)) {
        WASMModuleInstance* module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
        return WASM_ADDR(
            WasmObj, instance.id,
            (exec_env.cur_frame.ip - module_inst.module_.load_addr));
    }
    return 0;
}

ulong wasm_debug_instance_get_load_addr(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return WASM_ADDR(WasmInvalid, 0, 0);

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (exec_env) {
        return WASM_ADDR(WasmObj, instance.id, 0);
    }

    return WASM_ADDR(WasmInvalid, 0, 0);
}

WASMDebugMemoryInfo* wasm_debug_instance_get_memregion(WASMDebugInstance* instance, ulong addr) {
    WASMDebugMemoryInfo* mem_info = void;
    WASMExecEnv* exec_env = void;
    WASMModuleInstance* module_inst = void;
    WASMMemoryInstance* memory = void;
    uint num_bytes_per_page = void;
    uint linear_mem_size = 0;

    if (!instance)
        return null;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return null;

    if (((mem_info = wasm_runtime_malloc(WASMDebugMemoryInfo.sizeof)) == 0)) {
        LOG_ERROR("WASM Debug Engine error: failed to allocate memory");
        return null;
    }
    memset(mem_info, 0, WASMDebugMemoryInfo.sizeof);
    mem_info.start = WASM_ADDR(WasmInvalid, 0, 0);
    mem_info.size = 0;
    mem_info.name[0] = '\0';
    mem_info.permisson[0] = '\0';

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;

    switch (WASM_ADDR_TYPE(addr)) {
        case WasmObj:
            if (WASM_ADDR_OFFSET(addr) < module_inst.module_.load_size) {
                mem_info.start = WASM_ADDR(WasmObj, instance.id, 0);
                mem_info.size = module_inst.module_.load_size;
                snprintf(mem_info.name, typeof(mem_info.name).sizeof, "%s",
                         "module");
                snprintf(mem_info.permisson, typeof(mem_info.permisson).sizeof, "%s",
                         "rx");
            }
            break;
        case WasmMemory:
        {
            memory = wasm_get_default_memory(module_inst);

            if (memory) {
                num_bytes_per_page = memory.num_bytes_per_page;
                linear_mem_size = num_bytes_per_page * memory.cur_page_count;
            }
            if (WASM_ADDR_OFFSET(addr) < linear_mem_size) {
                mem_info.start = WASM_ADDR(WasmMemory, instance.id, 0);
                mem_info.size = linear_mem_size;
                snprintf(mem_info.name, typeof(mem_info.name).sizeof, "%s",
                         "memory");
                snprintf(mem_info.permisson, typeof(mem_info.permisson).sizeof, "%s",
                         "rw");
            }
            break;
        }
        default:
            mem_info.start = WASM_ADDR(WasmInvalid, 0, 0);
            mem_info.size = 0;
    }
    return mem_info;
}

void wasm_debug_instance_destroy_memregion(WASMDebugInstance* instance, WASMDebugMemoryInfo* mem_info) {
    wasm_runtime_free(mem_info);
}

bool wasm_debug_instance_get_obj_mem(WASMDebugInstance* instance, ulong offset, char* buf, ulong* size) {
    WASMExecEnv* exec_env = void;
    WASMModuleInstance* module_inst = void;
    WASMDebugBreakPoint* breakpoint = void;
    WASMFastOPCodeNode* fast_opcode = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;

    if (offset + *size > module_inst.module_.load_size) {
        LOG_VERBOSE("wasm_debug_instance_get_data_mem size over flow!\n");
        *size = module_inst.module_.load_size >= offset
                    ? module_inst.module_.load_size - offset
                    : 0;
    }

    bh_memcpy_s(buf, (uint32)*size, module_inst.module_.load_addr + offset,
                (uint32)*size);

    breakpoint = bh_list_first_elem(&instance.break_point_list);
    while (breakpoint) {
        if (offset <= breakpoint.addr && breakpoint.addr < offset + *size) {
            bh_memcpy_s(buf + (breakpoint.addr - offset), break_instr.sizeof,
                        &breakpoint.orignal_data, break_instr.sizeof);
        }
        breakpoint = bh_list_elem_next(breakpoint);
    }

    fast_opcode = bh_list_first_elem(&module_inst.module_.fast_opcode_list);
    while (fast_opcode) {
        if (offset <= fast_opcode.offset
            && fast_opcode.offset < offset + *size) {
            *cast(ubyte*)(buf + (fast_opcode.offset - offset)) =
                fast_opcode.orig_op;
        }
        fast_opcode = bh_list_elem_next(fast_opcode);
    }

    return true;
}

bool wasm_debug_instance_get_linear_mem(WASMDebugInstance* instance, ulong offset, char* buf, ulong* size) {
    WASMExecEnv* exec_env = void;
    WASMModuleInstance* module_inst = void;
    WASMMemoryInstance* memory = void;
    uint num_bytes_per_page = void;
    uint linear_mem_size = void;

    if (!instance)
        return false;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if (!exec_env)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    memory = wasm_get_default_memory(module_inst);
    if (memory) {
        num_bytes_per_page = memory.num_bytes_per_page;
        linear_mem_size = num_bytes_per_page * memory.cur_page_count;
        if (offset + *size > linear_mem_size) {
            LOG_VERBOSE("wasm_debug_instance_get_linear_mem size over flow!\n");
            *size = linear_mem_size >= offset ? linear_mem_size - offset : 0;
        }
        bh_memcpy_s(buf, (uint32)*size, memory.memory_data + offset,
                    (uint32)*size);
        return true;
    }
    return false;
}

bool wasm_debug_instance_set_linear_mem(WASMDebugInstance* instance, ulong offset, char* buf, ulong* size) {
    WASMExecEnv* exec_env = void;
    WASMModuleInstance* module_inst = void;
    WASMMemoryInstance* memory = void;
    uint num_bytes_per_page = void;
    uint linear_mem_size = void;

    if (!instance)
        return false;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if (!exec_env)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    memory = wasm_get_default_memory(module_inst);
    if (memory) {
        num_bytes_per_page = memory.num_bytes_per_page;
        linear_mem_size = num_bytes_per_page * memory.cur_page_count;
        if (offset + *size > linear_mem_size) {
            LOG_VERBOSE("wasm_debug_instance_get_linear_mem size over flow!\n");
            *size = linear_mem_size >= offset ? linear_mem_size - offset : 0;
        }
        bh_memcpy_s(memory.memory_data + offset, (uint32)*size, buf,
                    (uint32)*size);
        return true;
    }
    return false;
}

bool wasm_debug_instance_get_mem(WASMDebugInstance* instance, ulong addr, char* buf, ulong* size) {
    switch (WASM_ADDR_TYPE(addr)) {
        case WasmMemory:
            return wasm_debug_instance_get_linear_mem(
                instance, WASM_ADDR_OFFSET(addr), buf, size);
            break;
        case WasmObj:
            return wasm_debug_instance_get_obj_mem(
                instance, WASM_ADDR_OFFSET(addr), buf, size);
            break;
        default:
            return false;
    }
}

bool wasm_debug_instance_set_mem(WASMDebugInstance* instance, ulong addr, char* buf, ulong* size) {
    switch (WASM_ADDR_TYPE(addr)) {
        case WasmMemory:
            return wasm_debug_instance_set_linear_mem(
                instance, WASM_ADDR_OFFSET(addr), buf, size);
            break;
        case WasmObj:
        default:
            return false;
    }
}

WASMDebugInstance* wasm_exec_env_get_instance(WASMExecEnv* exec_env) {
    WASMDebugInstance* instance = null;

    if (!g_debug_engine) {
        return null;
    }

    os_mutex_lock(&g_debug_engine.instance_list_lock);
    instance = bh_list_first_elem(&g_debug_engine.debug_instance_list);
    while (instance) {
        if (instance.cluster == exec_env.cluster)
            break;
        instance = bh_list_elem_next(instance);
    }

    os_mutex_unlock(&g_debug_engine.instance_list_lock);
    return instance;
}

uint wasm_debug_instance_get_call_stack_pcs(WASMDebugInstance* instance, korp_tid tid, ulong* buf, ulong size) {
    WASMExecEnv* exec_env = void;
    WASMInterpFrame* frame = void;
    uint i = 0;

    if (!instance)
        return 0;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    while (exec_env) {
        if (exec_env.handle == tid) {
            WASMModuleInstance* module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
            frame = exec_env.cur_frame;
            while (frame && i < size) {
                if (frame.ip != null) {
                    buf[i++] =
                        WASM_ADDR(WasmObj, instance.id,
                                  (frame.ip - module_inst.module_.load_addr));
                }
                frame = frame.prev_frame;
            }
            return i;
        }
        exec_env = bh_list_elem_next(exec_env);
    }
    return 0;
}

bool wasm_debug_instance_add_breakpoint(WASMDebugInstance* instance, ulong addr, ulong length) {
    WASMExecEnv* exec_env = void;
    WASMModuleInstance* module_inst = void;
    ulong offset = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    if (WASM_ADDR_TYPE(addr) != WasmObj)
        return false;

    offset = WASM_ADDR_OFFSET(addr);

    if (length >= break_instr.sizeof) {
        if (offset + break_instr.sizeof <= module_inst.module_.load_size) {
            WASMDebugBreakPoint* breakpoint = void;
            if (((breakpoint =
                      wasm_runtime_malloc(WASMDebugBreakPoint.sizeof)) == 0)) {
                LOG_ERROR("WASM Debug Engine error: failed to allocate memory");
                return false;
            }
            memset(breakpoint, 0, WASMDebugBreakPoint.sizeof);
            breakpoint.addr = offset;
            /* TODO: how to if more than one breakpoints are set
                     at the same addr? */
            bh_memcpy_s(&breakpoint.orignal_data, cast(uint)break_instr.sizeof,
                        module_inst.module_.load_addr + offset,
                        cast(uint)break_instr.sizeof);

            bh_memcpy_s(module_inst.module_.load_addr + offset,
                        cast(uint)break_instr.sizeof, break_instr.ptr,
                        cast(uint)break_instr.sizeof);

            bh_list_insert(&instance.break_point_list, breakpoint);
            return true;
        }
    }
    return false;
}

bool wasm_debug_instance_remove_breakpoint(WASMDebugInstance* instance, ulong addr, ulong length) {
    WASMExecEnv* exec_env = void;
    WASMModuleInstance* module_inst = void;
    ulong offset = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;

    if (WASM_ADDR_TYPE(addr) != WasmObj)
        return false;
    offset = WASM_ADDR_OFFSET(addr);

    if (length >= break_instr.sizeof) {
        if (offset + break_instr.sizeof <= module_inst.module_.load_size) {
            WASMDebugBreakPoint* breakpoint = bh_list_first_elem(&instance.break_point_list);
            while (breakpoint) {
                WASMDebugBreakPoint* next_break = bh_list_elem_next(breakpoint);
                if (breakpoint.addr == offset) {
                    /* TODO: how to if more than one breakpoints are set
                       at the same addr? */
                    bh_memcpy_s(module_inst.module_.load_addr + offset,
                                cast(uint)break_instr.sizeof,
                                &breakpoint.orignal_data,
                                cast(uint)break_instr.sizeof);
                    bh_list_remove(&instance.break_point_list, breakpoint);
                    wasm_runtime_free(breakpoint);
                }
                breakpoint = next_break;
            }
        }
    }
    return true;
}

private bool add_watchpoint(bh_list* list, ulong addr, ulong length) {
    WASMDebugWatchPoint* watchpoint = void;
    if (((watchpoint = wasm_runtime_malloc(WASMDebugWatchPoint.sizeof)) == 0)) {
        LOG_ERROR("WASM Debug Engine error: failed to allocate memory for "
                  ~ "watchpoint");
        return false;
    }
    memset(watchpoint, 0, WASMDebugWatchPoint.sizeof);
    watchpoint.addr = addr;
    watchpoint.length = length;
    bh_list_insert(list, watchpoint);
    return true;
}

private bool remove_watchpoint(bh_list* list, ulong addr, ulong length) {
    WASMDebugWatchPoint* watchpoint = bh_list_first_elem(list);
    while (watchpoint) {
        WASMDebugWatchPoint* next = bh_list_elem_next(watchpoint);
        if (watchpoint.addr == addr && watchpoint.length == length) {
            bh_list_remove(list, watchpoint);
            wasm_runtime_free(watchpoint);
        }
        watchpoint = next;
    }
    return true;
}

bool wasm_debug_instance_watchpoint_write_add(WASMDebugInstance* instance, ulong addr, ulong length) {
    return add_watchpoint(&instance.watch_point_list_write, addr, length);
}

bool wasm_debug_instance_watchpoint_write_remove(WASMDebugInstance* instance, ulong addr, ulong length) {
    return remove_watchpoint(&instance.watch_point_list_write, addr, length);
}

bool wasm_debug_instance_watchpoint_read_add(WASMDebugInstance* instance, ulong addr, ulong length) {
    return add_watchpoint(&instance.watch_point_list_read, addr, length);
}

bool wasm_debug_instance_watchpoint_read_remove(WASMDebugInstance* instance, ulong addr, ulong length) {
    return remove_watchpoint(&instance.watch_point_list_read, addr, length);
}

bool wasm_debug_instance_on_failure(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    os_mutex_lock(&instance.wait_lock);
    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env) {
        os_mutex_unlock(&instance.wait_lock);
        return false;
    }

    if (instance.stopped_thread == null
        && instance.current_state == DBG_LAUNCHING) {
        /* if fail in start stage: may need wait for main thread to notify it */
        os_cond_wait(&instance.wait_cond, &instance.wait_lock);
    }
    instance.current_state = DBG_ERROR;
    instance.stopped_thread = null;

    /* terminate the wasm execution thread */
    while (exec_env) {
        /* Resume all threads so they can receive the TERM signal */
        os_mutex_lock(&exec_env.wait_lock);
        wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TERM);
        exec_env.current_status.running_status = STATUS_RUNNING;
        os_cond_signal(&exec_env.wait_cond);
        os_mutex_unlock(&exec_env.wait_lock);
        exec_env = bh_list_elem_next(exec_env);
    }
    os_mutex_unlock(&instance.wait_lock);

    return true;
}

bool wasm_debug_instance_continue(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    if (instance.current_state == APP_RUNNING) {
        LOG_VERBOSE("Already in running state, ignore continue request");
        return false;
    }

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    while (exec_env) {
        wasm_cluster_thread_continue(exec_env);
        exec_env = bh_list_elem_next(exec_env);
    }

    instance.current_state = APP_RUNNING;

    return true;
}

bool wasm_debug_instance_interrupt_all_threads(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    while (exec_env) {
        wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP);
        exec_env = bh_list_elem_next(exec_env);
    }
    return true;
}

bool wasm_debug_instance_detach(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    wasm_gdbserver_detach(instance.control_thread.server);

    while (exec_env) {
        if (instance.current_state == APP_STOPPED) {
            /* Resume all threads since remote debugger detached*/
            wasm_cluster_thread_continue(exec_env);
        }
        exec_env = bh_list_elem_next(exec_env);
    }

    /* relaunch, accept new debug connection */
    instance.current_state = DBG_LAUNCHING;
    instance.control_thread.status = DETACHED;
    instance.stopped_thread = null;

    return true;
}

bool wasm_debug_instance_kill(WASMDebugInstance* instance) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    while (exec_env) {
        wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TERM);
        if (instance.current_state == APP_STOPPED) {
            /* Resume all threads so they can receive the TERM signal */
            os_mutex_lock(&exec_env.wait_lock);
            exec_env.current_status.running_status = STATUS_RUNNING;
            os_cond_signal(&exec_env.wait_cond);
            os_mutex_unlock(&exec_env.wait_lock);
        }
        exec_env = bh_list_elem_next(exec_env);
    }

    instance.current_state = APP_RUNNING;
    return true;
}

bool wasm_debug_instance_singlestep(WASMDebugInstance* instance, korp_tid tid) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    if (instance.current_state == APP_RUNNING) {
        LOG_VERBOSE("Already in running state, ignore step request");
        return false;
    }

    exec_env = bh_list_first_elem(&instance.cluster.exec_env_list);
    if (!exec_env)
        return false;

    while (exec_env) {
        if (exec_env.handle == tid || tid == cast(korp_tid)cast(uintptr_t)~0LL) {
            wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_SINGSTEP);
            wasm_cluster_thread_step(exec_env);
        }
        exec_env = bh_list_elem_next(exec_env);
    }

    instance.current_state = APP_RUNNING;

    return true;
}

bool wasm_debug_instance_get_local(WASMDebugInstance* instance, int frame_index, int local_index, char* buf, int* size) {
    WASMExecEnv* exec_env = void;
    WASMInterpFrame* frame = void;
    WASMFunctionInstance* cur_func = void;
    ubyte local_type = 0xFF;
    uint local_offset = void;
    int param_count = void;
    int fi = 0;

    if (!instance)
        return false;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if (!exec_env)
        return false;

    frame = exec_env.cur_frame;
    while (frame && fi++ != frame_index) {
        frame = frame.prev_frame;
    }

    if (!frame)
        return false;
    cur_func = frame.function_;
    if (!cur_func)
        return false;

    param_count = cur_func.param_count;

    if (local_index >= param_count + cur_func.local_count)
        return false;

    local_offset = cur_func.local_offsets[local_index];
    if (local_index < param_count)
        local_type = cur_func.param_types[local_index];
    else if (local_index < cur_func.local_count + param_count)
        local_type = cur_func.local_types[local_index - param_count];

    switch (local_type) {
        case VALUE_TYPE_I32:
        case VALUE_TYPE_F32:
            *size = 4;
            bh_memcpy_s(buf, 4, cast(char*)(frame.lp + local_offset), 4);
            break;
        case VALUE_TYPE_I64:
        case VALUE_TYPE_F64:
            *size = 8;
            bh_memcpy_s(buf, 8, cast(char*)(frame.lp + local_offset), 8);
            break;
        default:
            *size = 0;
            break;
    }
    return true;
}

bool wasm_debug_instance_get_global(WASMDebugInstance* instance, int frame_index, int global_index, char* buf, int* size) {
    WASMExecEnv* exec_env = void;
    WASMInterpFrame* frame = void;
    WASMModuleInstance* module_inst = void;
    WASMGlobalInstance* globals = void, global = void;
    ubyte* global_addr = void;
    ubyte global_type = 0xFF;
    ubyte* global_data = void;
    int fi = 0;

    if (!instance)
        return false;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if (!exec_env)
        return false;

    frame = exec_env.cur_frame;
    while (frame && fi++ != frame_index) {
        frame = frame.prev_frame;
    }

    if (!frame)
        return false;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    global_data = module_inst.global_data;
    globals = module_inst.e.globals;

    if ((global_index < 0)
        || (cast(uint)global_index >= module_inst.e.global_count)) {
        return false;
    }
    global = globals + global_index;

static if (WASM_ENABLE_MULTI_MODULE == 0) {
    global_addr = global_data + global.data_offset;
} else {
    global_addr = global.import_global_inst
                      ? global.import_module_inst.global_data
                            + global.import_global_inst.data_offset
                      : global_data + global.data_offset;
}
    global_type = global.type;

    switch (global_type) {
        case VALUE_TYPE_I32:
        case VALUE_TYPE_F32:
            *size = 4;
            bh_memcpy_s(buf, 4, cast(char*)(global_addr), 4);
            break;
        case VALUE_TYPE_I64:
        case VALUE_TYPE_F64:
            *size = 8;
            bh_memcpy_s(buf, 8, cast(char*)(global_addr), 8);
            break;
        default:
            *size = 0;
            break;
    }
    return true;
}

ulong wasm_debug_instance_mmap(WASMDebugInstance* instance, uint size, int map_prot) {
    WASMExecEnv* exec_env = void;
    uint offset = 0;
    cast(void)map_prot;

    if (!instance)
        return 0;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if (!exec_env)
        return 0;

    if (instance.exec_mem_info.start_offset == 0) {
        return 0;
    }

    if (cast(ulong)instance.exec_mem_info.current_pos
            - instance.exec_mem_info.start_offset + size
        <= cast(ulong)instance.exec_mem_info.size) {
        offset = instance.exec_mem_info.current_pos;
        instance.exec_mem_info.current_pos += size;
    }

    if (offset == 0) {
        LOG_WARNING("the memory may be not enough for debug, try use larger "
                    ~ "--heap-size");
        return 0;
    }

    return WASM_ADDR(WasmMemory, 0, offset);
}

bool wasm_debug_instance_ummap(WASMDebugInstance* instance, ulong addr) {
    WASMExecEnv* exec_env = void;

    if (!instance)
        return false;

    exec_env = wasm_debug_instance_get_current_env(instance);
    if (!exec_env)
        return false;

    if (instance.exec_mem_info.start_offset == 0) {
        return false;
    }

    cast(void)addr;

    /* Currently we don't support to free the execution memory, simply return
     * true here */
    return true;
}
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_list;
public import gdbserver;
public import thread_manager;

enum WASMDebugControlThreadStatus {
    RUNNING,
    DETACHED,
    STOPPED,
}
alias RUNNING = WASMDebugControlThreadStatus.RUNNING;
alias DETACHED = WASMDebugControlThreadStatus.DETACHED;
alias STOPPED = WASMDebugControlThreadStatus.STOPPED;


struct WASMDebugEngine;
struct WASMDebugInstance;

struct WASMDebugControlThread {
    WASMGDBServer* server;
    korp_tid tid;
    korp_mutex wait_lock;
    char[128] ip_addr = 0;
    int port;
    WASMDebugControlThreadStatus status;
    WASMDebugEngine* debug_engine;
    WASMDebugInstance* debug_instance;
}

struct WASMDebugBreakPoint {
    WASMDebugBreakPoint* next;
    ulong addr;
    ulong orignal_data;
}

struct WASMDebugWatchPoint {
    bh_list_link next;
    ulong addr;
    ulong length;
}

enum debug_state_t {
    /* Debugger state conversion sequence:
     *   DBG_LAUNCHING ---> APP_STOPPED <---> APP_RUNNING
     */
    DBG_LAUNCHING,
    APP_RUNNING,
    APP_STOPPED,
    DBG_ERROR
}
alias DBG_LAUNCHING = debug_state_t.DBG_LAUNCHING;
alias APP_RUNNING = debug_state_t.APP_RUNNING;
alias APP_STOPPED = debug_state_t.APP_STOPPED;
alias DBG_ERROR = debug_state_t.DBG_ERROR;


struct WASMDebugExecutionMemory {
    uint start_offset;
    uint size;
    uint current_pos;
}

struct WASMDebugInstance {
    WASMDebugInstance* next;
    WASMDebugControlThread* control_thread;
    bh_list break_point_list;
    bh_list watch_point_list_read;
    bh_list watch_point_list_write;
    WASMCluster* cluster;
    uint id;
    korp_tid current_tid;
    korp_mutex wait_lock;
    korp_cond wait_cond;
    /* Last stopped thread, it should be set to NULL when sending
     * out the thread stop reply */
    WASMExecEnv* stopped_thread;
    /* Currently status of the debug instance, it will be set to
     * RUNNING when receiving STEP/CONTINUE commands, and set to
     * STOPPED when any thread stopped */
    /*volatile*/ debug_state_t current_state;
    /* Execution memory info. During debugging, the debug client may request to
     * malloc a memory space to evaluate user expressions. We preserve a buffer
     * during creating debug instance, and use a simple bump pointer allocator
     * to serve lldb's memory request */
    WASMDebugExecutionMemory exec_mem_info;
}

enum WASMDebugEventKind {
    BREAK_POINT_ADD,
    BREAK_POINT_REMOVE
}
alias BREAK_POINT_ADD = WASMDebugEventKind.BREAK_POINT_ADD;
alias BREAK_POINT_REMOVE = WASMDebugEventKind.BREAK_POINT_REMOVE;


struct WASMDebugEvent {
    WASMDebugEventKind kind;
    ubyte[0] metadata;
}

struct WASMDebugMemoryInfo {
    ulong start;
    ulong size;
    char[128] name = 0;
    char[4] permisson = 0;
}

enum WasmAddressType {
    WasmMemory = 0x00,
    WasmObj = 0x01,
    WasmInvalid = 0x03
}
alias WasmMemory = WasmAddressType.WasmMemory;
alias WasmObj = WasmAddressType.WasmObj;
alias WasmInvalid = WasmAddressType.WasmInvalid;


enum string WASM_ADDR(string type, string id, string offset) = ` \
    (((uint64)type << 62) | ((uint64)0 << 32) | ((uint64)offset << 0))`;

enum string WASM_ADDR_TYPE(string addr) = ` (((addr)&0xC000000000000000) >> 62)`;
enum string WASM_ADDR_OFFSET(string addr) = ` (((addr)&0x00000000FFFFFFFF))`;

enum INVALIED_ADDR = (0xFFFFFFFFFFFFFFFF);

void on_thread_stop_event(WASMDebugInstance* debug_inst, WASMExecEnv* exec_env);

void on_thread_exit_event(WASMDebugInstance* debug_inst, WASMExecEnv* exec_env);

WASMDebugInstance* wasm_debug_instance_create(WASMCluster* cluster, int port);

void wasm_debug_instance_destroy(WASMCluster* cluster);

WASMDebugInstance* wasm_exec_env_get_instance(WASMExecEnv* exec_env);

bool wasm_debug_engine_init(char* ip_addr, int process_port);

void wasm_debug_engine_destroy();

WASMExecEnv* wasm_debug_instance_get_current_env(WASMDebugInstance* instance);

ulong wasm_debug_instance_get_pid(WASMDebugInstance* instance);

korp_tid wasm_debug_instance_get_tid(WASMDebugInstance* instance);

uint wasm_debug_instance_get_tids(WASMDebugInstance* instance, korp_tid* tids, uint len);

void wasm_debug_instance_set_cur_thread(WASMDebugInstance* instance, korp_tid tid);

ulong wasm_debug_instance_get_pc(WASMDebugInstance* instance);

ulong wasm_debug_instance_get_load_addr(WASMDebugInstance* instance);

WASMDebugMemoryInfo* wasm_debug_instance_get_memregion(WASMDebugInstance* instance, ulong addr);

void wasm_debug_instance_destroy_memregion(WASMDebugInstance* instance, WASMDebugMemoryInfo* mem_info);

bool wasm_debug_instance_get_obj_mem(WASMDebugInstance* instance, ulong addr, char* buf, ulong* size);

bool wasm_debug_instance_get_linear_mem(WASMDebugInstance* instance, ulong addr, char* buf, ulong* size);

bool wasm_debug_instance_get_mem(WASMDebugInstance* instance, ulong addr, char* buf, ulong* size);

bool wasm_debug_instance_set_mem(WASMDebugInstance* instance, ulong addr, char* buf, ulong* size);

uint wasm_debug_instance_get_call_stack_pcs(WASMDebugInstance* instance, korp_tid tid, ulong* buf, ulong size);

bool wasm_debug_instance_add_breakpoint(WASMDebugInstance* instance, ulong addr, ulong length);

bool wasm_debug_instance_remove_breakpoint(WASMDebugInstance* instance, ulong addr, ulong length);

bool wasm_debug_instance_watchpoint_write_add(WASMDebugInstance* instance, ulong addr, ulong length);

bool wasm_debug_instance_watchpoint_write_remove(WASMDebugInstance* instance, ulong addr, ulong length);

bool wasm_debug_instance_watchpoint_read_add(WASMDebugInstance* instance, ulong addr, ulong length);

bool wasm_debug_instance_watchpoint_read_remove(WASMDebugInstance* instance, ulong addr, ulong length);

bool wasm_debug_instance_on_failure(WASMDebugInstance* instance);

bool wasm_debug_instance_interrupt_all_threads(WASMDebugInstance* instance);

bool wasm_debug_instance_continue(WASMDebugInstance* instance);

bool wasm_debug_instance_detach(WASMDebugInstance* instance);

bool wasm_debug_instance_kill(WASMDebugInstance* instance);

uint wasm_debug_instance_get_thread_status(WASMDebugInstance* instance, korp_tid tid);

bool wasm_debug_instance_singlestep(WASMDebugInstance* instance, korp_tid tid);

bool wasm_debug_instance_get_local(WASMDebugInstance* instance, int frame_index, int local_index, char* buf, int* size);

bool wasm_debug_instance_get_global(WASMDebugInstance* instance, int frame_index, int global_index, char* buf, int* size);

static if (WASM_ENABLE_LIBC_WASI != 0) {
bool wasm_debug_instance_get_current_object_name(WASMDebugInstance* instance, char* name_buffer, uint len);
}

ulong wasm_debug_instance_mmap(WASMDebugInstance* instance, uint size, int map_prot);

bool wasm_debug_instance_ummap(WASMDebugInstance* instance, ulong addr);

