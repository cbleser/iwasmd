module lv_preload;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_preload.h
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

static if (LV_USE_PRELOAD != 0) {

/*Testing of dependencies*/
static if (LV_USE_ARC == 0) {
static assert(0, "lv_preload: lv_arc is required. Enable it in lv_conf.h (LV_USE_ARC  1) ");
}

static if (LV_USE_ANIMATION == 0) {
static assert(0, "lv_preload: animations are required. Enable it in lv_conf.h (LV_USE_ANIMATION  1) ");
}

public import ...lv_core.lv_obj;
public import ...lv_misc.lv_anim;
public import lv_arc;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**
 * Type of preloader.
 */
enum {
    LV_PRELOAD_TYPE_SPINNING_ARC,
    LV_PRELOAD_TYPE_FILLSPIN_ARC,
};
alias lv_preload_type_t = ubyte;

/**
 * Direction the preloader should spin.
 */
enum {
    LV_PRELOAD_DIR_FORWARD,
    LV_PRELOAD_DIR_BACKWARD,
};
alias lv_preload_dir_t = ubyte;

/*Data of pre loader*/
struct _Lv_preload_ext_t {
    lv_arc_ext_t arc; /*Ext. of ancestor*/
    /*New data for this type */
    lv_anim_value_t arc_length;      /*Length of the spinning indicator in degree*/
    ushort time;                   /*Time of one round*/
    lv_preload_type_t anim_type;/*: 1 !!*/ /*Type of the arc animation*/
    lv_preload_dir_t anim_dir;/*: 1 !!*/   /*Animation Direction*/
}alias lv_preload_ext_t = _Lv_preload_ext_t;

/*Styles*/
enum {
    LV_PRELOAD_STYLE_MAIN,
};
alias lv_preload_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a pre loader objects
 * @param par pointer to an object, it will be the parent of the new pre loader
 * @param copy pointer to a pre loader object, if not NULL then the new object will be copied from
 * it
 * @return pointer to the created pre loader
 */
lv_obj_t* lv_preload_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*======================
 * Add/remove functions
 *=====================*/

/**
 * Set the length of the spinning  arc in degrees
 * @param preload pointer to a preload object
 * @param deg length of the arc
 */
void lv_preload_set_arc_length(lv_obj_t* preload, lv_anim_value_t deg);

/**
 * Set the spin time of the arc
 * @param preload pointer to a preload object
 * @param time time of one round in milliseconds
 */
void lv_preload_set_spin_time(lv_obj_t* preload, ushort time);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a style of a pre loader.
 * @param preload pointer to pre loader object
 * @param type which style should be set
 * @param style pointer to a style
 *  */
void lv_preload_set_style(lv_obj_t* preload, lv_preload_style_t type, const(lv_style_t)* style);

/**
 * Set the animation type of a preloader.
 * @param preload pointer to pre loader object
 * @param type animation type of the preload
 *  */
void lv_preload_set_type(lv_obj_t* preload, lv_preload_type_t type);

/**
 * Set the animation direction of a preloader
 * @param preload pointer to pre loader object
 * @param direction animation direction of the preload
 */
void lv_preload_set_dir(lv_obj_t* preload, lv_preload_dir_t dir);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the arc length [degree] of the a pre loader
 * @param preload pointer to a pre loader object
 */
lv_anim_value_t lv_preload_get_arc_length(const(lv_obj_t)* preload);

/**
 * Get the spin time of the arc
 * @param preload pointer to a pre loader object [milliseconds]
 */
ushort lv_preload_get_spin_time(const(lv_obj_t)* preload);

/**
 * Get style of a pre loader.
 * @param preload pointer to pre loader object
 * @param type which style should be get
 * @return style pointer to the style
 *  */
const(lv_style_t)* lv_preload_get_style(const(lv_obj_t)* preload, lv_preload_style_t type);

/**
 * Get the animation type of a preloader.
 * @param preload pointer to pre loader object
 * @return animation type
 *  */
lv_preload_type_t lv_preload_get_type(lv_obj_t* preload);

/**
 * Get the animation direction of a preloader
 * @param preload pointer to pre loader object
 * @return animation direction
 */
lv_preload_dir_t lv_preload_get_dir(lv_obj_t* preload);

/*=====================
 * Other functions
 *====================*/

/**
 * Animator function  (exec_cb) to rotate the arc of spinner.
 * @param ptr pointer to preloader
 * @param val the current desired value [0..360]
 */
void lv_preload_spinner_anim(void* ptr, lv_anim_value_t val);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_PRELOAD*/

version (none) {}
} /* extern "C" */
}

 /*LV_PRELOAD_H*/
