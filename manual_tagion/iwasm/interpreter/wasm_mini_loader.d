module wasm_mini_loader;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wasm_loader;
public import bh_common;
public import bh_log;
public import wasm;
public import wasm_opcode;
public import wasm_runtime;
public import ...common.wasm_native;
public import ...common.wasm_memory;
static if (WASM_ENABLE_FAST_JIT != 0) {
public import ...fast-jit.jit_compiler;
public import ...fast-jit.jit_codecache;
}
static if (WASM_ENABLE_JIT != 0) {
public import ...compilation.aot_llvm;
}

/* Read a value of given type from the address pointed to by the given
   pointer and increase the pointer to the position just after the
   value being read.  */
enum string TEMPLATE_READ_VALUE(string Type, string p) = ` \
    (p += sizeof(Type), *(Type *)(p - sizeof(Type)))`;

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null)
        snprintf(error_buf, error_buf_size, "WASM module load failed: %s",
                 string);
}

enum string CHECK_BUF(string buf, string buf_end, string length) = `                            \
    do {                                                           \
        bh_assert(buf + length >= buf && buf + length <= buf_end); \
    } while (0)`;

enum string CHECK_BUF1(string buf, string buf_end, string length) = `                           \
    do {                                                           \
        bh_assert(buf + length >= buf && buf + length <= buf_end); \
    } while (0)`;

enum string skip_leb(string p) = ` while (*p++ & 0x80)`;
enum string skip_leb_int64(string p, string p_end) = ` skip_leb(p)`;
enum string skip_leb_uint32(string p, string p_end) = ` skip_leb(p)`;
enum string skip_leb_int32(string p, string p_end) = ` skip_leb(p)`;

private bool is_32bit_type(ubyte type) {
    if (type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32
#if WASM_ENABLE_REF_TYPES != 0
        || type == VALUE_TYPE_FUNCREF || type == VALUE_TYPE_EXTERNREF
#endif
    )
        return true;
    return false;
}

private bool is_64bit_type(ubyte type) {
    if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64)
        return true;
    return false;
}

private bool is_value_type(ubyte type) {
    if (type == VALUE_TYPE_I32 || type == VALUE_TYPE_I64
        || type == VALUE_TYPE_F32 || type == VALUE_TYPE_F64
#if WASM_ENABLE_REF_TYPES != 0
        || type == VALUE_TYPE_FUNCREF || type == VALUE_TYPE_EXTERNREF
#endif
    )
        return true;
    return false;
}

private bool is_byte_a_type(ubyte type) {
    return is_value_type(type) || (type == VALUE_TYPE_VOID);
}

private void read_leb(ubyte** p_buf, const(ubyte)* buf_end, uint maxbits, bool sign, ulong* p_result, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    ulong result = 0;
    uint shift = 0;
    uint offset = 0, bcnt = 0;
    ulong byte_ = void;

    while (true) {
        bh_assert(bcnt + 1 <= (maxbits + 6) / 7);
        CHECK_BUF(buf, buf_end, offset + 1);
        byte_ = buf[offset];
        offset += 1;
        result |= ((byte_ & 0x7f) << shift);
        shift += 7;
        bcnt += 1;
        if ((byte_ & 0x80) == 0) {
            break;
        }
    }

    if (!sign && maxbits == 32 && shift >= maxbits) {
        /* The top bits set represent values > 32 bits */
        bh_assert(!((cast(ubyte)byte_) & 0xf0));
    }
    else if (sign && maxbits == 32) {
        if (shift < maxbits) {
            /* Sign extend, second highest bit is the sign bit */
            if (cast(ubyte)byte_ & 0x40)
                result |= (~(cast(ulong)0)) << shift;
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = (cast(ubyte)byte_) & 0x8;
            int top_bits = (cast(ubyte)byte_) & 0xf0;
            bh_assert(!((sign_bit_set && top_bits != 0x70)
                        || (!sign_bit_set && top_bits != 0)));
            cast(void)top_bits;
            cast(void)sign_bit_set;
        }
    }
    else if (sign && maxbits == 64) {
        if (shift < maxbits) {
            /* Sign extend, second highest bit is the sign bit */
            if (cast(ubyte)byte_ & 0x40)
                result |= (~(cast(ulong)0)) << shift;
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = (cast(ubyte)byte_) & 0x1;
            int top_bits = (cast(ubyte)byte_) & 0xfe;

            bh_assert(!((sign_bit_set && top_bits != 0x7e)
                        || (!sign_bit_set && top_bits != 0)));
            cast(void)top_bits;
            cast(void)sign_bit_set;
        }
    }

    *p_buf += offset;
    *p_result = result;
}

enum string read_uint8(string p) = ` TEMPLATE_READ_VALUE(uint8, p)`;
enum string read_uint32(string p) = ` TEMPLATE_READ_VALUE(uint32, p)`;
enum string read_bool(string p) = ` TEMPLATE_READ_VALUE(bool, p)`;

enum string read_leb_int64(string p, string p_end, string res) = `                              \
    do {                                                           \
        uint64 res64;                                              \
        read_leb((uint8 **)&p, p_end, 64, true, &res64, error_buf, \
                 error_buf_size);                                  \
        res = (int64)res64;                                        \
    } while (0)`;

enum string read_leb_uint32(string p, string p_end, string res) = `                              \
    do {                                                            \
        uint64 res64;                                               \
        read_leb((uint8 **)&p, p_end, 32, false, &res64, error_buf, \
                 error_buf_size);                                   \
        res = (uint32)res64;                                        \
    } while (0)`;

enum string read_leb_int32(string p, string p_end, string res) = `                              \
    do {                                                           \
        uint64 res64;                                              \
        read_leb((uint8 **)&p, p_end, 32, true, &res64, error_buf, \
                 error_buf_size);                                  \
        res = (int32)res64;                                        \
    } while (0)`;

private void* loader_malloc(ulong size, char* error_buf, uint error_buf_size) {
    void* mem = void;

    if (size >= UINT32_MAX || ((mem = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return null;
    }

    memset(mem, 0, cast(uint)size);
    return mem;
}

private char* const_str_list_insert(const(ubyte)* str, uint len, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    StringNode* node = void, node_next = void;

    if (len == 0) {
        return "";
    }
    else if (is_load_from_file_buf) {
        /* As the file buffer can be referred to after loading, we use
           the previous byte of leb encoded size to adjust the string:
           move string 1 byte backward and then append '\0' */
        char* c_str = cast(char*)str - 1;
        bh_memmove_s(c_str, len + 1, c_str + 1, len);
        c_str[len] = '\0';
        return c_str;
    }

    /* Search const str list */
    node = module_.const_str_list;
    while (node) {
        node_next = node.next;
        if (strlen(node.str) == len && !memcmp(node.str, str, len))
            break;
        node = node_next;
    }

    if (node) {
        LOG_DEBUG("reuse %s", node.str);
        return node.str;
    }

    if (((node = loader_malloc(sizeof(StringNode) + len + 1, error_buf,
                               error_buf_size)) == 0)) {
        return null;
    }

    node.str = (cast(char*)node) + StringNode.sizeof;
    bh_memcpy_s(node.str, len + 1, str, len);
    node.str[len] = '\0';

    if (!module_.const_str_list) {
        /* set as head */
        module_.const_str_list = node;
        node.next = null;
    }
    else {
        /* insert it */
        node.next = module_.const_str_list;
        module_.const_str_list = node;
    }

    return node.str;
}

private void destroy_wasm_type(WASMType* type) {
    if (type.ref_count > 1) {
        /* The type is referenced by other types
           of current wasm module */
        type.ref_count--;
        return;
    }

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0) {
    if (type.call_to_llvm_jit_from_fast_jit)
        jit_code_cache_free(type.call_to_llvm_jit_from_fast_jit);
}

    wasm_runtime_free(type);
}

private bool load_init_expr(const(ubyte)** p_buf, const(ubyte)* buf_end, InitializerExpression* init_expr, ubyte type, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    ubyte flag = void, end_byte = void; ubyte* p_float = void;
    uint i = void;

    CHECK_BUF(p, p_end, 1);
    init_expr.init_expr_type = read_uint8(p);
    flag = init_expr.init_expr_type;

    switch (flag) {
        /* i32.const */
        case INIT_EXPR_TYPE_I32_CONST:
            bh_assert(type == VALUE_TYPE_I32);
            read_leb_int32(p, p_end, init_expr.u.i32);
            break;
        /* i64.const */
        case INIT_EXPR_TYPE_I64_CONST:
            bh_assert(type == VALUE_TYPE_I64);
            read_leb_int64(p, p_end, init_expr.u.i64);
            break;
        /* f32.const */
        case INIT_EXPR_TYPE_F32_CONST:
            bh_assert(type == VALUE_TYPE_F32);
            CHECK_BUF(p, p_end, 4);
            p_float = cast(ubyte*)&init_expr.u.f32;
            for (i = 0; i < float32.sizeof; i++)
                *p_float++ = *p++;
            break;
        /* f64.const */
        case INIT_EXPR_TYPE_F64_CONST:
            bh_assert(type == VALUE_TYPE_F64);
            CHECK_BUF(p, p_end, 8);
            p_float = cast(ubyte*)&init_expr.u.f64;
            for (i = 0; i < float64.sizeof; i++)
                *p_float++ = *p++;
            break;
static if (WASM_ENABLE_REF_TYPES != 0) {
        case INIT_EXPR_TYPE_FUNCREF_CONST:
        {
            bh_assert(type == VALUE_TYPE_FUNCREF);
            read_leb_uint32(p, p_end, init_expr.u.ref_index);
            break;
        }
        case INIT_EXPR_TYPE_REFNULL_CONST:
        {
            ubyte reftype = void;

            CHECK_BUF(p, p_end, 1);
            reftype = read_uint8(p);

            bh_assert(type == reftype);

            init_expr.u.ref_index = NULL_REF;
            cast(void)reftype;
            break;
        }
} /* WASM_ENABLE_REF_TYPES != 0 */
        /* get_global */
        case INIT_EXPR_TYPE_GET_GLOBAL:
            read_leb_uint32(p, p_end, init_expr.u.global_index);
            break;
        default:
            bh_assert(0);
            break;
    }
    CHECK_BUF(p, p_end, 1);
    end_byte = read_uint8(p);
    bh_assert(end_byte == 0x0b);
    *p_buf = p;

    cast(void)end_byte;
    return true;
}

private bool load_type_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end, p_org = void;
    uint type_count = void, param_count = void, result_count = void, i = void, j = void;
    uint param_cell_num = void, ret_cell_num = void;
    ulong total_size = void;
    ubyte flag = void;
    WASMType* type = void;

    read_leb_uint32(p, p_end, type_count);

    if (type_count) {
        module_.type_count = type_count;
        total_size = (WASMType*).sizeof * cast(ulong)type_count;
        if (((module_.types =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        for (i = 0; i < type_count; i++) {
            CHECK_BUF(p, p_end, 1);
            flag = read_uint8(p);
            bh_assert(flag == 0x60);

            read_leb_uint32(p, p_end, param_count);

            /* Resolve param count and result count firstly */
            p_org = p;
            CHECK_BUF(p, p_end, param_count);
            p += param_count;
            read_leb_uint32(p, p_end, result_count);
            CHECK_BUF(p, p_end, result_count);
            p = p_org;

            bh_assert(param_count <= UINT16_MAX && result_count <= UINT16_MAX);

            total_size = WASMType.types.offsetof
                         + sizeof(uint8) * (uint64)(param_count + result_count);
            if (((type = module_.types[i] =
                      loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
                return false;
            }

            /* Resolve param types and result types */
            type.ref_count = 1;
            type.param_count = cast(ushort)param_count;
            type.result_count = cast(ushort)result_count;
            for (j = 0; j < param_count; j++) {
                CHECK_BUF(p, p_end, 1);
                type.types[j] = read_uint8(p);
            }
            read_leb_uint32(p, p_end, result_count);
            for (j = 0; j < result_count; j++) {
                CHECK_BUF(p, p_end, 1);
                type.types[param_count + j] = read_uint8(p);
            }
            for (j = 0; j < param_count + result_count; j++) {
                bh_assert(is_value_type(type.types[j]));
            }

            param_cell_num = wasm_get_cell_num(type.types, param_count);
            ret_cell_num =
                wasm_get_cell_num(type.types + param_count, result_count);
            bh_assert(param_cell_num <= UINT16_MAX
                      && ret_cell_num <= UINT16_MAX);
            type.param_cell_num = cast(ushort)param_cell_num;
            type.ret_cell_num = cast(ushort)ret_cell_num;

            /* If there is already a same type created, use it instead */
            for (j = 0; j < i; ++j) {
                if (wasm_type_equal(type, module_.types[j])) {
                    bh_assert(module_.types[j].ref_count != UINT16_MAX);
                    destroy_wasm_type(type);
                    module_.types[i] = module_.types[j];
                    module_.types[j].ref_count++;
                    break;
                }
            }
        }
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load type section success.\n");
    cast(void)flag;
    return true;
}

private void adjust_table_max_size(uint init_size, uint max_size_flag, uint* max_size) {
    uint default_max_size = init_size * 2 > TABLE_MAX_SIZE ? init_size * 2 : TABLE_MAX_SIZE;

    if (max_size_flag) {
        /* module defines the table limitation */
        bh_assert(init_size <= *max_size);

        if (init_size < *max_size) {
            *max_size =
                *max_size < default_max_size ? *max_size : default_max_size;
        }
    }
    else {
        /* partial defined table limitation, gives a default value */
        *max_size = default_max_size;
    }
}

private bool load_function_import(const(ubyte)** p_buf, const(ubyte)* buf_end, const(WASMModule)* parent_module, const(char)* sub_module_name, const(char)* function_name, WASMFunctionImport* function_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint declare_type_index = 0;
    WASMType* declare_func_type = null;
    WASMFunction* linked_func = null;
    const(char)* linked_signature = null;
    void* linked_attachment = null;
    bool linked_call_conv_raw = false;

    read_leb_uint32(p, p_end, declare_type_index);
    *p_buf = p;

    bh_assert(declare_type_index < parent_module.type_count);

    declare_func_type = parent_module.types[declare_type_index];

    /* check built-in modules */
    linked_func = wasm_native_resolve_symbol(
        sub_module_name, function_name, declare_func_type, &linked_signature,
        &linked_attachment, &linked_call_conv_raw);

    function_.module_name = cast(char*)sub_module_name;
    function_.field_name = cast(char*)function_name;
    function_.func_type = declare_func_type;
    function_.func_ptr_linked = linked_func;
    function_.signature = linked_signature;
    function_.attachment = linked_attachment;
    function_.call_conv_raw = linked_call_conv_raw;
    return true;
}

private bool load_table_import(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* parent_module, const(char)* sub_module_name, const(char)* table_name, WASMTableImport* table, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint declare_elem_type = 0, declare_max_size_flag = 0, declare_init_size = 0, declare_max_size = 0;

    CHECK_BUF(p, p_end, 1);
    /* 0x70 or 0x6F */
    declare_elem_type = read_uint8(p);
    bh_assert(VALUE_TYPE_FUNCREF == declare_elem_type
#if WASM_ENABLE_REF_TYPES != 0
              || VALUE_TYPE_EXTERNREF == declare_elem_type
#endif
    );

    read_leb_uint32(p, p_end, declare_max_size_flag);
    read_leb_uint32(p, p_end, declare_init_size);
    if (declare_max_size_flag & 1) {
        read_leb_uint32(p, p_end, declare_max_size);
        bh_assert(table.init_size <= table.max_size);
    }

    adjust_table_max_size(declare_init_size, declare_max_size_flag,
                          &declare_max_size);
    *p_buf = p;

    bh_assert(
        !((declare_max_size_flag & 1) && declare_init_size > declare_max_size));

    /* now we believe all declaration are ok */
    table.elem_type = declare_elem_type;
    table.init_size = declare_init_size;
    table.flags = declare_max_size_flag;
    table.max_size = declare_max_size;
    return true;
}

private bool load_memory_import(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* parent_module, const(char)* sub_module_name, const(char)* memory_name, WASMMemoryImport* memory, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
static if (WASM_ENABLE_APP_FRAMEWORK != 0) {
    uint pool_size = wasm_runtime_memory_pool_size();
    uint max_page_count = pool_size * APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
                            / DEFAULT_NUM_BYTES_PER_PAGE;
} else {
    uint max_page_count = DEFAULT_MAX_PAGES;
} /* WASM_ENABLE_APP_FRAMEWORK */
    uint declare_max_page_count_flag = 0;
    uint declare_init_page_count = 0;
    uint declare_max_page_count = 0;

    read_leb_uint32(p, p_end, declare_max_page_count_flag);
    read_leb_uint32(p, p_end, declare_init_page_count);
    bh_assert(declare_init_page_count <= 65536);

    if (declare_max_page_count_flag & 1) {
        read_leb_uint32(p, p_end, declare_max_page_count);
        bh_assert(declare_init_page_count <= declare_max_page_count);
        bh_assert(declare_max_page_count <= 65536);
        if (declare_max_page_count > max_page_count) {
            declare_max_page_count = max_page_count;
        }
    }
    else {
        /* Limit the maximum memory size to max_page_count */
        declare_max_page_count = max_page_count;
    }

    /* now we believe all declaration are ok */
    memory.flags = declare_max_page_count_flag;
    memory.init_page_count = declare_init_page_count;
    memory.max_page_count = declare_max_page_count;
    memory.num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;

    *p_buf = p;
    return true;
}

private bool load_global_import(const(ubyte)** p_buf, const(ubyte)* buf_end, const(WASMModule)* parent_module, char* sub_module_name, char* global_name, WASMGlobalImport* global, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    ubyte declare_type = 0;
    ubyte declare_mutable = 0;
    bool is_mutable = false;
    bool ret = false;

    CHECK_BUF(p, p_end, 2);
    declare_type = read_uint8(p);
    declare_mutable = read_uint8(p);
    *p_buf = p;

    bh_assert(declare_mutable < 2);

    is_mutable = declare_mutable & 1 ? true : false;

static if (WASM_ENABLE_LIBC_BUILTIN != 0) {
    /* check built-in modules */
    ret = wasm_native_lookup_libc_builtin_global(sub_module_name, global_name,
                                                 global);
    if (ret) {
        bh_assert(global.type == declare_type
                  && global.is_mutable != declare_mutable);
    }
} /* WASM_ENABLE_LIBC_BUILTIN */

    global.is_linked = ret;
    global.module_name = sub_module_name;
    global.field_name = global_name;
    global.type = declare_type;
    global.is_mutable = is_mutable;
    cast(void)p_end;
    return true;
}

private bool load_table(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMTable* table, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end, p_org = void;

    CHECK_BUF(p, p_end, 1);
    /* 0x70 or 0x6F */
    table.elem_type = read_uint8(p);
    bh_assert((VALUE_TYPE_FUNCREF == table.elem_type)
#if WASM_ENABLE_REF_TYPES != 0
              || VALUE_TYPE_EXTERNREF == table.elem_type
#endif
    );

    p_org = p;
    read_leb_uint32(p, p_end, table.flags);
    bh_assert(p - p_org <= 1);
    bh_assert(table.flags <= 1);
    cast(void)p_org;

    read_leb_uint32(p, p_end, table.init_size);
    if (table.flags == 1) {
        read_leb_uint32(p, p_end, table.max_size);
        bh_assert(table.init_size <= table.max_size);
    }

    adjust_table_max_size(table.init_size, table.flags, &table.max_size);

    *p_buf = p;
    return true;
}

private bool load_memory(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMMemory* memory, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end, p_org = void;
static if (WASM_ENABLE_APP_FRAMEWORK != 0) {
    uint pool_size = wasm_runtime_memory_pool_size();
    uint max_page_count = pool_size * APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
                            / DEFAULT_NUM_BYTES_PER_PAGE;
} else {
    uint max_page_count = DEFAULT_MAX_PAGES;
}

    p_org = p;
    read_leb_uint32(p, p_end, memory.flags);
    bh_assert(p - p_org <= 1);
    cast(void)p_org;
static if (WASM_ENABLE_SHARED_MEMORY == 0) {
    bh_assert(memory.flags <= 1);
} else {
    bh_assert(memory.flags <= 3 && memory.flags != 2);
}

    read_leb_uint32(p, p_end, memory.init_page_count);
    bh_assert(memory.init_page_count <= 65536);

    if (memory.flags & 1) {
        read_leb_uint32(p, p_end, memory.max_page_count);
        bh_assert(memory.init_page_count <= memory.max_page_count);
        bh_assert(memory.max_page_count <= 65536);
        if (memory.max_page_count > max_page_count)
            memory.max_page_count = max_page_count;
    }
    else {
        /* Limit the maximum memory size to max_page_count */
        memory.max_page_count = max_page_count;
    }

    memory.num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;

    *p_buf = p;
    return true;
}

private bool load_import_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end, p_old = void;
    uint import_count = void, name_len = void, type_index = void, i = void, u32 = void, flags = void;
    ulong total_size = void;
    WASMImport* import_ = void;
    WASMImport* import_functions = null, import_tables = null;
    WASMImport* import_memories = null, import_globals = null;
    char* sub_module_name = void, field_name = void;
    ubyte u8 = void, kind = void;

    read_leb_uint32(p, p_end, import_count);

    if (import_count) {
        module_.import_count = import_count;
        total_size = sizeof(WASMImport) * cast(ulong)import_count;
        if (((module_.imports =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        p_old = p;

        /* Scan firstly to get import count of each type */
        for (i = 0; i < import_count; i++) {
            /* module name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            p += name_len;

            /* field name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            p += name_len;

            CHECK_BUF(p, p_end, 1);
            /* 0x00/0x01/0x02/0x03 */
            kind = read_uint8(p);

            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    read_leb_uint32(p, p_end, type_index);
                    module_.import_function_count++;
                    break;

                case IMPORT_KIND_TABLE: /* import table */
                    CHECK_BUF(p, p_end, 1);
                    /* 0x70 */
                    u8 = read_uint8(p);
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    module_.import_table_count++;
static if (WASM_ENABLE_REF_TYPES == 0) {
                    bh_assert(module_.import_table_count <= 1);
}
                    break;

                case IMPORT_KIND_MEMORY: /* import memory */
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    module_.import_memory_count++;
                    bh_assert(module_.import_memory_count <= 1);
                    break;

                case IMPORT_KIND_GLOBAL: /* import global */
                    CHECK_BUF(p, p_end, 2);
                    p += 2;
                    module_.import_global_count++;
                    break;

                default:
                    bh_assert(0);
                    break;
            }
        }

        if (module_.import_function_count)
            import_functions = module_.import_functions = module_.imports;
        if (module_.import_table_count)
            import_tables = module_.import_tables =
                module_.imports + module_.import_function_count;
        if (module_.import_memory_count)
            import_memories = module_.import_memories =
                module_.imports + module_.import_function_count
                + module_.import_table_count;
        if (module_.import_global_count)
            import_globals = module_.import_globals =
                module_.imports + module_.import_function_count
                + module_.import_table_count + module_.import_memory_count;

        p = p_old;

        /* Scan again to resolve the data */
        for (i = 0; i < import_count; i++) {
            WASMModule* sub_module = null;

            /* load module name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            if (((sub_module_name = const_str_list_insert(
                      p, name_len, module_, is_load_from_file_buf, error_buf,
                      error_buf_size)) == 0)) {
                return false;
            }
            p += name_len;

            /* load field name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            if (((field_name = const_str_list_insert(
                      p, name_len, module_, is_load_from_file_buf, error_buf,
                      error_buf_size)) == 0)) {
                return false;
            }
            p += name_len;

            CHECK_BUF(p, p_end, 1);
            /* 0x00/0x01/0x02/0x03 */
            kind = read_uint8(p);

            LOG_DEBUG("import #%d: (%s, %s), kind: %d", i, sub_module_name,
                      field_name, kind);
            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    bh_assert(import_functions);
                    import_ = import_functions++;
                    if (!load_function_import(
                            &p, p_end, module_, sub_module_name, field_name,
                            &import_.u.function_, error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                case IMPORT_KIND_TABLE: /* import table */
                    bh_assert(import_tables);
                    import_ = import_tables++;
                    if (!load_table_import(&p, p_end, module_, sub_module_name,
                                           field_name, &import_.u.table,
                                           error_buf, error_buf_size)) {
                        LOG_DEBUG("can not import such a table (%s,%s)",
                                  sub_module_name, field_name);
                        return false;
                    }
                    break;

                case IMPORT_KIND_MEMORY: /* import memory */
                    bh_assert(import_memories);
                    import_ = import_memories++;
                    if (!load_memory_import(&p, p_end, module_, sub_module_name,
                                            field_name, &import_.u.memory,
                                            error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                case IMPORT_KIND_GLOBAL: /* import global */
                    bh_assert(import_globals);
                    import_ = import_globals++;
                    if (!load_global_import(&p, p_end, module_, sub_module_name,
                                            field_name, &import_.u.global,
                                            error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                default:
                    bh_assert(0);
                    import_ = null;
                    break;
            }
            import_.kind = kind;
            import_.u.names.module_name = sub_module_name;
            import_.u.names.field_name = field_name;
            cast(void)sub_module;
        }

static if (WASM_ENABLE_LIBC_WASI != 0) {
        import_ = module_.import_functions;
        for (i = 0; i < module_.import_function_count; i++, import_++) {
            if (!strcmp(import_.u.names.module_name, "wasi_unstable")
                || !strcmp(import_.u.names.module_name,
                           "wasi_snapshot_preview1")) {
                module_.import_wasi_api = true;
                break;
            }
        }
}
    }

    bh_assert(p == p_end);

    LOG_VERBOSE("Load import section success.\n");
    cast(void)u8;
    cast(void)u32;
    cast(void)type_index;
    return true;
}

private bool init_function_local_offsets(WASMFunction* func, char* error_buf, uint error_buf_size) {
    WASMType* param_type = func.func_type;
    uint param_count = param_type.param_count;
    ubyte* param_types = param_type.types;
    uint local_count = func.local_count;
    ubyte* local_types = func.local_types;
    uint i = void, local_offset = 0;
    ulong total_size = sizeof(uint16) * (cast(ulong)param_count + local_count);

    if (total_size > 0
        && ((func.local_offsets =
                 loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    for (i = 0; i < param_count; i++) {
        func.local_offsets[i] = cast(ushort)local_offset;
        local_offset += wasm_value_type_cell_num(param_types[i]);
    }

    for (i = 0; i < local_count; i++) {
        func.local_offsets[param_count + i] = cast(ushort)local_offset;
        local_offset += wasm_value_type_cell_num(local_types[i]);
    }

    bh_assert(local_offset == func.param_cell_num + func.local_cell_num);
    return true;
}

private bool load_function_section(const(ubyte)* buf, const(ubyte)* buf_end, const(ubyte)* buf_code, const(ubyte)* buf_code_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    const(ubyte)* p_code = buf_code, p_code_end = void, p_code_save = void;
    uint func_count = void;
    ulong total_size = void;
    uint code_count = 0, code_size = void, type_index = void, i = void, j = void, k = void, local_type_index = void;
    uint local_count = void, local_set_count = void, sub_local_count = void, local_cell_num = void;
    ubyte type = void;
    WASMFunction* func = void;

    read_leb_uint32(p, p_end, func_count);

    if (buf_code)
        read_leb_uint32(p_code, buf_code_end, code_count);

    bh_assert(func_count == code_count);

    if (func_count) {
        module_.function_count = func_count;
        total_size = (WASMFunction*).sizeof * cast(ulong)func_count;
        if (((module_.functions =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        for (i = 0; i < func_count; i++) {
            /* Resolve function type */
            read_leb_uint32(p, p_end, type_index);
            bh_assert(type_index < module_.type_count);

static if ((WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0)) {
            type_index = wasm_get_smallest_type_idx(
                module_.types, module_.type_count, type_index);
}

            read_leb_uint32(p_code, buf_code_end, code_size);
            bh_assert(code_size > 0 && p_code + code_size <= buf_code_end);

            /* Resolve local set count */
            p_code_end = p_code + code_size;
            local_count = 0;
            read_leb_uint32(p_code, buf_code_end, local_set_count);
            p_code_save = p_code;

            /* Calculate total local count */
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                bh_assert(sub_local_count <= UINT32_MAX - local_count);

                CHECK_BUF(p_code, buf_code_end, 1);
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                local_count += sub_local_count;
            }

            /* Alloc memory, layout: function structure + local types */
            code_size = (uint32)(p_code_end - p_code);

            total_size = sizeof(WASMFunction) + cast(ulong)local_count;
            if (((func = module_.functions[i] =
                      loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
                return false;
            }

            /* Set function type, local count, code size and code body */
            func.func_type = module_.types[type_index];
            func.local_count = local_count;
            if (local_count > 0)
                func.local_types = cast(ubyte*)func + WASMFunction.sizeof;
            func.code_size = code_size;
            /*
             * we shall make a copy of code body [p_code, p_code + code_size]
             * when we are worrying about inappropriate releasing behaviour.
             * all code bodies are actually in a buffer which user allocates in
             * his embedding environment and we don't have power on them.
             * it will be like:
             * code_body_cp = malloc(code_size);
             * memcpy(code_body_cp, p_code, code_size);
             * func->code = code_body_cp;
             */
            func.code = cast(ubyte*)p_code;

            /* Load each local type */
            p_code = p_code_save;
            local_type_index = 0;
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                /* Note: sub_local_count is allowed to be 0 */
                bh_assert(local_type_index <= UINT32_MAX - sub_local_count
                          && local_type_index + sub_local_count <= local_count);

                CHECK_BUF(p_code, buf_code_end, 1);
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                bh_assert(is_value_type(type));
                for (k = 0; k < sub_local_count; k++) {
                    func.local_types[local_type_index++] = type;
                }
            }

            func.param_cell_num = func.func_type.param_cell_num;
            func.ret_cell_num = func.func_type.ret_cell_num;
            local_cell_num =
                wasm_get_cell_num(func.local_types, func.local_count);
            bh_assert(local_cell_num <= UINT16_MAX);

            func.local_cell_num = cast(ushort)local_cell_num;

            if (!init_function_local_offsets(func, error_buf, error_buf_size))
                return false;

            p_code = p_code_end;
        }
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load function section success.\n");
    cast(void)code_count;
    return true;
}

private bool check_function_index(const(WASMModule)* module_, uint function_index, char* error_buf, uint error_buf_size) {
    return (function_index
            < module_.import_function_count + module_.function_count);
}

private bool load_table_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint table_count = void, i = void;
    ulong total_size = void;
    WASMTable* table = void;

    read_leb_uint32(p, p_end, table_count);
static if (WASM_ENABLE_REF_TYPES == 0) {
    bh_assert(module_.import_table_count + table_count <= 1);
}

    if (table_count) {
        module_.table_count = table_count;
        total_size = sizeof(WASMTable) * cast(ulong)table_count;
        if (((module_.tables =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        /* load each table */
        table = module_.tables;
        for (i = 0; i < table_count; i++, table++)
            if (!load_table(&p, p_end, table, error_buf, error_buf_size))
                return false;
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load table section success.\n");
    return true;
}

private bool load_memory_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint memory_count = void, i = void;
    ulong total_size = void;
    WASMMemory* memory = void;

    read_leb_uint32(p, p_end, memory_count);
    bh_assert(module_.import_memory_count + memory_count <= 1);

    if (memory_count) {
        module_.memory_count = memory_count;
        total_size = sizeof(WASMMemory) * cast(ulong)memory_count;
        if (((module_.memories =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        /* load each memory */
        memory = module_.memories;
        for (i = 0; i < memory_count; i++, memory++)
            if (!load_memory(&p, p_end, memory, error_buf, error_buf_size))
                return false;
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load memory section success.\n");
    return true;
}

private bool load_global_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint global_count = void, i = void;
    ulong total_size = void;
    WASMGlobal* global = void;
    ubyte mutable = void;

    read_leb_uint32(p, p_end, global_count);

    if (global_count) {
        module_.global_count = global_count;
        total_size = sizeof(WASMGlobal) * cast(ulong)global_count;
        if (((module_.globals =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        global = module_.globals;

        for (i = 0; i < global_count; i++, global++) {
            CHECK_BUF(p, p_end, 2);
            global.type = read_uint8(p);
            mutable = read_uint8(p);
            bh_assert(mutable < 2);
            global.is_mutable = mutable ? true : false;

            /* initialize expression */
            if (!load_init_expr(&p, p_end, &(global.init_expr), global.type,
                                error_buf, error_buf_size))
                return false;

            if (INIT_EXPR_TYPE_GET_GLOBAL == global.init_expr.init_expr_type) {
                /**
                 * Currently, constant expressions occurring as initializers
                 * of globals are further constrained in that contained
                 * global.get instructions are
                 * only allowed to refer to imported globals.
                 */
                uint target_global_index = global.init_expr.u.global_index;
                bh_assert(target_global_index < module_.import_global_count);
                cast(void)target_global_index;
            }
            else if (INIT_EXPR_TYPE_FUNCREF_CONST
                     == global.init_expr.init_expr_type) {
                bh_assert(global.init_expr.u.ref_index
                          < module_.import_function_count
                                + module_.function_count);
            }
        }
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load global section success.\n");
    return true;
}

private bool load_export_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint export_count = void, i = void, j = void, index = void;
    ulong total_size = void;
    uint str_len = void;
    WASMExport* export_ = void;
    const(char)* name = void;

    read_leb_uint32(p, p_end, export_count);

    if (export_count) {
        module_.export_count = export_count;
        total_size = sizeof(WASMExport) * cast(ulong)export_count;
        if (((module_.exports =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        export_ = module_.exports;
        for (i = 0; i < export_count; i++, export_ ++) {
            read_leb_uint32(p, p_end, str_len);
            CHECK_BUF(p, p_end, str_len);

            for (j = 0; j < i; j++) {
                name = module_.exports[j].name;
                bh_assert(!(strlen(name) == str_len
                            && memcmp(name, p, str_len) == 0));
            }

            if (((export_.name = const_str_list_insert(
                      p, str_len, module_, is_load_from_file_buf, error_buf,
                      error_buf_size)) == 0)) {
                return false;
            }

            p += str_len;
            CHECK_BUF(p, p_end, 1);
            export_.kind = read_uint8(p);
            read_leb_uint32(p, p_end, index);
            export_.index = index;

            switch (export_.kind) {
                /* function index */
                case EXPORT_KIND_FUNC:
                    bh_assert(index < module_.function_count
                                          + module_.import_function_count);
                    break;
                /* table index */
                case EXPORT_KIND_TABLE:
                    bh_assert(index < module_.table_count
                                          + module_.import_table_count);
                    break;
                /* memory index */
                case EXPORT_KIND_MEMORY:
                    bh_assert(index < module_.memory_count
                                          + module_.import_memory_count);
                    break;
                /* global index */
                case EXPORT_KIND_GLOBAL:
                    bh_assert(index < module_.global_count
                                          + module_.import_global_count);
                    break;
                default:
                    bh_assert(0);
                    break;
            }
        }
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load export section success.\n");
    cast(void)name;
    return true;
}

private bool check_table_index(const(WASMModule)* module_, uint table_index, char* error_buf, uint error_buf_size) {
static if (WASM_ENABLE_REF_TYPES == 0) {
    if (table_index != 0) {
        return false;
    }
}

    if (table_index >= module_.import_table_count + module_.table_count) {
        return false;
    }
    return true;
}

private bool load_table_index(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* module_, uint* p_table_index, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint table_index = void;

    read_leb_uint32(p, p_end, table_index);
    if (!check_table_index(module_, table_index, error_buf, error_buf_size)) {
        return false;
    }

    *p_table_index = table_index;
    *p_buf = p;
    return true;
}

static if (WASM_ENABLE_REF_TYPES != 0) {
private bool load_elem_type(const(ubyte)** p_buf, const(ubyte)* buf_end, uint* p_elem_type, bool elemkind_zero, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    ubyte elem_type = void;

    CHECK_BUF(p, p_end, 1);
    elem_type = read_uint8(p);
    if ((elemkind_zero && elem_type != 0)
        || (!elemkind_zero && elem_type != VALUE_TYPE_FUNCREF
            && elem_type != VALUE_TYPE_EXTERNREF)) {
        set_error_buf(error_buf, error_buf_size, "invalid reference type");
        return false;
    }

    if (elemkind_zero)
        *p_elem_type = VALUE_TYPE_FUNCREF;
    else
        *p_elem_type = elem_type;
    *p_buf = p;

    cast(void)p_end;
    return true;
}
} /* WASM_ENABLE_REF_TYPES != 0*/

private bool load_func_index_vec(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* module_, WASMTableSeg* table_segment, bool use_init_expr, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint function_count = void, function_index = 0, i = void;
    ulong total_size = void;

    read_leb_uint32(p, p_end, function_count);
    table_segment.function_count = function_count;
    total_size = sizeof(uint32) * cast(ulong)function_count;
    if (total_size > 0
        && ((table_segment.func_indexes = cast(uint*)loader_malloc(
                 total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    for (i = 0; i < function_count; i++) {
        InitializerExpression init_expr = { 0 };

static if (WASM_ENABLE_REF_TYPES != 0) {
        if (!use_init_expr) {
            read_leb_uint32(p, p_end, function_index);
        }
        else {
            if (!load_init_expr(&p, p_end, &init_expr, table_segment.elem_type,
                                error_buf, error_buf_size))
                return false;

            function_index = init_expr.u.ref_index;
        }
} else {
        read_leb_uint32(p, p_end, function_index);
}

        /* since we are using -1 to indicate ref.null */
        if (init_expr.init_expr_type != INIT_EXPR_TYPE_REFNULL_CONST
            && !check_function_index(module_, function_index, error_buf,
                                     error_buf_size)) {
            return false;
        }
        table_segment.func_indexes[i] = function_index;
    }

    *p_buf = p;
    return true;
}

private bool load_table_segment_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint table_segment_count = void, i = void, table_index = void, function_count = void;
    ulong total_size = void;
    WASMTableSeg* table_segment = void;

    read_leb_uint32(p, p_end, table_segment_count);

    if (table_segment_count) {
        module_.table_seg_count = table_segment_count;
        total_size = sizeof(WASMTableSeg) * cast(ulong)table_segment_count;
        if (((module_.table_segments =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        table_segment = module_.table_segments;
        for (i = 0; i < table_segment_count; i++, table_segment++) {
            bh_assert(p < p_end);

static if (WASM_ENABLE_REF_TYPES != 0) {
            read_leb_uint32(p, p_end, table_segment.mode);
            /* last three bits */
            table_segment.mode = table_segment.mode & 0x07;
            switch (table_segment.mode) {
                /* elemkind/elemtype + active */
                case 0:
                case 4:
                    table_segment.elem_type = VALUE_TYPE_FUNCREF;
                    table_segment.table_index = 0;

                    if (!check_table_index(module_, table_segment.table_index,
                                           error_buf, error_buf_size))
                        return false;

                    if (!load_init_expr(&p, p_end, &table_segment.base_offset,
                                        VALUE_TYPE_I32, error_buf,
                                        error_buf_size))
                        return false;

                    if (!load_func_index_vec(&p, p_end, module_, table_segment,
                                             table_segment.mode == 0 ? false
                                                                      : true,
                                             error_buf, error_buf_size))
                        return false;
                    break;
                /* elemkind + passive/declarative */
                case 1:
                case 3:
                    if (!load_elem_type(&p, p_end, &table_segment.elem_type,
                                        true, error_buf, error_buf_size))
                        return false;
                    if (!load_func_index_vec(&p, p_end, module_, table_segment,
                                             false, error_buf, error_buf_size))
                        return false;
                    break;
                /* elemkind/elemtype + table_idx + active */
                case 2:
                case 6:
                    if (!load_table_index(&p, p_end, module_,
                                          &table_segment.table_index,
                                          error_buf, error_buf_size))
                        return false;
                    if (!load_init_expr(&p, p_end, &table_segment.base_offset,
                                        VALUE_TYPE_I32, error_buf,
                                        error_buf_size))
                        return false;
                    if (!load_elem_type(&p, p_end, &table_segment.elem_type,
                                        table_segment.mode == 2 ? true : false,
                                        error_buf, error_buf_size))
                        return false;
                    if (!load_func_index_vec(&p, p_end, module_, table_segment,
                                             table_segment.mode == 2 ? false
                                                                      : true,
                                             error_buf, error_buf_size))
                        return false;
                    break;
                case 5:
                case 7:
                    if (!load_elem_type(&p, p_end, &table_segment.elem_type,
                                        false, error_buf, error_buf_size))
                        return false;
                    if (!load_func_index_vec(&p, p_end, module_, table_segment,
                                             true, error_buf, error_buf_size))
                        return false;
                    break;
                default:
                    return false;
            }
} else {
            /*
             * like:      00  41 05 0b               04 00 01 00 01
             * for: (elem 0   (offset (i32.const 5)) $f1 $f2 $f1 $f2)
             */
            if (!load_table_index(&p, p_end, module_,
                                  &table_segment.table_index, error_buf,
                                  error_buf_size))
                return false;
            if (!load_init_expr(&p, p_end, &table_segment.base_offset,
                                VALUE_TYPE_I32, error_buf, error_buf_size))
                return false;
            if (!load_func_index_vec(&p, p_end, module_, table_segment, false,
                                     error_buf, error_buf_size))
                return false;
} /* WASM_ENABLE_REF_TYPES != 0 */
        }
    }

    cast(void)table_index;
    cast(void)function_count;
    bh_assert(p == p_end);
    LOG_VERBOSE("Load table segment section success.\n");
    return true;
}

static bool
load_data_segment_section(const(ubyte)* buf, const(ubyte)* buf_end,
                          WASMModule* module_, char* error_buf,
                          uint error_buf_size)
{
    const(ubyte)* p = buf, p_end = buf_end;
    uint data_seg_count, i, mem_index, data_seg_len;
    ulong total_size;
    WASMDataSeg* dataseg;
    InitializerExpression init_expr;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    bool is_passive = false;
    uint mem_flag;
}

    read_leb_uint32(p, p_end, data_seg_count);

static if (WASM_ENABLE_BULK_MEMORY != 0) {
    bh_assert(module_.data_seg_count1 == 0
              || data_seg_count == module_.data_seg_count1);
}

    if (data_seg_count) {
        module_.data_seg_count = data_seg_count;
        total_size = (WASMDataSeg*).sizeof * cast(ulong)data_seg_count;
        if (((module_.data_segments =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        for (i = 0; i < data_seg_count; i++) {
            read_leb_uint32(p, p_end, mem_index);
static if (WASM_ENABLE_BULK_MEMORY != 0) {
            is_passive = false;
            mem_flag = mem_index & 0x03;
            switch (mem_flag) {
                case 0x01:
                    is_passive = true;
                    break;
                case 0x00:
                    /* no memory index, treat index as 0 */
                    mem_index = 0;
                    goto check_mem_index;
                case 0x02:
                    /* read following memory index */
                    read_leb_uint32(p, p_end, mem_index);
                check_mem_index:
                    bh_assert(mem_index < module_.import_memory_count
                                              + module_.memory_count);
                    break;
                case 0x03:
                default:
                    bh_assert(0);
                    break;
            }
} else {
            bh_assert(mem_index
                      < module_.import_memory_count + module_.memory_count);
} /* WASM_ENABLE_BULK_MEMORY */

#if WASM_ENABLE_BULK_MEMORY != 0
            if (!is_passive)
#endif
                if (!load_init_expr(&p, p_end, &init_expr, VALUE_TYPE_I32,
                                    error_buf, error_buf_size))
                    return false;

            read_leb_uint32(p, p_end, data_seg_len);

            if (((dataseg = module_.data_segments[i] = loader_malloc(
                      WASMDataSeg.sizeof, error_buf, error_buf_size)) == 0)) {
                return false;
            }

#if WASM_ENABLE_BULK_MEMORY != 0
            dataseg.is_passive = is_passive;
            if (!is_passive)
#endif
            {
                bh_memcpy_s(&dataseg.base_offset,
                            InitializerExpression.sizeof, &init_expr,
                            InitializerExpression.sizeof);

                dataseg.memory_index = mem_index;
            }

            dataseg.data_length = data_seg_len;
            CHECK_BUF(p, p_end, data_seg_len);
            dataseg.data = cast(ubyte*)p;
            p += data_seg_len;
        }
    }

    bh_assert(p == p_end);
    LOG_VERBOSE("Load data segment section success.\n");
    return true;
}

static if (WASM_ENABLE_BULK_MEMORY != 0) {
private bool load_datacount_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint data_seg_count1 = 0;

    read_leb_uint32(p, p_end, data_seg_count1);
    module_.data_seg_count1 = data_seg_count1;

    bh_assert(p == p_end);
    LOG_VERBOSE("Load datacount section success.\n");
    return true;
}
}

private bool load_code_section(const(ubyte)* buf, const(ubyte)* buf_end, const(ubyte)* buf_func, const(ubyte)* buf_func_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    const(ubyte)* p_func = buf_func;
    uint func_count = 0, code_count = void;

    /* code has been loaded in function section, so pass it here, just check
     * whether function and code section have inconsistent lengths */
    read_leb_uint32(p, p_end, code_count);

    if (buf_func)
        read_leb_uint32(p_func, buf_func_end, func_count);

    bh_assert(func_count == code_count);
    LOG_VERBOSE("Load code segment section success.\n");
    cast(void)code_count;
    cast(void)func_count;
    return true;
}

private bool load_start_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    WASMType* type = void;
    uint start_function = void;

    read_leb_uint32(p, p_end, start_function);

    bh_assert(start_function
              < module_.function_count + module_.import_function_count);

    if (start_function < module_.import_function_count)
        type = module_.import_functions[start_function].u.function_.func_type;
    else
        type = module_.functions[start_function - module_.import_function_count]
                   .func_type;

    bh_assert(type.param_count == 0 && type.result_count == 0);

    module_.start_function = start_function;

    bh_assert(p == p_end);
    LOG_VERBOSE("Load start section success.\n");
    cast(void)type;
    return true;
}

static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
private bool handle_name_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint name_type = void, subsection_size = void;
    uint previous_name_type = 0;
    uint num_func_name = void;
    uint func_index = void;
    uint previous_func_index = ~0U;
    uint func_name_len = void;
    uint name_index = void;
    int i = 0;

    bh_assert(p < p_end);

    while (p < p_end) {
        read_leb_uint32(p, p_end, name_type);
        if (i != 0) {
            bh_assert(name_type > previous_name_type);
        }
        previous_name_type = name_type;
        read_leb_uint32(p, p_end, subsection_size);
        CHECK_BUF(p, p_end, subsection_size);
        switch (name_type) {
            case SUB_SECTION_TYPE_FUNC:
                if (subsection_size) {
                    read_leb_uint32(p, p_end, num_func_name);
                    for (name_index = 0; name_index < num_func_name;
                         name_index++) {
                        read_leb_uint32(p, p_end, func_index);
                        bh_assert(func_index > previous_func_index);
                        previous_func_index = func_index;
                        read_leb_uint32(p, p_end, func_name_len);
                        CHECK_BUF(p, p_end, func_name_len);
                        /* Skip the import functions */
                        if (func_index >= module_.import_count) {
                            func_index -= module_.import_count;
                            bh_assert(func_index < module_.function_count);
                            if (((module_.functions[func_index].field_name =
                                      const_str_list_insert(
                                          p, func_name_len, module_,
                                          is_load_from_file_buf, error_buf,
                                          error_buf_size)) == 0)) {
                                return false;
                            }
                        }
                        p += func_name_len;
                    }
                }
                break;
            case SUB_SECTION_TYPE_MODULE: /* TODO: Parse for module subsection
                                           */
            case SUB_SECTION_TYPE_LOCAL:  /* TODO: Parse for local subsection */
            default:
                p = p + subsection_size;
                break;
        }
        i++;
    }

    return true;
}
}

private bool load_user_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint name_len = void;

    bh_assert(p < p_end);

    read_leb_uint32(p, p_end, name_len);

    bh_assert(name_len > 0 && p + name_len <= p_end);

static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    if (memcmp(p, "name", 4) == 0) {
        p += name_len;
        handle_name_section(p, p_end, module_, is_load_from_file_buf, error_buf,
                            error_buf_size);
    }
}
    LOG_VERBOSE("Load custom section success.\n");
    cast(void)name_len;
    return true;
}

private void calculate_global_data_offset(WASMModule* module_) {
    uint i = void, data_offset = void;

    data_offset = 0;
    for (i = 0; i < module_.import_global_count; i++) {
        WASMGlobalImport* import_global = &((module_.import_globals + i).u.global);
static if (WASM_ENABLE_FAST_JIT != 0) {
        import_global.data_offset = data_offset;
}
        data_offset += wasm_value_type_size(import_global.type);
    }

    for (i = 0; i < module_.global_count; i++) {
        WASMGlobal* global = module_.globals + i;
static if (WASM_ENABLE_FAST_JIT != 0) {
        global.data_offset = data_offset;
}
        data_offset += wasm_value_type_size(global.type);
    }

    module_.global_data_size = data_offset;
}

static if (WASM_ENABLE_FAST_JIT != 0) {
private bool init_fast_jit_functions(WASMModule* module_, char* error_buf, uint error_buf_size) {
static if (WASM_ENABLE_LAZY_JIT != 0) {
    JitGlobals* jit_globals = jit_compiler_get_jit_globals();
}
    uint i = void;

    if (!module_.function_count)
        return true;

    if (((module_.fast_jit_func_ptrs =
              loader_malloc((void*).sizeof * module_.function_count, error_buf,
                            error_buf_size)) == 0)) {
        return false;
    }

static if (WASM_ENABLE_LAZY_JIT != 0) {
    for (i = 0; i < module_.function_count; i++) {
        module_.fast_jit_func_ptrs[i] =
            jit_globals.compile_fast_jit_and_then_call;
    }
}

    for (i = 0; i < WASM_ORC_JIT_BACKEND_THREAD_NUM; i++) {
        if (os_mutex_init(&module_.fast_jit_thread_locks[i]) != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "init fast jit thread lock failed");
            return false;
        }
        module_.fast_jit_thread_locks_inited[i] = true;
    }

    return true;
}
} /* end of WASM_ENABLE_FAST_JIT != 0 */

static if (WASM_ENABLE_JIT != 0) {
private bool init_llvm_jit_functions_stage1(WASMModule* module_, char* error_buf, uint error_buf_size) {
    AOTCompOption option = { 0 };
    char* aot_last_error = void;
    ulong size = void;

    if (module_.function_count == 0)
        return true;

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LLVM_JIT != 0) {
    if (os_mutex_init(&module_.tierup_wait_lock) != 0) {
        set_error_buf(error_buf, error_buf_size, "init jit tierup lock failed");
        return false;
    }
    if (os_cond_init(&module_.tierup_wait_cond) != 0) {
        set_error_buf(error_buf, error_buf_size, "init jit tierup cond failed");
        os_mutex_destroy(&module_.tierup_wait_lock);
        return false;
    }
    module_.tierup_wait_lock_inited = true;
}

    size = sizeofcast(void*) * cast(ulong)module_.function_count
           + bool.sizeof * cast(ulong)module_.function_count;
    if (((module_.func_ptrs = loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }
    module_.func_ptrs_compiled =
        cast(bool*)(cast(ubyte*)module_.func_ptrs
                 + (void*).sizeof * module_.function_count);

    module_.comp_data = aot_create_comp_data(module_);
    if (!module_.comp_data) {
        aot_last_error = aot_get_last_error();
        bh_assert(aot_last_error != null);
        set_error_buf(error_buf, error_buf_size, aot_last_error);
        return false;
    }

    option.is_jit_mode = true;
    option.opt_level = 3;
    option.size_level = 3;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    option.enable_bulk_memory = true;
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
    option.enable_thread_mgr = true;
}
static if (WASM_ENABLE_TAIL_CALL != 0) {
    option.enable_tail_call = true;
}
static if (WASM_ENABLE_SIMD != 0) {
    option.enable_simd = true;
}
static if (WASM_ENABLE_REF_TYPES != 0) {
    option.enable_ref_types = true;
}
    option.enable_aux_stack_check = true;
static if ((WASM_ENABLE_PERF_PROFILING != 0) || (WASM_ENABLE_DUMP_CALL_STACK != 0)) {
    option.enable_aux_stack_frame = true;
}

    module_.comp_ctx = aot_create_comp_context(module_.comp_data, &option);
    if (!module_.comp_ctx) {
        aot_last_error = aot_get_last_error();
        bh_assert(aot_last_error != null);
        set_error_buf(error_buf, error_buf_size, aot_last_error);
        return false;
    }

    return true;
}

private bool init_llvm_jit_functions_stage2(WASMModule* module_, char* error_buf, uint error_buf_size) {
    char* aot_last_error = void;
    uint i = void;

    if (module_.function_count == 0)
        return true;

    if (!aot_compile_wasm(module_.comp_ctx)) {
        aot_last_error = aot_get_last_error();
        bh_assert(aot_last_error != null);
        set_error_buf(error_buf, error_buf_size, aot_last_error);
        return false;
    }

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0) {
    if (module_.orcjit_stop_compiling)
        return false;
}

    bh_print_time("Begin to lookup llvm jit functions");

    for (i = 0; i < module_.function_count; i++) {
        LLVMOrcJITTargetAddress func_addr = 0;
        LLVMErrorRef error = void;
        char[48] func_name = void;

        snprintf(func_name.ptr, func_name.sizeof, "%s%d", AOT_FUNC_PREFIX, i);
        error = LLVMOrcLLLazyJITLookup(module_.comp_ctx.orc_jit, &func_addr,
                                       func_name.ptr);
        if (error != LLVMErrorSuccess) {
            char* err_msg = LLVMGetErrorMessage(error);
            char[96] buf = void;
            snprintf(buf.ptr, buf.sizeof,
                     "failed to compile llvm jit function: %s", err_msg);
            set_error_buf(error_buf, error_buf_size, buf.ptr);
            LLVMDisposeErrorMessage(err_msg);
            return false;
        }

        /**
         * No need to lock the func_ptr[func_idx] here as it is basic
         * data type, the load/store for it can be finished by one cpu
         * instruction, and there can be only one cpu instruction
         * loading/storing at the same time.
         */
        module_.func_ptrs[i] = cast(void*)func_addr;

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0) {
        if (module_.orcjit_stop_compiling)
            return false;
}
    }

    bh_print_time("End lookup llvm jit functions");

    return true;
}
} /* end of WASM_ENABLE_JIT != 0 */

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0) {
private void* init_llvm_jit_functions_stage2_callback(void* arg) {
    WASMModule* module_ = cast(WASMModule*)arg;
    char[128] error_buf = void;
    uint error_buf_size = cast(uint)error_buf.sizeof;

    if (!init_llvm_jit_functions_stage2(module_, error_buf.ptr, error_buf_size)) {
        module_.orcjit_stop_compiling = true;
        return null;
    }

    os_mutex_lock(&module_.tierup_wait_lock);
    module_.llvm_jit_inited = true;
    os_cond_broadcast(&module_.tierup_wait_cond);
    os_mutex_unlock(&module_.tierup_wait_lock);

    return null;
}
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
/* The callback function to compile jit functions */
private void* orcjit_thread_callback(void* arg) {
    OrcJitThreadArg* thread_arg = cast(OrcJitThreadArg*)arg;
static if (WASM_ENABLE_JIT != 0) {
    AOTCompContext* comp_ctx = thread_arg.comp_ctx;
}
    WASMModule* module_ = thread_arg.module_;
    uint group_idx = thread_arg.group_idx;
    uint group_stride = WASM_ORC_JIT_BACKEND_THREAD_NUM;
    uint func_count = module_.function_count;
    uint i = void;

static if (WASM_ENABLE_FAST_JIT != 0) {
    /* Compile fast jit funcitons of this group */
    for (i = group_idx; i < func_count; i += group_stride) {
        if (!jit_compiler_compile(module_, i + module_.import_function_count)) {
            os_printf("failed to compile fast jit function %u\n", i);
            break;
        }

        if (module_.orcjit_stop_compiling) {
            return null;
        }
    }
}

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0) {
    /* For JIT tier-up, set each llvm jit func to call_to_fast_jit */
    for (i = group_idx; i < func_count;
         i += group_stride * WASM_ORC_JIT_COMPILE_THREAD_NUM) {
        uint j = void;

        for (j = 0; j < WASM_ORC_JIT_COMPILE_THREAD_NUM; j++) {
            if (i + j * group_stride < func_count) {
                if (!jit_compiler_set_call_to_fast_jit(
                        module_,
                        i + j * group_stride + module_.import_function_count)) {
                    os_printf(
                        "failed to compile call_to_fast_jit for func %u\n",
                        i + j * group_stride + module_.import_function_count);
                    module_.orcjit_stop_compiling = true;
                    return null;
                }
            }
            if (module_.orcjit_stop_compiling) {
                return null;
            }
        }
    }

    /* Wait until init_llvm_jit_functions_stage2 finishes */
    os_mutex_lock(&module_.tierup_wait_lock);
    while (!module_.llvm_jit_inited) {
        os_cond_reltimedwait(&module_.tierup_wait_cond,
                             &module_.tierup_wait_lock, 10);
        if (module_.orcjit_stop_compiling) {
            /* init_llvm_jit_functions_stage2 failed */
            os_mutex_unlock(&module_.tierup_wait_lock);
            return null;
        }
    }
    os_mutex_unlock(&module_.tierup_wait_lock);
}

static if (WASM_ENABLE_JIT != 0) {
    /* Compile llvm jit functions of this group */
    for (i = group_idx; i < func_count;
         i += group_stride * WASM_ORC_JIT_COMPILE_THREAD_NUM) {
        LLVMOrcJITTargetAddress func_addr = 0;
        LLVMErrorRef error = void;
        char[48] func_name = void;
        alias F = void function();
        union _U {
            F f = void;
            void* v = void;
        }_U u = void;
        uint j = void;

        snprintf(func_name.ptr, func_name.sizeof, "%s%d%s", AOT_FUNC_PREFIX, i,
                 "_wrapper");
        LOG_DEBUG("compile llvm jit func %s", func_name.ptr);
        error =
            LLVMOrcLLLazyJITLookup(comp_ctx.orc_jit, &func_addr, func_name.ptr);
        if (error != LLVMErrorSuccess) {
            char* err_msg = LLVMGetErrorMessage(error);
            os_printf("failed to compile llvm jit function %u: %s", i, err_msg);
            LLVMDisposeErrorMessage(err_msg);
            break;
        }

        /* Call the jit wrapper function to trigger its compilation, so as
           to compile the actual jit functions, since we add the latter to
           function list in the PartitionFunction callback */
        u.v = cast(void*)func_addr;
        u.f();

        for (j = 0; j < WASM_ORC_JIT_COMPILE_THREAD_NUM; j++) {
            if (i + j * group_stride < func_count) {
                module_.func_ptrs_compiled[i + j * group_stride] = true;
static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0) {
                snprintf(func_name.ptr, func_name.sizeof, "%s%d", AOT_FUNC_PREFIX,
                         i + j * group_stride);
                error = LLVMOrcLLLazyJITLookup(comp_ctx.orc_jit, &func_addr,
                                               func_name.ptr);
                if (error != LLVMErrorSuccess) {
                    char* err_msg = LLVMGetErrorMessage(error);
                    os_printf("failed to compile llvm jit function %u: %s", i,
                              err_msg);
                    LLVMDisposeErrorMessage(err_msg);
                    /* Ignore current llvm jit func, as its func ptr is
                       previous set to call_to_fast_jit, which also works */
                    continue;
                }

                jit_compiler_set_llvm_jit_func_ptr(
                    module_,
                    i + j * group_stride + module_.import_function_count,
                    cast(void*)func_addr);

                /* Try to switch to call this llvm jit funtion instead of
                   fast jit function from fast jit jitted code */
                jit_compiler_set_call_to_llvm_jit(
                    module_,
                    i + j * group_stride + module_.import_function_count);
}
            }
        }

        if (module_.orcjit_stop_compiling) {
            break;
        }
    }
}

    return null;
}

private void orcjit_stop_compile_threads(WASMModule* module_) {
    uint i = void, thread_num = (uint32)(sizeof(module_.orcjit_thread_args)
                                    / OrcJitThreadArg.sizeof);

    module_.orcjit_stop_compiling = true;
    for (i = 0; i < thread_num; i++) {
        if (module_.orcjit_threads[i])
            os_thread_join(module_.orcjit_threads[i], null);
    }
}

private bool compile_jit_functions(WASMModule* module_, char* error_buf, uint error_buf_size) {
    uint thread_num = (uint32)(sizeof(module_.orcjit_thread_args) / OrcJitThreadArg.sizeof);
    uint i = void, j = void;

    bh_print_time("Begin to compile jit functions");

    /* Create threads to compile the jit functions */
    for (i = 0; i < thread_num && i < module_.function_count; i++) {
static if (WASM_ENABLE_JIT != 0) {
        module_.orcjit_thread_args[i].comp_ctx = module_.comp_ctx;
}
        module_.orcjit_thread_args[i].module_ = module_;
        module_.orcjit_thread_args[i].group_idx = i;

        if (os_thread_create(&module_.orcjit_threads[i], &orcjit_thread_callback,
                             cast(void*)&module_.orcjit_thread_args[i],
                             APP_THREAD_STACK_SIZE_DEFAULT)
            != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "create orcjit compile thread failed");
            /* Terminate the threads created */
            module_.orcjit_stop_compiling = true;
            for (j = 0; j < i; j++) {
                os_thread_join(module_.orcjit_threads[j], null);
            }
            return false;
        }
    }

static if (WASM_ENABLE_LAZY_JIT == 0) {
    /* Wait until all jit functions are compiled for eager mode */
    for (i = 0; i < thread_num; i++) {
        if (module_.orcjit_threads[i])
            os_thread_join(module_.orcjit_threads[i], null);
    }

static if (WASM_ENABLE_FAST_JIT != 0) {
    /* Ensure all the fast-jit functions are compiled */
    for (i = 0; i < module_.function_count; i++) {
        if (!jit_compiler_is_compiled(module_,
                                      i + module_.import_function_count)) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to compile fast jit function");
            return false;
        }
    }
}

static if (WASM_ENABLE_JIT != 0) {
    /* Ensure all the llvm-jit functions are compiled */
    for (i = 0; i < module_.function_count; i++) {
        if (!module_.func_ptrs_compiled[i]) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to compile llvm jit function");
            return false;
        }
    }
}
} /* end of WASM_ENABLE_LAZY_JIT == 0 */

    bh_print_time("End compile jit functions");

    return true;
}
} /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 */

static if (WASM_ENABLE_REF_TYPES != 0) {
private bool get_table_elem_type(const(WASMModule)* module_, uint table_idx, ubyte* p_elem_type, char* error_buf, uint error_buf_size) {
    if (!check_table_index(module_, table_idx, error_buf, error_buf_size)) {
        return false;
    }

    if (p_elem_type) {
        if (table_idx < module_.import_table_count)
            *p_elem_type = module_.import_tables[table_idx].u.table.elem_type;
        else
            *p_elem_type =
                module_.tables[module_.import_table_count + table_idx]
                    .elem_type;
    }
    return true;
}

private bool get_table_seg_elem_type(const(WASMModule)* module_, uint table_seg_idx, ubyte* p_elem_type, char* error_buf, uint error_buf_size) {
    if (table_seg_idx >= module_.table_seg_count) {
        return false;
    }

    if (p_elem_type) {
        *p_elem_type = module_.table_segments[table_seg_idx].elem_type;
    }
    return true;
}
}

private bool wasm_loader_prepare_bytecode(WASMModule* module_, WASMFunction* func, uint cur_func_idx, char* error_buf, uint error_buf_size);

static if (WASM_ENABLE_FAST_INTERP != 0 && WASM_ENABLE_LABELS_AS_VALUES != 0) {
void** wasm_interp_get_handle_table();

private void** handle_table;
}

private bool load_from_sections(WASMModule* module_, WASMSection* sections, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    WASMExport* export_ = void;
    WASMSection* section = sections;
    const(ubyte)* buf = void, buf_end = void, buf_code = null, buf_code_end = null, buf_func = null, buf_func_end = null;
    WASMGlobal* aux_data_end_global = null, aux_heap_base_global = null;
    WASMGlobal* aux_stack_top_global = null, global = void;
    uint aux_data_end = (uint32)-1, aux_heap_base = (uint32)-1;
    uint aux_stack_top = (uint32)-1, global_index = void, func_index = void, i = void;
    uint aux_data_end_global_index = (uint32)-1;
    uint aux_heap_base_global_index = (uint32)-1;
    WASMType* func_type = void;

    /* Find code and function sections if have */
    while (section) {
        if (section.section_type == SECTION_TYPE_CODE) {
            buf_code = section.section_body;
            buf_code_end = buf_code + section.section_body_size;
        }
        else if (section.section_type == SECTION_TYPE_FUNC) {
            buf_func = section.section_body;
            buf_func_end = buf_func + section.section_body_size;
        }
        section = section.next;
    }

    section = sections;
    while (section) {
        buf = section.section_body;
        buf_end = buf + section.section_body_size;
        LOG_DEBUG("load section, type: %d", section.section_type);
        switch (section.section_type) {
            case SECTION_TYPE_USER:
                /* unsupported user section, ignore it. */
                if (!load_user_section(buf, buf_end, module_,
                                       is_load_from_file_buf, error_buf,
                                       error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_TYPE:
                if (!load_type_section(buf, buf_end, module_, error_buf,
                                       error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_IMPORT:
                if (!load_import_section(buf, buf_end, module_,
                                         is_load_from_file_buf, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_FUNC:
                if (!load_function_section(buf, buf_end, buf_code, buf_code_end,
                                           module_, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_TABLE:
                if (!load_table_section(buf, buf_end, module_, error_buf,
                                        error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_MEMORY:
                if (!load_memory_section(buf, buf_end, module_, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_GLOBAL:
                if (!load_global_section(buf, buf_end, module_, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_EXPORT:
                if (!load_export_section(buf, buf_end, module_,
                                         is_load_from_file_buf, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_START:
                if (!load_start_section(buf, buf_end, module_, error_buf,
                                        error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_ELEM:
                if (!load_table_segment_section(buf, buf_end, module_, error_buf,
                                                error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_CODE:
                if (!load_code_section(buf, buf_end, buf_func, buf_func_end,
                                       module_, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_DATA:
                if (!load_data_segment_section(buf, buf_end, module_, error_buf,
                                               error_buf_size))
                    return false;
                break;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
            case SECTION_TYPE_DATACOUNT:
                if (!load_datacount_section(buf, buf_end, module_, error_buf,
                                            error_buf_size))
                    return false;
                break;
}
            default:
                set_error_buf(error_buf, error_buf_size, "invalid section id");
                return false;
        }

        section = section.next;
    }

    module_.aux_data_end_global_index = (uint32)-1;
    module_.aux_heap_base_global_index = (uint32)-1;
    module_.aux_stack_top_global_index = (uint32)-1;

    /* Resolve auxiliary data/stack/heap info and reset memory info */
    export_ = module_.exports;
    for (i = 0; i < module_.export_count; i++, export_ ++) {
        if (export_.kind == EXPORT_KIND_GLOBAL) {
            if (!strcmp(export_.name, "__heap_base")) {
                global_index = export_.index - module_.import_global_count;
                global = module_.globals + global_index;
                if (global.type == VALUE_TYPE_I32 && !global.is_mutable
                    && global.init_expr.init_expr_type
                           == INIT_EXPR_TYPE_I32_CONST) {
                    aux_heap_base_global = global;
                    aux_heap_base = global.init_expr.u.i32;
                    aux_heap_base_global_index = export_.index;
                    LOG_VERBOSE("Found aux __heap_base global, value: %d",
                                aux_heap_base);
                }
            }
            else if (!strcmp(export_.name, "__data_end")) {
                global_index = export_.index - module_.import_global_count;
                global = module_.globals + global_index;
                if (global.type == VALUE_TYPE_I32 && !global.is_mutable
                    && global.init_expr.init_expr_type
                           == INIT_EXPR_TYPE_I32_CONST) {
                    aux_data_end_global = global;
                    aux_data_end = global.init_expr.u.i32;
                    aux_data_end_global_index = export_.index;
                    LOG_VERBOSE("Found aux __data_end global, value: %d",
                                aux_data_end);

                    aux_data_end = align_uint(aux_data_end, 16);
                }
            }

            /* For module compiled with -pthread option, the global is:
                [0] stack_top       <-- 0
                [1] tls_pointer
                [2] tls_size
                [3] data_end        <-- 3
                [4] global_base
                [5] heap_base       <-- 5
                [6] dso_handle

                For module compiled without -pthread option:
                [0] stack_top       <-- 0
                [1] data_end        <-- 1
                [2] global_base
                [3] heap_base       <-- 3
                [4] dso_handle
            */
            if (aux_data_end_global && aux_heap_base_global
                && aux_data_end <= aux_heap_base) {
                module_.aux_data_end_global_index = aux_data_end_global_index;
                module_.aux_data_end = aux_data_end;
                module_.aux_heap_base_global_index = aux_heap_base_global_index;
                module_.aux_heap_base = aux_heap_base;

                /* Resolve aux stack top global */
                for (global_index = 0; global_index < module_.global_count;
                     global_index++) {
                    global = module_.globals + global_index;
                    if (global.is_mutable /* heap_base and data_end is
                                              not mutable */
                        && global.type == VALUE_TYPE_I32
                        && global.init_expr.init_expr_type
                               == INIT_EXPR_TYPE_I32_CONST
                        && cast(uint)global.init_expr.u.i32 <= aux_heap_base) {
                        aux_stack_top_global = global;
                        aux_stack_top = cast(uint)global.init_expr.u.i32;
                        module_.aux_stack_top_global_index =
                            module_.import_global_count + global_index;
                        module_.aux_stack_bottom = aux_stack_top;
                        module_.aux_stack_size =
                            aux_stack_top > aux_data_end
                                ? aux_stack_top - aux_data_end
                                : aux_stack_top;
                        LOG_VERBOSE("Found aux stack top global, value: %d, "
                                    ~ "global index: %d, stack size: %d",
                                    aux_stack_top, global_index,
                                    module_.aux_stack_size);
                        break;
                    }
                }
                if (!aux_stack_top_global) {
                    /* Auxiliary stack global isn't found, it must be unused
                       in the wasm app, as if it is used, the global must be
                       defined. Here we set it to __heap_base global and set
                       its size to 0. */
                    aux_stack_top_global = aux_heap_base_global;
                    aux_stack_top = aux_heap_base;
                    module_.aux_stack_top_global_index =
                        module_.aux_heap_base_global_index;
                    module_.aux_stack_bottom = aux_stack_top;
                    module_.aux_stack_size = 0;
                }
                break;
            }
        }
    }

    module_.malloc_function = (uint32)-1;
    module_.free_function = (uint32)-1;
    module_.retain_function = (uint32)-1;

    /* Resolve malloc/free function exported by wasm module */
    export_ = module_.exports;
    for (i = 0; i < module_.export_count; i++, export_ ++) {
        if (export_.kind == EXPORT_KIND_FUNC) {
            if (!strcmp(export_.name, "malloc")
                && export_.index >= module_.import_function_count) {
                func_index = export_.index - module_.import_function_count;
                func_type = module_.functions[func_index].func_type;
                if (func_type.param_count == 1 && func_type.result_count == 1
                    && func_type.types[0] == VALUE_TYPE_I32
                    && func_type.types[1] == VALUE_TYPE_I32) {
                    bh_assert(module_.malloc_function == (uint32)-1);
                    module_.malloc_function = export_.index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                export_.name, export_.index);
                }
            }
            else if (!strcmp(export_.name, "__new")
                     && export_.index >= module_.import_function_count) {
                /* __new && __pin for AssemblyScript */
                func_index = export_.index - module_.import_function_count;
                func_type = module_.functions[func_index].func_type;
                if (func_type.param_count == 2 && func_type.result_count == 1
                    && func_type.types[0] == VALUE_TYPE_I32
                    && func_type.types[1] == VALUE_TYPE_I32
                    && func_type.types[2] == VALUE_TYPE_I32) {
                    uint j = void;
                    WASMExport* export_tmp = void;

                    bh_assert(module_.malloc_function == (uint32)-1);
                    module_.malloc_function = export_.index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                export_.name, export_.index);

                    /* resolve retain function.
                       If not found, reset malloc function index */
                    export_tmp = module_.exports;
                    for (j = 0; j < module_.export_count; j++, export_tmp++) {
                        if ((export_tmp.kind == EXPORT_KIND_FUNC)
                            && (!strcmp(export_tmp.name, "__retain")
                                || !strcmp(export_tmp.name, "__pin"))
                            && (export_tmp.index
                                >= module_.import_function_count)) {
                            func_index = export_tmp.index
                                         - module_.import_function_count;
                            func_type =
                                module_.functions[func_index].func_type;
                            if (func_type.param_count == 1
                                && func_type.result_count == 1
                                && func_type.types[0] == VALUE_TYPE_I32
                                && func_type.types[1] == VALUE_TYPE_I32) {
                                bh_assert(module_.retain_function
                                          == (uint32)-1);
                                module_.retain_function = export_tmp.index;
                                LOG_VERBOSE("Found retain function, name: %s, "
                                            ~ "index: %u",
                                            export_tmp.name,
                                            export_tmp.index);
                                break;
                            }
                        }
                    }
                    if (j == module_.export_count) {
                        module_.malloc_function = (uint32)-1;
                        LOG_VERBOSE("Can't find retain function,"
                                    ~ "reset malloc function index to -1");
                    }
                }
            }
            else if (((!strcmp(export_.name, "free"))
                      || (!strcmp(export_.name, "__release"))
                      || (!strcmp(export_.name, "__unpin")))
                     && export_.index >= module_.import_function_count) {
                func_index = export_.index - module_.import_function_count;
                func_type = module_.functions[func_index].func_type;
                if (func_type.param_count == 1 && func_type.result_count == 0
                    && func_type.types[0] == VALUE_TYPE_I32) {
                    bh_assert(module_.free_function == (uint32)-1);
                    module_.free_function = export_.index;
                    LOG_VERBOSE("Found free function, name: %s, index: %u",
                                export_.name, export_.index);
                }
            }
        }
    }

static if (WASM_ENABLE_FAST_INTERP != 0 && WASM_ENABLE_LABELS_AS_VALUES != 0) {
    handle_table = wasm_interp_get_handle_table();
}

    for (i = 0; i < module_.function_count; i++) {
        WASMFunction* func = module_.functions[i];
        if (!wasm_loader_prepare_bytecode(module_, func, i, error_buf,
                                          error_buf_size)) {
            return false;
        }

        if (i == module_.function_count - 1) {
            bh_assert(func.code + func.code_size == buf_code_end);
        }
    }

    if (!module_.possible_memory_grow) {
        WASMMemoryImport* memory_import = void;
        WASMMemory* memory = void;

        if (aux_data_end_global && aux_heap_base_global
            && aux_stack_top_global) {
            ulong init_memory_size = void;
            uint shrunk_memory_size = align_uint(aux_heap_base, 8);

            if (module_.import_memory_count) {
                memory_import = &module_.import_memories[0].u.memory;
                init_memory_size = cast(ulong)memory_import.num_bytes_per_page
                                   * memory_import.init_page_count;
                if (shrunk_memory_size <= init_memory_size) {
                    /* Reset memory info to decrease memory usage */
                    memory_import.num_bytes_per_page = shrunk_memory_size;
                    memory_import.init_page_count = 1;
                    LOG_VERBOSE("Shrink import memory size to %d",
                                shrunk_memory_size);
                }
            }
            if (module_.memory_count) {
                memory = &module_.memories[0];
                init_memory_size = cast(ulong)memory.num_bytes_per_page
                                   * memory.init_page_count;
                if (shrunk_memory_size <= init_memory_size) {
                    /* Reset memory info to decrease memory usage */
                    memory.num_bytes_per_page = shrunk_memory_size;
                    memory.init_page_count = 1;
                    LOG_VERBOSE("Shrink memory size to %d", shrunk_memory_size);
                }
            }
        }

        if (module_.import_memory_count) {
            memory_import = &module_.import_memories[0].u.memory;
            if (memory_import.init_page_count < DEFAULT_MAX_PAGES)
                memory_import.num_bytes_per_page *=
                    memory_import.init_page_count;
            else
                memory_import.num_bytes_per_page = UINT32_MAX;

            if (memory_import.init_page_count > 0)
                memory_import.init_page_count = memory_import.max_page_count =
                    1;
            else
                memory_import.init_page_count = memory_import.max_page_count =
                    0;
        }

        if (module_.memory_count) {
            memory = &module_.memories[0];
            if (memory.init_page_count < DEFAULT_MAX_PAGES)
                memory.num_bytes_per_page *= memory.init_page_count;
            else
                memory.num_bytes_per_page = UINT32_MAX;

            if (memory.init_page_count > 0)
                memory.init_page_count = memory.max_page_count = 1;
            else
                memory.init_page_count = memory.max_page_count = 0;
        }
    }

    calculate_global_data_offset(module_);

static if (WASM_ENABLE_FAST_JIT != 0) {
    if (!init_fast_jit_functions(module_, error_buf, error_buf_size)) {
        return false;
    }
}

static if (WASM_ENABLE_JIT != 0) {
    if (!init_llvm_jit_functions_stage1(module_, error_buf, error_buf_size)) {
        return false;
    }
static if (!(WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0)) {
    if (!init_llvm_jit_functions_stage2(module_, error_buf, error_buf_size)) {
        return false;
    }
} else {
    /* Run aot_compile_wasm in a backend thread, so as not to block the main
       thread fast jit execution, since applying llvm optimizations in
       aot_compile_wasm may cost a lot of time.
       Create thread with enough native stack to apply llvm optimizations */
    if (os_thread_create(&module_.llvm_jit_init_thread,
                         &init_llvm_jit_functions_stage2_callback,
                         cast(void*)module_, APP_THREAD_STACK_SIZE_DEFAULT * 8)
        != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "create orcjit compile thread failed");
        return false;
    }
}
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
    /* Create threads to compile the jit functions */
    if (!compile_jit_functions(module_, error_buf, error_buf_size)) {
        return false;
    }
}

static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    wasm_runtime_dump_module_mem_consumption(module_);
}
    return true;
}

private WASMModule* create_module(char* error_buf, uint error_buf_size) {
    WASMModule* module_ = loader_malloc(WASMModule.sizeof, error_buf, error_buf_size);
    bh_list_status ret = void;

    if (!module_) {
        return null;
    }

    module_.module_type = Wasm_Module_Bytecode;

    /* Set start_function to -1, means no start function */
    module_.start_function = (uint32)-1;

static if (WASM_ENABLE_FAST_INTERP == 0) {
    module_.br_table_cache_list = &module_.br_table_cache_list_head;
    ret = bh_list_init(module_.br_table_cache_list);
    bh_assert(ret == BH_LIST_SUCCESS);
}

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT && WASM_ENABLE_LAZY_JIT != 0) {
    if (os_mutex_init(&module_.instance_list_lock) != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "init instance list lock failed");
        wasm_runtime_free(module_);
        return null;
    }
}

    cast(void)ret;
    return module_;
}

WASMModule* wasm_loader_load_from_sections(WASMSection* section_list, char* error_buf, uint error_buf_size) {
    WASMModule* module_ = create_module(error_buf, error_buf_size);
    if (!module_)
        return null;

    if (!load_from_sections(module_, section_list, false, error_buf,
                            error_buf_size)) {
        wasm_loader_unload(module_);
        return null;
    }

    LOG_VERBOSE("Load module from sections success.\n");
    return module_;
}

private void destroy_sections(WASMSection* section_list) {
    WASMSection* section = section_list, next = void;
    while (section) {
        next = section.next;
        wasm_runtime_free(section);
        section = next;
    }
}

/* clang-format off */
private ubyte[13] section_ids = [
    SECTION_TYPE_USER,
    SECTION_TYPE_TYPE,
    SECTION_TYPE_IMPORT,
    SECTION_TYPE_FUNC,
    SECTION_TYPE_TABLE,
    SECTION_TYPE_MEMORY,
    SECTION_TYPE_GLOBAL,
    SECTION_TYPE_EXPORT,
    SECTION_TYPE_START,
    SECTION_TYPE_ELEM,
#if WASM_ENABLE_BULK_MEMORY != 0
    SECTION_TYPE_DATACOUNT,
#endif
    SECTION_TYPE_CODE,
    SECTION_TYPE_DATA
];
/* clang-format on */

private ubyte get_section_index(ubyte section_type) {
    ubyte max_id = section_ids.sizeof / uint8.sizeof;

    for (ubyte i = 0; i < max_id; i++) {
        if (section_type == section_ids[i])
            return i;
    }

    return (uint8)-1;
}

private bool create_sections(const(ubyte)* buf, uint size, WASMSection** p_section_list, char* error_buf, uint error_buf_size) {
    WASMSection* section_list_end = null, section = void;
    const(ubyte)* p = buf, p_end = buf + size;
    ubyte section_type = void, section_index = void, last_section_index = (uint8)-1;
    uint section_size = void;

    bh_assert(!*p_section_list);

    p += 8;
    while (p < p_end) {
        CHECK_BUF(p, p_end, 1);
        section_type = read_uint8(p);
        section_index = get_section_index(section_type);
        if (section_index != (uint8)-1) {
            if (section_type != SECTION_TYPE_USER) {
                /* Custom sections may be inserted at any place,
                   while other sections must occur at most once
                   and in prescribed order. */
                bh_assert(last_section_index == (uint8)-1
                          || last_section_index < section_index);
                last_section_index = section_index;
            }
            read_leb_uint32(p, p_end, section_size);
            CHECK_BUF1(p, p_end, section_size);

            if (((section = loader_malloc(WASMSection.sizeof, error_buf,
                                          error_buf_size)) == 0)) {
                return false;
            }

            section.section_type = section_type;
            section.section_body = cast(ubyte*)p;
            section.section_body_size = section_size;

            if (!*p_section_list)
                *p_section_list = section_list_end = section;
            else {
                section_list_end.next = section;
                section_list_end = section;
            }

            p += section_size;
        }
        else {
            bh_assert(0);
        }
    }

    cast(void)last_section_index;
    return true;
}

private void exchange32(ubyte* p_data) {
    ubyte value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;

    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

union ___ue {
    int a;
    char b = 0;
}private ___ue __ue = { a: 1 };

enum string is_little_endian() = ` (__ue.b == 1)`;

private bool load(const(ubyte)* buf, uint size, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf_end = buf + size;
    const(ubyte)* p = buf, p_end = buf_end;
    uint magic_number = void, version_ = void;
    WASMSection* section_list = null;

    CHECK_BUF1(p, p_end, uint32.sizeof);
    magic_number = read_uint32(p);
    if (!is_little_endian())
        exchange32(cast(ubyte*)&magic_number);

    bh_assert(magic_number == WASM_MAGIC_NUMBER);

    CHECK_BUF1(p, p_end, uint32.sizeof);
    version_ = read_uint32(p);
    if (!is_little_endian())
        exchange32(cast(ubyte*)&version_);

    if (version_ != WASM_CURRENT_VERSION) {
        set_error_buf(error_buf, error_buf_size, "unknown binary version");
        return false;
    }

    if (!create_sections(buf, size, &section_list, error_buf, error_buf_size)
        || !load_from_sections(module_, section_list, true, error_buf,
                               error_buf_size)) {
        destroy_sections(section_list);
        return false;
    }

    destroy_sections(section_list);
    cast(void)p_end;
    return true;
}

WASMModule* wasm_loader_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size) {
    WASMModule* module_ = create_module(error_buf, error_buf_size);
    if (!module_) {
        return null;
    }

static if (WASM_ENABLE_FAST_JIT != 0) {
    module_.load_addr = cast(ubyte*)buf;
    module_.load_size = size;
}

    if (!load(buf, size, module_, error_buf, error_buf_size)) {
        goto fail;
    }

    LOG_VERBOSE("Load module success.\n");
    return module_;

fail:
    wasm_loader_unload(module_);
    return null;
}

void wasm_loader_unload(WASMModule* module_) {
    uint i = void;

    if (!module_)
        return;

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT && WASM_ENABLE_LAZY_JIT != 0) {
    module_.orcjit_stop_compiling = true;
    if (module_.llvm_jit_init_thread)
        os_thread_join(module_.llvm_jit_init_thread, null);
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0) {
    /* Stop Fast/LLVM JIT compilation firstly to avoid accessing
       module internal data after they were freed */
    orcjit_stop_compile_threads(module_);
}

static if (WASM_ENABLE_JIT != 0) {
    if (module_.func_ptrs)
        wasm_runtime_free(module_.func_ptrs);
    if (module_.comp_ctx)
        aot_destroy_comp_context(module_.comp_ctx);
    if (module_.comp_data)
        aot_destroy_comp_data(module_.comp_data);
}

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT && WASM_ENABLE_LAZY_JIT != 0) {
    if (module_.tierup_wait_lock_inited) {
        os_mutex_destroy(&module_.tierup_wait_lock);
        os_cond_destroy(&module_.tierup_wait_cond);
    }
}

    if (module_.types) {
        for (i = 0; i < module_.type_count; i++) {
            if (module_.types[i])
                destroy_wasm_type(module_.types[i]);
        }
        wasm_runtime_free(module_.types);
    }

    if (module_.imports)
        wasm_runtime_free(module_.imports);

    if (module_.functions) {
        for (i = 0; i < module_.function_count; i++) {
            if (module_.functions[i]) {
                if (module_.functions[i].local_offsets)
                    wasm_runtime_free(module_.functions[i].local_offsets);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                if (module_.functions[i].code_compiled)
                    wasm_runtime_free(module_.functions[i].code_compiled);
                if (module_.functions[i].consts)
                    wasm_runtime_free(module_.functions[i].consts);
}
static if (WASM_ENABLE_FAST_JIT != 0) {
                if (module_.functions[i].fast_jit_jitted_code) {
                    jit_code_cache_free(
                        module_.functions[i].fast_jit_jitted_code);
                }
static if (WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0) {
                if (module_.functions[i].llvm_jit_func_ptr) {
                    jit_code_cache_free(
                        module_.functions[i].llvm_jit_func_ptr);
                }
}
}
                wasm_runtime_free(module_.functions[i]);
            }
        }
        wasm_runtime_free(module_.functions);
    }

    if (module_.tables)
        wasm_runtime_free(module_.tables);

    if (module_.memories)
        wasm_runtime_free(module_.memories);

    if (module_.globals)
        wasm_runtime_free(module_.globals);

    if (module_.exports)
        wasm_runtime_free(module_.exports);

    if (module_.table_segments) {
        for (i = 0; i < module_.table_seg_count; i++) {
            if (module_.table_segments[i].func_indexes)
                wasm_runtime_free(module_.table_segments[i].func_indexes);
        }
        wasm_runtime_free(module_.table_segments);
    }

    if (module_.data_segments) {
        for (i = 0; i < module_.data_seg_count; i++) {
            if (module_.data_segments[i])
                wasm_runtime_free(module_.data_segments[i]);
        }
        wasm_runtime_free(module_.data_segments);
    }

    if (module_.const_str_list) {
        StringNode* node = module_.const_str_list, node_next = void;
        while (node) {
            node_next = node.next;
            wasm_runtime_free(node);
            node = node_next;
        }
    }

static if (WASM_ENABLE_FAST_INTERP == 0) {
    if (module_.br_table_cache_list) {
        BrTableCache* node = bh_list_first_elem(module_.br_table_cache_list);
        BrTableCache* node_next = void;
        while (node) {
            node_next = bh_list_elem_next(node);
            wasm_runtime_free(node);
            node = node_next;
        }
    }
}

static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT && WASM_ENABLE_LAZY_JIT != 0) {
    os_mutex_destroy(&module_.instance_list_lock);
}

static if (WASM_ENABLE_FAST_JIT != 0) {
    if (module_.fast_jit_func_ptrs) {
        wasm_runtime_free(module_.fast_jit_func_ptrs);
    }

    for (i = 0; i < WASM_ORC_JIT_BACKEND_THREAD_NUM; i++) {
        if (module_.fast_jit_thread_locks_inited[i]) {
            os_mutex_destroy(&module_.fast_jit_thread_locks[i]);
        }
    }
}

    wasm_runtime_free(module_);
}

bool wasm_loader_find_block_addr(WASMExecEnv* exec_env, BlockAddr* block_addr_cache, const(ubyte)* start_addr, const(ubyte)* code_end_addr, ubyte label_type, ubyte** p_else_addr, ubyte** p_end_addr) {
    const(ubyte)* p = start_addr, p_end = code_end_addr;
    ubyte* else_addr = null;
    char[128] error_buf = void;
    uint block_nested_depth = 1, count = void, i = void, j = void, t = void;
    uint error_buf_size = error_buf.sizeof;
    ubyte opcode = void, u8 = void;
    BlockAddr[16] block_stack = 0; BlockAddr* block = void;

    i = (cast(uintptr_t)start_addr) & cast(uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
    block = block_addr_cache + BLOCK_ADDR_CONFLICT_SIZE * i;

    for (j = 0; j < BLOCK_ADDR_CONFLICT_SIZE; j++) {
        if (block[j].start_addr == start_addr) {
            /* Cache hit */
            *p_else_addr = block[j].else_addr;
            *p_end_addr = block[j].end_addr;
            return true;
        }
    }

    /* Cache unhit */
    block_stack[0].start_addr = start_addr;

    while (p < code_end_addr) {
        opcode = *p++;

        switch (opcode) {
            case WASM_OP_UNREACHABLE:
            case WASM_OP_NOP:
                break;

            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
            case WASM_OP_IF:
                /* block result type: 0x40/0x7F/0x7E/0x7D/0x7C */
                u8 = read_uint8(p);
                if (block_nested_depth
                    < block_stack.sizeof / BlockAddr.sizeof) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = null;
                }
                block_nested_depth++;
                break;

            case EXT_OP_BLOCK:
            case EXT_OP_LOOP:
            case EXT_OP_IF:
                /* block type */
                skip_leb_uint32(p, p_end);
                if (block_nested_depth
                    < block_stack.sizeof / BlockAddr.sizeof) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = null;
                }
                block_nested_depth++;
                break;

            case WASM_OP_ELSE:
                if (label_type == LABEL_TYPE_IF && block_nested_depth == 1)
                    else_addr = cast(ubyte*)(p - 1);
                if (block_nested_depth - 1
                    < block_stack.sizeof / BlockAddr.sizeof)
                    block_stack[block_nested_depth - 1].else_addr =
                        cast(ubyte*)(p - 1);
                break;

            case WASM_OP_END:
                if (block_nested_depth == 1) {
                    if (label_type == LABEL_TYPE_IF)
                        *p_else_addr = else_addr;
                    *p_end_addr = cast(ubyte*)(p - 1);

                    block_stack[0].end_addr = cast(ubyte*)(p - 1);
                    for (t = 0; t < block_stack.sizeof / BlockAddr.sizeof;
                         t++) {
                        start_addr = block_stack[t].start_addr;
                        if (start_addr) {
                            i = (cast(uintptr_t)start_addr)
                                & cast(uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                            block =
                                block_addr_cache + BLOCK_ADDR_CONFLICT_SIZE * i;
                            for (j = 0; j < BLOCK_ADDR_CONFLICT_SIZE; j++)
                                if (!block[j].start_addr)
                                    break;

                            if (j == BLOCK_ADDR_CONFLICT_SIZE) {
                                memmove(block + 1, block,
                                        (BLOCK_ADDR_CONFLICT_SIZE - 1)
                                            * BlockAddr.sizeof);
                                j = 0;
                            }
                            block[j].start_addr = block_stack[t].start_addr;
                            block[j].else_addr = block_stack[t].else_addr;
                            block[j].end_addr = block_stack[t].end_addr;
                        }
                        else
                            break;
                    }
                    return true;
                }
                else {
                    block_nested_depth--;
                    if (block_nested_depth
                        < block_stack.sizeof / BlockAddr.sizeof)
                        block_stack[block_nested_depth].end_addr =
                            cast(ubyte*)(p - 1);
                }
                break;

            case WASM_OP_BR:
            case WASM_OP_BR_IF:
                skip_leb_uint32(p, p_end); /* labelidx */
                break;

            case WASM_OP_BR_TABLE:
                read_leb_uint32(p, p_end, count); /* lable num */
static if (WASM_ENABLE_FAST_INTERP != 0) {
                for (i = 0; i <= count; i++) /* lableidxs */
                    skip_leb_uint32(p, p_end);
} else {
                p += count + 1;
                while (*p == WASM_OP_NOP)
                    p++;
}
                break;

static if (WASM_ENABLE_FAST_INTERP == 0) {
            case EXT_OP_BR_TABLE_CACHE:
                read_leb_uint32(p, p_end, count); /* lable num */
                while (*p == WASM_OP_NOP)
                    p++;
                break;
}

            case WASM_OP_RETURN:
                break;

            case WASM_OP_CALL:
static if (WASM_ENABLE_TAIL_CALL != 0) {
            case WASM_OP_RETURN_CALL:
}
                skip_leb_uint32(p, p_end); /* funcidx */
                break;

            case WASM_OP_CALL_INDIRECT:
static if (WASM_ENABLE_TAIL_CALL != 0) {
            case WASM_OP_RETURN_CALL_INDIRECT:
}
                skip_leb_uint32(p, p_end); /* typeidx */
                CHECK_BUF(p, p_end, 1);
                u8 = read_uint8(p); /* 0x00 */
                break;

            case WASM_OP_DROP:
            case WASM_OP_SELECT:
            case WASM_OP_DROP_64:
            case WASM_OP_SELECT_64:
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case WASM_OP_SELECT_T:
                skip_leb_uint32(p, p_end); /* vec length */
                CHECK_BUF(p, p_end, 1);
                u8 = read_uint8(p); /* typeidx */
                break;
            case WASM_OP_TABLE_GET:
            case WASM_OP_TABLE_SET:
                skip_leb_uint32(p, p_end); /* table index */
                break;
            case WASM_OP_REF_NULL:
                CHECK_BUF(p, p_end, 1);
                u8 = read_uint8(p); /* type */
                break;
            case WASM_OP_REF_IS_NULL:
                break;
            case WASM_OP_REF_FUNC:
                skip_leb_uint32(p, p_end); /* func index */
                break;
} /* WASM_ENABLE_REF_TYPES */
            case WASM_OP_GET_LOCAL:
            case WASM_OP_SET_LOCAL:
            case WASM_OP_TEE_LOCAL:
            case WASM_OP_GET_GLOBAL:
            case WASM_OP_SET_GLOBAL:
            case WASM_OP_GET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_AUX_STACK:
                skip_leb_uint32(p, p_end); /* localidx */
                break;

            case EXT_OP_GET_LOCAL_FAST:
            case EXT_OP_SET_LOCAL_FAST:
            case EXT_OP_TEE_LOCAL_FAST:
                CHECK_BUF(p, p_end, 1);
                p++;
                break;

            case WASM_OP_I32_LOAD:
            case WASM_OP_I64_LOAD:
            case WASM_OP_F32_LOAD:
            case WASM_OP_F64_LOAD:
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
            case WASM_OP_I32_STORE:
            case WASM_OP_I64_STORE:
            case WASM_OP_F32_STORE:
            case WASM_OP_F64_STORE:
            case WASM_OP_I32_STORE8:
            case WASM_OP_I32_STORE16:
            case WASM_OP_I64_STORE8:
            case WASM_OP_I64_STORE16:
            case WASM_OP_I64_STORE32:
                skip_leb_uint32(p, p_end); /* align */
                skip_leb_uint32(p, p_end); /* offset */
                break;

            case WASM_OP_MEMORY_SIZE:
            case WASM_OP_MEMORY_GROW:
                skip_leb_uint32(p, p_end); /* 0x00 */
                break;

            case WASM_OP_I32_CONST:
                skip_leb_int32(p, p_end);
                break;
            case WASM_OP_I64_CONST:
                skip_leb_int64(p, p_end);
                break;
            case WASM_OP_F32_CONST:
                p += float32.sizeof;
                break;
            case WASM_OP_F64_CONST:
                p += float64.sizeof;
                break;

            case WASM_OP_I32_EQZ:
            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
            case WASM_OP_I64_EQZ:
            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
            case WASM_OP_I32_WRAP_I64:
            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
            case WASM_OP_F32_DEMOTE_F64:
            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
            case WASM_OP_F64_PROMOTE_F32:
            case WASM_OP_I32_REINTERPRET_F32:
            case WASM_OP_I64_REINTERPRET_F64:
            case WASM_OP_F32_REINTERPRET_I32:
            case WASM_OP_F64_REINTERPRET_I64:
            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                break;
            case WASM_OP_MISC_PREFIX:
            {
                uint opcode1 = void;

                read_leb_uint32(p, p_end, opcode1);

                switch (opcode1) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        break;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
                    case WASM_OP_MEMORY_INIT:
                        skip_leb_uint32(p, p_end);
                        /* skip memory idx */
                        p++;
                        break;
                    case WASM_OP_DATA_DROP:
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_MEMORY_COPY:
                        /* skip two memory idx */
                        p += 2;
                        break;
                    case WASM_OP_MEMORY_FILL:
                        /* skip memory idx */
                        p++;
                        break;
}
static if (WASM_ENABLE_REF_TYPES != 0) {
                    case WASM_OP_TABLE_INIT:
                    case WASM_OP_TABLE_COPY:
                        /* tableidx */
                        skip_leb_uint32(p, p_end);
                        /* elemidx */
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_ELEM_DROP:
                        /* elemidx */
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_TABLE_SIZE:
                    case WASM_OP_TABLE_GROW:
                    case WASM_OP_TABLE_FILL:
                        skip_leb_uint32(p, p_end); /* table idx */
                        break;
} /* WASM_ENABLE_REF_TYPES */
                    default:
                        bh_assert(0);
                        break;
                }
                break;
            }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            case WASM_OP_ATOMIC_PREFIX:
            {
                /* atomic_op (1 u8) + memarg (2 u32_leb) */
                opcode = read_uint8(p);
                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    skip_leb_uint32(p, p_end); /* align */
                    skip_leb_uint32(p, p_end); /* offset */
                }
                else {
                    /* atomic.fence doesn't have memarg */
                    p++;
                }
                break;
            }
}

            default:
                bh_assert(0);
                break;
        }
    }

    cast(void)u8;
    return false;
}

enum REF_I32 = VALUE_TYPE_I32;
enum REF_F32 = VALUE_TYPE_F32;
enum REF_I64_1 = VALUE_TYPE_I64;
enum REF_I64_2 = VALUE_TYPE_I64;
enum REF_F64_1 = VALUE_TYPE_F64;
enum REF_F64_2 = VALUE_TYPE_F64;
enum REF_ANY = VALUE_TYPE_ANY;

static if (WASM_ENABLE_FAST_INTERP != 0) {

static if (WASM_DEBUG_PREPROCESSOR != 0) {
enum string LOG_OP(...) = ` os_printf(__VA_ARGS__)`;
} else {
enum string LOG_OP(...) = ` (void)0`;
}

enum PATCH_ELSE = 0;
enum PATCH_END = 1;
struct BranchBlockPatch {
    BranchBlockPatch* next;
    ubyte patch_type;
    ubyte* code_compiled;
}
}

struct BranchBlock {
    ubyte label_type;
    BlockType block_type;
    ubyte* start_addr;
    ubyte* else_addr;
    ubyte* end_addr;
    uint stack_cell_num;
static if (WASM_ENABLE_FAST_INTERP != 0) {
    ushort dynamic_offset;
    ubyte* code_compiled;
    BranchBlockPatch* patch_list;
    /* This is used to save params frame_offset of of if block */
    short* param_frame_offsets;
}

    /* Indicate the operand stack is in polymorphic state.
     * If the opcode is one of unreachable/br/br_table/return, stack is marked
     * to polymorphic state until the block's 'end' opcode is processed.
     * If stack is in polymorphic state and stack is empty, instruction can
     * pop any type of value directly without decreasing stack top pointer
     * and stack cell num. */
    bool is_stack_polymorphic;
}

struct WASMLoaderContext {
    /* frame ref stack */
    ubyte* frame_ref;
    ubyte* frame_ref_bottom;
    ubyte* frame_ref_boundary;
    uint frame_ref_size;
    uint stack_cell_num;
    uint max_stack_cell_num;

    /* frame csp stack */
    BranchBlock* frame_csp;
    BranchBlock* frame_csp_bottom;
    BranchBlock* frame_csp_boundary;
    uint frame_csp_size;
    uint csp_num;
    uint max_csp_num;

static if (WASM_ENABLE_FAST_INTERP != 0) {
    /* frame offset stack */
    short* frame_offset;
    short* frame_offset_bottom;
    short* frame_offset_boundary;
    uint frame_offset_size;
    short dynamic_offset;
    short start_dynamic_offset;
    short max_dynamic_offset;

    /* preserved local offset */
    short preserved_local_offset;

    /* const buffer */
    ubyte* const_buf;
    ushort num_const;
    ushort const_cell_num;
    uint const_buf_size;

    /* processed code */
    ubyte* p_code_compiled;
    ubyte* p_code_compiled_end;
    uint code_compiled_size;
    /* If the last opcode will be dropped, the peak memory usage will be larger
     * than the final code_compiled_size, we record the peak size to ensure
     * there will not be invalid memory access during second traverse */
    uint code_compiled_peak_size;
}
}

struct Const {
    WASMValue value;
    ushort slot_index;
    ubyte value_type;
}

private void* memory_realloc(void* mem_old, uint size_old, uint size_new, char* error_buf, uint error_buf_size) {
    ubyte* mem_new = void;
    bh_assert(size_new > size_old);
    if ((mem_new = loader_malloc(size_new, error_buf, error_buf_size))) {
        bh_memcpy_s(mem_new, size_new, mem_old, size_old);
        memset(mem_new + size_old, 0, size_new - size_old);
        wasm_runtime_free(mem_old);
    }
    return mem_new;
}

enum string MEM_REALLOC(string mem, string size_old, string size_new) = `                               \
    do {                                                                   \
        void *mem_new = memory_realloc(mem, size_old, size_new, error_buf, \
                                       error_buf_size);                    \
        if (!mem_new)                                                      \
            goto fail;                                                     \
        mem = mem_new;                                                     \
    } while (0)`;

enum string CHECK_CSP_PUSH() = `                                                  \
    do {                                                                  \
        if (ctx->frame_csp >= ctx->frame_csp_boundary) {                  \
            MEM_REALLOC(                                                  \
                ctx->frame_csp_bottom, ctx->frame_csp_size,               \
                (uint32)(ctx->frame_csp_size + 8 * sizeof(BranchBlock))); \
            ctx->frame_csp_size += (uint32)(8 * sizeof(BranchBlock));     \
            ctx->frame_csp_boundary =                                     \
                ctx->frame_csp_bottom                                     \
                + ctx->frame_csp_size / sizeof(BranchBlock);              \
            ctx->frame_csp = ctx->frame_csp_bottom + ctx->csp_num;        \
        }                                                                 \
    } while (0)`;

enum string CHECK_CSP_POP() = `               \
    do {                              \
        bh_assert(ctx->csp_num >= 1); \
    } while (0)`;

static if (WASM_ENABLE_FAST_INTERP != 0) {
private bool check_offset_push(WASMLoaderContext* ctx, char* error_buf, uint error_buf_size) {
    uint cell_num = (uint32)(ctx.frame_offset - ctx.frame_offset_bottom);
    if (ctx.frame_offset >= ctx.frame_offset_boundary) {
        MEM_REALLOC(ctx.frame_offset_bottom, ctx.frame_offset_size,
                    ctx.frame_offset_size + 16);
        ctx.frame_offset_size += 16;
        ctx.frame_offset_boundary =
            ctx.frame_offset_bottom + ctx.frame_offset_size / int16.sizeof;
        ctx.frame_offset = ctx.frame_offset_bottom + cell_num;
    }
    return true;
fail:
    return false;
}

private bool check_offset_pop(WASMLoaderContext* ctx, uint cells) {
    if (ctx.frame_offset - cells < ctx.frame_offset_bottom)
        return false;
    return true;
}

private void free_label_patch_list(BranchBlock* frame_csp) {
    BranchBlockPatch* label_patch = frame_csp.patch_list;
    BranchBlockPatch* next = void;
    while (label_patch != null) {
        next = label_patch.next;
        wasm_runtime_free(label_patch);
        label_patch = next;
    }
    frame_csp.patch_list = null;
}

private void free_all_label_patch_lists(BranchBlock* frame_csp, uint csp_num) {
    BranchBlock* tmp_csp = frame_csp;

    for (uint i = 0; i < csp_num; i++) {
        free_label_patch_list(tmp_csp);
        tmp_csp++;
    }
}

}

private bool check_stack_push(WASMLoaderContext* ctx, char* error_buf, uint error_buf_size) {
    if (ctx.frame_ref >= ctx.frame_ref_boundary) {
        MEM_REALLOC(ctx.frame_ref_bottom, ctx.frame_ref_size,
                    ctx.frame_ref_size + 16);
        ctx.frame_ref_size += 16;
        ctx.frame_ref_boundary = ctx.frame_ref_bottom + ctx.frame_ref_size;
        ctx.frame_ref = ctx.frame_ref_bottom + ctx.stack_cell_num;
    }
    return true;
fail:
    return false;
}

private bool check_stack_top_values(ubyte* frame_ref, int stack_cell_num, ubyte type, char* error_buf, uint error_buf_size) {
    bh_assert(!((is_32bit_type(type) && stack_cell_num < 1)
                || (is_64bit_type(type) && stack_cell_num < 2)));

    bh_assert(!(
        (type == VALUE_TYPE_I32 && *(frame_ref - 1) != REF_I32)
        || (type == VALUE_TYPE_F32 && *(frame_ref - 1) != REF_F32)
        || (type == VALUE_TYPE_I64
            && (*(frame_ref - 2) != REF_I64_1 || *(frame_ref - 1) != REF_I64_2))
        || (type == VALUE_TYPE_F64
            && (*(frame_ref - 2) != REF_F64_1
                || *(frame_ref - 1) != REF_F64_2))));
    return true;
}

private bool check_stack_pop(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    int block_stack_cell_num = (int32)(ctx.stack_cell_num - (ctx.frame_csp - 1).stack_cell_num);

    if (block_stack_cell_num > 0 && *(ctx.frame_ref - 1) == VALUE_TYPE_ANY) {
        /* the stack top is a value of any type, return success */
        return true;
    }

    if (!check_stack_top_values(ctx.frame_ref, block_stack_cell_num, type,
                                error_buf, error_buf_size))
        return false;

    return true;
}

private void wasm_loader_ctx_destroy(WASMLoaderContext* ctx) {
    if (ctx) {
        if (ctx.frame_ref_bottom)
            wasm_runtime_free(ctx.frame_ref_bottom);
        if (ctx.frame_csp_bottom) {
static if (WASM_ENABLE_FAST_INTERP != 0) {
            free_all_label_patch_lists(ctx.frame_csp_bottom, ctx.csp_num);
}
            wasm_runtime_free(ctx.frame_csp_bottom);
        }
static if (WASM_ENABLE_FAST_INTERP != 0) {
        if (ctx.frame_offset_bottom)
            wasm_runtime_free(ctx.frame_offset_bottom);
        if (ctx.const_buf)
            wasm_runtime_free(ctx.const_buf);
}
        wasm_runtime_free(ctx);
    }
}

private WASMLoaderContext* wasm_loader_ctx_init(WASMFunction* func, char* error_buf, uint error_buf_size) {
    WASMLoaderContext* loader_ctx = loader_malloc(WASMLoaderContext.sizeof, error_buf, error_buf_size);
    if (!loader_ctx)
        return null;

    loader_ctx.frame_ref_size = 32;
    if (((loader_ctx.frame_ref_bottom = loader_ctx.frame_ref = loader_malloc(
              loader_ctx.frame_ref_size, error_buf, error_buf_size)) == 0))
        goto fail;
    loader_ctx.frame_ref_boundary = loader_ctx.frame_ref_bottom + 32;

    loader_ctx.frame_csp_size = sizeof(BranchBlock) * 8;
    if (((loader_ctx.frame_csp_bottom = loader_ctx.frame_csp = loader_malloc(
              loader_ctx.frame_csp_size, error_buf, error_buf_size)) == 0))
        goto fail;
    loader_ctx.frame_csp_boundary = loader_ctx.frame_csp_bottom + 8;

static if (WASM_ENABLE_FAST_INTERP != 0) {
    loader_ctx.frame_offset_size = sizeof(int16) * 32;
    if (((loader_ctx.frame_offset_bottom = loader_ctx.frame_offset =
              loader_malloc(loader_ctx.frame_offset_size, error_buf,
                            error_buf_size)) == 0))
        goto fail;
    loader_ctx.frame_offset_boundary = loader_ctx.frame_offset_bottom + 32;

    loader_ctx.num_const = 0;
    loader_ctx.const_buf_size = sizeof(Const) * 8;
    if (((loader_ctx.const_buf = loader_malloc(loader_ctx.const_buf_size,
                                                error_buf, error_buf_size)) == 0))
        goto fail;

    if (func.param_cell_num >= cast(int)INT16_MAX - func.local_cell_num) {
        set_error_buf(error_buf, error_buf_size,
                      "fast interpreter offset overflow");
        goto fail;
    }

    loader_ctx.start_dynamic_offset = loader_ctx.dynamic_offset =
        loader_ctx.max_dynamic_offset =
            func.param_cell_num + func.local_cell_num;
}
    return loader_ctx;

fail:
    wasm_loader_ctx_destroy(loader_ctx);
    return null;
}

private bool wasm_loader_push_frame_ref(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    if (type == VALUE_TYPE_VOID)
        return true;

    if (!check_stack_push(ctx, error_buf, error_buf_size))
        return false;

    *ctx.frame_ref++ = type;
    ctx.stack_cell_num++;
    if (ctx.stack_cell_num > ctx.max_stack_cell_num)
        ctx.max_stack_cell_num = ctx.stack_cell_num;

    if (is_32bit_type(type))
        return true;

    if (!check_stack_push(ctx, error_buf, error_buf_size))
        return false;
    *ctx.frame_ref++ = type;
    ctx.stack_cell_num++;
    if (ctx.stack_cell_num > ctx.max_stack_cell_num) {
        ctx.max_stack_cell_num = ctx.stack_cell_num;
        bh_assert(ctx.max_stack_cell_num <= UINT16_MAX);
    }
    return true;
}

private bool wasm_loader_pop_frame_ref(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    BranchBlock* cur_block = ctx.frame_csp - 1;
    int available_stack_cell = (int32)(ctx.stack_cell_num - cur_block.stack_cell_num);

    /* Directly return success if current block is in stack
     * polymorphic state while stack is empty. */
    if (available_stack_cell <= 0 && cur_block.is_stack_polymorphic)
        return true;

    if (type == VALUE_TYPE_VOID)
        return true;

    if (!check_stack_pop(ctx, type, error_buf, error_buf_size))
        return false;

    ctx.frame_ref--;
    ctx.stack_cell_num--;

    if (is_32bit_type(type) || *ctx.frame_ref == VALUE_TYPE_ANY)
        return true;

    ctx.frame_ref--;
    ctx.stack_cell_num--;
    return true;
}

private bool wasm_loader_push_pop_frame_ref(WASMLoaderContext* ctx, ubyte pop_cnt, ubyte type_push, ubyte type_pop, char* error_buf, uint error_buf_size) {
    for (int i = 0; i < pop_cnt; i++) {
        if (!wasm_loader_pop_frame_ref(ctx, type_pop, error_buf,
                                       error_buf_size))
            return false;
    }
    if (!wasm_loader_push_frame_ref(ctx, type_push, error_buf, error_buf_size))
        return false;
    return true;
}

private bool wasm_loader_push_frame_csp(WASMLoaderContext* ctx, ubyte label_type, BlockType block_type, ubyte* start_addr, char* error_buf, uint error_buf_size) {
    CHECK_CSP_PUSH();
    memset(ctx.frame_csp, 0, BranchBlock.sizeof);
    ctx.frame_csp.label_type = label_type;
    ctx.frame_csp.block_type = block_type;
    ctx.frame_csp.start_addr = start_addr;
    ctx.frame_csp.stack_cell_num = ctx.stack_cell_num;
static if (WASM_ENABLE_FAST_INTERP != 0) {
    ctx.frame_csp.dynamic_offset = ctx.dynamic_offset;
    ctx.frame_csp.patch_list = null;
}
    ctx.frame_csp++;
    ctx.csp_num++;
    if (ctx.csp_num > ctx.max_csp_num) {
        ctx.max_csp_num = ctx.csp_num;
        bh_assert(ctx.max_csp_num <= UINT16_MAX);
    }
    return true;
fail:
    return false;
}

private bool wasm_loader_pop_frame_csp(WASMLoaderContext* ctx, char* error_buf, uint error_buf_size) {
    CHECK_CSP_POP();
static if (WASM_ENABLE_FAST_INTERP != 0) {
    if ((ctx.frame_csp - 1).param_frame_offsets)
        wasm_runtime_free((ctx.frame_csp - 1).param_frame_offsets);
}
    ctx.frame_csp--;
    ctx.csp_num--;
    return true;
}

static if (WASM_ENABLE_FAST_INTERP != 0) {

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
enum string emit_label(string opcode) = `                                      \
    do {                                                        \
        wasm_loader_emit_ptr(loader_ctx, handle_table[opcode]); \
        LOG_OP("\nemit_op [%02x]\t", opcode);                   \
    } while (0)`;
enum string skip_label() = `                                            \
    do {                                                        \
        wasm_loader_emit_backspace(loader_ctx, sizeof(void *)); \
        LOG_OP("\ndelete last op\n");                           \
    } while (0)`;
} else { /* else of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
enum string emit_label(string opcode) = `                                                     \
    do {                                                                       \
        int32 offset =                                                         \
            (int32)((uint8 *)handle_table[opcode] - (uint8 *)handle_table[0]); \
        if (!(offset >= INT16_MIN && offset < INT16_MAX)) {                    \
            set_error_buf(error_buf, error_buf_size,                           \
                          "pre-compiled label offset out of range");           \
            goto fail;                                                         \
        }                                                                      \
        wasm_loader_emit_int16(loader_ctx, offset);                            \
        LOG_OP("\nemit_op [%02x]\t", opcode);                                  \
    } while (0)`;
enum string skip_label() = `                                           \
    do {                                                       \
        wasm_loader_emit_backspace(loader_ctx, sizeof(int16)); \
        LOG_OP("\ndelete last op\n");                          \
    } while (0)`;
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
} else {  /* else of WASM_ENABLE_LABELS_AS_VALUES */
enum string emit_label(string opcode) = `                          \
    do {                                            \
        wasm_loader_emit_uint8(loader_ctx, opcode); \
        LOG_OP("\nemit_op [%02x]\t", opcode);       \
    } while (0)`;
enum string skip_label() = `                                           \
    do {                                                       \
        wasm_loader_emit_backspace(loader_ctx, sizeof(uint8)); \
        LOG_OP("\ndelete last op\n");                          \
    } while (0)`;
} /* end of WASM_ENABLE_LABELS_AS_VALUES */

enum string emit_empty_label_addr_and_frame_ip(string type) = `                             \
    do {                                                                     \
        if (!add_label_patch_to_list(loader_ctx->frame_csp - 1, type,        \
                                     loader_ctx->p_code_compiled, error_buf, \
                                     error_buf_size))                        \
            goto fail;                                                       \
        /* label address, to be patched */                                   \
        wasm_loader_emit_ptr(loader_ctx, NULL);                              \
    } while (0)`;

enum string emit_br_info(string frame_csp) = `                                         \
    do {                                                                \
        if (!wasm_loader_emit_br_info(loader_ctx, frame_csp, error_buf, \
                                      error_buf_size))                  \
            goto fail;                                                  \
    } while (0)`;

enum string LAST_OP_OUTPUT_I32() = `                                                   \
    (last_op >= WASM_OP_I32_EQZ && last_op <= WASM_OP_I32_ROTR)                \
        || (last_op == WASM_OP_I32_LOAD || last_op == WASM_OP_F32_LOAD)        \
        || (last_op >= WASM_OP_I32_LOAD8_S && last_op <= WASM_OP_I32_LOAD16_U) \
        || (last_op >= WASM_OP_F32_ABS && last_op <= WASM_OP_F32_COPYSIGN)     \
        || (last_op >= WASM_OP_I32_WRAP_I64                                    \
            && last_op <= WASM_OP_I32_TRUNC_U_F64)                             \
        || (last_op >= WASM_OP_F32_CONVERT_S_I32                               \
            && last_op <= WASM_OP_F32_DEMOTE_F64)                              \
        || (last_op == WASM_OP_I32_REINTERPRET_F32)                            \
        || (last_op == WASM_OP_F32_REINTERPRET_I32)                            \
        || (last_op == EXT_OP_COPY_STACK_TOP)`;

enum string LAST_OP_OUTPUT_I64() = `                                                   \
    (last_op >= WASM_OP_I64_CLZ && last_op <= WASM_OP_I64_ROTR)                \
        || (last_op >= WASM_OP_F64_ABS && last_op <= WASM_OP_F64_COPYSIGN)     \
        || (last_op == WASM_OP_I64_LOAD || last_op == WASM_OP_F64_LOAD)        \
        || (last_op >= WASM_OP_I64_LOAD8_S && last_op <= WASM_OP_I64_LOAD32_U) \
        || (last_op >= WASM_OP_I64_EXTEND_S_I32                                \
            && last_op <= WASM_OP_I64_TRUNC_U_F64)                             \
        || (last_op >= WASM_OP_F64_CONVERT_S_I32                               \
            && last_op <= WASM_OP_F64_PROMOTE_F32)                             \
        || (last_op == WASM_OP_I64_REINTERPRET_F64)                            \
        || (last_op == WASM_OP_F64_REINTERPRET_I64)                            \
        || (last_op == EXT_OP_COPY_STACK_TOP_I64)`;

enum string GET_CONST_OFFSET(string type, string val) = `                                    \
    do {                                                               \
        if (!(wasm_loader_get_const_offset(loader_ctx, type, &val,     \
                                           &operand_offset, error_buf, \
                                           error_buf_size)))           \
            goto fail;                                                 \
    } while (0)`;

enum string GET_CONST_F32_OFFSET(string type, string fval) = `                               \
    do {                                                               \
        if (!(wasm_loader_get_const_offset(loader_ctx, type, &fval,    \
                                           &operand_offset, error_buf, \
                                           error_buf_size)))           \
            goto fail;                                                 \
    } while (0)`;

enum string GET_CONST_F64_OFFSET(string type, string fval) = `                               \
    do {                                                               \
        if (!(wasm_loader_get_const_offset(loader_ctx, type, &fval,    \
                                           &operand_offset, error_buf, \
                                           error_buf_size)))           \
            goto fail;                                                 \
    } while (0)`;

enum string emit_operand(string ctx, string offset) = `            \
    do {                                     \
        wasm_loader_emit_int16(ctx, offset); \
        LOG_OP("%d\t", offset);              \
    } while (0)`;

enum string emit_byte(string ctx, string byte_) = `               \
    do {                                   \
        wasm_loader_emit_uint8(ctx, byte); \
        LOG_OP("%d\t", byte);              \
    } while (0)`;

enum string emit_uint32(string ctx, string value) = `              \
    do {                                     \
        wasm_loader_emit_uint32(ctx, value); \
        LOG_OP("%d\t", value);               \
    } while (0)`;

enum string emit_uint64(string ctx, string value) = `                     \
    do {                                            \
        wasm_loader_emit_const(ctx, &value, false); \
        LOG_OP("%lld\t", value);                    \
    } while (0)`;

enum string emit_float32(string ctx, string value) = `                   \
    do {                                           \
        wasm_loader_emit_const(ctx, &value, true); \
        LOG_OP("%f\t", value);                     \
    } while (0)`;

enum string emit_float64(string ctx, string value) = `                    \
    do {                                            \
        wasm_loader_emit_const(ctx, &value, false); \
        LOG_OP("%f\t", value);                      \
    } while (0)`;

private bool wasm_loader_ctx_reinit(WASMLoaderContext* ctx) {
    if (((ctx.p_code_compiled =
              loader_malloc(ctx.code_compiled_peak_size, null, 0)) == 0))
        return false;
    ctx.p_code_compiled_end =
        ctx.p_code_compiled + ctx.code_compiled_peak_size;

    /* clean up frame ref */
    memset(ctx.frame_ref_bottom, 0, ctx.frame_ref_size);
    ctx.frame_ref = ctx.frame_ref_bottom;
    ctx.stack_cell_num = 0;

    /* clean up frame csp */
    memset(ctx.frame_csp_bottom, 0, ctx.frame_csp_size);
    ctx.frame_csp = ctx.frame_csp_bottom;
    ctx.csp_num = 0;
    ctx.max_csp_num = 0;

    /* clean up frame offset */
    memset(ctx.frame_offset_bottom, 0, ctx.frame_offset_size);
    ctx.frame_offset = ctx.frame_offset_bottom;
    ctx.dynamic_offset = ctx.start_dynamic_offset;

    /* init preserved local offsets */
    ctx.preserved_local_offset = ctx.max_dynamic_offset;

    /* const buf is reserved */
    return true;
}

private void increase_compiled_code_space(WASMLoaderContext* ctx, int size) {
    ctx.code_compiled_size += size;
    if (ctx.code_compiled_size >= ctx.code_compiled_peak_size) {
        ctx.code_compiled_peak_size = ctx.code_compiled_size;
    }
}

private void wasm_loader_emit_const(WASMLoaderContext* ctx, void* value, bool is_32_bit) {
    uint size = is_32_bit ? uint32.sizeof : uint64.sizeof;

    if (ctx.p_code_compiled) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((cast(uintptr_t)ctx.p_code_compiled & 1) == 0);
}
        bh_memcpy_s(ctx.p_code_compiled,
                    (uint32)(ctx.p_code_compiled_end - ctx.p_code_compiled),
                    value, size);
        ctx.p_code_compiled += size;
    }
    else {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((ctx.code_compiled_size & 1) == 0);
}
        increase_compiled_code_space(ctx, size);
    }
}

private void wasm_loader_emit_uint32(WASMLoaderContext* ctx, uint value) {
    if (ctx.p_code_compiled) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((cast(uintptr_t)ctx.p_code_compiled & 1) == 0);
}
        STORE_U32(ctx.p_code_compiled, value);
        ctx.p_code_compiled += uint32.sizeof;
    }
    else {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((ctx.code_compiled_size & 1) == 0);
}
        increase_compiled_code_space(ctx, uint32.sizeof);
    }
}

private void wasm_loader_emit_int16(WASMLoaderContext* ctx, short value) {
    if (ctx.p_code_compiled) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((cast(uintptr_t)ctx.p_code_compiled & 1) == 0);
}
        STORE_U16(ctx.p_code_compiled, cast(ushort)value);
        ctx.p_code_compiled += int16.sizeof;
    }
    else {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((ctx.code_compiled_size & 1) == 0);
}
        increase_compiled_code_space(ctx, uint16.sizeof);
    }
}

private void wasm_loader_emit_uint8(WASMLoaderContext* ctx, ubyte value) {
    if (ctx.p_code_compiled) {
        *(ctx.p_code_compiled) = value;
        ctx.p_code_compiled += uint8.sizeof;
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        ctx.p_code_compiled++;
        bh_assert((cast(uintptr_t)ctx.p_code_compiled & 1) == 0);
}
    }
    else {
        increase_compiled_code_space(ctx, uint8.sizeof);
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        increase_compiled_code_space(ctx, uint8.sizeof);
        bh_assert((ctx.code_compiled_size & 1) == 0);
}
    }
}

private void wasm_loader_emit_ptr(WASMLoaderContext* ctx, void* value) {
    if (ctx.p_code_compiled) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((cast(uintptr_t)ctx.p_code_compiled & 1) == 0);
}
        STORE_PTR(ctx.p_code_compiled, value);
        ctx.p_code_compiled += (void*).sizeof;
    }
    else {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        bh_assert((ctx.code_compiled_size & 1) == 0);
}
        increase_compiled_code_space(ctx, (void*).sizeof);
    }
}

private void wasm_loader_emit_backspace(WASMLoaderContext* ctx, uint size) {
    if (ctx.p_code_compiled) {
        ctx.p_code_compiled -= size;
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        if (size == uint8.sizeof) {
            ctx.p_code_compiled--;
            bh_assert((cast(uintptr_t)ctx.p_code_compiled & 1) == 0);
        }
}
    }
    else {
        ctx.code_compiled_size -= size;
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        if (size == uint8.sizeof) {
            ctx.code_compiled_size--;
            bh_assert((ctx.code_compiled_size & 1) == 0);
        }
}
    }
}

private bool preserve_referenced_local(WASMLoaderContext* loader_ctx, ubyte opcode, uint local_index, uint local_type, bool* preserved, char* error_buf, uint error_buf_size) {
    uint i = 0;
    short preserved_offset = cast(short)local_index;

    *preserved = false;
    while (i < loader_ctx.stack_cell_num) {
        ubyte cur_type = loader_ctx.frame_ref_bottom[i];

        /* move previous local into dynamic space before a set/tee_local opcode
         */
        if (loader_ctx.frame_offset_bottom[i] == cast(short)local_index) {
            if (!(*preserved)) {
                *preserved = true;
                skip_label();
                preserved_offset = loader_ctx.preserved_local_offset;
                if (loader_ctx.p_code_compiled) {
                    bh_assert(preserved_offset != cast(short)local_index);
                }
                if (is_32bit_type(local_type)) {
                    /* Only increase preserve offset in the second traversal */
                    if (loader_ctx.p_code_compiled)
                        loader_ctx.preserved_local_offset++;
                    emit_label(EXT_OP_COPY_STACK_TOP);
                }
                else {
                    if (loader_ctx.p_code_compiled)
                        loader_ctx.preserved_local_offset += 2;
                    emit_label(EXT_OP_COPY_STACK_TOP_I64);
                }
                emit_operand(loader_ctx, local_index);
                emit_operand(loader_ctx, preserved_offset);
                emit_label(opcode);
            }
            loader_ctx.frame_offset_bottom[i] = preserved_offset;
        }

        if (is_32bit_type(cur_type))
            i++;
        else
            i += 2;
    }

    return true;

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
fail:
    return false;
}
}
}

private bool preserve_local_for_block(WASMLoaderContext* loader_ctx, ubyte opcode, char* error_buf, uint error_buf_size) {
    uint i = 0;
    bool preserve_local = void;

    /* preserve locals before blocks to ensure that "tee/set_local" inside
        blocks will not influence the value of these locals */
    while (i < loader_ctx.stack_cell_num) {
        short cur_offset = loader_ctx.frame_offset_bottom[i];
        ubyte cur_type = loader_ctx.frame_ref_bottom[i];

        if ((cur_offset < loader_ctx.start_dynamic_offset)
            && (cur_offset >= 0)) {
            if (!(preserve_referenced_local(loader_ctx, opcode, cur_offset,
                                            cur_type, &preserve_local,
                                            error_buf, error_buf_size)))
                return false;
        }

        if (is_32bit_type(cur_type == VALUE_TYPE_I32)) {
            i++;
        }
        else {
            i += 2;
        }
    }

    return true;
}

private bool add_label_patch_to_list(BranchBlock* frame_csp, ubyte patch_type, ubyte* p_code_compiled, char* error_buf, uint error_buf_size) {
    BranchBlockPatch* patch = loader_malloc(BranchBlockPatch.sizeof, error_buf, error_buf_size);
    if (!patch) {
        return false;
    }
    patch.patch_type = patch_type;
    patch.code_compiled = p_code_compiled;
    if (!frame_csp.patch_list) {
        frame_csp.patch_list = patch;
        patch.next = null;
    }
    else {
        patch.next = frame_csp.patch_list;
        frame_csp.patch_list = patch;
    }
    return true;
}

private void apply_label_patch(WASMLoaderContext* ctx, ubyte depth, ubyte patch_type) {
    BranchBlock* frame_csp = ctx.frame_csp - depth;
    BranchBlockPatch* node = frame_csp.patch_list;
    BranchBlockPatch* node_prev = null, node_next = void;

    if (!ctx.p_code_compiled)
        return;

    while (node) {
        node_next = node.next;
        if (node.patch_type == patch_type) {
            STORE_PTR(node.code_compiled, ctx.p_code_compiled);
            if (node_prev == null) {
                frame_csp.patch_list = node_next;
            }
            else {
                node_prev.next = node_next;
            }
            wasm_runtime_free(node);
        }
        else {
            node_prev = node;
        }
        node = node_next;
    }
}

private bool wasm_loader_emit_br_info(WASMLoaderContext* ctx, BranchBlock* frame_csp, char* error_buf, uint error_buf_size) {
    /* br info layout:
     *  a) arity of target block
     *  b) total cell num of arity values
     *  c) each arity value's cell num
     *  d) each arity value's src frame offset
     *  e) each arity values's dst dynamic offset
     *  f) branch target address
     *
     *  Note: b-e are omitted when arity is 0 so that
     *  interpreter can recover the br info quickly.
     */
    BlockType* block_type = &frame_csp.block_type;
    ubyte* types = null; ubyte cell = void;
    uint arity = 0;
    int i = void;
    short* frame_offset = ctx.frame_offset;
    ushort dynamic_offset = void;

    /* Note: loop's arity is different from if and block. loop's arity is
     * its parameter count while if and block arity is result count.
     */
    if (frame_csp.label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(block_type, &types);
    else
        arity = block_type_get_result_types(block_type, &types);

    /* Part a */
    emit_uint32(ctx, arity);

    if (arity) {
        /* Part b */
        emit_uint32(ctx, wasm_get_cell_num(types, arity));

        /* Part c */
        for (i = cast(int)arity - 1; i >= 0; i--) {
            cell = cast(ubyte)wasm_value_type_cell_num(types[i]);
            emit_byte(ctx, cell);
        }
        /* Part d */
        for (i = cast(int)arity - 1; i >= 0; i--) {
            cell = cast(ubyte)wasm_value_type_cell_num(types[i]);
            frame_offset -= cell;
            emit_operand(ctx, *cast(short*)(frame_offset));
        }
        /* Part e */
        dynamic_offset =
            frame_csp.dynamic_offset + wasm_get_cell_num(types, arity);
        for (i = cast(int)arity - 1; i >= 0; i--) {
            cell = cast(ubyte)wasm_value_type_cell_num(types[i]);
            dynamic_offset -= cell;
            emit_operand(ctx, dynamic_offset);
        }
    }

    /* Part f */
    if (frame_csp.label_type == LABEL_TYPE_LOOP) {
        wasm_loader_emit_ptr(ctx, frame_csp.code_compiled);
    }
    else {
        if (!add_label_patch_to_list(frame_csp, PATCH_END, ctx.p_code_compiled,
                                     error_buf, error_buf_size))
            return false;
        /* label address, to be patched */
        wasm_loader_emit_ptr(ctx, null);
    }

    return true;
}

private bool wasm_loader_push_frame_offset(WASMLoaderContext* ctx, ubyte type, bool disable_emit, short operand_offset, char* error_buf, uint error_buf_size) {
    if (type == VALUE_TYPE_VOID)
        return true;

    /* only check memory overflow in first traverse */
    if (ctx.p_code_compiled == null) {
        if (!check_offset_push(ctx, error_buf, error_buf_size))
            return false;
    }

    if (disable_emit)
        *(ctx.frame_offset)++ = operand_offset;
    else {
        emit_operand(ctx, ctx.dynamic_offset);
        *(ctx.frame_offset)++ = ctx.dynamic_offset;
        ctx.dynamic_offset++;
        if (ctx.dynamic_offset > ctx.max_dynamic_offset) {
            ctx.max_dynamic_offset = ctx.dynamic_offset;
            bh_assert(ctx.max_dynamic_offset < INT16_MAX);
        }
    }

    if (is_32bit_type(type))
        return true;

    if (ctx.p_code_compiled == null) {
        if (!check_offset_push(ctx, error_buf, error_buf_size))
            return false;
    }

    ctx.frame_offset++;
    if (!disable_emit) {
        ctx.dynamic_offset++;
        if (ctx.dynamic_offset > ctx.max_dynamic_offset) {
            ctx.max_dynamic_offset = ctx.dynamic_offset;
            bh_assert(ctx.max_dynamic_offset < INT16_MAX);
        }
    }
    return true;
}

/* This function should be in front of wasm_loader_pop_frame_ref
    as they both use ctx->stack_cell_num, and ctx->stack_cell_num
    will be modified by wasm_loader_pop_frame_ref */
private bool wasm_loader_pop_frame_offset(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    /* if ctx->frame_csp equals ctx->frame_csp_bottom,
        then current block is the function block */
    uint depth = ctx.frame_csp > ctx.frame_csp_bottom ? 1 : 0;
    BranchBlock* cur_block = ctx.frame_csp - depth;
    int available_stack_cell = (int32)(ctx.stack_cell_num - cur_block.stack_cell_num);

    /* Directly return success if current block is in stack
     * polymorphic state while stack is empty. */
    if (available_stack_cell <= 0 && cur_block.is_stack_polymorphic)
        return true;

    if (type == VALUE_TYPE_VOID)
        return true;

    if (is_32bit_type(type)) {
        /* Check the offset stack bottom to ensure the frame offset
            stack will not go underflow. But we don't thrown error
            and return true here, because the error msg should be
            given in wasm_loader_pop_frame_ref */
        if (!check_offset_pop(ctx, 1))
            return true;

        ctx.frame_offset -= 1;
        if ((*(ctx.frame_offset) > ctx.start_dynamic_offset)
            && (*(ctx.frame_offset) < ctx.max_dynamic_offset))
            ctx.dynamic_offset -= 1;
    }
    else {
        if (!check_offset_pop(ctx, 2))
            return true;

        ctx.frame_offset -= 2;
        if ((*(ctx.frame_offset) > ctx.start_dynamic_offset)
            && (*(ctx.frame_offset) < ctx.max_dynamic_offset))
            ctx.dynamic_offset -= 2;
    }
    emit_operand(ctx, *(ctx.frame_offset));
    return true;
}

private bool wasm_loader_push_pop_frame_offset(WASMLoaderContext* ctx, ubyte pop_cnt, ubyte type_push, ubyte type_pop, bool disable_emit, short operand_offset, char* error_buf, uint error_buf_size) {
    for (int i = 0; i < pop_cnt; i++) {
        if (!wasm_loader_pop_frame_offset(ctx, type_pop, error_buf,
                                          error_buf_size))
            return false;
    }
    if (!wasm_loader_push_frame_offset(ctx, type_push, disable_emit,
                                       operand_offset, error_buf,
                                       error_buf_size))
        return false;

    return true;
}

private bool wasm_loader_push_frame_ref_offset(WASMLoaderContext* ctx, ubyte type, bool disable_emit, short operand_offset, char* error_buf, uint error_buf_size) {
    if (!(wasm_loader_push_frame_offset(ctx, type, disable_emit, operand_offset,
                                        error_buf, error_buf_size)))
        return false;
    if (!(wasm_loader_push_frame_ref(ctx, type, error_buf, error_buf_size)))
        return false;

    return true;
}

private bool wasm_loader_pop_frame_ref_offset(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    /* put wasm_loader_pop_frame_offset in front of wasm_loader_pop_frame_ref */
    if (!wasm_loader_pop_frame_offset(ctx, type, error_buf, error_buf_size))
        return false;
    if (!wasm_loader_pop_frame_ref(ctx, type, error_buf, error_buf_size))
        return false;

    return true;
}

private bool wasm_loader_push_pop_frame_ref_offset(WASMLoaderContext* ctx, ubyte pop_cnt, ubyte type_push, ubyte type_pop, bool disable_emit, short operand_offset, char* error_buf, uint error_buf_size) {
    if (!wasm_loader_push_pop_frame_offset(ctx, pop_cnt, type_push, type_pop,
                                           disable_emit, operand_offset,
                                           error_buf, error_buf_size))
        return false;
    if (!wasm_loader_push_pop_frame_ref(ctx, pop_cnt, type_push, type_pop,
                                        error_buf, error_buf_size))
        return false;

    return true;
}

private bool wasm_loader_get_const_offset(WASMLoaderContext* ctx, ubyte type, void* value, short* offset, char* error_buf, uint error_buf_size) {
    byte bytes_to_increase = void;
    short operand_offset = 0;
    Const* c = void;

    /* Search existing constant */
    for (c = cast(Const*)ctx.const_buf;
         cast(ubyte*)c < ctx.const_buf + ctx.num_const * Const.sizeof; c++) {
        if ((type == c.value_type)
            && ((type == VALUE_TYPE_I64 && *cast(long*)value == c.value.i64)
                || (type == VALUE_TYPE_I32 && *cast(int*)value == c.value.i32)
#if WASM_ENABLE_REF_TYPES != 0
                || (type == VALUE_TYPE_FUNCREF
                    && *cast(int*)value == c.value.i32)
                || (type == VALUE_TYPE_EXTERNREF
                    && *cast(int*)value == c.value.i32)
#endif
                || (type == VALUE_TYPE_F64
                    && (0 == memcmp(value, &(c.value.f64), float64.sizeof)))
                || (type == VALUE_TYPE_F32
                    && (0
                        == memcmp(value, &(c.value.f32), float32.sizeof))))) {
            operand_offset = c.slot_index;
            break;
        }
        if (c.value_type == VALUE_TYPE_I64 || c.value_type == VALUE_TYPE_F64)
            operand_offset += 2;
        else
            operand_offset += 1;
    }

    if (cast(ubyte*)c == ctx.const_buf + ctx.num_const * Const.sizeof) {
        /* New constant, append to the const buffer */
        if ((type == VALUE_TYPE_F64) || (type == VALUE_TYPE_I64)) {
            bytes_to_increase = 2;
        }
        else {
            bytes_to_increase = 1;
        }

        /* The max cell num of const buffer is 32768 since the valid index range
         * is -32768 ~ -1. Return an invalid index 0 to indicate the buffer is
         * full */
        if (ctx.const_cell_num > INT16_MAX - bytes_to_increase + 1) {
            *offset = 0;
            return true;
        }

        if (cast(ubyte*)c == ctx.const_buf + ctx.const_buf_size) {
            MEM_REALLOC(ctx.const_buf, ctx.const_buf_size,
                        ctx.const_buf_size + 4 * Const.sizeof);
            ctx.const_buf_size += 4 * Const.sizeof;
            c = cast(Const*)(ctx.const_buf + ctx.num_const * Const.sizeof);
        }
        c.value_type = type;
        switch (type) {
            case VALUE_TYPE_F64:
                bh_memcpy_s(&(c.value.f64), WASMValue.sizeof, value,
                            float64.sizeof);
                ctx.const_cell_num += 2;
                /* The const buf will be reversed, we use the second cell */
                /* of the i64/f64 const so the finnal offset is corrent */
                operand_offset++;
                break;
            case VALUE_TYPE_I64:
                c.value.i64 = *cast(long*)value;
                ctx.const_cell_num += 2;
                operand_offset++;
                break;
            case VALUE_TYPE_F32:
                bh_memcpy_s(&(c.value.f32), WASMValue.sizeof, value,
                            float32.sizeof);
                ctx.const_cell_num++;
                break;
            case VALUE_TYPE_I32:
                c.value.i32 = *cast(int*)value;
                ctx.const_cell_num++;
                break;
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
                c.value.i32 = *cast(int*)value;
                ctx.const_cell_num++;
                break;
}
            default:
                break;
        }
        c.slot_index = operand_offset;
        ctx.num_const++;
        LOG_OP("#### new const [%d]: %ld\n", ctx.num_const,
               cast(long)c.value.i64);
    }
    /* use negetive index for const */
    operand_offset = -(operand_offset + 1);
    *offset = operand_offset;
    return true;
fail:
    return false;
}

/*
    PUSH(POP)_XXX = push(pop) frame_ref + push(pop) frame_offset
    -- Mostly used for the binary / compare operation
    PUSH(POP)_OFFSET_TYPE only push(pop) the frame_offset stack
    -- Mostly used in block / control instructions

    The POP will always emit the offset on the top of the frame_offset stack
    PUSH can be used in two ways:
    1. directly PUSH:
            PUSH_XXX();
        will allocate a dynamic space and emit
    2. silent PUSH:
            operand_offset = xxx; disable_emit = true;
            PUSH_XXX();
        only push the frame_offset stack, no emit
*/
enum string PUSH_I32() = `                                                           \
    do {                                                                     \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_I32,   \
                                               disable_emit, operand_offset, \
                                               error_buf, error_buf_size))   \
            goto fail;                                                       \
    } while (0)`;

enum string PUSH_F32() = `                                                           \
    do {                                                                     \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_F32,   \
                                               disable_emit, operand_offset, \
                                               error_buf, error_buf_size))   \
            goto fail;                                                       \
    } while (0)`;

enum string PUSH_I64() = `                                                           \
    do {                                                                     \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_I64,   \
                                               disable_emit, operand_offset, \
                                               error_buf, error_buf_size))   \
            goto fail;                                                       \
    } while (0)`;

enum string PUSH_F64() = `                                                           \
    do {                                                                     \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_F64,   \
                                               disable_emit, operand_offset, \
                                               error_buf, error_buf_size))   \
            goto fail;                                                       \
    } while (0)`;

enum string PUSH_FUNCREF() = `                                                         \
    do {                                                                       \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_FUNCREF, \
                                               disable_emit, operand_offset,   \
                                               error_buf, error_buf_size))     \
            goto fail;                                                         \
    } while (0)`;

enum string POP_I32() = `                                                         \
    do {                                                                  \
        if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_I32, \
                                              error_buf, error_buf_size)) \
            goto fail;                                                    \
    } while (0)`;

enum string POP_F32() = `                                                         \
    do {                                                                  \
        if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_F32, \
                                              error_buf, error_buf_size)) \
            goto fail;                                                    \
    } while (0)`;

enum string POP_I64() = `                                                         \
    do {                                                                  \
        if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_I64, \
                                              error_buf, error_buf_size)) \
            goto fail;                                                    \
    } while (0)`;

enum string POP_F64() = `                                                         \
    do {                                                                  \
        if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_F64, \
                                              error_buf, error_buf_size)) \
            goto fail;                                                    \
    } while (0)`;

enum string PUSH_OFFSET_TYPE(string type) = `                                              \
    do {                                                                    \
        if (!(wasm_loader_push_frame_offset(loader_ctx, type, disable_emit, \
                                            operand_offset, error_buf,      \
                                            error_buf_size)))               \
            goto fail;                                                      \
    } while (0)`;

enum string POP_OFFSET_TYPE(string type) = `                                           \
    do {                                                                \
        if (!(wasm_loader_pop_frame_offset(loader_ctx, type, error_buf, \
                                           error_buf_size)))            \
            goto fail;                                                  \
    } while (0)`;

enum string POP_AND_PUSH(string type_pop, string type_push) = `                         \
    do {                                                          \
        if (!(wasm_loader_push_pop_frame_ref_offset(              \
                loader_ctx, 1, type_push, type_pop, disable_emit, \
                operand_offset, error_buf, error_buf_size)))      \
            goto fail;                                            \
    } while (0)`;

/* type of POPs should be the same */
enum string POP2_AND_PUSH(string type_pop, string type_push) = `                        \
    do {                                                          \
        if (!(wasm_loader_push_pop_frame_ref_offset(              \
                loader_ctx, 2, type_push, type_pop, disable_emit, \
                operand_offset, error_buf, error_buf_size)))      \
            goto fail;                                            \
    } while (0)`;

} else { /* WASM_ENABLE_FAST_INTERP */

enum string PUSH_I32() = `                                                    \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I32,  \
                                         error_buf, error_buf_size))) \
            goto fail;                                                \
    } while (0)`;

enum string PUSH_F32() = `                                                    \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_F32,  \
                                         error_buf, error_buf_size))) \
            goto fail;                                                \
    } while (0)`;

enum string PUSH_I64() = `                                                    \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I64,  \
                                         error_buf, error_buf_size))) \
            goto fail;                                                \
    } while (0)`;

enum string PUSH_F64() = `                                                    \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_F64,  \
                                         error_buf, error_buf_size))) \
            goto fail;                                                \
    } while (0)`;

enum string PUSH_FUNCREF() = `                                                   \
    do {                                                                 \
        if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_FUNCREF, \
                                         error_buf, error_buf_size)))    \
            goto fail;                                                   \
    } while (0)`;

enum string POP_I32() = `                                                              \
    do {                                                                       \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, \
                                        error_buf_size)))                      \
            goto fail;                                                         \
    } while (0)`;

enum string POP_F32() = `                                                              \
    do {                                                                       \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_F32, error_buf, \
                                        error_buf_size)))                      \
            goto fail;                                                         \
    } while (0)`;

enum string POP_I64() = `                                                              \
    do {                                                                       \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I64, error_buf, \
                                        error_buf_size)))                      \
            goto fail;                                                         \
    } while (0)`;

enum string POP_F64() = `                                                              \
    do {                                                                       \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_F64, error_buf, \
                                        error_buf_size)))                      \
            goto fail;                                                         \
    } while (0)`;

enum string POP_FUNCREF() = `                                                   \
    do {                                                                \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_FUNCREF, \
                                        error_buf, error_buf_size)))    \
            goto fail;                                                  \
    } while (0)`;

enum string POP_AND_PUSH(string type_pop, string type_push) = `                              \
    do {                                                               \
        if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, type_push, \
                                             type_pop, error_buf,      \
                                             error_buf_size)))         \
            goto fail;                                                 \
    } while (0)`;

/* type of POPs should be the same */
enum string POP2_AND_PUSH(string type_pop, string type_push) = `                             \
    do {                                                               \
        if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, type_push, \
                                             type_pop, error_buf,      \
                                             error_buf_size)))         \
            goto fail;                                                 \
    } while (0)`;
} /* WASM_ENABLE_FAST_INTERP */

static if (WASM_ENABLE_FAST_INTERP != 0) {

private bool reserve_block_ret(WASMLoaderContext* loader_ctx, ubyte opcode, bool disable_emit, char* error_buf, uint error_buf_size) {
    short operand_offset = 0;
    BranchBlock* block = (opcode == WASM_OP_ELSE) ? loader_ctx.frame_csp - 1
                                                  : loader_ctx.frame_csp;
    BlockType* block_type = &block.block_type;
    ubyte* return_types = null;
    uint return_count = 0, value_count = 0, total_cel_num = 0;
    int i = 0;
    short dynamic_offset = void, dynamic_offset_org = void; short* frame_offset = null, frame_offset_org = null;

    return_count = block_type_get_result_types(block_type, &return_types);

    /* If there is only one return value, use EXT_OP_COPY_STACK_TOP/_I64 instead
     * of EXT_OP_COPY_STACK_VALUES for interpreter performance. */
    if (return_count == 1) {
        ubyte cell = cast(ubyte)wasm_value_type_cell_num(return_types[0]);
        if (cell <= 2 /* V128 isn't supported whose cell num is 4 */
            && block.dynamic_offset != *(loader_ctx.frame_offset - cell)) {
            /* insert op_copy before else opcode */
            if (opcode == WASM_OP_ELSE)
                skip_label();
            emit_label(cell == 1 ? EXT_OP_COPY_STACK_TOP
                                 : EXT_OP_COPY_STACK_TOP_I64);
            emit_operand(loader_ctx, *(loader_ctx.frame_offset - cell));
            emit_operand(loader_ctx, block.dynamic_offset);

            if (opcode == WASM_OP_ELSE) {
                *(loader_ctx.frame_offset - cell) = block.dynamic_offset;
            }
            else {
                loader_ctx.frame_offset -= cell;
                loader_ctx.dynamic_offset = block.dynamic_offset;
                PUSH_OFFSET_TYPE(return_types[0]);
                wasm_loader_emit_backspace(loader_ctx, int16.sizeof);
            }
            if (opcode == WASM_OP_ELSE)
                emit_label(opcode);
        }
        return true;
    }

    /* Copy stack top values to block's results which are in dynamic space.
     * The instruction format:
     *   Part a: values count
     *   Part b: all values total cell num
     *   Part c: each value's cell_num, src offset and dst offset
     *   Part d: each value's src offset and dst offset
     *   Part e: each value's dst offset
     */
    frame_offset = frame_offset_org = loader_ctx.frame_offset;
    dynamic_offset = dynamic_offset_org =
        block.dynamic_offset + wasm_get_cell_num(return_types, return_count);

    /* First traversal to get the count of values needed to be copied. */
    for (i = cast(int)return_count - 1; i >= 0; i--) {
        ubyte cells = cast(ubyte)wasm_value_type_cell_num(return_types[i]);

        frame_offset -= cells;
        dynamic_offset -= cells;
        if (dynamic_offset != *frame_offset) {
            value_count++;
            total_cel_num += cells;
        }
    }

    if (value_count) {
        uint j = 0;
        ubyte* emit_data = null, cells = null;
        short* src_offsets = null;
        ushort* dst_offsets = null;
        ulong size = cast(ulong)value_count
            * (sizeof(*cells) + sizeof(*src_offsets) + typeof(*dst_offsets).sizeof);

        /* Allocate memory for the emit data */
        if (((emit_data = loader_malloc(size, error_buf, error_buf_size)) == 0))
            return false;

        cells = emit_data;
        src_offsets = cast(short*)(cells + value_count);
        dst_offsets = cast(ushort*)(src_offsets + value_count);

        /* insert op_copy before else opcode */
        if (opcode == WASM_OP_ELSE)
            skip_label();
        emit_label(EXT_OP_COPY_STACK_VALUES);
        /* Part a) */
        emit_uint32(loader_ctx, value_count);
        /* Part b) */
        emit_uint32(loader_ctx, total_cel_num);

        /* Second traversal to get each value's cell num,  src offset and dst
         * offset. */
        frame_offset = frame_offset_org;
        dynamic_offset = dynamic_offset_org;
        for (i = cast(int)return_count - 1, j = 0; i >= 0; i--) {
            ubyte cell = cast(ubyte)wasm_value_type_cell_num(return_types[i]);
            frame_offset -= cell;
            dynamic_offset -= cell;
            if (dynamic_offset != *frame_offset) {
                /* cell num */
                cells[j] = cell;
                /* src offset */
                src_offsets[j] = *frame_offset;
                /* dst offset */
                dst_offsets[j] = dynamic_offset;
                j++;
            }
            if (opcode == WASM_OP_ELSE) {
                *frame_offset = dynamic_offset;
            }
            else {
                loader_ctx.frame_offset = frame_offset;
                loader_ctx.dynamic_offset = dynamic_offset;
                PUSH_OFFSET_TYPE(return_types[i]);
                wasm_loader_emit_backspace(loader_ctx, int16.sizeof);
                loader_ctx.frame_offset = frame_offset_org;
                loader_ctx.dynamic_offset = dynamic_offset_org;
            }
        }

        bh_assert(j == value_count);

        /* Emit the cells, src_offsets and dst_offsets */
        for (j = 0; j < value_count; j++)
            emit_byte(loader_ctx, cells[j]);
        for (j = 0; j < value_count; j++)
            emit_operand(loader_ctx, src_offsets[j]);
        for (j = 0; j < value_count; j++)
            emit_operand(loader_ctx, dst_offsets[j]);

        if (opcode == WASM_OP_ELSE)
            emit_label(opcode);

        wasm_runtime_free(emit_data);
    }

    return true;

fail:
    return false;
}

} /* WASM_ENABLE_FAST_INTERP */

enum string RESERVE_BLOCK_RET() = `                                                 \
    do {                                                                    \
        if (!reserve_block_ret(loader_ctx, opcode, disable_emit, error_buf, \
                               error_buf_size))                             \
            goto fail;                                                      \
    } while (0)`;

enum string PUSH_TYPE(string type) = `                                               \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, type, error_buf, \
                                         error_buf_size)))            \
            goto fail;                                                \
    } while (0)`;

enum string POP_TYPE(string type) = `                                               \
    do {                                                             \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, type, error_buf, \
                                        error_buf_size)))            \
            goto fail;                                               \
    } while (0)`;

enum string PUSH_CSP(string label_type, string block_type, string _start_addr) = `                       \
    do {                                                                    \
        if (!wasm_loader_push_frame_csp(loader_ctx, label_type, block_type, \
                                        _start_addr, error_buf,             \
                                        error_buf_size))                    \
            goto fail;                                                      \
    } while (0)`;

enum string POP_CSP() = `                                                              \
    do {                                                                       \
        if (!wasm_loader_pop_frame_csp(loader_ctx, error_buf, error_buf_size)) \
            goto fail;                                                         \
    } while (0)`;

enum string GET_LOCAL_INDEX_TYPE_AND_OFFSET() = `                        \
    do {                                                         \
        read_leb_uint32(p, p_end, local_idx);                    \
        bh_assert(local_idx < param_count + local_count);        \
        local_type = local_idx < param_count                     \
                         ? param_types[local_idx]                \
                         : local_types[local_idx - param_count]; \
        local_offset = local_offsets[local_idx];                 \
    } while (0)`;

enum string CHECK_BR(string depth) = `                                         \
    do {                                                        \
        if (!wasm_loader_check_br(loader_ctx, depth, error_buf, \
                                  error_buf_size))              \
            goto fail;                                          \
    } while (0)`;

enum string CHECK_MEMORY() = `                                                     \
    do {                                                                   \
        bh_assert(module->import_memory_count + module->memory_count > 0); \
    } while (0)`;

private bool wasm_loader_check_br(WASMLoaderContext* loader_ctx, uint depth, char* error_buf, uint error_buf_size) {
    BranchBlock* target_block = void, cur_block = void;
    BlockType* target_block_type = void;
    ubyte* types = null, frame_ref = void;
    uint arity = 0;
    int i = void, available_stack_cell = void;
    ushort cell_num = void;

    if (loader_ctx.csp_num < depth + 1) {
        set_error_buf(error_buf, error_buf_size,
                      "unknown label, "
                      ~ "unexpected end of section or function");
        return false;
    }

    cur_block = loader_ctx.frame_csp - 1;
    target_block = loader_ctx.frame_csp - (depth + 1);
    target_block_type = &target_block.block_type;
    frame_ref = loader_ctx.frame_ref;

    /* Note: loop's arity is different from if and block. loop's arity is
     * its parameter count while if and block arity is result count.
     */
    if (target_block.label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(target_block_type, &types);
    else
        arity = block_type_get_result_types(target_block_type, &types);

    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (cur_block.is_stack_polymorphic) {
        for (i = cast(int)arity - 1; i >= 0; i--) {
static if (WASM_ENABLE_FAST_INTERP != 0) {
            POP_OFFSET_TYPE(types[i]);
}
            POP_TYPE(types[i]);
        }
        for (i = 0; i < cast(int)arity; i++) {
static if (WASM_ENABLE_FAST_INTERP != 0) {
            bool disable_emit = true;
            short operand_offset = 0;
            PUSH_OFFSET_TYPE(types[i]);
}
            PUSH_TYPE(types[i]);
        }
        return true;
    }

    available_stack_cell =
        (int32)(loader_ctx.stack_cell_num - cur_block.stack_cell_num);

    /* Check stack top values match target block type */
    for (i = cast(int)arity - 1; i >= 0; i--) {
        if (!check_stack_top_values(frame_ref, available_stack_cell, types[i],
                                    error_buf, error_buf_size))
            return false;
        cell_num = wasm_value_type_cell_num(types[i]);
        frame_ref -= cell_num;
        available_stack_cell -= cell_num;
    }

    return true;

fail:
    return false;
}

private BranchBlock* check_branch_block(WASMLoaderContext* loader_ctx, ubyte** p_buf, ubyte* buf_end, char* error_buf, uint error_buf_size) {
    ubyte* p = *p_buf, p_end = buf_end;
    BranchBlock* frame_csp_tmp = void;
    uint depth = void;

    read_leb_uint32(p, p_end, depth);
    CHECK_BR(depth);
    frame_csp_tmp = loader_ctx.frame_csp - depth - 1;
static if (WASM_ENABLE_FAST_INTERP != 0) {
    emit_br_info(frame_csp_tmp);
}

    *p_buf = p;
    return frame_csp_tmp;
fail:
    return null;
}

private bool check_block_stack(WASMLoaderContext* loader_ctx, BranchBlock* block, char* error_buf, uint error_buf_size) {
    BlockType* block_type = &block.block_type;
    ubyte* return_types = null;
    uint return_count = 0;
    int available_stack_cell = void, return_cell_num = void, i = void;
    ubyte* frame_ref = null;

    available_stack_cell =
        (int32)(loader_ctx.stack_cell_num - block.stack_cell_num);

    return_count = block_type_get_result_types(block_type, &return_types);
    return_cell_num =
        return_count > 0 ? wasm_get_cell_num(return_types, return_count) : 0;

    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (block.is_stack_polymorphic) {
        for (i = cast(int)return_count - 1; i >= 0; i--) {
static if (WASM_ENABLE_FAST_INTERP != 0) {
            POP_OFFSET_TYPE(return_types[i]);
}
            POP_TYPE(return_types[i]);
        }

        /* Check stack is empty */
        bh_assert(loader_ctx.stack_cell_num == block.stack_cell_num);

        for (i = 0; i < cast(int)return_count; i++) {
static if (WASM_ENABLE_FAST_INTERP != 0) {
            bool disable_emit = true;
            short operand_offset = 0;
            PUSH_OFFSET_TYPE(return_types[i]);
}
            PUSH_TYPE(return_types[i]);
        }
        return true;
    }

    /* Check stack cell num equals return cell num */
    bh_assert(available_stack_cell == return_cell_num);

    /* Check stack values match return types */
    frame_ref = loader_ctx.frame_ref;
    for (i = cast(int)return_count - 1; i >= 0; i--) {
        if (!check_stack_top_values(frame_ref, available_stack_cell,
                                    return_types[i], error_buf, error_buf_size))
            return false;
        frame_ref -= wasm_value_type_cell_num(return_types[i]);
        available_stack_cell -= wasm_value_type_cell_num(return_types[i]);
    }

    cast(void)return_cell_num;
    return true;

fail:
    return false;
}

static if (WASM_ENABLE_FAST_INTERP != 0) {
/* Copy parameters to dynamic space.
 * 1) POP original parameter out;
 * 2) Push and copy original values to dynamic space.
 * The copy instruction format:
 *   Part a: param count
 *   Part b: all param total cell num
 *   Part c: each param's cell_num, src offset and dst offset
 *   Part d: each param's src offset
 *   Part e: each param's dst offset
 */
private bool copy_params_to_dynamic_space(WASMLoaderContext* loader_ctx, bool is_if_block, char* error_buf, uint error_buf_size) {
    short* frame_offset = null;
    ubyte* cells = null; ubyte cell = void;
    short* src_offsets = null;
    ubyte* emit_data = null;
    uint i = void;
    BranchBlock* block = loader_ctx.frame_csp - 1;
    BlockType* block_type = &block.block_type;
    WASMType* wasm_type = block_type.u.type;
    uint param_count = block_type.u.type.param_count;
    short condition_offset = 0;
    bool disable_emit = false;
    short operand_offset = 0;

    ulong size = cast(ulong)param_count * (sizeof(*cells) + typeof(*src_offsets).sizeof);

    /* For if block, we also need copy the condition operand offset. */
    if (is_if_block)
        size += sizeof(*cells) + typeof(*src_offsets).sizeof;

    /* Allocate memory for the emit data */
    if (((emit_data = loader_malloc(size, error_buf, error_buf_size)) == 0))
        return false;

    cells = emit_data;
    src_offsets = cast(short*)(cells + param_count);

    if (is_if_block)
        condition_offset = *loader_ctx.frame_offset;

    /* POP original parameter out */
    for (i = 0; i < param_count; i++) {
        POP_OFFSET_TYPE(wasm_type.types[param_count - i - 1]);
        wasm_loader_emit_backspace(loader_ctx, int16.sizeof);
    }
    frame_offset = loader_ctx.frame_offset;

    /* Get each param's cell num and src offset */
    for (i = 0; i < param_count; i++) {
        cell = cast(ubyte)wasm_value_type_cell_num(wasm_type.types[i]);
        cells[i] = cell;
        src_offsets[i] = *frame_offset;
        frame_offset += cell;
    }

    /* emit copy instruction */
    emit_label(EXT_OP_COPY_STACK_VALUES);
    /* Part a) */
    emit_uint32(loader_ctx, is_if_block ? param_count + 1 : param_count);
    /* Part b) */
    emit_uint32(loader_ctx, is_if_block ? wasm_type.param_cell_num + 1
                                        : wasm_type.param_cell_num);
    /* Part c) */
    for (i = 0; i < param_count; i++)
        emit_byte(loader_ctx, cells[i]);
    if (is_if_block)
        emit_byte(loader_ctx, 1);

    /* Part d) */
    for (i = 0; i < param_count; i++)
        emit_operand(loader_ctx, src_offsets[i]);
    if (is_if_block)
        emit_operand(loader_ctx, condition_offset);

    /* Part e) */
    /* Push to dynamic space. The push will emit the dst offset. */
    for (i = 0; i < param_count; i++)
        PUSH_OFFSET_TYPE(wasm_type.types[i]);
    if (is_if_block)
        PUSH_OFFSET_TYPE(VALUE_TYPE_I32);

    /* Free the emit data */
    wasm_runtime_free(emit_data);
    return true;

fail:
    /* Free the emit data */
    wasm_runtime_free(emit_data);
    return false;
}
}

/* reset the stack to the state of before entering the last block */
static if (WASM_ENABLE_FAST_INTERP != 0) {
enum string RESET_STACK() = `                                                     \
    do {                                                                  \
        loader_ctx->stack_cell_num =                                      \
            (loader_ctx->frame_csp - 1)->stack_cell_num;                  \
        loader_ctx->frame_ref =                                           \
            loader_ctx->frame_ref_bottom + loader_ctx->stack_cell_num;    \
        loader_ctx->frame_offset =                                        \
            loader_ctx->frame_offset_bottom + loader_ctx->stack_cell_num; \
    } while (0)`;
} else {
enum string RESET_STACK() = `                                                  \
    do {                                                               \
        loader_ctx->stack_cell_num =                                   \
            (loader_ctx->frame_csp - 1)->stack_cell_num;               \
        loader_ctx->frame_ref =                                        \
            loader_ctx->frame_ref_bottom + loader_ctx->stack_cell_num; \
    } while (0)`;
}

/* set current block's stack polymorphic state */
enum string SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(string flag) = `          \
    do {                                                     \
        BranchBlock *_cur_block = loader_ctx->frame_csp - 1; \
        _cur_block->is_stack_polymorphic = flag;             \
    } while (0)`;

enum string BLOCK_HAS_PARAM(string block_type) = ` \
    (!block_type.is_value_type && block_type.u.type->param_count > 0)`;

enum string PRESERVE_LOCAL_FOR_BLOCK() = `                                    \
    do {                                                              \
        if (!(preserve_local_for_block(loader_ctx, opcode, error_buf, \
                                       error_buf_size))) {            \
            goto fail;                                                \
        }                                                             \
    } while (0)`;

static bool
wasm_loader_prepare_bytecode(WASMModule* module_, WASMFunction* func,
                             uint cur_func_idx, char* error_buf,
                             uint error_buf_size)
{
    ubyte* p = func.code, p_end = func.code + func.code_size, p_org;
    uint param_count, local_count, global_count;
    ubyte* param_types, local_types; ubyte local_type, global_type;
    BlockType func_block_type;
    ushort* local_offsets; ushort local_offset;
    uint count, local_idx, global_idx, u32, align_, mem_offset, i;
    int i32, i32_const = 0;
    long i64_const;
    ubyte opcode, u8;
    bool return_value = false;
    WASMLoaderContext* loader_ctx;
    BranchBlock* frame_csp_tmp;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    uint segment_index;
}
static if (WASM_ENABLE_FAST_INTERP != 0) {
    ubyte* func_const_end, func_const = null;
    short operand_offset = 0;
    ubyte last_op = 0;
    bool disable_emit, preserve_local = false;
    float32 f32_const;
    float64 f64_const;

    LOG_OP("\nProcessing func | [%d] params | [%d] locals | [%d] return\n",
           func.param_cell_num, func.local_cell_num, func.ret_cell_num);
}

    global_count = module_.import_global_count + module_.global_count;

    param_count = func.func_type.param_count;
    param_types = func.func_type.types;

    func_block_type.is_value_type = false;
    func_block_type.u.type = func.func_type;

    local_count = func.local_count;
    local_types = func.local_types;
    local_offsets = func.local_offsets;

    if (((loader_ctx = wasm_loader_ctx_init(func, error_buf, error_buf_size)) == 0)) {
        goto fail;
    }

static if (WASM_ENABLE_FAST_INTERP != 0) {
    /* For the first traverse, the initial value of preserved_local_offset has
     * not been determined, we use the INT16_MAX to represent that a slot has
     * been copied to preserve space. For second traverse, this field will be
     * set to the appropriate value in wasm_loader_ctx_reinit.
     * This is for Issue #1230,
     * https://github.com/bytecodealliance/wasm-micro-runtime/issues/1230, the
     * drop opcodes need to know which slots are preserved, so those slots will
     * not be treated as dynamically allocated slots */
    loader_ctx.preserved_local_offset = INT16_MAX;

re_scan:
    if (loader_ctx.code_compiled_size > 0) {
        if (!wasm_loader_ctx_reinit(loader_ctx)) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
            goto fail;
        }
        p = func.code;
        func.code_compiled = loader_ctx.p_code_compiled;
        func.code_compiled_size = loader_ctx.code_compiled_size;
    }
}

    PUSH_CSP(LABEL_TYPE_FUNCTION, func_block_type, p);

    while (p < p_end) {
        opcode = *p++;
static if (WASM_ENABLE_FAST_INTERP != 0) {
        p_org = p;
        disable_emit = false;
        emit_label(opcode);
}

        switch (opcode) {
            case WASM_OP_UNREACHABLE:
                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;

            case WASM_OP_NOP:
static if (WASM_ENABLE_FAST_INTERP != 0) {
                skip_label();
}
                break;

            case WASM_OP_IF:
static if (WASM_ENABLE_FAST_INTERP != 0) {
                PRESERVE_LOCAL_FOR_BLOCK();
}
                POP_I32();
                goto handle_op_block_and_loop;
            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
static if (WASM_ENABLE_FAST_INTERP != 0) {
                PRESERVE_LOCAL_FOR_BLOCK();
}
            handle_op_block_and_loop:
            {
                ubyte value_type;
                BlockType block_type;

                p_org = p - 1;
                value_type = read_uint8(p);
                if (is_byte_a_type(value_type)) {
                    /* If the first byte is one of these special values:
                     * 0x40/0x7F/0x7E/0x7D/0x7C, take it as the type of
                     * the single return value. */
                    block_type.is_value_type = true;
                    block_type.u.value_type = value_type;
                }
                else {
                    uint type_index;
                    /* Resolve the leb128 encoded type index as block type */
                    p--;
                    read_leb_uint32(p, p_end, type_index);
                    bh_assert(type_index < module_.type_count);
                    block_type.is_value_type = false;
                    block_type.u.type = module_.types[type_index];
static if (WASM_ENABLE_FAST_INTERP == 0) {
                    /* If block use type index as block type, change the opcode
                     * to new extended opcode so that interpreter can resolve
                     * the block quickly.
                     */
                    *p_org = EXT_OP_BLOCK + (opcode - WASM_OP_BLOCK);
}
                }

                /* Pop block parameters from stack */
                if (BLOCK_HAS_PARAM(block_type)) {
                    WASMType* wasm_type = block_type.u.type;
                    for (i = 0; i < block_type.u.type.param_count; i++)
                        POP_TYPE(
                            wasm_type.types[wasm_type.param_count - i - 1]);
                }

                PUSH_CSP(LABEL_TYPE_BLOCK + (opcode - WASM_OP_BLOCK),
                         block_type, p);

                /* Pass parameters to block */
                if (BLOCK_HAS_PARAM(block_type)) {
                    for (i = 0; i < block_type.u.type.param_count; i++)
                        PUSH_TYPE(block_type.u.type.types[i]);
                }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                if (opcode == WASM_OP_BLOCK) {
                    skip_label();
                }
                else if (opcode == WASM_OP_LOOP) {
                    skip_label();
                    if (BLOCK_HAS_PARAM(block_type)) {
                        /* Make sure params are in dynamic space */
                        if (!copy_params_to_dynamic_space(
                                loader_ctx, false, error_buf, error_buf_size))
                            goto fail;
                    }
                    (loader_ctx.frame_csp - 1).code_compiled =
                        loader_ctx.p_code_compiled;
                }
                else if (opcode == WASM_OP_IF) {
                    /* If block has parameters, we should make sure they are in
                     * dynamic space. Otherwise, when else branch is missing,
                     * the later opcode may consume incorrect operand offset.
                     * Spec case:
                     *   (func (export "params-id") (param i32) (result i32)
                     *       (i32.const 1)
                     *       (i32.const 2)
                     *       (if (param i32 i32) (result i32 i32) (local.get 0)
                     * (then)) (i32.add)
                     *   )
                     *
                     * So we should emit a copy instruction before the if.
                     *
                     * And we also need to save the parameter offsets and
                     * recover them before entering else branch.
                     *
                     */
                    if (BLOCK_HAS_PARAM(block_type)) {
                        BranchBlock* block = loader_ctx.frame_csp - 1;
                        ulong size;

                        /* skip the if condition operand offset */
                        wasm_loader_emit_backspace(loader_ctx, int16.sizeof);
                        /* skip the if label */
                        skip_label();
                        /* Emit a copy instruction */
                        if (!copy_params_to_dynamic_space(
                                loader_ctx, true, error_buf, error_buf_size))
                            goto fail;

                        /* Emit the if instruction */
                        emit_label(opcode);
                        /* Emit the new condition operand offset */
                        POP_OFFSET_TYPE(VALUE_TYPE_I32);

                        /* Save top param_count values of frame_offset stack, so
                         * that we can recover it before executing else branch
                         */
                        size = sizeof(int16)
                               * cast(ulong)block_type.u.type.param_cell_num;
                        if (((block.param_frame_offsets = loader_malloc(
                                  size, error_buf, error_buf_size)) == 0))
                            goto fail;
                        bh_memcpy_s(block.param_frame_offsets, cast(uint)size,
                                    loader_ctx.frame_offset
                                        - size / int16.sizeof,
                                    cast(uint)size);
                    }

                    emit_empty_label_addr_and_frame_ip(PATCH_ELSE);
                    emit_empty_label_addr_and_frame_ip(PATCH_END);
                }
}
                break;
            }

            case WASM_OP_ELSE:
            {
                BlockType block_type = (loader_ctx.frame_csp - 1).block_type;
                bh_assert(loader_ctx.csp_num >= 2
                          && (loader_ctx.frame_csp - 1).label_type
                                 == LABEL_TYPE_IF);

                /* check whether if branch's stack matches its result type */
                if (!check_block_stack(loader_ctx, loader_ctx.frame_csp - 1,
                                       error_buf, error_buf_size))
                    goto fail;

                (loader_ctx.frame_csp - 1).else_addr = p - 1;

static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* if the result of if branch is in local or const area, add a
                 * copy op */
                RESERVE_BLOCK_RET();

                emit_empty_label_addr_and_frame_ip(PATCH_END);
                apply_label_patch(loader_ctx, 1, PATCH_ELSE);
}
                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(false);

                /* Pass parameters to if-false branch */
                if (BLOCK_HAS_PARAM(block_type)) {
                    for (i = 0; i < block_type.u.type.param_count; i++)
                        PUSH_TYPE(block_type.u.type.types[i]);
                }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* Recover top param_count values of frame_offset stack */
                if (BLOCK_HAS_PARAM((block_type))) {
                    uint size;
                    BranchBlock* block = loader_ctx.frame_csp - 1;
                    size = sizeof(int16) * block_type.u.type.param_cell_num;
                    bh_memcpy_s(loader_ctx.frame_offset, size,
                                block.param_frame_offsets, size);
                    loader_ctx.frame_offset += (size / int16.sizeof);
                }
}

                break;
            }

            case WASM_OP_END:
            {
                BranchBlock* cur_block = loader_ctx.frame_csp - 1;

                /* check whether block stack matches its result type */
                if (!check_block_stack(loader_ctx, cur_block, error_buf,
                                       error_buf_size))
                    goto fail;

                /* if no else branch, and return types do not match param types,
                 * fail */
                if (cur_block.label_type == LABEL_TYPE_IF
                    && !cur_block.else_addr) {
                    uint block_param_count = 0, block_ret_count = 0;
                    ubyte* block_param_types = null, block_ret_types = null;
                    BlockType* cur_block_type = &cur_block.block_type;
                    if (cur_block_type.is_value_type) {
                        if (cur_block_type.u.value_type != VALUE_TYPE_VOID) {
                            block_ret_count = 1;
                            block_ret_types = &cur_block_type.u.value_type;
                        }
                    }
                    else {
                        block_param_count = cur_block_type.u.type.param_count;
                        block_ret_count = cur_block_type.u.type.result_count;
                        block_param_types = cur_block_type.u.type.types;
                        block_ret_types =
                            cur_block_type.u.type.types + block_param_count;
                    }
                    bh_assert(block_param_count == block_ret_count
                              && (!block_param_count
                                  || !memcmp(block_param_types, block_ret_types,
                                             block_param_count)));
                    cast(void)block_ret_types;
                    cast(void)block_ret_count;
                    cast(void)block_param_types;
                }

                POP_CSP();

static if (WASM_ENABLE_FAST_INTERP != 0) {
                skip_label();
                /* copy the result to the block return address */
                RESERVE_BLOCK_RET();

                apply_label_patch(loader_ctx, 0, PATCH_END);
                free_label_patch_list(loader_ctx.frame_csp);
                if (loader_ctx.frame_csp.label_type == LABEL_TYPE_FUNCTION) {
                    int idx;
                    ubyte ret_type;

                    emit_label(WASM_OP_RETURN);
                    for (idx = cast(int)func.func_type.result_count - 1;
                         idx >= 0; idx--) {
                        ret_type = *(func.func_type.types
                                     + func.func_type.param_count + idx);
                        POP_OFFSET_TYPE(ret_type);
                    }
                }
}
                if (loader_ctx.csp_num > 0) {
                    loader_ctx.frame_csp.end_addr = p - 1;
                }
                else {
                    /* end of function block, function will return */
                    bh_assert(p == p_end);
                }

                break;
            }

            case WASM_OP_BR:
            {
                if (((frame_csp_tmp = check_branch_block(
                          loader_ctx, &p, p_end, error_buf, error_buf_size)) == 0))
                    goto fail;

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;
            }

            case WASM_OP_BR_IF:
            {
                POP_I32();

                if (((frame_csp_tmp = check_branch_block(
                          loader_ctx, &p, p_end, error_buf, error_buf_size)) == 0))
                    goto fail;

                break;
            }

            case WASM_OP_BR_TABLE:
            {
                ubyte* ret_types = null;
                uint ret_count = 0;
static if (WASM_ENABLE_FAST_INTERP == 0) {
                ubyte* p_depth_begin, p_depth;
                uint depth, j;
                BrTableCache* br_table_cache = null;

                p_org = p - 1;
}

                read_leb_uint32(p, p_end, count);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                emit_uint32(loader_ctx, count);
}
                POP_I32();

static if (WASM_ENABLE_FAST_INTERP == 0) {
                p_depth_begin = p_depth = p;
}
                for (i = 0; i <= count; i++) {
                    if (((frame_csp_tmp =
                              check_branch_block(loader_ctx, &p, p_end,
                                                 error_buf, error_buf_size)) == 0))
                        goto fail;

static if (WASM_ENABLE_FAST_INTERP == 0) {
                    depth = (uint32)(loader_ctx.frame_csp - 1 - frame_csp_tmp);
                    if (br_table_cache) {
                        br_table_cache.br_depths[i] = depth;
                    }
                    else {
                        if (depth > 255) {
                            /* The depth cannot be stored in one byte,
                               create br_table cache to store each depth */
                            if (((br_table_cache = loader_malloc(
                                      BrTableCache.br_depths.offsetof
                                          + sizeof(uint32)
                                                * (uint64)(count + 1),
                                      error_buf, error_buf_size)) == 0)) {
                                goto fail;
                            }
                            *p_org = EXT_OP_BR_TABLE_CACHE;
                            br_table_cache.br_table_op_addr = p_org;
                            br_table_cache.br_count = count;
                            /* Copy previous depths which are one byte */
                            for (j = 0; j < i; j++) {
                                br_table_cache.br_depths[j] = p_depth_begin[j];
                            }
                            br_table_cache.br_depths[i] = depth;
                            bh_list_insert(module_.br_table_cache_list,
                                           br_table_cache);
                        }
                        else {
                            /* The depth can be stored in one byte, use the
                               byte of the leb to store it */
                            *p_depth++ = cast(ubyte)depth;
                        }
                    }
}
                }

static if (WASM_ENABLE_FAST_INTERP == 0) {
                /* Set the tailing bytes to nop */
                if (br_table_cache)
                    p_depth = p_depth_begin;
                while (p_depth < p)
                    *p_depth++ = WASM_OP_NOP;
}

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);

                cast(void)ret_count;
                cast(void)ret_types;
                break;
            }

            case WASM_OP_RETURN:
            {
                int idx;
                ubyte ret_type;
                for (idx = cast(int)func.func_type.result_count - 1; idx >= 0;
                     idx--) {
                    ret_type = *(func.func_type.types
                                 + func.func_type.param_count + idx);
                    POP_TYPE(ret_type);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    /* emit the offset after return opcode */
                    POP_OFFSET_TYPE(ret_type);
}
                }

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);

                break;
            }

            case WASM_OP_CALL:
static if (WASM_ENABLE_TAIL_CALL != 0) {
            case WASM_OP_RETURN_CALL:
}
            {
                WASMType* func_type;
                uint func_idx;
                int idx;

                read_leb_uint32(p, p_end, func_idx);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* we need to emit func_idx before arguments */
                emit_uint32(loader_ctx, func_idx);
}

                bh_assert(func_idx < module_.import_function_count
                                         + module_.function_count);

                if (func_idx < module_.import_function_count)
                    func_type =
                        module_.import_functions[func_idx].u.function_.func_type;
                else
                    func_type = module_
                                    .functions[func_idx
                                                - module_.import_function_count]
                                    .func_type;

                if (func_type.param_count > 0) {
                    for (idx = (int32)(func_type.param_count - 1); idx >= 0;
                         idx--) {
                        POP_TYPE(func_type.types[idx]);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        POP_OFFSET_TYPE(func_type.types[idx]);
}
                    }
                }

#if WASM_ENABLE_TAIL_CALL != 0
                if (opcode == WASM_OP_CALL) {
//! #endif
                    for (i = 0; i < func_type->result_count; i++) {
                        PUSH_TYPE(func_type.types[func_type.param_count + i]);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        /* Here we emit each return value's dynamic_offset. But
                         * in fact these offsets are continuous, so interpreter
                         * only need to get the first return value's offset.
                         */
                        PUSH_OFFSET_TYPE(
                            func_type.types[func_type.param_count + i]);
}
                    }
static if (WASM_ENABLE_TAIL_CALL != 0) {
                }
                else {
                    bh_assert(func_type.result_count
                              == func.func_type.result_count);
                    for (i = 0; i < func_type.result_count; i++) {
                        bh_assert(
                            func_type.types[func_type.param_count + i]
                            == func.func_type
                                   .types[func.func_type.param_count + i]);
                    }
                }
}
static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_op_func_call = true;
}
                break;
            }

            case WASM_OP_CALL_INDIRECT:
static if (WASM_ENABLE_TAIL_CALL != 0) {
            case WASM_OP_RETURN_CALL_INDIRECT:
}
            {
                int idx;
                WASMType* func_type;
                uint type_idx, table_idx;

                bh_assert(module_.import_table_count + module_.table_count > 0);

                read_leb_uint32(p, p_end, type_idx);

static if (WASM_ENABLE_REF_TYPES != 0) {
                read_leb_uint32(p, p_end, table_idx);
} else {
                CHECK_BUF(p, p_end, 1);
                table_idx = read_uint8(p);
}
                if (!check_table_index(module_, table_idx, error_buf,
                                       error_buf_size)) {
                    goto fail;
                }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* we need to emit before arguments */
                emit_uint32(loader_ctx, type_idx);
                emit_uint32(loader_ctx, table_idx);
}

                /* skip elem idx */
                POP_I32();

                bh_assert(type_idx < module_.type_count);

                func_type = module_.types[type_idx];

                if (func_type.param_count > 0) {
                    for (idx = (int32)(func_type.param_count - 1); idx >= 0;
                         idx--) {
                        POP_TYPE(func_type.types[idx]);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        POP_OFFSET_TYPE(func_type.types[idx]);
}
                    }
                }

static if (WASM_ENABLE_TAIL_CALL != 0) {
                if (opcode == WASM_OP_CALL) {
//! #endif
                    for (i = 0; i < func_type->result_count; i++) {
                        PUSH_TYPE(func_type.types[func_type.param_count + i]);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        PUSH_OFFSET_TYPE(
                            func_type.types[func_type.param_count + i]);
}
                    }
static if (WASM_ENABLE_TAIL_CALL != 0) {
                }
                else {
                    bh_assert(func_type.result_count
                              == func.func_type.result_count);
                    for (i = 0; i < func_type.result_count; i++) {
                        bh_assert(
                            func_type.types[func_type.param_count + i]
                            == func.func_type
                                   .types[func.func_type.param_count + i]);
                    }
                }
}

static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_op_func_call = true;
}
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_op_call_indirect = true;
}
                break;
            }

            case WASM_OP_DROP:
            {
                BranchBlock* cur_block = loader_ctx.frame_csp - 1;
                int available_stack_cell = (int32)(loader_ctx.stack_cell_num
                            - cur_block.stack_cell_num);

                bh_assert(!(available_stack_cell <= 0
                            && !cur_block.is_stack_polymorphic));

                if (available_stack_cell > 0) {
                    if (is_32bit_type(*(loader_ctx.frame_ref - 1))) {
                        loader_ctx.frame_ref--;
                        loader_ctx.stack_cell_num--;
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        skip_label();
                        loader_ctx.frame_offset--;
                        if ((*(loader_ctx.frame_offset)
                             > loader_ctx.start_dynamic_offset)
                            && (*(loader_ctx.frame_offset)
                                < loader_ctx.max_dynamic_offset))
                            loader_ctx.dynamic_offset--;
}
                    }
                    else if (is_64bit_type(*(loader_ctx.frame_ref - 1))) {
                        loader_ctx.frame_ref -= 2;
                        loader_ctx.stack_cell_num -= 2;
static if (WASM_ENABLE_FAST_INTERP == 0) {
                        *(p - 1) = WASM_OP_DROP_64;
}
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        skip_label();
                        loader_ctx.frame_offset -= 2;
                        if ((*(loader_ctx.frame_offset)
                             > loader_ctx.start_dynamic_offset)
                            && (*(loader_ctx.frame_offset)
                                < loader_ctx.max_dynamic_offset))
                            loader_ctx.dynamic_offset -= 2;
}
                    }
                    else {
                        bh_assert(0);
                    }
                }
                else {
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    skip_label();
}
                }
                break;
            }

            case WASM_OP_SELECT:
            {
                ubyte ref_type;
                BranchBlock* cur_block = loader_ctx.frame_csp - 1;
                int available_stack_cell;

                POP_I32();

                available_stack_cell = (int32)(loader_ctx.stack_cell_num
                                               - cur_block.stack_cell_num);

                bh_assert(!(available_stack_cell <= 0
                            && !cur_block.is_stack_polymorphic));

                if (available_stack_cell > 0) {
                    switch (*(loader_ctx.frame_ref - 1)) {
                        case REF_I32:
                        case REF_F32:
                            break;
                        case REF_I64_2:
                        case REF_F64_2:
static if (WASM_ENABLE_FAST_INTERP == 0) {
                            *(p - 1) = WASM_OP_SELECT_64;
}
static if (WASM_ENABLE_FAST_INTERP != 0) {
                            if (loader_ctx.p_code_compiled) {
                                ubyte opcode_tmp = WASM_OP_SELECT_64;
                                ubyte* p_code_compiled_tmp = loader_ctx.p_code_compiled - 2;
static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
                                *cast(void**)(p_code_compiled_tmp
                                           - (void*).sizeof) =
                                    handle_table[opcode_tmp];
} else {
                                int offset = (int32)(cast(ubyte*)handle_table[opcode_tmp]
                                            - cast(ubyte*)handle_table[0]);
                                if (!(offset >= INT16_MIN
                                      && offset < INT16_MAX)) {
                                    set_error_buf(error_buf, error_buf_size,
                                                  "pre-compiled label offset "
                                                  ~ "out of range");
                                    goto fail;
                                }
                                *cast(short*)(p_code_compiled_tmp
                                           - int16.sizeof) = cast(short)offset;
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
} else {  /* else of WASM_ENABLE_LABELS_AS_VALUES */
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
                                *(p_code_compiled_tmp - 1) = opcode_tmp;
} else {
                                *(p_code_compiled_tmp - 2) = opcode_tmp;
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
} /* end of WASM_ENABLE_LABELS_AS_VALUES */
                            }
}
                            break;
                    default: break;}

                    ref_type = *(loader_ctx.frame_ref - 1);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    POP_OFFSET_TYPE(ref_type);
}
                    POP_TYPE(ref_type);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    POP_OFFSET_TYPE(ref_type);
}
                    POP_TYPE(ref_type);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    PUSH_OFFSET_TYPE(ref_type);
}
                    PUSH_TYPE(ref_type);
                }
                else {
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    PUSH_OFFSET_TYPE(VALUE_TYPE_ANY);
}
                    PUSH_TYPE(VALUE_TYPE_ANY);
                }
                break;
            }

static if (WASM_ENABLE_REF_TYPES != 0) {
            case WASM_OP_SELECT_T:
            {
                ubyte vec_len, ref_type;

                read_leb_uint32(p, p_end, vec_len);
                if (!vec_len) {
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid result arity");
                    goto fail;
                }

                CHECK_BUF(p, p_end, 1);
                ref_type = read_uint8(p);
                if (!is_value_type(ref_type)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unknown value type");
                    goto fail;
                }

                POP_I32();

static if (WASM_ENABLE_FAST_INTERP != 0) {
                if (loader_ctx.p_code_compiled) {
                    ubyte opcode_tmp = WASM_OP_SELECT;
                    ubyte* p_code_compiled_tmp = loader_ctx.p_code_compiled - 2;

                    if (ref_type == VALUE_TYPE_F64
                        || ref_type == VALUE_TYPE_I64)
                        opcode_tmp = WASM_OP_SELECT_64;

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
                    *cast(void**)(p_code_compiled_tmp - (void*).sizeof) =
                        handle_table[opcode_tmp];
} else {
                    int offset = (int32)(cast(ubyte*)handle_table[opcode_tmp]
                                           - cast(ubyte*)handle_table[0]);
                    if (!(offset >= INT16_MIN && offset < INT16_MAX)) {
                        set_error_buf(error_buf, error_buf_size,
                                      "pre-compiled label offset out of range");
                        goto fail;
                    }
                    *cast(short*)(p_code_compiled_tmp - int16.sizeof) =
                        cast(short)offset;
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
} else {  /* else of WASM_ENABLE_LABELS_AS_VALUES */
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
                    *(p_code_compiled_tmp - 1) = opcode_tmp;
} else {
                    *(p_code_compiled_tmp - 2) = opcode_tmp;
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
} /* end of WASM_ENABLE_LABELS_AS_VALUES */
                }
} /* WASM_ENABLE_FAST_INTERP != 0 */

static if (WASM_ENABLE_FAST_INTERP != 0) {
                POP_OFFSET_TYPE(ref_type);
                POP_TYPE(ref_type);
                POP_OFFSET_TYPE(ref_type);
                POP_TYPE(ref_type);
                PUSH_OFFSET_TYPE(ref_type);
                PUSH_TYPE(ref_type);
} else {
                POP2_AND_PUSH(ref_type, ref_type);
} /* WASM_ENABLE_FAST_INTERP != 0 */

                cast(void)vec_len;
                break;
            }

            /* table.get x. tables[x]. [i32] -> [t] */
            /* table.set x. tables[x]. [i32 t] -> [] */
            case WASM_OP_TABLE_GET:
            case WASM_OP_TABLE_SET:
            {
                ubyte decl_ref_type;
                uint table_idx;

                read_leb_uint32(p, p_end, table_idx);
                if (!get_table_elem_type(module_, table_idx, &decl_ref_type,
                                         error_buf, error_buf_size))
                    goto fail;

static if (WASM_ENABLE_FAST_INTERP != 0) {
                emit_uint32(loader_ctx, table_idx);
}

                if (opcode == WASM_OP_TABLE_GET) {
                    POP_I32();
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    PUSH_OFFSET_TYPE(decl_ref_type);
}
                    PUSH_TYPE(decl_ref_type);
                }
                else {
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    POP_OFFSET_TYPE(decl_ref_type);
}
                    POP_TYPE(decl_ref_type);
                    POP_I32();
                }
                break;
            }
            case WASM_OP_REF_NULL:
            {
                ubyte ref_type;

                CHECK_BUF(p, p_end, 1);
                ref_type = read_uint8(p);
                if (ref_type != VALUE_TYPE_FUNCREF
                    && ref_type != VALUE_TYPE_EXTERNREF) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unknown value type");
                    goto fail;
                }
static if (WASM_ENABLE_FAST_INTERP != 0) {
                PUSH_OFFSET_TYPE(ref_type);
}
                PUSH_TYPE(ref_type);
                break;
            }
            case WASM_OP_REF_IS_NULL:
            {
static if (WASM_ENABLE_FAST_INTERP != 0) {
                if (!wasm_loader_pop_frame_ref_offset(loader_ctx,
                                                      VALUE_TYPE_FUNCREF,
                                                      error_buf, error_buf_size)
                    && !wasm_loader_pop_frame_ref_offset(
                        loader_ctx, VALUE_TYPE_EXTERNREF, error_buf,
                        error_buf_size)) {
                    goto fail;
                }
} else {
                if (!wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_FUNCREF,
                                               error_buf, error_buf_size)
                    && !wasm_loader_pop_frame_ref(loader_ctx,
                                                  VALUE_TYPE_EXTERNREF,
                                                  error_buf, error_buf_size)) {
                    goto fail;
                }
}
                PUSH_I32();
                break;
            }
            case WASM_OP_REF_FUNC:
            {
                uint func_idx = 0;
                read_leb_uint32(p, p_end, func_idx);

                if (!check_function_index(module_, func_idx, error_buf,
                                          error_buf_size)) {
                    goto fail;
                }

                if (func_idx == cur_func_idx + module_.import_function_count) {
                    WASMTableSeg* table_seg = module_.table_segments;
                    bool func_declared = false;
                    uint j;

                    /* Check whether current function is declared */
                    for (i = 0; i < module_.table_seg_count; i++, table_seg++) {
                        if (table_seg.elem_type == VALUE_TYPE_FUNCREF
                            && wasm_elem_is_declarative(table_seg.mode)) {
                            for (j = 0; j < table_seg.function_count; j++) {
                                if (table_seg.func_indexes[j] == func_idx) {
                                    func_declared = true;
                                    break;
                                }
                            }
                        }
                    }
                    if (!func_declared) {
                        set_error_buf(error_buf, error_buf_size,
                                      "undeclared function reference");
                        goto fail;
                    }
                }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                emit_uint32(loader_ctx, func_idx);
}
                PUSH_FUNCREF();
                break;
            }
} /* WASM_ENABLE_REF_TYPES */

            case WASM_OP_GET_LOCAL:
            {
                p_org = p - 1;
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
                PUSH_TYPE(local_type);

static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* Get Local is optimized out */
                skip_label();
                disable_emit = true;
                operand_offset = local_offset;
                PUSH_OFFSET_TYPE(local_type);
} else {
static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_FAST_JIT == 0)) {
                if (local_offset < 0x80) {
                    *p_org++ = EXT_OP_GET_LOCAL_FAST;
                    if (is_32bit_type(local_type))
                        *p_org++ = cast(ubyte)local_offset;
                    else
                        *p_org++ = (uint8)(local_offset | 0x80);
                    while (p_org < p)
                        *p_org++ = WASM_OP_NOP;
                }
}
}
                break;
            }

            case WASM_OP_SET_LOCAL:
            {
                p_org = p - 1;
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
                POP_TYPE(local_type);

static if (WASM_ENABLE_FAST_INTERP != 0) {
                if (!(preserve_referenced_local(
                        loader_ctx, opcode, local_offset, local_type,
                        &preserve_local, error_buf, error_buf_size)))
                    goto fail;

                if (local_offset < 256) {
                    skip_label();
                    if ((!preserve_local) && (LAST_OP_OUTPUT_I32())) {
                        if (loader_ctx.p_code_compiled)
                            STORE_U16(loader_ctx.p_code_compiled - 2,
                                      local_offset);
                        loader_ctx.frame_offset--;
                        loader_ctx.dynamic_offset--;
                    }
                    else if ((!preserve_local) && (LAST_OP_OUTPUT_I64())) {
                        if (loader_ctx.p_code_compiled)
                            STORE_U16(loader_ctx.p_code_compiled - 2,
                                      local_offset);
                        loader_ctx.frame_offset -= 2;
                        loader_ctx.dynamic_offset -= 2;
                    }
                    else {
                        if (is_32bit_type(local_type)) {
                            emit_label(EXT_OP_SET_LOCAL_FAST);
                            emit_byte(loader_ctx, cast(ubyte)local_offset);
                        }
                        else {
                            emit_label(EXT_OP_SET_LOCAL_FAST_I64);
                            emit_byte(loader_ctx, cast(ubyte)local_offset);
                        }
                        POP_OFFSET_TYPE(local_type);
                    }
                }
                else { /* local index larger than 255, reserve leb */
                    emit_uint32(loader_ctx, local_idx);
                    POP_OFFSET_TYPE(local_type);
                }
} else {
static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_FAST_JIT == 0)) {
                if (local_offset < 0x80) {
                    *p_org++ = EXT_OP_SET_LOCAL_FAST;
                    if (is_32bit_type(local_type))
                        *p_org++ = cast(ubyte)local_offset;
                    else
                        *p_org++ = (uint8)(local_offset | 0x80);
                    while (p_org < p)
                        *p_org++ = WASM_OP_NOP;
                }
}
}
                break;
            }

            case WASM_OP_TEE_LOCAL:
            {
                p_org = p - 1;
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* If the stack is in polymorphic state, do fake pop and push on
                    offset stack to keep the depth of offset stack to be the
                   same with ref stack */
                BranchBlock* cur_block = loader_ctx.frame_csp - 1;
                if (cur_block.is_stack_polymorphic) {
                    POP_OFFSET_TYPE(local_type);
                    PUSH_OFFSET_TYPE(local_type);
                }
}
                POP_TYPE(local_type);
                PUSH_TYPE(local_type);

static if (WASM_ENABLE_FAST_INTERP != 0) {
                if (!(preserve_referenced_local(
                        loader_ctx, opcode, local_offset, local_type,
                        &preserve_local, error_buf, error_buf_size)))
                    goto fail;

                if (local_offset < 256) {
                    skip_label();
                    if (is_32bit_type(local_type)) {
                        emit_label(EXT_OP_TEE_LOCAL_FAST);
                        emit_byte(loader_ctx, cast(ubyte)local_offset);
                    }
                    else {
                        emit_label(EXT_OP_TEE_LOCAL_FAST_I64);
                        emit_byte(loader_ctx, cast(ubyte)local_offset);
                    }
                }
                else { /* local index larger than 255, reserve leb */
                    emit_uint32(loader_ctx, local_idx);
                }
                emit_operand(loader_ctx,
                             *(loader_ctx.frame_offset
                               - wasm_value_type_cell_num(local_type)));
} else {
static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_FAST_JIT == 0)) {
                if (local_offset < 0x80) {
                    *p_org++ = EXT_OP_TEE_LOCAL_FAST;
                    if (is_32bit_type(local_type))
                        *p_org++ = cast(ubyte)local_offset;
                    else
                        *p_org++ = (uint8)(local_offset | 0x80);
                    while (p_org < p)
                        *p_org++ = WASM_OP_NOP;
                }
}
}
                break;
            }

            case WASM_OP_GET_GLOBAL:
            {
                p_org = p - 1;
                read_leb_uint32(p, p_end, global_idx);
                bh_assert(global_idx < global_count);

                global_type =
                    global_idx < module_.import_global_count
                        ? module_.import_globals[global_idx].u.global.type
                        : module_
                              .globals[global_idx
                                        - module_.import_global_count]
                              .type;

                PUSH_TYPE(global_type);

static if (WASM_ENABLE_FAST_INTERP == 0) {
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    *p_org = WASM_OP_GET_GLOBAL_64;
                }
} else {  /* else of WASM_ENABLE_FAST_INTERP */
                if (is_64bit_type(global_type)) {
                    skip_label();
                    emit_label(WASM_OP_GET_GLOBAL_64);
                }
                emit_uint32(loader_ctx, global_idx);
                PUSH_OFFSET_TYPE(global_type);
} /* end of WASM_ENABLE_FAST_INTERP */
                break;
            }

            case WASM_OP_SET_GLOBAL:
            {
                bool is_mutable = false;

                p_org = p - 1;
                read_leb_uint32(p, p_end, global_idx);
                bh_assert(global_idx < global_count);

                is_mutable =
                    global_idx < module_.import_global_count
                        ? module_.import_globals[global_idx].u.global.is_mutable
                        : module_
                              .globals[global_idx
                                        - module_.import_global_count]
                              .is_mutable;
                bh_assert(is_mutable);

                global_type =
                    global_idx < module_.import_global_count
                        ? module_.import_globals[global_idx].u.global.type
                        : module_
                              .globals[global_idx
                                        - module_.import_global_count]
                              .type;

                POP_TYPE(global_type);

static if (WASM_ENABLE_FAST_INTERP == 0) {
                if (is_64bit_type(global_type)) {
                    *p_org = WASM_OP_SET_GLOBAL_64;
                }
                else if (module_.aux_stack_size > 0
                         && global_idx == module_.aux_stack_top_global_index) {
                    *p_org = WASM_OP_SET_GLOBAL_AUX_STACK;
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                    func.has_op_set_global_aux_stack = true;
}
                }
} else {  /* else of WASM_ENABLE_FAST_INTERP */
                if (is_64bit_type(global_type)) {
                    skip_label();
                    emit_label(WASM_OP_SET_GLOBAL_64);
                }
                else if (module_.aux_stack_size > 0
                         && global_idx == module_.aux_stack_top_global_index) {
                    skip_label();
                    emit_label(WASM_OP_SET_GLOBAL_AUX_STACK);
                }
                emit_uint32(loader_ctx, global_idx);
                POP_OFFSET_TYPE(global_type);
} /* end of WASM_ENABLE_FAST_INTERP */

                cast(void)is_mutable;
                break;
            }

            /* load */
            case WASM_OP_I32_LOAD:
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
            case WASM_OP_I64_LOAD:
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
            case WASM_OP_F32_LOAD:
            case WASM_OP_F64_LOAD:
            /* store */
            case WASM_OP_I32_STORE:
            case WASM_OP_I32_STORE8:
            case WASM_OP_I32_STORE16:
            case WASM_OP_I64_STORE:
            case WASM_OP_I64_STORE8:
            case WASM_OP_I64_STORE16:
            case WASM_OP_I64_STORE32:
            case WASM_OP_F32_STORE:
            case WASM_OP_F64_STORE:
            {
static if (WASM_ENABLE_FAST_INTERP != 0) {
                /* change F32/F64 into I32/I64 */
                if (opcode == WASM_OP_F32_LOAD) {
                    skip_label();
                    emit_label(WASM_OP_I32_LOAD);
                }
                else if (opcode == WASM_OP_F64_LOAD) {
                    skip_label();
                    emit_label(WASM_OP_I64_LOAD);
                }
                else if (opcode == WASM_OP_F32_STORE) {
                    skip_label();
                    emit_label(WASM_OP_I32_STORE);
                }
                else if (opcode == WASM_OP_F64_STORE) {
                    skip_label();
                    emit_label(WASM_OP_I64_STORE);
                }
}
                CHECK_MEMORY();
                read_leb_uint32(p, p_end, align_);      /* align */
                read_leb_uint32(p, p_end, mem_offset); /* offset */
static if (WASM_ENABLE_FAST_INTERP != 0) {
                emit_uint32(loader_ctx, mem_offset);
}
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_memory_operations = true;
}
                switch (opcode) {
                    /* load */
                    case WASM_OP_I32_LOAD:
                    case WASM_OP_I32_LOAD8_S:
                    case WASM_OP_I32_LOAD8_U:
                    case WASM_OP_I32_LOAD16_S:
                    case WASM_OP_I32_LOAD16_U:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I64_LOAD:
                    case WASM_OP_I64_LOAD8_S:
                    case WASM_OP_I64_LOAD8_U:
                    case WASM_OP_I64_LOAD16_S:
                    case WASM_OP_I64_LOAD16_U:
                    case WASM_OP_I64_LOAD32_S:
                    case WASM_OP_I64_LOAD32_U:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_F32_LOAD:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                        break;
                    case WASM_OP_F64_LOAD:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F64);
                        break;
                    /* store */
                    case WASM_OP_I32_STORE:
                    case WASM_OP_I32_STORE8:
                    case WASM_OP_I32_STORE16:
                        POP_I32();
                        POP_I32();
                        break;
                    case WASM_OP_I64_STORE:
                    case WASM_OP_I64_STORE8:
                    case WASM_OP_I64_STORE16:
                    case WASM_OP_I64_STORE32:
                        POP_I64();
                        POP_I32();
                        break;
                    case WASM_OP_F32_STORE:
                        POP_F32();
                        POP_I32();
                        break;
                    case WASM_OP_F64_STORE:
                        POP_F64();
                        POP_I32();
                        break;
                    default:
                        break;
                }
                break;
            }

            case WASM_OP_MEMORY_SIZE:
                CHECK_MEMORY();
                /* reserved byte 0x00 */
                bh_assert(*p == 0x00);
                p++;
                PUSH_I32();

                module_.possible_memory_grow = true;
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_memory_operations = true;
}
                break;

            case WASM_OP_MEMORY_GROW:
                CHECK_MEMORY();
                /* reserved byte 0x00 */
                bh_assert(*p == 0x00);
                p++;
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);

                module_.possible_memory_grow = true;
static if (WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_op_memory_grow = true;
}
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_memory_operations = true;
}
                break;

            case WASM_OP_I32_CONST:
                read_leb_int32(p, p_end, i32_const);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                skip_label();
                disable_emit = true;
                GET_CONST_OFFSET(VALUE_TYPE_I32, i32_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_I32_CONST);
                    emit_uint32(loader_ctx, i32_const);
                }
} else {
                cast(void)i32_const;
}
                PUSH_I32();
                break;

            case WASM_OP_I64_CONST:
                read_leb_int64(p, p_end, i64_const);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                skip_label();
                disable_emit = true;
                GET_CONST_OFFSET(VALUE_TYPE_I64, i64_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_I64_CONST);
                    emit_uint64(loader_ctx, i64_const);
                }
}
                PUSH_I64();
                break;

            case WASM_OP_F32_CONST:
                p += float32.sizeof;
static if (WASM_ENABLE_FAST_INTERP != 0) {
                skip_label();
                disable_emit = true;
                bh_memcpy_s(cast(ubyte*)&f32_const, float32.sizeof, p_org,
                            float32.sizeof);
                GET_CONST_F32_OFFSET(VALUE_TYPE_F32, f32_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_F32_CONST);
                    emit_float32(loader_ctx, f32_const);
                }
}
                PUSH_F32();
                break;

            case WASM_OP_F64_CONST:
                p += float64.sizeof;
static if (WASM_ENABLE_FAST_INTERP != 0) {
                skip_label();
                disable_emit = true;
                /* Some MCU may require 8-byte align */
                bh_memcpy_s(cast(ubyte*)&f64_const, float64.sizeof, p_org,
                            float64.sizeof);
                GET_CONST_F64_OFFSET(VALUE_TYPE_F64, f64_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_F64_CONST);
                    emit_float64(loader_ctx, f64_const);
                }
}
                PUSH_F64();
                break;

            case WASM_OP_I32_EQZ:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
                POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EQZ:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
                POP2_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
                POP2_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
                POP2_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
                POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
                POP2_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
                POP2_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
                POP2_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_WRAP_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_DEMOTE_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_PROMOTE_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_REINTERPRET_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_REINTERPRET_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_REINTERPRET_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_REINTERPRET_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_MISC_PREFIX:
            {
                uint opcode1;

                read_leb_uint32(p, p_end, opcode1);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                emit_byte(loader_ctx, (cast(ubyte)opcode1));
}
                switch (opcode1) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                        POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                        break;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
                    case WASM_OP_MEMORY_INIT:
                    {
                        read_leb_uint32(p, p_end, segment_index);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, segment_index);
}
                        bh_assert(module_.import_memory_count
                                      + module_.memory_count
                                  > 0);

                        bh_assert(*p == 0x00);
                        p++;

                        bh_assert(segment_index < module_.data_seg_count);
                        bh_assert(module_.data_seg_count1 > 0);

                        POP_I32();
                        POP_I32();
                        POP_I32();
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                        func.has_memory_operations = true;
}
                        break;
                    }
                    case WASM_OP_DATA_DROP:
                    {
                        read_leb_uint32(p, p_end, segment_index);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, segment_index);
}
                        bh_assert(segment_index < module_.data_seg_count);
                        bh_assert(module_.data_seg_count1 > 0);
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                        func.has_memory_operations = true;
}
                        break;
                    }
                    case WASM_OP_MEMORY_COPY:
                    {
                        /* both src and dst memory index should be 0 */
                        bh_assert(*cast(short*)p == 0x0000);
                        p += 2;

                        bh_assert(module_.import_memory_count
                                      + module_.memory_count
                                  > 0);

                        POP_I32();
                        POP_I32();
                        POP_I32();
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                        func.has_memory_operations = true;
}
                        break;
                    }
                    case WASM_OP_MEMORY_FILL:
                    {
                        bh_assert(*p == 0);
                        p++;

                        bh_assert(module_.import_memory_count
                                      + module_.memory_count
                                  > 0);

                        POP_I32();
                        POP_I32();
                        POP_I32();
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                        func.has_memory_operations = true;
}
                        break;
                    }
} /* WASM_ENABLE_BULK_MEMORY */
static if (WASM_ENABLE_REF_TYPES != 0) {
                    case WASM_OP_TABLE_INIT:
                    {
                        ubyte seg_ref_type, tbl_ref_type;
                        uint table_seg_idx, table_idx;

                        read_leb_uint32(p, p_end, table_seg_idx);
                        read_leb_uint32(p, p_end, table_idx);

                        if (!get_table_elem_type(module_, table_idx,
                                                 &tbl_ref_type, error_buf,
                                                 error_buf_size))
                            goto fail;

                        if (!get_table_seg_elem_type(module_, table_seg_idx,
                                                     &seg_ref_type, error_buf,
                                                     error_buf_size))
                            goto fail;

                        if (seg_ref_type != tbl_ref_type) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, table_seg_idx);
                        emit_uint32(loader_ctx, table_idx);
}
                        POP_I32();
                        POP_I32();
                        POP_I32();
                        break;
                    }
                    case WASM_OP_ELEM_DROP:
                    {
                        uint table_seg_idx;
                        read_leb_uint32(p, p_end, table_seg_idx);
                        if (!get_table_seg_elem_type(module_, table_seg_idx,
                                                     null, error_buf,
                                                     error_buf_size))
                            goto fail;
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, table_seg_idx);
}
                        break;
                    }
                    case WASM_OP_TABLE_COPY:
                    {
                        ubyte src_ref_type, dst_ref_type;
                        uint src_tbl_idx, dst_tbl_idx;

                        read_leb_uint32(p, p_end, src_tbl_idx);
                        if (!get_table_elem_type(module_, src_tbl_idx,
                                                 &src_ref_type, error_buf,
                                                 error_buf_size))
                            goto fail;

                        read_leb_uint32(p, p_end, dst_tbl_idx);
                        if (!get_table_elem_type(module_, dst_tbl_idx,
                                                 &dst_ref_type, error_buf,
                                                 error_buf_size))
                            goto fail;

                        if (src_ref_type != dst_ref_type) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, src_tbl_idx);
                        emit_uint32(loader_ctx, dst_tbl_idx);
}
                        POP_I32();
                        POP_I32();
                        POP_I32();
                        break;
                    }
                    case WASM_OP_TABLE_SIZE:
                    {
                        uint table_idx;

                        read_leb_uint32(p, p_end, table_idx);
                        /* TODO: shall we create a new function to check
                                 table idx instead of using below function? */
                        if (!get_table_elem_type(module_, table_idx, null,
                                                 error_buf, error_buf_size))
                            goto fail;

static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, table_idx);
}

                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_TABLE_GROW:
                    case WASM_OP_TABLE_FILL:
                    {
                        ubyte decl_ref_type;
                        uint table_idx;

                        read_leb_uint32(p, p_end, table_idx);
                        if (!get_table_elem_type(module_, table_idx,
                                                 &decl_ref_type, error_buf,
                                                 error_buf_size))
                            goto fail;

                        if (opcode1 == WASM_OP_TABLE_GROW) {
                            if (table_idx < module_.import_table_count) {
                                module_.import_tables[table_idx]
                                    .u.table.possible_grow = true;
                            }
                            else {
                                module_
                                    .tables[table_idx
                                             - module_.import_table_count]
                                    .possible_grow = true;
                            }
                        }

static if (WASM_ENABLE_FAST_INTERP != 0) {
                        emit_uint32(loader_ctx, table_idx);
}

                        POP_I32();
static if (WASM_ENABLE_FAST_INTERP != 0) {
                        POP_OFFSET_TYPE(decl_ref_type);
}
                        POP_TYPE(decl_ref_type);
                        if (opcode1 == WASM_OP_TABLE_GROW)
                            PUSH_I32();
                        else
                            POP_I32();
                        break;
                    }
} /* WASM_ENABLE_REF_TYPES */
                    default:
                        bh_assert(0);
                        break;
                }
                break;
            }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            case WASM_OP_ATOMIC_PREFIX:
            {
                opcode = read_uint8(p);
static if (WASM_ENABLE_FAST_INTERP != 0) {
                emit_byte(loader_ctx, opcode);
}
                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    CHECK_MEMORY();
                    read_leb_uint32(p, p_end, align_);      /* align */
                    read_leb_uint32(p, p_end, mem_offset); /* offset */
static if (WASM_ENABLE_FAST_INTERP != 0) {
                    emit_uint32(loader_ctx, mem_offset);
}
                }
static if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0) {
                func.has_memory_operations = true;
}
                switch (opcode) {
                    case WASM_OP_ATOMIC_NOTIFY:
                        POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_ATOMIC_WAIT32:
                        POP_I64();
                        POP_I32();
                        POP_I32();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_WAIT64:
                        POP_I64();
                        POP_I64();
                        POP_I32();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_FENCE:
                        /* reserved byte 0x00 */
                        bh_assert(*p == 0x00);
                        p++;
                        break;
                    case WASM_OP_ATOMIC_I32_LOAD:
                    case WASM_OP_ATOMIC_I32_LOAD8_U:
                    case WASM_OP_ATOMIC_I32_LOAD16_U:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_ATOMIC_I32_STORE:
                    case WASM_OP_ATOMIC_I32_STORE8:
                    case WASM_OP_ATOMIC_I32_STORE16:
                        POP_I32();
                        POP_I32();
                        break;
                    case WASM_OP_ATOMIC_I64_LOAD:
                    case WASM_OP_ATOMIC_I64_LOAD8_U:
                    case WASM_OP_ATOMIC_I64_LOAD16_U:
                    case WASM_OP_ATOMIC_I64_LOAD32_U:
                        POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_ATOMIC_I64_STORE:
                    case WASM_OP_ATOMIC_I64_STORE8:
                    case WASM_OP_ATOMIC_I64_STORE16:
                    case WASM_OP_ATOMIC_I64_STORE32:
                        POP_I64();
                        POP_I32();
                        break;
                    case WASM_OP_ATOMIC_RMW_I32_ADD:
                    case WASM_OP_ATOMIC_RMW_I32_ADD8_U:
                    case WASM_OP_ATOMIC_RMW_I32_ADD16_U:
                    case WASM_OP_ATOMIC_RMW_I32_SUB:
                    case WASM_OP_ATOMIC_RMW_I32_SUB8_U:
                    case WASM_OP_ATOMIC_RMW_I32_SUB16_U:
                    case WASM_OP_ATOMIC_RMW_I32_AND:
                    case WASM_OP_ATOMIC_RMW_I32_AND8_U:
                    case WASM_OP_ATOMIC_RMW_I32_AND16_U:
                    case WASM_OP_ATOMIC_RMW_I32_OR:
                    case WASM_OP_ATOMIC_RMW_I32_OR8_U:
                    case WASM_OP_ATOMIC_RMW_I32_OR16_U:
                    case WASM_OP_ATOMIC_RMW_I32_XOR:
                    case WASM_OP_ATOMIC_RMW_I32_XOR8_U:
                    case WASM_OP_ATOMIC_RMW_I32_XOR16_U:
                    case WASM_OP_ATOMIC_RMW_I32_XCHG:
                    case WASM_OP_ATOMIC_RMW_I32_XCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I32_XCHG16_U:
                        POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_ATOMIC_RMW_I64_ADD:
                    case WASM_OP_ATOMIC_RMW_I64_ADD8_U:
                    case WASM_OP_ATOMIC_RMW_I64_ADD16_U:
                    case WASM_OP_ATOMIC_RMW_I64_ADD32_U:
                    case WASM_OP_ATOMIC_RMW_I64_SUB:
                    case WASM_OP_ATOMIC_RMW_I64_SUB8_U:
                    case WASM_OP_ATOMIC_RMW_I64_SUB16_U:
                    case WASM_OP_ATOMIC_RMW_I64_SUB32_U:
                    case WASM_OP_ATOMIC_RMW_I64_AND:
                    case WASM_OP_ATOMIC_RMW_I64_AND8_U:
                    case WASM_OP_ATOMIC_RMW_I64_AND16_U:
                    case WASM_OP_ATOMIC_RMW_I64_AND32_U:
                    case WASM_OP_ATOMIC_RMW_I64_OR:
                    case WASM_OP_ATOMIC_RMW_I64_OR8_U:
                    case WASM_OP_ATOMIC_RMW_I64_OR16_U:
                    case WASM_OP_ATOMIC_RMW_I64_OR32_U:
                    case WASM_OP_ATOMIC_RMW_I64_XOR:
                    case WASM_OP_ATOMIC_RMW_I64_XOR8_U:
                    case WASM_OP_ATOMIC_RMW_I64_XOR16_U:
                    case WASM_OP_ATOMIC_RMW_I64_XOR32_U:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG16_U:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG32_U:
                        POP_I64();
                        POP_I32();
                        PUSH_I64();
                        break;
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U:
                        POP_I32();
                        POP_I32();
                        POP_I32();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U:
                        POP_I64();
                        POP_I64();
                        POP_I32();
                        PUSH_I64();
                        break;
                    default:
                        bh_assert(0);
                        break;
                }
                break;
            }
} /* end of WASM_ENABLE_SHARED_MEMORY */

            default:
                bh_assert(0);
                break;
        }

static if (WASM_ENABLE_FAST_INTERP != 0) {
        last_op = opcode;
}
    }

    if (loader_ctx.csp_num > 0) {
        set_error_buf(error_buf, error_buf_size,
                      "function body must end with END opcode");
        goto fail;
    }

static if (WASM_ENABLE_FAST_INTERP != 0) {
    if (loader_ctx.p_code_compiled == null)
        goto re_scan;

    func.const_cell_num = loader_ctx.const_cell_num;
    if (func.const_cell_num > 0) {
        int j;

        if (((func.consts = func_const = loader_malloc(
                  func.const_cell_num * 4, error_buf, error_buf_size)) == 0))
            goto fail;

        func_const_end = func.consts + func.const_cell_num * 4;
        /* reverse the const buf */
        for (j = loader_ctx.num_const - 1; j >= 0; j--) {
            Const* c = cast(Const*)(loader_ctx.const_buf + j * Const.sizeof);
            if (c.value_type == VALUE_TYPE_F64
                || c.value_type == VALUE_TYPE_I64) {
                bh_memcpy_s(func_const, (uint32)(func_const_end - func_const),
                            &(c.value.f64), cast(uint)int64.sizeof);
                func_const += int64.sizeof;
            }
            else {
                bh_memcpy_s(func_const, (uint32)(func_const_end - func_const),
                            &(c.value.f32), cast(uint)int32.sizeof);
                func_const += int32.sizeof;
            }
        }
    }

    func.max_stack_cell_num = loader_ctx.preserved_local_offset
                               - loader_ctx.start_dynamic_offset + 1;
} else {
    func.max_stack_cell_num = loader_ctx.max_stack_cell_num;
}
    func.max_block_num = loader_ctx.max_csp_num;
    return_value = true;

fail:
    wasm_loader_ctx_destroy(loader_ctx);

    cast(void)u8;
    cast(void)u32;
    cast(void)i32;
    cast(void)i64_const;
    cast(void)global_count;
    cast(void)local_count;
    cast(void)local_offset;
    cast(void)p_org;
    cast(void)mem_offset;
    cast(void)align_;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
    cast(void)segment_index;
}
    return return_value;}
}
