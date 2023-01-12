module tagion.iwasm.interpreter.wasm_loader;
@nogc nothrow:
extern(C): __gshared:
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
import tagion.iwasm.basic;
import tagion.iwasm.config;
public import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.share.utils.bh_hashmap;
public import tagion.iwasm.share.utils.bh_assert;
public import tagion.iwasm.share.utils.bh_list;
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
}
struct WASMMemoryImport {
    char* module_name;
    char* field_name;
    uint flags;
    uint num_bytes_per_page;
    uint init_page_count;
    uint max_page_count;
}
struct WASMGlobal {
    ubyte type;
    bool is_mutable;
    InitializerExpression init_expr;
    /* The data offset of current global in global data */
    uint data_offset;
}
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
    ubyte* data;
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
struct AOTCompData;
struct AOTCompContext;
/* Orc JIT thread arguments */
struct OrcJitThreadArg {
    AOTCompContext* comp_ctx;
    WASMModule* module_;
    uint group_idx;
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
public import tagion.iwasm.share.utils.bh_hashmap;
public import tagion.iwasm.common.wasm_runtime_common;
/**
 * Load a WASM module from a specified byte buffer.
 *
 * @param buf the byte buffer which contains the WASM binary data
 * @param size the size of the buffer
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return module loaded, NULL if failed
 */
WASMModule* wasm_loader_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size);
/**
 * Load a WASM module from a specified WASM section list.
 *
 * @param section_list the section list which contains each section data
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return WASM module loaded, NULL if failed
 */
WASMModule* wasm_loader_load_from_sections(WASMSection* section_list, char* error_buf, uint error_buf_size);
/**
 * Unload a WASM module.
 *
 * @param module the module to be unloaded
 */
void wasm_loader_unload(WASMModule* module_);
/**
 * Find address of related else opcode and end opcode of opcode block/loop/if
 * according to the start address of opcode.
 *
 * @param module the module to find
 * @param start_addr the next address of opcode block/loop/if
 * @param code_end_addr the end address of function code block
 * @param block_type the type of block, 0/1/2 denotes block/loop/if
 * @param p_else_addr returns the else addr if found
 * @param p_end_addr returns the end addr if found
 * @param error_buf returns the error log for this function
 * @param error_buf_size returns the error log string length
 *
 * @return true if success, false otherwise
 */
version(none)
bool wasm_loader_find_block_addr(WASMExecEnv* exec_env, BlockAddr* block_addr_cache, const(ubyte)* start_addr, const(ubyte)* code_end_addr, ubyte block_type, ubyte** p_else_addr, ubyte** p_end_addr);
public import tagion.iwasm.share.utils.bh_common;
public import tagion.iwasm.share.utils.bh_log;
public import tagion.iwasm.interpreter.wasm;
public import tagion.iwasm.interpreter.wasm_opcode;
public import tagion.iwasm.interpreter.wasm_runtime;
public import  tagion.iwasm.common.wasm_native;
public import  tagion.iwasm.common.wasm_memory;
public import  tagion.iwasm.fast_jit.jit_compiler;
public import  tagion.iwasm.fast_jit.jit_codecache;
public import  tagion.iwasm.compilation.aot_llvm;
/* Read a value of given type from the address pointed to by the given
   pointer and increase the pointer to the position just after the
   value being read.  */
private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null) {
        snprintf(error_buf, error_buf_size, "WASM module load failed: %s",
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
        snprintf(error_buf, error_buf_size, "WASM module load failed: %s", buf.ptr);
    }
}
private bool check_buf(const(ubyte)* buf, const(ubyte)* buf_end, uint length, char* error_buf, uint error_buf_size) {
    if (cast(uintptr_t)buf + length < cast(uintptr_t)buf
        || cast(uintptr_t)buf + length > cast(uintptr_t)buf_end) {
        set_error_buf(error_buf, error_buf_size,
                      "unexpected end of section or function");
        return false;
    }
    return true;
}
private bool check_buf1(const(ubyte)* buf, const(ubyte)* buf_end, uint length, char* error_buf, uint error_buf_size) {
    if (cast(uintptr_t)buf + length < cast(uintptr_t)buf
        || cast(uintptr_t)buf + length > cast(uintptr_t)buf_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }
    return true;
}
//#define skip_leb(p) while (*p++ & 0x80)
//#define skip_leb_int64(p, p_end) skip_leb(p)
//#define skip_leb_uint32(p, p_end) skip_leb(p)
//#define skip_leb_int32(p, p_end) skip_leb(p)
private bool read_leb(ubyte** p_buf, const(ubyte)* buf_end, uint maxbits, bool sign, ulong* p_result, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    ulong result = 0;
    uint shift = 0;
    uint offset = 0, bcnt = 0;
    ulong byte_ = void;
    while (true) {
        /* uN or SN must not exceed ceil(N/7) bytes */
        if (bcnt + 1 > (maxbits + 6) / 7) {
            set_error_buf(error_buf, error_buf_size,
                          "integer representation too long");
            return false;
        }
         if (!check_buf(buf, buf_end, offset + 1, error_buf, error_buf_size)) { goto fail; }
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
        if ((cast(ubyte)byte_) & 0xf0)
            goto fail_integer_too_large;
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
            if ((sign_bit_set && top_bits != 0x70)
                || (!sign_bit_set && top_bits != 0))
                goto fail_integer_too_large;
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
            if ((sign_bit_set && top_bits != 0x7e)
                || (!sign_bit_set && top_bits != 0))
                goto fail_integer_too_large;
        }
    }
    *p_buf += offset;
    *p_result = result;
    return true;
fail_integer_too_large:
    set_error_buf(error_buf, error_buf_size, "integer too large");
fail:
    return false;
}
//#define read_uint8(p) TEMPLATE_READ_VALUE(uint8, p)
//#define read_uint32(p) TEMPLATE_READ_VALUE(uint32, p)
//#define read_bool(p) TEMPLATE_READ_VALUE(bool, p)
/*
#define read_leb_int64(p, p_end, res)                                                                                                               uint64 res64;                                                           if (!read_leb((uint8 **)&p, p_end, 64, true, &res64, error_buf,                       error_buf_size))                                              goto fail;                                                          res = (int64)res64;                                                 
  } while (0)

define read_leb_int64(p, p_end, res)                                   
    do {                                                                
        uint64 res64;                                                   
        if (!read_leb((uint8 **)&p, p_end, 64, true, &res64, error_buf, 
                      error_buf_size))                                  
            goto fail;                                                  
        res = (int64)res64;                                             
    } while (0)

define read_leb_uint32(p, p_end, res)                                   
    do {                                                                 
        uint64 res64;                                                    
        if (!read_leb((uint8 **)&p, p_end, 32, false, &res64, error_buf, 
                      error_buf_size))                                   
            goto fail;                                                   
        res = cast(uint)res64;                                            
    } while (0)

define read_leb_int32(p, p_end, res)                                   
    do {                                                                
        uint64 res64;                                                   
        if (!read_leb((uint8 **)&p, p_end, 32, true, &res64, error_buf,
                      error_buf_size))                                  
            goto fail;                                                  
        res = cast(int)res64;                                            
    } while (0)

*/
private char* type2str(ubyte type) {
    char*[5] type_str = [ "v128", "f64", "f32", "i64", "i32" ];
    if (type >= VALUE_TYPE_V128 && type <= VALUE_TYPE_I32)
        return type_str[type - VALUE_TYPE_V128];
    else if (type == VALUE_TYPE_FUNCREF)
        return "funcref";
    else if (type == VALUE_TYPE_EXTERNREF)
        return "externref";
    else
        return "unknown type";
}
private bool is_32bit_type(ubyte type) {
    if (type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32
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
    )
        return true;
    return false;
}
private bool is_byte_a_type(ubyte type) {
    return is_value_type(type) || (type == VALUE_TYPE_VOID);
}
private void* loader_malloc(ulong size, char* error_buf, uint error_buf_size) {
    void* mem = void;
    if (size >= UINT32_MAX || ((mem = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return null;
    }
    memset(mem, 0, cast(uint)size);
    return mem;
}
private bool check_utf8_str(const(ubyte)* str, uint len) {
    /* The valid ranges are taken from page 125, below link
       https://www.unicode.org/versions/Unicode9.0.0/ch03.pdf */
    const(ubyte)* p = str, p_end = str + len;
    ubyte chr = void;
    while (p < p_end) {
        chr = *p;
        if (chr < 0x80) {
            p++;
        }
        else if (chr >= 0xC2 && chr <= 0xDF && p + 1 < p_end) {
            if (p[1] < 0x80 || p[1] > 0xBF) {
                return false;
            }
            p += 2;
        }
        else if (chr >= 0xE0 && chr <= 0xEF && p + 2 < p_end) {
            if (chr == 0xE0) {
                if (p[1] < 0xA0 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            else if (chr == 0xED) {
                if (p[1] < 0x80 || p[1] > 0x9F || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            else if (chr >= 0xE1 && chr <= 0xEF) {
                if (p[1] < 0x80 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            p += 3;
        }
        else if (chr >= 0xF0 && chr <= 0xF4 && p + 3 < p_end) {
            if (chr == 0xF0) {
                if (p[1] < 0x90 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            else if (chr >= 0xF1 && chr <= 0xF3) {
                if (p[1] < 0x80 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            else if (chr == 0xF4) {
                if (p[1] < 0x80 || p[1] > 0x8F || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            p += 4;
        }
        else {
            return false;
        }
    }
    return (p == p_end);
}
private char* const_str_list_insert(const(ubyte)* str, uint len, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    StringNode* node = void, node_next = void;
    if (!check_utf8_str(str, len)) {
        set_error_buf(error_buf, error_buf_size, "invalid UTF-8 encoding");
        return null;
    }
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
        return node.str;
    }
    if (((node = loader_malloc(StringNode.sizeof + len + 1, error_buf,
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
    wasm_runtime_free(type);
}
private bool load_init_expr(const(ubyte)** p_buf, const(ubyte)* buf_end, InitializerExpression* init_expr, ubyte type, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    ubyte flag = void, end_byte = void; ubyte* p_float = void;
    uint i = void;
     if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
    init_expr.init_expr_type = read_uint8(p);
    flag = init_expr.init_expr_type;
    switch (flag) {
        /* i32.const */
        case INIT_EXPR_TYPE_I32_CONST:
            if (type != VALUE_TYPE_I32)
                goto fail_type_mismatch;
            read_leb_int32(p, p_end, init_expr.u.i32);
            break;
        /* i64.const */
        case INIT_EXPR_TYPE_I64_CONST:
            if (type != VALUE_TYPE_I64)
                goto fail_type_mismatch;
            read_leb_int64(p, p_end, init_expr.u.i64);
            break;
        /* f32.const */
        case INIT_EXPR_TYPE_F32_CONST:
            if (type != VALUE_TYPE_F32)
                goto fail_type_mismatch;
             if (!check_buf(p, p_end, 4, error_buf, error_buf_size)) { goto fail; }
            p_float = cast(ubyte*)&init_expr.u.f32;
            for (i = 0; i < float.sizeof; i++)
                *p_float++ = *p++;
            break;
        /* f64.const */
        case INIT_EXPR_TYPE_F64_CONST:
            if (type != VALUE_TYPE_F64)
                goto fail_type_mismatch;
             if (!check_buf(p, p_end, 8, error_buf, error_buf_size)) { goto fail; }
            p_float = cast(ubyte*)&init_expr.u.f64;
            for (i = 0; i < double.sizeof; i++)
                *p_float++ = *p++;
            break;
        /* get_global */
        case INIT_EXPR_TYPE_GET_GLOBAL:
            read_leb_uint32(p, p_end, init_expr.u.global_index);
            break;
        default:
        {
            set_error_buf(error_buf, error_buf_size,
                          "illegal opcode "
                          ~ "or constant expression required "
                          ~ "or type mismatch");
            goto fail;
        }
    }
     if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
    end_byte = read_uint8(p);
    if (end_byte != 0x0b)
        goto fail_type_mismatch;
    *p_buf = p;
    return true;
fail_type_mismatch:
    set_error_buf(error_buf, error_buf_size,
                  "type mismatch or constant expression required");
fail:
    return false;
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
             if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
            flag = read_uint8(p);
            if (flag != 0x60) {
                set_error_buf(error_buf, error_buf_size, "invalid type flag");
                return false;
            }
            read_leb_uint32(p, p_end, param_count);
            /* Resolve param count and result count firstly */
            p_org = p;
             if (!check_buf(p, p_end, param_count, error_buf, error_buf_size)) { goto fail; }
            p += param_count;
            read_leb_uint32(p, p_end, result_count);
             if (!check_buf(p, p_end, result_count, error_buf, error_buf_size)) { goto fail; }
            p = p_org;
            if (param_count > UINT16_MAX || result_count > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "param count or result count too large");
                return false;
            }
            total_size = WASMType.types.offsetof
                         + ubyte.sizeof * cast(ulong)(param_count + result_count);
            if (((type = module_.types[i] =
                      loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
                return false;
            }
            /* Resolve param types and result types */
            type.ref_count = 1;
            type.param_count = cast(ushort)param_count;
            type.result_count = cast(ushort)result_count;
            for (j = 0; j < param_count; j++) {
                 if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
                type.types[j] = read_uint8(p);
            }
            read_leb_uint32(p, p_end, result_count);
            for (j = 0; j < result_count; j++) {
                 if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
                type.types[param_count + j] = read_uint8(p);
            }
            for (j = 0; j < param_count + result_count; j++) {
                if (!is_value_type(type.types[j])) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unknown value type");
                    return false;
                }
            }
            param_cell_num = wasm_get_cell_num(type.types, param_count);
            ret_cell_num =
                wasm_get_cell_num(type.types + param_count, result_count);
            if (param_cell_num > UINT16_MAX || ret_cell_num > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "param count or result count too large");
                return false;
            }
            type.param_cell_num = cast(ushort)param_cell_num;
            type.ret_cell_num = cast(ushort)ret_cell_num;
            /* If there is already a same type created, use it instead */
            for (j = 0; j < i; j++) {
                if (wasm_type_equal(type, module_.types[j])) {
                    if (module_.types[j].ref_count == UINT16_MAX) {
                        set_error_buf(error_buf, error_buf_size,
                                      "wasm type's ref count too large");
                        return false;
                    }
                    destroy_wasm_type(type);
                    module_.types[i] = module_.types[j];
                    module_.types[j].ref_count++;
                    break;
                }
            }
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load type section success.\n");
    return true;
fail:
    return false;
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
    bool is_native_symbol = false;
    read_leb_uint32(p, p_end, declare_type_index);
    *p_buf = p;
    if (declare_type_index >= parent_module.type_count) {
        set_error_buf(error_buf, error_buf_size, "unknown type");
        return false;
    }
    declare_type_index = wasm_get_smallest_type_idx(
        parent_module.types, parent_module.type_count, declare_type_index);
    declare_func_type = parent_module.types[declare_type_index];
    /* lookup registered native symbols first */
    linked_func = wasm_native_resolve_symbol(
        sub_module_name, function_name, declare_func_type, &linked_signature,
        &linked_attachment, &linked_call_conv_raw);
    if (linked_func) {
        is_native_symbol = true;
    }
    function_.module_name = cast(char*)sub_module_name;
    function_.field_name = cast(char*)function_name;
    function_.func_type = declare_func_type;
    /* func_ptr_linked is for native registered symbol */
    function_.func_ptr_linked = is_native_symbol ? linked_func : null;
    function_.signature = linked_signature;
    function_.attachment = linked_attachment;
    function_.call_conv_raw = linked_call_conv_raw;
    return true;
fail:
    return false;
}
private bool check_table_max_size(uint init_size, uint max_size, char* error_buf, uint error_buf_size) {
    if (max_size < init_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }
    return true;
}
private bool load_table_import(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* parent_module, const(char)* sub_module_name, const(char)* table_name, WASMTableImport* table, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint declare_elem_type = 0, declare_max_size_flag = 0, declare_init_size = 0, declare_max_size = 0;
     if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
    /* 0x70 or 0x6F */
    declare_elem_type = read_uint8(p);
    if (VALUE_TYPE_FUNCREF != declare_elem_type
    ) {
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return false;
    }
    read_leb_uint32(p, p_end, declare_max_size_flag);
    if (declare_max_size_flag > 1) {
        set_error_buf(error_buf, error_buf_size, "integer too large");
        return false;
    }
    read_leb_uint32(p, p_end, declare_init_size);
    if (declare_max_size_flag) {
        read_leb_uint32(p, p_end, declare_max_size);
        if (!check_table_max_size(declare_init_size, declare_max_size,
                                  error_buf, error_buf_size))
            return false;
    }
    adjust_table_max_size(declare_init_size, declare_max_size_flag,
                          &declare_max_size);
    *p_buf = p;
    /* (table (export "table") 10 20 funcref) */
    /* we need this section working in wamrc */
    if (!strcmp("spectest", sub_module_name)) {
        const(uint) spectest_table_init_size = 10;
        const(uint) spectest_table_max_size = 20;
        if (strcmp("table", table_name)) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }
        if (declare_init_size > spectest_table_init_size
            || declare_max_size < spectest_table_max_size) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }
        declare_init_size = spectest_table_init_size;
        declare_max_size = spectest_table_max_size;
    }
    /* now we believe all declaration are ok */
    table.elem_type = declare_elem_type;
    table.init_size = declare_init_size;
    table.flags = declare_max_size_flag;
    table.max_size = declare_max_size;
    return true;
fail:
    return false;
}
private bool check_memory_init_size(uint init_size, char* error_buf, uint error_buf_size) {
    if (init_size > DEFAULT_MAX_PAGES) {
        set_error_buf(error_buf, error_buf_size,
                      "memory size must be at most 65536 pages (4GiB)");
        return false;
    }
    return true;
}
private bool check_memory_max_size(uint init_size, uint max_size, char* error_buf, uint error_buf_size) {
    if (max_size < init_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }
    if (max_size > DEFAULT_MAX_PAGES) {
        set_error_buf(error_buf, error_buf_size,
                      "memory size must be at most 65536 pages (4GiB)");
        return false;
    }
    return true;
}
private bool load_memory_import(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* parent_module, const(char)* sub_module_name, const(char)* memory_name, WASMMemoryImport* memory, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint max_page_count = DEFAULT_MAX_PAGES;
    uint declare_max_page_count_flag = 0;
    uint declare_init_page_count = 0;
    uint declare_max_page_count = 0;
    read_leb_uint32(p, p_end, declare_max_page_count_flag);
    read_leb_uint32(p, p_end, declare_init_page_count);
    if (!check_memory_init_size(declare_init_page_count, error_buf,
                                error_buf_size)) {
        return false;
    }
    if (declare_max_page_count_flag & 1) {
        read_leb_uint32(p, p_end, declare_max_page_count);
        if (!check_memory_max_size(declare_init_page_count,
                                   declare_max_page_count, error_buf,
                                   error_buf_size)) {
            return false;
        }
        if (declare_max_page_count > max_page_count) {
            declare_max_page_count = max_page_count;
        }
    }
    else {
        /* Limit the maximum memory size to max_page_count */
        declare_max_page_count = max_page_count;
    }
    /* (memory (export "memory") 1 2) */
    if (!strcmp("spectest", sub_module_name)) {
        uint spectest_memory_init_page = 1;
        uint spectest_memory_max_page = 2;
        if (strcmp("memory", memory_name)) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }
        if (declare_init_page_count > spectest_memory_init_page
            || declare_max_page_count < spectest_memory_max_page) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }
        declare_init_page_count = spectest_memory_init_page;
        declare_max_page_count = spectest_memory_max_page;
    }
    /* now we believe all declaration are ok */
    memory.flags = declare_max_page_count_flag;
    memory.init_page_count = declare_init_page_count;
    memory.max_page_count = declare_max_page_count;
    memory.num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;
    *p_buf = p;
    return true;
fail:
    return false;
}
private bool load_global_import(const(ubyte)** p_buf, const(ubyte)* buf_end, const(WASMModule)* parent_module, char* sub_module_name, char* global_name, WASMGlobalImport* global, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    ubyte declare_type = 0;
    ubyte declare_mutable = 0;
     if (!check_buf(p, p_end, 2, error_buf, error_buf_size)) { goto fail; }
    declare_type = read_uint8(p);
    declare_mutable = read_uint8(p);
    *p_buf = p;
    if (declare_mutable >= 2) {
        set_error_buf(error_buf, error_buf_size, "invalid mutability");
        return false;
    }
    global.module_name = sub_module_name;
    global.field_name = global_name;
    global.type = declare_type;
    global.is_mutable = (declare_mutable == 1);
    return true;
fail:
    return false;
}
private bool load_table(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMTable* table, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end, p_org = void;
     if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
    /* 0x70 or 0x6F */
    table.elem_type = read_uint8(p);
    if (VALUE_TYPE_FUNCREF != table.elem_type
    ) {
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return false;
    }
    p_org = p;
    read_leb_uint32(p, p_end, table.flags);
    if (p - p_org > 1) {
        set_error_buf(error_buf, error_buf_size,
                      "integer representation too long");
        return false;
    }
    if (table.flags > 1) {
        set_error_buf(error_buf, error_buf_size, "integer too large");
        return false;
    }
    read_leb_uint32(p, p_end, table.init_size);
    if (table.flags) {
        read_leb_uint32(p, p_end, table.max_size);
        if (!check_table_max_size(table.init_size, table.max_size, error_buf,
                                  error_buf_size))
            return false;
    }
    adjust_table_max_size(table.init_size, table.flags, &table.max_size);
    *p_buf = p;
    return true;
fail:
    return false;
}
private bool load_memory(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMMemory* memory, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end, p_org = void;
    uint max_page_count = DEFAULT_MAX_PAGES;
    p_org = p;
    read_leb_uint32(p, p_end, memory.flags);
    if (p - p_org > 1) {
        set_error_buf(error_buf, error_buf_size,
                      "integer representation too long");
        return false;
    }
    if (memory.flags > 1) {
        set_error_buf(error_buf, error_buf_size, "integer too large");
        return false;
    }
    read_leb_uint32(p, p_end, memory.init_page_count);
    if (!check_memory_init_size(memory.init_page_count, error_buf,
                                error_buf_size))
        return false;
    if (memory.flags & 1) {
        read_leb_uint32(p, p_end, memory.max_page_count);
        if (!check_memory_max_size(memory.init_page_count,
                                   memory.max_page_count, error_buf,
                                   error_buf_size))
            return false;
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
fail:
    return false;
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
             if (!check_buf(p, p_end, name_len, error_buf, error_buf_size)) { goto fail; }
            p += name_len;
            /* field name */
            read_leb_uint32(p, p_end, name_len);
             if (!check_buf(p, p_end, name_len, error_buf, error_buf_size)) { goto fail; }
            p += name_len;
             if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
            /* 0x00/0x01/0x02/0x03 */
            kind = read_uint8(p);
            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    read_leb_uint32(p, p_end, type_index);
                    module_.import_function_count++;
                    break;
                case IMPORT_KIND_TABLE: /* import table */
                     if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
                    /* 0x70 */
                    u8 = read_uint8(p);
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    module_.import_table_count++;
                    if (module_.import_table_count > 1) {
                        set_error_buf(error_buf, error_buf_size,
                                      "multiple tables");
                        return false;
                    }
                    break;
                case IMPORT_KIND_MEMORY: /* import memory */
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    module_.import_memory_count++;
                    if (module_.import_memory_count > 1) {
                        set_error_buf(error_buf, error_buf_size,
                                      "multiple memories");
                        return false;
                    }
                    break;
                case IMPORT_KIND_GLOBAL: /* import global */
                     if (!check_buf(p, p_end, 2, error_buf, error_buf_size)) { goto fail; }
                    p += 2;
                    module_.import_global_count++;
                    break;
                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid import kind");
                    return false;
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
            /* load module name */
            read_leb_uint32(p, p_end, name_len);
             if (!check_buf(p, p_end, name_len, error_buf, error_buf_size)) { goto fail; }
            if (((sub_module_name = const_str_list_insert(
                      p, name_len, module_, is_load_from_file_buf, error_buf,
                      error_buf_size)) == 0)) {
                return false;
            }
            p += name_len;
            /* load field name */
            read_leb_uint32(p, p_end, name_len);
             if (!check_buf(p, p_end, name_len, error_buf, error_buf_size)) { goto fail; }
            if (((field_name = const_str_list_insert(
                      p, name_len, module_, is_load_from_file_buf, error_buf,
                      error_buf_size)) == 0)) {
                return false;
            }
            p += name_len;
             if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
            /* 0x00/0x01/0x02/0x03 */
            kind = read_uint8(p);
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
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid import kind");
                    return false;
            }
            import_.kind = kind;
            import_.u.names.module_name = sub_module_name;
            import_.u.names.field_name = field_name;
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load import section success.\n");
    cast(void)u8;
    cast(void)u32;
    cast(void)type_index;
    return true;
fail:
    return false;
}
private bool init_function_local_offsets(WASMFunction* func, char* error_buf, uint error_buf_size) {
    WASMType* param_type = func.func_type;
    uint param_count = param_type.param_count;
    ubyte* param_types = param_type.types;
    uint local_count = func.local_count;
    ubyte* local_types = func.local_types;
    uint i = void, local_offset = 0;
    ulong total_size = sizeof(uint16) * (cast(ulong)param_count + local_count);
    /*
     * Only allocate memory when total_size is not 0,
     * or the return value of malloc(0) might be NULL on some platforms,
     * which causes wasm loader return false.
     */
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
    if (func_count != code_count) {
        set_error_buf(error_buf, error_buf_size,
                      "function and code section have inconsistent lengths or "
                      ~ "unexpected end");
        return false;
    }
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
            if (type_index >= module_.type_count) {
                set_error_buf(error_buf, error_buf_size, "unknown type");
                return false;
            }
            type_index = wasm_get_smallest_type_idx(
                module_.types, module_.type_count, type_index);
            read_leb_uint32(p_code, buf_code_end, code_size);
            if (code_size == 0 || p_code + code_size > buf_code_end) {
                set_error_buf(error_buf, error_buf_size,
                              "invalid function code size");
                return false;
            }
            /* Resolve local set count */
            p_code_end = p_code + code_size;
            local_count = 0;
            read_leb_uint32(p_code, buf_code_end, local_set_count);
            p_code_save = p_code;
            /* Calculate total local count */
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                if (sub_local_count > UINT32_MAX - local_count) {
                    set_error_buf(error_buf, error_buf_size, "too many locals");
                    return false;
                }
                 if (!check_buf(p_code, buf_code_end, 1, error_buf, error_buf_size)) { goto fail; }
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                local_count += sub_local_count;
            }
            /* Alloc memory, layout: function structure + local types */
            code_size = cast(uint)(p_code_end - p_code);
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
                if (local_type_index > UINT32_MAX - sub_local_count
                    || local_type_index + sub_local_count > local_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid local count");
                    return false;
                }
                 if (!check_buf(p_code, buf_code_end, 1, error_buf, error_buf_size)) { goto fail; }
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                if (!is_value_type(type)) {
                    if (type == VALUE_TYPE_V128)
                        set_error_buf(error_buf, error_buf_size,
                                      "v128 value type requires simd feature");
                    else if (type == VALUE_TYPE_FUNCREF
                             || type == VALUE_TYPE_EXTERNREF)
                        set_error_buf(error_buf, error_buf_size,
                                      "ref value type requires "
                                      ~ "reference types feature");
                    else
                        set_error_buf_v(error_buf, error_buf_size,
                                        "invalid local type 0x%02X", type);
                    return false;
                }
                for (k = 0; k < sub_local_count; k++) {
                    func.local_types[local_type_index++] = type;
                }
            }
            func.param_cell_num = func.func_type.param_cell_num;
            func.ret_cell_num = func.func_type.ret_cell_num;
            local_cell_num =
                wasm_get_cell_num(func.local_types, func.local_count);
            if (local_cell_num > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "local count too large");
                return false;
            }
            func.local_cell_num = cast(ushort)local_cell_num;
            if (!init_function_local_offsets(func, error_buf, error_buf_size))
                return false;
            p_code = p_code_end;
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load function section success.\n");
    return true;
fail:
    return false;
}
private bool check_function_index(const(WASMModule)* module_, uint function_index, char* error_buf, uint error_buf_size) {
    if (function_index
        >= module_.import_function_count + module_.function_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown function %d",
                        function_index);
        return false;
    }
    return true;
}
private bool load_table_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint table_count = void, i = void;
    ulong total_size = void;
    WASMTable* table = void;
    read_leb_uint32(p, p_end, table_count);
    if (module_.import_table_count + table_count > 1) {
        /* a total of one table is allowed */
        set_error_buf(error_buf, error_buf_size, "multiple tables");
        return false;
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
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load table section success.\n");
    return true;
fail:
    return false;
}
private bool load_memory_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint memory_count = void, i = void;
    ulong total_size = void;
    WASMMemory* memory = void;
    read_leb_uint32(p, p_end, memory_count);
    /* a total of one memory is allowed */
    if (module_.import_memory_count + memory_count > 1) {
        set_error_buf(error_buf, error_buf_size, "multiple memories");
        return false;
    }
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
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load memory section success.\n");
    return true;
fail:
    return false;
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
             if (!check_buf(p, p_end, 2, error_buf, error_buf_size)) { goto fail; }
            global.type = read_uint8(p);
            mutable = read_uint8(p);
            if (mutable >= 2) {
                set_error_buf(error_buf, error_buf_size, "invalid mutability");
                return false;
            }
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
                if (target_global_index >= module_.import_global_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    return false;
                }
            }
            else if (INIT_EXPR_TYPE_FUNCREF_CONST
                     == global.init_expr.init_expr_type) {
                if (!check_function_index(module_, global.init_expr.u.ref_index,
                                          error_buf, error_buf_size)) {
                    return false;
                }
            }
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load global section success.\n");
    return true;
fail:
    return false;
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
            if (p == p_end) {
                /* export section with inconsistent count:
                   n export declared, but less than n given */
                set_error_buf(error_buf, error_buf_size,
                              "length out of bounds");
                return false;
            }
            read_leb_uint32(p, p_end, str_len);
             if (!check_buf(p, p_end, str_len, error_buf, error_buf_size)) { goto fail; }
            for (j = 0; j < i; j++) {
                name = module_.exports[j].name;
                if (strlen(name) == str_len && memcmp(name, p, str_len) == 0) {
                    set_error_buf(error_buf, error_buf_size,
                                  "duplicate export name");
                    return false;
                }
            }
            if (((export_.name = const_str_list_insert(
                      p, str_len, module_, is_load_from_file_buf, error_buf,
                      error_buf_size)) == 0)) {
                return false;
            }
            p += str_len;
             if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
            export_.kind = read_uint8(p);
            read_leb_uint32(p, p_end, index);
            export_.index = index;
            switch (export_.kind) {
                /* function index */
                case EXPORT_KIND_FUNC:
                    if (index >= module_.function_count
                                     + module_.import_function_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown function");
                        return false;
                    }
                    break;
                /* table index */
                case EXPORT_KIND_TABLE:
                    if (index
                        >= module_.table_count + module_.import_table_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown table");
                        return false;
                    }
                    break;
                /* memory index */
                case EXPORT_KIND_MEMORY:
                    if (index
                        >= module_.memory_count + module_.import_memory_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown memory");
                        return false;
                    }
                    break;
                /* global index */
                case EXPORT_KIND_GLOBAL:
                    if (index
                        >= module_.global_count + module_.import_global_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown global");
                        return false;
                    }
                    break;
                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid export kind");
                    return false;
            }
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load export section success.\n");
    return true;
fail:
    return false;
}
private bool check_table_index(const(WASMModule)* module_, uint table_index, char* error_buf, uint error_buf_size) {
    if (table_index != 0) {
        set_error_buf(error_buf, error_buf_size, "zero byte expected");
        return false;
    }
    if (table_index >= module_.import_table_count + module_.table_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown table %d",
                        table_index);
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
fail:
    return false;
}
private bool load_func_index_vec(const(ubyte)** p_buf, const(ubyte)* buf_end, WASMModule* module_, WASMTableSeg* table_segment, bool use_init_expr, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = *p_buf, p_end = buf_end;
    uint function_count = void, function_index = 0, i = void;
    ulong total_size = void;
    read_leb_uint32(p, p_end, function_count);
    table_segment.function_count = function_count;
    total_size = uint.sizeof * cast(ulong)function_count;
    if (total_size > 0
        && ((table_segment.func_indexes = cast(uint*)loader_malloc(
                 total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }
    for (i = 0; i < function_count; i++) {
        InitializerExpression init_expr = { 0 };
        read_leb_uint32(p, p_end, function_index);
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
fail:
    return false;
}
private bool load_table_segment_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint table_segment_count = void, i = void;
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
            if (p >= p_end) {
                set_error_buf(error_buf, error_buf_size,
                              "invalid value type or "
                              ~ "invalid elements segment kind");
                return false;
            }
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
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load table segment section success.\n");
    return true;
fail:
    return false;
}
private bool load_data_segment_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint data_seg_count = void, i = void, mem_index = void, data_seg_len = void;
    ulong total_size = void;
    WASMDataSeg* dataseg = void;
    InitializerExpression init_expr = void;
    read_leb_uint32(p, p_end, data_seg_count);
    if (data_seg_count) {
        module_.data_seg_count = data_seg_count;
        total_size = (WASMDataSeg*).sizeof * cast(ulong)data_seg_count;
        if (((module_.data_segments =
                  loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
            return false;
        }
        for (i = 0; i < data_seg_count; i++) {
            read_leb_uint32(p, p_end, mem_index);
            if (mem_index
                >= module_.import_memory_count + module_.memory_count) {
                set_error_buf_v(error_buf, error_buf_size, "unknown memory %d",
                                mem_index);
                return false;
            }
                if (!load_init_expr(&p, p_end, &init_expr, VALUE_TYPE_I32,
                                    error_buf, error_buf_size))
                    return false;
            read_leb_uint32(p, p_end, data_seg_len);
            if (((dataseg = module_.data_segments[i] = loader_malloc(
                      WASMDataSeg.sizeof, error_buf, error_buf_size)) == 0)) {
                return false;
            }
            {
                bh_memcpy_s(&dataseg.base_offset,
                            InitializerExpression.sizeof, &init_expr,
                            InitializerExpression.sizeof);
                dataseg.memory_index = mem_index;
            }
            dataseg.data_length = data_seg_len;
             if (!check_buf(p, p_end, data_seg_len, error_buf, error_buf_size)) { goto fail; }
            dataseg.data = cast(ubyte*)p;
            p += data_seg_len;
        }
    }
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load data segment section success.\n");
    return true;
fail:
    return false;
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
    if (func_count != code_count) {
        set_error_buf(error_buf, error_buf_size,
                      "function and code section have inconsistent lengths");
        return false;
    }
    LOG_VERBOSE("Load code segment section success.\n");
    return true;
fail:
    return false;
}
private bool load_start_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    WASMType* type = void;
    uint start_function = void;
    read_leb_uint32(p, p_end, start_function);
    if (start_function
        >= module_.function_count + module_.import_function_count) {
        set_error_buf(error_buf, error_buf_size, "unknown function");
        return false;
    }
    if (start_function < module_.import_function_count)
        type = module_.import_functions[start_function].u.function_.func_type;
    else
        type = module_.functions[start_function - module_.import_function_count]
                   .func_type;
    if (type.param_count != 0 || type.result_count != 0) {
        set_error_buf(error_buf, error_buf_size, "invalid start function");
        return false;
    }
    module_.start_function = start_function;
    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }
    LOG_VERBOSE("Load start section success.\n");
    return true;
fail:
    return false;
}
private bool load_user_section(const(ubyte)* buf, const(ubyte)* buf_end, WASMModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    char[32] section_name = void;
    uint name_len = void, buffer_len = void;
    if (p >= p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }
    read_leb_uint32(p, p_end, name_len);
    if (name_len == 0 || p + name_len > p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }
    if (!check_utf8_str(p, name_len)) {
        set_error_buf(error_buf, error_buf_size, "invalid UTF-8 encoding");
        return false;
    }
    buffer_len = section_name.sizeof;
    memset(section_name.ptr, 0, buffer_len);
    if (name_len < buffer_len) {
        bh_memcpy_s(section_name.ptr, buffer_len, p, name_len);
    }
    else {
        bh_memcpy_s(section_name.ptr, buffer_len, p, buffer_len - 4);
        memset(section_name.ptr + buffer_len - 4, '.', 3);
    }
    LOG_VERBOSE("Ignore custom section [%s].", section_name.ptr);
    return true;
fail:
    return false;
}
private void calculate_global_data_offset(WASMModule* module_) {
    uint i = void, data_offset = void;
    data_offset = 0;
    for (i = 0; i < module_.import_global_count; i++) {
        WASMGlobalImport* import_global = &((module_.import_globals + i).u.global);
        import_global.data_offset = data_offset;
        data_offset += wasm_value_type_size(import_global.type);
    }
    for (i = 0; i < module_.global_count; i++) {
        WASMGlobal* global = module_.globals + i;
        global.data_offset = data_offset;
        data_offset += wasm_value_type_size(global.type);
    }
    module_.global_data_size = data_offset;
}
private bool init_fast_jit_functions(WASMModule* module_, char* error_buf, uint error_buf_size) {
    uint i = void;
    if (!module_.function_count)
        return true;
    if (((module_.fast_jit_func_ptrs =
              loader_malloc((void*).sizeof * module_.function_count, error_buf,
                            error_buf_size)) == 0)) {
        return false;
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
private bool init_llvm_jit_functions_stage1(WASMModule* module_, char* error_buf, uint error_buf_size) {
    AOTCompOption option = { 0 };
    char* aot_last_error = void;
    ulong size = void;
    if (module_.function_count == 0)
        return true;
    size = (void*).sizeof * cast(ulong)module_.function_count
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
    option.enable_aux_stack_check = true;
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
            set_error_buf_v(error_buf, error_buf_size,
                            "failed to compile llvm jit function: %s", err_msg);
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
    }
    bh_print_time("End lookup llvm jit functions");
    return true;
}
/* The callback function to compile jit functions */
private void* orcjit_thread_callback(void* arg) {
    OrcJitThreadArg* thread_arg = cast(OrcJitThreadArg*)arg;
    AOTCompContext* comp_ctx = thread_arg.comp_ctx;
    WASMModule* module_ = thread_arg.module_;
    uint group_idx = thread_arg.group_idx;
    uint group_stride = WASM_ORC_JIT_BACKEND_THREAD_NUM;
    uint func_count = module_.function_count;
    uint i = void;
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
            }
        }
        if (module_.orcjit_stop_compiling) {
            break;
        }
    }
    return null;
}
private void orcjit_stop_compile_threads(WASMModule* module_) {
    uint i = void, thread_num = cast(uint)(sizeof(module_.orcjit_thread_args)
                                    / OrcJitThreadArg.sizeof);
    module_.orcjit_stop_compiling = true;
    for (i = 0; i < thread_num; i++) {
        if (module_.orcjit_threads[i])
            os_thread_join(module_.orcjit_threads[i], null);
    }
}
private bool compile_jit_functions(WASMModule* module_, char* error_buf, uint error_buf_size) {
    uint thread_num = cast(uint)(sizeof(module_.orcjit_thread_args) / OrcJitThreadArg.sizeof);
    uint i = void, j = void;
    bh_print_time("Begin to compile jit functions");
    /* Create threads to compile the jit functions */
    for (i = 0; i < thread_num && i < module_.function_count; i++) {
        module_.orcjit_thread_args[i].comp_ctx = module_.comp_ctx;
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
    /* Wait until all jit functions are compiled for eager mode */
    for (i = 0; i < thread_num; i++) {
        if (module_.orcjit_threads[i])
            os_thread_join(module_.orcjit_threads[i], null);
    }
    /* Ensure all the fast-jit functions are compiled */
    for (i = 0; i < module_.function_count; i++) {
        if (!jit_compiler_is_compiled(module_,
                                      i + module_.import_function_count)) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to compile fast jit function");
            return false;
        }
    }
    /* Ensure all the llvm-jit functions are compiled */
    for (i = 0; i < module_.function_count; i++) {
        if (!module_.func_ptrs_compiled[i]) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to compile llvm jit function");
            return false;
        }
    }
    bh_print_time("End compile jit functions");
    return true;
}
private bool wasm_loader_prepare_bytecode(WASMModule* module_, WASMFunction* func, uint cur_func_idx, char* error_buf, uint error_buf_size);
private bool load_from_sections(WASMModule* module_, WASMSection* sections, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    WASMExport* export_ = void;
    WASMSection* section = sections;
    const(ubyte)* buf = void, buf_end = void, buf_code = null, buf_code_end = null, buf_func = null, buf_func_end = null;
    WASMGlobal* aux_data_end_global = null, aux_heap_base_global = null;
    WASMGlobal* aux_stack_top_global = null, global = void;
    uint aux_data_end = cast(uint)-1, aux_heap_base = cast(uint)-1;
    uint aux_stack_top = cast(uint)-1, global_index = void, func_index = void, i = void;
    uint aux_data_end_global_index = cast(uint)-1;
    uint aux_heap_base_global_index = cast(uint)-1;
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
            default:
                set_error_buf(error_buf, error_buf_size, "invalid section id");
                return false;
        }
        section = section.next;
    }
    module_.aux_data_end_global_index = cast(uint)-1;
    module_.aux_heap_base_global_index = cast(uint)-1;
    module_.aux_stack_top_global_index = cast(uint)-1;
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
    module_.malloc_function = cast(uint)-1;
    module_.free_function = cast(uint)-1;
    module_.retain_function = cast(uint)-1;
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
                    bh_assert(module_.malloc_function == cast(uint)-1);
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
                    bh_assert(module_.malloc_function == cast(uint)-1);
                    module_.malloc_function = export_.index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                export_.name, export_.index);
                    /* resolve retain function.
                       If not found, reset malloc function index */
                    export_tmp = module_.exports;
                    for (j = 0; j < module_.export_count; j++, export_tmp++) {
                        if ((export_tmp.kind == EXPORT_KIND_FUNC)
                            && (!strcmp(export_tmp.name, "__retain")
                                || (!strcmp(export_tmp.name, "__pin")))
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
                                          == cast(uint)-1);
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
                        module_.malloc_function = cast(uint)-1;
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
                    bh_assert(module_.free_function == cast(uint)-1);
                    module_.free_function = export_.index;
                    LOG_VERBOSE("Found free function, name: %s, index: %u",
                                export_.name, export_.index);
                }
            }
        }
    }
    for (i = 0; i < module_.function_count; i++) {
        WASMFunction* func = module_.functions[i];
        if (!wasm_loader_prepare_bytecode(module_, func, i, error_buf,
                                          error_buf_size)) {
            return false;
        }
        if (i == module_.function_count - 1
            && func.code + func.code_size != buf_code_end) {
            set_error_buf(error_buf, error_buf_size,
                          "code section size mismatch");
            return false;
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
    if (!init_fast_jit_functions(module_, error_buf, error_buf_size)) {
        return false;
    }
    if (!init_llvm_jit_functions_stage1(module_, error_buf, error_buf_size)) {
        return false;
    }
    if (!init_llvm_jit_functions_stage2(module_, error_buf, error_buf_size)) {
        return false;
    }
    /* Create threads to compile the jit functions */
    if (!compile_jit_functions(module_, error_buf, error_buf_size)) {
        return false;
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
    module_.start_function = cast(uint)-1;
    module_.br_table_cache_list = &module_.br_table_cache_list_head;
    ret = bh_list_init(module_.br_table_cache_list);
    bh_assert(ret == BH_LIST_SUCCESS);
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
private ubyte[12] section_ids = [
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
         if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
        section_type = read_uint8(p);
        section_index = get_section_index(section_type);
        if (section_index != (uint8)-1) {
            if (section_type != SECTION_TYPE_USER) {
                /* Custom sections may be inserted at any place,
                   while other sections must occur at most once
                   and in prescribed order. */
                if (last_section_index != (uint8)-1
                    && (section_index <= last_section_index)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unexpected content after last section or "
                                  ~ "junk after last section");
                    return false;
                }
                last_section_index = section_index;
            }
            read_leb_uint32(p, p_end, section_size);
             if (!check_buf1(p, p_end, section_size, error_buf, error_buf_size)) { goto fail; }
            if (((section = loader_malloc(WASMSection.sizeof, error_buf,
                                          error_buf_size)) == 0)) {
                return false;
            }
            section.section_type = section_type;
            section.section_body = cast(ubyte*)p;
            section.section_body_size = section_size;
            if (!section_list_end)
                *p_section_list = section_list_end = section;
            else {
                section_list_end.next = section;
                section_list_end = section;
            }
            p += section_size;
        }
        else {
            set_error_buf(error_buf, error_buf_size, "invalid section id");
            return false;
        }
    }
    return true;
fail:
    return false;
}
private void exchange32(ubyte* p_data) {
    ubyte value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;
    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

version(none) {

union ___ue {
    int a;
    char b = 0;
}
private ___ue __ue = { a: 1 };
}

private bool load(const(ubyte)* buf, uint size, WASMModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf_end = buf + size;
    const(ubyte)* p = buf, p_end = buf_end;
    uint magic_number = void, version_ = void;
    WASMSection* section_list = null;
     if (!check_buf1(p, p_end, uint32.sizeof, error_buf, error_buf_size)) { goto fail; }
    magic_number = read_uint32(p);
    if (!(__ue.b == 1))
        exchange32(cast(ubyte*)&magic_number);
    if (magic_number != WASM_MAGIC_NUMBER) {
        set_error_buf(error_buf, error_buf_size, "magic header not detected");
        return false;
    }
     if (!check_buf1(p, p_end, uint32.sizeof, error_buf, error_buf_size)) { goto fail; }
    version_ = read_uint32(p);
    if (!(__ue.b == 1))
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
    return true;
fail:
    return false;
}
WASMModule* wasm_loader_load(ubyte* buf, uint size, char* error_buf, uint error_buf_size) {
    WASMModule* module_ = create_module(error_buf, error_buf_size);
    if (!module_) {
        return null;
    }
    module_.load_addr = cast(ubyte*)buf;
    module_.load_size = size;
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
    /* Stop Fast/LLVM JIT compilation firstly to avoid accessing
       module internal data after they were freed */
    orcjit_stop_compile_threads(module_);
    if (module_.func_ptrs)
        wasm_runtime_free(module_.func_ptrs);
    if (module_.comp_ctx)
        aot_destroy_comp_context(module_.comp_ctx);
    if (module_.comp_data)
        aot_destroy_comp_data(module_.comp_data);
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
                if (module_.functions[i].fast_jit_jitted_code) {
                    jit_code_cache_free(
                        module_.functions[i].fast_jit_jitted_code);
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
    if (module_.br_table_cache_list) {
        BrTableCache* node = bh_list_first_elem(module_.br_table_cache_list);
        BrTableCache* node_next = void;
        while (node) {
            node_next = bh_list_elem_next(node);
            wasm_runtime_free(node);
            node = node_next;
        }
    }
    if (module_.fast_jit_func_ptrs) {
        wasm_runtime_free(module_.fast_jit_func_ptrs);
    }
    for (i = 0; i < WASM_ORC_JIT_BACKEND_THREAD_NUM; i++) {
        if (module_.fast_jit_thread_locks_inited[i]) {
            os_mutex_destroy(&module_.fast_jit_thread_locks[i]);
        }
    }
    wasm_runtime_free(module_);
}
bool wasm_loader_find_block_addr(WASMExecEnv* exec_env, BlockAddr* block_addr_cache, const(ubyte)* start_addr, const(ubyte)* code_end_addr, ubyte label_type, ubyte** p_else_addr, 
ubyte** p_end_addr) {
    const(ubyte)* p = start_addr, p_end = code_end_addr;
    ubyte* else_addr = null;
    char[128] error_buf = void;
    uint block_nested_depth = 1, count = void, i = void, j = void, t = void;
    uint error_buf_size = error_buf.sizeof;
    ubyte opcode = void, u8 = void;
    BlockAddr[16] block_stack ; BlockAddr* block = void;
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
                p += count + 1;
                while (*p == WASM_OP_NOP)
                    p++;
                break;
            case EXT_OP_BR_TABLE_CACHE:
                read_leb_uint32(p, p_end, count); /* lable num */
                while (*p == WASM_OP_NOP)
                    p++;
                break;
            case WASM_OP_RETURN:
                break;
            case WASM_OP_CALL:
                skip_leb_uint32(p, p_end); /* funcidx */
                break;
            case WASM_OP_CALL_INDIRECT:
                skip_leb_uint32(p, p_end); /* typeidx */
                 if (!check_buf(p, p_end, 1, error_buf.ptr, error_buf_size)) { goto fail; }
                u8 = read_uint8(p); /* 0x00 */
                break;
            case WASM_OP_DROP:
            case WASM_OP_SELECT:
            case WASM_OP_DROP_64:
            case WASM_OP_SELECT_64:
                break;
            case WASM_OP_GET_LOCAL:
            case WASM_OP_SET_LOCAL:
            case WASM_OP_TEE_LOCAL:
            case WASM_OP_GET_GLOBAL:
            case WASM_OP_SET_GLOBAL:
            case WASM_OP_GET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_AUX_STACK:
                skip_leb_uint32(p, p_end); /* local index */
                break;
            case EXT_OP_GET_LOCAL_FAST:
            case EXT_OP_SET_LOCAL_FAST:
            case EXT_OP_TEE_LOCAL_FAST:
                 if (!check_buf(p, p_end, 1, error_buf.ptr, error_buf_size)) { goto fail; }
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
                p += float.sizeof;
                break;
            case WASM_OP_F64_CONST:
                p += double.sizeof;
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
                    default:
                        return false;
                }
                break;
            }
            default:
                return false;
        }
    }
    cast(void)u8;
    return false;
fail:
    return false;
}
struct BranchBlock {
    ubyte label_type;
    BlockType block_type;
    ubyte* start_addr;
    ubyte* else_addr;
    ubyte* end_addr;
    uint stack_cell_num;
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
private bool check_stack_push(WASMLoaderContext* ctx, char* error_buf, uint error_buf_size) {
    if (ctx.frame_ref >= ctx.frame_ref_boundary) {
         void* mem_new = memory_realloc(ctx.frame_ref_bottom, ctx.frame_ref_size, ctx.frame_ref_size + 16, error_buf, error_buf_size); if (!mem_new) goto fail; ctx.frame_ref_bottom = mem_new;
        ctx.frame_ref_size += 16;
        ctx.frame_ref_boundary = ctx.frame_ref_bottom + ctx.frame_ref_size;
        ctx.frame_ref = ctx.frame_ref_bottom + ctx.stack_cell_num;
    }
    return true;
fail:
    return false;
}
private bool check_stack_top_values(ubyte* frame_ref, int stack_cell_num, ubyte type, char* error_buf, uint error_buf_size) {
    if ((is_32bit_type(type) && stack_cell_num < 1)
        || (is_64bit_type(type) && stack_cell_num < 2)
    ) {
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: expect data but stack was empty");
        return false;
    }
    if ((is_32bit_type(type) && *(frame_ref - 1) != type)
        || (is_64bit_type(type)
            && (*(frame_ref - 2) != type || *(frame_ref - 1) != type))
    ) {
        set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                        "type mismatch: expect ", type2str(type),
                        " but got other");
        return false;
    }
    return true;
}
private bool check_stack_pop(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    int block_stack_cell_num = cast(int)(ctx.stack_cell_num - (ctx.frame_csp - 1).stack_cell_num);
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
            wasm_runtime_free(ctx.frame_csp_bottom);
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
    loader_ctx.frame_csp_size = BranchBlock.sizeof * 8;
    if (((loader_ctx.frame_csp_bottom = loader_ctx.frame_csp = loader_malloc(
              loader_ctx.frame_csp_size, error_buf, error_buf_size)) == 0))
        goto fail;
    loader_ctx.frame_csp_boundary = loader_ctx.frame_csp_bottom + 8;
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
    if (is_32bit_type(type) || type == VALUE_TYPE_ANY)
        goto check_stack_and_return;
    if (!check_stack_push(ctx, error_buf, error_buf_size))
        return false;
    *ctx.frame_ref++ = type;
    ctx.stack_cell_num++;
check_stack_and_return:
    if (ctx.stack_cell_num > ctx.max_stack_cell_num) {
        ctx.max_stack_cell_num = ctx.stack_cell_num;
        if (ctx.max_stack_cell_num > UINT16_MAX) {
            set_error_buf(error_buf, error_buf_size,
                          "operand stack depth limit exceeded");
            return false;
        }
    }
    return true;
}
private bool wasm_loader_pop_frame_ref(WASMLoaderContext* ctx, ubyte type, char* error_buf, uint error_buf_size) {
    BranchBlock* cur_block = ctx.frame_csp - 1;
    int available_stack_cell = cast(int)(ctx.stack_cell_num - cur_block.stack_cell_num);
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
     if (ctx.frame_csp >= ctx.frame_csp_boundary) {  void* mem_new = memory_realloc(ctx.frame_csp_bottom, ctx.frame_csp_size, cast(uint)(ctx.frame_csp_size + 8 * BranchBlock.sizeof), error_buf, error_buf_size); if (!mem_new) goto fail; ctx.frame_csp_bottom = mem_new; ctx.frame_csp_size += cast(uint)(8 * BranchBlock.sizeof); ctx.frame_csp_boundary = ctx.frame_csp_bottom + ctx.frame_csp_size / BranchBlock.sizeof; ctx.frame_csp = ctx.frame_csp_bottom + ctx.csp_num; }
    memset(ctx.frame_csp, 0, BranchBlock.sizeof);
    ctx.frame_csp.label_type = label_type;
    ctx.frame_csp.block_type = block_type;
    ctx.frame_csp.start_addr = start_addr;
    ctx.frame_csp.stack_cell_num = ctx.stack_cell_num;
    ctx.frame_csp++;
    ctx.csp_num++;
    if (ctx.csp_num > ctx.max_csp_num) {
        ctx.max_csp_num = ctx.csp_num;
        if (ctx.max_csp_num > UINT16_MAX) {
            set_error_buf(error_buf, error_buf_size,
                          "label stack depth limit exceeded");
            return false;
        }
    }
    return true;
fail:
    return false;
}
private bool wasm_loader_pop_frame_csp(WASMLoaderContext* ctx, char* error_buf, uint error_buf_size) {
     if (ctx.csp_num < 1) { set_error_buf(error_buf, error_buf_size, "type mismatch: " ~ "expect data but block stack was empty"); goto fail; }
    ctx.frame_csp--;
    ctx.csp_num--;
    return true;
fail:
    return false;
}
/* type of POPs should be the same */
private bool check_memory(WASMModule* module_, char* error_buf, uint error_buf_size) {
    if (module_.memory_count == 0 && module_.import_memory_count == 0) {
        set_error_buf(error_buf, error_buf_size, "unknown memory");
        return false;
    }
    return true;
}
private bool check_memory_access_align(ubyte opcode, uint align_, char* error_buf, uint error_buf_size) {
    ubyte[23] mem_access_aligns = [
        2, 3, 2, 3, 0, 0, 1, 1, 0, 0, 1, 1, 2, 2, /* loads */
        2, 3, 2, 3, 0, 1, 0, 1, 2 /* stores */
    ];
    bh_assert(opcode >= WASM_OP_I32_LOAD && opcode <= WASM_OP_I64_STORE32);
    if (align_ > mem_access_aligns[opcode - WASM_OP_I32_LOAD]) {
        set_error_buf(error_buf, error_buf_size,
                      "alignment must not be larger than natural");
        return false;
    }
    return true;
}
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
             if (!(wasm_loader_pop_frame_ref(loader_ctx, types[i], error_buf, error_buf_size))) goto fail;
        }
        for (i = 0; i < cast(int)arity; i++) {
             if (!(wasm_loader_push_frame_ref(loader_ctx, types[i], error_buf, error_buf_size))) goto fail;
        }
        return true;
    }
    available_stack_cell =
        cast(int)(loader_ctx.stack_cell_num - cur_block.stack_cell_num);
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
     if (!wasm_loader_check_br(loader_ctx, depth, error_buf, error_buf_size)) goto fail;
    frame_csp_tmp = loader_ctx.frame_csp - depth - 1;
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
        cast(int)(loader_ctx.stack_cell_num - block.stack_cell_num);
    return_count = block_type_get_result_types(block_type, &return_types);
    return_cell_num =
        return_count > 0 ? wasm_get_cell_num(return_types, return_count) : 0;
    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (block.is_stack_polymorphic) {
        for (i = cast(int)return_count - 1; i >= 0; i--) {
             if (!(wasm_loader_pop_frame_ref(loader_ctx, return_types[i], error_buf, error_buf_size))) goto fail;
        }
        /* Check stack is empty */
        if (loader_ctx.stack_cell_num != block.stack_cell_num) {
            set_error_buf(
                error_buf, error_buf_size,
                "type mismatch: stack size does not match block type");
            goto fail;
        }
        for (i = 0; i < cast(int)return_count; i++) {
             if (!(wasm_loader_push_frame_ref(loader_ctx, return_types[i], error_buf, error_buf_size))) goto fail;
        }
        return true;
    }
    /* Check stack cell num equals return cell num */
    if (available_stack_cell != return_cell_num) {
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: stack size does not match block type");
        goto fail;
    }
    /* Check stack values match return types */
    frame_ref = loader_ctx.frame_ref;
    for (i = cast(int)return_count - 1; i >= 0; i--) {
        if (!check_stack_top_values(frame_ref, available_stack_cell,
                                    return_types[i], error_buf, error_buf_size))
            return false;
        frame_ref -= wasm_value_type_cell_num(return_types[i]);
        available_stack_cell -= wasm_value_type_cell_num(return_types[i]);
    }
    return true;
fail:
    return false;
}
/* reset the stack to the state of before entering the last block */
/* set current block's stack polymorphic state */
private bool wasm_loader_prepare_bytecode(WASMModule* module_, WASMFunction* func, uint cur_func_idx, char* error_buf, uint error_buf_size) {
    ubyte* p = func.code, p_end = func.code + func.code_size, p_org = void;
    uint param_count = void, local_count = void, global_count = void;
    ubyte* param_types = void, local_types = void; ubyte local_type = void, global_type = void;
    BlockType func_block_type = void;
    ushort* local_offsets = void; ushort local_offset = void;
    uint type_idx = void, func_idx = void, local_idx = void, global_idx = void, table_idx = void;
    uint table_seg_idx = void, data_seg_idx = void, count = void, align_ = void, mem_offset = void, i = void;
    int i32_const = 0;
    long i64_const = void;
    ubyte opcode = void;
    bool return_value = false;
    WASMLoaderContext* loader_ctx = void;
    BranchBlock* frame_csp_tmp = void;
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
     if (!wasm_loader_push_frame_csp(loader_ctx, LABEL_TYPE_FUNCTION, func_block_type, p, error_buf, error_buf_size)) goto fail;
    while (p < p_end) {
        opcode = *p++;
        switch (opcode) {
            case WASM_OP_UNREACHABLE:
                 loader_ctx.stack_cell_num = (loader_ctx.frame_csp - 1).stack_cell_num; loader_ctx.frame_ref = loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num;
                 BranchBlock* _cur_block = loader_ctx.frame_csp - 1; _cur_block.is_stack_polymorphic = true;
                break;
            case WASM_OP_NOP:
                break;
            case WASM_OP_IF:
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                goto handle_op_block_and_loop;
            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
            handle_op_block_and_loop:
            {
                ubyte value_type = void;
                BlockType block_type = void;
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
                    uint type_index = void;
                    /* Resolve the leb128 encoded type index as block type */
                    p--;
                    read_leb_uint32(p, p_end, type_index);
                    if (type_index >= module_.type_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown type");
                        goto fail;
                    }
                    block_type.is_value_type = false;
                    block_type.u.type = module_.types[type_index];
                    /* If block use type index as block type, change the opcode
                     * to new extended opcode so that interpreter can resolve
                     * the block quickly.
                     */
                    *p_org = EXT_OP_BLOCK + (opcode - WASM_OP_BLOCK);
                }
                /* Pop block parameters from stack */
                if ((!block_type.is_value_type && block_type.u.type.param_count > 0)) {
                    WASMType* wasm_type = block_type.u.type;
                    for (i = 0; i < block_type.u.type.param_count; i++)
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, wasm_type.types[wasm_type.param_count - i - 1], error_buf, error_buf_size))) goto fail;
                }
                 if (!wasm_loader_push_frame_csp(loader_ctx, LABEL_TYPE_BLOCK + (opcode - WASM_OP_BLOCK), block_type, p, error_buf, error_buf_size)) goto fail;
                /* Pass parameters to block */
                if ((!block_type.is_value_type && block_type.u.type.param_count > 0)) {
                    for (i = 0; i < block_type.u.type.param_count; i++)
                         if (!(wasm_loader_push_frame_ref(loader_ctx, block_type.u.type.types[i], error_buf, error_buf_size))) goto fail;
                }
                break;
            }
            case WASM_OP_ELSE:
            {
                BlockType block_type = (loader_ctx.frame_csp - 1).block_type;
                if (loader_ctx.csp_num < 2
                    || (loader_ctx.frame_csp - 1).label_type
                           != LABEL_TYPE_IF) {
                    set_error_buf(
                        error_buf, error_buf_size,
                        "opcode else found without matched opcode if");
                    goto fail;
                }
                /* check whether if branch's stack matches its result type */
                if (!check_block_stack(loader_ctx, loader_ctx.frame_csp - 1,
                                       error_buf, error_buf_size))
                    goto fail;
                (loader_ctx.frame_csp - 1).else_addr = p - 1;
                 loader_ctx.stack_cell_num = (loader_ctx.frame_csp - 1).stack_cell_num; loader_ctx.frame_ref = loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num;
                 BranchBlock* _cur_block = loader_ctx.frame_csp - 1; _cur_block.is_stack_polymorphic = false;
                /* Pass parameters to if-false branch */
                if ((!block_type.is_value_type && block_type.u.type.param_count > 0)) {
                    for (i = 0; i < block_type.u.type.param_count; i++)
                         if (!(wasm_loader_push_frame_ref(loader_ctx, block_type.u.type.types[i], error_buf, error_buf_size))) goto fail;
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
                    if (block_param_count != block_ret_count
                        || (block_param_count
                            && memcmp(block_param_types, block_ret_types,
                                      block_param_count))) {
                        set_error_buf(error_buf, error_buf_size,
                                      "type mismatch: else branch missing");
                        goto fail;
                    }
                }
                 if (!wasm_loader_pop_frame_csp(loader_ctx, error_buf, error_buf_size)) goto fail;
                if (loader_ctx.csp_num > 0) {
                    loader_ctx.frame_csp.end_addr = p - 1;
                }
                else {
                    /* end of function block, function will return */
                    if (p < p_end) {
                        set_error_buf(error_buf, error_buf_size,
                                      "section size mismatch");
                        goto fail;
                    }
                }
                break;
            }
            case WASM_OP_BR:
            {
                if (((frame_csp_tmp = check_branch_block(
                          loader_ctx, &p, p_end, error_buf, error_buf_size)) == 0))
                    goto fail;
                 loader_ctx.stack_cell_num = (loader_ctx.frame_csp - 1).stack_cell_num; loader_ctx.frame_ref = loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num;
                 BranchBlock* _cur_block = loader_ctx.frame_csp - 1; _cur_block.is_stack_polymorphic = true;
                break;
            }
            case WASM_OP_BR_IF:
            {
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                if (((frame_csp_tmp = check_branch_block(
                          loader_ctx, &p, p_end, error_buf, error_buf_size)) == 0))
                    goto fail;
                break;
            }
            case WASM_OP_BR_TABLE:
            {
                ubyte* ret_types = null;
                uint ret_count = 0;
                ubyte* p_depth_begin = void, p_depth = void;
                uint depth = void, j = void;
                BrTableCache* br_table_cache = null;
                p_org = p - 1;
                read_leb_uint32(p, p_end, count);
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                p_depth_begin = p_depth = p;
                for (i = 0; i <= count; i++) {
                    if (((frame_csp_tmp =
                              check_branch_block(loader_ctx, &p, p_end,
                                                 error_buf, error_buf_size)) == 0))
                        goto fail;
                    if (i == 0) {
                        if (frame_csp_tmp.label_type != LABEL_TYPE_LOOP)
                            ret_count = block_type_get_result_types(
                                &frame_csp_tmp.block_type, &ret_types);
                    }
                    else {
                        ubyte* tmp_ret_types = null;
                        uint tmp_ret_count = 0;
                        /* Check whether all table items have the same return
                         * type */
                        if (frame_csp_tmp.label_type != LABEL_TYPE_LOOP)
                            tmp_ret_count = block_type_get_result_types(
                                &frame_csp_tmp.block_type, &tmp_ret_types);
                        if (ret_count != tmp_ret_count
                            || (ret_count
                                && 0
                                       != memcmp(ret_types, tmp_ret_types,
                                                 ret_count))) {
                            set_error_buf(
                                error_buf, error_buf_size,
                                "type mismatch: br_table targets must "
                                ~ "all use same result type");
                            goto fail;
                        }
                    }
                    depth = cast(uint)(loader_ctx.frame_csp - 1 - frame_csp_tmp);
                    if (br_table_cache) {
                        br_table_cache.br_depths[i] = depth;
                    }
                    else {
                        if (depth > 255) {
                            /* The depth cannot be stored in one byte,
                               create br_table cache to store each depth */
                            if (((br_table_cache = loader_malloc(
                                      BrTableCache.br_depths.offsetof
                                          + uint32.sizeof
                                                * cast(ulong)(count + 1),
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
                /* Set the tailing bytes to nop */
                if (br_table_cache)
                    p_depth = p_depth_begin;
                while (p_depth < p)
                    *p_depth++ = WASM_OP_NOP;
                 loader_ctx.stack_cell_num = (loader_ctx.frame_csp - 1).stack_cell_num; loader_ctx.frame_ref = loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num;
                 BranchBlock* _cur_block = loader_ctx.frame_csp - 1; _cur_block.is_stack_polymorphic = true;
                break;
            }
            case WASM_OP_RETURN:
            {
                int idx = void;
                ubyte ret_type = void;
                for (idx = cast(int)func.func_type.result_count - 1; idx >= 0;
                     idx--) {
                    ret_type = *(func.func_type.types
                                 + func.func_type.param_count + idx);
                     if (!(wasm_loader_pop_frame_ref(loader_ctx, ret_type, error_buf, error_buf_size))) goto fail;
                }
                 loader_ctx.stack_cell_num = (loader_ctx.frame_csp - 1).stack_cell_num; loader_ctx.frame_ref = loader_ctx.frame_ref_bottom + loader_ctx.stack_cell_num;
                 BranchBlock* _cur_block = loader_ctx.frame_csp - 1; _cur_block.is_stack_polymorphic = true;
                break;
            }
            case WASM_OP_CALL:
            {
                WASMType* func_type = void;
                int idx = void;
                read_leb_uint32(p, p_end, func_idx);
                if (!check_function_index(module_, func_idx, error_buf,
                                          error_buf_size)) {
                    goto fail;
                }
                if (func_idx < module_.import_function_count)
                    func_type =
                        module_.import_functions[func_idx].u.function_.func_type;
                else
                    func_type = module_
                                    .functions[func_idx
                                                - module_.import_function_count]
                                    .func_type;
                if (func_type.param_count > 0) {
                    for (idx = cast(int)(func_type.param_count - 1); idx >= 0;
                         idx--) {
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, func_type.types[idx], error_buf, error_buf_size))) goto fail;
                    }
                }
                    for (i = 0; i < func_type.result_count; i++) {
                         if (!(wasm_loader_push_frame_ref(loader_ctx, func_type.types[func_type.param_count + i], error_buf, error_buf_size))) goto fail;
                    }
                func.has_op_func_call = true;
                break;
            }
            /*
             * if disable reference type: call_indirect typeidx, 0x00
             * if enable reference type:  call_indirect typeidx, tableidx
             */
            case WASM_OP_CALL_INDIRECT:
            {
                int idx = void;
                WASMType* func_type = void;
                read_leb_uint32(p, p_end, type_idx);
                 if (!check_buf(p, p_end, 1, error_buf, error_buf_size)) { goto fail; }
                table_idx = read_uint8(p);
                if (!check_table_index(module_, table_idx, error_buf,
                                       error_buf_size)) {
                    goto fail;
                }
                /* skip elem idx */
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                if (type_idx >= module_.type_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown type");
                    goto fail;
                }
                func_type = module_.types[type_idx];
                if (func_type.param_count > 0) {
                    for (idx = cast(int)(func_type.param_count - 1); idx >= 0;
                         idx--) {
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, func_type.types[idx], error_buf, error_buf_size))) goto fail;
                    }
                }
                    for (i = 0; i < func_type.result_count; i++) {
                         if (!(wasm_loader_push_frame_ref(loader_ctx, func_type.types[func_type.param_count + i], error_buf, error_buf_size))) goto fail;
                    }
                func.has_op_func_call = true;
                func.has_op_call_indirect = true;
                break;
            }
            case WASM_OP_DROP:
            {
                BranchBlock* cur_block = loader_ctx.frame_csp - 1;
                int available_stack_cell = cast(int)(loader_ctx.stack_cell_num
                            - cur_block.stack_cell_num);
                if (available_stack_cell <= 0
                    && !cur_block.is_stack_polymorphic) {
                    set_error_buf(error_buf, error_buf_size,
                                  "type mismatch, opcode drop was found "
                                  ~ "but stack was empty");
                    goto fail;
                }
                if (available_stack_cell > 0) {
                    if (is_32bit_type(*(loader_ctx.frame_ref - 1))) {
                        loader_ctx.frame_ref--;
                        loader_ctx.stack_cell_num--;
                    }
                    else if (is_64bit_type(*(loader_ctx.frame_ref - 1))) {
                        loader_ctx.frame_ref -= 2;
                        loader_ctx.stack_cell_num -= 2;
                        *(p - 1) = WASM_OP_DROP_64;
                    }
                    else {
                        set_error_buf(error_buf, error_buf_size,
                                      "type mismatch");
                        goto fail;
                    }
                }
                else {
                }
                break;
            }
            case WASM_OP_SELECT:
            {
                ubyte ref_type = void;
                BranchBlock* cur_block = loader_ctx.frame_csp - 1;
                int available_stack_cell = void;
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                available_stack_cell = cast(int)(loader_ctx.stack_cell_num
                                               - cur_block.stack_cell_num);
                if (available_stack_cell <= 0
                    && !cur_block.is_stack_polymorphic) {
                    set_error_buf(error_buf, error_buf_size,
                                  "type mismatch or invalid result arity, "
                                  ~ "opcode select was found "
                                  ~ "but stack was empty");
                    goto fail;
                }
                if (available_stack_cell > 0) {
                    switch (*(loader_ctx.frame_ref - 1)) {
                        case VALUE_TYPE_I32:
                        case VALUE_TYPE_F32:
                            break;
                        case VALUE_TYPE_I64:
                        case VALUE_TYPE_F64:
                            *(p - 1) = WASM_OP_SELECT_64;
                            break;
                        default:
                        {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }
                    }
                    ref_type = *(loader_ctx.frame_ref - 1);
                     if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, ref_type, ref_type, error_buf, error_buf_size))) goto fail;
                }
                else {
                     if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_ANY, error_buf, error_buf_size))) goto fail;
                }
                break;
            }
            case WASM_OP_GET_LOCAL:
            {
                p_org = p - 1;
                 read_leb_uint32(p, p_end, local_idx); if (local_idx >= param_count + local_count) { set_error_buf(error_buf, error_buf_size, "unknown local"); goto fail; } local_type = local_idx < param_count ? param_types[local_idx] : local_types[local_idx - param_count]; local_offset = local_offsets[local_idx];
                 if (!(wasm_loader_push_frame_ref(loader_ctx, local_type, error_buf, error_buf_size))) goto fail;
                break;
            }
            case WASM_OP_SET_LOCAL:
            {
                p_org = p - 1;
                 read_leb_uint32(p, p_end, local_idx); if (local_idx >= param_count + local_count) { set_error_buf(error_buf, error_buf_size, "unknown local"); goto fail; } local_type = local_idx < param_count ? param_types[local_idx] : local_types[local_idx - param_count]; local_offset = local_offsets[local_idx];
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, local_type, error_buf, error_buf_size))) goto fail;
                break;
            }
            case WASM_OP_TEE_LOCAL:
            {
                p_org = p - 1;
                 read_leb_uint32(p, p_end, local_idx); if (local_idx >= param_count + local_count) { set_error_buf(error_buf, error_buf_size, "unknown local"); goto fail; } local_type = local_idx < param_count ? param_types[local_idx] : local_types[local_idx - param_count]; local_offset = local_offsets[local_idx];
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, local_type, error_buf, error_buf_size))) goto fail;
                 if (!(wasm_loader_push_frame_ref(loader_ctx, local_type, error_buf, error_buf_size))) goto fail;
                break;
            }
            case WASM_OP_GET_GLOBAL:
            {
                p_org = p - 1;
                read_leb_uint32(p, p_end, global_idx);
                if (global_idx >= global_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    goto fail;
                }
                global_type =
                    global_idx < module_.import_global_count
                        ? module_.import_globals[global_idx].u.global.type
                        : module_
                              .globals[global_idx
                                        - module_.import_global_count]
                              .type;
                 if (!(wasm_loader_push_frame_ref(loader_ctx, global_type, error_buf, error_buf_size))) goto fail;
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    *p_org = WASM_OP_GET_GLOBAL_64;
                }
                break;
            }
            case WASM_OP_SET_GLOBAL:
            {
                bool is_mutable = false;
                p_org = p - 1;
                read_leb_uint32(p, p_end, global_idx);
                if (global_idx >= global_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    goto fail;
                }
                is_mutable =
                    global_idx < module_.import_global_count
                        ? module_.import_globals[global_idx].u.global.is_mutable
                        : module_
                              .globals[global_idx
                                        - module_.import_global_count]
                              .is_mutable;
                if (!is_mutable) {
                    set_error_buf(error_buf, error_buf_size,
                                  "global is immutable");
                    goto fail;
                }
                global_type =
                    global_idx < module_.import_global_count
                        ? module_.import_globals[global_idx].u.global.type
                        : module_
                              .globals[global_idx
                                        - module_.import_global_count]
                              .type;
                 if (!(wasm_loader_pop_frame_ref(loader_ctx, global_type, error_buf, error_buf_size))) goto fail;
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    *p_org = WASM_OP_SET_GLOBAL_64;
                }
                else if (module_.aux_stack_size > 0
                         && global_idx == module_.aux_stack_top_global_index) {
                    *p_org = WASM_OP_SET_GLOBAL_AUX_STACK;
                    func.has_op_set_global_aux_stack = true;
                }
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
                 if (!check_memory(module_, error_buf, error_buf_size)) goto fail;
                read_leb_uint32(p, p_end, align_); /* align */
                read_leb_uint32(p, p_end, mem_offset); /* offset */
                if (!check_memory_access_align(opcode, align_, error_buf,
                                               error_buf_size)) {
                    goto fail;
                }
                func.has_memory_operations = true;
                switch (opcode) {
                    /* load */
                    case WASM_OP_I32_LOAD:
                    case WASM_OP_I32_LOAD8_S:
                    case WASM_OP_I32_LOAD8_U:
                    case WASM_OP_I32_LOAD16_S:
                    case WASM_OP_I32_LOAD16_U:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_I64_LOAD:
                    case WASM_OP_I64_LOAD8_S:
                    case WASM_OP_I64_LOAD8_U:
                    case WASM_OP_I64_LOAD16_S:
                    case WASM_OP_I64_LOAD16_U:
                    case WASM_OP_I64_LOAD32_S:
                    case WASM_OP_I64_LOAD32_U:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_F32_LOAD:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_F64_LOAD:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F64, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    /* store */
                    case WASM_OP_I32_STORE:
                    case WASM_OP_I32_STORE8:
                    case WASM_OP_I32_STORE16:
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_I64_STORE:
                    case WASM_OP_I64_STORE8:
                    case WASM_OP_I64_STORE16:
                    case WASM_OP_I64_STORE32:
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_F32_STORE:
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_F64_STORE:
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                         if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                        break;
                    default:
                        break;
                }
                break;
            }
            case WASM_OP_MEMORY_SIZE:
                 if (!check_memory(module_, error_buf, error_buf_size)) goto fail;
                /* reserved byte 0x00 */
                if (*p++ != 0x00) {
                    set_error_buf(error_buf, error_buf_size,
                                  "zero byte expected");
                    goto fail;
                }
                 if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                module_.possible_memory_grow = true;
                func.has_memory_operations = true;
                break;
            case WASM_OP_MEMORY_GROW:
                 if (!check_memory(module_, error_buf, error_buf_size)) goto fail;
                /* reserved byte 0x00 */
                if (*p++ != 0x00) {
                    set_error_buf(error_buf, error_buf_size,
                                  "zero byte expected");
                    goto fail;
                }
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                module_.possible_memory_grow = true;
                func.has_op_memory_grow = true;
                func.has_memory_operations = true;
                break;
            case WASM_OP_I32_CONST:
                read_leb_int32(p, p_end, i32_const);
                cast(void)i32_const;
                 if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_CONST:
                read_leb_int64(p, p_end, i64_const);
                 if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_CONST:
                p += float.sizeof;
                 if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_CONST:
                p += double.sizeof;
                 if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_EQZ:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
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
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_EQZ:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
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
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_I32, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_I32, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_I32, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
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
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
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
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_I64, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F32, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_F32, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F64, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, VALUE_TYPE_F64, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_WRAP_I64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F32, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_DEMOTE_F64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F32, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F64, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F64, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_PROMOTE_F32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F64, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_REINTERPRET_F32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_REINTERPRET_F64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F32_REINTERPRET_I32:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_F64_REINTERPRET_I64:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_F64, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_I32, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                 if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_I64, error_buf, error_buf_size))) goto fail;
                break;
            case WASM_OP_MISC_PREFIX:
            {
                uint opcode1 = void;
                read_leb_uint32(p, p_end, opcode1);
                switch (opcode1) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I32, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_F32, error_buf, error_buf_size))) goto fail;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                         if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, VALUE_TYPE_I64, VALUE_TYPE_F64, error_buf, error_buf_size))) goto fail;
                        break;
                    default:
                        set_error_buf_v(error_buf, error_buf_size,
                                        "%s %02x %02x", "unsupported opcode",
                                        0xfc, opcode1);
                        goto fail;
                }
                break;
            }
            default:
                set_error_buf_v(error_buf, error_buf_size, "%s %02x",
                                "unsupported opcode", opcode);
                goto fail;
        }
    }
    if (loader_ctx.csp_num > 0) {
        if (cur_func_idx < module_.function_count - 1)
            /* Function with missing end marker (between two functions) */
            set_error_buf(error_buf, error_buf_size, "END opcode expected");
        else
            /* Function with missing end marker
               (at EOF or end of code sections) */
            set_error_buf(error_buf, error_buf_size,
                          "unexpected end of section or function, "
                          ~ "or section size mismatch");
        goto fail;
    }
    func.max_stack_cell_num = loader_ctx.max_stack_cell_num;
    func.max_block_num = loader_ctx.max_csp_num;
    return_value = true;
fail:
    wasm_loader_ctx_destroy(loader_ctx);
    cast(void)table_idx;
    cast(void)table_seg_idx;
    cast(void)data_seg_idx;
    cast(void)i64_const;
    cast(void)local_offset;
    cast(void)p_org;
    cast(void)mem_offset;
    cast(void)align_;
    return return_value;
}
