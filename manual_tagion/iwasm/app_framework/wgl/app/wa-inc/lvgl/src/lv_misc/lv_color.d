module lv_color;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_color.h
 *
 */

#ifndef LV_COLOR_H
version = LV_COLOR_H;

#ifdef __cplusplus
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

/*Error checking*/
static if (LV_COLOR_DEPTH == 24) {
static assert(0, "LV_COLOR_DEPTH  24 is deprecated. Use LV_COLOR_DEPTH  32 instead (lv_conf.h)");
}

static if (LV_COLOR_DEPTH != 32 && LV_COLOR_SCREEN_TRANSP != 0) {
static assert(0, "LV_COLOR_SCREEN_TRANSP requires LV_COLOR_DEPTH == 32. Set it in lv_conf.h");
}

static if (LV_COLOR_DEPTH != 16 && LV_COLOR_16_SWAP != 0) {
static assert(0, "LV_COLOR_16_SWAP requires LV_COLOR_DEPTH == 16. Set it in lv_conf.h");
}

public import core.stdc.stdint;

/*********************
 *      DEFINES
 *********************/
enum LV_COLOR_WHITE = LV_COLOR_MAKE(0xFF, 0xFF, 0xFF);
enum LV_COLOR_SILVER = LV_COLOR_MAKE(0xC0, 0xC0, 0xC0);
enum LV_COLOR_GRAY = LV_COLOR_MAKE(0x80, 0x80, 0x80);
enum LV_COLOR_BLACK = LV_COLOR_MAKE(0x00, 0x00, 0x00);
enum LV_COLOR_RED = LV_COLOR_MAKE(0xFF, 0x00, 0x00);
enum LV_COLOR_MAROON = LV_COLOR_MAKE(0x80, 0x00, 0x00);
enum LV_COLOR_YELLOW = LV_COLOR_MAKE(0xFF, 0xFF, 0x00);
enum LV_COLOR_OLIVE = LV_COLOR_MAKE(0x80, 0x80, 0x00);
enum LV_COLOR_LIME = LV_COLOR_MAKE(0x00, 0xFF, 0x00);
enum LV_COLOR_GREEN = LV_COLOR_MAKE(0x00, 0x80, 0x00);
enum LV_COLOR_CYAN = LV_COLOR_MAKE(0x00, 0xFF, 0xFF);
enum LV_COLOR_AQUA = LV_COLOR_CYAN;
enum LV_COLOR_TEAL = LV_COLOR_MAKE(0x00, 0x80, 0x80);
enum LV_COLOR_BLUE = LV_COLOR_MAKE(0x00, 0x00, 0xFF);
enum LV_COLOR_NAVY = LV_COLOR_MAKE(0x00, 0x00, 0x80);
enum LV_COLOR_MAGENTA = LV_COLOR_MAKE(0xFF, 0x00, 0xFF);
enum LV_COLOR_PURPLE = LV_COLOR_MAKE(0x80, 0x00, 0x80);
enum LV_COLOR_ORANGE = LV_COLOR_MAKE(0xFF, 0xA5, 0x00);

/**
 * Opacity percentages.
 */
enum {
    LV_OPA_TRANSP = 0,
    LV_OPA_0      = 0,
    LV_OPA_10     = 25,
    LV_OPA_20     = 51,
    LV_OPA_30     = 76,
    LV_OPA_40     = 102,
    LV_OPA_50     = 127,
    LV_OPA_60     = 153,
    LV_OPA_70     = 178,
    LV_OPA_80     = 204,
    LV_OPA_90     = 229,
    LV_OPA_100    = 255,
    LV_OPA_COVER  = 255,
};

enum LV_OPA_MIN = 16  /*Opacities below this will be transparent*/;
enum LV_OPA_MAX = 251 /*Opacities above this will fully cover*/;

static if (LV_COLOR_DEPTH == 1) {
enum LV_COLOR_SIZE = 8;
} else static if (LV_COLOR_DEPTH == 8) {
enum LV_COLOR_SIZE = 8;
} else static if (LV_COLOR_DEPTH == 16) {
enum LV_COLOR_SIZE = 16;
} else static if (LV_COLOR_DEPTH == 32) {
enum LV_COLOR_SIZE = 32;
} else {
static assert(0, "Invalid LV_COLOR_DEPTH in lv_conf.h! Set it to 1, 8, 16 or 32!");
}

/**********************
 *      TYPEDEFS
 **********************/

union _Lv_color1_t {
    ubyte blue;/*: 1 !!*/
    ubyte green;/*: 1 !!*/
    ubyte red;/*: 1 !!*/
    ubyte full;/*: 1 !!*/
}alias lv_color1_t = _Lv_color1_t;

union _Lv_color8_t {
    struct _Ch {
        ubyte blue;/*: 2 !!*/
        ubyte green;/*: 3 !!*/
        ubyte red;/*: 3 !!*/
    }_Ch ch;
    ubyte full;
}alias lv_color8_t = _Lv_color8_t;

union _Lv_color16_t {
    struct _Ch {
static if (LV_COLOR_16_SWAP == 0) {
        ushort blue;/*: 5 !!*/
        ushort green;/*: 6 !!*/
        ushort red;/*: 5 !!*/
} else {
        ushort green_h;/*: 3 !!*/
        ushort red;/*: 5 !!*/
        ushort blue;/*: 5 !!*/
        ushort green_l;/*: 3 !!*/
}
    }_Ch ch;
    ushort full;
}alias lv_color16_t = _Lv_color16_t;

union _Lv_color32_t {
    struct _Ch {
        ubyte blue;
        ubyte green;
        ubyte red;
        ubyte alpha;
    }_Ch ch;
    uint full;
}alias lv_color32_t = _Lv_color32_t;

static if (LV_COLOR_DEPTH == 1) {
alias lv_color_int_t = ubyte;
alias lv_color_t = lv_color1_t;
} else static if (LV_COLOR_DEPTH == 8) {
alias lv_color_int_t = ubyte;
alias lv_color_t = lv_color8_t;
} else static if (LV_COLOR_DEPTH == 16) {
alias lv_color_int_t = ushort;
alias lv_color_t = lv_color16_t;
} else static if (LV_COLOR_DEPTH == 32) {
alias lv_color_int_t = uint;
alias lv_color_t = lv_color32_t;
} else {
static assert(0, "Invalid LV_COLOR_DEPTH in lv_conf.h! Set it to 1, 8, 16 or 32!");
}

alias lv_opa_t = ubyte;

struct _Lv_color_hsv_t {
    ushort h;
    ubyte s;
    ubyte v;
}alias lv_color_hsv_t = _Lv_color_hsv_t;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/*In color conversations:
 * - When converting to bigger color type the LSB weight of 1 LSB is calculated
 *   E.g. 16 bit Red has 5 bits
 *         8 bit Red has 2 bits
 *        ----------------------
 *        8 bit red LSB = (2^5 - 1) / (2^2 - 1) = 31 / 3 = 10
 *
 * - When calculating to smaller color type simply shift out the LSBs
 *   E.g.  8 bit Red has 2 bits
 *        16 bit Red has 5 bits
 *        ----------------------
 *         Shift right with 5 - 3 = 2
 */

static inline ubyte lv_color_to1(lv_color_t color)
{
static if (LV_COLOR_DEPTH == 1) {
    return color.full;
} else static if (LV_COLOR_DEPTH == 8) {
    if((color.ch.red & 0x4) || (color.ch.green & 0x4) || (color.ch.blue & 0x2)) {
        return 1;
    } else {
        return 0;
    }
} else static if (LV_COLOR_DEPTH == 16) {
static if (LV_COLOR_16_SWAP == 0) {
    if((color.ch.red & 0x10) || (color.ch.green & 0x20) || (color.ch.blue & 0x10)) {
        return 1;
//! #else
    if((color.ch.red & 0x10) || (color.ch.green_h & 0x20) || (color.ch.blue & 0x10)) {
        return 1;
//! #endif
    } else {
        return 0;
    }
} else static if (LV_COLOR_DEPTH == 32) {
    if((color.ch.red & 0x80) || (color.ch.green & 0x80) || (color.ch.blue & 0x80)) {
        return 1;
    } else {
        return 0;
    }
}
}

pragma(inline, true) private ubyte lv_color_to8(lv_color_t color) {
static if (LV_COLOR_DEPTH == 1) {
    if(color.full == 0)
        return 0;
    else
        return 0xFF;
} else static if (LV_COLOR_DEPTH == 8) {
    return color.full;
} else static if (LV_COLOR_DEPTH == 16) {

static if (LV_COLOR_16_SWAP == 0) {
    lv_color8_t ret = void;
    ret.ch.red   = color.ch.red >> 2;   /* 5 - 3  = 2*/
    ret.ch.green = color.ch.green >> 3; /* 6 - 3  = 3*/
    ret.ch.blue  = color.ch.blue >> 3;  /* 5 - 2  = 3*/
    return ret.full;
} else {
    lv_color8_t ret = void;
    ret.ch.red   = color.ch.red >> 2;  /* 5 - 3  = 2*/
    ret.ch.green = color.ch.green_h;   /* 6 - 3  = 3*/
    ret.ch.blue  = color.ch.blue >> 3; /* 5 - 2  = 3*/
    return ret.full;
}
} else static if (LV_COLOR_DEPTH == 32) {
    lv_color8_t ret = void;
    ret.ch.red   = color.ch.red >> 5;   /* 8 - 3  = 5*/
    ret.ch.green = color.ch.green >> 5; /* 8 - 3  = 5*/
    ret.ch.blue  = color.ch.blue >> 6;  /* 8 - 2  = 6*/
    return ret.full;
}
}

pragma(inline, true) private ushort lv_color_to16(lv_color_t color) {
static if (LV_COLOR_DEPTH == 1) {
    if(color.full == 0)
        return 0;
    else
        return 0xFFFF;
} else static if (LV_COLOR_DEPTH == 8) {
    lv_color16_t ret = void;
static if (LV_COLOR_16_SWAP == 0) {
    ret.ch.red = color.ch.red * 4;     /*(2^5 - 1)/(2^3 - 1) = 31/7 = 4*/
    ret.ch.green = color.ch.green * 9; /*(2^6 - 1)/(2^3 - 1) = 63/7 = 9*/
    ret.ch.blue = color.ch.blue * 10;  /*(2^5 - 1)/(2^2 - 1) = 31/3 = 10*/
} else {
    ret.red        = color.ch.red * 4;
    ubyte g_tmp = color.ch.green * 9;
    ret.ch.green_h = (g_tmp & 0x1F) >> 3;
    ret.ch.green_l = g_tmp & 0x07;
    ret.ch.blue    = color.ch.blue * 10;
}
    return ret.full;
} else static if (LV_COLOR_DEPTH == 16) {
    return color.full;
} else static if (LV_COLOR_DEPTH == 32) {
    lv_color16_t ret = void;
static if (LV_COLOR_16_SWAP == 0) {
    ret.ch.red   = color.ch.red >> 3;   /* 8 - 5  = 3*/
    ret.ch.green = color.ch.green >> 2; /* 8 - 6  = 2*/
    ret.ch.blue  = color.ch.blue >> 3;  /* 8 - 5  = 3*/
} else {
    ret.ch.red     = color.ch.red >> 3;
    ret.ch.green_h = (color.ch.green & 0xE0) >> 5;
    ret.ch.green_l = (color.ch.green & 0x1C) >> 2;
    ret.ch.blue    = color.ch.blue >> 3;
}
    return ret.full;
}
}

pragma(inline, true) private uint lv_color_to32(lv_color_t color) {
static if (LV_COLOR_DEPTH == 1) {
    if(color.full == 0)
        return 0;
    else
        return 0xFFFFFFFF;
} else static if (LV_COLOR_DEPTH == 8) {
    lv_color32_t ret = void;
    ret.ch.red = color.ch.red * 36;     /*(2^8 - 1)/(2^3 - 1) = 255/7 = 36*/
    ret.ch.green = color.ch.green * 36; /*(2^8 - 1)/(2^3 - 1) = 255/7 = 36*/
    ret.ch.blue = color.ch.blue * 85;   /*(2^8 - 1)/(2^2 - 1) = 255/3 = 85*/
    ret.ch.alpha = 0xFF;
    return ret.full;
} else static if (LV_COLOR_DEPTH == 16) {
static if (LV_COLOR_16_SWAP == 0) {
    lv_color32_t ret = void;
    ret.ch.red   = color.ch.red * 8;   /*(2^8 - 1)/(2^5 - 1) = 255/31 = 8*/
    ret.ch.green = color.ch.green * 4; /*(2^8 - 1)/(2^6 - 1) = 255/63 = 4*/
    ret.ch.blue  = color.ch.blue * 8;  /*(2^8 - 1)/(2^5 - 1) = 255/31 = 8*/
    ret.ch.alpha = 0xFF;
    return ret.full;
} else {
    lv_color32_t ret = void;
    ret.ch.red   = color.ch.red * 8;                                 /*(2^8 - 1)/(2^5 - 1) = 255/31 = 8*/
    ret.ch.green = ((color.ch.green_h << 3) + color.ch.green_l) * 4; /*(2^8 - 1)/(2^6 - 1) = 255/63 = 4*/
    ret.ch.blue  = color.ch.blue * 8;                                /*(2^8 - 1)/(2^5 - 1) = 255/31 = 8*/
    ret.ch.alpha = 0xFF;
    return ret.full;
}
} else static if (LV_COLOR_DEPTH == 32) {
    return color.full;
}
}

pragma(inline, true) private lv_color_t lv_color_mix(lv_color_t c1, lv_color_t c2, ubyte mix) {
    lv_color_t ret = void;
static if (LV_COLOR_DEPTH != 1) {
    /*LV_COLOR_DEPTH == 8, 16 or 32*/
    ret.ch.red = cast(ushort)(cast(ushort)c1.ch.red * mix + (c2.ch.red * (255 - mix))) >> 8;
static if (LV_COLOR_DEPTH == 16 && LV_COLOR_16_SWAP) {
    /*If swapped Green is in 2 parts*/
    ushort g_1 = (c1.ch.green_h << 3) + c1.ch.green_l;
    ushort g_2 = (c2.ch.green_h << 3) + c2.ch.green_l;
    ushort g_out = cast(ushort)(cast(ushort)g_1 * mix + (g_2 * (255 - mix))) >> 8;
    ret.ch.green_h = g_out >> 3;
    ret.ch.green_l = g_out & 0x7;
} else {
    ret.ch.green = cast(ushort)(cast(ushort)c1.ch.green * mix + (c2.ch.green * (255 - mix))) >> 8;
}
    ret.ch.blue = cast(ushort)(cast(ushort)c1.ch.blue * mix + (c2.ch.blue * (255 - mix))) >> 8;
static if (LV_COLOR_DEPTH == 32) {
    ret.ch.alpha = 0xFF;
}
} else {
    /*LV_COLOR_DEPTH == 1*/
    ret.full = mix > LV_OPA_50 ? c1.full : c2.full;
}

    return ret;
}

/**
 * Get the brightness of a color
 * @param color a color
 * @return the brightness [0..255]
 */
pragma(inline, true) private ubyte lv_color_brightness(lv_color_t color) {
    lv_color32_t c32 = void;
    c32.full        = lv_color_to32(color);
    ushort bright = 3 * c32.ch.red + c32.ch.blue + 4 * c32.ch.green;
    return cast(ushort)bright >> 3;
}

/* The most simple macro to create a color from R,G and B values */
static if (LV_COLOR_DEPTH == 1) {
enum string LV_COLOR_MAKE(string r8, string g8, string b8) = ` ((lv_color_t){(b8 >> 7 | g8 >> 7 | r8 >> 7)})`;
pragma(inline, true) private lv_color_t lv_color_make(int r8, int g8, int b8) {
    lv_color_t color = void;
    color.full = (b8 >> 7 | g8 >> 7 | r8 >> 7);
    return color;
}
} else static if (LV_COLOR_DEPTH == 8) {
enum string LV_COLOR_MAKE(string r8, string g8, string b8) = ` ((lv_color_t){{b8 >> 6, g8 >> 5, r8 >> 5}})`;
pragma(inline, true) private lv_color_t lv_color_make(ubyte r8, int g8, int b8) {
    lv_color_t color = void;
    color.ch.blue = b8 >> 6;
    color.ch.green = g8 >> 5;
    color.ch.red = r8 >> 5;
    return color;
}
} else static if (LV_COLOR_DEPTH == 16) {
static if (LV_COLOR_16_SWAP == 0) {
enum string LV_COLOR_MAKE(string r8, string g8, string b8) = ` ((lv_color_t){{b8 >> 3, g8 >> 2, r8 >> 3}})`;
pragma(inline, true) private lv_color_t lv_color_make(ubyte r8, ubyte g8, ubyte b8) {
    lv_color_t color = void;
    color.ch.blue  = cast(ushort)(b8 >> 3);
    color.ch.green = cast(ushort)(g8 >> 2);
    color.ch.red   = cast(ushort)(r8 >> 3);
    return color;
}
} else {
enum string LV_COLOR_MAKE(string r8, string g8, string b8) = ` ((lv_color_t){{g8 >> 5, r8 >> 3, b8 >> 3, (g8 >> 2) & 0x7}})`;
pragma(inline, true) private lv_color_t lv_color_make(ubyte r8, ubyte g8, ubyte b8) {
    lv_color_t color = void;
    color.ch.green_h = cast(ushort)(g8 >> 5);
    color.ch.red = cast(ushort)(r8 >> 3);
    color.ch.blue = cast(ushort)(b8 >> 3);
    color.ch.green_l = cast(ushort)((g8 >> 2) & 0x7);
    return color;
}
}
} else static if (LV_COLOR_DEPTH == 32) {
enum string LV_COLOR_MAKE(string r8, string g8, string b8) = ` ((lv_color_t){{b8, g8, r8, 0xff}}) /*Fix 0xff alpha*/`;
pragma(inline, true) private lv_color_t lv_color_make(ubyte r8, ubyte g8, ubyte b8) {
    lv_color_t color = void;
    color.ch.blue  = b8;
    color.ch.green = g8;
    color.ch.red   = r8;
    color.ch.alpha = 0xff;
    return color;
}
}

pragma(inline, true) private lv_color_t lv_color_hex(uint c) {
    return lv_color_make(cast(ubyte)((c >> 16) & 0xFF), cast(ubyte)((c >> 8) & 0xFF), cast(ubyte)(c & 0xFF));
}

pragma(inline, true) private lv_color_t lv_color_hex3(uint c) {
    return lv_color_make(cast(ubyte)(((c >> 4) & 0xF0) | ((c >> 8) & 0xF)), cast(ubyte)((c & 0xF0) | ((c & 0xF0) >> 4)),
                         cast(ubyte)((c & 0xF) | ((c & 0xF) << 4)));
}

/**
 * Convert a HSV color to RGB
 * @param h hue [0..359]
 * @param s saturation [0..100]
 * @param v value [0..100]
 * @return the given RGB color in RGB (with LV_COLOR_DEPTH depth)
 */
lv_color_t lv_color_hsv_to_rgb(ushort h, ubyte s, ubyte v);

/**
 * Convert an RGB color to HSV
 * @param r red
 * @param g green
 * @param b blue
 * @return the given RGB color n HSV
 */
lv_color_hsv_t lv_color_rgb_to_hsv(ubyte r, ubyte g, ubyte b);

/**********************
 *      MACROS
 **********************/

version (none) {
} /* extern "C" */
}

} /*USE_COLOR*/
