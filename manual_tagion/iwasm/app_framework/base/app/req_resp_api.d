module req_resp_api;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;

version (none) {
extern "C" {
//! #endif

bool wasm_response_send(const(char)* buf, int size);

void wasm_register_resource(const(char)* url);

void wasm_post_request(const(char)* buf, int size);

void wasm_sub_event(const(char)* url);

version (none) {}
}
}

 /* end of _REQ_RESP_API_H_ */
