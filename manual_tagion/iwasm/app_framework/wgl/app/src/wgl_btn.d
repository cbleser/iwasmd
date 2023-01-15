module wgl_btn;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wa-inc.lvgl.lvgl;
public import bh_platform;
public import gui_api;

enum ARGC = sizeof(argv) / sizeof(uint32);
enum string CALL_BTN_NATIVE_FUNC(string id) = ` wasm_btn_native_call(id, argv, ARGC)`;

lv_obj_t* lv_btn_create(lv_obj_t* par, const(lv_obj_t)* copy) {
    uint[2] argv = 0;

    argv[0] = cast(uint)par;
    argv[1] = cast(uint)copy;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_CREATE);
    return cast(lv_obj_t*)argv[0];
}

void lv_btn_set_toggle(lv_obj_t* btn, bool tgl) {
    uint[2] argv = 0;
    argv[0] = cast(uint)btn;
    argv[1] = tgl;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_SET_TOGGLE);
}

void lv_btn_set_state(lv_obj_t* btn, lv_btn_state_t state) {
    uint[2] argv = 0;
    argv[0] = cast(uint)btn;
    argv[1] = state;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_SET_STATE);
}

void lv_btn_toggle(lv_obj_t* btn) {
    uint[1] argv = 0;
    argv[0] = cast(uint)btn;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_TOGGLE);
}

void lv_btn_set_ink_in_time(lv_obj_t* btn, ushort time) {
    uint[2] argv = 0;
    argv[0] = cast(uint)btn;
    argv[1] = time;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_SET_INK_IN_TIME);
}

void lv_btn_set_ink_wait_time(lv_obj_t* btn, ushort time) {
    uint[2] argv = 0;
    argv[0] = cast(uint)btn;
    argv[1] = time;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_SET_INK_WAIT_TIME);
}

void lv_btn_set_ink_out_time(lv_obj_t* btn, ushort time) {
    uint[2] argv = 0;
    argv[0] = cast(uint)btn;
    argv[1] = time;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_SET_INK_OUT_TIME);
}

// void wgl_btn_set_style(wgl_obj_t btn, wgl_btn_style_t type,
//                        const wgl_style_t *style)
//{
//    //TODO: pack style
//    //wasm_btn_set_style(btn, type, style);
//}
//
lv_btn_state_t lv_btn_get_state(const(lv_obj_t)* btn) {
    uint[1] argv = 0;
    argv[0] = cast(uint)btn;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_GET_STATE);
    return cast(lv_btn_state_t)argv[0];
}

bool lv_btn_get_toggle(const(lv_obj_t)* btn) {
    uint[1] argv = 0;
    argv[0] = cast(uint)btn;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_GET_TOGGLE);
    return cast(bool)argv[0];
}

ushort lv_btn_get_ink_in_time(const(lv_obj_t)* btn) {
    uint[1] argv = 0;
    argv[0] = cast(uint)btn;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_GET_INK_IN_TIME);
    return cast(ushort)argv[0];
}

ushort lv_btn_get_ink_wait_time(const(lv_obj_t)* btn) {
    uint[1] argv = 0;
    argv[0] = cast(uint)btn;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_GET_INK_WAIT_TIME);
    return cast(ushort)argv[0];
}

ushort lv_btn_get_ink_out_time(const(lv_obj_t)* btn) {
    uint[1] argv = 0;
    argv[0] = cast(uint)btn;
    CALL_BTN_NATIVE_FUNC(BTN_FUNC_ID_GET_INK_OUT_TIME);
    return cast(ushort)argv[0];
}
//
// const wgl_style_t * wgl_btn_get_style(const wgl_obj_t btn,
//                                       wgl_btn_style_t type)
//{
//    //TODO: pack style
//    //wasm_btn_get_style(btn, type);
//    return NULL;
//}
