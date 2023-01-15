module wgl_native_utils;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef WAMR_GRAPHIC_LIBRARY_NATIVE_UTILS_H
version = WAMR_GRAPHIC_LIBRARY_NATIVE_UTILS_H;

#ifdef __cplusplus
extern "C" {
//! #endif

public import bh_platform;
public import lvgl;
public import wasm_export;
public import bi-inc.wgl_shared_utils;

enum string wgl_native_return_type(string type) = ` type *wgl_ret = (type *)(args_ret)`;
enum string wgl_native_get_arg(string type, string name) = ` type name = *((type *)(args++))`;
enum string wgl_native_set_return(string val) = ` *wgl_ret = (val)`;

enum string DEFINE_WGL_NATIVE_WRAPPER(string func_name) = `                      \
    static void func_name(wasm_exec_env_t exec_env, uint64 *args, \
                          uint32 *args_ret)`;

enum {
    WIDGET_TYPE_BTN,
    WIDGET_TYPE_LABEL,
    WIDGET_TYPE_CB,
    WIDGET_TYPE_LIST,
    WIDGET_TYPE_DDLIST,

    _WIDGET_TYPE_NUM,
};

struct WGLNativeFuncDef {
    /* Function id */
    int func_id;

    /* Native function pointer */
    void* func_ptr;

    /* argument number */
    ubyte arg_num;

    /* whether the first argument is lvgl object and needs validate */
    bool check_obj;
}

bool wgl_native_validate_object(int obj_id, lv_obj_t** obj);

bool wgl_native_add_object(lv_obj_t* obj, uint module_id, uint* obj_id);

uint wgl_native_wigdet_create(byte widget_type, uint par_obj_id, uint copy_obj_id, wasm_module_inst_t module_inst);

void wgl_native_func_call(wasm_exec_env_t exec_env, WGLNativeFuncDef* funcs, uint size, int func_id, uint* argv, uint argc);

version (none) {
}
}

//! #endif /* WAMR_GRAPHIC_LIBRARY_NATIVE_UTILS_H */


public import wgl_native_utils;
public import lvgl;
public import module_wasm_app;
public import wasm_export;
public import bh_assert;

public import core.stdc.stdint;

enum string THROW_EXC(string msg) = ` wasm_runtime_set_exception(module_inst, msg);`;

uint wgl_native_wigdet_create(byte widget_type, uint par_obj_id, uint copy_obj_id, wasm_module_inst_t module_inst) {
    uint obj_id = void;
    lv_obj_t* wigdet = null, par = null, copy = null;
    uint mod_id = void;

    // TODO: limit total widget number

    /* validate the parent object id if not equal to 0 */
    if (par_obj_id != 0 && !wgl_native_validate_object(par_obj_id, &par)) {
        THROW_EXC("create widget with invalid parent object.");
        return 0;
    }
    /* validate the copy object id if not equal to 0 */
    if (copy_obj_id != 0 && !wgl_native_validate_object(copy_obj_id, &copy)) {
        THROW_EXC("create widget with invalid copy object.");
        return 0;
    }

    if (par == null)
        par = lv_disp_get_scr_act(null);

    if (widget_type == WIDGET_TYPE_BTN)
        wigdet = lv_btn_create(par, copy);
    else if (widget_type == WIDGET_TYPE_LABEL)
        wigdet = lv_label_create(par, copy);
    else if (widget_type == WIDGET_TYPE_CB)
        wigdet = lv_cb_create(par, copy);
    else if (widget_type == WIDGET_TYPE_LIST)
        wigdet = lv_list_create(par, copy);
    else if (widget_type == WIDGET_TYPE_DDLIST)
        wigdet = lv_ddlist_create(par, copy);

    if (wigdet == null)
        return 0;

    mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
    bh_assert(mod_id != ID_NONE);

    if (wgl_native_add_object(wigdet, mod_id, &obj_id))
        return obj_id; /* success return */

    return 0;
}

void wgl_native_func_call(wasm_exec_env_t exec_env, WGLNativeFuncDef* funcs, uint size, int func_id, uint* argv, uint argc) {
    alias WGLNativeFuncPtr = void function(wasm_exec_env_t, ulong*, uint*);
    WGLNativeFuncPtr wglNativeFuncPtr = void;
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    WGLNativeFuncDef* func_def = funcs;
    WGLNativeFuncDef* func_def_end = func_def + size;

    /* Note: argv is validated in wasm_runtime_invoke_native()
     * with pointer length equals to 1. Here validate the argv
     * buffer again but with its total length in bytes */
    if (!wasm_runtime_validate_native_addr(module_inst, argv,
                                           argc * uint32.sizeof))
        return;

    while (func_def < func_def_end) {
        if (func_def.func_id == func_id && cast(uint)func_def.arg_num == argc) {
            ulong[16] argv_copy_buf = void; ulong size = void;
            ulong* argv_copy = argv_copy_buf;
            int i = void;

            if (argc > argv_copy_buf.sizeof / uint64.sizeof) {
                size = sizeof(uint64) * cast(ulong)argc;
                if (size >= UINT32_MAX
                    || ((argv_copy = wasm_runtime_malloc(cast(uint)size)) == 0)) {
                    THROW_EXC("allocate memory failed.");
                    return;
                }
                memset(argv_copy, 0, cast(uint)size);
            }

            /* Init argv_copy */
            for (i = 0; i < func_def.arg_num; i++)
                *cast(uint*)&argv_copy[i] = argv[i];

            /* Validate the first argument which is a lvgl object if needed */
            if (func_def.check_obj) {
                lv_obj_t* obj = null;
                if (!wgl_native_validate_object(argv[0], &obj)) {
                    THROW_EXC("the object is invalid");
                    goto fail;
                }
                *cast(lv_obj_t**)&argv_copy[0] = obj;
            }

            wglNativeFuncPtr = cast(WGLNativeFuncPtr)func_def.func_ptr;
            wglNativeFuncPtr(exec_env, argv_copy, argv);

            if (argv_copy != argv_copy_buf.ptr)
                wasm_runtime_free(argv_copy);

            /* success return */
            return;

        fail:
            if (argv_copy != argv_copy_buf.ptr)
                wasm_runtime_free(argv_copy);
            return;
        }

        func_def++;
    }

    THROW_EXC("the native widget function is not found!");
}
