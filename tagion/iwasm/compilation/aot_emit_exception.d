module tagion.iwasm.compilation.aot_emit_exception;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.interpreter.wasm_runtime;
import tagion.iwasm.aot.aot_runtime;

bool aot_emit_exception(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, int exception_id, bool is_cond_br, LLVMValueRef cond_br_if, LLVMBasicBlockRef cond_br_else_block) {
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMValueRef exce_id = I32_CONST(cast(uint)exception_id), func_const = void, func = void;
    LLVMTypeRef[2] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMValueRef[2] param_values = void;

    bh_assert(exception_id >= 0 && exception_id < EXCE_NUM);

    CHECK_LLVM_CONST(exce_id);

    /* Create got_exception block if needed */
    if (!func_ctx.got_exception_block) {
        if (((func_ctx.got_exception_block = LLVMAppendBasicBlockInContext(
                  comp_ctx.context, func_ctx.func, "got_exception")) == 0)) {
            aot_set_last_error("add LLVM basic block failed.");
            return false;
        }

        LLVMPositionBuilderAtEnd(comp_ctx.builder,
                                 func_ctx.got_exception_block);

        /* Create exection id phi */
        if (((func_ctx.exception_id_phi = LLVMBuildPhi(
                  comp_ctx.builder, I32_TYPE, "exception_id_phi")) == 0)) {
            aot_set_last_error("llvm build phi failed.");
            return false;
        }

        /* Call aot_set_exception_with_id() to throw exception */
        param_types[0] = INT8_PTR_TYPE;
        param_types[1] = I32_TYPE;
        ret_type = VOID_TYPE;

        /* Create function type */
        if (((func_type = LLVMFunctionType(ret_type, param_types.ptr, 2, false)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }

        if (comp_ctx.is_jit_mode) {
            /* Create function type */
            if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
                aot_set_last_error("create LLVM function type failed.");
                return false;
            }
            /* Create LLVM function with const function pointer */
            if (((func_const =
                      I64_CONST(cast(ulong)cast(uintptr_t)jit_set_exception_with_id)) == 0)
                || ((func = LLVMConstIntToPtr(func_const, func_ptr_type)) == 0)) {
                aot_set_last_error("create LLVM value failed.");
                return false;
            }
        }
        else if (comp_ctx.is_indirect_mode) {
            int func_index = void;
            if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
                aot_set_last_error("create LLVM function type failed.");
                return false;
            }

            func_index = aot_get_native_symbol_index(
                comp_ctx, "aot_set_exception_with_id");
            if (func_index < 0) {
                return false;
            }
            if (((func =
                      aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                              func_ptr_type, func_index)) == 0)) {
                return false;
            }
        }
        else {
            /* Create LLVM function with external function pointer */
            if (((func = LLVMGetNamedFunction(func_ctx.module_,
                                              "aot_set_exception_with_id")) == 0)
                && ((func = LLVMAddFunction(func_ctx.module_,
                                            "aot_set_exception_with_id",
                                            func_type)) == 0)) {
                aot_set_last_error("add LLVM function failed.");
                return false;
            }
        }

        /* Call the aot_set_exception_with_id() function */
        param_values[0] = func_ctx.aot_inst;
        param_values[1] = func_ctx.exception_id_phi;
        if (!LLVMBuildCall2(comp_ctx.builder, func_type, func, param_values.ptr, 2,
                            "")) {
            aot_set_last_error("llvm build call failed.");
            return false;
        }

        /* Create return IR */
        AOTFuncType* aot_func_type = func_ctx.aot_func.func_type;
        if (!aot_build_zero_function_ret(comp_ctx, func_ctx, aot_func_type)) {
            return false;
        }

        /* Resume the builder position */
        LLVMPositionBuilderAtEnd(comp_ctx.builder, block_curr);
    }

    /* Add phi incoming value to got_exception block */
    LLVMAddIncoming(func_ctx.exception_id_phi, &exce_id, &block_curr, 1);

    if (!is_cond_br) {
        /* not condition br, create br IR */
        if (!LLVMBuildBr(comp_ctx.builder, func_ctx.got_exception_block)) {
            aot_set_last_error("llvm build br failed.");
            return false;
        }
    }
    else {
        /* Create condition br */
        if (!LLVMBuildCondBr(comp_ctx.builder, cond_br_if,
                             func_ctx.got_exception_block,
                             cond_br_else_block)) {
            aot_set_last_error("llvm build cond br failed.");
            return false;
        }
        /* Start to translate the else block */
        LLVMPositionBuilderAtEnd(comp_ctx.builder, cond_br_else_block);
    }

    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
