module tagion.iwasm.compilation.aot_emit_const;
@nogc nothrow:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.llvm.llvm_c.Types;
import tagion.iwasm.compilation.aot_llvm;
import tagion.iwasm.aot.aot_intrinsic;

bool aot_compile_op_i32_const(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, int i32_const) {
    LLVMValueRef value = void;

    if (comp_ctx.is_indirect_mode
        && aot_intrinsic_check_capability(comp_ctx, "i32.const")) {
        WASMValue wasm_value = void;
        wasm_value.i32 = i32_const;
        value = aot_load_const_from_table(comp_ctx, func_ctx.native_symbol,
                                          &wasm_value, VALUE_TYPE_I32);
        if (!value) {
            return false;
        }
    }
    else {
        value = I32_CONST(cast(uint)i32_const);
        CHECK_LLVM_CONST(value);
    }

    PUSH_I32(value);
    return true;
fail:
    return false;
}

bool aot_compile_op_i64_const(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, long i64_const) {
    LLVMValueRef value = void;

    if (comp_ctx.is_indirect_mode
        && aot_intrinsic_check_capability(comp_ctx, "i64.const")) {
        WASMValue wasm_value = void;
        wasm_value.i64 = i64_const;
        value = aot_load_const_from_table(comp_ctx, func_ctx.native_symbol,
                                          &wasm_value, VALUE_TYPE_I64);
        if (!value) {
            return false;
        }
    }
    else {
        value = I64_CONST(cast(ulong)i64_const);
        CHECK_LLVM_CONST(value);
    }

    PUSH_I64(value);
    return true;
fail:
    return false;
}

bool aot_compile_op_f32_const(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, float f32_const) {
    LLVMValueRef alloca = void, value = void;

    if (!isnan(f32_const)) {
        if (comp_ctx.is_indirect_mode
            && aot_intrinsic_check_capability(comp_ctx, "f32.const")) {
            WASMValue wasm_value = void;
            memcpy(&wasm_value.f32, &f32_const, float.sizeof);
            value = aot_load_const_from_table(comp_ctx, func_ctx.native_symbol,
                                              &wasm_value, VALUE_TYPE_F32);
            if (!value) {
                return false;
            }
            PUSH_F32(value);
        }
        else {
            value = F32_CONST(f32_const);
            CHECK_LLVM_CONST(value);
            PUSH_F32(value);
        }
    }
    else {
        int i32_const = void;
        memcpy(&i32_const, &f32_const, int32.sizeof);
        if (((alloca =
                  LLVMBuildAlloca(comp_ctx.builder, I32_TYPE, "i32_ptr")) == 0)) {
            aot_set_last_error("llvm build alloca failed.");
            return false;
        }
        if (!LLVMBuildStore(comp_ctx.builder, I32_CONST(cast(uint)i32_const),
                            alloca)) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
        if (((alloca = LLVMBuildBitCast(comp_ctx.builder, alloca, F32_PTR_TYPE,
                                        "f32_ptr")) == 0)) {
            aot_set_last_error("llvm build bitcast failed.");
            return false;
        }
        if (((value =
                  LLVMBuildLoad2(comp_ctx.builder, F32_TYPE, alloca, "")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            return false;
        }
        PUSH_F32(value);
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_f64_const(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, double f64_const) {
    LLVMValueRef alloca = void, value = void;

    if (!isnan(f64_const)) {
        if (comp_ctx.is_indirect_mode
            && aot_intrinsic_check_capability(comp_ctx, "f64.const")) {
            WASMValue wasm_value = void;
            memcpy(&wasm_value.f64, &f64_const, double.sizeof);
            value = aot_load_const_from_table(comp_ctx, func_ctx.native_symbol,
                                              &wasm_value, VALUE_TYPE_F64);
            if (!value) {
                return false;
            }
            PUSH_F64(value);
        }
        else {
            value = F64_CONST(f64_const);
            CHECK_LLVM_CONST(value);
            PUSH_F64(value);
        }
    }
    else {
        long i64_const = void;
        memcpy(&i64_const, &f64_const, int64.sizeof);
        if (((alloca =
                  LLVMBuildAlloca(comp_ctx.builder, I64_TYPE, "i64_ptr")) == 0)) {
            aot_set_last_error("llvm build alloca failed.");
            return false;
        }
        value = I64_CONST(cast(ulong)i64_const);
        CHECK_LLVM_CONST(value);
        if (!LLVMBuildStore(comp_ctx.builder, value, alloca)) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
        if (((alloca = LLVMBuildBitCast(comp_ctx.builder, alloca, F64_PTR_TYPE,
                                        "f64_ptr")) == 0)) {
            aot_set_last_error("llvm build bitcast failed.");
            return false;
        }
        if (((value =
                  LLVMBuildLoad2(comp_ctx.builder, F64_TYPE, alloca, "")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            return false;
        }
        PUSH_F64(value);
    }

    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 