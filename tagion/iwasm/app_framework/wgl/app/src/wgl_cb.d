module wgl_cb;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wa-inc.lvgl.lvgl;
public import gui_api;

public import core.stdc.string;

enum ARGC = sizeof(argv) / sizeof(uint32);
enum string CALL_CB_NATIVE_FUNC(string id) = ` wasm_cb_native_call(id, argv, ARGC)`;

lv_obj_t* lv_cb_create(lv_obj_t* par, const(lv_obj_t)* copy) {
    uint[2] argv = 0;

    argv[0] = cast(uint)par;
    argv[1] = cast(uint)copy;
    CALL_CB_NATIVE_FUNC(CB_FUNC_ID_CREATE);
    return cast(lv_obj_t*)argv[0];
}

void lv_cb_set_text(lv_obj_t* cb, const(char)* txt) {
    uint[3] argv = 0;
    argv[0] = cast(uint)cb;
    argv[1] = cast(uint)txt;
    argv[2] = strlen(txt) + 1;
    CALL_CB_NATIVE_FUNC(CB_FUNC_ID_SET_TEXT);
}

void lv_cb_set_static_text(lv_obj_t* cb, const(char)* txt) {
    uint[3] argv = 0;
    argv[0] = cast(uint)cb;
    argv[1] = cast(uint)txt;
    argv[2] = strlen(txt) + 1;
    CALL_CB_NATIVE_FUNC(CB_FUNC_ID_SET_STATIC_TEXT);
}

// void wgl_cb_set_style(wgl_obj_t cb, wgl_cb_style_t type,
//                       const wgl_style_t *style)
//{
//    //TODO:
//}
//

private uint wgl_cb_get_text_length(lv_obj_t* cb) {
    uint[1] argv = 0;
    argv[0] = cast(uint)cb;
    CALL_CB_NATIVE_FUNC(CB_FUNC_ID_GET_TEXT_LENGTH);
    return argv[0];
}

private char* wgl_cb_get_text(lv_obj_t* cb, char* buffer, int buffer_len) {
    uint[3] argv = 0;
    argv[0] = cast(uint)cb;
    argv[1] = cast(uint)buffer;
    argv[2] = buffer_len;
    CALL_CB_NATIVE_FUNC(CB_FUNC_ID_GET_TEXT);
    return cast(char*)argv[0];
}

// TODO: need to use a global data buffer for the returned text
const(char)* lv_cb_get_text(const(lv_obj_t)* cb) {

    return null;
}

// const wgl_style_t * wgl_cb_get_style(const wgl_obj_t cb,
//                                      wgl_cb_style_t type)
//{
//    //TODO
//    return NULL;
//}
//
