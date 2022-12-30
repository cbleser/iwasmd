module wasm;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.share.utils.bh_hashmap;
public import tagion.iwasm.share.utils.bh_assert;


/** Value Type */
enum VALUE_TYPE_I32 = 0x7F;
enum VALUE_TYPE_I64 = 0X7E;
enum VALUE_TYPE_F32 = 0x7D;
enum VALUE_TYPE_F64 = 0x7C;
enum VALUE_TYPE_V128 = 0x7B;
enum VALUE_TYPE_FUNCREF = 0x70;
enum VALUE_TYPE_EXTERNREF = 0x6F;
enum VALUE_TYPE_VOID = 0x40;
/* Used by AOT */
enum VALUE_TYPE_I1 = 0x41;
/*  Used by loader to represent any type of i32/i64/f32/f64 */
enum VALUE_TYPE_ANY = 0x42;

enum DEFAULT_NUM_BYTES_PER_PAGE = 65536;
enum DEFAULT_MAX_PAGES = 65536;

enum NULL_REF = (0xFFFFFFFF);

enum TABLE_MAX_SIZE = (1024);

enum INIT_EXPR_TYPE_I32_CONST = 0x41;
enum INIT_EXPR_TYPE_I64_CONST = 0x42;
enum INIT_EXPR_TYPE_F32_CONST = 0x43;
enum INIT_EXPR_TYPE_F64_CONST = 0x44;
enum INIT_EXPR_TYPE_V128_CONST = 0xFD;
/* = WASM_OP_REF_FUNC */
enum INIT_EXPR_TYPE_FUNCREF_CONST = 0xD2;
/* = WASM_OP_REF_NULL */
enum INIT_EXPR_TYPE_REFNULL_CONST = 0xD0;
enum INIT_EXPR_TYPE_GET_GLOBAL = 0x23;
enum INIT_EXPR_TYPE_ERROR = 0xff;

enum WASM_MAGIC_NUMBER = 0x6d736100;
enum WASM_CURRENT_VERSION = 1;

enum SECTION_TYPE_USER = 0;
enum SECTION_TYPE_TYPE = 1;
enum SECTION_TYPE_IMPORT = 2;
enum SECTION_TYPE_FUNC = 3;
enum SECTION_TYPE_TABLE = 4;
enum SECTION_TYPE_MEMORY = 5;
enum SECTION_TYPE_GLOBAL = 6;
enum SECTION_TYPE_EXPORT = 7;
enum SECTION_TYPE_START = 8;
enum SECTION_TYPE_ELEM = 9;
enum SECTION_TYPE_CODE = 10;
enum SECTION_TYPE_DATA = 11;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
enum SECTION_TYPE_DATACOUNT = 12;
}

enum SUB_SECTION_TYPE_MODULE = 0;
enum SUB_SECTION_TYPE_FUNC = 1;
enum SUB_SECTION_TYPE_LOCAL = 2;

enum IMPORT_KIND_FUNC = 0;
enum IMPORT_KIND_TABLE = 1;
enum IMPORT_KIND_MEMORY = 2;
enum IMPORT_KIND_GLOBAL = 3;

enum EXPORT_KIND_FUNC = 0;
enum EXPORT_KIND_TABLE = 1;
enum EXPORT_KIND_MEMORY = 2;
enum EXPORT_KIND_GLOBAL = 3;

enum LABEL_TYPE_BLOCK = 0;
enum LABEL_TYPE_LOOP = 1;
enum LABEL_TYPE_IF = 2;
enum LABEL_TYPE_FUNCTION = 3;





union V128 {
    byte[16] i8x16;
    short[8] i16x8;
    int[4] i32x8;
    long[2] i64x2;
    float32[4] f32x4;
    float64[2] f64x2;
}

union WASMValue {
    int i32;
    uint u32;
    uint global_index;
    uint ref_index;
    long i64;
    ulong u64;
    float32 f32;
    float64 f64;
    uintptr_t addr;
    V128 v128;
}

struct InitializerExpression {
    /* type of INIT_EXPR_TYPE_XXX */
    /* it actually is instr, in some places, requires constant only */
    ubyte init_expr_type;
    WASMValue u;
}

struct WASMType {
    ushort param_count;
    ushort result_count;
    ushort param_cell_num;
    ushort ret_cell_num;
    ushort ref_count;
static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 
    && WASM_ENABLE_LAZY_JIT != 0) {
    /* Code block to call llvm jit functions of this
       kind of function type from fast jit jitted code */
    void* call_to_llvm_jit_from_fast_jit;
}
    /* types of params and results */
    ubyte[1] types;
}

struct WASMTable {
    ubyte elem_type;
    uint flags;
    uint init_size;
    /* specified if (flags & 1), else it is 0x10000 */
    uint max_size;
    bool possible_grow;
}

struct WASMMemory {
    uint flags;
    uint num_bytes_per_page;
    uint init_page_count;
    uint max_page_count;
}

struct WASMTableImport {
    char* module_name;
    char* field_name;
    ubyte elem_type;
    uint flags;
    uint init_size;
    /* specified if (flags & 1), else it is 0x10000 */
    uint max_size;
    bool possible_grow;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    WASMModule* import_module;
    WASMTable* import_table_linked;
}
}

struct WASMMemoryImport {
    char* module_name;
    char* field_name;
    uint flags;
    uint num_bytes_per_page;
    uint init_page_count;
    uint max_page_count;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    WASMModule* import_module;
    WASMMemory* import_memory_linked;
}
}

struct WASMFunctionImport {
    char* module_name;
    char* field_name;
    /* function type */
    WASMType* func_type;
    /* native function pointer after linked */
    void* func_ptr_linked;
    /* signature from registered native symbols */
    const(char)* signature;
    /* attachment */
    void* attachment;
    bool call_conv_raw;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    WASMModule* import_module;
    WASMFunction* import_func_linked;
}
    bool call_conv_wasm_c_api;
}

struct WASMGlobalImport {
    char* module_name;
    char* field_name;
    ubyte type;
    bool is_mutable;
    /* global data after linked */
    WASMValue global_data_linked;
    bool is_linked;
static if (WASM_ENABLE_MULTI_MODULE != 0) {
    /* imported function pointer after linked */
    /* TODO: remove if not needed */
    WASMModule* import_module;
    WASMGlobal* import_global_linked;
}
static if (WASM_ENABLE_FAST_JIT != 0) {
    /* The data offset of current global in global data */
    uint data_offset;
}
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
        }_Names names;
    }_U u;
}

struct WASMFunction {
static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    char* field_name;
}
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
static if (WASM_ENABLE_FAST_INTERP != 0) {
    uint code_compiled_size;
    ubyte* code_compiled;
    ubyte* consts;
    uint const_cell_num;
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 
    || WASM_ENABLE_WAMR_COMPILER != 0) {
    /* Whether function has opcode memory.grow */
    bool has_op_memory_grow;
    /* Whether function has opcode call or call_indirect */
    bool has_op_func_call;
}
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
    /* Whether function has memory operation opcodes */
    bool has_memory_operations;
    /* Whether function has opcode call_indirect */
    bool has_op_call_indirect;
    /* Whether function has opcode set_global_aux_stack */
    bool has_op_set_global_aux_stack;
}

static if (WASM_ENABLE_FAST_JIT != 0) {
    void* fast_jit_jitted_code;
static if (WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0) {
    void* llvm_jit_func_ptr;
}
}
};

struct WASMGlobal {
    ubyte type;
    bool is_mutable;
    InitializerExpression init_expr;
static if (WASM_ENABLE_FAST_JIT != 0) {
    /* The data offset of current global in global data */
    uint data_offset;
}
};

struct WASMExport {
    char* name;
    ubyte kind;
    uint index;
}

struct WASMTableSeg {
    /* 0 to 7 */
    uint mode;
    /* funcref or externref, elemkind will be considered as funcref */
    uint elem_type;
    bool is_dropped;
    /* optional, only for active */
    uint table_index;
    InitializerExpression base_offset;
    uint function_count;
    uint* func_indexes;
}

struct WASMDataSeg {
    uint memory_index;
    InitializerExpression base_offset;
    uint data_length;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    bool is_passive;
}
    ubyte* data;
}

struct BlockAddr {
    const(ubyte)* start_addr;
    ubyte* else_addr;
    ubyte* end_addr;
}

static if (WASM_ENABLE_LIBC_WASI != 0) {
struct WASIArguments {
    const(char)** dir_list;
    uint dir_count;
    const(char)** map_dir_list;
    uint map_dir_count;
    const(char)** env;
    uint env_count;
    /* in CIDR noation */
    const(char)** addr_pool;
    uint addr_count;
    const(char)** ns_lookup_pool;
    uint ns_lookup_count;
    char** argv;
    uint argc;
    int[3] stdio;
}
}

struct StringNode {
    StringNode* next;
    char* str;
}alias StringList = StringNode*;

struct BrTableCache {
    BrTableCache* next;
    /* Address of br_table opcode */
    ubyte* br_table_op_addr;
    uint br_count;
    uint[1] br_depths;
}

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
struct WASMFastOPCodeNode {
    WASMFastOPCodeNode* next;
    ulong offset;
    ubyte orig_op;
}
}

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
struct WASMCustomSection {
    WASMCustomSection* next;
    /* Start address of the section name */
    char* name_addr;
    /* Length of the section name decoded from leb */
    uint name_len;
    /* Start address of the content (name len and name skipped) */
    ubyte* content_addr;
    uint content_len;
}
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
struct AOTCompData;;
struct AOTCompContext;;

/* Orc JIT thread arguments */
struct OrcJitThreadArg {
static if (WASM_ENABLE_JIT != 0) {
    AOTCompContext* comp_ctx;
}
    WASMModule* module_;
    uint group_idx;
}
}

struct WASMModuleInstance;;

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
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    /* data count read from datacount section */
    uint data_seg_count1;
}

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
static if (WASM_ENABLE_FAST_INTERP == 0) {
    bh_list br_table_cache_list_head;
    bh_list* br_table_cache_list;
}

static if (WASM_ENABLE_LIBC_WASI != 0) {
    WASIArguments wasi_args;
    bool import_wasi_api;
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
    /* TODO: add mutex for mutli-thread? */
    bh_list import_module_list_head;
    bh_list* import_module_list;
}
static if (WASM_ENABLE_DEBUG_INTERP != 0 || WASM_ENABLE_DEBUG_AOT != 0) {
    bh_list fast_opcode_list;
    ubyte* buf_code;
    ulong buf_code_size;
}
static if (WASM_ENABLE_DEBUG_INTERP != 0 || WASM_ENABLE_DEBUG_AOT != 0 
    || WASM_ENABLE_FAST_JIT != 0) {
    ubyte* load_addr;
    ulong load_size;
}

static if (WASM_ENABLE_DEBUG_INTERP != 0                    
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT 
        && WASM_ENABLE_LAZY_JIT != 0)) {
    /**
     * List of instances referred to this module. When source debugging
     * feature is enabled, the debugger may modify the code section of
     * the module, so we need to report a warning if user create several
     * instances based on the same module. Sub instances created by
     * lib-pthread or spawn API won't be added into the list.
     *
     * Also add the instance to the list for Fast JIT to LLVM JIT
     * tier-up, since we need to lazily update the LLVM func pointers
     * in the instance.
     */
    WASMModuleInstance* instance_list;
    korp_mutex instance_list_lock;
}

static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    const(ubyte)* name_section_buf;
    const(ubyte)* name_section_buf_end;
}

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
    WASMCustomSection* custom_section_list;
}

static if (WASM_ENABLE_FAST_JIT != 0) {
    /* func pointers of Fast JITed (un-imported) functions */
    void** fast_jit_func_ptrs;
    /* locks for Fast JIT lazy compilation */
    korp_mutex[WASM_ORC_JIT_BACKEND_THREAD_NUM] fast_jit_thread_locks;
    bool[WASM_ORC_JIT_BACKEND_THREAD_NUM] fast_jit_thread_locks_inited;
}

static if (WASM_ENABLE_JIT != 0) {
    AOTCompData* comp_data;
    AOTCompContext* comp_ctx;
    /* func pointers of LLVM JITed (un-imported) functions */
    void** func_ptrs;
    /* whether the func pointers are compiled */
    bool* func_ptrs_compiled;
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
    /* backend compilation threads */
    korp_tid[WASM_ORC_JIT_BACKEND_THREAD_NUM] orcjit_threads;
    /* backend thread arguments */
    OrcJitThreadArg[WASM_ORC_JIT_BACKEND_THREAD_NUM] orcjit_thread_args;
    /* whether to stop the compilation of backend threads */
    bool orcjit_stop_compiling;
}

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 
    && WASM_ENABLE_LAZY_JIT != 0) {
    /* wait lock/cond for the synchronization of
       the llvm jit initialization */
    korp_mutex tierup_wait_lock;
    korp_cond tierup_wait_cond;
    bool tierup_wait_lock_inited;
    korp_tid llvm_jit_init_thread;
    /* whether the llvm jit is initialized */
    bool llvm_jit_inited;
}
};

struct BlockType {
    /* Block type may be expressed in one of two forms:
     * either by the type of the single return value or
     * by a type index of module.
     */
    union _U {
        ubyte value_type;
        WASMType* type;
    }_U u;
    bool is_value_type;
}

struct WASMBranchBlock {
    ubyte* begin_addr;
    ubyte* target_addr;
    uint* frame_sp;
    uint cell_num;
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
    uint h = cast(uint)strlen(str);
    const(ubyte)* p = cast(ubyte*)str;
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
        case VALUE_TYPE_I32:
        case VALUE_TYPE_F32:
static if (WASM_ENABLE_REF_TYPES != 0) {
        case VALUE_TYPE_FUNCREF:
        case VALUE_TYPE_EXTERNREF:
}
            return int32.sizeof;
        case VALUE_TYPE_I64:
        case VALUE_TYPE_F64:
            return int64.sizeof;
static if (WASM_ENABLE_SIMD != 0) {
        case VALUE_TYPE_V128:
            return sizeof(int64) * 2;
}
        case VALUE_TYPE_VOID:
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

static if (WASM_ENABLE_REF_TYPES != 0) {
pragma(inline, true) private ushort wasm_value_type_cell_num_outside(ubyte value_type) {
    if (VALUE_TYPE_EXTERNREF == value_type) {
        return uintptr_t.sizeof / uint32.sizeof;
    }
    else {
        return wasm_value_type_cell_num(value_type);
    }
}
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
               ? true
               : false;
}

pragma(inline, true) private uint wasm_get_smallest_type_idx(WASMType** types, uint type_count, uint cur_type_idx) {
    uint i = void;

    for (i = 0; i < cur_type_idx; i++) {
        if (wasm_type_equal(types[cur_type_idx], types[i]))
            return i;
    }
    cast(void)type_count;
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
        if (block_type.u.value_type != VALUE_TYPE_VOID) {
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


