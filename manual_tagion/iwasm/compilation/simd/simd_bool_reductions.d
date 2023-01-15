module tagion.iwasm.compilation.simd.simd_bool_reductions;
@nogc nothrow:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.compilation.aot_llvm;
import tagion.iwasm.compilation.simd.simd_bool_reductions;
import tagion.iwasm.compilation.simd.simd_common;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.aot.aot_runtime;

enum integer_all_true {
    e_int_all_true_v16i8,
    e_int_all_true_v8i16,
    e_int_all_true_v4i32,
    e_int_all_true_v2i64,
}
alias e_int_all_true_v16i8 = integer_all_true.e_int_all_true_v16i8;
alias e_int_all_true_v8i16 = integer_all_true.e_int_all_true_v8i16;
alias e_int_all_true_v4i32 = integer_all_true.e_int_all_true_v4i32;
alias e_int_all_true_v2i64 = integer_all_true.e_int_all_true_v2i64;


private bool simd_all_true(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, integer_all_true itype) {
    LLVMValueRef vector = void, result = void;
    LLVMTypeRef vector_i1_type = void;
    LLVMTypeRef[4] vector_type = [ V128_i8x16_TYPE, V128_i16x8_TYPE,
                                  V128_i32x4_TYPE, V128_i64x2_TYPE ];
    uint[4] lanes = [ 16, 8, 4, 2 ];
    const(char)*[5] intrinsic = [
        "llvm.vector.reduce.and.v16i1",
        "llvm.vector.reduce.and.v8i1",
        "llvm.vector.reduce.and.v4i1",
        "llvm.vector.reduce.and.v2i1",
    ];
    LLVMValueRef[5] zero = [
        LLVM_CONST(i8x16_vec_zero),
        LLVM_CONST(i16x8_vec_zero),
        LLVM_CONST(i32x4_vec_zero),
        LLVM_CONST(i64x2_vec_zero),
    ];

    if (((vector_i1_type = LLVMVectorType(INT1_TYPE, lanes[itype])) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        goto fail;
    }

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             vector_type[itype], "vector")) == 0)) {
        goto fail;
    }

    /* compare with zero */
    if (((result = LLVMBuildICmp(comp_ctx.builder, LLVMIntNE, vector,
                                 zero[itype], "ne_zero")) == 0)) {
        HANDLE_FAILURE("LLVMBuildICmp");
        goto fail;
    }

    /* check zero */
    if (((result =
              aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic[itype],
                                      INT1_TYPE, &vector_i1_type, 1, result)) == 0)) {
        goto fail;
    }

    if (((result =
              LLVMBuildZExt(comp_ctx.builder, result, I32_TYPE, "to_i32")) == 0)) {
        HANDLE_FAILURE("LLVMBuildZExt");
        goto fail;
    }

    PUSH_I32(result);

    return true;
fail:
    return false;
}

bool aot_compile_simd_i8x16_all_true(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_all_true(comp_ctx, func_ctx, e_int_all_true_v16i8);
}

bool aot_compile_simd_i16x8_all_true(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_all_true(comp_ctx, func_ctx, e_int_all_true_v8i16);
}

bool aot_compile_simd_i32x4_all_true(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_all_true(comp_ctx, func_ctx, e_int_all_true_v4i32);
}

bool aot_compile_simd_i64x2_all_true(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    return simd_all_true(comp_ctx, func_ctx, e_int_all_true_v2i64);
}

bool aot_compile_simd_v128_any_true(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMTypeRef vector_type = void;
    LLVMValueRef vector = void, result = void;

    if (((vector_type = LLVMVectorType(INT1_TYPE, 128)) == 0)) {
        return false;
    }

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "vector")) == 0)) {
        goto fail;
    }

    if (((result = aot_call_llvm_intrinsic(
              comp_ctx, func_ctx, "llvm.vector.reduce.or.v128i1", INT1_TYPE,
              &vector_type, 1, vector)) == 0)) {
        goto fail;
    }

    if (((result =
              LLVMBuildZExt(comp_ctx.builder, result, I32_TYPE, "to_i32")) == 0)) {
        HANDLE_FAILURE("LLVMBuildZExt");
        goto fail;
    }

    PUSH_I32(result);

    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


