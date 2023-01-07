module tagion.iwasm.interpreter.wasm_runtime;
@nogc nothrow:
extern (C):
__gshared:
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* This header is separate from features.h so that the compiler can
   include it implicitly at the start of every compilation.  It must
   not itself include <features.h> or any other header that includes
   <features.h> because the implicit include comes before any feature
   test macros that may be defined in a source file before it first
   explicitly includes a system header.  GCC knows the name of this
   header in order to preinclude it.  */
/* glibc's intent is to support the IEC 559 math functionality, real
   and complex.  If the GCC (4.9 and later) predefined macros
   specifying compiler intent are available, use them to determine
   whether the overall intent is to support these features; otherwise,
   presume an older compiler has intent to support these features and
   define these macros by default.  */
/* wchar_t uses Unicode 10.0.0.  Version 10.0 of the Unicode Standard is
   synchronized with ISO/IEC 10646:2017, fifth edition, plus
   the following additions from Amendment 1 to the fifth edition:
   - 56 emoji characters
   - 285 hentaigana
   - 3 additional Zanabazar Square characters */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import core.stdc.stdint : uintptr_t; 
import tagion.iwasm.basic;
import tagion.iwasm.config;
import tagion.iwasm.app_framework.base.app.bh_platform;
import tagion.iwasm.share.utils.bh_hashmap;
import tagion.iwasm.share.utils.bh_assert;
import tagion.iwasm.share.utils.bh_list;
import tagion.iwasm.share.utils.bh_vector;
/** Value Type */
/* Used by AOT */
/*  Used by loader to represent any type of i32/i64/f32/f64 */
/* = WASM_OP_REF_FUNC */
/* = WASM_OP_REF_NULL */

union V128 {
    byte[16] i8x16;
    short[8] i16x8;
    int[4] i32x8;
    long[2] i64x2;
    float[4] f32x4;
    double[2] f64x2;
}


struct WASMImport {
    ubyte kind;
    union _U {
        WASMFunctionImport function_;
        WASMTableImport table;
        WASMMemoryImport memory;
        WASMGlobalImport global;
        struct _Names {
            char* module_name;
            char* field_name;
        }

        _Names names;
    }

    _U u;
}

version(none) // Double declaration
struct WASMFunction {
    /* the type of function */
    WASMType* func_type;
    uint local_count;
    ubyte* local_types;
    /* cell num of parameters */
    ushort param_cell_num;
    /* cell num of return type */
    ushort ret_cell_num;
    /* cell num of local variables */
    ushort local_cell_num;
    /* offset of each local, including function parameters
       and local variables */
    ushort* local_offsets;
    uint max_stack_cell_num;
    uint max_block_num;
    uint code_size;
    ubyte* code;
    /* Whether function has opcode memory.grow */
    bool has_op_memory_grow;
    /* Whether function has opcode call or call_indirect */
    bool has_op_func_call;
    /* Whether function has memory operation opcodes */
    bool has_memory_operations;
    /* Whether function has opcode call_indirect */
    bool has_op_call_indirect;
    /* Whether function has opcode set_global_aux_stack */
    bool has_op_set_global_aux_stack;
    void* fast_jit_jitted_code;
}


struct WASMDataSeg {
    uint memory_index;
    InitializerExpression base_offset;
    uint data_length;
    ubyte* data;
}


struct StringNode {
    StringNode* next;
    char* str;
}

alias StringList = StringNode*;

struct AOTCompData;
struct AOTCompContext;
/* Orc JIT thread arguments */
struct OrcJitThreadArg {
    AOTCompContext* comp_ctx;
    WASMModule* module_;
    uint group_idx;
}
version(none) // Double declaration
struct WASMModule {
    /* Module type, for module loaded from WASM bytecode binary,
       this field is Wasm_Module_Bytecode;
       for module loaded from AOT file, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModule structure. */
    uint module_type;
    uint type_count;
    uint import_count;
    uint function_count;
    uint table_count;
    uint memory_count;
    uint global_count;
    uint export_count;
    uint table_seg_count;
    /* data seg count read from data segment section */
    uint data_seg_count;
    uint import_function_count;
    uint import_table_count;
    uint import_memory_count;
    uint import_global_count;
    WASMImport* import_functions;
    WASMImport* import_tables;
    WASMImport* import_memories;
    WASMImport* import_globals;
    WASMType** types;
    WASMImport* imports;
    WASMFunction** functions;
    WASMTable* tables;
    WASMMemory* memories;
    WASMGlobal* globals;
    WASMExport* exports;
    WASMTableSeg* table_segments;
    WASMDataSeg** data_segments;
    uint start_function;
    /* total global variable size */
    uint global_data_size;
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
    /* the index of malloc/free function,
       -1 means unexported */
    uint malloc_function;
    uint free_function;
    /* the index of __retain function,
       -1 means unexported */
    uint retain_function;
    /* Whether there is possible memory grow, e.g. memory.grow opcode */
    bool possible_memory_grow;
    StringList const_str_list;
    bh_list br_table_cache_list_head;
    bh_list* br_table_cache_list;
    ubyte* load_addr;
    ulong load_size;
    /* func pointers of Fast JITed (un-imported) functions */
    void** fast_jit_func_ptrs;
    /* locks for Fast JIT lazy compilation */
    korp_mutex[WASM_ORC_JIT_BACKEND_THREAD_NUM] fast_jit_thread_locks;
    bool[WASM_ORC_JIT_BACKEND_THREAD_NUM] fast_jit_thread_locks_inited;
    AOTCompData* comp_data;
    AOTCompContext* comp_ctx;
    /* func pointers of LLVM JITed (un-imported) functions */
    void** func_ptrs;
    /* whether the func pointers are compiled */
    bool* func_ptrs_compiled;
    /* backend compilation threads */
    korp_tid[WASM_ORC_JIT_BACKEND_THREAD_NUM] orcjit_threads;
    /* backend thread arguments */
    OrcJitThreadArg[WASM_ORC_JIT_BACKEND_THREAD_NUM] orcjit_thread_args;
    /* whether to stop the compilation of backend threads */
    bool orcjit_stop_compiling;
}


/* Execution environment, e.g. stack info */
/**
 * Align an unsigned value on a alignment boundary.
 *
 * @param v the value to be aligned
 * @param b the alignment boundary (2, 4, 8, ...)
 *
 * @return the aligned value
 */
pragma(inline, true) private uint align_uint(uint v, uint b) {
    uint m = b - 1;
    return (v + m) & ~m;
}
/**
 * Return the hash value of c string.
 */
pragma(inline, true) private uint wasm_string_hash(const(char)* str) {
    uint h = cast(uint) strlen(str);
    const(ubyte)* p = cast(ubyte*) str;
    const(ubyte)* end = p + h;
    while (p != end)
        h = ((h << 5) - h) + *p++;
    return h;
}
/**
 * Whether two c strings are equal.
 */
pragma(inline, true) private bool wasm_string_equal(const(char)* s1, const(char)* s2) {
    return strcmp(s1, s2) == 0 ? true : false;
}
/**
 * Return the byte size of value type.
 *
 */
pragma(inline, true) private uint wasm_value_type_size(ubyte value_type) {
    switch (value_type) {
    case 0x7F:
    case 0x7D:
        return int32.sizeof;
    case 0X7E:
    case 0x7C:
        return int64.sizeof;
    case 0x40:
        return 0;
    default:
        bh_assert(0);
    }
    return 0;
}

pragma(inline, true) private ushort wasm_value_type_cell_num(ubyte value_type) {
    return wasm_value_type_size(value_type) / 4;
}

pragma(inline, true) private uint wasm_get_cell_num(const(ubyte)* types, uint type_count) {
    uint cell_num = 0;
    uint i = void;
    for (i = 0; i < type_count; i++)
        cell_num += wasm_value_type_cell_num(types[i]);
    return cell_num;
}

pragma(inline, true) private bool wasm_type_equal(const(WASMType)* type1, const(WASMType)* type2) {
    if (type1 == type2) {
        return true;
    }
    return (type1.param_count == type2.param_count
            && type1.result_count == type2.result_count
            && memcmp(type1.types, type2.types,
                cast(uint)(type1.param_count + type1.result_count))
            == 0)
        ? true : false;
}

pragma(inline, true) private uint wasm_get_smallest_type_idx(WASMType** types, uint type_count, uint cur_type_idx) {
    uint i = void;
    for (i = 0; i < cur_type_idx; i++) {
        if (wasm_type_equal(types[cur_type_idx], types[i]))
        return i;
    }
    cast(void) type_count;
    return cur_type_idx;
}

pragma(inline, true) private uint block_type_get_param_types(BlockType* block_type, ubyte** p_param_types) {
    uint param_count = 0;
    if (!block_type.is_value_type) {
        WASMType* wasm_type = block_type.u.type;
        *p_param_types = wasm_type.types;
        param_count = wasm_type.param_count;
    }
    else {
        *p_param_types = null;
        param_count = 0;
    }
    return param_count;
}

pragma(inline, true) private uint block_type_get_result_types(BlockType* block_type, ubyte** p_result_types) {
    uint result_count = 0;
    if (block_type.is_value_type) {
        if (block_type.u.value_type != 0x40) {
            *p_result_types = &block_type.u.value_type;
            result_count = 1;
        }
    }
    else {
        WASMType* wasm_type = block_type.u.type;
        *p_result_types = wasm_type.types + wasm_type.param_count;
        result_count = wasm_type.result_count;
    }
    return result_count;
}
import tagion.iwasm.common.wasm_runtime_common;
import tagion.iwasm.common.wasm_exec_env;

/**
 * When LLVM JIT, WAMR compiler or AOT is enabled, we should ensure that
 * some offsets of the same field in the interpreter module instance and
 * aot module instance are the same, so that the LLVM JITed/AOTed code
 * can smoothly access the interpreter module instance.
 * Same for the memory instance and table instance.
 * We use the macro DefPointer to define some related pointer fields.
 */
/* Add u32 padding if LLVM JIT, WAMR compiler or AOT is enabled on
   32-bit platform */
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
    EXCE_FAILED_TO_COMPILE_FAST_JIT_FUNC,
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
}

alias MemBound = _MemBound;
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
    ubyte* memory_data;
    uint memory_data_padding;
    /* Memory data end address */
    ubyte* memory_data_end;
    uint memory_data_end_padding;
    /* Heap data base address */
    ubyte* heap_data;
    uint heap_data_padding;
    /* Heap data end address */
    ubyte* heap_data_end;
    uint heap_data_end_padding;
    /* The heap created */
    void* heap_handle;
    uint heap_handle_padding;
    MemBound mem_bound_check_1byte;
    MemBound mem_bound_check_2bytes;
    MemBound mem_bound_check_4bytes;
    MemBound mem_bound_check_8bytes;
    MemBound mem_bound_check_16bytes;
}

struct WASMTableInstance {
    /* Current size */
    uint cur_size;
    /* Maximum size */
    uint max_size;
    /* Table elements */
    uint[1] elems;
}

struct WASMGlobalInstance {
    /* value type, VALUE_TYPE_I32/I64/F32/F64 */
    ubyte type;
    /* mutable or constant */
    bool is_mutable;
    /* data offset to base_addr of WASMMemoryInstance */
    uint data_offset;
    /* initial value */
    WASMValue initial_value;
}

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
    ushort* local_offsets;
    /* parameter types */
    ubyte* param_types;
    /* local types, NULL for import function */
    ubyte* local_types;
    union _U {
        WASMFunctionImport* func_import;
        WASMFunction* func;
    }

    _U u;
}

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
}

struct AOTFuncPerfProfInfo;
struct WASMModuleInstance {
    /* Module instance type, for module instance loaded from
       WASM bytecode binary, this field is Wasm_Module_Bytecode;
       for module instance loaded from AOT file, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModuleInstance structure. */
    uint module_type;
    uint memory_count;
    WASMMemoryInstance** memories;
    uint memories_padding;
    /* global and table info */
    uint global_data_size;
    uint table_count;
    ubyte* global_data;
    uint global_data_padding;
    /* For AOTModuleInstance, it denotes `AOTTableInstance *` */
    WASMTableInstance** tables;
    uint tables_padding;
    /* import func ptrs + llvm jit func ptrs */
    void** func_ptrs;
    uint func_ptrs_padding;
    /* function type indexes */
    uint* func_type_indexes;
    uint func_type_indexes_padding;
    uint export_func_count;
    uint export_global_count;
    uint export_memory_count;
    uint export_table_count;
    /* For AOTModuleInstance, it denotes `AOTFunctionInstance *` */
    WASMExportFuncInstance* export_functions;
    uint export_functions_padding;
    WASMExportGlobInstance* export_globals;
    uint export_globals_padding;
    WASMExportMemInstance* export_memories;
    uint export_memories_padding;
    WASMExportTabInstance* export_tables;
    uint export_tables_padding;
    /* The exception buffer of wasm interpreter for current thread. */
    char[128] cur_exception = 0;
    /* The WASM module or AOT module, for AOTModuleInstance,
       it denotes `AOTModule *` */
    WASMModule* module_;
    uint module_padding;
    void* wasi_ctx;
    uint wasi_ctx_padding;
    WASMExecEnv* exec_env_singleton;
    uint exec_env_singleton_padding;
    /* Array of function pointers to import functions,
       not available in AOTModuleInstance */
    void** import_func_ptrs;
    uint import_func_ptrs_padding;
    /* Array of function pointers to fast jit functions,
       not available in AOTModuleInstance */
    void** fast_jit_func_ptrs;
    uint fast_jit_func_ptrs_padding;
    /* The custom data that can be set/get by wasm_{get|set}_custom_data */
    void* custom_data;
    uint custom_data_padding;
    /* Stack frames, used in call stack dump and perf profiling */
    Vector* frames;
    uint frames_padding;
    /* Function performance profiling info list, only available
       in AOTModuleInstance */
    AOTFuncPerfProfInfo* func_perf_profilings;
    uint func_perf_profilings_padding;
    /* WASM/AOT module extra info, for AOTModuleInstance,
       it denotes `AOTModuleInstanceExtra *` */
    WASMModuleInstanceExtra* e;
    uint e_padding;
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
    }

    _Global_table_data global_table_data;
}

alias WASMRuntimeFrame = WASMInterpFrame;
/**
 * Return the code block of a function.
 *
 * @param func the WASM function instance
 *
 * @return the code block of the function
 */
pragma(inline, true) private ubyte* wasm_get_func_code(WASMFunctionInstance* func) {
    return func.is_import_func ? null : func.u.func.code;
}
/**
 * Return the code block end of a function.
 *
 * @param func the WASM function instance
 *
 * @return the code block end of the function
 */
pragma(inline, true) private ubyte* wasm_get_func_code_end(WASMFunctionInstance* func) {
    return func.is_import_func ? null : func.u.func.code + func.u.func.code_size;
}

WASMModule* wasm_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size);
WASMModule* wasm_load_from_sections(WASMSection* section_list, char* error_buf, uint error_buf_size);
void wasm_unload(WASMModule* module_);
WASMModuleInstance* wasm_instantiate(WASMModule* module_, bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size);
void wasm_dump_perf_profiling(const(WASMModuleInstance)* module_inst);
void wasm_deinstantiate(WASMModuleInstance* module_inst, bool is_sub_inst);
WASMFunctionInstance* wasm_lookup_function(const(WASMModuleInstance)* module_inst, const(char)* name, const(char)* signature);
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
void wasm_get_module_mem_consumption(const(WASMModule)* module_, WASMModuleMemConsumption* mem_conspn);
void wasm_get_module_inst_mem_consumption(const(WASMModuleInstance)* module_, WASMModuleInstMemConsumption* mem_conspn);
pragma(inline, true) private WASMTableInstance* wasm_get_table_inst(const(WASMModuleInstance)* module_inst, uint tbl_idx) {
    /* careful, it might be a table in another module */
    WASMTableInstance* tbl_inst = module_inst.tables[tbl_idx];
    bh_assert(tbl_inst);
    return tbl_inst;
}

const(ubyte)* wasm_loader_get_custom_section(WASMModule* module_, const(char)* name, uint* len);
/**
 * Check whether the app address and the buf is inside the linear memory,
 * and convert the app address into native address
 */
bool jit_check_app_addr_and_convert(WASMModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr);
bool fast_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint type_idx, uint argc, uint* argv);
bool fast_jit_invoke_native(WASMExecEnv* exec_env, uint func_idx, WASMInterpFrame* prev_frame);
bool llvm_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv);
bool llvm_jit_invoke_native(WASMExecEnv* exec_env, uint func_idx, uint argc, uint* argv);
import tagion.iwasm.interpreter.wasm_loader;
import tagion.iwasm.interpreter.wasm_interp;
import tagion.iwasm.share.utils.bh_common;
import tagion.iwasm.share.utils.bh_log;
import tagion.iwasm.share.mem_alloc.mem_alloc;
import tagion.iwasm.common.wasm_runtime_common;
import tagion.iwasm.fast_jit.jit_compiler;
import tagion.iwasm.aot.aot_runtime;
private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null) {
        snprintf(error_buf, error_buf_size,
                "WASM module instantiate failed: %s", string);
    }
}

private void set_error_buf_v(char* error_buf, uint error_buf_size, const(char)* format_, ...) {
    va_list args = void;
    char[128] buf = void;
    if (error_buf != null) {
        va_start(args, format_);
        vsnprintf(buf.ptr, buf.sizeof, format_, args);
        va_end(args);
        snprintf(error_buf, error_buf_size,
                "WASM module instantiate failed: %s", buf.ptr);
    }
}

WASMModule* wasm_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size) {
    return wasm_loader_load(buf, size,
            (ver.WASM_ENABLE_MULTI_MODULE),
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
    if (size >= UINT32_MAX || ((mem = wasm_runtime_malloc(cast(uint) size)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return null;
    }
    memset(mem, 0, cast(uint) size);
    return mem;
}

static if (ver.WASM_ENABLE_MULTI_MODULE) {
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
                static if (ver.WASM_ENABLE_MULTI_MODULE) {
                    WASMModule* module_ = module_inst.module_;
                    if (i < module_.import_memory_count
                            && module_.import_memories[i].u.memory.import_module) {
                        continue;
                    }
                }
                static if (ver.WASM_ENABLE_SHARED_MEMORY) {
                    if (memories[i].is_shared) {
                        int ref_count = shared_memory_dec_reference(
                                cast(WASMModuleCommon*) module_inst.module_);
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
                    version (OS_ENABLE_HW_BOUND_CHECK) {
                    }
                    else {
                        wasm_runtime_free(memories[i].memory_data);
                    }
                    version (OS_ENABLE_HW_BOUND_CHECK) {
                        version (BH_PLATFORM_WINDOWS) {
                            os_mem_decommit(memories[i].memory_data,
                            memories[i].num_bytes_per_page
                                * memories[i].cur_page_count);
                        }
                        os_munmap(cast(ubyte*) memories[i].memory_data,
                        8 * cast(ulong) BH_GB);
                    }
                }
            }
        }
        wasm_runtime_free(memories);
    }
    cast(void) module_inst;
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
        ulong map_size = 8 * cast(ulong) BH_GB;
        ulong page_size = os_getpagesize();
    }

    static if (ver.WASM_ENABLE_SHARED_MEMORY) {
        bool is_shared_memory = flags & 0x02 ? true : false;

        /* shared memory */
        if (is_shared_memory) {
            WASMSharedMemNode* node = wasm_module_get_shared_memory(
                    cast(WASMModuleCommon*) module_inst.module_);
            /* If the memory of this module has been instantiated,
            return the memory instance directly */
            if (node) {
                uint ref_count = void;
                ref_count = shared_memory_inc_reference(
                        cast(WASMModuleCommon*) module_inst.module_);
                bh_assert(ref_count > 0);
                memory = cast(WASMMemoryInstance*) shared_memory_get_memory_inst(node);
                bh_assert(memory);

                cast(void) ref_count;
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
            *cast(uint*) global_addr = aux_heap_base;
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
    memory_data_size = cast(ulong) num_bytes_per_page * init_page_count;
    static if (ver.WASM_ENABLE_SHARED_MEMORY) {
        if (is_shared_memory) {
            /* Allocate max page for shared memory */
            memory_data_size = cast(ulong) num_bytes_per_page * max_page_count;
        }
    }
    bh_assert(memory_data_size <= 4 * cast(ulong) BH_GB);
    bh_assert(memory != null);
    version (OS_ENABLE_HW_BOUND_CHECK) {
    }
    else {
        if (memory_data_size > 0
                && ((memory.memory_data =
                    runtime_malloc(memory_data_size, error_buf, error_buf_size)) == 0)) {
            goto fail1;
        }
    }
    version (OS_ENABLE_HW_BOUND_CHECK) {
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
        memory_data_size = cast(uint) memory_data_size;
    memory.module_type = Wasm_Module_Bytecode;
    memory.num_bytes_per_page = num_bytes_per_page;
    memory.cur_page_count = init_page_count;
    memory.max_page_count = max_page_count;
    memory.memory_data_size = cast(uint) memory_data_size;
    memory.heap_data = memory.memory_data + heap_offset;
    memory.heap_data_end = memory.heap_data + heap_size;
    memory.memory_data_end = memory.memory_data + cast(uint) memory_data_size;
    /* Initialize heap */
    if (heap_size > 0) {
        uint heap_struct_size = mem_allocator_get_heap_struct_size();
        if (((memory.heap_handle = runtime_malloc(
                cast(ulong) heap_struct_size, error_buf, error_buf_size)) == 0)) {
            goto fail2;
        }
        if (!mem_allocator_create_with_struct_and_pool(
                memory.heap_handle, heap_struct_size, memory.heap_data,
                heap_size)) {
            set_error_buf(error_buf, error_buf_size, "init app heap failed");
            goto fail3;
        }
    }

    static if (ver.WASM_ENABLE_FAST_JIT || ver.WASM_ENABLE_JIT) {
        if (memory_data_size > 0) {
            static if (UINTPTR_MAX == UINT64_MAX) {
                memory.mem_bound_check_1byte.u64 = memory_data_size - 1;
                memory.mem_bound_check_2bytes.u64 = memory_data_size - 2;
                memory.mem_bound_check_4bytes.u64 = memory_data_size - 4;
                memory.mem_bound_check_8bytes.u64 = memory_data_size - 8;
                memory.mem_bound_check_16bytes.u64 = memory_data_size - 16;
            }
            else {
                memory.mem_bound_check_1byte.u32[0] = cast(uint) memory_data_size - 1;
                memory.mem_bound_check_2bytes.u32[0] = cast(uint) memory_data_size - 2;
                memory.mem_bound_check_4bytes.u32[0] = cast(uint) memory_data_size - 4;
                memory.mem_bound_check_8bytes.u32[0] = cast(uint) memory_data_size - 8;
                memory.mem_bound_check_16bytes.u32[0] = cast(uint) memory_data_size - 16;
            }
        }
    }

    static if (ver.WASM_ENABLE_SHARED_MEMORY) {
        if (is_shared_memory) {
            memory.is_shared = true;
            if (!shared_memory_set_memory_inst(
                    cast(WASMModuleCommon*) module_inst.module_,
                    cast(WASMMemoryInstanceCommon*) memory)) {
                set_error_buf(error_buf, error_buf_size, "allocate memory failed");
                goto fail4;
            }
        }
    }

    LOG_VERBOSE("Memory instantiate success.");
    return memory;

    static if (ver.WASM_ENABLE_SHARED_MEMORY) {
    fail4:
        if (heap_size > 0)
            mem_allocator_destroy(memory.heap_handle);
    }
fail3:
    if (heap_size > 0)
        wasm_runtime_free(memory.heap_handle);
fail2:
    version (OS_ENABLE_HW_BOUND_CHECK) {
    }
    else {
        if (memory.memory_data)
            wasm_runtime_free(memory.memory_data);
    }
    version (OS_ENABLE_HW_BOUND_CHECK) {
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
    WASMMemoryInstance** memories = void;
    WASMMemoryInstance* memory = void;
    total_size = (WASMMemoryInstance*).sizeof * cast(ulong) memory_count;
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

        if ((ver.WASM_ENABLE_MULTI_MODULE) && (import_.u.memory.import_module != null)) {
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
        else {
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
    cast(void) module_inst;
    return memories;
}
/**
 * Destroy table instances.
 */
private void tables_deinstantiate(WASMModuleInstance* module_inst) {
    if (module_inst.tables) {
        wasm_runtime_free(module_inst.tables);
    }
    static if (ver.WASM_ENABLE_MULTI_MODULE) {
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
    WASMTableInstance** tables = void;
    WASMTableInstance* table = first_table;
    static if (ver.WASM_ENABLE_MULTI_MODULE) {
        ulong total_size_of_tables_linked = cast(ulong)(WASMTableInstance*).sizeof * module_.import_table_count;
        WASMTableInstance** table_linked = null;
    }

    if (((tables = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }

    static if (ver.WASM_ENABLE_MULTI_MODULE) {
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
        static if (ver.WASM_ENABLE_MULTI_MODULE) {
            WASMTableInstance* table_inst_linked = null;
            WASMModuleInstance* module_inst_linked = null;
        }
        if ((ver.WASM_ENABLE_MULTI_MODULE) && import_.u.table.import_module) {
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
        else {
            /* in order to save memory, alloc resource as few as possible */
            max_size_fixed = import_.u.table.possible_grow
                ? import_.u.table.max_size : import_.u.table.init_size;
            /* it is a built-in table, every module has its own */
            total_size = WASMTableInstance.elems.offsetof;
            total_size += cast(ulong) max_size_fixed * uint32.sizeof;
        }
        tables[table_index++] = table;
        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, cast(uint) total_size);

        static if (ver.WASM_ENABLE_MULTI_MODULE) {
            *table_linked = table_inst_linked;
        }
        if ((ver.WASM_ENABLE_MULTI_MODULE) && table_inst_linked != null) {
            table.cur_size = table_inst_linked.cur_size;
            table.max_size = table_inst_linked.max_size;
        }
        else {
            table.cur_size = import_.u.table.init_size;
            table.max_size = max_size_fixed;
        }
        table = cast(WASMTableInstance*)(cast(ubyte*) table + cast(uint) total_size);
        static if (ver.WASM_ENABLE_MULTI_MODULE) {
            table_linked++;
        }
    }
    /* instantiate tables from table section */
    for (i = 0; i < module_.table_count; i++) {
        uint max_size_fixed = 0;
        total_size = WASMTableInstance.elems.offsetof;
        static if (ver.WASM_ENABLE_MULTI_MODULE) {
            /* in case, a module which imports this table will grow it */
            max_size_fixed = module_.tables[i].max_size;
        }
        else {
            max_size_fixed = module_.tables[i].possible_grow
                ? module_.tables[i].max_size : module_.tables[i].init_size;
        }
        total_size += uint.sizeof * cast(ulong) max_size_fixed;

        tables[table_index++] = table;
        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, cast(uint) total_size);
        table.cur_size = module_.tables[i].init_size;
        table.max_size = max_size_fixed;
        table = cast(WASMTableInstance*)(cast(ubyte*) table + cast(uint) total_size);
    }
    bh_assert(table_index == table_count);
    cast(void) module_inst;
    return tables;
    static if (ver.WASM_ENABLE_MULTI_MODULE) {
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
    ulong total_size = sizeof(WASMFunctionInstance) * cast(ulong) function_count;
    WASMFunctionInstance* functions = void, function_ = void;
    if (((functions = runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }
    total_size = (void*).sizeof * cast(ulong) module_.import_function_count;
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

        static if (ver.WASM_ENABLE_MULTI_MODULE) {
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
            cast(ushort) function_.u.func_import.func_type.param_count;
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
            cast(ushort) function_.u.func.func_type.param_count;
        function_.local_count = cast(ushort) function_.u.func.local_count;
        function_.param_types = function_.u.func.func_type.types;
        function_.local_types = function_.u.func.local_types;
        function_.local_offsets = function_.u.func.local_offsets;

        static if (ver.WASM_ENABLE_FAST_INTERP) {
            function_.const_cell_num = function_.u.func.const_cell_num;
        }

        function_++;
    }
    module_inst.fast_jit_func_ptrs = module_.fast_jit_func_ptrs;
    bh_assert(cast(uint)(function_ - functions) == function_count);
    cast(void) module_inst;
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
    ulong total_size = sizeof(WASMGlobalInstance) * cast(ulong) global_count;
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
        if ((ver.WASM_ENABLE_MULTI_MODULE) && global_import.import_module) {
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
        else {
            /* native globals share their initial_values in one module */
            bh_memcpy_s(&(global.initial_value), WASMValue.sizeof,
                    &(global_import.global_data_linked),
                    WASMValue.sizeof);
        }
        bh_assert(global_data_offset == global_import.data_offset);
        global.data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global.type);
        global++;
    }
    /* instantiate globals from global section */
    for (i = 0; i < module_.global_count; i++) {
        InitializerExpression* init_expr = &(module_.globals[i].init_expr);
        global.type = module_.globals[i].type;
        global.is_mutable = module_.globals[i].is_mutable;
        bh_assert(global_data_offset == module_.globals[i].data_offset);
        global.data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global.type);
        if (init_expr.init_expr_type == 0x23) {
            if (!check_global_init_expr(module_, init_expr.u.global_index,
                    error_buf, error_buf_size)) {
                goto fail;
            }
            bh_memcpy_s(
                    &(global.initial_value), WASMValue.sizeof,
                    &(globals[init_expr.u.global_index].initial_value),
            typeof(globals[init_expr.u.global_index].initial_value).sizeof);
        }
        else {
            bh_memcpy_s(&(global.initial_value), WASMValue.sizeof,
                    &(init_expr.u), typeof(init_expr.u).sizeof);
        }
        global++;
    }
    bh_assert(cast(uint)(global - globals) == global_count);
    bh_assert(global_data_offset == module_.global_data_size);
    cast(void) module_inst;
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
    for (i = 0; i < module_.export_count; i++, export_++)
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
    ulong total_size = sizeof(WASMExportFuncInstance) * cast(ulong) export_func_count;
    if (((export_func = export_funcs =
            runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return null;
    }
    for (i = 0; i < module_.export_count; i++, export_++)
        if (export_.kind == 0) {
            export_func.name = export_.name;
            export_func.function_ = &module_inst.e.functions[export_.index];
            export_func++;
        }
    bh_assert(cast(uint)(export_func - export_funcs) == export_func_count);
    return export_funcs;
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
    if (!post_inst_func) /* Not found */
        return true;
    post_inst_func_type = post_inst_func.u.func.func_type;
    if (post_inst_func_type.param_count != 0
            || post_inst_func_type.result_count != 0) /* Not a valid function type, ignore it */
        return true;
    return wasm_create_exec_env_and_call_function(module_inst, post_inst_func,
            0, null);
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
    uint[2] argv = void;
    uint argc = void;
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
    uint[2] argv = void;
    argv[0] = offset;
    {
        return wasm_create_exec_env_and_call_function(module_inst, free_func, 1,
                argv.ptr);
    }
}

private bool check_linked_symbol(WASMModuleInstance* module_inst, char* error_buf, uint error_buf_size) {
    WASMModule* module_ = module_inst.module_;
    uint i = void;
    for (i = 0; i < module_.import_function_count; i++) {
        WASMFunctionImport* func = &((module_.import_functions + i).u.function_);
        if (!func.func_ptr_linked
            ) {
            LOG_WARNING("warning: failed to link import function (%s, %s)",
                    func.module_name, func.field_name);
        }
    }
    for (i = 0; i < module_.import_global_count; i++) {
        WASMGlobalImport* global = &((module_.import_globals + i).u.global);
        if (!global.is_linked) {
            LOG_DEBUG("warning: failed to link import global (%s, %s)",
                    global.module_name, global.field_name);
        }
    }
    return true;
}

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
    ulong total_size = cast(ulong) uint.sizeof * module_inst.e.function_count;
    /* Allocate memory */
    if (((module_inst.func_type_indexes =
            runtime_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }
    for (i = 0; i < module_inst.e.function_count; i++) {
        WASMFunctionInstance* func_inst = module_inst.e.functions + i;
        WASMType* func_type = func_inst.is_import_func
            ? func_inst.u.func_import.func_type : func_inst.u.func.func_type;
        module_inst.func_type_indexes[i] =
            get_smallest_type_idx(module_inst.module_, func_type);
    }
    return true;
}
/**
 * Instantiate module
 */
WASMModuleInstance* wasm_instantiate(WASMModule* module_, bool is_sub_inst, uint stack_size, uint heap_size, char* error_buf, uint error_buf_size) {
    WASMModuleInstance* module_inst = void;
    WASMGlobalInstance* globals = null, global = void;
    WASMTableInstance* first_table = void;
    uint global_count = void, i = void;
    uint base_offset = void, length = void, extra_info_offset = void;
    uint module_inst_struct_size = offsetof(WASMModuleInstance, global_table_data.bytes);
    ulong module_inst_mem_inst_size = void;
    ulong total_size = void, table_size = 0;
    ubyte* global_data = void, global_data_end = void;
    if (!module_)
        return null;
    /* Check the heap size */
    heap_size = align_uint(heap_size, 8);
    if (heap_size > APP_HEAP_SIZE_MAX)
        heap_size = APP_HEAP_SIZE_MAX;
    module_inst_mem_inst_size =
        cast(ulong) sizeof(WASMMemoryInstance)
        * (module_.import_memory_count + module_.memory_count);
    /* If the module dosen't have memory, reserve one mem_info space
       with empty content to align with llvm jit compiler */
    if (module_inst_mem_inst_size == 0)
        module_inst_mem_inst_size = cast(ulong) WASMMemoryInstance.sizeof;
    /* Size of module inst, memory instances and global data */
    total_size = cast(ulong) module_inst_struct_size + module_inst_mem_inst_size
        + module_.global_data_size;
    /* Calculate the size of table data */
    for (i = 0; i < module_.import_table_count; i++) {
        WASMTableImport* import_table = &module_.import_tables[i].u.table;
        table_size += WASMTableInstance.elems.offsetof;
        table_size += cast(ulong) uint.sizeof
            * (import_table.possible_grow ? import_table.max_size : import_table.init_size);
    }
    for (i = 0; i < module_.table_count; i++) {
        WASMTable* table = module_.tables + i;
        table_size += WASMTableInstance.elems.offsetof;
        table_size +=
            cast(ulong) uint.sizeof
            * (table.possible_grow ? table.max_size : table.init_size);
    }
    total_size += table_size;
    /* The offset of WASMModuleInstanceExtra, make it 8-byte aligned */
    total_size = (total_size + 7L) &  ~ 7L;
    extra_info_offset = cast(uint) total_size;
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
        cast(WASMModuleInstanceExtra*)(cast(ubyte*) module_inst + extra_info_offset);
    /* Instantiate global firstly to get the mutable data size */
    global_count = module_.import_global_count + module_.global_count;
    if (global_count
            && ((globals = globals_instantiate(module_, module_inst, error_buf,
                error_buf_size)) == 0)) {
        goto fail;
    }
    module_inst.e.global_count = global_count;
    module_inst.e.globals = globals;
    module_inst.global_data = cast(ubyte*) module_inst + module_inst_struct_size
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
    module_inst.export_func_count = get_export_count(module_, 0);
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
            || (module_inst.e.function_count > 0
                && !init_func_ptrs(module_inst, module_, error_buf, error_buf_size))
            || (module_inst.e.function_count > 0
                && !init_func_type_indexes(module_inst, error_buf, error_buf_size))
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
            case 0x7F:
            case 0x7D:
                *cast(int*) global_data = global.initial_value.i32;
                global_data += int32.sizeof;
                break;
            case 0X7E:
            case 0x7C:
                bh_memcpy_s(global_data,
                        cast(uint)(global_data_end - global_data),
                        &global.initial_value.i64, int64.sizeof);
                global_data += int64.sizeof;
                break;
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
        /* has check it in loader */
        memory = module_inst.memories[data_seg.memory_index];
        bh_assert(memory);
        memory_data = memory.memory_data;
        memory_size = memory.num_bytes_per_page * memory.cur_page_count;
        bh_assert(memory_data || memory_size == 0);
        bh_assert(data_seg.base_offset.init_expr_type
                == 0x41
                || data_seg.base_offset.init_expr_type
                == 0x23);
        if (data_seg.base_offset.init_expr_type == 0x23) {
            if (!check_global_init_expr(module_,
                    data_seg.base_offset.u.global_index,
                    error_buf, error_buf_size)) {
                goto fail;
            }
            if (!globals
                    || globals[data_seg.base_offset.u.global_index].type
                    != 0x7F) {
                set_error_buf(error_buf, error_buf_size,
                        "data segment does not fit");
                goto fail;
            }
            base_offset =
                globals[data_seg.base_offset.u.global_index].initial_value.i32;
        }
        else {
            base_offset = cast(uint) data_seg.base_offset.u.i32;
        }
        /* check offset */
        if (base_offset > memory_size) {
            LOG_DEBUG("base_offset(%d) > memory_size(%d)", base_offset,
                    memory_size);
            set_error_buf(error_buf, error_buf_size,
                    "data segment does not fit");
            goto fail;
        }
        /* check offset + length(could be zero) */
        length = data_seg.data_length;
        if (base_offset + length > memory_size) {
            LOG_DEBUG("base_offset(%d) + length(%d) > memory_size(%d)",
                    base_offset, length, memory_size);
            set_error_buf(error_buf, error_buf_size,
                    "data segment does not fit");
            goto fail;
        }
        if (memory_data) {
            bh_memcpy_s(memory_data + base_offset, memory_size - base_offset,
                    data_seg.data, length);
        }
    }
    /* Initialize the table data with table segment section */
    for (i = 0; module_inst.table_count > 0 && i < module_.table_seg_count; i++) {
        WASMTableSeg* table_seg = module_.table_segments + i;
        /* has check it in loader */
        WASMTableInstance* table = module_inst.tables[table_seg.table_index];
        uint* table_data = void;
        bh_assert(table);
        table_data = table.elems;
        bh_assert(table_data);
        bh_assert(table_seg.base_offset.init_expr_type
                == 0x41
                || table_seg.base_offset.init_expr_type
                == 0x23);
        /* init vec(funcidx) or vec(expr) */
        if (table_seg.base_offset.init_expr_type
                == 0x23) {
            if (!check_global_init_expr(module_,
                    table_seg.base_offset.u.global_index,
                    error_buf, error_buf_size)) {
                goto fail;
            }
            if (!globals
                    || globals[table_seg.base_offset.u.global_index].type
                    != 0x7F) {
                set_error_buf(error_buf, error_buf_size,
                        "elements segment does not fit");
                goto fail;
            }
            table_seg.base_offset.u.i32 =
                globals[table_seg.base_offset.u.global_index]
                    .initial_value.i32;
        }
        /* check offset since length might negative */
        if (cast(uint) table_seg.base_offset.u.i32 > table.cur_size) {
            LOG_DEBUG("base_offset(%d) > table->cur_size(%d)",
                    table_seg.base_offset.u.i32, table.cur_size);
            set_error_buf(error_buf, error_buf_size,
                    "elements segment does not fit");
            goto fail;
        }
        /* check offset + length(could be zero) */
        length = table_seg.function_count;
        if (cast(uint) table_seg.base_offset.u.i32 + length > table.cur_size) {
            LOG_DEBUG("base_offset(%d) + length(%d)> table->cur_size(%d)",
                    table_seg.base_offset.u.i32, length, table.cur_size);
            set_error_buf(error_buf, error_buf_size,
                    "elements segment does not fit");
            goto fail;
        }
        /**
         * Check function index in the current module inst for now.
         * will check the linked table inst owner in future.
         * so loader check is enough
         */
        bh_memcpy_s(
                table_data + table_seg.base_offset.u.i32,
                cast(uint)((table.cur_size - cast(uint) table_seg.base_offset.u.i32)
                * uint32.sizeof),
                table_seg.func_indexes, cast(uint)(length * uint32.sizeof));
    }
    /* Initialize the thread related data */
    if (stack_size == 0)
        stack_size = DEFAULT_WASM_STACK_SIZE;
    module_inst.default_wasm_stack_size = stack_size;
    if (module_.malloc_function != cast(uint) - 1) {
        module_inst.e.malloc_function =
            &module_inst.e.functions[module_.malloc_function];
    }
    if (module_.free_function != cast(uint) - 1) {
        module_inst.e.free_function =
            &module_inst.e.functions[module_.free_function];
    }
    if (module_.retain_function != cast(uint) - 1) {
        module_inst.e.retain_function =
            &module_inst.e.functions[module_.retain_function];
    }
    if (module_.start_function != cast(uint) - 1) {
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
    cast(void) global_data_end;
    return module_inst;
fail:
    wasm_deinstantiate(module_inst, false);
    return null;
}

void wasm_deinstantiate(WASMModuleInstance* module_inst, bool is_sub_inst) {
    if (!module_inst)
        return;
    if (module_inst.func_ptrs)
        wasm_runtime_free(module_inst.func_ptrs);
    if (module_inst.func_type_indexes)
        wasm_runtime_free(module_inst.func_type_indexes);
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
    if (module_inst.exec_env_singleton)
        wasm_exec_env_destroy(module_inst.exec_env_singleton);
    if (module_inst.e.c_api_func_imports)
        wasm_runtime_free(module_inst.e.c_api_func_imports);
    wasm_runtime_free(module_inst);
}

WASMFunctionInstance* wasm_lookup_function(const(WASMModuleInstance)* module_inst, const(char)* name, const(char)* signature) {
    uint i = void;
    for (i = 0; i < module_inst.export_func_count; i++)
        if (!strcmp(module_inst.export_functions[i].name, name))
    return module_inst.export_functions[i].function_;
    cast(void) signature;
    return null;
}

private bool clear_wasi_proc_exit_exception(WASMModuleInstance* module_inst) {
    return false;
}

bool wasm_call_function(WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*) exec_env.module_inst;
    /* set thread handle and stack boundary */
    wasm_exec_env_set_thread_info(exec_env);
    wasm_interp_call_wasm(module_inst, exec_env, function_, argc, argv);
    cast(void) clear_wasi_proc_exit_exception(module_inst);
    return !wasm_get_exception(module_inst) ? true : false;
}

bool wasm_create_exec_env_and_call_function(WASMModuleInstance* module_inst, WASMFunctionInstance* func, uint argc, uint* argv) {
    WASMExecEnv* exec_env = null, existing_exec_env = null;
    bool ret = void;
    if (!existing_exec_env) {
        if (((exec_env =
                wasm_exec_env_create(cast(WASMModuleInstanceCommon*) module_inst,
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
                cast(WASMModuleInstanceCommon*) module_inst, buffer_offset);
        bh_memcpy_s(buffer, size, src, size);
    }
    return buffer_offset;
}

private bool call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv, bool check_type_idx, uint type_idx) {
    WASMModuleInstance* module_inst = null;
    WASMTableInstance* table_inst = null;
    uint func_idx = 0;
    WASMFunctionInstance* func_inst = null;
    module_inst = cast(WASMModuleInstance*) exec_env.module_inst;
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
    if (func_idx == (0xFFFFFFFF)) {
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
    wasm_interp_call_wasm(module_inst, exec_env, func_inst, argc, argv);
    cast(void) clear_wasi_proc_exit_exception(module_inst);
    return !wasm_get_exception(module_inst) ? true : false;
got_exception:
    return false;
}

bool wasm_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv) {
    return call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, false, 0);
}

void jit_set_exception_with_id(WASMModuleInstance* module_inst, uint id) {
    if (id != EXCE_ALREADY_THROWN)
        wasm_set_exception_with_id(module_inst, id);
}

bool jit_check_app_addr_and_convert(WASMModuleInstance* module_inst, bool is_str, uint app_buf_addr, uint app_buf_size, void** p_native_addr) {
    bool ret = wasm_check_app_addr_and_convert(
            module_inst, is_str, app_buf_addr, app_buf_size, p_native_addr);
    return ret;
}

bool fast_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint type_idx, uint argc, uint* argv) {
    return call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, true,
            type_idx);
}

bool llvm_jit_call_indirect(WASMExecEnv* exec_env, uint tbl_idx, uint elem_idx, uint argc, uint* argv) {
    bool ret = void;
    if (Wasm_Module_AoT == exec_env.module_inst.module_type) {
        return aot_call_indirect(exec_env, tbl_idx, elem_idx, argc, argv);
    }
    ret = call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, false, 0);
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
    if (Wasm_Module_AoT == exec_env.module_inst.module_type) {
        return aot_invoke_native(exec_env, func_idx, argc, argv);
    }
    module_inst = cast(WASMModuleInstance*) wasm_runtime_get_module_inst(exec_env);
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
                cast(WASMModuleInstanceCommon*) module_inst, func_ptr, func_type, argc,
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
    return ret;
}
