module aot_emit_memory;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_emit_memory;
public import aot_emit_exception;
public import ...aot.aot_runtime;
public import aot_intrinsic;

enum string BUILD_ICMP(string op, string left, string right, string res, string name) = `                                \
    do {                                                                      \
        if (!(res =                                                           \
                  LLVMBuildICmp(comp_ctx->builder, op, left, right, name))) { \
            aot_set_last_error("llvm build icmp failed.");                    \
            goto fail;                                                        \
        }                                                                     \
    } while (0)`;

enum string BUILD_OP(string Op, string left, string right, string res, string name) = `                                \
    do {                                                                    \
        if (!(res = LLVMBuild##Op(comp_ctx->builder, left, right, name))) { \
            aot_set_last_error("llvm build " #Op " fail.");                 \
            goto fail;                                                      \
        }                                                                   \
    } while (0)`;

enum string ADD_BASIC_BLOCK(string block, string name) = `                                          \
    do {                                                                      \
        if (!(block = LLVMAppendBasicBlockInContext(comp_ctx->context,        \
                                                    func_ctx->func, name))) { \
            aot_set_last_error("llvm add basic block failed.");               \
            goto fail;                                                        \
        }                                                                     \
    } while (0)`;

enum string SET_BUILD_POS(string block) = ` LLVMPositionBuilderAtEnd(comp_ctx->builder, block)`;

private LLVMValueRef get_memory_check_bound(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint bytes) {
    LLVMValueRef mem_check_bound = null;
    switch (bytes) {
        case 1:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_1byte;
            break;
        case 2:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_2bytes;
            break;
        case 4:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_4bytes;
            break;
        case 8:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_8bytes;
            break;
        case 16:
            mem_check_bound = func_ctx.mem_info[0].mem_bound_check_16bytes;
            break;
        default:
            bh_assert(0);
            return null;
    }

    if (func_ctx.mem_space_unchanged)
        return mem_check_bound;

    if (((mem_check_bound = LLVMBuildLoad2(
              comp_ctx.builder,
              (comp_ctx.pointer_size == uint64.sizeof) ? I64_TYPE : I32_TYPE,
              mem_check_bound, "mem_check_bound")) == 0)) {
        aot_set_last_error("llvm build load failed.");
        return null;
    }
    return mem_check_bound;
}

private LLVMValueRef get_memory_curr_page_count(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

LLVMValueRef aot_check_memory_overflow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint offset, uint bytes) {
    LLVMValueRef offset_const = I32_CONST(offset);
    LLVMValueRef addr = void, maddr = void, offset1 = void, cmp1 = void, cmp2 = void, cmp = void;
    LLVMValueRef mem_base_addr = void, mem_check_bound = void;
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMBasicBlockRef check_succ = void;
    AOTValue* aot_value_top = void;
    uint local_idx_of_aot_value = 0;
    bool is_target_64bit = void, is_local_of_aot_value = false;
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    bool is_shared_memory = comp_ctx.comp_data.memories[0].memory_flags & 0x02;
}

    is_target_64bit = (comp_ctx.pointer_size == uint64.sizeof) ? true : false;

    if (comp_ctx.is_indirect_mode
        && aot_intrinsic_check_capability(comp_ctx, "i32.const")) {
        WASMValue wasm_value = void;
        wasm_value.i32 = offset;
        offset_const = aot_load_const_from_table(
            comp_ctx, func_ctx.native_symbol, &wasm_value, VALUE_TYPE_I32);
        if (!offset_const) {
            return null;
        }
    }
    else {
        CHECK_LLVM_CONST(offset_const);
    }

    /* Get memory base address and memory data size */
    if (func_ctx.mem_space_unchanged
#if WASM_ENABLE_SHARED_MEMORY != 0
        || is_shared_memory
#endif
    ) {
        mem_base_addr = func_ctx.mem_info[0].mem_base_addr;
    }
    else {
        if (((mem_base_addr = LLVMBuildLoad2(
                  comp_ctx.builder, OPQ_PTR_TYPE,
                  func_ctx.mem_info[0].mem_base_addr, "mem_base")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            goto fail;
        }
    }

    aot_value_top =
        func_ctx.block_stack.block_list_end.value_stack.value_list_end;
    if (aot_value_top) {
        /* aot_value_top is freed in the following POP_I32(addr),
           so save its fields here for further use */
        is_local_of_aot_value = aot_value_top.is_local;
        local_idx_of_aot_value = aot_value_top.local_idx;
    }

    POP_I32(addr);

    /*
     * Note: not throw the integer-overflow-exception here since it must
     * have been thrown when converting float to integer before
     */
    /* return addres directly if constant offset and inside memory space */
    if (LLVMIsConstant(addr) && !LLVMIsUndef(addr)
#if LLVM_VERSION_NUMBER >= 12
        && !LLVMIsPoison(addr)
}
    ) {
        ulong mem_offset = cast(ulong)LLVMConstIntGetZExtValue(addr) + cast(ulong)offset;
        uint num_bytes_per_page = comp_ctx.comp_data.memories[0].num_bytes_per_page;
        uint init_page_count = comp_ctx.comp_data.memories[0].mem_init_page_count;
        ulong mem_data_size = cast(ulong)num_bytes_per_page * init_page_count;

        if (mem_offset + bytes <= mem_data_size) {
            /* inside memory space */
            offset1 = I32_CONST(cast(uint)mem_offset);
            CHECK_LLVM_CONST(offset1);
            if (((maddr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                                mem_base_addr, &offset1, 1,
                                                "maddr")) == 0)) {
                aot_set_last_error("llvm build add failed.");
                goto fail;
            }
            return maddr;
        }
    }

    if (is_target_64bit) {
        if (((offset_const = LLVMBuildZExt(comp_ctx.builder, offset_const,
                                           I64_TYPE, "offset_i64")) == 0)
            || ((addr = LLVMBuildZExt(comp_ctx.builder, addr, I64_TYPE,
                                      "addr_i64")) == 0)) {
            aot_set_last_error("llvm build zero extend failed.");
            goto fail;
        }
    }

    /* offset1 = offset + addr; */
    BUILD_OP(Add, offset_const, addr, offset1, "offset1");

    if (comp_ctx.enable_bound_check
        && !(is_local_of_aot_value
             && aot_checked_addr_list_find(func_ctx, local_idx_of_aot_value,
                                           offset, bytes))) {
        uint init_page_count = comp_ctx.comp_data.memories[0].mem_init_page_count;
        if (init_page_count == 0) {
            LLVMValueRef mem_size = void;

            if (((mem_size = get_memory_curr_page_count(comp_ctx, func_ctx)) == 0)) {
                goto fail;
            }
            BUILD_ICMP(LLVMIntEQ, mem_size, I32_ZERO, cmp, "is_zero");
            ADD_BASIC_BLOCK(check_succ, "check_mem_size_succ");
            LLVMMoveBasicBlockAfter(check_succ, block_curr);
            if (!aot_emit_exception(comp_ctx, func_ctx,
                                    EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, true, cmp,
                                    check_succ)) {
                goto fail;
            }

            SET_BUILD_POS(check_succ);
            block_curr = check_succ;
        }

        if (((mem_check_bound =
                  get_memory_check_bound(comp_ctx, func_ctx, bytes)) == 0)) {
            goto fail;
        }

        if (is_target_64bit) {
            BUILD_ICMP(LLVMIntUGT, offset1, mem_check_bound, cmp, "cmp");
        }
        else {
            /* Check integer overflow */
            BUILD_ICMP(LLVMIntULT, offset1, addr, cmp1, "cmp1");
            BUILD_ICMP(LLVMIntUGT, offset1, mem_check_bound, cmp2, "cmp2");
            BUILD_OP(Or, cmp1, cmp2, cmp, "cmp");
        }

        /* Add basic blocks */
        ADD_BASIC_BLOCK(check_succ, "check_succ");
        LLVMMoveBasicBlockAfter(check_succ, block_curr);

        if (!aot_emit_exception(comp_ctx, func_ctx,
                                EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, true, cmp,
                                check_succ)) {
            goto fail;
        }

        SET_BUILD_POS(check_succ);

        if (is_local_of_aot_value) {
            if (!aot_checked_addr_list_add(func_ctx, local_idx_of_aot_value,
                                           offset, bytes))
                goto fail;
        }
    }

    /* maddr = mem_base_addr + offset1 */
    if (((maddr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                        mem_base_addr, &offset1, 1, "maddr")) == 0)) {
        aot_set_last_error("llvm build add failed.");
        goto fail;
    }
    return maddr;
fail:
    return null;
}

enum string BUILD_PTR_CAST(string ptr_type) = `                                           \
    do {                                                                   \
        if (!(maddr = LLVMBuildBitCast(comp_ctx->builder, maddr, ptr_type, \
                                       "data_ptr"))) {                     \
            aot_set_last_error("llvm build bit cast failed.");             \
            goto fail;                                                     \
        }                                                                  \
    } while (0)`;

enum string BUILD_LOAD(string data_type) = `                                             \
    do {                                                                  \
        if (!(value = LLVMBuildLoad2(comp_ctx->builder, data_type, maddr, \
                                     "data"))) {                          \
            aot_set_last_error("llvm build load failed.");                \
            goto fail;                                                    \
        }                                                                 \
        LLVMSetAlignment(value, 1);                                       \
    } while (0)`;

enum string BUILD_TRUNC(string value, string data_type) = `                                     \
    do {                                                                  \
        if (!(value = LLVMBuildTrunc(comp_ctx->builder, value, data_type, \
                                     "val_trunc"))) {                     \
            aot_set_last_error("llvm build trunc failed.");               \
            goto fail;                                                    \
        }                                                                 \
    } while (0)`;

enum string BUILD_STORE() = `                                                   \
    do {                                                                \
        LLVMValueRef res;                                               \
        if (!(res = LLVMBuildStore(comp_ctx->builder, value, maddr))) { \
            aot_set_last_error("llvm build store failed.");             \
            goto fail;                                                  \
        }                                                               \
        LLVMSetAlignment(res, 1);                                       \
    } while (0)`;

enum string BUILD_SIGN_EXT(string dst_type) = `                                        \
    do {                                                                \
        if (!(value = LLVMBuildSExt(comp_ctx->builder, value, dst_type, \
                                    "data_s_ext"))) {                   \
            aot_set_last_error("llvm build sign ext failed.");          \
            goto fail;                                                  \
        }                                                               \
    } while (0)`;

enum string BUILD_ZERO_EXT(string dst_type) = `                                        \
    do {                                                                \
        if (!(value = LLVMBuildZExt(comp_ctx->builder, value, dst_type, \
                                    "data_z_ext"))) {                   \
            aot_set_last_error("llvm build zero ext failed.");          \
            goto fail;                                                  \
        }                                                               \
    } while (0)`;

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
bool check_memory_alignment(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMValueRef addr, uint align_) {
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMBasicBlockRef check_align_succ = void;
    LLVMValueRef align_mask = I32_CONST((cast(uint)1 << align_) - 1);
    LLVMValueRef res = void;

    CHECK_LLVM_CONST(align_mask);

    /* Convert pointer to int */
    if (((addr = LLVMBuildPtrToInt(comp_ctx.builder, addr, I32_TYPE,
                                   "address")) == 0)) {
        aot_set_last_error("llvm build ptr to int failed.");
        goto fail;
    }

    /* The memory address should be aligned */
    BUILD_OP(And, addr, align_mask, res, "and");
    BUILD_ICMP(LLVMIntNE, res, I32_ZERO, res, "cmp");

    /* Add basic blocks */
    ADD_BASIC_BLOCK(check_align_succ, "check_align_succ");
    LLVMMoveBasicBlockAfter(check_align_succ, block_curr);

    if (!aot_emit_exception(comp_ctx, func_ctx, EXCE_UNALIGNED_ATOMIC, true,
                            res, check_align_succ)) {
        goto fail;
    }

    SET_BUILD_POS(check_align_succ);

    return true;
fail:
    return false;
}

enum string BUILD_ATOMIC_LOAD(string align_, string data_type) = `                                \
    do {                                                                   \
        if (!(check_memory_alignment(comp_ctx, func_ctx, maddr, align))) { \
            goto fail;                                                     \
        }                                                                  \
        if (!(value = LLVMBuildLoad2(comp_ctx->builder, data_type, maddr,  \
                                     "data"))) {                           \
            aot_set_last_error("llvm build load failed.");                 \
            goto fail;                                                     \
        }                                                                  \
        LLVMSetAlignment(value, 1 << align);                               \
        LLVMSetVolatile(value, true);                                      \
        LLVMSetOrdering(value, LLVMAtomicOrderingSequentiallyConsistent);  \
    } while (0)`;

enum string BUILD_ATOMIC_STORE(string align_) = `                                          \
    do {                                                                   \
        LLVMValueRef res;                                                  \
        if (!(check_memory_alignment(comp_ctx, func_ctx, maddr, align))) { \
            goto fail;                                                     \
        }                                                                  \
        if (!(res = LLVMBuildStore(comp_ctx->builder, value, maddr))) {    \
            aot_set_last_error("llvm build store failed.");                \
            goto fail;                                                     \
        }                                                                  \
        LLVMSetAlignment(res, 1 << align);                                 \
        LLVMSetVolatile(res, true);                                        \
        LLVMSetOrdering(res, LLVMAtomicOrderingSequentiallyConsistent);    \
    } while (0)`;
}

bool aot_compile_op_i32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic) {
    LLVMValueRef maddr = void, value = null;
    LLVMTypeRef data_type = void;

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    switch (bytes) {
        case 4:
            BUILD_PTR_CAST(INT32_PTR_TYPE);
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            if (atomic)
                BUILD_ATOMIC_LOAD(align_, I32_TYPE);
            else
}
                BUILD_LOAD(I32_TYPE);
            break;
        case 2:
        case 1:
            if (bytes == 2) {
                BUILD_PTR_CAST(INT16_PTR_TYPE);
                data_type = INT16_TYPE;
            }
            else {
                BUILD_PTR_CAST(INT8_PTR_TYPE);
                data_type = INT8_TYPE;
            }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            if (atomic) {
                BUILD_ATOMIC_LOAD(align_, data_type);
                BUILD_ZERO_EXT(I32_TYPE);
            }
            else
}
            {
                BUILD_LOAD(data_type);
                if (sign)
                    BUILD_SIGN_EXT(I32_TYPE);
                else
                    BUILD_ZERO_EXT(I32_TYPE);
            }
            break;
        default:
            bh_assert(0);
            break;
    }

    PUSH_I32(value);
    cast(void)data_type;
    return true;
fail:
    return false;
}

bool aot_compile_op_i64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic) {
    LLVMValueRef maddr = void, value = null;
    LLVMTypeRef data_type = void;

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    switch (bytes) {
        case 8:
            BUILD_PTR_CAST(INT64_PTR_TYPE);
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            if (atomic)
                BUILD_ATOMIC_LOAD(align_, I64_TYPE);
            else
}
                BUILD_LOAD(I64_TYPE);
            break;
        case 4:
        case 2:
        case 1:
            if (bytes == 4) {
                BUILD_PTR_CAST(INT32_PTR_TYPE);
                data_type = I32_TYPE;
            }
            else if (bytes == 2) {
                BUILD_PTR_CAST(INT16_PTR_TYPE);
                data_type = INT16_TYPE;
            }
            else {
                BUILD_PTR_CAST(INT8_PTR_TYPE);
                data_type = INT8_TYPE;
            }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            if (atomic) {
                BUILD_ATOMIC_LOAD(align_, data_type);
                BUILD_ZERO_EXT(I64_TYPE);
            }
            else
}
            {
                BUILD_LOAD(data_type);
                if (sign)
                    BUILD_SIGN_EXT(I64_TYPE);
                else
                    BUILD_ZERO_EXT(I64_TYPE);
            }
            break;
        default:
            bh_assert(0);
            break;
    }

    PUSH_I64(value);
    cast(void)data_type;
    return true;
fail:
    return false;
}

bool aot_compile_op_f32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 4)) == 0))
        return false;

    BUILD_PTR_CAST(F32_PTR_TYPE);
    BUILD_LOAD(F32_TYPE);
    PUSH_F32(value);
    return true;
fail:
    return false;
}

bool aot_compile_op_f64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 8)) == 0))
        return false;

    BUILD_PTR_CAST(F64_PTR_TYPE);
    BUILD_LOAD(F64_TYPE);
    PUSH_F64(value);
    return true;
fail:
    return false;
}

bool aot_compile_op_i32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic) {
    LLVMValueRef maddr = void, value = void;

    POP_I32(value);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    switch (bytes) {
        case 4:
            BUILD_PTR_CAST(INT32_PTR_TYPE);
            break;
        case 2:
            BUILD_PTR_CAST(INT16_PTR_TYPE);
            BUILD_TRUNC(value, INT16_TYPE);
            break;
        case 1:
            BUILD_PTR_CAST(INT8_PTR_TYPE);
            BUILD_TRUNC(value, INT8_TYPE);
            break;
        default:
            bh_assert(0);
            break;
    }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (atomic)
        BUILD_ATOMIC_STORE(align_);
    else
}
        BUILD_STORE();
    return true;
fail:
    return false;
}

bool aot_compile_op_i64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic) {
    LLVMValueRef maddr = void, value = void;

    POP_I64(value);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    switch (bytes) {
        case 8:
            BUILD_PTR_CAST(INT64_PTR_TYPE);
            break;
        case 4:
            BUILD_PTR_CAST(INT32_PTR_TYPE);
            BUILD_TRUNC(value, I32_TYPE);
            break;
        case 2:
            BUILD_PTR_CAST(INT16_PTR_TYPE);
            BUILD_TRUNC(value, INT16_TYPE);
            break;
        case 1:
            BUILD_PTR_CAST(INT8_PTR_TYPE);
            BUILD_TRUNC(value, INT8_TYPE);
            break;
        default:
            bh_assert(0);
            break;
    }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    if (atomic)
        BUILD_ATOMIC_STORE(align_);
    else
}
        BUILD_STORE();
    return true;
fail:
    return false;
}

bool aot_compile_op_f32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;

    POP_F32(value);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 4)) == 0))
        return false;

    BUILD_PTR_CAST(F32_PTR_TYPE);
    BUILD_STORE();
    return true;
fail:
    return false;
}

bool aot_compile_op_f64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset) {
    LLVMValueRef maddr = void, value = void;

    POP_F64(value);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, 8)) == 0))
        return false;

    BUILD_PTR_CAST(F64_PTR_TYPE);
    BUILD_STORE();
    return true;
fail:
    return false;
}

private LLVMValueRef get_memory_curr_page_count(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef mem_size = void;

    if (func_ctx.mem_space_unchanged) {
        mem_size = func_ctx.mem_info[0].mem_cur_page_count_addr;
    }
    else {
        if (((mem_size = LLVMBuildLoad2(
                  comp_ctx.builder, I32_TYPE,
                  func_ctx.mem_info[0].mem_cur_page_count_addr, "mem_size")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            goto fail;
        }
    }

    return mem_size;
fail:
    return null;
}

bool aot_compile_op_memory_size(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef mem_size = get_memory_curr_page_count(comp_ctx, func_ctx);

    if (mem_size)
        PUSH_I32(mem_size);
    return mem_size ? true : false;
fail:
    return false;
}

bool aot_compile_op_memory_grow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef mem_size = get_memory_curr_page_count(comp_ctx, func_ctx);
    LLVMValueRef delta = void; LLVMValueRef[2] param_values = void; LLVMValueRef ret_value = void, func = void, value = void;
    LLVMTypeRef[2] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    int func_index = void;

    if (!mem_size)
        return false;

    POP_I32(delta);

    /* Function type of aot_enlarge_memory() */
    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    ret_type = INT8_TYPE;

    if (((func_type = LLVMFunctionType(ret_type, param_types.ptr, 2, false)) == 0)) {
        aot_set_last_error("llvm add function type failed.");
        return false;
    }

    if (comp_ctx.is_jit_mode) {
        /* JIT mode, call the function directly */
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("llvm add pointer type failed.");
            return false;
        }
        if (((value = I64_CONST(cast(ulong)cast(uintptr_t)wasm_enlarge_memory)) == 0)
            || ((func = LLVMConstIntToPtr(value, func_ptr_type)) == 0)) {
            aot_set_last_error("create LLVM value failed.");
            return false;
        }
    }
    else if (comp_ctx.is_indirect_mode) {
        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }
        func_index =
            aot_get_native_symbol_index(comp_ctx, "aot_enlarge_memory");
        if (func_index < 0) {
            return false;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_ptr_type, func_index)) == 0)) {
            return false;
        }
    }
    else {
        char* func_name = "aot_enlarge_memory";
        /* AOT mode, delcare the function */
        if (((func = LLVMGetNamedFunction(func_ctx.module_, func_name)) == 0)
            && ((func =
                     LLVMAddFunction(func_ctx.module_, func_name, func_type)) == 0)) {
            aot_set_last_error("llvm add function failed.");
            return false;
        }
    }

    /* Call function aot_enlarge_memory() */
    param_values[0] = func_ctx.aot_inst;
    param_values[1] = delta;
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 2, "call")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }

    BUILD_ICMP(LLVMIntUGT, ret_value, I8_ZERO, ret_value, "mem_grow_ret");

    /* ret_value = ret_value == true ? delta : pre_page_count */
    if (((ret_value = LLVMBuildSelect(comp_ctx.builder, ret_value, mem_size,
                                      I32_NEG_ONE, "mem_grow_ret")) == 0)) {
        aot_set_last_error("llvm build select failed.");
        return false;
    }

    PUSH_I32(ret_value);
    return true;
fail:
    return false;
}

#if WASM_ENABLE_BULK_MEMORY != 0

static LLVMValueRef
check_bulk_memory_overflow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx,
                           LLVMValueRef offset, LLVMValueRef bytes)
{
    LLVMValueRef maddr, max_addr, cmp;
    LLVMValueRef mem_base_addr;
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMBasicBlockRef check_succ;
    LLVMValueRef mem_size;

    /* Get memory base address and memory data size */
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    bool is_shared_memory = comp_ctx.comp_data.memories[0].memory_flags & 0x02;

    if (func_ctx.mem_space_unchanged || is_shared_memory) {
//! #else
    if (func_ctx->mem_space_unchanged) {
//! #endif
        mem_base_addr = func_ctx->mem_info[0].mem_base_addr;
    }
    else {
        if (((mem_base_addr = LLVMBuildLoad2(
                  comp_ctx.builder, OPQ_PTR_TYPE,
                  func_ctx.mem_info[0].mem_base_addr, "mem_base")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            goto fail;
        }
    }

    /*
     * Note: not throw the integer-overflow-exception here since it must
     * have been thrown when converting float to integer before
     */
    /* return addres directly if constant offset and inside memory space */
    if (!LLVMIsUndef(offset) && !LLVMIsUndef(bytes)
#if LLVM_VERSION_NUMBER >= 12
        && !LLVMIsPoison(offset) && !LLVMIsPoison(bytes)
}
        && LLVMIsConstant(offset) && LLVMIsConstant(bytes)) {
        ulong mem_offset = cast(ulong)LLVMConstIntGetZExtValue(offset);
        ulong mem_len = cast(ulong)LLVMConstIntGetZExtValue(bytes);
        uint num_bytes_per_page = comp_ctx.comp_data.memories[0].num_bytes_per_page;
        uint init_page_count = comp_ctx.comp_data.memories[0].mem_init_page_count;
        uint mem_data_size = num_bytes_per_page * init_page_count;
        if (mem_data_size > 0 && mem_offset + mem_len <= mem_data_size) {
            /* inside memory space */
            /* maddr = mem_base_addr + moffset */
            if (((maddr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                                mem_base_addr, &offset, 1,
                                                "maddr")) == 0)) {
                aot_set_last_error("llvm build add failed.");
                goto fail;
            }
            return maddr;
        }
    }

    if (func_ctx.mem_space_unchanged) {
        mem_size = func_ctx.mem_info[0].mem_data_size_addr;
    }
    else {
        if (((mem_size = LLVMBuildLoad2(
                  comp_ctx.builder, I32_TYPE,
                  func_ctx.mem_info[0].mem_data_size_addr, "mem_size")) == 0)) {
            aot_set_last_error("llvm build load failed.");
            goto fail;
        }
    }

    ADD_BASIC_BLOCK(check_succ, "check_succ");
    LLVMMoveBasicBlockAfter(check_succ, block_curr);

    offset =
        LLVMBuildZExt(comp_ctx.builder, offset, I64_TYPE, "extend_offset");
    bytes = LLVMBuildZExt(comp_ctx.builder, bytes, I64_TYPE, "extend_len");
    mem_size =
        LLVMBuildZExt(comp_ctx.builder, mem_size, I64_TYPE, "extend_size");

    BUILD_OP(Add, offset, bytes, max_addr, "max_addr");
    BUILD_ICMP(LLVMIntUGT, max_addr, mem_size, cmp, "cmp_max_mem_addr");
    if (!aot_emit_exception(comp_ctx, func_ctx,
                            EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, true, cmp,
                            check_succ)) {
        goto fail;
    }

    /* maddr = mem_base_addr + offset */
    if (((maddr = LLVMBuildInBoundsGEP2(comp_ctx.builder, INT8_TYPE,
                                        mem_base_addr, &offset, 1, "maddr")) == 0)) {
        aot_set_last_error("llvm build add failed.");
        goto fail;
    }
    return maddr;
fail:
    return null;
}

bool aot_compile_op_memory_init(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint seg_index) {
    LLVMValueRef seg = void, offset = void, dst = void, len = void; LLVMValueRef[5] param_values = void; LLVMValueRef ret_value = void, func = void, value = void;
    LLVMTypeRef[5] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    AOTFuncType* aot_func_type = func_ctx.aot_func.func_type;
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    LLVMBasicBlockRef mem_init_fail = void, init_success = void;

    seg = I32_CONST(seg_index);

    POP_I32(len);
    POP_I32(offset);
    POP_I32(dst);

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    param_types[2] = I32_TYPE;
    param_types[3] = I32_TYPE;
    param_types[4] = I32_TYPE;
    ret_type = INT8_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_memory_init, 5);
    else
        GET_AOT_FUNCTION(aot_memory_init, 5);

    /* Call function aot_memory_init() */
    param_values[0] = func_ctx.aot_inst;
    param_values[1] = seg;
    param_values[2] = offset;
    param_values[3] = len;
    param_values[4] = dst;
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 5, "call")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }

    BUILD_ICMP(LLVMIntUGT, ret_value, I8_ZERO, ret_value, "mem_init_ret");

    ADD_BASIC_BLOCK(mem_init_fail, "mem_init_fail");
    ADD_BASIC_BLOCK(init_success, "init_success");

    LLVMMoveBasicBlockAfter(mem_init_fail, block_curr);
    LLVMMoveBasicBlockAfter(init_success, block_curr);

    if (!LLVMBuildCondBr(comp_ctx.builder, ret_value, init_success,
                         mem_init_fail)) {
        aot_set_last_error("llvm build cond br failed.");
        goto fail;
    }

    /* If memory.init failed, return this function
       so the runtime can catch the exception */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, mem_init_fail);
    if (!aot_build_zero_function_ret(comp_ctx, func_ctx, aot_func_type)) {
        goto fail;
    }

    LLVMPositionBuilderAtEnd(comp_ctx.builder, init_success);

    return true;
fail:
    return false;
}

bool aot_compile_op_data_drop(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint seg_index) {
    LLVMValueRef seg = void; LLVMValueRef[2] param_values = void; LLVMValueRef ret_value = void, func = void, value = void;
    LLVMTypeRef[2] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;

    seg = I32_CONST(seg_index);
    CHECK_LLVM_CONST(seg);

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    ret_type = INT8_TYPE;

    if (comp_ctx.is_jit_mode)
        GET_AOT_FUNCTION(llvm_jit_data_drop, 2);
    else
        GET_AOT_FUNCTION(aot_data_drop, 2);

    /* Call function aot_data_drop() */
    param_values[0] = func_ctx.aot_inst;
    param_values[1] = seg;
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 2, "call")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_memory_copy(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef src = void, dst = void, src_addr = void, dst_addr = void, len = void, res = void;
    bool call_aot_memmove = false;

    POP_I32(len);
    POP_I32(src);
    POP_I32(dst);

    if (((src_addr = check_bulk_memory_overflow(comp_ctx, func_ctx, src, len)) == 0))
        return false;

    if (((dst_addr = check_bulk_memory_overflow(comp_ctx, func_ctx, dst, len)) == 0))
        return false;

    call_aot_memmove = comp_ctx.is_indirect_mode || comp_ctx.is_jit_mode;
    if (call_aot_memmove) {
        LLVMTypeRef[3] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
        LLVMValueRef func = void; LLVMValueRef[3] params = void;

        param_types[0] = INT8_PTR_TYPE;
        param_types[1] = INT8_PTR_TYPE;
        param_types[2] = I32_TYPE;
        ret_type = INT8_PTR_TYPE;

        if (((func_type = LLVMFunctionType(ret_type, param_types.ptr, 3, false)) == 0)) {
            aot_set_last_error("create LLVM function type failed.");
            return false;
        }

        if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error("create LLVM function pointer type failed.");
            return false;
        }

        if (comp_ctx.is_jit_mode) {
            if (((func = I64_CONST(cast(ulong)cast(uintptr_t)aot_memmove)) == 0)
                || ((func = LLVMConstIntToPtr(func, func_ptr_type)) == 0)) {
                aot_set_last_error("create LLVM value failed.");
                return false;
            }
        }
        else {
            int func_index = void;
            func_index = aot_get_native_symbol_index(comp_ctx, "memmove");
            if (func_index < 0) {
                return false;
            }
            if (((func =
                      aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                              func_ptr_type, func_index)) == 0)) {
                return false;
            }
        }

        params[0] = dst_addr;
        params[1] = src_addr;
        params[2] = len;
        if (((res = LLVMBuildCall2(comp_ctx.builder, func_type, func, params.ptr,
                                   3, "call_memmove")) == 0)) {
            aot_set_last_error("llvm build memmove failed.");
            return false;
        }
    }
    else {
        if (((res = LLVMBuildMemMove(comp_ctx.builder, dst_addr, 1, src_addr,
                                     1, len)) == 0)) {
            aot_set_last_error("llvm build memmove failed.");
            return false;
        }
    }

    return true;
fail:
    return false;
}

private void* jit_memset(void* s, int c, size_t n) {
    return memset(s, c, n);
}

bool aot_compile_op_memory_fill(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef val = void, dst = void, dst_addr = void, len = void, res = void;
    LLVMTypeRef[3] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMValueRef func = void; LLVMValueRef[3] params = void;

    POP_I32(len);
    POP_I32(val);
    POP_I32(dst);

    if (((dst_addr = check_bulk_memory_overflow(comp_ctx, func_ctx, dst, len)) == 0))
        return false;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = I32_TYPE;
    param_types[2] = I32_TYPE;
    ret_type = INT8_PTR_TYPE;

    if (((func_type = LLVMFunctionType(ret_type, param_types.ptr, 3, false)) == 0)) {
        aot_set_last_error("create LLVM function type failed.");
        return false;
    }

    if (((func_ptr_type = LLVMPointerType(func_type, 0)) == 0)) {
        aot_set_last_error("create LLVM function pointer type failed.");
        return false;
    }

    if (comp_ctx.is_jit_mode) {
        if (((func = I64_CONST(cast(ulong)cast(uintptr_t)jit_memset)) == 0)
            || ((func = LLVMConstIntToPtr(func, func_ptr_type)) == 0)) {
            aot_set_last_error("create LLVM value failed.");
            return false;
        }
    }
    else if (comp_ctx.is_indirect_mode) {
        int func_index = void;
        func_index = aot_get_native_symbol_index(comp_ctx, "memset");
        if (func_index < 0) {
            return false;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_ptr_type, func_index)) == 0)) {
            return false;
        }
    }
    else {
        if (((func = LLVMGetNamedFunction(func_ctx.module_, "memset")) == 0)
            && ((func =
                     LLVMAddFunction(func_ctx.module_, "memset", func_type)) == 0)) {
            aot_set_last_error("llvm add function failed.");
            return false;
        }
    }

    params[0] = dst_addr;
    params[1] = val;
    params[2] = len;
    if (((res = LLVMBuildCall2(comp_ctx.builder, func_type, func, params.ptr, 3,
                               "call_memset")) == 0)) {
        aot_set_last_error("llvm build memset failed.");
        return false;
    }

    return true;
fail:
    return false;
}
} /* end of WASM_ENABLE_BULK_MEMORY */

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
bool aot_compile_op_atomic_rmw(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte atomic_op, ubyte op_type, uint align_, uint offset, uint bytes) {
    LLVMValueRef maddr = void, value = void, result = void;

    if (op_type == VALUE_TYPE_I32)
        POP_I32(value);
    else
        POP_I64(value);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    if (!check_memory_alignment(comp_ctx, func_ctx, maddr, align_))
        return false;

    switch (bytes) {
        case 8:
            BUILD_PTR_CAST(INT64_PTR_TYPE);
            break;
        case 4:
            BUILD_PTR_CAST(INT32_PTR_TYPE);
            if (op_type == VALUE_TYPE_I64)
                BUILD_TRUNC(value, I32_TYPE);
            break;
        case 2:
            BUILD_PTR_CAST(INT16_PTR_TYPE);
            BUILD_TRUNC(value, INT16_TYPE);
            break;
        case 1:
            BUILD_PTR_CAST(INT8_PTR_TYPE);
            BUILD_TRUNC(value, INT8_TYPE);
            break;
        default:
            bh_assert(0);
            break;
    }

    if (((result = LLVMBuildAtomicRMW(
              comp_ctx.builder, atomic_op, maddr, value,
              LLVMAtomicOrderingSequentiallyConsistent, false)) == 0)) {
        goto fail;
    }

    LLVMSetVolatile(result, true);

    if (op_type == VALUE_TYPE_I32) {
        if (((result = LLVMBuildZExt(comp_ctx.builder, result, I32_TYPE,
                                     "result_i32")) == 0)) {
            goto fail;
        }
        PUSH_I32(result);
    }
    else {
        if (((result = LLVMBuildZExt(comp_ctx.builder, result, I64_TYPE,
                                     "result_i64")) == 0)) {
            goto fail;
        }
        PUSH_I64(result);
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_atomic_cmpxchg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte op_type, uint align_, uint offset, uint bytes) {
    LLVMValueRef maddr = void, value = void, expect = void, result = void;

    if (op_type == VALUE_TYPE_I32) {
        POP_I32(value);
        POP_I32(expect);
    }
    else {
        POP_I64(value);
        POP_I64(expect);
    }

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    if (!check_memory_alignment(comp_ctx, func_ctx, maddr, align_))
        return false;

    switch (bytes) {
        case 8:
            BUILD_PTR_CAST(INT64_PTR_TYPE);
            break;
        case 4:
            BUILD_PTR_CAST(INT32_PTR_TYPE);
            if (op_type == VALUE_TYPE_I64) {
                BUILD_TRUNC(value, I32_TYPE);
                BUILD_TRUNC(expect, I32_TYPE);
            }
            break;
        case 2:
            BUILD_PTR_CAST(INT16_PTR_TYPE);
            BUILD_TRUNC(value, INT16_TYPE);
            BUILD_TRUNC(expect, INT16_TYPE);
            break;
        case 1:
            BUILD_PTR_CAST(INT8_PTR_TYPE);
            BUILD_TRUNC(value, INT8_TYPE);
            BUILD_TRUNC(expect, INT8_TYPE);
            break;
        default:
            bh_assert(0);
            break;
    }

    if (((result = LLVMBuildAtomicCmpXchg(
              comp_ctx.builder, maddr, expect, value,
              LLVMAtomicOrderingSequentiallyConsistent,
              LLVMAtomicOrderingSequentiallyConsistent, false)) == 0)) {
        goto fail;
    }

    LLVMSetVolatile(result, true);

    /* CmpXchg return {i32, i1} structure,
       we need to extrack the previous_value from the structure */
    if (((result = LLVMBuildExtractValue(comp_ctx.builder, result, 0,
                                         "previous_value")) == 0)) {
        goto fail;
    }

    if (op_type == VALUE_TYPE_I32) {
        if (LLVMTypeOf(result) != I32_TYPE) {
            if (((result = LLVMBuildZExt(comp_ctx.builder, result, I32_TYPE,
                                         "result_i32")) == 0)) {
                goto fail;
            }
        }
        PUSH_I32(result);
    }
    else {
        if (LLVMTypeOf(result) != I64_TYPE) {
            if (((result = LLVMBuildZExt(comp_ctx.builder, result, I64_TYPE,
                                         "result_i64")) == 0)) {
                goto fail;
            }
        }
        PUSH_I64(result);
    }

    return true;
fail:
    return false;
}

bool aot_compile_op_atomic_wait(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte op_type, uint align_, uint offset, uint bytes) {
    LLVMValueRef maddr = void, value = void, timeout = void, expect = void, cmp = void;
    LLVMValueRef[5] param_values = void; LLVMValueRef ret_value = void, func = void, is_wait64 = void;
    LLVMTypeRef[5] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;
    LLVMBasicBlockRef wait_fail = void, wait_success = void;
    LLVMBasicBlockRef block_curr = LLVMGetInsertBlock(comp_ctx.builder);
    AOTFuncType* aot_func_type = func_ctx.aot_func.func_type;

    POP_I64(timeout);
    if (op_type == VALUE_TYPE_I32) {
        POP_I32(expect);
        is_wait64 = I8_CONST(false);
        if (((expect = LLVMBuildZExt(comp_ctx.builder, expect, I64_TYPE,
                                     "expect_i64")) == 0)) {
            goto fail;
        }
    }
    else {
        POP_I64(expect);
        is_wait64 = I8_CONST(true);
    }

    CHECK_LLVM_CONST(is_wait64);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    if (!check_memory_alignment(comp_ctx, func_ctx, maddr, align_))
        return false;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = INT8_PTR_TYPE;
    param_types[2] = I64_TYPE;
    param_types[3] = I64_TYPE;
    param_types[4] = INT8_TYPE;
    ret_type = I32_TYPE;

    GET_AOT_FUNCTION(wasm_runtime_atomic_wait, 5);

    /* Call function wasm_runtime_atomic_wait() */
    param_values[0] = func_ctx.aot_inst;
    param_values[1] = maddr;
    param_values[2] = expect;
    param_values[3] = timeout;
    param_values[4] = is_wait64;
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 5, "call")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }

    BUILD_ICMP(LLVMIntSGT, ret_value, I32_ZERO, cmp, "atomic_wait_ret");

    ADD_BASIC_BLOCK(wait_fail, "atomic_wait_fail");
    ADD_BASIC_BLOCK(wait_success, "wait_success");

    LLVMMoveBasicBlockAfter(wait_fail, block_curr);
    LLVMMoveBasicBlockAfter(wait_success, block_curr);

    if (!LLVMBuildCondBr(comp_ctx.builder, cmp, wait_success, wait_fail)) {
        aot_set_last_error("llvm build cond br failed.");
        goto fail;
    }

    /* If atomic wait failed, return this function
       so the runtime can catch the exception */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, wait_fail);
    if (!aot_build_zero_function_ret(comp_ctx, func_ctx, aot_func_type)) {
        goto fail;
    }

    LLVMPositionBuilderAtEnd(comp_ctx.builder, wait_success);

    PUSH_I32(ret_value);

    return true;
fail:
    return false;
}

bool aot_compiler_op_atomic_notify(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes) {
    LLVMValueRef maddr = void, value = void, count = void;
    LLVMValueRef[3] param_values = void; LLVMValueRef ret_value = void, func = void;
    LLVMTypeRef[3] param_types = void; LLVMTypeRef ret_type = void, func_type = void, func_ptr_type = void;

    POP_I32(count);

    if (((maddr = aot_check_memory_overflow(comp_ctx, func_ctx, offset, bytes)) == 0))
        return false;

    if (!check_memory_alignment(comp_ctx, func_ctx, maddr, align_))
        return false;

    param_types[0] = INT8_PTR_TYPE;
    param_types[1] = INT8_PTR_TYPE;
    param_types[2] = I32_TYPE;
    ret_type = I32_TYPE;

    GET_AOT_FUNCTION(wasm_runtime_atomic_notify, 3);

    /* Call function wasm_runtime_atomic_notify() */
    param_values[0] = func_ctx.aot_inst;
    param_values[1] = maddr;
    param_values[2] = count;
    if (((ret_value = LLVMBuildCall2(comp_ctx.builder, func_type, func,
                                     param_values.ptr, 3, "call")) == 0)) {
        aot_set_last_error("llvm build call failed.");
        return false;
    }

    PUSH_I32(ret_value);

    return true;
fail:
    return false;
}

} /* end of WASM_ENABLE_SHARED_MEMORY */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _AOT_EMIT_MEMORY_H_
version = _AOT_EMIT_MEMORY_H_;

public import aot_compiler;
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
public import wasm_shared_memory;
}

#ifdef __cplusplus
extern "C" {
//! #endif

bool aot_compile_op_i32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic);

bool aot_compile_op_i64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool sign, bool atomic);

bool aot_compile_op_f32_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);

bool aot_compile_op_f64_load(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);

bool aot_compile_op_i32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic);

bool aot_compile_op_i64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes, bool atomic);

bool aot_compile_op_f32_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);

bool aot_compile_op_f64_store(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset);

LLVMValueRef aot_check_memory_overflow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint offset, uint bytes);

bool aot_compile_op_memory_size(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_op_memory_grow(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

static if (WASM_ENABLE_BULK_MEMORY != 0) {
bool aot_compile_op_memory_init(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint seg_index);

bool aot_compile_op_data_drop(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint seg_index);

bool aot_compile_op_memory_copy(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

bool aot_compile_op_memory_fill(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);
}

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
bool aot_compile_op_atomic_rmw(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte atomic_op, ubyte op_type, uint align_, uint offset, uint bytes);

bool aot_compile_op_atomic_cmpxchg(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte op_type, uint align_, uint offset, uint bytes);

bool aot_compile_op_atomic_wait(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ubyte op_type, uint align_, uint offset, uint bytes);

bool aot_compiler_op_atomic_notify(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, uint align_, uint offset, uint bytes);
}

version (none) {
} /* end of extern "C" */
}

//! #endif /* end of _AOT_EMIT_MEMORY_H_ */
