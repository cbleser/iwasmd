module wgl_label;
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
enum string CALL_LABEL_NATIVE_FUNC(string id) = ` wasm_label_native_call(id, argv, ARGC)`;

lv_obj_t* lv_label_create(lv_obj_t* par, const(lv_obj_t)* copy) {
    uint[2] argv = 0;

    argv[0] = cast(uint)par;
    argv[1] = cast(uint)copy;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_CREATE);
    return cast(lv_obj_t*)argv[0];
}

void lv_label_set_text(lv_obj_t* label, const(char)* text) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = cast(uint)text;
    argv[2] = strlen(text) + 1;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_TEXT);
}

void lv_label_set_array_text(lv_obj_t* label, const(char)* array, ushort size) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = cast(uint)array;
    argv[2] = size;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_ARRAY_TEXT);
}

void lv_label_set_static_text(lv_obj_t* label, const(char)* text) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = cast(uint)text;
    argv[2] = strlen(text) + 1;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_STATIC_TEXT);
}

void lv_label_set_long_mode(lv_obj_t* label, lv_label_long_mode_t long_mode) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = long_mode;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_LONG_MODE);
}

void lv_label_set_align(lv_obj_t* label, lv_label_align_t align_) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = align_;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_ALIGN);
}

void lv_label_set_recolor(lv_obj_t* label, bool en) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = en;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_RECOLOR);
}

void lv_label_set_body_draw(lv_obj_t* label, bool en) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = en;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_BODY_DRAW);
}

void lv_label_set_anim_speed(lv_obj_t* label, ushort anim_speed) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = anim_speed;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_ANIM_SPEED);
}

void lv_label_set_text_sel_start(lv_obj_t* label, ushort index) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = index;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_TEXT_SEL_START);
}

void lv_label_set_text_sel_end(lv_obj_t* label, ushort index) {
    uint[2] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = index;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_SET_TEXT_SEL_END);
}

uint wgl_label_get_text_length(lv_obj_t* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_TEXT_LENGTH);
    return argv[0];
}

char* wgl_label_get_text(lv_obj_t* label, char* buffer, int buffer_len) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = cast(uint)buffer;
    argv[2] = buffer_len;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_TEXT);
    return cast(char*)argv[0];
}

// TODO:
char* lv_label_get_text(const(lv_obj_t)* label) {

    return null;
}

lv_label_long_mode_t lv_label_get_long_mode(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_LONG_MODE);
    return cast(lv_label_long_mode_t)argv[0];
}

lv_label_align_t lv_label_get_align(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_ALIGN);
    return cast(lv_label_align_t)argv[0];
}

bool lv_label_get_recolor(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_RECOLOR);
    return cast(bool)argv[0];
}

bool lv_label_get_body_draw(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_BODY_DRAW);
    return cast(bool)argv[0];
}

ushort lv_label_get_anim_speed(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_ANIM_SPEED);
    return cast(ushort)argv[0];
}

void lv_label_get_letter_pos(const(lv_obj_t)* label, ushort index, lv_point_t* pos) {
    uint[4] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = index;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_LETTER_POS);
    pos.x = argv[2];
    pos.y = argv[3];
}

ushort lv_label_get_letter_on(const(lv_obj_t)* label, lv_point_t* pos) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = pos.x;
    argv[2] = pos.y;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_LETTER_POS);
    return cast(ushort)argv[0];
}

bool lv_label_is_char_under_pos(const(lv_obj_t)* label, lv_point_t* pos) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = pos.x;
    argv[2] = pos.y;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_LETTER_POS);
    return cast(bool)argv[0];
}

ushort lv_label_get_text_sel_start(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_TEXT_SEL_START);
    return cast(ushort)argv[0];
}

ushort lv_label_get_text_sel_end(const(lv_obj_t)* label) {
    uint[1] argv = 0;
    argv[0] = cast(uint)label;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_GET_TEXT_SEL_END);
    return cast(ushort)argv[0];
}

void lv_label_ins_text(lv_obj_t* label, uint pos, const(char)* txt) {
    uint[4] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = pos;
    argv[2] = cast(uint)txt;
    argv[3] = strlen(txt) + 1;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_INS_TEXT);
}

void lv_label_cut_text(lv_obj_t* label, uint pos, uint cnt) {
    uint[3] argv = 0;
    argv[0] = cast(uint)label;
    argv[1] = pos;
    argv[2] = cnt;
    CALL_LABEL_NATIVE_FUNC(LABEL_FUNC_ID_CUT_TEXT);
}
