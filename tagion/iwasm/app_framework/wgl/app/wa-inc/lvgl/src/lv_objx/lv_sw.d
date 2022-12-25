module lv_sw;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_sw.h
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

static if (LV_USE_SW != 0) {

/*Testing of dependencies*/
static if (LV_USE_SLIDER == 0) {
static assert(0, "lv_sw: lv_slider is required. Enable it in lv_conf.h (LV_USE_SLIDER  1)");
}

public import ...lv_core.lv_obj;
public import lv_slider;

/*********************
 *      DEFINES
 *********************/
enum LV_SW_MAX_VALUE = 100;

/**********************
 *      TYPEDEFS
 **********************/
/*Data of switch*/
struct _Lv_sw_ext_t {
    lv_slider_ext_t slider; /*Ext. of ancestor*/
    /*New data for this type */
    const(lv_style_t)* style_knob_off; /**< Style of the knob when the switch is OFF*/
    const(lv_style_t)* style_knob_on;  /**< Style of the knob when the switch is ON (NULL to use the same as OFF)*/
    lv_coord_t start_x;
    ubyte changed;/*: 1 !!*/ /*Indicates the switch state explicitly changed by drag*/
    ubyte slided;/*: 1 !!*/
static if (LV_USE_ANIMATION) {
    ushort anim_time; /*switch animation time */
}
}alias lv_sw_ext_t = _Lv_sw_ext_t;

/**
 * Switch styles.
 */
enum {
    LV_SW_STYLE_BG, /**< Switch background. */
    LV_SW_STYLE_INDIC, /**< Switch fill area. */
    LV_SW_STYLE_KNOB_OFF, /**< Switch knob (when off). */
    LV_SW_STYLE_KNOB_ON, /**< Switch knob (when on). */
};
alias lv_sw_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a switch objects
 * @param par pointer to an object, it will be the parent of the new switch
 * @param copy pointer to a switch object, if not NULL then the new object will be copied from it
 * @return pointer to the created switch
 */
lv_obj_t* lv_sw_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Turn ON the switch
 * @param sw pointer to a switch object
 * @param anim LV_ANIM_ON: set the value with an animation; LV_ANIM_OFF: change the value immediately
 */
void lv_sw_on(lv_obj_t* sw, lv_anim_enable_t anim);

/**
 * Turn OFF the switch
 * @param sw pointer to a switch object
 * @param anim LV_ANIM_ON: set the value with an animation; LV_ANIM_OFF: change the value immediately
 */
void lv_sw_off(lv_obj_t* sw, lv_anim_enable_t anim);

/**
 * Toggle the position of the switch
 * @param sw pointer to a switch object
 * @param anim LV_ANIM_ON: set the value with an animation; LV_ANIM_OFF: change the value immediately
 * @return resulting state of the switch.
 */
bool lv_sw_toggle(lv_obj_t* sw, lv_anim_enable_t anim);

/**
 * Set a style of a switch
 * @param sw pointer to a switch object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_sw_set_style(lv_obj_t* sw, lv_sw_style_t type, const(lv_style_t)* style);

/**
 * Set the animation time of the switch
 * @param sw pointer to a  switch object
 * @param anim_time animation time
 * @return style pointer to a style
 */
void lv_sw_set_anim_time(lv_obj_t* sw, ushort anim_time);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the state of a switch
 * @param sw pointer to a switch object
 * @return false: OFF; true: ON
 */
pragma(inline, true) private bool lv_sw_get_state(const(lv_obj_t)* sw) {
    return lv_bar_get_value(sw) < LV_SW_MAX_VALUE / 2 ? false : true;
}

/**
 * Get a style of a switch
 * @param sw pointer to a  switch object
 * @param type which style should be get
 * @return style pointer to a style
 */
const(lv_style_t)* lv_sw_get_style(const(lv_obj_t)* sw, lv_sw_style_t type);

/**
 * Get the animation time of the switch
 * @param sw pointer to a  switch object
 * @return style pointer to a style
 */
ushort lv_sw_get_anim_time(const(lv_obj_t)* sw);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_SW*/

version (none) {}
} /* extern "C" */
}

 /*LV_SW_H*/
