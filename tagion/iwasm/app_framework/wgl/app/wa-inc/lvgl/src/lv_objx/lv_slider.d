module lv_slider;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_slider.h
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

static if (LV_USE_SLIDER != 0) {

/*Testing of dependencies*/
static if (LV_USE_BAR == 0) {
static assert(0, "lv_slider: lv_bar is required. Enable it in lv_conf.h (LV_USE_BAR  1) ");
}

public import ...lv_core.lv_obj;
public import lv_bar;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/
/*Data of slider*/
struct _Lv_slider_ext_t {
    lv_bar_ext_t bar; /*Ext. of ancestor*/
    /*New data for this type */
    const(lv_style_t)* style_knob; /*Style of the knob*/
    short drag_value;            /*Store a temporal value during press until release (Handled by the library)*/
    ubyte knob_in;/*: 1 !!*/           /*1: Draw the knob inside the bar*/
}alias lv_slider_ext_t = _Lv_slider_ext_t;

/** Built-in styles of slider*/
enum {
    LV_SLIDER_STYLE_BG, /** Slider background style. */
    LV_SLIDER_STYLE_INDIC, /** Slider indicator (filled area) style. */
    LV_SLIDER_STYLE_KNOB, /** Slider knob style. */
};
alias lv_slider_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a slider objects
 * @param par pointer to an object, it will be the parent of the new slider
 * @param copy pointer to a slider object, if not NULL then the new object will be copied from it
 * @return pointer to the created slider
 */
lv_obj_t* lv_slider_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a new value on the slider
 * @param slider pointer to a slider object
 * @param value new value
 * @param anim LV_ANIM_ON: set the value with an animation; LV_ANIM_OFF: change the value immediately
 */
pragma(inline, true) private void lv_slider_set_value(lv_obj_t* slider, short value, lv_anim_enable_t anim) {
    lv_bar_set_value(slider, value, anim);
}

/**
 * Set minimum and the maximum values of a bar
 * @param slider pointer to the slider object
 * @param min minimum value
 * @param max maximum value
 */
pragma(inline, true) private void lv_slider_set_range(lv_obj_t* slider, short min, short max) {
    lv_bar_set_range(slider, min, max);
}

/**
 * Set the animation time of the slider
 * @param slider pointer to a bar object
 * @param anim_time the animation time in milliseconds.
 */
pragma(inline, true) private void lv_slider_set_anim_time(lv_obj_t* slider, ushort anim_time) {
    lv_bar_set_anim_time(slider, anim_time);
}

/**
 * Set the 'knob in' attribute of a slider
 * @param slider pointer to slider object
 * @param in true: the knob is drawn always in the slider;
 *           false: the knob can be out on the edges
 */
void lv_slider_set_knob_in(lv_obj_t* slider, bool in_);

/**
 * Set a style of a slider
 * @param slider pointer to a slider object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_slider_set_style(lv_obj_t* slider, lv_slider_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the value of a slider
 * @param slider pointer to a slider object
 * @return the value of the slider
 */
short lv_slider_get_value(const(lv_obj_t)* slider);

/**
 * Get the minimum value of a slider
 * @param slider pointer to a slider object
 * @return the minimum value of the slider
 */
pragma(inline, true) private short lv_slider_get_min_value(const(lv_obj_t)* slider) {
    return lv_bar_get_min_value(slider);
}

/**
 * Get the maximum value of a slider
 * @param slider pointer to a slider object
 * @return the maximum value of the slider
 */
pragma(inline, true) private short lv_slider_get_max_value(const(lv_obj_t)* slider) {
    return lv_bar_get_max_value(slider);
}

/**
 * Give the slider is being dragged or not
 * @param slider pointer to a slider object
 * @return true: drag in progress false: not dragged
 */
bool lv_slider_is_dragged(const(lv_obj_t)* slider);

/**
 * Get the 'knob in' attribute of a slider
 * @param slider pointer to slider object
 * @return true: the knob is drawn always in the slider;
 *         false: the knob can be out on the edges
 */
bool lv_slider_get_knob_in(const(lv_obj_t)* slider);

/**
 * Get a style of a slider
 * @param slider pointer to a slider object
 * @param type which style should be get
 * @return style pointer to a style
 */
const(lv_style_t)* lv_slider_get_style(const(lv_obj_t)* slider, lv_slider_style_t type);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_SLIDER*/

version (none) {}
} /* extern "C" */
}

 /*LV_SLIDER_H*/
