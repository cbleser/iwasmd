module lv_draw_triangle;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_draw_triangle.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
public import lv_draw;

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
 *
 * @param points pointer to an array with 3 points
 * @param mask the triangle will be drawn only in this mask
 * @param style style for of the triangle
 * @param opa_scale scale down all opacities by the factor (0..255)
 */
void lv_draw_triangle(const(lv_point_t)* points, const(lv_area_t)* mask, const(lv_style_t)* style, lv_opa_t opa_scale);

/**
 * Draw a polygon from triangles. Only convex polygons are supported
 * @param points an array of points
 * @param point_cnt number of points
 * @param mask polygon will be drawn only in this mask
 * @param style style of the polygon
 * @param opa_scale scale down all opacities by the factor (0..255)
 */
void lv_draw_polygon(const(lv_point_t)* points, uint point_cnt, const(lv_area_t)* mask, const(lv_style_t)* style, lv_opa_t opa_scale);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_DRAW_TRIANGLE_H*/
