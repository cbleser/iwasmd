module tagion.iwasm.compilation.aot_emit_function_tmp;
@nogc nothrow:
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* This header is separate from features.h so that the compiler can
   include it implicitly at the start of every compilation.  It must
   not itself include <features.h> or any other header that includes
   <features.h> because the implicit include comes before any feature
   test macros that may be defined in a source file before it first
   explicitly includes a system header.  GCC knows the name of this
   header in order to preinclude it.  */
/* glibc's intent is to support the IEC 559 math functionality, real
   and complex.  If the GCC (4.9 and later) predefined macros
   specifying compiler intent are available, use them to determine
   whether the overall intent is to support these features; otherwise,
   presume an older compiler has intent to support these features and
   define these macros by default.  */
/* wchar_t uses Unicode 10.0.0.  Version 10.0 of the Unicode Standard is
   synchronized with ISO/IEC 10646:2017, fifth edition, plus
   the following additions from Amendment 1 to the fifth edition:
   - 56 emoji characters
   - 285 hentaigana
   - 3 additional Zanabazar Square characters */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.compilation.aot_compiler;
bool aot_compile_op_call(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint func_idx, bool tail_call);
bool aot_compile_op_call_indirect(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint type_idx, uint tbl_idx);
bool aot_compile_op_ref_null(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);
bool aot_compile_op_ref_is_null(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);
bool aot_compile_op_ref_func(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint func_idx);
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.compilation.aot_emit_control;
import tagion.iwasm.compilation.aot_emit_table;
import tagion.iwasm.aot.aot_runtime;
private bool create_func_return_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    AOTFuncType* aot_func_type = func_ctx.aot_func.func_type;
    /* Create function return block if it isn't created */
    if (!func_ctx.func_return_block) {
        if (((func_ctx.func_return_block = LLVMAppendBasicBlockInContext(
                  comp_ctx.context, func_ctx.func, "func_ret")) == 0)) {
            aot_set_last_error("llvm add basic block failed.");
            return false;
        }
        /* Create return IR */
        LLVMPositionBuilderAtEnd(comp_ctx.builder,
                                 func_ctx.func_return_block);
        if (!comp_ctx.enable_bound_check) {
            if (!aot_emit_exception(comp_ctx, func_ctx, EXCE_ALREADY_THROWN,
                                    false, null, null)) {
                return false;
            }
        }
        else if (!aot_build_zero_function_ret(comp_ctx, func_ctx,
                                              aot_func_type)) {
            return false;
        }
    }
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_curr);
    return true;
}
/* Check whether there was exception thrown, if yes, return directly */
private bool check_exception_thrown(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMBasicBlockRef block_curr = void, check_exce_succ = void;
    LLVMValueRef value = void, cmp = void;
    /* Create function return block if it isn't created */
    if (!create_func_return_block(comp_ctx, func_ctx))
        return false;
    /* Load the first byte of aot_module_inst->cur_exception, and check
       whether it is '\0'. If yes, no exception was thrown. */
    if (((value = LLVMBuildLoad2(comp_ctx.builder, INT8_TYPE,
                                 func_ctx.cur_exception, "exce_value")) == 0)
        || ((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, value, I8_ZERO,
                                 "cmp")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        return false;
    }
    /* Add check exection success block */
    if (((check_exce_succ = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "check_exce_succ")) == 0)) {
        aot_set_last_error("llvm add basic block failed.");
        return false;
    }
    block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMMoveBasicBlockAfter(check_exce_succ, block_curr);
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_curr);
    /* Create condition br */
    if (!LLVMBuildCondBr(comp_ctx.builder, cmp, check_exce_succ,
                         func_ctx.func_return_block)) {
        aot_set_last_error("llvm build cond br failed.");
        return false;
    }
    LLVMPositionBuilderAtEnd(comp_ctx.builder, check_exce_succ);
    return true;
}
/* Check whether there was exception thrown, if yes, return directly */
private bool check_call_return(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMValueRef res) {
    LLVMBasicBlockRef block_curr = void, check_call_succ = void;
    LLVMValueRef cmp = void;
    /* Create function return block if it isn't created */
    if (!create_func_return_block(comp_ctx, func_ctx))
        return false;
    if (((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntNE, res, I8_ZERO,
                              "cmp")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        return false;
    }
    /* Add check exection success block */
    if (((check_call_succ = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "check_call_succ")) == 0)) {
        aot_set_last_error("llvm add basic block failed.");
        return false;
    }
    block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMMoveBasicBlockAfter(check_call_succ, block_curr);
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_curr);
    /* Create condition br */
    if (!LLVMBuildCondBr(comp_ctx.builder, cmp, check_call_succ,
                         func_ctx.func_return_block)) {
        aot_set_last_error("llvm build cond br failed.");
        return false;
    }
    LLVMPositionBuilderAtEnd(comp_ctx.builder, check_call_succ);
    return true;
}
private bool call_aot_invoke_native_func(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMValueRef func_idx, AOTFuncType* aot_func_type, LLVMTypeRef* param_types, LLVMValueRef* param_values, uint param_count, uint param_cell_num, LLVMTypeRef ret_type, ubyte wasm_ret_type, LLVMValueRef* p_value_ret, LLVMValueRef* p_res) {
    LLVMTypeRef func_type = void, func_ptr_type = void; LLVMTypeRef[4] func_param_types = void;
    LLVMTypeRef ret_ptr_type = void, elem_ptr_type = void;
    LLVMValueRef func = void, elem_idx = void, elem_ptr = void;
    LLVMValueRef[4] func_param_values = void; LLVMValueRef value_ret = null, res = void;
    char[32] buf = void; char* func_name = "aot_invoke_native";
    uint i = void, cell_num = 0;
    /* prepare function type of aot_invoke_native */
    func_param_types[0] = comp_ctx.exec_env_type; /* exec_env */
    func_param_types[1] = I32_TYPE; /* func_idx */
    func_param_types[2] = I32_TYPE; /* argc */
    func_param_types[3] = INT32_PTR_TYPE; /* argv */
    if (((func_type =
              LLVMFunctionType(INT8_TYPE, func_param_types.ptr, 4, false)) == 0)) {
        aot_set_last_error("llvm add function type failed.");
        return false;
    }
    /* prepare function pointer */
    if (comp_ctx.is_jit_mode) {
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }
        /* JIT mode, call the function directly */
        if (((func = I64_CONST(cast(ulong)cast(uintptr_t)llvm_jit_invoke_native)) == 0)
            || ((func = LLVMConstIntToPtr(func, func_ptr_type)) == 0)) {
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
        func_index = aot_get_native_symbol_index(comp_ctx, func_name);
        if (func_index < 0) {
            return false;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_ptr_type, func_index)) == 0)) {
            return false;
        }
    }
    else {
        if (((func = LLVMGetNamedFunction(func_ctx.module_, func_name)) == 0)
            && ((func =
                     LLVMAddFunction(func_ctx.module_, func_name, func_type)) == 0)) {
            aot_set_last_error("add LLVM function failed.");
            return false;
        }
    }
    if (param_cell_num > 64) {
        aot_set_last_error("prepare native arguments failed: "
                           ~ "maximum 64 parameter cell number supported.");
        return false;
    }
    /* prepare frame_lp */
    for (i = 0; i < param_count; i++) {
        if (((elem_idx = I32_CONST(cell_num)) == 0)
            || ((elem_ptr_type = LLVMPointerType(param_types[i], 0)) == 0)) {
            aot_set_last_error("llvm add const or pointer type failed.");
            return false;
        }
        snprintf(buf.ptr, buf.sizeof, "%s%d", "elem", i);
        if (((elem_ptr =
                  LLVMBuildInBoundsGEP2(comp_ctx.builder, I32_TYPE,
                                        func_ctx.argv_buf, &elem_idx, 1, buf.ptr)) == 0)
            || ((elem_ptr = LLVMBuildBitCast(comp_ctx.builder, elem_ptr,
                                             elem_ptr_type, buf.ptr)) == 0)) {
            aot_set_last_error("llvm build bit cast failed.");
            return false;
        }
        if (((res = LLVMBuildStore(comp_ctx.builder, param_values[i],
                                   elem_ptr)) == 0)) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
        LLVMSetAlignment(res, 1);
        cell_num += wasm_value_type_cell_num(aot_func_type.types[i]);
    }
    func_param_values[0] = func_ctx.exec_env;
    func_param_values[1] = func_idx;
    func_param_values[2] = I32_CONST(param_cell_num);
    func_param_values[3] = func_ctx.argv_buf;
    if (!func_param_values[2]) {
        aot_set_last_error("llvm create const failed.");
        return false;
    }
    /* call aot_invoke_native() function */
    if (((res = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                               func_param_values.ptr, 4, "res")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }
    /* get function return value */
    if (wasm_ret_type != VALUE_TYPE_VOID) {
        if (((ret_ptr_type = LLVMPointerType(ret_type, 0)) == 0)) {
            aot_set_last_error("llvm add pointer type failed.");
            return false;
        }
        if (((value_ret =
                  LLVMBuildBitCast(comp_ctx.builder, func_ctx.argv_buf,
                                   ret_ptr_type, "argv_ret")) == 0)) {
            aot_set_last_error("llvm build bit cast failed.");
            return false;
        }
        if (((*p_value_ret = LLVMBuildLoad2(comp_ctx.builder, ret_type,
                                            value_ret, "value_ret")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            return false;
        }
    }
    *p_res = res;
    return true;
}
private bool check_stack_boundary(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint callee_cell_num) {
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMBasicBlockRef check_stack = void;
    LLVMValueRef callee_local_size = void, stack_bound = void, cmp = void;
    if (((callee_local_size = I32_CONST(callee_cell_num * 4)) == 0)) {
        aot_set_last_error("llvm build const failed.");
        return false;
    }
    if (((stack_bound = LLVMBuildInBoundsGEP2(
              comp_ctx.builder, INT8_TYPE, func_ctx.native_stack_bound,
              &callee_local_size, 1, "stack_bound")) == 0)) {
        aot_set_last_error("llvm build inbound gep failed.");
        return false;
    }
    if (((check_stack = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "check_stack")) == 0)) {
        aot_set_last_error("llvm add basic block failed.");
        return false;
    }
    LLVMMoveBasicBlockAfter(check_stack, block_curr);
    if (((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntULT,
                              func_ctx.last_alloca, stack_bound, "cmp")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        return false;
    }
    if (!aot_emit_exception(comp_ctx, func_ctx, EXCE_NATIVE_STACK_OVERFLOW,
                            true, cmp, check_stack)) {
        return false;
    }
    LLVMPositionBuilderAtEnd(comp_ctx.builder, check_stack);
    return true;
}
/**
 * Check whether the app address and its buffer are inside the linear memory,
 * if no, throw exception
 */
private bool check_app_addr_and_convert(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, bool is_str_arg, LLVMValueRef app_addr, LLVMValueRef buf_size, LLVMValueRef* p_native_addr_converted) {
    LLVMTypeRef func_type = void, func_ptr_type = void; LLVMTypeRef[5] func_param_types = void;
    LLVMValueRef func = void; LLVMValueRef[5] func_param_values = void; LLVMValueRef res = void, native_addr_ptr = void;
    char* func_name = "aot_check_app_addr_and_convert";
    /* prepare function type of aot_check_app_addr_and_convert */
    func_param_types[0] = comp_ctx.aot_inst_type; /* module_inst */
    func_param_types[1] = INT8_TYPE; /* is_str_arg */
    func_param_types[2] = I32_TYPE; /* app_offset */
    func_param_types[3] = I32_TYPE; /* buf_size */
    func_param_types[4] =
        comp_ctx.basic_types.int8_pptr_type; /* p_native_addr */
    if (((func_type =
              LLVMFunctionType(INT8_TYPE, func_param_types.ptr, 5, false)) == 0)) {
        aot_set_last_error("llvm add function type failed.");
        return false;
    }
    /* prepare function pointer */
    if (comp_ctx.is_jit_mode) {
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }
        /* JIT mode, call the function directly */
        if (((func =
                  I64_CONST(cast(ulong)cast(uintptr_t)jit_check_app_addr_and_convert)) == 0)
            || ((func = LLVMConstIntToPtr(func, func_ptr_type)) == 0)) {
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
        func_index = aot_get_native_symbol_index(comp_ctx, func_name);
        if (func_index < 0) {
            return false;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_ptr_type, func_index)) == 0)) {
            return false;
        }
    }
    else {
        if (((func = LLVMGetNamedFunction(func_ctx.module_, func_name)) == 0)
            && ((func =
                     LLVMAddFunction(func_ctx.module_, func_name, func_type)) == 0)) {
            aot_set_last_error("add LLVM function failed.");
            return false;
        }
    }
    if (((native_addr_ptr = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.argv_buf,
              comp_ctx.basic_types.int8_pptr_type, "p_native_addr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed.");
        return false;
    }
    func_param_values[0] = func_ctx.aot_inst;
    func_param_values[1] = I8_CONST(is_str_arg);
    func_param_values[2] = app_addr;
    func_param_values[3] = buf_size;
    func_param_values[4] = native_addr_ptr;
    if (!func_param_values[1]) {
        aot_set_last_error("llvm create const failed.");
        return false;
    }
    /* call aot_check_app_addr_and_convert() function */
    if (((res = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                               func_param_values.ptr, 5, "res")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }
    /* Check whether exception was thrown when executing the function */
    if (comp_ctx.enable_bound_check
        && !check_call_return(comp_ctx, func_ctx, res)) {
        return false;
    }
    if (((*p_native_addr_converted =
              LLVMBuildLoad2(comp_ctx.builder, OPQ_PTR_TYPE, native_addr_ptr,
                             "native_addr")) == 0)) {
        aot_set_last_error("llvm build load failed.");
        return false;
    }
    return true;
}
bool aot_compile_op_call(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint func_idx, bool tail_call) {
    uint import_func_count = comp_ctx.comp_data.import_func_count;
    AOTImportFunc* import_funcs = comp_ctx.comp_data.import_funcs;
    uint func_count = comp_ctx.func_ctx_count, param_cell_num = 0;
    uint ext_ret_cell_num = 0, cell_num = 0;
    AOTFuncContext** func_ctxes = comp_ctx.func_ctxes;
    AOTFuncType* func_type = void;
    AOTFunc* aot_func = void;
    LLVMTypeRef* param_types = null; LLVMTypeRef ret_type = void;
    LLVMTypeRef ext_ret_ptr_type = void;
    LLVMValueRef* param_values = null; LLVMValueRef value_ret = null, func = void;
    LLVMValueRef import_func_idx = void, res = void;
    LLVMValueRef ext_ret = void, ext_ret_ptr = void, ext_ret_idx = void;
    int i = void, j = 0, param_count = void, result_count = void, ext_ret_count = void;
    ulong total_size = void;
    uint callee_cell_num = void;
    ubyte wasm_ret_type = void;
    ubyte* ext_ret_types = null;
    const(char)* signature = null;
    bool ret = false;
    char[32] buf = void;
    /* Check function index */
    if (func_idx >= import_func_count + func_count) {
        aot_set_last_error("Function index out of range.");
        return false;
    }
    /* Get function type */
    if (func_idx < import_func_count) {
        func_type = import_funcs[func_idx].func_type;
        signature = import_funcs[func_idx].signature;
    }
    else {
        func_type =
            func_ctxes[func_idx - import_func_count].aot_func.func_type;
    }
    /* Get param cell number */
    param_cell_num = func_type.param_cell_num;
    /* Allocate memory for parameters.
     * Parameters layout:
     *   - exec env
     *   - wasm function's parameters
     *   - extra results'(except the first one) addresses
     */
    param_count = cast(int)func_type.param_count;
    result_count = cast(int)func_type.result_count;
    ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    total_size =
        LLVMValueRef.sizeof * cast(ulong)(param_count + 1 + ext_ret_count);
    if (total_size >= UINT32_MAX
        || ((param_values = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return false;
    }
    /* First parameter is exec env */
    param_values[j++] = func_ctx.exec_env;
    /* Pop parameters from stack */
    for (i = param_count - 1; i >= 0; i--)
        POP(param_values[i + j], func_type.types[i]);
    /* Set parameters for multiple return values, the first return value
       is returned by function return value, and the other return values
       are returned by function parameters with pointer types */
    if (ext_ret_count > 0) {
        ext_ret_types = func_type.types + param_count + 1;
        ext_ret_cell_num = wasm_get_cell_num(ext_ret_types, ext_ret_count);
        if (ext_ret_cell_num > 64) {
            aot_set_last_error("prepare extra results's return "
                               ~ "address arguments failed: "
                               ~ "maximum 64 parameter cell number supported.");
            goto fail;
        }
        for (i = 0; i < ext_ret_count; i++) {
            if (((ext_ret_idx = I32_CONST(cell_num)) == 0)
                || ((ext_ret_ptr_type =
                         LLVMPointerType(TO_LLVM_TYPE(ext_ret_types[i]), 0)) == 0)) {
                aot_set_last_error("llvm add const or pointer type failed.");
                goto fail;
            }
            snprintf(buf.ptr, buf.sizeof, "ext_ret%d_ptr", i);
            if (((ext_ret_ptr = LLVMBuildInBoundsGEP2(
                      comp_ctx.builder, I32_TYPE, func_ctx.argv_buf,
                      &ext_ret_idx, 1, buf.ptr)) == 0)) {
                aot_set_last_error("llvm build GEP failed.");
                goto fail;
            }
            snprintf(buf.ptr, buf.sizeof, "ext_ret%d_ptr_cast", i);
            if (((ext_ret_ptr = LLVMBuildBitCast(comp_ctx.builder, ext_ret_ptr,
                                                 ext_ret_ptr_type, buf.ptr)) == 0)) {
                aot_set_last_error("llvm build bit cast failed.");
                goto fail;
            }
            param_values[param_count + 1 + i] = ext_ret_ptr;
            cell_num += wasm_value_type_cell_num(ext_ret_types[i]);
        }
    }
    if (func_idx < import_func_count) {
        if (((import_func_idx = I32_CONST(func_idx)) == 0)) {
            aot_set_last_error("llvm build inbounds gep failed.");
            goto fail;
        }
        /* Initialize parameter types of the LLVM function */
        total_size = LLVMTypeRef.sizeof * cast(ulong)(param_count + 1);
        if (total_size >= UINT32_MAX
            || ((param_types = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }
        j = 0;
        param_types[j++] = comp_ctx.exec_env_type;
        for (i = 0; i < param_count; i++, j++) {
            param_types[j] = TO_LLVM_TYPE(func_type.types[i]);
            /* If the signature can be gotten, e.g. the signature of the builtin
               native libraries, just check the app offset and buf size, and
               then convert app offset to native addr and call the native func
               directly, no need to call aot_invoke_native to call it */
            if (signature) {
                LLVMValueRef native_addr = void, native_addr_size = void;
                if (signature[i + 1] == '*' || signature[i + 1] == '$') {
                    param_types[j] = INT8_PTR_TYPE;
                }
                if (signature[i + 1] == '*') {
                    if (signature[i + 2] == '~')
                        native_addr_size = param_values[i + 2];
                    else
                        native_addr_size = I32_ONE;
                    if (!check_app_addr_and_convert(
                            comp_ctx, func_ctx, false, param_values[j],
                            native_addr_size, &native_addr)) {
                        goto fail;
                    }
                    param_values[j] = native_addr;
                }
                else if (signature[i + 1] == '$') {
                    native_addr_size = I32_ZERO;
                    if (!check_app_addr_and_convert(
                            comp_ctx, func_ctx, true, param_values[j],
                            native_addr_size, &native_addr)) {
                        goto fail;
                    }
                    param_values[j] = native_addr;
                }
            }
        }
        if (func_type.result_count) {
            wasm_ret_type = func_type.types[func_type.param_count];
            ret_type = TO_LLVM_TYPE(wasm_ret_type);
        }
        else {
            wasm_ret_type = VALUE_TYPE_VOID;
            ret_type = VOID_TYPE;
        }
        if (!signature) {
            /* call aot_invoke_native() */
            if (!call_aot_invoke_native_func(
                    comp_ctx, func_ctx, import_func_idx, func_type,
                    param_types + 1, param_values + 1, param_count,
                    param_cell_num, ret_type, wasm_ret_type, &value_ret, &res))
                goto fail;
            /* Check whether there was exception thrown when executing
               the function */
            if (comp_ctx.enable_bound_check
                && !check_call_return(comp_ctx, func_ctx, res))
                goto fail;
        }
        else { /* call native func directly */
            LLVMTypeRef native_func_type = void, func_ptr_type = void;
            LLVMValueRef func_ptr = void;
            if (((native_func_type = LLVMFunctionType(
                      ret_type, param_types, param_count + 1, false)) == 0)) {
                aot_set_last_error("llvm add function type failed.");
                goto fail;
            }
            if (((func_ptr_type = LLVMPointerType(native_func_type, 0)) == 0)) {
                aot_set_last_error("create LLVM function type failed.");
                goto fail;
            }
            /* Load function pointer */
            if (((func_ptr = LLVMBuildInBoundsGEP2(
                      comp_ctx.builder, OPQ_PTR_TYPE, func_ctx.func_ptrs,
                      &import_func_idx, 1, "native_func_ptr_tmp")) == 0)) {
                aot_set_last_error("llvm build inbounds gep failed.");
                goto fail;
            }
            if (((func_ptr = LLVMBuildLoad2(comp_ctx.builder, OPQ_PTR_TYPE,
                                            func_ptr, "native_func_ptr")) == 0)) {
                aot_set_last_error("llvm build load failed.");
                goto fail;
            }
            if (((func = LLVMBuildBitCast(comp_ctx.builder, func_ptr,
                                          func_ptr_type, "native_func")) == 0)) {
                aot_set_last_error("llvm bit cast failed.");
                goto fail;
            }
            /* Call the function */
            if (((value_ret = LLVMBuildCall2(
                      comp_ctx.builder, native_func_type, func, param_values,
                      cast(uint)param_count + 1 + ext_ret_count,
                      (func_type.result_count > 0 ? "call" : ""))) == 0)) {
                aot_set_last_error("LLVM build call failed.");
                goto fail;
            }
            /* Check whether there was exception thrown when executing
               the function */
            if (!check_exception_thrown(comp_ctx, func_ctx)) {
                goto fail;
            }
        }
    }
    else {
        bool recursive_call = (func_ctx == func_ctxes[func_idx - import_func_count]) ? true
                                                                   : false;
        if (comp_ctx.is_indirect_mode) {
            LLVMTypeRef func_ptr_type = void;
            if (((func_ptr_type = LLVMPointerType(
                      func_ctxes[func_idx - import_func_count].func_type,
                      0)) == 0)) {
                aot_set_last_error("construct func ptr type failed.");
                goto fail;
            }
            if (((func = aot_get_func_from_table(comp_ctx, func_ctx.func_ptrs,
                                                 func_ptr_type, func_idx)) == 0)) {
                goto fail;
            }
        }
        else {
            if (func_ctxes[func_idx - import_func_count] == func_ctx) {
                /* recursive call */
                func = func_ctx.func;
            }
            else {
                if (!comp_ctx.is_jit_mode) {
                    func = func_ctxes[func_idx - import_func_count].func;
                }
                else {
                    func = func_ctxes[func_idx - import_func_count].func;
                }
            }
        }
        aot_func = func_ctxes[func_idx - import_func_count].aot_func;
        callee_cell_num =
            aot_func.param_cell_num + aot_func.local_cell_num + 1;
        if (comp_ctx.enable_stack_bound_check
            && !check_stack_boundary(comp_ctx, func_ctx, callee_cell_num))
            goto fail;
        /* Call the function */
        if (((value_ret = LLVMBuildCall2(
                  comp_ctx.builder, llvm_func_type, func, param_values,
                  cast(uint)param_count + 1 + ext_ret_count,
                  (func_type.result_count > 0 ? "call" : ""))) == 0)) {
            aot_set_last_error("LLVM build call failed.");
            goto fail;
        }
        /* Set calling convention for the call with the func's calling
           convention */
        LLVMSetInstructionCallConv(value_ret, LLVMGetFunctionCallConv(func));
        if (tail_call)
            LLVMSetTailCall(value_ret, true);
        /* Check whether there was exception thrown when executing
           the function */
        if (!tail_call && !recursive_call && comp_ctx.enable_bound_check
            && !check_exception_thrown(comp_ctx, func_ctx))
            goto fail;
    }
    if (func_type.result_count > 0) {
        /* Push the first result to stack */
        PUSH(value_ret, func_type.types[func_type.param_count]);
        /* Load extra result from its address and push to stack */
        for (i = 0; i < ext_ret_count; i++) {
            snprintf(buf.ptr, buf.sizeof, "func%d_ext_ret%d", func_idx, i);
            if (((ext_ret = LLVMBuildLoad2(
                      comp_ctx.builder, TO_LLVM_TYPE(ext_ret_types[i]),
                      param_values[1 + param_count + i], buf.ptr)) == 0)) {
                aot_set_last_error("llvm build load failed.");
                goto fail;
            }
            PUSH(ext_ret, ext_ret_types[i]);
        }
    }
    ret = true;
fail:
    if (param_types)
        wasm_runtime_free(param_types);
    if (param_values)
        wasm_runtime_free(param_values);
    return ret;
}
private bool call_aot_call_indirect_func(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, AOTFuncType* aot_func_type, LLVMValueRef func_type_idx, LLVMValueRef table_idx, LLVMValueRef table_elem_idx, LLVMTypeRef* param_types, LLVMValueRef* param_values, uint param_count, uint param_cell_num, uint result_count, ubyte* wasm_ret_types, LLVMValueRef* value_rets, LLVMValueRef* p_res) {
    LLVMTypeRef func_type = void, func_ptr_type = void; LLVMTypeRef[6] func_param_types = void;
    LLVMTypeRef ret_type = void, ret_ptr_type = void, elem_ptr_type = void;
    LLVMValueRef func = void, ret_idx = void, ret_ptr = void, elem_idx = void, elem_ptr = void;
    LLVMValueRef[6] func_param_values = void; LLVMValueRef res = null;
    char[32] buf = void; char* func_name = "aot_call_indirect";
    uint i = void, cell_num = 0, ret_cell_num = void, argv_cell_num = void;
    /* prepare function type of aot_call_indirect */
    func_param_types[0] = comp_ctx.exec_env_type; /* exec_env */
    func_param_types[1] = I32_TYPE; /* table_idx */
    func_param_types[2] = I32_TYPE; /* table_elem_idx */
    func_param_types[3] = I32_TYPE; /* argc */
    func_param_types[4] = INT32_PTR_TYPE; /* argv */
    if (((func_type =
              LLVMFunctionType(INT8_TYPE, func_param_types.ptr, 5, false)) == 0)) {
        aot_set_last_error("llvm add function type failed.");
        return false;
    }
    /* prepare function pointer */
    if (comp_ctx.is_jit_mode) {
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }
        /* JIT mode, call the function directly */
        if (((func = I64_CONST(cast(ulong)cast(uintptr_t)llvm_jit_call_indirect)) == 0)
            || ((func = LLVMConstIntToPtr(func, func_ptr_type)) == 0)) {
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
        func_index = aot_get_native_symbol_index(comp_ctx, func_name);
        if (func_index < 0) {
            return false;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_ptr_type, func_index)) == 0)) {
            return false;
        }
    }
    else {
        if (((func = LLVMGetNamedFunction(func_ctx.module_, func_name)) == 0)
            && ((func =
                     LLVMAddFunction(func_ctx.module_, func_name, func_type)) == 0)) {
            aot_set_last_error("add LLVM function failed.");
            return false;
        }
    }
    ret_cell_num = wasm_get_cell_num(wasm_ret_types, result_count);
    argv_cell_num =
        param_cell_num > ret_cell_num ? param_cell_num : ret_cell_num;
    if (argv_cell_num > 64) {
        aot_set_last_error("prepare native arguments failed: "
                           ~ "maximum 64 parameter cell number supported.");
        return false;
    }
    /* prepare frame_lp */
    for (i = 0; i < param_count; i++) {
        if (((elem_idx = I32_CONST(cell_num)) == 0)
            || ((elem_ptr_type = LLVMPointerType(param_types[i], 0)) == 0)) {
            aot_set_last_error("llvm add const or pointer type failed.");
            return false;
        }
        snprintf(buf.ptr, buf.sizeof, "%s%d", "elem", i);
        if (((elem_ptr =
                  LLVMBuildInBoundsGEP2(comp_ctx.builder, I32_TYPE,
                                        func_ctx.argv_buf, &elem_idx, 1, buf.ptr)) == 0)
            || ((elem_ptr = LLVMBuildBitCast(comp_ctx.builder, elem_ptr,
                                             elem_ptr_type, buf.ptr)) == 0)) {
            aot_set_last_error("llvm build bit cast failed.");
            return false;
        }
        if (((res = LLVMBuildStore(comp_ctx.builder, param_values[i],
                                   elem_ptr)) == 0)) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
        LLVMSetAlignment(res, 1);
        cell_num += wasm_value_type_cell_num(aot_func_type.types[i]);
    }
    func_param_values[0] = func_ctx.exec_env;
    func_param_values[1] = table_idx;
    func_param_values[2] = table_elem_idx;
    func_param_values[3] = I32_CONST(param_cell_num);
    func_param_values[4] = func_ctx.argv_buf;
    if (!func_param_values[3]) {
        aot_set_last_error("llvm create const failed.");
        return false;
    }
    /* call aot_call_indirect() function */
    if (((res = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                               func_param_values.ptr, 5, "res")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }
    /* get function result values */
    cell_num = 0;
    for (i = 0; i < result_count; i++) {
        ret_type = TO_LLVM_TYPE(wasm_ret_types[i]);
        if (((ret_idx = I32_CONST(cell_num)) == 0)
            || ((ret_ptr_type = LLVMPointerType(ret_type, 0)) == 0)) {
            aot_set_last_error("llvm add const or pointer type failed.");
            return false;
        }
        snprintf(buf.ptr, buf.sizeof, "argv_ret%d", i);
        if (((ret_ptr =
                  LLVMBuildInBoundsGEP2(comp_ctx.builder, I32_TYPE,
                                        func_ctx.argv_buf, &ret_idx, 1, buf.ptr)) == 0)
            || ((ret_ptr = LLVMBuildBitCast(comp_ctx.builder, ret_ptr,
                                            ret_ptr_type, buf.ptr)) == 0)) {
            aot_set_last_error("llvm build GEP or bit cast failed.");
            return false;
        }
        snprintf(buf.ptr, buf.sizeof, "ret%d", i);
        if (((value_rets[i] =
                  LLVMBuildLoad2(comp_ctx.builder, ret_type, ret_ptr, buf.ptr)) == 0)) {
            aot_set_last_error("llvm build load failed.");
            return false;
        }
        cell_num += wasm_value_type_cell_num(wasm_ret_types[i]);
    }
    *p_res = res;
    return true;
}
bool aot_compile_op_call_indirect(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint type_idx, uint tbl_idx) {
    AOTFuncType* func_type = void;
    LLVMValueRef tbl_idx_value = void, elem_idx = void, table_elem = void, func_idx = void;
    LLVMValueRef ftype_idx_ptr = void, ftype_idx = void, ftype_idx_const = void;
    LLVMValueRef cmp_elem_idx = void, cmp_func_idx = void, cmp_ftype_idx = void;
    LLVMValueRef func = void, func_ptr = void, table_size_const = void;
    LLVMValueRef ext_ret_offset = void, ext_ret_ptr = void, ext_ret = void, res = void;
    LLVMValueRef* param_values = null, value_rets = null;
    LLVMValueRef* result_phis = null; LLVMValueRef value_ret = void, import_func_count = void;
    LLVMTypeRef* param_types = null; LLVMTypeRef ret_type = void;
    LLVMTypeRef llvm_func_type = void, llvm_func_ptr_type = void;
    LLVMTypeRef ext_ret_ptr_type = void;
    LLVMBasicBlockRef check_elem_idx_succ = void, check_ftype_idx_succ = void;
    LLVMBasicBlockRef check_func_idx_succ = void, block_return = void, block_curr = void;
    LLVMBasicBlockRef block_call_import = void, block_call_non_import = void;
    LLVMValueRef offset = void;
    uint total_param_count = void, func_param_count = void, func_result_count = void;
    uint ext_cell_num = void, param_cell_num = void, i = void, j = void;
    ubyte wasm_ret_type = void; ubyte* wasm_ret_types = void;
    ulong total_size = void;
    char[32] buf = void;
    bool ret = false;
    /* Check function type index */
    if (type_idx >= comp_ctx.comp_data.func_type_count) {
        aot_set_last_error("function type index out of range");
        return false;
    }
    /* Find the equivalent function type whose type index is the smallest:
       the callee function's type index is also converted to the smallest
       one in wasm loader, so we can just check whether the two type indexes
       are equal (the type index of call_indirect opcode and callee func),
       we don't need to check whether the whole function types are equal,
       including param types and result types. */
    type_idx = wasm_get_smallest_type_idx(comp_ctx.comp_data.func_types,
                                          comp_ctx.comp_data.func_type_count,
                                          type_idx);
    ftype_idx_const = I32_CONST(type_idx);
    CHECK_LLVM_CONST(ftype_idx_const);
    func_type = comp_ctx.comp_data.func_types[type_idx];
    func_param_count = func_type.param_count;
    func_result_count = func_type.result_count;
    POP_I32(elem_idx);
    /* get the cur size of the table instance */
    if (((offset = I32_CONST(get_tbl_inst_offset(comp_ctx, func_ctx, tbl_idx)
                             + AOTTableInstance.cur_size.offsetof)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }
    if (((table_size_const = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                                   func_ctx.aot_inst, &offset,
                                                   1, "cur_size_i8p")) == 0)) {
        HANDLE_FAILURE("LLVMBuildGEP");
        goto fail;
    }
    if (((table_size_const =
              LLVMBuildBitCast(comp_ctx.builder, table_size_const,
                               INT32_PTR_TYPE, "cur_siuze_i32p")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }
    if (((table_size_const = LLVMBuildLoad2(comp_ctx.builder, I32_TYPE,
                                            table_size_const, "cur_size")) == 0)) {
        HANDLE_FAILURE("LLVMBuildLoad");
        goto fail;
    }
    /* Check if (uint32)elem index >= table size */
    if (((cmp_elem_idx = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGE, elem_idx,
                                       table_size_const, "cmp_elem_idx")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        goto fail;
    }
    /* Throw exception if elem index >= table size */
    if (((check_elem_idx_succ = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "check_elem_idx_succ")) == 0)) {
        aot_set_last_error("llvm add basic block failed.");
        goto fail;
    }
    LLVMMoveBasicBlockAfter(check_elem_idx_succ,
                            LLVMGetInsertBlock(comp_ctx.builder));
    if (!(aot_emit_exception(comp_ctx, func_ctx, EXCE_UNDEFINED_ELEMENT, true,
                             cmp_elem_idx, check_elem_idx_succ)))
        goto fail;
    /* load data as i32* */
    if (((offset = I32_CONST(get_tbl_inst_offset(comp_ctx, func_ctx, tbl_idx)
                             + AOTTableInstance.elems.offsetof)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }
    if (((table_elem = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                             func_ctx.aot_inst, &offset, 1,
                                             "table_elem_i8p")) == 0)) {
        aot_set_last_error("llvm build add failed.");
        goto fail;
    }
    if (((table_elem = LLVMBuildBitCast(comp_ctx.builder, table_elem,
                                        INT32_PTR_TYPE, "table_elem_i32p")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }
    /* Load function index */
    if (((table_elem =
              LLVMBuildInBoundsGEP2(comp_ctx.builder, I32_TYPE, table_elem,
                                    &elem_idx, 1, "table_elem")) == 0)) {
        HANDLE_FAILURE("LLVMBuildNUWAdd");
        goto fail;
    }
    if (((func_idx = LLVMBuildLoad2(comp_ctx.builder, I32_TYPE, table_elem,
                                    "func_idx")) == 0)) {
        aot_set_last_error("llvm build load failed.");
        goto fail;
    }
    /* Check if func_idx == -1 */
    if (((cmp_func_idx = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, func_idx,
                                       I32_NEG_ONE, "cmp_func_idx")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        goto fail;
    }
    /* Throw exception if func_idx == -1 */
    if (((check_func_idx_succ = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "check_func_idx_succ")) == 0)) {
        aot_set_last_error("llvm add basic block failed.");
        goto fail;
    }
    LLVMMoveBasicBlockAfter(check_func_idx_succ,
                            LLVMGetInsertBlock(comp_ctx.builder));
    if (!(aot_emit_exception(comp_ctx, func_ctx, EXCE_UNINITIALIZED_ELEMENT,
                             true, cmp_func_idx, check_func_idx_succ)))
        goto fail;
    /* Load function type index */
    if (((ftype_idx_ptr = LLVMBuildInBoundsGEP2(
              comp_ctx.builder, I32_TYPE, func_ctx.func_type_indexes,
              &func_idx, 1, "ftype_idx_ptr")) == 0)) {
        aot_set_last_error("llvm build inbounds gep failed.");
        goto fail;
    }
    if (((ftype_idx = LLVMBuildLoad2(comp_ctx.builder, I32_TYPE, ftype_idx_ptr,
                                     "ftype_idx")) == 0)) {
        aot_set_last_error("llvm build load failed.");
        goto fail;
    }
    /* Check if function type index not equal */
    if (((cmp_ftype_idx = LLVMBuildICmp(comp_ctx.builder, LLVMIntNE, ftype_idx,
                                        ftype_idx_const, "cmp_ftype_idx")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        goto fail;
    }
    /* Throw exception if ftype_idx != ftype_idx_const */
    if (((check_ftype_idx_succ = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "check_ftype_idx_succ")) == 0)) {
        aot_set_last_error("llvm add basic block failed.");
        goto fail;
    }
    LLVMMoveBasicBlockAfter(check_ftype_idx_succ,
                            LLVMGetInsertBlock(comp_ctx.builder));
    if (!(aot_emit_exception(comp_ctx, func_ctx,
                             EXCE_INVALID_FUNCTION_TYPE_INDEX, true,
                             cmp_ftype_idx, check_ftype_idx_succ)))
        goto fail;
    /* Initialize parameter types of the LLVM function */
    total_param_count = 1 + func_param_count;
    /* Extra function results' addresses (except the first one) are
       appended to aot function parameters. */
    if (func_result_count > 1)
        total_param_count += func_result_count - 1;
    total_size = LLVMTypeRef.sizeof * cast(ulong)total_param_count;
    if (total_size >= UINT32_MAX
        || ((param_types = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        goto fail;
    }
    /* Prepare param types */
    j = 0;
    param_types[j++] = comp_ctx.exec_env_type;
    for (i = 0; i < func_param_count; i++)
        param_types[j++] = TO_LLVM_TYPE(func_type.types[i]);
    for (i = 1; i < func_result_count; i++, j++) {
        param_types[j] = TO_LLVM_TYPE(func_type.types[func_param_count + i]);
        if (((param_types[j] = LLVMPointerType(param_types[j], 0)) == 0)) {
            aot_set_last_error("llvm get pointer type failed.");
            goto fail;
        }
    }
    /* Resolve return type of the LLVM function */
    if (func_result_count) {
        wasm_ret_type = func_type.types[func_param_count];
        ret_type = TO_LLVM_TYPE(wasm_ret_type);
    }
    else {
        wasm_ret_type = VALUE_TYPE_VOID;
        ret_type = VOID_TYPE;
    }
    /* Allocate memory for parameters */
    total_size = LLVMValueRef.sizeof * cast(ulong)total_param_count;
    if (total_size >= UINT32_MAX
        || ((param_values = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        goto fail;
    }
    /* First parameter is exec env */
    j = 0;
    param_values[j++] = func_ctx.exec_env;
    /* Pop parameters from stack */
    for (i = func_param_count - 1; cast(int)i >= 0; i--)
        POP(param_values[i + j], func_type.types[i]);
    /* Prepare extra parameters */
    ext_cell_num = 0;
    for (i = 1; i < func_result_count; i++) {
        ext_ret_offset = I32_CONST(ext_cell_num);
        CHECK_LLVM_CONST(ext_ret_offset);
        snprintf(buf.ptr, buf.sizeof, "ext_ret%d_ptr", i - 1);
        if (((ext_ret_ptr = LLVMBuildInBoundsGEP2(comp_ctx.builder, I32_TYPE,
                                                  func_ctx.argv_buf,
                                                  &ext_ret_offset, 1, buf.ptr)) == 0)) {
            aot_set_last_error("llvm build GEP failed.");
            goto fail;
        }
        ext_ret_ptr_type = param_types[func_param_count + i];
        snprintf(buf.ptr, buf.sizeof, "ext_ret%d_ptr_cast", i - 1);
        if (((ext_ret_ptr = LLVMBuildBitCast(comp_ctx.builder, ext_ret_ptr,
                                             ext_ret_ptr_type, buf.ptr)) == 0)) {
            aot_set_last_error("llvm build bit cast failed.");
            goto fail;
        }
        param_values[func_param_count + i] = ext_ret_ptr;
        ext_cell_num +=
            wasm_value_type_cell_num(func_type.types[func_param_count + i]);
    }
    if (ext_cell_num > 64) {
        aot_set_last_error("prepare call-indirect arguments failed: "
                           ~ "maximum 64 extra cell number supported.");
        goto fail;
    }
    /* Add basic blocks */
    block_call_import = LLVMAppendBasicBlockInContext(
        comp_ctx.context, func_ctx.func, "call_import");
    block_call_non_import = LLVMAppendBasicBlockInContext(
        comp_ctx.context, func_ctx.func, "call_non_import");
    block_return = LLVMAppendBasicBlockInContext(comp_ctx.context,
                                                 func_ctx.func, "func_return");
    if (!block_call_import || !block_call_non_import || !block_return) {
        aot_set_last_error("llvm add basic block failed.");
        goto fail;
    }
    LLVMMoveBasicBlockAfter(block_call_import,
                            LLVMGetInsertBlock(comp_ctx.builder));
    LLVMMoveBasicBlockAfter(block_call_non_import, block_call_import);
    LLVMMoveBasicBlockAfter(block_return, block_call_non_import);
    import_func_count = I32_CONST(comp_ctx.comp_data.import_func_count);
    CHECK_LLVM_CONST(import_func_count);
    /* Check if func_idx < import_func_count */
    if (((cmp_func_idx = LLVMBuildICmp(comp_ctx.builder, LLVMIntULT, func_idx,
                                       import_func_count, "cmp_func_idx")) == 0)) {
        aot_set_last_error("llvm build icmp failed.");
        goto fail;
    }
    /* If func_idx < import_func_count, jump to call import block,
       else jump to call non-import block */
    if (!LLVMBuildCondBr(comp_ctx.builder, cmp_func_idx, block_call_import,
                         block_call_non_import)) {
        aot_set_last_error("llvm build cond br failed.");
        goto fail;
    }
    /* Add result phis for return block */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_return);
    if (func_result_count > 0) {
        total_size = LLVMValueRef.sizeof * cast(ulong)func_result_count;
        if (total_size >= UINT32_MAX
            || ((result_phis = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }
        memset(result_phis, 0, cast(uint)total_size);
        for (i = 0; i < func_result_count; i++) {
            LLVMTypeRef tmp_type = TO_LLVM_TYPE(func_type.types[func_param_count + i]);
            if (((result_phis[i] =
                      LLVMBuildPhi(comp_ctx.builder, tmp_type, "phi")) == 0)) {
                aot_set_last_error("llvm build phi failed.");
                goto fail;
            }
        }
    }
    /* Translate call import block */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_call_import);
    /* Allocate memory for result values */
    if (func_result_count > 0) {
        total_size = LLVMValueRef.sizeof * cast(ulong)func_result_count;
        if (total_size >= UINT32_MAX
            || ((value_rets = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }
        memset(value_rets, 0, cast(uint)total_size);
    }
    param_cell_num = func_type.param_cell_num;
    wasm_ret_types = func_type.types + func_type.param_count;
    tbl_idx_value = I32_CONST(tbl_idx);
    if (!tbl_idx_value) {
        aot_set_last_error("llvm create const failed.");
        goto fail;
    }
    if (!call_aot_call_indirect_func(
            comp_ctx, func_ctx, func_type, ftype_idx, tbl_idx_value, elem_idx,
            param_types + 1, param_values + 1, func_param_count, param_cell_num,
            func_result_count, wasm_ret_types, value_rets, &res))
        goto fail;
    /* Check whether exception was thrown when executing the function */
    if (comp_ctx.enable_bound_check
        && !check_call_return(comp_ctx, func_ctx, res))
        goto fail;
    block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    for (i = 0; i < func_result_count; i++) {
        LLVMAddIncoming(result_phis[i], &value_rets[i], &block_curr, 1);
    }
    if (!LLVMBuildBr(comp_ctx.builder, block_return)) {
        aot_set_last_error("llvm build br failed.");
        goto fail;
    }
    /* Translate call non-import block */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_call_non_import);
    if (comp_ctx.enable_stack_bound_check
        && !check_stack_boundary(comp_ctx, func_ctx,
                                 param_cell_num + ext_cell_num
                                     + 1
                                     /* Reserve some local variables */
                                     + 16))
        goto fail;
    /* Load function pointer */
    if (((func_ptr = LLVMBuildInBoundsGEP2(comp_ctx.builder, OPQ_PTR_TYPE,
                                           func_ctx.func_ptrs, &func_idx, 1,
                                           "func_ptr_tmp")) == 0)) {
        aot_set_last_error("llvm build inbounds gep failed.");
        goto fail;
    }
    if (((func_ptr = LLVMBuildLoad2(comp_ctx.builder, OPQ_PTR_TYPE, func_ptr,
                                    "func_ptr")) == 0)) {
        aot_set_last_error("llvm build load failed.");
        goto fail;
    }
    if (((llvm_func_type =
              LLVMFunctionType(ret_type, param_types, total_param_count, false)) == 0)
        || ((llvm_func_ptr_type = LLVMPointerType(llvm_func_type, 0)) == 0)) {
        aot_set_last_error("llvm add function type failed.");
        goto fail;
    }
    if (((func = LLVMBuildBitCast(comp_ctx.builder, func_ptr,
                                  llvm_func_ptr_type, "indirect_func")) == 0)) {
        aot_set_last_error("llvm build bit cast failed.");
        goto fail;
    }
    if (((value_ret = LLVMBuildCall2(comp_ctx.builder, llvm_func_type, func,
                                     param_values, total_param_count,
                                     func_result_count > 0 ? "ret" : "")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        goto fail;
    }
    /* Check whether exception was thrown when executing the function */
    if (comp_ctx.enable_bound_check
        && !check_exception_thrown(comp_ctx, func_ctx))
        goto fail;
    if (func_result_count > 0) {
        block_curr = LLVMGetInsertBlock(comp_ctx.builder);
        /* Push the first result to stack */
        LLVMAddIncoming(result_phis[0], &value_ret, &block_curr, 1);
        /* Load extra result from its address and push to stack */
        for (i = 1; i < func_result_count; i++) {
            ret_type = TO_LLVM_TYPE(func_type.types[func_param_count + i]);
            snprintf(buf.ptr, buf.sizeof, "ext_ret%d", i - 1);
            if (((ext_ret = LLVMBuildLoad2(comp_ctx.builder, ret_type,
                                           param_values[func_param_count + i],
                                           buf.ptr)) == 0)) {
                aot_set_last_error("llvm build load failed.");
                goto fail;
            }
            LLVMAddIncoming(result_phis[i], &ext_ret, &block_curr, 1);
        }
    }
    if (!LLVMBuildBr(comp_ctx.builder, block_return)) {
        aot_set_last_error("llvm build br failed.");
        goto fail;
    }
    /* Translate function return block */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block_return);
    for (i = 0; i < func_result_count; i++) {
        PUSH(result_phis[i], func_type.types[func_param_count + i]);
    }
    ret = true;
fail:
    if (param_values)
        wasm_runtime_free(param_values);
    if (param_types)
        wasm_runtime_free(param_types);
    if (value_rets)
        wasm_runtime_free(value_rets);
    if (result_phis)
        wasm_runtime_free(result_phis);
    return ret;
}
bool aot_compile_op_ref_null(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    PUSH_I32(REF_NULL);
    return true;
fail:
    return false;
}
bool aot_compile_op_ref_is_null(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef lhs = void, res = void;
    POP_I32(lhs);
    if (((res = LLVMBuildICmp(comp_ctx.builder, LLVMIntEQ, lhs, REF_NULL,
                              "cmp_w_null")) == 0)) {
        HANDLE_FAILURE("LLVMBuildICmp");
        goto fail;
    }
    if (((res = LLVMBuildZExt(comp_ctx.builder, res, I32_TYPE, "r_i")) == 0)) {
        HANDLE_FAILURE("LLVMBuildZExt");
        goto fail;
    }
    PUSH_I32(res);
    return true;
fail:
    return false;
}
bool aot_compile_op_ref_func(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint func_idx) {
    LLVMValueRef ref_idx = void;
    if (((ref_idx = I32_CONST(func_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }
    PUSH_I32(ref_idx);
    return true;
fail:
    return false;
}
