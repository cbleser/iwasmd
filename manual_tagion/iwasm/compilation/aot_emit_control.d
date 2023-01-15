module aot_emit_control_tmp;
@nogc nothrow:
extern(C): __gshared:
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
//#include "aot_compiler.h"
bool aot_compile_op_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip, ubyte* frame_ip_end, uint label_type, uint param_count, ubyte* param_types, uint result_count, ubyte* result_types);
bool aot_compile_op_else(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip);
bool aot_compile_op_end(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip);
bool aot_compile_op_br(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint br_depth, ubyte** p_frame_ip);
bool aot_compile_op_br_if(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint br_depth, ubyte** p_frame_ip);
bool aot_compile_op_br_table(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint* br_depths, uint br_count, ubyte** p_frame_ip);
bool aot_compile_op_return(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip);
bool aot_compile_op_unreachable(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip);
bool aot_handle_next_reachable_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip);
//#include "aot_emit_exception.h"
//#include "../aot/aot_runtime.h"
//#include "../interpreter/wasm_loader.h"
private char*[3] block_name_prefix = [ "block", "loop", "if" ];
private char*[3] block_name_suffix = [ "begin", "else", "end" ];
/* clang-format off */
enum {
    LABEL_BEGIN = 0,
    LABEL_ELSE,
    LABEL_END
}
/* clang-format on */
private void format_block_name(char* name, uint name_size, uint block_index, uint label_type, uint label_id) {
    if (label_type != LABEL_TYPE_FUNCTION)
        snprintf(name, name_size, "%s%d%s%s", block_name_prefix[label_type],
                 block_index, "_", block_name_suffix[label_id]);
    else
        snprintf(name, name_size, "%s", "func_end");
}
private LLVMBasicBlockRef find_next_llvm_end_block(AOTBlock* block) {
    block = block.prev;
    while (block && !block.llvm_end_block)
        block = block.prev;
    return block ? block.llvm_end_block : null;
}
private AOTBlock* get_target_block(AOTFuncContext* func_ctx, uint br_depth) {
    uint i = br_depth;
    AOTBlock* block = func_ctx.block_stack.block_list_end;
    while (i-- > 0 && block) {
        block = block.prev;
    }
    if (!block) {
        aot_set_last_error("WASM block stack underflow.");
        return null;
    }
    return block;
}
private bool handle_next_reachable_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip) {
    AOTBlock* block = func_ctx.block_stack.block_list_end;
    AOTBlock* block_prev = void;
    ubyte* frame_ip = null;
    uint i = void;
    AOTFuncType* func_type = void;
    LLVMValueRef ret = void;
    aot_checked_addr_list_destroy(func_ctx);
    bh_assert(block);
    if (block.label_type == LABEL_TYPE_IF && block.llvm_else_block
        && *p_frame_ip <= block.wasm_code_else) {
        /* Clear value stack and start to translate else branch */
        aot_value_stack_destroy(&block.value_stack);
        /* Recover parameters of else branch */
        for (i = 0; i < block.param_count; i++)
            PUSH(block.else_param_phis[i], block.param_types[i]);
        LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_else_block);
        *p_frame_ip = block.wasm_code_else + 1;
        return true;
    }
    while (block && !block.is_reachable) {
        block_prev = block.prev;
        block = aot_block_stack_pop(&func_ctx.block_stack);
        if (block.label_type == LABEL_TYPE_IF) {
            if (block.llvm_else_block && !block.skip_wasm_code_else
                && *p_frame_ip <= block.wasm_code_else) {
                /* Clear value stack and start to translate else branch */
                aot_value_stack_destroy(&block.value_stack);
                LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_else_block);
                *p_frame_ip = block.wasm_code_else + 1;
                /* Push back the block */
                aot_block_stack_push(&func_ctx.block_stack, block);
                return true;
            }
            else if (block.llvm_end_block) {
                /* Remove unreachable basic block */
                LLVMDeleteBasicBlock(block.llvm_end_block);
                block.llvm_end_block = null;
            }
        }
        frame_ip = block.wasm_code_end;
        aot_block_destroy(block);
        block = block_prev;
    }
    if (!block) {
        *p_frame_ip = frame_ip + 1;
        return true;
    }
    *p_frame_ip = block.wasm_code_end + 1;
    LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_end_block);
    /* Pop block, push its return value, and destroy the block */
    block = aot_block_stack_pop(&func_ctx.block_stack);
    func_type = func_ctx.aot_func.func_type;
    for (i = 0; i < block.result_count; i++) {
        bh_assert(block.result_phis[i]);
        if (block.label_type != LABEL_TYPE_FUNCTION) {
            PUSH(block.result_phis[i], block.result_types[i]);
        }
        else {
            /* Store extra return values to function parameters */
            if (i != 0) {
                uint param_index = func_type.param_count + i;
                if (!LLVMBuildStore(
                        comp_ctx.builder, block.result_phis[i],
                        LLVMGetParam(func_ctx.func, param_index))) {
                    aot_set_last_error("llvm build store failed.");
                    goto fail;
                }
            }
        }
    }
    if (block.label_type == LABEL_TYPE_FUNCTION) {
        if (block.result_count) {
            /* Return the first return value */
            if (((ret =
                      LLVMBuildRet(comp_ctx.builder, block.result_phis[0])) == 0)) {
                aot_set_last_error("llvm build return failed.");
                goto fail;
            }
        }
        else {
            if (((ret = LLVMBuildRetVoid(comp_ctx.builder)) == 0)) {
                aot_set_last_error("llvm build return void failed.");
                goto fail;
            }
        }
    }
    aot_block_destroy(block);
    return true;
fail:
    return false;
}
private bool push_aot_block_to_stack_and_pass_params(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, AOTBlock* block) {
    uint i = void, param_index = void;
    LLVMValueRef value = void;
    ulong size = void;
    char[32] name = void;
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    if (block.param_count) {
        size = sizeof(LLVMValueRef) * cast(ulong)block.param_count;
        if (size >= UINT32_MAX
            || ((block.param_phis = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            return false;
        }
        if (block.label_type == LABEL_TYPE_IF && !block.skip_wasm_code_else
            && ((block.else_param_phis = wasm_runtime_malloc(cast(uint)size)) == 0)) {
            wasm_runtime_free(block.param_phis);
            block.param_phis = null;
            aot_set_last_error("allocate memory failed.");
            return false;
        }
        /* Create param phis */
        for (i = 0; i < block.param_count; i++) {
            LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_entry_block);
            snprintf(name.ptr, name.sizeof, "%s%d_phi%d",
                     block_name_prefix[block.label_type], block.block_index,
                     i);
            if (((block.param_phis[i] = LLVMBuildPhi(
                      comp_ctx.builder, TO_LLVM_TYPE(block.param_types[i]),
                      name.ptr)) == 0)) {
                aot_set_last_error("llvm build phi failed.");
                goto fail;
            }
            if (block.label_type == LABEL_TYPE_IF
                && !block.skip_wasm_code_else && block.llvm_else_block) {
                /* Build else param phis */
                LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_else_block);
                snprintf(name.ptr, name.sizeof, "else%d_phi%d", block.block_index,
                         i);
                if (((block.else_param_phis[i] = LLVMBuildPhi(
                          comp_ctx.builder,
                          TO_LLVM_TYPE(block.param_types[i]), name.ptr)) == 0)) {
                    aot_set_last_error("llvm build phi failed.");
                    goto fail;
                }
            }
        }
        LLVMPositionBuilderAtEnd(comp_ctx.builder, block_curr);
        /* Pop param values from current block's
         * value stack and add to param phis.
         */
        for (i = 0; i < block.param_count; i++) {
            param_index = block.param_count - 1 - i;
            POP(value, block.param_types[param_index]);
            do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMAddIncoming(block.param_phis[param_index], &value, &_block_curr, 1); } while (0);
            if (block.label_type == LABEL_TYPE_IF
                && !block.skip_wasm_code_else) {
                if (block.llvm_else_block) {
                    /* has else branch, add to else param phis */
                    LLVMAddIncoming(block.else_param_phis[param_index], &value,
                                    &block_curr, 1);
                }
                else {
                    /* no else branch, add to result phis */
                    do { if (block.result_count && !block.result_phis) { uint _i = void; ulong _size = void; LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); /* Allocate memory */ _size = sizeof(LLVMValueRef) * cast(ulong)block.result_count; if (_size >= UINT32_MAX || ((block.result_phis = wasm_runtime_malloc(cast(uint)_size)) == 0)) { aot_set_last_error("allocate memory failed."); goto fail; } LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_end_block); for (_i = 0; _i < block.result_count; _i++) { if (((block.result_phis[_i] = LLVMBuildPhi( comp_ctx.builder, TO_LLVM_TYPE(block.result_types[_i]), "phi")) == 0)) { aot_set_last_error("llvm build phi failed."); goto fail; } } LLVMPositionBuilderAtEnd(comp_ctx.builder, _block_curr); } } while (0);
                    do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMTypeRef phi_ty = LLVMTypeOf(block.result_phis[param_index]); LLVMTypeRef value_ty = LLVMTypeOf(value); bh_assert(LLVMGetTypeKind(phi_ty) == LLVMGetTypeKind(value_ty)); bh_assert(LLVMGetTypeContext(phi_ty) == LLVMGetTypeContext(value_ty)); LLVMAddIncoming(block.result_phis[param_index], &value, &_block_curr, 1); cast(void)phi_ty; cast(void)value_ty; } while (0);
                }
            }
        }
    }
    /* Push the new block to block stack */
    aot_block_stack_push(&func_ctx.block_stack, block);
    /* Push param phis to the new block */
    for (i = 0; i < block.param_count; i++) {
        PUSH(block.param_phis[i], block.param_types[i]);
    }
    return true;
fail:
    if (block.param_phis) {
        wasm_runtime_free(block.param_phis);
        block.param_phis = null;
    }
    if (block.else_param_phis) {
        wasm_runtime_free(block.else_param_phis);
        block.else_param_phis = null;
    }
    return false;
}
bool aot_compile_op_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip, ubyte* frame_ip_end, uint label_type, uint param_count, ubyte* param_types, uint result_count, ubyte* result_types) {
    BlockAddr[BLOCK_ADDR_CONFLICT_SIZE][BLOCK_ADDR_CACHE_SIZE] block_addr_cache = void;
    AOTBlock* block = void;
    ubyte* else_addr = void, end_addr = void;
    LLVMValueRef value = void;
    char[32] name = void;
    /* Check block stack */
    if (!func_ctx.block_stack.block_list_end) {
        aot_set_last_error("WASM block stack underflow.");
        return false;
    }
    memset(block_addr_cache.ptr, 0, block_addr_cache.sizeof);
    /* Get block info */
    if (!(wasm_loader_find_block_addr(
            null, cast(BlockAddr*)block_addr_cache, *p_frame_ip, frame_ip_end,
            cast(ubyte)label_type, &else_addr, &end_addr))) {
        aot_set_last_error("find block end addr failed.");
        return false;
    }
    /* Allocate memory */
    if (((block = wasm_runtime_malloc(AOTBlock.sizeof)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return false;
    }
    memset(block, 0, AOTBlock.sizeof);
    if (param_count
        && ((block.param_types = wasm_runtime_malloc(param_count)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        goto fail;
    }
    if (result_count) {
        if (((block.result_types = wasm_runtime_malloc(result_count)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }
    }
    /* Init aot block data */
    block.label_type = label_type;
    block.param_count = param_count;
    if (param_count) {
        bh_memcpy_s(block.param_types, param_count, param_types, param_count);
    }
    block.result_count = result_count;
    if (result_count) {
        bh_memcpy_s(block.result_types, result_count, result_types,
                    result_count);
    }
    block.wasm_code_else = else_addr;
    block.wasm_code_end = end_addr;
    block.block_index = func_ctx.block_stack.block_index[label_type];
    func_ctx.block_stack.block_index[label_type]++;
    if (label_type == LABEL_TYPE_BLOCK || label_type == LABEL_TYPE_LOOP) {
        /* Create block */
        format_block_name(name.ptr, name.sizeof, block.block_index, label_type,
                          LABEL_BEGIN);
        do { if (((block.llvm_entry_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
        LLVMMoveBasicBlockAfter(block.llvm_entry_block, LLVMGetInsertBlock(comp_ctx.builder));
        /* Jump to the entry block */
        do { if (!LLVMBuildBr(comp_ctx.builder, block.llvm_entry_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
        if (!push_aot_block_to_stack_and_pass_params(comp_ctx, func_ctx, block))
            goto fail;
        /* Start to translate the block */
        LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_entry_block);
        if (label_type == LABEL_TYPE_LOOP)
            aot_checked_addr_list_destroy(func_ctx);
    }
    else if (label_type == LABEL_TYPE_IF) {
        POP_COND(value);
        if (LLVMIsUndef(value)
        ) {
            if (!(aot_emit_exception(comp_ctx, func_ctx, EXCE_INTEGER_OVERFLOW,
                                     false, null, null))) {
                goto fail;
            }
            aot_block_destroy(block);
            return aot_handle_next_reachable_block(comp_ctx, func_ctx,
                                                   p_frame_ip);
        }
        if (!LLVMIsConstant(value)) {
            /* Compare value is not constant, create condition br IR */
            /* Create entry block */
            format_block_name(name.ptr, name.sizeof, block.block_index,
                              label_type, LABEL_BEGIN);
            do { if (((block.llvm_entry_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
            LLVMMoveBasicBlockAfter(block.llvm_entry_block, LLVMGetInsertBlock(comp_ctx.builder));
            /* Create end block */
            format_block_name(name.ptr, name.sizeof, block.block_index,
                              label_type, LABEL_END);
            do { if (((block.llvm_end_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
            LLVMMoveBasicBlockAfter(block.llvm_end_block, block.llvm_entry_block);
            if (else_addr) {
                /* Create else block */
                format_block_name(name.ptr, name.sizeof, block.block_index,
                                  label_type, LABEL_ELSE);
                do { if (((block.llvm_else_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
                LLVMMoveBasicBlockAfter(block.llvm_else_block, block.llvm_entry_block);
                /* Create condition br IR */
                do { if (!LLVMBuildCondBr(comp_ctx.builder, value, block.llvm_entry_block, block.llvm_else_block)) { aot_set_last_error("llvm build cond br failed."); goto fail; } } while (0);
            }
            else {
                /* Create condition br IR */
                do { if (!LLVMBuildCondBr(comp_ctx.builder, value, block.llvm_entry_block, block.llvm_end_block)) { aot_set_last_error("llvm build cond br failed."); goto fail; } } while (0);
                block.is_reachable = true;
            }
            if (!push_aot_block_to_stack_and_pass_params(comp_ctx, func_ctx,
                                                         block))
                goto fail;
            /* Start to translate if branch of BLOCK if */
            LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_entry_block);
        }
        else {
            if (cast(int)LLVMConstIntGetZExtValue(value) != 0) {
                /* Compare value is not 0, condition is true, else branch of
                   BLOCK if cannot be reached */
                block.skip_wasm_code_else = true;
                /* Create entry block */
                format_block_name(name.ptr, name.sizeof, block.block_index,
                                  label_type, LABEL_BEGIN);
                do { if (((block.llvm_entry_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
                LLVMMoveBasicBlockAfter(block.llvm_entry_block, LLVMGetInsertBlock(comp_ctx.builder));
                /* Jump to the entry block */
                do { if (!LLVMBuildBr(comp_ctx.builder, block.llvm_entry_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
                if (!push_aot_block_to_stack_and_pass_params(comp_ctx, func_ctx,
                                                             block))
                    goto fail;
                /* Start to translate the if branch */
                LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_entry_block);
            }
            else {
                /* Compare value is not 0, condition is false, if branch of
                   BLOCK if cannot be reached */
                if (else_addr) {
                    /* Create else block */
                    format_block_name(name.ptr, name.sizeof, block.block_index,
                                      label_type, LABEL_ELSE);
                    do { if (((block.llvm_else_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
                    LLVMMoveBasicBlockAfter(block.llvm_else_block, LLVMGetInsertBlock(comp_ctx.builder));
                    /* Jump to the else block */
                    do { if (!LLVMBuildBr(comp_ctx.builder, block.llvm_else_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
                    if (!push_aot_block_to_stack_and_pass_params(
                            comp_ctx, func_ctx, block))
                        goto fail;
                    /* Start to translate the else branch */
                    LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_else_block);
                    *p_frame_ip = else_addr + 1;
                }
                else {
                    /* skip the block */
                    aot_block_destroy(block);
                    *p_frame_ip = end_addr + 1;
                }
            }
        }
    }
    else {
        aot_set_last_error("Invalid block type.");
        goto fail;
    }
    return true;
fail:
    aot_block_destroy(block);
    return false;
}
bool aot_compile_op_else(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip) {
    AOTBlock* block = func_ctx.block_stack.block_list_end;
    LLVMValueRef value = void;
    char[32] name = void;
    uint i = void, result_index = void;
    /* Check block */
    if (!block) {
        aot_set_last_error("WASM block stack underflow.");
        return false;
    }
    if (block.label_type != LABEL_TYPE_IF
        || (!block.skip_wasm_code_else && !block.llvm_else_block)) {
        aot_set_last_error("Invalid WASM block type.");
        return false;
    }
    /* Create end block if needed */
    if (!block.llvm_end_block) {
        format_block_name(name.ptr, name.sizeof, block.block_index,
                          block.label_type, LABEL_END);
        do { if (((block.llvm_end_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
        if (block.llvm_else_block)
            LLVMMoveBasicBlockAfter(block.llvm_end_block, block.llvm_else_block);
        else
            LLVMMoveBasicBlockAfter(block.llvm_end_block, LLVMGetInsertBlock(comp_ctx.builder));
    }
    block.is_reachable = true;
    /* Comes from the if branch of BLOCK if */
    do { if (block.result_count && !block.result_phis) { uint _i = void; ulong _size = void; LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); /* Allocate memory */ _size = sizeof(LLVMValueRef) * cast(ulong)block.result_count; if (_size >= UINT32_MAX || ((block.result_phis = wasm_runtime_malloc(cast(uint)_size)) == 0)) { aot_set_last_error("allocate memory failed."); goto fail; } LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_end_block); for (_i = 0; _i < block.result_count; _i++) { if (((block.result_phis[_i] = LLVMBuildPhi( comp_ctx.builder, TO_LLVM_TYPE(block.result_types[_i]), "phi")) == 0)) { aot_set_last_error("llvm build phi failed."); goto fail; } } LLVMPositionBuilderAtEnd(comp_ctx.builder, _block_curr); } } while (0);
    for (i = 0; i < block.result_count; i++) {
        result_index = block.result_count - 1 - i;
        POP(value, block.result_types[result_index]);
        do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMTypeRef phi_ty = LLVMTypeOf(block.result_phis[result_index]); LLVMTypeRef value_ty = LLVMTypeOf(value); bh_assert(LLVMGetTypeKind(phi_ty) == LLVMGetTypeKind(value_ty)); bh_assert(LLVMGetTypeContext(phi_ty) == LLVMGetTypeContext(value_ty)); LLVMAddIncoming(block.result_phis[result_index], &value, &_block_curr, 1); cast(void)phi_ty; cast(void)value_ty; } while (0);
    }
    /* Jump to end block */
    do { if (!LLVMBuildBr(comp_ctx.builder, block.llvm_end_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
    if (!block.skip_wasm_code_else && block.llvm_else_block) {
        /* Clear value stack, recover param values
         * and start to translate else branch.
         */
        aot_value_stack_destroy(&block.value_stack);
        for (i = 0; i < block.param_count; i++)
            PUSH(block.else_param_phis[i], block.param_types[i]);
        LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_else_block);
        aot_checked_addr_list_destroy(func_ctx);
        return true;
    }
    /* No else branch or no need to translate else branch */
    block.is_reachable = true;
    return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
fail:
    return false;
}
bool aot_compile_op_end(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip) {
    AOTBlock* block = void;
    LLVMValueRef value = void;
    LLVMBasicBlockRef next_llvm_end_block = void;
    char[32] name = void;
    uint i = void, result_index = void;
    /* Check block stack */
    if (((block = func_ctx.block_stack.block_list_end) == 0)) {
        aot_set_last_error("WASM block stack underflow.");
        return false;
    }
    /* Create the end block */
    if (!block.llvm_end_block) {
        format_block_name(name.ptr, name.sizeof, block.block_index,
                          block.label_type, LABEL_END);
        do { if (((block.llvm_end_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
        if ((next_llvm_end_block = find_next_llvm_end_block(block)))
            LLVMMoveBasicBlockBefore(block.llvm_end_block, next_llvm_end_block);
    }
    /* Handle block result values */
    do { if (block.result_count && !block.result_phis) { uint _i = void; ulong _size = void; LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); /* Allocate memory */ _size = sizeof(LLVMValueRef) * cast(ulong)block.result_count; if (_size >= UINT32_MAX || ((block.result_phis = wasm_runtime_malloc(cast(uint)_size)) == 0)) { aot_set_last_error("allocate memory failed."); goto fail; } LLVMPositionBuilderAtEnd(comp_ctx.builder, block.llvm_end_block); for (_i = 0; _i < block.result_count; _i++) { if (((block.result_phis[_i] = LLVMBuildPhi( comp_ctx.builder, TO_LLVM_TYPE(block.result_types[_i]), "phi")) == 0)) { aot_set_last_error("llvm build phi failed."); goto fail; } } LLVMPositionBuilderAtEnd(comp_ctx.builder, _block_curr); } } while (0);
    for (i = 0; i < block.result_count; i++) {
        value = null;
        result_index = block.result_count - 1 - i;
        POP(value, block.result_types[result_index]);
        bh_assert(value);
        do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMTypeRef phi_ty = LLVMTypeOf(block.result_phis[result_index]); LLVMTypeRef value_ty = LLVMTypeOf(value); bh_assert(LLVMGetTypeKind(phi_ty) == LLVMGetTypeKind(value_ty)); bh_assert(LLVMGetTypeContext(phi_ty) == LLVMGetTypeContext(value_ty)); LLVMAddIncoming(block.result_phis[result_index], &value, &_block_curr, 1); cast(void)phi_ty; cast(void)value_ty; } while (0);
    }
    /* Jump to the end block */
    do { if (!LLVMBuildBr(comp_ctx.builder, block.llvm_end_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
    block.is_reachable = true;
    return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
fail:
    return false;
}
bool aot_compile_op_br(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint br_depth, ubyte** p_frame_ip) {
    AOTBlock* block_dst = void;
    LLVMValueRef value_ret = void, value_param = void;
    LLVMBasicBlockRef next_llvm_end_block = void;
    char[32] name = void;
    uint i = void, param_index = void, result_index = void;
    if (((block_dst = get_target_block(func_ctx, br_depth)) == 0)) {
        return false;
    }
    if (block_dst.label_type == LABEL_TYPE_LOOP) {
        /* Dest block is Loop block */
        /* Handle Loop parameters */
        for (i = 0; i < block_dst.param_count; i++) {
            param_index = block_dst.param_count - 1 - i;
            POP(value_param, block_dst.param_types[param_index]);
            do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMAddIncoming(block_dst.param_phis[param_index], &value_param, &_block_curr, 1); } while (0);
        }
        do { if (!LLVMBuildBr(comp_ctx.builder, block_dst.llvm_entry_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
    }
    else {
        /* Dest block is Block/If/Function block */
        /* Create the end block */
        if (!block_dst.llvm_end_block) {
            format_block_name(name.ptr, name.sizeof, block_dst.block_index,
                              block_dst.label_type, LABEL_END);
            do { if (((block_dst.llvm_end_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
            if ((next_llvm_end_block = find_next_llvm_end_block(block_dst)))
                LLVMMoveBasicBlockBefore(block_dst.llvm_end_block, next_llvm_end_block);
        }
        block_dst.is_reachable = true;
        /* Handle result values */
        do { if (block_dst.result_count && !block_dst.result_phis) { uint _i = void; ulong _size = void; LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); /* Allocate memory */ _size = sizeof(LLVMValueRef) * cast(ulong)block_dst.result_count; if (_size >= UINT32_MAX || ((block_dst.result_phis = wasm_runtime_malloc(cast(uint)_size)) == 0)) { aot_set_last_error("allocate memory failed."); goto fail; } LLVMPositionBuilderAtEnd(comp_ctx.builder, block_dst.llvm_end_block); for (_i = 0; _i < block_dst.result_count; _i++) { if (((block_dst.result_phis[_i] = LLVMBuildPhi( comp_ctx.builder, TO_LLVM_TYPE(block_dst.result_types[_i]), "phi")) == 0)) { aot_set_last_error("llvm build phi failed."); goto fail; } } LLVMPositionBuilderAtEnd(comp_ctx.builder, _block_curr); } } while (0);
        for (i = 0; i < block_dst.result_count; i++) {
            result_index = block_dst.result_count - 1 - i;
            POP(value_ret, block_dst.result_types[result_index]);
            do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMTypeRef phi_ty = LLVMTypeOf(block_dst.result_phis[result_index]); LLVMTypeRef value_ty = LLVMTypeOf(value_ret); bh_assert(LLVMGetTypeKind(phi_ty) == LLVMGetTypeKind(value_ty)); bh_assert(LLVMGetTypeContext(phi_ty) == LLVMGetTypeContext(value_ty)); LLVMAddIncoming(block_dst.result_phis[result_index], &value_ret, &_block_curr, 1); cast(void)phi_ty; cast(void)value_ty; } while (0);
        }
        /* Jump to the end block */
        do { if (!LLVMBuildBr(comp_ctx.builder, block_dst.llvm_end_block)) { aot_set_last_error("llvm build br failed."); goto fail; } } while (0);
    }
    return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
fail:
    return false;
}
bool aot_compile_op_br_if(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint br_depth, ubyte** p_frame_ip) {
    AOTBlock* block_dst = void;
    LLVMValueRef value_cmp = void, value = void; LLVMValueRef* values = null;
    LLVMBasicBlockRef llvm_else_block = void, next_llvm_end_block = void;
    char[32] name = void;
    uint i = void, param_index = void, result_index = void;
    ulong size = void;
    POP_COND(value_cmp);
    if (LLVMIsUndef(value_cmp)
    ) {
        if (!(aot_emit_exception(comp_ctx, func_ctx, EXCE_INTEGER_OVERFLOW,
                                 false, null, null))) {
            goto fail;
        }
        return aot_handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
    }
    if (!LLVMIsConstant(value_cmp)) {
        /* Compare value is not constant, create condition br IR */
        if (((block_dst = get_target_block(func_ctx, br_depth)) == 0)) {
            return false;
        }
        /* Create llvm else block */
        do { if (((llvm_else_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, "br_if_else")) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
        LLVMMoveBasicBlockAfter(llvm_else_block, LLVMGetInsertBlock(comp_ctx.builder));
        if (block_dst.label_type == LABEL_TYPE_LOOP) {
            /* Dest block is Loop block */
            /* Handle Loop parameters */
            if (block_dst.param_count) {
                size = sizeof(LLVMValueRef) * cast(ulong)block_dst.param_count;
                if (size >= UINT32_MAX
                    || ((values = wasm_runtime_malloc(cast(uint)size)) == 0)) {
                    aot_set_last_error("allocate memory failed.");
                    goto fail;
                }
                for (i = 0; i < block_dst.param_count; i++) {
                    param_index = block_dst.param_count - 1 - i;
                    POP(value, block_dst.param_types[param_index]);
                    do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMAddIncoming(block_dst.param_phis[param_index], &value, &_block_curr, 1); } while (0);
                    values[param_index] = value;
                }
                for (i = 0; i < block_dst.param_count; i++) {
                    PUSH(values[i], block_dst.param_types[i]);
                }
                wasm_runtime_free(values);
                values = null;
            }
            do { if (!LLVMBuildCondBr(comp_ctx.builder, value_cmp, block_dst.llvm_entry_block, llvm_else_block)) { aot_set_last_error("llvm build cond br failed."); goto fail; } } while (0);
            /* Move builder to else block */
            LLVMPositionBuilderAtEnd(comp_ctx.builder, llvm_else_block);
        }
        else {
            /* Dest block is Block/If/Function block */
            /* Create the end block */
            if (!block_dst.llvm_end_block) {
                format_block_name(name.ptr, name.sizeof, block_dst.block_index,
                                  block_dst.label_type, LABEL_END);
                do { if (((block_dst.llvm_end_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
                if ((next_llvm_end_block = find_next_llvm_end_block(block_dst)))
                    LLVMMoveBasicBlockBefore(block_dst.llvm_end_block, next_llvm_end_block);
            }
            /* Set reachable flag and create condition br IR */
            block_dst.is_reachable = true;
            /* Handle result values */
            if (block_dst.result_count) {
                size = sizeof(LLVMValueRef) * cast(ulong)block_dst.result_count;
                if (size >= UINT32_MAX
                    || ((values = wasm_runtime_malloc(cast(uint)size)) == 0)) {
                    aot_set_last_error("allocate memory failed.");
                    goto fail;
                }
                do { if (block_dst.result_count && !block_dst.result_phis) { uint _i = void; ulong _size = void; LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); /* Allocate memory */ _size = sizeof(LLVMValueRef) * cast(ulong)block_dst.result_count; if (_size >= UINT32_MAX || ((block_dst.result_phis = wasm_runtime_malloc(cast(uint)_size)) == 0)) { aot_set_last_error("allocate memory failed."); goto fail; } LLVMPositionBuilderAtEnd(comp_ctx.builder, block_dst.llvm_end_block); for (_i = 0; _i < block_dst.result_count; _i++) { if (((block_dst.result_phis[_i] = LLVMBuildPhi( comp_ctx.builder, TO_LLVM_TYPE(block_dst.result_types[_i]), "phi")) == 0)) { aot_set_last_error("llvm build phi failed."); goto fail; } } LLVMPositionBuilderAtEnd(comp_ctx.builder, _block_curr); } } while (0);
                for (i = 0; i < block_dst.result_count; i++) {
                    result_index = block_dst.result_count - 1 - i;
                    POP(value, block_dst.result_types[result_index]);
                    values[result_index] = value;
                    do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMTypeRef phi_ty = LLVMTypeOf(block_dst.result_phis[result_index]); LLVMTypeRef value_ty = LLVMTypeOf(value); bh_assert(LLVMGetTypeKind(phi_ty) == LLVMGetTypeKind(value_ty)); bh_assert(LLVMGetTypeContext(phi_ty) == LLVMGetTypeContext(value_ty)); LLVMAddIncoming(block_dst.result_phis[result_index], &value, &_block_curr, 1); cast(void)phi_ty; cast(void)value_ty; } while (0);
                }
                for (i = 0; i < block_dst.result_count; i++) {
                    PUSH(values[i], block_dst.result_types[i]);
                }
                wasm_runtime_free(values);
                values = null;
            }
            /* Condition jump to end block */
            do { if (!LLVMBuildCondBr(comp_ctx.builder, value_cmp, block_dst.llvm_end_block, llvm_else_block)) { aot_set_last_error("llvm build cond br failed."); goto fail; } } while (0);
            /* Move builder to else block */
            LLVMPositionBuilderAtEnd(comp_ctx.builder, llvm_else_block);
        }
    }
    else {
        if (cast(int)LLVMConstIntGetZExtValue(value_cmp) != 0) {
            /* Compare value is not 0, condition is true, same as op_br */
            return aot_compile_op_br(comp_ctx, func_ctx, br_depth, p_frame_ip);
        }
        else {
            /* Compare value is not 0, condition is false, skip br_if */
            return true;
        }
    }
    return true;
fail:
    if (values)
        wasm_runtime_free(values);
    return false;
}
bool aot_compile_op_br_table(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint* br_depths, uint br_count, ubyte** p_frame_ip) {
    uint i = void, j = void;
    LLVMValueRef value_switch = void, value_cmp = void, value_case = void, value = void; LLVMValueRef* values = null;
    LLVMBasicBlockRef default_llvm_block = null, target_llvm_block = void;
    LLVMBasicBlockRef next_llvm_end_block = void;
    AOTBlock* target_block = void;
    uint br_depth = void, depth_idx = void;
    uint param_index = void, result_index = void;
    ulong size = void;
    char[32] name = void;
    POP_I32(value_cmp);
    if (LLVMIsUndef(value_cmp)
    ) {
        if (!(aot_emit_exception(comp_ctx, func_ctx, EXCE_INTEGER_OVERFLOW,
                                 false, null, null))) {
            goto fail;
        }
        return aot_handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
    }
    if (!LLVMIsConstant(value_cmp)) {
        /* Compare value is not constant, create switch IR */
        for (i = 0; i <= br_count; i++) {
            target_block = get_target_block(func_ctx, br_depths[i]);
            if (!target_block)
                return false;
            if (target_block.label_type != LABEL_TYPE_LOOP) {
                /* Dest block is Block/If/Function block */
                /* Create the end block */
                if (!target_block.llvm_end_block) {
                    format_block_name(name.ptr, name.sizeof,
                                      target_block.block_index,
                                      target_block.label_type, LABEL_END);
                    do { if (((target_block.llvm_end_block = LLVMAppendBasicBlockInContext( comp_ctx.context, func_ctx.func, name.ptr)) == 0)) { aot_set_last_error("add LLVM basic block failed."); goto fail; } } while (0);
                    if ((next_llvm_end_block =
                             find_next_llvm_end_block(target_block)))
                        LLVMMoveBasicBlockBefore(target_block.llvm_end_block, next_llvm_end_block);
                }
                /* Handle result values */
                if (target_block.result_count) {
                    size = sizeof(LLVMValueRef)
                           * cast(ulong)target_block.result_count;
                    if (size >= UINT32_MAX
                        || ((values = wasm_runtime_malloc(cast(uint)size)) == 0)) {
                        aot_set_last_error("allocate memory failed.");
                        goto fail;
                    }
                    do { if (target_block.result_count && !target_block.result_phis) { uint _i = void; ulong _size = void; LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); /* Allocate memory */ _size = sizeof(LLVMValueRef) * cast(ulong)target_block.result_count; if (_size >= UINT32_MAX || ((target_block.result_phis = wasm_runtime_malloc(cast(uint)_size)) == 0)) { aot_set_last_error("allocate memory failed."); goto fail; } LLVMPositionBuilderAtEnd(comp_ctx.builder, target_block.llvm_end_block); for (_i = 0; _i < target_block.result_count; _i++) { if (((target_block.result_phis[_i] = LLVMBuildPhi( comp_ctx.builder, TO_LLVM_TYPE(target_block.result_types[_i]), "phi")) == 0)) { aot_set_last_error("llvm build phi failed."); goto fail; } } LLVMPositionBuilderAtEnd(comp_ctx.builder, _block_curr); } } while (0);
                    for (j = 0; j < target_block.result_count; j++) {
                        result_index = target_block.result_count - 1 - j;
                        POP(value, target_block.result_types[result_index]);
                        values[result_index] = value;
                        do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMTypeRef phi_ty = LLVMTypeOf(target_block.result_phis[result_index]); LLVMTypeRef value_ty = LLVMTypeOf(value); bh_assert(LLVMGetTypeKind(phi_ty) == LLVMGetTypeKind(value_ty)); bh_assert(LLVMGetTypeContext(phi_ty) == LLVMGetTypeContext(value_ty)); LLVMAddIncoming(target_block.result_phis[result_index], &value, &_block_curr, 1); cast(void)phi_ty; cast(void)value_ty; } while (0);
                    }
                    for (j = 0; j < target_block.result_count; j++) {
                        PUSH(values[j], target_block.result_types[j]);
                    }
                    wasm_runtime_free(values);
                }
                target_block.is_reachable = true;
                if (i == br_count)
                    default_llvm_block = target_block.llvm_end_block;
            }
            else {
                /* Handle Loop parameters */
                if (target_block.param_count) {
                    size = sizeof(LLVMValueRef)
                           * cast(ulong)target_block.param_count;
                    if (size >= UINT32_MAX
                        || ((values = wasm_runtime_malloc(cast(uint)size)) == 0)) {
                        aot_set_last_error("allocate memory failed.");
                        goto fail;
                    }
                    for (j = 0; j < target_block.param_count; j++) {
                        param_index = target_block.param_count - 1 - j;
                        POP(value, target_block.param_types[param_index]);
                        values[param_index] = value;
                        do { LLVMBasicBlockRef _block_curr = LLVMGetInsertBlock(comp_ctx.builder); LLVMAddIncoming(target_block.param_phis[param_index], &value, &_block_curr, 1); } while (0);
                    }
                    for (j = 0; j < target_block.param_count; j++) {
                        PUSH(values[j], target_block.param_types[j]);
                    }
                    wasm_runtime_free(values);
                }
                if (i == br_count)
                    default_llvm_block = target_block.llvm_entry_block;
            }
        }
        /* Create switch IR */
        if (((value_switch = LLVMBuildSwitch(comp_ctx.builder, value_cmp,
                                             default_llvm_block, br_count)) == 0)) {
            aot_set_last_error("llvm build switch failed.");
            return false;
        }
        /* Add each case for switch IR */
        for (i = 0; i < br_count; i++) {
            value_case = I32_CONST(i);
            CHECK_LLVM_CONST(value_case);
            target_block = get_target_block(func_ctx, br_depths[i]);
            if (!target_block)
                return false;
            target_llvm_block = target_block.label_type != LABEL_TYPE_LOOP
                                    ? target_block.llvm_end_block
                                    : target_block.llvm_entry_block;
            LLVMAddCase(value_switch, value_case, target_llvm_block);
        }
        return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
    }
    else {
        /* Compare value is constant, create br IR */
        depth_idx = cast(uint)LLVMConstIntGetZExtValue(value_cmp);
        br_depth = br_depths[br_count];
        if (depth_idx < br_count) {
            br_depth = br_depths[depth_idx];
        }
        return aot_compile_op_br(comp_ctx, func_ctx, br_depth, p_frame_ip);
    }
fail:
    if (values)
        wasm_runtime_free(values);
    return false;
}
bool aot_compile_op_return(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip) {
    AOTBlock* block_func = func_ctx.block_stack.block_list_head;
    LLVMValueRef value = void;
    LLVMValueRef ret = void;
    AOTFuncType* func_type = void;
    uint i = void, param_index = void, result_index = void;
    bh_assert(block_func);
    func_type = func_ctx.aot_func.func_type;
    if (block_func.result_count) {
        /* Store extra result values to function parameters */
        for (i = 0; i < block_func.result_count - 1; i++) {
            result_index = block_func.result_count - 1 - i;
            POP(value, block_func.result_types[result_index]);
            param_index = func_type.param_count + result_index;
            if (!LLVMBuildStore(comp_ctx.builder, value,
                                LLVMGetParam(func_ctx.func, param_index))) {
                aot_set_last_error("llvm build store failed.");
                goto fail;
            }
        }
        /* Return the first result value */
        POP(value, block_func.result_types[0]);
        if (((ret = LLVMBuildRet(comp_ctx.builder, value)) == 0)) {
            aot_set_last_error("llvm build return failed.");
            goto fail;
        }
    }
    else {
        if (((ret = LLVMBuildRetVoid(comp_ctx.builder)) == 0)) {
            aot_set_last_error("llvm build return void failed.");
            goto fail;
        }
    }
    return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
fail:
    return false;
}
bool aot_compile_op_unreachable(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip) {
    if (!aot_emit_exception(comp_ctx, func_ctx, EXCE_UNREACHABLE, false, null,
                            null))
        return false;
    return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
}
bool aot_handle_next_reachable_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte** p_frame_ip) {
    return handle_next_reachable_block(comp_ctx, func_ctx, p_frame_ip);
}
