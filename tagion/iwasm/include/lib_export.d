module lib_export;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdint;

version (none) {
extern "C" {
//! #endif

struct NativeSymbol {
    const(char)* symbol;
    void* func_ptr;
    const(char)* signature;
    /* attachment which can be retrieved in native API by
       calling wasm_runtime_get_function_attachment(exec_env) */
    void* attachment;
}

/* clang-format off */
enum string EXPORT_WASM_API(string symbol) = ` \
    { #symbol, (void *)symbol, NULL, NULL }`;
enum string EXPORT_WASM_API2(string symbol) = ` \
    { #symbol, (void *)symbol##_wrapper, NULL, NULL }`;

enum string EXPORT_WASM_API_WITH_SIG(string symbol, string signature) = ` \
    { #symbol, (void *)symbol, signature, NULL }`;
enum string EXPORT_WASM_API_WITH_SIG2(string symbol, string signature) = ` \
    { #symbol, (void *)symbol##_wrapper, signature, NULL }`;

enum string EXPORT_WASM_API_WITH_ATT(string symbol, string signature, string attachment) = ` \
    { #symbol, (void *)symbol, signature, attachment }`;
enum string EXPORT_WASM_API_WITH_ATT2(string symbol, string signature, string attachment) = ` \
    { #symbol, (void *)symbol##_wrapper, signature, attachment }`;
/* clang-format on */

/**
 * Get the exported APIs of base lib
 *
 * @param p_base_lib_apis return the exported API array of base lib
 *
 * @return the number of the exported API
 */
uint get_base_lib_export_apis(NativeSymbol** p_base_lib_apis);

version (none) {}
}
}

 /* end of _LIB_EXPORT_H_ */
