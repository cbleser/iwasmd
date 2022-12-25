module simd_comparisons;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import simd_comparisons;
public import simd_common;
public import ...aot_emit_exception;
public import ......aot.aot_runtime;

private bool float_cond_2_predicate(FloatCond cond, LLVMRealPredicate* out_) {
    switch (cond) {
        case FLOAT_EQ:
            *out_ = LLVMRealOEQ;
            break;
        case FLOAT_NE:
            *out_ = LLVMRealUNE;
            break;
        case FLOAT_LT:
            *out_ = LLVMRealOLT;
            break;
        case FLOAT_GT:
            *out_ = LLVMRealOGT;
            break;
        case FLOAT_LE:
            *out_ = LLVMRealOLE;
            break;
        case FLOAT_GE:
            *out_ = LLVMRealOGE;
            break;
        default:
            bh_assert(0);
            goto fail;
    }

    return true;
fail:
    return false;
}

private bool int_cond_2_predicate(IntCond cond, LLVMIntPredicate* out_) {
    switch (cond) {
        case INT_EQZ:
        case INT_EQ:
            *out_ = LLVMIntEQ;
            break;
        case INT_NE:
            *out_ = LLVMIntNE;
            break;
        case INT_LT_S:
            *out_ = LLVMIntSLT;
            break;
        case INT_LT_U:
            *out_ = LLVMIntULT;
            break;
        case INT_GT_S:
            *out_ = LLVMIntSGT;
            break;
        case INT_GT_U:
            *out_ = LLVMIntUGT;
            break;
        case INT_LE_S:
            *out_ = LLVMIntSLE;
            break;
        case INT_LE_U:
            *out_ = LLVMIntULE;
            break;
        case INT_GE_S:
            *out_ = LLVMIntSGE;
            break;
        case INT_GE_U:
            *out_ = LLVMIntUGE;
            break;
        default:
            bh_assert(0);
            goto fail;
    }

    return true;
fail:
    return false;
}

private bool interger_vector_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond, LLVMTypeRef vector_type) {
    LLVMValueRef vec1 = void, vec2 = void, result = void;
    LLVMIntPredicate int_pred = void;

    if (((vec2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                           "vec2")) == 0)) {
        goto fail;
    }

    if (((vec1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                           "vec1")) == 0)) {
        goto fail;
    }

    if (!int_cond_2_predicate(cond, &int_pred)) {
        HANDLE_FAILURE("int_cond_2_predicate");
        goto fail;
    }
    /* icmp <N x iX> %vec1, %vec2 */
    if (((result =
              LLVMBuildICmp(comp_ctx.builder, int_pred, vec1, vec2, "cmp")) == 0)) {
        HANDLE_FAILURE("LLVMBuildICmp");
        goto fail;
    }

    /* sext <N x i1> %result to <N x iX> */
    if (((result =
              LLVMBuildSExt(comp_ctx.builder, result, vector_type, "ext")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSExt");
        goto fail;
    }

    /* bitcast <N x iX> %result to <2 x i64> */
    if (((result = LLVMBuildBitCast(comp_ctx.builder, result, V128_i64x2_TYPE,
                                    "result")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    PUSH_V128(result);

    return true;
fail:
    return false;
}

bool aot_compile_simd_i8x16_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond) {
    return interger_vector_compare(comp_ctx, func_ctx, cond, V128_i8x16_TYPE);
}

bool aot_compile_simd_i16x8_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond) {
    return interger_vector_compare(comp_ctx, func_ctx, cond, V128_i16x8_TYPE);
}

bool aot_compile_simd_i32x4_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond) {
    return interger_vector_compare(comp_ctx, func_ctx, cond, V128_i32x4_TYPE);
}

bool aot_compile_simd_i64x2_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond) {
    return interger_vector_compare(comp_ctx, func_ctx, cond, V128_i64x2_TYPE);
}

private bool float_vector_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatCond cond, LLVMTypeRef vector_type, LLVMTypeRef result_type) {
    LLVMValueRef vec1 = void, vec2 = void, result = void;
    LLVMRealPredicate real_pred = void;

    if (((vec2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                           "vec2")) == 0)) {
        goto fail;
    }

    if (((vec1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                           "vec1")) == 0)) {
        goto fail;
    }

    if (!float_cond_2_predicate(cond, &real_pred)) {
        HANDLE_FAILURE("float_cond_2_predicate");
        goto fail;
    }
    /* fcmp <N x iX> %vec1, %vec2 */
    if (((result =
              LLVMBuildFCmp(comp_ctx.builder, real_pred, vec1, vec2, "cmp")) == 0)) {
        HANDLE_FAILURE("LLVMBuildFCmp");
        goto fail;
    }

    /* sext <N x i1> %result to <N x iX> */
    if (((result =
              LLVMBuildSExt(comp_ctx.builder, result, result_type, "ext")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSExt");
        goto fail;
    }

    /* bitcast <N x iX> %result to <2 x i64> */
    if (((result = LLVMBuildBitCast(comp_ctx.builder, result, V128_i64x2_TYPE,
                                    "result")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    PUSH_V128(result);

    return true;
fail:
    return false;
}

bool aot_compile_simd_f32x4_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatCond cond) {
    return float_vector_compare(comp_ctx, func_ctx, cond, V128_f32x4_TYPE,
                                V128_i32x4_TYPE);
}

bool aot_compile_simd_f64x2_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatCond cond) {
    return float_vector_compare(comp_ctx, func_ctx, cond, V128_f64x2_TYPE,
                                V128_i64x2_TYPE);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...aot_compiler;

version (none) {
extern "C" {
//! #endif

bool aot_compile_simd_i8x16_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond);

bool aot_compile_simd_i16x8_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond);

bool aot_compile_simd_i32x4_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond);

bool aot_compile_simd_i64x2_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, IntCond cond);

bool aot_compile_simd_f32x4_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatCond cond);

bool aot_compile_simd_f64x2_compare(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatCond cond);

version (none) {}
} /* end of extern "C" */
}

 /* end of _SIMD_COMPARISONS_H_ */
