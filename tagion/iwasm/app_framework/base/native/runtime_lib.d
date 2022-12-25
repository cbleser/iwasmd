module runtime_lib;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import runtime_timer;

bool init_wasm_timer();
void exit_wasm_timer();
timer_ctx_t get_wasm_timer_ctx();
timer_ctx_t create_wasm_timer_ctx(uint module_id, int prealloc_num);
void destroy_module_timer_ctx(uint module_id);

 /* LIB_BASE_RUNTIME_LIB_H_ */
