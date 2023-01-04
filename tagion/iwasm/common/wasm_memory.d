module tagion.iwasm.common.wasm_memory;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import tagion.iwasm.common.wasm_runtime_common;
public import tagion.iwasm.interpreter.wasm_runtime;
public import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.include.wasm_export;
public import tagion.iwasm.share.utils.bh_common;
public import tagion.iwasm.share.mem_alloc.mem_alloc;

enum Memory_Mode {
    MEMORY_MODE_UNKNOWN = 0,
    MEMORY_MODE_POOL,
    MEMORY_MODE_ALLOCATOR,
    MEMORY_MODE_SYSTEM_ALLOCATOR
}
alias MEMORY_MODE_UNKNOWN = Memory_Mode.MEMORY_MODE_UNKNOWN;
alias MEMORY_MODE_POOL = Memory_Mode.MEMORY_MODE_POOL;
alias MEMORY_MODE_ALLOCATOR = Memory_Mode.MEMORY_MODE_ALLOCATOR;
alias MEMORY_MODE_SYSTEM_ALLOCATOR = Memory_Mode.MEMORY_MODE_SYSTEM_ALLOCATOR;


private Memory_Mode memory_mode = MEMORY_MODE_UNKNOWN;

private mem_allocator_t pool_allocator = null;

static if (WASM_MEM_ALLOC_WITH_USER_DATA != 0) {
private void* allocator_user_data = null;
private void* function(void* user_data, uint size) malloc_func = null;
private void* function(void* user_data, void* ptr, uint size) realloc_func = null;
private void function(void* user_data, void* ptr) free_func = null;
} else {
private void* function(uint size) malloc_func = null;
private void* function(void* ptr, uint size) realloc_func = null;
private void function(void* ptr) free_func = null;
}

private uint global_pool_size;

private bool wasm_memory_init_with_pool(void* mem, uint bytes) {
    mem_allocator_t _allocator = mem_allocator_create(mem, bytes);

    if (_allocator) {
        memory_mode = MEMORY_MODE_POOL;
        pool_allocator = _allocator;
        global_pool_size = bytes;
        return true;
    }
    LOG_ERROR("Init memory with pool (%p, %u) failed.\n", mem, bytes);
    return false;
}

static if (WASM_MEM_ALLOC_WITH_USER_DATA != 0) {
private bool wasm_memory_init_with_allocator(void* _user_data, void* _malloc_func, void* _realloc_func, void* _free_func) {
    if (_malloc_func && _free_func && _malloc_func != _free_func) {
        memory_mode = MEMORY_MODE_ALLOCATOR;
        allocator_user_data = _user_data;
        malloc_func = _malloc_func;
        realloc_func = _realloc_func;
        free_func = _free_func;
        return true;
    }
    LOG_ERROR("Init memory with allocator (%p, %p, %p, %p) failed.\n",
              _user_data, _malloc_func, _realloc_func, _free_func);
    return false;
}
} else {
private bool wasm_memory_init_with_allocator(void* _malloc_func, void* _realloc_func, void* _free_func) {
    if (_malloc_func && _free_func && _malloc_func != _free_func) {
        memory_mode = MEMORY_MODE_ALLOCATOR;
        malloc_func = _malloc_func;
        realloc_func = _realloc_func;
        free_func = _free_func;
        return true;
    }
    LOG_ERROR("Init memory with allocator (%p, %p, %p) failed.\n", _malloc_func,
              _realloc_func, _free_func);
    return false;
}
}

bool wasm_runtime_memory_init(mem_alloc_type_t mem_alloc_type, const(MemAllocOption)* alloc_option) {
    if (mem_alloc_type == Alloc_With_Pool) {
        return wasm_memory_init_with_pool(alloc_option.pool.heap_buf,
                                          alloc_option.pool.heap_size);
    }
    else if (mem_alloc_type == Alloc_With_Allocator) {
static if (WASM_MEM_ALLOC_WITH_USER_DATA != 0) {
        return wasm_memory_init_with_allocator(
            alloc_option.allocator.user_data,
            alloc_option.allocator.malloc_func,
            alloc_option.allocator.realloc_func,
            alloc_option.allocator.free_func);
} else {
        return wasm_memory_init_with_allocator(
            alloc_option.allocator.malloc_func,
            alloc_option.allocator.realloc_func,
            alloc_option.allocator.free_func);
}
    }
    else if (mem_alloc_type == Alloc_With_System_Allocator) {
        memory_mode = MEMORY_MODE_SYSTEM_ALLOCATOR;
        return true;
    }
    else {
        return false;
    }
}

void wasm_runtime_memory_destroy() {
    if (memory_mode == MEMORY_MODE_POOL) {
static if (BH_ENABLE_GC_VERIFY == 0) {
        cast(void)mem_allocator_destroy(pool_allocator);
} else {
        int ret = mem_allocator_destroy(pool_allocator);
        if (ret != 0) {
            /* Memory leak detected */
            exit(-1);
        }
}
    }
    memory_mode = MEMORY_MODE_UNKNOWN;
}

uint wasm_runtime_memory_pool_size() {
    if (memory_mode == MEMORY_MODE_POOL)
        return global_pool_size;
    else
        return UINT32_MAX;
}

pragma(inline, true) private void* wasm_runtime_malloc_internal(uint size) {
    if (memory_mode == MEMORY_MODE_UNKNOWN) {
        LOG_WARNING(
            "wasm_runtime_malloc failed: memory hasn't been initialize.\n");
        return null;
    }
    else if (memory_mode == MEMORY_MODE_POOL) {
        return mem_allocator_malloc(pool_allocator, size);
    }
    else if (memory_mode == MEMORY_MODE_ALLOCATOR) {
static if (WASM_MEM_ALLOC_WITH_USER_DATA != 0) {
        return malloc_func(allocator_user_data, size);
} else {
        return malloc_func(size);
}
    }
    else {
        return os_malloc(size);
    }
}

private void* wasm_runtime_realloc_internal(void* ptr, uint size) {
    if (memory_mode == MEMORY_MODE_UNKNOWN) {
        LOG_WARNING(
            "wasm_runtime_realloc failed: memory hasn't been initialize.\n");
        return null;
    }
    if (memory_mode == MEMORY_MODE_POOL) {
        return mem_allocator_realloc(pool_allocator, ptr, size);
    }
    if (memory_mode == MEMORY_MODE_ALLOCATOR) {
        if (realloc_func) {
static if (WASM_MEM_ALLOC_WITH_USER_DATA != 0) {
            return realloc_func(allocator_user_data, ptr, size);
} else {
            return realloc_func(ptr, size);
}
		}
        else {
		return  null;
		}
    }
        return os_realloc(ptr, size);
}

pragma(inline, true) private void wasm_runtime_free_internal(void* ptr) {
    if (!ptr) {
        LOG_WARNING("warning: wasm_runtime_free with NULL pointer\n");
static if (BH_ENABLE_GC_VERIFY != 0) {
        exit(-1);
}
        return;
    }

    if (memory_mode == MEMORY_MODE_UNKNOWN) {
        LOG_WARNING("warning: wasm_runtime_free failed: "
                    ~ "memory hasn't been initialize.\n");
    }
    else if (memory_mode == MEMORY_MODE_POOL) {
        mem_allocator_free(pool_allocator, ptr);
    }
    else if (memory_mode == MEMORY_MODE_ALLOCATOR) {
static if (WASM_MEM_ALLOC_WITH_USER_DATA != 0) {
        free_func(allocator_user_data, ptr);
} else {
        free_func(ptr);
}
    }
    else {
        os_free(ptr);
    }
}

void* wasm_runtime_malloc(uint size) {
    if (size == 0) {
        LOG_WARNING("warning: wasm_runtime_malloc with size zero\n");
        /* At lease alloc 1 byte to avoid malloc failed */
        size = 1;
static if (BH_ENABLE_GC_VERIFY != 0) {
        exit(-1);
}
    }

    return wasm_runtime_malloc_internal(size);
}

void* wasm_runtime_realloc(void* ptr, uint size) {
    return wasm_runtime_realloc_internal(ptr, size);
}

void wasm_runtime_free(void* ptr) {
    wasm_runtime_free_internal(ptr);
}

bool wasm_runtime_get_mem_alloc_info(mem_alloc_info_t* mem_alloc_info) {
    if (memory_mode == MEMORY_MODE_POOL) {
        return mem_allocator_get_alloc_info(pool_allocator, mem_alloc_info);
    }
    return false;
}

bool wasm_runtime_validate_app_addr(WASMModuleInstanceCommon* module_inst_comm, uint app_offset, uint size) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMMemoryInstance* memory_inst = void;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        goto fail;
    }

    /* integer overflow check */
    if (app_offset > UINT32_MAX - size) {
        goto fail;
    }

    if (app_offset + size <= memory_inst.memory_data_size) {
        return true;
    }

fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

bool wasm_runtime_validate_app_str_addr(WASMModuleInstanceCommon* module_inst_comm, uint app_str_offset) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    uint app_end_offset = void;
    char* str = void, str_end = void;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    if (!wasm_runtime_get_app_addr_range(module_inst_comm, app_str_offset, null,
                                         &app_end_offset))
        goto fail;

    str = wasm_runtime_addr_app_to_native(module_inst_comm, app_str_offset);
    str_end = str + (app_end_offset - app_str_offset);
    while (str < str_end && *str != '\0')
        str++;
    if (str == str_end)
        goto fail;

    return true;
fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

bool wasm_runtime_validate_native_addr(WASMModuleInstanceCommon* module_inst_comm, void* native_ptr, uint size) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMMemoryInstance* memory_inst = void;
    ubyte* addr = cast(ubyte*)native_ptr;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        goto fail;
    }

    /* integer overflow check */
    if (cast(uintptr_t)addr > UINTPTR_MAX - size) {
        goto fail;
    }

    if (memory_inst.memory_data <= addr
        && addr + size <= memory_inst.memory_data_end) {
        return true;
    }

fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

void* wasm_runtime_addr_app_to_native(WASMModuleInstanceCommon* module_inst_comm, uint app_offset) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMMemoryInstance* memory_inst = void;
    ubyte* addr = void;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return null;
    }

    addr = memory_inst.memory_data + app_offset;

    if (memory_inst.memory_data <= addr && addr < memory_inst.memory_data_end)
        return addr;

    return null;
}

uint wasm_runtime_addr_native_to_app(WASMModuleInstanceCommon* module_inst_comm, void* native_ptr) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMMemoryInstance* memory_inst = void;
    ubyte* addr = cast(ubyte*)native_ptr;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return 0;
    }

    if (memory_inst.memory_data <= addr && addr < memory_inst.memory_data_end)
        return cast(uint)(addr - memory_inst.memory_data);

    return 0;
}

bool wasm_runtime_get_app_addr_range(WASMModuleInstanceCommon* module_inst_comm, uint app_offset, uint* p_app_start_offset, uint* p_app_end_offset) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMMemoryInstance* memory_inst = void;
    uint memory_data_size = void;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return false;
    }

    memory_data_size = memory_inst.memory_data_size;

    if (app_offset < memory_data_size) {
        if (p_app_start_offset)
            *p_app_start_offset = 0;
        if (p_app_end_offset)
            *p_app_end_offset = memory_data_size;
        return true;
    }

    return false;
}

bool wasm_runtime_get_native_addr_range(WASMModuleInstanceCommon* module_inst_comm, ubyte* native_ptr, ubyte** p_native_start_addr, ubyte** p_native_end_addr) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
    WASMMemoryInstance* memory_inst = void;
    ubyte* addr = cast(ubyte*)native_ptr;

    bh_assert(module_inst_comm.module_type == Wasm_Module_Bytecode
              || module_inst_comm.module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return false;
    }

    if (memory_inst.memory_data <= addr
        && addr < memory_inst.memory_data_end) {
        if (p_native_start_addr)
            *p_native_start_addr = memory_inst.memory_data;
        if (p_native_end_addr)
            *p_native_end_addr = memory_inst.memory_data_end;
        return true;
    }

    return false;
}

bool wasm_check_app_addr_and_convert(WASMModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr) {
    WASMMemoryInstance* memory_inst = wasm_get_default_memory(module_inst);
    ubyte* native_addr = void;

    if (!memory_inst) {
        goto fail;
    }

    native_addr = memory_inst.memory_data + app_buf_addr;

    /* No need to check the app_offset and buf_size if memory access
       boundary check with hardware trap is enabled */
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    if (app_buf_addr >= memory_inst.memory_data_size) {
        goto fail;
    }

    if (!is_str) {
        if (app_buf_size > memory_inst.memory_data_size - app_buf_addr) {
            goto fail;
        }
    }
    else {
        const(char)* str = void, str_end = void;

        /* The whole string must be in the linear memory */
        str = cast(const(char)*)native_addr;
        str_end = cast(const(char)*)memory_inst.memory_data_end;
        while (str < str_end && *str != '\0')
            str++;
        if (str == str_end)
            goto fail;
    }
}

    *p_native_addr = cast(void*)native_addr;
    return true;
fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

WASMMemoryInstance* wasm_get_default_memory(WASMModuleInstance* module_inst) {
    if (module_inst.memories)
        return module_inst.memories[0];
    else
        return null;
}

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
bool wasm_enlarge_memory(WASMModuleInstance* module_, uint inc_page_count) {
    WASMMemoryInstance* memory = wasm_get_default_memory(module_);
    ubyte* memory_data_old = void, memory_data_new = void, heap_data_old = void;
    uint num_bytes_per_page = void, heap_size = void, total_size_old = void;
    uint cur_page_count = void, max_page_count = void, total_page_count = void;
    ulong total_size_new = void;
    bool ret = true;

    if (!memory)
        return false;

    heap_data_old = memory.heap_data;
    heap_size = cast(uint)(memory.heap_data_end - memory.heap_data);

    memory_data_old = memory.memory_data;
    total_size_old = memory.memory_data_size;

    num_bytes_per_page = memory.num_bytes_per_page;
    cur_page_count = memory.cur_page_count;
    max_page_count = memory.max_page_count;
    total_page_count = inc_page_count + cur_page_count;
    total_size_new = num_bytes_per_page * cast(ulong)total_page_count;

    if (inc_page_count <= 0)
        /* No need to enlarge memory */
        return true;

    if (total_page_count < cur_page_count /* integer overflow */
        || total_page_count > max_page_count) {
        return false;
    }

    bh_assert(total_size_new <= 4 * cast(ulong)BH_GB);
    if (total_size_new > UINT32_MAX) {
        /* Resize to 1 page with size 4G-1 */
        num_bytes_per_page = UINT32_MAX;
        total_page_count = max_page_count = 1;
        total_size_new = UINT32_MAX;
    }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (memory.is_shared) {
        memory.num_bytes_per_page = num_bytes_per_page;
        memory.cur_page_count = total_page_count;
        memory.max_page_count = max_page_count;
        /* No need to update memory->memory_data_size as it is
           initialized with the maximum memory data size for
           shared memory */
        return true;
    }
}

    if (heap_size > 0) {
        if (mem_allocator_is_heap_corrupted(memory.heap_handle)) {
            wasm_runtime_show_app_heap_corrupted_prompt();
            return false;
        }
    }

    if (((memory_data_new =
              wasm_runtime_realloc(memory_data_old, cast(uint)total_size_new)) == 0)) {
        if (((memory_data_new = wasm_runtime_malloc(cast(uint)total_size_new)) == 0)) {
            return false;
        }
        if (memory_data_old) {
            bh_memcpy_s(memory_data_new, cast(uint)total_size_new,
                        memory_data_old, total_size_old);
            wasm_runtime_free(memory_data_old);
        }
    }

    memset(memory_data_new + total_size_old, 0,
           cast(uint)total_size_new - total_size_old);

    if (heap_size > 0) {
        if (mem_allocator_migrate(memory.heap_handle,
                                  cast(char*)heap_data_old
                                      + (memory_data_new - memory_data_old),
                                  heap_size)
            != 0) {
            /* Don't return here as memory->memory_data is obsolete and
               must be updated to be correctly used later. */
            ret = false;
        }
    }

    memory.heap_data = memory_data_new + (heap_data_old - memory_data_old);
    memory.heap_data_end = memory.heap_data + heap_size;

    memory.num_bytes_per_page = num_bytes_per_page;
    memory.cur_page_count = total_page_count;
    memory.max_page_count = max_page_count;
    memory.memory_data_size = cast(uint)total_size_new;

    memory.memory_data = memory_data_new;
    memory.memory_data_end = memory_data_new + cast(uint)total_size_new;

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 || WASM_ENABLE_AOT != 0) {
static if (UINTPTR_MAX == UINT64_MAX) {
    memory.mem_bound_check_1byte.u64 = total_size_new - 1;
    memory.mem_bound_check_2bytes.u64 = total_size_new - 2;
    memory.mem_bound_check_4bytes.u64 = total_size_new - 4;
    memory.mem_bound_check_8bytes.u64 = total_size_new - 8;
    memory.mem_bound_check_16bytes.u64 = total_size_new - 16;
} else {
    memory.mem_bound_check_1byte.u32[0] = cast(uint)total_size_new - 1;
    memory.mem_bound_check_2bytes.u32[0] = cast(uint)total_size_new - 2;
    memory.mem_bound_check_4bytes.u32[0] = cast(uint)total_size_new - 4;
    memory.mem_bound_check_8bytes.u32[0] = cast(uint)total_size_new - 8;
    memory.mem_bound_check_16bytes.u32[0] = cast(uint)total_size_new - 16;
}
}

    return ret;
}
} version (OS_ENABLE_HW_BOUND_CHECK) {
bool wasm_enlarge_memory(WASMModuleInstance* module_, uint inc_page_count) {
    WASMMemoryInstance* memory = wasm_get_default_memory(module_);
    uint num_bytes_per_page = void, total_size_old = void;
    uint cur_page_count = void, max_page_count = void, total_page_count = void;
    ulong total_size_new = void;

    if (!memory)
        return false;

    num_bytes_per_page = memory.num_bytes_per_page;
    cur_page_count = memory.cur_page_count;
    max_page_count = memory.max_page_count;
    total_size_old = num_bytes_per_page * cur_page_count;
    total_page_count = inc_page_count + cur_page_count;
    total_size_new = num_bytes_per_page * cast(ulong)total_page_count;

    if (inc_page_count <= 0)
        /* No need to enlarge memory */
        return true;

    if (total_page_count < cur_page_count /* integer overflow */
        || total_page_count > max_page_count) {
        return false;
    }

    bh_assert(total_size_new <= 4 * cast(ulong)BH_GB);
    if (total_size_new > UINT32_MAX) {
        /* Resize to 1 page with size 4G-1 */
        num_bytes_per_page = UINT32_MAX;
        total_page_count = max_page_count = 1;
        total_size_new = UINT32_MAX;
    }

version (BH_PLATFORM_WINDOWS) {
    if (!os_mem_commit(memory.memory_data_end,
                       cast(uint)total_size_new - total_size_old,
                       MMAP_PROT_READ | MMAP_PROT_WRITE)) {
        return false;
    }
}

    if (os_mprotect(memory.memory_data_end,
                    cast(uint)total_size_new - total_size_old,
                    MMAP_PROT_READ | MMAP_PROT_WRITE)
        != 0) {
version (BH_PLATFORM_WINDOWS) {
        os_mem_decommit(memory.memory_data_end,
                        cast(uint)total_size_new - total_size_old);
}
        return false;
    }

    /* The increased pages are filled with zero by the OS when os_mmap,
       no need to memset it again here */

    memory.num_bytes_per_page = num_bytes_per_page;
    memory.cur_page_count = total_page_count;
    memory.max_page_count = max_page_count;
    memory.memory_data_size = cast(uint)total_size_new;
    memory.memory_data_end = memory.memory_data + cast(uint)total_size_new;

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 || WASM_ENABLE_AOT != 0) {
    memory.mem_bound_check_1byte.u64 = total_size_new - 1;
    memory.mem_bound_check_2bytes.u64 = total_size_new - 2;
    memory.mem_bound_check_4bytes.u64 = total_size_new - 4;
    memory.mem_bound_check_8bytes.u64 = total_size_new - 8;
    memory.mem_bound_check_16bytes.u64 = total_size_new - 16;
}

    return true;
}
} /* end of OS_ENABLE_HW_BOUND_CHECK */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 


bool wasm_runtime_memory_init(mem_alloc_type_t mem_alloc_type, const(MemAllocOption)* alloc_option);

void wasm_runtime_memory_destroy();

uint wasm_runtime_memory_pool_size();

 /* end of _WASM_MEMORY_H */
