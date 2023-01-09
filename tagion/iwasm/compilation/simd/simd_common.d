module tagion.iwasm.compilation.simd.simd_common;
@nogc nothrow:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.compilation.simd.simd_common;

LLVMValueRef simd_pop_v128_and_bitcast(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, LLVMTypeRef vec_type, const(char)* name) {
    LLVMValueRef number = void;

    POP_V128(number);

    if (((number =
              LLVMBuildBitCast(comp_ctx.builder, number, vec_type, name)) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    return number;
fail:
    return null;
}

bool simd_bitcast_and_push_v128(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, LLVMValueRef vector, const(char)* name) {
    if (((vector = LLVMBuildBitCast(comp_ctx.builder, vector, V128_i64x2_TYPE,
                                    name)) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    /* push result into the stack */
    PUSH_V128(vector);

    return true;
fail:
    return false;
}

LLVMValueRef simd_lane_id_to_llvm_value(AOTCompContext* comp_ctx, ubyte lane_id) {
    LLVMValueRef[17] lane_indexes = [
        LLVM_CONST(i32_zero),     LLVM_CONST(i32_one),
        LLVM_CONST(i32_two),      LLVM_CONST(i32_three),
        LLVM_CONST(i32_four),     LLVM_CONST(i32_five),
        LLVM_CONST(i32_six),      LLVM_CONST(i32_seven),
        LLVM_CONST(i32_eight),    LLVM_CONST(i32_nine),
        LLVM_CONST(i32_ten),      LLVM_CONST(i32_eleven),
        LLVM_CONST(i32_twelve),   LLVM_CONST(i32_thirteen),
        LLVM_CONST(i32_fourteen), LLVM_CONST(i32_fifteen),
    ];

    return lane_id < 16 ? lane_indexes[lane_id] : null;
}

LLVMValueRef simd_build_const_integer_vector(const(AOTCompContext)* comp_ctx, const(LLVMTypeRef) element_type, const(int)* element_value, uint length) {
    LLVMValueRef vector = null;
    LLVMValueRef* elements = void;
    uint i = void;

    if (((elements = wasm_runtime_malloc(sizeof(LLVMValueRef) * length)) == 0)) {
        return null;
    }

    for (i = 0; i < length; i++) {
        if (((elements[i] =
                  LLVMConstInt(element_type, element_value[i], true)) == 0)) {
            HANDLE_FAILURE("LLVMConstInst");
            goto fail;
        }
    }

    if (((vector = LLVMConstVector(elements, length)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        goto fail;
    }

fail:
    wasm_runtime_free(elements);
    return vector;
}

LLVMValueRef simd_build_splat_const_integer_vector(const(AOTCompContext)* comp_ctx, const(LLVMTypeRef) element_type, const(long) element_value, uint length) {
    LLVMValueRef vector = null, element = void;
    LLVMValueRef* elements = void;
    uint i = void;

    if (((elements = wasm_runtime_malloc(sizeof(LLVMValueRef) * length)) == 0)) {
        return null;
    }

    if (((element = LLVMConstInt(element_type, element_value, true)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    for (i = 0; i < length; i++) {
        elements[i] = element;
    }

    if (((vector = LLVMConstVector(elements, length)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        goto fail;
    }

fail:
    wasm_runtime_free(elements);
    return vector;
}

LLVMValueRef simd_build_splat_const_float_vector(const(AOTCompContext)* comp_ctx, const(LLVMTypeRef) element_type, const(float) element_value, uint length) {
    LLVMValueRef vector = null, element = void;
    LLVMValueRef* elements = void;
    uint i = void;

    if (((elements = wasm_runtime_malloc(sizeof(LLVMValueRef) * length)) == 0)) {
        return null;
    }

    if (((element = LLVMConstReal(element_type, element_value)) == 0)) {
        HANDLE_FAILURE("LLVMConstReal");
        goto fail;
    }

    for (i = 0; i < length; i++) {
        elements[i] = element;
    }

    if (((vector = LLVMConstVector(elements, length)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        goto fail;
    }

fail:
    wasm_runtime_free(elements);
    return vector;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
