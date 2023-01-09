module tagion.iwasm.compilation.simd.simd_load_store;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.compilation.simd.simd_common;
import tagion.iwasm.compilation.simd.simd_load_store;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.compilation.aot_emit_memory;
import tagion.iwasm.aot.aot_runtime;
import tagion.iwasm.interpreter.wasm_opcode;

/* data_length in bytes */
private LLVMValueRef simd_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint data_length, LLVMTypeRef ptr_type, LLVMTypeRef data_type) {
    LLVMValueRef maddr = void, data = void;

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset,
                                            data_length)) == 0)) {
        HANDLE_FAILURE("aot_check_memory_overflow");
        return null;
    }

    if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, ptr_type,
                                   "data_ptr")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        return null;
    }

    if (((data = LLVMBuildLoad2(comp_ctx.builder, data_type, maddr, "data")) == 0)) {
        HANDLE_FAILURE("LLVMBuildLoad");
        return null;
    }

    LLVMSetAlignment(data, 1);

    return data;
}

bool aot_compile_simd_v128_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef result = void;

    if (((result = simd_load(comp_ctx, func_ctx, align_, offset, 16,
                             V128_PTR_TYPE, V128_TYPE)) == 0)) {
        return false;
    }

    PUSH_V128(result);

    return true;
fail:
    return false;
}

bool aot_compile_simd_load_extend(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte opcode, uint align_, uint offset) {
    LLVMValueRef sub_vector = void, result = void;
    uint opcode_index = opcode - SIMD_v128_load8x8_s;
    bool[6] signeds = [ true, false, true, false, true, false ];
    LLVMTypeRef[7] vector_types = [
        V128_i16x8_TYPE, V128_i16x8_TYPE, V128_i32x4_TYPE,
        V128_i32x4_TYPE, V128_i64x2_TYPE, V128_i64x2_TYPE,
    ];
    LLVMTypeRef[7] sub_vector_types = [
        LLVMVectorType(INT8_TYPE, 8),  LLVMVectorType(INT8_TYPE, 8),
        LLVMVectorType(INT16_TYPE, 4), LLVMVectorType(INT16_TYPE, 4),
        LLVMVectorType(I32_TYPE, 2),   LLVMVectorType(I32_TYPE, 2),
    ];
    LLVMTypeRef sub_vector_type = void, sub_vector_ptr_type = void;

    bh_assert(opcode_index < 6);

    sub_vector_type = sub_vector_types[opcode_index];

    /* to vector ptr type */
    if (!sub_vector_type
        || ((sub_vector_ptr_type = LLVMPointerType(sub_vector_type, 0)) == 0)) {
        HANDLE_FAILURE("LLVMPointerType");
        return false;
    }

    if (((sub_vector = simd_load(comp_ctx, func_ctx, align_, offset, 8,
                                 sub_vector_ptr_type, sub_vector_type)) == 0)) {
        return false;
    }

    if (signeds[opcode_index]) {
        if (((result = LLVMBuildSExt(comp_ctx.builder, sub_vector,
                                     vector_types[opcode_index], "vector")) == 0)) {
            HANDLE_FAILURE("LLVMBuildSExt");
            return false;
        }
    }
    else {
        if (((result = LLVMBuildZExt(comp_ctx.builder, sub_vector,
                                     vector_types[opcode_index], "vector")) == 0)) {
            HANDLE_FAILURE("LLVMBuildZExt");
            return false;
        }
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_load_splat(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte opcode, uint align_, uint offset) {
    uint opcode_index = opcode - SIMD_v128_load8_splat;
    LLVMValueRef element = void, result = void;
    LLVMTypeRef[4] element_ptr_types = [ INT8_PTR_TYPE, INT16_PTR_TYPE,
                                        INT32_PTR_TYPE, INT64_PTR_TYPE ];
    LLVMTypeRef[4] element_data_types = [ INT8_TYPE, INT16_TYPE, I32_TYPE,
                                         I64_TYPE ];
    uint[4] data_lengths = [ 1, 2, 4, 8 ];
    LLVMValueRef[5] undefs = [
        LLVM_CONST(i8x16_undef),
        LLVM_CONST(i16x8_undef),
        LLVM_CONST(i32x4_undef),
        LLVM_CONST(i64x2_undef),
    ];
    LLVMValueRef[5] masks = [
        LLVM_CONST(i32x16_zero),
        LLVM_CONST(i32x8_zero),
        LLVM_CONST(i32x4_zero),
        LLVM_CONST(i32x2_zero),
    ];

    bh_assert(opcode_index < 4);

    if (((element = simd_load(comp_ctx, func_ctx, align_, offset,
                              data_lengths[opcode_index],
                              element_ptr_types[opcode_index],
                              element_data_types[opcode_index])) == 0)) {
        return false;
    }

    if (((result =
              LLVMBuildInsertElement(comp_ctx.builder, undefs[opcode_index],
                                     element, I32_ZERO, "base")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        return false;
    }

    if (((result = LLVMBuildShuffleVector(comp_ctx.builder, result,
                                          undefs[opcode_index],
                                          masks[opcode_index], "vector")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

bool aot_compile_simd_load_lane(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte opcode, uint align_, uint offset, ubyte lane_id) {
    LLVMValueRef element = void, vector = void;
    uint opcode_index = opcode - SIMD_v128_load8_lane;
    uint[4] data_lengths = [ 1, 2, 4, 8 ];
    LLVMTypeRef[4] element_ptr_types = [ INT8_PTR_TYPE, INT16_PTR_TYPE,
                                        INT32_PTR_TYPE, INT64_PTR_TYPE ];
    LLVMTypeRef[4] element_data_types = [ INT8_TYPE, INT16_TYPE, I32_TYPE,
                                         I64_TYPE ];
    LLVMTypeRef[4] vector_types = [ V128_i8x16_TYPE, V128_i16x8_TYPE,
                                   V128_i32x4_TYPE, V128_i64x2_TYPE ];
    LLVMValueRef lane = simd_lane_id_to_llvm_value(comp_ctx, lane_id);

    bh_assert(opcode_index < 4);

    if (((vector = simd_pop_v128_and_bitcast(
              comp_ctx, func_ctx, vector_types[opcode_index], "src")) == 0)) {
        return false;
    }

    if (((element = simd_load(comp_ctx, func_ctx, align_, offset,
                              data_lengths[opcode_index],
                              element_ptr_types[opcode_index],
                              element_data_types[opcode_index])) == 0)) {
        return false;
    }

    if (((vector = LLVMBuildInsertElement(comp_ctx.builder, vector, element,
                                          lane, "dst")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, vector, "result");
}

bool aot_compile_simd_load_zero(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte opcode, uint align_, uint offset) {
    LLVMValueRef element = void, result = void, mask = void;
    uint opcode_index = opcode - SIMD_v128_load32_zero;
    uint[2] data_lengths = [ 4, 8 ];
    LLVMTypeRef[2] element_ptr_types = [ INT32_PTR_TYPE, INT64_PTR_TYPE ];
    LLVMTypeRef[2] element_data_types = [ I32_TYPE, I64_TYPE ];
    LLVMValueRef[3] zero = [
        LLVM_CONST(i32x4_vec_zero),
        LLVM_CONST(i64x2_vec_zero),
    ];
    LLVMValueRef[3] undef = [
        LLVM_CONST(i32x4_undef),
        LLVM_CONST(i64x2_undef),
    ];
    uint[2] mask_length = [ 4, 2 ];
    LLVMValueRef[4][3] mask_element = [
        [ LLVM_CONST(i32_zero), LLVM_CONST(i32_four), LLVM_CONST(i32_five),
          LLVM_CONST(i32_six) ],
        [ LLVM_CONST(i32_zero), LLVM_CONST(i32_two) ],
    ];

    bh_assert(opcode_index < 2);

    if (((element = simd_load(comp_ctx, func_ctx, align_, offset,
                              data_lengths[opcode_index],
                              element_ptr_types[opcode_index],
                              element_data_types[opcode_index])) == 0)) {
        return false;
    }

    if (((result =
              LLVMBuildInsertElement(comp_ctx.builder, undef[opcode_index],
                                     element, I32_ZERO, "vector")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInsertElement");
        return false;
    }

    /* fill in other lanes with zero */
    if (((mask = LLVMConstVector(mask_element[opcode_index],
                                 mask_length[opcode_index])) == 0)) {
        HANDLE_FAILURE("LLConstVector");
        return false;
    }

    if (((result = LLVMBuildShuffleVector(comp_ctx.builder, result,
                                          zero[opcode_index], mask,
                                          "fill_in_zero")) == 0)) {
        HANDLE_FAILURE("LLVMBuildShuffleVector");
        return false;
    }

    return simd_bitcast_and_push_v128(comp_ctx, func_ctx, result, "result");
}

/* data_length in bytes */
private bool simd_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint data_length, LLVMValueRef value, LLVMTypeRef value_ptr_type) {
    LLVMValueRef maddr = void, result = void;

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset,
                                            data_length)) == 0))
        return false;

    if (((maddr = LLVMBuildBitCast(comp_ctx.builder, maddr, value_ptr_type,
                                   "data_ptr")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        return false;
    }

    if (((result = LLVMBuildStore(comp_ctx.builder, value, maddr)) == 0)) {
        HANDLE_FAILURE("LLVMBuildStore");
        return false;
    }

    LLVMSetAlignment(result, 1);

    return true;
}

bool aot_compile_simd_v128_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef value = void;

    POP_V128(value);

    return simd_store(comp_ctx, func_ctx, align_, offset, 16, value,
                      V128_PTR_TYPE);
fail:
    return false;
}

bool aot_compile_simd_store_lane(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte opcode, uint align_, uint offset, ubyte lane_id) {
    LLVMValueRef element = void, vector = void;
    uint[4] data_lengths = [ 1, 2, 4, 8 ];
    LLVMTypeRef[4] element_ptr_types = [ INT8_PTR_TYPE, INT16_PTR_TYPE,
                                        INT32_PTR_TYPE, INT64_PTR_TYPE ];
    uint opcode_index = opcode - SIMD_v128_store8_lane;
    LLVMTypeRef[4] vector_types = [ V128_i8x16_TYPE, V128_i16x8_TYPE,
                                   V128_i32x4_TYPE, V128_i64x2_TYPE ];
    LLVMValueRef lane = simd_lane_id_to_llvm_value(comp_ctx, lane_id);

    bh_assert(opcode_index < 4);

    if (((vector = simd_pop_v128_and_bitcast(
              comp_ctx, func_ctx, vector_types[opcode_index], "src")) == 0)) {
        return false;
    }

    if (((element = LLVMBuildExtractElement(comp_ctx.builder, vector, lane,
                                            "element")) == 0)) {
        HANDLE_FAILURE("LLVMBuildExtractElement");
        return false;
    }

    return simd_store(comp_ctx, func_ctx, align_, offset,
                      data_lengths[opcode_index], element,
                      element_ptr_types[opcode_index]);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
