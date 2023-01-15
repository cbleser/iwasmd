module lv_conf_checker;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/**
 * GENERATED FILE, DO NOT EDIT IT!
 * @file lv_conf_checker.h
 * Make sure all the defines of lv_conf.h have a default value
**/

 
/* clang-format off */

public import core.stdc.stdint;

/*====================
   Graphical settings
 *====================*/

/* Maximal horizontal and vertical resolution to support by the library.*/
version (LV_HOR_RES_MAX) {} else {
enum LV_HOR_RES_MAX =          (480);
}
version (LV_VER_RES_MAX) {} else {
enum LV_VER_RES_MAX =          (320);
}

/* Color depth:
 * - 1:  1 byte per pixel
 * - 8:  RGB233
 * - 16: RGB565
 * - 32: ARGB8888
 */
version (LV_COLOR_DEPTH) {} else {
enum LV_COLOR_DEPTH =     16;
}

/* Swap the 2 bytes of RGB565 color.
 * Useful if the display has a 8 bit interface (e.g. SPI)*/
version (LV_COLOR_16_SWAP) {} else {
enum LV_COLOR_16_SWAP =   0;
}

/* 1: Enable screen transparency.
 * Useful for OSD or other overlapping GUIs.
 * Requires `LV_COLOR_DEPTH = 32` colors and the screen's style should be modified: `style.body.opa = ...`*/
version (LV_COLOR_SCREEN_TRANSP) {} else {
enum LV_COLOR_SCREEN_TRANSP =    0;
}

/*Images pixels with this color will not be drawn (with chroma keying)*/
version (LV_COLOR_TRANSP) {} else {
enum LV_COLOR_TRANSP =    LV_COLOR_LIME         /*LV_COLOR_LIME: pure green*/;
}

/* Enable anti-aliasing (lines, and radiuses will be smoothed) */
version (LV_ANTIALIAS) {} else {
enum LV_ANTIALIAS =        1;
}

/* Default display refresh period.
 * Can be changed in the display driver (`lv_disp_drv_t`).*/
version (LV_DISP_DEF_REFR_PERIOD) {} else {
enum LV_DISP_DEF_REFR_PERIOD =      30      /*[ms]*/;
}

/* Dot Per Inch: used to initialize default sizes.
 * E.g. a button with width = LV_DPI / 2 -> half inch wide
 * (Not so important, you can adjust it to modify default sizes and spaces)*/
version (LV_DPI) {} else {
enum LV_DPI =              100     /*[px]*/;
}

/* Type of coordinates. Should be `int16_t` (or `int32_t` for extreme cases) */

/*=========================
   Memory manager settings
 *=========================*/

/* LittelvGL's internal memory manager's settings.
 * The graphical objects and other related data are stored here. */

/* 1: use custom malloc/free, 0: use the built-in `lv_mem_alloc` and `lv_mem_free` */
version (LV_MEM_CUSTOM) {} else {
enum LV_MEM_CUSTOM =      0;
}
static if (LV_MEM_CUSTOM == 0) {
/* Size of the memory used by `lv_mem_alloc` in bytes (>= 2kB)*/
version (LV_MEM_SIZE) {} else {
enum LV_MEM_SIZE =    (32U * 1024U);
}

/* Complier prefix for a big array declaration */
 


/* Set an address for the memory pool instead of allocating it as an array.
 * Can be in external SRAM too. */
version (LV_MEM_ADR) {} else {
enum LV_MEM_ADR =          0;
}

/* Automatically defrag. on free. Defrag. means joining the adjacent free cells. */
version (LV_MEM_AUTO_DEFRAG) {} else {
enum LV_MEM_AUTO_DEFRAG =  1;
}
} else {       /*LV_MEM_CUSTOM*/
version (LV_MEM_CUSTOM_INCLUDE) {} else {
enum LV_MEM_CUSTOM_INCLUDE = <stdlib.h>   /*Header for the dynamic memory function*/;
}
version (LV_MEM_CUSTOM_ALLOC) {} else {
enum LV_MEM_CUSTOM_ALLOC =   malloc       /*Wrapper to malloc*/;
}
version (LV_MEM_CUSTOM_FREE) {} else {
enum LV_MEM_CUSTOM_FREE =    free         /*Wrapper to free*/;
}
}     /*LV_MEM_CUSTOM*/

/* Garbage Collector settings
 * Used if lvgl is binded to higher level language and the memory is managed by that language */
version (LV_ENABLE_GC) {} else {
enum LV_ENABLE_GC = 0;
}
static if (LV_ENABLE_GC != 0) {
version (LV_GC_INCLUDE) {} else {
enum LV_GC_INCLUDE = "gc.h"                           /*Include Garbage Collector related things*/;
}
version (LV_MEM_CUSTOM_REALLOC) {} else {
enum LV_MEM_CUSTOM_REALLOC =   your_realloc           /*Wrapper to realloc*/;
}
version (LV_MEM_CUSTOM_GET_SIZE) {} else {
enum LV_MEM_CUSTOM_GET_SIZE =  your_mem_get_size      /*Wrapper to lv_mem_get_size*/;
}
} /* LV_ENABLE_GC */

/*=======================
   Input device settings
 *=======================*/

/* Input device default settings.
 * Can be changed in the Input device driver (`lv_indev_drv_t`)*/

/* Input device read period in milliseconds */
version (LV_INDEV_DEF_READ_PERIOD) {} else {
enum LV_INDEV_DEF_READ_PERIOD =          30;
}

/* Drag threshold in pixels */
version (LV_INDEV_DEF_DRAG_LIMIT) {} else {
enum LV_INDEV_DEF_DRAG_LIMIT =           10;
}

/* Drag throw slow-down in [%]. Greater value -> faster slow-down */
version (LV_INDEV_DEF_DRAG_THROW) {} else {
enum LV_INDEV_DEF_DRAG_THROW =           20;
}

/* Long press time in milliseconds.
 * Time to send `LV_EVENT_LONG_PRESSSED`) */
version (LV_INDEV_DEF_LONG_PRESS_TIME) {} else {
enum LV_INDEV_DEF_LONG_PRESS_TIME =      400;
}

/* Repeated trigger period in long press [ms]
 * Time between `LV_EVENT_LONG_PRESSED_REPEAT */
version (LV_INDEV_DEF_LONG_PRESS_REP_TIME) {} else {
enum LV_INDEV_DEF_LONG_PRESS_REP_TIME =  100;
}

/*==================
 * Feature usage
 *==================*/

/*1: Enable the Animations */
version (LV_USE_ANIMATION) {} else {
enum LV_USE_ANIMATION =        1;
}
static if (LV_USE_ANIMATION) {

/*Declare the type of the user data of animations (can be e.g. `void *`, `int`, `struct`)*/

}

/* 1: Enable shadow drawing*/
version (LV_USE_SHADOW) {} else {
enum LV_USE_SHADOW =           1;
}

/* 1: Enable object groups (for keyboard/encoder navigation) */
version (LV_USE_GROUP) {} else {
enum LV_USE_GROUP =            1;
}
static if (LV_USE_GROUP) {
}  /*LV_USE_GROUP*/

/* 1: Enable GPU interface*/
version (LV_USE_GPU) {} else {
enum LV_USE_GPU =              1;
}

/* 1: Enable file system (might be required for images */
version (LV_USE_FILESYSTEM) {} else {
enum LV_USE_FILESYSTEM =       1;
}
static if (LV_USE_FILESYSTEM) {
/*Declare the type of the user data of file system drivers (can be e.g. `void *`, `int`, `struct`)*/
}

/*1: Add a `user_data` to drivers and objects*/
version (LV_USE_USER_DATA) {} else {
enum LV_USE_USER_DATA =        0;
}

/*========================
 * Image decoder and cache
 *========================*/

/* 1: Enable indexed (palette) images */
version (LV_IMG_CF_INDEXED) {} else {
enum LV_IMG_CF_INDEXED =       1;
}

/* 1: Enable alpha indexed images */
version (LV_IMG_CF_ALPHA) {} else {
enum LV_IMG_CF_ALPHA =         1;
}

/* Default image cache size. Image caching keeps the images opened.
 * If only the built-in image formats are used there is no real advantage of caching.
 * (I.e. no new image decoder is added)
 * With complex image decoders (e.g. PNG or JPG) caching can save the continuous open/decode of images.
 * However the opened images might consume additional RAM.
 * LV_IMG_CACHE_DEF_SIZE must be >= 1 */
version (LV_IMG_CACHE_DEF_SIZE) {} else {
enum LV_IMG_CACHE_DEF_SIZE =       1;
}

/*Declare the type of the user data of image decoder (can be e.g. `void *`, `int`, `struct`)*/

/*=====================
 *  Compiler settings
 *====================*/
/* Define a custom attribute to `lv_tick_inc` function */
 


/* Define a custom attribute to `lv_task_handler` function */
 


/* With size optimization (-Os) the compiler might not align data to
 * 4 or 8 byte boundary. This alignment will be explicitly applied where needed.
 * E.g. __attribute__((aligned(4))) */
 


/* Attribute to mark large constant arrays for example
 * font's bitmaps */
 


/*===================
 *  HAL settings
 *==================*/

/* 1: use a custom tick source.
 * It removes the need to manually update the tick with `lv_tick_inc`) */
version (LV_TICK_CUSTOM) {} else {
enum LV_TICK_CUSTOM =     0;
}
static if (LV_TICK_CUSTOM == 1) {
version (LV_TICK_CUSTOM_INCLUDE) {} else {
enum LV_TICK_CUSTOM_INCLUDE =  "something.h"       /*Header for the sys time function*/;
}
version (LV_TICK_CUSTOM_SYS_TIME_EXPR) {} else {
enum LV_TICK_CUSTOM_SYS_TIME_EXPR = (millis())     /*Expression evaluating to current systime in ms*/;
}
}   /*LV_TICK_CUSTOM*/


/*================
 * Log settings
 *===============*/

/*1: Enable the log module*/
version (LV_USE_LOG) {} else {
enum LV_USE_LOG =      0;
}
static if (LV_USE_LOG) {
/* How important log should be added:
 * LV_LOG_LEVEL_TRACE       A lot of logs to give detailed information
 * LV_LOG_LEVEL_INFO        Log important events
 * LV_LOG_LEVEL_WARN        Log if something unwanted happened but didn't cause a problem
 * LV_LOG_LEVEL_ERROR       Only critical issue, when the system may fail
 * LV_LOG_LEVEL_NONE        Do not log anything
 */
version (LV_LOG_LEVEL) {} else {
enum LV_LOG_LEVEL =    LV_LOG_LEVEL_WARN;
}

/* 1: Print the log with 'printf';
 * 0: user need to register a callback with `lv_log_register_print`*/
version (LV_LOG_PRINTF) {} else {
enum LV_LOG_PRINTF =   0;
}
}  /*LV_USE_LOG*/

/*================
 *  THEME USAGE
 *================*/
version (LV_THEME_LIVE_UPDATE) {} else {
enum LV_THEME_LIVE_UPDATE =    0   /*1: Allow theme switching at run time. Uses 8..10 kB of RAM*/;
}

version (LV_USE_THEME_TEMPL) {} else {
enum LV_USE_THEME_TEMPL =      0   /*Just for test*/;
}
version (LV_USE_THEME_DEFAULT) {} else {
enum LV_USE_THEME_DEFAULT =    0   /*Built mainly from the built-in styles. Consumes very few RAM*/;
}
version (LV_USE_THEME_ALIEN) {} else {
enum LV_USE_THEME_ALIEN =      0   /*Dark futuristic theme*/;
}
version (LV_USE_THEME_NIGHT) {} else {
enum LV_USE_THEME_NIGHT =      0   /*Dark elegant theme*/;
}
version (LV_USE_THEME_MONO) {} else {
enum LV_USE_THEME_MONO =       0   /*Mono color theme for monochrome displays*/;
}
version (LV_USE_THEME_MATERIAL) {} else {
enum LV_USE_THEME_MATERIAL =   0   /*Flat theme with bold colors and light shadows*/;
}
version (LV_USE_THEME_ZEN) {} else {
enum LV_USE_THEME_ZEN =        0   /*Peaceful, mainly light theme */;
}
version (LV_USE_THEME_NEMO) {} else {
enum LV_USE_THEME_NEMO =       0   /*Water-like theme based on the movie "Finding Nemo"*/;
}

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
version (LV_FONT_ROBOTO_12) {} else {
enum LV_FONT_ROBOTO_12 =    0;
}
version (LV_FONT_ROBOTO_16) {} else {
enum LV_FONT_ROBOTO_16 =    1;
}
version (LV_FONT_ROBOTO_22) {} else {
enum LV_FONT_ROBOTO_22 =    0;
}
version (LV_FONT_ROBOTO_28) {} else {
enum LV_FONT_ROBOTO_28 =    0;
}

/*Pixel perfect monospace font
 * http://pelulamu.net/unscii/ */
version (LV_FONT_UNSCII_8) {} else {
enum LV_FONT_UNSCII_8 =     0;
}

/* Optionally declare your custom fonts here.
 * You can use these fonts as default font too
 * and they will be available globally. E.g.
 * #define LV_FONT_CUSTOM_DECLARE LV_FONT_DECLARE(my_font_1) \
 *                                LV_FONT_DECLARE(my_font_2)
 */
 


/*Always set a default font from the built-in fonts*/
version (LV_FONT_DEFAULT) {} else {
enum LV_FONT_DEFAULT =        &lv_font_roboto_16;
}

/* Enable it if you have fonts with a lot of characters.
 * The limit depends on the font size, font face and bpp
 * but with > 10,000 characters if you see issues probably you need to enable it.*/
version (LV_FONT_FMT_TXT_LARGE) {} else {
enum LV_FONT_FMT_TXT_LARGE =   0;
}

/*Declare the type of the user data of fonts (can be e.g. `void *`, `int`, `struct`)*/

/*=================
 *  Text settings
 *=================*/

/* Select a character encoding for strings.
 * Your IDE or editor should have the same character encoding
 * - LV_TXT_ENC_UTF8
 * - LV_TXT_ENC_ASCII
 * */
version (LV_TXT_ENC) {} else {
enum LV_TXT_ENC = LV_TXT_ENC_UTF8;
}

 /*Can break (wrap) texts on these chars*/
version (LV_TXT_BREAK_CHARS) {} else {
enum LV_TXT_BREAK_CHARS =                  " ,.;:-_";
}

/*===================
 *  LV_OBJ SETTINGS
 *==================*/

/*Declare the type of the user data of object (can be e.g. `void *`, `int`, `struct`)*/

/*1: enable `lv_obj_realaign()` based on `lv_obj_align()` parameters*/
version (LV_USE_OBJ_REALIGN) {} else {
enum LV_USE_OBJ_REALIGN =          1;
}

/* Enable to make the object clickable on a larger area.
 * LV_EXT_CLICK_AREA_OFF or 0: Disable this feature
 * LV_EXT_CLICK_AREA_TINY: The extra area can be adjusted horizontally and vertically (0..255 px)
 * LV_EXT_CLICK_AREA_FULL: The extra area can be adjusted in all 4 directions (-32k..+32k px)
 */
version (LV_USE_EXT_CLICK_AREA) {} else {
enum LV_USE_EXT_CLICK_AREA =  LV_EXT_CLICK_AREA_OFF;
}

/*==================
 *  LV OBJ X USAGE
 *================*/
/*
 * Documentation of the object types: https://docs.littlevgl.com/#Object-types
 */

/*Arc (dependencies: -)*/
version (LV_USE_ARC) {} else {
enum LV_USE_ARC =      1;
}

/*Bar (dependencies: -)*/
version (LV_USE_BAR) {} else {
enum LV_USE_BAR =      1;
}

/*Button (dependencies: lv_cont*/
version (LV_USE_BTN) {} else {
enum LV_USE_BTN =      1;
}
static if (LV_USE_BTN != 0) {
/*Enable button-state animations - draw a circle on click (dependencies: LV_USE_ANIMATION)*/
version (LV_BTN_INK_EFFECT) {} else {
enum LV_BTN_INK_EFFECT =   0;
}
}

/*Button matrix (dependencies: -)*/
version (LV_USE_BTNM) {} else {
enum LV_USE_BTNM =     1;
}

/*Calendar (dependencies: -)*/
version (LV_USE_CALENDAR) {} else {
enum LV_USE_CALENDAR = 1;
}

/*Canvas (dependencies: lv_img)*/
version (LV_USE_CANVAS) {} else {
enum LV_USE_CANVAS =   1;
}

/*Check box (dependencies: lv_btn, lv_label)*/
version (LV_USE_CB) {} else {
enum LV_USE_CB =       1;
}

/*Chart (dependencies: -)*/
version (LV_USE_CHART) {} else {
enum LV_USE_CHART =    1;
}
static if (LV_USE_CHART) {
version (LV_CHART_AXIS_TICK_LABEL_MAX_LEN) {} else {
enum LV_CHART_AXIS_TICK_LABEL_MAX_LEN =    20;
}
}

/*Container (dependencies: -*/
version (LV_USE_CONT) {} else {
enum LV_USE_CONT =     1;
}

/*Drop down list (dependencies: lv_page, lv_label, lv_symbol_def.h)*/
version (LV_USE_DDLIST) {} else {
enum LV_USE_DDLIST =    1;
}
static if (LV_USE_DDLIST != 0) {
/*Open and close default animation time [ms] (0: no animation)*/
version (LV_DDLIST_DEF_ANIM_TIME) {} else {
enum LV_DDLIST_DEF_ANIM_TIME =     200;
}
}

/*Gauge (dependencies:lv_bar, lv_lmeter)*/
version (LV_USE_GAUGE) {} else {
enum LV_USE_GAUGE =    1;
}

/*Image (dependencies: lv_label*/
version (LV_USE_IMG) {} else {
enum LV_USE_IMG =      1;
}

/*Image Button (dependencies: lv_btn*/
version (LV_USE_IMGBTN) {} else {
enum LV_USE_IMGBTN =   1;
}
static if (LV_USE_IMGBTN) {
/*1: The imgbtn requires left, mid and right parts and the width can be set freely*/
version (LV_IMGBTN_TILED) {} else {
enum LV_IMGBTN_TILED = 0;
}
}

/*Keyboard (dependencies: lv_btnm)*/
version (LV_USE_KB) {} else {
enum LV_USE_KB =       1;
}

/*Label (dependencies: -*/
version (LV_USE_LABEL) {} else {
enum LV_USE_LABEL =    1;
}
static if (LV_USE_LABEL != 0) {
/*Hor, or ver. scroll speed [px/sec] in 'LV_LABEL_LONG_ROLL/ROLL_CIRC' mode*/
version (LV_LABEL_DEF_SCROLL_SPEED) {} else {
enum LV_LABEL_DEF_SCROLL_SPEED =       25;
}

/* Waiting period at beginning/end of animation cycle */
version (LV_LABEL_WAIT_CHAR_COUNT) {} else {
enum LV_LABEL_WAIT_CHAR_COUNT =        3;
}

/*Enable selecting text of the label */
version (LV_LABEL_TEXT_SEL) {} else {
enum LV_LABEL_TEXT_SEL =               0;
}

/*Store extra some info in labels (12 bytes) to speed up drawing of very long texts*/
version (LV_LABEL_LONG_TXT_HINT) {} else {
enum LV_LABEL_LONG_TXT_HINT =          0;
}
}

/*LED (dependencies: -)*/
version (LV_USE_LED) {} else {
enum LV_USE_LED =      1;
}

/*Line (dependencies: -*/
version (LV_USE_LINE) {} else {
enum LV_USE_LINE =     1;
}

/*List (dependencies: lv_page, lv_btn, lv_label, (lv_img optionally for icons ))*/
version (LV_USE_LIST) {} else {
enum LV_USE_LIST =     1;
}
static if (LV_USE_LIST != 0) {
/*Default animation time of focusing to a list element [ms] (0: no animation)  */
version (LV_LIST_DEF_ANIM_TIME) {} else {
enum LV_LIST_DEF_ANIM_TIME =  100;
}
}

/*Line meter (dependencies: *;)*/
version (LV_USE_LMETER) {} else {
enum LV_USE_LMETER =   1;
}

/*Message box (dependencies: lv_rect, lv_btnm, lv_label)*/
version (LV_USE_MBOX) {} else {
enum LV_USE_MBOX =     1;
}

/*Page (dependencies: lv_cont)*/
version (LV_USE_PAGE) {} else {
enum LV_USE_PAGE =     1;
}
static if (LV_USE_PAGE != 0) {
/*Focus default animation time [ms] (0: no animation)*/
version (LV_PAGE_DEF_ANIM_TIME) {} else {
enum LV_PAGE_DEF_ANIM_TIME =     400;
}
}

/*Preload (dependencies: lv_arc, lv_anim)*/
version (LV_USE_PRELOAD) {} else {
enum LV_USE_PRELOAD =      1;
}
static if (LV_USE_PRELOAD != 0) {
version (LV_PRELOAD_DEF_ARC_LENGTH) {} else {
enum LV_PRELOAD_DEF_ARC_LENGTH =   60      /*[deg]*/;
}
version (LV_PRELOAD_DEF_SPIN_TIME) {} else {
enum LV_PRELOAD_DEF_SPIN_TIME =    1000    /*[ms]*/;
}
version (LV_PRELOAD_DEF_ANIM) {} else {
enum LV_PRELOAD_DEF_ANIM =         LV_PRELOAD_TYPE_SPINNING_ARC;
}
}

/*Roller (dependencies: lv_ddlist)*/
version (LV_USE_ROLLER) {} else {
enum LV_USE_ROLLER =    1;
}
static if (LV_USE_ROLLER != 0) {
/*Focus animation time [ms] (0: no animation)*/
version (LV_ROLLER_DEF_ANIM_TIME) {} else {
enum LV_ROLLER_DEF_ANIM_TIME =     200;
}

/*Number of extra "pages" when the roller is infinite*/
version (LV_ROLLER_INF_PAGES) {} else {
enum LV_ROLLER_INF_PAGES =         7;
}
}

/*Slider (dependencies: lv_bar)*/
version (LV_USE_SLIDER) {} else {
enum LV_USE_SLIDER =    1;
}

/*Spinbox (dependencies: lv_ta)*/
version (LV_USE_SPINBOX) {} else {
enum LV_USE_SPINBOX =       1;
}

/*Switch (dependencies: lv_slider)*/
version (LV_USE_SW) {} else {
enum LV_USE_SW =       1;
}

/*Text area (dependencies: lv_label, lv_page)*/
version (LV_USE_TA) {} else {
enum LV_USE_TA =       1;
}
static if (LV_USE_TA != 0) {
version (LV_TA_DEF_CURSOR_BLINK_TIME) {} else {
enum LV_TA_DEF_CURSOR_BLINK_TIME = 400     /*ms*/;
}
version (LV_TA_DEF_PWD_SHOW_TIME) {} else {
enum LV_TA_DEF_PWD_SHOW_TIME =     1500    /*ms*/;
}
}

/*Table (dependencies: lv_label)*/
version (LV_USE_TABLE) {} else {
enum LV_USE_TABLE =    1;
}
static if (LV_USE_TABLE) {
version (LV_TABLE_COL_MAX) {} else {
enum LV_TABLE_COL_MAX =    12;
}
}

/*Tab (dependencies: lv_page, lv_btnm)*/
version (LV_USE_TABVIEW) {} else {
enum LV_USE_TABVIEW =      1;
}
static if (LV_USE_TABVIEW != 0) {
/*Time of slide animation [ms] (0: no animation)*/
version (LV_TABVIEW_DEF_ANIM_TIME) {} else {
enum LV_TABVIEW_DEF_ANIM_TIME =    300;
}
}

/*Tileview (dependencies: lv_page) */
version (LV_USE_TILEVIEW) {} else {
enum LV_USE_TILEVIEW =     1;
}
static if (LV_USE_TILEVIEW) {
/*Time of slide animation [ms] (0: no animation)*/
version (LV_TILEVIEW_DEF_ANIM_TIME) {} else {
enum LV_TILEVIEW_DEF_ANIM_TIME =   300;
}
}

/*Window (dependencies: lv_cont, lv_btn, lv_label, lv_img, lv_page)*/
version (LV_USE_WIN) {} else {
enum LV_USE_WIN =      1;
}

/*==================
 * Non-user section
 *==================*/

static if (HasVersion!"_MSC_VER" && !HasVersion!"_CRT_SECURE_NO_WARNINGS") {    /* Disable warnings for Visual Studio*/
 

}


  /*LV_CONF_CHECKER_H*/
