module wgl_obj;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wa-inc.lvgl.lvgl;
public import gui_api;
public import core.stdc.stdlib;
public import core.stdc.string;

enum ARGC = sizeof(argv) / sizeof(uint32);
enum string CALL_OBJ_NATIVE_FUNC(string id) = ` wasm_obj_native_call(id, argv, ARGC)`;

struct _obj_evt_cb {
    _obj_evt_cb* next;

    lv_obj_t* obj;
    lv_event_cb_t event_cb;
}alias obj_evt_cb_t = _obj_evt_cb;

private obj_evt_cb_t* g_obj_evt_cb_list = null;

/* For lvgl compatible */
char[100] g_widget_text = 0;

lv_res_t lv_obj_del(lv_obj_t* obj) {
    uint[1] argv = 0;
    argv[0] = cast(uint)obj;
    CALL_OBJ_NATIVE_FUNC(OBJ_FUNC_ID_DEL);
    return cast(lv_res_t)argv[0];
}

void lv_obj_del_async(_lv_obj_t* obj) {
    uint[1] argv = 0;
    argv[0] = cast(uint)obj;
    CALL_OBJ_NATIVE_FUNC(OBJ_FUNC_ID_DEL_ASYNC);
}

void lv_obj_clean(lv_obj_t* obj) {
    uint[1] argv = 0;
    argv[0] = cast(uint)obj;
    CALL_OBJ_NATIVE_FUNC(OBJ_FUNC_ID_CLEAN);
}

void lv_obj_align(lv_obj_t* obj, const(lv_obj_t)* base, lv_align_t align_, lv_coord_t x_mod, lv_coord_t y_mod) {
    uint[5] argv = 0;
    argv[0] = cast(uint)obj;
    argv[1] = cast(uint)base;
    argv[2] = align_;
    argv[3] = x_mod;
    argv[4] = y_mod;
    CALL_OBJ_NATIVE_FUNC(OBJ_FUNC_ID_ALIGN);
}

lv_event_cb_t lv_obj_get_event_cb(const(lv_obj_t)* obj) {
    obj_evt_cb_t* obj_evt_cb = g_obj_evt_cb_list;
    while (obj_evt_cb != null) {
        if (obj_evt_cb.obj == obj) {
            return obj_evt_cb.event_cb;
        }
        obj_evt_cb = obj_evt_cb.next;
    }

    return null;
}

void lv_obj_set_event_cb(lv_obj_t* obj, lv_event_cb_t event_cb) {
    obj_evt_cb_t* obj_evt_cb = void;
    uint[1] argv = 0;

    obj_evt_cb = g_obj_evt_cb_list;
    while (obj_evt_cb) {
        if (obj_evt_cb.obj == obj) {
            obj_evt_cb.event_cb = event_cb;
            return;
        }
    }

    obj_evt_cb = cast(obj_evt_cb_t*)malloc(typeof(*obj_evt_cb).sizeof);
    if (obj_evt_cb == null)
        return;

    memset(obj_evt_cb, 0, typeof(*obj_evt_cb).sizeof);
    obj_evt_cb.obj = obj;
    obj_evt_cb.event_cb = event_cb;

    if (g_obj_evt_cb_list != null) {
        obj_evt_cb.next = g_obj_evt_cb_list;
        g_obj_evt_cb_list = obj_evt_cb;
    }
    else {
        g_obj_evt_cb_list = obj_evt_cb;
    }

    argv[0] = cast(uint)obj;
    CALL_OBJ_NATIVE_FUNC(OBJ_FUNC_ID_SET_EVT_CB);
}

void on_widget_event(lv_obj_t* obj, lv_event_t event) {
    obj_evt_cb_t* obj_evt_cb = g_obj_evt_cb_list;

    while (obj_evt_cb != null) {
        if (obj_evt_cb.obj == obj) {
            obj_evt_cb.event_cb(obj, event);
            return;
        }
        obj_evt_cb = obj_evt_cb.next;
    }
}
