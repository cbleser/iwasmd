module tagion.iwasm.aot.aot_runtime;
@nogc nothrow:
extern(C): __gshared:

/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import core.stdc.stdint : uintptr_t;
import tagion.iwasm.basic;
import tagion.iwasm.share.utils.bh_log;
import tagion.iwasm.share.mem_alloc.mem_alloc;
public import tagion.iwasm.common.wasm_runtime_common;
public import tagion.iwasm.interpreter.wasm_runtime;
static if (ver.WASM_ENABLE_SHARED_MEMORY) {
public import tagion.iwasm.common.wasm_shared_memory;
}
static if (ver.WASM_ENABLE_THREAD_MGR) {
public import tagion.iwasm.libraries.thread_mgr.thread_manager;
}

/*
 * Note: These offsets need to match the values hardcoded in
 * AoT compilation code: aot_create_func_context, check_suspend_flags.
 */

static assert(WASMExecEnv.module_inst.offsetof == 2 * uintptr_t.sizeof);
static assert(WASMExecEnv.argv_buf.offsetof == 3 * uintptr_t.sizeof);
static assert(WASMExecEnv.native_stack_boundary.offsetof
                 == 4 * uintptr_t.sizeof);
static assert(WASMExecEnv.suspend_flags.offsetof == 5 * uintptr_t.sizeof);
static assert(WASMExecEnv.aux_stack_boundary.offsetof
                 == 6 * uintptr_t.sizeof);
static assert(WASMExecEnv.aux_stack_bottom.offsetof
                 == 7 * uintptr_t.sizeof);
static assert(WASMExecEnv.native_symbol.offsetof == 8 * uintptr_t.sizeof);

static assert(AOTModuleInstance.memories.offsetof == 1 * ulong.sizeof);
//static assert(AOTModuleInstance.func_ptrs.offsetof == 5 * ulong.sizeof);
//static assert(AOTModuleInstance.func_type_indexes.offsetof
//                 == 6 * ulong.sizeof);
//static assert(AOTModuleInstance.cur_exception.offsetof
//                 == 13 * ulong.sizeof);
//static assert(AOTModuleInstance.global_table_data.offsetof
//                 == 13 * ulong.sizeof + 128 + 11 * ulong.sizeof);

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null) {
        snprintf(error_buf, error_buf_size, "AOT module instantiate failed: %s",
                 string);
    }
}

private void set_error_buf_v(char* error_buf, uint error_buf_size, const(char)* format, ...) {
    va_list args = void;
    char[128] buf = void;

    if (error_buf != null) {
        va_start(args, format);
        vsnprintf(buf.ptr, buf.sizeof, format, args);
        va_end(args);
        snprintf(error_buf, error_buf_size, "AOT module instantiate failed: %s",
                 buf.ptr);
    }
}

private void* runtime_malloc(ulong size, char* error_buf, uint error_buf_size) {
    void* mem = void;

    if (size >= uint_MAX || ((mem = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return null;
    }

    memset(mem, 0, cast(uint)size);
    return mem;
}

private bool check_global_init_expr(const(AOTModule)* module_, uint global_index, char* error_buf, uint error_buf_size) {
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
        || module_.import_globals.is_mutable) {
        set_error_buf(error_buf, error_buf_size,
                      "constant expression required");
        return false;
    }

    return true;
}

private void init_global_data(ubyte* global_data, ubyte type, WASMValue* initial_value) {
    switch (type) {
        case VALUE_TYPE_I32:
        case VALUE_TYPE_F32:
static if (ver.WASM_ENABLE_REF_TYPES) {
        case VALUE_TYPE_FUNCREF:
        case VALUE_TYPE_EXTERNREF:
}
            *cast(int*)global_data = initial_value.i32;
            break;
        case VALUE_TYPE_I64:
        case VALUE_TYPE_F64:
            bh_memcpy_s(global_data, int64.sizeof, &initial_value.i64,
                        int64.sizeof);
            break;
static if (ver.WASM_ENABLE_SIMD) {
        case VALUE_TYPE_V128:
            bh_memcpy_s(global_data, V128.sizeof, &initial_value.v128,
                        V128.sizeof);
            break;
}
        default:
            bh_assert(0);
    }
}

private bool global_instantiate(AOTModuleInstance* module_inst, AOTModule* module_, char* error_buf, uint error_buf_size) {
    uint i = void;
    InitializerExpression* init_expr = void;
    ubyte* p = module_inst.global_data;
    AOTImportGlobal* import_global = module_.import_globals;
    AOTGlobal* global = module_.globals;

    /* Initialize import global data */
    for (i = 0; i < module_.import_global_count; i++, import_global++) {
        bh_assert(import_global.data_offset
                  == cast(uint)(p - module_inst.global_data));
        init_global_data(p, import_global.type,
                         &import_global.global_data_linked);
        p += import_global.size;
    }

    /* Initialize defined global data */
    for (i = 0; i < module_.global_count; i++, global++) {
        bh_assert(global.data_offset
                  == cast(uint)(p - module_inst.global_data));
        init_expr = &global.init_expr;
        switch (init_expr.init_expr_type) {
            case INIT_EXPR_TYPE_GET_GLOBAL:
            {
                if (!check_global_init_expr(module_, init_expr.u.global_index,
                                            error_buf, error_buf_size)) {
                    return false;
                }
                init_global_data(
                    p, global.type,
                    &module_.import_globals[init_expr.u.global_index]
                         .global_data_linked);
                break;
            }
static if (ver.WASM_ENABLE_REF_TYPES) {
            case INIT_EXPR_TYPE_REFNULL_CONST:
            {
                *cast(uint*)p = NULL_REF;
                break;
            }
}
            default:
            {
                init_global_data(p, global.type, &init_expr.u);
                break;
            }
        }
        p += global.size;
    }

    bh_assert(module_inst.global_data_size
              == cast(uint)(p - module_inst.global_data));
    return true;
}

private bool tables_instantiate(AOTModuleInstance* module_inst, AOTModule* module_, AOTTableInstance* first_tbl_inst, char* error_buf, uint error_buf_size) {
    uint i = void, global_index = void, global_data_offset = void, base_offset = void, length = void;
    ulong total_size = void;
    AOTTableInitData* table_seg = void;
    AOTTableInstance* tbl_inst = first_tbl_inst;

    total_size = cast(ulong)(WASMTableInstance*).sizeof * module_inst.table_count;
    if (total_size > 0
        && ((module_inst.tables =
                 runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /*
     * treat import table like a local one until we enable module linking
     * in AOT mode
     */
    for (i = 0; i != module_inst.table_count; ++i) {
        if (i < module_.import_table_count) {
            AOTImportTable* import_table = module_.import_tables + i;
            tbl_inst.cur_size = import_table.table_init_size;
            tbl_inst.max_size =
                aot_get_imp_tbl_data_slots(import_table, false);
        }
        else {
            AOTTable* table = module_.tables + (i - module_.import_table_count);
            tbl_inst.cur_size = table.table_init_size;
            tbl_inst.max_size = aot_get_tbl_data_slots(table, false);
        }

        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(tbl_inst.elems, 0xff, uint.sizeof * tbl_inst.max_size);

        module_inst.tables[i] = tbl_inst;
        tbl_inst = cast(AOTTableInstance*)(cast(ubyte*)tbl_inst
                                        + AOTTableInstance.elems.offsetof
                                        + uint.sizeof * tbl_inst.max_size);
    }

    /* fill table with element segment content */
    for (i = 0; i < module_.table_init_data_count; i++) {
        table_seg = module_.table_init_data_list[i];

static if (ver.WASM_ENABLE_REF_TYPES) {
        if (!wasm_elem_is_active(table_seg.mode))
            continue;
}

        bh_assert(table_seg.table_index < module_inst.table_count);

        tbl_inst = module_inst.tables[table_seg.table_index];
        bh_assert(tbl_inst);

static if (ver.WASM_ENABLE_REF_TYPES) {
        bh_assert(
            table_seg.offset.init_expr_type == INIT_EXPR_TYPE_I32_CONST
            || table_seg.offset.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL
            || table_seg.offset.init_expr_type == INIT_EXPR_TYPE_FUNCREF_CONST
            || table_seg.offset.init_expr_type
                   == INIT_EXPR_TYPE_REFNULL_CONST);
} else {
        bh_assert(table_seg.offset.init_expr_type == INIT_EXPR_TYPE_I32_CONST
                  || table_seg.offset.init_expr_type
                         == INIT_EXPR_TYPE_GET_GLOBAL);
}

        /* Resolve table data base offset */
        if (table_seg.offset.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
            global_index = table_seg.offset.u.global_index;

            if (!check_global_init_expr(module_, global_index, error_buf,
                                        error_buf_size)) {
                return false;
            }

            if (global_index < module_.import_global_count)
                global_data_offset =
                    module_.import_globals[global_index].data_offset;
            else
                global_data_offset =
                    module_.globals[global_index - module_.import_global_count]
                        .data_offset;

            base_offset =
                *cast(uint*)(module_inst.global_data + global_data_offset);
        }
        else
            base_offset = cast(uint)table_seg.offset.u.i32;

        /* Copy table data */
        /* base_offset only since length might negative */
        if (base_offset > tbl_inst.cur_size) {
static if (ver.WASM_ENABLE_REF_TYPES) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds table access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
}
            return false;
        }

        /* base_offset + length(could be zero) */
        length = table_seg.func_index_count;
        if (base_offset + length > tbl_inst.cur_size) {
static if (ver.WASM_ENABLE_REF_TYPES) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds table access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "elements segment does not fit");
}
            return false;
        }

        /**
         * Check function index in the current module inst for now.
         * will check the linked table inst owner in future
         */
        bh_memcpy_s(tbl_inst.elems + base_offset,
                    (tbl_inst.max_size - base_offset) * uint.sizeof,
                    table_seg.func_indexes, length * uint.sizeof);
    }

    return true;
}

private void memories_deinstantiate(AOTModuleInstance* module_inst) {
    uint i = void;
    AOTMemoryInstance* memory_inst = void;

    for (i = 0; i < module_inst.memory_count; i++) {
        memory_inst = module_inst.memories[i];
        if (memory_inst) {
static if (ver.WASM_ENABLE_SHARED_MEMORY) {
            if (memory_inst.is_shared) {
                int ref_count = shared_memory_dec_reference(
                    cast(WASMModuleCommon*)module_inst.module_);
                bh_assert(ref_count >= 0);

                /* if the reference count is not zero,
                    don't free the memory */
                if (ref_count > 0)
                    continue;
            }
}
            if (memory_inst.heap_handle) {
                mem_allocator_destroy(memory_inst.heap_handle);
                wasm_runtime_free(memory_inst.heap_handle);
            }

            if (memory_inst.memory_data) {
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
                wasm_runtime_free(memory_inst.memory_data);
} version (OS_ENABLE_HW_BOUND_CHECK) {
version (BH_PLATFORM_WINDOWS) {
                os_mem_decommit(memory_inst.memory_data,
                                memory_inst.num_bytes_per_page
                                    * memory_inst.cur_page_count);
}
                os_munmap(memory_inst.memory_data, 8 * cast(ulong)BH_GB);
}
            }
        }
    }
    wasm_runtime_free(module_inst.memories);
}

private AOTMemoryInstance* memory_instantiate(AOTModuleInstance* module_inst, AOTModule* module_, AOTMemoryInstance* memory_inst, AOTMemory* memory, uint heap_size, char* error_buf, uint error_buf_size) {
    void* heap_handle = void;
    uint num_bytes_per_page = memory.num_bytes_per_page;
    uint init_page_count = memory.mem_init_page_count;
    uint max_page_count = memory.mem_max_page_count;
    uint inc_page_count = void, aux_heap_base = void, global_idx = void;
    uint bytes_of_last_page = void, bytes_to_page_end = void;
    uint heap_offset = num_bytes_per_page * init_page_count;
    ulong total_size = void;
    ubyte* p = null, global_addr = void;
version (OS_ENABLE_HW_BOUND_CHECK) {
    ubyte* mapped_mem = void;
    ulong map_size = 8 * cast(ulong)BH_GB;
    ulong page_size = os_getpagesize();
}

static if (ver.WASM_ENABLE_SHARED_MEMORY) {
    bool is_shared_memory = memory.memory_flags & 0x02 ? true : false;

    /* Shared memory */
    if (is_shared_memory) {
        AOTMemoryInstance* shared_memory_instance = void;
        WASMSharedMemNode* node = wasm_module_get_shared_memory(cast(WASMModuleCommon*)module_);
        /* If the memory of this module has been instantiated,
            return the memory instance directly */
        if (node) {
            uint ref_count = void;
            ref_count = shared_memory_inc_reference(cast(WASMModuleCommon*)module_);
            bh_assert(ref_count > 0);
            shared_memory_instance =
                cast(AOTMemoryInstance*)shared_memory_get_memory_inst(node);
            bh_assert(shared_memory_instance);

            cast(void)ref_count;
            return shared_memory_instance;
        }
    }
}

    if (heap_size > 0 && module_.malloc_func_index != uint.max
        && module_.free_func_index != uint.max) {
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
        else if (module_.aux_heap_base_global_index != uint.max
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
            global_idx = module_.aux_heap_base_global_index
                         - module_.import_global_count;
            global_addr = module_inst.global_data
                          + module_.globals[global_idx].data_offset;
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
            num_bytes_per_page = uint_MAX;
            init_page_count = max_page_count = 1;
        }
        if (max_page_count > DEFAULT_MAX_PAGES)
            max_page_count = DEFAULT_MAX_PAGES;
    }

    LOG_VERBOSE("Memory instantiate:");
    LOG_VERBOSE("  page bytes: %u, init pages: %u, max pages: %u",
                num_bytes_per_page, init_page_count, max_page_count);
    LOG_VERBOSE("  data offset: %u, stack size: %d", module_.aux_data_end,
                module_.aux_stack_size);
    LOG_VERBOSE("  heap offset: %u, heap size: %d\n", heap_offset, heap_size);

    total_size = cast(ulong)num_bytes_per_page * init_page_count;
static if (ver.WASM_ENABLE_SHARED_MEMORY) {
    if (is_shared_memory) {
        /* Allocate max page for shared memory */
        total_size = cast(ulong)num_bytes_per_page * max_page_count;
    }
}
    bh_assert(total_size <= uint_MAX);

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    /* Allocate memory */
    if (total_size > 0
        && ((p = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }
} version (OS_ENABLE_HW_BOUND_CHECK) {
    total_size = (total_size + page_size - 1) & ~(page_size - 1);

    /* Totally 8G is mapped, the opcode load/store address range is 0 to 8G:
     *   ea = i + memarg.offset
     * both i and memarg.offset are u32 in range 0 to 4G
     * so the range of ea is 0 to 8G
     */
    if (((p = mapped_mem =
              os_mmap(null, map_size, MMAP_PROT_NONE, MMAP_MAP_NONE)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "mmap memory failed");
        return null;
    }

version (BH_PLATFORM_WINDOWS) {
    if (!os_mem_commit(p, total_size, MMAP_PROT_READ | MMAP_PROT_WRITE)) {
        set_error_buf(error_buf, error_buf_size, "commit memory failed");
        os_munmap(mapped_mem, map_size);
        return null;
    }
}

    if (os_mprotect(p, total_size, MMAP_PROT_READ | MMAP_PROT_WRITE) != 0) {
        set_error_buf(error_buf, error_buf_size, "mprotect memory failed");
version (BH_PLATFORM_WINDOWS) {
        os_mem_decommit(p, total_size);
}
        os_munmap(mapped_mem, map_size);
        return null;
    }
    /* Newly allocated pages are filled with zero by the OS, we don't fill it
     * again here */
} /* end of OS_ENABLE_HW_BOUND_CHECK */

    if (total_size > uint_MAX)
        total_size = uint_MAX;

    memory_inst.module_type = Wasm_Module_AoT;
    memory_inst.num_bytes_per_page = num_bytes_per_page;
    memory_inst.cur_page_count = init_page_count;
    memory_inst.max_page_count = max_page_count;
    memory_inst.memory_data_size = cast(uint)total_size;

    /* Init memory info */
    memory_inst.memory_data = p;
    memory_inst.memory_data_end = p + cast(uint)total_size;

    /* Initialize heap info */
    memory_inst.heap_data = p + heap_offset;
    memory_inst.heap_data_end = p + heap_offset + heap_size;
    if (heap_size > 0) {
        uint heap_struct_size = mem_allocator_get_heap_struct_size();

        if (((heap_handle = runtime_malloc(cast(ulong)heap_struct_size, error_buf,
                                           error_buf_size)) == 0)) {
            goto fail1;
        }

        memory_inst.heap_handle = heap_handle;

        if (!mem_allocator_create_with_struct_and_pool(
                heap_handle, heap_struct_size, memory_inst.heap_data,
                heap_size)) {
            set_error_buf(error_buf, error_buf_size, "init app heap failed");
            goto fail2;
        }
    }

    if (total_size > 0) {
static if (uintptr_t.max == ulong.max) {
        memory_inst.mem_bound_check_1byte.u64 = total_size - 1;
        memory_inst.mem_bound_check_2bytes.u64 = total_size - 2;
        memory_inst.mem_bound_check_4bytes.u64 = total_size - 4;
        memory_inst.mem_bound_check_8bytes.u64 = total_size - 8;
        memory_inst.mem_bound_check_16bytes.u64 = total_size - 16;
} else {
        memory_inst.mem_bound_check_1byte.u32[0] = cast(uint)total_size - 1;
        memory_inst.mem_bound_check_2bytes.u32[0] = cast(uint)total_size - 2;
        memory_inst.mem_bound_check_4bytes.u32[0] = cast(uint)total_size - 4;
        memory_inst.mem_bound_check_8bytes.u32[0] = cast(uint)total_size - 8;
        memory_inst.mem_bound_check_16bytes.u32[0] = cast(uint)total_size - 16;
}
    }

static if (ver.WASM_ENABLE_SHARED_MEMORY) {
    if (is_shared_memory) {
        memory_inst.is_shared = true;
        if (!shared_memory_set_memory_inst(
                cast(WASMModuleCommon*)module_,
                cast(WASMMemoryInstanceCommon*)memory_inst)) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
            goto fail3;
        }
    }
}

    return memory_inst;

static if (ver.WASM_ENABLE_SHARED_MEMORY) {
fail3:
    if (heap_size > 0)
        mem_allocator_destroy(memory_inst.heap_handle);
}
fail2:
    if (heap_size > 0)
        wasm_runtime_free(memory_inst.heap_handle);
fail1:
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    if (memory_inst.memory_data)
        wasm_runtime_free(memory_inst.memory_data);
} version (OS_ENABLE_HW_BOUND_CHECK) {
version (BH_PLATFORM_WINDOWS) {
    if (memory_inst.memory_data)
        os_mem_decommit(p, total_size);
}
    os_munmap(mapped_mem, map_size);
}
    memory_inst.memory_data = null;
    return null;
}

private AOTMemoryInstance* aot_get_default_memory(AOTModuleInstance* module_inst) {
    if (module_inst.memories)
        return module_inst.memories[0];
    else
        return null;
}

private bool memories_instantiate(AOTModuleInstance* module_inst, AOTModule* module_, uint heap_size, char* error_buf, uint error_buf_size) {
    uint global_index = void, global_data_offset = void, base_offset = void, length = void;
    uint i = void, memory_count = module_.memory_count;
    AOTMemoryInstance* memories = void, memory_inst = void;
    AOTMemInitData* data_seg = void;
    ulong total_size = void;

    module_inst.memory_count = memory_count;
    total_size = (AOTMemoryInstance*).sizeof * cast(ulong)memory_count;
    if (((module_inst.memories =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    memories = module_inst.global_table_data.memory_instances;
    for (i = 0; i < memory_count; i++, memories++) {
        memory_inst = memory_instantiate(module_inst, module_, memories,
                                         &module_.memories[i], heap_size,
                                         error_buf, error_buf_size);
        if (!memory_inst) {
            return false;
        }

        module_inst.memories[i] = memory_inst;
    }

    /* Get default memory instance */
    memory_inst = aot_get_default_memory(module_inst);
    if (!memory_inst) {
        /* Ignore setting memory init data if no memory inst is created */
        return true;
    }

    for (i = 0; i < module_.mem_init_data_count; i++) {
        data_seg = module_.mem_init_data_list[i];
static if (ver.WASM_ENABLE_BULK_MEMORY) {
        if (data_seg.is_passive)
            continue;
}

        bh_assert(data_seg.offset.init_expr_type == INIT_EXPR_TYPE_I32_CONST
                  || data_seg.offset.init_expr_type
                         == INIT_EXPR_TYPE_GET_GLOBAL);

        /* Resolve memory data base offset */
        if (data_seg.offset.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
            global_index = data_seg.offset.u.global_index;

            if (!check_global_init_expr(module_, global_index, error_buf,
                                        error_buf_size)) {
                return false;
            }

            if (global_index < module_.import_global_count)
                global_data_offset =
                    module_.import_globals[global_index].data_offset;
            else
                global_data_offset =
                    module_.globals[global_index - module_.import_global_count]
                        .data_offset;

            base_offset =
                *cast(uint*)(module_inst.global_data + global_data_offset);
        }
        else {
            base_offset = cast(uint)data_seg.offset.u.i32;
        }

        /* Copy memory data */
        bh_assert(memory_inst.memory_data
                  || memory_inst.memory_data_size == 0);

        /* Check memory data */
        /* check offset since length might negative */
        if (base_offset > memory_inst.memory_data_size) {
            LOG_DEBUG("base_offset(%d) > memory_data_size(%d)", base_offset,
                      memory_inst.memory_data_size);
static if (ver.WASM_ENABLE_REF_TYPES) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds memory access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit");
}
            return false;
        }

        /* check offset + length(could be zero) */
        length = data_seg.byte_count;
        if (base_offset + length > memory_inst.memory_data_size) {
            LOG_DEBUG("base_offset(%d) + length(%d) > memory_data_size(%d)",
                      base_offset, length, memory_inst.memory_data_size);
static if (ver.WASM_ENABLE_REF_TYPES) {
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds memory access");
} else {
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit");
}
            return false;
        }

        if (memory_inst.memory_data) {
            bh_memcpy_s(cast(ubyte*)memory_inst.memory_data + base_offset,
                        memory_inst.memory_data_size - base_offset,
                        data_seg.bytes, length);
        }
    }

    return true;
}

private bool init_func_ptrs(AOTModuleInstance* module_inst, AOTModule* module_, char* error_buf, uint error_buf_size) {
    uint i = void;
    void** func_ptrs = void;
    ulong total_size = (cast(ulong)module_.import_func_count + module_.func_count)
                        * (void*).sizeof;

    if (module_.import_func_count + module_.func_count == 0)
        return true;

    /* Allocate memory */
    if (((module_inst.func_ptrs =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Set import function pointers */
    func_ptrs = cast(void**)module_inst.func_ptrs;
    for (i = 0; i < module_.import_func_count; i++, func_ptrs++) {
        *func_ptrs = cast(void*)module_.import_funcs[i].func_ptr_linked;
        if (!*func_ptrs) {
            const(char)* module_name = module_.import_funcs[i].module_name;
            const(char)* field_name = module_.import_funcs[i].func_name;
            LOG_WARNING("warning: failed to link import function (%s, %s)",
                        module_name, field_name);
        }
    }

    /* Set defined function pointers */
    bh_memcpy_s(func_ptrs, (void*).sizeof * module_.func_count,
                module_.func_ptrs, (void*).sizeof * module_.func_count);
    return true;
}

private bool init_func_type_indexes(AOTModuleInstance* module_inst, AOTModule* module_, char* error_buf, uint error_buf_size) {
    uint i = void;
    uint* func_type_index = void;
    ulong total_size = (cast(ulong)module_.import_func_count + module_.func_count)
                        * uint.sizeof;

    if (module_.import_func_count + module_.func_count == 0)
        return true;

    /* Allocate memory */
    if (((module_inst.func_type_indexes =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Set import function type indexes */
    func_type_index = module_inst.func_type_indexes;
    for (i = 0; i < module_.import_func_count; i++, func_type_index++)
        *func_type_index = module_.import_funcs[i].func_type_index;

    bh_memcpy_s(func_type_index, uint.sizeof * module_.func_count,
                module_.func_type_indexes, uint.sizeof * module_.func_count);
    return true;
}

private bool create_export_funcs(AOTModuleInstance* module_inst, AOTModule* module_, char* error_buf, uint error_buf_size) {
    AOTExport* exports = module_.exports;
    AOTFunctionInstance* export_func = void;
    ulong size = void;
    uint i = void, func_index = void, ftype_index = void;

    if (module_inst.export_func_count > 0) {
        /* Allocate memory */
        size = sizeof(AOTFunctionInstance)
               * cast(ulong)module_inst.export_func_count;
        if (((export_func = runtime_malloc(size, error_buf, error_buf_size)) == 0)) {
            return false;
        }
        module_inst.export_functions = cast(void*)export_func;

        for (i = 0; i < module_.export_count; i++) {
            if (exports[i].kind == EXPORT_KIND_FUNC) {
                export_func.func_name = exports[i].name;
                export_func.func_index = exports[i].index;
                if (export_func.func_index < module_.import_func_count) {
                    export_func.is_import_func = true;
                    export_func.u.func_import =
                        &module_.import_funcs[export_func.func_index];
                }
                else {
                    export_func.is_import_func = false;
                    func_index =
                        export_func.func_index - module_.import_func_count;
                    ftype_index = module_.func_type_indexes[func_index];
                    export_func.u.func.func_type =
                        module_.func_types[ftype_index];
                    export_func.u.func.func_ptr =
                        module_.func_ptrs[func_index];
                }
                export_func++;
            }
        }
    }

    return true;
}

private bool create_exports(AOTModuleInstance* module_inst, AOTModule* module_, char* error_buf, uint error_buf_size) {
    AOTExport* exports = module_.exports;
    uint i = void;

    for (i = 0; i < module_.export_count; i++) {
        switch (exports[i].kind) {
            case EXPORT_KIND_FUNC:
                module_inst.export_func_count++;
                break;
            case EXPORT_KIND_GLOBAL:
                module_inst.export_global_count++;
                break;
            case EXPORT_KIND_TABLE:
                module_inst.export_table_count++;
                break;
            case EXPORT_KIND_MEMORY:
                module_inst.export_memory_count++;
                break;
            default:
                return false;
        }
    }

    return create_export_funcs(module_inst, module_, error_buf, error_buf_size);
}

private bool clear_wasi_proc_exit_exception(AOTModuleInstance* module_inst) {
static if (ver.WASM_ENABLE_LIBC_WASI) {
    const(char)* exception = aot_get_exception(module_inst);
    if (exception && !strcmp(exception, "Exception: wasi proc exit")) {
        /* The "wasi proc exit" exception is thrown by native lib to
           let wasm app exit, which is a normal behavior, we clear
           the exception here. */
        aot_set_exception(module_inst, null);
        return true;
    }
    return false;
} else {
    return false;
}
}

private bool execute_post_inst_function(AOTModuleInstance* module_inst) {
    AOTFunctionInstance* post_inst_func = aot_lookup_function(module_inst, "__post_instantiate", "()");

    if (!post_inst_func)
        /* Not found */
        return true;

    return aot_create_exec_env_and_call_function(module_inst, post_inst_func, 0,
                                                 null);
}

private bool execute_start_function(AOTModuleInstance* module_inst) {
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;
    WASMExecEnv* exec_env = void;
    alias F = void function(WASMExecEnv*);
    union _U {
        F f = void;
        void* v = void;
    }_U u = void;

    if (!module_.start_function)
        return true;

    if (((exec_env =
              wasm_exec_env_create(cast(WASMModuleInstanceCommon*)module_inst,
                                   module_inst.default_wasm_stack_size)) == 0)) {
        aot_set_exception(module_inst, "allocate memory failed");
        return false;
    }

    u.v = module_.start_function;
    u.f(exec_env);

    wasm_exec_env_destroy(exec_env);
    cast(void)clear_wasi_proc_exit_exception(module_inst);
    return !aot_get_exception(module_inst);
}

static if (ver.WASM_ENABLE_BULK_MEMORY) {
private bool execute_memory_init_function(AOTModuleInstance* module_inst) {
    AOTFunctionInstance* memory_init_func = aot_lookup_function(module_inst, "__wasm_call_ctors", "()");

    if (!memory_init_func)
        /* Not found */
        return true;

    return aot_create_exec_env_and_call_function(module_inst, memory_init_func,
                                                 0, null);
}
}

AOTModuleInstance *
aot_instantiate(AOTModule* module_, bool is_sub_inst, uint stack_size,
                uint heap_size, char* error_buf, uint error_buf_size)
{
    AOTModuleInstance* module_inst;
    const(uint) module_inst_struct_size = offsetof(AOTModuleInstance, global_table_data.bytes);
    const(ulong) module_inst_mem_inst_size = cast(ulong)module_.memory_count * AOTMemoryInstance.sizeof;
    ulong total_size, table_size = 0;
    ubyte* p;
    uint i, extra_info_offset;

    /* Check heap size */
    heap_size = align_uint(heap_size, 8);
    if (heap_size > APP_HEAP_SIZE_MAX)
        heap_size = APP_HEAP_SIZE_MAX;

    total_size = cast(ulong)module_inst_struct_size + module_inst_mem_inst_size
                 + module_.global_data_size;

    /*
     * calculate size of table data
     */
    for (i = 0; i != module_.import_table_count; ++i) {
        table_size += AOTTableInstance.elems.offsetof;
        table_size += cast(ulong)uint.sizeof
                      * cast(ulong)aot_get_imp_tbl_data_slots(
                          module_.import_tables + i, false);
    }

    for (i = 0; i != module_.table_count; ++i) {
        table_size += AOTTableInstance.elems.offsetof;
        table_size +=
            cast(ulong)uint.sizeof
            * cast(ulong)aot_get_tbl_data_slots(module_.tables + i, false);
    }
    total_size += table_size;

    /* The offset of AOTModuleInstanceExtra, make it 8-byte aligned */
    total_size = (total_size + 7L) & ~7L;
    extra_info_offset = cast(uint)total_size;
    total_size += AOTModuleInstanceExtra.sizeof;

    /* Allocate module instance, global data, table data and heap data */
    if (((module_inst =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    module_inst.module_type = Wasm_Module_AoT;
    module_inst.module_ = cast(void*)module_;
    module_inst.e =
        cast(WASMModuleInstanceExtra*)(cast(ubyte*)module_inst + extra_info_offset);

    /* Initialize global info */
    p = cast(ubyte*)module_inst + module_inst_struct_size
        + module_inst_mem_inst_size;
    module_inst.global_data = p;
    module_inst.global_data_size = module_.global_data_size;
    if (!global_instantiate(module_inst, module_, error_buf, error_buf_size))
        goto fail;

    /* Initialize table info */
    p += module_.global_data_size;
    module_inst.table_count = module_.table_count + module_.import_table_count;
    if (!tables_instantiate(module_inst, module_, cast(AOTTableInstance*)p,
                            error_buf, error_buf_size))
        goto fail;

    /* Initialize memory space */
    if (!memories_instantiate(module_inst, module_, heap_size, error_buf,
                              error_buf_size))
        goto fail;

    /* Initialize function pointers */
    if (!init_func_ptrs(module_inst, module_, error_buf, error_buf_size))
        goto fail;

    /* Initialize function type indexes */
    if (!init_func_type_indexes(module_inst, module_, error_buf, error_buf_size))
        goto fail;

    if (!create_exports(module_inst, module_, error_buf, error_buf_size))
        goto fail;

static if (ver.WASM_ENABLE_LIBC_WASI) {
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
                error_buf, error_buf_size))
            goto fail;
    }
}

    /* Initialize the thread related data */
    if (stack_size == 0)
        stack_size = DEFAULT_WASM_STACK_SIZE;
static if (ver.WASM_ENABLE_SPEC_TEST) {
    if (stack_size < 48 * 1024)
        stack_size = 48 * 1024;
}
    module_inst.default_wasm_stack_size = stack_size;

static if (ver.WASM_ENABLE_PERF_PROFILING) {
    total_size = cast(ulong)sizeof(AOTFuncPerfProfInfo)
                 * (module_.import_func_count + module_.func_count);
    if (((module_inst.func_perf_profilings =
              runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        goto fail;
    }
}

static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
    if (((module_inst.frames =
              runtime_malloc(Vector.sizeof, error_buf, error_buf_size)) == 0)) {
        goto fail;
    }
}

    /* Execute __post_instantiate function and start function*/
    if (!execute_post_inst_function(module_inst)
        || !execute_start_function(module_inst)) {
        set_error_buf(error_buf, error_buf_size, module_inst.cur_exception);
        goto fail;
    }

//#if WASM_ENABLE_BULK_MEMORY != 0
static if (WASM_ENABLE_BULK_MEMORY != 0 &&
sWASM_ENABLE_LIBC_WASI != 0) {
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
static if (ver.WASM_ENABLE_LIBC_WASI) {
    }
}
}

static if (ver.WASM_ENABLE_MEMORY_TRACING) {
    wasm_runtime_dump_module_inst_mem_consumption(
        cast(WASMModuleInstanceCommon*)module_inst);
}

    return module_inst;

fail:
    aot_deinstantiate(module_inst, is_sub_inst);
    return null;
}

void aot_deinstantiate(AOTModuleInstance* module_inst, bool is_sub_inst) {
static if (ver.WASM_ENABLE_LIBC_WASI) {
    /* Destroy wasi resource before freeing app heap, since some fields of
       wasi contex are allocated from app heap, and if app heap is freed,
       these fields will be set to NULL, we cannot free their internal data
       which may allocated from global heap. */
    /* Only destroy wasi ctx in the main module instance */
    if (!is_sub_inst)
        wasm_runtime_destroy_wasi(cast(WASMModuleInstanceCommon*)module_inst);
}

static if (ver.WASM_ENABLE_PERF_PROFILING) {
    if (module_inst.func_perf_profilings)
        wasm_runtime_free(module_inst.func_perf_profilings);
}

static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
    if (module_inst.frames) {
        bh_vector_destroy(module_inst.frames);
        wasm_runtime_free(module_inst.frames);
        module_inst.frames = null;
    }
}

    if (module_inst.tables)
        wasm_runtime_free(module_inst.tables);

    if (module_inst.memories)
        memories_deinstantiate(module_inst);

    if (module_inst.export_functions)
        wasm_runtime_free(module_inst.export_functions);

    if (module_inst.func_ptrs)
        wasm_runtime_free(module_inst.func_ptrs);

    if (module_inst.func_type_indexes)
        wasm_runtime_free(module_inst.func_type_indexes);

    if (module_inst.exec_env_singleton)
        wasm_exec_env_destroy(cast(WASMExecEnv*)module_inst.exec_env_singleton);

    if ((cast(AOTModuleInstanceExtra*)module_inst.e).c_api_func_imports)
        wasm_runtime_free(
            (cast(AOTModuleInstanceExtra*)module_inst.e).c_api_func_imports);

    wasm_runtime_free(module_inst);
}

AOTFunctionInstance* aot_lookup_function(const(AOTModuleInstance)* module_inst, const(char)* name, const(char)* signature) {
    uint i = void;
    AOTFunctionInstance* export_funcs = cast(AOTFunctionInstance*)module_inst.export_functions;

    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(export_funcs[i].func_name, name))
            return &export_funcs[i];
    cast(void)signature;
    return null;
}

version (OS_ENABLE_HW_BOUND_CHECK) {

private bool invoke_native_with_hw_bound_check(WASMExecEnv* exec_env, void* func_ptr, const(WASMType)* func_type, const(char)* signature, void* attachment, uint* argv, uint argc, uint* argv_ret) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
    WASMExecEnv* exec_env_tls = wasm_runtime_get_exec_env_tls();
    WASMJmpBuf jmpbuf_node = { 0 }; WASMJmpBuf* jmpbuf_node_pop = void;
    uint page_size = os_getpagesize();
    uint guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    ushort param_count = func_type.param_count;
    ushort result_count = func_type.result_count;
    const(ubyte)* types = func_type.types;
version (BH_PLATFORM_WINDOWS) {
    const(char)* exce = void;
    int result = void;
}
    bool ret = void;

    /* Check native stack overflow firstly to ensure we have enough
       native stack to run the following codes before actually calling
       the aot function in invokeNative function. */
    if (cast(ubyte*)&module_inst < exec_env.native_stack_boundary
                                    + page_size * (guard_page_count + 1)) {
        aot_set_exception_with_id(module_inst, EXCE_NATIVE_STACK_OVERFLOW);
        return false;
    }

    if (exec_env_tls && (exec_env_tls != exec_env)) {
        aot_set_exception(module_inst, "invalid exec env");
        return false;
    }

    if (!os_thread_signal_inited()) {
        aot_set_exception(module_inst, "thread signal env not inited");
        return false;
    }

    wasm_exec_env_push_jmpbuf(exec_env, &jmpbuf_node);

    wasm_runtime_set_exec_env_tls(exec_env);
    if (os_setjmp(jmpbuf_node.jmpbuf) == 0) {
        /* Quick call with func_ptr if the function signature is simple */
        if (!signature && param_count == 1 && types[0] == VALUE_TYPE_I32) {
            if (result_count == 0) {
                void function(WASMExecEnv*, uint) NativeFunc = cast(void function(WASMExecEnv*, uint))func_ptr;
                NativeFunc(exec_env, argv[0]);
                ret = aot_get_exception(module_inst) ? false : true;
            }
            else if (result_count == 1
                     && types[param_count] == VALUE_TYPE_I32) {
                uint function(WASMExecEnv*, uint) NativeFunc = cast(uint function(WASMExecEnv*, uint))func_ptr;
                argv_ret[0] = NativeFunc(exec_env, argv[0]);
                ret = aot_get_exception(module_inst) ? false : true;
            }
            else {
                ret = wasm_runtime_invoke_native(exec_env, func_ptr, func_type,
                                                 signature, attachment, argv,
                                                 argc, argv_ret);
            }
        }
        else {
            ret = wasm_runtime_invoke_native(exec_env, func_ptr, func_type,
                                             signature, attachment, argv, argc,
                                             argv_ret);
        }
version (BH_PLATFORM_WINDOWS) {
        if ((exce = aot_get_exception(module_inst))
            && strstr(exce, "native stack overflow")) {
            /* After a stack overflow, the stack was left
               in a damaged state, let the CRT repair it */
            result = _resetstkoflw();
            bh_assert(ver.result);
        }
}
    }
    else {
        /* Exception has been set in signal handler before calling longjmp */
        ret = false;
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
    return ret;
}

alias invoke_native_internal = invoke_native_with_hw_bound_check;
} else { /* else of OS_ENABLE_HW_BOUND_CHECK */
alias invoke_native_internal = wasm_runtime_invoke_native;
} /* end of OS_ENABLE_HW_BOUND_CHECK */

bool aot_call_function(WASMExecEnv* exec_env, AOTFunctionInstance* function_, uint argc, uint* argv) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
    AOTFuncType* func_type = function_.u.func.func_type;
    uint result_count = func_type.result_count;
    uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    bool ret = void;

    if (argc < func_type.param_cell_num) {
        char[108] buf = void;
        snprintf(buf.ptr, buf.sizeof,
                 "invalid argument count %u, must be no smaller than %u", argc,
                 func_type.param_cell_num);
        aot_set_exception(module_inst, buf.ptr);
        return false;
    }
    argc = func_type.param_cell_num;

    /* func pointer was looked up previously */
    bh_assert(function_.u.func.func_ptr != null);

    /* set thread handle and stack boundary */
    wasm_exec_env_set_thread_info(exec_env);

    if (ext_ret_count > 0) {
        uint cell_num = 0, i = void;
        ubyte* ext_ret_types = func_type.types + func_type.param_count + 1;
        uint[32] argv1_buf = void; uint* argv1 = argv1_buf, ext_rets = null;
        uint* argv_ret = argv;
        uint ext_ret_cell = wasm_get_cell_num(ext_ret_types, ext_ret_count);
        ulong size = void;

        /* Allocate memory all arguments */
        size =
            uint.sizeof * cast(ulong)argc /* original arguments */
            + (void*).sizeof
                  * cast(ulong)ext_ret_count /* extra result values' addr */
            + uint.sizeof * cast(ulong)ext_ret_cell; /* extra result values */
        if (size > argv1_buf.sizeof
            && ((argv1 = runtime_malloc(size, module_inst.cur_exception,
                                        typeof(module_inst.cur_exception).sizeof)) == 0)) {
            aot_set_exception_with_id(module_inst, EXCE_OUT_OF_MEMORY);
            return false;
        }

        /* Copy original arguments */
        bh_memcpy_s(argv1, cast(uint)size, argv, uint.sizeof * argc);

        /* Get the extra result value's address */
        ext_rets =
            argv1 + argc + (void*).sizeof / uint.sizeof * ext_ret_count;

        /* Append each extra result value's address to original arguments */
        for (i = 0; i < ext_ret_count; i++) {
            *cast(uintptr_t*)(argv1 + argc + (void*).sizeof / uint.sizeof * i) =
                cast(uintptr_t)(ext_rets + cell_num);
            cell_num += wasm_value_type_cell_num(ext_ret_types[i]);
        }

static if ((ver.WASM_ENABLE_DUMP_CALL_STACK) || (ver.WASM_ENABLE_PERF_PROFILING)) {
        if (!aot_alloc_frame(exec_env, function_.func_index)) {
            if (argv1 != argv1_buf.ptr)
                wasm_runtime_free(argv1);
            return false;
        }
}

        ret = invoke_native_internal(exec_env, function_.u.func.func_ptr,
                                     func_type, null, null, argv1, argc, argv);

        if (!ret || aot_get_exception(module_inst)) {
            if (clear_wasi_proc_exit_exception(module_inst))
                ret = true;
            else
                ret = false;
        }

static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
        if (!ret) {
            if (aot_create_call_stack(exec_env)) {
                aot_dump_call_stack(exec_env, true, null, 0);
            }
        }
}

static if ((ver.WASM_ENABLE_DUMP_CALL_STACK) || (ver.WASM_ENABLE_PERF_PROFILING)) {
        aot_free_frame(exec_env);
}
        if (!ret) {
            if (argv1 != argv1_buf.ptr)
                wasm_runtime_free(argv1);
            return ret;
        }

        /* Get extra result values */
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
            case VALUE_TYPE_F32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
}
                argv_ret++;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                argv_ret += 2;
                break;
static if (ver.WASM_ENABLE_SIMD) {
            case VALUE_TYPE_V128:
                argv_ret += 4;
                break;
}
            default:
                bh_assert(0);
                break;
        }
        ext_rets =
            argv1 + argc + (void*).sizeof / uint.sizeof * ext_ret_count;
        bh_memcpy_s(argv_ret, uint.sizeof * cell_num, ext_rets,
                    uint.sizeof * cell_num);

        if (argv1 != argv1_buf.ptr)
            wasm_runtime_free(argv1);
        return true;
    }
    else {
static if ((ver.WASM_ENABLE_DUMP_CALL_STACK) || (ver.WASM_ENABLE_PERF_PROFILING)) {
        if (!aot_alloc_frame(exec_env, function_.func_index)) {
            return false;
        }
}

        ret = invoke_native_internal(exec_env, function_.u.func.func_ptr,
                                     func_type, null, null, argv, argc, argv);

        if (clear_wasi_proc_exit_exception(module_inst))
            ret = true;

static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
        if (aot_get_exception(module_inst)) {
            if (aot_create_call_stack(exec_env)) {
                aot_dump_call_stack(exec_env, true, null, 0);
            }
        }
}

static if ((ver.WASM_ENABLE_DUMP_CALL_STACK) || (ver.WASM_ENABLE_PERF_PROFILING)) {
        aot_free_frame(exec_env);
}

        return ret && !aot_get_exception(module_inst) ? true : false;
    }
}

bool aot_create_exec_env_and_call_function(AOTModuleInstance* module_inst, AOTFunctionInstance* func, uint argc, uint* argv) {
    WASMExecEnv* exec_env = null, existing_exec_env = null;
    bool ret = void;

version (OS_ENABLE_HW_BOUND_CHECK) {
    existing_exec_env = exec_env = wasm_runtime_get_exec_env_tls();
} else static if (ver.WASM_ENABLE_THREAD_MGR) {
    existing_exec_env = exec_env =
        wasm_clusters_search_exec_env(cast(WASMModuleInstanceCommon*)module_inst);
}

    if (!existing_exec_env) {
        if (((exec_env =
                  wasm_exec_env_create(cast(WASMModuleInstanceCommon*)module_inst,
                                       module_inst.default_wasm_stack_size)) == 0)) {
            aot_set_exception(module_inst, "allocate memory failed");
            return false;
        }
    }

    ret = aot_call_function(exec_env, func, argc, argv);

    /* don't destroy the exec_env if it isn't created in this function */
    if (!existing_exec_env)
        wasm_exec_env_destroy(exec_env);

    return ret;
}

void aot_set_exception(AOTModuleInstance* module_inst, const(char)* exception) {
    wasm_set_exception(module_inst, exception);
}

void aot_set_exception_with_id(AOTModuleInstance* module_inst, uint id) {
    if (id != EXCE_ALREADY_THROWN)
        wasm_set_exception_with_id(module_inst, id);
version (OS_ENABLE_HW_BOUND_CHECK) {
    wasm_runtime_access_exce_check_guard_page();
}
}

const(char)* aot_get_exception(AOTModuleInstance* module_inst) {
    return wasm_get_exception(module_inst);
}

version (OS_ENABLE_HW_BOUND_CHECK) {
	enum os_enable_hw_bound_check = true;
	}
	else {
	enum os_enable_hw_bound_check = false;
	}
private bool execute_malloc_function(AOTModuleInstance* module_inst, AOTFunctionInstance* malloc_func, AOTFunctionInstance* retain_func, uint size, uint* p_result) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    WASMExecEnv* exec_env_tls = wasm_runtime_get_exec_env_tls();
}
    uint[2] argv = void; uint argc = void;
    bool ret = void;

    argv[0] = size;
    argc = 1;
    if (retain_func) {
        argv[1] = 0;
        argc = 2;
    }

    if (os_enable_hw_bound_check && exec_env_tls != null) {
        bh_assert(exec_env_tls.module_inst
                  == cast(WASMModuleInstanceCommon*)module_inst);
        ret = aot_call_function(exec_env_tls, malloc_func, argc, argv.ptr);

        if (retain_func && ret) {
            ret = aot_call_function(exec_env_tls, retain_func, 1, argv.ptr);
        }
    }
    else
    {
        ret = aot_create_exec_env_and_call_function(module_inst, malloc_func,
                                                    argc, argv.ptr);

        if (retain_func && ret) {
            ret = aot_create_exec_env_and_call_function(module_inst,
                                                        retain_func, 1, argv.ptr);
        }
    }

    if (ret)
        *p_result = argv[0];
    return ret;
}

private bool execute_free_function(AOTModuleInstance* module_inst, AOTFunctionInstance* free_func, uint offset) {
version (OS_ENABLE_HW_BOUND_CHECK) {
    WASMExecEnv* exec_env_tls = wasm_runtime_get_exec_env_tls();
}
    uint[2] argv = void;

    argv[0] = offset;
version (OS_ENABLE_HW_BOUND_CHECK) {
    if (os_enable_hw_bound_check && exec_env_tls != null) {
        bh_assert(exec_env_tls.module_inst
                  == cast(WASMModuleInstanceCommon*)module_inst);
        return aot_call_function(exec_env_tls, free_func, 1, argv.ptr);
    }
    else
    {
        return aot_create_exec_env_and_call_function(module_inst, free_func, 1,
                                                     argv.ptr);
    }
}

uint aot_module_malloc(AOTModuleInstance* module_inst, uint size, void** p_native_addr) {
    AOTMemoryInstance* memory_inst = aot_get_default_memory(module_inst);
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;
    ubyte* addr = null;
    uint offset = 0;

    if (!memory_inst) {
        aot_set_exception(module_inst, "uninitialized memory");
        return 0;
    }

    if (memory_inst.heap_handle) {
        addr = mem_allocator_malloc(memory_inst.heap_handle, size);
    }
    else if (module_.malloc_func_index != uint.max
             && module_.free_func_index != uint.max) {
        AOTFunctionInstance* malloc_func = void, retain_func = null;
        char* malloc_func_name = void;
        char* malloc_func_sig = void;

        if (module_.retain_func_index != uint.max) {
            malloc_func_name = "__new";
            malloc_func_sig = "(ii)i";
            retain_func = aot_lookup_function(module_inst, "__retain", "(i)i");
            if (!retain_func)
                retain_func = aot_lookup_function(module_inst, "__pin", "(i)i");
            bh_assert(retain_func);
        }
        else {
            malloc_func_name = "malloc";
            malloc_func_sig = "(i)i";
        }
        malloc_func =
            aot_lookup_function(module_inst, malloc_func_name, malloc_func_sig);

        if (!malloc_func
            || !execute_malloc_function(module_inst, malloc_func, retain_func,
                                        size, &offset)) {
            return 0;
        }
        addr = offset ? cast(ubyte*)memory_inst.memory_data + offset : null;
    }

    if (!addr) {
        if (memory_inst.heap_handle
            && mem_allocator_is_heap_corrupted(memory_inst.heap_handle)) {
            wasm_runtime_show_app_heap_corrupted_prompt();
            aot_set_exception(module_inst, "app heap corrupted");
        }
        else {
            LOG_WARNING("warning: allocate %u bytes memory failed", size);
        }
        return 0;
    }
    if (p_native_addr)
        *p_native_addr = addr;
    return cast(uint)(addr - memory_inst.memory_data);
}

uint aot_module_realloc(AOTModuleInstance* module_inst, uint ptr, uint size, void** p_native_addr) {
    AOTMemoryInstance* memory_inst = aot_get_default_memory(module_inst);
    ubyte* addr = null;

    if (!memory_inst) {
        aot_set_exception(module_inst, "uninitialized memory");
        return 0;
    }

    if (memory_inst.heap_handle) {
        addr = mem_allocator_realloc(
            memory_inst.heap_handle,
            ptr ? memory_inst.memory_data + ptr : null, size);
    }

    /* Only support realloc in WAMR's app heap */

    if (!addr) {
        if (memory_inst.heap_handle
            && mem_allocator_is_heap_corrupted(memory_inst.heap_handle)) {
            aot_set_exception(module_inst, "app heap corrupted");
        }
        else {
            aot_set_exception(module_inst, "out of memory");
        }
        return 0;
    }

    if (p_native_addr)
        *p_native_addr = addr;
    return cast(uint)(addr - memory_inst.memory_data);
}

void aot_module_free(AOTModuleInstance* module_inst, uint ptr) {
    AOTMemoryInstance* memory_inst = aot_get_default_memory(module_inst);
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;

    if (!memory_inst) {
        return;
    }

    if (ptr) {
        ubyte* addr = memory_inst.memory_data + ptr;
        if (memory_inst.heap_handle && memory_inst.heap_data < addr
            && addr < memory_inst.heap_data_end) {
            mem_allocator_free(memory_inst.heap_handle, addr);
        }
        else if (module_.malloc_func_index != uint.max
                 && module_.free_func_index != uint.max
                 && memory_inst.memory_data <= addr
                 && addr < memory_inst.memory_data_end) {
            AOTFunctionInstance* free_func = void;
            char* free_func_name = void;

            if (module_.retain_func_index != uint.max) {
                free_func_name = "__release";
            }
            else {
                free_func_name = "free";
            }
            free_func =
                aot_lookup_function(module_inst, free_func_name, "(i)i");
            if (!free_func && module_.retain_func_index != uint.max)
                free_func = aot_lookup_function(module_inst, "__unpin", "(i)i");

            if (free_func)
                execute_free_function(module_inst, free_func, ptr);
        }
    }
}

uint aot_module_dup_data(AOTModuleInstance* module_inst, const(char)* src, uint size) {
    char* buffer = void;
    uint buffer_offset = aot_module_malloc(module_inst, size, cast(void**)&buffer);

    if (ver.buffer_offset) {
        buffer = wasm_runtime_addr_app_to_native(
            cast(WASMModuleInstanceCommon*)module_inst, buffer_offset);
        bh_memcpy_s(buffer, size, src, size);
    }
    return buffer_offset;
}

bool aot_enlarge_memory(AOTModuleInstance* module_inst, uint inc_page_count) {
    return wasm_enlarge_memory(module_inst, inc_page_count);
}

bool aot_invoke_native(WASMExecEnv* exec_env, uint func_idx, uint argc, uint* argv) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)wasm_runtime_get_module_inst(exec_env);
    AOTModule* aot_module = cast(AOTModule*)module_inst.module_;
    AOTModuleInstanceExtra* module_inst_extra = cast(AOTModuleInstanceExtra*)module_inst.e;
    CApiFuncImport* c_api_func_import = module_inst_extra.c_api_func_imports + func_idx;
    uint* func_type_indexes = module_inst.func_type_indexes;
    uint func_type_idx = func_type_indexes[func_idx];
    AOTFuncType* func_type = aot_module.func_types[func_type_idx];
    void** func_ptrs = module_inst.func_ptrs;
    void* func_ptr = func_ptrs[func_idx];
    AOTImportFunc* import_func = void;
    const(char)* signature = void;
    void* attachment = void;
    char[96] buf = void;
    bool ret = false;

    bh_assert(func_idx < aot_module.import_func_count);

    import_func = aot_module.import_funcs + func_idx;
    if (import_func.call_conv_wasm_c_api)
        func_ptr = c_api_func_import.func_ptr_linked;

    if (!func_ptr) {
        snprintf(buf.ptr, buf.sizeof,
                 "failed to call unlinked import function (%s, %s)",
                 import_func.module_name, import_func.func_name);
        aot_set_exception(module_inst, buf.ptr);
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

bool aot_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint table_elem_idx, uint argc, uint* argv) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)wasm_runtime_get_module_inst(exec_env);
    AOTModule* aot_module = cast(AOTModule*)module_inst.module_;
    uint* func_type_indexes = module_inst.func_type_indexes;
    AOTTableInstance* tbl_inst = void;
    AOTFuncType* func_type = void;
    void** func_ptrs = module_inst.func_ptrs; void* func_ptr = void;
    uint func_type_idx = void, func_idx = void, ext_ret_count = void;
    AOTImportFunc* import_func = void;
    const(char)* signature = null;
    void* attachment = null;
    char[96] buf = void;
    bool ret = void;

    /* this function is called from native code, so exec_env->handle and
       exec_env->native_stack_boundary must have been set, we don't set
       it again */

    if (cast(ubyte*)&module_inst < exec_env.native_stack_boundary) {
        aot_set_exception_with_id(module_inst, EXCE_NATIVE_STACK_OVERFLOW);
        goto fail;
    }

    tbl_inst = module_inst.tables[tbl_idx];
    bh_assert(tbl_inst);

    if (table_elem_idx >= tbl_inst.cur_size) {
        aot_set_exception_with_id(module_inst, EXCE_UNDEFINED_ELEMENT);
        goto fail;
    }

    func_idx = tbl_inst.elems[table_elem_idx];
    if (func_idx == NULL_REF) {
        aot_set_exception_with_id(module_inst, EXCE_UNINITIALIZED_ELEMENT);
        goto fail;
    }

    func_type_idx = func_type_indexes[func_idx];
    func_type = aot_module.func_types[func_type_idx];

    if (func_idx >= aot_module.import_func_count) {
        /* func pointer was looked up previously */
        bh_assert(func_ptrs[func_idx] != null);
    }

    if (((func_ptr = func_ptrs[func_idx]) == 0)) {
        bh_assert(func_idx < aot_module.import_func_count);
        import_func = aot_module.import_funcs + func_idx;
        snprintf(buf.ptr, buf.sizeof,
                 "failed to call unlinked import function (%s, %s)",
                 import_func.module_name, import_func.func_name);
        aot_set_exception(module_inst, buf.ptr);
        goto fail;
    }

    if (func_idx < aot_module.import_func_count) {
        /* Call native function */
        import_func = aot_module.import_funcs + func_idx;
        signature = import_func.signature;
        if (import_func.call_conv_raw) {
            attachment = import_func.attachment;
            ret = wasm_runtime_invoke_native_raw(exec_env, func_ptr, func_type,
                                                 signature, attachment, argv,
                                                 argc, argv);
            if (!ret)
                goto fail;

            return true;
        }
    }

    ext_ret_count =
        func_type.result_count > 1 ? func_type.result_count - 1 : 0;
    if (ext_ret_count > 0) {
        uint[32] argv1_buf = void; uint* argv1 = argv1_buf;
        uint* ext_rets = null, argv_ret = argv;
        uint cell_num = 0, i = void;
        ubyte* ext_ret_types = func_type.types + func_type.param_count + 1;
        uint ext_ret_cell = wasm_get_cell_num(ext_ret_types, ext_ret_count);
        ulong size = void;

        /* Allocate memory all arguments */
        size =
            uint.sizeof * cast(ulong)argc /* original arguments */
            + (void*).sizeof
                  * cast(ulong)ext_ret_count /* extra result values' addr */
            + uint.sizeof * cast(ulong)ext_ret_cell; /* extra result values */
        if (size > argv1_buf.sizeof
            && ((argv1 = runtime_malloc(size, module_inst.cur_exception,
                                        typeof(module_inst.cur_exception).sizeof)) == 0)) {
            aot_set_exception_with_id(module_inst, EXCE_OUT_OF_MEMORY);
            goto fail;
        }

        /* Copy original arguments */
        bh_memcpy_s(argv1, cast(uint)size, argv, uint.sizeof * argc);

        /* Get the extra result value's address */
        ext_rets =
            argv1 + argc + (void*).sizeof / uint.sizeof * ext_ret_count;

        /* Append each extra result value's address to original arguments */
        for (i = 0; i < ext_ret_count; i++) {
            *cast(uintptr_t*)(argv1 + argc + (void*).sizeof / uint.sizeof * i) =
                cast(uintptr_t)(ext_rets + cell_num);
            cell_num += wasm_value_type_cell_num(ext_ret_types[i]);
        }

        ret = invoke_native_internal(exec_env, func_ptr, func_type, signature,
                                     attachment, argv1, argc, argv);
        if (!ret) {
            if (argv1 != argv1_buf.ptr)
                wasm_runtime_free(argv1);
            goto fail;
        }

        /* Get extra result values */
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
            case VALUE_TYPE_F32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
}
                argv_ret++;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                argv_ret += 2;
                break;
static if (ver.WASM_ENABLE_SIMD) {
            case VALUE_TYPE_V128:
                argv_ret += 4;
                break;
}
            default:
                bh_assert(0);
                break;
        }
        ext_rets =
            argv1 + argc + (void*).sizeof / uint.sizeof * ext_ret_count;
        bh_memcpy_s(argv_ret, uint.sizeof * cell_num, ext_rets,
                    uint.sizeof * cell_num);

        if (argv1 != argv1_buf.ptr)
            wasm_runtime_free(argv1);

        return true;
    }
    else {
        ret = invoke_native_internal(exec_env, func_ptr, func_type, signature,
                                     attachment, argv, argc, argv);
        if (!ret)
            goto fail;

        return true;
    }

fail:
    if (clear_wasi_proc_exit_exception(module_inst))
        return true;

version (OS_ENABLE_HW_BOUND_CHECK) {
    wasm_runtime_access_exce_check_guard_page();
}
    return false;
}

bool aot_check_app_addr_and_convert(AOTModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr) {
    bool ret = void;

    ret = wasm_check_app_addr_and_convert(module_inst, is_str, app_buf_addr,
                                          app_buf_size, p_native_addr);

version (OS_ENABLE_HW_BOUND_CHECK) {
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
}

    return ret;
}

void* aot_memmove(void* dest, const(void)* src, size_t n) {
    return memmove(dest, src, n);
}

void* aot_memset(void* s, int c, size_t n) {
    return memset(s, c, n);
}

double aot_sqrt(double x) {
    return sqrt(x);
}

float aot_sqrtf(float x) {
    return sqrtf(x);
}

static if (ver.WASM_ENABLE_BULK_MEMORY) {
bool aot_memory_init(AOTModuleInstance* module_inst, uint seg_index, uint offset, uint len, uint dst) {
    AOTMemoryInstance* memory_inst = aot_get_default_memory(module_inst);
    AOTModule* aot_module = void;
    ubyte* data = null;
    ubyte* maddr = void;
    ulong seg_len = 0;

    aot_module = cast(AOTModule*)module_inst.module_;
    seg_len = aot_module.mem_init_data_list[seg_index].byte_count;
    data = aot_module.mem_init_data_list[seg_index].bytes;

    if (!wasm_runtime_validate_app_addr(cast(WASMModuleInstanceCommon*)module_inst,
                                        dst, len))
        return false;

    if (cast(ulong)offset + cast(ulong)len > seg_len) {
        aot_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    maddr = wasm_runtime_addr_app_to_native(
        cast(WASMModuleInstanceCommon*)module_inst, dst);

    bh_memcpy_s(maddr, memory_inst.memory_data_size - dst, data + offset, len);
    return true;
}

bool aot_data_drop(AOTModuleInstance* module_inst, uint seg_index) {
    AOTModule* aot_module = cast(AOTModule*)module_inst.module_;

    aot_module.mem_init_data_list[seg_index].byte_count = 0;
    /* Currently we can't free the dropped data segment
       as the mem_init_data_count is a continuous array */
    return true;
}
} /* WASM_ENABLE_BULK_MEMORY */

version (WASM_ENABLE_THREAD_MGR) {
bool aot_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;

    uint stack_top_idx = module_.aux_stack_top_global_index;
    uint data_end = module_.aux_data_end;
    uint stack_bottom = module_.aux_stack_bottom;
    bool is_stack_before_data = stack_bottom < data_end ? true : false;

    /* Check the aux stack space, currently we don't allocate space in heap */
    if ((is_stack_before_data && (size > start_offset))
        || ((!is_stack_before_data) && (start_offset - data_end < size)))
        return false;

    if (stack_top_idx != uint.max) {
        /* The aux stack top is a wasm global,
            set the initial value for the global */
        uint global_offset = module_.globals[stack_top_idx].data_offset;
        ubyte* global_addr = module_inst.global_data + global_offset;
        *cast(int*)global_addr = start_offset;

        /* The aux stack boundary is a constant value,
            set the value to exec_env */
        exec_env.aux_stack_boundary.boundary = start_offset - size;
        exec_env.aux_stack_bottom.bottom = start_offset;
        return true;
    }

    return false;
}

bool aot_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;

    /* The aux stack information is resolved in loader
        and store in module */
    uint stack_bottom = module_.aux_stack_bottom;
    uint total_aux_stack_size = module_.aux_stack_size;

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

void const_string_node_size_cb(void* key, void* value, void* p_const_string_size) // if ((ver.WASM_ENABLE_MEMORY_PROFILING) || (ver.WASM_ENABLE_MEMORY_TRACING)) {
{
	uint const_string_size = 0;
    const_string_size += bh_hash_map_get_elem_struct_size();
    const_string_size += strlen(cast(const(char)*)value) + 1;
    *cast(uint*)p_const_string_size += const_string_size;
}

void aot_get_module_mem_consumption(const(AOTModule)* module_, WASMModuleMemConsumption* mem_conspn) {
    uint i = void, size = void;

    memset(mem_conspn, 0, typeof(*mem_conspn).sizeof);

    mem_conspn.module_struct_size = AOTModule.sizeof;

    mem_conspn.types_size = (AOTFuncType*).sizeof * module_.func_type_count;
    for (i = 0; i < module_.func_type_count; i++) {
        AOTFuncType* type = module_.func_types[i];
        size = AOTFuncType.types.offsetof
               + sizeof(uint8) * (type.param_count + type.result_count);
        mem_conspn.types_size += size;
    }

    mem_conspn.imports_size =
        sizeof(AOTImportMemory) * module_.import_memory_count
        + sizeof(AOTImportTable) * module_.import_table_count
        + sizeof(AOTImportGlobal) * module_.import_global_count
        + sizeof(AOTImportFunc) * module_.import_func_count;

    /* func_ptrs and func_type_indexes */
    mem_conspn.functions_size =
        ((void*).sizeof + uint.sizeof) * module_.func_count;

    mem_conspn.tables_size = sizeof(AOTTable) * module_.table_count;

    mem_conspn.memories_size = sizeof(AOTMemory) * module_.memory_count;
    mem_conspn.globals_size = sizeof(AOTGlobal) * module_.global_count;
    mem_conspn.exports_size = sizeof(AOTExport) * module_.export_count;

    mem_conspn.table_segs_size =
        (AOTTableInitData*).sizeof * module_.table_init_data_count;
    for (i = 0; i < module_.table_init_data_count; i++) {
        AOTTableInitData* init_data = module_.table_init_data_list[i];
        size = AOTTableInitData.func_indexes.offsetof
               + uint.sizeof * init_data.func_index_count;
        mem_conspn.table_segs_size += size;
    }

    mem_conspn.data_segs_size =
        (AOTMemInitData*).sizeof * module_.mem_init_data_count;
    for (i = 0; i < module_.mem_init_data_count; i++) {
        mem_conspn.data_segs_size += AOTMemInitData.sizeof;
    }

    if (module_.const_str_set) {
        uint const_string_size = 0;

        mem_conspn.const_strs_size =
            bh_hash_map_get_struct_size(module_.const_str_set);

        bh_hash_map_traverse(module_.const_str_set, &const_string_node_size_cb,
                             cast(void*)&const_string_size);
        mem_conspn.const_strs_size += const_string_size;
    }

    /* code size + literal size + object data section size */
    mem_conspn.aot_code_size =
        module_.code_size + module_.literal_size
        + sizeof(AOTObjectDataSection) * module_.data_section_count;
    for (i = 0; i < module_.data_section_count; i++) {
        AOTObjectDataSection* obj_data = module_.data_sections + i;
        mem_conspn.aot_code_size += sizeof(uint8) * obj_data.size;
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
    mem_conspn.total_size += mem_conspn.aot_code_size;
}

void aot_get_module_inst_mem_consumption(const(AOTModuleInstance)* module_inst, WASMModuleInstMemConsumption* mem_conspn) {
    AOTTableInstance* tbl_inst = void;
    uint i = void;

    memset(mem_conspn, 0, typeof(*mem_conspn).sizeof);

    mem_conspn.module_inst_struct_size = AOTModuleInstance.sizeof;

    mem_conspn.memories_size =
        (void*).sizeof * module_inst.memory_count
        + sizeof(AOTMemoryInstance) * module_inst.memory_count;
    for (i = 0; i < module_inst.memory_count; i++) {
        AOTMemoryInstance* mem_inst = module_inst.memories[i];
        mem_conspn.memories_size +=
            mem_inst.num_bytes_per_page * mem_inst.cur_page_count;
        mem_conspn.app_heap_size =
            mem_inst.heap_data_end - mem_inst.heap_data;
        /* size of app heap structure */
        mem_conspn.memories_size += mem_allocator_get_heap_struct_size();
    }

    mem_conspn.tables_size +=
        (AOTTableInstance*).sizeof * module_inst.table_count;
    for (i = 0; i < module_inst.table_count; i++) {
        tbl_inst = module_inst.tables[i];
        mem_conspn.tables_size += AOTTableInstance.elems.offsetof;
        mem_conspn.tables_size += uint.sizeof * tbl_inst.max_size;
    }

    /* func_ptrs and func_type_indexes */
    mem_conspn.functions_size =
        ((void*).sizeof + uint.sizeof)
        * ((cast(AOTModule*)module_inst.module_).import_func_count
           + (cast(AOTModule*)module_inst.module_).func_count);

    mem_conspn.globals_size = module_inst.global_data_size;

    mem_conspn.exports_size =
        sizeof(AOTFunctionInstance) * cast(ulong)module_inst.export_func_count;

    mem_conspn.total_size += mem_conspn.module_inst_struct_size;
    mem_conspn.total_size += mem_conspn.memories_size;
    mem_conspn.total_size += mem_conspn.functions_size;
    mem_conspn.total_size += mem_conspn.tables_size;
    mem_conspn.total_size += mem_conspn.globals_size;
    mem_conspn.total_size += mem_conspn.exports_size;
}
} /* end of (ver.WASM_ENABLE_MEMORY_PROFILING) \
                 || (ver.WASM_ENABLE_MEMORY_TRACING) */

static if (ver.WASM_ENABLE_REF_TYPES) {
void aot_drop_table_seg(AOTModuleInstance* module_inst, uint tbl_seg_idx) {
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;
    AOTTableInitData* tbl_seg = module_.table_init_data_list[tbl_seg_idx];
    tbl_seg.is_dropped = true;
}

void aot_table_init(AOTModuleInstance* module_inst, uint tbl_idx, uint tbl_seg_idx, uint length, uint src_offset, uint dst_offset) {
    AOTTableInstance* tbl_inst = void;
    AOTTableInitData* tbl_seg = void;
    const(AOTModule)* module_ = cast(AOTModule*)module_inst.module_;

    tbl_inst = module_inst.tables[tbl_idx];
    bh_assert(tbl_inst);

    tbl_seg = module_.table_init_data_list[tbl_seg_idx];
    bh_assert(tbl_seg);

    if (!length) {
        return;
    }

    if (length + src_offset > tbl_seg.func_index_count
        || dst_offset + length > tbl_inst.cur_size) {
        aot_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    if (tbl_seg.is_dropped) {
        aot_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    if (!wasm_elem_is_passive(tbl_seg.mode)) {
        aot_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    bh_memcpy_s(cast(ubyte*)tbl_inst + AOTTableInstance.elems.offsetof
                    + dst_offset * uint.sizeof,
                (tbl_inst.cur_size - dst_offset) * uint.sizeof,
                tbl_seg.func_indexes + src_offset, length * uint.sizeof);
}

void aot_table_copy(AOTModuleInstance* module_inst, uint src_tbl_idx, uint dst_tbl_idx, uint length, uint src_offset, uint dst_offset) {
    AOTTableInstance* src_tbl_inst = void, dst_tbl_inst = void;

    src_tbl_inst = module_inst.tables[src_tbl_idx];
    bh_assert(src_tbl_inst);

    dst_tbl_inst = module_inst.tables[dst_tbl_idx];
    bh_assert(dst_tbl_inst);

    if (cast(ulong)dst_offset + length > dst_tbl_inst.cur_size
        || cast(ulong)src_offset + length > src_tbl_inst.cur_size) {
        aot_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    /* if src_offset >= dst_offset, copy from front to back */
    /* if src_offset < dst_offset, copy from back to front */
    /* merge all together */
    bh_memmove_s(cast(ubyte*)dst_tbl_inst + AOTTableInstance.elems.offsetof
                     + dst_offset * uint.sizeof,
                 (dst_tbl_inst.cur_size - dst_offset) * uint.sizeof,
                 cast(ubyte*)src_tbl_inst + AOTTableInstance.elems.offsetof
                     + src_offset * uint.sizeof,
                 length * uint.sizeof);
}

void aot_table_fill(AOTModuleInstance* module_inst, uint tbl_idx, uint length, uint val, uint data_offset) {
    AOTTableInstance* tbl_inst = void;

    tbl_inst = module_inst.tables[tbl_idx];
    bh_assert(tbl_inst);

    if (data_offset + length > tbl_inst.cur_size) {
        aot_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    for (; length != 0; data_offset++, length--) {
        tbl_inst.elems[data_offset] = val;
    }
}

uint aot_table_grow(AOTModuleInstance* module_inst, uint tbl_idx, uint inc_entries, uint init_val) {
    uint entry_count = void, i = void, orig_tbl_sz = void;
    AOTTableInstance* tbl_inst = void;

    tbl_inst = module_inst.tables[tbl_idx];
    if (!tbl_inst) {
        return uint.max;
    }

    orig_tbl_sz = tbl_inst.cur_size;

    if (!inc_entries) {
        return orig_tbl_sz;
    }

    if (tbl_inst.cur_size > uint_MAX - inc_entries) {
        return uint.max;
    }

    entry_count = tbl_inst.cur_size + inc_entries;
    if (entry_count > tbl_inst.max_size) {
        return uint.max;
    }

    /* fill in */
    for (i = 0; i < inc_entries; ++i) {
        tbl_inst.elems[tbl_inst.cur_size + i] = init_val;
    }

    tbl_inst.cur_size = entry_count;
    return orig_tbl_sz;
}
} /* WASM_ENABLE_REF_TYPES != 0 */

static if ((ver.WASM_ENABLE_DUMP_CALL_STACK) || (ver.WASM_ENABLE_PERF_PROFILING)) {
static if (ver.WASM_ENABLE_CUSTOM_NAME_SECTION) {
private const(char)* lookup_func_name(const(char)** func_names, uint* func_indexes, uint func_index_count, uint func_index) {
    long low = 0, mid = void;
    long high = func_index_count - 1;

    if (!func_names || !func_indexes || func_index_count == 0)
        return null;

    while (low <= high) {
        mid = (low + high) / 2;
        if (func_index == func_indexes[mid]) {
            return func_names[mid];
        }
        else if (func_index < func_indexes[mid])
            high = mid - 1;
        else
            low = mid + 1;
    }

    return null;
}
} /* WASM_ENABLE_CUSTOM_NAME_SECTION != 0 */

private const(char)* get_func_name_from_index(const(AOTModuleInstance)* module_inst, uint func_index) {
    const(char)* func_name = null;
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;

static if (ver.WASM_ENABLE_CUSTOM_NAME_SECTION) {
    if ((func_name =
             lookup_func_name(module_.aux_func_names, module_.aux_func_indexes,
                              module_.aux_func_name_count, func_index))) {
        return func_name;
    }
}

    if (func_index < module_.import_func_count) {
        func_name = module_.import_funcs[func_index].func_name;
    }
    else {
        uint i = void;

        for (i = 0; i < module_.export_count; i++) {
            AOTExport export_ = module_.exports[i];
            if (export_.index == func_index && export_.kind == EXPORT_KIND_FUNC) {
                func_name = export_.name;
                break;
            }
        }
    }

    return func_name;
}

bool aot_alloc_frame(WASMExecEnv* exec_env, uint func_index) {
    AOTFrame* frame = wasm_exec_env_alloc_wasm_frame(exec_env, AOTFrame.sizeof);
static if (ver.WASM_ENABLE_PERF_PROFILING) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
    AOTFuncPerfProfInfo* func_perf_prof = module_inst.func_perf_profilings + func_index;
}

    if (!frame) {
        aot_set_exception(cast(AOTModuleInstance*)exec_env.module_inst,
                          "auxiliary call stack overflow");
        return false;
    }

static if (ver.WASM_ENABLE_PERF_PROFILING) {
    frame.time_started = os_time_get_boot_microsecond();
    frame.func_perf_prof_info = func_perf_prof;
}

    frame.prev_frame = cast(AOTFrame*)exec_env.cur_frame;
    exec_env.cur_frame = cast(WASMInterpFrame*)frame;

    frame.func_index = func_index;
    return true;
}

void aot_free_frame(WASMExecEnv* exec_env) {
    AOTFrame* cur_frame = cast(AOTFrame*)exec_env.cur_frame;
    AOTFrame* prev_frame = cur_frame.prev_frame;

static if (ver.WASM_ENABLE_PERF_PROFILING) {
    cur_frame.func_perf_prof_info.total_exec_time +=
        os_time_get_boot_microsecond() - cur_frame.time_started;
    cur_frame.func_perf_prof_info.total_exec_cnt++;
}

    wasm_exec_env_free_wasm_frame(exec_env, cur_frame);
    exec_env.cur_frame = cast(WASMInterpFrame*)prev_frame;
}
} /* end of (ver.WASM_ENABLE_DUMP_CALL_STACK) \
                 || (ver.WASM_ENABLE_PERF_PROFILING) */

static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
bool aot_create_call_stack(WASMExecEnv* exec_env) {
    AOTFrame* cur_frame = cast(AOTFrame*)exec_env.cur_frame, first_frame = cur_frame;
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
    uint n = 0;

    while (cur_frame) {
        cur_frame = cur_frame.prev_frame;
        n++;
    }

    /* release previous stack frames and create new ones */
    if (!bh_vector_destroy(module_inst.frames)
        || !bh_vector_init(module_inst.frames, n, WASMCApiFrame.sizeof,
                           false)) {
        return false;
    }

    cur_frame = first_frame;
    while (cur_frame) {
        WASMCApiFrame frame = { 0 };
        frame.instance = module_inst;
        frame.module_offset = 0;
        frame.func_index = cur_frame.func_index;
        frame.func_offset = 0;
        frame.func_name_wp =
            get_func_name_from_index(module_inst, cur_frame.func_index);

        if (!bh_vector_append(module_inst.frames, &frame)) {
            bh_vector_destroy(module_inst.frames);
            return false;
        }

        cur_frame = cur_frame.prev_frame;
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

uint aot_dump_call_stack(WASMExecEnv* exec_env, bool print, char* buf, uint len) {
    AOTModuleInstance* module_inst = cast(AOTModuleInstance*)exec_env.module_inst;
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

static if (ver.WASM_ENABLE_PERF_PROFILING) {
void aot_dump_perf_profiling(const(AOTModuleInstance)* module_inst) {
    AOTFuncPerfProfInfo* perf_prof = cast(AOTFuncPerfProfInfo*)module_inst.func_perf_profilings;
    AOTModule* module_ = cast(AOTModule*)module_inst.module_;
    uint total_func_count = module_.import_func_count + module_.func_count, i = void;
    const(char)* func_name = void;

    os_printf("Performance profiler data:\n");
    for (i = 0; i < total_func_count; i++, perf_prof++) {
        func_name = get_func_name_from_index(module_inst, i);

        if (func_name)
            os_printf("  func %s, execution time: %.3f ms, execution count: %d "
                      ~ "times\n",
                      func_name, perf_prof.total_exec_time / 1000.0f,
                      perf_prof.total_exec_cnt);
        else
            os_printf("  func %d, execution time: %.3f ms, execution count: %d "
                      ~ "times\n",
                      i, perf_prof.total_exec_time / 1000.0f,
                      perf_prof.total_exec_cnt);
    }
}
} /* end of WASM_ENABLE_PERF_PROFILING */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


public import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.common.wasm_runtime_common;
public import tagion.iwasm.interpreter.wasm_runtime;
public import tagion.iwasm.compilation.aot;

extern (C) {
//! #endif

enum AOTSectionType {
    AOT_SECTION_TYPE_TARGET_INFO = 0,
    AOT_SECTION_TYPE_INIT_DATA = 1,
    AOT_SECTION_TYPE_TEXT = 2,
    AOT_SECTION_TYPE_FUNCTION = 3,
    AOT_SECTION_TYPE_EXPORT = 4,
    AOT_SECTION_TYPE_RELOCATION = 5,
    AOT_SECTION_TYPE_SIGANATURE = 6,
    AOT_SECTION_TYPE_CUSTOM = 100,
}
alias AOT_SECTION_TYPE_TARGET_INFO = AOTSectionType.AOT_SECTION_TYPE_TARGET_INFO;
alias AOT_SECTION_TYPE_INIT_DATA = AOTSectionType.AOT_SECTION_TYPE_INIT_DATA;
alias AOT_SECTION_TYPE_TEXT = AOTSectionType.AOT_SECTION_TYPE_TEXT;
alias AOT_SECTION_TYPE_FUNCTION = AOTSectionType.AOT_SECTION_TYPE_FUNCTION;
alias AOT_SECTION_TYPE_EXPORT = AOTSectionType.AOT_SECTION_TYPE_EXPORT;
alias AOT_SECTION_TYPE_RELOCATION = AOTSectionType.AOT_SECTION_TYPE_RELOCATION;
alias AOT_SECTION_TYPE_SIGANATURE = AOTSectionType.AOT_SECTION_TYPE_SIGANATURE;
alias AOT_SECTION_TYPE_CUSTOM = AOTSectionType.AOT_SECTION_TYPE_CUSTOM;


enum AOTCustomSectionType {
    AOT_CUSTOM_SECTION_RAW = 0,
    AOT_CUSTOM_SECTION_NATIVE_SYMBOL = 1,
    AOT_CUSTOM_SECTION_ACCESS_CONTROL = 2,
    AOT_CUSTOM_SECTION_NAME = 3,
}
alias AOT_CUSTOM_SECTION_RAW = AOTCustomSectionType.AOT_CUSTOM_SECTION_RAW;
alias AOT_CUSTOM_SECTION_NATIVE_SYMBOL = AOTCustomSectionType.AOT_CUSTOM_SECTION_NATIVE_SYMBOL;
alias AOT_CUSTOM_SECTION_ACCESS_CONTROL = AOTCustomSectionType.AOT_CUSTOM_SECTION_ACCESS_CONTROL;
alias AOT_CUSTOM_SECTION_NAME = AOTCustomSectionType.AOT_CUSTOM_SECTION_NAME;


struct AOTObjectDataSection {
    char* name;
    ubyte* data;
    uint size;
}

/* Relocation info */
struct AOTRelocation {
    ulong relocation_offset;
    long relocation_addend;
    uint relocation_type;
    char* symbol_name;
    /* index in the symbol offset field */
    uint symbol_index;
}

/* Relocation Group */
struct AOTRelocationGroup {
    char* section_name;
    /* index in the symbol offset field */
    uint name_index;
    uint relocation_count;
    AOTRelocation* relocations;
}

/* AOT function instance */
struct AOTFunctionInstance {
    char* func_name;
    uint func_index;
    bool is_import_func;
    union _U {
        struct _Func {
            AOTFuncType* func_type;
            /* function pointer linked */
            void* func_ptr;
        }_Func func;
        AOTImportFunc* func_import;
    }_U u;
}

struct AOTModuleInstanceExtra {
    CApiFuncImport* c_api_func_imports;
}

static if (ver.OS_ENABLE_HW_BOUND_CHECK && ver.BH_PLATFORM_WINDOWS) {
/* clang-format off */
struct AOTUnwindInfo {
    ubyte Version;/*: 3 !!*/
    ubyte Flags;/*: 5 !!*/
    ubyte SizeOfProlog;
    ubyte CountOfCodes;
    ubyte FrameRegister;/*: 4 !!*/
    ubyte FrameOffset;/*: 4 !!*/
    struct _UnwindCode {
        struct  {
            ubyte CodeOffset;
            ubyte UnwindOp;/*: 4 !!*/
            ubyte OpInfo;/*: 4 !!*/
        };
        ushort FrameOffset;
    }_UnwindCode[1] UnwindCode;
}
/* clang-format on */

/* size of mov instruction and jmp instruction */
enum PLT_ITEM_SIZE = 12;
}

struct AOTModule {
    uint module_type;

    /* import memories */
    uint import_memory_count;
    AOTImportMemory* import_memories;

    /* memory info */
    uint memory_count;
    AOTMemory* memories;

    /* init data */
    uint mem_init_data_count;
    AOTMemInitData** mem_init_data_list;

    /* native symbol */
    void** native_symbol_list;

    /* import tables */
    uint import_table_count;
    AOTImportTable* import_tables;

    /* tables */
    uint table_count;
    AOTTable* tables;

    /* table init data info */
    uint table_init_data_count;
    AOTTableInitData** table_init_data_list;

    /* function type info */
    uint func_type_count;
    AOTFuncType** func_types;

    /* import global variable info */
    uint import_global_count;
    AOTImportGlobal* import_globals;

    /* global variable info */
    uint global_count;
    AOTGlobal* globals;

    /* total global variable size */
    uint global_data_size;

    /* import function info */
    uint import_func_count;
    AOTImportFunc* import_funcs;

    /* function info */
    uint func_count;
    /* func pointers of AOTed (un-imported) functions */
    void** func_ptrs;
    /* func type indexes of AOTed (un-imported) functions */
    uint* func_type_indexes;

    /* export info */
    uint export_count;
    AOTExport* exports;

    /* start function index, -1 denotes no start function */
    uint start_func_index;
    /* start function, point to AOTed function */
    void* start_function;

    uint malloc_func_index;
    uint free_func_index;
    uint retain_func_index;

    /* AOTed code */
    void* code;
    uint code_size;

    /* literal for AOTed code */
    ubyte* literal;
    uint literal_size;

version (BH_PLATFORM_WINDOWS) {
    /* extra plt data area for __ymm, __xmm and __real constants
       in Windows platform */
    ubyte* extra_plt_data;
    uint extra_plt_data_size;
    uint ymm_plt_count;
    uint xmm_plt_count;
    uint real_plt_count;
    uint float_plt_count;
}

static if (ver.OS_ENABLE_HW_BOUND_CHECK && ver.BH_PLATFORM_WINDOWS) {
    /* dynamic function table to be added by RtlAddFunctionTable(),
       used to unwind the call stack and register exception handler
       for AOT functions */
    RUNTIME_FUNCTION* rtl_func_table;
    bool rtl_func_table_registered;
}

    /* data sections in AOT object file, including .data, .rodata
       and .rodata.cstN. */
    AOTObjectDataSection* data_sections;
    uint data_section_count;

    /* constant string set */
    HashMap* const_str_set;

    /* the index of auxiliary __data_end global,
       -1 means unexported */
    uint aux_data_end_global_index;
    /* auxiliary __data_end exported by wasm app */
    uint aux_data_end;

    /* the index of auxiliary __heap_base global,
       -1 means unexported */
    uint aux_heap_base_global_index;
    /* auxiliary __heap_base exported by wasm app */
    uint aux_heap_base;

    /* the index of auxiliary stack top global,
       -1 means unexported */
    uint aux_stack_top_global_index;
    /* auxiliary stack bottom resolved */
    uint aux_stack_bottom;
    /* auxiliary stack size resolved */
    uint aux_stack_size;

    /* is indirect mode or not */
    bool is_indirect_mode;

static if (ver.WASM_ENABLE_LIBC_WASI) {
    WASIArguments wasi_args;
    bool import_wasi_api;
}
static if (ver.WASM_ENABLE_DEBUG_AOT) {
    void* elf_hdr;
    uint elf_size;
}
static if (ver.WASM_ENABLE_CUSTOM_NAME_SECTION) {
    const(char)** aux_func_names;
    uint* aux_func_indexes;
    uint aux_func_name_count;
}
static if (ver.WASM_ENABLE_LOAD_CUSTOM_SECTION) {
    WASMCustomSection* custom_section_list;
}
}

alias AOTMemoryInstance = WASMMemoryInstance;
alias AOTTableInstance = WASMTableInstance;
alias AOTModuleInstance = WASMModuleInstance;

/* Target info, read from ELF header of object file */
struct AOTTargetInfo {
    /* Binary type, elf32l/elf32b/elf64l/elf64b */
    ushort bin_type;
    /* ABI type */
    ushort abi_type;
    /* Object file type */
    ushort e_type;
    /* Architecture */
    ushort e_machine;
    /* Object file version */
    uint e_version;
    /* Processor-specific flags */
    uint e_flags;
    /* Reserved */
    uint reserved;
    /* Arch name */
    char[16] arch = 0;
}

struct AOTFuncPerfProfInfo {
    /* total execution time */
    ulong total_exec_time;
    /* total execution count */
    uint total_exec_cnt;
}

/* AOT auxiliary call stack */
struct AOTFrame {
    AOTFrame* prev_frame;
    uint func_index;
static if (ver.WASM_ENABLE_PERF_PROFILING) {
    ulong time_started;
    AOTFuncPerfProfInfo* func_perf_prof_info;
}
}

/**
 * Load a AOT module from aot file buffer
 * @param buf the byte buffer which contains the AOT file data
 * @param size the size of the buffer
 * @param error_buf output of the error info
 * @param error_buf_size the size of the error string
 *
 * @return return AOT module loaded, NULL if failed
 */
AOTModule* aot_load_from_aot_file(const(ubyte)* buf, uint size, char* error_buf, uint error_buf_size);

/**
 * Load a AOT module from a specified AOT section list.
 *
 * @param section_list the section list which contains each section data
 * @param error_buf output of the error info
 * @param error_buf_size the size of the error string
 *
 * @return return AOT module loaded, NULL if failed
 */
AOTModule* aot_load_from_sections(AOTSection* section_list, char* error_buf, uint error_buf_size);

/**
 * Unload a AOT module.
 *
 * @param module the module to be unloaded
 */
void aot_unload(AOTModule* module_);

/**
 * Instantiate a AOT module.
 *
 * @param module the AOT module to instantiate
 * @param is_sub_inst the flag of sub instance
 * @param heap_size the default heap size of the module instance, a heap will
 *        be created besides the app memory space. Both wasm app and native
 *        function can allocate memory from the heap. If heap_size is 0, the
 *        default heap size will be used.
 * @param error_buf buffer to output the error info if failed
 * @param error_buf_size the size of the error buffer
 *
 * @return return the instantiated AOT module instance, NULL if failed
 */
AOTModuleInstance* aot_instantiate(AOTModule* module_, bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size);

/**
 * Deinstantiate a AOT module instance, destroy the resources.
 *
 * @param module_inst the AOT module instance to destroy
 * @param is_sub_inst the flag of sub instance
 */
void aot_deinstantiate(AOTModuleInstance* module_inst, bool is_sub_inst);

/**
 * Lookup an exported function in the AOT module instance.
 *
 * @param module_inst the module instance
 * @param name the name of the function
 * @param signature the signature of the function, use "i32"/"i64"/"f32"/"f64"
 *        to represent the type of i32/i64/f32/f64, e.g. "(i32i64)" "(i32)f32"
 *
 * @return the function instance found
 */
AOTFunctionInstance* aot_lookup_function(const(AOTModuleInstance)* module_inst, const(char)* name, const(char)* signature);
/**
 * Call the given AOT function of a AOT module instance with
 * arguments.
 *
 * @param exec_env the execution environment
 * @param function the function to be called
 * @param argc the number of arguments
 * @param argv the arguments.  If the function method has return value,
 *   the first (or first two in case 64-bit return value) element of
 *   argv stores the return value of the called AOT function after this
 *   function returns.
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call aot_get_exception to get exception info.
 */
bool aot_call_function(WASMExecEnv* exec_env, AOTFunctionInstance* function_, uint argc, uint* argv);

bool aot_create_exec_env_and_call_function(AOTModuleInstance* module_inst, AOTFunctionInstance* function_, uint argc, uint* argv);

/**
 * Set AOT module instance exception with exception string
 *
 * @param module the AOT module instance
 *
 * @param exception current exception string
 */
void aot_set_exception(AOTModuleInstance* module_inst, const(char)* exception);

void aot_set_exception_with_id(AOTModuleInstance* module_inst, uint id);

/**
 * Get exception info of the AOT module instance.
 *
 * @param module_inst the AOT module instance
 *
 * @return the exception string
 */
const(char)* aot_get_exception(AOTModuleInstance* module_inst);

uint aot_module_malloc(AOTModuleInstance* module_inst, uint size, void** p_native_addr);

uint aot_module_realloc(AOTModuleInstance* module_inst, uint ptr, uint size, void** p_native_addr);

void aot_module_free(AOTModuleInstance* module_inst, uint ptr);

uint aot_module_dup_data(AOTModuleInstance* module_inst, const(char)* src, uint size);

bool aot_enlarge_memory(AOTModuleInstance* module_inst, uint inc_page_count);

/**
 * Invoke native function from aot code
 */
bool aot_invoke_native(WASMExecEnv* exec_env, uint func_idx, uint argc, uint* argv);

bool aot_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint table_elem_idx, uint argc, uint* argv);

/**
 * Check whether the app address and the buf is inside the linear memory,
 * and convert the app address into native address
 */
bool aot_check_app_addr_and_convert(AOTModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr);

uint aot_get_plt_table_size();

void* aot_memmove(void* dest, const(void)* src, size_t n);

void* aot_memset(void* s, int c, size_t n);

double aot_sqrt(double x);

float aot_sqrtf(float x);

static if (ver.WASM_ENABLE_BULK_MEMORY) {
bool aot_memory_init(AOTModuleInstance* module_inst, uint seg_index, uint offset, uint len, uint dst);

bool aot_data_drop(AOTModuleInstance* module_inst, uint seg_index);
}

static if (ver.WASM_ENABLE_THREAD_MGR) {
bool aot_set_aux_stack(WASMExecEnv* exec_env, uint start_offset, uint size);

bool aot_get_aux_stack(WASMExecEnv* exec_env, uint* start_offset, uint* size);
}

void aot_get_module_mem_consumption(const(AOTModule)* module_, WASMModuleMemConsumption* mem_conspn);

void aot_get_module_inst_mem_consumption(const(AOTModuleInstance)* module_inst, WASMModuleInstMemConsumption* mem_conspn);

static if (ver.WASM_ENABLE_REF_TYPES) {
void aot_drop_table_seg(AOTModuleInstance* module_inst, uint tbl_seg_idx);

void aot_table_init(AOTModuleInstance* module_inst, uint tbl_idx, uint tbl_seg_idx, uint length, uint src_offset, uint dst_offset);

void aot_table_copy(AOTModuleInstance* module_inst, uint src_tbl_idx, uint dst_tbl_idx, uint length, uint src_offset, uint dst_offset);

void aot_table_fill(AOTModuleInstance* module_inst, uint tbl_idx, uint length, uint val, uint data_offset);

uint aot_table_grow(AOTModuleInstance* module_inst, uint tbl_idx, uint inc_entries, uint init_val);
}

bool aot_alloc_frame(WASMExecEnv* exec_env, uint func_index);

void aot_free_frame(WASMExecEnv* exec_env);

bool aot_create_call_stack(WASMExecEnv* exec_env);

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
uint aot_dump_call_stack(WASMExecEnv* exec_env, bool print, char* buf, uint len);

void aot_dump_perf_profiling(const(AOTModuleInstance)* module_inst);

const(ubyte)* aot_get_custom_section(const(AOTModule)* module_, const(char)* name, uint* len);

version (none) {
} /* end of extern "C" */
}

//! #endif /* end of _AOT_RUNTIME_H_ */
