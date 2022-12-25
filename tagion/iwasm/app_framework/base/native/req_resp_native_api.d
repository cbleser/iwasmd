module req_resp_native_api;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;
public import wasm_export;

version (none) {
extern "C" {
//! #endif

bool wasm_response_send(wasm_exec_env_t exec_env, char* buffer, int size);
void wasm_register_resource(wasm_exec_env_t exec_env, char* url);
void wasm_post_request(wasm_exec_env_t exec_env, char* buffer, int size);
void wasm_sub_event(wasm_exec_env_t exec_env, char* url);

version (none) {}
}
}

 /* end of _REQ_RESP_API_H_ */
