module simd_int_arith;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import simd_int_arith;
public import simd_common;
public import ...aot_emit_exception;
public import ......aot.aot_runtime;

private bool simd_integer_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, LLVMTypeRef vector_type) {
    LLVMValueRef lhs = void, rhs = void, result = null;

    if (((rhs =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type, "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "lhs")) == 0)) {
        return false;
    }

    switch (arith_op) {
        case V128_ADD:
            result = LLVMBuildAdd(comp_ctx.builder, lhs, rhs, "sum");
            break;
        case V128_SUB:
            result = LLVMBuildSub(comp_ctx.builder, lhs, rhs, "difference");
            break;
        case V128_MUL:
            result = LLVMBuildMul(comp_ctx.builder, lhs, rhs, "product");
            break;
        default:
            HANDLE_FAILURE("Unsupport arith_op");
            break;
    }

    if (!result) {
        HANDLE_FAILURE("LLVMBuildAdd/LLVMBuildSub/LLVMBuildMul");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op) {
    return simd_integer_arith(comp_ctx, func_ctx, arith_op, V128_i8x16_TYPE);
}

bool aot_compile_simd_i16x8_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op) {
    return simd_integer_arith(comp_ctx, func_ctx, arith_op, V128_i16x8_TYPE);
}

bool aot_compile_simd_i32x4_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op) {
    return simd_integer_arith(comp_ctx, func_ctx, arith_op, V128_i32x4_TYPE);
}

bool aot_compile_simd_i64x2_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op) {
    return simd_integer_arith(comp_ctx, func_ctx, arith_op, V128_i64x2_TYPE);
}

private bool simd_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef type) {
    LLVMValueRef vector = void, result = void;

    if (((vector =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, type, "vector")) == 0)) {
        return false;
    }

    if (((result = LLVMBuildNeg(comp_ctx.builder, vector, "neg")) == 0)) {
        HANDLE_FAILURE("LLVMBuildNeg");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_neg(comp_ctx, func_ctx, V128_i8x16_TYPE);
}

bool aot_compile_simd_i16x8_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_neg(comp_ctx, func_ctx, V128_i16x8_TYPE);
}

bool aot_compile_simd_i32x4_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_neg(comp_ctx, func_ctx, V128_i32x4_TYPE);
}

bool aot_compile_simd_i64x2_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_neg(comp_ctx, func_ctx, V128_i64x2_TYPE);
}

bool aot_compile_simd_i8x16_popcnt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef vector = void, result = void;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_i8x16_TYPE, "vector")) == 0)) {
        return false;
    }

    if (((result = aot_call_llvm_intrinsic(comp_ctx, func_ctx,
                                           "llvm.ctpop.v16i8", V128_i8x16_TYPE,
                                           &V128_i8x16_TYPE, 1, vector)) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

private bool simd_v128_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef vector_type, V128Arithmetic arith_op, bool is_signed) {
    LLVMValueRef lhs = void, rhs = void, result = void;
    LLVMIntPredicate op = void;

    if (((rhs =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type, "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "lhs")) == 0)) {
        return false;
    }

    if (V128_MIN == arith_op) {
        op = is_signed ? LLVMIntSLT : LLVMIntULT;
    }
    else {
        op = is_signed ? LLVMIntSGT : LLVMIntUGT;
    }

    if (((result = LLVMBuildICmp(comp_ctx.builder, op, lhs, rhs, "cmp")) == 0)) {
        HANDLE_FAILURE("LLVMBuildICmp");
        return false;
    }

    if (((result =
              LLVMBuildSelect(comp_ctx.builder, result, lhs, rhs, "select")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSelect");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed) {
    return simd_v128_cmp(comp_ctx, func_ctx, V128_i8x16_TYPE, arith_op,
                         is_signed);
}

bool aot_compile_simd_i16x8_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed) {
    return simd_v128_cmp(comp_ctx, func_ctx, V128_i16x8_TYPE, arith_op,
                         is_signed);
}

bool aot_compile_simd_i32x4_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed) {
    return simd_v128_cmp(comp_ctx, func_ctx, V128_i32x4_TYPE, arith_op,
                         is_signed);
}

/* llvm.abs.* */
private bool simd_v128_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, char* intrinsic, LLVMTypeRef vector_type) {
    LLVMValueRef vector = void, result = void;
    LLVMTypeRef[2] param_types = [ vector_type, INT1_TYPE ];

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "vec")) == 0)) {
        return false;
    }

    if (((result = aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic,
                                           vector_type, param_types.ptr, 2, vector,
                                           /* is_int_min_poison */
                                           LLVM_CONST(i1_zero))) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_abs(comp_ctx, func_ctx, "llvm.abs.v16i8", V128_i8x16_TYPE);
}

bool aot_compile_simd_i16x8_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_abs(comp_ctx, func_ctx, "llvm.abs.v8i16", V128_i16x8_TYPE);
}

bool aot_compile_simd_i32x4_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_abs(comp_ctx, func_ctx, "llvm.abs.v4i32", V128_i32x4_TYPE);
}

bool aot_compile_simd_i64x2_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_abs(comp_ctx, func_ctx, "llvm.abs.v2i64", V128_i64x2_TYPE);
}

enum integer_avgr_u {
    e_avgr_u_i8x16,
    e_avgr_u_i16x8,
    e_avgr_u_i32x4,
}
alias e_avgr_u_i8x16 = integer_avgr_u.e_avgr_u_i8x16;
alias e_avgr_u_i16x8 = integer_avgr_u.e_avgr_u_i16x8;
alias e_avgr_u_i32x4 = integer_avgr_u.e_avgr_u_i32x4;


/* TODO: try int_x86_mmx_pavg_b and int_x86_mmx_pavg_w */
/* (v1 + v2 + 1) / 2 */
private bool simd_v128_avg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, integer_avgr_u itype) {
    LLVMValueRef lhs = void, rhs = void, ones = void, result = void;
    LLVMTypeRef vector_ext_type = void;
    LLVMTypeRef[4] vector_type = [
        V128_i8x16_TYPE,
        V128_i16x8_TYPE,
        V128_i32x4_TYPE,
    ];
    uint[3] lanes = [ 16, 8, 4 ];

    if (((rhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                          vector_type[itype], "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             vector_type[itype], "lhs")) == 0)) {
        return false;
    }

    if (((vector_ext_type = LLVMVectorType(I64_TYPE, lanes[itype])) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        return false;
    }

    if (((lhs = LLVMBuildZExt(comp_ctx.builder, lhs, vector_ext_type,
                              "zext_to_i64")) == 0)
        || ((rhs = LLVMBuildZExt(comp_ctx.builder, rhs, vector_ext_type,
                                 "zext_to_i64")) == 0)) {
        HANDLE_FAILURE("LLVMBuildZExt");
        return false;
    }

    /* by default, add will do signed/unsigned overflow */
    if (((result = LLVMBuildAdd(comp_ctx.builder, lhs, rhs, "l_add_r")) == 0)) {
        HANDLE_FAILURE("LLVMBuildAdd");
        return false;
    }

    if (((ones = simd_build_splat_const_integer_vector(comp_ctx, I64_TYPE, 1,
                                                       lanes[itype])) == 0)) {
        return false;
    }

    if (((result = LLVMBuildAdd(comp_ctx.builder, result, ones, "plus_1")) == 0)) {
        HANDLE_FAILURE("LLVMBuildAdd");
        return false;
    }

    if (((result = LLVMBuildLShr(comp_ctx.builder, result, ones, "avg")) == 0)) {
        HANDLE_FAILURE("LLVMBuildLShr");
        return false;
    }

    if (((result = LLVMBuildTrunc(comp_ctx.builder, result, vector_type[itype],
                                  "to_orig_type")) == 0)) {
        HANDLE_FAILURE("LLVMBuildTrunc");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_avgr_u(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_avg(comp_ctx, func_ctx, e_avgr_u_i8x16);
}

bool aot_compile_simd_i16x8_avgr_u(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_avg(comp_ctx, func_ctx, e_avgr_u_i16x8);
}

bool aot_compile_simd_i32x4_avgr_u(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_avg(comp_ctx, func_ctx, e_avgr_u_i32x4);
}

bool aot_compile_simd_i32x4_dot_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef vec1 = void, vec2 = void, even_mask = void, odd_mask = void, zero = void, result = void;
    LLVMTypeRef vector_ext_type = void;
    LLVMValueRef[5] even_element = [
        LLVM_CONST(i32_zero),
        LLVM_CONST(i32_two),
        LLVM_CONST(i32_four),
        LLVM_CONST(i32_six),
    ];
    LLVMValueRef[5] odd_element = [
        LLVM_CONST(i32_one),
        LLVM_CONST(i32_three),
        LLVM_CONST(i32_five),
        LLVM_CONST(i32_seven),
    ];

    if (((vec1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, V128_i16x8_TYPE,
                                           "vec1")) == 0)
        || ((vec2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                              V128_i16x8_TYPE, "vec2")) == 0)) {
        return false;
    }

    if (((vector_ext_type = LLVMVectorType(I32_TYPE, 8)) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        return false;
    }

    /* sext <v8i16> to <v8i32> */
    if (((vec1 = LLVMBuildSExt(comp_ctx.builder, vec1, vector_ext_type,
                               "vec1_v8i32")) == 0)
        || ((vec2 = LLVMBuildSExt(comp_ctx.builder, vec2, vector_ext_type,
                                  "vec2_v8i32")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSExt");
        return false;
    }

    if (((result = LLVMBuildMul(comp_ctx.builder, vec1, vec2, "product")) == 0)) {
        HANDLE_FAILURE("LLVMBuildMul");
        return false;
    }

    /* pick elements with even indexes and odd indexes */
    if (((even_mask = LLVMConstVector(even_element.ptr, 4)) == 0)
        || ((odd_mask = LLVMConstVector(odd_element.ptr, 4)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        return false;
    }

    if (((zero = simd_build_splat_const_integer_vector(comp_ctx, I32_TYPE, 0,
                                                       8)) == 0)) {
        return false;
    }

    if (((vec1 = LLVMBuildShuffleVector(comp_ctx.builder, result, zero,
                                        even_mask, "even_result")) == 0)
        || ((vec2 = LLVMBuildShuffleVector(comp_ctx.builder, result, zero,
                                           odd_mask, "odd_result")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    if (((result = LLVMBuildAdd(comp_ctx.builder, vec1, vec2, "new_vec")) == 0)) {
        HANDLE_FAILURE("LLVMBuildAdd");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...aot_compiler;

version (none) {
extern "C" {
//! #endif

bool aot_compile_simd_i8x16_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic cond);

bool aot_compile_simd_i16x8_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic cond);

bool aot_compile_simd_i32x4_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic cond);

bool aot_compile_simd_i64x2_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic cond);

bool aot_compile_simd_i8x16_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i16x8_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i32x4_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i64x2_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i8x16_popcnt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i8x16_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed);

bool aot_compile_simd_i16x8_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed);

bool aot_compile_simd_i32x4_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed);

bool aot_compile_simd_i8x16_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i16x8_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i32x4_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i64x2_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i8x16_avgr_u(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i16x8_avgr_u(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i32x4_avgr_u(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i32x4_dot_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

version (none) {}
} /* end of extern "C" */
}

 /* end of _SIMD_INT_ARITH_H_ */
