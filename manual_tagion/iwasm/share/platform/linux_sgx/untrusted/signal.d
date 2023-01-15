module signal;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
public import core.stdc.signal;

int ocall_raise(int sig) {
    return raise(sig);
}