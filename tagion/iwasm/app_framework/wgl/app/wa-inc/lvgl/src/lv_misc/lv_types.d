module lv_types;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_types.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**
 * LittlevGL error codes.
 */
enum {
    LV_RES_INV = 0, /*Typically indicates that the object is deleted (become invalid) in the action
                       function or an operation was failed*/
    LV_RES_OK,      /*The object is valid (no deleted) after the action*/
};
alias lv_res_t = ubyte;

alias lv_uintptr_t = uint;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_TYPES_H*/
