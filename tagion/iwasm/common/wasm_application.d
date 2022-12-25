module wasm_application;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_platform;
static if (WASM_ENABLE_INTERP != 0) {
public import ...interpreter.wasm_runtime;
}
static if (WASM_ENABLE_AOT != 0) {
public import ...aot.aot_runtime;
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
public import ...libraries.thread-mgr.thread_manager;
}

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

union ___ue {
    int a;
    char b = 0;
}private ___ue __ue = { a: 1 };

enum string is_little_endian() = ` (__ue.b == 1)`;

/**
 * Implementation of wasm_application_execute_main()
 */
private bool check_main_func_type(const(WASMType)* type) {
    if (!(type.param_count == 0 || type.param_count == 2)
        || type.result_count > 1) {
        LOG_ERROR(
            "WASM execute application failed: invalid main function type.\n");
        return false;
    }

    if (type.param_count == 2
        && !(type.types[0] == VALUE_TYPE_I32
             && type.types[1] == VALUE_TYPE_I32)) {
        LOG_ERROR(
            "WASM execute application failed: invalid main function type.\n");
        return false;
    }

    if (type.result_count
        && type.types[type.param_count] != VALUE_TYPE_I32) {
        LOG_ERROR(
            "WASM execute application failed: invalid main function type.\n");
        return false;
    }

    return true;
}

private bool execute_main(WASMModuleInstanceCommon* module_inst, int argc, char** argv) {
    WASMFunctionInstanceCommon* func = void;
    WASMType* func_type = null;
    WASMExecEnv* exec_env = null;
    uint argc1 = 0; uint[2] argv1 = 0;
    uint total_argv_size = 0;
    ulong total_size = void;
    uint argv_buf_offset = 0;
    int i = void;
    char* argv_buf = void, p = void, p_end = void;
    uint* argv_offsets = void; uint module_type = void;
    bool ret = void, is_import_func = true;

    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (!exec_env) {
        wasm_runtime_set_exception(module_inst,
                                   "create singleton exec_env failed");
        return false;
    }

static if (WASM_ENABLE_LIBC_WASI != 0) {
    /* In wasi mode, we should call the function named "_start"
       which initializes the wasi envrionment and then calls
       the actual main function. Directly calling main function
       may cause exception thrown. */
    if ((func = wasm_runtime_lookup_wasi_start_function(module_inst))) {
        return wasm_runtime_call_wasm(exec_env, func, 0, null);
    }
} /* end of WASM_ENABLE_LIBC_WASI */

    if (((func = wasm_runtime_lookup_function(module_inst, "main", null)) == 0)
        && ((func = wasm_runtime_lookup_function(module_inst,
                                                 "__main_argc_argv", null)) == 0)
        && ((func = wasm_runtime_lookup_function(module_inst, "_main", null)) == 0)) {
static if (WASM_ENABLE_LIBC_WASI != 0) {
        wasm_runtime_set_exception(
            module_inst, "lookup the entry point symbol (like _start, main, "
                         ~ "_main, __main_argc_argv) failed");
} else {
        wasm_runtime_set_exception(module_inst,
                                   "lookup the entry point symbol (like main, "
                                   ~ "_main, __main_argc_argv) failed");
}
        return false;
    }

static if (WASM_ENABLE_INTERP != 0) {
    if (module_inst.module_type == Wasm_Module_Bytecode) {
        is_import_func = (cast(WASMFunctionInstance*)func).is_import_func;
    }
}
static if (WASM_ENABLE_AOT != 0) {
    if (module_inst.module_type == Wasm_Module_AoT) {
        is_import_func = (cast(AOTFunctionInstance*)func).is_import_func;
    }
}

    if (is_import_func) {
        wasm_runtime_set_exception(module_inst, "lookup main function failed");
        return false;
    }

    module_type = module_inst.module_type;
    func_type = wasm_runtime_get_function_type(func, module_type);

    if (!func_type) {
        LOG_ERROR("invalid module instance type");
        return false;
    }

    if (!check_main_func_type(func_type)) {
        wasm_runtime_set_exception(module_inst,
                                   "invalid function type of main function");
        return false;
    }

    if (func_type.param_count) {
        for (i = 0; i < argc; i++)
            total_argv_size += (uint32)(strlen(argv[i]) + 1);
        total_argv_size = align_uint(total_argv_size, 4);

        total_size = cast(ulong)total_argv_size + sizeof(int32) * cast(ulong)argc;

        if (total_size >= UINT32_MAX
            || ((argv_buf_offset = wasm_runtime_module_malloc(
                     module_inst, cast(uint)total_size, cast(void**)&argv_buf)) == 0)) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
            return false;
        }

        p = argv_buf;
        argv_offsets = cast(uint*)(p + total_argv_size);
        p_end = p + total_size;

        for (i = 0; i < argc; i++) {
            bh_memcpy_s(p, (uint32)(p_end - p), argv[i],
                        (uint32)(strlen(argv[i]) + 1));
            argv_offsets[i] = argv_buf_offset + (uint32)(p - argv_buf);
            p += strlen(argv[i]) + 1;
        }

        argc1 = 2;
        argv1[0] = cast(uint)argc;
        argv1[1] =
            cast(uint)wasm_runtime_addr_native_to_app(module_inst, argv_offsets);
    }

    ret = wasm_runtime_call_wasm(exec_env, func, argc1, argv1.ptr);
    if (ret && func_type.result_count > 0 && argc > 0 && argv)
        /* copy the return value */
        *cast(int*)argv = cast(int)argv1[0];

    if (argv_buf_offset)
        wasm_runtime_module_free(module_inst, argv_buf_offset);
    return ret;
}

bool wasm_application_execute_main(WASMModuleInstanceCommon* module_inst, int argc, char** argv) {
    bool ret = void;
static if (WASM_ENABLE_THREAD_MGR != 0) {
    WASMCluster* cluster = void;
}
static if (WASM_ENABLE_THREAD_MGR != 0 || WASM_ENABLE_MEMORY_PROFILING != 0) {
    WASMExecEnv* exec_env = void;
}

    ret = execute_main(module_inst, argc, argv);

static if (WASM_ENABLE_THREAD_MGR != 0) {
    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env && (cluster = wasm_exec_env_get_cluster(exec_env))) {
        wasm_cluster_wait_for_all_except_self(cluster, exec_env);
    }
}

static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env) {
        wasm_runtime_dump_mem_consumption(exec_env);
    }
}

static if (WASM_ENABLE_PERF_PROFILING != 0) {
    wasm_runtime_dump_perf_profiling(module_inst);
}

    return (ret && !wasm_runtime_get_exception(module_inst)) ? true : false;
}

/**
 * Implementation of wasm_application_execute_func()
 */

union ieee754_float {
    float f = 0;

    /* This is the IEEE 754 single-precision format.  */
    union _Ieee {
        struct _Ieee_big_endian {
            uint negative;/*: 1 !!*/
            uint exponent;/*: 8 !!*/
            uint mantissa;/*: 23 !!*/
        }_Ieee_big_endian ieee_big_endian;
        struct _Ieee_little_endian {
            uint mantissa;/*: 23 !!*/
            uint exponent;/*: 8 !!*/
            uint negative;/*: 1 !!*/
        }_Ieee_little_endian ieee_little_endian;
    }_Ieee ieee;
}

union ieee754_double {
    double d = 0;

    /* This is the IEEE 754 double-precision format.  */
    union _Ieee {
        struct _Ieee_big_endian {
            uint negative;/*: 1 !!*/
            uint exponent;/*: 11 !!*/
            /* Together these comprise the mantissa.  */
            uint mantissa0;/*: 20 !!*/
            uint mantissa1;/*: 32 !!*/
        }_Ieee_big_endian ieee_big_endian;

        struct _Ieee_little_endian {
            /* Together these comprise the mantissa.  */
            uint mantissa1;/*: 32 !!*/
            uint mantissa0;/*: 20 !!*/
            uint exponent;/*: 11 !!*/
            uint negative;/*: 1 !!*/
        }_Ieee_little_endian ieee_little_endian;
    }_Ieee ieee;
}

private bool execute_func(WASMModuleInstanceCommon* module_inst, const(char)* name, int argc, char** argv) {
    WASMFunctionInstanceCommon* target_func = void;
    WASMType* type = null;
    WASMExecEnv* exec_env = null;
    uint argc1 = void; uint* argv1 = null; uint cell_num = 0, j = void, k = 0;
static if (WASM_ENABLE_REF_TYPES != 0) {
    uint param_size_in_double_world = 0, result_size_in_double_world = 0;
}
    int i = void, p = void, module_type = void;
    ulong total_size = void;
    const(char)* exception = void;
    char[128] buf = void;

    bh_assert(argc >= 0);
    LOG_DEBUG("call a function \"%s\" with %d arguments", name, argc);

    if (((target_func =
              wasm_runtime_lookup_function(module_inst, name, null)) == 0)) {
        snprintf(buf.ptr, buf.sizeof, "lookup function %s failed", name);
        wasm_runtime_set_exception(module_inst, buf.ptr);
        goto fail;
    }

    module_type = module_inst.module_type;
    type = wasm_runtime_get_function_type(target_func, module_type);

    if (!type) {
        LOG_ERROR("invalid module instance type");
        return false;
    }

    if (type.param_count != cast(uint)argc) {
        wasm_runtime_set_exception(module_inst, "invalid input argument count");
        goto fail;
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
    argc1 = param_size_in_double_world;
    cell_num = (param_size_in_double_world >= result_size_in_double_world)
                   ? param_size_in_double_world
                   : result_size_in_double_world;
} else {
    argc1 = type.param_cell_num;
    cell_num = (argc1 > type.ret_cell_num) ? argc1 : type.ret_cell_num;
}

    total_size = sizeof(uint32) * (uint64)(cell_num > 2 ? cell_num : 2);
    if ((((argv1 = runtime_malloc(cast(uint)total_size, module_inst, null, 0)) == 0))) {
        goto fail;
    }

    /* Parse arguments */
    for (i = 0, p = 0; i < argc; i++) {
        char* endptr = null;
        bh_assert(argv[i] != null);
        if (argv[i][0] == '\0') {
            snprintf(buf.ptr, buf.sizeof, "invalid input argument %" PRId32, i);
            wasm_runtime_set_exception(module_inst, buf.ptr);
            goto fail;
        }
        switch (type.types[i]) {
            case VALUE_TYPE_I32:
                argv1[p++] = cast(uint)strtoul(argv[i], &endptr, 0);
                break;
            case VALUE_TYPE_I64:
            {
                union _U {
                    ulong val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.val = strtoull(argv[i], &endptr, 0);
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
            case VALUE_TYPE_F32:
            {
                float32 f32 = strtof(argv[i], &endptr);
                if (isnan(f32)) {
                    if (argv[i][0] == '-') {
                        ieee754_float u = void;
                        u.f = f32;
                        if (is_little_endian())
                            u.ieee.ieee_little_endian.negative = 1;
                        else
                            u.ieee.ieee_big_endian.negative = 1;
                        bh_memcpy_s(&f32, float.sizeof, &u.f, float.sizeof);
                    }
                    if (endptr[0] == ':') {
                        uint sig = void;
                        ieee754_float u = void;
                        sig = cast(uint)strtoul(endptr + 1, &endptr, 0);
                        u.f = f32;
                        if (is_little_endian())
                            u.ieee.ieee_little_endian.mantissa = sig;
                        else
                            u.ieee.ieee_big_endian.mantissa = sig;
                        bh_memcpy_s(&f32, float.sizeof, &u.f, float.sizeof);
                    }
                }
                bh_memcpy_s(&argv1[p], cast(uint)total_size - p, &f32,
                            cast(uint)float.sizeof);
                p++;
                break;
            }
            case VALUE_TYPE_F64:
            {
                union _U {
                    float64 val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.val = strtod(argv[i], &endptr);
                if (isnan(u.val)) {
                    if (argv[i][0] == '-') {
                        ieee754_double ud = void;
                        ud.d = u.val;
                        if (is_little_endian())
                            ud.ieee.ieee_little_endian.negative = 1;
                        else
                            ud.ieee.ieee_big_endian.negative = 1;
                        bh_memcpy_s(&u.val, double.sizeof, &ud.d,
                                    double.sizeof);
                    }
                    if (endptr[0] == ':') {
                        ulong sig = void;
                        ieee754_double ud = void;
                        sig = strtoull(endptr + 1, &endptr, 0);
                        ud.d = u.val;
                        if (is_little_endian()) {
                            ud.ieee.ieee_little_endian.mantissa0 = sig >> 32;
                            ud.ieee.ieee_little_endian.mantissa1 = cast(uint)sig;
                        }
                        else {
                            ud.ieee.ieee_big_endian.mantissa0 = sig >> 32;
                            ud.ieee.ieee_big_endian.mantissa1 = cast(uint)sig;
                        }
                        bh_memcpy_s(&u.val, double.sizeof, &ud.d,
                                    double.sizeof);
                    }
                }
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
static if (WASM_ENABLE_SIMD != 0) {
            case VALUE_TYPE_V128:
            {
                /* it likes 0x123\0x234 or 123\234 */
                /* retrive first i64 */
                *cast(ulong*)(argv1 + p) = strtoull(argv[i], &endptr, 0);
                /* skip \ */
                endptr++;
                /* retrive second i64 */
                *cast(ulong*)(argv1 + p + 2) = strtoull(endptr, &endptr, 0);
                p += 4;
                break;
            }
} /* WASM_ENABLE_SIMD != 0 */
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
            {
                if (strncasecmp(argv[i], "null", 4) == 0) {
                    argv1[p++] = (uint32)-1;
                }
                else {
                    argv1[p++] = cast(uint)strtoul(argv[i], &endptr, 0);
                }
                break;
            }
            case VALUE_TYPE_EXTERNREF:
            {
static if (UINTPTR_MAX == UINT32_MAX) {
                if (strncasecmp(argv[i], "null", 4) == 0) {
                    argv1[p++] = (uint32)-1;
                }
                else {
                    argv1[p++] = strtoul(argv[i], &endptr, 0);
                }
} else {
                union _U {
                    uintptr_t val = void;
                    uint[2] parts = void;
                }_U u = void;
                if (strncasecmp(argv[i], "null", 4) == 0) {
                    u.val = cast(uintptr_t)-1LL;
                }
                else {
                    u.val = strtoull(argv[i], &endptr, 0);
                }
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
}
                break;
            }
} /* WASM_ENABLE_REF_TYPES */
            default:
                bh_assert(0);
                break;
        }
        if (endptr && *endptr != '\0' && *endptr != '_') {
            snprintf(buf.ptr, buf.sizeof, "invalid input argument %" PRId32 ~ ": %s",
                     i, argv[i]);
            wasm_runtime_set_exception(module_inst, buf.ptr);
            goto fail;
        }
    }

    wasm_runtime_set_exception(module_inst, null);
static if (WASM_ENABLE_REF_TYPES == 0) {
    bh_assert(p == cast(int)argc1);
}

    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (!exec_env) {
        wasm_runtime_set_exception(module_inst,
                                   "create singleton exec_env failed");
        goto fail;
    }

    if (!wasm_runtime_call_wasm(exec_env, target_func, argc1, argv1)) {
        goto fail;
    }

    /* print return value */
    for (j = 0; j < type.result_count; j++) {
        switch (type.types[type.param_count + j]) {
            case VALUE_TYPE_I32:
            {
                os_printf("0x%" PRIx32 ~ ":i32", argv1[k]);
                k++;
                break;
            }
            case VALUE_TYPE_I64:
            {
                union _U {
                    ulong val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                os_printf("0x%" PRIx64 ~ ":i64", u.val);
                break;
            }
            case VALUE_TYPE_F32:
            {
                os_printf("%.7g:f32", *cast(float32*)(argv1 + k));
                k++;
                break;
            }
            case VALUE_TYPE_F64:
            {
                union _U {
                    float64 val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                os_printf("%.7g:f64", u.val);
                break;
            }
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
            {
                if (argv1[k] != NULL_REF)
                    os_printf("%" PRIu32 ~ ":ref.func", argv1[k]);
                else
                    os_printf("func:ref.null");
                k++;
                break;
            }
            case VALUE_TYPE_EXTERNREF:
            {
static if (UINTPTR_MAX == UINT32_MAX) {
                if (argv1[k] != 0 && argv1[k] != (uint32)-1)
                    os_printf("%p:ref.extern", cast(void*)argv1[k]);
                else
                    os_printf("extern:ref.null");
                k++;
} else {
                union _U {
                    uintptr_t val = void;
                    uint[2] parts = void;
                }_U u = void;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                if (u.val && u.val != cast(uintptr_t)-1LL)
                    os_printf("%p:ref.extern", cast(void*)u.val);
                else
                    os_printf("extern:ref.null");
}
                break;
            }
}
static if (WASM_ENABLE_SIMD != 0) {
            case VALUE_TYPE_V128:
            {
                ulong* v = cast(ulong*)(argv1 + k);
                os_printf("<0x%016" PRIx64 ~ " 0x%016" PRIx64 ~ ">:v128", *v,
                          *(v + 1));
                k += 4;
                break;
            }
} /*  WASM_ENABLE_SIMD != 0 */
            default:
                bh_assert(0);
                break;
        }
        if (j < (uint32)(type.result_count - 1))
            os_printf(",");
    }
    os_printf("\n");

    wasm_runtime_free(argv1);
    return true;

fail:
    if (argv1)
        wasm_runtime_free(argv1);

    exception = wasm_runtime_get_exception(module_inst);
    bh_assert(exception);
    os_printf("%s\n", exception);
    return false;
}

bool wasm_application_execute_func(WASMModuleInstanceCommon* module_inst, const(char)* name, int argc, char** argv) {
    bool ret = void;
static if (WASM_ENABLE_THREAD_MGR != 0) {
    WASMCluster* cluster = void;
}
static if (WASM_ENABLE_THREAD_MGR != 0 || WASM_ENABLE_MEMORY_PROFILING != 0) {
    WASMExecEnv* exec_env = void;
}

    ret = execute_func(module_inst, name, argc, argv);

static if (WASM_ENABLE_THREAD_MGR != 0) {
    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env && (cluster = wasm_exec_env_get_cluster(exec_env))) {
        wasm_cluster_wait_for_all_except_self(cluster, exec_env);
    }
}

static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env) {
        wasm_runtime_dump_mem_consumption(exec_env);
    }
}

static if (WASM_ENABLE_PERF_PROFILING != 0) {
    wasm_runtime_dump_perf_profiling(module_inst);
}

    return (ret && !wasm_runtime_get_exception(module_inst)) ? true : false;
}
