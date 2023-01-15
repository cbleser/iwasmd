module lv_circ;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_circ.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
public import core.stdc.stddef;
public import lv_area;

/*********************
 *      DEFINES
 *********************/
enum string LV_CIRC_OCT1_X(string p) = ` (p.x)`;
enum string LV_CIRC_OCT1_Y(string p) = ` (p.y)`;
enum string LV_CIRC_OCT2_X(string p) = ` (p.y)`;
enum string LV_CIRC_OCT2_Y(string p) = ` (p.x)`;
enum string LV_CIRC_OCT3_X(string p) = ` (-p.y)`;
enum string LV_CIRC_OCT3_Y(string p) = ` (p.x)`;
enum string LV_CIRC_OCT4_X(string p) = ` (-p.x)`;
enum string LV_CIRC_OCT4_Y(string p) = ` (p.y)`;
enum string LV_CIRC_OCT5_X(string p) = ` (-p.x)`;
enum string LV_CIRC_OCT5_Y(string p) = ` (-p.y)`;
enum string LV_CIRC_OCT6_X(string p) = ` (-p.y)`;
enum string LV_CIRC_OCT6_Y(string p) = ` (-p.x)`;
enum string LV_CIRC_OCT7_X(string p) = ` (p.y)`;
enum string LV_CIRC_OCT7_Y(string p) = ` (-p.x)`;
enum string LV_CIRC_OCT8_X(string p) = ` (p.x)`;
enum string LV_CIRC_OCT8_Y(string p) = ` (-p.y)`;

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Initialize the circle drawing
 * @param c pointer to a point. The coordinates will be calculated here
 * @param tmp point to a variable. It will store temporary data
 * @param radius radius of the circle
 */
void lv_circ_init(lv_point_t* c, lv_coord_t* tmp, lv_coord_t radius);

/**
 * Test the circle drawing is ready or not
 * @param c same as in circ_init
 * @return true if the circle is not ready yet
 */
bool lv_circ_cont(lv_point_t* c);

/**
 * Get the next point from the circle
 * @param c same as in circ_init. The next point stored here.
 * @param tmp same as in circ_init.
 */
void lv_circ_next(lv_point_t* c, lv_coord_t* tmp);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}


