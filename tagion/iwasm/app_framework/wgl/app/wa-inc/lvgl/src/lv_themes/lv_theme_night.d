module lv_theme_night;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_theme_night.h
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

static if (LV_USE_THEME_NIGHT) {

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Initialize the night theme
 * @param hue [0..360] hue value from HSV color space to define the theme's base color
 * @param font pointer to a font (NULL to use the default)
 * @return pointer to the initialized theme
 */
lv_theme_t* lv_theme_night_init(ushort hue, lv_font_t* font);

/**
 * Get a pointer to the theme
 * @return pointer to the theme
 */
lv_theme_t* lv_theme_get_night();

/**********************
 *      MACROS
 **********************/

}

version (none) {}
} /* extern "C" */
}

 /*LV_THEME_NIGHT_H*/
