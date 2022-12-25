module lv_cb;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_cb.h
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

static if (LV_USE_CB != 0) {

/*Testing of dependencies*/
static if (LV_USE_BTN == 0) {
static assert(0, "lv_cb: lv_btn is required. Enable it in lv_conf.h (LV_USE_BTN  1) ");
}

static if (LV_USE_LABEL == 0) {
static assert(0, "lv_cb: lv_label is required. Enable it in lv_conf.h (LV_USE_LABEL  1) ");
}

public import ...lv_core.lv_obj;
public import lv_btn;
public import lv_label;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/*Data of check box*/
struct _Lv_cb_ext_t {
    lv_btn_ext_t bg_btn; /*Ext. of ancestor*/
    /*New data for this type */
    lv_obj_t* bullet; /*Pointer to button*/
    lv_obj_t* label;  /*Pointer to label*/
}alias lv_cb_ext_t = _Lv_cb_ext_t;

/** Checkbox styles. */
enum {
    LV_CB_STYLE_BG, /**< Style of object background. */
    LV_CB_STYLE_BOX_REL, /**< Style of box (released). */
    LV_CB_STYLE_BOX_PR, /**< Style of box (pressed). */
    LV_CB_STYLE_BOX_TGL_REL, /**< Style of box (released but checked). */
    LV_CB_STYLE_BOX_TGL_PR, /**< Style of box (pressed and checked). */
    LV_CB_STYLE_BOX_INA, /**< Style of disabled box */
};
alias lv_cb_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a check box objects
 * @param par pointer to an object, it will be the parent of the new check box
 * @param copy pointer to a check box object, if not NULL then the new object will be copied from it
 * @return pointer to the created check box
 */
lv_obj_t* lv_cb_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set the text of a check box. `txt` will be copied and may be deallocated
 * after this function returns.
 * @param cb pointer to a check box
 * @param txt the text of the check box. NULL to refresh with the current text.
 */
void lv_cb_set_text(lv_obj_t* cb, const(char)* txt);

/**
 * Set the text of a check box. `txt` must not be deallocated during the life
 * of this checkbox.
 * @param cb pointer to a check box
 * @param txt the text of the check box. NULL to refresh with the current text.
 */
void lv_cb_set_static_text(lv_obj_t* cb, const(char)* txt);

/**
 * Set the state of the check box
 * @param cb pointer to a check box object
 * @param checked true: make the check box checked; false: make it unchecked
 */
pragma(inline, true) private void lv_cb_set_checked(lv_obj_t* cb, bool checked) {
    lv_btn_set_state(cb, checked ? LV_BTN_STATE_TGL_REL : LV_BTN_STATE_REL);
}

/**
 * Make the check box inactive (disabled)
 * @param cb pointer to a check box object
 */
pragma(inline, true) private void lv_cb_set_inactive(lv_obj_t* cb) {
    lv_btn_set_state(cb, LV_BTN_STATE_INA);
}

/**
 * Set a style of a check box
 * @param cb pointer to check box object
 * @param type which style should be set
 * @param style pointer to a style
 *  */
void lv_cb_set_style(lv_obj_t* cb, lv_cb_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the text of a check box
 * @param cb pointer to check box object
 * @return pointer to the text of the check box
 */
const(char)* lv_cb_get_text(const(lv_obj_t)* cb);

/**
 * Get the current state of the check box
 * @param cb pointer to a check box object
 * @return true: checked; false: not checked
 */
pragma(inline, true) private bool lv_cb_is_checked(const(lv_obj_t)* cb) {
    return lv_btn_get_state(cb) == LV_BTN_STATE_REL ? false : true;
}

/**
 * Get whether the check box is inactive or not.
 * @param cb pointer to a check box object
 * @return true: inactive; false: not inactive
 */
pragma(inline, true) private bool lv_cb_is_inactive(const(lv_obj_t)* cb) {
    return lv_btn_get_state(cb) == LV_BTN_STATE_INA ? false : true;
}

/**
 * Get a style of a button
 * @param cb pointer to check box object
 * @param type which style should be get
 * @return style pointer to the style
 *  */
const(lv_style_t)* lv_cb_get_style(const(lv_obj_t)* cb, lv_cb_style_t type);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_CB*/

version (none) {}
} /* extern "C" */
}

 /*LV_CB_H*/
