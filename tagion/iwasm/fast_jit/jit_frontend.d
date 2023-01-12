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
module tagion.iwasm.fast_jit.jit_frontend;
@nogc nothrow:
extern (C):
__gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import std.traits : isIntegral;
import tagion.iwasm.basic;
import tagion.iwasm.app_framework.base.app.bh_platform : bh_memcpy_s;
import tagion.iwasm.fast_jit.jit_compiler;
import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_utils;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_frame;
import tagion.iwasm.fast_jit.fe.jit_emit_compare;
import tagion.iwasm.fast_jit.fe.jit_emit_const;
import tagion.iwasm.fast_jit.fe.jit_emit_control;
import tagion.iwasm.fast_jit.fe.jit_emit_conversion;
import tagion.iwasm.fast_jit.fe.jit_emit_exception;
import tagion.iwasm.fast_jit.fe.jit_emit_function;
import tagion.iwasm.fast_jit.fe.jit_emit_memory;
import tagion.iwasm.fast_jit.fe.jit_emit_numberic;
import tagion.iwasm.fast_jit.fe.jit_emit_parametric;
import tagion.iwasm.fast_jit.fe.jit_emit_table;
import tagion.iwasm.fast_jit.fe.jit_emit_variable;
import tagion.iwasm.interpreter.wasm_interp;
import tagion.iwasm.interpreter.wasm_opcode;
import tagion.iwasm.interpreter.wasm_runtime;
import tagion.iwasm.interpreter.wasm : LabelType;
import tagion.iwasm.common.wasm_exec_env;
import tagion.iwasm.share.utils.bh_list;
//import tagion.iwasm.share.utils.bh_assert;

private uint get_global_base_offset(const(WASMModule)* module_) {
    uint module_inst_struct_size = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof;
    uint mem_inst_size = cast(uint) WASMMemoryInstance.sizeof
        * (module_.import_memory_count + module_.memory_count);
    static if (ver.WASM_ENABLE_JIT) {
        /* If the module dosen't have memory, reserve one mem_info space
       with empty content to align with llvm jit compiler */
        if (mem_inst_size == 0)
            mem_inst_size = cast(uint) WASMMemoryInstance.sizeof;
    }
    /* Size of module inst and memory instances */
    return module_inst_struct_size + mem_inst_size;
}

private uint get_first_table_inst_offset(const(WASMModule)* module_) {
    return get_global_base_offset(module_) + module_.global_data_size;
}

uint jit_frontend_get_global_data_offset(const(WASMModule)* module_, uint global_idx) {
    uint global_base_offset = get_global_base_offset(module_);
    if (global_idx < module_.import_global_count) {
        const(WASMGlobalImport)* import_global = &((module_.import_globals + global_idx).u.global);
        return global_base_offset + import_global.data_offset;
    }
    else {
        const(WASMGlobal)* global = module_.globals + (global_idx - module_.import_global_count);
        return global_base_offset + global.data_offset;
    }
}

uint jit_frontend_get_table_inst_offset(const(WASMModule)* module_, uint tbl_idx) {
    uint offset = void, i = 0;
    offset = get_first_table_inst_offset(module_);
    while (i < tbl_idx && i < module_.import_table_count) {
        const import_table = &module_.import_tables[i].u.table;
        offset += cast(uint) WASMTableInstance.elems.offsetof;
        static if (ver.WASM_ENABLE_MULTI_MODULE) {
            offset += cast(uint) uint.sizeof * import_table.max_size;
        }
        else {
            offset += cast(uint) uint.sizeof
                * (import_table.possible_grow ? import_table.max_size : import_table.init_size);
        }
        i++;
    }
    if (i == tbl_idx) {
        return offset;
    }
    tbl_idx -= module_.import_table_count;
    i -= module_.import_table_count;
    while (i < tbl_idx && i < module_.table_count) {
        const table = module_.tables + i;
        offset += cast(uint) WASMTableInstance.elems.offsetof;
        static if (ver.WASM_ENABLE_MULTI_MODULE) {
            offset += cast(uint) uint.sizeof * table.max_size;
        }
        else {
            offset += cast(uint) uint.sizeof
                * (table.possible_grow ? table.max_size : table.init_size);
        }
        i++;
    }
    return offset;
}

uint jit_frontend_get_module_inst_extra_offset(const(WASMModule)* module_) {
    uint offset = jit_frontend_get_table_inst_offset(
            module_, module_.import_table_count + module_.table_count);
    return align_uint(offset, 8);
}

private void free_block_memory(JitBlock* block) {
    if (block.param_types)
        jit_free(block.param_types);
    if (block.result_types)
        jit_free(block.result_types);
    jit_free(block);
}
enum string CHECK_BUF(string buf, string buf_end, string length) = ` do { if (buf + length > buf_end) { jit_set_last_error(cc, "read leb failed: unexpected end."); return false; } } while (0)`;

bool check_buf(JitCompContext* cc, scope const(void*) buf, scope const(void*) end, const size_t size) {
	if ((buf + size) > end) {
	jit_set_last_error(cc, "read led failed: unexpetced end.");
		return false;
	}
	return true;
}
private bool read_leb(JitCompContext* cc, scope const(ubyte)* buf, scope const(ubyte)* buf_end, uint* p_offset, uint maxbits, bool sign, ulong* p_result) {
    ulong result = 0;
    uint shift = 0;
    uint bcnt = 0;
    ulong byte_ = void;
    while (true) {
		if (check_buf(cc, buf, buf_end, 1)) return false;
//        CHECK_BUF(buf, buf_end, 1);
        byte_ = buf[*p_offset];
        *p_offset += 1;
        result |= ((byte_ & 0x7f) << shift);
        shift += 7;
        if ((byte_ & 0x80) == 0) {
            break;
        }
        bcnt += 1;
    }
    if (bcnt > (maxbits + 6) / 7) {
        jit_set_last_error(cc, "read leb failed: "
                ~ "integer representation too long");
        return false;
    }
    if (sign && (shift < maxbits) && (byte_ & 0x40)) {
        /* Sign extend */
        result |= (~(cast(ulong) 0)) << shift;
    }
    *p_result = result;
    return true;
}

bool read_lebT(T)(JitCompContext* cc, ref const(ubyte)* p, scope const(ubyte*) p_end, ref T res)  if (isIntegral!T) { 
	uint off; 
	ulong res64;
	enum max_bits=T.sizeof * 8;
if (!read_leb(cc, p, p_end, &off, max_bits, false, &res64))  {
		return false; 
		p += off; 
		res = cast(T)res64; 
	}
	return true;
}

version(none) {
enum string read_leb_int32(cc, string p, string p_end, string res) = ` do { uint off = 0; ulong res64; if (!read_leb(cc, p, p_end, &off, 32, true, &res64)) return false; p += off; res = (int32)res64; } while (0)`;
enum string read_leb_int64(cc, string p, string p_end, string res) = ` do { uint off = 0; ulong res64; if (!read_leb(cc, p, p_end, &off, 64, true, &res64)) return false; p += off; res = (int64)res64; } while (0)`;
}

private bool jit_compile_func(JitCompContext* cc) {
    WASMFunction* cur_func = cc.cur_wasm_func;
    WASMType* func_type = null;
    const(ubyte)* frame_ip = cur_func.code;
    ubyte opcode = void;
    ubyte* p_f32 = void, p_f64 = void;
    const(ubyte)* frame_ip_end = frame_ip + cur_func.code_size;
    ValueType* param_types = null, result_types = null;
    ValueType value_type = void;
    ushort param_count = void, result_count = void;
    uint br_depth = void;
    uint* br_depths = void;
    uint br_count = void;
    uint func_idx = void, type_idx = void, mem_idx = void, local_idx = void, global_idx = void, i = void;
    uint bytes = 4, align_ = void, offset = void;
    bool merge_cmp_and_if = false, merge_cmp_and_br_if = false;
    bool sign = true;
    int i32_const = void;
    long i64_const = void;
    float f32_const = void;
    double f64_const = void;
    while (frame_ip < frame_ip_end) {
        cc.jit_frame.ip = frame_ip;
        opcode = *frame_ip++;
        version (none) { /* TODO */
            static if (ver.WASM_ENABLE_THREAD_MGR) {
                /* Insert suspend check point */
                if (cc.enable_thread_mgr) {
                    if (!check_suspend_flags(cc, func_ctx))
                        return false;
                }
            }
        }
        switch (opcode) {
        case WASM_OP_UNREACHABLE:
            if (!jit_compile_op_unreachable(cc, &frame_ip))
                return false;
            break;
        case WASM_OP_NOP:
            break;
        case WASM_OP_BLOCK:
        case WASM_OP_LOOP:
        case WASM_OP_IF: {
                value_type = cast(ValueType)(*frame_ip++);
                if (value_type == VALUE_TYPE_I32 || value_type == VALUE_TYPE_I64
                        || value_type == VALUE_TYPE_F32
                        || value_type == VALUE_TYPE_F64
                        || value_type == VALUE_TYPE_V128
                        || value_type == VALUE_TYPE_VOID
                        || value_type == VALUE_TYPE_FUNCREF
                        || value_type == VALUE_TYPE_EXTERNREF) {
                    param_count = 0;
                    param_types = null;
                    if (value_type == VALUE_TYPE_VOID) {
                        result_count = 0;
                        result_types = null;
                    }
                    else {
                        result_count = 1;
                        result_types = &value_type;
                    }
                }
                else {
                    jit_set_last_error(cc, "unsupported value type");
                    return false;
                }
                if (!jit_compile_op_block(
                        cc, &frame_ip, frame_ip_end,
                        cast(uint)(LabelType.BLOCK + opcode - WASM_OP_BLOCK),
                        param_count, param_types, result_count, result_types,
                        merge_cmp_and_if))
                    return false;
                /* Clear flag */
                merge_cmp_and_if = false;
                break;
            }
        case EXT_OP_BLOCK:
        case EXT_OP_LOOP:
        case EXT_OP_IF: {
                read_lebT!uint(cc, frame_ip, frame_ip_end, type_idx);
                func_type = cc.cur_wasm_module.types[type_idx];
                param_count = func_type.param_count;
                param_types = func_type.types.ptr;
                result_count = func_type.result_count;
                result_types = func_type.types.ptr + param_count;
                if (!jit_compile_op_block(
                        cc, &frame_ip, frame_ip_end,
                        cast(uint)(LabelType.BLOCK + opcode - EXT_OP_BLOCK),
                        param_count, param_types, result_count, result_types,
                        merge_cmp_and_if))
                    return false;
                /* Clear flag */
                merge_cmp_and_if = false;
                break;
            }
        case WASM_OP_ELSE:
            if (!jit_compile_op_else(cc, &frame_ip))
                return false;
            break;
        case WASM_OP_END:
            if (!jit_compile_op_end(cc, &frame_ip))
                return false;
            break;
        case WASM_OP_BR:
            read_lebT!uint(cc, frame_ip, frame_ip_end, br_depth);
            if (!jit_compile_op_br(cc, br_depth, &frame_ip))
                return false;
            break;
        case WASM_OP_BR_IF:
            read_lebT!uint(cc, frame_ip, frame_ip_end, br_depth);
            if (!jit_compile_op_br_if(cc, br_depth, merge_cmp_and_br_if,
                    &frame_ip))
                return false;
            /* Clear flag */
            merge_cmp_and_br_if = false;
            break;
        case WASM_OP_BR_TABLE:
            read_lebT!uint(cc, frame_ip, frame_ip_end, br_count);
            if ((br_depths = jit_calloc_reg( uint.sizeof
                    * (br_count + 1))) is null) {
                jit_set_last_error(cc, "allocate memory failed.");
                goto fail;
            }
            static if (ver.WASM_ENABLE_FAST_INTERP) {
                for (i = 0; i <= br_count; i++)
                    read_lebT!uint(cc, frame_ip, frame_ip_end, br_depths[i]);
            }
            else {
                for (i = 0; i <= br_count; i++)
                    br_depths[i] = *frame_ip++;
            }
            if (!jit_compile_op_br_table(cc, br_depths, br_count,
                    &frame_ip)) {
                jit_free(br_depths);
                return false;
            }
            jit_free(br_depths);
            break;
            //static if (!ver.WASM_ENABLE_FAST_INTERP) {
        case EXT_OP_BR_TABLE_CACHE: {
                    BrTableCache* node = bh_list_first_elemT!BrTableCache(
                            cc.cur_wasm_module.br_table_cache_list);
                    BrTableCache* node_next = void;
                    const(ubyte)* p_opcode = frame_ip - 1;
                    read_lebT!uint(cc, frame_ip, frame_ip_end, br_count);
                    while (node) {
                        node_next = bh_list_elem_nextT!(BrTableCache)(node);
                        if (node.br_table_op_addr == p_opcode) {
                            br_depths = node.br_depths.ptr;
                            if (!jit_compile_op_br_table(cc, br_depths, br_count,
                                    &frame_ip)) {
                                return false;
                            }
                            break;
                        }
                        node = node_next;
                    }
                    bh_assert(node !is null);
                    break;
                }
            //}
        case WASM_OP_RETURN:
            if (!jit_compile_op_return(cc, &frame_ip))
                return false;
            break;
        case WASM_OP_CALL:
            read_lebT!uint(cc, frame_ip, frame_ip_end, func_idx);
            if (!jit_compile_op_call(cc, func_idx, false))
                return false;
            break;
        case WASM_OP_CALL_INDIRECT: {
                uint tbl_idx = void;
                read_lebT!uint(cc, frame_ip, frame_ip_end, type_idx);
                static if (ver.WASM_ENABLE_REF_TYPES) {
                    read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                }
                else {
                    frame_ip++;
                    tbl_idx = 0;
                }
                if (!jit_compile_op_call_indirect(cc, type_idx, tbl_idx))
                    return false;
                break;
            }
            static if (ver.WASM_ENABLE_TAIL_CALL) {
        case WASM_OP_RETURN_CALL:
                read_lebT!uint(cc, frame_ip, frame_ip_end, func_idx);
                if (!jit_compile_op_call(cc, func_idx, true))
                    return false;
                if (!jit_compile_op_return(cc, &frame_ip))
                    return false;
                break;
        case WASM_OP_RETURN_CALL_INDIRECT: {
                    uint tbl_idx = void;
                    read_lebT!uint(cc, frame_ip, frame_ip_end, type_idx);
                    static if (ver.WASM_ENABLE_REF_TYPES) {
                        read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                    }
                    else {
                        frame_ip++;
                        tbl_idx = 0;
                    }
                    if (!jit_compile_op_call_indirect(cc, type_idx, tbl_idx))
                        return false;
                    if (!jit_compile_op_return(cc, &frame_ip))
                        return false;
                    break;
                }
            } /* end of WASM_ENABLE_TAIL_CALL */
        case WASM_OP_DROP:
            if (!jit_compile_op_drop(cc, true))
                return false;
            break;
        case WASM_OP_DROP_64:
            if (!jit_compile_op_drop(cc, false))
                return false;
            break;
        case WASM_OP_SELECT:
            if (!jit_compile_op_select(cc, true))
                return false;
            break;
        case WASM_OP_SELECT_64:
            if (!jit_compile_op_select(cc, false))
                return false;
            break;
            static if (ver.WASM_ENABLE_REF_TYPES) {
        case WASM_OP_SELECT_T: {
                    uint vec_len = void;
                    read_lebT!uint(cc, frame_ip, frame_ip_end, vec_len);
                    bh_assert(vec_len == 1);
                    cast(void) vec_len;
                    type_idx = *frame_ip++;
                    if (!jit_compile_op_select(cc,
                            (type_idx != VALUE_TYPE_I64)
                            && (type_idx != VALUE_TYPE_F64)))
                        return false;
                    break;
                }
        case WASM_OP_TABLE_GET: {
                    uint tbl_idx = void;
                    read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                    if (!jit_compile_op_table_get(cc, tbl_idx))
                        return false;
                    break;
                }
        case WASM_OP_TABLE_SET: {
                    uint tbl_idx = void;
                    read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                    if (!jit_compile_op_table_set(cc, tbl_idx))
                        return false;
                    break;
                }
        case WASM_OP_REF_NULL: {
                    uint ref_type = void;
                    read_lebT!uint(cc, frame_ip, frame_ip_end, ref_type);
                    if (!jit_compile_op_ref_null(cc, ref_type))
                        return false;
                    break;
                }
        case WASM_OP_REF_IS_NULL: {
                    if (!jit_compile_op_ref_is_null(cc))
                        return false;
                    break;
                }
        case WASM_OP_REF_FUNC: {
                    read_lebT!uint(cc, frame_ip, frame_ip_end, func_idx);
                    if (!jit_compile_op_ref_func(cc, func_idx))
                        return false;
                    break;
                }
            }
        case WASM_OP_GET_LOCAL:
            read_lebT!uint(cc, frame_ip, frame_ip_end, local_idx);
            if (!jit_compile_op_get_local(cc, local_idx))
                return false;
            break;
        case WASM_OP_SET_LOCAL:
            read_lebT!uint(cc, frame_ip, frame_ip_end, local_idx);
            if (!jit_compile_op_set_local(cc, local_idx))
                return false;
            break;
        case WASM_OP_TEE_LOCAL:
            read_lebT!uint(cc, frame_ip, frame_ip_end, local_idx);
            if (!jit_compile_op_tee_local(cc, local_idx))
                return false;
            break;
        case WASM_OP_GET_GLOBAL:
        case WASM_OP_GET_GLOBAL_64:
            read_lebT!uint(cc, frame_ip, frame_ip_end, global_idx);
            if (!jit_compile_op_get_global(cc, global_idx))
                return false;
            break;
        case WASM_OP_SET_GLOBAL:
        case WASM_OP_SET_GLOBAL_64:
        case WASM_OP_SET_GLOBAL_AUX_STACK:
            read_lebT!uint(cc, frame_ip, frame_ip_end, global_idx);
            if (!jit_compile_op_set_global(
                    cc, global_idx,
                    opcode == WASM_OP_SET_GLOBAL_AUX_STACK ? true : false))
                return false;
            break;
        case WASM_OP_I32_LOAD:
            bytes = 4;
            sign = true;
            goto op_i32_load;
        case WASM_OP_I32_LOAD8_S:
        case WASM_OP_I32_LOAD8_U:
            bytes = 1;
            sign = (opcode == WASM_OP_I32_LOAD8_S) ? true : false;
            goto op_i32_load;
        case WASM_OP_I32_LOAD16_S:
        case WASM_OP_I32_LOAD16_U:
            bytes = 2;
            sign = (opcode == WASM_OP_I32_LOAD16_S) ? true : false;
        op_i32_load:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_i32_load(cc, align_, offset, bytes, sign,
                    false))
                return false;
            break;
        case WASM_OP_I64_LOAD:
            bytes = 8;
            sign = true;
            goto op_i64_load;
        case WASM_OP_I64_LOAD8_S:
        case WASM_OP_I64_LOAD8_U:
            bytes = 1;
            sign = (opcode == WASM_OP_I64_LOAD8_S) ? true : false;
            goto op_i64_load;
        case WASM_OP_I64_LOAD16_S:
        case WASM_OP_I64_LOAD16_U:
            bytes = 2;
            sign = (opcode == WASM_OP_I64_LOAD16_S) ? true : false;
            goto op_i64_load;
        case WASM_OP_I64_LOAD32_S:
        case WASM_OP_I64_LOAD32_U:
            bytes = 4;
            sign = (opcode == WASM_OP_I64_LOAD32_S) ? true : false;
        op_i64_load:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_i64_load(cc, align_, offset, bytes, sign,
                    false))
                return false;
            break;
        case WASM_OP_F32_LOAD:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_f32_load(cc, align_, offset))
                return false;
            break;
        case WASM_OP_F64_LOAD:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_f64_load(cc, align_, offset))
                return false;
            break;
        case WASM_OP_I32_STORE:
            bytes = 4;
            goto op_i32_store;
        case WASM_OP_I32_STORE8:
            bytes = 1;
            goto op_i32_store;
        case WASM_OP_I32_STORE16:
            bytes = 2;
        op_i32_store:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_i32_store(cc, align_, offset, bytes, false))
                return false;
            break;
        case WASM_OP_I64_STORE:
            bytes = 8;
            goto op_i64_store;
        case WASM_OP_I64_STORE8:
            bytes = 1;
            goto op_i64_store;
        case WASM_OP_I64_STORE16:
            bytes = 2;
            goto op_i64_store;
        case WASM_OP_I64_STORE32:
            bytes = 4;
        op_i64_store:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_i64_store(cc, align_, offset, bytes, false))
                return false;
            break;
        case WASM_OP_F32_STORE:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_f32_store(cc, align_, offset))
                return false;
            break;
        case WASM_OP_F64_STORE:
            read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
            read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
            if (!jit_compile_op_f64_store(cc, align_, offset))
                return false;
            break;
        case WASM_OP_MEMORY_SIZE:
            read_lebT!uint(cc, frame_ip, frame_ip_end, mem_idx);
            if (!jit_compile_op_memory_size(cc, mem_idx))
                return false;
            break;
        case WASM_OP_MEMORY_GROW:
            read_lebT!uint(cc, frame_ip, frame_ip_end, mem_idx);
            if (!jit_compile_op_memory_grow(cc, mem_idx))
                return false;
            break;
        case WASM_OP_I32_CONST:
            read_lebT!int32(cc, frame_ip, frame_ip_end, i32_const);
            if (!jit_compile_op_i32_const(cc, i32_const))
                return false;
            break;
        case WASM_OP_I64_CONST:
            read_lebT!long(cc, frame_ip, frame_ip_end, i64_const);
            if (!jit_compile_op_i64_const(cc, i64_const))
                return false;
            break;
        case WASM_OP_F32_CONST:
            p_f32 = cast(ubyte*)&f32_const;
            for (i = 0; i < float.sizeof; i++)
                *p_f32++ = *frame_ip++;
            if (!jit_compile_op_f32_const(cc, f32_const))
                return false;
            break;
        case WASM_OP_F64_CONST:
            p_f64 = cast(ubyte*)&f64_const;
            for (i = 0; i < double.sizeof; i++)
                *p_f64++ = *frame_ip++;
            if (!jit_compile_op_f64_const(cc, f64_const))
                return false;
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
            if (!jit_compile_op_i32_compare(cc, cast(IntCond)(INT_EQZ + opcode
                    - WASM_OP_I32_EQZ)))
                return false;
            if (frame_ip < frame_ip_end) {
                /* Merge `CMP, SELECTcc, CMP, BNE` insns into `CMP, Bcc` */
                if (*frame_ip == WASM_OP_IF || *frame_ip == EXT_OP_IF)
                    merge_cmp_and_if = true;
                if (*frame_ip == WASM_OP_BR_IF)
                    merge_cmp_and_br_if = true;
            }
            break;
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
            if (!jit_compile_op_i64_compare(cc, cast(IntCond)(INT_EQZ + opcode
                    - WASM_OP_I64_EQZ)))
                return false;
            if (frame_ip < frame_ip_end) {
                /* Merge `CMP, SELECTcc, CMP, BNE` insns into `CMP, Bcc` */
                if (*frame_ip == WASM_OP_IF || *frame_ip == EXT_OP_IF)
                    merge_cmp_and_if = true;
                if (*frame_ip == WASM_OP_BR_IF)
                    merge_cmp_and_br_if = true;
            }
            break;
        case WASM_OP_F32_EQ:
        case WASM_OP_F32_NE:
        case WASM_OP_F32_LT:
        case WASM_OP_F32_GT:
        case WASM_OP_F32_LE:
        case WASM_OP_F32_GE:
            if (!jit_compile_op_f32_compare(cc, cast(FloatCond)(FLOAT_EQ + opcode
                    - WASM_OP_F32_EQ)))
                return false;
            if (frame_ip < frame_ip_end) {
                /* Merge `CMP, SELECTcc, CMP, BNE` insns into `CMP, Bcc` */
                if (*frame_ip == WASM_OP_IF || *frame_ip == EXT_OP_IF)
                    merge_cmp_and_if = true;
                if (*frame_ip == WASM_OP_BR_IF)
                    merge_cmp_and_br_if = true;
            }
            break;
        case WASM_OP_F64_EQ:
        case WASM_OP_F64_NE:
        case WASM_OP_F64_LT:
        case WASM_OP_F64_GT:
        case WASM_OP_F64_LE:
        case WASM_OP_F64_GE:
            if (!jit_compile_op_f64_compare(cc, cast(FloatCond)(FLOAT_EQ + opcode
                    - WASM_OP_F64_EQ)))
                return false;
            if (frame_ip < frame_ip_end) {
                /* Merge `CMP, SELECTcc, CMP, BNE` insns into `CMP, Bcc` */
                if (*frame_ip == WASM_OP_IF || *frame_ip == EXT_OP_IF)
                    merge_cmp_and_if = true;
                if (*frame_ip == WASM_OP_BR_IF)
                    merge_cmp_and_br_if = true;
            }
            break;
        case WASM_OP_I32_CLZ:
            if (!jit_compile_op_i32_clz(cc))
                return false;
            break;
        case WASM_OP_I32_CTZ:
            if (!jit_compile_op_i32_ctz(cc))
                return false;
            break;
        case WASM_OP_I32_POPCNT:
            if (!jit_compile_op_i32_popcnt(cc))
                return false;
            break;
        case WASM_OP_I32_ADD:
        case WASM_OP_I32_SUB:
        case WASM_OP_I32_MUL:
        case WASM_OP_I32_DIV_S:
        case WASM_OP_I32_DIV_U:
        case WASM_OP_I32_REM_S:
        case WASM_OP_I32_REM_U:
            if (!jit_compile_op_i32_arithmetic(
                    cc, cast(IntArithmetic)(INT_ADD + opcode - WASM_OP_I32_ADD), &frame_ip))
                return false;
            break;
        case WASM_OP_I32_AND:
        case WASM_OP_I32_OR:
        case WASM_OP_I32_XOR:
            if (!jit_compile_op_i32_bitwise(cc, cast(IntBitwise)(INT_SHL + opcode
                    - WASM_OP_I32_AND)))
                return false;
            break;
        case WASM_OP_I32_SHL:
        case WASM_OP_I32_SHR_S:
        case WASM_OP_I32_SHR_U:
        case WASM_OP_I32_ROTL:
        case WASM_OP_I32_ROTR:
            if (!jit_compile_op_i32_shift(cc, cast(IntShift)(INT_SHL + opcode
                    - WASM_OP_I32_SHL)))
                return false;
            break;
        case WASM_OP_I64_CLZ:
            if (!jit_compile_op_i64_clz(cc))
                return false;
            break;
        case WASM_OP_I64_CTZ:
            if (!jit_compile_op_i64_ctz(cc))
                return false;
            break;
        case WASM_OP_I64_POPCNT:
            if (!jit_compile_op_i64_popcnt(cc))
                return false;
            break;
        case WASM_OP_I64_ADD:
        case WASM_OP_I64_SUB:
        case WASM_OP_I64_MUL:
        case WASM_OP_I64_DIV_S:
        case WASM_OP_I64_DIV_U:
        case WASM_OP_I64_REM_S:
        case WASM_OP_I64_REM_U:
            if (!jit_compile_op_i64_arithmetic(
                    cc, cast(IntArithmetic)(INT_ADD + opcode - WASM_OP_I64_ADD), &frame_ip))
                return false;
            break;
        case WASM_OP_I64_AND:
        case WASM_OP_I64_OR:
        case WASM_OP_I64_XOR:
            if (!jit_compile_op_i64_bitwise(cc, cast(IntBitwise)(INT_SHL + opcode
                    - WASM_OP_I64_AND)))
                return false;
            break;
        case WASM_OP_I64_SHL:
        case WASM_OP_I64_SHR_S:
        case WASM_OP_I64_SHR_U:
        case WASM_OP_I64_ROTL:
        case WASM_OP_I64_ROTR:
            if (!jit_compile_op_i64_shift(cc, cast(IntShift)(INT_SHL + opcode
                    - WASM_OP_I64_SHL)))
                return false;
            break;
        case WASM_OP_F32_ABS:
        case WASM_OP_F32_NEG:
        case WASM_OP_F32_CEIL:
        case WASM_OP_F32_FLOOR:
        case WASM_OP_F32_TRUNC:
        case WASM_OP_F32_NEAREST:
        case WASM_OP_F32_SQRT:
            if (!jit_compile_op_f32_math(cc, cast(FloatMath)(FLOAT_ABS + opcode
                    - WASM_OP_F32_ABS)))
                return false;
            break;
        case WASM_OP_F32_ADD:
        case WASM_OP_F32_SUB:
        case WASM_OP_F32_MUL:
        case WASM_OP_F32_DIV:
        case WASM_OP_F32_MIN:
        case WASM_OP_F32_MAX:
            if (!jit_compile_op_f32_arithmetic(cc, cast(FloatArithmetic)(FLOAT_ADD + opcode
                    - WASM_OP_F32_ADD)))
                return false;
            break;
        case WASM_OP_F32_COPYSIGN:
            if (!jit_compile_op_f32_copysign(cc))
                return false;
            break;
        case WASM_OP_F64_ABS:
        case WASM_OP_F64_NEG:
        case WASM_OP_F64_CEIL:
        case WASM_OP_F64_FLOOR:
        case WASM_OP_F64_TRUNC:
        case WASM_OP_F64_NEAREST:
        case WASM_OP_F64_SQRT:
            if (!jit_compile_op_f64_math(cc, cast(FloatMath)(FLOAT_ABS + opcode
                    - WASM_OP_F64_ABS)))
                return false;
            break;
        case WASM_OP_F64_ADD:
        case WASM_OP_F64_SUB:
        case WASM_OP_F64_MUL:
        case WASM_OP_F64_DIV:
        case WASM_OP_F64_MIN:
        case WASM_OP_F64_MAX:
            if (!jit_compile_op_f64_arithmetic(cc, cast(FloatArithmetic)(FLOAT_ADD + opcode
                    - WASM_OP_F64_ADD)))
                return false;
            break;
        case WASM_OP_F64_COPYSIGN:
            if (!jit_compile_op_f64_copysign(cc))
                return false;
            break;
        case WASM_OP_I32_WRAP_I64:
            if (!jit_compile_op_i32_wrap_i64(cc))
                return false;
            break;
        case WASM_OP_I32_TRUNC_S_F32:
        case WASM_OP_I32_TRUNC_U_F32:
            sign = (opcode == WASM_OP_I32_TRUNC_S_F32) ? true : false;
            if (!jit_compile_op_i32_trunc_f32(cc, sign, false))
                return false;
            break;
        case WASM_OP_I32_TRUNC_S_F64:
        case WASM_OP_I32_TRUNC_U_F64:
            sign = (opcode == WASM_OP_I32_TRUNC_S_F64) ? true : false;
            if (!jit_compile_op_i32_trunc_f64(cc, sign, false))
                return false;
            break;
        case WASM_OP_I64_EXTEND_S_I32:
        case WASM_OP_I64_EXTEND_U_I32:
            sign = (opcode == WASM_OP_I64_EXTEND_S_I32) ? true : false;
            if (!jit_compile_op_i64_extend_i32(cc, sign))
                return false;
            break;
        case WASM_OP_I64_TRUNC_S_F32:
        case WASM_OP_I64_TRUNC_U_F32:
            sign = (opcode == WASM_OP_I64_TRUNC_S_F32) ? true : false;
            if (!jit_compile_op_i64_trunc_f32(cc, sign, false))
                return false;
            break;
        case WASM_OP_I64_TRUNC_S_F64:
        case WASM_OP_I64_TRUNC_U_F64:
            sign = (opcode == WASM_OP_I64_TRUNC_S_F64) ? true : false;
            if (!jit_compile_op_i64_trunc_f64(cc, sign, false))
                return false;
            break;
        case WASM_OP_F32_CONVERT_S_I32:
        case WASM_OP_F32_CONVERT_U_I32:
            sign = (opcode == WASM_OP_F32_CONVERT_S_I32) ? true : false;
            if (!jit_compile_op_f32_convert_i32(cc, sign))
                return false;
            break;
        case WASM_OP_F32_CONVERT_S_I64:
        case WASM_OP_F32_CONVERT_U_I64:
            sign = (opcode == WASM_OP_F32_CONVERT_S_I64) ? true : false;
            if (!jit_compile_op_f32_convert_i64(cc, sign))
                return false;
            break;
        case WASM_OP_F32_DEMOTE_F64:
            if (!jit_compile_op_f32_demote_f64(cc))
                return false;
            break;
        case WASM_OP_F64_CONVERT_S_I32:
        case WASM_OP_F64_CONVERT_U_I32:
            sign = (opcode == WASM_OP_F64_CONVERT_S_I32) ? true : false;
            if (!jit_compile_op_f64_convert_i32(cc, sign))
                return false;
            break;
        case WASM_OP_F64_CONVERT_S_I64:
        case WASM_OP_F64_CONVERT_U_I64:
            sign = (opcode == WASM_OP_F64_CONVERT_S_I64) ? true : false;
            if (!jit_compile_op_f64_convert_i64(cc, sign))
                return false;
            break;
        case WASM_OP_F64_PROMOTE_F32:
            if (!jit_compile_op_f64_promote_f32(cc))
                return false;
            break;
        case WASM_OP_I32_REINTERPRET_F32:
            if (!jit_compile_op_i32_reinterpret_f32(cc))
                return false;
            break;
        case WASM_OP_I64_REINTERPRET_F64:
            if (!jit_compile_op_i64_reinterpret_f64(cc))
                return false;
            break;
        case WASM_OP_F32_REINTERPRET_I32:
            if (!jit_compile_op_f32_reinterpret_i32(cc))
                return false;
            break;
        case WASM_OP_F64_REINTERPRET_I64:
            if (!jit_compile_op_f64_reinterpret_i64(cc))
                return false;
            break;
        case WASM_OP_I32_EXTEND8_S:
            if (!jit_compile_op_i32_extend_i32(cc, 8))
                return false;
            break;
        case WASM_OP_I32_EXTEND16_S:
            if (!jit_compile_op_i32_extend_i32(cc, 16))
                return false;
            break;
        case WASM_OP_I64_EXTEND8_S:
            if (!jit_compile_op_i64_extend_i64(cc, 8))
                return false;
            break;
        case WASM_OP_I64_EXTEND16_S:
            if (!jit_compile_op_i64_extend_i64(cc, 16))
                return false;
            break;
        case WASM_OP_I64_EXTEND32_S:
            if (!jit_compile_op_i64_extend_i64(cc, 32))
                return false;
            break;
        case WASM_OP_MISC_PREFIX: {
                uint opcode1 = void;
                read_lebT!uint(cc, frame_ip, frame_ip_end, opcode1);
                opcode = cast(ubyte) opcode1;
                switch (opcode) {
                case WASM_OP_I32_TRUNC_SAT_S_F32:
                case WASM_OP_I32_TRUNC_SAT_U_F32:
                    sign = (opcode == WASM_OP_I32_TRUNC_SAT_S_F32) ? true : false;
                    if (!jit_compile_op_i32_trunc_f32(cc, sign, true))
                        return false;
                    break;
                case WASM_OP_I32_TRUNC_SAT_S_F64:
                case WASM_OP_I32_TRUNC_SAT_U_F64:
                    sign = (opcode == WASM_OP_I32_TRUNC_SAT_S_F64) ? true : false;
                    if (!jit_compile_op_i32_trunc_f64(cc, sign, true))
                        return false;
                    break;
                case WASM_OP_I64_TRUNC_SAT_S_F32:
                case WASM_OP_I64_TRUNC_SAT_U_F32:
                    sign = (opcode == WASM_OP_I64_TRUNC_SAT_S_F32) ? true : false;
                    if (!jit_compile_op_i64_trunc_f32(cc, sign, true))
                        return false;
                    break;
                case WASM_OP_I64_TRUNC_SAT_S_F64:
                case WASM_OP_I64_TRUNC_SAT_U_F64:
                    sign = (opcode == WASM_OP_I64_TRUNC_SAT_S_F64) ? true : false;
                    if (!jit_compile_op_i64_trunc_f64(cc, sign, true))
                        return false;
                    break;
                    static if (ver.WASM_ENABLE_BULK_MEMORY) {
                case WASM_OP_MEMORY_INIT: {
                            uint seg_idx = 0;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, seg_idx);
                            read_lebT!uint(cc, frame_ip, frame_ip_end, mem_idx);
                            if (!jit_compile_op_memory_init(cc, mem_idx, seg_idx))
                                return false;
                            break;
                        }
                case WASM_OP_DATA_DROP: {
                            uint seg_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, seg_idx);
                            if (!jit_compile_op_data_drop(cc, seg_idx))
                                return false;
                            break;
                        }
                case WASM_OP_MEMORY_COPY: {
                            uint src_mem_idx = void, dst_mem_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, src_mem_idx);
                            read_lebT!uint(cc, frame_ip, frame_ip_end, dst_mem_idx);
                            if (!jit_compile_op_memory_copy(cc, src_mem_idx,
                                    dst_mem_idx))
                                return false;
                            break;
                        }
                case WASM_OP_MEMORY_FILL: {
                            read_lebT!uint(cc, frame_ip, frame_ip_end, mem_idx);
                            if (!jit_compile_op_memory_fill(cc, mem_idx))
                                return false;
                            break;
                        }
                    } /* WASM_ENABLE_BULK_MEMORY */
                    static if (ver.WASM_ENABLE_REF_TYPES) {
                case WASM_OP_TABLE_INIT: {
                            uint tbl_idx = void, tbl_seg_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_seg_idx);
                            read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                            if (!jit_compile_op_table_init(cc, tbl_idx,
                                    tbl_seg_idx))
                                return false;
                            break;
                        }
                case WASM_OP_ELEM_DROP: {
                            uint tbl_seg_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_seg_idx);
                            if (!jit_compile_op_elem_drop(cc, tbl_seg_idx))
                                return false;
                            break;
                        }
                case WASM_OP_TABLE_COPY: {
                            uint src_tbl_idx = void, dst_tbl_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, dst_tbl_idx);
                            read_lebT!uint(cc, frame_ip, frame_ip_end, src_tbl_idx);
                            if (!jit_compile_op_table_copy(cc, src_tbl_idx,
                                    dst_tbl_idx))
                                return false;
                            break;
                        }
                case WASM_OP_TABLE_GROW: {
                            uint tbl_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                            if (!jit_compile_op_table_grow(cc, tbl_idx))
                                return false;
                            break;
                        }
                case WASM_OP_TABLE_SIZE: {
                            uint tbl_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                            if (!jit_compile_op_table_size(cc, tbl_idx))
                                return false;
                            break;
                        }
                case WASM_OP_TABLE_FILL: {
                            uint tbl_idx = void;
                            read_lebT!uint(cc, frame_ip, frame_ip_end, tbl_idx);
                            if (!jit_compile_op_table_fill(cc, tbl_idx))
                                return false;
                            break;
                        }
                    } /* WASM_ENABLE_REF_TYPES */
                default:
                    jit_set_last_error(cc, "unsupported opcode");
                    return false;
                }
                break;
            }
            static if (ver.WASM_ENABLE_SHARED_MEMORY) {
        case WASM_OP_ATOMIC_PREFIX: {
                    ubyte bin_op = void, op_type = void;
                    if (frame_ip < frame_ip_end) {
                        opcode = *frame_ip++;
                    }
                    if (opcode != WASM_OP_ATOMIC_FENCE) {
                        read_lebT!uint(cc, frame_ip, frame_ip_end, align_);
                        read_lebT!uint(cc, frame_ip, frame_ip_end, offset);
                    }
                    switch (opcode) {
                    case WASM_OP_ATOMIC_WAIT32:
                        if (!jit_compile_op_atomic_wait(cc, VALUE_TYPE_I32,
                                align_, offset, 4))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_WAIT64:
                        if (!jit_compile_op_atomic_wait(cc, VALUE_TYPE_I64,
                                align_, offset, 8))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_NOTIFY:
                        if (!jit_compiler_op_atomic_notify(cc, align_, offset,
                                bytes))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_FENCE:
                        /* Skip memory index */
                        frame_ip++;
                        break;
                    case WASM_OP_ATOMIC_I32_LOAD:
                        bytes = 4;
                        goto op_atomic_i32_load;
                    case WASM_OP_ATOMIC_I32_LOAD8_U:
                        bytes = 1;
                        goto op_atomic_i32_load;
                    case WASM_OP_ATOMIC_I32_LOAD16_U:
                        bytes = 2;
                    op_atomic_i32_load:
                        if (!jit_compile_op_i32_load(cc, align_, offset, bytes,
                                sign, true))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_I64_LOAD:
                        bytes = 8;
                        goto op_atomic_i64_load;
                    case WASM_OP_ATOMIC_I64_LOAD8_U:
                        bytes = 1;
                        goto op_atomic_i64_load;
                    case WASM_OP_ATOMIC_I64_LOAD16_U:
                        bytes = 2;
                        goto op_atomic_i64_load;
                    case WASM_OP_ATOMIC_I64_LOAD32_U:
                        bytes = 4;
                    op_atomic_i64_load:
                        if (!jit_compile_op_i64_load(cc, align_, offset, bytes,
                                sign, true))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_I32_STORE:
                        bytes = 4;
                        goto op_atomic_i32_store;
                    case WASM_OP_ATOMIC_I32_STORE8:
                        bytes = 1;
                        goto op_atomic_i32_store;
                    case WASM_OP_ATOMIC_I32_STORE16:
                        bytes = 2;
                    op_atomic_i32_store:
                        if (!jit_compile_op_i32_store(cc, align_, offset, bytes,
                                true))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_I64_STORE:
                        bytes = 8;
                        goto op_atomic_i64_store;
                    case WASM_OP_ATOMIC_I64_STORE8:
                        bytes = 1;
                        goto op_atomic_i64_store;
                    case WASM_OP_ATOMIC_I64_STORE16:
                        bytes = 2;
                        goto op_atomic_i64_store;
                    case WASM_OP_ATOMIC_I64_STORE32:
                        bytes = 4;
                    op_atomic_i64_store:
                        if (!jit_compile_op_i64_store(cc, align_, offset, bytes,
                                true))
                            return false;
                        break;
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG:
                        bytes = 4;
                        op_type = VALUE_TYPE_I32;
                        goto op_atomic_cmpxchg;
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG:
                        bytes = 8;
                        op_type = VALUE_TYPE_I64;
                        goto op_atomic_cmpxchg;
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U:
                        bytes = 1;
                        op_type = VALUE_TYPE_I32;
                        goto op_atomic_cmpxchg;
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U:
                        bytes = 2;
                        op_type = VALUE_TYPE_I32;
                        goto op_atomic_cmpxchg;
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U:
                        bytes = 1;
                        op_type = VALUE_TYPE_I64;
                        goto op_atomic_cmpxchg;
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U:
                        bytes = 2;
                        op_type = VALUE_TYPE_I64;
                        goto op_atomic_cmpxchg;
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U:
                        bytes = 4;
                        op_type = VALUE_TYPE_I64;
                    op_atomic_cmpxchg:
                        if (!jit_compile_op_atomic_cmpxchg(cc, op_type, align_,
                                offset, bytes))
                            return false;
                        break;
                        /* TODO */
                        /*
                        COMPILE_ATOMIC_RMW(Add, ADD);
                        COMPILE_ATOMIC_RMW(Sub, SUB);
                        COMPILE_ATOMIC_RMW(And, AND);
                        COMPILE_ATOMIC_RMW(Or, OR);
                        COMPILE_ATOMIC_RMW(Xor, XOR);
                        COMPILE_ATOMIC_RMW(Xchg, XCHG);
                        */
                    build_atomic_rmw:
                        if (!jit_compile_op_atomic_rmw(cc, bin_op, op_type,
                                align_, offset, bytes))
                            return false;
                        break;
                    default:
                        jit_set_last_error(cc, "unsupported opcode");
                        return false;
                    }
                    break;
                }
            } /* end of WASM_ENABLE_SHARED_MEMORY */
        default:
            jit_set_last_error(cc, "unsupported opcode");
            return false;
        }
        /* Error may occur when creating registers, basic blocks, insns,
           consts and labels, in which the return value may be unchecked,
           here we check again */
        if (jit_get_last_error(cc)) {
            return false;
        }
    }
    cast(void) func_idx;
    return true;
fail:
    return false;
}

uint jit_frontend_get_jitted_return_addr_offset() {
    return cast(uint) WASMInterpFrame.jitted_return_addr.offsetof;
}

version (none) {
    static if (ver.WASM_ENABLE_THREAD_MGR) {
        bool check_suspend_flags(JitCompContext* cc, JITFuncContext* func_ctx) {
            LLVMValueRef terminate_addr = void, terminate_flags = void, flag = void, offset = void, res = void;
            JitBasicBlock* terminate_check_block = void;
            JitBasicBlock non_terminate_block = void;
            JITFuncType* jit_func_type = func_ctx.jit_func.func_type;
            JitBasicBlock* terminate_block = void;
            /* Offset of suspend_flags */
            offset = I32_FIVE;
            if (((terminate_addr = LLVMBuildInBoundsGEP(
                    cc.builder, func_ctx.exec_env, &offset, 1, "terminate_addr")) == 0)) {
                jit_set_last_error("llvm build in bounds gep failed");
                return false;
            }
            if (((terminate_addr =
                    LLVMBuildBitCast(cc.builder, terminate_addr, INT32_PTR_TYPE,
                    "terminate_addr_ptr")) == 0)) {
                jit_set_last_error("llvm build bit cast failed");
                return false;
            }
            if (((terminate_flags =
                    LLVMBuildLoad(cc.builder, terminate_addr, "terminate_flags")) == 0)) {
                jit_set_last_error("llvm build bit cast failed");
                return false;
            }
            /* Set terminate_flags memory accecc to volatile, so that the value
        will always be loaded from memory rather than register */
            LLVMSetVolatile(terminate_flags, true);
            CREATE_BASIC_BLOCK(terminate_check_block, "terminate_check");
            MOVE_BASIC_BLOCK_AFTER_CURR(terminate_check_block);
            CREATE_BASIC_BLOCK(non_terminate_block, "non_terminate");
            MOVE_BASIC_BLOCK_AFTER_CURR(non_terminate_block);
            BUILD_ICMP(LLVMIntSGT, terminate_flags, I32_ZERO, res, "need_terminate");
            BUILD_COND_BR(res, terminate_check_block, non_terminate_block);
            /* Move builder to terminate check block */
            SET_BUILDER_POS(terminate_check_block);
            CREATE_BASIC_BLOCK(terminate_block, "terminate");
            MOVE_BASIC_BLOCK_AFTER_CURR(terminate_block);
            if (((flag = LLVMBuildAnd(cc.builder, terminate_flags, I32_ONE,
                    "termination_flag")) == 0)) {
                jit_set_last_error("llvm build AND failed");
                return false;
            }
            BUILD_ICMP(LLVMIntSGT, flag, I32_ZERO, res, "need_terminate");
            BUILD_COND_BR(res, terminate_block, non_terminate_block);
            /* Move builder to terminate block */
            SET_BUILDER_POS(terminate_block);
            if (!jit_build_zero_function_ret(cc, func_ctx, jit_func_type)) {
                goto fail;
            }
            /* Move builder to terminate block */
            SET_BUILDER_POS(non_terminate_block);
            return true;
        fail:
            return false;
        }
    } /* End of WASM_ENABLE_THREAD_MGR */
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
public import tagion.iwasm.interpreter.wasm_interp;

static if (ver.WASM_ENABLE_AOT) {
    public import tagion.iwasm.aot.aot_runtime;
}
enum IntCond {
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

alias INT_EQZ = IntCond.INT_EQZ;
alias INT_EQ = IntCond.INT_EQ;
alias INT_NE = IntCond.INT_NE;
alias INT_LT_S = IntCond.INT_LT_S;
alias INT_LT_U = IntCond.INT_LT_U;
alias INT_GT_S = IntCond.INT_GT_S;
alias INT_GT_U = IntCond.INT_GT_U;
alias INT_LE_S = IntCond.INT_LE_S;
alias INT_LE_U = IntCond.INT_LE_U;
alias INT_GE_S = IntCond.INT_GE_S;
alias INT_GE_U = IntCond.INT_GE_U;
enum FloatCond {
    FLOAT_EQ = 0,
    FLOAT_NE,
    FLOAT_LT,
    FLOAT_GT,
    FLOAT_LE,
    FLOAT_GE,
    FLOAT_UNO
}

alias FLOAT_EQ = FloatCond.FLOAT_EQ;
alias FLOAT_NE = FloatCond.FLOAT_NE;
alias FLOAT_LT = FloatCond.FLOAT_LT;
alias FLOAT_GT = FloatCond.FLOAT_GT;
alias FLOAT_LE = FloatCond.FLOAT_LE;
alias FLOAT_GE = FloatCond.FLOAT_GE;
alias FLOAT_UNO = FloatCond.FLOAT_UNO;
enum IntArithmetic {
    INT_ADD = 0,
    INT_SUB,
    INT_MUL,
    INT_DIV_S,
    INT_DIV_U,
    INT_REM_S,
    INT_REM_U
}

alias INT_ADD = IntArithmetic.INT_ADD;
alias INT_SUB = IntArithmetic.INT_SUB;
alias INT_MUL = IntArithmetic.INT_MUL;
alias INT_DIV_S = IntArithmetic.INT_DIV_S;
alias INT_DIV_U = IntArithmetic.INT_DIV_U;
alias INT_REM_S = IntArithmetic.INT_REM_S;
alias INT_REM_U = IntArithmetic.INT_REM_U;
enum V128Arithmetic {
    V128_ADD = 0,
    V128_SUB,
    V128_MUL,
    V128_DIV,
    V128_NEG,
    V128_MIN,
    V128_MAX,
}

alias V128_ADD = V128Arithmetic.V128_ADD;
alias V128_SUB = V128Arithmetic.V128_SUB;
alias V128_MUL = V128Arithmetic.V128_MUL;
alias V128_DIV = V128Arithmetic.V128_DIV;
alias V128_NEG = V128Arithmetic.V128_NEG;
alias V128_MIN = V128Arithmetic.V128_MIN;
alias V128_MAX = V128Arithmetic.V128_MAX;
enum IntBitwise {
    INT_AND = 0,
    INT_OR,
    INT_XOR,
}

alias INT_AND = IntBitwise.INT_AND;
alias INT_OR = IntBitwise.INT_OR;
alias INT_XOR = IntBitwise.INT_XOR;
enum V128Bitwise {
    V128_NOT,
    V128_AND,
    V128_ANDNOT,
    V128_OR,
    V128_XOR,
    V128_BITSELECT,
}

alias V128_NOT = V128Bitwise.V128_NOT;
alias V128_AND = V128Bitwise.V128_AND;
alias V128_ANDNOT = V128Bitwise.V128_ANDNOT;
alias V128_OR = V128Bitwise.V128_OR;
alias V128_XOR = V128Bitwise.V128_XOR;
alias V128_BITSELECT = V128Bitwise.V128_BITSELECT;
enum IntShift {
    INT_SHL = 0,
    INT_SHR_S,
    INT_SHR_U,
    INT_ROTL,
    INT_ROTR
}

alias INT_SHL = IntShift.INT_SHL;
alias INT_SHR_S = IntShift.INT_SHR_S;
alias INT_SHR_U = IntShift.INT_SHR_U;
alias INT_ROTL = IntShift.INT_ROTL;
alias INT_ROTR = IntShift.INT_ROTR;
enum FloatMath {
    FLOAT_ABS = 0,
    FLOAT_NEG,
    FLOAT_CEIL,
    FLOAT_FLOOR,
    FLOAT_TRUNC,
    FLOAT_NEAREST,
    FLOAT_SQRT
}

alias FLOAT_ABS = FloatMath.FLOAT_ABS;
alias FLOAT_NEG = FloatMath.FLOAT_NEG;
alias FLOAT_CEIL = FloatMath.FLOAT_CEIL;
alias FLOAT_FLOOR = FloatMath.FLOAT_FLOOR;
alias FLOAT_TRUNC = FloatMath.FLOAT_TRUNC;
alias FLOAT_NEAREST = FloatMath.FLOAT_NEAREST;
alias FLOAT_SQRT = FloatMath.FLOAT_SQRT;
enum FloatArithmetic {
    FLOAT_ADD = 0,
    FLOAT_SUB,
    FLOAT_MUL,
    FLOAT_DIV,
    FLOAT_MIN,
    FLOAT_MAX,
}

alias FLOAT_ADD = FloatArithmetic.FLOAT_ADD;
alias FLOAT_SUB = FloatArithmetic.FLOAT_SUB;
alias FLOAT_MUL = FloatArithmetic.FLOAT_MUL;
alias FLOAT_DIV = FloatArithmetic.FLOAT_DIV;
alias FLOAT_MIN = FloatArithmetic.FLOAT_MIN;
alias FLOAT_MAX = FloatArithmetic.FLOAT_MAX;
/**
 * Translate instructions in a function. The translated block must
 * end with a branch instruction whose targets are offsets relating to
 * the end bcip of the translated block, which are integral constants.
 * If a target of a branch is really a constant value (which should be
 * rare), put it into a register and then jump to the register instead
 * of using the constant value directly in the target. In the
 * translation process, don't create any new labels. The code bcip of
 * the begin and end of the translated block is stored in the
 * jit_annl_begin_bcip and jit_annl_end_bcip annotations of the label
 * of the block, which must be the same as the bcips used in
 * profiling.
 *
 * NOTE: the function must explicitly set SP to correct value when the
 * entry's bcip is the function's entry address.
 *
 * @param cc containing compilation context of generated IR
 * @param entry entry of the basic block to be translated. If its
 * value is NULL, the function will clean up any pass local data that
 * might be created previously.
 * @param is_reached a bitmap recording which bytecode has been
 * reached as a block entry
 *
 * @return IR block containing translated instructions if succeeds,
 * NULL otherwise
 */
JitBasicBlock* jit_frontend_translate_func(JitCompContext* cc);
/**
 * Lower the IR of the given compilation context.
 *
 * @param cc the compilation context
 *
 * @return true if succeeds, false otherwise
 */
bool jit_frontend_lower(JitCompContext* cc);
uint jit_frontend_get_jitted_return_addr_offset();
uint jit_frontend_get_global_data_offset(const(WASMModule)* module_, uint global_idx);
uint jit_frontend_get_table_inst_offset(const(WASMModule)* module_, uint tbl_idx);
uint jit_frontend_get_module_inst_extra_offset(const(WASMModule)* module_);

/**
 * Get the offset from frame pointer to the n-th local variable slot.
 *
 * @param n the index to the local variable array
 *
 * @return the offset from frame pointer to the local variable slot
 */
uint offset_of_local(size_t n) {
    return cast(uint)(WASMInterpFrame.lp.offsetof + n * 4);
}
enum string POP(string jit_value, string value_type) = ` do { if (!jit_cc_pop_value(cc, value_type, &jit_value)) goto fail; } while (0)`;
enum string POP_I32(string v) = ` POP(v, VALUE_TYPE_I32)`;
enum string POP_I64(string v) = ` POP(v, VALUE_TYPE_I64)`;
enum string POP_F32(string v) = ` POP(v, VALUE_TYPE_F32)`;
enum string POP_F64(string v) = ` POP(v, VALUE_TYPE_F64)`;
enum string POP_FUNCREF(string v) = ` POP(v, VALUE_TYPE_FUNCREF)`;
enum string POP_EXTERNREF(string v) = ` POP(v, VALUE_TYPE_EXTERNREF)`;
enum string PUSH(string jit_value, string value_type) = ` do { if (!jit_value) goto fail; if (!jit_cc_push_value(cc, value_type, jit_value)) goto fail; } while (0)`;
enum string PUSH_I32(string v) = ` PUSH(v, VALUE_TYPE_I32)`;
enum string PUSH_I64(string v) = ` PUSH(v, VALUE_TYPE_I64)`;
enum string PUSH_F32(string v) = ` PUSH(v, VALUE_TYPE_F32)`;
enum string PUSH_F64(string v) = ` PUSH(v, VALUE_TYPE_F64)`;
enum string PUSH_FUNCREF(string v) = ` PUSH(v, VALUE_TYPE_FUNCREF)`;
enum string PUSH_EXTERNREF(string v) = ` PUSH(v, VALUE_TYPE_EXTERNREF)`;
