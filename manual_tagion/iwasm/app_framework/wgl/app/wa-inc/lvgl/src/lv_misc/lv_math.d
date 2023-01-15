module lv_math;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file math_base.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
public import core.stdc.stdint;

/*********************
 *      DEFINES
 *********************/
enum string LV_MATH_MIN(string a, string b) = ` ((a) < (b) ? (a) : (b))`;
enum string LV_MATH_MAX(string a, string b) = ` ((a) > (b) ? (a) : (b))`;
enum string LV_MATH_ABS(string x) = ` ((x) > 0 ? (x) : (-(x)))`;

enum LV_TRIGO_SIN_MAX = 32767;
enum LV_TRIGO_SHIFT = 15 /**<  >> LV_TRIGO_SHIFT to normalize*/;

enum LV_BEZIER_VAL_MAX = 1024 /**< Max time in Bezier functions (not [0..1] to use integers) */;
enum LV_BEZIER_VAL_SHIFT = 10 /**< log2(LV_BEZIER_VAL_MAX): used to normalize up scaled values*/;

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Return with sinus of an angle
 * @param angle
 * @return sinus of 'angle'. sin(-90) = -32767, sin(90) = 32767
 */
short lv_trigo_sin(short angle);

/**
 * Calculate a value of a Cubic Bezier function.
 * @param t time in range of [0..LV_BEZIER_VAL_MAX]
 * @param u0 start values in range of [0..LV_BEZIER_VAL_MAX]
 * @param u1 control value 1 values in range of [0..LV_BEZIER_VAL_MAX]
 * @param u2 control value 2 in range of [0..LV_BEZIER_VAL_MAX]
 * @param u3 end values in range of [0..LV_BEZIER_VAL_MAX]
 * @return the value calculated from the given parameters in range of [0..LV_BEZIER_VAL_MAX]
 */
int lv_bezier3(uint t, int u0, int u1, int u2, int u3);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}


