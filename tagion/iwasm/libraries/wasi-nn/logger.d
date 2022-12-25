module logger;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdio;
public import core.stdc.string;

enum __FILENAME__ = \
    (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__);

/* Disable a level by removing the define */
version = ENABLE_ERR_LOG;
version = ENABLE_WARN_LOG;
version = ENABLE_DBG_LOG;
version = ENABLE_INFO_LOG;

// Definition of the levels
version (ENABLE_ERR_LOG) {
enum string NN_ERR_PRINTF(string fmt, ...) = `                                    \
    printf("[%s:%d] " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__); \
    printf("\n");                                                  \
    fflush(stdout)`;
} else {
//#define NN_ERR_PRINTF(fmt, ...)
}
version (ENABLE_WARN_LOG) {
enum string NN_WARN_PRINTF(string fmt, ...) = `                                   \
    printf("[%s:%d] " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__); \
    printf("\n");                                                  \
    fflush(stdout)`;
} else {
//#define NN_WARN_PRINTF(fmt, ...)
}
version (ENABLE_DBG_LOG) {
enum string NN_DBG_PRINTF(string fmt, ...) = `                                    \
    printf("[%s:%d] " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__); \
    printf("\n");                                                  \
    fflush(stdout)`;
} else {
//#define NN_DBG_PRINTF(fmt, ...)
}
version (ENABLE_INFO_LOG) {
enum string NN_INFO_PRINTF(string fmt, ...) = `                                   \
    printf("[%s:%d] " fmt, __FILENAME__, __LINE__, ##__VA_ARGS__); \
    printf("\n");                                                  \
    fflush(stdout)`;
} else {
//#define NN_INFO_PRINTF(fmt, ...)
}


