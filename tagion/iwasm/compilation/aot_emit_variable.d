module aot_emit_variable;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_emit_variable;
public import aot_emit_exception;
public import ...aot.aot_runtime;

enum string CHECK_LOCAL(string idx) = `                                      \
    do {                                                      \
        if (idx >= func_ctx->aot_func->func_type->param_count \
                       + func_ctx->aot_func->local_count) {   \
            aot_set_last_error("local index out of range");   \
            return false;                                     \
        }                                                     \
    } while (0)`;

private ubyte get_local_type(AOTFuncContext* func_ctx, uint local_idx) {
    AOTFunc* aot_func = func_ctx.aot_func;
    uint param_count = aot_func.func_type.param_count;
    return local_idx < param_count
               ? aot_func.func_type.types[local_idx]
               : aot_func.local_types[local_idx - param_count];
}

bool aot_compile_op_get_local(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint local_idx) {
    char[32] name = void;
    LLVMValueRef value = void;
    AOTValue* aot_value_top = void;
    ubyte local_type = void;

    CHECK_LOCAL(local_idx);

    local_type = get_local_type(func_ctx, local_idx);

    snprintf(name.ptr, name.sizeof, "%s%d%s", "local", local_idx, "#");
    if (((value = LLVMBuildLoad2(comp_ctx.builder, TO_LLVM_TYPE(local_type),
                                 func_ctx.locals[local_idx], name.ptr)) == 0)) {
        aot_set_last_error("llvm build load fail");
        return false;
    }

    PUSH(value, local_type);

    aot_value_top =
        func_ctx.block_stack.block_list_end.value_stack.value_list_end;
    aot_value_top.is_local = true;
    aot_value_top.local_idx = local_idx;
    return true;

fail:
    return false;
}

bool aot_compile_op_set_local(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint local_idx) {
    LLVMValueRef value = void;

    CHECK_LOCAL(local_idx);

    POP(value, get_local_type(func_ctx, local_idx));

    if (!LLVMBuildStore(comp_ctx.builder, value,
                        func_ctx.locals[local_idx])) {
        aot_set_last_error("llvm build store fail");
        return false;
    }

    aot_checked_addr_list_del(func_ctx, local_idx);
    return true;

fail:
    return false;
}

bool aot_compile_op_tee_local(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint local_idx) {
    LLVMValueRef value = void;
    ubyte type = void;

    CHECK_LOCAL(local_idx);

    type = get_local_type(func_ctx, local_idx);

    POP(value, type);

    if (!LLVMBuildStore(comp_ctx.builder, value,
                        func_ctx.locals[local_idx])) {
        aot_set_last_error("llvm build store fail");
        return false;
    }

    PUSH(value, type);
    aot_checked_addr_list_del(func_ctx, local_idx);
    return true;

fail:
    return false;
}

private bool compile_global(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint global_idx, bool is_set, bool is_aux_stack) {
    AOTCompData* comp_data = comp_ctx.comp_data;
    uint import_global_count = comp_data.import_global_count;
    uint global_base_offset = void;
    uint global_offset = void;
    ubyte global_type = void;
    LLVMValueRef offset = void, global_ptr = void, global = void, res = void;
    LLVMTypeRef ptr_type = null;

    global_base_offset =
        offsetof(AOTModuleInstance, global_table_data.bytes)
        + sizeof(AOTMemoryInstance) * comp_ctx.comp_data.memory_count;

    bh_assert(global_idx < import_global_count + comp_data.global_count);

    if (global_idx < import_global_count) {
        global_offset = global_base_offset
                        + comp_data.import_globals[global_idx].data_offset;
        global_type = comp_data.import_globals[global_idx].type;
    }
    else {
        global_offset =
            global_base_offset
            + comp_data.globals[global_idx - import_global_count].data_offset;
        global_type = comp_data.globals[global_idx - import_global_count].type;
    }

    offset = I32_CONST(global_offset);
    if (((global_ptr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                             func_ctx.aot_inst, &offset, 1,
                                             "global_ptr_tmp")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed.");
        return false;
    }

    switch (global_type) {
        case VALUE_TYPE_I32:
        case VALUE_TYPE_EXTERNREF:
        case VALUE_TYPE_FUNCREF:
            ptr_type = comp_ctx.basic_types.int32_ptr_type;
            break;
        case VALUE_TYPE_I64:
            ptr_type = comp_ctx.basic_types.int64_ptr_type;
            break;
        case VALUE_TYPE_F32:
            ptr_type = comp_ctx.basic_types.float32_ptr_type;
            break;
        case VALUE_TYPE_F64:
            ptr_type = comp_ctx.basic_types.float64_ptr_type;
            break;
        case VALUE_TYPE_V128:
            ptr_type = comp_ctx.basic_types.v128_ptr_type;
            break;
        default:
            bh_assert("unknown type");
            break;
    }

    if (((global_ptr = LLVMBuildBitCast(comp_ctx.builder, global_ptr, ptr_type,
                                        "global_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed.");
        return false;
    }

    if (!is_set) {
        if (((global =
                  LLVMBuildLoad2(comp_ctx.builder, TO_LLVM_TYPE(global_type),
                                 global_ptr, "global")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            return false;
        }
        /* All globals' data is 4-byte aligned */
        LLVMSetAlignment(global, 4);
        PUSH(global, global_type);
    }
    else {
        POP(global, global_type);

        if (is_aux_stack && comp_ctx.enable_aux_stack_check) {
            LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
            LLVMBasicBlockRef check_overflow_succ = void, check_underflow_succ = void;
            LLVMValueRef cmp = void;

            /* Add basic blocks */
            if (((check_overflow_succ = LLVMAppendBasicBlockInContext(
                      comp_ctx.context, func_ctx.func,
                      "check_overflow_succ")) == 0)) {
                aot_set_last_error("llvm add basic block failed.");
                return false;
            }
            LLVMMoveBasicBlockAfter(check_overflow_succ, block_curr);

            if (((check_underflow_succ = LLVMAppendBasicBlockInContext(
                      comp_ctx.context, func_ctx.func,
                      "check_underflow_succ")) == 0)) {
                aot_set_last_error("llvm add basic block failed.");
                return false;
            }
            LLVMMoveBasicBlockAfter(check_underflow_succ, check_overflow_succ);

            /* Check aux stack overflow */
            if (((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntULE, global,
                                      func_ctx.aux_stack_bound, "cmp")) == 0)) {
                aot_set_last_error("llvm build icmp failed.");
                return false;
            }
            if (!aot_emit_exception(comp_ctx, func_ctx, EXCE_AUX_STACK_OVERFLOW,
                                    true, cmp, check_overflow_succ)) {
                return false;
            }

            /* Check aux stack underflow */
            LLVMPositionBuilderAtEnd(comp_ctx.builder, check_overflow_succ);
            if (((cmp = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGT, global,
                                      func_ctx.aux_stack_bottom, "cmp")) == 0)) {
                aot_set_last_error("llvm build icmp failed.");
                return false;
            }
            if (!aot_emit_exception(comp_ctx, func_ctx,
                                    EXCE_AUX_STACK_UNDERFLOW, true, cmp,
                                    check_underflow_succ)) {
                return false;
            }

            LLVMPositionBuilderAtEnd(comp_ctx.builder, check_underflow_succ);
        }

        if (((res = LLVMBuildStore(comp_ctx.builder, global, global_ptr)) == 0)) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
        /* All globals' data is 4-byte aligned */
        LLVMSetAlignment(res, 4);
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_get_global(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint global_idx) {
    return compile_global(comp_ctx, func_ctx, global_idx, false, false);
}

bool aot_compile_op_set_global(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint global_idx, bool is_aux_stack) {
    return compile_global(comp_ctx, func_ctx, global_idx, true, is_aux_stack);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import aot_compiler;

version (none) {
extern "C" {
//! #endif

bool aot_compile_op_get_local(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint local_idx);

bool aot_compile_op_set_local(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint local_idx);

bool aot_compile_op_tee_local(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint local_idx);

bool aot_compile_op_get_global(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint global_idx);

bool aot_compile_op_set_global(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint global_idx, bool is_aux_stack);

version (none) {}
} /* end of extern "C" */
}

 /* end of _AOT_EMIT_VARIABLE_H_ */