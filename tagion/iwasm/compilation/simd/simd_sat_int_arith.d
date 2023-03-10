module simd_sat_int_arith;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import simd_sat_int_arith;
public import simd_common;
public import ...aot_emit_exception;
public import ......aot.aot_runtime;

private bool simd_sat_int_arith(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef vector_type, const(char)* intrinsics) {
    LLVMValueRef lhs = void, rhs = void, result = void;
    LLVMTypeRef[2] param_types = void;

    if (((rhs =
              simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type, "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "lhs")) == 0)) {
        return false;
    }

    param_types[0] = vector_type;
    param_types[1] = vector_type;

    if (((result =
              aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsics,
                                      vector_type, param_types.ptr, 2, lhs, rhs)) == 0)) {
        HANDLE_FAILURE("LLVMBuildCall");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed) {
    char*[2][3] intrinsics = [
        [ "llvm.sadd.sat.v16i8", "llvm.uadd.sat.v16i8" ],
        [ "llvm.ssub.sat.v16i8", "llvm.usub.sat.v16i8" ],
    ];

    return simd_sat_int_arith(comp_ctx, func_ctx, V128_i8x16_TYPE,
                              is_signed ? intrinsics[arith_op][0]
                                        : intrinsics[arith_op][1]);
}

bool aot_compile_simd_i16x8_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed) {
    char*[2][3] intrinsics = [
        [ "llvm.sadd.sat.v8i16", "llvm.uadd.sat.v8i16" ],
        [ "llvm.ssub.sat.v8i16", "llvm.usub.sat.v8i16" ],
    ];

    return simd_sat_int_arith(comp_ctx, func_ctx, V128_i16x8_TYPE,
                              is_signed ? intrinsics[arith_op][0]
                                        : intrinsics[arith_op][1]);
}

bool aot_compile_simd_i32x4_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed) {
    char*[2][3] intrinsics = [
        [ "llvm.sadd.sat.v4i32", "llvm.uadd.sat.v4i32" ],
        [ "llvm.ssub.sat.v4i32", "llvm.usub.sat.v4i32" ],
    ];

    return simd_sat_int_arith(comp_ctx, func_ctx, V128_i16x8_TYPE,
                              is_signed ? intrinsics[arith_op][0]
                                        : intrinsics[arith_op][1]);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...aot_compiler;

version (none) {
extern "C" {
//! #endif

bool aot_compile_simd_i8x16_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed);

bool aot_compile_simd_i16x8_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed);

bool aot_compile_simd_i32x4_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, V128Arithmetic arith_op, bool is_signed);
version (none) {}
} /* end of extern "C" */
}

 /* end of _SIMD_SAT_INT_ARITH_H_ */
