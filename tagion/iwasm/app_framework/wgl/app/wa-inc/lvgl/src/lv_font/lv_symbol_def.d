module lv_symbol_def;
@nogc nothrow:
extern(C): __gshared:
 
/* clang-format off */

version (none) {
extern "C" {
//! #endif
version (LV_CONF_INCLUDE_SIMPLE) {
public import lv_conf;
} else {
public import .........lv_conf;
}


enum LV_SYMBOL_AUDIO =           "\xef\x80\x81";
enum LV_SYMBOL_VIDEO =           "\xef\x80\x88";
enum LV_SYMBOL_LIST =            "\xef\x80\x8b";
enum LV_SYMBOL_OK =              "\xef\x80\x8c";
enum LV_SYMBOL_CLOSE =           "\xef\x80\x8d";
enum LV_SYMBOL_POWER =           "\xef\x80\x91";
enum LV_SYMBOL_SETTINGS =        "\xef\x80\x93";
enum LV_SYMBOL_TRASH =           "\xef\x80\x94";
enum LV_SYMBOL_HOME =            "\xef\x80\x95";
enum LV_SYMBOL_DOWNLOAD =        "\xef\x80\x99";
enum LV_SYMBOL_DRIVE =           "\xef\x80\x9c";
enum LV_SYMBOL_REFRESH =         "\xef\x80\xa1";
enum LV_SYMBOL_MUTE =            "\xef\x80\xa6";
enum LV_SYMBOL_VOLUME_MID =      "\xef\x80\xa7";
enum LV_SYMBOL_VOLUME_MAX =      "\xef\x80\xa8";
enum LV_SYMBOL_IMAGE =           "\xef\x80\xbe";
enum LV_SYMBOL_EDIT =            "\xef\x81\x80";
enum LV_SYMBOL_PREV =            "\xef\x81\x88";
enum LV_SYMBOL_PLAY =            "\xef\x81\x8b";
enum LV_SYMBOL_PAUSE =           "\xef\x81\x8c";
enum LV_SYMBOL_STOP =            "\xef\x81\x8d";
enum LV_SYMBOL_NEXT =            "\xef\x81\x91";
enum LV_SYMBOL_EJECT =           "\xef\x81\x92";
enum LV_SYMBOL_LEFT =            "\xef\x81\x93";
enum LV_SYMBOL_RIGHT =           "\xef\x81\x94";
enum LV_SYMBOL_PLUS =            "\xef\x81\xa7";
enum LV_SYMBOL_MINUS =           "\xef\x81\xa8";
enum LV_SYMBOL_WARNING =         "\xef\x81\xb1";
enum LV_SYMBOL_SHUFFLE =         "\xef\x81\xb4";
enum LV_SYMBOL_UP =              "\xef\x81\xb7";
enum LV_SYMBOL_DOWN =            "\xef\x81\xb8";
enum LV_SYMBOL_LOOP =            "\xef\x81\xb9";
enum LV_SYMBOL_DIRECTORY =       "\xef\x81\xbb";
enum LV_SYMBOL_UPLOAD =          "\xef\x82\x93";
enum LV_SYMBOL_CALL =            "\xef\x82\x95";
enum LV_SYMBOL_CUT =             "\xef\x83\x84";
enum LV_SYMBOL_COPY =            "\xef\x83\x85";
enum LV_SYMBOL_SAVE =            "\xef\x83\x87";
enum LV_SYMBOL_CHARGE =          "\xef\x83\xa7";
enum LV_SYMBOL_BELL =            "\xef\x83\xb3";
enum LV_SYMBOL_KEYBOARD =        "\xef\x84\x9c";
enum LV_SYMBOL_GPS =             "\xef\x84\xa4";
enum LV_SYMBOL_FILE =            "\xef\x85\x9b";
enum LV_SYMBOL_WIFI =            "\xef\x87\xab";
enum LV_SYMBOL_BATTERY_FULL =    "\xef\x89\x80";
enum LV_SYMBOL_BATTERY_3 =       "\xef\x89\x81";
enum LV_SYMBOL_BATTERY_2 =       "\xef\x89\x82";
enum LV_SYMBOL_BATTERY_1 =       "\xef\x89\x83";
enum LV_SYMBOL_BATTERY_EMPTY =   "\xef\x89\x84";
enum LV_SYMBOL_BLUETOOTH =       "\xef\x8a\x93";

/** Invalid symbol at (U+F8FF). If written before a string then `lv_img` will show it as a label*/
enum LV_SYMBOL_DUMMY =           "\xEF\xA3\xBF";

/*
 * The following list is generated using
 * cat src/lv_misc/lv_symbol_def.h | sed -E -n 's/^#define\s+(LV_SYMBOL_\w+).*"$/    _LV_STR_\1,/p'
 */
enum {
    _LV_STR_SYMBOL_AUDIO,
    _LV_STR_SYMBOL_VIDEO,
    _LV_STR_SYMBOL_LIST,
    _LV_STR_SYMBOL_OK,
    _LV_STR_SYMBOL_CLOSE,
    _LV_STR_SYMBOL_POWER,
    _LV_STR_SYMBOL_SETTINGS,
    _LV_STR_SYMBOL_TRASH,
    _LV_STR_SYMBOL_HOME,
    _LV_STR_SYMBOL_DOWNLOAD,
    _LV_STR_SYMBOL_DRIVE,
    _LV_STR_SYMBOL_REFRESH,
    _LV_STR_SYMBOL_MUTE,
    _LV_STR_SYMBOL_VOLUME_MID,
    _LV_STR_SYMBOL_VOLUME_MAX,
    _LV_STR_SYMBOL_IMAGE,
    _LV_STR_SYMBOL_EDIT,
    _LV_STR_SYMBOL_PREV,
    _LV_STR_SYMBOL_PLAY,
    _LV_STR_SYMBOL_PAUSE,
    _LV_STR_SYMBOL_STOP,
    _LV_STR_SYMBOL_NEXT,
    _LV_STR_SYMBOL_EJECT,
    _LV_STR_SYMBOL_LEFT,
    _LV_STR_SYMBOL_RIGHT,
    _LV_STR_SYMBOL_PLUS,
    _LV_STR_SYMBOL_MINUS,
    _LV_STR_SYMBOL_WARNING,
    _LV_STR_SYMBOL_SHUFFLE,
    _LV_STR_SYMBOL_UP,
    _LV_STR_SYMBOL_DOWN,
    _LV_STR_SYMBOL_LOOP,
    _LV_STR_SYMBOL_DIRECTORY,
    _LV_STR_SYMBOL_UPLOAD,
    _LV_STR_SYMBOL_CALL,
    _LV_STR_SYMBOL_CUT,
    _LV_STR_SYMBOL_COPY,
    _LV_STR_SYMBOL_SAVE,
    _LV_STR_SYMBOL_CHARGE,
    _LV_STR_SYMBOL_BELL,
    _LV_STR_SYMBOL_KEYBOARD,
    _LV_STR_SYMBOL_GPS,
    _LV_STR_SYMBOL_FILE,
    _LV_STR_SYMBOL_WIFI,
    _LV_STR_SYMBOL_BATTERY_FULL,
    _LV_STR_SYMBOL_BATTERY_3,
    _LV_STR_SYMBOL_BATTERY_2,
    _LV_STR_SYMBOL_BATTERY_1,
    _LV_STR_SYMBOL_BATTERY_EMPTY,
    _LV_STR_SYMBOL_BLUETOOTH,
    _LV_STR_SYMBOL_DUMMY,
};

version (none) {}
} /* extern "C" */
}


 /*LV_SYMBOL_DEF_H*/





