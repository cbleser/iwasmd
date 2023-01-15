module connection_api;
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

uint wasm_open_connection(const(char)* name, char* args_buf, uint args_buf_len);

void wasm_close_connection(uint handle);

int wasm_send_on_connection(uint handle, const(char)* data, uint data_len);

bool wasm_config_connection(uint handle, const(char)* cfg_buf, uint cfg_buf_len);

version (none) {}
}
}

 /* end of CONNECTION_API_H_ */
