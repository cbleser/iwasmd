module tagion.iwasm.fast_jit.jit_compiler;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.basic;
import tagion.iwasm.fast_jit.jit_ir;
import tagion.iwasm.fast_jit.jit_codecache;
import tagion.iwasm.interpreter.wasm;

struct JitCompilerPass {
    /* Name of the pass */
    const(char)* name;
    /* The entry of the compiler pass */
    bool function(JitCompContext* cc) run;
}

/* clang-format off */
JitCompilerPass[] compiler_passes = [ 
    { name: null, run:null },
    JitCompilerPass("dump".ptr, &jit_pass_dump),
    JitCompilerPass("update_cfg", &jit_pass_update_cfg),
    JitCompilerPass("frontend".ptr, &jit_pass_frontend),
    JitCompilerPass("lower_cg".ptr, &jit_pass_lower_cg),
    JitCompilerPass("regalloc".ptr, &jit_pass_regalloc),
    JitCompilerPass("codegen".ptr, &jit_pass_codegen),
    JitCompilerPass("register_jitted_code".ptr, &jit_pass_register_jitted_code)
];

/* Number of compiler passes */
alias COMPILER_PASS_NUM = compiler_passes.length;

version(WASM_ENABLE_FAST_JIT_DUMP ) {
private const(ubyte)[6] compiler_passes_without_dump = [
    3, 4, 5, 6, 7, 0
];
} else {
private const(ubyte)[11] compiler_passes_with_dump = [
    3, 2, 1, 4, 1, 5, 1, 6, 1, 7, 0
];
}

struct JitGlobals {
    /* Compiler pass sequence, the last element must be 0 */
    const(ubyte)* passes;
    char* return_to_interp_from_jitted;
version(WASM_ENABLE_LAZY_JIT) {
    char* compile_fast_jit_and_then_call;
}
}

/* The exported global data of JIT compiler */
JitGlobals jit_globals;

//const x=jit_globals.return_to_interp_from_jitted;
version(none)
static this() {
jit_globals.x=10;
jit_globals.return_to_interp_from_jitted= null;
jit_globals.passes = null;
version(WASM_ENABLE_FAST_JIT_DUMP) {
jit_globals.passes = compiler_passes_without_dump.ptr;
}
else {
    jit_globals.passes = compiler_passes_with_dump.ptr;
}
    jit_globals.return_to_interp_from_jitted = null;
version(WASM_ENABLE_LAZY_JIT) {
    jit_globals.compile_fast_jit_and_then_call = null;
}
}
/* clang-format on */

private bool apply_compiler_passes(JitCompContext* cc) {
    const(ubyte)* p = jit_globals.passes;

    for (; *p; p++) {
        /* Set the pass NO */
        cc.cur_pass_no = p - jit_globals.passes;
        bh_assert(*p < COMPILER_PASS_NUM);

        if (!compiler_passes[*p].run(cc) || jit_get_last_error(cc)) {
            LOG_VERBOSE("JIT: compilation failed at pass[%td] = %s\n",
                        p - jit_globals.passes, compiler_passes[*p].name);
            return false;
        }
    }

    return true;
}

bool jit_compiler_init(const(JitCompOptions)* options) {
    uint code_cache_size = options.code_cache_size > 0
                                 ? options.code_cache_size
                                 : FAST_JIT_DEFAULT_CODE_CACHE_SIZE;

    LOG_VERBOSE("JIT: compiler init with code cache size: %u\n",
                code_cache_size);

    if (!jit_code_cache_init(code_cache_size))
        return false;

    if (!jit_codegen_init())
        goto fail1;

    return true;

fail1:
    jit_code_cache_destroy();
    return false;
}

void jit_compiler_destroy() {
    jit_codegen_destroy();

    jit_code_cache_destroy();
}

JitGlobals* jit_compiler_get_jit_globals() {
    return &jit_globals;
}

const(char)* jit_compiler_get_pass_name(uint i) {
    return i < COMPILER_PASS_NUM ? compiler_passes[i].name : null;
}

bool jit_compiler_compile(WASMModule* module_, uint func_idx) {
    JitCompContext* cc = null;
    char* last_error = void;
    bool ret = false;
    uint i = func_idx - module_.import_function_count;
    uint j = i % WASM_ORC_JIT_BACKEND_THREAD_NUM;

    /* Lock to avoid duplicated compilation by other threads */
    os_mutex_lock(&module_.fast_jit_thread_locks[j]);

    if (jit_compiler_is_compiled(module_, func_idx)) {
        /* Function has been compiled */
        os_mutex_unlock(&module_.fast_jit_thread_locks[j]);
        return true;
    }

    /* Initialize the compilation context */
    if (((cc = jit_calloc(typeof(*cc).sizeof)) == 0)) {
        goto fail;
    }

    if (!jit_cc_init(cc, 64)) {
        goto fail;
    }

    cc.cur_wasm_module = module_;
    cc.cur_wasm_func = module_.functions[i];
    cc.cur_wasm_func_idx = func_idx;
    cc.mem_space_unchanged = (!cc.cur_wasm_func.has_op_memory_grow
                               && !cc.cur_wasm_func.has_op_func_call)
                              || (!module_.possible_memory_grow);

    /* Apply compiler passes */
    if (!apply_compiler_passes(cc) || jit_get_last_error(cc)) {
        last_error = jit_get_last_error(cc);
        os_printf("fast jit compilation failed: %s\n",
                  last_error ? last_error : "unknown error");
        goto fail;
    }

    ret = true;

fail:
    /* Destroy the compilation context */
    if (cc)
        jit_cc_delete(cc);

    os_mutex_unlock(&module_.fast_jit_thread_locks[j]);

    return ret;
}

bool jit_compiler_compile_all(WASMModule* module_) {
    uint i = void;

    for (i = 0; i < module_.function_count; i++) {
        if (!jit_compiler_compile(module_, module_.import_function_count + i)) {
            return false;
        }
    }

    return true;
}

bool jit_compiler_is_compiled(const(WASMModule)* module_, uint func_idx) {
    uint i = func_idx - module_.import_function_count;

    bh_assert(func_idx >= module_.import_function_count
              && func_idx
                     < module_.import_function_count + module_.function_count);

static if (WASM_ENABLE_LAZY_JIT == 0) {
    return module_.fast_jit_func_ptrs[i] ? true : false;
} else {
    return module_.fast_jit_func_ptrs[i]
                   != jit_globals.compile_fast_jit_and_then_call
               ? true
               : false;
}
}

static if (ver.WASM_ENABLE_LAZY_JIT && ver.WASM_ENABLE_JIT) {
bool jit_compiler_set_call_to_llvm_jit(WASMModule* module_, uint func_idx) {
    uint i = func_idx - module_.import_function_count;
    uint j = i % WASM_ORC_JIT_BACKEND_THREAD_NUM;
    WASMType* func_type = module_.functions[i].func_type;
    uint k = (cast(uint)cast(uintptr_t)func_type >> 3) % WASM_ORC_JIT_BACKEND_THREAD_NUM;
    void* func_ptr = null;

    /* Compile code block of call_to_llvm_jit_from_fast_jit of
       this kind of function type if it hasn't been compiled */
    if (((func_ptr = func_type.call_to_llvm_jit_from_fast_jit) == 0)) {
        os_mutex_lock(&module_.fast_jit_thread_locks[k]);
        if (((func_ptr = func_type.call_to_llvm_jit_from_fast_jit) == 0)) {
            if (((func_ptr = func_type.call_to_llvm_jit_from_fast_jit =
                      jit_codegen_compile_call_to_llvm_jit(func_type)) == 0)) {
                os_mutex_unlock(&module_.fast_jit_thread_locks[k]);
                return false;
            }
        }
        os_mutex_unlock(&module_.fast_jit_thread_locks[k]);
    }

    /* Switch current fast jit func ptr to the code block */
    os_mutex_lock(&module_.fast_jit_thread_locks[j]);
    module_.fast_jit_func_ptrs[i] = func_ptr;
    os_mutex_unlock(&module_.fast_jit_thread_locks[j]);
    return true;
}

bool jit_compiler_set_call_to_fast_jit(WASMModule* module_, uint func_idx) {
    void* func_ptr = null;

    func_ptr = jit_codegen_compile_call_to_fast_jit(module_, func_idx);
    if (func_ptr) {
        jit_compiler_set_llvm_jit_func_ptr(module_, func_idx, func_ptr);
    }

    return func_ptr ? true : false;
}

void jit_compiler_set_llvm_jit_func_ptr(WASMModule* module_, uint func_idx, void* func_ptr) {
    WASMModuleInstance* instance = void;
    uint i = func_idx - module_.import_function_count;

    module_.functions[i].llvm_jit_func_ptr = module_.func_ptrs[i] = func_ptr;

    os_mutex_lock(&module_.instance_list_lock);
    instance = module_.instance_list;
    while (instance) {
        instance.func_ptrs[func_idx] = func_ptr;
        instance = instance.e.next;
    }
    os_mutex_unlock(&module_.instance_list_lock);
}
} /* end of ver.WASM_ENABLE_LAZY_JIT && ver.WASM_ENABLE_JIT */

int jit_interp_switch_to_jitted(void* exec_env, JitInterpSwitchInfo* info, uint func_idx, void* pc) {
    return jit_codegen_interp_jitted_glue(exec_env, info, func_idx, pc);
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.interpreter.wasm_runtime;
public import tagion.iwasm.fast_jit.jit_ir;

//version (none) {
extern (C) {
//! #endif

}

/**
 * Actions the interpreter should do when jitted code returns to
 * interpreter.
 */
enum JitInterpAction {
    JIT_INTERP_ACTION_NORMAL, /* normal execution */
    JIT_INTERP_ACTION_THROWN, /* exception was thrown */
    JIT_INTERP_ACTION_CALL    /* call wasm function */
}
alias JIT_INTERP_ACTION_NORMAL = JitInterpAction.JIT_INTERP_ACTION_NORMAL;
alias JIT_INTERP_ACTION_THROWN = JitInterpAction.JIT_INTERP_ACTION_THROWN;
alias JIT_INTERP_ACTION_CALL = JitInterpAction.JIT_INTERP_ACTION_CALL;


/**
 * Information exchanged between jitted code and interpreter.
 */
struct JitInterpSwitchInfo {
    /* Points to the frame that is passed to jitted code and the frame
       that is returned from jitted code */
    void* frame;

    /* Output values from jitted code of different actions */
    union _Out_ {
        /* IP and SP offsets for NORMAL */
        struct _Normal {
            int ip;
            int sp;
        }_Normal normal;

        /* Function called from jitted code for CALL */
        struct _Call {
            void* function_;
        }_Call call;

        /* Returned integer and/or floating point values for RETURN. This
           is also used to pass return values from interpreter to jitted
           code if the caller is in jitted code and the callee is in
           interpreter. */
        struct _Ret {
            uint[2] ival;
            uint[2] fval;
            uint last_return_type;
        }_Ret ret;
    }_Out_ out_;
}

/* Jit compiler options */
struct JitCompOptions {
    uint code_cache_size;
    uint opt_level;
}

//bool jit_compiler_init(const(JitCompOptions)* option);

//void jit_compiler_destroy();

//JitGlobals* jit_compiler_get_jit_globals();

//const(char)* jit_compiler_get_pass_name(uint i);

//bool jit_compiler_compile(WASMModule* module_, uint func_idx);

//bool jit_compiler_compile_all(WASMModule* module_);

bool jit_compiler_is_compiled(const(WASMModule)* module_, uint func_idx);

static if (ver.WASM_ENABLE_LAZY_JIT && ver.WASM_ENABLE_JIT) {
bool jit_compiler_set_call_to_llvm_jit(WASMModule* module_, uint func_idx);

bool jit_compiler_set_call_to_fast_jit(WASMModule* module_, uint func_idx);

void jit_compiler_set_llvm_jit_func_ptr(WASMModule* module_, uint func_idx, void* func_ptr);
}

int jit_interp_switch_to_jitted(void* self, JitInterpSwitchInfo* info, uint func_idx, void* pc);

/*
 * Pass declarations:
 */

/**
 * Dump the compilation context.
 */
bool jit_pass_dump(JitCompContext* cc);

/**
 * Update CFG (usually before dump for better readability).
 */
bool jit_pass_update_cfg(JitCompContext* cc);

/**
 * Translate profiling result into MIR.
 */
bool jit_pass_frontend(JitCompContext* cc);

/**
 * Lower unsupported operations into supported ones.
 */
bool jit_pass_lower_cg(JitCompContext* cc);

/**
 * Register allocation.
 */
bool jit_pass_regalloc(JitCompContext* cc);

/**
 * Native code generation.
 */
bool jit_pass_codegen(JitCompContext* cc);

/**
 * Register the jitted code so that it can be executed.
 */
bool jit_pass_register_jitted_code(JitCompContext* cc);

