module tagion.iwasm.compilation.aot_emit_numberic;
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
 * Copyright (C) 2020 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.llvm.llvm_c.Types;
import tagion.iwasm.compilation.aot_llvm;
import tagion.iwasm.compilation.aot_compiler;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.compilation.aot_emit_control;
import tagion.iwasm.aot.aot_runtime;
import tagion.iwasm.aot.aot_intrinsic;
import core.stdc.stdarg;
/* Call llvm constrained floating-point intrinsic */
private LLVMValueRef call_llvm_float_experimental_constrained_intrinsic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_f32, const(char)* intrinsic, ...) {
    va_list param_value_list = void;
    LLVMValueRef ret = void;
    LLVMTypeRef[4] param_types = void; LLVMTypeRef ret_type = is_f32 ? F32_TYPE : F64_TYPE;
    int param_count = (comp_ctx.disable_llvm_intrinsics
                       && aot_intrinsic_check_capability(comp_ctx, intrinsic))
                          ? 2
                          : 4;
    param_types[0] = param_types[1] = ret_type;
    param_types[2] = param_types[3] = MD_TYPE;
    va_start(param_value_list, intrinsic);
    ret = aot_call_llvm_intrinsic_v(comp_ctx, func_ctx, intrinsic, ret_type,
                                    param_types.ptr, param_count, param_value_list);
    va_end(param_value_list);
    return ret;
}
/* Call llvm constrained libm-equivalent intrinsic */
private LLVMValueRef call_llvm_libm_experimental_constrained_intrinsic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_f32, const(char)* intrinsic, ...) {
    va_list param_value_list = void;
    LLVMValueRef ret = void;
    LLVMTypeRef[3] param_types = void; LLVMTypeRef ret_type = is_f32 ? F32_TYPE : F64_TYPE;
    param_types[0] = ret_type;
    param_types[1] = param_types[2] = MD_TYPE;
    va_start(param_value_list, intrinsic);
    ret = aot_call_llvm_intrinsic_v(comp_ctx, func_ctx, intrinsic, ret_type,
                                    param_types.ptr, 3, param_value_list);
    va_end(param_value_list);
    return ret;
}
private LLVMValueRef compile_op_float_min_max(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_f32, LLVMValueRef left, LLVMValueRef right, bool is_min) {
    LLVMTypeRef[2] param_types = void; LLVMTypeRef ret_type = is_f32 ? F32_TYPE : F64_TYPE, int_type = is_f32 ? I32_TYPE : I64_TYPE;
    LLVMValueRef cmp = void, is_eq = void, is_nan = void, ret = void, left_int = void, right_int = void, tmp = void, nan = LLVMConstRealOfString(ret_type, "NaN");
    char* intrinsic = is_min ? (is_f32 ? "llvm.minnum.f32" : "llvm.minnum.f64")
                             : (is_f32 ? "llvm.maxnum.f32" : "llvm.maxnum.f64");
    CHECK_LLVM_CONST(nan);
    param_types[0] = param_types[1] = ret_type;
    if (comp_ctx.disable_llvm_intrinsics
        && aot_intrinsic_check_capability(comp_ctx,
                                          is_f32 ? "f32_cmp" : "f64_cmp")) {
        LLVMTypeRef[3] param_types_intrinsic = void;
        LLVMValueRef opcond = LLVMConstInt(I32_TYPE, FLOAT_UNO, true);
        param_types_intrinsic[0] = I32_TYPE;
        param_types_intrinsic[1] = is_f32 ? F32_TYPE : F64_TYPE;
        param_types_intrinsic[2] = param_types_intrinsic[1];
        is_nan = aot_call_llvm_intrinsic(
            comp_ctx, func_ctx, is_f32 ? "f32_cmp" : "f64_cmp", I32_TYPE,
            param_types_intrinsic.ptr, 3, opcond, left, right);
        opcond = LLVMConstInt(I32_TYPE, FLOAT_EQ, true);
        is_eq = aot_call_llvm_intrinsic(
            comp_ctx, func_ctx, is_f32 ? "f32_cmp" : "f64_cmp", I32_TYPE,
            param_types_intrinsic.ptr, 3, opcond, left, right);
        if (!is_nan || !is_eq) {
            return null;
        }
        if (((is_nan = LLVMBuildIntCast(comp_ctx.builder, is_nan, INT1_TYPE,
                                        "bit_cast_is_nan")) == 0)) {
            aot_set_last_error("llvm build is_nan bit cast fail.");
            return null;
        }
        if (((is_eq = LLVMBuildIntCast(comp_ctx.builder, is_eq, INT1_TYPE,
                                       "bit_cast_is_eq")) == 0)) {
            aot_set_last_error("llvm build is_eq bit cast fail.");
            return null;
        }
    }
    else if (((is_nan = LLVMBuildFCmp(comp_ctx.builder, LLVMRealUNO, left,
                                      right, "is_nan")) == 0)
             || ((is_eq = LLVMBuildFCmp(comp_ctx.builder, LLVMRealOEQ, left,
                                        right, "is_eq")) == 0)) {
        aot_set_last_error("llvm build fcmp fail.");
        return null;
    }
    /* If left and right are equal, they may be zero with different sign.
       Webassembly spec assert -0 < +0. So do a bitwise here. */
    if (((left_int =
              LLVMBuildBitCast(comp_ctx.builder, left, int_type, "left_int")) == 0)
        || ((right_int = LLVMBuildBitCast(comp_ctx.builder, right, int_type,
                                          "right_int")) == 0)) {
        aot_set_last_error("llvm build bitcast fail.");
        return null;
    }
    if (is_min)
        do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_f32 ? "i32.or" : "i64.or")) { tmp = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_f32 ? "i32.or" : "i64.or", param_types[0], param_types.ptr, 2, left_int, right_int); } else { do { if (((tmp = LLVMBuildOr(comp_ctx.builder, left_int, right_int, "tmp_int")) == 0)) { aot_set_last_error("llvm build " ~ "\"tmp_int\"" ~ " fail."); return false; } } while (0); } } while (0);
    else
        do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_f32 ? "i32.and" : "i64.and")) { tmp = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_f32 ? "i32.and" : "i64.and", param_types[0], param_types.ptr, 2, left_int, right_int); } else { do { if (((tmp = LLVMBuildAnd(comp_ctx.builder, left_int, right_int, "tmp_int")) == 0)) { aot_set_last_error("llvm build " ~ "\"tmp_int\"" ~ " fail."); return false; } } while (0); } } while (0);
    if (((tmp = LLVMBuildBitCast(comp_ctx.builder, tmp, ret_type, "tmp")) == 0)) {
        aot_set_last_error("llvm build bitcast fail.");
        return null;
    }
    if (((cmp = aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic, ret_type,
                                        param_types.ptr, 2, left, right)) == 0))
        return null;
    if (((cmp = LLVMBuildSelect(comp_ctx.builder, is_eq, tmp, cmp, "cmp")) == 0)) {
        aot_set_last_error("llvm build select fail.");
        return null;
    }
    if (((ret = LLVMBuildSelect(comp_ctx.builder, is_nan, nan, cmp,
                                is_min ? "min" : "max")) == 0)) {
        aot_set_last_error("llvm build select fail.");
        return null;
    }
    return ret;
fail:
    return null;
}
enum BitCountType {
    CLZ32 = 0,
    CLZ64,
    CTZ32,
    CTZ64,
    POP_CNT32,
    POP_CNT64
}
alias CLZ32 = BitCountType.CLZ32;
alias CLZ64 = BitCountType.CLZ64;
alias CTZ32 = BitCountType.CTZ32;
alias CTZ64 = BitCountType.CTZ64;
alias POP_CNT32 = BitCountType.POP_CNT32;
alias POP_CNT64 = BitCountType.POP_CNT64;

/* clang-format off */
immutable bit_cnt_llvm_intrinsic = [
    "llvm.ctlz.i32",
    "llvm.ctlz.i64",
    "llvm.cttz.i32",
    "llvm.cttz.i64",
    "llvm.ctpop.i32",
    "llvm.ctpop.i64",
];
/* clang-format on */
private bool aot_compile_int_bit_count(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, BitCountType type, bool is_i32) {
    LLVMValueRef zero_undef = void;
    LLVMTypeRef ret_type = void; LLVMTypeRef[2] param_types = void;
    param_types[0] = ret_type = is_i32 ? I32_TYPE : I64_TYPE;
    param_types[1] = LLVMInt1TypeInContext(comp_ctx.context);
    zero_undef = LLVMConstInt(param_types[1], false, true);
    CHECK_LLVM_CONST(zero_undef);
    /* Call the LLVM intrinsic function */
    if (type < POP_CNT32)
        do { LLVMValueRef res = void, operand = void; do { if (is_i32) POP_I32(operand); else POP_I64(operand); } while (0); if (((res = aot_call_llvm_intrinsic( comp_ctx, func_ctx, bit_cnt_llvm_intrinsic[type], ret_type, param_types.ptr, 2, operand, zero_undef)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
    else
        do { LLVMValueRef res = void, operand = void; do { if (is_i32) POP_I32(operand); else POP_I64(operand); } while (0); if (((res = aot_call_llvm_intrinsic( comp_ctx, func_ctx, bit_cnt_llvm_intrinsic[type], ret_type, param_types.ptr, 1, operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
    return true;
fail:
    return false;
}
private bool compile_rems(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMValueRef left, LLVMValueRef right, LLVMValueRef overflow_cond, bool is_i32) {
    LLVMValueRef phi = void, no_overflow_value = void, zero = is_i32 ? I32_ZERO : I64_ZERO;
    LLVMBasicBlockRef block_curr = void, no_overflow_block = void, rems_end_block = void;
    LLVMTypeRef[2] param_types = void;
    param_types[1] = param_types[0] = is_i32 ? I32_TYPE : I64_TYPE;
    block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    /* Add 2 blocks: no_overflow_block and rems_end block */
    do { if (((rems_end_block = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "rems_end")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } LLVMMoveBasicBlockAfter(rems_end_block, LLVMGetInsertBlock(comp_ctx.builder)); } while (0);
    do { if (((no_overflow_block = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "rems_no_overflow")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } LLVMMoveBasicBlockAfter(no_overflow_block, LLVMGetInsertBlock(comp_ctx.builder)); } while (0);
    /* Create condition br */
    if (!LLVMBuildCondBr(comp_ctx.builder, overflow_cond, rems_end_block,
                         no_overflow_block)) {
        aot_set_last_error("llvm build cond br failed.");
        return false;
    }
    /* Translate no_overflow_block */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, no_overflow_block);
    do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.rem_s" : "i64.rem_s")) { no_overflow_value = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.rem_s" : "i64.rem_s", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((no_overflow_value = LLVMBuildSRem(comp_ctx.builder, left, right, "rem_s")) == 0)) { aot_set_last_error("llvm build " ~ "\"rem_s\"" ~ " fail."); return false; } } while (0); } } while (0);
    /* Jump to rems_end block */
    if (!LLVMBuildBr(comp_ctx.builder, rems_end_block)) {
        aot_set_last_error("llvm build br failed.");
        return false;
    }
    /* Translate rems_end_block */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, rems_end_block);
    /* Create result phi */
    if (((phi = LLVMBuildPhi(comp_ctx.builder, is_i32 ? I32_TYPE : I64_TYPE,
                             "rems_result_phi")) == 0)) {
        aot_set_last_error("llvm build phi failed.");
        return false;
    }
    /* Add phi incoming values */
    LLVMAddIncoming(phi, &no_overflow_value, &no_overflow_block, 1);
    LLVMAddIncoming(phi, &zero, &block_curr, 1);
    if (is_i32)
        PUSH_I32(phi);
    else
        PUSH_I64(phi);
    return true;
fail:
    return false;
}
private bool compile_int_div(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntArithmetic arith_op, bool is_i32, ubyte** p_frame_ip) {
    LLVMValueRef left = void, right = void, cmp_div_zero = void, overflow = void, res = void;
    LLVMBasicBlockRef check_div_zero_succ = void, check_overflow_succ = void;
    LLVMTypeRef[2] param_types = void;
    const(char)* intrinsic = null;
    param_types[1] = param_types[0] = is_i32 ? I32_TYPE : I64_TYPE;
    bh_assert(arith_op == INT_DIV_S || arith_op == INT_DIV_U
              || arith_op == INT_REM_S || arith_op == INT_REM_U);
    do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0);
    do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0);
    if (LLVMIsUndef(right) || LLVMIsUndef(left)
    ) {
        if (!(aot_emit_exception(comp_ctx, func_ctx, EXCE_INTEGER_OVERFLOW,
                                 false, null, null))) {
            goto fail;
        }
        return aot_handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
    }
    if (LLVMIsConstant(right)) {
        long right_val = cast(long)LLVMConstIntGetSExtValue(right);
        switch (right_val) {
            case 0:
                /* Directly throw exception if divided by zero */
                if (!(aot_emit_exception(comp_ctx, func_ctx,
                                         EXCE_INTEGER_DIVIDE_BY_ZERO, false,
                                         null, null)))
                    goto fail;
                return aot_handle_next_reachable_block(comp_ctx, func_ctx,
                                                       p_frame_ip);
            case 1:
                if (arith_op == INT_DIV_S || arith_op == INT_DIV_U)
                    do { if (is_i32) PUSH_I32(left); else PUSH_I64(left); } while (0);
                else
                    do { if (is_i32) PUSH_I32(is_i32 ? I32_ZERO : I64_ZERO); else PUSH_I64(is_i32 ? I32_ZERO : I64_ZERO); } while (0);
                return true;
            case -1:
                if (arith_op == INT_DIV_S) {
                    do { if (((overflow = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, left, is_i32 ? I32_MIN : I64_MIN, "overflow")) == 0)) { aot_set_last_error("llvm build " ~ "overflow" ~ " fail."); return false; } } while (0);
                    do { if (((check_overflow_succ = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "check_overflow_success")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } LLVMMoveBasicBlockAfter(check_overflow_succ, LLVMGetInsertBlock(comp_ctx.builder)); } while (0);
                    /* Throw conditional exception if overflow */
                    if (!(aot_emit_exception(comp_ctx, func_ctx,
                                             EXCE_INTEGER_OVERFLOW, true,
                                             overflow, check_overflow_succ)))
                        goto fail;
                    /* Push -(left) to stack */
                    if (((res = LLVMBuildNeg(comp_ctx.builder, left, "neg")) == 0)) {
                        aot_set_last_error("llvm build neg fail.");
                        return false;
                    }
                    do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0);
                    return true;
                }
                else if (arith_op == INT_REM_S) {
                    do { if (is_i32) PUSH_I32(is_i32 ? I32_ZERO : I64_ZERO); else PUSH_I64(is_i32 ? I32_ZERO : I64_ZERO); } while (0);
                    return true;
                }
                else {
                    /* fall to default */
                    goto handle_default;
                }
            handle_default:
            default:
                /* Build div */
                switch (arith_op) {
                    case INT_DIV_S:
                        do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.div_s" : "i64.div_s")) { res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.div_s" : "i64.div_s", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((res = LLVMBuildSDiv(comp_ctx.builder, left, right, "div_s")) == 0)) { aot_set_last_error("llvm build " ~ "\"div_s\"" ~ " fail."); return false; } } while (0); } } while (0);
                        break;
                    case INT_DIV_U:
                        do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.div_u" : "i64.div_u")) { res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.div_u" : "i64.div_u", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((res = LLVMBuildUDiv(comp_ctx.builder, left, right, "div_u")) == 0)) { aot_set_last_error("llvm build " ~ "\"div_u\"" ~ " fail."); return false; } } while (0); } } while (0);
                        break;
                    case INT_REM_S:
                        do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.rem_s" : "i64.rem_s")) { res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.rem_s" : "i64.rem_s", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((res = LLVMBuildSRem(comp_ctx.builder, left, right, "rem_s")) == 0)) { aot_set_last_error("llvm build " ~ "\"rem_s\"" ~ " fail."); return false; } } while (0); } } while (0);
                        break;
                    case INT_REM_U:
                        do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.rem_u" : "i64.rem_u")) { res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.rem_u" : "i64.rem_u", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((res = LLVMBuildURem(comp_ctx.builder, left, right, "rem_u")) == 0)) { aot_set_last_error("llvm build " ~ "\"rem_u\"" ~ " fail."); return false; } } while (0); } } while (0);
                        break;
                    default:
                        bh_assert(0);
                        return false;
                }
                do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0);
                return true;
        }
    }
    else {
        /* Check divied by zero */
        do { if (((cmp_div_zero = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, right, is_i32 ? I32_ZERO : I64_ZERO, "cmp_div_zero")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_div_zero" ~ " fail."); return false; } } while (0);
        do { if (((check_div_zero_succ = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "check_div_zero_success")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } LLVMMoveBasicBlockAfter(check_div_zero_succ, LLVMGetInsertBlock(comp_ctx.builder)); } while (0);
        /* Throw conditional exception if divided by zero */
        if (!(aot_emit_exception(comp_ctx, func_ctx,
                                 EXCE_INTEGER_DIVIDE_BY_ZERO, true,
                                 cmp_div_zero, check_div_zero_succ)))
            goto fail;
        switch (arith_op) {
            case INT_DIV_S:
                /* Check integer overflow */
                if (is_i32)
                    do { LLVMValueRef cmp_min_int = void, cmp_neg_one = void; do { if (((cmp_min_int = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, left, I32_MIN, "cmp_min_int")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_min_int" ~ " fail."); return false; } } while (0); do { if (((cmp_neg_one = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, right, I32_NEG_ONE, "cmp_neg_one")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_neg_one" ~ " fail."); return false; } } while (0); do { if (((overflow = LLVMBuildAnd(comp_ctx.builder, cmp_min_int, cmp_neg_one, "overflow")) == 0)) { aot_set_last_error("llvm build " ~ "\"overflow\"" ~ " fail."); return false; } } while (0); } while (0);
                else
                    do { LLVMValueRef cmp_min_int = void, cmp_neg_one = void; do { if (((cmp_min_int = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, left, I64_MIN, "cmp_min_int")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_min_int" ~ " fail."); return false; } } while (0); do { if (((cmp_neg_one = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, right, I64_NEG_ONE, "cmp_neg_one")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_neg_one" ~ " fail."); return false; } } while (0); do { if (((overflow = LLVMBuildAnd(comp_ctx.builder, cmp_min_int, cmp_neg_one, "overflow")) == 0)) { aot_set_last_error("llvm build " ~ "\"overflow\"" ~ " fail."); return false; } } while (0); } while (0);
                do { if (((check_overflow_succ = LLVMAppendBasicBlockInContext(comp_ctx.context, func_ctx.func, "check_overflow_success")) == 0)) { aot_set_last_error("llvm add basic block failed."); goto fail; } LLVMMoveBasicBlockAfter(check_overflow_succ, LLVMGetInsertBlock(comp_ctx.builder)); } while (0);
                /* Throw conditional exception if integer overflow */
                if (!(aot_emit_exception(comp_ctx, func_ctx,
                                         EXCE_INTEGER_OVERFLOW, true, overflow,
                                         check_overflow_succ)))
                    goto fail;
                do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.div_s" : "i64.div_s")) { res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.div_s" : "i64.div_s", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((res = LLVMBuildSDiv(comp_ctx.builder, left, right, "div_s")) == 0)) { aot_set_last_error("llvm build " ~ "\"div_s\"" ~ " fail."); return false; } } while (0); } } while (0);
                do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0);
                return true;
            case INT_DIV_U:
                intrinsic = is_i32 ? "i32.div_u" : "i64.div_u";
                if (comp_ctx.disable_llvm_intrinsics
                    && aot_intrinsic_check_capability(comp_ctx, intrinsic)) {
                    res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic,
                                                  param_types[0], param_types.ptr,
                                                  2, left, right);
                }
                else {
                    do { if (((res = LLVMBuildUDiv(comp_ctx.builder, left, right, "div_u")) == 0)) { aot_set_last_error("llvm build " ~ "\"div_u\"" ~ " fail."); return false; } } while (0);
                }
                do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0);
                return true;
            case INT_REM_S:
                /*  Webassembly spec requires it return 0 */
                if (is_i32)
                    do { LLVMValueRef cmp_min_int = void, cmp_neg_one = void; do { if (((cmp_min_int = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, left, I32_MIN, "cmp_min_int")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_min_int" ~ " fail."); return false; } } while (0); do { if (((cmp_neg_one = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, right, I32_NEG_ONE, "cmp_neg_one")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_neg_one" ~ " fail."); return false; } } while (0); do { if (((overflow = LLVMBuildAnd(comp_ctx.builder, cmp_min_int, cmp_neg_one, "overflow")) == 0)) { aot_set_last_error("llvm build " ~ "\"overflow\"" ~ " fail."); return false; } } while (0); } while (0);
                else
                    do { LLVMValueRef cmp_min_int = void, cmp_neg_one = void; do { if (((cmp_min_int = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, left, I64_MIN, "cmp_min_int")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_min_int" ~ " fail."); return false; } } while (0); do { if (((cmp_neg_one = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, right, I64_NEG_ONE, "cmp_neg_one")) == 0)) { aot_set_last_error("llvm build " ~ "cmp_neg_one" ~ " fail."); return false; } } while (0); do { if (((overflow = LLVMBuildAnd(comp_ctx.builder, cmp_min_int, cmp_neg_one, "overflow")) == 0)) { aot_set_last_error("llvm build " ~ "\"overflow\"" ~ " fail."); return false; } } while (0); } while (0);
                return compile_rems(comp_ctx, func_ctx, left, right, overflow,
                                    is_i32);
            case INT_REM_U:
                do { if (comp_ctx.disable_llvm_intrinsics && aot_intrinsic_check_capability(comp_ctx, is_i32 ? "i32.rem_u" : "i64.rem_u")) { res = aot_call_llvm_intrinsic(comp_ctx, func_ctx, is_i32 ? "i32.rem_u" : "i64.rem_u", param_types[0], param_types.ptr, 2, left, right); } else { do { if (((res = LLVMBuildURem(comp_ctx.builder, left, right, "rem_u")) == 0)) { aot_set_last_error("llvm build " ~ "\"rem_u\"" ~ " fail."); return false; } } while (0); } } while (0);
                do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0);
                return true;
            default:
                bh_assert(0);
                return false;
        }
    }
fail:
    return false;
}
private LLVMValueRef compile_int_add(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_i32) {
    /* If one of the operands is 0, just return the other */
    if ((!LLVMIsUndef(left) && LLVMIsConstant(left) && ((is_i32 && cast(int)LLVMConstIntGetZExtValue(left) == 0) || (!is_i32 && cast(long)LLVMConstIntGetSExtValue(left) == 0))))
        return right;
    if ((!LLVMIsUndef(right) && LLVMIsConstant(right) && ((is_i32 && cast(int)LLVMConstIntGetZExtValue(right) == 0) || (!is_i32 && cast(long)LLVMConstIntGetSExtValue(right) == 0))))
        return left;
    /* Build add */
    return LLVMBuildAdd(comp_ctx.builder, left, right, "add");
}
private LLVMValueRef compile_int_sub(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_i32) {
    /* If the right operand is 0, just return the left */
    if ((!LLVMIsUndef(right) && LLVMIsConstant(right) && ((is_i32 && cast(int)LLVMConstIntGetZExtValue(right) == 0) || (!is_i32 && cast(long)LLVMConstIntGetSExtValue(right) == 0))))
        return left;
    /* Build sub */
    return LLVMBuildSub(comp_ctx.builder, left, right, "sub");
}
private LLVMValueRef compile_int_mul(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_i32) {
    /* If one of the operands is 0, just return constant 0 */
    if ((!LLVMIsUndef(left) && LLVMIsConstant(left) && ((is_i32 && cast(int)LLVMConstIntGetZExtValue(left) == 0) || (!is_i32 && cast(long)LLVMConstIntGetSExtValue(left) == 0))) || (!LLVMIsUndef(right) && LLVMIsConstant(right) && ((is_i32 && cast(int)LLVMConstIntGetZExtValue(right) == 0) || (!is_i32 && cast(long)LLVMConstIntGetSExtValue(right) == 0))))
        return is_i32 ? I32_ZERO : I64_ZERO;
    /* Build mul */
    return LLVMBuildMul(comp_ctx.builder, left, right, "mul");
}
private bool compile_op_int_arithmetic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntArithmetic arith_op, bool is_i32, ubyte** p_frame_ip) {
    switch (arith_op) {
        case INT_ADD:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_add(comp_ctx, left, right, is_i32)) == 0)) { if ("compile int add fail.") aot_set_last_error("compile int add fail."); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_SUB:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_sub(comp_ctx, left, right, is_i32)) == 0)) { if ("compile int sub fail.") aot_set_last_error("compile int sub fail."); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_MUL:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_mul(comp_ctx, left, right, is_i32)) == 0)) { if ("compile int mul fail.") aot_set_last_error("compile int mul fail."); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_DIV_S:
        case INT_DIV_U:
        case INT_REM_S:
        case INT_REM_U:
            return compile_int_div(comp_ctx, func_ctx, arith_op, is_i32,
                                   p_frame_ip);
        default:
            bh_assert(0);
            return false;
    }
fail:
    return false;
}
private bool compile_op_int_bitwise(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntBitwise bitwise_op, bool is_i32) {
    switch (bitwise_op) {
        case INT_AND:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = LLVMBuildAnd(comp_ctx.builder, left, right, "and")) == 0)) { if ("llvm build and fail.") aot_set_last_error("llvm build and fail."); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_OR:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = LLVMBuildOr(comp_ctx.builder, left, right, "or")) == 0)) { if ("llvm build or fail.") aot_set_last_error("llvm build or fail."); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_XOR:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = LLVMBuildXor(comp_ctx.builder, left, right, "xor")) == 0)) { if ("llvm build xor fail.") aot_set_last_error("llvm build xor fail."); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        default:
            bh_assert(0);
            return false;
    }
fail:
    return false;
}
private LLVMValueRef compile_int_shl(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_i32) {
    LLVMValueRef res = void;
    if (strcmp(comp_ctx.target_arch, "x86_64") != 0
        && strcmp(comp_ctx.target_arch, "i386") != 0)
        do { /* LLVM has undefined behavior if shift count is greater than           *  bits count while Webassembly spec requires the shift count          *  be wrapped.                                                         */ LLVMValueRef shift_count_mask = void, bits_minus_one = void; bits_minus_one = is_i32 ? I32_31 : I64_63; do { if (((shift_count_mask = LLVMBuildAnd(comp_ctx.builder, right, bits_minus_one, "shift_count_mask")) == 0)) { aot_set_last_error("llvm build " ~ "\"shift_count_mask\"" ~ " fail."); return null; } } while (0); right = shift_count_mask; } while (0);
    /* Build shl */
    do { if (((res = LLVMBuildShl(comp_ctx.builder, left, right, "shl")) == 0)) { aot_set_last_error("llvm build " ~ "\"shl\"" ~ " fail."); return null; } } while (0);
    return res;
}
private LLVMValueRef compile_int_shr_s(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_i32) {
    LLVMValueRef res = void;
    if (strcmp(comp_ctx.target_arch, "x86_64") != 0
        && strcmp(comp_ctx.target_arch, "i386") != 0)
        do { /* LLVM has undefined behavior if shift count is greater than           *  bits count while Webassembly spec requires the shift count          *  be wrapped.                                                         */ LLVMValueRef shift_count_mask = void, bits_minus_one = void; bits_minus_one = is_i32 ? I32_31 : I64_63; do { if (((shift_count_mask = LLVMBuildAnd(comp_ctx.builder, right, bits_minus_one, "shift_count_mask")) == 0)) { aot_set_last_error("llvm build " ~ "\"shift_count_mask\"" ~ " fail."); return null; } } while (0); right = shift_count_mask; } while (0);
    /* Build shl */
    do { if (((res = LLVMBuildAShr(comp_ctx.builder, left, right, "shr_s")) == 0)) { aot_set_last_error("llvm build " ~ "\"shr_s\"" ~ " fail."); return null; } } while (0);
    return res;
}
private LLVMValueRef compile_int_shr_u(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_i32) {
    LLVMValueRef res = void;
    if (strcmp(comp_ctx.target_arch, "x86_64") != 0
        && strcmp(comp_ctx.target_arch, "i386") != 0)
        do { /* LLVM has undefined behavior if shift count is greater than           *  bits count while Webassembly spec requires the shift count          *  be wrapped.                                                         */ LLVMValueRef shift_count_mask = void, bits_minus_one = void; bits_minus_one = is_i32 ? I32_31 : I64_63; do { if (((shift_count_mask = LLVMBuildAnd(comp_ctx.builder, right, bits_minus_one, "shift_count_mask")) == 0)) { aot_set_last_error("llvm build " ~ "\"shift_count_mask\"" ~ " fail."); return null; } } while (0); right = shift_count_mask; } while (0);
    /* Build shl */
    do { if (((res = LLVMBuildLShr(comp_ctx.builder, left, right, "shr_u")) == 0)) { aot_set_last_error("llvm build " ~ "\"shr_u\"" ~ " fail."); return null; } } while (0);
    return res;
}
private LLVMValueRef compile_int_rot(AOTCompContext* comp_ctx, LLVMValueRef left, LLVMValueRef right, bool is_rotl, bool is_i32) {
    LLVMValueRef bits_minus_shift_count = void, res = void, tmp_l = void, tmp_r = void;
    char* name = is_rotl ? "rotl" : "rotr";
    do { /* LLVM has undefined behavior if shift count is greater than           *  bits count while Webassembly spec requires the shift count          *  be wrapped.                                                         */ LLVMValueRef shift_count_mask = void, bits_minus_one = void; bits_minus_one = is_i32 ? I32_31 : I64_63; do { if (((shift_count_mask = LLVMBuildAnd(comp_ctx.builder, right, bits_minus_one, "shift_count_mask")) == 0)) { aot_set_last_error("llvm build " ~ "\"shift_count_mask\"" ~ " fail."); return null; } } while (0); right = shift_count_mask; } while (0);
    /* rotl/rotr with 0 */
    if ((!LLVMIsUndef(right) && LLVMIsConstant(right) && ((is_i32 && cast(int)LLVMConstIntGetZExtValue(right) == 0) || (!is_i32 && cast(long)LLVMConstIntGetSExtValue(right) == 0))))
        return left;
    /* Calculate (bits - shif_count) */
    do { if (((bits_minus_shift_count = LLVMBuildSub(comp_ctx.builder, is_i32 ? I32_32 : I64_64, right, "bits_minus_shift_count")) == 0)) { aot_set_last_error("llvm build " ~ "\"bits_minus_shift_count\"" ~ " fail."); return null; } } while (0);
    if (is_rotl) {
        /* left<<count | left>>(BITS-count) */
        do { if (((tmp_l = LLVMBuildShl(comp_ctx.builder, left, right, "tmp_l")) == 0)) { aot_set_last_error("llvm build " ~ "\"tmp_l\"" ~ " fail."); return null; } } while (0);
        do { if (((tmp_r = LLVMBuildLShr(comp_ctx.builder, left, bits_minus_shift_count, "tmp_r")) == 0)) { aot_set_last_error("llvm build " ~ "\"tmp_r\"" ~ " fail."); return null; } } while (0);
    }
    else {
        /* left>>count | left<<(BITS-count) */
        do { if (((tmp_l = LLVMBuildLShr(comp_ctx.builder, left, right, "tmp_l")) == 0)) { aot_set_last_error("llvm build " ~ "\"tmp_l\"" ~ " fail."); return null; } } while (0);
        do { if (((tmp_r = LLVMBuildShl(comp_ctx.builder, left, bits_minus_shift_count, "tmp_r")) == 0)) { aot_set_last_error("llvm build " ~ "\"tmp_r\"" ~ " fail."); return null; } } while (0);
    }
    do { if (((res = LLVMBuildOr(comp_ctx.builder, tmp_l, tmp_r, name)) == 0)) { aot_set_last_error("llvm build " ~ "name" ~ " fail."); return null; } } while (0);
    return res;
}
private bool compile_op_int_shift(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntShift shift_op, bool is_i32) {
    switch (shift_op) {
        case INT_SHL:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_shl(comp_ctx, left, right, is_i32)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_SHR_S:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_shr_s(comp_ctx, left, right, is_i32)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_SHR_U:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_shr_u(comp_ctx, left, right, is_i32)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_ROTL:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_rot(comp_ctx, left, right, true, is_i32)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        case INT_ROTR:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_i32) POP_I32(right); else POP_I64(right); } while (0); do { if (is_i32) POP_I32(left); else POP_I64(left); } while (0); if (((res = compile_int_rot(comp_ctx, left, right, false, is_i32)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_i32) PUSH_I32(res); else PUSH_I64(res); } while (0); } while (0);
            return true;
        default:
            bh_assert(0);
            return false;
    }
fail:
    return false;
}
private bool is_target_arm(AOTCompContext* comp_ctx) {
    return !strncmp(comp_ctx.target_arch, "arm", 3)
           || !strncmp(comp_ctx.target_arch, "aarch64", 7)
           || !strncmp(comp_ctx.target_arch, "thumb", 5);
}
private bool is_target_x86(AOTCompContext* comp_ctx) {
    return !strncmp(comp_ctx.target_arch, "x86_64", 6)
           || !strncmp(comp_ctx.target_arch, "i386", 4);
}
private bool is_target_xtensa(AOTCompContext* comp_ctx) {
    return !strncmp(comp_ctx.target_arch, "xtensa", 6);
}
private bool is_target_mips(AOTCompContext* comp_ctx) {
    return !strncmp(comp_ctx.target_arch, "mips", 4);
}
private bool is_target_riscv(AOTCompContext* comp_ctx) {
    return !strncmp(comp_ctx.target_arch, "riscv", 5);
}
private bool is_targeting_soft_float(AOTCompContext* comp_ctx, bool is_f32) {
    bool ret = false;
    char* feature_string = void;
    if (((feature_string =
              LLVMGetTargetMachineFeatureString(comp_ctx.target_machine)) == 0)) {
        aot_set_last_error("llvm get target machine feature string fail.");
        return false;
    }
    /* Note:
     * LLVM CodeGen uses FPU Coprocessor registers by default,
     * so user must specify '--cpu-features=+soft-float' to wamrc if the target
     * doesn't have or enable FPU on arm, x86 or mips. */
    if (is_target_arm(comp_ctx) || is_target_x86(comp_ctx)
        || is_target_mips(comp_ctx)) {
        ret = strstr(feature_string, "+soft-float") ? true : false;
    }
    else if (is_target_xtensa(comp_ctx)) {
        /* Note:
         * 1. The Floating-Point Coprocessor Option of xtensa only support
         * single-precision floating-point operations, so must use soft-float
         * for f64(i.e. double).
         * 2. LLVM CodeGen uses Floating-Point Coprocessor registers by default,
         * so user must specify '--cpu-features=-fp' to wamrc if the target
         * doesn't have or enable Floating-Point Coprocessor Option on xtensa.
         */
        if (comp_ctx.disable_llvm_intrinsics)
            ret = false;
        else
            ret = (!is_f32 || strstr(feature_string, "-fp")) ? true : false;
    }
    else if (is_target_riscv(comp_ctx)) {
        /*
         * Note: Use builtin intrinsics since hardware float operation
         * will cause rodata relocation, this will try to use hardware
         * float unit (by return false) but handled by software finally
         */
        if (comp_ctx.disable_llvm_intrinsics)
            ret = false;
        else
            ret = !strstr(feature_string, "+d") ? true : false;
    }
    else {
        ret = true;
    }
    LLVMDisposeMessage(feature_string);
    return ret;
}
private bool compile_op_float_arithmetic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op, bool is_f32) {
    switch (arith_op) {
        case FLOAT_ADD:
            if (is_targeting_soft_float(comp_ctx, is_f32))
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = LLVMBuildFAdd(comp_ctx.builder, left, right, "fadd")) == 0)) { if ("llvm build fadd fail.") aot_set_last_error("llvm build fadd fail."); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            else
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = call_llvm_float_experimental_constrained_intrinsic( comp_ctx, func_ctx, is_f32, (is_f32 ? "llvm.experimental.constrained.fadd.f32" : "llvm.experimental.constrained.fadd.f64"), left, right, comp_ctx.fp_rounding_mode, comp_ctx.fp_exception_behavior)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_SUB:
            if (is_targeting_soft_float(comp_ctx, is_f32))
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = LLVMBuildFSub(comp_ctx.builder, left, right, "fsub")) == 0)) { if ("llvm build fsub fail.") aot_set_last_error("llvm build fsub fail."); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            else
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = call_llvm_float_experimental_constrained_intrinsic( comp_ctx, func_ctx, is_f32, (is_f32 ? "llvm.experimental.constrained.fsub.f32" : "llvm.experimental.constrained.fsub.f64"), left, right, comp_ctx.fp_rounding_mode, comp_ctx.fp_exception_behavior)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_MUL:
            if (is_targeting_soft_float(comp_ctx, is_f32))
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = LLVMBuildFMul(comp_ctx.builder, left, right, "fmul")) == 0)) { if ("llvm build fmul fail.") aot_set_last_error("llvm build fmul fail."); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            else
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = call_llvm_float_experimental_constrained_intrinsic( comp_ctx, func_ctx, is_f32, (is_f32 ? "llvm.experimental.constrained.fmul.f32" : "llvm.experimental.constrained.fmul.f64"), left, right, comp_ctx.fp_rounding_mode, comp_ctx.fp_exception_behavior)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_DIV:
            if (is_targeting_soft_float(comp_ctx, is_f32))
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = LLVMBuildFDiv(comp_ctx.builder, left, right, "fdiv")) == 0)) { if ("llvm build fdiv fail.") aot_set_last_error("llvm build fdiv fail."); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            else
                do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = call_llvm_float_experimental_constrained_intrinsic( comp_ctx, func_ctx, is_f32, (is_f32 ? "llvm.experimental.constrained.fdiv.f32" : "llvm.experimental.constrained.fdiv.f64"), left, right, comp_ctx.fp_rounding_mode, comp_ctx.fp_exception_behavior)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_MIN:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = compile_op_float_min_max( comp_ctx, func_ctx, is_f32, left, right, true)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_MAX:
            do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = compile_op_float_min_max(comp_ctx, func_ctx, is_f32, left, right, false)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        default:
            bh_assert(0);
            return false;
    }
fail:
    return false;
}
private LLVMValueRef call_llvm_float_math_intrinsic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_f32, const(char)* intrinsic, ...) {
    va_list param_value_list = void;
    LLVMValueRef ret = void;
    LLVMTypeRef param_type = void, ret_type = is_f32 ? F32_TYPE : F64_TYPE;
    param_type = ret_type;
    va_start(param_value_list, intrinsic);
    ret = aot_call_llvm_intrinsic_v(comp_ctx, func_ctx, intrinsic, ret_type,
                                    &param_type, 1, param_value_list);
    va_end(param_value_list);
    return ret;
}
private bool compile_op_float_math(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatMath math_op, bool is_f32) {
    switch (math_op) {
        case FLOAT_ABS:
            do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_float_math_intrinsic( comp_ctx, func_ctx, is_f32, is_f32 ? "llvm.fabs.f32" : "llvm.fabs.f64", operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_NEG:
            do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = LLVMBuildFNeg(comp_ctx.builder, operand, "fneg")) == 0)) { if ("llvm build fneg fail.") aot_set_last_error("llvm build fneg fail."); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_CEIL:
            do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_float_math_intrinsic( comp_ctx, func_ctx, is_f32, is_f32 ? "llvm.ceil.f32" : "llvm.ceil.f64", operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_FLOOR:
            do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_float_math_intrinsic( comp_ctx, func_ctx, is_f32, is_f32 ? "llvm.floor.f32" : "llvm.floor.f64", operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_TRUNC:
            do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_float_math_intrinsic( comp_ctx, func_ctx, is_f32, is_f32 ? "llvm.trunc.f32" : "llvm.trunc.f64", operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_NEAREST:
            do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_float_math_intrinsic( comp_ctx, func_ctx, is_f32, is_f32 ? "llvm.rint.f32" : "llvm.rint.f64", operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        case FLOAT_SQRT:
            if (is_targeting_soft_float(comp_ctx, is_f32)
                || comp_ctx.disable_llvm_intrinsics)
                do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_float_math_intrinsic( comp_ctx, func_ctx, is_f32, is_f32 ? "llvm.sqrt.f32" : "llvm.sqrt.f64", operand)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            else
                do { LLVMValueRef res = void, operand = void; do { if (is_f32) POP_F32(operand); else POP_F64(operand); } while (0); if (((res = call_llvm_libm_experimental_constrained_intrinsic( comp_ctx, func_ctx, is_f32, (is_f32 ? "llvm.experimental.constrained.sqrt.f32" : "llvm.experimental.constrained.sqrt.f64"), operand, comp_ctx.fp_rounding_mode, comp_ctx.fp_exception_behavior)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
            return true;
        default:
            bh_assert(0);
            return false;
    }
    return true;
fail:
    return false;
}
private bool compile_float_copysign(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_f32) {
    LLVMTypeRef ret_type = void; LLVMTypeRef[2] param_types = void;
    param_types[0] = param_types[1] = ret_type = is_f32 ? F32_TYPE : F64_TYPE;
    do { LLVMValueRef res = void, left = void, right = void; do { if (is_f32) POP_F32(right); else POP_F64(right); } while (0); do { if (is_f32) POP_F32(left); else POP_F64(left); } while (0); if (((res = aot_call_llvm_intrinsic( comp_ctx, func_ctx, is_f32 ? "llvm.copysign.f32" : "llvm.copysign.f64", ret_type, param_types.ptr, 2, left, right)) == 0)) { if (null) aot_set_last_error(null); return false; } do { if (is_f32) PUSH_F32(res); else PUSH_F64(res); } while (0); } while (0);
    return true;
fail:
    return false;
}
bool aot_compile_op_i32_clz(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return aot_compile_int_bit_count(comp_ctx, func_ctx, CLZ32, true);
}
bool aot_compile_op_i32_ctz(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return aot_compile_int_bit_count(comp_ctx, func_ctx, CTZ32, true);
}
bool aot_compile_op_i32_popcnt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return aot_compile_int_bit_count(comp_ctx, func_ctx, POP_CNT32, true);
}
bool aot_compile_op_i64_clz(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return aot_compile_int_bit_count(comp_ctx, func_ctx, CLZ64, false);
}
bool aot_compile_op_i64_ctz(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return aot_compile_int_bit_count(comp_ctx, func_ctx, CTZ64, false);
}
bool aot_compile_op_i64_popcnt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return aot_compile_int_bit_count(comp_ctx, func_ctx, POP_CNT64, false);
}
bool aot_compile_op_i32_arithmetic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntArithmetic arith_op, ubyte** p_frame_ip) {
    return compile_op_int_arithmetic(comp_ctx, func_ctx, arith_op, true,
                                     p_frame_ip);
}
bool aot_compile_op_i64_arithmetic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntArithmetic arith_op, ubyte** p_frame_ip) {
    return compile_op_int_arithmetic(comp_ctx, func_ctx, arith_op, false,
                                     p_frame_ip);
}
bool aot_compile_op_i32_bitwise(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntBitwise bitwise_op) {
    return compile_op_int_bitwise(comp_ctx, func_ctx, bitwise_op, true);
}
bool aot_compile_op_i64_bitwise(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntBitwise bitwise_op) {
    return compile_op_int_bitwise(comp_ctx, func_ctx, bitwise_op, false);
}
bool aot_compile_op_i32_shift(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntShift shift_op) {
    return compile_op_int_shift(comp_ctx, func_ctx, shift_op, true);
}
bool aot_compile_op_i64_shift(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntShift shift_op) {
    return compile_op_int_shift(comp_ctx, func_ctx, shift_op, false);
}
bool aot_compile_op_f32_math(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatMath math_op) {
    return compile_op_float_math(comp_ctx, func_ctx, math_op, true);
}
bool aot_compile_op_f64_math(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatMath math_op) {
    return compile_op_float_math(comp_ctx, func_ctx, math_op, false);
}
bool aot_compile_op_f32_arithmetic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op) {
    return compile_op_float_arithmetic(comp_ctx, func_ctx, arith_op, true);
}
bool aot_compile_op_f64_arithmetic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op) {
    return compile_op_float_arithmetic(comp_ctx, func_ctx, arith_op, false);
}
bool aot_compile_op_f32_copysign(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return compile_float_copysign(comp_ctx, func_ctx, true);
}
bool aot_compile_op_f64_copysign(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return compile_float_copysign(comp_ctx, func_ctx, false);
}
