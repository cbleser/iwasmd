module bh_common;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_COMMON_H
version = _BH_COMMON_H;

public import bh_platform;

#ifdef __cplusplus
extern "C" {
//! #endif

enum string bh_memcpy_s(string dest, string dlen, string src, string slen) = `                            \
    do {                                                              \
        int _ret = slen == 0 ? 0 : b_memcpy_s(dest, dlen, src, slen); \
        (void)_ret;                                                   \
        bh_assert(_ret == 0);                                         \
    } while (0)`;

enum string bh_memcpy_wa(string dest, string dlen, string src, string slen) = `                            \
    do {                                                               \
        int _ret = slen == 0 ? 0 : b_memcpy_wa(dest, dlen, src, slen); \
        (void)_ret;                                                    \
        bh_assert(_ret == 0);                                          \
    } while (0)`;

enum string bh_memmove_s(string dest, string dlen, string src, string slen) = `                            \
    do {                                                               \
        int _ret = slen == 0 ? 0 : b_memmove_s(dest, dlen, src, slen); \
        (void)_ret;                                                    \
        bh_assert(_ret == 0);                                          \
    } while (0)`;

enum string bh_strcat_s(string dest, string dlen, string src) = `            \
    do {                                        \
        int _ret = b_strcat_s(dest, dlen, src); \
        (void)_ret;                             \
        bh_assert(_ret == 0);                   \
    } while (0)`;

enum string bh_strcpy_s(string dest, string dlen, string src) = `            \
    do {                                        \
        int _ret = b_strcpy_s(dest, dlen, src); \
        (void)_ret;                             \
        bh_assert(_ret == 0);                   \
    } while (0)`;

int b_memcpy_s(void* s1, uint s1max, const(void)* s2, uint n);
int b_memcpy_wa(void* s1, uint s1max, const(void)* s2, uint n);
int b_memmove_s(void* s1, uint s1max, const(void)* s2, uint n);
int b_strcat_s(char* s1, uint s1max, const(char)* s2);
int b_strcpy_s(char* s1, uint s1max, const(char)* s2);

/* strdup with string allocated by BH_MALLOC */
char* bh_strdup(const(char)* s);

/* strdup with string allocated by WA_MALLOC */
char* wa_strdup(const(char)* s);

version (none) {
}
}

//! #endif
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_common;

private char* align_ptr(char* src, uint b) {
    uintptr_t v = cast(uintptr_t)src;
    uintptr_t m = b - 1;
    return cast(char*)((v + m) & ~m);
}

/*
Memory copy, with word alignment
*/
int b_memcpy_wa(void* s1, uint s1max, const(void)* s2, uint n) {
    char* dest = cast(char*)s1;
    char* src = cast(char*)s2;

    char* pa = align_ptr(src, 4);
    char* pb = align_ptr((src + n), 4);

    uint buff = void;
    const(char)* p_byte_read = void;

    uint* p = void;
    char* ps = void;

    if (pa > src) {
        pa -= 4;
    }

    for (p = cast(uint*)pa; p < cast(uint*)pb; p++) {
        buff = *(p);
        p_byte_read = (cast(char*)&buff);

        /* read leading word */
        if (cast(char*)p <= src) {
            for (ps = src; ps < (cast(char*)p + 4); ps++) {
                if (ps >= src + n) {
                    break;
                }
                p_byte_read = (cast(char*)&buff) + (ps - cast(char*)p);
                *dest++ = *p_byte_read;
            }
        }
        /* read trailing word */
        else if (cast(char*)p >= pb - 4) {
            for (ps = cast(char*)p; ps < src + n; ps++) {
                *dest++ = *p_byte_read++;
            }
        }
        /* read meaning word(s) */
        else {
            if (cast(char*)p + 4 >= src + n) {
                for (ps = cast(char*)p; ps < src + n; ps++) {
                    *dest++ = *p_byte_read++;
                }
            }
            else {
                *cast(uint*)dest = buff;
                dest += 4;
            }
        }
    }

    return 0;
}

int b_memcpy_s(void* s1, uint s1max, const(void)* s2, uint n) {
    char* dest = cast(char*)s1;
    char* src = cast(char*)s2;
    if (n == 0) {
        return 0;
    }

    if (s1 == null) {
        return -1;
    }
    if (s2 == null || n > s1max) {
        memset(dest, 0, s1max);
        return -1;
    }
    memcpy(dest, src, n);
    return 0;
}

int b_memmove_s(void* s1, uint s1max, const(void)* s2, uint n) {
    char* dest = cast(char*)s1;
    char* src = cast(char*)s2;
    if (n == 0) {
        return 0;
    }

    if (s1 == null) {
        return -1;
    }
    if (s2 == null || n > s1max) {
        memset(dest, 0, s1max);
        return -1;
    }
    memmove(dest, src, n);
    return 0;
}

int b_strcat_s(char* s1, uint s1max, const(char)* s2) {
    if (null == s1 || null == s2 || s1max < (strlen(s1) + strlen(s2) + 1)) {
        return -1;
    }

    memcpy(s1 + strlen(s1), s2, strlen(s2) + 1);
    return 0;
}

int b_strcpy_s(char* s1, uint s1max, const(char)* s2) {
    if (null == s1 || null == s2 || s1max < (strlen(s2) + 1)) {
        return -1;
    }

    memcpy(s1, s2, strlen(s2) + 1);
    return 0;
}

char* bh_strdup(const(char)* s) {
    uint size = void;
    char* s1 = null;

    if (s) {
        size = (uint32)(strlen(s) + 1);
        if ((s1 = BH_MALLOC(size)))
            bh_memcpy_s(s1, size, s, size);
    }
    return s1;
}

char* wa_strdup(const(char)* s) {
    uint size = void;
    char* s1 = null;

    if (s) {
        size = (uint32)(strlen(s) + 1);
        if ((s1 = WA_MALLOC(size)))
            bh_memcpy_s(s1, size, s, size);
    }
    return s1;
}
