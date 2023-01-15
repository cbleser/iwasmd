module lv_bar;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_bar.h
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

static if (LV_USE_BAR != 0) {

public import ...lv_core.lv_obj;
public import ...lv_misc.lv_anim;
public import lv_cont;
public import lv_btn;
public import lv_label;

/*********************
 *      DEFINES
 *********************/

/** Bar animation start value. (Not the real value of the Bar just indicates process animation)*/
enum LV_BAR_ANIM_STATE_START = 0;

/** Bar animation end value.  (Not the real value of the Bar just indicates process animation)*/
enum LV_BAR_ANIM_STATE_END = 256;

/** Mark no animation is in progress */
enum LV_BAR_ANIM_STATE_INV = -1;

/** log2(LV_BAR_ANIM_STATE_END) used to normalize data*/
enum LV_BAR_ANIM_STATE_NORM = 8;

/**********************
 *      TYPEDEFS
 **********************/

/** Data of bar*/
struct _Lv_bar_ext_t {
    /*No inherited ext, derived from the base object */

    /*New data for this type */
    short cur_value; /*Current value of the bar*/
    short min_value; /*Minimum value of the bar*/
    short max_value; /*Maximum value of the bar*/
static if (LV_USE_ANIMATION) {
    lv_anim_value_t anim_start;
    lv_anim_value_t anim_end;
    lv_anim_value_t anim_state;
    lv_anim_value_t anim_time;
}
    ubyte sym;/*: 1 !!*/                /*Symmetric: means the center is around zero value*/
    const(lv_style_t)* style_indic; /*Style of the indicator*/
}alias lv_bar_ext_t = _Lv_bar_ext_t;

/** Bar styles. */
enum {
    LV_BAR_STYLE_BG, /** Bar background style. */
    LV_BAR_STYLE_INDIC, /** Bar fill area style. */
};
alias lv_bar_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a bar objects
 * @param par pointer to an object, it will be the parent of the new bar
 * @param copy pointer to a bar object, if not NULL then the new object will be copied from it
 * @return pointer to the created bar
 */
lv_obj_t* lv_bar_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a new value on the bar
 * @param bar pointer to a bar object
 * @param value new value
 * @param anim LV_ANIM_ON: set the value with an animation; LV_ANIM_OFF: change the value immediately
 */
void lv_bar_set_value(lv_obj_t* bar, short value, lv_anim_enable_t anim);

/**
 * Set minimum and the maximum values of a bar
 * @param bar pointer to the bar object
 * @param min minimum value
 * @param max maximum value
 */
void lv_bar_set_range(lv_obj_t* bar, short min, short max);

/**
 * Make the bar symmetric to zero. The indicator will grow from zero instead of the minimum
 * position.
 * @param bar pointer to a bar object
 * @param en true: enable disable symmetric behavior; false: disable
 */
void lv_bar_set_sym(lv_obj_t* bar, bool en);

/**
 * Set the animation time of the bar
 * @param bar pointer to a bar object
 * @param anim_time the animation time in milliseconds.
 */
void lv_bar_set_anim_time(lv_obj_t* bar, ushort anim_time);

/**
 * Set a style of a bar
 * @param bar pointer to a bar object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_bar_set_style(lv_obj_t* bar, lv_bar_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the value of a bar
 * @param bar pointer to a bar object
 * @return the value of the bar
 */
short lv_bar_get_value(const(lv_obj_t)* bar);

/**
 * Get the minimum value of a bar
 * @param bar pointer to a bar object
 * @return the minimum value of the bar
 */
short lv_bar_get_min_value(const(lv_obj_t)* bar);

/**
 * Get the maximum value of a bar
 * @param bar pointer to a bar object
 * @return the maximum value of the bar
 */
short lv_bar_get_max_value(const(lv_obj_t)* bar);

/**
 * Get whether the bar is symmetric or not.
 * @param bar pointer to a bar object
 * @return true: symmetric is enabled; false: disable
 */
bool lv_bar_get_sym(lv_obj_t* bar);

/**
 * Get the animation time of the bar
 * @param bar pointer to a bar object
 * @return the animation time in milliseconds.
 */
ushort lv_bar_get_anim_time(lv_obj_t* bar);

/**
 * Get a style of a bar
 * @param bar pointer to a bar object
 * @param type which style should be get
 * @return style pointer to a style
 */
const(lv_style_t)* lv_bar_get_style(const(lv_obj_t)* bar, lv_bar_style_t type);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_BAR*/

version (none) {}
} /* extern "C" */
}

 /*LV_BAR_H*/
