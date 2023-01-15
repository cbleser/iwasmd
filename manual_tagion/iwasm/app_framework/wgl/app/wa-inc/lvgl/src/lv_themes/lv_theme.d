module lv_theme;
@nogc nothrow:
extern(C): __gshared:
/**
 *@file lv_themes.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *    INCLUDES
 *********************/
version (LV_CONF_INCLUDE_SIMPLE) {
public import lv_conf;
} else {
public import .........lv_conf;
}

public import ...lv_core.lv_style;
public import ...lv_core.lv_group;

/*********************
 *    DEFINES
 *********************/

/**********************
 *    TYPEDEFS
 **********************/

/**
 * A theme in LittlevGL consists of many styles bound together.
 * 
 * There is a style for each object type, as well as a generic style for
 * backgrounds and panels.
 */
struct _Lv_theme_t {
    struct _Style {
        lv_style_t* scr;
        lv_style_t* bg;
        lv_style_t* panel;

static if (LV_USE_CONT != 0) {
        lv_style_t* cont;
}

static if (LV_USE_BTN != 0) {
        struct _Btn {
            lv_style_t* rel;
            lv_style_t* pr;
            lv_style_t* tgl_rel;
            lv_style_t* tgl_pr;
            lv_style_t* ina;
        }_Btn btn;
}

static if (LV_USE_IMGBTN != 0) {
        struct _Imgbtn {
            lv_style_t* rel;
            lv_style_t* pr;
            lv_style_t* tgl_rel;
            lv_style_t* tgl_pr;
            lv_style_t* ina;
        }_Imgbtn imgbtn;
}

static if (LV_USE_LABEL != 0) {
        struct _Label {
            lv_style_t* prim;
            lv_style_t* sec;
            lv_style_t* hint;
        }_Label label;
}

static if (LV_USE_IMG != 0) {
        struct _Img {
            lv_style_t* light;
            lv_style_t* dark;
        }_Img img;
}

static if (LV_USE_LINE != 0) {
        struct _Line {
            lv_style_t* decor;
        }_Line line;
}

static if (LV_USE_LED != 0) {
        lv_style_t* led;
}

static if (LV_USE_BAR != 0) {
        struct _Bar {
            lv_style_t* bg;
            lv_style_t* indic;
        }_Bar bar;
}

static if (LV_USE_SLIDER != 0) {
        struct _Slider {
            lv_style_t* bg;
            lv_style_t* indic;
            lv_style_t* knob;
        }_Slider slider;
}

static if (LV_USE_LMETER != 0) {
        lv_style_t* lmeter;
}

static if (LV_USE_GAUGE != 0) {
        lv_style_t* gauge;
}

static if (LV_USE_ARC != 0) {
        lv_style_t* arc;
}

static if (LV_USE_PRELOAD != 0) {
        lv_style_t* preload;
}

static if (LV_USE_SW != 0) {
        struct _Sw {
            lv_style_t* bg;
            lv_style_t* indic;
            lv_style_t* knob_off;
            lv_style_t* knob_on;
        }_Sw sw;
}

static if (LV_USE_CHART != 0) {
        lv_style_t* chart;
}

static if (LV_USE_CALENDAR != 0) {
        struct _Calendar {
            lv_style_t* bg;
            lv_style_t* header;
            lv_style_t* header_pr;
            lv_style_t* day_names;
            lv_style_t* highlighted_days;
            lv_style_t* inactive_days;
            lv_style_t* week_box;
            lv_style_t* today_box;
        }_Calendar calendar;
}

static if (LV_USE_CB != 0) {
        struct _Cb {
            lv_style_t* bg;
            struct _Box {
                lv_style_t* rel;
                lv_style_t* pr;
                lv_style_t* tgl_rel;
                lv_style_t* tgl_pr;
                lv_style_t* ina;
            }_Box box;
        }_Cb cb;
}

static if (LV_USE_BTNM != 0) {
        struct _Btnm {
            lv_style_t* bg;
            struct _Btn {
                lv_style_t* rel;
                lv_style_t* pr;
                lv_style_t* tgl_rel;
                lv_style_t* tgl_pr;
                lv_style_t* ina;
            }_Btn btn;
        }_Btnm btnm;
}

static if (LV_USE_KB != 0) {
        struct _Kb {
            lv_style_t* bg;
            struct _Btn {
                lv_style_t* rel;
                lv_style_t* pr;
                lv_style_t* tgl_rel;
                lv_style_t* tgl_pr;
                lv_style_t* ina;
            }_Btn btn;
        }_Kb kb;
}

static if (LV_USE_MBOX != 0) {
        struct _Mbox {
            lv_style_t* bg;
            struct _Btn {
                lv_style_t* bg;
                lv_style_t* rel;
                lv_style_t* pr;
            }_Btn btn;
        }_Mbox mbox;
}

static if (LV_USE_PAGE != 0) {
        struct _Page {
            lv_style_t* bg;
            lv_style_t* scrl;
            lv_style_t* sb;
        }_Page page;
}

static if (LV_USE_TA != 0) {
        struct _Ta {
            lv_style_t* area;
            lv_style_t* oneline;
            lv_style_t* cursor;
            lv_style_t* sb;
        }_Ta ta;
}

static if (LV_USE_SPINBOX != 0) {
        struct _Spinbox {
            lv_style_t* bg;
            lv_style_t* cursor;
            lv_style_t* sb;
        }_Spinbox spinbox;
}

static if (LV_USE_LIST) {
        struct _List {
            lv_style_t* bg;
            lv_style_t* scrl;
            lv_style_t* sb;
            struct _Btn {
                lv_style_t* rel;
                lv_style_t* pr;
                lv_style_t* tgl_rel;
                lv_style_t* tgl_pr;
                lv_style_t* ina;
            }_Btn btn;
        }_List list;
}

static if (LV_USE_DDLIST != 0) {
        struct _Ddlist {
            lv_style_t* bg;
            lv_style_t* sel;
            lv_style_t* sb;
        }_Ddlist ddlist;
}

static if (LV_USE_ROLLER != 0) {
        struct _Roller {
            lv_style_t* bg;
            lv_style_t* sel;
        }_Roller roller;
}

static if (LV_USE_TABVIEW != 0) {
        struct _Tabview {
            lv_style_t* bg;
            lv_style_t* indic;
            struct _Btn {
                lv_style_t* bg;
                lv_style_t* rel;
                lv_style_t* pr;
                lv_style_t* tgl_rel;
                lv_style_t* tgl_pr;
            }_Btn btn;
        }_Tabview tabview;
}

static if (LV_USE_TILEVIEW != 0) {
        struct _Tileview {
            lv_style_t* bg;
            lv_style_t* scrl;
            lv_style_t* sb;
        }_Tileview tileview;
}

static if (LV_USE_TABLE != 0) {
        struct _Table {
            lv_style_t* bg;
            lv_style_t* cell;
        }_Table table;
}

static if (LV_USE_WIN != 0) {
        struct _Win {
            lv_style_t* bg;
            lv_style_t* sb;
            lv_style_t* header;
            lv_style_t* content;
            struct _Btn {
                lv_style_t* rel;
                lv_style_t* pr;
            }_Btn btn;
        }_Win win;
}
    }_Style style;

static if (LV_USE_GROUP) {
    struct _Group {
        /* The `x` in the names inidicates that inconsistence becasue
         * the group related function are stored in the theme.*/
        lv_group_style_mod_cb_t style_mod_xcb;
        lv_group_style_mod_cb_t style_mod_edit_xcb;
    }_Group group;
}
}alias lv_theme_t = _Lv_theme_t;

/**********************
 *  GLOBAL PROTOTYPES
 **********************/

/**
 * Set a theme for the system.
 * From now, all the created objects will use styles from this theme by default
 * @param th pointer to theme (return value of: 'lv_theme_init_xxx()')
 */
void lv_theme_set_current(lv_theme_t* th);

/**
 * Get the current system theme.
 * @return pointer to the current system theme. NULL if not set.
 */
lv_theme_t* lv_theme_get_current();

/**********************
 *    MACROS
 **********************/

/* Returns number of styles within the `lv_theme_t` structure. */
enum LV_THEME_STYLE_COUNT = (sizeof(((lv_theme_t *)0)->style) / sizeof(lv_style_t *));

/**********************
 *     POST INCLUDE
 *********************/
public import lv_theme_templ;
public import lv_theme_default;
public import lv_theme_alien;
public import lv_theme_night;
public import lv_theme_zen;
public import lv_theme_mono;
public import lv_theme_nemo;
public import lv_theme_material;

version (none) {}
} /* extern "C" */
}

 /*LV_THEMES_H*/
