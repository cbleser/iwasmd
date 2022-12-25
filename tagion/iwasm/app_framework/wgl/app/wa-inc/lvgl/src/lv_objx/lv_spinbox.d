module lv_spinbox;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_spinbox.h
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

static if (LV_USE_SPINBOX != 0) {

/*Testing of dependencies*/
static if (LV_USE_TA == 0) {
static assert(0, "lv_spinbox: lv_ta is required. Enable it in lv_conf.h (LV_USE_TA  1) ");
}

public import ...lv_core.lv_obj;
public import ...lv_objx.lv_ta;

/*********************
 *      DEFINES
 *********************/
enum LV_SPINBOX_MAX_DIGIT_COUNT = 16;

/**********************
 *      TYPEDEFS
 **********************/

/*Data of spinbox*/
struct _Lv_spinbox_ext_t {
    lv_ta_ext_t ta; /*Ext. of ancestor*/
    /*New data for this type */
    int value;
    int range_max;
    int range_min;
    int step;
    ushort digit_count;/*: 4 !!*/
    ushort dec_point_pos;/*: 4 !!*/ /*if 0, there is no separator and the number is an integer*/
    ushort digit_padding_left;/*: 4 !!*/
}alias lv_spinbox_ext_t = _Lv_spinbox_ext_t;

/*Styles*/
enum {
    LV_SPINBOX_STYLE_BG,
    LV_SPINBOX_STYLE_SB,
    LV_SPINBOX_STYLE_CURSOR,
};
alias lv_spinbox_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a spinbox objects
 * @param par pointer to an object, it will be the parent of the new spinbox
 * @param copy pointer to a spinbox object, if not NULL then the new object will be copied from it
 * @return pointer to the created spinbox
 */
lv_obj_t* lv_spinbox_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a style of a spinbox.
 * @param templ pointer to template object
 * @param type which style should be set
 * @param style pointer to a style
 */
pragma(inline, true) private void lv_spinbox_set_style(lv_obj_t* spinbox, lv_spinbox_style_t type, lv_style_t* style) {
    lv_ta_set_style(spinbox, type, style);
}

/**
 * Set spinbox value
 * @param spinbox pointer to spinbox
 * @param i value to be set
 */
void lv_spinbox_set_value(lv_obj_t* spinbox, int i);

/**
 * Set spinbox digit format (digit count and decimal format)
 * @param spinbox pointer to spinbox
 * @param digit_count number of digit excluding the decimal separator and the sign
 * @param separator_position number of digit before the decimal point. If 0, decimal point is not
 * shown
 */
void lv_spinbox_set_digit_format(lv_obj_t* spinbox, ubyte digit_count, ubyte separator_position);

/**
 * Set spinbox step
 * @param spinbox pointer to spinbox
 * @param step steps on increment/decrement
 */
void lv_spinbox_set_step(lv_obj_t* spinbox, uint step);

/**
 * Set spinbox value range
 * @param spinbox pointer to spinbox
 * @param range_min maximum value, inclusive
 * @param range_max minimum value, inclusive
 */
void lv_spinbox_set_range(lv_obj_t* spinbox, int range_min, int range_max);

/**
 * Set spinbox left padding in digits count (added between sign and first digit)
 * @param spinbox pointer to spinbox
 * @param cb Callback function called on value change event
 */
void lv_spinbox_set_padding_left(lv_obj_t* spinbox, ubyte padding);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get style of a spinbox.
 * @param templ pointer to template object
 * @param type which style should be get
 * @return style pointer to the style
 */
pragma(inline, true) private const(lv_style_t)* lv_spinbox_get_style(lv_obj_t* spinbox, lv_spinbox_style_t type) {
    return lv_ta_get_style(spinbox, type);
}

/**
 * Get the spinbox numeral value (user has to convert to float according to its digit format)
 * @param spinbox pointer to spinbox
 * @return value integer value of the spinbox
 */
int lv_spinbox_get_value(lv_obj_t* spinbox);

/*=====================
 * Other functions
 *====================*/

/**
 * Select next lower digit for edition by dividing the step by 10
 * @param spinbox pointer to spinbox
 */
void lv_spinbox_step_next(lv_obj_t* spinbox);

/**
 * Select next higher digit for edition by multiplying the step by 10
 * @param spinbox pointer to spinbox
 */
void lv_spinbox_step_prev(lv_obj_t* spinbox);

/**
 * Increment spinbox value by one step
 * @param spinbox pointer to spinbox
 */
void lv_spinbox_increment(lv_obj_t* spinbox);

/**
 * Decrement spinbox value by one step
 * @param spinbox pointer to spinbox
 */
void lv_spinbox_decrement(lv_obj_t* spinbox);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_SPINBOX*/

version (none) {}
} /* extern "C" */
}

 /*LV_SPINBOX_H*/
