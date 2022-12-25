module simd_conversions;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import simd_conversions;
public import simd_common;
public import ...aot_emit_exception;
public import ...aot_emit_numberic;
public import ......aot.aot_runtime;

private bool simd_integer_narrow_x86(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef in_vector_type, LLVMTypeRef out_vector_type, const(char)* instrinsic) {
    LLVMValueRef vector1 = void, vector2 = void, result = void;
    LLVMTypeRef[2] param_types = [ in_vector_type, in_vector_type ];

    if (((vector2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                              in_vector_type, "vec2")) == 0)
        || ((vector1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                                 in_vector_type, "vec1")) == 0)) {
        return false;
    }

    if (((result = aot_call_llvm_intrinsic(comp_ctx, func_ctx, instrinsic,
                                           out_vector_type, param_types.ptr, 2,
                                           vector1, vector2)) == 0)) {
        HANDLE_FAILURE("LLVMBuildCall");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

enum integer_sat_type {
    e_sat_i16x8 = 0,
    e_sat_i32x4,
    e_sat_i64x2,
    e_sat_i32x8,
}
alias e_sat_i16x8 = integer_sat_type.e_sat_i16x8;
alias e_sat_i32x4 = integer_sat_type.e_sat_i32x4;
alias e_sat_i64x2 = integer_sat_type.e_sat_i64x2;
alias e_sat_i32x8 = integer_sat_type.e_sat_i32x8;


private LLVMValueRef simd_saturate(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, integer_sat_type itype, LLVMValueRef vector, LLVMValueRef min, LLVMValueRef max, bool is_signed) {
    LLVMValueRef result = void;
    LLVMTypeRef vector_type = void;

    LLVMTypeRef[2][5] param_types = [
        [ V128_i16x8_TYPE, V128_i16x8_TYPE ],
        [ V128_i32x4_TYPE, V128_i32x4_TYPE ],
        [ V128_i64x2_TYPE, V128_i64x2_TYPE ],
        [ 0 ],
    ];

    const(char)*[5] smin_intrinsic = [
        "llvm.smin.v8i16",
        "llvm.smin.v4i32",
        "llvm.smin.v2i64",
        "llvm.smin.v8i32",
    ];

    const(char)*[5] umin_intrinsic = [
        "llvm.umin.v8i16",
        "llvm.umin.v4i32",
        "llvm.umin.v2i64",
        "llvm.umin.v8i32",
    ];

    const(char)*[5] smax_intrinsic = [
        "llvm.smax.v8i16",
        "llvm.smax.v4i32",
        "llvm.smax.v2i64",
        "llvm.smax.v8i32",
    ];

    const(char)*[5] umax_intrinsic = [
        "llvm.umax.v8i16",
        "llvm.umax.v4i32",
        "llvm.umax.v2i64",
        "llvm.umax.v8i32",
    ];

    if (e_sat_i32x8 == itype) {
        if (((vector_type = LLVMVectorType(I32_TYPE, 8)) == 0)) {
            HANDLE_FAILURE("LLVMVectorType");
            return null;
        }

        param_types[itype][0] = vector_type;
        param_types[itype][1] = vector_type;
    }

    if (((result = aot_call_llvm_intrinsic(
              comp_ctx, func_ctx,
              is_signed ? smin_intrinsic[itype] : umin_intrinsic[itype],
              param_types[itype][0], param_types[itype], 2, vector, max)) == 0)
        || ((result = aot_call_llvm_intrinsic(
                 comp_ctx, func_ctx,
                 is_signed ? smax_intrinsic[itype] : umax_intrinsic[itype],
                 param_types[itype][0], param_types[itype], 2, result, min)) == 0)) {
        return null;
    }

    return result;
}

private bool simd_integer_narrow_common(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, integer_sat_type itype, bool is_signed) {
    LLVMValueRef vec1 = void, vec2 = void, min = void, max = void, mask = void, result = void;
    LLVMTypeRef[3] in_vector_type = [ V128_i16x8_TYPE, V128_i32x4_TYPE,
                                     V128_i64x2_TYPE ];
    LLVMTypeRef[3] min_max_type = [ INT16_TYPE, I32_TYPE, I64_TYPE ];
    LLVMTypeRef[3] trunc_type = 0;
    ubyte[3] length = [ 8, 4, 2 ];

    long[3] smin = [ 0xff80, 0xffFF8000, 0xffFFffFF80000000 ];
    long[3] umin = [ 0x0, 0x0, 0x0 ];
    long[3] smax = [ 0x007f, 0x00007fff, 0x000000007fFFffFF ];
    long[3] umax = [ 0x00ff, 0x0000ffff, 0x00000000ffFFffFF ];

    LLVMValueRef[17] mask_element = [
        LLVM_CONST(i32_zero),     LLVM_CONST(i32_one),
        LLVM_CONST(i32_two),      LLVM_CONST(i32_three),
        LLVM_CONST(i32_four),     LLVM_CONST(i32_five),
        LLVM_CONST(i32_six),      LLVM_CONST(i32_seven),
        LLVM_CONST(i32_eight),    LLVM_CONST(i32_nine),
        LLVM_CONST(i32_ten),      LLVM_CONST(i32_eleven),
        LLVM_CONST(i32_twelve),   LLVM_CONST(i32_thirteen),
        LLVM_CONST(i32_fourteen), LLVM_CONST(i32_fifteen),
    ];

    if (((trunc_type[0] = LLVMVectorType(INT8_TYPE, 8)) == 0)
        || ((trunc_type[1] = LLVMVectorType(INT16_TYPE, 4)) == 0)
        || ((trunc_type[2] = LLVMVectorType(I32_TYPE, 2)) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        return false;
    }

    if (((vec2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                           in_vector_type[itype], "vec2")) == 0)
        || ((vec1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                              in_vector_type[itype], "vec1")) == 0)) {
        return false;
    }

    if (((max = simd_build_splat_const_integer_vector(
              comp_ctx, min_max_type[itype],
              is_signed ? smax[itype] : umax[itype], length[itype])) == 0)
        || ((min = simd_build_splat_const_integer_vector(
                 comp_ctx, min_max_type[itype],
                 is_signed ? smin[itype] : umin[itype], length[itype])) == 0)) {
        return false;
    }

    /* sat */
    if (((vec1 = simd_saturate(comp_ctx, func_ctx, e_sat_i16x8, vec1, min, max,
                               is_signed)) == 0)
        || ((vec2 = simd_saturate(comp_ctx, func_ctx, e_sat_i16x8, vec2, min,
                                  max, is_signed)) == 0)) {
        return false;
    }

    /* trunc */
    if (((vec1 = LLVMBuildTrunc(comp_ctx.builder, vec1, trunc_type[itype],
                                "vec1_trunc")) == 0)
        || ((vec2 = LLVMBuildTrunc(comp_ctx.builder, vec2, trunc_type[itype],
                                   "vec2_trunc")) == 0)) {
        HANDLE_FAILURE("LLVMBuildTrunc");
        return false;
    }

    /* combine */
    if (((mask = LLVMConstVector(mask_element.ptr, (length[itype] << 1))) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        return false;
    }

    if (((result = LLVMBuildShuffleVector(comp_ctx.builder, vec1, vec2, mask,
                                          "vec_shuffle")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i8x16_narrow_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    if (is_target_x86(comp_ctx)) {
        return simd_integer_narrow_x86(
            comp_ctx, func_ctx, V128_i16x8_TYPE, V128_i8x16_TYPE,
            is_signed ? "llvm.x86.sse2.packsswb.128"
                      : "llvm.x86.sse2.packuswb.128");
    }
    else {
        return simd_integer_narrow_common(comp_ctx, func_ctx, e_sat_i16x8,
                                          is_signed);
    }
}

bool aot_compile_simd_i16x8_narrow_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    if (is_target_x86(comp_ctx)) {
        return simd_integer_narrow_x86(comp_ctx, func_ctx, V128_i32x4_TYPE,
                                       V128_i16x8_TYPE,
                                       is_signed ? "llvm.x86.sse2.packssdw.128"
                                                 : "llvm.x86.sse41.packusdw");
    }
    else {
        return simd_integer_narrow_common(comp_ctx, func_ctx, e_sat_i32x4,
                                          is_signed);
    }
}

bool aot_compile_simd_i32x4_narrow_i64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    /* TODO: x86 intrinsics */
    return simd_integer_narrow_common(comp_ctx, func_ctx, e_sat_i64x2,
                                      is_signed);
}

enum integer_extend_type {
    e_ext_i8x16,
    e_ext_i16x8,
    e_ext_i32x4,
}
alias e_ext_i8x16 = integer_extend_type.e_ext_i8x16;
alias e_ext_i16x8 = integer_extend_type.e_ext_i16x8;
alias e_ext_i32x4 = integer_extend_type.e_ext_i32x4;


private LLVMValueRef simd_integer_extension(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, integer_extend_type itype, LLVMValueRef vector, bool lower_half, bool is_signed) {
    LLVMValueRef mask = void, sub_vector = void, result = void;
    LLVMValueRef[17] bits = [
        LLVM_CONST(i32_zero),     LLVM_CONST(i32_one),
        LLVM_CONST(i32_two),      LLVM_CONST(i32_three),
        LLVM_CONST(i32_four),     LLVM_CONST(i32_five),
        LLVM_CONST(i32_six),      LLVM_CONST(i32_seven),
        LLVM_CONST(i32_eight),    LLVM_CONST(i32_nine),
        LLVM_CONST(i32_ten),      LLVM_CONST(i32_eleven),
        LLVM_CONST(i32_twelve),   LLVM_CONST(i32_thirteen),
        LLVM_CONST(i32_fourteen), LLVM_CONST(i32_fifteen),
    ];
    LLVMTypeRef[3] out_vector_type = [ V128_i16x8_TYPE, V128_i32x4_TYPE,
                                      V128_i64x2_TYPE ];
    LLVMValueRef[3] undef = [ LLVM_CONST(i8x16_undef), LLVM_CONST(i16x8_undef),
                             LLVM_CONST(i32x4_undef) ];
    uint[3] sub_vector_length = [ 8, 4, 2 ];

    if (!(mask = lower_half ? LLVMConstVector(bits.ptr, sub_vector_length[itype])
                            : LLVMConstVector(bits.ptr + sub_vector_length[itype],
                                              sub_vector_length[itype]))) {
        HANDLE_FAILURE("LLVMConstVector");
        return false;
    }

    /* retrive the low or high half */
    if (((sub_vector = LLVMBuildShuffleVector(comp_ctx.builder, vector,
                                              undef[itype], mask, "half")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    if (is_signed) {
        if (((result = LLVMBuildSExt(comp_ctx.builder, sub_vector,
                                     out_vector_type[itype], "sext")) == 0)) {
            HANDLE_FAILURE("LLVMBuildSExt");
            return false;
        }
    }
    else {
        if (((result = LLVMBuildZExt(comp_ctx.builder, sub_vector,
                                     out_vector_type[itype], "zext")) == 0)) {
            HANDLE_FAILURE("LLVMBuildZExt");
            return false;
        }
    }

    return result;
}

private bool simd_integer_extension_wrapper(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, integer_extend_type itype, bool lower_half, bool is_signed) {
    LLVMValueRef vector = void, result = void;

    LLVMTypeRef[3] in_vector_type = [ V128_i8x16_TYPE, V128_i16x8_TYPE,
                                     V128_i32x4_TYPE ];

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             in_vector_type[itype], "vec")) == 0)) {
        return false;
    }

    if (((result = simd_integer_extension(comp_ctx, func_ctx, itype, vector,
                                          lower_half, is_signed)) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i16x8_extend_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed) {
    return simd_integer_extension_wrapper(comp_ctx, func_ctx, e_ext_i8x16,
                                          lower_half, is_signed);
}

bool aot_compile_simd_i32x4_extend_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed) {
    return simd_integer_extension_wrapper(comp_ctx, func_ctx, e_ext_i16x8,
                                          lower_half, is_signed);
}

bool aot_compile_simd_i64x2_extend_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed) {
    return simd_integer_extension_wrapper(comp_ctx, func_ctx, e_ext_i32x4,
                                          lower_half, is_signed);
}

private LLVMValueRef simd_trunc_sat(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, const(char)* intrinsics, LLVMTypeRef in_vector_type, LLVMTypeRef out_vector_type) {
    LLVMValueRef vector = void, result = void;
    LLVMTypeRef[1] param_types = [ in_vector_type ];

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, in_vector_type,
                                             "vector")) == 0)) {
        return false;
    }

    if (((result = aot_call_llvm_intrinsic(comp_ctx, func_ctx, intrinsics,
                                           out_vector_type, param_types.ptr, 1,
                                           vector)) == 0)) {
        return false;
    }

    return result;
}

bool aot_compile_simd_i32x4_trunc_sat_f32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    LLVMValueRef result = void;
    if (((result = simd_trunc_sat(comp_ctx, func_ctx,
                                  is_signed ? "llvm.fptosi.sat.v4i32.v4f32"
                                            : "llvm.fptoui.sat.v4i32.v4f32",
                                  V128_f32x4_TYPE, V128_i32x4_TYPE)) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i32x4_trunc_sat_f64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    LLVMValueRef result = void, zero = void, mask = void;
    LLVMTypeRef out_vector_type = void;
    LLVMValueRef[5] lanes = [
        LLVM_CONST(i32_zero),
        LLVM_CONST(i32_one),
        LLVM_CONST(i32_two),
        LLVM_CONST(i32_three),
    ];

    if (((out_vector_type = LLVMVectorType(I32_TYPE, 2)) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        return false;
    }

    if (((result = simd_trunc_sat(comp_ctx, func_ctx,
                                  is_signed ? "llvm.fptosi.sat.v2i32.v2f64"
                                            : "llvm.fptoui.sat.v2i32.v2f64",
                                  V128_f64x2_TYPE, out_vector_type)) == 0)) {
        return false;
    }

    if (((zero = LLVMConstNull(out_vector_type)) == 0)) {
        HANDLE_FAILURE("LLVMConstNull");
        return false;
    }

    /* v2i32 -> v4i32 */
    if (((mask = LLVMConstVector(lanes.ptr, 4)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        return false;
    }

    if (((result = LLVMBuildShuffleVector(comp_ctx.builder, result, zero, mask,
                                          "extend")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

private LLVMValueRef simd_integer_convert(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed, LLVMValueRef vector, LLVMTypeRef out_vector_type) {
    LLVMValueRef result = void;
    result = is_signed ? LLVMBuildSIToFP(comp_ctx.builder, vector,
                                         out_vector_type, "converted")
                       : LLVMBuildUIToFP(comp_ctx.builder, vector,
                                         out_vector_type, "converted");
    if (!result) {
        HANDLE_FAILURE("LLVMBuildSIToFP/LLVMBuildUIToFP");
    }

    return result;
}

bool aot_compile_simd_f32x4_convert_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    LLVMValueRef vector = void, result = void;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_i32x4_TYPE, "vec")) == 0)) {
        return false;
    }

    if (((result = simd_integer_convert(comp_ctx, func_ctx, is_signed, vector,
                                        V128_f32x4_TYPE)) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_f64x2_convert_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    LLVMValueRef vector = void, mask = void, result = void;
    LLVMValueRef[3] lanes = [
        LLVM_CONST(i32_zero),
        LLVM_CONST(i32_one),
    ];
    LLVMTypeRef out_vector_type = void;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_i32x4_TYPE, "vec")) == 0)) {
        return false;
    }

    if (((out_vector_type = LLVMVectorType(F64_TYPE, 4)) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        return false;
    }

    if (((result = simd_integer_convert(comp_ctx, func_ctx, is_signed, vector,
                                        out_vector_type)) == 0)) {
        return false;
    }

    /* v4f64 -> v2f64 */
    if (((mask = LLVMConstVector(lanes.ptr, 2)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        return false;
    }

    if (((result = LLVMBuildShuffleVector(comp_ctx.builder, result, result,
                                          mask, "trunc")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

private bool simd_extadd_pairwise(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef in_vector_type, LLVMTypeRef out_vector_type, bool is_signed) {
    LLVMValueRef vector = void, even_mask = void, odd_mask = void, sub_vector_even = void, sub_vector_odd = void, result = void;

    LLVMValueRef[9] even_element = [
        LLVM_CONST(i32_zero),   LLVM_CONST(i32_two),      LLVM_CONST(i32_four),
        LLVM_CONST(i32_six),    LLVM_CONST(i32_eight),    LLVM_CONST(i32_ten),
        LLVM_CONST(i32_twelve), LLVM_CONST(i32_fourteen),
    ];

    LLVMValueRef[9] odd_element = [
        LLVM_CONST(i32_one),      LLVM_CONST(i32_three),
        LLVM_CONST(i32_five),     LLVM_CONST(i32_seven),
        LLVM_CONST(i32_nine),     LLVM_CONST(i32_eleven),
        LLVM_CONST(i32_thirteen), LLVM_CONST(i32_fifteen),
    ];

    /* assumption about i16x8 from i8x16 and i32x4 from i16x8 */
    ubyte mask_length = V128_i16x8_TYPE == out_vector_type ? 8 : 4;

    if (((vector = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, in_vector_type,
                                             "vector")) == 0)) {
        return false;
    }

    if (((even_mask = LLVMConstVector(even_element.ptr, mask_length)) == 0)
        || ((odd_mask = LLVMConstVector(odd_element.ptr, mask_length)) == 0)) {
        HANDLE_FAILURE("LLVMConstVector");
        return false;
    }

    /* shuffle a <16xi8> vector to two <8xi8> vectors */
    if (((sub_vector_even = LLVMBuildShuffleVector(
              comp_ctx.builder, vector, vector, even_mask, "pick_even")) == 0)
        || ((sub_vector_odd = LLVMBuildShuffleVector(
                 comp_ctx.builder, vector, vector, odd_mask, "pick_odd")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    /* sext/zext <8xi8> to <8xi16> */
    if (is_signed) {
        if (((sub_vector_even =
                  LLVMBuildSExt(comp_ctx.builder, sub_vector_even,
                                out_vector_type, "even_sext")) == 0)
            || ((sub_vector_odd =
                     LLVMBuildSExt(comp_ctx.builder, sub_vector_odd,
                                   out_vector_type, "odd_sext")) == 0)) {
            HANDLE_FAILURE("LLVMBuildSExt");
            return false;
        }
    }
    else {
        if (((sub_vector_even =
                  LLVMBuildZExt(comp_ctx.builder, sub_vector_even,
                                out_vector_type, "even_zext")) == 0)
            || ((sub_vector_odd =
                     LLVMBuildZExt(comp_ctx.builder, sub_vector_odd,
                                   out_vector_type, "odd_zext")) == 0)) {
            HANDLE_FAILURE("LLVMBuildZExt");
            return false;
        }
    }

    if (((result = LLVMBuildAdd(comp_ctx.builder, sub_vector_even,
                                sub_vector_odd, "sum")) == 0)) {
        HANDLE_FAILURE("LLVMBuildAdd");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i16x8_extadd_pairwise_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    return simd_extadd_pairwise(comp_ctx, func_ctx, V128_i8x16_TYPE,
                                V128_i16x8_TYPE, is_signed);
}

bool aot_compile_simd_i32x4_extadd_pairwise_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed) {
    return simd_extadd_pairwise(comp_ctx, func_ctx, V128_i16x8_TYPE,
                                V128_i32x4_TYPE, is_signed);
}

bool aot_compile_simd_i16x8_q15mulr_sat(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef lhs = void, rhs = void, pad = void, offset = void, min = void, max = void, result = void;
    LLVMTypeRef vector_ext_type = void;

    if (((rhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx, V128_i16x8_TYPE,
                                          "rhs")) == 0)
        || ((lhs = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                             V128_i16x8_TYPE, "lhs")) == 0)) {
        return false;
    }

    if (((vector_ext_type = LLVMVectorType(I32_TYPE, 8)) == 0)) {
        HANDLE_FAILURE("LLVMVectorType");
        return false;
    }

    if (((lhs = LLVMBuildSExt(comp_ctx.builder, lhs, vector_ext_type,
                              "lhs_v8i32")) == 0)
        || ((rhs = LLVMBuildSExt(comp_ctx.builder, rhs, vector_ext_type,
                                 "rhs_v8i32")) == 0)) {
        HANDLE_FAILURE("LLVMBuildSExt");
        return false;
    }

    /* 0x4000 and 15*/
    if (((pad = simd_build_splat_const_integer_vector(comp_ctx, I32_TYPE,
                                                      0x4000, 8)) == 0)
        || ((offset = simd_build_splat_const_integer_vector(comp_ctx, I32_TYPE,
                                                            15, 8)) == 0)) {
        return false;
    }

    /* TODO: looking for x86 intrinsics about integer"fused multiply-and-add" */
    /* S.SignedSaturate((x * y + 0x4000) >> 15) */
    if (((result = LLVMBuildMul(comp_ctx.builder, lhs, rhs, "mul")) == 0)) {
        HANDLE_FAILURE("LLVMBuildMul");
        return false;
    }

    if (((result = LLVMBuildAdd(comp_ctx.builder, result, pad, "add")) == 0)) {
        HANDLE_FAILURE("LLVMBuildAdd");
        return false;
    }

    if (((result = LLVMBuildAShr(comp_ctx.builder, result, offset, "ashr")) == 0)) {
        HANDLE_FAILURE("LLVMBuildAShr");
        return false;
    }

    if (((min = simd_build_splat_const_integer_vector(comp_ctx, I32_TYPE,
                                                      0xffff8000, 8)) == 0)
        || ((max = simd_build_splat_const_integer_vector(comp_ctx, I32_TYPE,
                                                         0x00007fff, 8)) == 0)) {
        return false;
    }

    /* sat after trunc will let *sat* part be optimized */
    if (((result = simd_saturate(comp_ctx, func_ctx, e_sat_i32x8, result, min,
                                 max, true)) == 0)) {
        return false;
    }

    if (((result = LLVMBuildTrunc(comp_ctx.builder, result, V128_i16x8_TYPE,
                                  "down_to_v8i16")) == 0)) {
        HANDLE_FAILURE("LLVMBuidlTrunc");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

enum integer_extmul_type {
    e_i16x8_extmul_i8x16,
    e_i32x4_extmul_i16x8,
    e_i64x2_extmul_i32x4,
}
alias e_i16x8_extmul_i8x16 = integer_extmul_type.e_i16x8_extmul_i8x16;
alias e_i32x4_extmul_i16x8 = integer_extmul_type.e_i32x4_extmul_i16x8;
alias e_i64x2_extmul_i32x4 = integer_extmul_type.e_i64x2_extmul_i32x4;


private bool simd_integer_extmul(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed, integer_extmul_type itype) {
    LLVMValueRef vec1 = void, vec2 = void, result = void;
    integer_extend_type[4] ext_type = [
        e_ext_i8x16,
        e_ext_i16x8,
        e_ext_i32x4,
    ];
    LLVMTypeRef[4] in_vector_type = [
        V128_i8x16_TYPE,
        V128_i16x8_TYPE,
        V128_i32x4_TYPE,
    ];

    if (((vec1 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                           in_vector_type[itype], "vec1")) == 0)
        || ((vec2 = simd_pop_v128_and_bitcast(comp_ctx, func_ctx,
                                              in_vector_type[itype], "vec2")) == 0)) {
        return false;
    }

    if (((vec1 = simd_integer_extension(comp_ctx, func_ctx, ext_type[itype],
                                        vec1, lower_half, is_signed)) == 0)
        || ((vec2 = simd_integer_extension(comp_ctx, func_ctx, ext_type[itype],
                                           vec2, lower_half, is_signed)) == 0)) {
        return false;
    }

    if (((result = LLVMBuildMul(comp_ctx.builder, vec1, vec2, "product")) == 0)) {
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_i16x8_extmul_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed) {
    return simd_integer_extmul(comp_ctx, func_ctx, lower_half, is_signed,
                               e_i16x8_extmul_i8x16);
}

bool aot_compile_simd_i32x4_extmul_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed) {
    return simd_integer_extmul(comp_ctx, func_ctx, lower_half, is_signed,
                               e_i32x4_extmul_i16x8);
}

bool aot_compile_simd_i64x2_extmul_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed) {
    return simd_integer_extmul(comp_ctx, func_ctx, lower_half, is_signed,
                               e_i64x2_extmul_i32x4);
}/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...aot_compiler;

version (none) {
extern "C" {
//! #endif

bool aot_compile_simd_i8x16_narrow_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_i16x8_narrow_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_i32x4_narrow_i64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_i16x8_extend_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_low, bool is_signed);

bool aot_compile_simd_i32x4_extend_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_low, bool is_signed);

bool aot_compile_simd_i64x2_extend_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed);

bool aot_compile_simd_i32x4_trunc_sat_f32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_i32x4_trunc_sat_f64x2(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_f32x4_convert_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_f64x2_convert_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);
bool aot_compile_simd_i16x8_extadd_pairwise_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);

bool aot_compile_simd_i32x4_extadd_pairwise_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_signed);
bool aot_compile_simd_i16x8_q15mulr_sat(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_simd_i16x8_extmul_i8x16(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_low, bool is_signed);

bool aot_compile_simd_i32x4_extmul_i16x8(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_low, bool is_signed);

bool aot_compile_simd_i64x2_extmul_i32x4(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool lower_half, bool is_signed);
version (none) {}
} /* end of extern "C" */
}

 /* end of _SIMD_CONVERSIONS_H_ */
