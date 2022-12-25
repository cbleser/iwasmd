module aot;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot;

private char[128] aot_error = 0;

char* aot_get_last_error() {
    return aot_error[0] == '\0' ? "" : aot_error;
}

void aot_set_last_error_v(const(char)* format, ...) {
    va_list args = void;
    va_start(args, format);
    vsnprintf(aot_error.ptr, aot_error.sizeof, format, args);
    va_end(args);
}

void aot_set_last_error(const(char)* error) {
    if (error)
        snprintf(aot_error.ptr, aot_error.sizeof, "Error: %s", error);
    else
        aot_error[0] = '\0';
}

private void aot_destroy_mem_init_data_list(AOTMemInitData** data_list, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (data_list[i])
            wasm_runtime_free(data_list[i]);
    wasm_runtime_free(data_list);
}

private AOTMemInitData** aot_create_mem_init_data_list(const(WASMModule)* module_) {
    AOTMemInitData** data_list = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = (AOTMemInitData*).sizeof * cast(ulong)module_.data_seg_count;
    if (size >= UINT32_MAX
        || ((data_list = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    memset(data_list, 0, size);

    /* Create each memory data segment */
    for (i = 0; i < module_.data_seg_count; i++) {
        size = AOTMemInitData.bytes.offsetof
               + cast(ulong)module_.data_segments[i].data_length;
        if (size >= UINT32_MAX
            || ((data_list[i] = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }

static if (WASM_ENABLE_BULK_MEMORY != 0) {
        data_list[i].is_passive = module_.data_segments[i].is_passive;
        data_list[i].memory_index = module_.data_segments[i].memory_index;
}
        data_list[i].offset = module_.data_segments[i].base_offset;
        data_list[i].byte_count = module_.data_segments[i].data_length;
        memcpy(data_list[i].bytes, module_.data_segments[i].data,
               module_.data_segments[i].data_length);
    }

    return data_list;

fail:
    aot_destroy_mem_init_data_list(data_list, module_.data_seg_count);
    return null;
}

private void aot_destroy_table_init_data_list(AOTTableInitData** data_list, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (data_list[i])
            wasm_runtime_free(data_list[i]);
    wasm_runtime_free(data_list);
}

private AOTTableInitData** aot_create_table_init_data_list(const(WASMModule)* module_) {
    AOTTableInitData** data_list = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = (AOTTableInitData*).sizeof * cast(ulong)module_.table_seg_count;
    if (size >= UINT32_MAX
        || ((data_list = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    memset(data_list, 0, size);

    /* Create each table data segment */
    for (i = 0; i < module_.table_seg_count; i++) {
        size =
            AOTTableInitData.func_indexes.offsetof
            + sizeof(uint32) * cast(ulong)module_.table_segments[i].function_count;
        if (size >= UINT32_MAX
            || ((data_list[i] = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }

        data_list[i].offset = module_.table_segments[i].base_offset;
        data_list[i].func_index_count =
            module_.table_segments[i].function_count;
        data_list[i].mode = module_.table_segments[i].mode;
        data_list[i].elem_type = module_.table_segments[i].elem_type;
        /* runtime control it */
        data_list[i].is_dropped = false;
        data_list[i].table_index = module_.table_segments[i].table_index;
        bh_memcpy_s(&data_list[i].offset, AOTInitExpr.sizeof,
                    &module_.table_segments[i].base_offset,
                    AOTInitExpr.sizeof);
        data_list[i].func_index_count =
            module_.table_segments[i].function_count;
        bh_memcpy_s(data_list[i].func_indexes,
                    sizeof(uint32) * module_.table_segments[i].function_count,
                    module_.table_segments[i].func_indexes,
                    sizeof(uint32) * module_.table_segments[i].function_count);
    }

    return data_list;

fail:
    aot_destroy_table_init_data_list(data_list, module_.table_seg_count);
    return null;
}

private AOTImportGlobal* aot_create_import_globals(const(WASMModule)* module_, uint* p_import_global_data_size) {
    AOTImportGlobal* import_globals = void;
    ulong size = void;
    uint i = void, data_offset = 0;

    /* Allocate memory */
    size = sizeof(AOTImportGlobal) * cast(ulong)module_.import_global_count;
    if (size >= UINT32_MAX
        || ((import_globals = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    memset(import_globals, 0, cast(uint)size);

    /* Create each import global */
    for (i = 0; i < module_.import_global_count; i++) {
        WASMGlobalImport* import_global = &module_.import_globals[i].u.global;
        import_globals[i].module_name = import_global.module_name;
        import_globals[i].global_name = import_global.field_name;
        import_globals[i].type = import_global.type;
        import_globals[i].is_mutable = import_global.is_mutable;
        import_globals[i].global_data_linked =
            import_global.global_data_linked;
        import_globals[i].size = wasm_value_type_size(import_global.type);
        /* Calculate data offset */
        import_globals[i].data_offset = data_offset;
        data_offset += wasm_value_type_size(import_global.type);
    }

    *p_import_global_data_size = data_offset;
    return import_globals;
}

private AOTGlobal* aot_create_globals(const(WASMModule)* module_, uint global_data_start_offset, uint* p_global_data_size) {
    AOTGlobal* globals = void;
    ulong size = void;
    uint i = void, data_offset = global_data_start_offset;

    /* Allocate memory */
    size = sizeof(AOTGlobal) * cast(ulong)module_.global_count;
    if (size >= UINT32_MAX || ((globals = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    memset(globals, 0, cast(uint)size);

    /* Create each global */
    for (i = 0; i < module_.global_count; i++) {
        WASMGlobal* global = &module_.globals[i];
        globals[i].type = global.type;
        globals[i].is_mutable = global.is_mutable;
        globals[i].size = wasm_value_type_size(global.type);
        memcpy(&globals[i].init_expr, &global.init_expr,
               typeof(global.init_expr).sizeof);
        /* Calculate data offset */
        globals[i].data_offset = data_offset;
        data_offset += wasm_value_type_size(global.type);
    }

    *p_global_data_size = data_offset - global_data_start_offset;
    return globals;
}

private void aot_destroy_func_types(AOTFuncType** func_types, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (func_types[i])
            wasm_runtime_free(func_types[i]);
    wasm_runtime_free(func_types);
}

private AOTFuncType** aot_create_func_types(const(WASMModule)* module_) {
    AOTFuncType** func_types = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = (AOTFuncType*).sizeof * cast(ulong)module_.type_count;
    if (size >= UINT32_MAX
        || ((func_types = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    memset(func_types, 0, size);

    /* Create each function type */
    for (i = 0; i < module_.type_count; i++) {
        size = AOTFuncType.types.offsetof
               + cast(ulong)module_.types[i].param_count
               + cast(ulong)module_.types[i].result_count;
        if (size >= UINT32_MAX
            || ((func_types[i] = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }
        memcpy(func_types[i], module_.types[i], size);
    }

    return func_types;

fail:
    aot_destroy_func_types(func_types, module_.type_count);
    return null;
}

private AOTImportFunc* aot_create_import_funcs(const(WASMModule)* module_) {
    AOTImportFunc* import_funcs = void;
    ulong size = void;
    uint i = void, j = void;

    /* Allocate memory */
    size = sizeof(AOTImportFunc) * cast(ulong)module_.import_function_count;
    if (size >= UINT32_MAX
        || ((import_funcs = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    /* Create each import function */
    for (i = 0; i < module_.import_function_count; i++) {
        WASMFunctionImport* import_func = &module_.import_functions[i].u.function_;
        import_funcs[i].module_name = import_func.module_name;
        import_funcs[i].func_name = import_func.field_name;
        import_funcs[i].func_ptr_linked = import_func.func_ptr_linked;
        import_funcs[i].func_type = import_func.func_type;
        import_funcs[i].signature = import_func.signature;
        import_funcs[i].attachment = import_func.attachment;
        import_funcs[i].call_conv_raw = import_func.call_conv_raw;
        import_funcs[i].call_conv_wasm_c_api = false;
        /* Resolve function type index */
        for (j = 0; j < module_.type_count; j++)
            if (import_func.func_type == module_.types[j]) {
                import_funcs[i].func_type_index = j;
                break;
            }
    }

    return import_funcs;
}

private void aot_destroy_funcs(AOTFunc** funcs, uint count) {
    uint i = void;

    for (i = 0; i < count; i++)
        if (funcs[i])
            wasm_runtime_free(funcs[i]);
    wasm_runtime_free(funcs);
}

private AOTFunc** aot_create_funcs(const(WASMModule)* module_) {
    AOTFunc** funcs = void;
    ulong size = void;
    uint i = void, j = void;

    /* Allocate memory */
    size = (AOTFunc*).sizeof * cast(ulong)module_.function_count;
    if (size >= UINT32_MAX || ((funcs = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }

    memset(funcs, 0, size);

    /* Create each function */
    for (i = 0; i < module_.function_count; i++) {
        WASMFunction* func = module_.functions[i];
        size = AOTFunc.sizeof;
        if (((funcs[i] = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }

        funcs[i].func_type = func.func_type;

        /* Resolve function type index */
        for (j = 0; j < module_.type_count; j++)
            if (func.func_type == module_.types[j]) {
                funcs[i].func_type_index = j;
                break;
            }

        /* Resolve local variable info and code info */
        funcs[i].local_count = func.local_count;
        funcs[i].local_types = func.local_types;
        funcs[i].param_cell_num = func.param_cell_num;
        funcs[i].local_cell_num = func.local_cell_num;
        funcs[i].code = func.code;
        funcs[i].code_size = func.code_size;
    }

    return funcs;

fail:
    aot_destroy_funcs(funcs, module_.function_count);
    return null;
}

AOTCompData* aot_create_comp_data(WASMModule* module_) {
    AOTCompData* comp_data = void;
    uint import_global_data_size = 0, global_data_size = 0, i = void, j = void;
    ulong size = void;

    /* Allocate memory */
    if (((comp_data = wasm_runtime_malloc(AOTCompData.sizeof)) == 0)) {
        aot_set_last_error("create compile data failed.\n");
        return null;
    }

    memset(comp_data, 0, AOTCompData.sizeof);

    comp_data.memory_count =
        module_.import_memory_count + module_.memory_count;

    /* TODO: create import memories */

    /* Allocate memory for memory array, reserve one AOTMemory space at least */
    if (!comp_data.memory_count)
        comp_data.memory_count = 1;

    size = cast(ulong)comp_data.memory_count * AOTMemory.sizeof;
    if (size >= UINT32_MAX
        || ((comp_data.memories = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("create memories array failed.\n");
        goto fail;
    }
    memset(comp_data.memories, 0, size);

    if (!(module_.import_memory_count + module_.memory_count)) {
        comp_data.memories[0].num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;
    }

    /* Set memory page count */
    for (i = 0; i < module_.import_memory_count + module_.memory_count; i++) {
        if (i < module_.import_memory_count) {
            comp_data.memories[i].memory_flags =
                module_.import_memories[i].u.memory.flags;
            comp_data.memories[i].num_bytes_per_page =
                module_.import_memories[i].u.memory.num_bytes_per_page;
            comp_data.memories[i].mem_init_page_count =
                module_.import_memories[i].u.memory.init_page_count;
            comp_data.memories[i].mem_max_page_count =
                module_.import_memories[i].u.memory.max_page_count;
            comp_data.memories[i].num_bytes_per_page =
                module_.import_memories[i].u.memory.num_bytes_per_page;
        }
        else {
            j = i - module_.import_memory_count;
            comp_data.memories[i].memory_flags = module_.memories[j].flags;
            comp_data.memories[i].num_bytes_per_page =
                module_.memories[j].num_bytes_per_page;
            comp_data.memories[i].mem_init_page_count =
                module_.memories[j].init_page_count;
            comp_data.memories[i].mem_max_page_count =
                module_.memories[j].max_page_count;
            comp_data.memories[i].num_bytes_per_page =
                module_.memories[j].num_bytes_per_page;
        }
    }

    /* Create memory data segments */
    comp_data.mem_init_data_count = module_.data_seg_count;
    if (comp_data.mem_init_data_count > 0
        && ((comp_data.mem_init_data_list =
                 aot_create_mem_init_data_list(module_)) == 0))
        goto fail;

    /* Create tables */
    comp_data.table_count = module_.import_table_count + module_.table_count;

    if (comp_data.table_count > 0) {
        size = sizeof(AOTTable) * cast(ulong)comp_data.table_count;
        if (size >= UINT32_MAX
            || ((comp_data.tables = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            aot_set_last_error("create memories array failed.\n");
            goto fail;
        }
        memset(comp_data.tables, 0, size);
        for (i = 0; i < comp_data.table_count; i++) {
            if (i < module_.import_table_count) {
                comp_data.tables[i].elem_type =
                    module_.import_tables[i].u.table.elem_type;
                comp_data.tables[i].table_flags =
                    module_.import_tables[i].u.table.flags;
                comp_data.tables[i].table_init_size =
                    module_.import_tables[i].u.table.init_size;
                comp_data.tables[i].table_max_size =
                    module_.import_tables[i].u.table.max_size;
                comp_data.tables[i].possible_grow =
                    module_.import_tables[i].u.table.possible_grow;
            }
            else {
                j = i - module_.import_table_count;
                comp_data.tables[i].elem_type = module_.tables[j].elem_type;
                comp_data.tables[i].table_flags = module_.tables[j].flags;
                comp_data.tables[i].table_init_size =
                    module_.tables[j].init_size;
                comp_data.tables[i].table_max_size =
                    module_.tables[j].max_size;
                comp_data.tables[i].possible_grow =
                    module_.tables[j].possible_grow;
            }
        }
    }

    /* Create table data segments */
    comp_data.table_init_data_count = module_.table_seg_count;
    if (comp_data.table_init_data_count > 0
        && ((comp_data.table_init_data_list =
                 aot_create_table_init_data_list(module_)) == 0))
        goto fail;

    /* Create import globals */
    comp_data.import_global_count = module_.import_global_count;
    if (comp_data.import_global_count > 0
        && ((comp_data.import_globals =
                 aot_create_import_globals(module_, &import_global_data_size)) == 0))
        goto fail;

    /* Create globals */
    comp_data.global_count = module_.global_count;
    if (comp_data.global_count
        && ((comp_data.globals = aot_create_globals(
                 module_, import_global_data_size, &global_data_size)) == 0))
        goto fail;

    comp_data.global_data_size = import_global_data_size + global_data_size;

    /* Create function types */
    comp_data.func_type_count = module_.type_count;
    if (comp_data.func_type_count
        && ((comp_data.func_types = aot_create_func_types(module_)) == 0))
        goto fail;

    /* Create import functions */
    comp_data.import_func_count = module_.import_function_count;
    if (comp_data.import_func_count
        && ((comp_data.import_funcs = aot_create_import_funcs(module_)) == 0))
        goto fail;

    /* Create functions */
    comp_data.func_count = module_.function_count;
    if (comp_data.func_count && ((comp_data.funcs = aot_create_funcs(module_)) == 0))
        goto fail;

static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    /* Create custom name section */
    comp_data.name_section_buf = module_.name_section_buf;
    comp_data.name_section_buf_end = module_.name_section_buf_end;
}

    /* Create aux data/heap/stack information */
    comp_data.aux_data_end_global_index = module_.aux_data_end_global_index;
    comp_data.aux_data_end = module_.aux_data_end;
    comp_data.aux_heap_base_global_index = module_.aux_heap_base_global_index;
    comp_data.aux_heap_base = module_.aux_heap_base;
    comp_data.aux_stack_top_global_index = module_.aux_stack_top_global_index;
    comp_data.aux_stack_bottom = module_.aux_stack_bottom;
    comp_data.aux_stack_size = module_.aux_stack_size;

    comp_data.start_func_index = module_.start_function;
    comp_data.malloc_func_index = module_.malloc_function;
    comp_data.free_func_index = module_.free_function;
    comp_data.retain_func_index = module_.retain_function;

    comp_data.wasm_module = module_;

    return comp_data;

fail:

    aot_destroy_comp_data(comp_data);
    return null;
}

void aot_destroy_comp_data(AOTCompData* comp_data) {
    if (!comp_data)
        return;

    if (comp_data.import_memories)
        wasm_runtime_free(comp_data.import_memories);

    if (comp_data.memories)
        wasm_runtime_free(comp_data.memories);

    if (comp_data.mem_init_data_list)
        aot_destroy_mem_init_data_list(comp_data.mem_init_data_list,
                                       comp_data.mem_init_data_count);

    if (comp_data.import_tables)
        wasm_runtime_free(comp_data.import_tables);

    if (comp_data.tables)
        wasm_runtime_free(comp_data.tables);

    if (comp_data.table_init_data_list)
        aot_destroy_table_init_data_list(comp_data.table_init_data_list,
                                         comp_data.table_init_data_count);

    if (comp_data.import_globals)
        wasm_runtime_free(comp_data.import_globals);

    if (comp_data.globals)
        wasm_runtime_free(comp_data.globals);

    if (comp_data.func_types)
        aot_destroy_func_types(comp_data.func_types,
                               comp_data.func_type_count);

    if (comp_data.import_funcs)
        wasm_runtime_free(comp_data.import_funcs);

    if (comp_data.funcs)
        aot_destroy_funcs(comp_data.funcs, comp_data.func_count);

    if (comp_data.aot_name_section_buf)
        wasm_runtime_free(comp_data.aot_name_section_buf);

    wasm_runtime_free(comp_data);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;
public import bh_assert;
public import ...common.wasm_runtime_common;
public import ...interpreter.wasm;

version (none) {
extern "C" {
//! #endif

version (AOT_FUNC_PREFIX) {} else {
enum AOT_FUNC_PREFIX = "aot_func#";
}

alias AOTInitExpr = InitializerExpression;
alias AOTFuncType = WASMType;
alias AOTExport = WASMExport;

static if (WASM_ENABLE_DEBUG_AOT != 0) {
alias dwar_extractor_handle_t = void*;
}

enum AOTIntCond {
    INT_EQZ = 0,
    INT_EQ,
    INT_NE,
    INT_LT_S,
    INT_LT_U,
    INT_GT_S,
    INT_GT_U,
    INT_LE_S,
    INT_LE_U,
    INT_GE_S,
    INT_GE_U
}
alias INT_EQZ = AOTIntCond.INT_EQZ;
alias INT_EQ = AOTIntCond.INT_EQ;
alias INT_NE = AOTIntCond.INT_NE;
alias INT_LT_S = AOTIntCond.INT_LT_S;
alias INT_LT_U = AOTIntCond.INT_LT_U;
alias INT_GT_S = AOTIntCond.INT_GT_S;
alias INT_GT_U = AOTIntCond.INT_GT_U;
alias INT_LE_S = AOTIntCond.INT_LE_S;
alias INT_LE_U = AOTIntCond.INT_LE_U;
alias INT_GE_S = AOTIntCond.INT_GE_S;
alias INT_GE_U = AOTIntCond.INT_GE_U;


enum AOTFloatCond {
    FLOAT_EQ = 0,
    FLOAT_NE,
    FLOAT_LT,
    FLOAT_GT,
    FLOAT_LE,
    FLOAT_GE,
    FLOAT_UNO
}
alias FLOAT_EQ = AOTFloatCond.FLOAT_EQ;
alias FLOAT_NE = AOTFloatCond.FLOAT_NE;
alias FLOAT_LT = AOTFloatCond.FLOAT_LT;
alias FLOAT_GT = AOTFloatCond.FLOAT_GT;
alias FLOAT_LE = AOTFloatCond.FLOAT_LE;
alias FLOAT_GE = AOTFloatCond.FLOAT_GE;
alias FLOAT_UNO = AOTFloatCond.FLOAT_UNO;


/**
 * Import memory
 */
struct AOTImportMemory {
    char* module_name;
    char* memory_name;
    uint memory_flags;
    uint num_bytes_per_page;
    uint mem_init_page_count;
    uint mem_max_page_count;
}

/**
 * Memory information
 */
struct AOTMemory {
    /* memory info */
    uint memory_flags;
    uint num_bytes_per_page;
    uint mem_init_page_count;
    uint mem_max_page_count;
}

/**
 * A segment of memory init data
 */
struct AOTMemInitData {
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    /* Passive flag */
    bool is_passive;
    /* memory index */
    uint memory_index;
}
    /* Start address of init data */
    AOTInitExpr offset;
    /* Byte count */
    uint byte_count;
    /* Byte array */
    ubyte[1] bytes;
}

/**
 * Import table
 */
struct AOTImportTable {
    char* module_name;
    char* table_name;
    uint elem_type;
    uint table_flags;
    uint table_init_size;
    uint table_max_size;
    bool possible_grow;
}

/**
 * Table
 */
struct AOTTable {
    uint elem_type;
    uint table_flags;
    uint table_init_size;
    uint table_max_size;
    bool possible_grow;
}

/**
 * A segment of table init data
 */
struct AOTTableInitData {
    /* 0 to 7 */
    uint mode;
    /* funcref or externref, elemkind will be considered as funcref */
    uint elem_type;
    bool is_dropped;
    /* optional, only for active */
    uint table_index;
    /* Start address of init data */
    AOTInitExpr offset;
    /* Function index count */
    uint func_index_count;
    /* Function index array */
    uint[1] func_indexes;
}

/**
 * Import global variable
 */
struct AOTImportGlobal {
    char* module_name;
    char* global_name;
    /* VALUE_TYPE_I32/I64/F32/F64 */
    ubyte type;
    bool is_mutable;
    uint size;
    /* The data offset of current global in global data */
    uint data_offset;
    /* global data after linked */
    WASMValue global_data_linked;
}

/**
 * Global variable
 */
struct AOTGlobal {
    /* VALUE_TYPE_I32/I64/F32/F64 */
    ubyte type;
    bool is_mutable;
    uint size;
    /* The data offset of current global in global data */
    uint data_offset;
    AOTInitExpr init_expr;
}

/**
 * Import function
 */
struct AOTImportFunc {
    char* module_name;
    char* func_name;
    AOTFuncType* func_type;
    uint func_type_index;
    /* function pointer after linked */
    void* func_ptr_linked;
    /* signature from registered native symbols */
    const(char)* signature;
    /* attachment */
    void* attachment;
    bool call_conv_raw;
    bool call_conv_wasm_c_api;
    bool wasm_c_api_with_env;
}

/**
 * Function
 */
struct AOTFunc {
    AOTFuncType* func_type;
    uint func_type_index;
    uint local_count;
    ubyte* local_types;
    ushort param_cell_num;
    ushort local_cell_num;
    uint code_size;
    ubyte* code;
}

struct AOTCompData {
    /* Import memories */
    uint import_memory_count;
    AOTImportMemory* import_memories;

    /* Memories */
    uint memory_count;
    AOTMemory* memories;

    /* Memory init data info */
    uint mem_init_data_count;
    AOTMemInitData** mem_init_data_list;

    /* Import tables */
    uint import_table_count;
    AOTImportTable* import_tables;

    /* Tables */
    uint table_count;
    AOTTable* tables;

    /* Table init data info */
    uint table_init_data_count;
    AOTTableInitData** table_init_data_list;

    /* Import globals */
    uint import_global_count;
    AOTImportGlobal* import_globals;

    /* Globals */
    uint global_count;
    AOTGlobal* globals;

    /* Function types */
    uint func_type_count;
    AOTFuncType** func_types;

    /* Import functions */
    uint import_func_count;
    AOTImportFunc* import_funcs;

    /* Functions */
    uint func_count;
    AOTFunc** funcs;

    /* Custom name sections */
    const(ubyte)* name_section_buf;
    const(ubyte)* name_section_buf_end;
    ubyte* aot_name_section_buf;
    uint aot_name_section_size;

    uint global_data_size;

    uint start_func_index;
    uint malloc_func_index;
    uint free_func_index;
    uint retain_func_index;

    uint aux_data_end_global_index;
    uint aux_data_end;
    uint aux_heap_base_global_index;
    uint aux_heap_base;
    uint aux_stack_top_global_index;
    uint aux_stack_bottom;
    uint aux_stack_size;

    WASMModule* wasm_module;
static if (WASM_ENABLE_DEBUG_AOT != 0) {
    dwar_extractor_handle_t extractor;
}
}

struct AOTNativeSymbol {
    bh_list_link link;
    char[32] symbol = 0;
    int index;
}

AOTCompData* aot_create_comp_data(WASMModule* module_);

void aot_destroy_comp_data(AOTCompData* comp_data);

char* aot_get_last_error();

void aot_set_last_error(const(char)* error);

void aot_set_last_error_v(const(char)* format, ...);

static if (BH_DEBUG != 0) {
enum string HANDLE_FAILURE(string callee) = `                                    \
    do {                                                          \
        aot_set_last_error_v("call %s failed in %s:%d", (callee), \
                             __FUNCTION__, __LINE__);             \
    } while (0)`;
} else {
enum string HANDLE_FAILURE(string callee) = `                            \
    do {                                                  \
        aot_set_last_error_v("call %s failed", (callee)); \
    } while (0)`;
}

pragma(inline, true) private uint aot_get_imp_tbl_data_slots(const(AOTImportTable)* tbl, bool is_jit_mode) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    if (is_jit_mode)
        return tbl.table_max_size;
} else {
    cast(void)is_jit_mode;
}
    return tbl.possible_grow ? tbl.table_max_size : tbl.table_init_size;
}

pragma(inline, true) private uint aot_get_tbl_data_slots(const(AOTTable)* tbl, bool is_jit_mode) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    if (is_jit_mode)
        return tbl.table_max_size;
} else {
    cast(void)is_jit_mode;
}
    return tbl.possible_grow ? tbl.table_max_size : tbl.table_init_size;
}

version (none) {}
} /* end of extern "C" */
}

 /* end of _AOT_H_ */
