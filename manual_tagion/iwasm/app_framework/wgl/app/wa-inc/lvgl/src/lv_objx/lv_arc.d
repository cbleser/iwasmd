module lv_arc;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_arc.h
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

static if (LV_USE_ARC != 0) {

public import ...lv_core.lv_obj;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/
/*Data of arc*/
struct _Lv_arc_ext_t {
    /*New data for this type */
    lv_coord_t angle_start;
    lv_coord_t angle_end;
}alias lv_arc_ext_t = _Lv_arc_ext_t;

/*Styles*/
enum {
    LV_ARC_STYLE_MAIN,
};
alias lv_arc_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a arc objects
 * @param par pointer to an object, it will be the parent of the new arc
 * @param copy pointer to a arc object, if not NULL then the new object will be copied from it
 * @return pointer to the created arc
 */
lv_obj_t* lv_arc_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*======================
 * Add/remove functions
 *=====================*/

/*=====================
 * Setter functions
 *====================*/

/**
 * Set the start and end angles of an arc. 0 deg: bottom, 90 deg: right etc.
 * @param arc pointer to an arc object
 * @param start the start angle [0..360]
 * @param end the end angle [0..360]
 */
void lv_arc_set_angles(lv_obj_t* arc, ushort start, ushort end);

/**
 * Set a style of a arc.
 * @param arc pointer to arc object
 * @param type which style should be set
 * @param style pointer to a style
 *  */
void lv_arc_set_style(lv_obj_t* arc, lv_arc_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the start angle of an arc.
 * @param arc pointer to an arc object
 * @return the start angle [0..360]
 */
ushort lv_arc_get_angle_start(lv_obj_t* arc);

/**
 * Get the end angle of an arc.
 * @param arc pointer to an arc object
 * @return the end angle [0..360]
 */
ushort lv_arc_get_angle_end(lv_obj_t* arc);

/**
 * Get style of a arc.
 * @param arc pointer to arc object
 * @param type which style should be get
 * @return style pointer to the style
 *  */
const(lv_style_t)* lv_arc_get_style(const(lv_obj_t)* arc, lv_arc_style_t type);

/*=====================
 * Other functions
 *====================*/

/**********************
 *      MACROS
 **********************/

} /*LV_USE_ARC*/

version (none) {}
} /* extern "C" */
}

 /*LV_ARC_H*/
