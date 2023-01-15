module wgl_label_wrapper;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import lvgl;
public import wasm_export;
public import native_interface;
public import module_wasm_app;
public import wgl_native_utils;

/* -------------------------------------------------------------------------
 * Label widget native function wrappers
 * -------------------------------------------------------------------------*/
DEFINE_WGL_NATIVE_WRAPPER lv_label_create_wrapper {
    int res = void;
    wgl_native_return_type(int32);
    wgl_native_get_arg(uint32, par_obj_id);
    wgl_native_get_arg(uint32, copy_obj_id);
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    res = wgl_native_wigdet_create(WIDGET_TYPE_LABEL, par_obj_id, copy_obj_id,
                                   module_inst);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_label_set_text_wrapper {
    char* text = void;
    wgl_native_get_arg(lv_obj_t, label);
    wgl_native_get_arg(uint32, text_offset);
    wgl_native_get_arg(uint32, text_len);
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (!validate_app_addr(text_offset, text_len)
        || ((text = addr_app_to_native(text_offset)) == 0))
        return;

    lv_label_set_text(label, text);
}

DEFINE_WGL_NATIVE_WRAPPER lv_label_get_text_length_wrapper {
    wgl_native_return_type(int32);
    wgl_native_get_arg(lv_obj_t, label);
    const(char)* text = void;

    cast(void)exec_env;

    text = lv_label_get_text(label);
    wgl_native_set_return(text ? strlen(text) : 0);
}

DEFINE_WGL_NATIVE_WRAPPER lv_label_get_text_wrapper {
    const(char)* text = void;
    char* buffer = void;
    wgl_native_return_type(uint32);
    wgl_native_get_arg(lv_obj_t, label);
    wgl_native_get_arg(uint32, buffer_offset);
    wgl_native_get_arg(int, buffer_len);
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (!validate_app_addr(buffer_offset, buffer_len)
        || ((buffer = addr_app_to_native(buffer_offset)) == 0))
        return;

    if ((text = lv_label_get_text(label))) {
        strncpy(buffer, text, buffer_len - 1);
        buffer[buffer_len - 1] = '\0';
    }

    wgl_native_set_return(buffer_offset);
}

/* clang-format off */
private WGLNativeFuncDef[5] label_native_func_defs = [
    [ LABEL_FUNC_ID_CREATE, lv_label_create_wrapper, 2, false ],
    [ LABEL_FUNC_ID_SET_TEXT, lv_label_set_text_wrapper, 3, true ],
    [ LABEL_FUNC_ID_GET_TEXT_LENGTH, lv_label_get_text_length_wrapper, 1, true ],
    [ LABEL_FUNC_ID_GET_TEXT, lv_label_get_text_wrapper, 3, true ],
];
/* clang-format on */

/*************** Native Interface to Wasm App ***********/
void wasm_label_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc) {
    uint size = label_native_func_defs.sizeof / WGLNativeFuncDef.sizeof;

    wgl_native_func_call(exec_env, label_native_func_defs.ptr, size, func_id, argv,
                         argc);
}
