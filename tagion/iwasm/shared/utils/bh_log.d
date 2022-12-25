module bh_log;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/**
 * @file   bh_log.h
 * @date   Tue Nov  8 18:19:10 2011
 *
 * @brief This log system supports wrapping multiple outputs into one
 * log message.  This is useful for outputting variable-length logs
 * without additional memory overhead (the buffer for concatenating
 * the message), e.g. exception stack trace, which cannot be printed
 * by a single log calling without the help of an additional buffer.
 * Avoiding additional memory buffer is useful for resource-constraint
 * systems.  It can minimize the impact of log system on applications
 * and logs can be printed even when no enough memory is available.
 * Functions with prefix "_" are private functions.  Only macros that
 * are not start with "_" are exposed and can be used.
 */

#ifndef _BH_LOG_H
version = _BH_LOG_H;

public import bh_platform;

#ifdef __cplusplus
extern "C" {
//! #endif

enum _LogLevel {
    BH_LOG_LEVEL_FATAL = 0,
    BH_LOG_LEVEL_ERROR = 1,
    BH_LOG_LEVEL_WARNING = 2,
    BH_LOG_LEVEL_DEBUG = 3,
    BH_LOG_LEVEL_VERBOSE = 4
}alias LogLevel = _LogLevel;

void bh_log_set_verbose_level(uint level);

void bh_log(LogLevel log_level, const(char)* file, int line, const(char)* fmt, ...);

version (BH_PLATFORM_NUTTX) {

}

static if (BH_DEBUG != 0) {
enum string LOG_FATAL(...) = ` \
    bh_log(BH_LOG_LEVEL_FATAL, __FILE__, __LINE__, __VA_ARGS__)`;
} else {
enum string LOG_FATAL(...) = ` \
    bh_log(BH_LOG_LEVEL_FATAL, __FUNCTION__, __LINE__, __VA_ARGS__)`;
}

enum string LOG_ERROR(...) = ` bh_log(BH_LOG_LEVEL_ERROR, NULL, 0, __VA_ARGS__)`;
enum string LOG_WARNING(...) = ` bh_log(BH_LOG_LEVEL_WARNING, NULL, 0, __VA_ARGS__)`;
enum string LOG_VERBOSE(...) = ` bh_log(BH_LOG_LEVEL_VERBOSE, NULL, 0, __VA_ARGS__)`;

static if (BH_DEBUG != 0) {
enum string LOG_DEBUG(...) = ` \
    bh_log(BH_LOG_LEVEL_DEBUG, __FILE__, __LINE__, __VA_ARGS__)`;
} else {
enum string LOG_DEBUG(...) = ` (void)0`;
}

void bh_print_time(const(char)* prompt);

void bh_print_proc_mem(const(char)* prompt);

void bh_log_proc_mem(const(char)* function_, uint line);

enum string LOG_PROC_MEM(...) = ` bh_log_proc_mem(__FUNCTION__, __LINE__)`;

version (none) {
}
}

//! #endif /* _BH_LOG_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_log;

/**
 * The verbose level of the log system.  Only those verbose logs whose
 * levels are less than or equal to this value are outputed.
 */
private uint log_verbose_level = BH_LOG_LEVEL_WARNING;

void bh_log_set_verbose_level(uint level) {
    log_verbose_level = level;
}

void bh_log(LogLevel log_level, const(char)* file, int line, const(char)* fmt, ...) {
    va_list ap = void;
    korp_tid self = void;
    char[32] buf = 0;
    ulong usec = void;
    uint t = void, h = void, m = void, s = void, mills = void;

    if (cast(uint)log_level > log_verbose_level)
        return;

    self = os_self_thread();

    usec = os_time_get_boot_microsecond();
    t = (uint32)(usec / 1000000) % (24 * 60 * 60);
    h = t / (60 * 60);
    t = t % (60 * 60);
    m = t / 60;
    s = t % 60;
    mills = (uint32)(usec % 1000);

    snprintf(buf.ptr, buf.sizeof,
             "%02" PRIu32 ~ ":%02" PRIu32 ~ ":%02" PRIu32 ~ ":%03" PRIu32, h, m, s,
             mills);

    os_printf("[%s - %" PRIXPTR ~ "]: ", buf.ptr, cast(uintptr_t)self);

    if (file)
        os_printf("%s, line %d, ", file, line);

    va_start(ap, fmt);
    os_vprintf(fmt, ap);
    va_end(ap);

    os_printf("\n");
}

private uint last_time_ms = 0;
private uint total_time_ms = 0;

void bh_print_time(const(char)* prompt) {
    uint curr_time_ms = void;

    if (log_verbose_level < 3)
        return;

    curr_time_ms = cast(uint)bh_get_tick_ms();

    if (last_time_ms == 0)
        last_time_ms = curr_time_ms;

    total_time_ms += curr_time_ms - last_time_ms;

    os_printf("%-48s time of last stage: %" PRIu32 ~ " ms, total time: %" PRIu32
              ~ " ms\n",
              prompt, curr_time_ms - last_time_ms, total_time_ms);

    last_time_ms = curr_time_ms;
}

void bh_print_proc_mem(const(char)* prompt) {
    char[1024] buf = 0;

    if (log_verbose_level < BH_LOG_LEVEL_DEBUG)
        return;

    if (os_dumps_proc_mem_info(buf.ptr, buf.sizeof) != 0)
        return;

    os_printf("%s\n", prompt);
    os_printf("===== memory usage =====\n");
    os_printf("%s", buf.ptr);
    os_printf("==========\n");
    return;
}

void bh_log_proc_mem(const(char)* function_, uint line) {
    char[128] prompt = 0;
    snprintf(prompt.ptr, prompt.sizeof, "[MEM] %s(...) L%" PRIu32, function_, line);
    bh_print_proc_mem(prompt.ptr);
}
