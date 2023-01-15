module lv_conf;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/**
 * @file lv_conf.h
 *
 */

/*
 * COPY THIS FILE AS `lv_conf.h` NEXT TO the `lvgl` FOLDER
 */

static if (1) { /*Set it to "1" to enable content*/

 
/* clang-format off */

public import core.stdc.stdint;



/*====================
   Graphical settings
 *====================*/

/* Maximal horizontal and vertical resolution to support by the library.*/
enum LV_HOR_RES_MAX =          (480);
enum LV_VER_RES_MAX =          (320);

/* Color depth:
 * - 1:  1 byte per pixel
 * - 8:  RGB233
 * - 16: RGB565
 * - 32: ARGB8888
 */
enum LV_COLOR_DEPTH =     16;

/* Swap the 2 bytes of RGB565 color.
 * Useful if the display has a 8 bit interface (e.g. SPI)*/
enum LV_COLOR_16_SWAP =   0;

/* 1: Enable screen transparency.
 * Useful for OSD or other overlapping GUIs.
 * Requires `LV_COLOR_DEPTH = 32` colors and the screen's style should be modified: `style.body.opa = ...`*/
enum LV_COLOR_SCREEN_TRANSP =    0;

/*Images pixels with this color will not be drawn (with chroma keying)*/
enum LV_COLOR_TRANSP =    LV_COLOR_LIME         /*LV_COLOR_LIME: pure green*/;

/* Enable anti-aliasing (lines, and radiuses will be smoothed) */
enum LV_ANTIALIAS =        1;

/* Default display refresh period.
 * Can be changed in the display driver (`lv_disp_drv_t`).*/
enum LV_DISP_DEF_REFR_PERIOD =      30      /*[ms]*/;

/* Dot Per Inch: used to initialize default sizes.
 * E.g. a button with width = LV_DPI / 2 -> half inch wide
 * (Not so important, you can adjust it to modify default sizes and spaces)*/
enum LV_DPI =              100     /*[px]*/;

/* Type of coordinates. Should be `int16_t` (or `int32_t` for extreme cases) */
alias lv_coord_t = short;

/*=========================
   Memory manager settings
 *=========================*/

/* LittelvGL's internal memory manager's settings.
 * The graphical objects and other related data are stored here. */

/* 1: use custom malloc/free, 0: use the built-in `lv_mem_alloc` and `lv_mem_free` */
enum LV_MEM_CUSTOM =      0;
static if (LV_MEM_CUSTOM == 0) {
/* Size of the memory used by `lv_mem_alloc` in bytes (>= 2kB)*/
enum LV_MEM_SIZE =    (32U * 1024U);

/* Complier prefix for a big array declaration */
version = LV_MEM_ATTR;

/* Set an address for the memory pool instead of allocating it as an array.
 * Can be in external SRAM too. */
enum LV_MEM_ADR =          0;

/* Automatically defrag. on free. Defrag. means joining the adjacent free cells. */
enum LV_MEM_AUTO_DEFRAG =  1;
} else {       /*LV_MEM_CUSTOM*/
enum LV_MEM_CUSTOM_INCLUDE = <stdlib.h>   /*Header for the dynamic memory function*/;
enum LV_MEM_CUSTOM_ALLOC =   malloc       /*Wrapper to malloc*/;
enum LV_MEM_CUSTOM_FREE =    free         /*Wrapper to free*/;
}     /*LV_MEM_CUSTOM*/

/* Garbage Collector settings
 * Used if lvgl is binded to higher level language and the memory is managed by that language */
enum LV_ENABLE_GC = 0;
static if (LV_ENABLE_GC != 0) {
enum LV_GC_INCLUDE = "gc.h"                           /*Include Garbage Collector related things*/;
enum LV_MEM_CUSTOM_REALLOC =   your_realloc           /*Wrapper to realloc*/;
enum LV_MEM_CUSTOM_GET_SIZE =  your_mem_get_size      /*Wrapper to lv_mem_get_size*/;
} /* LV_ENABLE_GC */

/*=======================
   Input device settings
 *=======================*/

/* Input device default settings.
 * Can be changed in the Input device driver (`lv_indev_drv_t`)*/

/* Input device read period in milliseconds */
enum LV_INDEV_DEF_READ_PERIOD =          30;

/* Drag threshold in pixels */
enum LV_INDEV_DEF_DRAG_LIMIT =           10;

/* Drag throw slow-down in [%]. Greater value -> faster slow-down */
enum LV_INDEV_DEF_DRAG_THROW =           20;

/* Long press time in milliseconds.
 * Time to send `LV_EVENT_LONG_PRESSSED`) */
enum LV_INDEV_DEF_LONG_PRESS_TIME =      400;

/* Repeated trigger period in long press [ms]
 * Time between `LV_EVENT_LONG_PRESSED_REPEAT */
enum LV_INDEV_DEF_LONG_PRESS_REP_TIME =  100;

/*==================
 * Feature usage
 *==================*/

/*1: Enable the Animations */
enum LV_USE_ANIMATION =        1;
static if (LV_USE_ANIMATION) {

/*Declare the type of the user data of animations (can be e.g. `void *`, `int`, `struct`)*/
alias lv_anim_user_data_t = void*;

}

/* 1: Enable shadow drawing*/
enum LV_USE_SHADOW =           1;

/* 1: Enable object groups (for keyboard/encoder navigation) */
enum LV_USE_GROUP =            1;
static if (LV_USE_GROUP) {
alias lv_group_user_data_t = void*;
}  /*LV_USE_GROUP*/

/* 1: Enable GPU interface*/
enum LV_USE_GPU =              1;

/* 1: Enable file system (might be required for images */
enum LV_USE_FILESYSTEM =       1;
static if (LV_USE_FILESYSTEM) {
/*Declare the type of the user data of file system drivers (can be e.g. `void *`, `int`, `struct`)*/
alias lv_fs_drv_user_data_t = void*;
}

/*1: Add a `user_data` to drivers and objects*/
enum LV_USE_USER_DATA =        0;

/*========================
 * Image decoder and cache
 *========================*/

/* 1: Enable indexed (palette) images */
enum LV_IMG_CF_INDEXED =       1;

/* 1: Enable alpha indexed images */
enum LV_IMG_CF_ALPHA =         1;

/* Default image cache size. Image caching keeps the images opened.
 * If only the built-in image formats are used there is no real advantage of caching.
 * (I.e. no new image decoder is added)
 * With complex image decoders (e.g. PNG or JPG) caching can save the continuous open/decode of images.
 * However the opened images might consume additional RAM.
 * LV_IMG_CACHE_DEF_SIZE must be >= 1 */
enum LV_IMG_CACHE_DEF_SIZE =       1;

/*Declare the type of the user data of image decoder (can be e.g. `void *`, `int`, `struct`)*/
alias lv_img_decoder_user_data_t = void*;

/*=====================
 *  Compiler settings
 *====================*/
/* Define a custom attribute to `lv_tick_inc` function */
version = LV_ATTRIBUTE_TICK_INC;

/* Define a custom attribute to `lv_task_handler` function */
version = LV_ATTRIBUTE_TASK_HANDLER;

/* With size optimization (-Os) the compiler might not align data to
 * 4 or 8 byte boundary. This alignment will be explicitly applied where needed.
 * E.g. __attribute__((aligned(4))) */
version = LV_ATTRIBUTE_MEM_ALIGN;

/* Attribute to mark large constant arrays for example
 * font's bitmaps */
version = LV_ATTRIBUTE_LARGE_CONST;

/*===================
 *  HAL settings
 *==================*/

/* 1: use a custom tick source.
 * It removes the need to manually update the tick with `lv_tick_inc`) */
enum LV_TICK_CUSTOM =     0;
static if (LV_TICK_CUSTOM == 1) {
enum LV_TICK_CUSTOM_INCLUDE =  "something.h"       /*Header for the sys time function*/;
enum LV_TICK_CUSTOM_SYS_TIME_EXPR = (millis())     /*Expression evaluating to current systime in ms*/;
}   /*LV_TICK_CUSTOM*/

alias lv_disp_drv_user_data_t = void*;             /*Type of user data in the display driver*/
alias lv_indev_drv_user_data_t = void*;            /*Type of user data in the input device driver*/

/*================
 * Log settings
 *===============*/

/*1: Enable the log module*/
enum LV_USE_LOG =      0;
static if (LV_USE_LOG) {
/* How important log should be added:
 * LV_LOG_LEVEL_TRACE       A lot of logs to give detailed information
 * LV_LOG_LEVEL_INFO        Log important events
 * LV_LOG_LEVEL_WARN        Log if something unwanted happened but didn't cause a problem
 * LV_LOG_LEVEL_ERROR       Only critical issue, when the system may fail
 * LV_LOG_LEVEL_NONE        Do not log anything
 */
enum LV_LOG_LEVEL =    LV_LOG_LEVEL_WARN;

/* 1: Print the log with 'printf';
 * 0: user need to register a callback with `lv_log_register_print`*/
enum LV_LOG_PRINTF =   0;
}  /*LV_USE_LOG*/

/*================
 *  THEME USAGE
 *================*/
enum LV_THEME_LIVE_UPDATE =    0   /*1: Allow theme switching at run time. Uses 8..10 kB of RAM*/;

enum LV_USE_THEME_TEMPL =      0   /*Just for test*/;
enum LV_USE_THEME_DEFAULT =    0   /*Built mainly from the built-in styles. Consumes very few RAM*/;
enum LV_USE_THEME_ALIEN =      0   /*Dark futuristic theme*/;
enum LV_USE_THEME_NIGHT =      0   /*Dark elegant theme*/;
enum LV_USE_THEME_MONO =       0   /*Mono color theme for monochrome displays*/;
enum LV_USE_THEME_MATERIAL =   0   /*Flat theme with bold colors and light shadows*/;
enum LV_USE_THEME_ZEN =        0   /*Peaceful, mainly light theme */;
enum LV_USE_THEME_NEMO =       0   /*Water-like theme based on the movie "Finding Nemo"*/;

/*==================
 *    FONT USAGE
 *===================*/

/* The built-in fonts contains the ASCII range and some Symbols with  4 bit-per-pixel.
 * The symbols are available via `LV_SYMBOL_...` defines
 * More info about fonts: https://docs.littlevgl.com/#Fonts
 * To create a new font go to: https://littlevgl.com/ttf-font-to-c-array
 */

/* Robot fonts with bpp = 4
 * https://fonts.google.com/specimen/Roboto  */
enum LV_FONT_ROBOTO_12 =    0;
enum LV_FONT_ROBOTO_16 =    1;
enum LV_FONT_ROBOTO_22 =    0;
enum LV_FONT_ROBOTO_28 =    0;

/*Pixel perfect monospace font
 * http://pelulamu.net/unscii/ */
enum LV_FONT_UNSCII_8 =     0;

/* Optionally declare your custom fonts here.
 * You can use these fonts as default font too
 * and they will be available globally. E.g.
 * #define LV_FONT_CUSTOM_DECLARE LV_FONT_DECLARE(my_font_1) \
 *                                LV_FONT_DECLARE(my_font_2)
 */
version = LV_FONT_CUSTOM_DECLARE;

/*Always set a default font from the built-in fonts*/
enum LV_FONT_DEFAULT =        &lv_font_roboto_16;

/* Enable it if you have fonts with a lot of characters.
 * The limit depends on the font size, font face and bpp
 * but with > 10,000 characters if you see issues probably you need to enable it.*/
enum LV_FONT_FMT_TXT_LARGE =   0;

/*Declare the type of the user data of fonts (can be e.g. `void *`, `int`, `struct`)*/
alias lv_font_user_data_t = void*;

/*=================
 *  Text settings
 *=================*/

/* Select a character encoding for strings.
 * Your IDE or editor should have the same character encoding
 * - LV_TXT_ENC_UTF8
 * - LV_TXT_ENC_ASCII
 * */
enum LV_TXT_ENC = LV_TXT_ENC_UTF8;

 /*Can break (wrap) texts on these chars*/
enum LV_TXT_BREAK_CHARS =                  " ,.;:-_";

/*===================
 *  LV_OBJ SETTINGS
 *==================*/

/*Declare the type of the user data of object (can be e.g. `void *`, `int`, `struct`)*/
alias lv_obj_user_data_t = void*;

/*1: enable `lv_obj_realaign()` based on `lv_obj_align()` parameters*/
enum LV_USE_OBJ_REALIGN =          1;

/* Enable to make the object clickable on a larger area.
 * LV_EXT_CLICK_AREA_OFF or 0: Disable this feature
 * LV_EXT_CLICK_AREA_TINY: The extra area can be adjusted horizontally and vertically (0..255 px)
 * LV_EXT_CLICK_AREA_FULL: The extra area can be adjusted in all 4 directions (-32k..+32k px)
 */
enum LV_USE_EXT_CLICK_AREA =  LV_EXT_CLICK_AREA_OFF;

/*==================
 *  LV OBJ X USAGE
 *================*/
/*
 * Documentation of the object types: https://docs.littlevgl.com/#Object-types
 */

/*Arc (dependencies: -)*/
enum LV_USE_ARC =      1;

/*Bar (dependencies: -)*/
enum LV_USE_BAR =      1;

/*Button (dependencies: lv_cont*/
enum LV_USE_BTN =      1;
static if (LV_USE_BTN != 0) {
/*Enable button-state animations - draw a circle on click (dependencies: LV_USE_ANIMATION)*/
enum LV_BTN_INK_EFFECT =   0;
}

/*Button matrix (dependencies: -)*/
enum LV_USE_BTNM =     1;

/*Calendar (dependencies: -)*/
enum LV_USE_CALENDAR = 1;

/*Canvas (dependencies: lv_img)*/
enum LV_USE_CANVAS =   1;

/*Check box (dependencies: lv_btn, lv_label)*/
enum LV_USE_CB =       1;

/*Chart (dependencies: -)*/
enum LV_USE_CHART =    1;
static if (LV_USE_CHART) {
enum LV_CHART_AXIS_TICK_LABEL_MAX_LEN =    20;
}

/*Container (dependencies: -*/
enum LV_USE_CONT =     1;

/*Drop down list (dependencies: lv_page, lv_label, lv_symbol_def.h)*/
enum LV_USE_DDLIST =    1;
static if (LV_USE_DDLIST != 0) {
/*Open and close default animation time [ms] (0: no animation)*/
enum LV_DDLIST_DEF_ANIM_TIME =     200;
}

/*Gauge (dependencies:lv_bar, lv_lmeter)*/
enum LV_USE_GAUGE =    1;

/*Image (dependencies: lv_label*/
enum LV_USE_IMG =      1;

/*Image Button (dependencies: lv_btn*/
enum LV_USE_IMGBTN =   1;
static if (LV_USE_IMGBTN) {
/*1: The imgbtn requires left, mid and right parts and the width can be set freely*/
enum LV_IMGBTN_TILED = 0;
}

/*Keyboard (dependencies: lv_btnm)*/
enum LV_USE_KB =       1;

/*Label (dependencies: -*/
enum LV_USE_LABEL =    1;
static if (LV_USE_LABEL != 0) {
/*Hor, or ver. scroll speed [px/sec] in 'LV_LABEL_LONG_ROLL/ROLL_CIRC' mode*/
enum LV_LABEL_DEF_SCROLL_SPEED =       25;

/* Waiting period at beginning/end of animation cycle */
enum LV_LABEL_WAIT_CHAR_COUNT =        3;

/*Enable selecting text of the label */
enum LV_LABEL_TEXT_SEL =               0;

/*Store extra some info in labels (12 bytes) to speed up drawing of very long texts*/
enum LV_LABEL_LONG_TXT_HINT =          0;
}

/*LED (dependencies: -)*/
enum LV_USE_LED =      1;

/*Line (dependencies: -*/
enum LV_USE_LINE =     1;

/*List (dependencies: lv_page, lv_btn, lv_label, (lv_img optionally for icons ))*/
enum LV_USE_LIST =     1;
static if (LV_USE_LIST != 0) {
/*Default animation time of focusing to a list element [ms] (0: no animation)  */
enum LV_LIST_DEF_ANIM_TIME =  100;
}

/*Line meter (dependencies: *;)*/
enum LV_USE_LMETER =   1;

/*Message box (dependencies: lv_rect, lv_btnm, lv_label)*/
enum LV_USE_MBOX =     1;

/*Page (dependencies: lv_cont)*/
enum LV_USE_PAGE =     1;
static if (LV_USE_PAGE != 0) {
/*Focus default animation time [ms] (0: no animation)*/
enum LV_PAGE_DEF_ANIM_TIME =     400;
}

/*Preload (dependencies: lv_arc, lv_anim)*/
enum LV_USE_PRELOAD =      1;
static if (LV_USE_PRELOAD != 0) {
enum LV_PRELOAD_DEF_ARC_LENGTH =   60      /*[deg]*/;
enum LV_PRELOAD_DEF_SPIN_TIME =    1000    /*[ms]*/;
enum LV_PRELOAD_DEF_ANIM =         LV_PRELOAD_TYPE_SPINNING_ARC;
}

/*Roller (dependencies: lv_ddlist)*/
enum LV_USE_ROLLER =    1;
static if (LV_USE_ROLLER != 0) {
/*Focus animation time [ms] (0: no animation)*/
enum LV_ROLLER_DEF_ANIM_TIME =     200;

/*Number of extra "pages" when the roller is infinite*/
enum LV_ROLLER_INF_PAGES =         7;
}

/*Slider (dependencies: lv_bar)*/
enum LV_USE_SLIDER =    1;

/*Spinbox (dependencies: lv_ta)*/
enum LV_USE_SPINBOX =       1;

/*Switch (dependencies: lv_slider)*/
enum LV_USE_SW =       1;

/*Text area (dependencies: lv_label, lv_page)*/
enum LV_USE_TA =       1;
static if (LV_USE_TA != 0) {
enum LV_TA_DEF_CURSOR_BLINK_TIME = 400     /*ms*/;
enum LV_TA_DEF_PWD_SHOW_TIME =     1500    /*ms*/;
}

/*Table (dependencies: lv_label)*/
enum LV_USE_TABLE =    1;
static if (LV_USE_TABLE) {
enum LV_TABLE_COL_MAX =    12;
}

/*Tab (dependencies: lv_page, lv_btnm)*/
enum LV_USE_TABVIEW =      1;
static if (LV_USE_TABVIEW != 0) {
/*Time of slide animation [ms] (0: no animation)*/
enum LV_TABVIEW_DEF_ANIM_TIME =    300;
}

/*Tileview (dependencies: lv_page) */
enum LV_USE_TILEVIEW =     1;
static if (LV_USE_TILEVIEW) {
/*Time of slide animation [ms] (0: no animation)*/
enum LV_TILEVIEW_DEF_ANIM_TIME =   300;
}

/*Window (dependencies: lv_cont, lv_btn, lv_label, lv_img, lv_page)*/
enum LV_USE_WIN =      1;

/*==================
 * Non-user section
 *==================*/

static if (HasVersion!"_MSC_VER" && !HasVersion!"_CRT_SECURE_NO_WARNINGS") {    /* Disable warnings for Visual Studio*/
version = _CRT_SECURE_NO_WARNINGS;
}

/*--END OF LV_CONF_H--*/

/*Be sure every define has a default value*/
//#include "../lv_conf_checker.h"

 /*LV_CONF_H*/

} /*End of "Content enable"*/
