module wgl_list_wrapper;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import native_interface;
public import lvgl;
public import module_wasm_app;
public import wgl_native_utils;
public import bh_assert;

/* -------------------------------------------------------------------------
 * List widget native function wrappers
 * -------------------------------------------------------------------------*/
DEFINE_WGL_NATIVE_WRAPPER lv_list_create_wrapper {
    int res = void;
    wgl_native_return_type(int32);
    wgl_native_get_arg(uint32, par_obj_id);
    wgl_native_get_arg(uint32, copy_obj_id);
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    res = wgl_native_wigdet_create(WIDGET_TYPE_LIST, par_obj_id, copy_obj_id,
                                   module_inst);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_list_add_btn_wrapper {
    wgl_native_return_type(int32);
    wgl_native_get_arg(lv_obj_t, list);
    wgl_native_get_arg(uint32, text_offset);
    wgl_native_get_arg(uint32, text_len);
    uint btn_obj_id = void;
    lv_obj_t* btn = void;
    uint mod_id = void;
    char* text = void;
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (!validate_app_addr(text_offset, text_len)
        || ((text = addr_app_to_native(text_offset)) == 0))
        return;

    if (((btn = lv_list_add_btn(list, null, text)) == 0)) {
        wasm_runtime_set_exception(module_inst, "add button to list fail.");
        return;
    }

    mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
    bh_assert(mod_id != ID_NONE);

    if (!wgl_native_add_object(btn, mod_id, &btn_obj_id)) {
        wasm_runtime_set_exception(module_inst,
                                   "add button to object list fail.");
        return;
    }

    wgl_native_set_return(btn_obj_id);
}

private WGLNativeFuncDef[3] list_native_func_defs = [
    [ LIST_FUNC_ID_CREATE, lv_list_create_wrapper, 2, false ],
    [ LIST_FUNC_ID_ADD_BTN, lv_list_add_btn_wrapper, 3, true ],
];

/*************** Native Interface to Wasm App ***********/
void wasm_list_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc) {
    uint size = list_native_func_defs.sizeof / WGLNativeFuncDef.sizeof;

    wgl_native_func_call(exec_env, list_native_func_defs.ptr, size, func_id, argv,
                         argc);
}
