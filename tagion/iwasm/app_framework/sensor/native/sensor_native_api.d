module sensor_native_api;
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

bool wasm_sensor_config(wasm_exec_env_t exec_env, uint sensor, uint interval, int bit_cfg, uint delay);
uint wasm_sensor_open(wasm_exec_env_t exec_env, char* name, int instance);

bool wasm_sensor_config_with_attr_container(wasm_exec_env_t exec_env, uint sensor, char* buffer, int len);

bool wasm_sensor_close(wasm_exec_env_t exec_env, uint sensor);

version (none) {}
}
}

 /* end of _SENSOR_NATIVE_API_H_ */
