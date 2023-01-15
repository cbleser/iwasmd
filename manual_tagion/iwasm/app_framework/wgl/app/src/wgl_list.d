module wgl_list;
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
enum string CALL_LIST_NATIVE_FUNC(string id) = ` wasm_list_native_call(id, argv, ARGC)`;

lv_obj_t* lv_list_create(lv_obj_t* par, const(lv_obj_t)* copy) {
    uint[2] argv = 0;

    argv[0] = cast(uint)par;
    argv[1] = cast(uint)copy;

    CALL_LIST_NATIVE_FUNC(LIST_FUNC_ID_CREATE);
    return cast(lv_obj_t*)argv[0];
}
//
//
// void wgl_list_clean(wgl_obj_t obj)
//{
//    wasm_list_clean(obj);
//}
//

lv_obj_t* lv_list_add_btn(lv_obj_t* list, const(void)* img_src, const(char)* txt) {
    uint[3] argv = 0;

    cast(void)img_src; /* doesn't support img src currently */

    argv[0] = cast(uint)list;
    argv[1] = cast(uint)txt;
    argv[2] = strlen(txt) + 1;
    CALL_LIST_NATIVE_FUNC(LIST_FUNC_ID_ADD_BTN);
    return cast(lv_obj_t*)argv[0];
}
//
//
// bool wgl_list_remove(const wgl_obj_t list, uint16_t index)
//{
//    return wasm_list_remove(list, index);
//}
//
//
// void wgl_list_set_single_mode(wgl_obj_t list, bool mode)
//{
//    wasm_list_set_single_mode(list, mode);
//}
//
//#if LV_USE_GROUP
//
//
// void wgl_list_set_btn_selected(wgl_obj_t list, wgl_obj_t btn)
//{
//    wasm_list_set_btn_selected(list, btn);
//}
//#endif
//
//
// void wgl_list_set_style(wgl_obj_t list, wgl_list_style_t type,
//                         const wgl_style_t * style)
//{
//    //TODO
//}
//
//
// bool wgl_list_get_single_mode(wgl_obj_t list)
//{
//    return wasm_list_get_single_mode(list);
//}
//
//
// const char * wgl_list_get_btn_text(const wgl_obj_t btn)
//{
//    return wasm_list_get_btn_text(btn);
//}
//
// wgl_obj_t wgl_list_get_btn_label(const wgl_obj_t btn)
//{
//    return wasm_list_get_btn_label(btn);
//}
//
//
// wgl_obj_t wgl_list_get_btn_img(const wgl_obj_t btn)
//{
//    return wasm_list_get_btn_img(btn);
//}
//
//
// wgl_obj_t wgl_list_get_prev_btn(const wgl_obj_t list, wgl_obj_t prev_btn)
//{
//    return wasm_list_get_prev_btn(list, prev_btn);
//}
//
//
// wgl_obj_t wgl_list_get_next_btn(const wgl_obj_t list, wgl_obj_t prev_btn)
//{
//    return wasm_list_get_next_btn(list, prev_btn);
//}
//
//
// int32_t wgl_list_get_btn_index(const wgl_obj_t list, const wgl_obj_t btn)
//{
//    return wasm_list_get_btn_index(list, btn);
//}
//
//
// uint16_t wgl_list_get_size(const wgl_obj_t list)
//{
//    return wasm_list_get_size(list);
//}
//
//#if LV_USE_GROUP
//
// wgl_obj_t wgl_list_get_btn_selected(const wgl_obj_t list)
//{
//    return wasm_list_get_btn_selected(list);
//}
//#endif
//
//
//
// const wgl_style_t * wgl_list_get_style(const wgl_obj_t list,
//                                        wgl_list_style_t type)
//{
//    //TODO
//    return NULL;
//}
//
//
// void wgl_list_up(const wgl_obj_t list)
//{
//    wasm_list_up(list);
//}
//
// void wgl_list_down(const wgl_obj_t list)
//{
//    wasm_list_down(list);
//}
//
//
// void wgl_list_focus(const wgl_obj_t btn, wgl_anim_enable_t anim)
//{
//    wasm_list_focus(btn, anim);
//}
//
