module lv_task;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_task.c
 * An 'lv_task'  is a void (*fp) (void* param) type function which will be called periodically.
 * A priority (5 levels + disable) can be assigned to lv_tasks.
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

/*********************
 *      DEFINES
 *********************/
 

/**********************
 *      TYPEDEFS
 **********************/

struct _lv_task_t;;

/**
 * Tasks execute this type type of functions.
 */
alias lv_task_cb_t = void function(_lv_task_t*);

/**
 * Possible priorities for lv_tasks
 */
enum {
    LV_TASK_PRIO_OFF = 0,
    LV_TASK_PRIO_LOWEST,
    LV_TASK_PRIO_LOW,
    LV_TASK_PRIO_MID,
    LV_TASK_PRIO_HIGH,
    LV_TASK_PRIO_HIGHEST,
    _LV_TASK_PRIO_NUM,
};
alias lv_task_prio_t = ubyte;

/**
 * Descriptor of a lv_task
 */
struct _lv_task_t {
    uint period; /**< How often the task should run */
    uint last_run; /**< Last time the task ran */
    lv_task_cb_t task_cb; /**< Task function */

    void* user_data; /**< Custom user data */

    ubyte prio;/*: 3 !!*/ /**< Task priority */
    ubyte once;/*: 1 !!*/ /**< 1: one shot task */
}alias lv_task_t = _lv_task_t;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Init the lv_task module
 */
void lv_task_core_init();

//! @cond Doxygen_Suppress

/**
 * Call it  periodically to handle lv_tasks.
 */
LV_ATTRIBUTE_TASK_HANDLER lv_task_handler();

//! @endcond

/**
 * Create an "empty" task. It needs to initialzed with at least
 * `lv_task_set_cb` and `lv_task_set_period`
 * @return pointer to the craeted task
 */
lv_task_t* lv_task_create_basic();

/**
 * Create a new lv_task
 * @param task_xcb a callback which is the task itself. It will be called periodically.
 *                 (the 'x' in the argument name indicates that its not a fully generic function because it not follows
 *                  the `func_name(object, callback, ...)` convention)
 * @param period call period in ms unit
 * @param prio priority of the task (LV_TASK_PRIO_OFF means the task is stopped)
 * @param user_data custom parameter
 * @return pointer to the new task
 */
lv_task_t* lv_task_create(lv_task_cb_t task_xcb, uint period, lv_task_prio_t prio, void* user_data);

/**
 * Delete a lv_task
 * @param task pointer to task_cb created by task
 */
void lv_task_del(lv_task_t* task);

/**
 * Set the callback the task (the function to call periodically)
 * @param task pointer to a task
 * @param task_cb the function to call periodically
 */
void lv_task_set_cb(lv_task_t* task, lv_task_cb_t task_cb);

/**
 * Set new priority for a lv_task
 * @param task pointer to a lv_task
 * @param prio the new priority
 */
void lv_task_set_prio(lv_task_t* task, lv_task_prio_t prio);

/**
 * Set new period for a lv_task
 * @param task pointer to a lv_task
 * @param period the new period
 */
void lv_task_set_period(lv_task_t* task, uint period);

/**
 * Make a lv_task ready. It will not wait its period.
 * @param task pointer to a lv_task.
 */
void lv_task_ready(lv_task_t* task);

/**
 * Delete the lv_task after one call
 * @param task pointer to a lv_task.
 */
void lv_task_once(lv_task_t* task);

/**
 * Reset a lv_task.
 * It will be called the previously set period milliseconds later.
 * @param task pointer to a lv_task.
 */
void lv_task_reset(lv_task_t* task);

/**
 * Enable or disable the whole  lv_task handling
 * @param en: true: lv_task handling is running, false: lv_task handling is suspended
 */
void lv_task_enable(bool en);

/**
 * Get idle percentage
 * @return the lv_task idle in percentage
 */
ubyte lv_task_get_idle();

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}


