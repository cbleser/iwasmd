module lvgl;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
version (none) {
extern "C" {
//! #endif

//#include "bi-inc/wgl_shared_utils.h" /* shared types between app and native */
/*
#include "lvgl-compatible/lv_types.h"
#include "lvgl-compatible/lv_obj.h"
#include "lvgl-compatible/lv_btn.h"
#include "lvgl-compatible/lv_cb.h"
#include "lvgl-compatible/lv_label.h"
#include "lvgl-compatible/lv_list.h"
*/

public import src.lv_version;

public import src.lv_misc.lv_log;
public import src.lv_misc.lv_task;
public import src.lv_misc.lv_math;
//#include "src/lv_misc/lv_async.h"

//#include "src/lv_hal/lv_hal.h"

public import src.lv_core.lv_obj;
public import src.lv_core.lv_group;

public import src.lv_core.lv_refr;
public import src.lv_core.lv_disp;

public import src.lv_themes.lv_theme;

public import src.lv_font.lv_font;
public import src.lv_font.lv_font_fmt_txt;

public import src.lv_objx.lv_btn;
public import src.lv_objx.lv_imgbtn;
public import src.lv_objx.lv_img;
public import src.lv_objx.lv_label;
public import src.lv_objx.lv_line;
public import src.lv_objx.lv_page;
public import src.lv_objx.lv_cont;
public import src.lv_objx.lv_list;
public import src.lv_objx.lv_chart;
public import src.lv_objx.lv_table;
public import src.lv_objx.lv_cb;
public import src.lv_objx.lv_bar;
public import src.lv_objx.lv_slider;
public import src.lv_objx.lv_led;
public import src.lv_objx.lv_btnm;
public import src.lv_objx.lv_kb;
public import src.lv_objx.lv_ddlist;
public import src.lv_objx.lv_roller;
public import src.lv_objx.lv_ta;
public import src.lv_objx.lv_canvas;
public import src.lv_objx.lv_win;
public import src.lv_objx.lv_tabview;
public import src.lv_objx.lv_tileview;
public import src.lv_objx.lv_mbox;
public import src.lv_objx.lv_gauge;
public import src.lv_objx.lv_lmeter;
public import src.lv_objx.lv_sw;
public import src.lv_objx.lv_kb;
public import src.lv_objx.lv_arc;
public import src.lv_objx.lv_preload;
public import src.lv_objx.lv_calendar;
public import src.lv_objx.lv_spinbox;

public import src.lv_draw.lv_img_cache;

version (none) {}
}
}

 /* WAMR_GRAPHIC_LIBRARY_LVGL_COMPATIBLE_H */
