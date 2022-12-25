module lv_tileview;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_tileview.h
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

static if (LV_USE_TILEVIEW != 0) {

public import ...lv_objx.lv_page;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/*Data of tileview*/
struct _Lv_tileview_ext_t {
    lv_page_ext_t page;
    /*New data for this type */
    const(lv_point_t)* valid_pos;
    ushort valid_pos_cnt;
static if (LV_USE_ANIMATION) {
    ushort anim_time;
}
    lv_point_t act_id;
    ubyte drag_top_en;/*: 1 !!*/
    ubyte drag_bottom_en;/*: 1 !!*/
    ubyte drag_left_en;/*: 1 !!*/
    ubyte drag_right_en;/*: 1 !!*/
    ubyte drag_hor;/*: 1 !!*/
    ubyte drag_ver;/*: 1 !!*/
}alias lv_tileview_ext_t = _Lv_tileview_ext_t;

/*Styles*/
enum {
    LV_TILEVIEW_STYLE_MAIN,
};
alias lv_tileview_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a tileview objects
 * @param par pointer to an object, it will be the parent of the new tileview
 * @param copy pointer to a tileview object, if not NULL then the new object will be copied from it
 * @return pointer to the created tileview
 */
lv_obj_t* lv_tileview_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*======================
 * Add/remove functions
 *=====================*/

/**
 * Register an object on the tileview. The register object will able to slide the tileview
 * @param tileview pointer to a Tileview object
 * @param element pointer to an object
 */
void lv_tileview_add_element(lv_obj_t* tileview, lv_obj_t* element);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set the valid position's indices. The scrolling will be possible only to these positions.
 * @param tileview pointer to a Tileview object
 * @param valid_pos array width the indices. E.g. `lv_point_t p[] = {{0,0}, {1,0}, {1,1}`. Only the
 * pointer is saved so can't be a local variable.
 * @param valid_pos_cnt numner of elements in `valid_pos` array
 */
void lv_tileview_set_valid_positions(lv_obj_t* tileview, const(lv_point_t)* valid_pos, ushort valid_pos_cnt);

/**
 * Set the tile to be shown
 * @param tileview pointer to a tileview object
 * @param x column id (0, 1, 2...)
 * @param y line id (0, 1, 2...)
 * @param anim LV_ANIM_ON: set the value with an animation; LV_ANIM_OFF: change the value immediately
 */
void lv_tileview_set_tile_act(lv_obj_t* tileview, lv_coord_t x, lv_coord_t y, lv_anim_enable_t anim);

/**
 * Enable the edge flash effect. (Show an arc when the an edge is reached)
 * @param tileview pointer to a Tileview
 * @param en true or false to enable/disable end flash
 */
pragma(inline, true) private void lv_tileview_set_edge_flash(lv_obj_t* tileview, bool en) {
    lv_page_set_edge_flash(tileview, en);
}

/**
 * Set the animation time for the Tile view
 * @param tileview pointer to a page object
 * @param anim_time animation time in milliseconds
 */
pragma(inline, true) private void lv_tileview_set_anim_time(lv_obj_t* tileview, ushort anim_time) {
    lv_page_set_anim_time(tileview, anim_time);
}

/**
 * Set a style of a tileview.
 * @param tileview pointer to tileview object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_tileview_set_style(lv_obj_t* tileview, lv_tileview_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the scroll propagation property
 * @param tileview pointer to a Tileview
 * @return true or false
 */
pragma(inline, true) private bool lv_tileview_get_edge_flash(lv_obj_t* tileview) {
    return lv_page_get_edge_flash(tileview);
}

/**
 * Get the animation time for the Tile view
 * @param tileview pointer to a page object
 * @return animation time in milliseconds
 */
pragma(inline, true) private ushort lv_tileview_get_anim_time(lv_obj_t* tileview) {
    return lv_page_get_anim_time(tileview);
}

/**
 * Get style of a tileview.
 * @param tileview pointer to tileview object
 * @param type which style should be get
 * @return style pointer to the style
 */
const(lv_style_t)* lv_tileview_get_style(const(lv_obj_t)* tileview, lv_tileview_style_t type);

/*=====================
 * Other functions
 *====================*/

/**********************
 *      MACROS
 **********************/

} /*LV_USE_TILEVIEW*/

version (none) {}
} /* extern "C" */
}

 /*LV_TILEVIEW_H*/
