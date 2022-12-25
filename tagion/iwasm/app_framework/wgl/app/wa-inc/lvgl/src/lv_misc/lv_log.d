module lv_log;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_log.h
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

/*********************
 *      DEFINES
 *********************/

/*Possible log level. For compatibility declare it independently from `LV_USE_LOG`*/

enum LV_LOG_LEVEL_TRACE = 0 /**< A lot of logs to give detailed information*/;
enum LV_LOG_LEVEL_INFO = 1  /**< Log important events*/;
enum LV_LOG_LEVEL_WARN = 2  /**< Log if something unwanted happened but didn't caused problem*/;
enum LV_LOG_LEVEL_ERROR = 3 /**< Only critical issue, when the system may fail*/;
enum LV_LOG_LEVEL_NONE = 4 /**< Do not log anything*/;
enum _LV_LOG_LEVEL_NUM = 5 /**< Number of log levels */;

alias lv_log_level_t = byte;

static if (LV_USE_LOG) {
/**********************
 *      TYPEDEFS
 **********************/

/**
 * Log print function. Receives "Log Level", "File path", "Line number" and "Description".
 */
alias lv_log_print_g_cb_t = void function(lv_log_level_t level, const(char)*, uint, const(char)*);

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Register custom print/write function to call when a log is added.
 * It can format its "File path", "Line number" and "Description" as required
 * and send the formatted log message to a consol or serial port.
 * @param print_cb a function pointer to print a log
 */
void lv_log_register_print_cb(lv_log_print_g_cb_t print_cb);

/**
 * Add a log
 * @param level the level of log. (From `lv_log_level_t` enum)
 * @param file name of the file when the log added
 * @param line line number in the source code where the log added
 * @param dsc description of the log
 */
void lv_log_add(lv_log_level_t level, const(char)* file, int line, const(char)* dsc);

/**********************
 *      MACROS
 **********************/

static if (LV_LOG_LEVEL <= LV_LOG_LEVEL_TRACE) {
enum string LV_LOG_TRACE(string dsc) = ` lv_log_add(LV_LOG_LEVEL_TRACE, __FILE__, __LINE__, dsc);`;
} else {
enum string LV_LOG_TRACE(string dsc) = `                                                                                              \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
}

static if (LV_LOG_LEVEL <= LV_LOG_LEVEL_INFO) {
enum string LV_LOG_INFO(string dsc) = ` lv_log_add(LV_LOG_LEVEL_INFO, __FILE__, __LINE__, dsc);`;
} else {
enum string LV_LOG_INFO(string dsc) = `                                                                                               \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
}

static if (LV_LOG_LEVEL <= LV_LOG_LEVEL_WARN) {
enum string LV_LOG_WARN(string dsc) = ` lv_log_add(LV_LOG_LEVEL_WARN, __FILE__, __LINE__, dsc);`;
} else {
enum string LV_LOG_WARN(string dsc) = `                                                                                               \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
}

static if (LV_LOG_LEVEL <= LV_LOG_LEVEL_ERROR) {
enum string LV_LOG_ERROR(string dsc) = ` lv_log_add(LV_LOG_LEVEL_ERROR, __FILE__, __LINE__, dsc);`;
} else {
enum string LV_LOG_ERROR(string dsc) = `                                                                                              \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
}

} else { /*LV_USE_LOG*/

/*Do nothing if `LV_USE_LOG  0`*/
enum string lv_log_add(string level, string file, string line, string dsc) = `                                                                             \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
enum string LV_LOG_TRACE(string dsc) = `                                                                                              \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
enum string LV_LOG_INFO(string dsc) = `                                                                                               \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
enum string LV_LOG_WARN(string dsc) = `                                                                                               \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
enum string LV_LOG_ERROR(string dsc) = `                                                                                              \
    {                                                                                                                  \
        ;                                                                                                              \
    }`;
} /*LV_USE_LOG*/

version (none) {}
} /* extern "C" */
}

 /*LV_LOG_H*/
