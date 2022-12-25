module jit_codecache;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_codecache;
public import mem_alloc;
public import jit_compiler;

private void* code_cache_pool = null;
private uint code_cache_pool_size = 0;
private mem_allocator_t code_cache_pool_allocator = null;

bool jit_code_cache_init(uint code_cache_size) {
    int map_prot = MMAP_PROT_READ | MMAP_PROT_WRITE | MMAP_PROT_EXEC;
    int map_flags = MMAP_MAP_NONE;

    if (((code_cache_pool =
              os_mmap(null, code_cache_size, map_prot, map_flags)) == 0)) {
        return false;
    }

    if (((code_cache_pool_allocator =
              mem_allocator_create(code_cache_pool, code_cache_size)) == 0)) {
        os_munmap(code_cache_pool, code_cache_size);
        code_cache_pool = null;
        return false;
    }

    code_cache_pool_size = code_cache_size;
    return true;
}

void jit_code_cache_destroy() {
    mem_allocator_destroy(code_cache_pool_allocator);
    os_munmap(code_cache_pool, code_cache_pool_size);
}

void* jit_code_cache_alloc(uint size) {
    return mem_allocator_malloc(code_cache_pool_allocator, size);
}

void jit_code_cache_free(void* ptr) {
    if (ptr)
        mem_allocator_free(code_cache_pool_allocator, ptr);
}

bool jit_pass_register_jitted_code(JitCompContext* cc) {
    uint jit_func_idx = cc.cur_wasm_func_idx - cc.cur_wasm_module.import_function_count;
    cc.cur_wasm_module.fast_jit_func_ptrs[jit_func_idx] =
        cc.cur_wasm_func.fast_jit_jitted_code = cc.jitted_addr_begin;
    return true;
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;

version (none) {
extern "C" {
//! #endif

bool jit_code_cache_init(uint code_cache_size);

void jit_code_cache_destroy();

void* jit_code_cache_alloc(uint size);

void jit_code_cache_free(void* ptr);

version (none) {}
}
}

 /* end of _JIT_CODE_CACHE_H_ */
