module lv_draw_line;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_draw_line.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/

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
 * Draw a line
 * @param point1 first point of the line
 * @param point2 second point of the line
 * @param mask the line will be drawn only on this area
 * @param style pointer to a line's style
 * @param opa_scale scale down all opacities by the factor
 */
void lv_draw_line(const(lv_point_t)* point1, const(lv_point_t)* point2, const(lv_area_t)* mask, const(lv_style_t)* style, lv_opa_t opa_scale);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_DRAW_LINE_H*/
