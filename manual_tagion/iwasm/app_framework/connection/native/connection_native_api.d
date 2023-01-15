module connection_native_api;
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

/*
 * connection interfaces
 */

uint wasm_open_connection(wasm_exec_env_t exec_env, char* name, char* args_buf, uint len);
void wasm_close_connection(wasm_exec_env_t exec_env, uint handle);
int wasm_send_on_connection(wasm_exec_env_t exec_env, uint handle, char* data, uint len);
bool wasm_config_connection(wasm_exec_env_t exec_env, uint handle, char* cfg_buf, uint len);

version (none) {}
}
}

 /* end of CONNECTION_API_H_ */
