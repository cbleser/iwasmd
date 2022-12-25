module libc_builtin_wrapper;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_common;
public import bh_log;
public import wasm_export;
public import ...interpreter.wasm;

static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
enum strncasecmp = _strnicmp;
enum strcasecmp = _stricmp;
}

void wasm_runtime_set_exception(wasm_module_inst_t module_, const(char)* exception);

uint wasm_runtime_module_realloc(wasm_module_inst_t module_, uint ptr, uint size, void** p_native_addr);

/* clang-format off */
enum string get_module_inst(string exec_env) = ` \
    wasm_runtime_get_module_inst(exec_env)`;

enum string validate_app_addr(string offset, string size) = ` \
    wasm_runtime_validate_app_addr(module_inst, offset, size)`;

enum string validate_app_str_addr(string offset) = ` \
    wasm_runtime_validate_app_str_addr(module_inst, offset)`;

enum string validate_native_addr(string addr, string size) = ` \
    wasm_runtime_validate_native_addr(module_inst, addr, size)`;

enum string addr_app_to_native(string offset) = ` \
    wasm_runtime_addr_app_to_native(module_inst, offset)`;

enum string addr_native_to_app(string ptr) = ` \
    wasm_runtime_addr_native_to_app(module_inst, ptr)`;

enum string module_malloc(string size, string p_native_addr) = ` \
    wasm_runtime_module_malloc(module_inst, size, p_native_addr)`;

enum string module_free(string offset) = ` \
    wasm_runtime_module_free(module_inst, offset)`;
/* clang-format on */

alias out_func_t = int function(int c, void* ctx);

alias _va_list = char*;
enum string _INTSIZEOF(string n) = ` (((uint32)sizeof(n) + 3) & (uint32)~3)`;
enum string _va_arg(string ap, string t) = ` (*(t *)((ap += _INTSIZEOF(t)) - _INTSIZEOF(t)))`;

enum string CHECK_VA_ARG(string ap, string t) = `                                  \
    do {                                                     \
        if ((uint8 *)ap + _INTSIZEOF(t) > native_end_addr) { \
            if (fmt_buf != temp_fmt) {                       \
                wasm_runtime_free(fmt_buf);                  \
            }                                                \
            goto fail;                                       \
        }                                                    \
    } while (0)`;

/* clang-format off */
enum string PREPARE_TEMP_FORMAT() = `                                \
    char temp_fmt[32], *s, *fmt_buf = temp_fmt;              \
    uint32 fmt_buf_len = (uint32)sizeof(temp_fmt);           \
    int32 n;                                                 \
                                                             \
    /* additional 2 bytes: one is the format char,           \
       the other is `\0` */                                  \
    if ((uint32)(fmt - fmt_start_addr + 2) >= fmt_buf_len) { \
        bh_assert((uint32)(fmt - fmt_start_addr) <=          \
                  UINT32_MAX - 2);                           \
        fmt_buf_len = (uint32)(fmt - fmt_start_addr + 2);    \
        if (!(fmt_buf = wasm_runtime_malloc(fmt_buf_len))) { \
            print_err(out, ctx);                             \
            break;                                           \
        }                                                    \
    }                                                        \
                                                             \
    memset(fmt_buf, 0, fmt_buf_len);                         \
    bh_memcpy_s(fmt_buf, fmt_buf_len, fmt_start_addr,        \
                (uint32)(fmt - fmt_start_addr + 1));`;
/* clang-format on */

enum string OUTPUT_TEMP_FORMAT() = `            \
    do {                                \
        if (n > 0) {                    \
            s = buf;                    \
            while (*s)                  \
                out((int)(*s++), ctx);  \
        }                               \
                                        \
        if (fmt_buf != temp_fmt) {      \
            wasm_runtime_free(fmt_buf); \
        }                               \
    } while (0)`;

private void print_err(out_func_t out_, void* ctx) {
    out_('E', ctx);
    out_('R', ctx);
    out_('R', ctx);
}

private bool _vprintf_wa(out_func_t out_, void* ctx, const(char)* fmt, _va_list ap, wasm_module_inst_t module_inst) {
    int might_format = 0; /* 1 if encountered a '%' */
    int long_ctr = 0;
    ubyte* native_end_addr = void;
    const(char)* fmt_start_addr = null;

    if (!wasm_runtime_get_native_addr_range(module_inst, cast(ubyte*)ap, null,
                                            &native_end_addr))
        goto fail;

    /* fmt has already been adjusted if needed */

    while (*fmt) {
        if (!might_format) {
            if (*fmt != '%') {
                out_(cast(int)*fmt, ctx);
            }
            else {
                might_format = 1;
                long_ctr = 0;
                fmt_start_addr = fmt;
            }
        }
        else {
            switch (*fmt) {
                case '.':
                case '+':
                case '-':
                case ' ':
                case '#':
                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                    goto still_might_format;

                case 't': /* ptrdiff_t */
                case 'z': /* size_t (32bit on wasm) */
                    long_ctr = 1;
                    goto still_might_format;

                case 'j':
                    /* intmax_t/uintmax_t */
                    long_ctr = 2;
                    goto still_might_format;

                case 'l':
                    long_ctr++;
                    /* Fall through */
                case 'h':
                    /* FIXME: do nothing for these modifiers */
                    goto still_might_format;

                case 'o':
                case 'd':
                case 'i':
                case 'u':
                case 'p':
                case 'x':
                case 'X':
                case 'c':
                {
                    char[64] buf = void;
                    PREPARE_TEMP_FORMAT();

                    if (long_ctr < 2) {
                        int d = void;

                        CHECK_VA_ARG(ap, uint32);
                        d = _va_arg(ap, int32);

                        if (long_ctr == 1) {
                            uint fmt_end_idx = (uint32)(fmt - fmt_start_addr);

                            if (fmt_buf[fmt_end_idx - 1] == 'l'
                                || fmt_buf[fmt_end_idx - 1] == 'z'
                                || fmt_buf[fmt_end_idx - 1] == 't') {
                                /* The %ld, %zd and %td should be treated as
                                 * 32bit integer in wasm */
                                fmt_buf[fmt_end_idx - 1] = fmt_buf[fmt_end_idx];
                                fmt_buf[fmt_end_idx] = '\0';
                            }
                        }

                        n = snprintf(buf.ptr, buf.sizeof, fmt_buf, d);
                    }
                    else {
                        long lld = void;

                        /* Make 8-byte aligned */
                        ap = (_va_list)((cast(uintptr_t)ap + 7) & ~cast(uintptr_t)7);
                        CHECK_VA_ARG(ap, uint64);
                        lld = _va_arg(ap, int64);
                        n = snprintf(buf.ptr, buf.sizeof, fmt_buf, lld);
                    }

                    OUTPUT_TEMP_FORMAT();
                    break;
                }

                case 's':
                {
                    char[128] buf_tmp = void; char* buf = buf_tmp;
                    char* start = void;
                    uint s_offset = void, str_len = void, buf_len = void;

                    PREPARE_TEMP_FORMAT();

                    CHECK_VA_ARG(ap, int32);
                    s_offset = _va_arg(ap, uint32);

                    if (!validate_app_str_addr(s_offset)) {
                        if (fmt_buf != temp_fmt) {
                            wasm_runtime_free(fmt_buf);
                        }
                        return false;
                    }

                    s = start = addr_app_to_native(s_offset);

                    str_len = cast(uint)strlen(start);
                    if (str_len >= UINT32_MAX - 64) {
                        print_err(out_, ctx);
                        if (fmt_buf != temp_fmt) {
                            wasm_runtime_free(fmt_buf);
                        }
                        break;
                    }

                    /* reserve 64 more bytes as there may be width description
                     * in the fmt */
                    buf_len = str_len + 64;

                    if (buf_len > cast(uint)buf_tmp.sizeof) {
                        if (((buf = wasm_runtime_malloc(buf_len)) == 0)) {
                            print_err(out_, ctx);
                            if (fmt_buf != temp_fmt) {
                                wasm_runtime_free(fmt_buf);
                            }
                            break;
                        }
                    }

                    n = snprintf(buf, buf_len, fmt_buf,
                                 (s_offset == 0 && str_len == 0) ? null
                                                                 : start);

                    OUTPUT_TEMP_FORMAT();

                    if (buf != buf_tmp.ptr) {
                        wasm_runtime_free(buf);
                    }

                    break;
                }

                case '%':
                {
                    out_(cast(int)'%', ctx);
                    break;
                }

                case 'e':
                case 'E':
                case 'g':
                case 'G':
                case 'f':
                case 'F':
                {
                    float64 f64 = void;
                    char[64] buf = void;
                    PREPARE_TEMP_FORMAT();

                    /* Make 8-byte aligned */
                    ap = (_va_list)((cast(uintptr_t)ap + 7) & ~cast(uintptr_t)7);
                    CHECK_VA_ARG(ap, float64);
                    f64 = _va_arg(ap, float64);
                    n = snprintf(buf.ptr, buf.sizeof, fmt_buf, f64);

                    OUTPUT_TEMP_FORMAT();
                    break;
                }

                case 'n':
                    /* print nothing */
                    break;

                default:
                    out_(cast(int)'%', ctx);
                    out_(cast(int)*fmt, ctx);
                    break;
            }

            might_format = 0;
        }

    still_might_format:
        ++fmt;
    }
    return true;

fail:
    wasm_runtime_set_exception(module_inst, "out of bounds memory access");
    return false;
}

struct str_context {
    char* str;
    uint max;
    uint count;
}

private int sprintf_out(int c, str_context* ctx) {
    if (!ctx.str || ctx.count >= ctx.max) {
        ctx.count++;
        return c;
    }

    if (ctx.count == ctx.max - 1) {
        ctx.str[ctx.count++] = '\0';
    }
    else {
        ctx.str[ctx.count++] = cast(char)c;
    }

    return c;
}

version (BUILTIN_LIBC_BUFFERED_PRINTF) {} else {
enum BUILTIN_LIBC_BUFFERED_PRINTF = 0;
}

version (BUILTIN_LIBC_BUFFERED_PRINT_SIZE) {} else {
enum BUILTIN_LIBC_BUFFERED_PRINT_SIZE = 128;
}
 


static if (BUILTIN_LIBC_BUFFERED_PRINTF != 0) {

private BUILTIN_LIBC_BUFFERED_PRINT_PREFIX[BUILTIN_LIBC_BUFFERED_PRINT_SIZE] print_buf = 0;

private BUILTIN_LIBC_BUFFERED_PRINT_PREFIX print_buf_size = 0;

private int printf_out(int c, str_context* ctx) {
    if (c == '\n') {
        print_buf[print_buf_size] = '\0';
        os_printf("%s\n", print_buf.ptr);
        print_buf_size = 0;
    }
    else if (print_buf_size >= sizeof(print_buf).ptr - 2) {
        print_buf[print_buf_size++] = cast(char)c;
        print_buf[print_buf_size] = '\0';
        os_printf("%s\n", print_buf.ptr);
        print_buf_size = 0;
    }
    else {
        print_buf[print_buf_size++] = cast(char)c;
    }
    ctx.count++;
    return c;
}
} else {
private int printf_out(int c, str_context* ctx) {
    os_printf("%c", c);
    ctx.count++;
    return c;
}
}

private int printf_wrapper(wasm_exec_env_t exec_env, const(char)* format, _va_list va_args) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    str_context ctx = { null, 0, 0 };

    /* format has been checked by runtime */
    if (!validate_native_addr(va_args, int32.sizeof))
        return 0;

    if (!_vprintf_wa(cast(out_func_t)printf_out, &ctx, format, va_args,
                     module_inst))
        return 0;

    return cast(int)ctx.count;
}

private int sprintf_wrapper(wasm_exec_env_t exec_env, char* str, const(char)* format, _va_list va_args) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    ubyte* native_end_offset = void;
    str_context ctx = void;

    /* str and format have been checked by runtime */
    if (!validate_native_addr(va_args, uint32.sizeof))
        return 0;

    if (!wasm_runtime_get_native_addr_range(module_inst, cast(ubyte*)str, null,
                                            &native_end_offset)) {
        wasm_runtime_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    ctx.str = str;
    ctx.max = (uint32)(native_end_offset - cast(ubyte*)str);
    ctx.count = 0;

    if (!_vprintf_wa(cast(out_func_t)sprintf_out, &ctx, format, va_args,
                     module_inst))
        return 0;

    if (ctx.count < ctx.max) {
        str[ctx.count] = '\0';
    }

    return cast(int)ctx.count;
}

private int snprintf_wrapper(wasm_exec_env_t exec_env, char* str, uint size, const(char)* format, _va_list va_args) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    str_context ctx = void;

    /* str and format have been checked by runtime */
    if (!validate_native_addr(va_args, uint32.sizeof))
        return 0;

    ctx.str = str;
    ctx.max = size;
    ctx.count = 0;

    if (!_vprintf_wa(cast(out_func_t)sprintf_out, &ctx, format, va_args,
                     module_inst))
        return 0;

    if (ctx.count < ctx.max) {
        str[ctx.count] = '\0';
    }

    return cast(int)ctx.count;
}

private int puts_wrapper(wasm_exec_env_t exec_env, const(char)* str) {
    return os_printf("%s\n", str);
}

private int putchar_wrapper(wasm_exec_env_t exec_env, int c) {
    os_printf("%c", c);
    return 1;
}

private uint strdup_wrapper(wasm_exec_env_t exec_env, const(char)* str) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char* str_ret = void;
    uint len = void;
    uint str_ret_offset = 0;

    /* str has been checked by runtime */
    if (str) {
        len = cast(uint)strlen(str) + 1;

        str_ret_offset = module_malloc(len, cast(void**)&str_ret);
        if (str_ret_offset) {
            bh_memcpy_s(str_ret, len, str, len);
        }
    }

    return str_ret_offset;
}

private uint _strdup_wrapper(wasm_exec_env_t exec_env, const(char)* str) {
    return strdup_wrapper(exec_env, str);
}

private int memcmp_wrapper(wasm_exec_env_t exec_env, const(void)* s1, const(void)* s2, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    /* s2 has been checked by runtime */
    if (!validate_native_addr(cast(void*)s1, size))
        return 0;

    return memcmp(s1, s2, size);
}

private uint memcpy_wrapper(wasm_exec_env_t exec_env, void* dst, const(void)* src, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint dst_offset = addr_native_to_app(dst);

    if (size == 0)
        return dst_offset;

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return dst_offset;

    bh_memcpy_s(dst, size, src, size);
    return dst_offset;
}

private uint memmove_wrapper(wasm_exec_env_t exec_env, void* dst, void* src, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint dst_offset = addr_native_to_app(dst);

    if (size == 0)
        return dst_offset;

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return dst_offset;

    memmove(dst, src, size);
    return dst_offset;
}

private uint memset_wrapper(wasm_exec_env_t exec_env, void* s, int c, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint s_offset = addr_native_to_app(s);

    if (!validate_native_addr(s, size))
        return s_offset;

    memset(s, c, size);
    return s_offset;
}

private uint strchr_wrapper(wasm_exec_env_t exec_env, const(char)* s, int c) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char* ret = void;

    /* s has been checked by runtime */
    ret = strchr(s, c);
    return ret ? addr_native_to_app(ret) : 0;
}

private int strcmp_wrapper(wasm_exec_env_t exec_env, const(char)* s1, const(char)* s2) {
    /* s1 and s2 have been checked by runtime */
    return strcmp(s1, s2);
}

private int strncmp_wrapper(wasm_exec_env_t exec_env, const(char)* s1, const(char)* s2, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    /* s2 has been checked by runtime */
    if (!validate_native_addr(cast(void*)s1, size))
        return 0;

    return strncmp(s1, s2, size);
}

private uint strcpy_wrapper(wasm_exec_env_t exec_env, char* dst, const(char)* src) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint len = cast(uint)strlen(src) + 1;

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, len))
        return 0;

version (BH_PLATFORM_WINDOWS) {} else {
    strncpy(dst, src, len);
} version (BH_PLATFORM_WINDOWS) {
    strncpy_s(dst, len, src, len);
}
    return addr_native_to_app(dst);
}

private uint strncpy_wrapper(wasm_exec_env_t exec_env, char* dst, const(char)* src, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return 0;

version (BH_PLATFORM_WINDOWS) {} else {
    strncpy(dst, src, size);
} version (BH_PLATFORM_WINDOWS) {
    strncpy_s(dst, size, src, size);
}
    return addr_native_to_app(dst);
}

private uint strlen_wrapper(wasm_exec_env_t exec_env, const(char)* s) {
    /* s has been checked by runtime */
    return cast(uint)strlen(s);
}

private uint malloc_wrapper(wasm_exec_env_t exec_env, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    return module_malloc(size, null);
}

private uint calloc_wrapper(wasm_exec_env_t exec_env, uint nmemb, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    ulong total_size = cast(ulong)nmemb * cast(ulong)size;
    uint ret_offset = 0;
    ubyte* ret_ptr = void;

    if (total_size >= UINT32_MAX)
        return 0;

    ret_offset = module_malloc(cast(uint)total_size, cast(void**)&ret_ptr);
    if (ret_offset) {
        memset(ret_ptr, 0, cast(uint)total_size);
    }

    return ret_offset;
}

private uint realloc_wrapper(wasm_exec_env_t exec_env, uint ptr, uint new_size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    return wasm_runtime_module_realloc(module_inst, ptr, new_size, null);
}

private void free_wrapper(wasm_exec_env_t exec_env, void* ptr) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (!validate_native_addr(ptr, uint32.sizeof))
        return;

    module_free(addr_native_to_app(ptr));
}

private int atoi_wrapper(wasm_exec_env_t exec_env, const(char)* s) {
    /* s has been checked by runtime */
    return atoi(s);
}

private void exit_wrapper(wasm_exec_env_t exec_env, int status) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf = void;
    snprintf(buf.ptr, buf.sizeof, "env.exit(%" PRId32 ~ ")", status);
    wasm_runtime_set_exception(module_inst, buf.ptr);
}

private int strtol_wrapper(wasm_exec_env_t exec_env, const(char)* nptr, char** endptr, int base) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int num = 0;

    /* nptr has been checked by runtime */
    if (!validate_native_addr(endptr, uint32.sizeof))
        return 0;

    num = cast(int)strtol(nptr, endptr, base);
    *cast(uint*)endptr = addr_native_to_app(*endptr);

    return num;
}

private uint strtoul_wrapper(wasm_exec_env_t exec_env, const(char)* nptr, char** endptr, int base) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint num = 0;

    /* nptr has been checked by runtime */
    if (!validate_native_addr(endptr, uint32.sizeof))
        return 0;

    num = cast(uint)strtoul(nptr, endptr, base);
    *cast(uint*)endptr = addr_native_to_app(*endptr);

    return num;
}

private uint memchr_wrapper(wasm_exec_env_t exec_env, const(void)* s, int c, uint n) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    void* res = void;

    if (!validate_native_addr(cast(void*)s, n))
        return 0;

    res = memchr(s, c, n);
    return addr_native_to_app(res);
}

private int strncasecmp_wrapper(wasm_exec_env_t exec_env, const(char)* s1, const(char)* s2, uint n) {
    /* s1 and s2 have been checked by runtime */
    return strncasecmp(s1, s2, n);
}

private uint strspn_wrapper(wasm_exec_env_t exec_env, const(char)* s, const(char)* accept) {
    /* s and accept have been checked by runtime */
    return cast(uint)strspn(s, accept);
}

private uint strcspn_wrapper(wasm_exec_env_t exec_env, const(char)* s, const(char)* reject) {
    /* s and reject have been checked by runtime */
    return cast(uint)strcspn(s, reject);
}

private uint strstr_wrapper(wasm_exec_env_t exec_env, const(char)* s, const(char)* find) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    /* s and find have been checked by runtime */
    char* res = strstr(s, find);
    return addr_native_to_app(res);
}

private int isupper_wrapper(wasm_exec_env_t exec_env, int c) {
    return isupper(c);
}

private int isalpha_wrapper(wasm_exec_env_t exec_env, int c) {
    return isalpha(c);
}

private int isspace_wrapper(wasm_exec_env_t exec_env, int c) {
    return isspace(c);
}

private int isgraph_wrapper(wasm_exec_env_t exec_env, int c) {
    return isgraph(c);
}

private int isprint_wrapper(wasm_exec_env_t exec_env, int c) {
    return isprint(c);
}

private int isdigit_wrapper(wasm_exec_env_t exec_env, int c) {
    return isdigit(c);
}

private int isxdigit_wrapper(wasm_exec_env_t exec_env, int c) {
    return isxdigit(c);
}

private int tolower_wrapper(wasm_exec_env_t exec_env, int c) {
    return tolower(c);
}

private int toupper_wrapper(wasm_exec_env_t exec_env, int c) {
    return toupper(c);
}

private int isalnum_wrapper(wasm_exec_env_t exec_env, int c) {
    return isalnum(c);
}

private uint emscripten_memcpy_big_wrapper(wasm_exec_env_t exec_env, void* dst, const(void)* src, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint dst_offset = addr_native_to_app(dst);

    /* src has been checked by runtime */
    if (!validate_native_addr(dst, size))
        return dst_offset;

    bh_memcpy_s(dst, size, src, size);
    return dst_offset;
}

private void abort_wrapper(wasm_exec_env_t exec_env, int code) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf = void;
    snprintf(buf.ptr, buf.sizeof, "env.abort(%" PRId32 ~ ")", code);
    wasm_runtime_set_exception(module_inst, buf.ptr);
}

private void abortStackOverflow_wrapper(wasm_exec_env_t exec_env, int code) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf = void;
    snprintf(buf.ptr, buf.sizeof, "env.abortStackOverflow(%" PRId32 ~ ")", code);
    wasm_runtime_set_exception(module_inst, buf.ptr);
}

private void nullFunc_X_wrapper(wasm_exec_env_t exec_env, int code) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf = void;
    snprintf(buf.ptr, buf.sizeof, "env.nullFunc_X(%" PRId32 ~ ")", code);
    wasm_runtime_set_exception(module_inst, buf.ptr);
}

private uint __cxa_allocate_exception_wrapper(wasm_exec_env_t exec_env, uint thrown_size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint exception = module_malloc(thrown_size, null);
    if (!exception)
        return 0;

    return exception;
}

private void __cxa_begin_catch_wrapper(wasm_exec_env_t exec_env, void* exception_object) {}

private void __cxa_throw_wrapper(wasm_exec_env_t exec_env, void* thrown_exception, void* tinfo, uint table_elem_idx) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf = void;

    snprintf(buf.ptr, buf.sizeof, "%s", "exception thrown by stdc++");
    wasm_runtime_set_exception(module_inst, buf.ptr);
}

struct timespec_app {
    long tv_sec;
    int tv_nsec;
}

private uint clock_gettime_wrapper(wasm_exec_env_t exec_env, uint clk_id, timespec_app* ts_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    ulong time = void;

    if (!validate_native_addr(ts_app, timespec_app.sizeof))
        return (uint32)-1;

    time = os_time_get_boot_microsecond();
    ts_app.tv_sec = time / 1000000;
    ts_app.tv_nsec = (time % 1000000) * 1000;

    return cast(uint)0;
}

private ulong clock_wrapper(wasm_exec_env_t exec_env) {
    /* Convert to nano seconds as CLOCKS_PER_SEC in wasi-sdk */

    return os_time_get_boot_microsecond() * 1000;
}

static if (WASM_ENABLE_SPEC_TEST != 0) {
private void print_wrapper(wasm_exec_env_t exec_env) {
    os_printf("in specttest.print()\n");
}

private void print_i32_wrapper(wasm_exec_env_t exec_env, int i32) {
    os_printf("in specttest.print_i32(%" PRId32 ~ ")\n", i32);
}

private void print_i32_f32_wrapper(wasm_exec_env_t exec_env, int i32, float f32) {
    os_printf("in specttest.print_i32_f32(%" PRId32 ~ ", %f)\n", i32, f32);
}

private void print_f64_f64_wrapper(wasm_exec_env_t exec_env, double f64_1, double f64_2) {
    os_printf("in specttest.print_f64_f64(%f, %f)\n", f64_1, f64_2);
}

private void print_f32_wrapper(wasm_exec_env_t exec_env, float f32) {
    os_printf("in specttest.print_f32(%f)\n", f32);
}

private void print_f64_wrapper(wasm_exec_env_t exec_env, double f64) {
    os_printf("in specttest.print_f64(%f)\n", f64);
}
} /* WASM_ENABLE_SPEC_TEST */

/* clang-format off */
enum string REG_NATIVE_FUNC(string func_name, string signature) = ` \
    { #func_name, func_name##_wrapper, signature, NULL }`;
/* clang-format on */

private NativeSymbol[53] native_symbols_libc_builtin = [
    REG_NATIVE_FUNC(printf, "($*)i"),
    REG_NATIVE_FUNC(sprintf, "($$*)i"),
    REG_NATIVE_FUNC(snprintf, "(*~$*)i"),
    [ "vprintf", printf_wrapper, "($*)i", null ],
    [ "vsprintf", sprintf_wrapper, "($$*)i", null ],
    [ "vsnprintf", snprintf_wrapper, "(*~$*)i", null ],
    REG_NATIVE_FUNC(puts, "($)i"),
    REG_NATIVE_FUNC(putchar, "(i)i"),
    REG_NATIVE_FUNC(memcmp, "(**~)i"),
    REG_NATIVE_FUNC(memcpy, "(**~)i"),
    REG_NATIVE_FUNC(memmove, "(**~)i"),
    REG_NATIVE_FUNC(memset, "(*ii)i"),
    REG_NATIVE_FUNC(strchr, "($i)i"),
    REG_NATIVE_FUNC(strcmp, "($$)i"),
    REG_NATIVE_FUNC(strcpy, "(*$)i"),
    REG_NATIVE_FUNC(strlen, "($)i"),
    REG_NATIVE_FUNC(strncmp, "(**~)i"),
    REG_NATIVE_FUNC(strncpy, "(**~)i"),
    REG_NATIVE_FUNC(malloc, "(i)i"),
    REG_NATIVE_FUNC(realloc, "(ii)i"),
    REG_NATIVE_FUNC(calloc, "(ii)i"),
    REG_NATIVE_FUNC(strdup, "($)i"),
    /* clang may introduce __strdup */
    REG_NATIVE_FUNC(_strdup, "($)i"),
    REG_NATIVE_FUNC(free, "(*)"),
    REG_NATIVE_FUNC(atoi, "($)i"),
    REG_NATIVE_FUNC(exit, "(i)"),
    REG_NATIVE_FUNC(strtol, "($*i)i"),
    REG_NATIVE_FUNC(strtoul, "($*i)i"),
    REG_NATIVE_FUNC(memchr, "(*ii)i"),
    REG_NATIVE_FUNC(strncasecmp, "($$i)i"),
    REG_NATIVE_FUNC(strspn, "($$)i"),
    REG_NATIVE_FUNC(strcspn, "($$)i"),
    REG_NATIVE_FUNC(strstr, "($$)i"),
    REG_NATIVE_FUNC(isupper, "(i)i"),
    REG_NATIVE_FUNC(isalpha, "(i)i"),
    REG_NATIVE_FUNC(isspace, "(i)i"),
    REG_NATIVE_FUNC(isgraph, "(i)i"),
    REG_NATIVE_FUNC(isprint, "(i)i"),
    REG_NATIVE_FUNC(isdigit, "(i)i"),
    REG_NATIVE_FUNC(isxdigit, "(i)i"),
    REG_NATIVE_FUNC(tolower, "(i)i"),
    REG_NATIVE_FUNC(toupper, "(i)i"),
    REG_NATIVE_FUNC(isalnum, "(i)i"),
    REG_NATIVE_FUNC(emscripten_memcpy_big, "(**~)i"),
    REG_NATIVE_FUNC(abort, "(i)"),
    REG_NATIVE_FUNC(abortStackOverflow, "(i)"),
    REG_NATIVE_FUNC(nullFunc_X, "(i)"),
    REG_NATIVE_FUNC(__cxa_allocate_exception, "(i)i"),
    REG_NATIVE_FUNC(__cxa_begin_catch, "(*)"),
    REG_NATIVE_FUNC(__cxa_throw, "(**i)"),
    REG_NATIVE_FUNC(clock_gettime, "(i*)i"),
    REG_NATIVE_FUNC(clock, "()I"),
];

static if (WASM_ENABLE_SPEC_TEST != 0) {
private NativeSymbol[6] native_symbols_spectest = [
    REG_NATIVE_FUNC(print, "()"),
    REG_NATIVE_FUNC(print_i32, "(i)"),
    REG_NATIVE_FUNC(print_i32_f32, "(if)"),
    REG_NATIVE_FUNC(print_f64_f64, "(FF)"),
    REG_NATIVE_FUNC(print_f32, "(f)"),
    REG_NATIVE_FUNC(print_f64, "(F)")
];
}

uint get_libc_builtin_export_apis(NativeSymbol** p_libc_builtin_apis) {
    *p_libc_builtin_apis = native_symbols_libc_builtin;
    return native_symbols_libc_builtin.sizeof / NativeSymbol.sizeof;
}

static if (WASM_ENABLE_SPEC_TEST != 0) {
uint get_spectest_export_apis(NativeSymbol** p_libc_builtin_apis) {
    *p_libc_builtin_apis = native_symbols_spectest;
    return native_symbols_spectest.sizeof / NativeSymbol.sizeof;
}
}

/*************************************
 * Global Variables                  *
 *************************************/

struct WASMNativeGlobalDef {
    const(char)* module_name;
    const(char)* global_name;
    ubyte type;
    bool is_mutable;
    WASMValue value;
}

private WASMNativeGlobalDef[10] native_global_defs = [
#if WASM_ENABLE_SPEC_TEST != 0
    { "spectest", "global_i32", VALUE_TYPE_I32, false, value:i32: 666 },
    { "spectest", "global_i64", VALUE_TYPE_I64, false, value:i64: 666 },
    { "spectest", "global_f32", VALUE_TYPE_F32, false, value:f32: 666.6 },
    { "spectest", "global_f64", VALUE_TYPE_F64, false, value:f64: 666.6 },
    { "test", "global-i32", VALUE_TYPE_I32, false, value:i32: 0 },
    { "test", "global-f32", VALUE_TYPE_F32, false, value:f32: 0 },
    { "test", "global-mut-i32", VALUE_TYPE_I32, true, value:i32: 0 },
    { "test", "global-mut-i64", VALUE_TYPE_I64, true, value:i64: 0 },
#endif
    { "global", "NaN", VALUE_TYPE_F64, value:u64: 0x7FF8000000000000LL },
    { "global", "Infinity", VALUE_TYPE_F64, value:u64: 0x7FF0000000000000LL }
];

bool wasm_native_lookup_libc_builtin_global(const(char)* module_name, const(char)* global_name, WASMGlobalImport* global) {
    uint size = native_global_defs.sizeof / WASMNativeGlobalDef.sizeof;
    WASMNativeGlobalDef* global_def = native_global_defs;
    WASMNativeGlobalDef* global_def_end = global_def + size;

    if (!module_name || !global_name || !global)
        return false;

    /* Lookup constant globals which can be defined by table */
    while (global_def < global_def_end) {
        if (!strcmp(global_def.module_name, module_name)
            && !strcmp(global_def.global_name, global_name)) {
            global.type = global_def.type;
            global.is_mutable = global_def.is_mutable;
            global.global_data_linked = global_def.value;
            return true;
        }
        global_def++;
    }

    return false;
}
