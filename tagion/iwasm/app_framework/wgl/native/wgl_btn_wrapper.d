module wgl_btn_wrapper;
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

/* -------------------------------------------------------------------------
 * Button widget native function wrappers
 * -------------------------------------------------------------------------*/
DEFINE_WGL_NATIVE_WRAPPER lv_btn_create_wrapper {
    int res = void;
    wgl_native_return_type(int32);
    wgl_native_get_arg(uint32, par_obj_id);
    wgl_native_get_arg(uint32, copy_obj_id);
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    res = wgl_native_wigdet_create(WIDGET_TYPE_BTN, par_obj_id, copy_obj_id,
                                   module_inst);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_set_toggle_wrapper {
    wgl_native_get_arg(lv_obj_t, btn);
    wgl_native_get_arg(bool_, tgl);

    cast(void)exec_env;
    lv_btn_set_toggle(btn, tgl);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_set_state_wrapper {
    wgl_native_get_arg(lv_obj_t, btn);
    wgl_native_get_arg(lv_btn_state_t, state);

    cast(void)exec_env;
    lv_btn_set_state(btn, state);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_set_ink_in_time_wrapper {
    wgl_native_get_arg(lv_obj_t, btn);
    wgl_native_get_arg(uint16_t, time);

    cast(void)exec_env;
    lv_btn_set_ink_in_time(btn, time);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_set_ink_out_time_wrapper {
    wgl_native_get_arg(lv_obj_t, btn);
    wgl_native_get_arg(uint16_t, time);

    cast(void)exec_env;
    lv_btn_set_ink_out_time(btn, time);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_set_ink_wait_time_wrapper {
    wgl_native_get_arg(lv_obj_t, btn);
    wgl_native_get_arg(uint16_t, time);

    cast(void)exec_env;
    lv_btn_set_ink_wait_time(btn, time);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_get_ink_in_time_wrapper {
    ushort res = void;
    wgl_native_return_type(uint16_t);
    wgl_native_get_arg(lv_obj_t, btn);

    cast(void)exec_env;
    res = lv_btn_get_ink_in_time(btn);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_get_ink_out_time_wrapper {
    ushort res = void;
    wgl_native_return_type(uint16_t);
    wgl_native_get_arg(lv_obj_t, btn);

    cast(void)exec_env;
    res = lv_btn_get_ink_out_time(btn);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_get_ink_wait_time_wrapper {
    ushort res = void;
    wgl_native_return_type(uint16_t);
    wgl_native_get_arg(lv_obj_t, btn);

    cast(void)exec_env;
    res = lv_btn_get_ink_wait_time(btn);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_get_state_wrapper {
    lv_btn_state_t res = void;
    wgl_native_return_type(lv_btn_state_t);
    wgl_native_get_arg(lv_obj_t, btn);

    cast(void)exec_env;
    res = lv_btn_get_state(btn);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_get_toggle_wrapper {
    bool res = void;
    wgl_native_return_type(bool_);
    wgl_native_get_arg(lv_obj_t, btn);

    cast(void)exec_env;
    res = lv_btn_get_toggle(btn);
    wgl_native_set_return(res);
}

DEFINE_WGL_NATIVE_WRAPPER lv_btn_toggle_wrapper {
    wgl_native_get_arg(lv_obj_t, btn);

    cast(void)exec_env;
    lv_btn_toggle(btn);
}

/* clang-format off */
private WGLNativeFuncDef[13] btn_native_func_defs = [
    [ BTN_FUNC_ID_CREATE, lv_btn_create_wrapper, 2, false ],
    [ BTN_FUNC_ID_SET_TOGGLE, lv_btn_set_toggle_wrapper, 2, true ],
    [ BTN_FUNC_ID_SET_STATE, lv_btn_set_state_wrapper, 2, true ],
    [ BTN_FUNC_ID_SET_INK_IN_TIME, lv_btn_set_ink_in_time_wrapper, 2, true ],
    [ BTN_FUNC_ID_SET_INK_OUT_TIME, lv_btn_set_ink_out_time_wrapper, 2, true ],
    [ BTN_FUNC_ID_SET_INK_WAIT_TIME, lv_btn_set_ink_wait_time_wrapper, 2, true ],
    [ BTN_FUNC_ID_GET_INK_IN_TIME, lv_btn_get_ink_in_time_wrapper, 1, true ],
    [ BTN_FUNC_ID_GET_INK_OUT_TIME, lv_btn_get_ink_out_time_wrapper, 1, true ],
    [ BTN_FUNC_ID_GET_INK_WAIT_TIME, lv_btn_get_ink_wait_time_wrapper, 1, true ],
    [ BTN_FUNC_ID_GET_STATE, lv_btn_get_state_wrapper, 1, true ],
    [ BTN_FUNC_ID_GET_TOGGLE, lv_btn_get_toggle_wrapper, 1, true ],
    [ BTN_FUNC_ID_TOGGLE, lv_btn_toggle_wrapper, 1, true ],
];
/* clang-format on */

/*************** Native Interface to Wasm App ***********/
void wasm_btn_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc) {
    uint size = btn_native_func_defs.sizeof / WGLNativeFuncDef.sizeof;

    wgl_native_func_call(exec_env, btn_native_func_defs.ptr, size, func_id, argv,
                         argc);
}
