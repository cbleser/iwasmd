module lv_imgbtn;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_imgbtn.h
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

static if (LV_USE_IMGBTN != 0) {

/*Testing of dependencies*/
static if (LV_USE_BTN == 0) {
static assert(0, "lv_imgbtn: lv_btn is required. Enable it in lv_conf.h (LV_USE_BTN  1) ");
}

public import ...lv_core.lv_obj;
public import lv_btn;
public import ...lv_draw.lv_draw_img;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/
/*Data of image button*/
struct _Lv_imgbtn_ext_t {
    lv_btn_ext_t btn; /*Ext. of ancestor*/
    /*New data for this type */
static if (LV_IMGBTN_TILED == 0) {
    const(void)*[_LV_BTN_STATE_NUM] img_src; /*Store images to each state*/
} else {
    const(void)*[_LV_BTN_STATE_NUM] img_src_left;  /*Store left side images to each state*/
    const(void)*[_LV_BTN_STATE_NUM] img_src_mid;   /*Store center images to each state*/
    const(void)*[_LV_BTN_STATE_NUM] img_src_right; /*Store right side images to each state*/
}
    lv_img_cf_t act_cf; /*Color format of the currently active image*/
}alias lv_imgbtn_ext_t = _Lv_imgbtn_ext_t;

/*Styles*/
enum {
    LV_IMGBTN_STYLE_REL, /**< Same meaning as ordinary button styles. */
    LV_IMGBTN_STYLE_PR,
    LV_IMGBTN_STYLE_TGL_REL,
    LV_IMGBTN_STYLE_TGL_PR,
    LV_IMGBTN_STYLE_INA,
};
alias lv_imgbtn_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a image button objects
 * @param par pointer to an object, it will be the parent of the new image button
 * @param copy pointer to a image button object, if not NULL then the new object will be copied from
 * it
 * @return pointer to the created image button
 */
lv_obj_t* lv_imgbtn_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*======================
 * Add/remove functions
 *=====================*/

/*=====================
 * Setter functions
 *====================*/

static if (LV_IMGBTN_TILED == 0) {
/**
 * Set images for a state of the image button
 * @param imgbtn pointer to an image button object
 * @param state for which state set the new image (from `lv_btn_state_t`) `
 * @param src pointer to an image source (a C array or path to a file)
 */
void lv_imgbtn_set_src(lv_obj_t* imgbtn, lv_btn_state_t state, const(void)* src);
} else {
/**
 * Set images for a state of the image button
 * @param imgbtn pointer to an image button object
 * @param state for which state set the new image (from `lv_btn_state_t`) `
 * @param src_left pointer to an image source for the left side of the button (a C array or path to
 * a file)
 * @param src_mid pointer to an image source for the middle of the button (ideally 1px wide) (a C
 * array or path to a file)
 * @param src_right pointer to an image source for the right side of the button (a C array or path
 * to a file)
 */
void lv_imgbtn_set_src(lv_obj_t* imgbtn, lv_btn_state_t state, const(void)* src_left, const(void)* src_mid, const(void)* src_right);

}

/**
 * Enable the toggled states. On release the button will change from/to toggled state.
 * @param imgbtn pointer to an image button object
 * @param tgl true: enable toggled states, false: disable
 */
pragma(inline, true) private void lv_imgbtn_set_toggle(lv_obj_t* imgbtn, bool tgl) {
    lv_btn_set_toggle(imgbtn, tgl);
}

/**
 * Set the state of the image button
 * @param imgbtn pointer to an image button object
 * @param state the new state of the button (from lv_btn_state_t enum)
 */
pragma(inline, true) private void lv_imgbtn_set_state(lv_obj_t* imgbtn, lv_btn_state_t state) {
    lv_btn_set_state(imgbtn, state);
}

/**
 * Toggle the state of the image button (ON->OFF, OFF->ON)
 * @param imgbtn pointer to a image button object
 */
pragma(inline, true) private void lv_imgbtn_toggle(lv_obj_t* imgbtn) {
    lv_btn_toggle(imgbtn);
}

/**
 * Set a style of a image button.
 * @param imgbtn pointer to image button object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_imgbtn_set_style(lv_obj_t* imgbtn, lv_imgbtn_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

static if (LV_IMGBTN_TILED == 0) {
/**
 * Get the images in a  given state
 * @param imgbtn pointer to an image button object
 * @param state the state where to get the image (from `lv_btn_state_t`) `
 * @return pointer to an image source (a C array or path to a file)
 */
const(void)* lv_imgbtn_get_src(lv_obj_t* imgbtn, lv_btn_state_t state);

} else {

/**
 * Get the left image in a given state
 * @param imgbtn pointer to an image button object
 * @param state the state where to get the image (from `lv_btn_state_t`) `
 * @return pointer to the left image source (a C array or path to a file)
 */
const(void)* lv_imgbtn_get_src_left(lv_obj_t* imgbtn, lv_btn_state_t state);

/**
 * Get the middle image in a given state
 * @param imgbtn pointer to an image button object
 * @param state the state where to get the image (from `lv_btn_state_t`) `
 * @return pointer to the middle image source (a C array or path to a file)
 */
const(void)* lv_imgbtn_get_src_middle(lv_obj_t* imgbtn, lv_btn_state_t state);

/**
 * Get the right image in a given state
 * @param imgbtn pointer to an image button object
 * @param state the state where to get the image (from `lv_btn_state_t`) `
 * @return pointer to the left image source (a C array or path to a file)
 */
const(void)* lv_imgbtn_get_src_right(lv_obj_t* imgbtn, lv_btn_state_t state);

}
/**
 * Get the current state of the image button
 * @param imgbtn pointer to a image button object
 * @return the state of the button (from lv_btn_state_t enum)
 */
pragma(inline, true) private lv_btn_state_t lv_imgbtn_get_state(const(lv_obj_t)* imgbtn) {
    return lv_btn_get_state(imgbtn);
}

/**
 * Get the toggle enable attribute of the image button
 * @param imgbtn pointer to a image button object
 * @return ture: toggle enabled, false: disabled
 */
pragma(inline, true) private bool lv_imgbtn_get_toggle(const(lv_obj_t)* imgbtn) {
    return lv_btn_get_toggle(imgbtn);
}

/**
 * Get style of a image button.
 * @param imgbtn pointer to image button object
 * @param type which style should be get
 * @return style pointer to the style
 */
const(lv_style_t)* lv_imgbtn_get_style(const(lv_obj_t)* imgbtn, lv_imgbtn_style_t type);

/*=====================
 * Other functions
 *====================*/

/**********************
 *      MACROS
 **********************/

} /*LV_USE_IMGBTN*/

version (none) {}
} /* extern "C" */
}

 /*LV_IMGBTN_H*/
