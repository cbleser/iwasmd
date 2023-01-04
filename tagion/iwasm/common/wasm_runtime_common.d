module tagion.iwasm.common.wasm_runtime_common;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.app_framework.base.app.bh_platform;
import tagion.iwasm.share.utils.bh_common;
import tagion.iwasm.share.utils.bh_assert;
import tagion.iwasm.share.utils.bh_log;
import tagion.iwasm.common.wasm_memory;
version (WASM_ENABLE_INTERP) {
import tagion.iwasm.interpreter.wasm_runtime;
}
version (WASM_ENABLE_AOT ) {
import tagion.iwasm.aot.aot.aot_runtime;
static if (WASM_ENABLE_DEBUG_AOT ) {
import tagion.iwasm.aot.debug_.jit_debug;
}
}
version (WASM_ENABLE_THREAD_MGR ) {
import tagion.iwasm.libraries.thread_mgr.thread_manager;
version (WASM_ENABLE_DEBUG_INTERP) {
import tagion.iwasm.libraries.debug_engine.debug_engine;
}
}
version (WASM_ENABLE_SHARED_MEMORY ) {
import wasm_shared_memory;
}
version (WASM_ENABLE_FAST_JIT ) {
import tagion.iwasm.fast_jit.jit_compiler;
}
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
import tagion.iwasm.compilation.aot_llvm;
}
import tagion.iwasm.common.wasm_c_api_internal;

/**
 * For runtime build, BH_MALLOC/BH_FREE should be defined as
 * wasm_runtime_malloc/wasm_runtime_free.
 */
bool CHECK(string a) {
	import std.format;
	mixin(format(q{return SHOULD_BE_%s}, a));
}
enum string CHECK1(string a) = ` SHOULD_BE_##a`;

enum SHOULD_BE_wasm_runtime_malloc = 1;
static assert(CHECK!"BH_MALLOC");
enum SHOULD_BE_wasm_runtime_free = 1;
static assert (!CHECK!"BH_FREE");
//static if (WASM_ENABLE_MULTI_MODULE != 0) {
/**
 * A safety insurance to prevent
 * circular depencies which leads stack overflow
 * try to break early
 */
struct LoadingModule {
    bh_list_link l;
    /* point to a string pool */
    const(char)* module_name;
}

//private bh_list loading_module_list_head;
//private bh_list* loading_module_list = &loading_module_list_head;
//private korp_mutex loading_module_list_lock;

/**
 * A list to store all exported functions/globals/memories/tables
 * of every fully loaded module
 */
//private bh_list registered_module_list_head;
//private bh_list* registered_module_list = &registered_module_list_head;
//private korp_mutex registered_module_list_lock;
//private void wasm_runtime_destroy_registered_module_list();
//} /* WASM_ENABLE_MULTI_MODULE */

enum E_TYPE_XIP = 4;

version (WASM_ENABLE_REF_TYPES ) {
/* Initialize externref hashmap */
private bool wasm_externref_map_init();

/* Destroy externref hashmap */
private void wasm_externref_map_destroy();
} /* WASM_ENABLE_REF_TYPES */

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null)
        snprintf(error_buf, error_buf_size, "%s", string);
}

private void* runtime_malloc(ulong size, WASMModuleInstanceCommon* module_inst, char* error_buf, uint error_buf_size) {
    void* mem = void;

    if (size >= UINT32_MAX || ((mem = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        if (module_inst != null) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
        }
        else if (error_buf != null) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        }
        return null;
    }

    memset(mem, 0, cast(uint)size);
    return mem;
}

static if (WASM_ENABLE_FAST_JIT != 0) {
private JitCompOptions jit_options = { 0 };
}

version (OS_ENABLE_HW_BOUND_CHECK) {
/* The exec_env of thread local storage, set before calling function
   and used in signal handler, as we cannot get it from the argument
   of signal handler */
//private os_thread_local_attribute WASMExecEnv* exec_env_tls = null;

version (BH_PLATFORM_WINDOWS) {} else {
private void runtime_signal_handler(void* sig_addr) {
    WASMModuleInstance* module_inst = void;
    WASMMemoryInstance* memory_inst = void;
    WASMJmpBuf* jmpbuf_node = void;
    ubyte* mapped_mem_start_addr = null;
    ubyte* mapped_mem_end_addr = null;
    uint page_size = os_getpagesize();
static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
    ubyte* stack_min_addr = void;
    uint guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
}

    /* Check whether current thread is running wasm function */
    if (exec_env_tls && exec_env_tls.handle == os_self_thread()
        && (jmpbuf_node = exec_env_tls.jmpbuf_stack_top)) {
        /* Get mapped mem info of current instance */
        module_inst = cast(WASMModuleInstance*)exec_env_tls.module_inst;
        /* Get the default memory instance */
        memory_inst = wasm_get_default_memory(module_inst);
        if (memory_inst) {
            mapped_mem_start_addr = memory_inst.memory_data;
            mapped_mem_end_addr = memory_inst.memory_data + 8 * cast(ulong)BH_GB;
        }

static if (WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) {
        /* Get stack info of current thread */
        stack_min_addr = os_thread_get_stack_boundary();
}

        if (memory_inst
            && (mapped_mem_start_addr <= cast(ubyte*)sig_addr
                && cast(ubyte*)sig_addr < mapped_mem_end_addr)) {
            /* The address which causes segmentation fault is inside
               the memory instance's guard regions */
            wasm_set_exception(module_inst, "out of bounds memory access");
            os_longjmp(jmpbuf_node.jmpbuf, 1);
        }
        else if ((WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) && (stack_min_addr - page_size <= cast(ubyte*)sig_addr)
                 && (cast(ubyte*)sig_addr
                        < stack_min_addr + page_size * guard_page_count)) {
            /* The address which causes segmentation fault is inside
               native thread's guard page */
            wasm_set_exception(module_inst, "native stack overflow");
            os_longjmp(jmpbuf_node.jmpbuf, 1);
        }
         else if (exec_env_tls.exce_check_guard_page <= cast(uint8*)sig_addr
                 && cast(uint8*)sig_addr
                        < exec_env_tls.exce_check_guard_page + page_size) {
            bh_assert(wasm_get_exception(module_inst));
            os_longjmp(jmpbuf_node.jmpbuf, 1);
        }
    }
}
} 
version (BH_PLATFORM_WINDOWS) {
private LONG runtime_exception_handler(EXCEPTION_POINTERS* exce_info) {
    PEXCEPTION_RECORD ExceptionRecord = exce_info.ExceptionRecord;
    ubyte* sig_addr = cast(ubyte*)ExceptionRecord.ExceptionInformation[1];
    WASMModuleInstance* module_inst = void;
    WASMMemoryInstance* memory_inst = void;
    WASMJmpBuf* jmpbuf_node = void;
    ubyte* mapped_mem_start_addr = null;
    ubyte* mapped_mem_end_addr = null;
    uint page_size = os_getpagesize();

    if (exec_env_tls && exec_env_tls.handle == os_self_thread()
        && (jmpbuf_node = exec_env_tls.jmpbuf_stack_top)) {
        module_inst = cast(WASMModuleInstance*)exec_env_tls.module_inst;
        if (ExceptionRecord.ExceptionCode == EXCEPTION_ACCESS_VIOLATION) {
            /* Get the default memory instance */
            memory_inst = wasm_get_default_memory(module_inst);
            if (memory_inst) {
                mapped_mem_start_addr = memory_inst.memory_data;
                mapped_mem_end_addr =
                    memory_inst.memory_data + 8 * cast(ulong)BH_GB;
            }

            if (memory_inst && mapped_mem_start_addr <= cast(ubyte*)sig_addr
                && cast(ubyte*)sig_addr < mapped_mem_end_addr) {
                /* The address which causes segmentation fault is inside
                   the memory instance's guard regions.
                   Set exception and let the wasm func continue to run, when
                   the wasm func returns, the caller will check whether the
                   exception is thrown and return to runtime. */
                wasm_set_exception(module_inst, "out of bounds memory access");
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    /* Continue to search next exception handler for
                       interpreter mode as it can be caught by
                       `__try { .. } __except { .. }` sentences in
                       wasm_runtime.c */
                    return EXCEPTION_CONTINUE_SEARCH;
                }
                else {
                    /* Skip current instruction and continue to run for
                       AOT mode. TODO: implement unwind support for AOT
                       code in Windows platform */
                    exce_info.ContextRecord.Rip++;
                    return EXCEPTION_CONTINUE_EXECUTION;
                }
            }
            else if (exec_env_tls.exce_check_guard_page <= cast(ubyte*)sig_addr
                     && cast(ubyte*)sig_addr
                            < exec_env_tls.exce_check_guard_page + page_size) {
                bh_assert(wasm_get_exception(module_inst));
                if (module_inst.module_type == Wasm_Module_Bytecode) {
                    return EXCEPTION_CONTINUE_SEARCH;
                }
                else {
                    exce_info.ContextRecord.Rip++;
                    return EXCEPTION_CONTINUE_EXECUTION;
                }
            }
        }
        else if ((WASM_DISABLE_STACK_HW_BOUND_CHECK == 0) && (ExceptionRecord.ExceptionCode == EXCEPTION_STACK_OVERFLOW)) {
            /* Set stack overflow exception and let the wasm func continue
               to run, when the wasm func returns, the caller will check
               whether the exception is thrown and return to runtime, and
               the damaged stack will be recovered by _resetstkoflw(). */
            wasm_set_exception(module_inst, "native stack overflow");
            if (module_inst.module_type == Wasm_Module_Bytecode) {
                return EXCEPTION_CONTINUE_SEARCH;
            }
            else {
                return EXCEPTION_CONTINUE_EXECUTION;
            }
        }
    }

    os_printf("Unhandled exception thrown:  exception code: 0x%lx, "
              ~ "exception address: %p, exception information: %p\n",
              ExceptionRecord.ExceptionCode, ExceptionRecord.ExceptionAddress,
              sig_addr);
    return EXCEPTION_CONTINUE_SEARCH;
}
} /* end of BH_PLATFORM_WINDOWS */

private bool runtime_signal_init() {
version (BH_PLATFORM_WINDOWS) {} else {
    return os_thread_signal_init(&runtime_signal_handler) == 0 ? true : false;
} version (BH_PLATFORM_WINDOWS) {
    if (os_thread_signal_init() != 0)
        return false;

    if (!AddVectoredExceptionHandler(1, &runtime_exception_handler)) {
        os_thread_signal_destroy();
        return false;
    }
}
    return true;
}

private void runtime_signal_destroy() {
version (BH_PLATFORM_WINDOWS) {
    RemoveVectoredExceptionHandler(&runtime_exception_handler);
}
    os_thread_signal_destroy();
}

void wasm_runtime_set_exec_env_tls(WASMExecEnv* exec_env) {
    exec_env_tls = exec_env;
}

WASMExecEnv* wasm_runtime_get_exec_env_tls() {
    return exec_env_tls;
}
} /* end of OS_ENABLE_HW_BOUND_CHECK */

private bool wasm_runtime_env_init() {
    if (bh_platform_init() != 0)
        return false;

    if (wasm_native_init() == false) {
        goto fail1;
    }

static if (WASM_ENABLE_MULTI_MODULE) {
    if (BHT_OK != os_mutex_init(&registered_module_list_lock)) {
        goto fail2;
    }

    if (BHT_OK != os_mutex_init(&loading_module_list_lock)) {
        goto fail3;
    }
}

static if (WASM_ENABLE_SHARED_MEMORY) {
    if (!wasm_shared_memory_init()) {
        goto fail4;
    }
}

static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_THREAD_MGR != 0)) {
    if (!thread_manager_init()) {
        goto fail5;
    }
}

version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!runtime_signal_init()) {
        goto fail6;
    }
}

static if (WASM_ENABLE_AOT != 0) {
static if (WASM_ENABLE_DEBUG_AOT != 0) {
    if (!jit_debug_engine_init()) {
        goto fail7;
    }
}
}

static if (WASM_ENABLE_REF_TYPES != 0) {
    if (!wasm_externref_map_init()) {
        goto fail8;
    }
}

static if (WASM_ENABLE_FAST_JIT != 0) {
    if (!jit_compiler_init(&jit_options)) {
        goto fail9;
    }
}

static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
    if (!aot_compiler_init()) {
        goto fail10;
    }
}

    return true;

static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
fail10:
static if (WASM_ENABLE_FAST_JIT != 0) {
    jit_compiler_destroy();
}
}
static if (WASM_ENABLE_FAST_JIT != 0) {
fail9:
static if (WASM_ENABLE_REF_TYPES != 0) {
    wasm_externref_map_destroy();
}
}
static if (WASM_ENABLE_REF_TYPES != 0) {
fail8:
}
static if (WASM_ENABLE_AOT != 0) {
static if (WASM_ENABLE_DEBUG_AOT != 0) {
    jit_debug_engine_destroy();
fail7:
}
}
version (OS_ENABLE_HW_BOUND_CHECK) {
    runtime_signal_destroy();
fail6:
}
static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_THREAD_MGR != 0)) {
    thread_manager_destroy();
fail5:
}
static if (WASM_ENABLE_SHARED_MEMORY) {
    wasm_shared_memory_destroy();
fail4:
}
static if (WASM_ENABLE_MULTI_MODULE) {
    os_mutex_destroy(&loading_module_list_lock);
fail3:
    os_mutex_destroy(&registered_module_list_lock);
fail2:
}
    wasm_native_destroy();
fail1:
    bh_platform_destroy();

    return false;
}

private bool wasm_runtime_exec_env_check(WASMExecEnv* exec_env) {
    return exec_env && exec_env.module_inst && exec_env.wasm_stack_size > 0
           && exec_env.wasm_stack.s.top_boundary
                  == exec_env.wasm_stack.s.bottom + exec_env.wasm_stack_size
           && exec_env.wasm_stack.s.top <= exec_env.wasm_stack.s.top_boundary;
}

bool wasm_runtime_init() {
    if (!wasm_runtime_memory_init(Alloc_With_System_Allocator, null))
        return false;

    if (!wasm_runtime_env_init()) {
        wasm_runtime_memory_destroy();
        return false;
    }

    return true;
}

void wasm_runtime_destroy() {
static if (WASM_ENABLE_REF_TYPES != 0) {
    wasm_externref_map_destroy();
}

static if (WASM_ENABLE_AOT != 0) {
static if (WASM_ENABLE_DEBUG_AOT != 0) {
    jit_debug_engine_destroy();
}
}

version (OS_ENABLE_HW_BOUND_CHECK) {
    runtime_signal_destroy();
}

    /* runtime env destroy */
static if (WASM_ENABLE_MULTI_MODULE) {
    wasm_runtime_destroy_loading_module_list();
    os_mutex_destroy(&loading_module_list_lock);

    wasm_runtime_destroy_registered_module_list();
    os_mutex_destroy(&registered_module_list_lock);
}

static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
    /* Destroy LLVM-JIT compiler after destroying the modules
     * loaded by multi-module feature, since these modules may
     * create backend threads to compile the wasm functions,
     * which may access the LLVM resources. We wait until they
     * finish the compilation to avoid accessing the destroyed
     * resources in the compilation threads.
     */
    aot_compiler_destroy();
}

static if (WASM_ENABLE_FAST_JIT != 0) {
    /* Destroy Fast-JIT compiler after destroying the modules
     * loaded by multi-module feature, since the Fast JIT's
     * code cache allocator may be used by these modules.
     */
    jit_compiler_destroy();
}

static if (WASM_ENABLE_SHARED_MEMORY) {
    wasm_shared_memory_destroy();
}

static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_THREAD_MGR != 0)) {
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    wasm_debug_engine_destroy();
}
    thread_manager_destroy();
}

    wasm_native_destroy();
    bh_platform_destroy();

    wasm_runtime_memory_destroy();
}

bool wasm_runtime_full_init(RuntimeInitArgs* init_args) {
    if (!wasm_runtime_memory_init(init_args.mem_alloc_type,
                                  &init_args.mem_alloc_option))
        return false;

static if (WASM_ENABLE_FAST_JIT != 0) {
    jit_options.code_cache_size = init_args.fast_jit_code_cache_size;
}

    if (!wasm_runtime_env_init()) {
        wasm_runtime_memory_destroy();
        return false;
    }

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    if (strlen(init_args.ip_addr))
        if (!wasm_debug_engine_init(init_args.ip_addr,
                                    init_args.instance_port)) {
            wasm_runtime_destroy();
            return false;
        }
}

    if (init_args.n_native_symbols > 0
        && !wasm_runtime_register_natives(init_args.native_module_name,
                                          init_args.native_symbols,
                                          init_args.n_native_symbols)) {
        wasm_runtime_destroy();
        return false;
    }

static if (WASM_ENABLE_THREAD_MGR != 0) {
    wasm_cluster_set_max_thread_num(init_args.max_thread_num);
}

    return true;
}

PackageType get_package_type(const(ubyte)* buf, uint size) {
static if ((WASM_ENABLE_WORD_ALIGN_READ != 0)) {
    uint buf32 = *cast(uint*)buf;
    buf = cast(const(ubyte)*)&buf32;
}
    if (buf && size >= 4) {
        if (buf[0] == '\0' && buf[1] == 'a' && buf[2] == 's' && buf[3] == 'm')
            return Wasm_Module_Bytecode;
        if (buf[0] == '\0' && buf[1] == 'a' && buf[2] == 'o' && buf[3] == 't')
            return Wasm_Module_AoT;
    }
    return Package_Type_Unknown;
}

static if (WASM_ENABLE_AOT != 0) {
private ubyte* align_ptr(const(ubyte)* p, uint b) {
    uintptr_t v = cast(uintptr_t)p;
    uintptr_t m = b - 1;
    return cast(ubyte*)((v + m) & ~m);
}

enum string CHECK_BUF(string buf, string buf_end, string length) = `                      \
    do {                                                     \
        if ((uintptr_t)buf + length < (uintptr_t)buf         \
            || (uintptr_t)buf + length > (uintptr_t)buf_end) \
            return false;                                    \
    } while (0)`;

enum string read_uint16(string p, string p_end, string res) = `                 \
    do {                                           \
        p = (uint8 *)align_ptr(p, uint16.sizeof); \
        CHECK_BUF(p, p_end, uint16.sizeof);       \
        res = *(uint16 *)p;                        \
        p += uint16.sizeof;                       \
    } while (0)`;

enum string read_uint32(string p, string p_end, string res) = `                 \
    do {                                           \
        p = (uint8 *)align_ptr(p, uint32.sizeof); \
        CHECK_BUF(p, p_end, uint32.sizeof);       \
        res = *(uint32 *)p;                        \
        p += uint32.sizeof;                       \
    } while (0)`;

bool wasm_runtime_is_xip_file(const(ubyte)* buf, uint size) {
    const(ubyte)* p = buf, p_end = buf + size;
    uint section_type = void, section_size = void;
    ushort e_type = void;

    if (get_package_type(buf, size) != Wasm_Module_AoT)
        return false;

    CHECK_BUF(p, p_end, 8);
    p += 8;
    while (p < p_end) {
        read_uint32(p, p_end, section_type);
        read_uint32(p, p_end, section_size);
        CHECK_BUF(p, p_end, section_size);

        if (section_type == AOT_SECTION_TYPE_TARGET_INFO) {
            p += 4;
            read_uint16(p, p_end, e_type);
            return (e_type == E_TYPE_XIP) ? true : false;
        }
        else if (section_type >= AOT_SECTION_TYPE_SIGANATURE) {
            return false;
        }
        p += section_size;
    }

    return false;
}
} /* end of WASM_ENABLE_AOT */

static if ((WASM_ENABLE_THREAD_MGR != 0) && (WASM_ENABLE_DEBUG_INTERP != 0)) {
uint wasm_runtime_start_debug_instance_with_port(WASMExecEnv* exec_env, int port) {
    WASMModuleInstanceCommon* module_inst = wasm_runtime_get_module_inst(exec_env);
    WASMCluster* cluster = wasm_exec_env_get_cluster(exec_env);
    bh_assert(module_inst);
    bh_assert(cluster);

    if (module_inst.module_type != Wasm_Module_Bytecode) {
        LOG_WARNING("Attempt to create a debug instance for an AOT module");
        return 0;
    }

    if (cluster.debug_inst) {
        LOG_WARNING("Cluster already bind to a debug instance");
        return cluster.debug_inst.control_thread.port;
    }

    if (wasm_debug_instance_create(cluster, port)) {
        return cluster.debug_inst.control_thread.port;
    }

    return 0;
}

uint wasm_runtime_start_debug_instance(WASMExecEnv* exec_env) {
    return wasm_runtime_start_debug_instance_with_port(exec_env, -1);
}
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
private module_reader reader;
private module_destroyer destroyer;
void wasm_runtime_set_module_reader(const(module_reader) reader_cb, const(module_destroyer) destroyer_cb) {
    reader = reader_cb;
    destroyer = destroyer_cb;
}

module_reader wasm_runtime_get_module_reader() {
    return reader;
}

module_destroyer wasm_runtime_get_module_destroyer() {
    return destroyer;
}

private WASMRegisteredModule* wasm_runtime_find_module_registered_by_reference(WASMModuleCommon* module_) {
    WASMRegisteredModule* reg_module = null;

    os_mutex_lock(&registered_module_list_lock);
    reg_module = bh_list_first_elem(registered_module_list);
    while (reg_module && module_ != reg_module.module_) {
        reg_module = bh_list_elem_next(reg_module);
    }
    os_mutex_unlock(&registered_module_list_lock);

    return reg_module;
}

bool wasm_runtime_register_module_internal(const(char)* module_name, WASMModuleCommon* module_, ubyte* orig_file_buf, uint orig_file_buf_size, char* error_buf, uint error_buf_size) {
    WASMRegisteredModule* node = null;

    node = wasm_runtime_find_module_registered_by_reference(module_);
    if (node) {                  /* module has been registered */
        if (node.module_name) { /* module has name */
            if (!module_name || strcmp(node.module_name, module_name)) {
                /* module has different name */
                LOG_DEBUG("module(%p) has been registered with name %s", module_,
                          node.module_name);
                set_error_buf(error_buf, error_buf_size,
                              "Register module failed: "
                              ~ "failed to rename the module");
                return false;
            }
            else {
                /* module has the same name */
                LOG_DEBUG(
                    "module(%p) has been registered with the same name %s",
                    module_, node.module_name);
                return true;
            }
        }
        else {
            /* module has empyt name, reset it */
            node.module_name = module_name;
            return true;
        }
    }

    /* module hasn't been registered */
    node = runtime_malloc(WASMRegisteredModule.sizeof, null, null, 0);
    if (!node) {
        LOG_DEBUG("malloc WASMRegisteredModule failed. SZ=%d",
                  WASMRegisteredModule.sizeof);
        return false;
    }

    /* share the string and the module */
    node.module_name = module_name;
    node.module_ = module_;
    node.orig_file_buf = orig_file_buf;
    node.orig_file_buf_size = orig_file_buf_size;

    os_mutex_lock(&registered_module_list_lock);
    bh_list_status ret = bh_list_insert(registered_module_list, node);
    bh_assert(BH_LIST_SUCCESS == ret);
    cast(void)ret;
    os_mutex_unlock(&registered_module_list_lock);
    return true;
}

bool wasm_runtime_register_module(const(char)* module_name, WASMModuleCommon* module_, char* error_buf, uint error_buf_size) {
    if (!error_buf || !error_buf_size) {
        LOG_ERROR("error buffer is required");
        return false;
    }

    if (!module_name || !module_) {
        LOG_DEBUG("module_name and module are required");
        set_error_buf(error_buf, error_buf_size,
                      "Register module failed: "
                      ~ "module_name and module are required");
        return false;
    }

    if (wasm_runtime_is_built_in_module(module_name)) {
        LOG_DEBUG("%s is a built-in module name", module_name);
        set_error_buf(error_buf, error_buf_size,
                      "Register module failed: "
                      ~ "can not register as a built-in module");
        return false;
    }

    return wasm_runtime_register_module_internal(module_name, module_, null, 0,
                                                 error_buf, error_buf_size);
}

void wasm_runtime_unregister_module(const(WASMModuleCommon)* module_) {
    WASMRegisteredModule* registered_module = null;

    os_mutex_lock(&registered_module_list_lock);
    registered_module = bh_list_first_elem(registered_module_list);
    while (registered_module && module_ != registered_module.module_) {
        registered_module = bh_list_elem_next(registered_module);
    }

    /* it does not matter if it is not exist. after all, it is gone */
    if (registered_module) {
        bh_list_remove(registered_module_list, registered_module);
        wasm_runtime_free(registered_module);
    }
    os_mutex_unlock(&registered_module_list_lock);
}

WASMModuleCommon* wasm_runtime_find_module_registered(const(char)* module_name) {
    WASMRegisteredModule* module_ = null, module_next = void;

    os_mutex_lock(&registered_module_list_lock);
    module_ = bh_list_first_elem(registered_module_list);
    while (module_) {
        module_next = bh_list_elem_next(module_);
        if (module_.module_name && !strcmp(module_name, module_.module_name)) {
            break;
        }
        module_ = module_next;
    }
    os_mutex_unlock(&registered_module_list_lock);

    return module_ ? module_.module_ : null;
}

/*
 * simply destroy all
 */
private void wasm_runtime_destroy_registered_module_list() {
    WASMRegisteredModule* reg_module = null;

    os_mutex_lock(&registered_module_list_lock);
    reg_module = bh_list_first_elem(registered_module_list);
    while (reg_module) {
        WASMRegisteredModule* next_reg_module = bh_list_elem_next(reg_module);

        bh_list_remove(registered_module_list, reg_module);

        /* now, it is time to release every module in the runtime */
        if (reg_module.module_.module_type == Wasm_Module_Bytecode) {
static if (WASM_ENABLE_INTERP != 0) {
            wasm_unload(cast(WASMModule*)reg_module.module_);
}
        }
        else {
static if (WASM_ENABLE_AOT != 0) {
            aot_unload(cast(AOTModule*)reg_module.module_);
}
        }

        /* destroy the file buffer */
        if (destroyer && reg_module.orig_file_buf) {
            destroyer(reg_module.orig_file_buf,
                      reg_module.orig_file_buf_size);
            reg_module.orig_file_buf = null;
            reg_module.orig_file_buf_size = 0;
        }

        wasm_runtime_free(reg_module);
        reg_module = next_reg_module;
    }
    os_mutex_unlock(&registered_module_list_lock);
}

bool wasm_runtime_add_loading_module(const(char)* module_name, char* error_buf, uint error_buf_size) {
    LOG_DEBUG("add %s into a loading list", module_name);
    LoadingModule* loadingModule = runtime_malloc(LoadingModule.sizeof, null, error_buf, error_buf_size);

    if (!loadingModule) {
        return false;
    }

    /* share the incoming string */
    loadingModule.module_name = module_name;

    os_mutex_lock(&loading_module_list_lock);
    bh_list_status ret = bh_list_insert(loading_module_list, loadingModule);
    bh_assert(BH_LIST_SUCCESS == ret);
    cast(void)ret;
    os_mutex_unlock(&loading_module_list_lock);
    return true;
}

void wasm_runtime_delete_loading_module(const(char)* module_name) {
    LOG_DEBUG("delete %s from a loading list", module_name);

    LoadingModule* module_ = null;

    os_mutex_lock(&loading_module_list_lock);
    module_ = bh_list_first_elem(loading_module_list);
    while (module_ && strcmp(module_.module_name, module_name)) {
        module_ = bh_list_elem_next(module_);
    }

    /* it does not matter if it is not exist. after all, it is gone */
    if (module_) {
        bh_list_remove(loading_module_list, module_);
        wasm_runtime_free(module_);
    }
    os_mutex_unlock(&loading_module_list_lock);
}

bool wasm_runtime_is_loading_module(const(char)* module_name) {
    LOG_DEBUG("find %s in a loading list", module_name);

    LoadingModule* module_ = null;

    os_mutex_lock(&loading_module_list_lock);
    module_ = bh_list_first_elem(loading_module_list);
    while (module_ && strcmp(module_name, module_.module_name)) {
        module_ = bh_list_elem_next(module_);
    }
    os_mutex_unlock(&loading_module_list_lock);

    return module_ != null;
}

void wasm_runtime_destroy_loading_module_list() {
    LoadingModule* module_ = null;

    os_mutex_lock(&loading_module_list_lock);
    module_ = bh_list_first_elem(loading_module_list);
    while (module_) {
        LoadingModule* next_module = bh_list_elem_next(module_);

        bh_list_remove(loading_module_list, module_);
        /*
         * will not free the module_name since it is
         * shared one of the const string pool
         */
        wasm_runtime_free(module_);

        module_ = next_module;
    }

    os_mutex_unlock(&loading_module_list_lock);
}

bool wasm_runtime_is_built_in_module(const(char)* module_name) {
    return !strcmp("env", module_name) || !strcmp("wasi_unstable", module_name)
            || !strcmp("wasi_snapshot_preview1", module_name)
            || ((!WASM_ENABLE_SPEC_TEST != 0) && (strcmp("spectest", module_name)))
            || !strcmp("", module_name);
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
bool wasm_exec_env_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size) {
    WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        return wasm_set_aux_stack(exec_env, start_offset, size);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        return aot_set_aux_stack(exec_env, start_offset, size);
    }
}
    return false;
}

bool wasm_exec_env_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size) {
    WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        return wasm_get_aux_stack(exec_env, start_offset, size);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        return aot_get_aux_stack(exec_env, start_offset, size);
    }
}
    return false;
}

void wasm_runtime_set_max_thread_num(uint num) {
    wasm_cluster_set_max_thread_num(num);
}
} /* end of WASM_ENABLE_THREAD_MGR */

private WASMModuleCommon* register_module_with_null_name(WASMModuleCommon* module_common, char* error_buf, uint error_buf_size) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    if (module_common) {
        if (!wasm_runtime_register_module_internal(null, module_common, null, 0,
                                                   error_buf, error_buf_size)) {
            wasm_runtime_unload(module_common);
            return null;
        }
        return module_common;
    }
    else
        return null;
} else {
    return module_common;
}
}

WASMModuleCommon* wasm_runtime_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size) {
    WASMModuleCommon* module_common = null;

    if (get_package_type(buf, size) == Wasm_Module_Bytecode) {
static if (WASM_ENABLE_INTERP != 0) {
        module_common =
            cast(WASMModuleCommon*)wasm_load(buf, size, error_buf, error_buf_size);
        return register_module_with_null_name(module_common, error_buf,
                                              error_buf_size);
}
    }
    else if (get_package_type(buf, size) == Wasm_Module_AoT) {
static if (WASM_ENABLE_AOT != 0) {
        module_common = cast(WASMModuleCommon*)aot_load_from_aot_file(
            buf, size, error_buf, error_buf_size);
        return register_module_with_null_name(module_common, error_buf,
                                              error_buf_size);
}
    }

    if (size < 4)
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: unexpected end");
    else
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: magic header not detected");
    return null;
}

WASMModuleCommon* wasm_runtime_load_from_sections(WASMSection* section_list, bool is_aot, char* error_buf, uint error_buf_size) {
    WASMModuleCommon* module_common = void;

    if (!is_aot) {
static if (WASM_ENABLE_INTERP != 0) {
        module_common = cast(WASMModuleCommon*)wasm_load_from_sections(
            section_list, error_buf, error_buf_size);
        return register_module_with_null_name(module_common, error_buf,
                                              error_buf_size);
}
    }
    else {
static if (WASM_ENABLE_AOT != 0) {
        module_common = cast(WASMModuleCommon*)aot_load_from_sections(
            section_list, error_buf, error_buf_size);
        return register_module_with_null_name(module_common, error_buf,
                                              error_buf_size);
}
    }

static if (WASM_ENABLE_INTERP == 0 || WASM_ENABLE_AOT == 0) {
    set_error_buf(error_buf, error_buf_size,
                  "WASM module load failed: invalid section list type");
    return null;
}
}

void wasm_runtime_unload(WASMModuleCommon* module_) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    /**
     * since we will unload and free all module when runtime_destroy()
     * we don't want users to unwillingly disrupt it
     */
    return;
}

static if (WASM_ENABLE_INTERP != 0) {
    if (module_.module_type == Wasm_Module_Bytecode) {
        wasm_unload(cast(WASMModule*)module_);
        return;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_.module_type == Wasm_Module_AoT) {
        aot_unload(cast(AOTModule*)module_);
        return;
    }
}
}

WASMModuleInstanceCommon* wasm_runtime_instantiate_internal(WASMModuleCommon* module_, bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_.module_type == Wasm_Module_Bytecode)
        return cast(WASMModuleInstanceCommon*)wasm_instantiate(
            cast(WASMModule*)module_, is_sub_inst, stack_size, heap_size, error_buf,
            error_buf_size);
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_.module_type == Wasm_Module_AoT)
        return cast(WASMModuleInstanceCommon*)aot_instantiate(
            cast(AOTModule*)module_, is_sub_inst, stack_size, heap_size, error_buf,
            error_buf_size);
}
    set_error_buf(error_buf, error_buf_size,
                  "Instantiate module failed, invalid module type");
    return null;
}

WASMModuleInstanceCommon* wasm_runtime_instantiate(WASMModuleCommon* module_, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size) {
    return wasm_runtime_instantiate_internal(
        module_, false, stack_size, heap_size, error_buf, error_buf_size);
}

void wasm_runtime_deinstantiate_internal(WASMModuleInstanceCommon* module_inst, bool is_sub_inst) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        wasm_deinstantiate(cast(WASMModuleInstance*)module_inst, is_sub_inst);
        return;
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        aot_deinstantiate(cast(AOTModuleInstance*)module_inst, is_sub_inst);
        return;
    }
}
}

void wasm_runtime_deinstantiate(WASMModuleInstanceCommon* module_inst) {
    wasm_runtime_deinstantiate_internal(module_inst, false);
}

WASMModuleCommon* wasm_runtime_get_module(WASMModuleInstanceCommon* module_inst) {
    return cast(WASMModuleCommon*)(cast(WASMModuleInstance*)module_inst).module_;
}

WASMExecEnv* wasm_runtime_create_exec_env(WASMModuleInstanceCommon* module_inst, uint stack_size) {
    return wasm_exec_env_create(module_inst, stack_size);
}

void wasm_runtime_destroy_exec_env(WASMExecEnv* exec_env) {
    wasm_exec_env_destroy(exec_env);
}

bool wasm_runtime_init_thread_env() {
version (BH_PLATFORM_WINDOWS) {
    if (os_thread_env_init() != 0)
        return false;
}

version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!runtime_signal_init()) {
version (BH_PLATFORM_WINDOWS) {
        os_thread_env_destroy();
}
        return false;
    }
}

    return true;
}

void wasm_runtime_destroy_thread_env() {
version (OS_ENABLE_HW_BOUND_CHECK) {
    runtime_signal_destroy();
}

version (BH_PLATFORM_WINDOWS) {
    os_thread_env_destroy();
}
}

bool wasm_runtime_thread_env_inited() {
version (BH_PLATFORM_WINDOWS) {
    if (!os_thread_env_inited())
        return false;
}

static if (WASM_ENABLE_AOT != 0) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!os_thread_signal_inited())
        return false;
}
}
    return true;
}

static if ((WASM_ENABLE_MEMORY_PROFILING != 0) || (WASM_ENABLE_MEMORY_TRACING != 0)) {
void wasm_runtime_dump_module_mem_consumption(const(WASMModuleCommon)* module_) {
    WASMModuleMemConsumption mem_conspn = { 0 };

static if (WASM_ENABLE_INTERP != 0) {
    if (module_.module_type == Wasm_Module_Bytecode) {
        wasm_get_module_mem_consumption(cast(WASMModule*)module_, &mem_conspn);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_.module_type == Wasm_Module_AoT) {
        aot_get_module_mem_consumption(cast(AOTModule*)module_, &mem_conspn);
    }
}

    os_printf("WASM module memory consumption, total size: %u\n",
              mem_conspn.total_size);
    os_printf("    module struct size: %u\n", mem_conspn.module_struct_size);
    os_printf("    types size: %u\n", mem_conspn.types_size);
    os_printf("    imports size: %u\n", mem_conspn.imports_size);
    os_printf("    funcs size: %u\n", mem_conspn.functions_size);
    os_printf("    tables size: %u\n", mem_conspn.tables_size);
    os_printf("    memories size: %u\n", mem_conspn.memories_size);
    os_printf("    globals size: %u\n", mem_conspn.globals_size);
    os_printf("    exports size: %u\n", mem_conspn.exports_size);
    os_printf("    table segs size: %u\n", mem_conspn.table_segs_size);
    os_printf("    data segs size: %u\n", mem_conspn.data_segs_size);
    os_printf("    const strings size: %u\n", mem_conspn.const_strs_size);
static if (WASM_ENABLE_AOT != 0) {
    os_printf("    aot code size: %u\n", mem_conspn.aot_code_size);
}
}

void wasm_runtime_dump_module_inst_mem_consumption(const(WASMModuleInstanceCommon)* module_inst) {
    WASMModuleInstMemConsumption mem_conspn = { 0 };

static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        wasm_get_module_inst_mem_consumption(cast(WASMModuleInstance*)module_inst,
                                             &mem_conspn);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        aot_get_module_inst_mem_consumption(cast(AOTModuleInstance*)module_inst,
                                            &mem_conspn);
    }
}

    os_printf("WASM module inst memory consumption, total size: %u\n",
              mem_conspn.total_size);
    os_printf("    module inst struct size: %u\n",
              mem_conspn.module_inst_struct_size);
    os_printf("    memories size: %u\n", mem_conspn.memories_size);
    os_printf("        app heap size: %u\n", mem_conspn.app_heap_size);
    os_printf("    tables size: %u\n", mem_conspn.tables_size);
    os_printf("    functions size: %u\n", mem_conspn.functions_size);
    os_printf("    globals size: %u\n", mem_conspn.globals_size);
    os_printf("    exports size: %u\n", mem_conspn.exports_size);
}

void wasm_runtime_dump_exec_env_mem_consumption(const(WASMExecEnv)* exec_env) {
    uint total_size = offsetof(WASMExecEnv, wasm_stack.s.bottom) + exec_env.wasm_stack_size;

    os_printf("Exec env memory consumption, total size: %u\n", total_size);
    os_printf("    exec env struct size: %u\n",
              offsetof(WASMExecEnv, wasm_stack.s.bottom));
static if (WASM_ENABLE_INTERP != 0 && WASM_ENABLE_FAST_INTERP == 0) {
    os_printf("        block addr cache size: %u\n",
              typeof(exec_env.block_addr_cache).sizeof);
}
    os_printf("    stack size: %u\n", exec_env.wasm_stack_size);
}

uint gc_get_heap_highmark_size(void* heap);

void wasm_runtime_dump_mem_consumption(WASMExecEnv* exec_env) {
    WASMModuleInstMemConsumption module_inst_mem_consps = void;
    WASMModuleMemConsumption module_mem_consps = void;
    WASMModuleInstanceCommon* module_inst_common = void;
    WASMModuleCommon* module_common = null;
    void* heap_handle = null;
    uint total_size = 0, app_heap_peak_size = 0;
    uint max_aux_stack_used = -1;

    module_inst_common = exec_env.module_inst;
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst_common.module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance* wasm_module_inst = cast(WASMModuleInstance*)module_inst_common;
        WASMModule* wasm_module = wasm_module_inst.module_;
        module_common = cast(WASMModuleCommon*)wasm_module;
        if (wasm_module_inst.memories) {
            heap_handle = wasm_module_inst.memories[0].heap_handle;
        }
        wasm_get_module_inst_mem_consumption(wasm_module_inst,
                                             &module_inst_mem_consps);
        wasm_get_module_mem_consumption(wasm_module, &module_mem_consps);
        if (wasm_module_inst.module_.aux_stack_top_global_index != cast(uint)-1)
            max_aux_stack_used = wasm_module_inst.e.max_aux_stack_used;
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst_common.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* aot_module_inst = cast(AOTModuleInstance*)module_inst_common;
        AOTModule* aot_module = cast(AOTModule*)aot_module_inst.module_;
        module_common = cast(WASMModuleCommon*)aot_module;
        if (aot_module_inst.memories) {
            AOTMemoryInstance** memories = aot_module_inst.memories;
            heap_handle = memories[0].heap_handle;
        }
        aot_get_module_inst_mem_consumption(aot_module_inst,
                                            &module_inst_mem_consps);
        aot_get_module_mem_consumption(aot_module, &module_mem_consps);
    }
}

    bh_assert(module_common != null);

    if (heap_handle) {
        app_heap_peak_size = gc_get_heap_highmark_size(heap_handle);
    }

    total_size = offsetof(WASMExecEnv, wasm_stack.s.bottom)
                 + exec_env.wasm_stack_size + module_mem_consps.total_size
                 + module_inst_mem_consps.total_size;

    os_printf("\nMemory consumption summary (bytes):\n");
    wasm_runtime_dump_module_mem_consumption(module_common);
    wasm_runtime_dump_module_inst_mem_consumption(module_inst_common);
    wasm_runtime_dump_exec_env_mem_consumption(exec_env);
    os_printf("\nTotal memory consumption of module, module inst and "
              ~ "exec env: %u\n",
              total_size);
    os_printf("Total interpreter stack used: %u\n",
              exec_env.max_wasm_stack_used);

    if (max_aux_stack_used != cast(uint)-1)
        os_printf("Total auxiliary stack used: %u\n", max_aux_stack_used);
    else
        os_printf("Total aux stack used: no enough info to profile\n");

    os_printf("Total app heap used: %u\n", app_heap_peak_size);
}
} /* end of (WASM_ENABLE_MEMORY_PROFILING != 0) \
                 || (WASM_ENABLE_MEMORY_TRACING != 0) */

static if (WASM_ENABLE_PERF_PROFILING != 0) {
void wasm_runtime_dump_perf_profiling(WASMModuleInstanceCommon* module_inst) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        wasm_dump_perf_profiling(cast(WASMModuleInstance*)module_inst);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        aot_dump_perf_profiling(cast(AOTModuleInstance*)module_inst);
    }
}
}
}

WASMModuleInstanceCommon* wasm_runtime_get_module_inst(WASMExecEnv* exec_env) {
    return wasm_exec_env_get_module_inst(exec_env);
}

void wasm_runtime_set_module_inst(WASMExecEnv* exec_env, WASMModuleInstanceCommon* module_inst) {
    wasm_exec_env_set_module_inst(exec_env, module_inst);
}

void* wasm_runtime_get_function_attachment(WASMExecEnv* exec_env) {
    return exec_env.attachment;
}

void wasm_runtime_set_user_data(WASMExecEnv* exec_env, void* user_data) {
    exec_env.user_data = user_data;
}

void* wasm_runtime_get_user_data(WASMExecEnv* exec_env) {
    return exec_env.user_data;
}

version (OS_ENABLE_HW_BOUND_CHECK) {
void wasm_runtime_access_exce_check_guard_page() {
    if (exec_env_tls && exec_env_tls.handle == os_self_thread()) {
        uint page_size = os_getpagesize();
        memset(exec_env_tls.exce_check_guard_page, 0, page_size);
    }
}
}

WASMType* wasm_runtime_get_function_type(const(WASMFunctionInstanceCommon)* function_, uint module_type) {
    WASMType* type = null;

static if (WASM_ENABLE_INTERP != 0) {
    if (module_type == Wasm_Module_Bytecode) {
        WASMFunctionInstance* wasm_func = cast(WASMFunctionInstance*)function_;
        type = wasm_func.is_import_func ? wasm_func.u.func_import.func_type
                                         : wasm_func.u.func.func_type;
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_type == Wasm_Module_AoT) {
        AOTFunctionInstance* aot_func = cast(AOTFunctionInstance*)function_;
        type = aot_func.is_import_func ? aot_func.u.func_import.func_type
                                        : aot_func.u.func.func_type;
    }
}

    return type;
}

WASMFunctionInstanceCommon* wasm_runtime_lookup_function(WASMModuleInstanceCommon* module_inst, const(char)* name, const(char)* signature) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode)
        return cast(WASMFunctionInstanceCommon*)wasm_lookup_function(
            cast(const(WASMModuleInstance)*)module_inst, name, signature);
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT)
        return cast(WASMFunctionInstanceCommon*)aot_lookup_function(
            cast(const(AOTModuleInstance)*)module_inst, name, signature);
}
    return null;
}

uint wasm_func_get_param_count(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst) {
    WASMType* type = wasm_runtime_get_function_type(func_inst, module_inst.module_type);
    bh_assert(type);

    return type.param_count;
}

uint wasm_func_get_result_count(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst) {
    WASMType* type = wasm_runtime_get_function_type(func_inst, module_inst.module_type);
    bh_assert(type);

    return type.result_count;
}

private ubyte val_type_to_val_kind(ubyte value_type) {
    switch (value_type) {
        case VALUE_TYPE_I32:
            return WASM_I32;
        case VALUE_TYPE_I64:
            return WASM_I64;
        case VALUE_TYPE_F32:
            return WASM_F32;
        case VALUE_TYPE_F64:
            return WASM_F64;
        case VALUE_TYPE_FUNCREF:
            return WASM_FUNCREF;
        case VALUE_TYPE_EXTERNREF:
            return WASM_ANYREF;
        default:
            bh_assert(0);
            return 0;
    }
}

void wasm_func_get_param_types(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst, wasm_valkind_t* param_types) {
    WASMType* type = wasm_runtime_get_function_type(func_inst, module_inst.module_type);
    uint i = void;

    bh_assert(type);

    for (i = 0; i < type.param_count; i++) {
        param_types[i] = val_type_to_val_kind(type.types[i]);
    }
}

void wasm_func_get_result_types(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst, wasm_valkind_t* result_types) {
    WASMType* type = wasm_runtime_get_function_type(func_inst, module_inst.module_type);
    uint i = void;

    bh_assert(type);

    for (i = 0; i < type.result_count; i++) {
        result_types[i] =
            val_type_to_val_kind(type.types[type.param_count + i]);
    }
}

static if (WASM_ENABLE_REF_TYPES != 0) {
/* (uintptr_t)externref -> cast(uint)index */
/*   argv               ->   *ret_argv */
private bool wasm_runtime_prepare_call_function(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint* argv, uint argc, uint** ret_argv, uint* ret_argc_param, uint* ret_argc_result) {
    uint* new_argv = null; uint argv_i = 0, new_argv_i = 0, param_i = 0, result_i = 0;
    bool need_param_transform = false, need_result_transform = false;
    ulong size = 0;
    WASMType* func_type = wasm_runtime_get_function_type(
        function_, exec_env.module_inst.module_type);

    bh_assert(func_type);

    *ret_argc_param = func_type.param_cell_num;
    *ret_argc_result = func_type.ret_cell_num;
    for (param_i = 0; param_i < func_type.param_count; param_i++) {
        if (VALUE_TYPE_EXTERNREF == func_type.types[param_i]) {
            need_param_transform = true;
        }
    }

    for (result_i = 0; result_i < func_type.result_count; result_i++) {
        if (VALUE_TYPE_EXTERNREF
            == func_type.types[func_type.param_count + result_i]) {
            need_result_transform = true;
        }
    }

    if (!need_param_transform && !need_result_transform) {
        *ret_argv = argv;
        return true;
    }

    if (func_type.param_cell_num >= func_type.ret_cell_num) {
        size = uint32.sizeof * func_type.param_cell_num;
    }
    else {
        size = uint32.sizeof * func_type.ret_cell_num;
    }

    if (((new_argv = runtime_malloc(size, exec_env.module_inst, null, 0)) == 0)) {
        return false;
    }

    if (!need_param_transform) {
        bh_memcpy_s(new_argv, cast(uint)size, argv, cast(uint)size);
    }
    else {
        for (param_i = 0; param_i < func_type.param_count && argv_i < argc
                          && new_argv_i < func_type.param_cell_num;
             param_i++) {
            ubyte param_type = func_type.types[param_i];
            if (VALUE_TYPE_EXTERNREF == param_type) {
                void* externref_obj = void;
                uint externref_index = void;

static if (UINTPTR_MAX == UINT32_MAX) {
                externref_obj = cast(void*)argv[argv_i];
} else {
                union _U {
                    uintptr_t val = void;
                    uint[2] parts = void;
                }_U u = void;

                u.parts[0] = argv[argv_i];
                u.parts[1] = argv[argv_i + 1];
                externref_obj = cast(void*)u.val;
}
                if (!wasm_externref_obj2ref(exec_env.module_inst,
                                            externref_obj, &externref_index)) {
                    wasm_runtime_free(new_argv);
                    return false;
                }

                new_argv[new_argv_i] = externref_index;
                argv_i += uintptr_t.sizeof / uint32.sizeof;
                new_argv_i++;
            }
            else {
                ushort param_cell_num = wasm_value_type_cell_num(param_type);
                uint param_size = uint32.sizeof * param_cell_num;
                bh_memcpy_s(new_argv + new_argv_i, param_size, argv + argv_i,
                            param_size);
                argv_i += param_cell_num;
                new_argv_i += param_cell_num;
            }
        }
    }

    *ret_argv = new_argv;
    return true;
}

/* (uintptr_t)externref <- cast(uint)index */
/*   argv               <-   new_argv */
private bool wasm_runtime_finalize_call_function(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint* argv, uint argc, uint* ret_argv) {
    uint argv_i = 0, result_i = 0, ret_argv_i = 0;
    WASMType* func_type = void;

    bh_assert((argv && ret_argv) || (argc == 0));

    if (argv == ret_argv) {
        /* no need to transfrom externref results */
        return true;
    }

    func_type = wasm_runtime_get_function_type(
        function_, exec_env.module_inst.module_type);
    bh_assert(func_type);

    for (result_i = 0; result_i < func_type.result_count && argv_i < argc;
         result_i++) {
        ubyte result_type = func_type.types[func_type.param_count + result_i];
        if (result_type == VALUE_TYPE_EXTERNREF) {
            void* externref_obj = void;
static if (UINTPTR_MAX != UINT32_MAX) {
            union _U {
                uintptr_t val = void;
                uint[2] parts = void;
            }_U u = void;
}

            if (!wasm_externref_ref2obj(argv[argv_i], &externref_obj)) {
                wasm_runtime_free(argv);
                return false;
            }

static if (UINTPTR_MAX == UINT32_MAX) {
            ret_argv[ret_argv_i] = cast(uintptr_t)externref_obj;
} else {
            u.val = cast(uintptr_t)externref_obj;
            ret_argv[ret_argv_i] = u.parts[0];
            ret_argv[ret_argv_i + 1] = u.parts[1];
}
            argv_i += 1;
            ret_argv_i += uintptr_t.sizeof / uint32.sizeof;
        }
        else {
            ushort result_cell_num = wasm_value_type_cell_num(result_type);
            uint result_size = uint32.sizeof * result_cell_num;
            bh_memcpy_s(ret_argv + ret_argv_i, result_size, argv + argv_i,
                        result_size);
            argv_i += result_cell_num;
            ret_argv_i += result_cell_num;
        }
    }

    wasm_runtime_free(argv);
    return true;
}
}

bool wasm_runtime_call_wasm(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint argc, uint* argv) {
    bool ret = false;
    uint* new_argv = null; uint param_argc = void;
static if (WASM_ENABLE_REF_TYPES != 0) {
    uint result_argc = 0;
}

    if (!wasm_runtime_exec_env_check(exec_env)) {
        LOG_ERROR("Invalid exec env stack info.");
        return false;
    }

static if (WASM_ENABLE_REF_TYPES != 0) {
    if (!wasm_runtime_prepare_call_function(exec_env, function_, argv, argc,
                                            &new_argv, &param_argc,
                                            &result_argc)) {
        wasm_runtime_set_exception(exec_env.module_inst,
                                   "the arguments conversion is failed");
        return false;
    }
} else {
    new_argv = argv;
    param_argc = argc;
}

static if (WASM_ENABLE_INTERP != 0) {
    if (exec_env.module_inst.module_type == Wasm_Module_Bytecode)
        ret = wasm_call_function(exec_env, cast(WASMFunctionInstance*)function_,
                                 param_argc, new_argv);
}
static if (WASM_ENABLE_AOT != 0) {
    if (exec_env.module_inst.module_type == Wasm_Module_AoT)
        ret = aot_call_function(exec_env, cast(AOTFunctionInstance*)function_,
                                param_argc, new_argv);
}
    if (!ret) {
        if (new_argv != argv) {
            wasm_runtime_free(new_argv);
        }
        return false;
    }

static if (WASM_ENABLE_REF_TYPES != 0) {
    if (!wasm_runtime_finalize_call_function(exec_env, function_, new_argv,
                                             result_argc, argv)) {
        wasm_runtime_set_exception(exec_env.module_inst,
                                   "the result conversion is failed");
        return false;
    }
}

    return ret;
}

private void parse_args_to_uint32_array(WASMType* type, wasm_val_t* args, uint* out_argv) {
    uint i = void, p = void;

    for (i = 0, p = 0; i < type.param_count; i++) {
        switch (args[i].kind) {
            case WASM_I32:
                out_argv[p++] = args[i].of.i32;
                break;
            case WASM_I64:
            {
                union _U {
                    ulong val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.val = args[i].of.i64;
                out_argv[p++] = u.parts[0];
                out_argv[p++] = u.parts[1];
                break;
            }
            case WASM_F32:
            {
                union _U {
                    float32 val = void;
                    uint part = void;
                }_U u = void;
                u.val = args[i].of.f32;
                out_argv[p++] = u.part;
                break;
            }
            case WASM_F64:
            {
                union _U {
                    float64 val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.val = args[i].of.f64;
                out_argv[p++] = u.parts[0];
                out_argv[p++] = u.parts[1];
                break;
            }
static if (WASM_ENABLE_REF_TYPES != 0) {
            case WASM_FUNCREF:
            {
                out_argv[p++] = args[i].of.i32;
                break;
            }
            case WASM_ANYREF:
            {
static if (UINTPTR_MAX == UINT32_MAX) {
                out_argv[p++] = args[i].of.foreign;
} else {
                union _U {
                    uintptr_t val = void;
                    uint[2] parts = void;
                }_U u = void;

                u.val = cast(uintptr_t)args[i].of.foreign;
                out_argv[p++] = u.parts[0];
                out_argv[p++] = u.parts[1];
}
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }
}

private void parse_uint32_array_to_results(WASMType* type, uint* argv, wasm_val_t* out_results) {
    uint i = void, p = void;

    for (i = 0, p = 0; i < type.result_count; i++) {
        switch (type.types[type.param_count + i]) {
            case VALUE_TYPE_I32:
                out_results[i].kind = WASM_I32;
                out_results[i].of.i32 = cast(int)argv[p++];
                break;
            case VALUE_TYPE_I64:
            {
                union _U {
                    ulong val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.parts[0] = argv[p++];
                u.parts[1] = argv[p++];
                out_results[i].kind = WASM_I64;
                out_results[i].of.i64 = u.val;
                break;
            }
            case VALUE_TYPE_F32:
            {
                union _U {
                    float32 val = void;
                    uint part = void;
                }_U u = void;
                u.part = argv[p++];
                out_results[i].kind = WASM_F32;
                out_results[i].of.f32 = u.val;
                break;
            }
            case VALUE_TYPE_F64:
            {
                union _U {
                    float64 val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.parts[0] = argv[p++];
                u.parts[1] = argv[p++];
                out_results[i].kind = WASM_F64;
                out_results[i].of.f64 = u.val;
                break;
            }
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
            {
                out_results[i].kind = WASM_I32;
                out_results[i].of.i32 = cast(int)argv[p++];
                break;
            }
            case VALUE_TYPE_EXTERNREF:
            {
static if (UINTPTR_MAX == UINT32_MAX) {
                out_results[i].kind = WASM_ANYREF;
                out_results[i].of.foreign = cast(uintptr_t)argv[p++];
} else {
                union _U {
                    uintptr_t val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.parts[0] = argv[p++];
                u.parts[1] = argv[p++];
                out_results[i].kind = WASM_ANYREF;
                out_results[i].of.foreign = u.val;
}
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }
}

bool wasm_runtime_call_wasm_a(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint num_results, wasm_val_t* results, uint num_args, wasm_val_t* args) {
    uint argc = void; uint[16] argv_buf = 0; uint* argv = argv_buf; uint cell_num = void, module_type = void;
static if (WASM_ENABLE_REF_TYPES != 0) {
    uint i = void, param_size_in_double_world = 0, result_size_in_double_world = 0;
}
    ulong total_size = void;
    WASMType* type = void;
    bool ret = false;

    module_type = exec_env.module_inst.module_type;
    type = wasm_runtime_get_function_type(function_, module_type);

    if (!type) {
        LOG_ERROR("Function type get failed, WAMR Interpreter and AOT must be "
                  ~ "enabled at least one.");
        goto fail1;
    }

static if (WASM_ENABLE_REF_TYPES != 0) {
    for (i = 0; i < type.param_count; i++) {
        param_size_in_double_world +=
            wasm_value_type_cell_num_outside(type.types[i]);
    }
    for (i = 0; i < type.result_count; i++) {
        result_size_in_double_world += wasm_value_type_cell_num_outside(
            type.types[type.param_count + i]);
    }
    argc = param_size_in_double_world;
    cell_num = (argc >= result_size_in_double_world)
                   ? argc
                   : result_size_in_double_world;
} else {
    argc = type.param_cell_num;
    cell_num = (argc > type.ret_cell_num) ? argc : type.ret_cell_num;
}

    if (num_results != type.result_count) {
        LOG_ERROR(
            "The result value number does not match the function declaration.");
        goto fail1;
    }

    if (num_args != type.param_count) {
        LOG_ERROR("The argument value number does not match the function "
                  ~ "declaration.");
        goto fail1;
    }

    total_size = uint32.sizeof * cast(ulong)(cell_num > 2 ? cell_num : 2);
    if (total_size > argv_buf.sizeof) {
        if (((argv =
                  runtime_malloc(total_size, exec_env.module_inst, null, 0)) == 0)) {
            goto fail1;
        }
    }

    parse_args_to_uint32_array(type, args, argv);
    if (((ret = wasm_runtime_call_wasm(exec_env, function_, argc, argv)) == 0))
        goto fail2;

    parse_uint32_array_to_results(type, argv, results);

fail2:
    if (argv != argv_buf.ptr)
        wasm_runtime_free(argv);
fail1:
    return ret;
}

bool wasm_runtime_call_wasm_v(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint num_results, wasm_val_t* results, uint num_args, ...) {
    wasm_val_t[8] args_buf = 0; wasm_val_t* args = args_buf;
    WASMType* type = null;
    bool ret = false;
    ulong total_size = void;
    uint i = 0, module_type = void;
    va_list vargs = void;

    module_type = exec_env.module_inst.module_type;
    type = wasm_runtime_get_function_type(function_, module_type);

    if (!type) {
        LOG_ERROR("Function type get failed, WAMR Interpreter and AOT "
                  ~ "must be enabled at least one.");
        goto fail1;
    }

    if (num_args != type.param_count) {
        LOG_ERROR("The argument value number does not match the "
                  ~ "function declaration.");
        goto fail1;
    }

    total_size = wasm_val_t.sizeof * cast(ulong)num_args;
    if (total_size > args_buf.sizeof) {
        if (((args =
                  runtime_malloc(total_size, exec_env.module_inst, null, 0)) == 0)) {
            goto fail1;
        }
    }

    va_start(vargs, num_args);
    for (i = 0; i < num_args; i++) {
        switch (type.types[i]) {
            case VALUE_TYPE_I32:
                args[i].kind = WASM_I32;
                args[i].of.i32 = va_arg(vargs, uint32);
                break;
            case VALUE_TYPE_I64:
                args[i].kind = WASM_I64;
                args[i].of.i64 = va_arg(vargs, uint64);
                break;
            case VALUE_TYPE_F32:
                args[i].kind = WASM_F32;
                args[i].of.f32 = cast(float32)va_arg(vargs, float64);
                break;
            case VALUE_TYPE_F64:
                args[i].kind = WASM_F64;
                args[i].of.f64 = va_arg(vargs, float64);
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
            {
                args[i].kind = WASM_FUNCREF;
                args[i].of.i32 = va_arg(vargs, uint32);
                break;
            }
            case VALUE_TYPE_EXTERNREF:
            {
                args[i].kind = WASM_ANYREF;
                args[i].of.foreign = va_arg(vargs, uintptr_t);
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }
    va_end(vargs);

    ret = wasm_runtime_call_wasm_a(exec_env, function_, num_results, results,
                                   num_args, args);
    if (args != args_buf.ptr)
        wasm_runtime_free(args);

fail1:
    return ret;
}

bool wasm_runtime_create_exec_env_singleton(WASMModuleInstanceCommon* module_inst_comm) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMExecEnv* exec_env = null;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    if (module_inst.exec_env_singleton) {
        return true;
    }

    exec_env = wasm_exec_env_create(module_inst_comm,
                                    module_inst.default_wasm_stack_size);
    if (exec_env)
        module_inst.exec_env_singleton = exec_env;

    return exec_env ? true : false;
}

WASMExecEnv* wasm_runtime_get_exec_env_singleton(WASMModuleInstanceCommon* module_inst_comm) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    if (!module_inst.exec_env_singleton) {
        wasm_runtime_create_exec_env_singleton(module_inst_comm);
    }
    return module_inst.exec_env_singleton;
}

void wasm_set_exception(WASMModuleInstance* module_inst, const(char)* exception) {
    if (exception)
        snprintf(module_inst.cur_exception, typeof(module_inst.cur_exception).sizeof,
                 "Exception: %s", exception);
    else
        module_inst.cur_exception[0] = '\0';
}

/* clang-format off */
private string[] exception_msgs = [
    "unreachable",                    /* EXCE_UNREACHABLE */
    "allocate memory failed",         /* EXCE_OUT_OF_MEMORY */
    "out of bounds memory access",    /* EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS */
    "integer overflow",               /* EXCE_INTEGER_OVERFLOW */
    "integer divide by zero",         /* EXCE_INTEGER_DIVIDE_BY_ZERO */
    "invalid conversion to integer",  /* EXCE_INVALID_CONVERSION_TO_INTEGER */
    "indirect call type mismatch",    /* EXCE_INVALID_FUNCTION_TYPE_INDEX */
    "invalid function index",         /* EXCE_INVALID_FUNCTION_INDEX */
    "undefined element",              /* EXCE_UNDEFINED_ELEMENT */
    "uninitialized element",          /* EXCE_UNINITIALIZED_ELEMENT */
    "failed to call unlinked import function", /* EXCE_CALL_UNLINKED_IMPORT_FUNC */
    "native stack overflow",          /* EXCE_NATIVE_STACK_OVERFLOW */
    "unaligned atomic",               /* EXCE_UNALIGNED_ATOMIC */
    "wasm auxiliary stack overflow",  /* EXCE_AUX_STACK_OVERFLOW */
    "wasm auxiliary stack underflow", /* EXCE_AUX_STACK_UNDERFLOW */
    "out of bounds table access",     /* EXCE_OUT_OF_BOUNDS_TABLE_ACCESS */
    "wasm operand stack overflow",    /* EXCE_OPERAND_STACK_OVERFLOW */
    "failed to compile fast jit function", /* EXCE_FAILED_TO_COMPILE_FAST_JIT_FUNC */
    "",                               /* EXCE_ALREADY_THROWN */
];
/* clang-format on */

void wasm_set_exception_with_id(WASMModuleInstance* module_inst, uint id) {
    if (id < EXCE_NUM)
        wasm_set_exception(module_inst, exception_msgs[id]);
    else
        wasm_set_exception(module_inst, "unknown exception");
}

const(char)* wasm_get_exception(WASMModuleInstance* module_inst) {
    if (module_inst.cur_exception[0] == '\0')
        return null;
    else
        return module_inst.cur_exception;
}

void wasm_runtime_set_exception(WASMModuleInstanceCommon* module_inst_comm, const(char)* exception) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    wasm_set_exception(module_inst, exception);
}

const(char)* wasm_runtime_get_exception(WASMModuleInstanceCommon* module_inst_comm) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    return wasm_get_exception(module_inst);
}

void wasm_runtime_clear_exception(WASMModuleInstanceCommon* module_inst_comm) {
    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    wasm_runtime_set_exception(module_inst_comm, null);
}

void wasm_runtime_set_custom_data_internal(WASMModuleInstanceCommon* module_inst_comm, void* custom_data) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    module_inst.custom_data = custom_data;
}

void wasm_runtime_set_custom_data(WASMModuleInstanceCommon* module_inst, void* custom_data) {
static if (WASM_ENABLE_THREAD_MGR != 0) {
    wasm_cluster_spread_custom_data(module_inst, custom_data);
} else {
    wasm_runtime_set_custom_data_internal(module_inst, custom_data);
}
}

void* wasm_runtime_get_custom_data(WASMModuleInstanceCommon* module_inst_comm) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    return module_inst.custom_data;
}

uint wasm_runtime_module_malloc(WASMModuleInstanceCommon* module_inst, uint size, void** p_native_addr) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode)
        return wasm_module_malloc(cast(WASMModuleInstance*)module_inst, size,
                                  p_native_addr);
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT)
        return aot_module_malloc(cast(AOTModuleInstance*)module_inst, size,
                                 p_native_addr);
}
    return 0;
}

uint wasm_runtime_module_realloc(WASMModuleInstanceCommon* module_inst, uint ptr, uint size, void** p_native_addr) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode)
        return wasm_module_realloc(cast(WASMModuleInstance*)module_inst, ptr, size,
                                   p_native_addr);
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT)
        return aot_module_realloc(cast(AOTModuleInstance*)module_inst, ptr, size,
                                  p_native_addr);
}
    return 0;
}

void wasm_runtime_module_free(WASMModuleInstanceCommon* module_inst, uint ptr) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        wasm_module_free(cast(WASMModuleInstance*)module_inst, ptr);
        return;
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        aot_module_free(cast(AOTModuleInstance*)module_inst, ptr);
        return;
    }
}
}

uint wasm_runtime_module_dup_data(WASMModuleInstanceCommon* module_inst, const(char)* src, uint size) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        return wasm_module_dup_data(cast(WASMModuleInstance*)module_inst, src,
                                    size);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        return aot_module_dup_data(cast(AOTModuleInstance*)module_inst, src, size);
    }
}
    return 0;
}

static if (WASM_ENABLE_LIBC_WASI != 0) {

private WASIArguments* get_wasi_args_from_module(wasm_module_t module_) {
    WASIArguments* wasi_args = null;

static if (WASM_ENABLE_INTERP != 0 || WASM_ENABLE_JIT != 0) {
    if (module_.module_type == Wasm_Module_Bytecode)
        wasi_args = &(cast(WASMModule*)module_).wasi_args;
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_.module_type == Wasm_Module_AoT)
        wasi_args = &(cast(AOTModule*)module_).wasi_args;
}

    return wasi_args;
}

void wasm_runtime_set_wasi_args_ex(WASMModuleCommon* module_, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env_list, uint env_count, char** argv, int argc, int stdinfd, int stdoutfd, int stderrfd) {
    WASIArguments* wasi_args = get_wasi_args_from_module(module_);

    if (wasi_args) {
        wasi_args.dir_list = dir_list;
        wasi_args.dir_count = dir_count;
        wasi_args.map_dir_list = map_dir_list;
        wasi_args.map_dir_count = map_dir_count;
        wasi_args.env = env_list;
        wasi_args.env_count = env_count;
        wasi_args.argv = argv;
        wasi_args.argc = cast(uint)argc;
        wasi_args.stdio[0] = stdinfd;
        wasi_args.stdio[1] = stdoutfd;
        wasi_args.stdio[2] = stderrfd;
    }
}

void wasm_runtime_set_wasi_args(WASMModuleCommon* module_, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env_list, uint env_count, char** argv, int argc) {
    wasm_runtime_set_wasi_args_ex(module_, dir_list, dir_count, map_dir_list,
                                  map_dir_count, env_list, env_count, argv,
                                  argc, -1, -1, -1);
}

void wasm_runtime_set_wasi_addr_pool(wasm_module_t module_, const(char)** addr_pool, uint addr_pool_size) {
    WASIArguments* wasi_args = get_wasi_args_from_module(module_);

    if (wasi_args) {
        wasi_args.addr_pool = addr_pool;
        wasi_args.addr_count = addr_pool_size;
    }
}

void wasm_runtime_set_wasi_ns_lookup_pool(wasm_module_t module_, const(char)** ns_lookup_pool, uint ns_lookup_pool_size) {
    WASIArguments* wasi_args = get_wasi_args_from_module(module_);

    if (wasi_args) {
        wasi_args.ns_lookup_pool = ns_lookup_pool;
        wasi_args.ns_lookup_count = ns_lookup_pool_size;
    }
}

static if (WASM_ENABLE_UVWASI == 0) {
private bool copy_string_array(const(char)** array, uint array_size, char** buf_ptr, char*** list_ptr, ulong* out_buf_size) {
    ulong buf_size = 0, total_size = void;
    uint buf_offset = 0, i = void;
    char* buf = null; char** list = null;

    for (i = 0; i < array_size; i++)
        buf_size += strlen(array[i]) + 1;

    /* We add +1 to generate null-terminated array of strings */
    total_size = (char*).sizeof * (cast(ulong)array_size + 1);
    if (total_size >= UINT32_MAX
        || (total_size > 0 && ((list = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        || buf_size >= UINT32_MAX
        || (buf_size > 0 && ((buf = wasm_runtime_malloc(cast(uint)buf_size)) == 0))) {

        if (buf)
            wasm_runtime_free(buf);
        if (list)
            wasm_runtime_free(list);
        return false;
    }

    for (i = 0; i < array_size; i++) {
        list[i] = buf + buf_offset;
        bh_strcpy_s(buf + buf_offset, cast(uint)buf_size - buf_offset, array[i]);
        buf_offset += cast(uint)(strlen(array[i]) + 1);
    }
    list[array_size] = null;

    *list_ptr = list;
    *buf_ptr = buf;
    if (out_buf_size)
        *out_buf_size = buf_size;

    return true;
}

bool wasm_runtime_init_wasi(WASMModuleInstanceCommon* module_inst, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env, uint env_count, const(char)** addr_pool, uint addr_pool_size, const(char)** ns_lookup_pool, uint ns_lookup_pool_size, char** argv, uint argc, int stdinfd, int stdoutfd, int stderrfd, char* error_buf, uint error_buf_size) {
    WASIContext* wasi_ctx = void;
    char* argv_buf = null;
    char** argv_list = null;
    char* env_buf = null;
    char** env_list = null;
    char* ns_lookup_buf = null;
    char** ns_lookup_list = null;
    ulong argv_buf_size = 0, env_buf_size = 0;
    fd_table* curfds = null;
    fd_prestats* prestats = null;
    argv_environ_values* argv_environ = null;
    addr_pool* apool = null;
    bool fd_table_inited = false, fd_prestats_inited = false;
    bool argv_environ_inited = false;
    bool addr_pool_inited = false;
    __wasi_fd_t wasm_fd = 3;
    int raw_fd = void;
    char* path = void; char[PATH_MAX] resolved_path = void;
    uint i = void;

    if (((wasi_ctx = runtime_malloc(WASIContext.sizeof, null, error_buf,
                                    error_buf_size)) == 0)) {
        return false;
    }

    wasm_runtime_set_wasi_ctx(module_inst, wasi_ctx);

    /* process argv[0], trip the path and suffix, only keep the program name */
    if (!copy_string_array(cast(const(char)**)argv, argc, &argv_buf, &argv_list,
                           &argv_buf_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    if (!copy_string_array(env, env_count, &env_buf, &env_list,
                           &env_buf_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    if (((curfds = wasm_runtime_malloc(fd_table.sizeof)) == 0)
        || ((prestats = wasm_runtime_malloc(fd_prestats.sizeof)) == 0)
        || ((argv_environ =
                 wasm_runtime_malloc(argv_environ_values.sizeof)) == 0)
        || ((apool = wasm_runtime_malloc(addr_pool.sizeof)) == 0)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    if (!fd_table_init(curfds)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      ~ "init fd table failed");
        goto fail;
    }
    fd_table_inited = true;

    if (!fd_prestats_init(prestats)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      ~ "init fd prestats failed");
        goto fail;
    }
    fd_prestats_inited = true;

    if (!argv_environ_init(argv_environ, argv_buf, argv_buf_size, argv_list,
                           argc, env_buf, env_buf_size, env_list, env_count)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      ~ "init argument environment failed");
        goto fail;
    }
    argv_environ_inited = true;

    if (!addr_pool_init(apool)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      ~ "init the address pool failed");
        goto fail;
    }
    addr_pool_inited = true;

    /* Prepopulate curfds with stdin, stdout, and stderr file descriptors.
     *
     * If -1 is given, use STDIN_FILENO (0), STDOUT_FILENO (1),
     * STDERR_FILENO (2) respectively.
     */
    if (!fd_table_insert_existing(curfds, 0, (stdinfd != -1) ? stdinfd : 0)
        || !fd_table_insert_existing(curfds, 1, (stdoutfd != -1) ? stdoutfd : 1)
        || !fd_table_insert_existing(curfds, 2,
                                     (stderrfd != -1) ? stderrfd : 2)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: init fd table failed");
        goto fail;
    }

    wasm_fd = 3;
    for (i = 0; i < dir_count; i++, wasm_fd++) {
        path = realpath(dir_list[i], resolved_path.ptr);
        if (!path) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening directory %s: %d\n",
                         dir_list[i], errno);
            goto fail;
        }

        raw_fd = open(path, O_RDONLY | O_DIRECTORY, 0);
        if (raw_fd == -1) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening directory %s: %d\n",
                         dir_list[i], errno);
            goto fail;
        }

        fd_table_insert_existing(curfds, wasm_fd, raw_fd);
        fd_prestats_insert(prestats, dir_list[i], wasm_fd);
    }

    /* addr_pool(textual) -> apool */
    for (i = 0; i < addr_pool_size; i++) {
        char* cp = void, address = void, mask = void;
        bool ret = false;

        cp = bh_strdup(addr_pool[i]);
        if (!cp) {
            set_error_buf(error_buf, error_buf_size,
                          "Init wasi environment failed: copy address failed");
            goto fail;
        }

        address = strtok(cp, "/");
        mask = strtok(null, "/");

        ret = addr_pool_insert(apool, address, cast(ubyte)(mask ? atoi(mask) : 0));
        wasm_runtime_free(cp);
        if (!ret) {
            set_error_buf(error_buf, error_buf_size,
                          "Init wasi environment failed: store address failed");
            goto fail;
        }
    }

    if (!copy_string_array(ns_lookup_pool, ns_lookup_pool_size, &ns_lookup_buf,
                           &ns_lookup_list, null)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    wasi_ctx.curfds = curfds;
    wasi_ctx.prestats = prestats;
    wasi_ctx.argv_environ = argv_environ;
    wasi_ctx.addr_pool = apool;
    wasi_ctx.argv_buf = argv_buf;
    wasi_ctx.argv_list = argv_list;
    wasi_ctx.env_buf = env_buf;
    wasi_ctx.env_list = env_list;
    wasi_ctx.ns_lookup_buf = ns_lookup_buf;
    wasi_ctx.ns_lookup_list = ns_lookup_list;

    return true;

fail:
    if (argv_environ_inited)
        argv_environ_destroy(argv_environ);
    if (fd_prestats_inited)
        fd_prestats_destroy(prestats);
    if (fd_table_inited)
        fd_table_destroy(curfds);
    if (addr_pool_inited)
        addr_pool_destroy(apool);
    if (curfds)
        wasm_runtime_free(curfds);
    if (prestats)
        wasm_runtime_free(prestats);
    if (argv_environ)
        wasm_runtime_free(argv_environ);
    if (apool)
        wasm_runtime_free(apool);
    if (argv_buf)
        wasm_runtime_free(argv_buf);
    if (argv_list)
        wasm_runtime_free(argv_list);
    if (env_buf)
        wasm_runtime_free(env_buf);
    if (env_list)
        wasm_runtime_free(env_list);
    if (ns_lookup_buf)
        wasm_runtime_free(ns_lookup_buf);
    if (ns_lookup_list)
        wasm_runtime_free(ns_lookup_list);
    return false;
}
} else {  /* else of WASM_ENABLE_UVWASI == 0 */
private void* wasm_uvwasi_malloc(size_t size, void* mem_user_data) {
    return runtime_malloc(size, null, null, 0);
    cast(void)mem_user_data;
}

private void wasm_uvwasi_free(void* ptr, void* mem_user_data) {
    if (ptr)
        wasm_runtime_free(ptr);
    cast(void)mem_user_data;
}

private void* wasm_uvwasi_calloc(size_t nmemb, size_t size, void* mem_user_data) {
    ulong total_size = cast(ulong)nmemb * size;
    return runtime_malloc(total_size, null, null, 0);
    cast(void)mem_user_data;
}

private void* wasm_uvwasi_realloc(void* ptr, size_t size, void* mem_user_data) {
    if (size >= UINT32_MAX) {
        return null;
    }
    return wasm_runtime_realloc(ptr, cast(uint)size);
}

/* clang-format off */
private uvwasi_mem_t uvwasi_allocator = {
    mem_user_data: 0,
    malloc: wasm_uvwasi_malloc,
    free: wasm_uvwasi_free,
    calloc: wasm_uvwasi_calloc,
    realloc: wasm_uvwasi_realloc
};
/* clang-format on */

bool wasm_runtime_init_wasi(WASMModuleInstanceCommon* module_inst, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env, uint env_count, const(char)** addr_pool, uint addr_pool_size, const(char)** ns_lookup_pool, uint ns_lookup_pool_size, char** argv, uint argc, int stdinfd, int stdoutfd, int stderrfd, char* error_buf, uint error_buf_size) {
    WASIContext* ctx = void;
    uvwasi_t* uvwasi = void;
    uvwasi_options_t init_options = void;
    const(char)** envp = null;
    ulong total_size = void;
    uint i = void;
    bool ret = false;

    ctx = runtime_malloc(typeof(*ctx).sizeof, module_inst, error_buf, error_buf_size);
    if (!ctx)
        return false;
    uvwasi = &ctx.uvwasi;

    /* Setup the initialization options */
    uvwasi_options_init(&init_options);
    init_options.allocator = &uvwasi_allocator;
    init_options.argc = argc;
    init_options.argv = cast(const(char)**)argv;
    init_options.in_ = (stdinfd != -1) ? cast(uvwasi_fd_t)stdinfd : init_options.in_;
    init_options.out_ =
        (stdoutfd != -1) ? cast(uvwasi_fd_t)stdoutfd : init_options.out_;
    init_options.err =
        (stderrfd != -1) ? cast(uvwasi_fd_t)stderrfd : init_options.err;

    if (dir_count > 0) {
        init_options.preopenc = dir_count;

        total_size = uvwasi_preopen_t.sizeof * cast(ulong)init_options.preopenc;
        init_options.preopens = cast(uvwasi_preopen_t*)runtime_malloc(
            total_size, module_inst, error_buf, error_buf_size);
        if (init_options.preopens == null)
            goto fail;

        for (i = 0; i < init_options.preopenc; i++) {
            init_options.preopens[i].real_path = dir_list[i];
            init_options.preopens[i].mapped_path =
                (i < map_dir_count) ? map_dir_list[i] : dir_list[i];
        }
    }

    if (env_count > 0) {
        total_size = (char*).sizeof * cast(ulong)(env_count + 1);
        envp =
            runtime_malloc(total_size, module_inst, error_buf, error_buf_size);
        if (envp == null)
            goto fail;

        for (i = 0; i < env_count; i++) {
            envp[i] = env[i];
        }
        envp[env_count] = null;
        init_options.envp = envp;
    }

    if (UVWASI_ESUCCESS != uvwasi_init(uvwasi, &init_options)) {
        set_error_buf(error_buf, error_buf_size, "uvwasi init failed");
        goto fail;
    }

    wasm_runtime_set_wasi_ctx(module_inst, ctx);

    ret = true;

fail:
    if (envp)
        wasm_runtime_free(cast(void*)envp);

    if (init_options.preopens)
        wasm_runtime_free(init_options.preopens);

    if (!ret && uvwasi)
        wasm_runtime_free(uvwasi);

    return ret;
}
} /* end of WASM_ENABLE_UVWASI */

bool wasm_runtime_is_wasi_mode(WASMModuleInstanceCommon* module_inst) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode
        && (cast(WASMModuleInstance*)module_inst).module_.import_wasi_api)
        return true;
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT
        && (cast(AOTModule*)(cast(AOTModuleInstance*)module_inst).module_)
               .import_wasi_api)
        return true;
}
    return false;
}

WASMFunctionInstanceCommon* wasm_runtime_lookup_wasi_start_function(WASMModuleInstanceCommon* module_inst) {
    uint i = void;

static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance* wasm_inst = cast(WASMModuleInstance*)module_inst;
        WASMFunctionInstance* func = void;
        for (i = 0; i < wasm_inst.export_func_count; i++) {
            if (!strcmp(wasm_inst.export_functions[i].name, "_start")) {
                func = wasm_inst.export_functions[i].function_;
                if (func.u.func.func_type.param_count != 0
                    || func.u.func.func_type.result_count != 0) {
                    LOG_ERROR("Lookup wasi _start function failed: "
                              ~ "invalid function type.\n");
                    return null;
                }
                return cast(WASMFunctionInstanceCommon*)func;
            }
        }
        return null;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* aot_inst = cast(AOTModuleInstance*)module_inst;
        AOTFunctionInstance* export_funcs = cast(AOTFunctionInstance*)aot_inst.export_functions;
        for (i = 0; i < aot_inst.export_func_count; i++) {
            if (!strcmp(export_funcs[i].func_name, "_start")) {
                AOTFuncType* func_type = export_funcs[i].u.func.func_type;
                if (func_type.param_count != 0
                    || func_type.result_count != 0) {
                    LOG_ERROR("Lookup wasi _start function failed: "
                              ~ "invalid function type.\n");
                    return null;
                }
                return cast(WASMFunctionInstanceCommon*)&export_funcs[i];
            }
        }
        return null;
    }
} /* end of WASM_ENABLE_AOT */

    return null;
}

static if (WASM_ENABLE_UVWASI == 0) {
void wasm_runtime_destroy_wasi(WASMModuleInstanceCommon* module_inst) {
    WASIContext* wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);

    if (wasi_ctx) {
        if (wasi_ctx.argv_environ) {
            argv_environ_destroy(wasi_ctx.argv_environ);
            wasm_runtime_free(wasi_ctx.argv_environ);
        }
        if (wasi_ctx.curfds) {
            fd_table_destroy(wasi_ctx.curfds);
            wasm_runtime_free(wasi_ctx.curfds);
        }
        if (wasi_ctx.prestats) {
            fd_prestats_destroy(wasi_ctx.prestats);
            wasm_runtime_free(wasi_ctx.prestats);
        }
        if (wasi_ctx.addr_pool) {
            addr_pool_destroy(wasi_ctx.addr_pool);
            wasm_runtime_free(wasi_ctx.addr_pool);
        }
        if (wasi_ctx.argv_buf)
            wasm_runtime_free(wasi_ctx.argv_buf);
        if (wasi_ctx.argv_list)
            wasm_runtime_free(wasi_ctx.argv_list);
        if (wasi_ctx.env_buf)
            wasm_runtime_free(wasi_ctx.env_buf);
        if (wasi_ctx.env_list)
            wasm_runtime_free(wasi_ctx.env_list);
        if (wasi_ctx.ns_lookup_buf)
            wasm_runtime_free(wasi_ctx.ns_lookup_buf);
        if (wasi_ctx.ns_lookup_list)
            wasm_runtime_free(wasi_ctx.ns_lookup_list);

        wasm_runtime_free(wasi_ctx);
    }
}
} else {
void wasm_runtime_destroy_wasi(WASMModuleInstanceCommon* module_inst) {
    WASIContext* wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);

    if (wasi_ctx) {
        uvwasi_destroy(&wasi_ctx.uvwasi);
        wasm_runtime_free(wasi_ctx);
    }
}
}

uint wasm_runtime_get_wasi_exit_code(WASMModuleInstanceCommon* module_inst) {
    WASIContext* wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);
    return wasi_ctx.exit_code;
}

WASIContext* wasm_runtime_get_wasi_ctx(WASMModuleInstanceCommon* module_inst_comm) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    return module_inst.wasi_ctx;
}

void wasm_runtime_set_wasi_ctx(WASMModuleInstanceCommon* module_inst_comm, WASIContext* wasi_ctx) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    module_inst.wasi_ctx = wasi_ctx;
}
} /* end of WASM_ENABLE_LIBC_WASI */

WASMModuleCommon* wasm_exec_env_get_module(WASMExecEnv* exec_env) {
    WASMModuleInstanceCommon* module_inst_comm = wasm_runtime_get_module_inst(exec_env);
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);
    return cast(WASMModuleCommon*)module_inst.module_;
}

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
const(ubyte)* wasm_runtime_get_custom_section(WASMModuleCommon* module_comm, const(char)* name, uint* len) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_comm.module_type == Wasm_Module_Bytecode)
        return wasm_loader_get_custom_section(cast(WASMModule*)module_comm, name,
                                              len);
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_comm.module_type == Wasm_Module_AoT)
        return aot_get_custom_section(cast(AOTModule*)module_comm, name, len);
}
    return null;
}
} /* end of WASM_ENABLE_LOAD_CUSTOM_SECTION != 0 */

union ___ue {
    int a;
    char b = 0;
}private ___ue __ue = { a: 1 };

enum string is_little_endian() = ` (__ue.b == 1)`;

bool wasm_runtime_register_natives(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols) {
    return wasm_native_register_natives(module_name, native_symbols,
                                        n_native_symbols);
}

bool wasm_runtime_register_natives_raw(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols) {
    return wasm_native_register_natives_raw(module_name, native_symbols,
                                            n_native_symbols);
}

bool wasm_runtime_unregister_natives(const(char)* module_name, NativeSymbol* native_symbols) {
    return wasm_native_unregister_natives(module_name, native_symbols);
}

bool wasm_runtime_invoke_native_raw(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
    WASMModuleInstanceCommon* module_ = wasm_runtime_get_module_inst(exec_env);
    alias NativeRawFuncPtr = void function(WASMExecEnv*, ulong*);
    NativeRawFuncPtr invokeNativeRaw = cast(NativeRawFuncPtr)func_ptr;
    ulong[16] argv_buf = 0; ulong* argv1 = argv_buf, argv_dst = void; ulong size = void;
    uint* argv_src = argv; uint i = void, argc1 = void, ptr_len = void;
    uint arg_i32 = void;
    bool ret = false;

    argc1 = func_type.param_count;
    if (argc1 > argv_buf.sizeof / uint64.sizeof) {
        size = uint64.sizeof * cast(ulong)argc1;
        if (((argv1 = runtime_malloc(cast(uint)size, exec_env.module_inst, null,
                                     0)) == 0)) {
            return false;
        }
    }

    argv_dst = argv1;

    /* Traverse secondly to fill in each argument */
    for (i = 0; i < func_type.param_count; i++, argv_dst++) {
        switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
            {
                *cast(uint*)argv_dst = arg_i32 = *argv_src++;
                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(module_, arg_i32,
                                                            ptr_len))
                            goto fail;

                        *cast(uintptr_t*)argv_dst =
                            cast(uintptr_t)wasm_runtime_addr_app_to_native(module_,
                                                                       arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(module_,
                                                                arg_i32))
                            goto fail;

                        *cast(uintptr_t*)argv_dst =
                            cast(uintptr_t)wasm_runtime_addr_app_to_native(module_,
                                                                       arg_i32);
                    }
                }
                break;
            }
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                bh_memcpy_s(argv_dst, uint64.sizeof, argv_src,
                            uint32.sizeof * 2);
                argv_src += 2;
                break;
            case VALUE_TYPE_F32:
                *cast(float32*)argv_dst = *cast(float32*)argv_src++;
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                uint externref_idx = *argv_src++;

                void* externref_obj = void;

                if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                    goto fail;

                bh_memcpy_s(argv_dst, uintptr_t.sizeof, argv_src,
                            uintptr_t.sizeof);
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }

    exec_env.attachment = attachment;
    invokeNativeRaw(exec_env, argv1);
    exec_env.attachment = null;

    if (func_type.result_count > 0) {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
                argv_ret[0] = *cast(uint*)argv1;
                break;
            case VALUE_TYPE_F32:
                *cast(float32*)argv_ret = *cast(float32*)argv1;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                bh_memcpy_s(argv_ret, uint32.sizeof * 2, argv1,
                            uint64.sizeof);
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                uint externref_idx = void;
                ulong externref_obj = void;

                bh_memcpy_s(&externref_obj, uint64.sizeof, argv1,
                            uint64.sizeof);

                if (!wasm_externref_obj2ref(exec_env.module_inst,
                                            cast(void*)cast(uintptr_t)externref_obj,
                                            &externref_idx))
                    goto fail;
                argv_ret[0] = externref_idx;
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }

    ret = !wasm_runtime_get_exception(module_) ? true : false;

fail:
    if (argv1 != argv_buf.ptr)
        wasm_runtime_free(argv1);
    return ret;
}

/**
 * Implementation of wasm_runtime_invoke_native()
 */

/* The invoke native implementation on ARM platform with VFP co-processor */
static if (HasVersion!"BUILD_TARGET_ARM_VFP" || HasVersion!"BUILD_TARGET_THUMB_VFP" 
    || HasVersion!"BUILD_TARGET_RISCV32_ILP32D"                          
    || HasVersion!"BUILD_TARGET_RISCV32_ILP32" || HasVersion!"BUILD_TARGET_ARC") {
alias GenericFunctionPointer = void function();
void invokeNative(GenericFunctionPointer f, uint* args, uint n_stacks);

alias Float64FuncPtr = float64 function(GenericFunctionPointer, uint*, uint);
alias Float32FuncPtr = float32 function(GenericFunctionPointer, uint*, uint);
alias Int64FuncPtr = long function(GenericFunctionPointer, uint*, uint);
alias Int32FuncPtr = int function(GenericFunctionPointer, uint*, uint);
alias VoidFuncPtr = void function(GenericFunctionPointer, uint*, uint);

private /*volatile*/ Float64FuncPtr invokeNative_Float64 = cast(Float64FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Float32FuncPtr invokeNative_Float32 = cast(Float32FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Int64FuncPtr invokeNative_Int64 = cast(Int64FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Int32FuncPtr invokeNative_Int32 = cast(Int32FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ VoidFuncPtr invokeNative_Void = cast(VoidFuncPtr)cast(uintptr_t)invokeNative;

static if (HasVersion!"BUILD_TARGET_ARM_VFP" || HasVersion!"BUILD_TARGET_THUMB_VFP") {
enum MAX_REG_INTS = 4;
enum MAX_REG_FLOATS = 16;
} else {
enum MAX_REG_INTS = 8;
enum MAX_REG_FLOATS = 8;
}

bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
    WASMModuleInstanceCommon* module_ = wasm_runtime_get_module_inst(exec_env);
    /* argv buf layout: int args(fix cnt) + float args(fix cnt) + stack args */
    uint[32] argv_buf = void; uint* argv1 = argv_buf, ints = void, stacks = void; uint size = void;
    uint* argv_src = argv; uint i = void, argc1 = void, n_ints = 0, n_stacks = 0;
    uint arg_i32 = void, ptr_len = void;
    uint result_count = func_type.result_count;
    uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    bool ret = false;
static if (WASM_ENABLE_REF_TYPES != 0) {
    bool is_aot_func = (null == signature);
}
static if (!HasVersion!"BUILD_TARGET_RISCV32_ILP32" && !HasVersion!"BUILD_TARGET_ARC") {
    uint* fps = void;
    int n_fps = 0;
} else {
enum fps = ints;
enum n_fps = n_ints;
}

    n_ints++; /* exec env */
    
    /* Traverse firstly to calculate stack args count */
    for (i = 0; i < func_type.param_count; i++) {
void value_type(int type)() {
	
}
        switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
//static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
//}
                if (n_ints < MAX_REG_INTS)
                    n_ints++;
                else
                    n_stacks++;
                break;
            case VALUE_TYPE_I64:
                if (n_ints < MAX_REG_INTS - 1) {
static if (HasVersion!"BUILD_TARGET_ARM_VFP" || HasVersion!"BUILD_TARGET_THUMB_VFP") {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_ints & 1) {
                        n_ints++;
					}
}
                    n_ints += 2;
                }
				else if ((HasVersion!"BUILD_TARGET_RISCV32_ILP32" 
    || HasVersion!"BUILD_TARGET_RISCV32_ILP32D" || HasVersion!"BUILD_TARGET_ARC")  &&
                /* part in register, part in stack */
                (n_ints == MAX_REG_INTS - 1)) {
                    n_ints++;
                    n_stacks++;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
static if (!HasVersion!"BUILD_TARGET_ARC") {
                    if (n_stacks & 1) {
                        n_stacks++;
					}	
}
                    n_stacks += 2;
                }
                break;
static if (!HasVersion!"BUILD_TARGET_RISCV32_ILP32D") {
            case VALUE_TYPE_F32:
                if (n_fps < MAX_REG_FLOATS)
                    n_fps++;
                else
                    n_stacks++;
                break;
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS - 1) {
static if (!HasVersion!"BUILD_TARGET_RISCV32_ILP32" && !HasVersion!"BUILD_TARGET_ARC") {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_fps & 1)
                        n_fps++;
}
                    n_fps += 2;
                }
                else if((HasVersion!"BUILD_TARGET_RISCV32_ILP32" || 
				HasVersion!"BUILD_TARGET_ARC")&&(n_fps == MAX_REG_FLOATS - 1)) {
                    n_fps++;
                    n_stacks++;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
static if (!HasVersion!"BUILD_TARGET_ARC") {
                    if (n_stacks & 1) {
                        n_stacks++;
						}
}
                    n_stacks += 2;
                }
                break;
} else {  /* BUILD_TARGET_RISCV32_ILP32D */
            case VALUE_TYPE_F32:
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS) {
                    n_fps++;
                }
                else if (func_type.types[i] == VALUE_TYPE_F32
                         && n_ints < MAX_REG_INTS) {
                    /* use int reg firstly if available */
                    n_ints++;
                }
                else if (func_type.types[i] == VALUE_TYPE_F64
                         && n_ints < MAX_REG_INTS - 1) {
                    /* use int regs firstly if available */
                    if (n_ints & 1)
                        n_ints++;
                    ints += 2;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned in riscv32
                     */
                    if (n_stacks & 1)
                        n_stacks++;
                    n_stacks += 2;
                }
                break;
} /* BUILD_TARGET_RISCV32_ILP32D */
            default:
                bh_assert(0);
                break;
        }
    }

    for (i = 0; i < ext_ret_count; i++) {
        if (n_ints < MAX_REG_INTS)
            n_ints++;
        else
            n_stacks++;
    }

static if (HasVersion!"BUILD_TARGET_ARM_VFP" || HasVersion!"BUILD_TARGET_THUMB_VFP") {
    argc1 = MAX_REG_INTS + MAX_REG_FLOATS + n_stacks;
} else static if (HasVersion!"BUILD_TARGET_RISCV32_ILP32" || HasVersion!"BUILD_TARGET_ARC") {
    argc1 = MAX_REG_INTS + n_stacks;
} else { /* for BUILD_TARGET_RISCV32_ILP32D */
    argc1 = MAX_REG_INTS + MAX_REG_FLOATS * 2 + n_stacks;
}

    if (argc1 > argv_buf.sizeof / uint32.sizeof) {
        size = uint32.sizeof * cast(uint)argc1;
        if (((argv1 = runtime_malloc(cast(uint)size, exec_env.module_inst, null,
                                     0)) == 0)) {
            return false;
        }
    }

    ints = argv1;
static if (HasVersion!"BUILD_TARGET_ARM_VFP" || HasVersion!"BUILD_TARGET_THUMB_VFP") {
    fps = ints + MAX_REG_INTS;
    stacks = fps + MAX_REG_FLOATS;
} else static if (HasVersion!"BUILD_TARGET_RISCV32_ILP32" || HasVersion!"BUILD_TARGET_ARC") {
    stacks = ints + MAX_REG_INTS;
} else { /* for BUILD_TARGET_RISCV32_ILP32D */
    fps = ints + MAX_REG_INTS;
    stacks = fps + MAX_REG_FLOATS * 2;
}

    n_ints = 0;
    n_fps = 0;
    n_stacks = 0;
    ints[n_ints++] = cast(uint)cast(uintptr_t)exec_env;

    /* Traverse secondly to fill in each argument */
    for (i = 0; i < func_type.param_count; i++) {
        switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
            {
                arg_i32 = *argv_src++;

                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(module_, arg_i32,
                                                            ptr_len))
                            goto fail;

                        arg_i32 = cast(uintptr_t)wasm_runtime_addr_app_to_native(
                            module_, arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(module_,
                                                                arg_i32))
                            goto fail;

                        arg_i32 = cast(uintptr_t)wasm_runtime_addr_app_to_native(
                            module_, arg_i32);
                    }
                }

                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = arg_i32;
                else
                    stacks[n_stacks++] = arg_i32;
                break;
            }
            case VALUE_TYPE_I64:
            {
                if (n_ints < MAX_REG_INTS - 1) {
static if (HasVersion!"BUILD_TARGET_ARM_VFP" || HasVersion!"BUILD_TARGET_THUMB_VFP") {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_ints & 1)
                        n_ints++;
}
                    ints[n_ints++] = *argv_src++;
                    ints[n_ints++] = *argv_src++;
                }
				else if ((HasVersion!"BUILD_TARGET_RISCV32_ILP32" 
    || HasVersion!"BUILD_TARGET_RISCV32_ILP32D" || HasVersion!"BUILD_TARGET_ARC") && 
                (n_ints == MAX_REG_INTS - 1)) {
                    ints[n_ints++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
static if (!HasVersion!"BUILD_TARGET_ARC") {
                    if (n_stacks & 1)
                        n_stacks++;
}
                    stacks[n_stacks++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
                break;
            }
static if (!HasVersion!"BUILD_TARGET_RISCV32_ILP32D") {
            case VALUE_TYPE_F32:
            {
                if (n_fps < MAX_REG_FLOATS)
                    *cast(float32*)&fps[n_fps++] = *cast(float32*)argv_src++;
                else
                    *cast(float32*)&stacks[n_stacks++] = *cast(float32*)argv_src++;
                break;
            }
            case VALUE_TYPE_F64:
            {
                if (n_fps < MAX_REG_FLOATS - 1) {
static if (!HasVersion!"BUILD_TARGET_RISCV32_ILP32" && !HasVersion!"BUILD_TARGET_ARC") {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_fps & 1)
                        n_fps++;
}
                    fps[n_fps++] = *argv_src++;
                    fps[n_fps++] = *argv_src++;
                }
						else if ((HasVersion!"BUILD_TARGET_RISCV32_ILP32" || HasVersion!"BUILD_TARGET_ARC") && 
                (n_fps == MAX_REG_FLOATS - 1)) {
                    fps[n_fps++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
static if (!HasVersion!"BUILD_TARGET_ARC") {
                    if (n_stacks & 1) {
                        n_stacks++;
									}
}
                    stacks[n_stacks++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
                break;
            }
} else {  /* BUILD_TARGET_RISCV32_ILP32D */
            case VALUE_TYPE_F32:
            case VALUE_TYPE_F64:
            {
                if (n_fps < MAX_REG_FLOATS) {
                    if (func_type.types[i] == VALUE_TYPE_F32) {
                        *cast(float32*)&fps[n_fps * 2] = *cast(float32*)argv_src++;
                        /* NaN boxing, the upper bits of a valid NaN-boxed
                          value must be all 1s. */
                        fps[n_fps * 2 + 1] = 0xFFFFFFFF;
                    }
                    else {
                        *cast(float64*)&fps[n_fps * 2] = *cast(float64*)argv_src;
                        argv_src += 2;
                    }
                    n_fps++;
                }
                else if (func_type.types[i] == VALUE_TYPE_F32
                         && n_ints < MAX_REG_INTS) {
                    /* use int reg firstly if available */
                    *cast(float32*)&ints[n_ints++] = *cast(float32*)argv_src++;
                }
                else if (func_type.types[i] == VALUE_TYPE_F64
                         && n_ints < MAX_REG_INTS - 1) {
                    /* use int regs firstly if available */
                    if (n_ints & 1)
                        n_ints++;
                    *cast(float64*)&ints[n_ints] = *cast(float64*)argv_src;
                    n_ints += 2;
                    argv_src += 2;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned in riscv32
                     */
                    if (n_stacks & 1)
                        n_stacks++;
                    if (func_type.types[i] == VALUE_TYPE_F32) {
                        *cast(float32*)&stacks[n_stacks] = *cast(float32*)argv_src++;
                        /* NaN boxing, the upper bits of a valid NaN-boxed
                          value must be all 1s. */
                        stacks[n_stacks + 1] = 0xFFFFFFFF;
                    }
                    else {
                        *cast(float64*)&stacks[n_stacks] = *cast(float64*)argv_src;
                        argv_src += 2;
                    }
                    n_stacks += 2;
                }
                break;
            }
} /* BUILD_TARGET_RISCV32_ILP32D */
//static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                uint externref_idx = *argv_src++;

                if (is_aot_func) {
                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = externref_idx;
                    else
                        stacks[n_stacks++] = externref_idx;
                }
                else {
                    void* externref_obj;

                    if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                        goto fail;

                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = cast(uintptr_t)externref_obj;
                    else
                        stacks[n_stacks++] = cast(uintptr_t)externref_obj;
                }
                break;
            }
//}
            default:
                bh_assert(0);
                break;
        }
    }

    /* Save extra result values' address to argv1 */
    for (i = 0; i < ext_ret_count; i++) {
        if (n_ints < MAX_REG_INTS)
            ints[n_ints++] = *cast(uint*)argv_src++;
        else
            stacks[n_stacks++] = *cast(uint*)argv_src++;
    }

    exec_env.attachment = attachment;
    if (func_type.result_count == 0) {
        invokeNative_Void(func_ptr, argv1, n_stacks);
    }
    else {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
//static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
//}
                argv_ret[0] =
                    cast(uint)invokeNative_Int32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_I64:
                PUT_I64_TO_ADDR(argv_ret,
                                invokeNative_Int64(func_ptr, argv1, n_stacks));
                break;
            case VALUE_TYPE_F32:
                *cast(float32*)argv_ret =
                    invokeNative_Float32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(
                    argv_ret, invokeNative_Float64(func_ptr, argv1, n_stacks));
                break;
//static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                if (is_aot_func) {
                    uint externref_idx = cast(uint)invokeNative_Int32(func_ptr, argv1, argc1);
                    argv_ret[0] = externref_idx;
                }
                else {
                    uint externref_idx;
                    void* externref_obj;

                    externref_obj = cast(void*)cast(uintptr_t)invokeNative_Int32(
                        func_ptr, argv1, argc1);

                    if (!wasm_externref_obj2ref(exec_env.module_inst,
                                                externref_obj, &externref_idx))
                        goto fail;

                    argv_ret[0] = externref_idx;
                }
                break;
            }
//}
            default:
                bh_assert(0);
                break;
        }
    }
    exec_env.attachment = null;

    ret = !wasm_runtime_get_exception(module_) ? true : false;

fail:
    if (argv1 != argv_buf)
        wasm_runtime_free(argv1);
    return ret;
}
} /* end of defined(BUILD_TARGET_ARM_VFP)    \
          || defined(BUILD_TARGET_THUMB_VFP)      \
          || defined(BUILD_TARGET_RISCV32_ILP32D) \
          || defined(BUILD_TARGET_RISCV32_ILP32)  \
          || defined(BUILD_TARGET_ARC) */

static if (HasVersion!"BUILD_TARGET_X86_32" || HasVersion!"BUILD_TARGET_ARM"    
    || HasVersion!"BUILD_TARGET_THUMB" || HasVersion!"BUILD_TARGET_MIPS" 
    || HasVersion!"BUILD_TARGET_XTENSA") {
alias GenericFunctionPointer = void function();
void invokeNative(GenericFunctionPointer f, uint* args, uint sz);

alias Float64FuncPtr = float64 function(GenericFunctionPointer f, uint*, uint);
alias Float32FuncPtr = float32 function(GenericFunctionPointer f, uint*, uint);
alias Int64FuncPtr = long function(GenericFunctionPointer f, uint*, uint);
alias Int32FuncPtr = int function(GenericFunctionPointer f, uint*, uint);
alias VoidFuncPtr = void function(GenericFunctionPointer f, uint*, uint);

private /*volatile*/ Int64FuncPtr invokeNative_Int64 = cast(Int64FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Int32FuncPtr invokeNative_Int32 = cast(Int32FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Float64FuncPtr invokeNative_Float64 = cast(Float64FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Float32FuncPtr invokeNative_Float32 = cast(Float32FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ VoidFuncPtr invokeNative_Void = cast(VoidFuncPtr)cast(uintptr_t)invokeNative;

pragma(inline, true) private void word_copy(uint* dest, uint* src, uint num) {
    for (; num > 0; num--)
        *dest++ = *src++;
}

bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
    WASMModuleInstanceCommon* module_ = wasm_runtime_get_module_inst(exec_env);
    uint[32] argv_buf = void; uint* argv1 = argv_buf; uint argc1 = void, i = void, j = 0;
    uint arg_i32 = void, ptr_len = void;
    uint result_count = func_type.result_count;
    uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    ulong size = void;
    bool ret = false;
static if (WASM_ENABLE_REF_TYPES != 0) {
    bool is_aot_func = (null == signature);
}

version (BUILD_TARGET_X86_32) {
    argc1 = argc + ext_ret_count + 2;
} else {
    /* arm/thumb/mips/xtensa, 64-bit data must be 8 bytes aligned,
       so we need to allocate more memory. */
    argc1 = func_type.param_count * 2 + ext_ret_count + 2;
}

    if (argc1 > argv_buf.sizeof / uint32.sizeof) {
        size = uint32.sizeof * cast(ulong)argc1;
        if (((argv1 = runtime_malloc(cast(uint)size, exec_env.module_inst, null,
                                     0)) == 0)) {
            return false;
        }
    }

    for (i = 0; i < (WASMExecEnv*).sizeof / uint32.sizeof; i++)
        argv1[j++] = (cast(uint*)&exec_env)[i];

    for (i = 0; i < func_type.param_count; i++) {
        switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
            {
                arg_i32 = *argv++;

                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(module_, arg_i32,
                                                            ptr_len))
                            goto fail;

                        arg_i32 = cast(uintptr_t)wasm_runtime_addr_app_to_native(
                            module_, arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(module_,
                                                                arg_i32))
                            goto fail;

                        arg_i32 = cast(uintptr_t)wasm_runtime_addr_app_to_native(
                            module_, arg_i32);
                    }
                }

                argv1[j++] = arg_i32;
                break;
            }
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
static if (!HasVersion!"BUILD_TARGET_X86_32") {
                /* 64-bit data must be 8 bytes aligned in arm, thumb, mips
                   and xtensa */
                if (j & 1)
                    j++;
}
                argv1[j++] = *argv++;
                argv1[j++] = *argv++;
                break;
            case VALUE_TYPE_F32:
                argv1[j++] = *argv++;
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                uint externref_idx = *argv++;
                if (is_aot_func) {
                    argv1[j++] = externref_idx;
                }
                else {
                    void* externref_obj = void;

                    if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                        goto fail;

                    argv1[j++] = cast(uintptr_t)externref_obj;
                }
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }

    /* Save extra result values' address to argv1 */
    word_copy(argv1 + j, argv, ext_ret_count);

    argc1 = j + ext_ret_count;
    exec_env.attachment = attachment;
    if (func_type.result_count == 0) {
        invokeNative_Void(func_ptr, argv1, argc1);
    }
    else {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
                argv_ret[0] =
                    cast(uint)invokeNative_Int32(func_ptr, argv1, argc1);
                break;
            case VALUE_TYPE_I64:
                PUT_I64_TO_ADDR(argv_ret,
                                invokeNative_Int64(func_ptr, argv1, argc1));
                break;
            case VALUE_TYPE_F32:
                *cast(float32*)argv_ret =
                    invokeNative_Float32(func_ptr, argv1, argc1);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(argv_ret,
                                invokeNative_Float64(func_ptr, argv1, argc1));
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                if (is_aot_func) {
                    uint externref_idx = cast(uint)invokeNative_Int32(func_ptr, argv1, argc1);
                    argv_ret[0] = externref_idx;
                }
                else {
                    void* externref_obj = cast(void*)cast(uintptr_t)invokeNative_Int32(
                        func_ptr, argv1, argc1);
                    uint externref_idx = void;
                    if (!wasm_externref_obj2ref(exec_env.module_inst,
                                                externref_obj, &externref_idx))
                        goto fail;
                    argv_ret[0] = externref_idx;
                }
                break;
            }
}
            default:
                bh_assert(0);
                break;
        }
    }
    exec_env.attachment = null;

    ret = !wasm_runtime_get_exception(module_) ? true : false;

fail:
    if (argv1 != argv_buf.ptr)
        wasm_runtime_free(argv1);
    return ret;
}

} /* end of defined(BUILD_TARGET_X86_32)   \
                 || defined(BUILD_TARGET_ARM)   \
                 || defined(BUILD_TARGET_THUMB) \
                 || defined(BUILD_TARGET_MIPS)  \
                 || defined(BUILD_TARGET_XTENSA) */

static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64"            
    || HasVersion!"BUILD_TARGET_AARCH64" || HasVersion!"BUILD_TARGET_RISCV64_LP64D" 
    || HasVersion!"BUILD_TARGET_RISCV64_LP64") {


static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
union  V128 {
	align(8):
    byte[16] m128i_i8;
    short[8] m128i_i16;
    int[4] m128i_i32;
    long[2] m128i_i64;
    uint[16] m128i_u8;
    uint[8] m128i_u16;
    uint[4] m128i_u32;
    uint[2] m128i_u64;
} 
V128 v128;
} 
else static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64" 
    || HasVersion!"BUILD_TARGET_RISCV64_LP64D"                         
    || HasVersion!"BUILD_TARGET_RISCV64_LP64") {
long[2] v128;
} 
else {
version (BUILD_TARGET_AARCH64) {
public import arm_neon;
uint32x4_t v128;
}
}


alias GenericFunctionPointer = void function();
void invokeNative(GenericFunctionPointer f, ulong* args, ulong n_stacks);

alias Float64FuncPtr = float64 function(GenericFunctionPointer, ulong*, ulong);
alias Float32FuncPtr = float32 function(GenericFunctionPointer, ulong*, ulong);
alias Int64FuncPtr = long function(GenericFunctionPointer, ulong*, ulong);
alias Int32FuncPtr = int function(GenericFunctionPointer, ulong*, ulong);
alias VoidFuncPtr = void function(GenericFunctionPointer, ulong*, ulong);

private /*volatile*/ Float64FuncPtr invokeNative_Float64 = cast(Float64FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Float32FuncPtr invokeNative_Float32 = cast(Float32FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Int64FuncPtr invokeNative_Int64 = cast(Int64FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ Int32FuncPtr invokeNative_Int32 = cast(Int32FuncPtr)cast(uintptr_t)invokeNative;
private /*volatile*/ VoidFuncPtr invokeNative_Void = cast(VoidFuncPtr)cast(uintptr_t)invokeNative;

static if (WASM_ENABLE_SIMD != 0) {
alias V128FuncPtr = v128 function(GenericFunctionPointer, ulong*, ulong);
private V128FuncPtr invokeNative_V128 = cast(V128FuncPtr)cast(uintptr_t)invokeNative;
}

static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
enum MAX_REG_FLOATS = 4;
enum MAX_REG_INTS = 4;
} else { /* else of defined(_WIN32) || defined(_WIN32_) */
enum MAX_REG_FLOATS = 8;
static if (HasVersion!"BUILD_TARGET_AARCH64" || HasVersion!"BUILD_TARGET_RISCV64_LP64D" 
    || HasVersion!"BUILD_TARGET_RISCV64_LP64") {
enum MAX_REG_INTS = 8;
} else {
enum MAX_REG_INTS = 6;
} /* end of defined(BUILD_TARGET_AARCH64)   \
          || defined(BUILD_TARGET_RISCV64_LP64D) \
          || defined(BUILD_TARGET_RISCV64_LP64) */
} /* end of defined(_WIN32) || defined(_WIN32_) */

bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
    WASMModuleInstanceCommon* module_ = wasm_runtime_get_module_inst(exec_env);
    ulong[32] argv_buf = 0; ulong* argv1 = argv_buf, ints = void, stacks = void; ulong size = void, arg_i64 = void;
    uint* argv_src = argv; uint i = void, argc1 = void, n_ints = 0, n_stacks = 0;
    uint arg_i32 = void, ptr_len = void;
    uint result_count = func_type.result_count;
    uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    bool ret = false;
static if (WASM_ENABLE_REF_TYPES != 0) {
    bool is_aot_func = (null == signature);
}
version (BUILD_TARGET_RISCV64_LP64) {} else {
static if (WASM_ENABLE_SIMD == 0) {
    ulong* fps = void;
} else {
    v128* fps = void;
}
} version (BUILD_TARGET_RISCV64_LP64) { /* else of BUILD_TARGET_RISCV64_LP64 */
enum fps = ints;
} /* end of BUILD_TARGET_RISCV64_LP64 */

static if (HasVersion!"Windows" || HasVersion!"_WIN32_" || HasVersion!"BUILD_TARGET_RISCV64_LP64") {
    /* important difference in calling conventions */
enum n_fps = n_ints;
} else {
    int n_fps = 0;
}

static if (WASM_ENABLE_SIMD == 0) {
    argc1 = 1 + MAX_REG_FLOATS + cast(uint)func_type.param_count + ext_ret_count;
} else {
    argc1 = 1 + MAX_REG_FLOATS * 2 + cast(uint)func_type.param_count * 2
            + ext_ret_count;
}
    if (argc1 > argv_buf.sizeof / uint64.sizeof) {
        size = uint64.sizeof * cast(ulong)argc1;
        if (((argv1 = runtime_malloc(cast(uint)size, exec_env.module_inst, null,
                                     0)) == 0)) {
            return false;
        }
    }

version (BUILD_TARGET_RISCV64_LP64) {} else {
static if (WASM_ENABLE_SIMD == 0) {
    fps = argv1;
    ints = fps + MAX_REG_FLOATS;
} else {
    fps = cast(v128*)argv1;
    ints = cast(ulong*)(fps + MAX_REG_FLOATS);
}
} version (BUILD_TARGET_RISCV64_LP64) {  /* else of BUILD_TARGET_RISCV64_LP64 */
    ints = argv1;
} /* end of BUILD_TARGET_RISCV64_LP64 */
    stacks = ints + MAX_REG_INTS;

    ints[n_ints++] = cast(ulong)cast(uintptr_t)exec_env;

    for (i = 0; i < func_type.param_count; i++) {
        switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
            {
                arg_i32 = *argv_src++;
                arg_i64 = arg_i32;
                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(module_, arg_i32,
                                                            ptr_len))
                            goto fail;

                        arg_i64 = cast(uintptr_t)wasm_runtime_addr_app_to_native(
                            module_, arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(module_,
                                                                arg_i32))
                            goto fail;

                        arg_i64 = cast(uintptr_t)wasm_runtime_addr_app_to_native(
                            module_, arg_i32);
                    }
                }
                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = arg_i64;
                else
                    stacks[n_stacks++] = arg_i64;
                break;
            }
            case VALUE_TYPE_I64:
                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = *cast(ulong*)argv_src;
                else
                    stacks[n_stacks++] = *cast(ulong*)argv_src;
                argv_src += 2;
                break;
            case VALUE_TYPE_F32:
                if (n_fps < MAX_REG_FLOATS) {
                    *cast(float32*)&fps[n_fps++] = *cast(float32*)argv_src++;
                }
                else {
                    *cast(float32*)&stacks[n_stacks++] = *cast(float32*)argv_src++;
                }
                break;
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS) {
                    *cast(float64*)&fps[n_fps++] = *cast(float64*)argv_src;
                }
                else {
                    *cast(float64*)&stacks[n_stacks++] = *cast(float64*)argv_src;
                }
                argv_src += 2;
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                uint externref_idx = *argv_src++;
                if (is_aot_func) {
                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = externref_idx;
                    else
                        stacks[n_stacks++] = externref_idx;
                }
                else {
                    void* externref_obj = void;

                    if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                        goto fail;

                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = cast(uintptr_t)externref_obj;
                    else
                        stacks[n_stacks++] = cast(uintptr_t)externref_obj;
                }
                break;
            }
}
static if (WASM_ENABLE_SIMD != 0) {
            case VALUE_TYPE_V128:
                if (n_fps < MAX_REG_FLOATS) {
                    *cast(v128*)&fps[n_fps++] = *cast(v128*)argv_src;
                }
                else {
                    *cast(v128*)&stacks[n_stacks++] = *cast(v128*)argv_src;
                    n_stacks++;
                }
                argv_src += 4;
                break;
}
            default:
                bh_assert(0);
                break;
        }
    }

    /* Save extra result values' address to argv1 */
    for (i = 0; i < ext_ret_count; i++) {
        if (n_ints < MAX_REG_INTS)
            ints[n_ints++] = *cast(ulong*)argv_src;
        else
            stacks[n_stacks++] = *cast(ulong*)argv_src;
        argv_src += 2;
    }

    exec_env.attachment = attachment;
    if (result_count == 0) {
        invokeNative_Void(func_ptr, argv1, n_stacks);
    }
    else {
        /* Invoke the native function and get the first result value */
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
}
                argv_ret[0] =
                    cast(uint)invokeNative_Int32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_I64:
                PUT_I64_TO_ADDR(argv_ret,
                                invokeNative_Int64(func_ptr, argv1, n_stacks));
                break;
            case VALUE_TYPE_F32:
                *cast(float32*)argv_ret =
                    invokeNative_Float32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(
                    argv_ret, invokeNative_Float64(func_ptr, argv1, n_stacks));
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            {
                if (is_aot_func) {
                    argv_ret[0] = invokeNative_Int32(func_ptr, argv1, n_stacks);
                }
                else {
                    uint externref_idx = void;
                    void* externref_obj = cast(void*)cast(uintptr_t)invokeNative_Int64(
                        func_ptr, argv1, n_stacks);

                    if (!wasm_externref_obj2ref(exec_env.module_inst,
                                                externref_obj, &externref_idx))
                        goto fail;

                    argv_ret[0] = externref_idx;
                }
                break;
            }
}
static if (WASM_ENABLE_SIMD != 0) {
            case VALUE_TYPE_V128:
                *cast(v128*)argv_ret =
                    invokeNative_V128(func_ptr, argv1, n_stacks);
                break;
}
            default:
                bh_assert(0);
                break;
        }
    }
    exec_env.attachment = null;

    ret = !wasm_runtime_get_exception(module_) ? true : false;
fail:
    if (argv1 != argv_buf.ptr)
        wasm_runtime_free(argv1);

    return ret;
}

} /* end of defined(BUILD_TARGET_X86_64)           \
                 || defined(BUILD_TARGET_AMD_64)        \
                 || defined(BUILD_TARGET_AARCH64)       \
                 || defined(BUILD_TARGET_RISCV64_LP64D) \
                 || defined(BUILD_TARGET_RISCV64_LP64) */

bool wasm_runtime_call_indirect(WASMExecEnv* exec_env, uint element_indices, uint argc, uint* argv) {
    if (!wasm_runtime_exec_env_check(exec_env)) {
        LOG_ERROR("Invalid exec env stack info.");
        return false;
    }

    /* this function is called from native code, so exec_env->handle and
       exec_env->native_stack_boundary must have been set, we don't set
       it again */

static if (WASM_ENABLE_INTERP != 0) {
    if (exec_env.module_inst.module_type == Wasm_Module_Bytecode)
        return wasm_call_indirect(exec_env, 0, element_indices, argc, argv);
}
static if (WASM_ENABLE_AOT != 0) {
    if (exec_env.module_inst.module_type == Wasm_Module_AoT)
        return aot_call_indirect(exec_env, 0, element_indices, argc, argv);
}
    return false;
}

private void exchange_uint32(ubyte* p_data) {
    ubyte value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;

    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

private void exchange_uint64(ubyte* p_data) {
    uint value = void;

    value = *cast(uint*)p_data;
    *cast(uint*)p_data = *cast(uint*)(p_data + 4);
    *cast(uint*)(p_data + 4) = value;
    exchange_uint32(p_data);
    exchange_uint32(p_data + 4);
}

void wasm_runtime_read_v128(const(ubyte)* bytes, ulong* ret1, ulong* ret2) {
    ulong u1 = void, u2 = void;

    bh_memcpy_s(&u1, 8, bytes, 8);
    bh_memcpy_s(&u2, 8, bytes + 8, 8);

    if (!is_little_endian()) {
        exchange_uint64(cast(ubyte*)&u1);
        exchange_uint64(cast(ubyte*)&u2);
        *ret1 = u2;
        *ret2 = u1;
    }
    else {
        *ret1 = u1;
        *ret2 = u2;
    }
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
struct WASMThreadArg {
    WASMExecEnv* new_exec_env;
    wasm_thread_callback_t callback;
    void* arg;
}

WASMExecEnv* wasm_runtime_spawn_exec_env(WASMExecEnv* exec_env) {
    return wasm_cluster_spawn_exec_env(exec_env);
}

void wasm_runtime_destroy_spawned_exec_env(WASMExecEnv* exec_env) {
    wasm_cluster_destroy_spawned_exec_env(exec_env);
}

private void* wasm_runtime_thread_routine(void* arg) {
    WASMThreadArg* thread_arg = cast(WASMThreadArg*)arg;
    void* ret = void;

    bh_assert(thread_arg.new_exec_env);
    ret = thread_arg.callback(thread_arg.new_exec_env, thread_arg.arg);

    wasm_runtime_destroy_spawned_exec_env(thread_arg.new_exec_env);
    wasm_runtime_free(thread_arg);

    os_thread_exit(ret);
    return ret;
}

int wasm_runtime_spawn_thread(WASMExecEnv* exec_env, wasm_thread_t* tid, wasm_thread_callback_t callback, void* arg) {
    WASMExecEnv* new_exec_env = wasm_runtime_spawn_exec_env(exec_env);
    WASMThreadArg* thread_arg = void;
    int ret = void;

    if (!new_exec_env)
        return -1;

    if (((thread_arg = wasm_runtime_malloc(WASMThreadArg.sizeof)) == 0)) {
        wasm_runtime_destroy_spawned_exec_env(new_exec_env);
        return -1;
    }

    thread_arg.new_exec_env = new_exec_env;
    thread_arg.callback = callback;
    thread_arg.arg = arg;

    ret = os_thread_create(cast(korp_tid*)tid, &wasm_runtime_thread_routine,
                           thread_arg, APP_THREAD_STACK_SIZE_DEFAULT);

    if (ret != 0) {
        wasm_runtime_destroy_spawned_exec_env(new_exec_env);
        wasm_runtime_free(thread_arg);
    }

    return ret;
}

int wasm_runtime_join_thread(wasm_thread_t tid, void** retval) {
    return os_thread_join(cast(korp_tid)tid, retval);
}

} /* end of WASM_ENABLE_THREAD_MGR */

private korp_mutex externref_lock;
private uint externref_global_id = 1;
private HashMap* externref_map;

struct ExternRefMapNode {
    /* The extern object from runtime embedder */
    void* extern_obj;
    /* The module instance it belongs to */
    WASMModuleInstanceCommon* module_inst;
    /* Whether it is retained */
    bool retained;
    /* Whether it is marked by runtime */
    bool marked;
}

private uint wasm_externref_hash(const(void)* key) {
    uint externref_idx = cast(uint)cast(uintptr_t)key;
    return externref_idx;
}

private bool wasm_externref_equal(void* key1, void* key2) {
    uint externref_idx1 = cast(uint)cast(uintptr_t)key1;
    uint externref_idx2 = cast(uint)cast(uintptr_t)key2;
    return externref_idx1 == externref_idx2 ? true : false;
}

private bool wasm_externref_map_init() {
    if (os_mutex_init(&externref_lock) != 0)
        return false;

    if (((externref_map = bh_hash_map_create(32, false, &wasm_externref_hash,
                                             &wasm_externref_equal, null,
                                             wasm_runtime_free)) == 0)) {
        os_mutex_destroy(&externref_lock);
        return false;
    }

    externref_global_id = 1;
    return true;
}

private void wasm_externref_map_destroy() {
    bh_hash_map_destroy(externref_map);
    os_mutex_destroy(&externref_lock);
}

struct LookupExtObj_UserData {
    ExternRefMapNode node;
    bool found;
    uint externref_idx;
}

private void lookup_extobj_callback(void* key, void* value, void* user_data) {
    uint externref_idx = cast(uint)cast(uintptr_t)key;
    ExternRefMapNode* node = cast(ExternRefMapNode*)value;
    LookupExtObj_UserData* user_data_lookup = cast(LookupExtObj_UserData*)user_data;

    if (node.extern_obj == user_data_lookup.node.extern_obj
        && node.module_inst == user_data_lookup.node.module_inst) {
        user_data_lookup.found = true;
        user_data_lookup.externref_idx = externref_idx;
    }
}

bool
wasm_externref_obj2ref(WASMModuleInstanceCommon* module_inst, void* extern_obj,
                       uint* p_externref_idx)
{
    LookupExtObj_UserData lookup_user_data = { 0 };
    ExternRefMapNode* node;
    uint externref_idx;

    /*
     * to catch a parameter from `wasm_application_execute_func`,
     * which represents a string 'null'
     */
static if (UINTPTR_MAX == UINT32_MAX) {

    const _flag = (cast(uint)-1 == cast(uintptr_t)extern_obj);
	}
	else {

    const _flag = (cast(ulong)-1L == cast(uintptr_t)extern_obj); 
	}
		if(_flag) {
        *p_externref_idx = NULL_REF;
        return true;
    }

    /* in a wrapper, extern_obj could be any value */
    lookup_user_data.node.extern_obj = extern_obj;
    lookup_user_data.node.module_inst = module_inst;
    lookup_user_data.found = false;

    os_mutex_lock(&externref_lock);

    /* Lookup hashmap firstly */
    bh_hash_map_traverse(externref_map, &lookup_extobj_callback,
                         cast(void*)&lookup_user_data);
    if (lookup_user_data.found) {
        *p_externref_idx = lookup_user_data.externref_idx;
        os_mutex_unlock(&externref_lock);
        return true;
    }

    /* Not found in hashmap */
    if (externref_global_id == NULL_REF || externref_global_id == 0) {
        goto fail1;
    }

    if (((node = wasm_runtime_malloc(ExternRefMapNode.sizeof)) == 0)) {
        goto fail1;
    }

    memset(node, 0, ExternRefMapNode.sizeof);
    node.extern_obj = extern_obj;
    node.module_inst = module_inst;

    externref_idx = externref_global_id;

    if (!bh_hash_map_insert(externref_map, cast(void*)cast(uintptr_t)externref_idx,
                            cast(void*)node)) {
        goto fail2;
    }

    externref_global_id++;
    *p_externref_idx = externref_idx;
    os_mutex_unlock(&externref_lock);
    return true;
fail2:
    wasm_runtime_free(node);
fail1:
    os_mutex_unlock(&externref_lock);
    return false;
}

bool wasm_externref_ref2obj(uint externref_idx, void** p_extern_obj) {
    ExternRefMapNode* node = void;

    /* catch a `ref.null` vairable */
    if (externref_idx == NULL_REF) {
        *p_extern_obj = null;
        return true;
    }

    os_mutex_lock(&externref_lock);
    node = bh_hash_map_find(externref_map, cast(void*)cast(uintptr_t)externref_idx);
    os_mutex_unlock(&externref_lock);

    if (!node)
        return false;

    *p_extern_obj = node.extern_obj;
    return true;
}

private void reclaim_extobj_callback(void* key, void* value, void* user_data) {
    ExternRefMapNode* node = cast(ExternRefMapNode*)value;
    WASMModuleInstanceCommon* module_inst = cast(WASMModuleInstanceCommon*)user_data;

    if (node.module_inst == module_inst) {
        if (!node.marked && !node.retained) {
            bh_hash_map_remove(externref_map, key, null, null);
            wasm_runtime_free(value);
        }
        else {
            node.marked = false;
        }
    }
}

private void mark_externref(uint externref_idx) {
    ExternRefMapNode* node = void;

    if (externref_idx != NULL_REF) {
        node =
            bh_hash_map_find(externref_map, cast(void*)cast(uintptr_t)externref_idx);
        if (node) {
            node.marked = true;
        }
    }
}

static if (WASM_ENABLE_INTERP != 0) {
private void interp_mark_all_externrefs(WASMModuleInstance* module_inst) {
    uint i = void, j = void, externref_idx = void; uint* table_data = void;
    ubyte* global_data = module_inst.global_data;
    WASMGlobalInstance* global = void;
    WASMTableInstance* table = void;

    global = module_inst.e.globals;
    for (i = 0; i < module_inst.e.global_count; i++, global++) {
        if (global.type == VALUE_TYPE_EXTERNREF) {
            externref_idx = *cast(uint*)(global_data + global.data_offset);
            mark_externref(externref_idx);
        }
    }

    for (i = 0; i < module_inst.table_count; i++) {
        ubyte elem_type = 0;
        uint init_size = void, max_size = void;

        table = wasm_get_table_inst(module_inst, i);
        cast(void)wasm_runtime_get_table_inst_elem_type(
            cast(WASMModuleInstanceCommon*)module_inst, i, &elem_type, &init_size,
            &max_size);

        if (elem_type == VALUE_TYPE_EXTERNREF) {
            table_data = table.elems;
            for (j = 0; j < table.cur_size; j++) {
                externref_idx = table_data[j];
                mark_externref(externref_idx);
            }
        }
        cast(void)init_size;
        cast(void)max_size;
    }
}
}

static if (WASM_ENABLE_AOT != 0) {
private void aot_mark_all_externrefs(AOTModuleInstance* module_inst) {
    uint i = 0, j = 0;
    const(AOTModule)* module_ = cast(AOTModule*)module_inst.module_;
    const(AOTTable)* table = module_.tables;
    const(AOTGlobal)* global = module_.globals;
    const(AOTTableInstance)* table_inst = void;

    for (i = 0; i < module_.global_count; i++, global++) {
        if (global.type == VALUE_TYPE_EXTERNREF) {
            mark_externref(
                *cast(uint*)(module_inst.global_data + global.data_offset));
        }
    }

    for (i = 0; i < module_.table_count; i++) {
        table_inst = module_inst.tables[i];
        if ((table + i).elem_type == VALUE_TYPE_EXTERNREF) {
            while (j < table_inst.cur_size) {
                mark_externref(table_inst.elems[j++]);
            }
        }
    }
}
}

void wasm_externref_reclaim(WASMModuleInstanceCommon* module_inst) {
    os_mutex_lock(&externref_lock);
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode)
        interp_mark_all_externrefs(cast(WASMModuleInstance*)module_inst);
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT)
        aot_mark_all_externrefs(cast(AOTModuleInstance*)module_inst);
}

    bh_hash_map_traverse(externref_map, &reclaim_extobj_callback,
                         cast(void*)module_inst);
    os_mutex_unlock(&externref_lock);
}

private void cleanup_extobj_callback(void* key, void* value, void* user_data) {
    ExternRefMapNode* node = cast(ExternRefMapNode*)value;
    WASMModuleInstanceCommon* module_inst = cast(WASMModuleInstanceCommon*)user_data;

    if (node.module_inst == module_inst) {
        bh_hash_map_remove(externref_map, key, null, null);
        wasm_runtime_free(value);
    }
}

void wasm_externref_cleanup(WASMModuleInstanceCommon* module_inst) {
    os_mutex_lock(&externref_lock);
    bh_hash_map_traverse(externref_map, &cleanup_extobj_callback,
                         cast(void*)module_inst);
    os_mutex_unlock(&externref_lock);
}

bool wasm_externref_retain(uint externref_idx) {
    ExternRefMapNode* node = void;

    os_mutex_lock(&externref_lock);

    if (externref_idx != NULL_REF) {
        node =
            bh_hash_map_find(externref_map, cast(void*)cast(uintptr_t)externref_idx);
        if (node) {
            node.retained = true;
            os_mutex_unlock(&externref_lock);
            return true;
        }
    }

    os_mutex_unlock(&externref_lock);
    return false;
}
} /* end of WASM_ENABLE_REF_TYPES */

static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
uint wasm_runtime_dump_line_buf_impl(const(char)* line_buf, bool dump_or_print, char** buf, uint* len) {
    if (dump_or_print) {
        return cast(uint)os_printf("%s", line_buf);
    }
    else if (*buf) {
        uint dump_len = void;

        dump_len = snprintf(*buf, *len, "%s", line_buf);
        if (dump_len >= *len) {
            dump_len = *len;
        }

        *len = *len - dump_len;
        *buf = *buf + dump_len;
        return dump_len;
    }
    else {
        return cast(uint)strlen(line_buf);
    }
}

void wasm_runtime_dump_call_stack(WASMExecEnv* exec_env) {
    WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        wasm_interp_dump_call_stack(exec_env, true, null, 0);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        aot_dump_call_stack(exec_env, true, null, 0);
    }
}
}

uint wasm_runtime_get_call_stack_buf_size(wasm_exec_env_t exec_env) {
    WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);

static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        return wasm_interp_dump_call_stack(exec_env, false, null, 0);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        return aot_dump_call_stack(exec_env, false, null, 0);
    }
}

    return 0;
}

uint wasm_runtime_dump_call_stack_to_buf(wasm_exec_env_t exec_env, char* buf, uint len) {
    WASMModuleInstanceCommon* module_inst = wasm_exec_env_get_module_inst(exec_env);

static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        return wasm_interp_dump_call_stack(exec_env, false, buf, len);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        return aot_dump_call_stack(exec_env, false, buf, len);
    }
}

    return 0;
}
} /* end of WASM_ENABLE_DUMP_CALL_STACK */

bool wasm_runtime_get_table_elem_type(const(WASMModuleCommon)* module_comm, uint table_idx, ubyte* out_elem_type, uint* out_min_size, uint* out_max_size) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_comm.module_type == Wasm_Module_Bytecode) {
        WASMModule* module_ = cast(WASMModule*)module_comm;

        if (table_idx < module_.import_table_count) {
            WASMTableImport* import_table = &((module_.import_tables + table_idx).u.table);
            *out_elem_type = import_table.elem_type;
            *out_min_size = import_table.init_size;
            *out_max_size = import_table.max_size;
        }
        else {
            WASMTable* table = module_.tables + (table_idx - module_.import_table_count);
            *out_elem_type = table.elem_type;
            *out_min_size = table.init_size;
            *out_max_size = table.max_size;
        }
        return true;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_comm.module_type == Wasm_Module_AoT) {
        AOTModule* module_ = cast(AOTModule*)module_comm;

        if (table_idx < module_.import_table_count) {
            AOTImportTable* import_table = module_.import_tables + table_idx;
            *out_elem_type = VALUE_TYPE_FUNCREF;
            *out_min_size = import_table.table_init_size;
            *out_max_size = import_table.table_max_size;
        }
        else {
            AOTTable* table = module_.tables + (table_idx - module_.import_table_count);
            *out_elem_type = table.elem_type;
            *out_min_size = table.table_init_size;
            *out_max_size = table.table_max_size;
        }
        return true;
    }
}

    return false;
}

bool wasm_runtime_get_table_inst_elem_type(const(WASMModuleInstanceCommon)* module_inst_comm, uint table_idx, ubyte* out_elem_type, uint* out_min_size, uint* out_max_size) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst_comm.module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
        return wasm_runtime_get_table_elem_type(
            cast(WASMModuleCommon*)module_inst.module_, table_idx, out_elem_type,
            out_min_size, out_max_size);
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst_comm.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* module_inst = cast(AOTModuleInstance*)module_inst_comm;
        return wasm_runtime_get_table_elem_type(
            cast(WASMModuleCommon*)module_inst.module_, table_idx, out_elem_type,
            out_min_size, out_max_size);
    }
}
    return false;
}

bool wasm_runtime_get_export_func_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, WASMType** out_) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_comm.module_type == Wasm_Module_Bytecode) {
        WASMModule* module_ = cast(WASMModule*)module_comm;

        if (export_.index < module_.import_function_count) {
            *out_ = module_.import_functions[export_.index].u.function_.func_type;
        }
        else {
            *out_ =
                module_.functions[export_.index - module_.import_function_count]
                    .func_type;
        }
        return true;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_comm.module_type == Wasm_Module_AoT) {
        AOTModule* module_ = cast(AOTModule*)module_comm;

        if (export_.index < module_.import_func_count) {
            *out_ = module_.func_types[module_.import_funcs[export_.index]
                                          .func_type_index];
        }
        else {
            *out_ = module_.func_types
                       [module_.func_type_indexes[export_.index
                                                  - module_.import_func_count]];
        }
        return true;
    }
}
    return false;
}

bool wasm_runtime_get_export_global_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, ubyte* out_val_type, bool* out_mutability) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_comm.module_type == Wasm_Module_Bytecode) {
        WASMModule* module_ = cast(WASMModule*)module_comm;

        if (export_.index < module_.import_global_count) {
            WASMGlobalImport* import_global = &((module_.import_globals + export_.index).u.global);
            *out_val_type = import_global.type;
            *out_mutability = import_global.is_mutable;
        }
        else {
            WASMGlobal* global = module_.globals + (export_.index - module_.import_global_count);
            *out_val_type = global.type;
            *out_mutability = global.is_mutable;
        }
        return true;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_comm.module_type == Wasm_Module_AoT) {
        AOTModule* module_ = cast(AOTModule*)module_comm;

        if (export_.index < module_.import_global_count) {
            AOTImportGlobal* import_global = module_.import_globals + export_.index;
            *out_val_type = import_global.type;
            *out_mutability = import_global.is_mutable;
        }
        else {
            AOTGlobal* global = module_.globals + (export_.index - module_.import_global_count);
            *out_val_type = global.type;
            *out_mutability = global.is_mutable;
        }
        return true;
    }
}
    return false;
}

bool wasm_runtime_get_export_memory_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, uint* out_min_page, uint* out_max_page) {
static if (WASM_ENABLE_INTERP != 0) {
    if (module_comm.module_type == Wasm_Module_Bytecode) {
        WASMModule* module_ = cast(WASMModule*)module_comm;

        if (export_.index < module_.import_memory_count) {
            WASMMemoryImport* import_memory = &((module_.import_memories + export_.index).u.memory);
            *out_min_page = import_memory.init_page_count;
            *out_max_page = import_memory.max_page_count;
        }
        else {
            WASMMemory* memory = module_.memories
                + (export_.index - module_.import_memory_count);
            *out_min_page = memory.init_page_count;
            *out_max_page = memory.max_page_count;
        }
        return true;
    }
}

static if (WASM_ENABLE_AOT != 0) {
    if (module_comm.module_type == Wasm_Module_AoT) {
        AOTModule* module_ = cast(AOTModule*)module_comm;

        if (export_.index < module_.import_memory_count) {
            AOTImportMemory* import_memory = module_.import_memories + export_.index;
            *out_min_page = import_memory.mem_init_page_count;
            *out_max_page = import_memory.mem_max_page_count;
        }
        else {
            AOTMemory* memory = module_.memories
                                + (export_.index - module_.import_memory_count);
            *out_min_page = memory.mem_init_page_count;
            *out_max_page = memory.mem_max_page_count;
        }
        return true;
    }
}
    return false;
}

bool wasm_runtime_get_export_table_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, ubyte* out_elem_type, uint* out_min_size, uint* out_max_size) {
    return wasm_runtime_get_table_elem_type(
        module_comm, export_.index, out_elem_type, out_min_size, out_max_size);
}

pragma(inline, true) private bool argv_to_params(wasm_val_t* out_params, const(uint)* argv, WASMType* func_type) {
    wasm_val_t* param = out_params;
    uint i = 0; uint* u32 = void;

    for (i = 0; i < func_type.param_count; i++, param++) {
        switch (func_type.types[i]) {
            case VALUE_TYPE_I32:
                param.kind = WASM_I32;
                param.of.i32 = *argv++;
                break;
            case VALUE_TYPE_I64:
                param.kind = WASM_I64;
                u32 = cast(uint*)&param.of.i64;
                u32[0] = *argv++;
                u32[1] = *argv++;
                break;
            case VALUE_TYPE_F32:
                param.kind = WASM_F32;
                param.of.f32 = *cast(float32*)argv++;
                break;
            case VALUE_TYPE_F64:
                param.kind = WASM_F64;
                u32 = cast(uint*)&param.of.i64;
                u32[0] = *argv++;
                u32[1] = *argv++;
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
                param.kind = WASM_ANYREF;

                if (!wasm_externref_ref2obj(*argv,
                                            cast(void**)&param.of.foreign)) {
                    return false;
                }

                argv++;
                break;
}
            default:
                return false;
        }
    }

    return true;
}

pragma(inline, true) private bool results_to_argv(WASMModuleInstanceCommon* module_inst, uint* out_argv, const(wasm_val_t)* results, WASMType* func_type) {
    const(wasm_val_t)* result = results;
    uint* argv = out_argv, u32 = void; uint i = void;
    ubyte* result_types = func_type.types + func_type.param_count;

    for (i = 0; i < func_type.result_count; i++, result++) {
        switch (result_types[i]) {
            case VALUE_TYPE_I32:
            case VALUE_TYPE_F32:
                *cast(int*)argv++ = result.of.i32;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                u32 = cast(uint*)&result.of.i64;
                *argv++ = u32[0];
                *argv++ = u32[1];
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
                if (!wasm_externref_obj2ref(module_inst,
                                            cast(void*)result.of.foreign, argv)) {
                    return false;
                }
                argv++;
                break;
}
            default:
                return false;
        }
    }

    return true;
}

bool wasm_runtime_invoke_c_api_native(WASMModuleInstanceCommon* module_inst, void* func_ptr, WASMType* func_type, uint argc, uint* argv, bool with_env, void* wasm_c_api_env) {
    wasm_val_t[16] params_buf = 0; wasm_val_t[4] results_buf = 0;
    wasm_val_t* params = params_buf, results = results_buf;
    wasm_trap_t* trap = null;
    bool ret = false;
    wasm_val_vec_t params_vec = void, results_vec = void;

    if (func_type.param_count > 16) {
        if (((params =
                  runtime_malloc(wasm_val_t.sizeof * func_type.param_count,
                                 module_inst, null, 0)) == 0)) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
            return false;
        }
    }

    if (!argv_to_params(params, argv, func_type)) {
        wasm_runtime_set_exception(module_inst, "unsupported param type");
        goto fail;
    }

    if (func_type.result_count > 4) {
        if (((results =
                  runtime_malloc(wasm_val_t.sizeof * func_type.result_count,
                                 module_inst, null, 0)) == 0)) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
            goto fail;
        }
    }

    params_vec.data = params;
    params_vec.num_elems = func_type.param_count;
    params_vec.size = func_type.param_count;
    params_vec.size_of_elem = wasm_val_t.sizeof;

    results_vec.data = results;
    results_vec.num_elems = 0;
    results_vec.size = func_type.result_count;
    results_vec.size_of_elem = wasm_val_t.sizeof;

    if (!with_env) {
        wasm_func_callback_t callback = cast(wasm_func_callback_t)func_ptr;
        trap = callback(&params_vec, &results_vec);
    }
    else {
        wasm_func_callback_with_env_t callback = cast(wasm_func_callback_with_env_t)func_ptr;
        trap = callback(wasm_c_api_env, &params_vec, &results_vec);
    }

    if (trap) {
        if (trap.message.data) {
            /* since trap->message->data does not end with '\0' */
            char[108] trap_message = 0;
            uint max_size_to_copy = cast(uint)trap_message.sizeof.ptr - 1;
            uint size_to_copy = (trap.message.size < max_size_to_copy)
                                      ? cast(uint)trap.message.size
                                      : max_size_to_copy;
            bh_memcpy_s(trap_message.ptr, cast(uint)trap_message.sizeof,
                        trap.message.data, size_to_copy);
            wasm_runtime_set_exception(module_inst, trap_message.ptr);
        }
        else {
            wasm_runtime_set_exception(
                module_inst, "native function throw unknown exception");
        }
        wasm_trap_delete(trap);
        goto fail;
    }

    if (!results_to_argv(module_inst, argv, results, func_type)) {
        wasm_runtime_set_exception(module_inst, "unsupported result type");
        goto fail;
    }
    results_vec.num_elems = func_type.result_count;
    ret = true;

fail:
    if (params != params_buf.ptr)
        wasm_runtime_free(params);
    if (results != results_buf.ptr)
        wasm_runtime_free(results);
    return ret;
}

void wasm_runtime_show_app_heap_corrupted_prompt() {
    LOG_ERROR("Error: app heap is corrupted, if the wasm file "
              ~ "is compiled by wasi-sdk-12.0 or higher version, "
              ~ "please add -Wl,--export=malloc -Wl,--export=free "
              ~ "to export malloc and free functions. If it is "
              ~ "compiled by asc, please add --exportRuntime to "
              ~ "export the runtime helpers.");
}

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
void wasm_runtime_destroy_custom_sections(WASMCustomSection* section_list) {
    WASMCustomSection* section = section_list, next = void;
    while (section) {
        next = section.next;
        wasm_runtime_free(section);
        section = next;
    }
}
} /* end of WASM_ENABLE_LOAD_CUSTOM_SECTION */

void wasm_runtime_get_version(uint* major, uint* minor, uint* patch) {
    *major = WAMR_VERSION_MAJOR;
    *minor = WAMR_VERSION_MINOR;
    *patch = WAMR_VERSION_PATCH;
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


public import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.share.utils.bh_common;
public import tagion.iwasm.common.wasm_exec_env;
public import tagion.iwasm.common.wasm_native;
public import tagion.iwasm.include.wasm_export;
public import tagion.iwasm.interpreter.wasm;
static if (WASM_ENABLE_LIBC_WASI != 0) {
static if (WASM_ENABLE_UVWASI == 0) {
public import wasmtime_ssp;
public import posix;
} else {
public import uvwasi;
}
}


static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {

enum string PUT_I64_TO_ADDR(string addr, string value) = `       \
    do {                                   \
        *(int64 *)(addr) = (int64)(value); \
    } while (0)`;
enum string PUT_F64_TO_ADDR(string addr, string value) = `           \
    do {                                       \
        *(float64 *)(addr) = (float64)(value); \
    } while (0)`;

enum string GET_I64_FROM_ADDR(string addr) = ` (*(int64 *)(addr))`;
enum string GET_F64_FROM_ADDR(string addr) = ` (*(float64 *)(addr))`;

/* For STORE opcodes */
enum STORE_I64 = PUT_I64_TO_ADDR;
enum string STORE_U32(string addr, string value) = `               \
    do {                                     \
        *(uint32 *)(addr) = cast(uint)(value); \
    } while (0)`;
enum string STORE_U16(string addr, string value) = `               \
    do {                                     \
        *(uint16 *)(addr) = (uint16)(value); \
    } while (0)`;

/* For LOAD opcodes */
enum string LOAD_I64(string addr) = ` (*(int64 *)(addr))`;
enum string LOAD_F64(string addr) = ` (*(float64 *)(addr))`;
enum string LOAD_I32(string addr) = ` (*(int32 *)(addr))`;
enum string LOAD_U32(string addr) = ` (*(uint32 *)(addr))`;
enum string LOAD_I16(string addr) = ` (*(int16 *)(addr))`;
enum string LOAD_U16(string addr) = ` (*(uint16 *)(addr))`;

enum string STORE_PTR(string addr, string ptr) = `          \
    do {                              \
        *(void **)addr = (void *)ptr; \
    } while (0)`;

} else { /* WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0 */

enum string PUT_I64_TO_ADDR(string addr, string value) = `         \
    do {                                     \
        uint32 *addr_u32 = (uint32 *)(addr); \
        union {                              \
            int64 val;                       \
            uint32 parts[2];                 \
        } u;                                 \
        u.val = (int64)(value);              \
        addr_u32[0] = u.parts[0];            \
        addr_u32[1] = u.parts[1];            \
    } while (0)`;
enum string PUT_F64_TO_ADDR(string addr, string value) = `         \
    do {                                     \
        uint32 *addr_u32 = (uint32 *)(addr); \
        union {                              \
            float64 val;                     \
            uint32 parts[2];                 \
        } u;                                 \
        u.val = (value);                     \
        addr_u32[0] = u.parts[0];            \
        addr_u32[1] = u.parts[1];            \
    } while (0)`;

pragma(inline, true) private long GET_I64_FROM_ADDR(uint* addr) {
    union _U {
        long val = void;
        uint[2] parts = void;
    }_U u = void;
    u.parts[0] = addr[0];
    u.parts[1] = addr[1];
    return u.val;
}

pragma(inline, true) private float64 GET_F64_FROM_ADDR(uint* addr) {
    union _U {
        float64 val = void;
        uint[2] parts = void;
    }_U u = void;
    u.parts[0] = addr[0];
    u.parts[1] = addr[1];
    return u.val;
}

/* For STORE opcodes */
enum string STORE_I64(string addr, string value) = `                      \
    do {                                            \
        uintptr_t addr_ = (uintptr_t)(addr);        \
        union {                                     \
            int64 val;                              \
            uint32 u32[2];                          \
            uint16 u16[4];                          \
            uint8 u8[8];                            \
        } u;                                        \
        if ((addr_ & (uintptr_t)7) == 0)            \
            *(int64 *)(addr) = (int64)(value);      \
        else {                                      \
            u.val = (int64)(value);                 \
            if ((addr_ & (uintptr_t)3) == 0) {      \
                ((uint32 *)(addr))[0] = u.u32[0];   \
                ((uint32 *)(addr))[1] = u.u32[1];   \
            }                                       \
            else if ((addr_ & (uintptr_t)1) == 0) { \
                ((uint16 *)(addr))[0] = u.u16[0];   \
                ((uint16 *)(addr))[1] = u.u16[1];   \
                ((uint16 *)(addr))[2] = u.u16[2];   \
                ((uint16 *)(addr))[3] = u.u16[3];   \
            }                                       \
            else {                                  \
                int32 t;                            \
                for (t = 0; t < 8; t++)             \
                    ((uint8 *)(addr))[t] = u.u8[t]; \
            }                                       \
        }                                           \
    } while (0)`;

enum string STORE_U32(string addr, string value) = `                    \
    do {                                          \
        uintptr_t addr_ = (uintptr_t)(addr);      \
        union {                                   \
            uint32 val;                           \
            uint16 u16[2];                        \
            uint8 u8[4];                          \
        } u;                                      \
        if ((addr_ & (uintptr_t)3) == 0)          \
            *(uint32 *)(addr) = cast(uint)(value);  \
        else {                                    \
            u.val = cast(uint)(value);              \
            if ((addr_ & (uintptr_t)1) == 0) {    \
                ((uint16 *)(addr))[0] = u.u16[0]; \
                ((uint16 *)(addr))[1] = u.u16[1]; \
            }                                     \
            else {                                \
                ((uint8 *)(addr))[0] = u.u8[0];   \
                ((uint8 *)(addr))[1] = u.u8[1];   \
                ((uint8 *)(addr))[2] = u.u8[2];   \
                ((uint8 *)(addr))[3] = u.u8[3];   \
            }                                     \
        }                                         \
    } while (0)`;

enum string STORE_U16(string addr, string value) = `          \
    do {                                \
        union {                         \
            uint16 val;                 \
            uint8 u8[2];                \
        } u;                            \
        u.val = (uint16)(value);        \
        ((uint8 *)(addr))[0] = u.u8[0]; \
        ((uint8 *)(addr))[1] = u.u8[1]; \
    } while (0)`;

/* For LOAD opcodes */
pragma(inline, true) private long LOAD_I64(void* addr) {
    uintptr_t addr1 = cast(uintptr_t)addr;
    union _U {
        long val = void;
        uint[2] u32 = void;
        ushort[4] u16 = void;
        ubyte[8] u8 = void;
    }_U u = void;
    if ((addr1 & cast(uintptr_t)7) == 0)
        return *cast(long*)addr;

    if ((addr1 & cast(uintptr_t)3) == 0) {
        u.u32[0] = (cast(uint*)addr)[0];
        u.u32[1] = (cast(uint*)addr)[1];
    }
    else if ((addr1 & cast(uintptr_t)1) == 0) {
        u.u16[0] = (cast(ushort*)addr)[0];
        u.u16[1] = (cast(ushort*)addr)[1];
        u.u16[2] = (cast(ushort*)addr)[2];
        u.u16[3] = (cast(ushort*)addr)[3];
    }
    else {
        int t = void;
        for (t = 0; t < 8; t++)
            u.u8[t] = (cast(ubyte*)addr)[t];
    }
    return u.val;
}

pragma(inline, true) private float64 LOAD_F64(void* addr) {
    uintptr_t addr1 = cast(uintptr_t)addr;
    union _U {
        float64 val = void;
        uint[2] u32 = void;
        ushort[4] u16 = void;
        ubyte[8] u8 = void;
    }_U u = void;
    if ((addr1 & cast(uintptr_t)7) == 0)
        return *cast(float64*)addr;

    if ((addr1 & cast(uintptr_t)3) == 0) {
        u.u32[0] = (cast(uint*)addr)[0];
        u.u32[1] = (cast(uint*)addr)[1];
    }
    else if ((addr1 & cast(uintptr_t)1) == 0) {
        u.u16[0] = (cast(ushort*)addr)[0];
        u.u16[1] = (cast(ushort*)addr)[1];
        u.u16[2] = (cast(ushort*)addr)[2];
        u.u16[3] = (cast(ushort*)addr)[3];
    }
    else {
        int t = void;
        for (t = 0; t < 8; t++)
            u.u8[t] = (cast(ubyte*)addr)[t];
    }
    return u.val;
}

pragma(inline, true) private int LOAD_I32(void* addr) {
    uintptr_t addr1 = cast(uintptr_t)addr;
    union _U {
        int val = void;
        ushort[2] u16 = void;
        ubyte[4] u8 = void;
    }_U u = void;
    if ((addr1 & cast(uintptr_t)3) == 0)
        return *cast(int*)addr;

    if ((addr1 & cast(uintptr_t)1) == 0) {
        u.u16[0] = (cast(ushort*)addr)[0];
        u.u16[1] = (cast(ushort*)addr)[1];
    }
    else {
        u.u8[0] = (cast(ubyte*)addr)[0];
        u.u8[1] = (cast(ubyte*)addr)[1];
        u.u8[2] = (cast(ubyte*)addr)[2];
        u.u8[3] = (cast(ubyte*)addr)[3];
    }
    return u.val;
}

pragma(inline, true) private short LOAD_I16(void* addr) {
    uintptr_t addr1 = cast(uintptr_t)addr;
    union _U {
        short val = void;
        ubyte[2] u8 = void;
    }_U u = void;
    if ((addr1 & cast(uintptr_t)1)) {
        u.u8[0] = (cast(ubyte*)addr)[0];
        u.u8[1] = (cast(ubyte*)addr)[1];
        return u.val;
    }
    return *cast(short*)addr;
}

//enum string LOAD_U32(string addr) = ` (cast(uint)LOAD_I32(addr))`;
//enum string LOAD_U16(string addr) = ` ((uint16)LOAD_I16(addr))`;

static if (UINTPTR_MAX == UINT32_MAX) {
enum string STORE_PTR(string addr, string ptr) = ` STORE_U32(addr, (uintptr_t)ptr)`;
} else static if (UINTPTR_MAX == UINT64_MAX) {
enum string STORE_PTR(string addr, string ptr) = ` STORE_I64(addr, (uintptr_t)ptr)`;
}

} /* WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0 */

struct WASMModuleCommon {
    /* Module type, for module loaded from WASM bytecode binary,
       this field is Wasm_Module_Bytecode, and this structure should
       be treated as WASMModule structure;
       for module loaded from AOT binary, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModule structure. */
    uint module_type;

    /* The following uint8[1] member is a dummy just to indicate
       some module_type dependent members follow.
       Typically it should be accessed by casting to the corresponding
       actual module_type dependent structure, not via this member. */
    ubyte[1] module_data;
}

struct WASMModuleInstanceCommon {
    /* Module instance type, for module instance loaded from WASM
       bytecode binary, this field is Wasm_Module_Bytecode, and this
       structure should be treated as WASMModuleInstance structure;
       for module instance loaded from AOT binary, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModuleInstance structure. */
    uint module_type;

    /* The following uint8[1] member is a dummy just to indicate
       some module_type dependent members follow.
       Typically it should be accessed by casting to the corresponding
       actual module_type dependent structure, not via this member. */
    ubyte[1] module_inst_data;
}

struct WASMModuleMemConsumption {
    uint total_size;
    uint module_struct_size;
    uint types_size;
    uint imports_size;
    uint functions_size;
    uint tables_size;
    uint memories_size;
    uint globals_size;
    uint exports_size;
    uint table_segs_size;
    uint data_segs_size;
    uint const_strs_size;
static if (WASM_ENABLE_AOT != 0) {
    uint aot_code_size;
}
}

struct WASMModuleInstMemConsumption {
    uint total_size;
    uint module_inst_struct_size;
    uint memories_size;
    uint app_heap_size;
    uint tables_size;
    uint globals_size;
    uint functions_size;
    uint exports_size;
}

static if (WASM_ENABLE_LIBC_WASI != 0) {
static if (WASM_ENABLE_UVWASI == 0) {
struct WASIContext {
    fd_table* curfds;
    fd_prestats* prestats;
    argv_environ_values* argv_environ;
    addr_pool* addr_pool;
    char* ns_lookup_buf;
    char** ns_lookup_list;
    char* argv_buf;
    char** argv_list;
    char* env_buf;
    char** env_list;
    uint exit_code;
}
} else {
struct WASIContext {
    uvwasi_t uvwasi;
    uint exit_code;
}
}
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
struct WASMRegisteredModule {
    bh_list_link l;
    /* point to a string pool */
    const(char)* module_name;
    WASMModuleCommon* module_;
    /* to store the original module file buffer address */
    ubyte* orig_file_buf;
    uint orig_file_buf_size;
}
}

struct WASMMemoryInstanceCommon {
    uint module_type;

    /* The following uint8[1] member is a dummy just to indicate
       some module_type dependent members follow.
       Typically it should be accessed by casting to the corresponding
       actual module_type dependent structure, not via this member. */
    ubyte[1] memory_inst_data;
}

alias PackageType = package_type_t;
alias WASMSection = wasm_section_t;
alias AOTSection = wasm_section_t;

struct wasm_frame_t {
    /*  wasm_instance_t */
    void* instance;
    uint module_offset;
    uint func_index;
    uint func_offset;
    const(char)* func_name_wp;
}alias WASMCApiFrame = wasm_frame_t;

version (OS_ENABLE_HW_BOUND_CHECK) {
/* Signal info passing to interp/aot signal handler */
struct WASMSignalInfo {
    WASMExecEnv* exec_env_tls;
version (BH_PLATFORM_WINDOWS) {} else {
    void* sig_addr;
} version (BH_PLATFORM_WINDOWS) {
    EXCEPTION_POINTERS* exce_info;
}
}

/* Set exec_env of thread local storage */
void wasm_runtime_set_exec_env_tls(WASMExecEnv* exec_env);

/* Get exec_env of thread local storage */
WASMExecEnv* wasm_runtime_get_exec_env_tls();
}

/* See wasm_export.h for description */
void wasm_runtime_init();

/* See wasm_export.h for description */
void wasm_runtime_full_init(RuntimeInitArgs* init_args);

/* See wasm_export.h for description */
void wasm_runtime_destroy();

/* See wasm_export.h for description */
void get_package_type(const(ubyte)* buf, uint size);

/* See wasm_export.h for description */
void wasm_runtime_is_xip_file(const(ubyte)* buf, uint size);

/* See wasm_export.h for description */
void* wasm_runtime_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size);

/* See wasm_export.h for description */
void* wasm_runtime_load_from_sections(WASMSection* section_list, bool is_aot, char* error_buf, uint error_buf_size);

/* See wasm_export.h for description */
void wasm_runtime_unload(WASMModuleCommon* module_);

/* Internal API */
WASMModuleInstanceCommon* wasm_runtime_instantiate_internal(WASMModuleCommon* module_, bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size);

/* Internal API */
void wasm_runtime_deinstantiate_internal(WASMModuleInstanceCommon* module_inst, bool is_sub_inst);

/* See wasm_export.h for description */
void* wasm_runtime_instantiate(WASMModuleCommon* module_, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size);

/* See wasm_export.h for description */
void wasm_runtime_deinstantiate(WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
WASMModuleCommon*
wasm_runtime_get_module(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
void* wasm_runtime_lookup_function(WASMModuleInstanceCommon* module_inst, const(char)* name, const(char)* signature);

/* Internal API */
WASMType* wasm_runtime_get_function_type(const(WASMFunctionInstanceCommon)* function_, uint module_type);

/* See wasm_export.h for description */
void wasm_func_get_param_count(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
void wasm_func_get_result_count(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
void wasm_func_get_param_types(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst, wasm_valkind_t* param_types);

/* See wasm_export.h for description */
void wasm_func_get_result_types(WASMFunctionInstanceCommon* func_inst, WASMModuleInstanceCommon* module_inst, wasm_valkind_t* result_types);

/* See wasm_export.h for description */
void* wasm_runtime_create_exec_env(WASMModuleInstanceCommon* module_inst, uint stack_size);

/* See wasm_export.h for description */
void wasm_runtime_destroy_exec_env(WASMExecEnv* exec_env);

/* See wasm_export.h for description */
WASMModuleInstanceCommon*
wasm_runtime_get_module_inst(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
void wasm_runtime_set_module_inst(WASMExecEnv* exec_env, WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
void* wasm_runtime_get_function_attachment(WASMExecEnv* exec_env);

/* See wasm_export.h for description */
void wasm_runtime_set_user_data(WASMExecEnv* exec_env, void* user_data);

/* See wasm_export.h for description */
void* wasm_runtime_get_user_data(WASMExecEnv* exec_env);

version (OS_ENABLE_HW_BOUND_CHECK) {
/* Access exception check guard page to trigger the signal handler */
void wasm_runtime_access_exce_check_guard_page();
}

/* See wasm_export.h for description */
void wasm_runtime_call_wasm(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint argc, uint* argv);

void wasm_runtime_call_wasm_a(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint num_results, wasm_val_t* results, uint num_args, wasm_val_t* args);

void wasm_runtime_call_wasm_v(WASMExecEnv* exec_env, WASMFunctionInstanceCommon* function_, uint num_results, wasm_val_t* results, uint num_args, ...);

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
/* See wasm_export.h for description */
void wasm_runtime_start_debug_instance_with_port(WASMExecEnv* exec_env, int port);

/* See wasm_export.h for description */
void wasm_runtime_start_debug_instance(WASMExecEnv* exec_env);
}

/**
 * Call a function reference of a given WASM runtime instance with
 * arguments.
 *
 * @param exec_env the execution environment to call the function
 *   which must be created from wasm_create_exec_env()
 * @param element_indices the function ference indicies, usually
 *   prvovided by the caller of a registed native function
 * @param argc the number of arguments
 * @param argv the arguments.  If the function method has return value,
 *   the first (or first two in case 64-bit return value) element of
 *   argv stores the return value of the called WASM function after this
 *   function returns.
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call wasm_runtime_get_exception to get exception info.
 */
bool wasm_runtime_call_indirect(WASMExecEnv* exec_env, uint element_indices, uint argc, uint* argv);

bool wasm_runtime_create_exec_env_singleton(WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
WASMExecEnv*
wasm_runtime_get_exec_env_singleton(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
void wasm_application_execute_main(WASMModuleInstanceCommon* module_inst, int argc, char** argv);

/* See wasm_export.h for description */
void wasm_application_execute_func(WASMModuleInstanceCommon* module_inst, const(char)* name, int argc, char** argv);

/* See wasm_export.h for description */
void wasm_runtime_set_exception(WASMModuleInstanceCommon* module_, const(char)* exception);

/* See wasm_export.h for description */
const(void)* wasm_runtime_get_exception(WASMModuleInstanceCommon* module_);

/* See wasm_export.h for description */
void wasm_runtime_clear_exception(WASMModuleInstanceCommon* module_inst);

/* Internal API */
void wasm_runtime_set_custom_data_internal(WASMModuleInstanceCommon* module_inst, void* custom_data);

/* See wasm_export.h for description */
void wasm_runtime_set_custom_data(WASMModuleInstanceCommon* module_inst, void* custom_data);

/* See wasm_export.h for description */
void* wasm_runtime_get_custom_data(WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
void wasm_runtime_module_malloc(WASMModuleInstanceCommon* module_inst, uint size, void** p_native_addr);

/* See wasm_export.h for description */
void wasm_runtime_module_free(WASMModuleInstanceCommon* module_inst, uint ptr);

/* See wasm_export.h for description */
void wasm_runtime_module_dup_data(WASMModuleInstanceCommon* module_inst, const(char)* src, uint size);

/* See wasm_export.h for description */
void wasm_runtime_validate_app_addr(WASMModuleInstanceCommon* module_inst, uint app_offset, uint size);

/* See wasm_export.h for description */
void wasm_runtime_validate_app_str_addr(WASMModuleInstanceCommon* module_inst, uint app_str_offset);

/* See wasm_export.h for description */
void wasm_runtime_validate_native_addr(WASMModuleInstanceCommon* module_inst, void* native_ptr, uint size);

/* See wasm_export.h for description */
void* wasm_runtime_addr_app_to_native(WASMModuleInstanceCommon* module_inst, uint app_offset);

/* See wasm_export.h for description */
void wasm_runtime_addr_native_to_app(WASMModuleInstanceCommon* module_inst, void* native_ptr);

/* See wasm_export.h for description */
void wasm_runtime_get_app_addr_range(WASMModuleInstanceCommon* module_inst, uint app_offset, uint* p_app_start_offset, uint* p_app_end_offset);

/* See wasm_export.h for description */
void wasm_runtime_get_native_addr_range(WASMModuleInstanceCommon* module_inst, ubyte* native_ptr, ubyte** p_native_start_addr, ubyte** p_native_end_addr);

/* See wasm_export.h for description */
const(void)* wasm_runtime_get_custom_section(WASMModuleCommon* module_comm, const(char)* name, uint* len);

static if (WASM_ENABLE_MULTI_MODULE != 0) {
void wasm_runtime_set_module_reader(const(module_reader) reader, const(module_destroyer) destroyer);

module_reader wasm_runtime_get_module_reader();

module_destroyer wasm_runtime_get_module_destroyer();

bool wasm_runtime_register_module_internal(const(char)* module_name, WASMModuleCommon* module_, ubyte* orig_file_buf, uint orig_file_buf_size, char* error_buf, uint error_buf_size);

void wasm_runtime_unregister_module(const(WASMModuleCommon)* module_);

bool wasm_runtime_add_loading_module(const(char)* module_name, char* error_buf, uint error_buf_size);

void wasm_runtime_delete_loading_module(const(char)* module_name);

bool wasm_runtime_is_loading_module(const(char)* module_name);

void wasm_runtime_destroy_loading_module_list();
} /* WASM_ENALBE_MULTI_MODULE */

bool wasm_runtime_is_built_in_module(const(char)* module_name);

static if (WASM_ENABLE_THREAD_MGR != 0) {
bool wasm_exec_env_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size);

bool wasm_exec_env_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size);
}

static if (WASM_ENABLE_LIBC_WASI != 0) {
void wasm_runtime_set_wasi_args_ex(WASMModuleCommon* module_, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env_list, uint env_count, char** argv, int argc, int stdinfd, int stdoutfd, int stderrfd);

/* See wasm_export.h for description */
void wasm_runtime_set_wasi_args(WASMModuleCommon* module_, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env_list, uint env_count, char** argv, int argc);

/* See wasm_export.h for description */
void wasm_runtime_is_wasi_mode(WASMModuleInstanceCommon* module_inst);

/* See wasm_export.h for description */
WASMFunctionInstanceCommon*
wasm_runtime_lookup_wasi_start_function(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
void wasm_runtime_get_wasi_exit_code(WASMModuleInstanceCommon* module_inst);

bool wasm_runtime_init_wasi(WASMModuleInstanceCommon* module_inst, const(char)** dir_list, uint dir_count, const(char)** map_dir_list, uint map_dir_count, const(char)** env, uint env_count, const(char)** addr_pool, uint addr_pool_size, const(char)** ns_lookup_pool, uint ns_lookup_pool_size, char** argv, uint argc, int stdinfd, int stdoutfd, int stderrfd, char* error_buf, uint error_buf_size);

void wasm_runtime_destroy_wasi(WASMModuleInstanceCommon* module_inst);

void wasm_runtime_set_wasi_ctx(WASMModuleInstanceCommon* module_inst, WASIContext* wasi_ctx);

WASIContext* wasm_runtime_get_wasi_ctx(WASMModuleInstanceCommon* module_inst);

void wasm_runtime_set_wasi_addr_pool(wasm_module_t module_, const(char)** addr_pool, uint addr_pool_size);

void wasm_runtime_set_wasi_ns_lookup_pool(wasm_module_t module_, const(char)** ns_lookup_pool, uint ns_lookup_pool_size);
} /* end of WASM_ENABLE_LIBC_WASI */

static if (WASM_ENABLE_REF_TYPES != 0) {
/* See wasm_export.h for description */
void wasm_externref_obj2ref(WASMModuleInstanceCommon* module_inst, void* extern_obj, uint* p_externref_idx);

/* See wasm_export.h for description */
void wasm_externref_ref2obj(uint externref_idx, void** p_extern_obj);

/* See wasm_export.h for description */
void wasm_externref_retain(uint externref_idx);

/**
 * Reclaim the externref objects/indexes which are not used by
 * module instance
 */
void wasm_externref_reclaim(WASMModuleInstanceCommon* module_inst);

/**
 * Cleanup the externref objects/indexes of the module instance
 */
void wasm_externref_cleanup(WASMModuleInstanceCommon* module_inst);
} /* end of WASM_ENABLE_REF_TYPES */

static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
/**
 * @brief Internal implementation for dumping or printing callstack line
 *
 * @note if dump_or_print is true, then print to stdout directly;
 * if dump_or_print is false, but *buf is NULL, then return the length of the
 * line;
 * if dump_or_print is false, and *buf is not NULL, then dump content to
 * the memory pointed by *buf, and adjust *buf and *len according to actual
 * bytes dumped, and return the actual dumped length
 *
 * @param line_buf current line to dump or print
 * @param dump_or_print whether to print to stdout or dump to buf
 * @param buf [INOUT] pointer to the buffer
 * @param len [INOUT] pointer to remaining length
 * @return bytes printed to stdout or dumped to buf
 */
uint wasm_runtime_dump_line_buf_impl(const(char)* line_buf, bool dump_or_print, char** buf, uint* len);
} /* end of WASM_ENABLE_DUMP_CALL_STACK != 0 */

/* Get module of the current exec_env */
WASMModuleCommon* wasm_exec_env_get_module(WASMExecEnv* exec_env);

/* See wasm_export.h for description */
void wasm_runtime_register_natives(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols);

/* See wasm_export.h for description */
void wasm_runtime_register_natives_raw(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols);

/* See wasm_export.h for description */
void wasm_runtime_unregister_natives(const(char)* module_name, NativeSymbol* native_symbols);

bool wasm_runtime_invoke_native(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* ret);

bool wasm_runtime_invoke_native_raw(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* ret);

void wasm_runtime_read_v128(const(ubyte)* bytes, ulong* ret1, ulong* ret2);

void wasm_runtime_dump_module_mem_consumption(const(WASMModuleCommon)* module_);

void wasm_runtime_dump_module_inst_mem_consumption(const(WASMModuleInstanceCommon)* module_inst);

void wasm_runtime_dump_exec_env_mem_consumption(const(WASMExecEnv)* exec_env);

bool wasm_runtime_get_table_elem_type(const(WASMModuleCommon)* module_comm, uint table_idx, ubyte* out_elem_type, uint* out_min_size, uint* out_max_size);

bool wasm_runtime_get_table_inst_elem_type(const(WASMModuleInstanceCommon)* module_inst_comm, uint table_idx, ubyte* out_elem_type, uint* out_min_size, uint* out_max_size);

bool wasm_runtime_get_export_func_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, WASMType** out_);

bool wasm_runtime_get_export_global_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, ubyte* out_val_type, bool* out_mutability);

bool wasm_runtime_get_export_memory_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, uint* out_min_page, uint* out_max_page);

bool wasm_runtime_get_export_table_type(const(WASMModuleCommon)* module_comm, const(WASMExport)* export_, ubyte* out_elem_type, uint* out_min_size, uint* out_max_size);

bool wasm_runtime_invoke_c_api_native(WASMModuleInstanceCommon* module_inst, void* func_ptr, WASMType* func_type, uint argc, uint* argv, bool with_env, void* wasm_c_api_env);

void wasm_runtime_show_app_heap_corrupted_prompt();

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
void wasm_runtime_destroy_custom_sections(WASMCustomSection* section_list);
}



