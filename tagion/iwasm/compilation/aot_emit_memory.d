module tagion.iwasm.compilation.aot_emit_memory;
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
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.compilation.aot_compiler;
bool aot_compile_op_i32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic);
bool aot_compile_op_i64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic);
bool aot_compile_op_f32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);
bool aot_compile_op_f64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);
bool aot_compile_op_i32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic);
bool aot_compile_op_i64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic);
bool aot_compile_op_f32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);
bool aot_compile_op_f64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);
LLVMValueRef aot_check_memory_overflow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint offset, uint bytes);
bool aot_compile_op_memory_size(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);
bool aot_compile_op_memory_grow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.aot.aot_runtime;
import tagion.iwasm.aot.aot_intrinsic;
private LLVMValueRef get_memory_check_bound(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint bytes) {
    LLVMValueRef mem_check_bound = null;
    switch (bytes) {
        case 1:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_1byte;
            break;
        case 2:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_2bytes;
            break;
        case 4:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_4bytes;
            break;
        case 8:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_8bytes;
            break;
        case 16:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_16bytes;
            break;
        default:
            bh_assert(0);
            return null;
    }
    if (func_ctx.mem_space_unchanged)
        return mem_check_bound;
    if (((mem_check_bound = LLVMBuildLoad2(
              comp_ctx.builder,
              (comp_ctx.pointer_size == uint64.sizeof) ? I64_TYPE : I32_TYPE,
              mem_check_bound, "mem_check_bound")) == 0)) {
        aot_set_last_error("llvm build load failed.");
        return null;
    }
    return mem_check_bound;
}
private LLVMValueRef get_memory_curr_page_count(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);
LLVMValueRef aot_check_memory_overflow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint offset, uint bytes) {
    LLVMValueRef offset_const = I32_CONST(offset);
    LLVMValueRef addr = void, maddr = void, offset1 = void, cmp1 = void, cmp2 = void, cmp = void;
    LLVMValueRef mem_base_addr = void, mem_check_bound = void;
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMBasicBlockRef check_succ = void;
    AOTValue* aot_value_top = void;
    uint local_idx_of_aot_value = 0;
    bool is_target_64bit = void, is_local_of_aot_value = false;
    is_target_64bit = (comp_ctx.pointer_size == uint64.sizeof) ? true : false;
    if (comp_ctx.is_indirect_mode
        && aot_intrinsic_check_capability(comp_ctx, "i32.const")) {
        WASMValue wasm_value = void;
        wasm_value.i32 = offset;
        offset_const = aot_load_const_from_table(
            comp_ctx, func_ctx.native_symbol, &wasm_value, VALUE_TYPE_I32);
        if (!offset_const) {
            return null;
        }
    }
    else {
        CHECK_LLVM_CONST(offset_const);
    }
    /* Get memory base address and memory data size */
    if (func_ctx.mem_space_unchanged
    ) {
        mem_base_addr = func_ctx.mem_info[0].mem_base_addr;
    }
    else {
        if (((mem_base_addr = LLVMBuildLoad2(
                  comp_ctx.builder, OPQ_PTR_TYPE,
                  func_ctx.mem_info[0].mem_base_addr, "mem_base")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            goto fail;
        }
    }
    aot_value_top =
        func_ctx.block_stack.block_list_end.value_stack.value_list_end;
    if (aot_value_top) {
        /* aot_value_top is freed in the following POP_I32(addr),
           so save its fields here for further use */
        is_local_of_aot_value = aot_value_top.is_local;
        local_idx_of_aot_value = aot_value_top.local_idx;
    }
    POP_I32(addr);
    /*
     * Note: not throw the integer-overflow-exception here since it must
     * have been thrown when converting float to integer before
     */
    /* return addres directly if constant offset and inside memory space */
    if (LLVMIsConstant(addr) && !LLVMIsUndef(addr)
    ) {
        ulong mem_offset = cast(ulong)LLVMConstIntGetZExtValue(addr) + cast(ulong)offset;
        uint num_bytes_per_page = comp_ctx.comp_data.memories[0].num_bytes_per_page;
        uint init_page_count = comp_ctx.comp_data.memories[0].mem_init_page_count;
        ulong mem_data_size = cast(ulong)num_bytes_per_page * init_page_count;
        if (mem_offset + bytes <= mem_data_size) {
            /* inside memory space */
            offset1 = I32_CONST(cast(uint)mem_offset);
            CHECK_LLVM_CONST(offset1);
            if (((maddr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                                mem_base_addr, &offset1, 1,
                                                "maddr")) == 0)) {
                aot_set_last_error("llvm build add failed.");
                goto fail;
            }
            return maddr;
        }
    }
    if (is_target_64bit) {
        if (((offset_const = LLVMBuildZExt(comp_ctx.builder, offset_const,
                                           I64_TYPE, "offset_i64")) == 0)
            || ((addr = LLVMBuildZExt(comp_ctx.builder, addr, I64_TYPE,
                                      "addr_i64")) == 0)) {
            aot_set_last_error("llvm build zero extend failed.");
            goto fail;
        }
    }
    /* offset1 = offset + addr; */
    do { if (((offset1 = LLVMBuildAdd(comp_ctx.builder, offset_const, addr, "offset1")) == 0)) { aot_set_last_error("llvm build " ~ "Add" ~ " fail."); goto fail; } } while (0);
    if (comp_ctx.enable_bound_check
        && !(is_local_of_aot_value
             && aot_checked_addr_list_find(func_ctx, local_idx_of_aot_value,
                                           offset, bytes))) {
        uint init_page_count = comp_ctx.comp_data.memories[0].mem_init_page_count;
        if (init_page_count == 0) {
            LLVMValueRef mem_size = void;
            if (((mem_size = get_memory_curr_page_count(comp_ctx, func_ctx)) == 0)) {
                goto fail;
            }
            do { if (((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, mem_size, I32_ZERO, "is_zero")) == 0)) { aot_set_last_error("llvm build icmp failed."); goto fail; } } while (0);
            do { if (((check_succ = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "check_mem_size_succ")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } } while (0);
            LLVMMoveBasicBlockAfter(check_succ, block_curr);
            if (!aot_emit_exception(comp_ctx, func_ctx,
                                    EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, true, cmp,
                                    check_succ)) {
                goto fail;
            }
            LLVMPositionBuilderAtEnd(comp_ctx.builder, check_succ);
            block_curr = check_succ;
        }
        if (((mem_check_bound =
                  get_memory_check_bound(comp_ctx, func_ctx, bytes)) == 0)) {
            goto fail;
        }
        if (is_target_64bit) {
            do { if (((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGT, offset1, mem_check_bound, "cmp")) == 0)) { aot_set_last_error("llvm build icmp failed."); goto fail; } } while (0);
        }
        else {
            /* Check integer overflow */
            do { if (((cmp1 = LLVMBuildICmp(comp_ctx.builder, LLVMIntULT, offset1, addr, "cmp1")) == 0)) { aot_set_last_error("llvm build icmp failed."); goto fail; } } while (0);
            do { if (((cmp2 = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGT, offset1, mem_check_bound, "cmp2")) == 0)) { aot_set_last_error("llvm build icmp failed."); goto fail; } } while (0);
            do { if (((cmp = LLVMBuildOr(comp_ctx.builder, cmp1, cmp2, "cmp")) == 0)) { aot_set_last_error("llvm build " ~ "Or" ~ " fail."); goto fail; } } while (0);
        }
        /* Add basic blocks */
        do { if (((check_succ = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "check_succ")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } } while (0);
        LLVMMoveBasicBlockAfter(check_succ, block_curr);
        if (!aot_emit_exception(comp_ctx, func_ctx,
                                EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, true, cmp,
                                check_succ)) {
            goto fail;
        }
        LLVMPositionBuilderAtEnd(comp_ctx.builder, check_succ);
        if (is_local_of_aot_value) {
            if (!aot_checked_addr_list_add(func_ctx, local_idx_of_aot_value,
                                           offset, bytes))
                goto fail;
        }
    }
    /* maddr = mem_base_addr + offset1 */
    if (((maddr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                        mem_base_addr, &offset1, 1, "maddr")) == 0)) {
        aot_set_last_error("llvm build add failed.");
        goto fail;
    }
    return maddr;
fail:
    return null;
}
bool aot_compile_op_i32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic) {
    LLVMValueRef maddr = void, value = null;
    LLVMTypeRef data_type = void;
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;
    switch (bytes) {
        case 4:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT32_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                do { if (((value = LLVMBuildLoad2(comp_ctx.builder, I32_TYPE, maddr, "data")) == 0)) { aot_set_last_error("llvm build load failed."); goto fail; } LLVMSetAlignment(value, 1); } while (0);
            break;
        case 2:
        case 1:
            if (bytes == 2) {
                do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT16_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                data_type = INT16_TYPE;
            }
            else {
                do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT8_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                data_type = INT8_TYPE;
            }
            {
                do { if (((value = LLVMBuildLoad2(comp_ctx.builder, data_type, maddr, "data")) == 0)) { aot_set_last_error("llvm build load failed."); goto fail; } LLVMSetAlignment(value, 1); } while (0);
                if (sign)
                    do { if (((value = LLVMBuildSExt(comp_ctx.builder, value, I32_TYPE, "data_s_ext")) == 0)) { aot_set_last_error("llvm build sign ext failed."); goto fail; } } while (0);
                else
                    do { if (((value = LLVMBuildZExt(comp_ctx.builder, value, I32_TYPE, "data_z_ext")) == 0)) { aot_set_last_error("llvm build zero ext failed."); goto fail; } } while (0);
            }
            break;
        default:
            bh_assert(0);
            break;
    }
    PUSH_I32(value);
    cast(void)data_type;
    return true;
fail:
    return false;
}
bool aot_compile_op_i64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic) {
    LLVMValueRef maddr = void, value = null;
    LLVMTypeRef data_type = void;
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;
    switch (bytes) {
        case 8:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT64_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                do { if (((value = LLVMBuildLoad2(comp_ctx.builder, I64_TYPE, maddr, "data")) == 0)) { aot_set_last_error("llvm build load failed."); goto fail; } LLVMSetAlignment(value, 1); } while (0);
            break;
        case 4:
        case 2:
        case 1:
            if (bytes == 4) {
                do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT32_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                data_type = I32_TYPE;
            }
            else if (bytes == 2) {
                do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT16_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                data_type = INT16_TYPE;
            }
            else {
                do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT8_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
                data_type = INT8_TYPE;
            }
            {
                do { if (((value = LLVMBuildLoad2(comp_ctx.builder, data_type, maddr, "data")) == 0)) { aot_set_last_error("llvm build load failed."); goto fail; } LLVMSetAlignment(value, 1); } while (0);
                if (sign)
                    do { if (((value = LLVMBuildSExt(comp_ctx.builder, value, I64_TYPE, "data_s_ext")) == 0)) { aot_set_last_error("llvm build sign ext failed."); goto fail; } } while (0);
                else
                    do { if (((value = LLVMBuildZExt(comp_ctx.builder, value, I64_TYPE, "data_z_ext")) == 0)) { aot_set_last_error("llvm build zero ext failed."); goto fail; } } while (0);
            }
            break;
        default:
            bh_assert(0);
            break;
    }
    PUSH_I64(value);
    cast(void)data_type;
    return true;
fail:
    return false;
}
bool aot_compile_op_f32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 4)) == 0))
        return false;
    do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, F32_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
    do { if (((value = LLVMBuildLoad2(comp_ctx.builder, F32_TYPE, maddr, "data")) == 0)) { aot_set_last_error("llvm build load failed."); goto fail; } LLVMSetAlignment(value, 1); } while (0);
    PUSH_F32(value);
    return true;
fail:
    return false;
}
bool aot_compile_op_f64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 8)) == 0))
        return false;
    do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, F64_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
    do { if (((value = LLVMBuildLoad2(comp_ctx.builder, F64_TYPE, maddr, "data")) == 0)) { aot_set_last_error("llvm build load failed."); goto fail; } LLVMSetAlignment(value, 1); } while (0);
    PUSH_F64(value);
    return true;
fail:
    return false;
}
bool aot_compile_op_i32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic) {
    LLVMValueRef maddr = void, value = void;
    POP_I32(value);
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;
    switch (bytes) {
        case 4:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT32_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            break;
        case 2:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT16_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            do { if (((value = LLVMBuildTrunc(comp_ctx.builder, value, INT16_TYPE, "val_trunc")) == 0)) { aot_set_last_error("llvm build trunc failed."); goto fail; } } while (0);
            break;
        case 1:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT8_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            do { if (((value = LLVMBuildTrunc(comp_ctx.builder, value, INT8_TYPE, "val_trunc")) == 0)) { aot_set_last_error("llvm build trunc failed."); goto fail; } } while (0);
            break;
        default:
            bh_assert(0);
            break;
    }
        do { LLVMValueRef res = void; if (((res = LLVMBuildStore(comp_ctx.builder, value, maddr)) == 0)) { aot_set_last_error("llvm build store failed."); goto fail; } LLVMSetAlignment(res, 1); } while (0);
    return true;
fail:
    return false;
}
bool aot_compile_op_i64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic) {
    LLVMValueRef maddr = void, value = void;
    POP_I64(value);
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;
    switch (bytes) {
        case 8:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT64_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            break;
        case 4:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT32_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            do { if (((value = LLVMBuildTrunc(comp_ctx.builder, value, I32_TYPE, "val_trunc")) == 0)) { aot_set_last_error("llvm build trunc failed."); goto fail; } } while (0);
            break;
        case 2:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT16_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            do { if (((value = LLVMBuildTrunc(comp_ctx.builder, value, INT16_TYPE, "val_trunc")) == 0)) { aot_set_last_error("llvm build trunc failed."); goto fail; } } while (0);
            break;
        case 1:
            do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, INT8_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
            do { if (((value = LLVMBuildTrunc(comp_ctx.builder, value, INT8_TYPE, "val_trunc")) == 0)) { aot_set_last_error("llvm build trunc failed."); goto fail; } } while (0);
            break;
        default:
            bh_assert(0);
            break;
    }
        do { LLVMValueRef res = void; if (((res = LLVMBuildStore(comp_ctx.builder, value, maddr)) == 0)) { aot_set_last_error("llvm build store failed."); goto fail; } LLVMSetAlignment(res, 1); } while (0);
    return true;
fail:
    return false;
}
bool aot_compile_op_f32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;
    POP_F32(value);
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 4)) == 0))
        return false;
    do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, F32_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
    do { LLVMValueRef res = void; if (((res = LLVMBuildStore(comp_ctx.builder, value, maddr)) == 0)) { aot_set_last_error("llvm build store failed."); goto fail; } LLVMSetAlignment(res, 1); } while (0);
    return true;
fail:
    return false;
}
bool aot_compile_op_f64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;
    POP_F64(value);
    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 8)) == 0))
        return false;
    do { if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, F64_PTR_TYPE, "data_ptr")) == 0)) { aot_set_last_error("llvm build bit cast failed."); goto fail; } } while (0);
    do { LLVMValueRef res = void; if (((res = LLVMBuildStore(comp_ctx.builder, value, maddr)) == 0)) { aot_set_last_error("llvm build store failed."); goto fail; } LLVMSetAlignment(res, 1); } while (0);
    return true;
fail:
    return false;
}
private LLVMValueRef get_memory_curr_page_count(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef mem_size = void;
    if (func_ctx.mem_space_unchanged) {
        mem_size = func_ctx.mem_info[0].mem_cur_page_count_addr;
    }
    else {
        if (((mem_size = LLVMBuildLoad2(
                  comp_ctx.builder, I32_TYPE,
                  func_ctx.mem_info[0].mem_cur_page_count_addr, "mem_size")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            goto fail;
        }
    }
    return mem_size;
fail:
    return null;
}
bool aot_compile_op_memory_size(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef mem_size = get_memory_curr_page_count(comp_ctx, func_ctx);
    if (mem_size)
        PUSH_I32(mem_size);
    return mem_size ? true : false;
fail:
    return false;
}
bool aot_compile_op_memory_grow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef mem_size = get_memory_curr_page_count(comp_ctx, func_ctx);
    LLVMValueRef delta = void; LLVMValueRef[2] param_values = void; LLVMValueRef ret_value = void, func = void, value = void;
    LLVMTypeRef[2] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    int func_index = void;
    if (!mem_size)
        return false;
    POP_I32(delta);
    /* Function type of aot_enlarge_memory() */
    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    ret_type = INT8_TYPE;
    if (((func_type = LLVMFunctionType(ret_type, param_types.ptr, 2, false)) == 0)) {
        aot_set_last_error("llvm add function type failed.");
        return false;
    }
    if (comp_ctx.is_jit_mode) {
        /* JIT mode, call the function directly */
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("llvm add pointer type failed.");
            return false;
        }
        if (((value = I64_CONST(cast(ulong)cast(uintptr_t)wasm_enlarge_memory)) == 0)
            || ((func = LLVMConstIntToPtr(value, func_ptr_type)) == 0)) {
            aot_set_last_error("create LLVM value failed.");
            return false;
        }
    }
    else if (comp_ctx.is_indirect_mode) {
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }
        func_index =
            aot_get_native_symbol_index(comp_ctx, "aot_enlarge_memory");
        if (func_index < 0) {
            return false;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_ptr_type, func_index)) == 0)) {
            return false;
        }
    }
    else {
        char* func_name = "aot_enlarge_memory";
        /* AOT mode, delcare the function */
        if (((func = LLVMGetNamedFunction(func_ctx.module_, func_name)) == 0)
            && ((func =
                     LLVMAddFunction(func_ctx.module_, func_name, func_type)) == 0)) {
            aot_set_last_error("llvm add function failed.");
            return false;
        }
    }
    /* Call function aot_enlarge_memory() */
    param_values[0] = func_ctx.aot_inst;
    param_values[1] = delta;
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 2, "call")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }
    do { if (((ret_value = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGT, ret_value, I8_ZERO, "mem_grow_ret")) == 0)) { aot_set_last_error("llvm build icmp failed."); goto fail; } } while (0);
    /* ret_value = ret_value == true ? delta : pre_page_count */
    if (((ret_value = LLVMBuildSelect(comp_ctx.builder, ret_value, mem_size,
                                      I32_NEG_ONE, "mem_grow_ret")) == 0)) {
        aot_set_last_error("llvm build select failed.");
        return false;
    }
    PUSH_I32(ret_value);
    return true;
fail:
    return false;
}
