module utils;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import utils;

private const(char)* hexchars = "0123456789abcdef";

int hex(char ch) {
    if ((ch >= 'a') && (ch <= 'f'))
        return (ch - 'a' + 10);
    if ((ch >= '0') && (ch <= '9'))
        return (ch - '0');
    if ((ch >= 'A') && (ch <= 'F'))
        return (ch - 'A' + 10);
    return (-1);
}

char* mem2hex(char* mem, char* buf, int count) {
    ubyte ch = void;

    for (int i = 0; i < count; i++) {
        ch = *(mem++);
        *buf++ = hexchars[ch >> 4];
        *buf++ = hexchars[ch % 16];
    }
    *buf = 0;
    return (buf);
}

char* hex2mem(char* buf, char* mem, int count) {
    ubyte ch = void;

    for (int i = 0; i < count; i++) {
        ch = hex(*buf++) << 4;
        ch = ch + hex(*buf++);
        *(mem++) = ch;
    }
    return (mem);
}
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;

int hex(char ch);

char* mem2hex(char* mem, char* buf, int count);

char* hex2mem(char* buf, char* mem, int count);

int unescape(char* msg, int len);

 /* UTILS_H */
