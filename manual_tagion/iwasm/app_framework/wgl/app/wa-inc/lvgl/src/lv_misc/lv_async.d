module lv_async;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_async.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/

public import lv_task;
public import lv_types;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**
 * Type for async callback.
 */
alias lv_async_cb_t = void function(void*);

struct _lv_async_info_t {
    lv_async_cb_t cb;
    void* user_data;
}alias lv_async_info_t = _lv_async_info_t;

struct _lv_obj_t;;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Call an asynchronous function the next time lv_task_handler() is run. This function is likely to return
 * **before** the call actually happens!
 * @param task_xcb a callback which is the task itself.
 *                 (the 'x' in the argument name indicates that its not a fully generic function because it not follows
 *                  the `func_name(object, callback, ...)` convention)
 * @param user_data custom parameter
 */
lv_res_t lv_async_call(lv_async_cb_t async_xcb, void* user_data);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_TEMPL_H*/
