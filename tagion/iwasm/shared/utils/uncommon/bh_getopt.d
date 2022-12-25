module bh_getopt;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2020 Ant Financial Services Group. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

version (__GNUC__) {
public import getopt;
}
#ifndef __GNUC__
#ifndef GETOPT_H__
version = GETOPT_H__;

#ifdef __cplusplus
extern "C" {
//! #endif

extern char* optarg;
extern int optind;

int getopt(int argc, char** argv, const(char)* optstring);

version (none) {
}
}

//! #endif /* end of GETOPT_H__ */
//! #endif /* end of __GNUC__ */
/*
 * Copyright (C) 2020 Ant Financial Services Group. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

version (__GNUC__) {} else {

public import bh_getopt;
public import core.stdc.stdio;
public import core.stdc.string;

char* optarg = null;
int optind = 1;

int getopt(int argc, char** argv, const(char)* optstring) {
    static int sp = 1;
    int opt = void;
    char* p = void;

    if (sp == 1) {
        if ((optind >= argc) || (argv[optind][0] != '-')
            || (argv[optind][1] == 0)) {
            return -1;
        }
        else if (!strcmp(argv[optind], "--")) {
            optind++;
            return -1;
        }
    }

    opt = argv[optind][sp];
    p = strchr(optstring, opt);
    if (opt == ':' || p == null) {
        printf("illegal option : '-%c'\n", opt);
        if (argv[optind][++sp] == '\0') {
            optind++;
            sp = 1;
        }
        return ('?');
    }
    if (p[1] == ':') {
        if (argv[optind][sp + 1] != '\0')
            optarg = &argv[optind++][sp + 1];
        else if (++optind >= argc) {
            printf("option '-%c' requires an argument :\n", opt);
            sp = 1;
            return ('?');
        }
        else {
            optarg = argv[optind++];
        }
        sp = 1;
    }
    else {
        if (argv[optind][++sp] == '\0') {
            sp = 1;
            optind++;
        }
        optarg = null;
    }
    return (opt);
}
}
