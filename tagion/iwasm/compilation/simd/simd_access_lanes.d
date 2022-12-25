module simd_access_lanes;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import simd_access_lanes;
public import simd_common;
public import ...aot_emit_exception;
public import ......aot.aot_runtime;

bool aot_compile_simd_shuffle(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, const(ubyte)* frame_ip) {
    LLVMValueRef vec1 = void, vec2 = void, mask = void, result = void;
    ubyte[16] imm = 0;
    int[16] values = void;
    uint i = void;

    wasm_runtime_read_v128(frame_ip, cast(ulong*)imm, cast(ulong*)(imm.ptr + 8));
    for (i = 0; i < 16; i++) {
        values[i] = imm[i];
    }

    if (((vec2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, V128_i8x16_TYPE,
                                           "vec2")) == 0)) {
        goto fail;
    }

    if (((vec1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, V128_i8x16_TYPE,
                                           "vec1")) == 0)) {
        goto fail;
    }

    /* build a vector <16 x i32> */
    if (((mask = simd_build_const_integer_vector(comp_ctx, I32_TYPE, values.ptr,
                                                 16)) == 0)) {
        goto fail;
    }

    if (((result = LLVMBuildShuffleVector(comp_ctx.builder, vec1, vec2, mask,
                                          "new_vector")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        goto fail;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");

fail:
    return false;
}

/*TODO: llvm.experimental.vector.*/
/* shufflevector is not an option, since it requires *mask as a const */
bool aot_compile_simd_swizzle_x86(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef vector = void, mask = void, max_lanes = void, condition = void, mask_lanes = void, result = void;
    LLVMTypeRef[2] param_types = void;

    if (((mask = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, V128_i8x16_TYPE,
                                           "mask")) == 0)) {
        goto fail;
    }

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_i8x16_TYPE, "vec")) == 0)) {
        goto fail;
    }

    /* icmp uge <16 x i8> mask, <16, 16, 16, 16, ...> */
    if (((max_lanes = simd_build_splat_const_integer_vector(comp_ctx, INT8_TYPE,
                                                            16, 16)) == 0)) {
        goto fail;
    }

    /* if the highest bit of every i8 of mask is 1, means doesn't pick up
       from vector */
    /* select <16 x i1> %condition, <16 x i8> <0x80, 0x80, ...>,
              <16 x i8> %mask */
    if (((mask_lanes = simd_build_splat_const_integer_vector(
              comp_ctx, INT8_TYPE, 0x80, 16)) == 0)) {
        goto fail;
    }

    if (((condition = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGE, mask,
                                    max_lanes, "compare_with_16")) == 0)) {
        HANDLE_FAILURE("LLVMBuldICmp");
        goto fail;
    }

    if (((mask = LLVMBuildSelect(comp_ctx.builder, condition, mask_lanes, mask,
                                 "mask")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSelect");
        goto fail;
    }

    param_types[0] = V128_i8x16_TYPE;
    param_types[1] = V128_i8x16_TYPE;
    if (((result = aot_call_llvm_intrinsic(
              comp_ctx, func_ctx, "llvm.x86.ssse3.pshuf.b.128", V128_i8x16_TYPE,
              param_types.ptr, 2, vector, mask)) == 0)) {
        HANDLE_FAILURE("LLVMBuildCall");
        goto fail;
    }

    if (((result = LLVMBuildBitCast(comp_ctx.builder, result, V128_i64x2_TYPE,
                                    "ret")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    PUSH_V128(result);

    return true;
fail:
    return false;
}

private bool aot_compile_simd_swizzle_common(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef vector = void, mask = void, default_lane_value = void, condition = void, max_lane_id = void, result = void, idx = void, id = void, replace_with_zero = void, elem = void, elem_or_zero = void, undef = void;
    ubyte i = void;

    if (((mask = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, V128_i8x16_TYPE,
                                           "mask")) == 0)) {
        goto fail;
    }

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_i8x16_TYPE, "vec")) == 0)) {
        goto fail;
    }

    if (((undef = LLVMGetUndef(V128_i8x16_TYPE)) == 0)) {
        HANDLE_FAILURE("LLVMGetUndef");
        goto fail;
    }

    /* icmp uge <16 x i8> mask, <16, 16, 16, 16, ...> */
    if (((max_lane_id = simd_build_splat_const_integer_vector(
              comp_ctx, INT8_TYPE, 16, 16)) == 0)) {
        goto fail;
    }

    if (((condition = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGE, mask,
                                    max_lane_id, "out_of_range")) == 0)) {
        HANDLE_FAILURE("LLVMBuldICmp");
        goto fail;
    }

    /* if the id is out of range (>=16), set the id as 0 */
    if (((default_lane_value = simd_build_splat_const_integer_vector(
              comp_ctx, INT8_TYPE, 0, 16)) == 0)) {
        goto fail;
    }

    if (((idx = LLVMBuildSelect(comp_ctx.builder, condition,
                                default_lane_value, mask, "mask")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSelect");
        goto fail;
    }

    for (i = 0; i < 16; i++) {
        if (((id = LLVMBuildExtractElement(comp_ctx.builder, idx, I8_CONST(i),
                                           "id")) == 0)) {
            HANDLE_FAILURE("LLVMBuildExtractElement");
            goto fail;
        }

        if (((replace_with_zero =
                  LLVMBuildExtractElement(comp_ctx.builder, condition,
                                          I8_CONST(i), "replace_with_zero")) == 0)) {
            HANDLE_FAILURE("LLVMBuildExtractElement");
            goto fail;
        }

        if (((elem = LLVMBuildExtractElement(comp_ctx.builder, vector, id,
                                             "vector[mask[i]]")) == 0)) {
            HANDLE_FAILURE("LLVMBuildExtractElement");
            goto fail;
        }

        if (((elem_or_zero =
                  LLVMBuildSelect(comp_ctx.builder, replace_with_zero,
                                  I8_CONST(0), elem, "elem_or_zero")) == 0)) {
            HANDLE_FAILURE("LLVMBuildSelect");
            goto fail;
        }

        if (((undef =
                  LLVMBuildInsertElement(comp_ctx.builder, undef, elem_or_zero,
                                         I8_CONST(i), "new_vector")) == 0)) {
            HANDLE_FAILURE("LLVMBuildInsertElement");
            goto fail;
        }
    }

    if (((result = LLVMBuildBitCast(comp_ctx.builder, undef, V128_i64x2_TYPE,
                                    "ret")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    PUSH_V128(result);

    return true;
fail:
    return false;
}

bool aot_compile_simd_swizzle(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    if (is_target_x86(comp_ctx)) {
        return aot_compile_simd_swizzle_x86(comp_ctx, func_ctx);
    }
    else {
        return aot_compile_simd_swizzle_common(comp_ctx, func_ctx);
    }
}

private bool aot_compile_simd_extract(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id, bool need_extend, bool is_signed, LLVMTypeRef vector_type, LLVMTypeRef result_type, uint aot_value_type) {
    LLVMValueRef vector = void, lane = void, result = void;

    if (((lane = simd_lane_id_to_llvm_value(comp_ctx, lane_id)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    /* bitcast <2 x i64> %0 to <vector_type> */
    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "vec")) == 0)) {
        goto fail;
    }

    /* extractelement <vector_type> %vector, i8 lane_id*/
    if (((result = LLVMBuildExtractElement(comp_ctx.builder, vector, lane,
                                           "element")) == 0)) {
        HANDLE_FAILURE("LLVMBuildExtractElement");
        goto fail;
    }

    if (need_extend) {
        if (is_signed) {
            /* sext <element_type> %element to <result_type> */
            if (((result = LLVMBuildSExt(comp_ctx.builder, result, result_type,
                                         "ret")) == 0)) {
                HANDLE_FAILURE("LLVMBuildSExt");
                goto fail;
            }
        }
        else {
            /* sext <element_type> %element to <result_type> */
            if (((result = LLVMBuildZExt(comp_ctx.builder, result, result_type,
                                         "ret")) == 0)) {
                HANDLE_FAILURE("LLVMBuildZExt");
                goto fail;
            }
        }
    }

    PUSH(result, aot_value_type);

    return true;
fail:
    return false;
}

bool aot_compile_simd_extract_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id, bool is_signed) {
    return aot_compile_simd_extract(comp_ctx, func_ctx, lane_id, true,
                                    is_signed, V128_i8x16_TYPE, I32_TYPE,
                                    VALUE_TYPE_I32);
}

bool aot_compile_simd_extract_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id, bool is_signed) {
    return aot_compile_simd_extract(comp_ctx, func_ctx, lane_id, true,
                                    is_signed, V128_i16x8_TYPE, I32_TYPE,
                                    VALUE_TYPE_I32);
}

bool aot_compile_simd_extract_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_extract(comp_ctx, func_ctx, lane_id, false, false,
                                    V128_i32x4_TYPE, I32_TYPE, VALUE_TYPE_I32);
}

bool aot_compile_simd_extract_i64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_extract(comp_ctx, func_ctx, lane_id, false, false,
                                    V128_i64x2_TYPE, I64_TYPE, VALUE_TYPE_I64);
}

bool aot_compile_simd_extract_f32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_extract(comp_ctx, func_ctx, lane_id, false, false,
                                    V128_f32x4_TYPE, F32_TYPE, VALUE_TYPE_F32);
}

bool aot_compile_simd_extract_f64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_extract(comp_ctx, func_ctx, lane_id, false, false,
                                    V128_f64x2_TYPE, F64_TYPE, VALUE_TYPE_F64);
}

private bool aot_compile_simd_replace(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id, uint new_value_type, LLVMTypeRef vector_type, bool need_reduce, LLVMTypeRef element_type) {
    LLVMValueRef vector = void, new_value = void, lane = void, result = void;

    POP(new_value, new_value_type);

    if (((lane = simd_lane_id_to_llvm_value(comp_ctx, lane_id)) == 0)) {
        goto fail;
    }

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, vector_type,
                                             "vec")) == 0)) {
        goto fail;
    }

    /* trunc <new_value_type> to <element_type> */
    if (need_reduce) {
        if (((new_value = LLVMBuildTrunc(comp_ctx.builder, new_value,
                                         element_type, "element")) == 0)) {
            HANDLE_FAILURE("LLVMBuildTrunc");
            goto fail;
        }
    }

    /* insertelement <vector_type> %vector, <element_type>  %element,
                     i32 lane */
    if (((result = LLVMBuildInsertElement(comp_ctx.builder, vector, new_value,
                                          lane, "new_vector")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        goto fail;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "reesult");

fail:
    return false;
}

bool aot_compile_simd_replace_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_replace(comp_ctx, func_ctx, lane_id, VALUE_TYPE_I32,
                                    V128_i8x16_TYPE, true, INT8_TYPE);
}

bool aot_compile_simd_replace_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_replace(comp_ctx, func_ctx, lane_id, VALUE_TYPE_I32,
                                    V128_i16x8_TYPE, true, INT16_TYPE);
}

bool aot_compile_simd_replace_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_replace(comp_ctx, func_ctx, lane_id, VALUE_TYPE_I32,
                                    V128_i32x4_TYPE, false, I32_TYPE);
}

bool aot_compile_simd_replace_i64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_replace(comp_ctx, func_ctx, lane_id, VALUE_TYPE_I64,
                                    V128_i64x2_TYPE, false, I64_TYPE);
}

bool aot_compile_simd_replace_f32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_replace(comp_ctx, func_ctx, lane_id, VALUE_TYPE_F32,
                                    V128_f32x4_TYPE, false, F32_TYPE);
}

bool aot_compile_simd_replace_f64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id) {
    return aot_compile_simd_replace(comp_ctx, func_ctx, lane_id, VALUE_TYPE_F64,
                                    V128_f64x2_TYPE, false, F64_TYPE);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...aot_compiler;

version (none) {
extern "C" {
//! #endif

bool aot_compile_simd_shuffle(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, const(ubyte)* frame_ip);

bool aot_compile_simd_swizzle(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_extract_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id, bool is_signed);

bool aot_compile_simd_extract_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id, bool is_signed);

bool aot_compile_simd_extract_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_extract_i64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_extract_f32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_extract_f64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_replace_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_replace_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_replace_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_replace_i64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_replace_f32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_replace_f64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_load8_lane(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_load16_lane(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_load32_lane(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

bool aot_compile_simd_load64_lane(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte lane_id);

version (none) {}
} /* end of extern "C" */
}

 /* end of _SIMD_ACCESS_LANES_H_ */
