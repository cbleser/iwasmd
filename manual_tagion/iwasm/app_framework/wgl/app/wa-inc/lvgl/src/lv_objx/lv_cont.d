module lv_cont;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_cont.h
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

static if (LV_USE_CONT != 0) {

public import ...lv_core.lv_obj;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/** Container layout options*/
enum {
    LV_LAYOUT_OFF = 0, /**< No layout */
    LV_LAYOUT_CENTER, /**< Center objects */
    LV_LAYOUT_COL_L,  /**< Column left align*/
    LV_LAYOUT_COL_M,  /**< Column middle align*/
    LV_LAYOUT_COL_R,  /**< Column right align*/
    LV_LAYOUT_ROW_T,  /**< Row top align*/
    LV_LAYOUT_ROW_M,  /**< Row middle align*/
    LV_LAYOUT_ROW_B,  /**< Row bottom align*/
    LV_LAYOUT_PRETTY, /**< Put as many object as possible in row and begin a new row*/
    LV_LAYOUT_GRID,   /**< Align same-sized object into a grid*/
    _LV_LAYOUT_NUM
};
alias lv_layout_t = ubyte;

/**
 * How to resize the container around the children.
 */
enum {
    LV_FIT_NONE,  /**< Do not change the size automatically*/
    LV_FIT_TIGHT, /**< Shrink wrap around the children */
    LV_FIT_FLOOD, /**< Align the size to the parent's edge*/
    LV_FIT_FILL,  /**< Align the size to the parent's edge first but if there is an object out of it
                     then get larger */
    _LV_FIT_NUM
};
alias lv_fit_t = ubyte;

struct _Lv_cont_ext_t {
    /*Inherited from 'base_obj' so no inherited ext. */ /*Ext. of ancestor*/
    /*New data for this type */
    ubyte layout;/*: 4 !!*/     /*A layout from 'lv_layout_t' enum*/
    ubyte fit_left;/*: 2 !!*/   /*A fit type from `lv_fit_t` enum */
    ubyte fit_right;/*: 2 !!*/  /*A fit type from `lv_fit_t` enum */
    ubyte fit_top;/*: 2 !!*/    /*A fit type from `lv_fit_t` enum */
    ubyte fit_bottom;/*: 2 !!*/ /*A fit type from `lv_fit_t` enum */
}alias lv_cont_ext_t = _Lv_cont_ext_t;

/*Styles*/
enum {
    LV_CONT_STYLE_MAIN,
};
alias lv_cont_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a container objects
 * @param par pointer to an object, it will be the parent of the new container
 * @param copy pointer to a container object, if not NULL then the new object will be copied from it
 * @return pointer to the created container
 */
lv_obj_t* lv_cont_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a layout on a container
 * @param cont pointer to a container object
 * @param layout a layout from 'lv_cont_layout_t'
 */
void lv_cont_set_layout(lv_obj_t* cont, lv_layout_t layout);

/**
 * Set the fit policy in all 4 directions separately.
 * It tell how to change the container's size automatically.
 * @param cont pointer to a container object
 * @param left left fit policy from `lv_fit_t`
 * @param right right fit policy from `lv_fit_t`
 * @param top top fit policy from `lv_fit_t`
 * @param bottom bottom fit policy from `lv_fit_t`
 */
void lv_cont_set_fit4(lv_obj_t* cont, lv_fit_t left, lv_fit_t right, lv_fit_t top, lv_fit_t bottom);

/**
 * Set the fit policy horizontally and vertically separately.
 * It tells how to change the container's size automatically.
 * @param cont pointer to a container object
 * @param hor horizontal fit policy from `lv_fit_t`
 * @param ver vertical fit policy from `lv_fit_t`
 */
pragma(inline, true) private void lv_cont_set_fit2(lv_obj_t* cont, lv_fit_t hor, lv_fit_t ver) {
    lv_cont_set_fit4(cont, hor, hor, ver, ver);
}

/**
 * Set the fit policy in all 4 direction at once.
 * It tells how to change the container's size automatically.
 * @param cont pointer to a container object
 * @param fit fit policy from `lv_fit_t`
 */
pragma(inline, true) private void lv_cont_set_fit(lv_obj_t* cont, lv_fit_t fit) {
    lv_cont_set_fit4(cont, fit, fit, fit, fit);
}

/**
 * Set the style of a container
 * @param cont pointer to a container object
 * @param type which style should be set (can be only `LV_CONT_STYLE_MAIN`)
 * @param style pointer to the new style
 */
pragma(inline, true) private void lv_cont_set_style(lv_obj_t* cont, lv_cont_style_t type, const(lv_style_t)* style) {
    cast(void)type; /*Unused*/
    lv_obj_set_style(cont, style);
}

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the layout of a container
 * @param cont pointer to container object
 * @return the layout from 'lv_cont_layout_t'
 */
lv_layout_t lv_cont_get_layout(const(lv_obj_t)* cont);

/**
 * Get left fit mode of a container
 * @param cont pointer to a container object
 * @return an element of `lv_fit_t`
 */
lv_fit_t lv_cont_get_fit_left(const(lv_obj_t)* cont);

/**
 * Get right fit mode of a container
 * @param cont pointer to a container object
 * @return an element of `lv_fit_t`
 */
lv_fit_t lv_cont_get_fit_right(const(lv_obj_t)* cont);

/**
 * Get top fit mode of a container
 * @param cont pointer to a container object
 * @return an element of `lv_fit_t`
 */
lv_fit_t lv_cont_get_fit_top(const(lv_obj_t)* cont);

/**
 * Get bottom fit mode of a container
 * @param cont pointer to a container object
 * @return an element of `lv_fit_t`
 */
lv_fit_t lv_cont_get_fit_bottom(const(lv_obj_t)* cont);

/**
 * Get the style of a container
 * @param cont pointer to a container object
 * @param type which style should be get (can be only `LV_CONT_STYLE_MAIN`)
 * @return pointer to the container's style
 */
pragma(inline, true) private const(lv_style_t)* lv_cont_get_style(const(lv_obj_t)* cont, lv_cont_style_t type) {
    cast(void)type; /*Unused*/
    return lv_obj_get_style(cont);
}

/**********************
 *      MACROS
 **********************/

} /*LV_USE_CONT*/

version (none) {}
} /* extern "C" */
}

 /*LV_CONT_H*/
