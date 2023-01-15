module sensor_api;
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

uint wasm_sensor_open(const(char)* name, int instance);

bool wasm_sensor_config(uint sensor, uint interval, int bit_cfg, uint delay);

bool wasm_sensor_config_with_attr_container(uint sensor, char* buffer, uint len);

bool wasm_sensor_close(uint sensor);

version (none) {}
}
}

 /* end of _SENSOR_API_H_ */
