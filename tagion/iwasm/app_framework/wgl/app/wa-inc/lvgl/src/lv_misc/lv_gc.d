module lv_gc;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_gc.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/

version (LV_CONF_INCLUDE_SIMPLE) {
public import lv_conf;
} else {
public import .........lv_conf;
}

public import core.stdc.stdint;
public import stdbool;
public import lv_mem;
public import lv_ll;
public import ...lv_draw.lv_img_cache;

/*********************
 *      DEFINES
 *********************/

enum string LV_GC_ROOTS(string prefix) = `                                                                                            \
    prefix lv_ll_t _lv_task_ll;  /*Linked list to store the lv_tasks*/                                                 \
    prefix lv_ll_t _lv_disp_ll;  /*Linked list of screens*/                                                            \
    prefix lv_ll_t _lv_indev_ll; /*Linked list of screens*/                                                            \
    prefix lv_ll_t _lv_drv_ll;                                                                                         \
    prefix lv_ll_t _lv_file_ll;                                                                                        \
    prefix lv_ll_t _lv_anim_ll;                                                                                        \
    prefix lv_ll_t _lv_group_ll;                                                                                       \
    prefix lv_ll_t _lv_img_defoder_ll;                                                                                 \
    prefix lv_img_cache_entry_t * _lv_img_cache_array;                                                                 \
    prefix void * _lv_task_act;                                                                                        \
    prefix void * _lv_draw_buf; `;

version = LV_NO_PREFIX;
enum LV_ROOTS = LV_GC_ROOTS(LV_NO_PREFIX);

static if (LV_ENABLE_GC == 1) {
static if (LV_MEM_CUSTOM != 1) {
static assert(0, "GC requires CUSTOM_MEM");
} /* LV_MEM_CUSTOM */
} else {  /* LV_ENABLE_GC */
enum string LV_GC_ROOT(string x) = ` x`;
LV_GC_ROOTS(extern)
} /* LV_ENABLE_GC */

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_GC_H*/
