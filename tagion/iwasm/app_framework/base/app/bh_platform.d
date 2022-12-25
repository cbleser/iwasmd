module tagion.iwasm.app_framework.base.app.bh_platform;
@nogc nothrow:
extern(C): __gshared:


import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
alias uint8 = ubyte;
alias int8 = char;
alias uint16 = ushort;
alias int16 = short;
alias uint32 = uint;
alias int32 = int;


// all wasm-app<->native shared source files should use WA_MALLOC/WA_FREE.
// they will be mapped to different implementations in each side
version (WA_MALLOC) {} else {
enum WA_MALLOC = malloc;
}

version (WA_FREE) {} else {
enum WA_FREE = free;
}

uint htonl(uint value);
uint ntohl(uint value);
ushort htons(ushort value);
ushort ntohs(ushort value);

// We are not worried for the WASM world since the sandbox will catch it.
enum string bh_memcpy_s(string dst, string dst_len, string src, string src_len) = ` memcpy(dst, src, src_len)`;

version (NDEBUG) {
enum string bh_assert(string v) = ` (void)0`;
} else {
enum string bh_assert(string v) = `                                                     \
    do {                                                                 \
        if (!(v)) {                                                      \
            int _count;                                                  \
            printf("ASSERTION FAILED: %s, at %s, line %d", #v, __FILE__, \
                   __LINE__);                                            \
            _count = printf("\n");                                       \
            printf("%d\n", _count / (_count - 1));                       \
        }                                                                \
    } while (0)`;
}

 /* DEPS_IWASM_APP_LIBS_BASE_BH_PLATFORM_H_ */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.stdio;
public import core.stdc.stdlib;
public import core.stdc.string;

/*
 *
 *
 */

private bool is_little_endian() {
    c_long i = 0x01020304;
    ubyte* c = cast(ubyte*)&i;
    return (*c == 0x04) ? true : false;
}

private void swap32(ubyte* pData) {
    ubyte value = *pData;
    *pData = *(pData + 3);
    *(pData + 3) = value;

    value = *(pData + 1);
    *(pData + 1) = *(pData + 2);
    *(pData + 2) = value;
}

private void swap16(ubyte* pData) {
    ubyte value = *pData;
    *(pData) = *(pData + 1);
    *(pData + 1) = value;
}

uint htonl(uint value) {
    uint ret = void;
    if (is_little_endian()) {
        ret = value;
        swap32(cast(ubyte*)&ret);
        return ret;
    }

    return value;
}

uint ntohl(uint value) {
    return htonl(value);
}

ushort htons(ushort value) {
    ushort ret = void;
    if (is_little_endian()) {
        ret = value;
        swap16(cast(ubyte*)&ret);
        return ret;
    }

    return value;
}

ushort ntohs(ushort value) {
    return htons(value);
}

char* wa_strdup(const(char)* s) {
    char* s1 = null;
    if (s && (s1 = WA_MALLOC(strlen(s) + 1)))
        memcpy(s1, s, strlen(s) + 1);
    return s1;
}
