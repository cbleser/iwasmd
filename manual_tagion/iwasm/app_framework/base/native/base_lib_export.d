module base_lib_export;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.stdio;
public import core.stdc.stdlib;
public import core.stdc.string;
public import lib_export;
public import req_resp_native_api;
public import timer_native_api;

private NativeSymbol[1] extended_native_symbol_defs = [
/* TODO: use macro EXPORT_WASM_API() or EXPORT_WASM_API2() to
   add functions to register. */
public import "base_lib.inl"
];

uint get_base_lib_export_apis(NativeSymbol** p_base_lib_apis) {
    *p_base_lib_apis = extended_native_symbol_defs;
    return extended_native_symbol_defs.sizeof / NativeSymbol.sizeof;
}
