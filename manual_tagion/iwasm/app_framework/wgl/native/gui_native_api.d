module gui_native_api;
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

/**
 * gui interfaces
 */

void wasm_obj_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc);

void wasm_btn_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc);

void wasm_label_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc);

void wasm_cb_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc);

void wasm_list_native_call(wasm_exec_env_t exec_env, int func_id, uint* argv, uint argc);

version (none) {}
}
}

 /* end of _GUI_API_H_ */
