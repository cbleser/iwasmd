module lv_disp;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_disp.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
public import ...lv_hal.lv_hal;
public import lv_obj;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Return with a pointer to the active screen
 * @param disp pointer to display which active screen should be get. (NULL to use the default
 * screen)
 * @return pointer to the active screen object (loaded by 'lv_scr_load()')
 */
lv_obj_t* lv_disp_get_scr_act(lv_disp_t* disp);

/**
 * Make a screen active
 * @param scr pointer to a screen
 */
void lv_disp_load_scr(lv_obj_t* scr);

/**
 * Return with the top layer. (Same on every screen and it is above the normal screen layer)
 * @param disp pointer to display which top layer should be get. (NULL to use the default screen)
 * @return pointer to the top layer object  (transparent screen sized lv_obj)
 */
lv_obj_t* lv_disp_get_layer_top(lv_disp_t* disp);

/**
 * Return with the sys. layer. (Same on every screen and it is above the normal screen and the top
 * layer)
 * @param disp pointer to display which sys. layer  should be get. (NULL to use the default screen)
 * @return pointer to the sys layer object  (transparent screen sized lv_obj)
 */
lv_obj_t* lv_disp_get_layer_sys(lv_disp_t* disp);

/**
 * Assign a screen to a display.
 * @param disp pointer to a display where to assign the screen
 * @param scr pointer to a screen object to assign
 */
void lv_disp_assign_screen(lv_disp_t* disp, lv_obj_t* scr);

/**
 * Get a pointer to the screen refresher task to
 * modify its parameters with `lv_task_...` functions.
 * @param disp pointer to a display
 * @return pointer to the display refresher task. (NULL on error)
 */
lv_task_t* lv_disp_get_refr_task(lv_disp_t* disp);

/**
 * Get elapsed time since last user activity on a display (e.g. click)
 * @param disp pointer to an display (NULL to get the overall smallest inactivity)
 * @return elapsed ticks (milliseconds) since the last activity
 */
uint lv_disp_get_inactive_time(const(lv_disp_t)* disp);

/**
 * Manually trigger an activity on a display
 * @param disp pointer to an display (NULL to use the default display)
 */
void lv_disp_trig_activity(lv_disp_t* disp);

/*------------------------------------------------
 * To improve backward compatibility
 * Recommended only if you have one display
 *------------------------------------------------*/

/**
 * Get the active screen of the default display
 * @return pointer to the active screen
 */
pragma(inline, true) private lv_obj_t* lv_scr_act() {
    return lv_disp_get_scr_act(lv_disp_get_default());
}

/**
 * Get the top layer  of the default display
 * @return pointer to the top layer
 */
pragma(inline, true) private lv_obj_t* lv_layer_top() {
    return lv_disp_get_layer_top(lv_disp_get_default());
}

/**
 * Get the active screen of the deafult display
 * @return  pointer to the sys layer
 */
pragma(inline, true) private lv_obj_t* lv_layer_sys() {
    return lv_disp_get_layer_sys(lv_disp_get_default());
}

pragma(inline, true) private void lv_scr_load(lv_obj_t* scr) {
    lv_disp_load_scr(scr);
}

/**********************
 *      MACROS
 **********************/

/*------------------------------------------------
 * To improve backward compatibility
 * Recommended only if you have one display
 *------------------------------------------------*/

version (LV_HOR_RES) {} else {
/**
 * The horizontal resolution of the currently active display.
 */
enum LV_HOR_RES = lv_disp_get_hor_res(lv_disp_get_default());
}

version (LV_VER_RES) {} else {
/**
 * The vertical resolution of the currently active display.
 */
enum LV_VER_RES = lv_disp_get_ver_res(lv_disp_get_default());
}

version (none) {}
} /* extern "C" */
}

 /*LV_TEMPL_H*/
