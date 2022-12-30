module tagion.iwasm.interpreter.wasm_runtime;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.interpreter.wasm_loader;
import tagion.iwasm.interpreter.wasm_interp;
public import bh_common;
public import bh_log;
public import mem_alloc;
public import tagion.iwasm.common.wasm_runtime_common;
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
public import tagion.iwasm.common.wasm_shared_memory;
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
public import tagion.iwasm.libraries.thread_mgr.thread_manager;
}
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
public import tagion.iwasm.libraries.debug_engine.debug_engine;
}
static if (WASM_ENABLE_FAST_JIT != 0) {
public import tagion.iwasm.fast_jit.jit_compiler;
}
static if (WASM_ENABLE_JIT != 0) {
public import tagion.iwasm.aot.aot_runtime;
}

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null) {
        snprintf(error_buf, error_buf_size,
                 "WASM module instantiate failed: %s", string);
    }
}

private void set_error_buf_v(char* error_buf, uint error_buf_size, const(char)* format, ...) {
    va_list args = void;
    char[128] buf = void;

    if (error_buf != null) {
        va_start(args, format);
        vsnprintf(buf.ptr, buf.sizeof, format, args);
        va_end(args);
        snprintf(error_buf, error_buf_size,
                 "WASM module instantiate failed: %s", buf.ptr);
    }
}

WASMModule* wasm_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size) {
	return wasm_loader_load(buf, size,
(WASM_ENABLE_MULTI_MODULE != 0),
                            error_buf, error_buf_size);
}

WASMModule* wasm_load_from_sections(WASMSection* section_list, char* error_buf, uint error_buf_size) {
    return wasm_loader_load_from_sections(section_list, error_buf,
                                          error_buf_size);
}

void wasm_unload(WASMModule* module_) {
    wasm_loader_unload(module_);
}

private void* runtime_malloc(ulong size, char* error_buf, uint error_buf_size) {
    void* mem = void;

    if (size >= UINT32_MAX || ((mem = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return null;
    }

    memset(mem, 0, cast(uint)size);
    return mem;
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
private WASMModuleInstance* get_sub_module_inst(const(WASMModuleInstance)* parent_module_inst, const(WASMModule)* sub_module) {
    bh_list* sub_module_inst_list = parent_module_inst.e.sub_module_inst_list;
    WASMSubModInstNode* node = bh_list_first_elem(sub_module_inst_list);

    while (node && sub_module != node.module_inst.module_) {
        node = bh_list_elem_next(node);
    }
    return node ? node.module_inst : null;
}
}

/**
 * Destroy memory instances.
 */
private void memories_deinstantiate(WASMModuleInstance* module_inst, WASMMemoryInstance** memories, uint count) {
    uint i = void;
    if (memories) {
        for (i = 0; i < count; i++) {
            if (memories[i]) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
                WASMModule* module_ = module_inst.module_;
                if (i < module_.import_memory_count
                    && module_.import_memories[i].u.memory.import_module) {
                    continue;
                }
}
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
                if (memories[i].is_shared) {
                    int ref_count = shared_memory_dec_reference(
                        cast(WASMModuleCommon*)module_inst.module_);
                    bh_assert(ref_count >= 0);

                    /* if the reference count is not zero,
                        don't free the memory */
                    if (ref_count > 0)
                        continue;
                }
}
                if (memories[i].heap_handle) {
                    mem_allocator_destroy(memories[i].heap_handle);
                    wasm_runtime_free(memories[i].heap_handle);
                    memories[i].heap_handle = null;
                }
                if (memories[i].memory_data) {
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
                    wasm_runtime_free(memories[i].memory_data);
} version (OS_ENABLE_HW_BOUND_CHECK) {
version (BH_PLATFORM_WINDOWS) {
                    os_mem_decommit(memories[i].memory_data,
                                    memories[i].num_bytes_per_page
                                        * memories[i].cur_page_count);
}
                    os_munmap(cast(ubyte*)memories[i].memory_data,
                              8 * cast(ulong)BH_GB);
}
                }
            }
        }
        wasm_runtime_free(memories);
    }
    cast(void)module_inst;
}

private WASMMemoryInstance* memory_instantiate(WASMModuleInstance* module_inst, WASMMemoryInstance* memory, uint num_bytes_per_page, uint init_page_count, uint max_page_count, uint heap_size, uint flags, char* error_buf, uint error_buf_size) {
    WASMModule* module_ = module_inst.module_;
    ulong memory_data_size = void;
    uint heap_offset = num_bytes_per_page * init_page_count;
    uint inc_page_count = void, aux_heap_base = void, global_idx = void;
    uint bytes_of_last_page = void, bytes_to_page_end = void;
    ubyte* global_addr = void;
version (OS_ENABLE_HW_BOUND_CHECK) {
    ubyte* mapped_mem = void;
    ulong map_size = 8 * cast(ulong)BH_GB;
    ulong page_size = os_getpagesize();
}

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    bool is_shared_memory = flags & 0x02 ? true : false;

    /* shared memory */
    if (is_shared_memory) {
        WASMSharedMemNode* node = wasm_module_get_shared_memory(
            cast(WASMModuleCommon*)module_inst.module_);
        /* If the memory of this module has been instantiated,
            return the memory instance directly */
        if (node) {
            uint ref_count = void;
            ref_count = shared_memory_inc_reference(
                cast(WASMModuleCommon*)module_inst.module_);
            bh_assert(ref_count > 0);
            memory = cast(WASMMemoryInstance*)shared_memory_get_memory_inst(node);
            bh_assert(memory);

            cast(void)ref_count;
            return memory;
        }
    }
} /* end of WASM_ENABLE_SHARED_MEMORY */

    if (heap_size > 0 && module_inst.module_.malloc_function != cast(uint)-1
        && module_inst.module_.free_function != cast(uint)-1) {
        /* Disable app heap, use malloc/free function exported
           by wasm app to allocate/free memory instead */
        heap_size = 0;
    }

    if (init_page_count == max_page_count && init_page_count == 1) {
        /* If only one page and at most one page, we just append
           the app heap to the end of linear memory, enlarge the
           num_bytes_per_page, and don't change the page count */
        heap_offset = num_bytes_per_page;
        num_bytes_per_page += heap_size;
        if (num_bytes_per_page < heap_size) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to insert app heap into linear memory, "
                          ~ "try using `--heap_size=0` option");
            return null;
        }
    }
    else if (heap_size > 0) {
        if (init_page_count == max_page_count && init_page_count == 0) {
            /* If the memory data size is always 0, we resize it to
               one page for app heap */
            num_bytes_per_page = heap_size;
            heap_offset = 0;
            inc_page_count = 1;
        }
        else if (module_.aux_heap_base_global_index != cast(uint)-1
                 && module_.aux_heap_base
                        < num_bytes_per_page * init_page_count) {
            /* Insert app heap before __heap_base */
            aux_heap_base = module_.aux_heap_base;
            bytes_of_last_page = aux_heap_base % num_bytes_per_page;
            if (bytes_of_last_page == 0)
                bytes_of_last_page = num_bytes_per_page;
            bytes_to_page_end = num_bytes_per_page - bytes_of_last_page;
            inc_page_count =
                (heap_size - bytes_to_page_end + num_bytes_per_page - 1)
                / num_bytes_per_page;
            heap_offset = aux_heap_base;
            aux_heap_base += heap_size;

            bytes_of_last_page = aux_heap_base % num_bytes_per_page;
            if (bytes_of_last_page == 0)
                bytes_of_last_page = num_bytes_per_page;
            bytes_to_page_end = num_bytes_per_page - bytes_of_last_page;
            if (bytes_to_page_end < 1 * BH_KB) {
                aux_heap_base += 1 * BH_KB;
                inc_page_count++;
            }

            /* Adjust __heap_base global value */
            global_idx = module_.aux_heap_base_global_index;
            bh_assert(module_inst.e.globals
                      && global_idx < module_inst.e.global_count);
            global_addr = module_inst.global_data
                          + module_inst.e.globals[global_idx].data_offset;
            *cast(uint*)global_addr = aux_heap_base;
            LOG_VERBOSE("Reset __heap_base global to %u", aux_heap_base);
        }
        else {
            /* Insert app heap before new page */
            inc_page_count =
                (heap_size + num_bytes_per_page - 1) / num_bytes_per_page;
            heap_offset = num_bytes_per_page * init_page_count;
            heap_size = num_bytes_per_page * inc_page_count;
            if (heap_size > 0)
                heap_size -= 1 * BH_KB;
        }
        init_page_count += inc_page_count;
        max_page_count += inc_page_count;
        if (init_page_count > DEFAULT_MAX_PAGES) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to insert app heap into linear memory, "
                          ~ "try using `--heap_size=0` option");
            return null;
        }
        else if (init_page_count == DEFAULT_MAX_PAGES) {
            num_bytes_per_page = UINT32_MAX;
            init_page_count = max_page_count = 1;
        }
        if (max_page_count > DEFAULT_MAX_PAGES)
            max_page_count = DEFAULT_MAX_PAGES;
    }

    LOG_VERBOSE("Memory instantiate:");
    LOG_VERBOSE("  page bytes: %u, init pages: %u, max pages: %u",
                num_bytes_per_page, init_page_count, max_page_count);
    LOG_VERBOSE("  heap offset: %u, heap size: %d\n", heap_offset, heap_size);

    memory_data_size = cast(ulong)num_bytes_per_page * init_page_count;
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (is_shared_memory) {
        /* Allocate max page for shared memory */
        memory_data_size = cast(ulong)num_bytes_per_page * max_page_count;
    }
}
    bh_assert(memory_data_size <= 4 * cast(ulong)BH_GB);

    bh_assert(memory != null);
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    if (memory_data_size > 0
        && ((memory.memory_data =
                 runtime_malloc(memory_data_size, error_buf, error_buf_size)) == 0)) {
        goto fail1;
    }
} version (OS_ENABLE_HW_BOUND_CHECK) {
    memory_data_size = (memory_data_size + page_size - 1) & ~(page_size - 1);

    /* Totally 8G is mapped, the opcode load/store address range is 0 to 8G:
     *   ea = i + memarg.offset
     * both i and memarg.offset are u32 in range 0 to 4G
     * so the range of ea is 0 to 8G
     */
    if (((memory.memory_data = mapped_mem =
              os_mmap(null, map_size, MMAP_PROT_NONE, MMAP_MAP_NONE)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "mmap memory failed");
        goto fail1;
    }

version (BH_PLATFORM_WINDOWS) {
    if (!os_mem_commit(mapped_mem, memory_data_size,
                       MMAP_PROT_READ | MMAP_PROT_WRITE)) {
        set_error_buf(error_buf, error_buf_size, "commit memory failed");
        os_munmap(mapped_mem, map_size);
        goto fail1;
    }
}

    if (os_mprotect(mapped_mem, memory_data_size,
                    MMAP_PROT_READ | MMAP_PROT_WRITE)
        != 0) {
        set_error_buf(error_buf, error_buf_size, "mprotect memory failed");
        goto fail2;
    }
    /* Newly allocated pages are filled with zero by the OS, we don't fill it
     * again here */
} /* end of OS_ENABLE_HW_BOUND_CHECK */

    if (memory_data_size > UINT32_MAX)
        memory_data_size = cast(uint)memory_data_size;

    memory.module_type = Wasm_Module_Bytecode;
    memory.num_bytes_per_page = num_bytes_per_page;
    memory.cur_page_count = init_page_count;
    memory.max_page_count = max_page_count;
    memory.memory_data_size = cast(uint)memory_data_size;

    memory.heap_data = memory.memory_data + heap_offset;
    memory.heap_data_end = memory.heap_data + heap_size;
    memory.memory_data_end = memory.memory_data + cast(uint)memory_data_size;

    /* Initialize heap */
    if (heap_size > 0) {
        uint heap_struct_size = mem_allocator_get_heap_struct_size();

        if (((memory.heap_handle = runtime_malloc(
                  cast(ulong)heap_struct_size, error_buf, error_buf_size)) == 0)) {
            goto fail2;
        }
        if (!mem_allocator_create_with_struct_and_pool(
                memory.heap_handle, heap_struct_size, memory.heap_data,
                heap_size)) {
            set_error_buf(error_buf, error_buf_size, "init app heap failed");
            goto fail3;
        }
    }

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
    if (memory_data_size > 0) {
static if (UINTPTR_MAX == UINT64_MAX) {
        memory.mem_bound_check_1byte.u64 = memory_data_size - 1;
        memory.mem_bound_check_2bytes.u64 = memory_data_size - 2;
        memory.mem_bound_check_4bytes.u64 = memory_data_size - 4;
        memory.mem_bound_check_8bytes.u64 = memory_data_size - 8;
        memory.mem_bound_check_16bytes.u64 = memory_data_size - 16;
} else {
        memory.mem_bound_check_1byte.u32[0] = cast(uint)memory_data_size - 1;
        memory.mem_bound_check_2bytes.u32[0] = cast(uint)memory_data_size - 2;
        memory.mem_bound_check_4bytes.u32[0] = cast(uint)memory_data_size - 4;
        memory.mem_bound_check_8bytes.u32[0] = cast(uint)memory_data_size - 8;
        memory.mem_bound_check_16bytes.u32[0] = cast(uint)memory_data_size - 16;
}
    }
}

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (is_shared_memory) {
        memory.is_shared = true;
        if (!shared_memory_set_memory_inst(
                cast(WASMModuleCommon*)module_inst.module_,
                cast(WASMMemoryInstanceCommon*)memory)) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
            goto fail4;
        }
    }
}

    LOG_VERBOSE("Memory instantiate success.");
    return memory;

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
fail4:
    if (heap_size > 0)
        mem_allocator_destroy(memory.heap_handle);
}
fail3:
    if (heap_size > 0)
        wasm_runtime_free(memory.heap_handle);
fail2:
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    if (memory.memory_data)
        wasm_runtime_free(memory.memory_data);
} version (OS_ENABLE_HW_BOUND_CHECK) {
version (BH_PLATFORM_WINDOWS) {
    os_mem_decommit(mapped_mem, memory_data_size);
}
    os_munmap(mapped_mem, map_size);
}
fail1:
    return null;
}

/**
 * Instantiate memories in a module.
 */
private WASMMemoryInstance** memories_instantiate(const(WASMModule)* module_, WASMModuleInstance* module_inst, uint heap_size, char* error_buf, uint error_buf_size) {
    WASMImport* import_ = void;
    uint mem_index = 0, i = void, memory_count = module_.import_memory_count + module_.memory_count;
    ulong total_size = void;
    WASMMemoryInstance** memories = void; WASMMemoryInstance* memory = void;

    total_size = (WASMMemoryInstance*).sizeof * cast(ulong)memory_count;

    if (((memories = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    memory = module_inst.global_table_data.memory_instances;

    /* instantiate memories from import section */
    import_ = module_.import_memories;
    for (i = 0; i < module_.import_memory_count; i++, import_++, memory++) {
        uint num_bytes_per_page = import_.u.memory.num_bytes_per_page;
        uint init_page_count = import_.u.memory.init_page_count;
        uint max_page_count = import_.u.memory.max_page_count;
        uint flags = import_.u.memory.flags;
        uint actual_heap_size = heap_size;

        if ((WASM_ENABLE_MULTI_MODULE != 0) && (import_.u.memory.import_module != null)) {
            WASMModuleInstance* module_inst_linked = void;

            if (((module_inst_linked = get_sub_module_inst(
                      module_inst, import_.u.memory.import_module)) == 0)) {
                set_error_buf(error_buf, error_buf_size, "unknown memory");
                memories_deinstantiate(module_inst, memories, memory_count);
                return null;
            }

            if (((memories[mem_index++] = wasm_lookup_memory(
                      module_inst_linked, import_.u.memory.field_name)) == 0)) {
                set_error_buf(error_buf, error_buf_size, "unknown memory");
                memories_deinstantiate(module_inst, memories, memory_count);
                return null;
            }
        }
        else
        {
            if (((memories[mem_index++] = memory_instantiate(
                      module_inst, memory, num_bytes_per_page, init_page_count,
                      max_page_count, actual_heap_size, flags, error_buf,
                      error_buf_size)) == 0)) {
                memories_deinstantiate(module_inst, memories, memory_count);
                return null;
            }
        }
    }

    /* instantiate memories from memory section */
    for (i = 0; i < module_.memory_count; i++, memory++) {
        if (((memories[mem_index++] = memory_instantiate(
                  module_inst, memory, module_.memories[i].num_bytes_per_page,
                  module_.memories[i].init_page_count,
                  module_.memories[i].max_page_count, heap_size,
                  module_.memories[i].flags, error_buf, error_buf_size)) == 0)) {
            memories_deinstantiate(module_inst, memories, memory_count);
            return null;
        }
    }

    bh_assert(mem_index == memory_count);
    cast(void)module_inst;
    return memories;
}

/**
 * Destroy table instances.
 */
private void tables_deinstantiate(WASMModuleInstance* module_inst) {
    if (module_inst.tables) {
        wasm_runtime_free(module_inst.tables);
    }
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    if (module_inst.e.table_insts_linked) {
        wasm_runtime_free(module_inst.e.table_insts_linked);
    }
}
}

/**
 * Instantiate tables in a module.
 */
private WASMTableInstance** tables_instantiate(const(WASMModule)* module_, WASMModuleInstance* module_inst, WASMTableInstance* first_table, char* error_buf, uint error_buf_size) {
    WASMImport* import_ = void;
    uint table_index = 0, i = void;
    uint table_count = module_.import_table_count + module_.table_count;
    ulong total_size = cast(ulong)(WASMTableInstance*).sizeof * table_count;
    WASMTableInstance** tables = void; WASMTableInstance* table = first_table;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    ulong total_size_of_tables_linked = cast(ulong)(WASMTableInstance*).sizeof * module_.import_table_count;
    WASMTableInstance** table_linked = null;
}

    if (((tables = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

static if (WASM_ENABLE_MULTI_MODULE != 0) {
    if (module_.import_table_count > 0
        && ((module_inst.e.table_insts_linked = table_linked = runtime_malloc(
                 total_size_of_tables_linked, error_buf, error_buf_size)) == 0)) {
        goto fail;
    }
}

    /* instantiate tables from import section */
    import_ = module_.import_tables;
    for (i = 0; i < module_.import_table_count; i++, import_++) {
        uint max_size_fixed = 0;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        WASMTableInstance* table_inst_linked = null;
        WASMModuleInstance* module_inst_linked = null;
		}
        if ((WASM_ENABLE_MULTI_MODULE != 0) && import_.u.table.import_module) {
            if (((module_inst_linked = get_sub_module_inst(
                      module_inst, import_.u.table.import_module)) == 0)) {
                set_error_buf(error_buf, error_buf_size, "unknown table");
                goto fail;
            }

            if (((table_inst_linked = wasm_lookup_table(
                      module_inst_linked, import_.u.table.field_name)) == 0)) {
                set_error_buf(error_buf, error_buf_size, "unknown table");
                goto fail;
            }

            total_size = WASMTableInstance.elems.offsetof;
        }
        else
        {
            /* in order to save memory, alloc resource as few as possible */
            max_size_fixed = import_.u.table.possible_grow
                                 ? import_.u.table.max_size
                                 : import_.u.table.init_size;

            /* it is a built-in table, every module has its own */
            total_size = WASMTableInstance.elems.offsetof;
            total_size += cast(ulong)max_size_fixed * uint32.sizeof;
        }

        tables[table_index++] = table;

        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, cast(uint)total_size);

static if (WASM_ENABLE_MULTI_MODULE != 0) {
        *table_linked = table_inst_linked;
		}
        if ((WASM_ENABLE_MULTI_MODULE != 0) && table_inst_linked != null) {
            table.cur_size = table_inst_linked.cur_size;
            table.max_size = table_inst_linked.max_size;
        }
        else
        {
            table.cur_size = import_.u.table.init_size;
            table.max_size = max_size_fixed;
        }

        table = cast(WASMTableInstance*)(cast(ubyte*)table + cast(uint)total_size);
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        table_linked++;
}
    }

    /* instantiate tables from table section */
    for (i = 0; i < module_.table_count; i++) {
        uint max_size_fixed = 0;

        total_size = WASMTableInstance.elems.offsetof;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        /* in case, a module which imports this table will grow it */
        max_size_fixed = module_.tables[i].max_size;
} else {
        max_size_fixed = module_.tables[i].possible_grow
                             ? module_.tables[i].max_size
                             : module_.tables[i].init_size;
}
        total_size += uint.sizeof * cast(ulong)max_size_fixed;

        tables[table_index++] = table;

        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, cast(uint)total_size);
        table.cur_size = module_.tables[i].init_size;
        table.max_size = max_size_fixed;

        table = cast(WASMTableInstance*)(cast(ubyte*)table + cast(uint)total_size);
    }

    bh_assert(table_index == table_count);
    cast(void)module_inst;
    return tables;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
fail:
    wasm_runtime_free(tables);
    return null;
}
}

/**
 * Destroy function instances.
 */
private void functions_deinstantiate(WASMFunctionInstance* functions, uint count) {
    if (functions) {
        wasm_runtime_free(functions);
    }
}

/**
 * Instantiate functions in a module.
 */
private WASMFunctionInstance* functions_instantiate(const(WASMModule)* module_, WASMModuleInstance* module_inst, char* error_buf, uint error_buf_size) {
    WASMImport* import_ = void;
    uint i = void, function_count = module_.import_function_count + module_.function_count;
    ulong total_size = sizeof(WASMFunctionInstance) * cast(ulong)function_count;
    WASMFunctionInstance* functions = void, function_ = void;

    if (((functions = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    total_size = (void*).sizeof * cast(ulong)module_.import_function_count;
    if (total_size > 0
        && ((module_inst.import_func_ptrs =
                 runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        wasm_runtime_free(functions);
        return null;
    }

    /* instantiate functions from import section */
    function_ = functions;
    import_ = module_.import_functions;
    for (i = 0; i < module_.import_function_count; i++, import_++) {
        function_.is_import_func = true;

static if (WASM_ENABLE_MULTI_MODULE != 0) {
        if (import_.u.function_.import_module) {
            function_.import_module_inst = get_sub_module_inst(
                module_inst, import_.u.function_.import_module);

            if (function_.import_module_inst) {
                function_.import_func_inst =
                    wasm_lookup_function(function_.import_module_inst,
                                         import_.u.function_.field_name, null);
            }
        }
} /* WASM_ENABLE_MULTI_MODULE */
        function_.u.func_import = &import_.u.function_;
        function_.param_cell_num = import_.u.function_.func_type.param_cell_num;
        function_.ret_cell_num = import_.u.function_.func_type.ret_cell_num;
        function_.param_count =
            cast(ushort)function_.u.func_import.func_type.param_count;
        function_.param_types = function_.u.func_import.func_type.types;
        function_.local_cell_num = 0;
        function_.local_count = 0;
        function_.local_types = null;

        /* Copy the function pointer to current instance */
        module_inst.import_func_ptrs[i] =
            function_.u.func_import.func_ptr_linked;

        function_++;
    }

    /* instantiate functions from function section */
    for (i = 0; i < module_.function_count; i++) {
        function_.is_import_func = false;
        function_.u.func = module_.functions[i];

        function_.param_cell_num = function_.u.func.param_cell_num;
        function_.ret_cell_num = function_.u.func.ret_cell_num;
        function_.local_cell_num = function_.u.func.local_cell_num;

        function_.param_count =
            cast(ushort)function_.u.func.func_type.param_count;
        function_.local_count = cast(ushort)function_.u.func.local_count;
        function_.param_types = function_.u.func.func_type.types;
        function_.local_types = function_.u.func.local_types;

        function_.local_offsets = function_.u.func.local_offsets;

static if (WASM_ENABLE_FAST_INTERP != 0) {
        function_.const_cell_num = function_.u.func.const_cell_num;
}

        function_++;
    }

static if (WASM_ENABLE_FAST_JIT != 0) {
    module_inst.fast_jit_func_ptrs = module_.fast_jit_func_ptrs;
}

    bh_assert(cast(uint)(function_ - functions) == function_count);
    cast(void)module_inst;
    return functions;
}

/**
 * Destroy global instances.
 */
private void globals_deinstantiate(WASMGlobalInstance* globals) {
    if (globals)
        wasm_runtime_free(globals);
}

private bool check_global_init_expr(const(WASMModule)* module_, uint global_index, char* error_buf, uint error_buf_size) {
    if (global_index >= module_.import_global_count + module_.global_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown global %d",
                        global_index);
        return false;
    }

    /**
     * Currently, constant expressions occurring as initializers of
     * globals are further constrained in that contained global.get
     * instructions are only allowed to refer to imported globals.
     *
     * And initializer expression cannot reference a mutable global.
     */
    if (global_index >= module_.import_global_count
        || (module_.import_globals + global_index).u.global.is_mutable) {
        set_error_buf(error_buf, error_buf_size,
                      "constant expression required");
        return false;
    }

    return true;
}

/**
 * Instantiate globals in a module.
 */
private WASMGlobalInstance* globals_instantiate(const(WASMModule)* module_, WASMModuleInstance* module_inst, char* error_buf, uint error_buf_size) {
    WASMImport* import_ = void;
    uint global_data_offset = 0;
    uint i = void, global_count = module_.import_global_count + module_.global_count;
    ulong total_size = sizeof(WASMGlobalInstance) * cast(ulong)global_count;
    WASMGlobalInstance* globals = void, global = void;

    if (((globals = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    /* instantiate globals from import section */
    global = globals;
    import_ = module_.import_globals;
    for (i = 0; i < module_.import_global_count; i++, import_++) {
        WASMGlobalImport* global_import = &import_.u.global;
        global.type = global_import.type;
        global.is_mutable = global_import.is_mutable;
        if ((WASM_ENABLE_MULTI_MODULE != 0) && global_import.import_module) {
            if (((global.import_module_inst = get_sub_module_inst(
                      module_inst, global_import.import_module)) == 0)) {
                set_error_buf(error_buf, error_buf_size, "unknown global");
                goto fail;
            }

            if (((global.import_global_inst = wasm_lookup_global(
                      global.import_module_inst, global_import.field_name)) == 0)) {
                set_error_buf(error_buf, error_buf_size, "unknown global");
                goto fail;
            }

            /* The linked global instance has been initialized, we
               just need to copy the value. */
            bh_memcpy_s(&(global.initial_value), WASMValue.sizeof,
                        &(global_import.import_global_linked.init_expr),
                        WASMValue.sizeof);
        }
        else
        {
            /* native globals share their initial_values in one module */
            bh_memcpy_s(&(global.initial_value), WASMValue.sizeof,
                        &(global_import.global_data_linked),
                        WASMValue.sizeof);
        }
static if (WASM_ENABLE_FAST_JIT != 0) {
        bh_assert(global_data_offset == global_import.data_offset);
}
        global.data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global.type);

        global++;
    }

    /* instantiate globals from global section */
    for (i = 0; i < module_.global_count; i++) {
        InitializerExpression* init_expr = &(module_.globals[i].init_expr);

        global.type = module_.globals[i].type;
        global.is_mutable = module_.globals[i].is_mutable;
static if (WASM_ENABLE_FAST_JIT != 0) {
        bh_assert(global_data_offset == module_.globals[i].data_offset);
}
        global.data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global.type);

        if (init_expr.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
            if (!check_global_init_expr(module_, init_expr.u.global_index,
                                        error_buf, error_buf_size)) {
                goto fail;
            }

            bh_memcpy_s(
                &(global.initial_value), WASMValue.sizeof,
                &(globals[init_expr.u.global_index].initial_value),
                typeof(globals[init_expr.u.global_index].initial_value).sizeof);
        }
			        else if ((WASM_ENABLE_REF_TYPES != 0) && init_expr.init_expr_type == INIT_EXPR_TYPE_REFNULL_CONST) {
            global.initial_value.u32 = cast(uint)NULL_REF;
        }
        else {
            bh_memcpy_s(&(global.initial_value), WASMValue.sizeof,
                        &(init_expr.u), typeof(init_expr.u).sizeof);
        }
        global++;
    }

    bh_assert(cast(uint)(global - globals) == global_count);
    bh_assert(global_data_offset == module_.global_data_size);
    cast(void)module_inst;
    return globals;
fail:
    wasm_runtime_free(globals);
    return null;
}

/**
 * Return export function count in module export section.
 */
private uint get_export_count(const(WASMModule)* module_, ubyte kind) {
    WASMExport* export_ = module_.exports;
    uint count = 0, i = void;

    for (i = 0; i < module_.export_count; i++, export_ ++)
        if (export_.kind == kind)
            count++;

    return count;
}

/**
 * Destroy export function instances.
 */
private void export_functions_deinstantiate(WASMExportFuncInstance* functions) {
    if (functions)
        wasm_runtime_free(functions);
}

/**
 * Instantiate export functions in a module.
 */
private WASMExportFuncInstance* export_functions_instantiate(const(WASMModule)* module_, WASMModuleInstance* module_inst, uint export_func_count, char* error_buf, uint error_buf_size) {
    WASMExportFuncInstance* export_funcs = void, export_func = void;
    WASMExport* export_ = module_.exports;
    uint i = void;
    ulong total_size = sizeof(WASMExportFuncInstance) * cast(ulong)export_func_count;

    if (((export_func = export_funcs =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    for (i = 0; i < module_.export_count; i++, export_ ++)
        if (export_.kind == EXPORT_KIND_FUNC) {
            export_func.name = export_.name;
            export_func.function_ = &module_inst.e.functions[export_.index];
            export_func++;
        }

    bh_assert(cast(uint)(export_func - export_funcs) == export_func_count);
    return export_funcs;
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
private void export_globals_deinstantiate(WASMExportGlobInstance* globals) {
    if (globals)
        wasm_runtime_free(globals);
}

private WASMExportGlobInstance* export_globals_instantiate(const(WASMModule)* module_, WASMModuleInstance* module_inst, uint export_glob_count, char* error_buf, uint error_buf_size) {
    WASMExportGlobInstance* export_globals = void, export_global = void;
    WASMExport* export_ = module_.exports;
    uint i = void;
    ulong total_size = sizeof(WASMExportGlobInstance) * cast(ulong)export_glob_count;

    if (((export_global = export_globals =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    for (i = 0; i < module_.export_count; i++, export_ ++)
        if (export_.kind == EXPORT_KIND_GLOBAL) {
            export_global.name = export_.name;
            export_global.global = &module_inst.e.globals[export_.index];
            export_global++;
        }

    bh_assert(cast(uint)(export_global - export_globals) == export_glob_count);
    return export_globals;
}
}

private bool execute_post_inst_function(WASMModuleInstance* module_inst) {
    WASMFunctionInstance* post_inst_func = null;
    WASMType* post_inst_func_type = void;
    uint i = void;

    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name,
                    "__post_instantiate")) {
            post_inst_func = module_inst.export_functions[i].function_;
            break;
        }

    if (!post_inst_func)
        /* Not found */
        return true;

    post_inst_func_type = post_inst_func.u.func.func_type;
    if (post_inst_func_type.param_count != 0
        || post_inst_func_type.result_count != 0)
        /* Not a valid function type, ignore it */
        return true;

    return wasm_create_exec_env_and_call_function(module_inst, post_inst_func,
                                                  0, null);
}

static if (WASM_ENABLE_BULK_MEMORY != 0) {
private bool execute_memory_init_function(WASMModuleInstance* module_inst) {
    WASMFunctionInstance* memory_init_func = null;
    WASMType* memory_init_func_type = void;
    uint i = void;

    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name,
                    "__wasm_call_ctors")) {
            memory_init_func = module_inst.export_functions[i].function_;
            break;
        }

    if (!memory_init_func)
        /* Not found */
        return true;

    memory_init_func_type = memory_init_func.u.func.func_type;
    if (memory_init_func_type.param_count != 0
        || memory_init_func_type.result_count != 0)
        /* Not a valid function type, ignore it */
        return true;

    return wasm_create_exec_env_and_call_function(module_inst, memory_init_func,
                                                  0, null);
}
}

private bool execute_start_function(WASMModuleInstance* module_inst) {
    WASMFunctionInstance* func = module_inst.e.start_function;

    if (!func)
        return true;

    bh_assert(!func.is_import_func && func.param_cell_num == 0
              && func.ret_cell_num == 0);

    return wasm_create_exec_env_and_call_function(module_inst, func, 0, null);
}

private bool execute_malloc_function(WASMModuleInstance* module_inst, WASMFunctionInstance* malloc_func, WASMFunctionInstance* retain_func, uint size, uint* p_result) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    WASMExecEnv* exec_env_tls = wasm_runtime_get_exec_env_tls();
}
    uint[2] argv = void; uint argc = void;
    bool ret = void;

    argv[0] = size;
    argc = 1;

    /* if __retain is exported, then this module is compiled by
        assemblyscript, the memory should be managed by as's runtime,
        in this case we need to call the retain function after malloc
        the memory */
    if (retain_func) {
        /* the malloc functino from assemblyscript is:
            function __new(size: usize, id: u32)
            id = 0 means this is an ArrayBuffer object */
        argv[1] = 0;
        argc = 2;
    }

    if ((OS_ENABLE_HW_BOUND_CHECK) && exec_env_tls != null) {
        bh_assert(exec_env_tls.module_inst
                  == cast(WASMModuleInstanceCommon*)module_inst);
        ret = wasm_call_function(exec_env_tls, malloc_func, argc, argv.ptr);

        if (retain_func && ret) {
            ret = wasm_call_function(exec_env_tls, retain_func, 1, argv.ptr);
        }
    }
    else
    {
        ret = wasm_create_exec_env_and_call_function(module_inst, malloc_func,
                                                     argc, argv.ptr);

        if (retain_func && ret) {
            ret = wasm_create_exec_env_and_call_function(module_inst,
                                                         retain_func, 1, argv.ptr);
        }
    }

    if (ret)
        *p_result = argv[0];
    return ret;
}

private bool execute_free_function(WASMModuleInstance* module_inst, WASMFunctionInstance* free_func, uint offset) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    WASMExecEnv* exec_env_tls = wasm_runtime_get_exec_env_tls();
}
    uint[2] argv = void;

    argv[0] = offset;
    if ((OS_ENABLE_HW_BOUND_CHECK) && exec_env_tls != null) {
        bh_assert(exec_env_tls.module_inst
                  == cast(WASMModuleInstanceCommon*)module_inst);
        return wasm_call_function(exec_env_tls, free_func, 1, argv.ptr);
    }
    else
    {
        return wasm_create_exec_env_and_call_function(module_inst, free_func, 1,
                                                      argv.ptr);
    }
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
private bool sub_module_instantiate(WASMModule* module_, WASMModuleInstance* module_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size) {
    bh_list* sub_module_inst_list = module_inst.e.sub_module_inst_list;
    WASMRegisteredModule* sub_module_list_node = bh_list_first_elem(module_.import_module_list);

    while (sub_module_list_node) {
        WASMSubModInstNode* sub_module_inst_list_node = null;
        WASMModule* sub_module = cast(WASMModule*)sub_module_list_node.module_;
        WASMModuleInstance* sub_module_inst = null;

        sub_module_inst =
            wasm_instantiate(sub_module, false, stack_size, heap_size,
                             error_buf, error_buf_size);
        if (!sub_module_inst) {
            LOG_DEBUG("instantiate %s failed",
                      sub_module_list_node.module_name);
            goto failed;
        }

        sub_module_inst_list_node = runtime_malloc(WASMSubModInstNode.sizeof,
                                                   error_buf, error_buf_size);
        if (!sub_module_inst_list_node) {
            LOG_DEBUG("Malloc WASMSubModInstNode failed, SZ:%d",
                      WASMSubModInstNode.sizeof);
            goto failed;
        }

        sub_module_inst_list_node.module_inst = sub_module_inst;
        sub_module_inst_list_node.module_name =
            sub_module_list_node.module_name;
        bh_list_status ret = bh_list_insert(sub_module_inst_list, sub_module_inst_list_node);
        bh_assert(BH_LIST_SUCCESS == ret);
        cast(void)ret;

        sub_module_list_node = bh_list_elem_next(sub_module_list_node);

static if (WASM_ENABLE_LIBC_WASI != 0) {
        {
            /*
             * reactor instances may assume that _initialize will be called by
             * the environment at most once, and that none of their other
             * exports are accessed before that call.
             *
             * let the loader decide how to act if there is no _initialize
             * in a reactor
             */
            WASMFunctionInstance* initialize = wasm_lookup_function(sub_module_inst, "_initialize", null);
            if (initialize
                && !wasm_create_exec_env_and_call_function(
                    sub_module_inst, initialize, 0, null)) {
                set_error_buf(error_buf, error_buf_size,
                              "Call _initialize failed ");
                goto failed;
            }
        }
}

        continue;
    failed:
        if (sub_module_inst_list_node) {
            bh_list_remove(sub_module_inst_list, sub_module_inst_list_node);
            wasm_runtime_free(sub_module_inst_list_node);
        }

        if (sub_module_inst)
            wasm_deinstantiate(sub_module_inst, false);
        return false;
    }

    return true;
}

private void sub_module_deinstantiate(WASMModuleInstance* module_inst) {
    bh_list* list = module_inst.e.sub_module_inst_list;
    WASMSubModInstNode* node = bh_list_first_elem(list);
    while (node) {
        WASMSubModInstNode* next_node = bh_list_elem_next(node);
        bh_list_remove(list, node);
        wasm_deinstantiate(node.module_inst, false);
        wasm_runtime_free(node);
        node = next_node;
    }
}
}

private bool check_linked_symbol(WASMModuleInstance* module_inst, char* error_buf, uint error_buf_size) {
    WASMModule* module_ = module_inst.module_;
    uint i = void;

    for (i = 0; i < module_.import_function_count; i++) {
        WASMFunctionImport* func = &((module_.import_functions + i).u.function_);
        if (!func.func_ptr_linked &&
(WASM_ENABLE_MULTI_MODULE != 0)
            && !func.import_func_linked
        ) {
static if (WASM_ENABLE_WAMR_COMPILER == 0) {
            LOG_WARNING("warning: failed to link import function (%s, %s)",
                        func.module_name, func.field_name);
} else {
            /* do nothing to avoid confused message */
} /* WASM_ENABLE_WAMR_COMPILER == 0 */
        }
    }

    for (i = 0; i < module_.import_global_count; i++) {
        WASMGlobalImport* global = &((module_.import_globals + i).u.global);
        if (!global.is_linked) {
static if (WASM_ENABLE_SPEC_TEST != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "unknown import or incompatible import type");
            return false;
} else {
static if (WASM_ENABLE_WAMR_COMPILER == 0) {
            LOG_DEBUG("warning: failed to link import global (%s, %s)",
                      global.module_name, global.field_name);
} else {
            /* do nothing to avoid confused message */
} /* WASM_ENABLE_WAMR_COMPILER == 0 */
} /* WASM_ENABLE_SPEC_TEST != 0 */
        }
    }

    return true;
}

static if (WASM_ENABLE_JIT != 0) {
private bool init_func_ptrs(WASMModuleInstance* module_inst, WASMModule* module_, char* error_buf, uint error_buf_size) {
    uint i = void;
    void** func_ptrs = void;
    ulong total_size = cast(ulong)(void*).sizeof * module_inst.e.function_count;

    /* Allocate memory */
    if (((func_ptrs = module_inst.func_ptrs =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Set import function pointers */
    for (i = 0; i < module_.import_function_count; i++, func_ptrs++) {
        WASMFunctionImport* import_func = &module_.import_functions[i].u.function_;
        /* TODO: handle multi module */
        *func_ptrs = import_func.func_ptr_linked;
    }

    /* Set defined function pointers */
    bh_memcpy_s(func_ptrs, (void*).sizeof * module_.function_count,
                module_.func_ptrs, (void*).sizeof * module_.function_count);
    return true;
}
} /* end of WASM_ENABLE_JIT != 0 */

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
private uint get_smallest_type_idx(WASMModule* module_, WASMType* func_type) {
    uint i = void;

    for (i = 0; i < module_.type_count; i++) {
        if (func_type == module_.types[i])
            return i;
    }

    bh_assert(0);
    return -1;
}

private bool init_func_type_indexes(WASMModuleInstance* module_inst, char* error_buf, uint error_buf_size) {
    uint i = void;
    ulong total_size = uint.sizeof * module_inst.e.function_count;

    /* Allocate memory */
    if (((module_inst.func_type_indexes =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    for (i = 0; i < module_inst.e.function_count; i++) {
        WASMFunctionInstance* func_inst = module_inst.e.functions + i;
        WASMType* func_type = func_inst.is_import_func
                                  ? func_inst.u.func_import.func_type
                                  : func_inst.u.func.func_type;
        module_inst.func_type_indexes[i] =
            get_smallest_type_idx(module_inst.module_, func_type);
    }

    return true;
}
} /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 */

/**
 * Instantiate module
 */
WASMModuleInstance *
wasm_instantiate(WASMModule* module_, bool is_sub_inst, uint stack_size,
                 uint heap_size, char* error_buf, uint error_buf_size)
{
    WASMModuleInstance* module_inst;
    WASMGlobalInstance* globals = null, global;
    WASMTableInstance* first_table;
    uint global_count, i;
    uint base_offset, length, extra_info_offset;
    uint module_inst_struct_size = offsetof(WASMModuleInstance, global_table_data.bytes);
    ulong module_inst_mem_inst_size;
    ulong total_size, table_size = 0;
    ubyte* global_data, global_data_end;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    bool ret = false;
}

    if (!module_)
        return null;

    /* Check the heap size */
    heap_size = align_uint(heap_size, 8);
    if (heap_size > APP_HEAP_SIZE_MAX)
        heap_size = APP_HEAP_SIZE_MAX;

    module_inst_mem_inst_size =
        cast(ulong)sizeof(WASMMemoryInstance)
        * (module_.import_memory_count + module_.memory_count);

static if (WASM_ENABLE_JIT != 0) {
    /* If the module dosen't have memory, reserve one mem_info space
       with empty content to align with llvm jit compiler */
    if (module_inst_mem_inst_size == 0)
        module_inst_mem_inst_size = cast(ulong)WASMMemoryInstance.sizeof;
}

    /* Size of module inst, memory instances and global data */
    total_size = cast(ulong)module_inst_struct_size + module_inst_mem_inst_size
                 + module_.global_data_size;

    /* Calculate the size of table data */
    for (i = 0; i < module_.import_table_count; i++) {
        WASMTableImport* import_table = &module_.import_tables[i].u.table;
        table_size += WASMTableInstance.elems.offsetof;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        table_size += uint.sizeof * import_table.max_size;
} else {
        table_size += uint.sizeof
                      * (import_table.possible_grow ? import_table.max_size
                                                     : import_table.init_size);
}
    }
    for (i = 0; i < module_.table_count; i++) {
        WASMTable* table = module_.tables + i;
        table_size += WASMTableInstance.elems.offsetof;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        table_size += uint.sizeof * table.max_size;
} else {
        table_size +=
            uint.sizeof
            * (table.possible_grow ? table.max_size : table.init_size);
}
    }
    total_size += table_size;

    /* The offset of WASMModuleInstanceExtra, make it 8-byte aligned */
    total_size = (total_size + 7L) & ~7L;
    extra_info_offset = cast(uint)total_size;
    total_size += WASMModuleInstanceExtra.sizeof;

    /* Allocate the memory for module instance with memory instances,
       global data, table data appended at the end */
    if (((module_inst =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    module_inst.module_type = Wasm_Module_Bytecode;
    module_inst.module_ = module_;
    module_inst.e =
        cast(WASMModuleInstanceExtra*)(cast(ubyte*)module_inst + extra_info_offset);

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (os_mutex_init(&module_inst.e.mem_lock) != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "create shared memory lock failed");
        goto fail;
    }
    module_inst.e.mem_lock_inited = true;
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
    module_inst.e.sub_module_inst_list =
        &module_inst.e.sub_module_inst_list_head;
    ret = sub_module_instantiate(module_, module_inst, stack_size, heap_size,
                                 error_buf, error_buf_size);
    if (!ret) {
        LOG_DEBUG("build a sub module list failed");
        goto fail;
    }
}

static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
    if (((module_inst.frames = runtime_malloc(cast(ulong)Vector.sizeof,
                                               error_buf, error_buf_size)) == 0)) {
        goto fail;
    }
}

    /* Instantiate global firstly to get the mutable data size */
    global_count = module_.import_global_count + module_.global_count;
    if (global_count
        && ((globals = globals_instantiate(module_, module_inst, error_buf,
                                           error_buf_size)) == 0)) {
        goto fail;
    }
    module_inst.e.global_count = global_count;
    module_inst.e.globals = globals;
    module_inst.global_data = cast(ubyte*)module_inst + module_inst_struct_size
                               + module_inst_mem_inst_size;
    module_inst.global_data_size = module_.global_data_size;
    first_table = cast(WASMTableInstance*)(module_inst.global_data
                                        + module_.global_data_size);

    module_inst.memory_count =
        module_.import_memory_count + module_.memory_count;
    module_inst.table_count = module_.import_table_count + module_.table_count;
    module_inst.e.function_count =
        module_.import_function_count + module_.function_count;

    /* export */
    module_inst.export_func_count = get_export_count(module_, EXPORT_KIND_FUNC);
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    module_inst.export_table_count =
        get_export_count(module_, EXPORT_KIND_TABLE);
    module_inst.export_memory_count =
        get_export_count(module_, EXPORT_KIND_MEMORY);
    module_inst.export_global_count =
        get_export_count(module_, EXPORT_KIND_GLOBAL);
}

    /* Instantiate memories/tables/functions */
    if ((module_inst.memory_count > 0
         && ((module_inst.memories = memories_instantiate(
                  module_, module_inst, heap_size, error_buf, error_buf_size)) == 0))
        || (module_inst.table_count > 0
            && ((module_inst.tables =
                     tables_instantiate(module_, module_inst, first_table,
                                        error_buf, error_buf_size)) == 0))
        || (module_inst.e.function_count > 0
            && ((module_inst.e.functions = functions_instantiate(
                     module_, module_inst, error_buf, error_buf_size)) == 0))
        || (module_inst.export_func_count > 0
            && ((module_inst.export_functions = export_functions_instantiate(
                     module_, module_inst, module_inst.export_func_count,
                     error_buf, error_buf_size)) == 0))
|| (( WASM_ENABLE_MULTI_MODULE != 0)
        && (module_inst.export_global_count > 0
            && ((module_inst.export_globals = export_globals_instantiate(
                     module_, module_inst, module_inst.export_global_count,
                     error_buf, error_buf_size)) == 0))
)
|| ((WASM_ENABLE_JIT != 0)
        && (module_inst.e.function_count > 0
            && !init_func_ptrs(module_inst, module_, error_buf, error_buf_size))
)
|| ((WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0)
        && (module_inst.e.function_count > 0
            && !init_func_type_indexes(module_inst, error_buf, error_buf_size))
)
    ) {
        goto fail;
    }

    if (global_count > 0) {
        /* Initialize the global data */
        global_data = module_inst.global_data;
        global_data_end = global_data + module_.global_data_size;
        global = globals;
        for (i = 0; i < global_count; i++, global++) {
            switch (global.type) {
                case VALUE_TYPE_I32:
                case VALUE_TYPE_F32:
static if (WASM_ENABLE_REF_TYPES != 0) {
                case VALUE_TYPE_FUNCREF:
                case VALUE_TYPE_EXTERNREF:
}
                    *cast(int*)global_data = global.initial_value.i32;
                    global_data += int32.sizeof;
                    break;
                case VALUE_TYPE_I64:
                case VALUE_TYPE_F64:
                    bh_memcpy_s(global_data,
                                cast(uint)(global_data_end - global_data),
                                &global.initial_value.i64, int64.sizeof);
                    global_data += int64.sizeof;
                    break;
static if (WASM_ENABLE_SIMD != 0) {
                case VALUE_TYPE_V128:
                    bh_memcpy_s(global_data, cast(uint)V128.sizeof,
                                &global.initial_value.v128, V128.sizeof);
                    global_data += V128.sizeof;
                    break;
}
                default:
                    bh_assert(0);
            }
        }
        bh_assert(global_data == global_data_end);
    }

    if (!check_linked_symbol(module_inst, error_buf, error_buf_size)) {
        goto fail;
    }

    /* Initialize the memory data with data segment section */
    for (i = 0; i < module_.data_seg_count; i++) {
        WASMMemoryInstance* memory = null;
        ubyte* memory_data = null;
        uint memory_size = 0;
        WASMDataSeg* data_seg = module_.data_segments[i];

static if (WASM_ENABLE_BULK_MEMORY != 0) {
        if (data_seg.is_passive)
            continue;
}

        /* has check it in loader */
        memory = module_inst.memories[data_seg.memory_index];
        bh_assert(memory);

        memory_data = memory.memory_data;
        memory_size = memory.num_bytes_per_page * memory.cur_page_count;
        bh_assert(memory_data || memory_size == 0);

        bh_assert(data_seg.base_offset.init_expr_type
                      == INIT_EXPR_TYPE_I32_CONST
                  || data_seg.base_offset.init_expr_type
                         == INIT_EXPR_TYPE_GET_GLOBAL);

        if (data_seg.base_offset.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
            if (!check_global_init_expr(module_,
                                        data_seg.base_offset.u.global_index,
                                        error_buf, error_buf_size)) {
                goto fail;
            }

            if (!globals
                || globals[data_seg.base_offset.u.global_index].type
                       != VALUE_TYPE_I32) {
                set_error_buf(error_buf, error_buf_size,
                              "data segment does not fit");
                goto fail;
            }

            base_offset =
                globals[data_seg.base_offset.u.global_index].initial_value.i32;
        }
        else {
            base_offset = cast(uint)data_seg.base_offset.u.i32;
        }

        /* check offset */
        if (base_offset > memory_size) {
            LOG_DEBUG("base_offset(%d) > memory_size(%d)", base_offset,
                      memory_size);
static if (WASM_ENABLE_REF_TYPES != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds memory access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit");
}
            goto fail;
        }

        /* check offset + length(could be zero) */
        length = data_seg.data_length;
        if (base_offset + length > memory_size) {
            LOG_DEBUG("base_offset(%d) + length(%d) > memory_size(%d)",
                      base_offset, length, memory_size);
static if (WASM_ENABLE_REF_TYPES != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds memory access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit");
}
            goto fail;
        }

        if (memory_data) {
            bh_memcpy_s(memory_data + base_offset, memory_size - base_offset,
                        data_seg.data, length);
        }
    }

    /* Initialize the table data with table segment section */
    for (i = 0; module_inst.table_count > 0 && i < module_.table_seg_count;
         i++) {
        WASMTableSeg* table_seg = module_.table_segments + i;
        /* has check it in loader */
        WASMTableInstance* table = module_inst.tables[table_seg.table_index];
        uint* table_data;
static if (WASM_ENABLE_REF_TYPES != 0) {
        ubyte tbl_elem_type;
        uint tbl_init_size, tbl_max_size;
}

        bh_assert(table);

static if (WASM_ENABLE_REF_TYPES != 0) {
        cast(void)wasm_runtime_get_table_inst_elem_type(
            cast(WASMModuleInstanceCommon*)module_inst, table_seg.table_index,
            &tbl_elem_type, &tbl_init_size, &tbl_max_size);
        if (tbl_elem_type != VALUE_TYPE_FUNCREF
            && tbl_elem_type != VALUE_TYPE_EXTERNREF) {
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
            goto fail;
        }
        cast(void)tbl_init_size;
        cast(void)tbl_max_size;
}

        table_data = table.elems;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        if (table_seg.table_index < module_.import_table_count
            && module_inst.e.table_insts_linked[table_seg.table_index]) {
            table_data =
                module_inst.e.table_insts_linked[table_seg.table_index]
                    .elems;
        }
}
        bh_assert(table_data);

static if (WASM_ENABLE_REF_TYPES != 0) {
        if (!wasm_elem_is_active(table_seg.mode))
            continue;
}

static if (WASM_ENABLE_REF_TYPES != 0) {
        bh_assert(table_seg.base_offset.init_expr_type
                      == INIT_EXPR_TYPE_I32_CONST
                  || table_seg.base_offset.init_expr_type
                         == INIT_EXPR_TYPE_GET_GLOBAL
                  || table_seg.base_offset.init_expr_type
                         == INIT_EXPR_TYPE_FUNCREF_CONST
                  || table_seg.base_offset.init_expr_type
                         == INIT_EXPR_TYPE_REFNULL_CONST);
} else {
        bh_assert(table_seg.base_offset.init_expr_type
                      == INIT_EXPR_TYPE_I32_CONST
                  || table_seg.base_offset.init_expr_type
                         == INIT_EXPR_TYPE_GET_GLOBAL);
}

        /* init vec(funcidx) or vec(expr) */
        if (table_seg.base_offset.init_expr_type
            == INIT_EXPR_TYPE_GET_GLOBAL) {
            if (!check_global_init_expr(module_,
                                        table_seg.base_offset.u.global_index,
                                        error_buf, error_buf_size)) {
                goto fail;
            }

            if (!globals
                || globals[table_seg.base_offset.u.global_index].type
                       != VALUE_TYPE_I32) {
                set_error_buf(error_buf, error_buf_size,
                              "elements segment does not fit");
                goto fail;
            }

            table_seg.base_offset.u.i32 =
                globals[table_seg.base_offset.u.global_index]
                    .initial_value.i32;
        }

        /* check offset since length might negative */
        if (cast(uint)table_seg.base_offset.u.i32 > table.cur_size) {
            LOG_DEBUG("base_offset(%d) > table->cur_size(%d)",
                      table_seg.base_offset.u.i32, table.cur_size);
static if (WASM_ENABLE_REF_TYPES != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds table access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
}
            goto fail;
        }

        /* check offset + length(could be zero) */
        length = table_seg.function_count;
        if (cast(uint)table_seg.base_offset.u.i32 + length > table.cur_size) {
            LOG_DEBUG("base_offset(%d) + length(%d)> table->cur_size(%d)",
                      table_seg.base_offset.u.i32, length, table.cur_size);
static if (WASM_ENABLE_REF_TYPES != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds table access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
}
            goto fail;
        }

        /**
         * Check function index in the current module inst for now.
         * will check the linked table inst owner in future.
         * so loader check is enough
         */
        bh_memcpy_s(
            table_data + table_seg.base_offset.u.i32,
            cast(uint)((table.cur_size - cast(uint)table_seg.base_offset.u.i32)
                     * uint32.sizeof),
            table_seg.func_indexes, cast(uint)(length * uint32.sizeof));
    }

    /* Initialize the thread related data */
    if (stack_size == 0)
        stack_size = DEFAULT_WASM_STACK_SIZE;
static if (WASM_ENABLE_SPEC_TEST != 0) {
    if (stack_size < 128 * 1024)
        stack_size = 128 * 1024;
}
    module_inst.default_wasm_stack_size = stack_size;

    if (module_.malloc_function != cast(uint)-1) {
        module_inst.e.malloc_function =
            &module_inst.e.functions[module_.malloc_function];
    }

    if (module_.free_function != cast(uint)-1) {
        module_inst.e.free_function =
            &module_inst.e.functions[module_.free_function];
    }

    if (module_.retain_function != cast(uint)-1) {
        module_inst.e.retain_function =
            &module_inst.e.functions[module_.retain_function];
    }

static if (WASM_ENABLE_LIBC_WASI != 0) {
    /* The sub-instance will get the wasi_ctx from main-instance */
    if (!is_sub_inst) {
        if (!wasm_runtime_init_wasi(
                cast(WASMModuleInstanceCommon*)module_inst,
                module_.wasi_args.dir_list, module_.wasi_args.dir_count,
                module_.wasi_args.map_dir_list, module_.wasi_args.map_dir_count,
                module_.wasi_args.env, module_.wasi_args.env_count,
                module_.wasi_args.addr_pool, module_.wasi_args.addr_count,
                module_.wasi_args.ns_lookup_pool,
                module_.wasi_args.ns_lookup_count, module_.wasi_args.argv,
                module_.wasi_args.argc, module_.wasi_args.stdio[0],
                module_.wasi_args.stdio[1], module_.wasi_args.stdio[2],
                error_buf, error_buf_size)) {
            goto fail;
        }
    }
}

static if (WASM_ENABLE_DEBUG_INTERP != 0                         
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 
        && WASM_ENABLE_LAZY_JIT != 0)) {
    if (!is_sub_inst) {
        /* Add module instance into module's instance list */
        os_mutex_lock(&module_.instance_list_lock);
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
        if (module_.instance_list) {
            LOG_WARNING(
                "warning: multiple instances referencing to the same module "
                ~ "may cause unexpected behaviour during debugging");
        }
}
static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 
    && WASM_ENABLE_LAZY_JIT != 0) {
        /* Copy llvm func ptrs again in case that they were updated
           after the module instance was created */
        bh_memcpy_s(module_inst.func_ptrs + module_.import_function_count,
                    (void*).sizeof * module_.function_count, module_.func_ptrs,
                    (void*).sizeof * module_.function_count);
}
        module_inst.e.next = module_.instance_list;
        module_.instance_list = module_inst;
        os_mutex_unlock(&module_.instance_list_lock);
    }
}

    if (module_.start_function != cast(uint)-1) {
        /* TODO: fix start function can be import function issue */
        if (module_.start_function >= module_.import_function_count)
            module_inst.e.start_function =
                &module_inst.e.functions[module_.start_function];
    }

    /* Execute __post_instantiate function */
    if (!execute_post_inst_function(module_inst)
        || !execute_start_function(module_inst)) {
        set_error_buf(error_buf, error_buf_size, module_inst.cur_exception);
        goto fail;
    }

#if WASM_ENABLE_BULK_MEMORY != 0
static if (WASM_ENABLE_LIBC_WASI != 0) {
    if (!module_.import_wasi_api) {
//! #endif
        /* Only execute the memory init function for main instance because
            the data segments will be dropped once initialized.
        */
        if (!is_sub_inst) {
            if (!execute_memory_init_function(module_inst)) {
                set_error_buf(error_buf, error_buf_size,
                              module_inst.cur_exception);
                goto fail;
            }
        }
static if (WASM_ENABLE_LIBC_WASI != 0) {
    }
}
}

static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    wasm_runtime_dump_module_inst_mem_consumption(
        cast(WASMModuleInstanceCommon*)module_inst);
}

    cast(void)global_data_end;
    return module_inst;

fail:
    wasm_deinstantiate(module_inst, false);
    return null;
}

void wasm_deinstantiate(WASMModuleInstance* module_inst, bool is_sub_inst) {
    if (!module_inst)
        return;

static if (WASM_ENABLE_JIT != 0) {
    if (module_inst.func_ptrs)
        wasm_runtime_free(module_inst.func_ptrs);
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
    if (module_inst.func_type_indexes)
        wasm_runtime_free(module_inst.func_type_indexes);
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
    sub_module_deinstantiate(module_inst);
}

static if (WASM_ENABLE_LIBC_WASI != 0) {
    /* Destroy wasi resource before freeing app heap, since some fields of
       wasi contex are allocated from app heap, and if app heap is freed,
       these fields will be set to NULL, we cannot free their internal data
       which may allocated from global heap. */
    /* Only destroy wasi ctx in the main module instance */
    if (!is_sub_inst)
        wasm_runtime_destroy_wasi(cast(WASMModuleInstanceCommon*)module_inst);
}

    if (module_inst.memory_count > 0)
        memories_deinstantiate(module_inst, module_inst.memories,
                               module_inst.memory_count);

    if (module_inst.import_func_ptrs) {
        wasm_runtime_free(module_inst.import_func_ptrs);
    }

    tables_deinstantiate(module_inst);
    functions_deinstantiate(module_inst.e.functions,
                            module_inst.e.function_count);
    globals_deinstantiate(module_inst.e.globals);
    export_functions_deinstantiate(module_inst.export_functions);
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    export_globals_deinstantiate(module_inst.export_globals);
}

static if (WASM_ENABLE_REF_TYPES != 0) {
    wasm_externref_cleanup(cast(WASMModuleInstanceCommon*)module_inst);
}

    if (module_inst.exec_env_singleton)
        wasm_exec_env_destroy(module_inst.exec_env_singleton);

static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
    if (module_inst.frames) {
        bh_vector_destroy(module_inst.frames);
        wasm_runtime_free(module_inst.frames);
        module_inst.frames = null;
    }
}

static if (WASM_ENABLE_DEBUG_INTERP != 0                         \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
        && WASM_ENABLE_LAZY_JIT != 0)) {
    if (!is_sub_inst) {
        WASMModule* module_ = module_inst.module_;
        WASMModuleInstance* instance_prev = null, instance = void;
        os_mutex_lock(&module_.instance_list_lock);

        instance = module_.instance_list;
        while (instance) {
            if (instance == module_inst) {
                if (!instance_prev)
                    module_.instance_list = instance.e.next;
                else
                    instance_prev.e.next = instance.e.next;
                break;
            }
            instance_prev = instance;
            instance = instance.e.next;
        }

        os_mutex_unlock(&module_.instance_list_lock);
    }
}

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (module_inst.e.mem_lock_inited)
        os_mutex_destroy(&module_inst.e.mem_lock);
}

    if (module_inst.e.c_api_func_imports)
        wasm_runtime_free(module_inst.e.c_api_func_imports);

    wasm_runtime_free(module_inst);
}

WASMFunctionInstance* wasm_lookup_function(const(WASMModuleInstance)* module_inst, const(char)* name, const(char)* signature) {
    uint i = void;
    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name, name))
            return module_inst.export_functions[i].function_;
    cast(void)signature;
    return null;
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
WASMGlobalInstance* wasm_lookup_global(const(WASMModuleInstance)* module_inst, const(char)* name) {
    uint i = void;
    for (i = 0; i < module_inst.export_global_count; i++)
        if (!strcmp(module_inst.export_globals[i].name, name))
            return module_inst.export_globals[i].global;
    return null;
}

WASMMemoryInstance* wasm_lookup_memory(const(WASMModuleInstance)* module_inst, const(char)* name) {
    /**
     * using a strong assumption that one module instance only has
     * one memory instance
     */
    cast(void)module_inst.export_memories;
    return module_inst.memories[0];
}

WASMTableInstance* wasm_lookup_table(const(WASMModuleInstance)* module_inst, const(char)* name) {
    /**
     * using a strong assumption that one module instance only has
     * one table instance
     */
    cast(void)module_inst.export_tables;
    return module_inst.tables[0];
}
}

private bool clear_wasi_proc_exit_exception(WASMModuleInstance* module_inst) {
static if (WASM_ENABLE_LIBC_WASI != 0) {
    const(char)* exception = wasm_get_exception(module_inst);
    if (exception && !strcmp(exception, "Exception: wasi proc exit")) {
        /* The "wasi proc exit" exception is thrown by native lib to
           let wasm app exit, which is a normal behavior, we clear
           the exception here. */
        wasm_set_exception(module_inst, null);
        return true;
    }
    return false;
} else {
    return false;
}
}

version (OS_ENABLE_HW_BOUND_CHECK) {

private void call_wasm_with_hw_bound_check(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv) {
    WASMExecEnv* exec_env_tls = wasm_runtime_get_exec_env_tls();
    WASMJmpBuf jmpbuf_node = { 0 }; WASMJmpBuf* jmpbuf_node_pop = void;
    uint page_size = os_getpagesize();
    uint guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    WASMRuntimeFrame* prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    ubyte* prev_top = exec_env.wasm_stack.s.top;
version (BH_PLATFORM_WINDOWS) {
    const(char)* exce = void;
    int result = void;
}
    bool ret = true;

    /* Check native stack overflow firstly to ensure we have enough
       native stack to run the following codes before actually calling
       the aot function in invokeNative function. */
    if (cast(ubyte*)&exec_env_tls < exec_env.native_stack_boundary
                                     + page_size * (guard_page_count + 1)) {
        wasm_set_exception(module_inst, "native stack overflow");
        return;
    }

    if (exec_env_tls && (exec_env_tls != exec_env)) {
        wasm_set_exception(module_inst, "invalid exec env");
        return;
    }

    if (!os_thread_signal_inited()) {
        wasm_set_exception(module_inst, "thread signal env not inited");
        return;
    }

    wasm_exec_env_push_jmpbuf(exec_env, &jmpbuf_node);

    wasm_runtime_set_exec_env_tls(exec_env);
    if (os_setjmp(jmpbuf_node.jmpbuf) == 0) {
version (BH_PLATFORM_WINDOWS) {} else {
        wasm_interp_call_wasm(module_inst, exec_env, function_, argc, argv);
} version (BH_PLATFORM_WINDOWS) {
        __try {
            wasm_interp_call_wasm(module_inst, exec_env, function_, argc, argv);
        } __except (wasm_get_exception(module_inst)
                        ? EXCEPTION_EXECUTE_HANDLER
                        : EXCEPTION_CONTINUE_SEARCH) {
            /* exception was thrown in wasm_exception_handler */
            ret = false;
        }
        if ((exce = wasm_get_exception(module_inst))
            && strstr(exce, "native stack overflow")) {
            /* After a stack overflow, the stack was left
               in a damaged state, let the CRT repair it */
            result = _resetstkoflw();
            bh_assert(result != 0);
        }
}
    }
    else {
        /* Exception has been set in signal handler before calling longjmp */
        ret = false;
    }

    /* Note: can't check wasm_get_exception(module_inst) here, there may be
     * exception which is not caught by hardware (e.g. uninitialized elements),
     * then the stack-frame is already freed inside wasm_interp_call_wasm */
    if (!ret) {
static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
        if (wasm_interp_create_call_stack(exec_env)) {
            wasm_interp_dump_call_stack(exec_env, true, null, 0);
        }
}
        /* Restore operand frames */
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);
        exec_env.wasm_stack.s.top = prev_top;
    }

    jmpbuf_node_pop = wasm_exec_env_pop_jmpbuf(exec_env);
    bh_assert(&jmpbuf_node == jmpbuf_node_pop);
    if (!exec_env.jmpbuf_stack_top) {
        wasm_runtime_set_exec_env_tls(null);
    }
    if (!ret) {
        os_sigreturn();
        os_signal_unmask();
    }
    cast(void)jmpbuf_node_pop;
}
enum interp_call_wasm = call_wasm_with_hw_bound_check;
} else {
enum interp_call_wasm = wasm_interp_call_wasm;
}

bool wasm_call_function(WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)exec_env.module_inst;

    /* set thread handle and stack boundary */
    wasm_exec_env_set_thread_info(exec_env);

    interp_call_wasm(module_inst, exec_env, function_, argc, argv);
    cast(void)clear_wasi_proc_exit_exception(module_inst);
    return !wasm_get_exception(module_inst) ? true : false;
}

bool wasm_create_exec_env_and_call_function(WASMModuleInstance* module_inst, WASMFunctionInstance* func, uint argc, uint* argv) {
    WASMExecEnv* exec_env = null, existing_exec_env = null;
    bool ret = void;

version (OS_ENABLE_HW_BOUND_CHECK) {
    existing_exec_env = exec_env = wasm_runtime_get_exec_env_tls();
} else static if (WASM_ENABLE_THREAD_MGR != 0) {
    existing_exec_env = exec_env =
        wasm_clusters_search_exec_env(cast(WASMModuleInstanceCommon*)module_inst);
}

    if (!existing_exec_env) {
        if (((exec_env =
                  wasm_exec_env_create(cast(WASMModuleInstanceCommon*)module_inst,
                                       module_inst.default_wasm_stack_size)) == 0)) {
            wasm_set_exception(module_inst, "allocate memory failed");
            return false;
        }
    }

    ret = wasm_call_function(exec_env, func, argc, argv);

    /* don't destroy the exec_env if it isn't created in this function */
    if (!existing_exec_env)
        wasm_exec_env_destroy(exec_env);

    return ret;
}

static if (WASM_ENABLE_PERF_PROFILING != 0) {
void wasm_dump_perf_profiling(const(WASMModuleInstance)* module_inst) {
    WASMExportFuncInstance* export_func = void;
    WASMFunctionInstance* func_inst = void;
    char* func_name = void;
    uint i = void, j = void;

    os_printf("Performance profiler data:\n");
    for (i = 0; i < module_inst.e.function_count; i++) {
        func_inst = module_inst.e.functions + i;
        if (func_inst.is_import_func) {
            func_name = func_inst.u.func_import.field_name;
        }
static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
        else if(func_inst field_name) {
            func_name = func_inst.u.func.field_name;
        }
}
        else func_name = null;
            for (j = 0; j < module_inst.export_func_count; j++) {
                export_func = module_inst.export_functions + j;
                if (export_func.function_ == func_inst) {
                    func_name = export_func.name;
                    break;
                }
            }
        }

        if (func_name)
            os_printf("  func %s, execution time: %.3f ms, execution count: %d "
                      ~ "times\n",
                      func_name,
                      module_inst.e.functions[i].total_exec_time / 1000.0f,
                      module_inst.e.functions[i].total_exec_cnt);
        else
            os_printf("  func %d, execution time: %.3f ms, execution count: %d "
                      ~ "times\n",
                      i, module_inst.e.functions[i].total_exec_time / 1000.0f,
                      module_inst.e.functions[i].total_exec_cnt);
    }
}
}

uint wasm_module_malloc(WASMModuleInstance* module_inst, uint size, void** p_native_addr) {
    WASMMemoryInstance* memory = wasm_get_default_memory(module_inst);
    ubyte* addr = null;
    uint offset = 0;

    if (!memory) {
        wasm_set_exception(module_inst, "uninitialized memory");
        return 0;
    }

    if (memory.heap_handle) {
        addr = mem_allocator_malloc(memory.heap_handle, size);
    }
    else if (module_inst.e.malloc_function && module_inst.e.free_function) {
        if (!execute_malloc_function(
                module_inst, module_inst.e.malloc_function,
                module_inst.e.retain_function, size, &offset)) {
            return 0;
        }
        /* If we use app's malloc function,
           the default memory may be changed while memory growing */
        memory = wasm_get_default_memory(module_inst);
        addr = offset ? memory.memory_data + offset : null;
    }

    if (!addr) {
        if (memory.heap_handle
            && mem_allocator_is_heap_corrupted(memory.heap_handle)) {
            wasm_runtime_show_app_heap_corrupted_prompt();
            wasm_set_exception(module_inst, "app heap corrupted");
        }
        else {
            LOG_WARNING("warning: allocate %u bytes memory failed", size);
        }
        return 0;
    }
    if (p_native_addr)
        *p_native_addr = addr;

    return cast(uint)(addr - memory.memory_data);
}

uint wasm_module_realloc(WASMModuleInstance* module_inst, uint ptr, uint size, void** p_native_addr) {
    WASMMemoryInstance* memory = wasm_get_default_memory(module_inst);
    ubyte* addr = null;

    if (!memory) {
        wasm_set_exception(module_inst, "uninitialized memory");
        return 0;
    }

    if (memory.heap_handle) {
        addr = mem_allocator_realloc(
            memory.heap_handle, ptr ? memory.memory_data + ptr : null, size);
    }

    /* Only support realloc in WAMR's app heap */

    if (!addr) {
        if (memory.heap_handle
            && mem_allocator_is_heap_corrupted(memory.heap_handle)) {
            wasm_set_exception(module_inst, "app heap corrupted");
        }
        else {
            wasm_set_exception(module_inst, "out of memory");
        }
        return 0;
    }
    if (p_native_addr)
        *p_native_addr = addr;

    return cast(uint)(addr - memory.memory_data);
}

void wasm_module_free(WASMModuleInstance* module_inst, uint ptr) {
    if (ptr) {
        WASMMemoryInstance* memory = wasm_get_default_memory(module_inst);
        ubyte* addr = void;

        if (!memory) {
            return;
        }

        addr = memory.memory_data + ptr;

        if (memory.heap_handle && memory.heap_data <= addr
            && addr < memory.heap_data_end) {
            mem_allocator_free(memory.heap_handle, addr);
        }
        else if (module_inst.e.malloc_function
                 && module_inst.e.free_function && memory.memory_data <= addr
                 && addr < memory.memory_data_end) {
            execute_free_function(module_inst, module_inst.e.free_function,
                                  ptr);
        }
    }
}

uint wasm_module_dup_data(WASMModuleInstance* module_inst, const(char)* src, uint size) {
    char* buffer = void;
    uint buffer_offset = wasm_module_malloc(module_inst, size, cast(void**)&buffer);
    if (buffer_offset != 0) {
        buffer = wasm_runtime_addr_app_to_native(
            cast(WASMModuleInstanceCommon*)module_inst, buffer_offset);
        bh_memcpy_s(buffer, size, src, size);
    }
    return buffer_offset;
}

static if (WASM_ENABLE_REF_TYPES != 0) {
bool wasm_enlarge_table(WASMModuleInstance* module_inst, uint table_idx, uint inc_size, uint init_val) {
    uint total_size = void; uint* new_table_data_start = void; uint i = void;
    WASMTableInstance* table_inst = void;

    if (!inc_size) {
        return true;
    }

    bh_assert(table_idx < module_inst.table_count);
    table_inst = wasm_get_table_inst(module_inst, table_idx);
    if (!table_inst) {
        return false;
    }

    if (inc_size > UINT32_MAX - table_inst.cur_size) {
        return false;
    }

    total_size = table_inst.cur_size + inc_size;
    if (total_size > table_inst.max_size) {
        return false;
    }

    /* fill in */
    new_table_data_start = table_inst.elems + table_inst.cur_size;
    for (i = 0; i < inc_size; ++i) {
        new_table_data_start[i] = init_val;
    }

    table_inst.cur_size = total_size;
    return true;
}
} /* WASM_ENABLE_REF_TYPES != 0 */

private bool call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv, bool check_type_idx, uint type_idx) {
    WASMModuleInstance* module_inst = null;
    WASMTableInstance* table_inst = null;
    uint func_idx = 0;
    WASMFunctionInstance* func_inst = null;

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    bh_assert(module_inst);

    table_inst = module_inst.tables[tbl_idx];
    if (!table_inst) {
        wasm_set_exception(module_inst, "unknown table");
        goto got_exception;
    }

    if (elem_idx >= table_inst.cur_size) {
        wasm_set_exception(module_inst, "undefined element");
        goto got_exception;
    }

    func_idx = table_inst.elems[elem_idx];
    if (func_idx == NULL_REF) {
        wasm_set_exception(module_inst, "uninitialized element");
        goto got_exception;
    }

    /**
     * we insist to call functions owned by the module itself
     **/
    if (func_idx >= module_inst.e.function_count) {
        wasm_set_exception(module_inst, "unknown function");
        goto got_exception;
    }

    func_inst = module_inst.e.functions + func_idx;

    if (check_type_idx) {
        WASMType* cur_type = module_inst.module_.types[type_idx];
        WASMType* cur_func_type = void;

        if (func_inst.is_import_func)
            cur_func_type = func_inst.u.func_import.func_type;
        else
            cur_func_type = func_inst.u.func.func_type;

        if (cur_type != cur_func_type) {
            wasm_set_exception(module_inst, "indirect call type mismatch");
            goto got_exception;
        }
    }

    interp_call_wasm(module_inst, exec_env, func_inst, argc, argv);

    cast(void)clear_wasi_proc_exit_exception(module_inst);
    return !wasm_get_exception(module_inst) ? true : false;

got_exception:
    return false;
}

bool wasm_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv) {
    return call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, false, 0);
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
bool wasm_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    uint stack_top_idx = module_inst.module_.aux_stack_top_global_index;
    uint data_end = module_inst.module_.aux_data_end;
    uint stack_bottom = module_inst.module_.aux_stack_bottom;
    bool is_stack_before_data = stack_bottom < data_end ? true : false;

    /* Check the aux stack space, currently we don't allocate space in heap */
    if ((is_stack_before_data && (size > start_offset))
        || ((!is_stack_before_data) && (start_offset - data_end < size)))
        return false;

    if (stack_top_idx != cast(uint)-1) {
        /* The aux stack top is a wasm global,
            set the initial value for the global */
        ubyte* global_addr = module_inst.global_data
            + module_inst.e.globals[stack_top_idx].data_offset;
        *cast(int*)global_addr = start_offset;
        /* The aux stack boundary is a constant value,
            set the value to exec_env */
        exec_env.aux_stack_boundary.boundary = start_offset - size;
        exec_env.aux_stack_bottom.bottom = start_offset;
        return true;
    }

    return false;
}

bool wasm_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)exec_env.module_inst;

    /* The aux stack information is resolved in loader
        and store in module */
    uint stack_bottom = module_inst.module_.aux_stack_bottom;
    uint total_aux_stack_size = module_inst.module_.aux_stack_size;

    if (stack_bottom != 0 && total_aux_stack_size != 0) {
        if (start_offset)
            *start_offset = stack_bottom;
        if (size)
            *size = total_aux_stack_size;
        return true;
    }
    return false;
}
}

static if ((WASM_ENABLE_MEMORY_PROFILING != 0) || (WASM_ENABLE_MEMORY_TRACING != 0)) {
void wasm_get_module_mem_consumption(const(WASMModule)* module_, WASMModuleMemConsumption* mem_conspn) {
    uint i = void, size = void;

    memset(mem_conspn, 0, typeof(*mem_conspn).sizeof);

    mem_conspn.module_struct_size = WASMModule.sizeof;

    mem_conspn.types_size = (WASMType*).sizeof * module_.type_count;
    for (i = 0; i < module_.type_count; i++) {
        WASMType* type = module_.types[i];
        size = WASMType.types.offsetof
               + sizeof(uint8) * (type.param_count + type.result_count);
        mem_conspn.types_size += size;
    }

    mem_conspn.imports_size = sizeof(WASMImport) * module_.import_count;

    mem_conspn.functions_size =
        (WASMFunction*).sizeof * module_.function_count;
    for (i = 0; i < module_.function_count; i++) {
        WASMFunction* func = module_.functions[i];
        WASMType* type = func.func_type;
        size = sizeof(WASMFunction) + func.local_count
               + sizeof(uint16) * (type.param_count + func.local_count);
static if (WASM_ENABLE_FAST_INTERP != 0) {
        size +=
            func.code_compiled_size + sizeofcast(uint) * func.const_cell_num;
}
        mem_conspn.functions_size += size;
    }

    mem_conspn.tables_size = sizeof(WASMTable) * module_.table_count;
    mem_conspn.memories_size = sizeof(WASMMemory) * module_.memory_count;
    mem_conspn.globals_size = sizeof(WASMGlobal) * module_.global_count;
    mem_conspn.exports_size = sizeof(WASMExport) * module_.export_count;

    mem_conspn.table_segs_size =
        sizeof(WASMTableSeg) * module_.table_seg_count;
    for (i = 0; i < module_.table_seg_count; i++) {
        WASMTableSeg* table_seg = &module_.table_segments[i];
        mem_conspn.tables_size += sizeofcast(uint) * table_seg.function_count;
    }

    mem_conspn.data_segs_size = (WASMDataSeg*).sizeof * module_.data_seg_count;
    for (i = 0; i < module_.data_seg_count; i++) {
        mem_conspn.data_segs_size += WASMDataSeg.sizeof;
    }

    if (module_.const_str_list) {
        StringNode* node = module_.const_str_list, node_next = void;
        while (node) {
            node_next = node.next;
            mem_conspn.const_strs_size +=
                sizeof(StringNode) + strlen(node.str) + 1;
            node = node_next;
        }
    }

    mem_conspn.total_size += mem_conspn.module_struct_size;
    mem_conspn.total_size += mem_conspn.types_size;
    mem_conspn.total_size += mem_conspn.imports_size;
    mem_conspn.total_size += mem_conspn.functions_size;
    mem_conspn.total_size += mem_conspn.tables_size;
    mem_conspn.total_size += mem_conspn.memories_size;
    mem_conspn.total_size += mem_conspn.globals_size;
    mem_conspn.total_size += mem_conspn.exports_size;
    mem_conspn.total_size += mem_conspn.table_segs_size;
    mem_conspn.total_size += mem_conspn.data_segs_size;
    mem_conspn.total_size += mem_conspn.const_strs_size;
}

void wasm_get_module_inst_mem_consumption(const(WASMModuleInstance)* module_inst, WASMModuleInstMemConsumption* mem_conspn) {
    uint i = void, size = void;

    memset(mem_conspn, 0, typeof(*mem_conspn).sizeof);

    mem_conspn.module_inst_struct_size = cast(ubyte*)module_inst.e
                                          - cast(ubyte*)module_inst
                                          + WASMModuleInstanceExtra.sizeof;

    mem_conspn.memories_size =
        (WASMMemoryInstance*).sizeof * module_inst.memory_count;
    for (i = 0; i < module_inst.memory_count; i++) {
        WASMMemoryInstance* memory = module_inst.memories[i];
        size = memory.num_bytes_per_page * memory.cur_page_count;
        mem_conspn.memories_size += size;
        mem_conspn.app_heap_size += memory.heap_data_end - memory.heap_data;
        /* size of app heap structure */
        mem_conspn.memories_size += mem_allocator_get_heap_struct_size();
        /* Module instance structures have been appened into the end of
           module instance */
    }

    mem_conspn.tables_size =
        (WASMTableInstance*).sizeof * module_inst.table_count;
    /* Table instance structures and table elements have been appened into
       the end of module instance */

    mem_conspn.functions_size =
        sizeof(WASMFunctionInstance) * module_inst.e.function_count;

    mem_conspn.globals_size =
        sizeof(WASMGlobalInstance) * module_inst.e.global_count;
    /* Global data has been appened into the end of module instance */

    mem_conspn.exports_size =
        sizeof(WASMExportFuncInstance) * module_inst.export_func_count;

    mem_conspn.total_size += mem_conspn.module_inst_struct_size;
    mem_conspn.total_size += mem_conspn.memories_size;
    mem_conspn.total_size += mem_conspn.functions_size;
    mem_conspn.total_size += mem_conspn.tables_size;
    mem_conspn.total_size += mem_conspn.globals_size;
    mem_conspn.total_size += mem_conspn.exports_size;
}
} /* end of (WASM_ENABLE_MEMORY_PROFILING != 0) \
                 || (WASM_ENABLE_MEMORY_TRACING != 0) */

static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
bool wasm_interp_create_call_stack(WASMExecEnv* exec_env) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)wasm_exec_env_get_module_inst(exec_env);
    WASMInterpFrame* first_frame = void, cur_frame = wasm_exec_env_get_cur_frame(exec_env);
    uint n = 0;

    /* count frames includes a function */
    first_frame = cur_frame;
    while (cur_frame) {
        if (cur_frame.function_) {
            n++;
        }
        cur_frame = cur_frame.prev_frame;
    }

    /* release previous stack frames and create new ones */
    if (!bh_vector_destroy(module_inst.frames)
        || !bh_vector_init(module_inst.frames, n, WASMCApiFrame.sizeof,
                           false)) {
        return false;
    }

    cur_frame = first_frame;
    n = 0;

    while (cur_frame) {
        WASMCApiFrame frame = { 0 };
        WASMFunctionInstance* func_inst = cur_frame.function_;
        const(char)* func_name = null;
        const(ubyte)* func_code_base = null;

        if (!func_inst) {
            cur_frame = cur_frame.prev_frame;
            continue;
        }

        /* place holder, will overwrite it in wasm_c_api */
        frame.instance = module_inst;
        frame.module_offset = 0;
        frame.func_index = cast(uint)(func_inst - module_inst.e.functions);

        func_code_base = wasm_get_func_code(func_inst);
        if (!cur_frame.ip || !func_code_base) {
            frame.func_offset = 0;
        }
        else {
            frame.func_offset = cast(uint)(cur_frame.ip - func_code_base);
        }

        /* look for the function name */
        if (func_inst.is_import_func) {
            func_name = func_inst.u.func_import.field_name;
        }
        else {
static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
            func_name = func_inst.u.func.field_name;
}
            /* if custom name section is not generated,
                search symbols from export table */
            if (!func_name) {
                uint i = void;
                for (i = 0; i < module_inst.export_func_count; i++) {
                    WASMExportFuncInstance* export_func = module_inst.export_functions + i;
                    if (export_func.function_ == func_inst) {
                        func_name = export_func.name;
                        break;
                    }
                }
            }
        }

        frame.func_name_wp = func_name;

        if (!bh_vector_append(module_inst.frames, &frame)) {
            bh_vector_destroy(module_inst.frames);
            return false;
        }

        cur_frame = cur_frame.prev_frame;
        n++;
    }

    return true;
}

enum string PRINT_OR_DUMP() = `                                                   \
    do {                                                                  \
        total_len +=                                                      \
            wasm_runtime_dump_line_buf_impl(line_buf, print, &buf, &len); \
        if ((!print) && buf && (len == 0)) {                              \
            return total_len;                                             \
        }                                                                 \
    } while (0)`;

uint wasm_interp_dump_call_stack(WASMExecEnv* exec_env, bool print, char* buf, uint len) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)wasm_exec_env_get_module_inst(exec_env);
    uint n = 0, total_len = 0, total_frames = void;
    /* reserve 256 bytes for line buffer, any line longer than 256 bytes
     * will be truncated */
    char[256] line_buf = void;

    if (!module_inst.frames) {
        return 0;
    }

    total_frames = cast(uint)bh_vector_size(module_inst.frames);
    if (total_frames == 0) {
        return 0;
    }

    snprintf(line_buf.ptr, line_buf.sizeof, "\n");
    PRINT_OR_DUMP();

    while (n < total_frames) {
        WASMCApiFrame frame = { 0 };
        uint line_length = void, i = void;

        if (!bh_vector_get(module_inst.frames, n, &frame)) {
            return 0;
        }

        /* function name not exported, print number instead */
        if (frame.func_name_wp == null) {
            line_length = snprintf(line_buf.ptr, line_buf.sizeof, "#%02d $f%d\n",
                                   n, frame.func_index);
        }
        else {
            line_length = snprintf(line_buf.ptr, line_buf.sizeof, "#%02d %s\n", n,
                                   frame.func_name_wp);
        }

        if (line_length >= line_buf.sizeof) {
            uint line_buffer_len = line_buf.sizeof;
            /* If line too long, ensure the last character is '\n' */
            for (i = line_buffer_len - 5; i < line_buffer_len - 2; i++) {
                line_buf[i] = '.';
            }
            line_buf[line_buffer_len - 2] = '\n';
        }

        PRINT_OR_DUMP();

        n++;
    }
    snprintf(line_buf.ptr, line_buf.sizeof, "\n");
    PRINT_OR_DUMP();

    return total_len + 1;
}
} /* end of WASM_ENABLE_DUMP_CALL_STACK */

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0) {
void jit_set_exception_with_id(WASMModuleInstance* module_inst, uint id) {
    if (id != EXCE_ALREADY_THROWN)
        wasm_set_exception_with_id(module_inst, id);
version (OS_ENABLE_HW_BOUND_CHECK) {
    wasm_runtime_access_exce_check_guard_page();
}
}

bool jit_check_app_addr_and_convert(WASMModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr) {
    bool ret = wasm_check_app_addr_and_convert(
        module_inst, is_str, app_buf_addr, app_buf_size, p_native_addr);

version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
}

    return ret;
}
} /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
          || WASM_ENABLE_WAMR_COMPILER != 0 */

static if (WASM_ENABLE_FAST_JIT != 0) {
bool fast_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint type_idx, uint argc, uint* argv) {
    return call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, true,
                         type_idx);
}
} /* end of WASM_ENABLE_FAST_JIT != 0 */

static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {

bool llvm_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv) {
    bool ret = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == exec_env.module_inst.module_type) {
        return aot_call_indirect(exec_env, tbl_idx, elem_idx, argc, argv);
    }
}

    ret = call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, false, 0);
version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
}
    return ret;
}

bool llvm_jit_invoke_native(WASMExecEnv* exec_env, uint func_idx, uint argc, uint* argv) {
    WASMModuleInstance* module_inst = void;
    WASMModule* module_ = void;
    uint* func_type_indexes = void;
    uint func_type_idx = void;
    WASMType* func_type = void;
    void* func_ptr = void;
    WASMFunctionImport* import_func = void;
    CApiFuncImport* c_api_func_import = null;
    const(char)* signature = void;
    void* attachment = void;
    char[96] buf = void;
    bool ret = false;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == exec_env.module_inst.module_type) {
        return aot_invoke_native(exec_env, func_idx, argc, argv);
    }
}

    module_inst = cast(WASMModuleInstance*)wasm_runtime_get_module_inst(exec_env);
    module_ = module_inst.module_;
    func_type_indexes = module_inst.func_type_indexes;
    func_type_idx = func_type_indexes[func_idx];
    func_type = module_.types[func_type_idx];
    func_ptr = module_inst.func_ptrs[func_idx];

    bh_assert(func_idx < module_.import_function_count);

    import_func = &module_.import_functions[func_idx].u.function_;
    if (import_func.call_conv_wasm_c_api) {
        c_api_func_import = module_inst.e.c_api_func_imports + func_idx;
        func_ptr = c_api_func_import.func_ptr_linked;
    }

    if (!func_ptr) {
        snprintf(buf.ptr, buf.sizeof,
                 "failed to call unlinked import function (%s, %s)",
                 import_func.module_name, import_func.field_name);
        wasm_set_exception(module_inst, buf.ptr);
        goto fail;
    }

    attachment = import_func.attachment;
    if (import_func.call_conv_wasm_c_api) {
        ret = wasm_runtime_invoke_c_api_native(
            cast(WASMModuleInstanceCommon*)module_inst, func_ptr, func_type, argc,
            argv, c_api_func_import.with_env_arg, c_api_func_import.env_arg);
    }
    else if (!import_func.call_conv_raw) {
        signature = import_func.signature;
        ret =
            wasm_runtime_invoke_native(exec_env, func_ptr, func_type, signature,
                                       attachment, argv, argc, argv);
    }
    else {
        signature = import_func.signature;
        ret = wasm_runtime_invoke_native_raw(exec_env, func_ptr, func_type,
                                             signature, attachment, argv, argc,
                                             argv);
    }

fail:
version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
}
    return ret;
}

static if (WASM_ENABLE_BULK_MEMORY != 0) {
bool llvm_jit_memory_init(WASMModuleInstance* module_inst, uint seg_index, uint offset, uint len, uint dst) {
    WASMMemoryInstance* memory_inst = void;
    WASMModule* module_ = void;
    ubyte* data = null;
    ubyte* maddr = void;
    ulong seg_len = 0;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        return aot_memory_init(module_inst, seg_index, offset, len, dst);
    }
}

    memory_inst = wasm_get_default_memory(module_inst);
    module_ = module_inst.module_;
    seg_len = module_.data_segments[seg_index].data_length;
    data = module_.data_segments[seg_index].data;

    if (!wasm_runtime_validate_app_addr(cast(WASMModuleInstanceCommon*)module_inst,
                                        dst, len))
        return false;

    if (cast(ulong)offset + cast(ulong)len > seg_len) {
        wasm_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    maddr = wasm_runtime_addr_app_to_native(
        cast(WASMModuleInstanceCommon*)module_inst, dst);

    bh_memcpy_s(maddr, memory_inst.memory_data_size - dst, data + offset, len);
    return true;
}

bool llvm_jit_data_drop(WASMModuleInstance* module_inst, uint seg_index) {
static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        return aot_data_drop(module_inst, seg_index);
    }
}

    module_inst.module_.data_segments[seg_index].data_length = 0;
    /* Currently we can't free the dropped data segment
       as they are stored in wasm bytecode */
    return true;
}
} /* end of WASM_ENABLE_BULK_MEMORY != 0 */

static if (WASM_ENABLE_REF_TYPES != 0) {
void llvm_jit_drop_table_seg(WASMModuleInstance* module_inst, uint tbl_seg_idx) {
    WASMTableSeg* tbl_segs = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        return aot_drop_table_seg(module_inst, tbl_seg_idx);
    }
}

    tbl_segs = module_inst.module_.table_segments;
    tbl_segs[tbl_seg_idx].is_dropped = true;
}

void llvm_jit_table_init(WASMModuleInstance* module_inst, uint tbl_idx, uint tbl_seg_idx, uint length, uint src_offset, uint dst_offset) {
    WASMTableInstance* tbl_inst = void;
    WASMTableSeg* tbl_seg = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        return aot_table_init(module_inst, tbl_idx, tbl_seg_idx, length,
                              src_offset, dst_offset);
    }
}

    tbl_inst = wasm_get_table_inst(module_inst, tbl_idx);
    tbl_seg = module_inst.module_.table_segments + tbl_seg_idx;

    bh_assert(tbl_inst);
    bh_assert(tbl_seg);

    if (!length) {
        return;
    }

    if (length + src_offset > tbl_seg.function_count
        || dst_offset + length > tbl_inst.cur_size) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    if (tbl_seg.is_dropped) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    if (!wasm_elem_is_passive(tbl_seg.mode)) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    bh_memcpy_s(cast(ubyte*)tbl_inst + WASMTableInstance.elems.offsetof
                    + dst_offset * uint32.sizeof,
                cast(uint)sizeofcast(uint) * (tbl_inst.cur_size - dst_offset),
                tbl_seg.func_indexes + src_offset,
                cast(uint)(length * uint32.sizeof));
}

void llvm_jit_table_copy(WASMModuleInstance* module_inst, uint src_tbl_idx, uint dst_tbl_idx, uint length, uint src_offset, uint dst_offset) {
    WASMTableInstance* src_tbl_inst = void;
    WASMTableInstance* dst_tbl_inst = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        aot_table_copy(module_inst, src_tbl_idx, dst_tbl_idx, length,
                       src_offset, dst_offset);
        return;
    }
}

    src_tbl_inst = wasm_get_table_inst(module_inst, src_tbl_idx);
    dst_tbl_inst = wasm_get_table_inst(module_inst, dst_tbl_idx);
    bh_assert(src_tbl_inst);
    bh_assert(dst_tbl_inst);

    if (cast(ulong)dst_offset + length > dst_tbl_inst.cur_size
        || cast(ulong)src_offset + length > src_tbl_inst.cur_size) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    /* if src_offset >= dst_offset, copy from front to back */
    /* if src_offset < dst_offset, copy from back to front */
    /* merge all together */
    bh_memmove_s(cast(ubyte*)dst_tbl_inst + WASMTableInstance.elems.offsetof
                     + sizeofcast(uint) * dst_offset,
                 cast(uint)sizeofcast(uint) * (dst_tbl_inst.cur_size - dst_offset),
                 cast(ubyte*)src_tbl_inst + WASMTableInstance.elems.offsetof
                     + sizeofcast(uint) * src_offset,
                 cast(uint)sizeofcast(uint) * length);
}

void llvm_jit_table_fill(WASMModuleInstance* module_inst, uint tbl_idx, uint length, uint val, uint data_offset) {
    WASMTableInstance* tbl_inst = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        aot_table_fill(module_inst, tbl_idx, length, val, data_offset);
        return;
    }
}

    tbl_inst = wasm_get_table_inst(module_inst, tbl_idx);
    bh_assert(tbl_inst);

    if (data_offset + length > tbl_inst.cur_size) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    for (; length != 0; data_offset++, length--) {
        tbl_inst.elems[data_offset] = val;
    }
}

uint llvm_jit_table_grow(WASMModuleInstance* module_inst, uint tbl_idx, uint inc_size, uint init_val) {
    WASMTableInstance* tbl_inst = void;
    uint i = void, orig_size = void, total_size = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == module_inst.module_type) {
        return aot_table_grow(module_inst, tbl_idx, inc_size, init_val);
    }
}

    tbl_inst = wasm_get_table_inst(module_inst, tbl_idx);
    if (!tbl_inst) {
        return cast(uint)-1;
    }

    orig_size = tbl_inst.cur_size;

    if (!inc_size) {
        return orig_size;
    }

    if (tbl_inst.cur_size > UINT32_MAX - inc_size) { /* integer overflow */
        return cast(uint)-1;
    }

    total_size = tbl_inst.cur_size + inc_size;
    if (total_size > tbl_inst.max_size) {
        return cast(uint)-1;
    }

    /* fill in */
    for (i = 0; i < inc_size; ++i) {
        tbl_inst.elems[tbl_inst.cur_size + i] = init_val;
    }

    tbl_inst.cur_size = total_size;
    return orig_size;
}
} /* end of WASM_ENABLE_REF_TYPES != 0 */

static if (WASM_ENABLE_DUMP_CALL_STACK != 0 || WASM_ENABLE_PERF_PROFILING != 0) {
bool llvm_jit_alloc_frame(WASMExecEnv* exec_env, uint func_index) {
    WASMModuleInstance* module_inst = void;
    WASMInterpFrame* frame = void;
    uint size = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == exec_env.module_inst.module_type) {
        return aot_alloc_frame(exec_env, func_index);
    }
}

    module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    size = wasm_interp_interp_frame_size(0);

    frame = wasm_exec_env_alloc_wasm_frame(exec_env, size);
    if (!frame) {
        wasm_set_exception(module_inst, "wasm operand stack overflow");
        return false;
    }

    frame.function_ = module_inst.e.functions + func_index;
    frame.ip = null;
    frame.sp = frame.lp;
static if (WASM_ENABLE_PERF_PROFILING != 0) {
    frame.time_started = os_time_get_boot_microsecond();
}
    frame.prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    wasm_exec_env_set_cur_frame(exec_env, frame);

    return true;
}

void llvm_jit_free_frame(WASMExecEnv* exec_env) {
    WASMInterpFrame* frame = void;
    WASMInterpFrame* prev_frame = void;

static if (WASM_ENABLE_JIT != 0) {
    if (Wasm_Module_AoT == exec_env.module_inst.module_type) {
        aot_free_frame(exec_env);
        return;
    }
}

    frame = wasm_exec_env_get_cur_frame(exec_env);
    prev_frame = frame.prev_frame;

static if (WASM_ENABLE_PERF_PROFILING != 0) {
    if (frame.function_) {
        frame.function_.total_exec_time +=
            os_time_get_boot_microsecond() - frame.time_started;
        frame.function_.total_exec_cnt++;
    }
}
    wasm_exec_env_free_wasm_frame(exec_env, frame);
    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
}
} /* end of WASM_ENABLE_DUMP_CALL_STACK != 0 \
          || WASM_ENABLE_PERF_PROFILING != 0 */

} /* end of WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0 */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_RUNTIME_H
version = _WASM_RUNTIME_H;

public import wasm;
public import bh_hashmap;
public import ...common.wasm_runtime_common;
public import ...common.wasm_exec_env;

#ifdef __cplusplus
extern "C" {
//! #endif







/**
 * When LLVM JIT, WAMR compiler or AOT is enabled, we should ensure that
 * some offsets of the same field in the interpreter module instance and
 * aot module instance are the same, so that the LLVM JITed/AOTed code
 * can smoothly access the interpreter module instance.
 * Same for the memory instance and table instance.
 * We use the macro DefPointer to define some related pointer fields.
 */
static if ((WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0 \
     || WASM_ENABLE_AOT != 0)                               \
    && UINTPTR_MAX == UINT32_MAX) {
/* Add u32 padding if LLVM JIT, WAMR compiler or AOT is enabled on
   32-bit platform */
enum string DefPointer(string type, string field) = ` \
    type field;                 \
    uint32 field##_padding`;
} else {
enum string DefPointer(string type, string field) = ` type field`;
}

enum WASMExceptionID {
    EXCE_UNREACHABLE = 0,
    EXCE_OUT_OF_MEMORY,
    EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS,
    EXCE_INTEGER_OVERFLOW,
    EXCE_INTEGER_DIVIDE_BY_ZERO,
    EXCE_INVALID_CONVERSION_TO_INTEGER,
    EXCE_INVALID_FUNCTION_TYPE_INDEX,
    EXCE_INVALID_FUNCTION_INDEX,
    EXCE_UNDEFINED_ELEMENT,
    EXCE_UNINITIALIZED_ELEMENT,
    EXCE_CALL_UNLINKED_IMPORT_FUNC,
    EXCE_NATIVE_STACK_OVERFLOW,
    EXCE_UNALIGNED_ATOMIC,
    EXCE_AUX_STACK_OVERFLOW,
    EXCE_AUX_STACK_UNDERFLOW,
    EXCE_OUT_OF_BOUNDS_TABLE_ACCESS,
    EXCE_OPERAND_STACK_OVERFLOW,
#if WASM_ENABLE_FAST_JIT != 0
    EXCE_FAILED_TO_COMPILE_FAST_JIT_FUNC,
}
    EXCE_ALREADY_THROWN,
    EXCE_NUM,
}
alias EXCE_UNREACHABLE = WASMExceptionID.EXCE_UNREACHABLE;
alias EXCE_OUT_OF_MEMORY = WASMExceptionID.EXCE_OUT_OF_MEMORY;
alias EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS = WASMExceptionID.EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS;
alias EXCE_INTEGER_OVERFLOW = WASMExceptionID.EXCE_INTEGER_OVERFLOW;
alias EXCE_INTEGER_DIVIDE_BY_ZERO = WASMExceptionID.EXCE_INTEGER_DIVIDE_BY_ZERO;
alias EXCE_INVALID_CONVERSION_TO_INTEGER = WASMExceptionID.EXCE_INVALID_CONVERSION_TO_INTEGER;
alias EXCE_INVALID_FUNCTION_TYPE_INDEX = WASMExceptionID.EXCE_INVALID_FUNCTION_TYPE_INDEX;
alias EXCE_INVALID_FUNCTION_INDEX = WASMExceptionID.EXCE_INVALID_FUNCTION_INDEX;
alias EXCE_UNDEFINED_ELEMENT = WASMExceptionID.EXCE_UNDEFINED_ELEMENT;
alias EXCE_UNINITIALIZED_ELEMENT = WASMExceptionID.EXCE_UNINITIALIZED_ELEMENT;
alias EXCE_CALL_UNLINKED_IMPORT_FUNC = WASMExceptionID.EXCE_CALL_UNLINKED_IMPORT_FUNC;
alias EXCE_NATIVE_STACK_OVERFLOW = WASMExceptionID.EXCE_NATIVE_STACK_OVERFLOW;
alias EXCE_UNALIGNED_ATOMIC = WASMExceptionID.EXCE_UNALIGNED_ATOMIC;
alias EXCE_AUX_STACK_OVERFLOW = WASMExceptionID.EXCE_AUX_STACK_OVERFLOW;
alias EXCE_AUX_STACK_UNDERFLOW = WASMExceptionID.EXCE_AUX_STACK_UNDERFLOW;
alias EXCE_OUT_OF_BOUNDS_TABLE_ACCESS = WASMExceptionID.EXCE_OUT_OF_BOUNDS_TABLE_ACCESS;
alias EXCE_OPERAND_STACK_OVERFLOW = WASMExceptionID.EXCE_OPERAND_STACK_OVERFLOW;
alias EXCE_FAILED_TO_COMPILE_FAST_JIT_FUNC = WASMExceptionID.EXCE_FAILED_TO_COMPILE_FAST_JIT_FUNC;
alias EXCE_ALREADY_THROWN = WASMExceptionID.EXCE_ALREADY_THROWN;
alias EXCE_NUM = WASMExceptionID.EXCE_NUM;


union _MemBound {
    ulong u64;
    uint[2] u32;
}alias MemBound = _MemBound;

struct WASMMemoryInstance {
    /* Module type */
    uint module_type;
    /* Shared memory flag */
    bool is_shared;

    /* Number bytes per page */
    uint num_bytes_per_page;
    /* Current page count */
    uint cur_page_count;
    /* Maximum page count */
    uint max_page_count;
    /* Memory data size */
    uint memory_data_size;
    /**
     * Memory data begin address, Note:
     *   the app-heap might be inserted in to the linear memory,
     *   when memory is re-allocated, the heap data and memory data
     *   must be copied to new memory also
     */
    ;
    /* Memory data end address */
    ;

    /* Heap data base address */
    ;
    /* Heap data end address */
    ;
    /* The heap created */
    ;

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_AOT != 0) {
    MemBound mem_bound_check_1byte;
    MemBound mem_bound_check_2bytes;
    MemBound mem_bound_check_4bytes;
    MemBound mem_bound_check_8bytes;
    MemBound mem_bound_check_16bytes;
}
};

struct WASMTableInstance {
    /* Current size */
    uint cur_size;
    /* Maximum size */
    uint max_size;
    /* Table elements */
    uint[1] elems;
};

struct WASMGlobalInstance {
    /* value type, VALUE_TYPE_I32/I64/F32/F64 */
    ubyte type;
    /* mutable or constant */
    bool is_mutable;
    /* data offset to base_addr of WASMMemoryInstance */
    uint data_offset;
    /* initial value */
    WASMValue initial_value;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    /* just for import, keep the reference here */
    WASMModuleInstance* import_module_inst;
    WASMGlobalInstance* import_global_inst;
}
};

struct WASMFunctionInstance {
    /* whether it is import function or WASM function */
    bool is_import_func;
    /* parameter count */
    ushort param_count;
    /* local variable count, 0 for import function */
    ushort local_count;
    /* cell num of parameters */
    ushort param_cell_num;
    /* cell num of return type */
    ushort ret_cell_num;
    /* cell num of local variables, 0 for import function */
    ushort local_cell_num;
static if (WASM_ENABLE_FAST_INTERP != 0) {
    /* cell num of consts */
    ushort const_cell_num;
}
    ushort* local_offsets;
    /* parameter types */
    ubyte* param_types;
    /* local types, NULL for import function */
    ubyte* local_types;
    union _U {
        WASMFunctionImport* func_import;
        WASMFunction* func;
    }_U u;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    WASMModuleInstance* import_module_inst;
    WASMFunctionInstance* import_func_inst;
}
static if (WASM_ENABLE_PERF_PROFILING != 0) {
    /* total execution time */
    ulong total_exec_time;
    /* total execution count */
    uint total_exec_cnt;
}
};

struct WASMExportFuncInstance {
    char* name;
    WASMFunctionInstance* function_;
}

struct WASMExportGlobInstance {
    char* name;
    WASMGlobalInstance* global;
}

struct WASMExportTabInstance {
    char* name;
    WASMTableInstance* table;
}

struct WASMExportMemInstance {
    char* name;
    WASMMemoryInstance* memory;
}

/* wasm-c-api import function info */
struct CApiFuncImport {
    /* host func pointer after linked */
    void* func_ptr_linked;
    /* whether the host func has env argument */
    bool with_env_arg;
    /* the env argument of the host func */
    void* env_arg;
}

/* Extra info of WASM module instance for interpreter/jit mode */
struct WASMModuleInstanceExtra {
    WASMGlobalInstance* globals;
    WASMFunctionInstance* functions;

    uint global_count;
    uint function_count;

    WASMFunctionInstance* start_function;
    WASMFunctionInstance* malloc_function;
    WASMFunctionInstance* free_function;
    WASMFunctionInstance* retain_function;

    CApiFuncImport* c_api_func_imports;

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    /* lock for shared memory atomic operations */
    korp_mutex mem_lock;
    bool mem_lock_inited;
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
    bh_list sub_module_inst_list_head;
    bh_list* sub_module_inst_list;
    /* linked table instances of import table instances */
    WASMTableInstance** table_insts_linked;
}

static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
    uint max_aux_stack_used;
}

static if (WASM_ENABLE_DEBUG_INTERP != 0                    \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT \
        && WASM_ENABLE_LAZY_JIT != 0)) {
    WASMModuleInstance* next;
}
}

struct AOTFuncPerfProfInfo;;

struct WASMModuleInstance {
    /* Module instance type, for module instance loaded from
       WASM bytecode binary, this field is Wasm_Module_Bytecode;
       for module instance loaded from AOT file, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModuleInstance structure. */
    uint module_type;

    uint memory_count;
    ;

    /* global and table info */
    uint global_data_size;
    uint table_count;
    ;
    /* For AOTModuleInstance, it denotes `AOTTableInstance *` */
    ;

    /* import func ptrs + llvm jit func ptrs */
    ;

    /* function type indexes */
    ;

    uint export_func_count;
    uint export_global_count;
    uint export_memory_count;
    uint export_table_count;
    /* For AOTModuleInstance, it denotes `AOTFunctionInstance *` */
    ;
    ;
    ;
    ;

    /* The exception buffer of wasm interpreter for current thread. */
    char[128] cur_exception = 0;

    /* The WASM module or AOT module, for AOTModuleInstance,
       it denotes `AOTModule *` */
    ;

static if (WASM_ENABLE_LIBC_WASI) {
    /* WASI context */
    ;
} else {
    ;
}
    ;
    /* Array of function pointers to import functions,
       not available in AOTModuleInstance */
    ;
    /* Array of function pointers to fast jit functions,
       not available in AOTModuleInstance */
    ;
    /* The custom data that can be set/get by wasm_{get|set}_custom_data */
    ;
    /* Stack frames, used in call stack dump and perf profiling */
    ;
    /* Function performance profiling info list, only available
       in AOTModuleInstance */
    ;
    /* WASM/AOT module extra info, for AOTModuleInstance,
       it denotes `AOTModuleInstanceExtra *` */
    ;

    /* Default WASM operand stack size */
    uint default_wasm_stack_size;
    uint[3] reserved;

    /*
     * +------------------------------+ <-- memories
     * | WASMMemoryInstance[mem_count], mem_count is always 1 for LLVM JIT/AOT
     * +------------------------------+ <-- global_data
     * | global data
     * +------------------------------+ <-- tables
     * | WASMTableInstance[table_count]
     * +------------------------------+ <-- e
     * | WASMModuleInstanceExtra
     * +------------------------------+
     */
    union _Global_table_data {
        ulong _make_it_8_byte_aligned_;
        WASMMemoryInstance[1] memory_instances;
        ubyte[1] bytes;
    }_Global_table_data global_table_data;
};

struct WASMInterpFrame;;
alias WASMRuntimeFrame = WASMInterpFrame;

static if (WASM_ENABLE_MULTI_MODULE != 0) {
struct WASMSubModInstNode {
    bh_list_link l;
    /* point to a string pool */
    const(char)* module_name;
    WASMModuleInstance* module_inst;
}
}

/**
 * Return the code block of a function.
 *
 * @param func the WASM function instance
 *
 * @return the code block of the function
 */
pragma(inline, true) private ubyte* wasm_get_func_code(WASMFunctionInstance* func) {
static if (WASM_ENABLE_FAST_INTERP == 0) {
    return func.is_import_func ? null : func.u.func.code;
} else {
    return func.is_import_func ? null : func.u.func.code_compiled;
}
}

/**
 * Return the code block end of a function.
 *
 * @param func the WASM function instance
 *
 * @return the code block end of the function
 */
pragma(inline, true) private ubyte* wasm_get_func_code_end(WASMFunctionInstance* func) {
static if (WASM_ENABLE_FAST_INTERP == 0) {
    return func.is_import_func ? null
                                : func.u.func.code + func.u.func.code_size;
} else {
    return func.is_import_func
               ? null
               : func.u.func.code_compiled + func.u.func.code_compiled_size;
}
}

WASMModule* wasm_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size);

WASMModule* wasm_load_from_sections(WASMSection* section_list, char* error_buf, uint error_buf_size);

void wasm_unload(WASMModule* module_);

WASMModuleInstance* wasm_instantiate(WASMModule* module_, bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size);

void wasm_dump_perf_profiling(const(WASMModuleInstance)* module_inst);

void wasm_deinstantiate(WASMModuleInstance* module_inst, bool is_sub_inst);

WASMFunctionInstance* wasm_lookup_function(const(WASMModuleInstance)* module_inst, const(char)* name, const(char)* signature);

static if (WASM_ENABLE_MULTI_MODULE != 0) {
WASMGlobalInstance* wasm_lookup_global(const(WASMModuleInstance)* module_inst, const(char)* name);

WASMMemoryInstance* wasm_lookup_memory(const(WASMModuleInstance)* module_inst, const(char)* name);

WASMTableInstance* wasm_lookup_table(const(WASMModuleInstance)* module_inst, const(char)* name);
}

bool wasm_call_function(WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv);

bool wasm_create_exec_env_and_call_function(WASMModuleInstance* module_inst, WASMFunctionInstance* function_, uint argc, uint* argv);

void wasm_set_exception(WASMModuleInstance* module_, const(char)* exception);

void wasm_set_exception_with_id(WASMModuleInstance* module_inst, uint id);

const(char)* wasm_get_exception(WASMModuleInstance* module_);

uint wasm_module_malloc(WASMModuleInstance* module_inst, uint size, void** p_native_addr);

uint wasm_module_realloc(WASMModuleInstance* module_inst, uint ptr, uint size, void** p_native_addr);

void wasm_module_free(WASMModuleInstance* module_inst, uint ptr);

uint wasm_module_dup_data(WASMModuleInstance* module_inst, const(char)* src, uint size);

/**
 * Check whether the app address and the buf is inside the linear memory,
 * and convert the app address into native address
 */
bool wasm_check_app_addr_and_convert(WASMModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr);

WASMMemoryInstance* wasm_get_default_memory(WASMModuleInstance* module_inst);

bool wasm_enlarge_memory(WASMModuleInstance* module_inst, uint inc_page_count);

bool wasm_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv);

static if (WASM_ENABLE_THREAD_MGR != 0) {
bool wasm_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size);

bool wasm_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size);
}

void wasm_get_module_mem_consumption(const(WASMModule)* module_, WASMModuleMemConsumption* mem_conspn);

void wasm_get_module_inst_mem_consumption(const(WASMModuleInstance)* module_, WASMModuleInstMemConsumption* mem_conspn);

static if (WASM_ENABLE_REF_TYPES != 0) {
pragma(inline, true) private bool wasm_elem_is_active(uint mode) {
    return (mode & 0x1) == 0x0;
}

pragma(inline, true) private bool wasm_elem_is_passive(uint mode) {
    return (mode & 0x1) == 0x1;
}

pragma(inline, true) private bool wasm_elem_is_declarative(uint mode) {
    return (mode & 0x3) == 0x3;
}

bool wasm_enlarge_table(WASMModuleInstance* module_inst, uint table_idx, uint inc_entries, uint init_val);
} /* WASM_ENABLE_REF_TYPES != 0 */

pragma(inline, true) private WASMTableInstance* wasm_get_table_inst(const(WASMModuleInstance)* module_inst, uint tbl_idx) {
    /* careful, it might be a table in another module */
    WASMTableInstance* tbl_inst = module_inst.tables[tbl_idx];
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    if (tbl_idx < module_inst.module_.import_table_count
        && module_inst.e.table_insts_linked[tbl_idx]) {
        tbl_inst = module_inst.e.table_insts_linked[tbl_idx];
    }
}
    bh_assert(tbl_inst);
    return tbl_inst;
}

static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
bool wasm_interp_create_call_stack(WASMExecEnv* exec_env);

/**
 * @brief Dump wasm call stack or get the size
 *
 * @param exec_env the execution environment
 * @param print whether to print to stdout or not
 * @param buf buffer to store the dumped content
 * @param len length of the buffer
 *
 * @return when print is true, return the bytes printed out to stdout; when
 * print is false and buf is NULL, return the size required to store the
 * callstack content; when print is false and buf is not NULL, return the size
 * dumped to the buffer, 0 means error and data in buf may be invalid
 */
uint wasm_interp_dump_call_stack(WASMExecEnv* exec_env, bool print, char* buf, uint len);
}

const(ubyte)* wasm_loader_get_custom_section(WASMModule* module_, const(char)* name, uint* len);

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0) {
void jit_set_exception_with_id(WASMModuleInstance* module_inst, uint id);

/**
 * Check whether the app address and the buf is inside the linear memory,
 * and convert the app address into native address
 */
bool jit_check_app_addr_and_convert(WASMModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr);
} /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
          || WASM_ENABLE_WAMR_COMPILER != 0 */

static if (WASM_ENABLE_FAST_JIT != 0) {
bool fast_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint type_idx, uint argc, uint* argv);

bool fast_jit_invoke_native(WASMExecEnv* exec_env, uint func_idx, WASMInterpFrame* prev_frame);
}

static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
bool llvm_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv);

bool llvm_jit_invoke_native(WASMExecEnv* exec_env, uint func_idx, uint argc, uint* argv);

static if (WASM_ENABLE_BULK_MEMORY != 0) {
bool llvm_jit_memory_init(WASMModuleInstance* module_inst, uint seg_index, uint offset, uint len, uint dst);

bool llvm_jit_data_drop(WASMModuleInstance* module_inst, uint seg_index);
}

static if (WASM_ENABLE_REF_TYPES != 0) {
void llvm_jit_drop_table_seg(WASMModuleInstance* module_inst, uint tbl_seg_idx);

void llvm_jit_table_init(WASMModuleInstance* module_inst, uint tbl_idx, uint tbl_seg_idx, uint length, uint src_offset, uint dst_offset);

void llvm_jit_table_copy(WASMModuleInstance* module_inst, uint src_tbl_idx, uint dst_tbl_idx, uint length, uint src_offset, uint dst_offset);

void llvm_jit_table_fill(WASMModuleInstance* module_inst, uint tbl_idx, uint length, uint val, uint data_offset);

uint llvm_jit_table_grow(WASMModuleInstance* module_inst, uint tbl_idx, uint inc_entries, uint init_val);
}

static if (WASM_ENABLE_DUMP_CALL_STACK != 0 || WASM_ENABLE_PERF_PROFILING != 0) {
bool llvm_jit_alloc_frame(WASMExecEnv* exec_env, uint func_index);

void llvm_jit_free_frame(WASMExecEnv* exec_env);
}
} /* end of WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0 */

version (none) {
}
}

//! #endif /* end of _WASM_RUNTIME_H */
