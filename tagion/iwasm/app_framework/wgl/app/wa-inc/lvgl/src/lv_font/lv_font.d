module lv_font;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_font.h
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

public import core.stdc.stdint;
public import core.stdc.stddef;
public import stdbool;

public import lv_symbol_def;

/*********************
 *      DEFINES
 *********************/
/*Number of fractional digits in the advanced width (`adv_w`) field of `lv_font_glyph_dsc_t`*/
enum LV_FONT_WIDTH_FRACT_DIGIT =       4;

enum LV_FONT_KERN_POSITIVE =        0;
enum LV_FONT_KERN_NEGATIVE =        1;

/**********************
 *      TYPEDEFS
 **********************/

/*------------------
 * General types
 *-----------------*/

/** Describes the properties of a glyph. */
struct _Lv_font_glyph_dsc_t {
    ushort adv_w; /**< The glyph needs this space. Draw the next glyph after this width. 8 bit integer, 4 bit fractional */
    ubyte box_w;  /**< Width of the glyph's bounding box*/
    ubyte box_h;  /**< Height of the glyph's bounding box*/
    byte ofs_x;   /**< x offset of the bounding box*/
    byte ofs_y;  /**< y offset of the bounding box*/
    ubyte bpp;   /**< Bit-per-pixel: 1, 2, 4, 8*/
}alias lv_font_glyph_dsc_t = _Lv_font_glyph_dsc_t;

/*Describe the properties of a font*/
struct _lv_font_struct {
    /** Get a glyph's  descriptor from a font*/
    bool function(const(_lv_font_struct)*, lv_font_glyph_dsc_t*, uint letter, uint letter_next) get_glyph_dsc;

    /** Get a glyph's bitmap from a font*/
    const(ubyte)* function(const(_lv_font_struct)*, uint) get_glyph_bitmap;

    /*Pointer to the font in a font pack (must have the same line height)*/
    ubyte line_height;      /**< The real line height where any text fits*/
    ubyte base_line;        /**< Base line measured from the top of the line_height*/
    void* dsc;               /**< Store implementation specific data here*/
static if (LV_USE_USER_DATA) {
    lv_font_user_data_t user_data; /**< Custom user data for font. */
}
}alias lv_font_t = _lv_font_struct;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Return with the bitmap of a font.
 * @param font_p pointer to a font
 * @param letter an UNICODE character code
 * @return  pointer to the bitmap of the letter
 */
const(ubyte)* lv_font_get_glyph_bitmap(const(lv_font_t)* font_p, uint letter);

/**
 * Get the descriptor of a glyph
 * @param font_p pointer to font
 * @param dsc_out store the result descriptor here
 * @param letter an UNICODE letter code
 * @return true: descriptor is successfully loaded into `dsc_out`.
 *         false: the letter was not found, no data is loaded to `dsc_out`
 */
bool lv_font_get_glyph_dsc(const(lv_font_t)* font_p, lv_font_glyph_dsc_t* dsc_out, uint letter, uint letter_next);

/**
 * Get the width of a glyph with kerning
 * @param font pointer to a font
 * @param letter an UNICODE letter
 * @param letter_next the next letter after `letter`. Used for kerning
 * @return the width of the glyph
 */
ushort lv_font_get_glyph_width(const(lv_font_t)* font, uint letter, uint letter_next);

/**
 * Get the line height of a font. All characters fit into this height
 * @param font_p pointer to a font
 * @return the height of a font
 */
pragma(inline, true) private ubyte lv_font_get_line_height(const(lv_font_t)* font_p) {
    return font_p.line_height;
}

/**********************
 *      MACROS
 **********************/

enum string LV_FONT_DECLARE(string font_name) = ` extern lv_font_t font_name;`;

static if (LV_FONT_ROBOTO_12) {
LV_FONT_DECLARE(lv_font_roboto_12)
}

static if (LV_FONT_ROBOTO_16) {
LV_FONT_DECLARE(lv_font_roboto_16)
}

static if (LV_FONT_ROBOTO_22) {
LV_FONT_DECLARE(lv_font_roboto_22)
}

static if (LV_FONT_ROBOTO_28) {
LV_FONT_DECLARE(lv_font_roboto_28)
}

static if (LV_FONT_UNSCII_8) {
LV_FONT_DECLARE(lv_font_unscii_8)
}

/*Declare the custom (user defined) fonts*/
version (LV_FONT_CUSTOM_DECLARE) {
LV_FONT_CUSTOM_DECLARE
}

version (none) {}
} /* extern "C" */
}

 /*USE_FONT*/
