module timer_native_api;
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

alias timer_id_t = uint;

/*
 * timer interfaces
 */

alias timer_id_t = uint;

timer_id_t wasm_create_timer(wasm_exec_env_t exec_env, int interval, bool is_period, bool auto_start);
void wasm_timer_destroy(wasm_exec_env_t exec_env, timer_id_t timer_id);
void wasm_timer_cancel(wasm_exec_env_t exec_env, timer_id_t timer_id);
void wasm_timer_restart(wasm_exec_env_t exec_env, timer_id_t timer_id, int interval);
uint wasm_get_sys_tick_ms(wasm_exec_env_t exec_env);

version (none) {}
}
}

 /* end of _TIMER_API_H_ */
