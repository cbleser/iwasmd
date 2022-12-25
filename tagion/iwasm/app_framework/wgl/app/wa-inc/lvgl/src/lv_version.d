module lv_version;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_version.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
/*Current version of LittlevGL*/
enum LVGL_VERSION_MAJOR =   6;
enum LVGL_VERSION_MINOR =   0;
enum LVGL_VERSION_PATCH =   0;
enum LVGL_VERSION_INFO =    "";


/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**********************
 *      MACROS
 **********************/
/** Gives 1 if the x.y.z version is supported in the current version
 * Usage:
 *
 * - Require v6
 * #if LV_VERSION_CHECK(6,0,0)
 *   new_func_in_v6();
 * #endif
 *
 *
 * - Require at least v5.3
 * #if LV_VERSION_CHECK(5,3,0)
 *   new_feature_from_v5_3();
 * #endif
 *
 *
 * - Require v5.3.2 bugfixes
 * #if LV_VERSION_CHECK(5,3,2)
 *   bugfix_in_v5_3_2();
 * #endif
 *
 * */
enum string LV_VERSION_CHECK(string x,string y,string z) = ` (x == LVGL_VERSION_MAJOR && (y < LVGL_VERSION_MINOR || (y == LVGL_VERSION_MINOR && z <= LVGL_VERSION_PATCH)))`;


version (none) {}
} /* extern "C" */
}

 /*LV_VERSION_H*/
