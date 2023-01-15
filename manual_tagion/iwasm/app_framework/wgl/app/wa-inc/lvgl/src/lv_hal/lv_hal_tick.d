module lv_hal_tick;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_hal_tick.h
 * Provide access to the system tick with 1 millisecond resolution
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

/*********************
 *      DEFINES
 *********************/
 


/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

//! @cond Doxygen_Suppress

/**
 * You have to call this function periodically
 * @param tick_period the call period of this function in milliseconds
 */
LV_ATTRIBUTE_TICK_INC lv_tick_inc(uint tick_period);

//! @endcond

/**
 * Get the elapsed milliseconds since start up
 * @return the elapsed milliseconds
 */
uint lv_tick_get();

/**
 * Get the elapsed milliseconds since a previous time stamp
 * @param prev_tick a previous time stamp (return value of systick_get() )
 * @return the elapsed milliseconds since 'prev_tick'
 */
uint lv_tick_elaps(uint prev_tick);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_HAL_TICK_H*/
