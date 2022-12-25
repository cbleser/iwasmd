module connection_lib_impl;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/*
 * Note:
 * This file implements the linux version connection library which is
 * defined in connection_lib.h.
 * It also provides a reference impl of connections manager.
 */

public import connection_lib;

/* clang-format off */
/*
 * Platform implementation of connection library
 */
connection_interface_t connection_impl = {
    _open: null,
    _close: null,
    _send: null,
    _config: null
};
/* clang-format on */
