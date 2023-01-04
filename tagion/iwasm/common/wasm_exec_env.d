module tagion.iwasm.common.wasm_exec_env;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import tagion.iwasm.common.wasm_runtime_common;
static if (WASM_ENABLE_INTERP != 0) {
public import tagion.iwasm.interpreter.wasm_runtime;
}
static if (WASM_ENABLE_AOT != 0) {
public import tagion.aot.aot.aot_runtime;
}


static if (WASM_ENABLE_THREAD_MGR != 0) {
public import tagion.iwasm.libraries.thread_mgr.thread_manager;
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
public import tagion.iwasm.libraries.debug_engine.debug_engine;
}
}

WASMExecEnv* wasm_exec_env_create_internal(WASMModuleInstanceCommon* module_inst, uint stack_size) {
    ulong total_size = offsetof(WASMExecEnv, wasm_stack.s.bottom) + cast(ulong)stack_size;
    WASMExecEnv* exec_env = void;

    if (total_size >= UINT32_MAX
        || ((exec_env = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return null;

    memset(exec_env, 0, cast(uint)total_size);

static if (WASM_ENABLE_AOT != 0) {
    if (((exec_env.argv_buf = wasm_runtime_malloc(uint.sizeof * 64)) == 0)) {
        goto fail1;
    }
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
    if (os_mutex_init(&exec_env.wait_lock) != 0)
        goto fail2;

    if (os_cond_init(&exec_env.wait_cond) != 0)
        goto fail3;

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    if (((exec_env.current_status = wasm_cluster_create_exenv_status()) == 0))
        goto fail4;
}
}

version (OS_ENABLE_HW_BOUND_CHECK) {
    if (((exec_env.exce_check_guard_page =
              os_mmap(null, os_getpagesize(), MMAP_PROT_NONE, MMAP_MAP_NONE)) == 0))
        goto fail5;
}

    exec_env.module_inst = module_inst;
    exec_env.wasm_stack_size = stack_size;
    exec_env.wasm_stack.s.top_boundary =
        exec_env.wasm_stack.s.bottom + stack_size;
    exec_env.wasm_stack.s.top = exec_env.wasm_stack.s.bottom;

static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* i = cast(AOTModuleInstance*)module_inst;
        AOTModule* m = cast(AOTModule*)i.module_;
        exec_env.native_symbol = m.native_symbol_list;
    }
}

static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    wasm_runtime_dump_exec_env_mem_consumption(exec_env);
}

    return exec_env;

version (OS_ENABLE_HW_BOUND_CHECK) {
fail5:
static if (WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0) {
    wasm_cluster_destroy_exenv_status(exec_env.current_status);
}
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
fail4:
    os_cond_destroy(&exec_env.wait_cond);
}
fail3:
    os_mutex_destroy(&exec_env.wait_lock);
fail2:
}
static if (WASM_ENABLE_AOT != 0) {
    wasm_runtime_free(exec_env.argv_buf);
fail1:
}
    wasm_runtime_free(exec_env);
    return null;
}

void wasm_exec_env_destroy_internal(WASMExecEnv* exec_env) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    os_munmap(exec_env.exce_check_guard_page, os_getpagesize());
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
    os_mutex_destroy(&exec_env.wait_lock);
    os_cond_destroy(&exec_env.wait_cond);
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    wasm_cluster_destroy_exenv_status(exec_env.current_status);
}
}
static if (WASM_ENABLE_AOT != 0) {
    wasm_runtime_free(exec_env.argv_buf);
}
    wasm_runtime_free(exec_env);
}

WASMExecEnv* wasm_exec_env_create(WASMModuleInstanceCommon* module_inst, uint stack_size) {
static if (WASM_ENABLE_THREAD_MGR != 0) {
    WASMCluster* cluster = void;
}
    WASMExecEnv* exec_env = wasm_exec_env_create_internal(module_inst, stack_size);

    if (!exec_env)
        return null;

static if (WASM_ENABLE_INTERP != 0) {
    /* Set the aux_stack_boundary and aux_stack_bottom */
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        WASMModule* module_ = (cast(WASMModuleInstance*)module_inst).module_;
        exec_env.aux_stack_bottom.bottom = module_.aux_stack_bottom;
        exec_env.aux_stack_boundary.boundary =
            module_.aux_stack_bottom - module_.aux_stack_size;
    }
}
static if (WASM_ENABLE_AOT != 0) {
    /* Set the aux_stack_boundary and aux_stack_bottom */
    if (module_inst.module_type == Wasm_Module_AoT) {
        AOTModule* module_ = cast(AOTModule*)(cast(AOTModuleInstance*)module_inst).module_;
        exec_env.aux_stack_bottom.bottom = module_.aux_stack_bottom;
        exec_env.aux_stack_boundary.boundary =
            module_.aux_stack_bottom - module_.aux_stack_size;
    }
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
    /* Create a new cluster for this exec_env */
    if (((cluster = wasm_cluster_create(exec_env)) == 0)) {
        wasm_exec_env_destroy_internal(exec_env);
        return null;
    }
} /* end of WASM_ENABLE_THREAD_MGR */

    return exec_env;
}

void wasm_exec_env_destroy(WASMExecEnv* exec_env) {
static if (WASM_ENABLE_THREAD_MGR != 0) {
    /* Terminate all sub-threads */
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    if (cluster) {
        wasm_cluster_terminate_all_except_self(cluster, exec_env);
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
        /* Must fire exit event after other threads exits, otherwise
           the stopped thread will be overrided by other threads */
        wasm_cluster_thread_exited(exec_env);
}
        wasm_cluster_del_exec_env(cluster, exec_env);
    }
} /* end of WASM_ENABLE_THREAD_MGR */

    wasm_exec_env_destroy_internal(exec_env);
}

WASMModuleInstanceCommon* wasm_exec_env_get_module_inst(WASMExecEnv* exec_env) {
    return exec_env.module_inst;
}

void wasm_exec_env_set_module_inst(WASMExecEnv* exec_env, WASMModuleInstanceCommon* module_inst) {
    exec_env.module_inst = module_inst;
}

void wasm_exec_env_set_thread_info(WASMExecEnv* exec_env) {
    ubyte* stack_boundary = os_thread_get_stack_boundary();
    exec_env.handle = os_self_thread();
    exec_env.native_stack_boundary =
        stack_boundary ? stack_boundary + WASM_STACK_GUARD_SIZE : null;
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
void* wasm_exec_env_get_thread_arg(WASMExecEnv* exec_env) {
    return exec_env.thread_arg;
}

void wasm_exec_env_set_thread_arg(WASMExecEnv* exec_env, void* thread_arg) {
    exec_env.thread_arg = thread_arg;
}
}

version (OS_ENABLE_HW_BOUND_CHECK) {
void wasm_exec_env_push_jmpbuf(WASMExecEnv* exec_env, WASMJmpBuf* jmpbuf) {
    jmpbuf.prev = exec_env.jmpbuf_stack_top;
    exec_env.jmpbuf_stack_top = jmpbuf;
}

WASMJmpBuf* wasm_exec_env_pop_jmpbuf(WASMExecEnv* exec_env) {
    WASMJmpBuf* stack_top = exec_env.jmpbuf_stack_top;

    if (stack_top) {
        exec_env.jmpbuf_stack_top = stack_top.prev;
        return stack_top;
    }

    return null;
}
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import tagion.iwasm.share.utils.bh_assert;
static if (WASM_ENABLE_INTERP != 0) {
public import tagion.iwasm.interpreter.wasm;
}


version (OS_ENABLE_HW_BOUND_CHECK) {
struct WASMJmpBuf {
    WASMJmpBuf* prev;
    korp_jmpbuf jmpbuf;
}
}

/* Execution environment */
struct WASMExecEnv {
    /* Next thread's exec env of a WASM module instance. */
    WASMExecEnv* next;

    /* Previous thread's exec env of a WASM module instance. */
    WASMExecEnv* prev;

    /* Note: field module_inst, argv_buf, native_stack_boundary,
       suspend_flags, aux_stack_boundary, aux_stack_bottom, and
       native_symbol are used by AOTed code, don't change the
       places of them */

    /* The WASM module instance of current thread */
    WASMModuleInstanceCommon* module_inst;

static if (WASM_ENABLE_AOT != 0) {
    uint* argv_buf;
}

    /* The boundary of native stack. When runtime detects that native
       frame may overrun this boundary, it throws stack overflow
       exception. */
    ubyte* native_stack_boundary;

    /* Used to terminate or suspend current thread
        bit 0: need to terminate
        bit 1: need to suspend
        bit 2: need to go into breakpoint
        bit 3: return from pthread_exit */
    union _Suspend_flags {
        uint flags;
        uintptr_t __padding__;
    }_Suspend_flags suspend_flags;

    /* Auxiliary stack boundary */
    union _Aux_stack_boundary {
        uint boundary;
        uintptr_t __padding__;
    }_Aux_stack_boundary aux_stack_boundary;

    /* Auxiliary stack bottom */
    union _Aux_stack_bottom {
        uint bottom;
        uintptr_t __padding__;
    }_Aux_stack_bottom aux_stack_bottom;

static if (WASM_ENABLE_AOT != 0) {
    /* Native symbol list, reserved */
    void** native_symbol;
}

static if (WASM_ENABLE_FAST_JIT != 0) {
    /**
     * Cache for
     * - jit native operations in 32-bit target which hasn't 64-bit
     *   int/float registers, mainly for the operations of double and int64,
     *   such as F64TOI64, F32TOI64, I64 MUL/REM, and so on.
     * - SSE instructions.
     **/
    ulong[2] jit_cache;
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
    /* thread return value */
    void* thread_ret_value;

    /* Must be provided by thread library */
    void* function(void*) thread_start_routine;
    void* thread_arg;

    /* pointer to the cluster */
    WASMCluster* cluster;

    /* used to support debugger */
    korp_mutex wait_lock;
    korp_cond wait_cond;
    /* the count of threads which are joining current thread */
    uint wait_count;

    /* whether current thread is detached */
    bool thread_is_detached;
}

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    WASMCurrentEnvStatus* current_status;
}

    /* attachment for native function */
    void* attachment;

    void* user_data;

    /* Current interpreter frame of current thread */
    WASMInterpFrame* cur_frame;

    /* The native thread handle of current thread */
    korp_tid handle;

static if (WASM_ENABLE_INTERP != 0 && WASM_ENABLE_FAST_INTERP == 0) {
    BlockAddr[BLOCK_ADDR_CONFLICT_SIZE][BLOCK_ADDR_CACHE_SIZE] block_addr_cache;
}

version (OS_ENABLE_HW_BOUND_CHECK) {
    WASMJmpBuf* jmpbuf_stack_top;
    /* One guard page for the exception check */
    ubyte* exce_check_guard_page;
}

static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
    uint max_wasm_stack_used;
}

    /* The WASM stack size */
    uint wasm_stack_size;

    /* The WASM stack of current thread */
    union _Wasm_stack {
        ulong __make_it_8_byte_aligned_;

        struct _S {
            /* The top boundary of the stack. */
            ubyte* top_boundary;

            /* Top cell index which is free. */
            ubyte* top;

            /* The WASM stack. */
            ubyte[1] bottom;
        }_S s;
    }_Wasm_stack wasm_stack;
}

WASMExecEnv* wasm_exec_env_create_internal(WASMModuleInstanceCommon* module_inst, uint stack_size);

void wasm_exec_env_destroy_internal(WASMExecEnv* exec_env);

WASMExecEnv* wasm_exec_env_create(WASMModuleInstanceCommon* module_inst, uint stack_size);

void wasm_exec_env_destroy(WASMExecEnv* exec_env);

/**
 * Allocate a WASM frame from the WASM stack.
 *
 * @param exec_env the current execution environment
 * @param size size of the WASM frame, it must be a multiple of 4
 *
 * @return the WASM frame if there is enough space in the stack area
 * with a protection area, NULL otherwise
 */
pragma(inline, true) private void* wasm_exec_env_alloc_wasm_frame(WASMExecEnv* exec_env, uint size) {
    ubyte* addr = exec_env.wasm_stack.s.top;

    bh_assert(!(size & 3));

    /* For classic interpreter, the outs area doesn't contain the const cells,
       its size cannot be larger than the frame size, so here checking stack
       overflow with multiplying by 2 is enough. For fast interpreter, since
       the outs area contains const cells, its size may be larger than current
       frame size, we should check again before putting the function arguments
       into the outs area. */
    if (size * 2
        > cast(uint)cast(uintptr_t)(exec_env.wasm_stack.s.top_boundary - addr)) {
        /* WASM stack overflow. */
        return null;
    }

    exec_env.wasm_stack.s.top += size;

static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
    {
        uint wasm_stack_used = exec_env.wasm_stack.s.top - exec_env.wasm_stack.s.bottom;
        if (wasm_stack_used > exec_env.max_wasm_stack_used)
            exec_env.max_wasm_stack_used = wasm_stack_used;
    }
}
    return addr;
}

pragma(inline, true) private void wasm_exec_env_free_wasm_frame(WASMExecEnv* exec_env, void* prev_top) {
    bh_assert(cast(ubyte*)prev_top >= exec_env.wasm_stack.s.bottom);
    exec_env.wasm_stack.s.top = cast(ubyte*)prev_top;
}

/**
 * Get the current WASM stack top pointer.
 *
 * @param exec_env the current execution environment
 *
 * @return the current WASM stack top pointer
 */
pragma(inline, true) private void* wasm_exec_env_wasm_stack_top(WASMExecEnv* exec_env) {
    return exec_env.wasm_stack.s.top;
}

/**
 * Set the current frame pointer.
 *
 * @param exec_env the current execution environment
 * @param frame the WASM frame to be set for the current exec env
 */
pragma(inline, true) private void wasm_exec_env_set_cur_frame(WASMExecEnv* exec_env, WASMInterpFrame* frame) {
    exec_env.cur_frame = frame;
}

/**
 * Get the current frame pointer.
 *
 * @param exec_env the current execution environment
 *
 * @return the current frame pointer
 */
pragma(inline, true) private WASMInterpFrame* wasm_exec_env_get_cur_frame(WASMExecEnv* exec_env) {
    return exec_env.cur_frame;
}

WASMModuleInstanceCommon* wasm_exec_env_get_module_inst(WASMExecEnv* exec_env);

void wasm_exec_env_set_module_inst(WASMExecEnv* exec_env, WASMModuleInstanceCommon* module_inst);

void wasm_exec_env_set_thread_info(WASMExecEnv* exec_env);

static if (WASM_ENABLE_THREAD_MGR != 0) {
void* wasm_exec_env_get_thread_arg(WASMExecEnv* exec_env);

void wasm_exec_env_set_thread_arg(WASMExecEnv* exec_env, void* thread_arg);
}

version (OS_ENABLE_HW_BOUND_CHECK) {
void wasm_exec_env_push_jmpbuf(WASMExecEnv* exec_env, WASMJmpBuf* jmpbuf);

WASMJmpBuf* wasm_exec_env_pop_jmpbuf(WASMExecEnv* exec_env);
}

