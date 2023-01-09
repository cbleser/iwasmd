module tagion.iwasm.compilation.simd.simd_construct_values;
@nogc nothrow:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.compilation.simd.simd_common;
import tagion.iwasm.compilation.simd.simd_construct_values;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.interpreter.wasm_opcode;
import tagion.iwasm.aot.aot_runtime;

bool aot_compile_simd_v128_const(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, const(ubyte)* imm_bytes) {
    ulong imm1 = void, imm2 = void;
    LLVMValueRef first_long = void, agg1 = void, second_long = void, agg2 = void;

    wasm_runtime_read_v128(imm_bytes, &imm1, &imm2);

    /* %agg1 = insertelement <2 x i64> undef, i16 0, i64 ${*imm} */
    if (((first_long = I64_CONST(imm1)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((agg1 =
              LLVMBuildInsertElement(comp_ctx.builder, LLVM_CONST(i64x2_undef),
                                     first_long, I32_ZERO, "agg1")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        goto fail;
    }

    /* %agg2 = insertelement <2 x i64> %agg1, i16 1, i64 ${*(imm + 1)} */
    if (((second_long = I64_CONST(imm2)) == 0)) {
        HANDLE_FAILURE("LLVMGetUndef");
        goto fail;
    }

    if (((agg2 = LLVMBuildInsertElement(comp_ctx.builder, agg1, second_long,
                                        I32_ONE, "agg2")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        goto fail;
    }

    PUSH_V128(agg2);
    return true;
fail:
    return false;
}

bool aot_compile_simd_splat(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte opcode) {
    uint opcode_index = opcode - SIMD_i8x16_splat;
    LLVMValueRef value = null, base = void, new_vector = void;
    LLVMValueRef[7] undefs = [
        LLVM_CONST(i8x16_undef), LLVM_CONST(i16x8_undef),
        LLVM_CONST(i32x4_undef), LLVM_CONST(i64x2_undef),
        LLVM_CONST(f32x4_undef), LLVM_CONST(f64x2_undef),
    ];
    LLVMValueRef[7] masks = [
        LLVM_CONST(i32x16_zero), LLVM_CONST(i32x8_zero), LLVM_CONST(i32x4_zero),
        LLVM_CONST(i32x2_zero),  LLVM_CONST(i32x4_zero), LLVM_CONST(i32x2_zero),
    ];

    switch (opcode) {
        case SIMD_i8x16_splat:
        {
            LLVMValueRef input = void;
            POP_I32(input);
            /* trunc i32 %input to i8 */
            value =
                LLVMBuildTrunc(comp_ctx.builder, input, INT8_TYPE, "trunc");
            break;
        }
        case SIMD_i16x8_splat:
        {
            LLVMValueRef input = void;
            POP_I32(input);
            /* trunc i32 %input to i16 */
            value =
                LLVMBuildTrunc(comp_ctx.builder, input, INT16_TYPE, "trunc");
            break;
        }
        case SIMD_i32x4_splat:
        {
            POP_I32(value);
            break;
        }
        case SIMD_i64x2_splat:
        {
            POP(value, VALUE_TYPE_I64);
            break;
        }
        case SIMD_f32x4_splat:
        {
            POP(value, VALUE_TYPE_F32);
            break;
        }
        case SIMD_f64x2_splat:
        {
            POP(value, VALUE_TYPE_F64);
            break;
        }
        default:
        {
            break;
        }
    }

    if (!value) {
        goto fail;
    }

    /* insertelement <n x ty> undef, ty %value, i32 0 */
    if (((base = LLVMBuildInsertElement(comp_ctx.builder, undefs[opcode_index],
                                        value, I32_ZERO, "base")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        goto fail;
    }

    /* shufflevector <ty1> %base, <ty2> undef, <n x i32> zeroinitializer */
    if (((new_vector = LLVMBuildShuffleVector(
              comp_ctx.builder, base, undefs[opcode_index],
              masks[opcode_index], "new_vector")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        goto fail;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, new_vector, "result");
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
