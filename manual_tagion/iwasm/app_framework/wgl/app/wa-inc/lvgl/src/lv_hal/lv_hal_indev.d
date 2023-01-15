module lv_hal_indev;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_hal_indev.h
 *
 * @description Input Device HAL interface layer header file
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

public import stdbool;
public import core.stdc.stdint;
public import ...lv_misc.lv_area;
public import ...lv_misc.lv_task;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

struct _lv_obj_t;;
struct _disp_t;;
struct _lv_indev_t;;
struct _lv_indev_drv_t;;

/** Possible input device types*/
enum {
    LV_INDEV_TYPE_NONE,    /**< Uninitialized state*/
    LV_INDEV_TYPE_POINTER, /**< Touch pad, mouse, external button*/
    LV_INDEV_TYPE_KEYPAD,  /**< Keypad or keyboard*/
    LV_INDEV_TYPE_BUTTON,  /**< External (hardware button) which is assigned to a specific point of the
                              screen*/
    LV_INDEV_TYPE_ENCODER, /**< Encoder with only Left, Right turn and a Button*/
};
alias lv_indev_type_t = ubyte;

/** States for input devices*/
enum { LV_INDEV_STATE_REL = 0, LV_INDEV_STATE_PR };
alias lv_indev_state_t = ubyte;

/** Data structure passed to an input driver to fill */
struct _Lv_indev_data_t {
    lv_point_t point; /**< For LV_INDEV_TYPE_POINTER the currently pressed point*/
    uint key;     /**< For LV_INDEV_TYPE_KEYPAD the currently pressed key*/
    uint btn_id;  /**< For LV_INDEV_TYPE_BUTTON the currently pressed button*/
    short enc_diff; /**< For LV_INDEV_TYPE_ENCODER number of steps since the previous read*/

    lv_indev_state_t state; /**< LV_INDEV_STATE_REL or LV_INDEV_STATE_PR*/
}alias lv_indev_data_t = _Lv_indev_data_t;

/** Initialized by the user and registered by 'lv_indev_add()'*/
struct _lv_indev_drv_t {

    /**< Input device type*/
    lv_indev_type_t type;

    /**< Function pointer to read input device data.
     * Return 'true' if there is more data to be read (buffered).
     * Most drivers can safely return 'false' */
    bool function(_lv_indev_drv_t* indev_drv, lv_indev_data_t* data) read_cb;

    /** Called when an action happened on the input device.
     * The second parameter is the event from `lv_event_t`*/
    void function(_lv_indev_drv_t*, ubyte) feedback_cb;

static if (LV_USE_USER_DATA) {
    lv_indev_drv_user_data_t user_data;
}

    /**< Pointer to the assigned display*/
    _disp_t* disp;

    /**< Task to read the periodically read the input device*/
    lv_task_t* read_task;

    /**< Number of pixels to slide before actually drag the object*/
    ubyte drag_limit;

    /**< Drag throw slow-down in [%]. Greater value means faster slow-down */
    ubyte drag_throw;

    /**< Long press time in milliseconds*/
    ushort long_press_time;

    /**< Repeated trigger period in long press [ms] */
    ushort long_press_rep_time;
}alias lv_indev_drv_t = _lv_indev_drv_t;

/** Run time data of input devices
 * Internally used by the library, you should not need to touch it.
 */
struct _lv_indev_proc_t {
    lv_indev_state_t state; /**< Current state of the input device. */
    union _Types {
        struct _Pointer { /*Pointer and button data*/
            lv_point_t act_point; /**< Current point of input device. */
            lv_point_t last_point; /**< Last point of input device. */
            lv_point_t vect; /**< Difference between `act_point` and `last_point`. */
            lv_point_t drag_sum; /*Count the dragged pixels to check LV_INDEV_DEF_DRAG_LIMIT*/
            lv_point_t drag_throw_vect;
            _lv_obj_t* act_obj;      /*The object being pressed*/
            _lv_obj_t* last_obj;     /*The last obejct which was pressed (used by dragthrow and
                                                other post-release event)*/
            _lv_obj_t* last_pressed; /*The lastly pressed object*/

            /*Flags*/
            ubyte drag_limit_out;/*: 1 !!*/
            ubyte drag_in_prog;/*: 1 !!*/
        }_Pointer pointer;
        struct _Keypad { /*Keypad data*/
            lv_indev_state_t last_state;
            uint last_key;
        }_Keypad keypad;
    }_Types types;

    uint pr_timestamp;         /**< Pressed time stamp*/
    uint longpr_rep_timestamp; /**< Long press repeat time stamp*/

    /*Flags*/
    ubyte long_pr_sent;/*: 1 !!*/
    ubyte reset_query;/*: 1 !!*/
    ubyte disabled;/*: 1 !!*/
    ubyte wait_until_release;/*: 1 !!*/
}alias lv_indev_proc_t = _lv_indev_proc_t;

struct _lv_obj_t;;
struct _lv_group_t;;

/** The main input device descriptor with driver, runtime data ('proc') and some additional
 * information*/
struct _lv_indev_t {
    lv_indev_drv_t driver;
    lv_indev_proc_t proc;
    _lv_obj_t* cursor;     /**< Cursor for LV_INPUT_TYPE_POINTER*/
    _lv_group_t* group;    /**< Keypad destination group*/
    const(lv_point_t)* btn_points; /**< Array points assigned to the button ()screen will be pressed
                                      here by the buttons*/
}alias lv_indev_t = _lv_indev_t;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Initialize an input device driver with default values.
 * It is used to surly have known values in the fields ant not memory junk.
 * After it you can set the fields.
 * @param driver pointer to driver variable to initialize
 */
void lv_indev_drv_init(lv_indev_drv_t* driver);

/**
 * Register an initialized input device driver.
 * @param driver pointer to an initialized 'lv_indev_drv_t' variable (can be local variable)
 * @return pointer to the new input device or NULL on error
 */
lv_indev_t* lv_indev_drv_register(lv_indev_drv_t* driver);

/**
 * Update the driver in run time.
 * @param indev pointer to a input device. (return value of `lv_indev_drv_register`)
 * @param new_drv pointer to the new driver
 */
void lv_indev_drv_update(lv_indev_t* indev, lv_indev_drv_t* new_drv);

/**
 * Get the next input device.
 * @param indev pointer to the current input device. NULL to initialize.
 * @return the next input devise or NULL if no more. Give the first input device when the parameter
 * is NULL
 */
lv_indev_t* lv_indev_get_next(lv_indev_t* indev);

/**
 * Read data from an input device.
 * @param indev pointer to an input device
 * @param data input device will write its data here
 * @return false: no more data; true: there more data to read (buffered)
 */
bool lv_indev_read(lv_indev_t* indev, lv_indev_data_t* data);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}


