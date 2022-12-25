module lv_lmeter;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_lmeter.h
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

static if (LV_USE_LMETER != 0) {

public import ...lv_core.lv_obj;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/
/*Data of line meter*/
struct _Lv_lmeter_ext_t {
    /*No inherited ext.*/ /*Ext. of ancestor*/
    /*New data for this type */
    ushort scale_angle; /*Angle of the scale in deg. (0..360)*/
    ubyte line_cnt;     /*Count of lines */
    short cur_value;
    short min_value;
    short max_value;
}alias lv_lmeter_ext_t = _Lv_lmeter_ext_t;

/*Styles*/
enum {
    LV_LMETER_STYLE_MAIN,
};
alias lv_lmeter_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a line meter objects
 * @param par pointer to an object, it will be the parent of the new line meter
 * @param copy pointer to a line meter object, if not NULL then the new object will be copied from
 * it
 * @return pointer to the created line meter
 */
lv_obj_t* lv_lmeter_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a new value on the line meter
 * @param lmeter pointer to a line meter object
 * @param value new value
 */
void lv_lmeter_set_value(lv_obj_t* lmeter, short value);

/**
 * Set minimum and the maximum values of a line meter
 * @param lmeter pointer to he line meter object
 * @param min minimum value
 * @param max maximum value
 */
void lv_lmeter_set_range(lv_obj_t* lmeter, short min, short max);

/**
 * Set the scale settings of a line meter
 * @param lmeter pointer to a line meter object
 * @param angle angle of the scale (0..360)
 * @param line_cnt number of lines
 */
void lv_lmeter_set_scale(lv_obj_t* lmeter, ushort angle, ubyte line_cnt);

/**
 * Set the styles of a line meter
 * @param lmeter pointer to a line meter object
 * @param type which style should be set (can be only `LV_LMETER_STYLE_MAIN`)
 * @param style set the style of the line meter
 */
pragma(inline, true) private void lv_lmeter_set_style(lv_obj_t* lmeter, lv_lmeter_style_t type, lv_style_t* style) {
    cast(void)type; /*Unused*/
    lv_obj_set_style(lmeter, style);
}

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the value of a line meter
 * @param lmeter pointer to a line meter object
 * @return the value of the line meter
 */
short lv_lmeter_get_value(const(lv_obj_t)* lmeter);

/**
 * Get the minimum value of a line meter
 * @param lmeter pointer to a line meter object
 * @return the minimum value of the line meter
 */
short lv_lmeter_get_min_value(const(lv_obj_t)* lmeter);

/**
 * Get the maximum value of a line meter
 * @param lmeter pointer to a line meter object
 * @return the maximum value of the line meter
 */
short lv_lmeter_get_max_value(const(lv_obj_t)* lmeter);

/**
 * Get the scale number of a line meter
 * @param lmeter pointer to a line meter object
 * @return number of the scale units
 */
ubyte lv_lmeter_get_line_count(const(lv_obj_t)* lmeter);

/**
 * Get the scale angle of a line meter
 * @param lmeter pointer to a line meter object
 * @return angle of the scale
 */
ushort lv_lmeter_get_scale_angle(const(lv_obj_t)* lmeter);

/**
 * Get the style of a line meter
 * @param lmeter pointer to a line meter object
 * @param type which style should be get (can be only `LV_LMETER_STYLE_MAIN`)
 * @return pointer to the line meter's style
 */
pragma(inline, true) private const(lv_style_t)* lv_lmeter_get_style(const(lv_obj_t)* lmeter, lv_lmeter_style_t type) {
    cast(void)type; /*Unused*/
    return lv_obj_get_style(lmeter);
}

/**********************
 *      MACROS
 **********************/

} /*LV_USE_LMETER*/

version (none) {}
} /* extern "C" */
}

 /*LV_LMETER_H*/
