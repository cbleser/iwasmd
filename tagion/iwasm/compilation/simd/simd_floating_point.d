module simd_floating_point;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import simd_floating_point;
public import simd_common;
public import ...aot_emit_exception;
public import ...aot_emit_numberic;
public import ......aot.aot_runtime;

private bool simd_v128_float_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op, LLVMTypeRef vector_type) {
    LLVMValueRef lhs = void, rhs = void, result = null;

    if (((rhs =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type, "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "lhs")) == 0)) {
        return false;
    }

    switch (arith_op) {
        case FLOAT_ADD:
            result = LLVMBuildFAdd(comp_ctx.builder, lhs, rhs, "sum");
            break;
        case FLOAT_SUB:
            result = LLVMBuildFSub(comp_ctx.builder, lhs, rhs, "difference");
            break;
        case FLOAT_MUL:
            result = LLVMBuildFMul(comp_ctx.builder, lhs, rhs, "product");
            break;
        case FLOAT_DIV:
            result = LLVMBuildFDiv(comp_ctx.builder, lhs, rhs, "quotient");
            break;
        default:
            return false;
    }

    if (!result) {
        HANDLE_FAILURE(
            "LLVMBuildFAdd/LLVMBuildFSub/LLVMBuildFMul/LLVMBuildFDiv");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_f32x4_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op) {
    return simd_v128_float_arith(comp_ctx, func_ctx, arith_op, V128_f32x4_TYPE);
}

bool aot_compile_simd_f64x2_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op) {
    return simd_v128_float_arith(comp_ctx, func_ctx, arith_op, V128_f64x2_TYPE);
}

private bool simd_v128_float_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef vector_type) {
    LLVMValueRef vector = void, result = void;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "vector")) == 0)) {
        return false;
    }

    if (((result = LLVMBuildFNeg(comp_ctx.builder, vector, "neg")) == 0)) {
        HANDLE_FAILURE("LLVMBuildFNeg");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_f32x4_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_float_neg(comp_ctx, func_ctx, V128_f32x4_TYPE);
}

bool aot_compile_simd_f64x2_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_v128_float_neg(comp_ctx, func_ctx, V128_f64x2_TYPE);
}

private bool simd_float_intrinsic(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef vector_type, const(char)* intrinsic) {
    LLVMValueRef vector = void, result = void;
    LLVMTypeRef[1] param_types = [ vector_type ];

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "vector")) == 0)) {
        return false;
    }

    if (((result =
              aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic,
                                      vector_type, param_types.ptr, 1, vector)) == 0)) {
        HANDLE_FAILURE("LLVMBuildCall");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_f32x4_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.fabs.v4f32");
}

bool aot_compile_simd_f64x2_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.fabs.v2f64");
}

bool aot_compile_simd_f32x4_round(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.round.v4f32");
}

bool aot_compile_simd_f64x2_round(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.round.v2f64");
}

bool aot_compile_simd_f32x4_sqrt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.sqrt.v4f32");
}

bool aot_compile_simd_f64x2_sqrt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.sqrt.v2f64");
}

bool aot_compile_simd_f32x4_ceil(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.ceil.v4f32");
}

bool aot_compile_simd_f64x2_ceil(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.ceil.v2f64");
}

bool aot_compile_simd_f32x4_floor(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.floor.v4f32");
}

bool aot_compile_simd_f64x2_floor(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.floor.v2f64");
}

bool aot_compile_simd_f32x4_trunc(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.trunc.v4f32");
}

bool aot_compile_simd_f64x2_trunc(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.trunc.v2f64");
}

bool aot_compile_simd_f32x4_nearest(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f32x4_TYPE,
                                "llvm.rint.v4f32");
}

bool aot_compile_simd_f64x2_nearest(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_float_intrinsic(comp_ctx, func_ctx, V128_f64x2_TYPE,
                                "llvm.rint.v2f64");
}

private bool simd_float_cmp(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op, LLVMTypeRef vector_type) {
    LLVMValueRef lhs = void, rhs = void, result = void;
    LLVMRealPredicate op = FLOAT_MIN == arith_op ? LLVMRealULT : LLVMRealUGT;

    if (((rhs =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type, "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "lhs")) == 0)) {
        return false;
    }

    if (((result = LLVMBuildFCmp(comp_ctx.builder, op, lhs, rhs, "cmp")) == 0)) {
        HANDLE_FAILURE("LLVMBuildFCmp");
        return false;
    }

    if (((result =
              LLVMBuildSelect(comp_ctx.builder, result, lhs, rhs, "select")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSelect");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

/*TODO: sugggest non-IA platforms check with "llvm.minimum.*" and
 * "llvm.maximum.*" firstly */
bool aot_compile_simd_f32x4_min_max(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min) {
    return simd_float_cmp(comp_ctx, func_ctx, run_min ? FLOAT_MIN : FLOAT_MAX,
                          V128_f32x4_TYPE);
}

bool aot_compile_simd_f64x2_min_max(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min) {
    return simd_float_cmp(comp_ctx, func_ctx, run_min ? FLOAT_MIN : FLOAT_MAX,
                          V128_f64x2_TYPE);
}

private bool simd_float_pmin_max(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef vector_type, const(char)* intrinsic) {
    LLVMValueRef lhs = void, rhs = void, result = void;
    LLVMTypeRef[2] param_types = void;

    param_types[0] = vector_type;
    param_types[1] = vector_type;

    if (((rhs =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type, "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "lhs")) == 0)) {
        return false;
    }

    if (((result =
              aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic,
                                      vector_type, param_types.ptr, 2, lhs, rhs)) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_f32x4_pmin_pmax(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min) {
    return simd_float_pmin_max(comp_ctx, func_ctx, V128_f32x4_TYPE,
                               run_min ? "llvm.minnum.v4f32"
                                       : "llvm.maxnum.v4f32");
}

bool aot_compile_simd_f64x2_pmin_pmax(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min) {
    return simd_float_pmin_max(comp_ctx, func_ctx, V128_f64x2_TYPE,
                               run_min ? "llvm.minnum.v2f64"
                                       : "llvm.maxnum.v2f64");
}

bool aot_compile_simd_f64x2_demote(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef vector = void, elem_0 = void, elem_1 = void, result = void;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_f64x2_TYPE, "vector")) == 0)) {
        return false;
    }

    if (((elem_0 = LLVMBuildExtractElement(comp_ctx.builder, vector,
                                           LLVM_CONST(i32_zero), "elem_0")) == 0)
        || ((elem_1 = LLVMBuildExtractElement(comp_ctx.builder, vector,
                                              LLVM_CONST(i32_one), "elem_1")) == 0)) {
        HANDLE_FAILURE("LLVMBuildExtractElement");
        return false;
    }

    /* fptrunc <f64> elem to <f32> */
    if (((elem_0 = LLVMBuildFPTrunc(comp_ctx.builder, elem_0, F32_TYPE,
                                    "elem_0_trunc")) == 0)
        || ((elem_1 = LLVMBuildFPTrunc(comp_ctx.builder, elem_1, F32_TYPE,
                                       "elem_1_trunc")) == 0)) {
        HANDLE_FAILURE("LLVMBuildFPTrunc");
        return false;
    }

    if (((result = LLVMBuildInsertElement(comp_ctx.builder,
                                          LLVM_CONST(f32x4_vec_zero), elem_0,
                                          LLVM_CONST(i32_zero), "new_vector_0")) == 0)
        || ((result =
                 LLVMBuildInsertElement(comp_ctx.builder, result, elem_1,
                                        LLVM_CONST(i32_one), "new_vector_1")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_f32x4_promote(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef vector = void, elem_0 = void, elem_1 = void, result = void;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_f32x4_TYPE, "vector")) == 0)) {
        return false;
    }

    if (((elem_0 = LLVMBuildExtractElement(comp_ctx.builder, vector,
                                           LLVM_CONST(i32_zero), "elem_0")) == 0)
        || ((elem_1 = LLVMBuildExtractElement(comp_ctx.builder, vector,
                                              LLVM_CONST(i32_one), "elem_1")) == 0)) {
        HANDLE_FAILURE("LLVMBuildExtractElement");
        return false;
    }

    /* fpext <f32> elem to <f64> */
    if (((elem_0 =
              LLVMBuildFPExt(comp_ctx.builder, elem_0, F64_TYPE, "elem_0_ext")) == 0)
        || ((elem_1 = LLVMBuildFPExt(comp_ctx.builder, elem_1, F64_TYPE,
                                     "elem_1_ext")) == 0)) {
        HANDLE_FAILURE("LLVMBuildFPExt");
        return false;
    }

    if (((result = LLVMBuildInsertElement(comp_ctx.builder,
                                          LLVM_CONST(f64x2_vec_zero), elem_0,
                                          LLVM_CONST(i32_zero), "new_vector_0")) == 0)
        || ((result =
                 LLVMBuildInsertElement(comp_ctx.builder, result, elem_1,
                                        LLVM_CONST(i32_one), "new_vector_1")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
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

bool aot_compile_simd_f32x4_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op);

bool aot_compile_simd_f64x2_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, FloatArithmetic arith_op);

bool aot_compile_simd_f32x4_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_neg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_abs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_round(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_round(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_sqrt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_sqrt(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_ceil(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_ceil(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_floor(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_floor(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_trunc(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_trunc(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_nearest(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f64x2_nearest(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_min_max(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min);

bool aot_compile_simd_f64x2_min_max(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min);

bool aot_compile_simd_f32x4_pmin_pmax(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min);

bool aot_compile_simd_f64x2_pmin_pmax(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool run_min);

bool aot_compile_simd_f64x2_demote(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_f32x4_promote(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

version (none) {}
} /* end of extern "C" */
}

 /* end of _SIMD_FLOATING_POINT_H_ */
