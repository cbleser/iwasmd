module lv_line;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_line.h
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

static if (LV_USE_LINE != 0) {

public import ...lv_core.lv_obj;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/*Data of line*/
struct _Lv_line_ext_t {
    /*Inherited from 'base_obj' so no inherited ext.*/ /*Ext. of ancestor*/
    const(lv_point_t)* point_array;                    /*Pointer to an array with the points of the line*/
    ushort point_num;                                /*Number of points in 'point_array' */
    ubyte auto_size;/*: 1 !!*/                             /*1: set obj. width to x max and obj. height to y max */
    ubyte y_inv;/*: 1 !!*/                                 /*1: y == 0 will be on the bottom*/
}alias lv_line_ext_t = _Lv_line_ext_t;

/*Styles*/
enum {
    LV_LINE_STYLE_MAIN,
};
alias lv_line_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a line objects
 * @param par pointer to an object, it will be the parent of the new line
 * @return pointer to the created line
 */
lv_obj_t* lv_line_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set an array of points. The line object will connect these points.
 * @param line pointer to a line object
 * @param point_a an array of points. Only the address is saved,
 * so the array can NOT be a local variable which will be destroyed
 * @param point_num number of points in 'point_a'
 */
void lv_line_set_points(lv_obj_t* line, const(lv_point_t)* point_a, ushort point_num);

/**
 * Enable (or disable) the auto-size option. The size of the object will fit to its points.
 * (set width to x max and height to y max)
 * @param line pointer to a line object
 * @param en true: auto size is enabled, false: auto size is disabled
 */
void lv_line_set_auto_size(lv_obj_t* line, bool en);

/**
 * Enable (or disable) the y coordinate inversion.
 * If enabled then y will be subtracted from the height of the object,
 * therefore the y=0 coordinate will be on the bottom.
 * @param line pointer to a line object
 * @param en true: enable the y inversion, false:disable the y inversion
 */
void lv_line_set_y_invert(lv_obj_t* line, bool en);

enum lv_line_set_y_inv =                                                                                              \
    lv_line_set_y_invert /*The name was inconsistent. In v.6.0 only `lv_line_set_y_invert`will                         \
                            work */;

/**
 * Set the style of a line
 * @param line pointer to a line object
 * @param type which style should be set (can be only `LV_LINE_STYLE_MAIN`)
 * @param style pointer to a style
 */
pragma(inline, true) private void lv_line_set_style(lv_obj_t* line, lv_line_style_t type, const(lv_style_t)* style) {
    cast(void)type; /*Unused*/
    lv_obj_set_style(line, style);
}

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the auto size attribute
 * @param line pointer to a line object
 * @return true: auto size is enabled, false: disabled
 */
bool lv_line_get_auto_size(const(lv_obj_t)* line);

/**
 * Get the y inversion attribute
 * @param line pointer to a line object
 * @return true: y inversion is enabled, false: disabled
 */
bool lv_line_get_y_invert(const(lv_obj_t)* line);

/**
 * Get the style of an line object
 * @param line pointer to an line object
 * @param type which style should be get (can be only `LV_LINE_STYLE_MAIN`)
 * @return pointer to the line's style
 */
pragma(inline, true) private const(lv_style_t)* lv_line_get_style(const(lv_obj_t)* line, lv_line_style_t type) {
    cast(void)type; /*Unused*/
    return lv_obj_get_style(line);
}

/**********************
 *      MACROS
 **********************/

} /*LV_USE_LINE*/

version (none) {}
} /* extern "C" */
}

 /*LV_LINE_H*/
