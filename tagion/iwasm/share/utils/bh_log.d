module tagion.iwasm.share.utils	.bh_log;
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


import tagion.iwasm.share.utils.bh_platform;

enum _LogLevel {
    BH_LOG_LEVEL_FATAL = 0,
    BH_LOG_LEVEL_ERROR = 1,
    BH_LOG_LEVEL_WARNING = 2,
    BH_LOG_LEVEL_DEBUG = 3,
    BH_LOG_LEVEL_VERBOSE = 4
}
alias LogLevel = _LogLevel;

//void bh_log_set_verbose_level(uint level);

//void bh_log(LogLevel log_level, const(char)* file, int line, const(char)* fmt, ...);

//version (BH_PLATFORM_NUTTX) {

//}

version (BH_DEBUG) {
void LOG_FATAL(Args...)(Args args, string file=__FILE__, size_t line=__LINE__) { 
    bh_log(BH_LOG_LEVEL_FATAL, args, file, line);
}
}
else {
void LOG_FATAL(Args...)(Args args, string func=__FUNCTION__, size_t line=__LINE__) { 
    bh_log(BH_LOG_LEVEL_FATAL, args, func, line);
}
}

alias LOG_ERROR(Args...) = bh_log!Args(BH_LOG_LEVEL_ERROR);
alias LOG_WARNING(Args...) = bh_log!Args(BH_LOG_LEVEL_WARNING);
alias LOG_VERBOSE(Args...) = bh_log!Args(BH_LOG_LEVEL_VERBOSE);

version(BH_DEBUG) {
string LOG_DEBUG(Args...)(Args args, string file=__FILE__, size_t line=__LINE__) { 
    return bh_log(BH_LOG_LEVEL_DEBUG, args, file, line);
}
}
else {
string LOG_DEBUG(Args...)(Args args, string func=__FUNCTION__, size_t line=__LINE__) { 
	return null;
} 
}

void bh_print_time(const(char)* prompt);

void bh_print_proc_mem(const(char)* prompt);

void bh_log_proc_mem(const(char)* function_, uint line);

string LOG_PROC_MEM(Args...)(Args args, string func=__FUNCTION__, size_t line=__LINE__) { 
 bh_log_proc_mem(func, line);
}

//! #endif /* _BH_LOG_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


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
    t = cast(uint)(usec / 1000000) % (24 * 60 * 60);
    h = t / (60 * 60);
    t = t % (60 * 60);
    m = t / 60;
    s = t % 60;
    mills = cast(uint)(usec % 1000);

    snprintf(buf.ptr, buf.sizeof,
             "%02u:%02u:%02u:%03u", h, m, s,
             mills);

    os_printf("[%s - %X ]: ", buf.ptr, cast(uintptr_t)self);

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

    os_printf("%-48s time of last stage: %u  ms, total time: %u ms",
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
    char[128] prompt = void;
    snprintf(prompt.ptr, prompt.sizeof, "[MEM] %s(...) L%u", function_, line);
    bh_print_proc_mem(prompt.ptr);
}
