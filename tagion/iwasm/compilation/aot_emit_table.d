module tagion.iwasm.compilation.aot_emit_table;
@nogc nothrow:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.basic;
import tagion.iwasm.compilation.aot_llvm;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.aot.aot_runtime;

ulong get_tbl_inst_offset(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, uint tbl_idx) {
    ulong offset = 0, i = 0;
    AOTImportTable* imp_tbls = comp_ctx.comp_data.import_tables;
    AOTTable* tbls = comp_ctx.comp_data.tables;

    offset =
        offsetof(AOTModuleInstance, global_table_data.bytes)
        + cast(ulong)comp_ctx.comp_data.memory_count * sizeof(AOTMemoryInstance)
        + comp_ctx.comp_data.global_data_size;

    while (i < tbl_idx && i < comp_ctx.comp_data.import_table_count) {
        offset += AOTTableInstance.elems.offsetof;
        /* avoid loading from current AOTTableInstance */
        offset +=
            sizeof(uint32)
            * aot_get_imp_tbl_data_slots(imp_tbls + i, comp_ctx.is_jit_mode);
        ++i;
    }

    if (i == tbl_idx) {
        return offset;
    }

    tbl_idx -= comp_ctx.comp_data.import_table_count;
    i -= comp_ctx.comp_data.import_table_count;
    while (i < tbl_idx && i < comp_ctx.comp_data.table_count) {
        offset += AOTTableInstance.elems.offsetof;
        /* avoid loading from current AOTTableInstance */
        offset += sizeof(uint32)
                  * aot_get_tbl_data_slots(tbls + i, comp_ctx.is_jit_mode);
        ++i;
    }

    return offset;
}

static if (ver.WASM_ENABLE_REF_TYPES) {

LLVMValueRef aot_compile_get_tbl_inst(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx) {
    LLVMValueRef offset = void, tbl_inst = void;

    if (((offset =
              I64_CONST(get_tbl_inst_offset(comp_ctx, func_ctx, tbl_idx))) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((tbl_inst = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                           func_ctx.aot_inst, &offset, 1,
                                           "tbl_inst")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInBoundsGEP");
        goto fail;
    }

    return tbl_inst;
fail:
    return null;
}

bool aot_compile_op_elem_drop(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_seg_idx) {
    LLVMTypeRef[2] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMValueRef[2] param_values = void; LLVMValueRef ret_value = void, func = void, value = void;

    /* void aot_drop_table_seg(AOTModuleInstance *, uint32 ) */
    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    ret_type = VOID_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_drop_table_seg, 2);
    else
        GET_AOT_FUNCTION(aot_drop_table_seg, 2);

    param_values[0] = func_ctx.aot_inst;
    if (((param_values[1] = I32_CONST(tbl_seg_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    /* "" means return void */
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 2, "")) == 0)) {
        HANDLE_FAILURE("LLVMBuildCall");
        goto fail;
    }

    return true;
fail:
    return false;
}

private bool aot_check_table_access(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx, LLVMValueRef elem_idx) {
    LLVMValueRef offset = void, tbl_sz = void, cmp_elem_idx = void;
    LLVMBasicBlockRef check_elem_idx_succ = void;

    /* get the cur size of the table instance */
    if (((offset = I32_CONST(get_tbl_inst_offset(comp_ctx, func_ctx, tbl_idx)
                             + AOTTableInstance.cur_size.offsetof)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((tbl_sz = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                         func_ctx.aot_inst, &offset, 1,
                                         "cur_size_i8p")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInBoundsGEP");
        goto fail;
    }

    if (((tbl_sz = LLVMBuildBitCast(comp_ctx.builder, tbl_sz, INT32_PTR_TYPE,
                                    "cur_siuze_i32p")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    if (((tbl_sz = LLVMBuildLoad2(comp_ctx.builder, I32_TYPE, tbl_sz,
                                  "cur_size")) == 0)) {
        HANDLE_FAILURE("LLVMBuildLoad");
        goto fail;
    }

    /* Check if (uint32)elem index >= table size */
    if (((cmp_elem_idx = LLVMBuildICmp(comp_ctx.builder, LLVMIntUGE, elem_idx,
                                       tbl_sz, "cmp_elem_idx")) == 0)) {
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

    if (!(aot_emit_exception(comp_ctx, func_ctx,
                             EXCE_OUT_OF_BOUNDS_TABLE_ACCESS, true,
                             cmp_elem_idx, check_elem_idx_succ)))
        goto fail;

    return true;
fail:
    return false;
}

bool aot_compile_op_table_get(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx) {
    LLVMValueRef elem_idx = void, offset = void, table_elem = void, func_idx = void;

    POP_I32(elem_idx);

    if (!aot_check_table_access(comp_ctx, func_ctx, tbl_idx, elem_idx)) {
        goto fail;
    }

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
        HANDLE_FAILURE("LLVMBuildLoad");
        goto fail;
    }

    PUSH_I32(func_idx);

    return true;
fail:
    return false;
}

bool aot_compile_op_table_set(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx) {
    LLVMValueRef val = void, elem_idx = void, offset = void, table_elem = void;

    POP_I32(val);
    POP_I32(elem_idx);

    if (!aot_check_table_access(comp_ctx, func_ctx, tbl_idx, elem_idx)) {
        goto fail;
    }

    /* load data as i32* */
    if (((offset = I32_CONST(get_tbl_inst_offset(comp_ctx, func_ctx, tbl_idx)
                             + AOTTableInstance.elems.offsetof)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((table_elem = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                             func_ctx.aot_inst, &offset, 1,
                                             "table_elem_i8p")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInBoundsGEP");
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
        HANDLE_FAILURE("LLVMBuildInBoundsGEP");
        goto fail;
    }

    if (!(LLVMBuildStore(comp_ctx.builder, val, table_elem))) {
        HANDLE_FAILURE("LLVMBuildStore");
        goto fail;
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_table_init(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx, uint tbl_seg_idx) {
    LLVMValueRef func = void; LLVMValueRef[6] param_values = void; LLVMValueRef value = void;
    LLVMTypeRef[6] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    param_types[2] = I32_TYPE;
    param_types[3] = I32_TYPE;
    param_types[4] = I32_TYPE;
    param_types[5] = I32_TYPE;
    ret_type = VOID_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_table_init, 6);
    else
        GET_AOT_FUNCTION(aot_table_init, 6);

    param_values[0] = func_ctx.aot_inst;

    if (((param_values[1] = I32_CONST(tbl_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((param_values[2] = I32_CONST(tbl_seg_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    /* n */
    POP_I32(param_values[3]);
    /* s */
    POP_I32(param_values[4]);
    /* d */
    POP_I32(param_values[5]);

    /* "" means return void */
    if (!(LLVMBuildCall2(comp_ctx.builder, func_type, func, param_values.ptr, 6,
                         ""))) {
        HANDLE_FAILURE("LLVMBuildCall");
        goto fail;
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_table_copy(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint src_tbl_idx, uint dst_tbl_idx) {
    LLVMTypeRef[6] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMValueRef func = void; LLVMValueRef[6] param_values = void; LLVMValueRef value = void;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    param_types[2] = I32_TYPE;
    param_types[3] = I32_TYPE;
    param_types[4] = I32_TYPE;
    param_types[5] = I32_TYPE;
    ret_type = VOID_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_table_copy, 6);
    else
        GET_AOT_FUNCTION(aot_table_copy, 6);

    param_values[0] = func_ctx.aot_inst;

    if (((param_values[1] = I32_CONST(src_tbl_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((param_values[2] = I32_CONST(dst_tbl_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    /* n */
    POP_I32(param_values[3]);
    /* s */
    POP_I32(param_values[4]);
    /* d */
    POP_I32(param_values[5]);

    /* "" means return void */
    if (!(LLVMBuildCall2(comp_ctx.builder, func_type, func, param_values.ptr, 6,
                         ""))) {
        HANDLE_FAILURE("LLVMBuildCall");
        goto fail;
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_table_size(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx) {
    LLVMValueRef offset = void, tbl_sz = void;

    if (((offset = I32_CONST(get_tbl_inst_offset(comp_ctx, func_ctx, tbl_idx)
                             + AOTTableInstance.cur_size.offsetof)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    if (((tbl_sz = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                         func_ctx.aot_inst, &offset, 1,
                                         "tbl_sz_ptr_i8")) == 0)) {
        HANDLE_FAILURE("LLVMBuildInBoundsGEP");
        goto fail;
    }

    if (((tbl_sz = LLVMBuildBitCast(comp_ctx.builder, tbl_sz, INT32_PTR_TYPE,
                                    "tbl_sz_ptr")) == 0)) {
        HANDLE_FAILURE("LLVMBuildBitCast");
        goto fail;
    }

    if (((tbl_sz =
              LLVMBuildLoad2(comp_ctx.builder, I32_TYPE, tbl_sz, "tbl_sz")) == 0)) {
        HANDLE_FAILURE("LLVMBuildLoad");
        goto fail;
    }

    PUSH_I32(tbl_sz);

    return true;
fail:
    return false;
}

bool aot_compile_op_table_grow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx) {
    LLVMTypeRef[4] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMValueRef func = void; LLVMValueRef[4] param_values = void; LLVMValueRef ret = void, value = void;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    param_types[2] = I32_TYPE;
    param_types[3] = I32_TYPE;
    ret_type = I32_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_table_grow, 4);
    else
        GET_AOT_FUNCTION(aot_table_grow, 4);

    param_values[0] = func_ctx.aot_inst;

    if (((param_values[1] = I32_CONST(tbl_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    /* n */
    POP_I32(param_values[2]);
    /* v */
    POP_I32(param_values[3]);

    if (((ret = LLVMBuildCall2(comp_ctx.builder, func_type, func, param_values.ptr,
                               4, "table_grow")) == 0)) {
        HANDLE_FAILURE("LLVMBuildCall");
        goto fail;
    }

    PUSH_I32(ret);

    return true;
fail:
    return false;
}

bool aot_compile_op_table_fill(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint tbl_idx) {
    LLVMTypeRef[5] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMValueRef func = void; LLVMValueRef[5] param_values = void; LLVMValueRef value = void;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    param_types[2] = I32_TYPE;
    param_types[3] = I32_TYPE;
    param_types[4] = I32_TYPE;
    ret_type = VOID_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_table_fill, 5);
    else
        GET_AOT_FUNCTION(aot_table_fill, 5);

    param_values[0] = func_ctx.aot_inst;

    if (((param_values[1] = I32_CONST(tbl_idx)) == 0)) {
        HANDLE_FAILURE("LLVMConstInt");
        goto fail;
    }

    /* n */
    POP_I32(param_values[2]);
    /* v */
    POP_I32(param_values[3]);
    /* i */
    POP_I32(param_values[4]);

    /* "" means return void */
    if (!(LLVMBuildCall2(comp_ctx.builder, func_type, func, param_values.ptr, 5,
                         ""))) {
        HANDLE_FAILURE("LLVMBuildCall");
        goto fail;
    }

    return true;
fail:
    return false;
}

} /*  WASM_ENABLE_REF_TYPES != 0 */

/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 

