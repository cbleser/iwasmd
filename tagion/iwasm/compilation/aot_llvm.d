module aot_llvm_tmp;
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
import tagion.iwasm.compilation.aot;
import tagion.iwasm.llvm.llvm.Config.llvm_config;
import tagion.iwasm.llvm.llvm_c.Types;
import tagion.iwasm.llvm.llvm_c.Target;
import tagion.iwasm.llvm.llvm_c.Core;
import tagion.iwasm.llvm.llvm_c.Object;
import tagion.iwasm.llvm.llvm_c.ExecutionEngine;
import tagion.iwasm.llvm.llvm_c.Analysis;
import tagion.iwasm.llvm.llvm_c.BitWriter;
import tagion.iwasm.llvm.llvm_c.Transforms.Utils;
import tagion.iwasm.llvm.llvm_c.Transforms.Scalar;
import tagion.iwasm.llvm.llvm_c.Transforms.Vectorize;
import tagion.iwasm.llvm.llvm_c.Transforms.PassManagerBuilder;
import tagion.iwasm.llvm.llvm_c.Orc;
import tagion.iwasm.llvm.llvm_c.Error;
import tagion.iwasm.llvm.llvm_c.Support;
import tagion.iwasm.llvm.llvm_c.Initialization;
import tagion.iwasm.llvm.llvm_c.TargetMachine;
import tagion.iwasm.llvm.llvm_c.LLJIT;
import tagion.iwasm.compilation.aot_orc_extra;
// #define DEBUG_PASS
// #define DUMP_MODULE
/**
 * Value in the WASM operation stack, each stack element
 * is an LLVM value
 */
struct AOTValue {
    AOTValue* next;
    AOTValue* prev;
    LLVMValueRef value;
    /* VALUE_TYPE_I32/I64/F32/F64/VOID */
    ubyte type;
    bool is_local;
    uint local_idx;
}
/**
 * Value stack, represents stack elements in a WASM block
 */
struct AOTValueStack {
    AOTValue* value_list_head;
    AOTValue* value_list_end;
}
struct AOTBlock {
    AOTBlock* next;
    AOTBlock* prev;
    /* Block index */
    uint block_index;
    /* LABEL_TYPE_BLOCK/LOOP/IF/FUNCTION */
    uint label_type;
    /* Whether it is reachable */
    bool is_reachable;
    /* Whether skip translation of wasm else branch */
    bool skip_wasm_code_else;
    /* code of else opcode of this block, if it is a IF block  */
    ubyte* wasm_code_else;
    /* code end of this block */
    ubyte* wasm_code_end;
    /* LLVM label points to code begin */
    LLVMBasicBlockRef llvm_entry_block;
    /* LLVM label points to code else */
    LLVMBasicBlockRef llvm_else_block;
    /* LLVM label points to code end */
    LLVMBasicBlockRef llvm_end_block;
    /* WASM operation stack */
    AOTValueStack value_stack;
    /* Param count/types/PHIs of this block */
    uint param_count;
    ubyte* param_types;
    LLVMValueRef* param_phis;
    LLVMValueRef* else_param_phis;
    /* Result count/types/PHIs of this block */
    uint result_count;
    ubyte* result_types;
    LLVMValueRef* result_phis;
}
/**
 * Block stack, represents WASM block stack elements
 */
struct AOTBlockStack {
    AOTBlock* block_list_head;
    AOTBlock* block_list_end;
    /* Current block index of each block type */
    uint[3] block_index;
}
struct AOTCheckedAddr {
    AOTCheckedAddr* next;
    uint local_idx;
    uint offset;
    uint bytes;
}alias AOTCheckedAddrList = AOTCheckedAddr*;
struct AOTMemInfo {
    LLVMValueRef mem_base_addr;
    LLVMValueRef mem_data_size_addr;
    LLVMValueRef mem_cur_page_count_addr;
    LLVMValueRef mem_bound_check_1byte;
    LLVMValueRef mem_bound_check_2bytes;
    LLVMValueRef mem_bound_check_4bytes;
    LLVMValueRef mem_bound_check_8bytes;
    LLVMValueRef mem_bound_check_16bytes;
}
struct AOTFuncContext {
    AOTFunc* aot_func;
    LLVMValueRef func;
    LLVMTypeRef func_type;
    /* LLVM module for this function, note that in LAZY JIT mode,
       each aot function belongs to an individual module */
    LLVMModuleRef module_;
    AOTBlockStack block_stack;
    LLVMValueRef exec_env;
    LLVMValueRef aot_inst;
    LLVMValueRef argv_buf;
    LLVMValueRef native_stack_bound;
    LLVMValueRef aux_stack_bound;
    LLVMValueRef aux_stack_bottom;
    LLVMValueRef native_symbol;
    LLVMValueRef last_alloca;
    LLVMValueRef func_ptrs;
    AOTMemInfo* mem_info;
    LLVMValueRef cur_exception;
    bool mem_space_unchanged;
    AOTCheckedAddrList checked_addr_list;
    LLVMBasicBlockRef got_exception_block;
    LLVMBasicBlockRef func_return_block;
    LLVMValueRef exception_id_phi;
    LLVMValueRef func_type_indexes;
    LLVMValueRef[1] locals;
}
struct AOTLLVMTypes {
    LLVMTypeRef int1_type;
    LLVMTypeRef int8_type;
    LLVMTypeRef int16_type;
    LLVMTypeRef int32_type;
    LLVMTypeRef int64_type;
    LLVMTypeRef float32_type;
    LLVMTypeRef float64_type;
    LLVMTypeRef void_type;
    LLVMTypeRef int8_ptr_type;
    LLVMTypeRef int8_pptr_type;
    LLVMTypeRef int16_ptr_type;
    LLVMTypeRef int32_ptr_type;
    LLVMTypeRef int64_ptr_type;
    LLVMTypeRef float32_ptr_type;
    LLVMTypeRef float64_ptr_type;
    LLVMTypeRef v128_type;
    LLVMTypeRef v128_ptr_type;
    LLVMTypeRef i8x16_vec_type;
    LLVMTypeRef i16x8_vec_type;
    LLVMTypeRef i32x4_vec_type;
    LLVMTypeRef i64x2_vec_type;
    LLVMTypeRef f32x4_vec_type;
    LLVMTypeRef f64x2_vec_type;
    LLVMTypeRef i1x2_vec_type;
    LLVMTypeRef meta_data_type;
    LLVMTypeRef funcref_type;
    LLVMTypeRef externref_type;
}
struct AOTLLVMConsts {
    LLVMValueRef i1_zero;
    LLVMValueRef i1_one;
    LLVMValueRef i8_zero;
    LLVMValueRef i32_zero;
    LLVMValueRef i64_zero;
    LLVMValueRef f32_zero;
    LLVMValueRef f64_zero;
    LLVMValueRef i32_one;
    LLVMValueRef i32_two;
    LLVMValueRef i32_three;
    LLVMValueRef i32_four;
    LLVMValueRef i32_five;
    LLVMValueRef i32_six;
    LLVMValueRef i32_seven;
    LLVMValueRef i32_eight;
    LLVMValueRef i32_nine;
    LLVMValueRef i32_ten;
    LLVMValueRef i32_eleven;
    LLVMValueRef i32_twelve;
    LLVMValueRef i32_thirteen;
    LLVMValueRef i32_fourteen;
    LLVMValueRef i32_fifteen;
    LLVMValueRef i32_neg_one;
    LLVMValueRef i64_neg_one;
    LLVMValueRef i32_min;
    LLVMValueRef i64_min;
    LLVMValueRef i32_31;
    LLVMValueRef i32_32;
    LLVMValueRef i64_63;
    LLVMValueRef i64_64;
    LLVMValueRef i8x16_vec_zero;
    LLVMValueRef i16x8_vec_zero;
    LLVMValueRef i32x4_vec_zero;
    LLVMValueRef i64x2_vec_zero;
    LLVMValueRef f32x4_vec_zero;
    LLVMValueRef f64x2_vec_zero;
    LLVMValueRef i8x16_undef;
    LLVMValueRef i16x8_undef;
    LLVMValueRef i32x4_undef;
    LLVMValueRef i64x2_undef;
    LLVMValueRef f32x4_undef;
    LLVMValueRef f64x2_undef;
    LLVMValueRef i32x16_zero;
    LLVMValueRef i32x8_zero;
    LLVMValueRef i32x4_zero;
    LLVMValueRef i32x2_zero;
}
/**
 * Compiler context
 */
struct AOTCompContext {
    AOTCompData* comp_data;
    /* LLVM variables required to emit LLVM IR */
    LLVMContextRef context;
    LLVMBuilderRef builder;
    LLVMTargetMachineRef target_machine;
    char* target_cpu;
    char[16] target_arch = 0;
    uint pointer_size;
    /* Hardware intrinsic compability flags */
    ulong[8] flags;
    /* required by JIT */
    LLVMOrcLLLazyJITRef orc_jit;
    LLVMOrcThreadSafeContextRef orc_thread_safe_context;
    LLVMModuleRef module_;
    bool is_jit_mode;
    /* AOT indirect mode flag & symbol list */
    bool is_indirect_mode;
    bh_list native_symbols;
    /* Bulk memory feature */
    bool enable_bulk_memory;
    /* Bounday Check */
    bool enable_bound_check;
    /* Native stack bounday Check */
    bool enable_stack_bound_check;
    /* 128-bit SIMD */
    bool enable_simd;
    /* Auxiliary stack overflow/underflow check */
    bool enable_aux_stack_check;
    /* Generate auxiliary stack frame */
    bool enable_aux_stack_frame;
    /* Thread Manager */
    bool enable_thread_mgr;
    /* Tail Call */
    bool enable_tail_call;
    /* Reference Types */
    bool enable_ref_types;
    /* Disable LLVM built-in intrinsics */
    bool disable_llvm_intrinsics;
    /* Disable LLVM link time optimization */
    bool disable_llvm_lto;
    /* Whether optimize the JITed code */
    bool optimize;
    uint opt_level;
    uint size_level;
    /* LLVM floating-point rounding mode metadata */
    LLVMValueRef fp_rounding_mode;
    /* LLVM floating-point exception behavior metadata */
    LLVMValueRef fp_exception_behavior;
    /* LLVM data types */
    AOTLLVMTypes basic_types;
    LLVMTypeRef exec_env_type;
    LLVMTypeRef aot_inst_type;
    /* LLVM const values */
    AOTLLVMConsts llvm_consts;
    /* Function contexts */
    /* TODO: */
    AOTFuncContext** func_ctxes;
    uint func_ctx_count;
    char** custom_sections_wp;
    uint custom_sections_count;
    /* 3rd-party toolchains */
    /* External llc compiler, if specified, wamrc will emit the llvm-ir file and
     * invoke the llc compiler to generate object file.
     * This can be used when we want to benefit from the optimization of other
     * LLVM based toolchains */
    const(char)* external_llc_compiler;
    const(char)* llc_compiler_flags;
    /* External asm compiler, if specified, wamrc will emit the text-based
     * assembly file (.s) and invoke the llc compiler to generate object file.
     * This will be useful when the upstream LLVM doesn't support to emit object
     * file for some architecture (such as arc) */
    const(char)* external_asm_compiler;
    const(char)* asm_compiler_flags;
}
enum {
    AOT_FORMAT_FILE,
    AOT_OBJECT_FILE,
    AOT_LLVMIR_UNOPT_FILE,
    AOT_LLVMIR_OPT_FILE,
}
struct AOTCompOption {
    bool is_jit_mode;
    bool is_indirect_mode;
    char* target_arch;
    char* target_abi;
    char* target_cpu;
    char* cpu_features;
    bool is_sgx_platform;
    bool enable_bulk_memory;
    bool enable_thread_mgr;
    bool enable_tail_call;
    bool enable_simd;
    bool enable_ref_types;
    bool enable_aux_stack_check;
    bool enable_aux_stack_frame;
    bool disable_llvm_intrinsics;
    bool disable_llvm_lto;
    uint opt_level;
    uint size_level;
    uint output_format;
    uint bounds_checks;
    uint stack_bounds_checks;
    char** custom_sections;
    uint custom_sections_count;
}alias aot_comp_option_t = AOTCompOption*;
bool aot_compiler_init();
void aot_compiler_destroy();
AOTCompContext* aot_create_comp_context(AOTCompData* comp_data, aot_comp_option_t option);
void aot_destroy_comp_context(AOTCompContext* comp_ctx);
int aot_get_native_symbol_index(AOTCompContext* comp_ctx, const(char)* symbol);
bool aot_compile_wasm(AOTCompContext* comp_ctx);
ubyte* aot_emit_elf_file(AOTCompContext* comp_ctx, uint* p_elf_file_size);
void aot_destroy_elf_file(ubyte* elf_file);
void aot_value_stack_push(AOTValueStack* stack, AOTValue* value);
AOTValue* aot_value_stack_pop(AOTValueStack* stack);
void aot_value_stack_destroy(AOTValueStack* stack);
void aot_block_stack_push(AOTBlockStack* stack, AOTBlock* block);
AOTBlock* aot_block_stack_pop(AOTBlockStack* stack);
void aot_block_stack_destroy(AOTBlockStack* stack);
void aot_block_destroy(AOTBlock* block);
LLVMTypeRef wasm_type_to_llvm_type(AOTLLVMTypes* llvm_types, ubyte wasm_type);
bool aot_checked_addr_list_add(AOTFuncContext* func_ctx, uint local_idx, uint offset, uint bytes);
void aot_checked_addr_list_del(AOTFuncContext* func_ctx, uint local_idx);
bool aot_checked_addr_list_find(AOTFuncContext* func_ctx, uint local_idx, uint offset, uint bytes);
void aot_checked_addr_list_destroy(AOTFuncContext* func_ctx);
bool aot_build_zero_function_ret(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, AOTFuncType* func_type);
LLVMValueRef aot_call_llvm_intrinsic(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, const(char)* intrinsic, LLVMTypeRef ret_type, LLVMTypeRef* param_types, int param_count, ...);
LLVMValueRef aot_call_llvm_intrinsic_v(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, const(char)* intrinsic, LLVMTypeRef ret_type, LLVMTypeRef* param_types, int param_count, va_list param_value_list);
LLVMValueRef aot_get_func_from_table(const(AOTCompContext)* comp_ctx, LLVMValueRef base, LLVMTypeRef func_type, int index);
LLVMValueRef aot_load_const_from_table(AOTCompContext* comp_ctx, LLVMValueRef base, const(WASMValue)* value, ubyte value_type);
bool aot_check_simd_compatibility(const(char)* arch_c_str, const(char)* cpu_c_str);
void aot_add_expand_memory_op_pass(LLVMPassManagerRef pass);
void aot_add_simple_loop_unswitch_pass(LLVMPassManagerRef pass);
void aot_apply_llvm_new_pass_manager(AOTCompContext* comp_ctx, LLVMModuleRef module_);
void aot_handle_llvm_errmsg(const(char)* string, LLVMErrorRef err);
import tagion.iwasm.compilation.aot_compiler;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.aot.aot_runtime;
import tagion.iwasm.aot.aot_intrinsic;
LLVMTypeRef wasm_type_to_llvm_type(AOTLLVMTypes* llvm_types, ubyte wasm_type) {
    switch (wasm_type) {
        case VALUE_TYPE_I32:
        case VALUE_TYPE_FUNCREF:
        case VALUE_TYPE_EXTERNREF:
            return llvm_types.int32_type;
        case VALUE_TYPE_I64:
            return llvm_types.int64_type;
        case VALUE_TYPE_F32:
            return llvm_types.float32_type;
        case VALUE_TYPE_F64:
            return llvm_types.float64_type;
        case VALUE_TYPE_V128:
            return llvm_types.i64x2_vec_type;
        case VALUE_TYPE_VOID:
            return llvm_types.void_type;
        default:
            break;
    }
    return null;
}
/**
 * Add LLVM function
 */
private LLVMValueRef aot_add_llvm_func(AOTCompContext* comp_ctx, LLVMModuleRef module_, AOTFuncType* aot_func_type, uint func_index, LLVMTypeRef* p_func_type) {
    LLVMValueRef func = null;
    LLVMTypeRef* param_types = void; LLVMTypeRef ret_type = void, func_type = void;
    LLVMValueRef local_value = void;
    LLVMTypeRef func_type_wrapper = void;
    LLVMValueRef func_wrapper = void;
    LLVMBasicBlockRef func_begin = void;
    char[48] func_name = void;
    ulong size = void;
    uint i = void, j = 0, param_count = cast(ulong)aot_func_type.param_count;
    uint backend_thread_num = void, compile_thread_num = void;
    /* exec env as first parameter */
    param_count++;
    /* Extra wasm function results(except the first one)'s address are
     * appended to aot function parameters. */
    if (aot_func_type.result_count > 1)
        param_count += aot_func_type.result_count - 1;
    /* Initialize parameter types of the LLVM function */
    size = LLVMTypeRef.sizeof * (cast(ulong)param_count);
    if (size >= UINT32_MAX
        || ((param_types = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }
    /* exec env as first parameter */
    param_types[j++] = comp_ctx.exec_env_type;
    for (i = 0; i < aot_func_type.param_count; i++)
        param_types[j++] = TO_LLVM_TYPE(aot_func_type.types[i]);
    /* Extra results' address */
    for (i = 1; i < aot_func_type.result_count; i++, j++) {
        param_types[j] =
            TO_LLVM_TYPE(aot_func_type.types[aot_func_type.param_count + i]);
        if (((param_types[j] = LLVMPointerType(param_types[j], 0)) == 0)) {
            aot_set_last_error("llvm get pointer type failed.");
            goto fail;
        }
    }
    /* Resolve return type of the LLVM function */
    if (aot_func_type.result_count)
        ret_type =
            TO_LLVM_TYPE(aot_func_type.types[aot_func_type.param_count]);
    else
        ret_type = VOID_TYPE;
    /* Resolve function prototype */
    if (((func_type =
              LLVMFunctionType(ret_type, param_types, param_count, false)) == 0)) {
        aot_set_last_error("create LLVM function type failed.");
        goto fail;
    }
    /* Add LLVM function */
    snprintf(func_name.ptr, func_name.sizeof, "%s%d", AOT_FUNC_PREFIX, func_index);
    if (((func = LLVMAddFunction(module_, func_name.ptr, func_type)) == 0)) {
        aot_set_last_error("add LLVM function failed.");
        goto fail;
    }
    j = 0;
    local_value = LLVMGetParam(func, j++);
    LLVMSetValueName(local_value, "exec_env");
    /* Set parameter names */
    for (i = 0; i < aot_func_type.param_count; i++) {
        local_value = LLVMGetParam(func, j++);
        LLVMSetValueName(local_value, "");
    }
    if (p_func_type)
        *p_func_type = func_type;
    backend_thread_num = WASM_ORC_JIT_BACKEND_THREAD_NUM;
    compile_thread_num = WASM_ORC_JIT_COMPILE_THREAD_NUM;
    /* Add the jit wrapper function with simple prototype, so that we
       can easily call it to trigger its compilation and let LLVM JIT
       compile the actual jit functions by adding them into the function
       list in the PartitionFunction callback */
    if (comp_ctx.is_jit_mode
        && (func_index % (backend_thread_num * compile_thread_num)
            < backend_thread_num)) {
        func_type_wrapper = LLVMFunctionType(VOID_TYPE, null, 0, false);
        if (!func_type_wrapper) {
            aot_set_last_error("create LLVM function type failed.");
            goto fail;
        }
        snprintf(func_name.ptr, func_name.sizeof, "%s%d%s", AOT_FUNC_PREFIX,
                 func_index, "_wrapper");
        if (((func_wrapper =
                  LLVMAddFunction(module_, func_name.ptr, func_type_wrapper)) == 0)) {
            aot_set_last_error("add LLVM function failed.");
            goto fail;
        }
        if (((func_begin = LLVMAppendBasicBlockInContext(
                  comp_ctx.context, func_wrapper, "func_begin")) == 0)) {
            aot_set_last_error("add LLVM basic block failed.");
            goto fail;
        }
        LLVMPositionBuilderAtEnd(comp_ctx.builder, func_begin);
        if (!LLVMBuildRetVoid(comp_ctx.builder)) {
            aot_set_last_error("llvm build ret failed.");
            goto fail;
        }
    }
fail:
    wasm_runtime_free(param_types);
    return func;
}
private void free_block_memory(AOTBlock* block) {
    if (block.param_types)
        wasm_runtime_free(block.param_types);
    if (block.result_types)
        wasm_runtime_free(block.result_types);
    wasm_runtime_free(block);
}
/**
 * Create first AOTBlock, or function block for the function
 */
private AOTBlock* aot_create_func_block(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, AOTFunc* func, AOTFuncType* aot_func_type) {
    AOTBlock* aot_block = void;
    uint param_count = aot_func_type.param_count, result_count = aot_func_type.result_count;
    /* Allocate memory */
    if (((aot_block = wasm_runtime_malloc(AOTBlock.sizeof)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }
    memset(aot_block, 0, AOTBlock.sizeof);
    if (param_count
        && ((aot_block.param_types = wasm_runtime_malloc(param_count)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        goto fail;
    }
    if (result_count) {
        if (((aot_block.result_types = wasm_runtime_malloc(result_count)) == 0)) {
            aot_set_last_error("allocate memory failed.");
            goto fail;
        }
    }
    /* Set block data */
    aot_block.label_type = LABEL_TYPE_FUNCTION;
    aot_block.param_count = param_count;
    if (param_count) {
        bh_memcpy_s(aot_block.param_types, param_count, aot_func_type.types,
                    param_count);
    }
    aot_block.result_count = result_count;
    if (result_count) {
        bh_memcpy_s(aot_block.result_types, result_count,
                    aot_func_type.types + param_count, result_count);
    }
    aot_block.wasm_code_end = func.code + func.code_size;
    /* Add function entry block */
    if (((aot_block.llvm_entry_block = LLVMAppendBasicBlockInContext(
              comp_ctx.context, func_ctx.func, "func_begin")) == 0)) {
        aot_set_last_error("add LLVM basic block failed.");
        goto fail;
    }
    return aot_block;
fail:
    free_block_memory(aot_block);
    return null;
}
private bool create_argv_buf(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef argv_buf_offset = I32_THREE, argv_buf_addr = void;
    LLVMTypeRef int32_ptr_type = void;
    /* Get argv buffer address */
    if (((argv_buf_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.exec_env, &argv_buf_offset, 1, "argv_buf_addr")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((int32_ptr_type = LLVMPointerType(INT32_PTR_TYPE, 0)) == 0)) {
        aot_set_last_error("llvm add pointer type failed");
        return false;
    }
    /* Convert to int32 pointer type */
    if (((argv_buf_addr = LLVMBuildBitCast(comp_ctx.builder, argv_buf_addr,
                                           int32_ptr_type, "argv_buf_ptr")) == 0)) {
        aot_set_last_error("llvm build load failed");
        return false;
    }
    if (((func_ctx.argv_buf = LLVMBuildLoad(comp_ctx.builder, argv_buf_addr, "argv_buf")) == 0)) {
        aot_set_last_error("llvm build load failed");
        return false;
    }
    return true;
}
private bool create_native_stack_bound(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef stack_bound_offset = I32_FOUR, stack_bound_addr = void;
    if (((stack_bound_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.exec_env, &stack_bound_offset, 1, "stack_bound_addr")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.native_stack_bound =
              LLVMBuildLoad(comp_ctx.builder, stack_bound_addr, "native_stack_bound")) == 0)) {
        aot_set_last_error("llvm build load failed");
        return false;
    }
    return true;
}
private bool create_aux_stack_info(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef aux_stack_bound_offset = I32_SIX, aux_stack_bound_addr = void;
    LLVMValueRef aux_stack_bottom_offset = I32_SEVEN, aux_stack_bottom_addr = void;
    /* Get aux stack boundary address */
    if (((aux_stack_bound_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.exec_env, &aux_stack_bound_offset, 1, "aux_stack_bound_addr")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((aux_stack_bound_addr =
              LLVMBuildBitCast(comp_ctx.builder, aux_stack_bound_addr,
                               INT32_PTR_TYPE, "aux_stack_bound_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (((func_ctx.aux_stack_bound =
              LLVMBuildLoad(comp_ctx.builder, aux_stack_bound_addr, "aux_stack_bound")) == 0)) {
        aot_set_last_error("llvm build load failed");
        return false;
    }
    /* Get aux stack bottom address */
    if (((aux_stack_bottom_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.exec_env, &aux_stack_bottom_offset, 1, "aux_stack_bottom_addr")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((aux_stack_bottom_addr =
              LLVMBuildBitCast(comp_ctx.builder, aux_stack_bottom_addr,
                               INT32_PTR_TYPE, "aux_stack_bottom_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (((func_ctx.aux_stack_bottom =
              LLVMBuildLoad(comp_ctx.builder, aux_stack_bottom_addr, "aux_stack_bottom")) == 0)) {
        aot_set_last_error("llvm build load failed");
        return false;
    }
    return true;
}
private bool create_native_symbol(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef native_symbol_offset = I32_EIGHT, native_symbol_addr = void;
    if (((native_symbol_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.exec_env, &native_symbol_offset, 1, "native_symbol_addr")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.native_symbol =
              LLVMBuildLoad(comp_ctx.builder, native_symbol_addr, "native_symbol_tmp")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (((func_ctx.native_symbol =
              LLVMBuildBitCast(comp_ctx.builder, func_ctx.native_symbol,
                               comp_ctx.exec_env_type, "native_symbol")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    return true;
}
private bool create_local_variables(AOTCompData* comp_data, AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, AOTFunc* func) {
    AOTFuncType* aot_func_type = comp_data.func_types[func.func_type_index];
    char[32] local_name = void;
    uint i = void, j = 1;
    for (i = 0; i < aot_func_type.param_count; i++, j++) {
        snprintf(local_name.ptr, local_name.sizeof, "l%d", i);
        func_ctx.locals[i] =
            LLVMBuildAlloca(comp_ctx.builder,
                            TO_LLVM_TYPE(aot_func_type.types[i]), local_name.ptr);
        if (!func_ctx.locals[i]) {
            aot_set_last_error("llvm build alloca failed.");
            return false;
        }
        if (!LLVMBuildStore(comp_ctx.builder, LLVMGetParam(func_ctx.func, j),
                            func_ctx.locals[i])) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
    }
    for (i = 0; i < func.local_count; i++) {
        LLVMTypeRef local_type = void;
        LLVMValueRef local_value = null;
        snprintf(local_name.ptr, local_name.sizeof, "l%d",
                 aot_func_type.param_count + i);
        local_type = TO_LLVM_TYPE(func.local_types[i]);
        func_ctx.locals[aot_func_type.param_count + i] =
            LLVMBuildAlloca(comp_ctx.builder, local_type, local_name.ptr);
        if (!func_ctx.locals[aot_func_type.param_count + i]) {
            aot_set_last_error("llvm build alloca failed.");
            return false;
        }
        switch (func.local_types[i]) {
            case VALUE_TYPE_I32:
                local_value = I32_ZERO;
                break;
            case VALUE_TYPE_I64:
                local_value = I64_ZERO;
                break;
            case VALUE_TYPE_F32:
                local_value = F32_ZERO;
                break;
            case VALUE_TYPE_F64:
                local_value = F64_ZERO;
                break;
            case VALUE_TYPE_V128:
                local_value = V128_i64x2_ZERO;
                break;
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
                local_value = REF_NULL;
                break;
            default:
                bh_assert(0);
                break;
        }
        if (!LLVMBuildStore(comp_ctx.builder, local_value,
                            func_ctx.locals[aot_func_type.param_count + i])) {
            aot_set_last_error("llvm build store failed.");
            return false;
        }
    }
    if (comp_ctx.enable_stack_bound_check) {
        if (aot_func_type.param_count + func.local_count > 0) {
            func_ctx.last_alloca = func_ctx.locals[aot_func_type.param_count
                                                     + func.local_count - 1];
            if (((func_ctx.last_alloca =
                      LLVMBuildBitCast(comp_ctx.builder, func_ctx.last_alloca,
                                       INT8_PTR_TYPE, "stack_ptr")) == 0)) {
                aot_set_last_error("llvm build bit cast failed.");
                return false;
            }
        }
        else {
            if (((func_ctx.last_alloca = LLVMBuildAlloca(
                      comp_ctx.builder, INT8_TYPE, "stack_ptr")) == 0)) {
                aot_set_last_error("llvm build alloca failed.");
                return false;
            }
        }
    }
    return true;
}
private bool create_memory_info(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, LLVMTypeRef int8_ptr_type, uint func_index) {
    LLVMValueRef offset = void, mem_info_base = void;
    uint memory_count = void;
    WASMModule* module_ = comp_ctx.comp_data.wasm_module;
    WASMFunction* func = module_.functions[func_index];
    LLVMTypeRef bound_check_type = void;
    bool mem_space_unchanged = (!func.has_op_memory_grow && !func.has_op_func_call)
        || (!module_.possible_memory_grow);
    func_ctx.mem_space_unchanged = mem_space_unchanged;
    memory_count = module_.memory_count + module_.import_memory_count;
    /* If the module dosen't have memory, reserve
        one mem_info space with empty content */
    if (memory_count == 0)
        memory_count = 1;
    if (((func_ctx.mem_info =
              wasm_runtime_malloc(AOTMemInfo.sizeof * memory_count)) == 0)) {
        return false;
    }
    memset(func_ctx.mem_info, 0, AOTMemInfo.sizeof);
    /* Currently we only create memory info for memory 0 */
    /* Load memory base address */
    {
        uint offset_of_global_table_data = void;
        if (comp_ctx.is_jit_mode)
            offset_of_global_table_data =
                WASMModuleInstance.global_table_data.offsetof;
        else
            offset_of_global_table_data =
                AOTModuleInstance.global_table_data.offsetof;
        offset = I32_CONST(offset_of_global_table_data
                           + AOTMemoryInstance.memory_data.offsetof);
        if (((func_ctx.mem_info[0].mem_base_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.aot_inst, &offset, 1, "mem_base_addr_offset")) == 0)) {
            aot_set_last_error("llvm build in bounds gep failed");
            return false;
        }
        offset = I32_CONST(offset_of_global_table_data
                           + AOTMemoryInstance.cur_page_count.offsetof);
        if (((func_ctx.mem_info[0].mem_cur_page_count_addr =
                  LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.aot_inst, &offset, 1, "mem_cur_page_offset")) == 0)) {
            aot_set_last_error("llvm build in bounds gep failed");
            return false;
        }
        offset = I32_CONST(offset_of_global_table_data
                           + AOTMemoryInstance.memory_data_size.offsetof);
        if (((func_ctx.mem_info[0].mem_data_size_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.aot_inst, &offset, 1, "mem_data_size_offset")) == 0)) {
            aot_set_last_error("llvm build in bounds gep failed");
            return false;
        }
    }
    /* Store mem info base address before cast */
    mem_info_base = func_ctx.mem_info[0].mem_base_addr;
    if (((func_ctx.mem_info[0].mem_base_addr = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_base_addr,
              int8_ptr_type, "mem_base_addr_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_cur_page_count_addr = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_cur_page_count_addr,
              INT32_PTR_TYPE, "mem_cur_page_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_data_size_addr = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_data_size_addr,
              INT32_PTR_TYPE, "mem_data_size_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (mem_space_unchanged) {
        if (((func_ctx.mem_info[0].mem_base_addr = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_base_addr, "mem_base_addr")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
        if (((func_ctx.mem_info[0].mem_cur_page_count_addr =
                  LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_cur_page_count_addr, "mem_cur_page_count")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
        if (((func_ctx.mem_info[0].mem_data_size_addr = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_data_size_addr, "mem_data_size")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
    }
    bound_check_type = (comp_ctx.pointer_size == uint64.sizeof)
                           ? INT64_PTR_TYPE
                           : INT32_PTR_TYPE;
    /* Load memory bound check constants */
    offset = I32_CONST(AOTMemoryInstance.mem_bound_check_1byte.offsetof
                       - AOTMemoryInstance.memory_data.offsetof);
    if (((func_ctx.mem_info[0].mem_bound_check_1byte =
              LLVMBuildInBoundsGEP(comp_ctx.builder, mem_info_base, &offset, 1, "bound_check_1byte_offset")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_bound_check_1byte = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_1byte,
              bound_check_type, "bound_check_1byte_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (mem_space_unchanged) {
        if (((func_ctx.mem_info[0].mem_bound_check_1byte = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_1byte, "bound_check_1byte")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
    }
    offset = I32_CONST(AOTMemoryInstance.mem_bound_check_2bytes.offsetof
                       - AOTMemoryInstance.memory_data.offsetof);
    if (((func_ctx.mem_info[0].mem_bound_check_2bytes =
              LLVMBuildInBoundsGEP(comp_ctx.builder, mem_info_base, &offset, 1, "bound_check_2bytes_offset")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_bound_check_2bytes = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_2bytes,
              bound_check_type, "bound_check_2bytes_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (mem_space_unchanged) {
        if (((func_ctx.mem_info[0].mem_bound_check_2bytes = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_2bytes, "bound_check_2bytes")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
    }
    offset = I32_CONST(AOTMemoryInstance.mem_bound_check_4bytes.offsetof
                       - AOTMemoryInstance.memory_data.offsetof);
    if (((func_ctx.mem_info[0].mem_bound_check_4bytes =
              LLVMBuildInBoundsGEP(comp_ctx.builder, mem_info_base, &offset, 1, "bound_check_4bytes_offset")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_bound_check_4bytes = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_4bytes,
              bound_check_type, "bound_check_4bytes_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (mem_space_unchanged) {
        if (((func_ctx.mem_info[0].mem_bound_check_4bytes = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_4bytes, "bound_check_4bytes")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
    }
    offset = I32_CONST(AOTMemoryInstance.mem_bound_check_8bytes.offsetof
                       - AOTMemoryInstance.memory_data.offsetof);
    if (((func_ctx.mem_info[0].mem_bound_check_8bytes =
              LLVMBuildInBoundsGEP(comp_ctx.builder, mem_info_base, &offset, 1, "bound_check_8bytes_offset")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_bound_check_8bytes = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_8bytes,
              bound_check_type, "bound_check_8bytes_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (mem_space_unchanged) {
        if (((func_ctx.mem_info[0].mem_bound_check_8bytes = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_8bytes, "bound_check_8bytes")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
    }
    offset = I32_CONST(AOTMemoryInstance.mem_bound_check_16bytes.offsetof
                       - AOTMemoryInstance.memory_data.offsetof);
    if (((func_ctx.mem_info[0].mem_bound_check_16bytes = LLVMBuildInBoundsGEP(comp_ctx.builder, mem_info_base, &offset, 1, "bound_check_16bytes_offset")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        return false;
    }
    if (((func_ctx.mem_info[0].mem_bound_check_16bytes = LLVMBuildBitCast(
              comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_16bytes,
              bound_check_type, "bound_check_16bytes_ptr")) == 0)) {
        aot_set_last_error("llvm build bit cast failed");
        return false;
    }
    if (mem_space_unchanged) {
        if (((func_ctx.mem_info[0].mem_bound_check_16bytes = LLVMBuildLoad(comp_ctx.builder, func_ctx.mem_info[0].mem_bound_check_16bytes, "bound_check_16bytes")) == 0)) {
            aot_set_last_error("llvm build load failed");
            return false;
        }
    }
    return true;
}
private bool create_cur_exception(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef offset = void;
    offset = I32_CONST(AOTModuleInstance.cur_exception.offsetof);
    func_ctx.cur_exception =
        LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.aot_inst, &offset, 1, "cur_exception");
    if (!func_ctx.cur_exception) {
        aot_set_last_error("llvm build in bounds gep failed.");
        return false;
    }
    return true;
}
private bool create_func_type_indexes(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef offset = void, func_type_indexes_ptr = void;
    LLVMTypeRef int32_ptr_type = void;
    offset = I32_CONST(AOTModuleInstance.func_type_indexes.offsetof);
    func_type_indexes_ptr =
        LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.aot_inst, &offset, 1, "func_type_indexes_ptr");
    if (!func_type_indexes_ptr) {
        aot_set_last_error("llvm build add failed.");
        return false;
    }
    if (((int32_ptr_type = LLVMPointerType(INT32_PTR_TYPE, 0)) == 0)) {
        aot_set_last_error("llvm get pointer type failed.");
        return false;
    }
    func_ctx.func_type_indexes =
        LLVMBuildBitCast(comp_ctx.builder, func_type_indexes_ptr,
                         int32_ptr_type, "func_type_indexes_tmp");
    if (!func_ctx.func_type_indexes) {
        aot_set_last_error("llvm build bit cast failed.");
        return false;
    }
    func_ctx.func_type_indexes =
        LLVMBuildLoad(comp_ctx.builder, func_ctx.func_type_indexes, "func_type_indexes");
    if (!func_ctx.func_type_indexes) {
        aot_set_last_error("llvm build load failed.");
        return false;
    }
    return true;
}
private bool create_func_ptrs(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx) {
    LLVMValueRef offset = void;
    offset = I32_CONST(AOTModuleInstance.func_ptrs.offsetof);
    func_ctx.func_ptrs =
        LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.aot_inst, &offset, 1, "func_ptrs_offset");
    if (!func_ctx.func_ptrs) {
        aot_set_last_error("llvm build in bounds gep failed.");
        return false;
    }
    func_ctx.func_ptrs =
        LLVMBuildBitCast(comp_ctx.builder, func_ctx.func_ptrs,
                         comp_ctx.exec_env_type, "func_ptrs_tmp");
    if (!func_ctx.func_ptrs) {
        aot_set_last_error("llvm build bit cast failed.");
        return false;
    }
    func_ctx.func_ptrs = LLVMBuildLoad(comp_ctx.builder, func_ctx.func_ptrs, "func_ptrs_ptr");
    if (!func_ctx.func_ptrs) {
        aot_set_last_error("llvm build load failed.");
        return false;
    }
    func_ctx.func_ptrs =
        LLVMBuildBitCast(comp_ctx.builder, func_ctx.func_ptrs,
                         comp_ctx.exec_env_type, "func_ptrs");
    if (!func_ctx.func_ptrs) {
        aot_set_last_error("llvm build bit cast failed.");
        return false;
    }
    return true;
}
/**
 * Create function compiler context
 */
private AOTFuncContext* aot_create_func_context(AOTCompData* comp_data, AOTCompContext* comp_ctx, AOTFunc* func, uint func_index) {
    AOTFuncContext* func_ctx = void;
    AOTFuncType* aot_func_type = comp_data.func_types[func.func_type_index];
    WASMModule* module_ = comp_ctx.comp_data.wasm_module;
    WASMFunction* wasm_func = module_.functions[func_index];
    AOTBlock* aot_block = void;
    LLVMTypeRef int8_ptr_type = void;
    LLVMValueRef aot_inst_offset = I32_TWO, aot_inst_addr = void;
    ulong size = void;
    /* Allocate memory for the function context */
    size = AOTFuncContext.locals.offsetof
           + LLVMValueRef.sizeof
                 * (cast(ulong)aot_func_type.param_count + func.local_count);
    if (size >= UINT32_MAX || ((func_ctx = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }
    memset(func_ctx, 0, cast(uint)size);
    func_ctx.aot_func = func;
    func_ctx.module_ = comp_ctx.module_;
    /* Add LLVM function */
    if (((func_ctx.func =
              aot_add_llvm_func(comp_ctx, func_ctx.module_, aot_func_type,
                                func_index, &func_ctx.func_type)) == 0)) {
        goto fail;
    }
    /* Create function's first AOTBlock */
    if (((aot_block =
              aot_create_func_block(comp_ctx, func_ctx, func, aot_func_type)) == 0)) {
        goto fail;
    }
    aot_block_stack_push(&func_ctx.block_stack, aot_block);
    /* Add local variables */
    LLVMPositionBuilderAtEnd(comp_ctx.builder, aot_block.llvm_entry_block);
    /* Save the pameters for fast access */
    func_ctx.exec_env = LLVMGetParam(func_ctx.func, 0);
    /* Get aot inst address, the layout of exec_env is:
       exec_env->next, exec_env->prev, exec_env->module_inst, and argv_buf */
    if (((aot_inst_addr = LLVMBuildInBoundsGEP(comp_ctx.builder, func_ctx.exec_env, &aot_inst_offset, 1, "aot_inst_addr")) == 0)) {
        aot_set_last_error("llvm build in bounds gep failed");
        goto fail;
    }
    /* Load aot inst */
    if (((func_ctx.aot_inst = LLVMBuildLoad(comp_ctx.builder, aot_inst_addr, "aot_inst")) == 0)) {
        aot_set_last_error("llvm build load failed");
        goto fail;
    }
    /* Get argv buffer address */
    if (wasm_func.has_op_func_call && !create_argv_buf(comp_ctx, func_ctx)) {
        goto fail;
    }
    /* Get native stack boundary address */
    if (comp_ctx.enable_stack_bound_check
        && !create_native_stack_bound(comp_ctx, func_ctx)) {
        goto fail;
    }
    /* Get auxiliary stack info */
    if (wasm_func.has_op_set_global_aux_stack
        && !create_aux_stack_info(comp_ctx, func_ctx)) {
        goto fail;
    }
    /* Get native symbol list */
    if (comp_ctx.is_indirect_mode
        && !create_native_symbol(comp_ctx, func_ctx)) {
        goto fail;
    }
    /* Create local variables */
    if (!create_local_variables(comp_data, comp_ctx, func_ctx, func)) {
        goto fail;
    }
    if (((int8_ptr_type = LLVMPointerType(INT8_PTR_TYPE, 0)) == 0)) {
        aot_set_last_error("llvm add pointer type failed.");
        goto fail;
    }
    /* Create base addr, end addr, data size of mem, heap */
    if (wasm_func.has_memory_operations
        && !create_memory_info(comp_ctx, func_ctx, int8_ptr_type, func_index)) {
        goto fail;
    }
    /* Load current exception */
    if (!create_cur_exception(comp_ctx, func_ctx)) {
        goto fail;
    }
    /* Load function type indexes */
    if (wasm_func.has_op_call_indirect
        && !create_func_type_indexes(comp_ctx, func_ctx)) {
        goto fail;
    }
    /* Load function pointers */
    if (!create_func_ptrs(comp_ctx, func_ctx)) {
        goto fail;
    }
    return func_ctx;
fail:
    if (func_ctx.mem_info)
        wasm_runtime_free(func_ctx.mem_info);
    aot_block_stack_destroy(&func_ctx.block_stack);
    wasm_runtime_free(func_ctx);
    return null;
}
private void aot_destroy_func_contexts(AOTFuncContext** func_ctxes, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (func_ctxes[i]) {
            if (func_ctxes[i].mem_info)
                wasm_runtime_free(func_ctxes[i].mem_info);
            aot_block_stack_destroy(&func_ctxes[i].block_stack);
            aot_checked_addr_list_destroy(func_ctxes[i]);
            wasm_runtime_free(func_ctxes[i]);
        }
    wasm_runtime_free(func_ctxes);
}
/**
 * Create function compiler contexts
 */
private AOTFuncContext** aot_create_func_contexts(AOTCompData* comp_data, AOTCompContext* comp_ctx) {
    AOTFuncContext** func_ctxes = void;
    ulong size = void;
    uint i = void;
    /* Allocate memory */
    size = (AOTFuncContext*).sizeof * cast(ulong)comp_data.func_count;
    if (size >= UINT32_MAX
        || ((func_ctxes = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }
    memset(func_ctxes, 0, size);
    /* Create each function context */
    for (i = 0; i < comp_data.func_count; i++) {
        AOTFunc* func = comp_data.funcs[i];
        if (((func_ctxes[i] =
                  aot_create_func_context(comp_data, comp_ctx, func, i)) == 0)) {
            aot_destroy_func_contexts(func_ctxes, comp_data.func_count);
            return null;
        }
    }
    return func_ctxes;
}
private bool aot_set_llvm_basic_types(AOTLLVMTypes* basic_types, LLVMContextRef context) {
    basic_types.int1_type = LLVMInt1TypeInContext(context);
    basic_types.int8_type = LLVMInt8TypeInContext(context);
    basic_types.int16_type = LLVMInt16TypeInContext(context);
    basic_types.int32_type = LLVMInt32TypeInContext(context);
    basic_types.int64_type = LLVMInt64TypeInContext(context);
    basic_types.float32_type = LLVMFloatTypeInContext(context);
    basic_types.float64_type = LLVMDoubleTypeInContext(context);
    basic_types.void_type = LLVMVoidTypeInContext(context);
    basic_types.meta_data_type = LLVMMetadataTypeInContext(context);
    basic_types.int8_ptr_type = LLVMPointerType(basic_types.int8_type, 0);
    if (basic_types.int8_ptr_type) {
        basic_types.int8_pptr_type =
            LLVMPointerType(basic_types.int8_ptr_type, 0);
    }
    basic_types.int16_ptr_type = LLVMPointerType(basic_types.int16_type, 0);
    basic_types.int32_ptr_type = LLVMPointerType(basic_types.int32_type, 0);
    basic_types.int64_ptr_type = LLVMPointerType(basic_types.int64_type, 0);
    basic_types.float32_ptr_type =
        LLVMPointerType(basic_types.float32_type, 0);
    basic_types.float64_ptr_type =
        LLVMPointerType(basic_types.float64_type, 0);
    basic_types.i8x16_vec_type = LLVMVectorType(basic_types.int8_type, 16);
    basic_types.i16x8_vec_type = LLVMVectorType(basic_types.int16_type, 8);
    basic_types.i32x4_vec_type = LLVMVectorType(basic_types.int32_type, 4);
    basic_types.i64x2_vec_type = LLVMVectorType(basic_types.int64_type, 2);
    basic_types.f32x4_vec_type = LLVMVectorType(basic_types.float32_type, 4);
    basic_types.f64x2_vec_type = LLVMVectorType(basic_types.float64_type, 2);
    basic_types.v128_type = basic_types.i64x2_vec_type;
    basic_types.v128_ptr_type = LLVMPointerType(basic_types.v128_type, 0);
    basic_types.i1x2_vec_type = LLVMVectorType(basic_types.int1_type, 2);
    basic_types.funcref_type = LLVMInt32TypeInContext(context);
    basic_types.externref_type = LLVMInt32TypeInContext(context);
    return (basic_types.int8_ptr_type && basic_types.int8_pptr_type
            && basic_types.int16_ptr_type && basic_types.int32_ptr_type
            && basic_types.int64_ptr_type && basic_types.float32_ptr_type
            && basic_types.float64_ptr_type && basic_types.i8x16_vec_type
            && basic_types.i16x8_vec_type && basic_types.i32x4_vec_type
            && basic_types.i64x2_vec_type && basic_types.f32x4_vec_type
            && basic_types.f64x2_vec_type && basic_types.i1x2_vec_type
            && basic_types.meta_data_type && basic_types.funcref_type
            && basic_types.externref_type)
               ? true
               : false;
}
private bool aot_create_llvm_consts(AOTLLVMConsts* consts, AOTCompContext* comp_ctx) {
    if (((consts.i1_zero = LLVMConstInt(comp_ctx.basic_types.int1_type, 0, true)) == 0)) return false;
    if (((consts.i1_one = LLVMConstInt(comp_ctx.basic_types.int1_type, 1, true)) == 0)) return false;
    if (((consts.i8_zero = I8_CONST(0)) == 0))
        return false;
    if (((consts.f32_zero = F32_CONST(0)) == 0))
        return false;
    if (((consts.f64_zero = F64_CONST(0)) == 0))
        return false;
    if (((consts.i32_min = LLVMConstInt(I32_TYPE, cast(uint)INT32_MIN, true)) == 0)) return false;
    if (((consts.i32_neg_one = LLVMConstInt(I32_TYPE, cast(uint)-1, true)) == 0)) return false;
    if (((consts.i32_zero = LLVMConstInt(I32_TYPE, 0, true)) == 0)) return false;
    if (((consts.i32_one = LLVMConstInt(I32_TYPE, 1, true)) == 0)) return false;
    if (((consts.i32_two = LLVMConstInt(I32_TYPE, 2, true)) == 0)) return false;
    if (((consts.i32_three = LLVMConstInt(I32_TYPE, 3, true)) == 0)) return false;
    if (((consts.i32_four = LLVMConstInt(I32_TYPE, 4, true)) == 0)) return false;
    if (((consts.i32_five = LLVMConstInt(I32_TYPE, 5, true)) == 0)) return false;
    if (((consts.i32_six = LLVMConstInt(I32_TYPE, 6, true)) == 0)) return false;
    if (((consts.i32_seven = LLVMConstInt(I32_TYPE, 7, true)) == 0)) return false;
    if (((consts.i32_eight = LLVMConstInt(I32_TYPE, 8, true)) == 0)) return false;
    if (((consts.i32_nine = LLVMConstInt(I32_TYPE, 9, true)) == 0)) return false;
    if (((consts.i32_ten = LLVMConstInt(I32_TYPE, 10, true)) == 0)) return false;
    if (((consts.i32_eleven = LLVMConstInt(I32_TYPE, 11, true)) == 0)) return false;
    if (((consts.i32_twelve = LLVMConstInt(I32_TYPE, 12, true)) == 0)) return false;
    if (((consts.i32_thirteen = LLVMConstInt(I32_TYPE, 13, true)) == 0)) return false;
    if (((consts.i32_fourteen = LLVMConstInt(I32_TYPE, 14, true)) == 0)) return false;
    if (((consts.i32_fifteen = LLVMConstInt(I32_TYPE, 15, true)) == 0)) return false;
    if (((consts.i32_31 = LLVMConstInt(I32_TYPE, 31, true)) == 0)) return false;
    if (((consts.i32_32 = LLVMConstInt(I32_TYPE, 32, true)) == 0)) return false;
    if (((consts.i64_min = LLVMConstInt(I64_TYPE, cast(ulong)INT64_MIN, true)) == 0)) return false;
    if (((consts.i64_neg_one = LLVMConstInt(I64_TYPE, (uint64)-1, true)) == 0)) return false;
    if (((consts.i64_zero = LLVMConstInt(I64_TYPE, 0, true)) == 0)) return false;
    if (((consts.i64_63 = LLVMConstInt(I64_TYPE, 63, true)) == 0)) return false;
    if (((consts.i64_64 = LLVMConstInt(I64_TYPE, 64, true)) == 0)) return false;
    if (((consts.i8x16_vec_zero = LLVMConstNull(V128_i8x16_TYPE)) == 0)) return false; if (((consts.i8x16_undef = LLVMGetUndef(V128_i8x16_TYPE)) == 0)) return false;
    if (((consts.i16x8_vec_zero = LLVMConstNull(V128_i16x8_TYPE)) == 0)) return false; if (((consts.i16x8_undef = LLVMGetUndef(V128_i16x8_TYPE)) == 0)) return false;
    if (((consts.i32x4_vec_zero = LLVMConstNull(V128_i32x4_TYPE)) == 0)) return false; if (((consts.i32x4_undef = LLVMGetUndef(V128_i32x4_TYPE)) == 0)) return false;
    if (((consts.i64x2_vec_zero = LLVMConstNull(V128_i64x2_TYPE)) == 0)) return false; if (((consts.i64x2_undef = LLVMGetUndef(V128_i64x2_TYPE)) == 0)) return false;
    if (((consts.f32x4_vec_zero = LLVMConstNull(V128_f32x4_TYPE)) == 0)) return false; if (((consts.f32x4_undef = LLVMGetUndef(V128_f32x4_TYPE)) == 0)) return false;
    if (((consts.f64x2_vec_zero = LLVMConstNull(V128_f64x2_TYPE)) == 0)) return false; if (((consts.f64x2_undef = LLVMGetUndef(V128_f64x2_TYPE)) == 0)) return false;
    { LLVMTypeRef type = LLVMVectorType(I32_TYPE, 16); if (!type || ((consts.i32x16_zero = LLVMConstNull(type)) == 0)) return false; }
    { LLVMTypeRef type = LLVMVectorType(I32_TYPE, 8); if (!type || ((consts.i32x8_zero = LLVMConstNull(type)) == 0)) return false; }
    { LLVMTypeRef type = LLVMVectorType(I32_TYPE, 4); if (!type || ((consts.i32x4_zero = LLVMConstNull(type)) == 0)) return false; }
    { LLVMTypeRef type = LLVMVectorType(I32_TYPE, 2); if (!type || ((consts.i32x2_zero = LLVMConstNull(type)) == 0)) return false; }
    return true;
}
struct ArchItem {
    char* arch;
    bool support_eb;
}
/* clang-format off */
private ArchItem[56] valid_archs = [
    [ "x86_64", false ],
    [ "i386", false ],
    [ "xtensa", false ],
    [ "mips", true ],
    [ "mipsel", false ],
    [ "aarch64v8", false ],
    [ "aarch64v8.1", false ],
    [ "aarch64v8.2", false ],
    [ "aarch64v8.3", false ],
    [ "aarch64v8.4", false ],
    [ "aarch64v8.5", false ],
    [ "aarch64_bev8", false ], /* big endian */
    [ "aarch64_bev8.1", false ],
    [ "aarch64_bev8.2", false ],
    [ "aarch64_bev8.3", false ],
    [ "aarch64_bev8.4", false ],
    [ "aarch64_bev8.5", false ],
    [ "armv4", true ],
    [ "armv4t", true ],
    [ "armv5t", true ],
    [ "armv5te", true ],
    [ "armv5tej", true ],
    [ "armv6", true ],
    [ "armv6kz", true ],
    [ "armv6t2", true ],
    [ "armv6k", true ],
    [ "armv7", true ],
    [ "armv6m", true ],
    [ "armv6sm", true ],
    [ "armv7em", true ],
    [ "armv8a", true ],
    [ "armv8r", true ],
    [ "armv8m.base", true ],
    [ "armv8m.main", true ],
    [ "armv8.1m.main", true ],
    [ "thumbv4", true ],
    [ "thumbv4t", true ],
    [ "thumbv5t", true ],
    [ "thumbv5te", true ],
    [ "thumbv5tej", true ],
    [ "thumbv6", true ],
    [ "thumbv6kz", true ],
    [ "thumbv6t2", true ],
    [ "thumbv6k", true ],
    [ "thumbv7", true ],
    [ "thumbv6m", true ],
    [ "thumbv6sm", true ],
    [ "thumbv7em", true ],
    [ "thumbv8a", true ],
    [ "thumbv8r", true ],
    [ "thumbv8m.base", true ],
    [ "thumbv8m.main", true ],
    [ "thumbv8.1m.main", true ],
    [ "riscv32", true ],
    [ "riscv64", true ],
    [ "arc", true ]
];
private const(char)*[10] valid_abis = [
    "gnu",
    "eabi",
    "gnueabihf",
    "msvc",
    "ilp32",
    "ilp32f",
    "ilp32d",
    "lp64",
    "lp64f",
    "lp64d"
];
/* clang-format on */
private void print_supported_targets() {
    uint i = void;
    os_printf("Supported targets:\n");
    for (i = 0; i < valid_archs.sizeof / ArchItem.sizeof; i++) {
        os_printf("%s ", valid_archs[i].arch);
        if (valid_archs[i].support_eb)
            os_printf("%seb ", valid_archs[i].arch);
    }
    os_printf("\n");
}
private void print_supported_abis() {
    uint i = void;
    os_printf("Supported ABI: ");
    for (i = 0; i < valid_abis.sizeof / (const(char)*).sizeof; i++)
        os_printf("%s ", valid_abis[i]);
    os_printf("\n");
}
private bool check_target_arch(const(char)* target_arch) {
    uint i = void;
    char* arch = void;
    bool support_eb = void;
    for (i = 0; i < valid_archs.sizeof / ArchItem.sizeof; i++) {
        arch = valid_archs[i].arch;
        support_eb = valid_archs[i].support_eb;
        if (!strncmp(target_arch, arch, strlen(arch))
            && ((support_eb
                 && (!strcmp(target_arch + strlen(arch), "eb")
                     || !strcmp(target_arch + strlen(arch), "")))
                || (!support_eb && !strcmp(target_arch + strlen(arch), "")))) {
            return true;
        }
    }
    return false;
}
private bool check_target_abi(const(char)* target_abi) {
    uint i = void;
    for (i = 0; i < valid_abis.sizeof / (char*).sizeof; i++) {
        if (!strcmp(target_abi, valid_abis[i]))
            return true;
    }
    return false;
}
private void get_target_arch_from_triple(const(char)* triple, char* arch_buf, uint buf_size) {
    uint i = 0;
    while (*triple != '-' && *triple != '\0' && i < buf_size - 1)
        arch_buf[i++] = *triple++;
    /* Make sure buffer is long enough */
    bh_assert(*triple == '-' || *triple == '\0');
}
void aot_handle_llvm_errmsg(const(char)* string, LLVMErrorRef err) {
    char* err_msg = LLVMGetErrorMessage(err);
    aot_set_last_error_v("%s: %s", string, err_msg);
    LLVMDisposeErrorMessage(err_msg);
}
private bool create_target_machine_detect_host(AOTCompContext* comp_ctx) {
    char* triple = null;
    LLVMTargetRef target = null;
    char* err_msg = null;
    char* cpu = null;
    char* features = null;
    LLVMTargetMachineRef target_machine = null;
    bool ret = false;
    triple = LLVMGetDefaultTargetTriple();
    if (triple == null) {
        aot_set_last_error("failed to get default target triple.");
        goto fail;
    }
    if (LLVMGetTargetFromTriple(triple, &target, &err_msg) != 0) {
        aot_set_last_error_v("failed to get llvm target from triple %s.",
                             err_msg);
        LLVMDisposeMessage(err_msg);
        goto fail;
    }
    if (!LLVMTargetHasJIT(target)) {
        aot_set_last_error("unspported JIT on this platform.");
        goto fail;
    }
    cpu = LLVMGetHostCPUName();
    if (cpu == null) {
        aot_set_last_error("failed to get host cpu information.");
        goto fail;
    }
    features = LLVMGetHostCPUFeatures();
    if (features == null) {
        aot_set_last_error("failed to get host cpu features.");
        goto fail;
    }
    LOG_VERBOSE("LLVM ORCJIT detected CPU \"%s\", with features \"%s\"\n", cpu,
                features);
    /* create TargetMachine */
    target_machine = LLVMCreateTargetMachine(
        target, triple, cpu, features, LLVMCodeGenLevelDefault,
        LLVMRelocDefault, LLVMCodeModelJITDefault);
    if (!target_machine) {
        aot_set_last_error("failed to create target machine.");
        goto fail;
    }
    comp_ctx.target_machine = target_machine;
    /* Save target arch */
    get_target_arch_from_triple(triple, comp_ctx.target_arch,
                                typeof(comp_ctx.target_arch).sizeof);
    ret = true;
fail:
    if (triple)
        LLVMDisposeMessage(triple);
    if (features)
        LLVMDisposeMessage(features);
    if (cpu)
        LLVMDisposeMessage(cpu);
    return ret;
}
private bool orc_jit_create(AOTCompContext* comp_ctx) {
    LLVMErrorRef err = void;
    LLVMOrcLLLazyJITRef orc_jit = null;
    LLVMOrcLLLazyJITBuilderRef builder = null;
    LLVMOrcJITTargetMachineBuilderRef jtmb = null;
    bool ret = false;
    builder = LLVMOrcCreateLLLazyJITBuilder();
    if (builder == null) {
        aot_set_last_error("failed to create jit builder.");
        goto fail;
    }
    err = LLVMOrcJITTargetMachineBuilderDetectHost(&jtmb);
    if (err != LLVMErrorSuccess) {
        aot_handle_llvm_errmsg(
            "quited to create LLVMOrcJITTargetMachineBuilderRef", err);
        goto fail;
    }
    LLVMOrcLLLazyJITBuilderSetNumCompileThreads(
        builder, WASM_ORC_JIT_COMPILE_THREAD_NUM);
    /* Ownership transfer:
       LLVMOrcJITTargetMachineBuilderRef -> LLVMOrcLLJITBuilderRef */
    LLVMOrcLLLazyJITBuilderSetJITTargetMachineBuilder(builder, jtmb);
    err = LLVMOrcCreateLLLazyJIT(&orc_jit, builder);
    if (err != LLVMErrorSuccess) {
        aot_handle_llvm_errmsg("quited to create llvm lazy orcjit instance",
                               err);
        goto fail;
    }
    /* Ownership transfer: LLVMOrcLLJITBuilderRef -> LLVMOrcLLJITRef */
    builder = null;
    /* Ownership transfer: local -> AOTCompContext */
    comp_ctx.orc_jit = orc_jit;
    orc_jit = null;
    ret = true;
fail:
    if (builder)
        LLVMOrcDisposeLLLazyJITBuilder(builder);
    if (orc_jit)
        LLVMOrcDisposeLLLazyJIT(orc_jit);
    return ret;
}
bool aot_compiler_init() {
    /* Initialize LLVM environment */
    LLVMInitializeCore(LLVMGetGlobalPassRegistry());
    /* Init environment of native for JIT compiler */
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    return true;
}
void aot_compiler_destroy() {
    LLVMShutdown();
}
AOTCompContext* aot_create_comp_context(AOTCompData* comp_data, aot_comp_option_t option) {
    AOTCompContext* comp_ctx = void, ret = null;
    LLVMTargetRef target = void;
    char* triple = null, triple_norm = void, arch = void, abi = void;
    char* cpu = null, features = void; char[128] buf = void;
    char* triple_norm_new = null, cpu_new = null;
    char* err = null, fp_round = "round.tonearest", fp_exce = "fpexcept.strict";
    char[32] triple_buf = 0; char[128] features_buf = 0;
    uint opt_level = void, size_level = void, i = void;
    LLVMCodeModel code_model = void;
    LLVMTargetDataRef target_data_ref = void;
    /* Allocate memory */
    if (((comp_ctx = wasm_runtime_malloc(AOTCompContext.sizeof)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return null;
    }
    memset(comp_ctx, 0, AOTCompContext.sizeof);
    comp_ctx.comp_data = comp_data;
    /* Create LLVM context, module and builder */
    comp_ctx.orc_thread_safe_context = LLVMOrcCreateNewThreadSafeContext();
    if (!comp_ctx.orc_thread_safe_context) {
        aot_set_last_error("create LLVM ThreadSafeContext failed.");
        goto fail;
    }
    /* Get a reference to the underlying LLVMContext, note:
         different from non LAZY JIT mode, no need to dispose this context,
         if will be disposed when the thread safe context is disposed */
    if (((comp_ctx.context = LLVMOrcThreadSafeContextGetContext(
              comp_ctx.orc_thread_safe_context)) == 0)) {
        aot_set_last_error("get context from LLVM ThreadSafeContext failed.");
        goto fail;
    }
    if (((comp_ctx.builder = LLVMCreateBuilderInContext(comp_ctx.context)) == 0)) {
        aot_set_last_error("create LLVM builder failed.");
        goto fail;
    }
    /* Create LLVM module for each jit function, note:
       different from non ORC JIT mode, no need to dispose it,
       it will be disposed when the thread safe context is disposed */
    if (((comp_ctx.module_ = LLVMModuleCreateWithNameInContext(
              "WASM Module", comp_ctx.context)) == 0)) {
        aot_set_last_error("create LLVM module failed.");
        goto fail;
    }
    if (BH_LIST_ERROR == bh_list_init(&comp_ctx.native_symbols)) {
        goto fail;
    }
    if (option.enable_bulk_memory)
        comp_ctx.enable_bulk_memory = true;
    if (option.enable_thread_mgr)
        comp_ctx.enable_thread_mgr = true;
    if (option.enable_tail_call)
        comp_ctx.enable_tail_call = true;
    if (option.enable_ref_types)
        comp_ctx.enable_ref_types = true;
    if (option.enable_aux_stack_frame)
        comp_ctx.enable_aux_stack_frame = true;
    if (option.enable_aux_stack_check)
        comp_ctx.enable_aux_stack_check = true;
    if (option.is_indirect_mode)
        comp_ctx.is_indirect_mode = true;
    if (option.disable_llvm_intrinsics)
        comp_ctx.disable_llvm_intrinsics = true;
    if (option.disable_llvm_lto)
        comp_ctx.disable_llvm_lto = true;
    comp_ctx.opt_level = option.opt_level;
    comp_ctx.size_level = option.size_level;
    comp_ctx.custom_sections_wp = option.custom_sections;
    comp_ctx.custom_sections_count = option.custom_sections_count;
    if (option.is_jit_mode) {
        comp_ctx.is_jit_mode = true;
        /* Create TargetMachine */
        if (!create_target_machine_detect_host(comp_ctx))
            goto fail;
        /* Create LLJIT Instance */
        if (!orc_jit_create(comp_ctx))
            goto fail;
        comp_ctx.enable_bound_check = true;
        /* Always enable stack boundary check if `bounds-checks`
           is enabled */
        comp_ctx.enable_stack_bound_check = true;
    }
    else {
        /* Create LLVM target machine */
        arch = option.target_arch;
        abi = option.target_abi;
        cpu = option.target_cpu;
        features = option.cpu_features;
        opt_level = option.opt_level;
        size_level = option.size_level;
        /* verify external llc compiler */
        comp_ctx.external_llc_compiler = getenv("WAMRC_LLC_COMPILER");
        if (comp_ctx.external_llc_compiler) {
            if (access(comp_ctx.external_llc_compiler, X_OK) != 0) {
                LOG_WARNING("WAMRC_LLC_COMPILER [%s] not found, fallback to "
                            ~ "default pipeline",
                            comp_ctx.external_llc_compiler);
                comp_ctx.external_llc_compiler = null;
            }
            else {
                comp_ctx.llc_compiler_flags = getenv("WAMRC_LLC_FLAGS");
                LOG_VERBOSE("Using external LLC compiler [%s]",
                            comp_ctx.external_llc_compiler);
            }
        }
        /* verify external asm compiler */
        if (!comp_ctx.external_llc_compiler) {
            comp_ctx.external_asm_compiler = getenv("WAMRC_ASM_COMPILER");
            if (comp_ctx.external_asm_compiler) {
                if (access(comp_ctx.external_asm_compiler, X_OK) != 0) {
                    LOG_WARNING(
                        "WAMRC_ASM_COMPILER [%s] not found, fallback to "
                        ~ "default pipeline",
                        comp_ctx.external_asm_compiler);
                    comp_ctx.external_asm_compiler = null;
                }
                else {
                    comp_ctx.asm_compiler_flags = getenv("WAMRC_ASM_FLAGS");
                    LOG_VERBOSE("Using external ASM compiler [%s]",
                                comp_ctx.external_asm_compiler);
                }
            }
        }
        if (arch) {
            /* Add default sub-arch if not specified */
            if (!strcmp(arch, "arm"))
                arch = "armv4";
            else if (!strcmp(arch, "armeb"))
                arch = "armv4eb";
            else if (!strcmp(arch, "thumb"))
                arch = "thumbv4t";
            else if (!strcmp(arch, "thumbeb"))
                arch = "thumbv4teb";
            else if (!strcmp(arch, "aarch64"))
                arch = "aarch64v8";
            else if (!strcmp(arch, "aarch64_be"))
                arch = "aarch64_bev8";
        }
        /* Check target arch */
        if (arch && !check_target_arch(arch)) {
            if (!strcmp(arch, "help"))
                print_supported_targets();
            else
                aot_set_last_error(
                    "Invalid target. "
                    ~ "Use --target=help to list all supported targets");
            goto fail;
        }
        /* Check target ABI */
        if (abi && !check_target_abi(abi)) {
            if (!strcmp(abi, "help"))
                print_supported_abis();
            else
                aot_set_last_error(
                    "Invalid target ABI. "
                    ~ "Use --target-abi=help to list all supported ABI");
            goto fail;
        }
        /* Set default abi for riscv target */
        if (arch && !strncmp(arch, "riscv", 5) && !abi) {
            if (!strcmp(arch, "riscv64"))
                abi = "lp64d";
            else
                abi = "ilp32d";
        }
        if (abi) {
            /* Construct target triple: <arch>-<vendor>-<sys>-<abi> */
            const(char)* vendor_sys = void;
            char* arch1 = arch; char[32] default_arch = 0;
            if (!arch1) {
                char* default_triple = LLVMGetDefaultTargetTriple();
                if (!default_triple) {
                    aot_set_last_error(
                        "llvm get default target triple failed.");
                    goto fail;
                }
                vendor_sys = strstr(default_triple, "-");
                bh_assert(vendor_sys);
                bh_memcpy_s(default_arch.ptr, default_arch.sizeof, default_triple,
                            cast(uint)(vendor_sys - default_triple));
                arch1 = default_arch;
                LLVMDisposeMessage(default_triple);
            }
            /**
             * Set <vendor>-<sys> according to abi to generate the object file
             * with the correct file format which might be different from the
             * default object file format of the host, e.g., generating AOT file
             * for Windows/MacOS under Linux host, or generating AOT file for
             * Linux/MacOS under Windows host.
             */
            if (!strcmp(abi, "msvc")) {
                if (!strcmp(arch1, "i386"))
                    vendor_sys = "-pc-win32-";
                else
                    vendor_sys = "-pc-windows-";
            }
            else {
                vendor_sys = "-pc-linux-";
            }
            bh_assert(strlen(arch1) + strlen(vendor_sys) + strlen(abi)
                      < triple_buf.sizeof);
            bh_memcpy_s(triple_buf.ptr, cast(uint)triple_buf.sizeof, arch1,
                        cast(uint)strlen(arch1));
            bh_memcpy_s(triple_buf.ptr + strlen(arch1),
                        cast(uint)(triple_buf.length - strlen(arch1)),
                        vendor_sys, cast(uint)strlen(vendor_sys));
            bh_memcpy_s(triple_buf.ptr + strlen(arch1) + strlen(vendor_sys),
                        cast(uint)(triple_buf.length - strlen(arch1)
                                 - strlen(vendor_sys)),
                        abi, cast(uint)strlen(abi));
            triple = triple_buf;
        }
        else if (arch) {
            /* Construct target triple: <arch>-<vendor>-<sys>-<abi> */
            const(char)* vendor_sys = void;
            char* default_triple = LLVMGetDefaultTargetTriple();
            if (!default_triple) {
                aot_set_last_error("llvm get default target triple failed.");
                goto fail;
            }
            if (strstr(default_triple, "windows")) {
                vendor_sys = "-pc-windows-";
                if (!abi)
                    abi = "msvc";
            }
            else if (strstr(default_triple, "win32")) {
                vendor_sys = "-pc-win32-";
                if (!abi)
                    abi = "msvc";
            }
            else {
                vendor_sys = "-pc-linux-";
                if (!abi)
                    abi = "gnu";
            }
            LLVMDisposeMessage(default_triple);
            bh_assert(strlen(arch) + strlen(vendor_sys) + strlen(abi)
                      < triple_buf.sizeof);
            bh_memcpy_s(triple_buf.ptr, cast(uint)triple_buf.sizeof, arch,
                        cast(uint)strlen(arch));
            bh_memcpy_s(triple_buf.ptr + strlen(arch),
                        cast(uint)(triple_buf.length - strlen(arch)), vendor_sys,
                        cast(uint)strlen(vendor_sys));
            bh_memcpy_s(triple_buf.ptr + strlen(arch) + strlen(vendor_sys),
                        cast(uint)(triple_buf.length - strlen(arch)
                                 - strlen(vendor_sys)),
                        abi, cast(uint)strlen(abi));
            triple = triple_buf;
        }
        if (!cpu && features) {
            aot_set_last_error("cpu isn't specified for cpu features.");
            goto fail;
        }
        if (!triple && !cpu) {
            /* Get a triple for the host machine */
            if (((triple_norm = triple_norm_new =
                      LLVMGetDefaultTargetTriple()) == 0)) {
                aot_set_last_error("llvm get default target triple failed.");
                goto fail;
            }
            /* Get CPU name of the host machine */
            if (((cpu = cpu_new = LLVMGetHostCPUName()) == 0)) {
                aot_set_last_error("llvm get host cpu name failed.");
                goto fail;
            }
        }
        else if (triple) {
            /* Normalize a target triple */
            if (((triple_norm = triple_norm_new =
                      LLVMNormalizeTargetTriple(triple)) == 0)) {
                snprintf(buf.ptr, buf.sizeof,
                         "llvm normlalize target triple (%s) failed.", triple);
                aot_set_last_error(buf.ptr);
                goto fail;
            }
            if (!cpu)
                cpu = "";
        }
        else {
            /* triple is NULL, cpu isn't NULL */
            snprintf(buf.ptr, buf.sizeof, "target isn't specified for cpu %s.",
                     cpu);
            aot_set_last_error(buf.ptr);
            goto fail;
        }
        /* Add module flag and cpu feature for riscv target */
        if (arch && !strncmp(arch, "riscv", 5)) {
            LLVMMetadataRef meta_target_abi = void;
            if (((meta_target_abi = LLVMMDStringInContext2(comp_ctx.context,
                                                           abi, strlen(abi))) == 0)) {
                aot_set_last_error("create metadata string failed.");
                goto fail;
            }
            LLVMAddModuleFlag(comp_ctx.module_, LLVMModuleFlagBehaviorError,
                              "target-abi", strlen("target-abi"),
                              meta_target_abi);
            if (!strcmp(abi, "lp64d") || !strcmp(abi, "ilp32d")) {
                if (features) {
                    snprintf(features_buf.ptr, features_buf.sizeof, "%s%s",
                             features, ",+d");
                    features = features_buf;
                }
                else
                    features = "+d";
            }
        }
        if (!features)
            features = "";
        /* Get target with triple, note that LLVMGetTargetFromTriple()
           return 0 when success, but not true. */
        if (LLVMGetTargetFromTriple(triple_norm, &target, &err) != 0) {
            if (err) {
                LLVMDisposeMessage(err);
                err = null;
            }
            snprintf(buf.ptr, buf.sizeof,
                     "llvm get target from triple (%s) failed", triple_norm);
            aot_set_last_error(buf.ptr);
            goto fail;
        }
        /* Save target arch */
        get_target_arch_from_triple(triple_norm, comp_ctx.target_arch,
                                    typeof(comp_ctx.target_arch).sizeof);
        if (option.bounds_checks == 1 || option.bounds_checks == 0) {
            /* Set by user */
            comp_ctx.enable_bound_check =
                (option.bounds_checks == 1) ? true : false;
        }
        else {
            /* Unset by user, use default value */
            if (strstr(comp_ctx.target_arch, "64")
                && !option.is_sgx_platform) {
                comp_ctx.enable_bound_check = false;
            }
            else {
                comp_ctx.enable_bound_check = true;
            }
        }
        if (comp_ctx.enable_bound_check) {
            /* Always enable stack boundary check if `bounds-checks`
               is enabled */
            comp_ctx.enable_stack_bound_check = true;
        }
        else {
            /* When `bounds-checks` is disabled, we set stack boundary
               check status according to the input option */
            comp_ctx.enable_stack_bound_check =
                (option.stack_bounds_checks == 1) ? true : false;
        }
        os_printf("Create AoT compiler with:\n");
        os_printf("  target:        %s\n", comp_ctx.target_arch);
        os_printf("  target cpu:    %s\n", cpu);
        os_printf("  cpu features:  %s\n", features);
        os_printf("  opt level:     %d\n", opt_level);
        os_printf("  size level:    %d\n", size_level);
        switch (option.output_format) {
            case AOT_LLVMIR_UNOPT_FILE:
                os_printf("  output format: unoptimized LLVM IR\n");
                break;
            case AOT_LLVMIR_OPT_FILE:
                os_printf("  output format: optimized LLVM IR\n");
                break;
            case AOT_FORMAT_FILE:
                os_printf("  output format: AoT file\n");
                break;
            case AOT_OBJECT_FILE:
                os_printf("  output format: native object file\n");
                break;
        default: break;}
        if (!LLVMTargetHasTargetMachine(target)) {
            snprintf(buf.ptr, buf.sizeof,
                     "no target machine for this target (%s).", triple_norm);
            aot_set_last_error(buf.ptr);
            goto fail;
        }
        /* Report error if target isn't arc and hasn't asm backend.
           For arc target, as it cannot emit to memory buffer of elf file
           currently, we let it emit to assembly file instead, and then call
           arc-gcc to compile
           asm file to elf file, and read elf file to memory buffer. */
        if (strncmp(comp_ctx.target_arch, "arc", 3)
            && !LLVMTargetHasAsmBackend(target)) {
            snprintf(buf.ptr, buf.sizeof, "no asm backend for this target (%s).",
                     LLVMGetTargetName(target));
            aot_set_last_error(buf.ptr);
            goto fail;
        }
        /* Set code model */
        if (size_level == 0)
            code_model = LLVMCodeModelLarge;
        else if (size_level == 1)
            code_model = LLVMCodeModelMedium;
        else if (size_level == 2)
            code_model = LLVMCodeModelKernel;
        else
            code_model = LLVMCodeModelSmall;
        /* Create the target machine */
        if (((comp_ctx.target_machine = LLVMCreateTargetMachine(
                  target, triple_norm, cpu, features, opt_level,
                  LLVMRelocStatic, code_model)) == 0)) {
            aot_set_last_error("create LLVM target machine failed.");
            goto fail;
        }
    }
    if (option.enable_simd && strcmp(comp_ctx.target_arch, "x86_64") != 0
        && strncmp(comp_ctx.target_arch, "aarch64", 7) != 0) {
        /* Disable simd if it isn't supported by target arch */
        option.enable_simd = false;
    }
    if (option.enable_simd) {
        char* tmp = void;
        bool check_simd_ret = void;
        comp_ctx.enable_simd = true;
        if (((tmp = LLVMGetTargetMachineCPU(comp_ctx.target_machine)) == 0)) {
            aot_set_last_error("get CPU from Target Machine fail");
            goto fail;
        }
        check_simd_ret =
            aot_check_simd_compatibility(comp_ctx.target_arch, tmp);
        LLVMDisposeMessage(tmp);
        if (!check_simd_ret) {
            aot_set_last_error("SIMD compatibility check failed, "
                               ~ "try adding --cpu=<cpu> to specify a cpu "
                               ~ "or adding --disable-simd to disable SIMD");
            goto fail;
        }
    }
    if (((target_data_ref =
              LLVMCreateTargetDataLayout(comp_ctx.target_machine)) == 0)) {
        aot_set_last_error("create LLVM target data layout failed.");
        goto fail;
    }
    comp_ctx.pointer_size = LLVMPointerSize(target_data_ref);
    LLVMDisposeTargetData(target_data_ref);
    comp_ctx.optimize = true;
    if (option.output_format == AOT_LLVMIR_UNOPT_FILE)
        comp_ctx.optimize = false;
    /* Create metadata for llvm float experimental constrained intrinsics */
    if (((comp_ctx.fp_rounding_mode = LLVMMDStringInContext(
              comp_ctx.context, fp_round, cast(uint)strlen(fp_round))) == 0)
        || ((comp_ctx.fp_exception_behavior = LLVMMDStringInContext(
                 comp_ctx.context, fp_exce, cast(uint)strlen(fp_exce))) == 0)) {
        aot_set_last_error("create float llvm metadata failed.");
        goto fail;
    }
    if (!aot_set_llvm_basic_types(&comp_ctx.basic_types, comp_ctx.context)) {
        aot_set_last_error("create LLVM basic types failed.");
        goto fail;
    }
    if (!aot_create_llvm_consts(&comp_ctx.llvm_consts, comp_ctx)) {
        aot_set_last_error("create LLVM const values failed.");
        goto fail;
    }
    /* set exec_env data type to int8** */
    comp_ctx.exec_env_type = comp_ctx.basic_types.int8_pptr_type;
    /* set aot_inst data type to int8* */
    comp_ctx.aot_inst_type = INT8_PTR_TYPE;
    /* Create function context for each function */
    comp_ctx.func_ctx_count = comp_data.func_count;
    if (comp_data.func_count > 0
        && ((comp_ctx.func_ctxes =
                 aot_create_func_contexts(comp_data, comp_ctx)) == 0))
        goto fail;
    if (cpu) {
        uint len = cast(uint)strlen(cpu) + 1;
        if (((comp_ctx.target_cpu = wasm_runtime_malloc(len)) == 0)) {
            aot_set_last_error("allocate memory failed");
            goto fail;
        }
        bh_memcpy_s(comp_ctx.target_cpu, len, cpu, len);
    }
    if (comp_ctx.disable_llvm_intrinsics)
        aot_intrinsic_fill_capability_flags(comp_ctx);
    ret = comp_ctx;
fail:
    if (triple_norm_new)
        LLVMDisposeMessage(triple_norm_new);
    if (cpu_new)
        LLVMDisposeMessage(cpu_new);
    if (!ret)
        aot_destroy_comp_context(comp_ctx);
    cast(void)i;
    return ret;
}
void aot_destroy_comp_context(AOTCompContext* comp_ctx) {
    if (!comp_ctx)
        return;
    if (comp_ctx.target_machine)
        LLVMDisposeTargetMachine(comp_ctx.target_machine);
    if (comp_ctx.builder)
        LLVMDisposeBuilder(comp_ctx.builder);
    if (comp_ctx.orc_thread_safe_context)
        LLVMOrcDisposeThreadSafeContext(comp_ctx.orc_thread_safe_context);
    /* Note: don't dispose comp_ctx->context and comp_ctx->module as
       they are disposed when disposing the thread safe context */
    /* Has to be the last one */
    if (comp_ctx.orc_jit)
        LLVMOrcDisposeLLLazyJIT(comp_ctx.orc_jit);
    if (comp_ctx.func_ctxes)
        aot_destroy_func_contexts(comp_ctx.func_ctxes,
                                  comp_ctx.func_ctx_count);
    if (bh_list_length(&comp_ctx.native_symbols) > 0) {
        AOTNativeSymbol* sym = bh_list_first_elem(&comp_ctx.native_symbols);
        while (sym) {
            AOTNativeSymbol* t = bh_list_elem_next(sym);
            bh_list_remove(&comp_ctx.native_symbols, sym);
            wasm_runtime_free(sym);
            sym = t;
        }
    }
    if (comp_ctx.target_cpu) {
        wasm_runtime_free(comp_ctx.target_cpu);
    }
    wasm_runtime_free(comp_ctx);
}
private bool insert_native_symbol(AOTCompContext* comp_ctx, const(char)* symbol, int idx) {
    AOTNativeSymbol* sym = wasm_runtime_malloc(AOTNativeSymbol.sizeof);
    if (!sym) {
        aot_set_last_error("alloc native symbol failed.");
        return false;
    }
    memset(sym, 0, AOTNativeSymbol.sizeof);
    bh_assert(strlen(symbol) <= typeof(sym.symbol).sizeof);
    snprintf(sym.symbol, typeof(sym.symbol).sizeof, "%s", symbol);
    sym.index = idx;
    if (BH_LIST_ERROR == bh_list_insert(&comp_ctx.native_symbols, sym)) {
        wasm_runtime_free(sym);
        aot_set_last_error("insert native symbol to list failed.");
        return false;
    }
    return true;
}
int aot_get_native_symbol_index(AOTCompContext* comp_ctx, const(char)* symbol) {
    int idx = -1;
    AOTNativeSymbol* sym = null;
    sym = bh_list_first_elem(&comp_ctx.native_symbols);
    /* Lookup an existing symobl record */
    while (sym) {
        if (strcmp(sym.symbol, symbol) == 0) {
            idx = sym.index;
            break;
        }
        sym = bh_list_elem_next(sym);
    }
    /* Given symbol is not exist in list, then we alloc a new index for it */
    if (idx < 0) {
        if (comp_ctx.pointer_size == uint32.sizeof
            && (!strncmp(symbol, "f64#", 4) || !strncmp(symbol, "i64#", 4))) {
            idx = bh_list_length(&comp_ctx.native_symbols);
            /* Add 4 bytes padding on 32-bit target to make sure that
               the f64 const is stored on 8-byte aligned address */
            if (idx & 1) {
                if (!insert_native_symbol(comp_ctx, "__ignore", idx)) {
                    return -1;
                }
            }
        }
        idx = bh_list_length(&comp_ctx.native_symbols);
        if (!insert_native_symbol(comp_ctx, symbol, idx)) {
            return -1;
        }
        if (comp_ctx.pointer_size == uint32.sizeof
            && (!strncmp(symbol, "f64#", 4) || !strncmp(symbol, "i64#", 4))) {
            /* f64 const occupies 2 pointer slots on 32-bit target */
            if (!insert_native_symbol(comp_ctx, "__ignore", idx + 1)) {
                return -1;
            }
        }
    }
    return idx;
}
void aot_value_stack_push(AOTValueStack* stack, AOTValue* value) {
    if (!stack.value_list_head)
        stack.value_list_head = stack.value_list_end = value;
    else {
        stack.value_list_end.next = value;
        value.prev = stack.value_list_end;
        stack.value_list_end = value;
    }
}
AOTValue* aot_value_stack_pop(AOTValueStack* stack) {
    AOTValue* value = stack.value_list_end;
    bh_assert(stack.value_list_end);
    if (stack.value_list_head == stack.value_list_end)
        stack.value_list_head = stack.value_list_end = null;
    else {
        stack.value_list_end = stack.value_list_end.prev;
        stack.value_list_end.next = null;
        value.prev = null;
    }
    return value;
}
void aot_value_stack_destroy(AOTValueStack* stack) {
    AOTValue* value = stack.value_list_head, p = void;
    while (value) {
        p = value.next;
        wasm_runtime_free(value);
        value = p;
    }
    stack.value_list_head = null;
    stack.value_list_end = null;
}
void aot_block_stack_push(AOTBlockStack* stack, AOTBlock* block) {
    if (!stack.block_list_head)
        stack.block_list_head = stack.block_list_end = block;
    else {
        stack.block_list_end.next = block;
        block.prev = stack.block_list_end;
        stack.block_list_end = block;
    }
}
AOTBlock* aot_block_stack_pop(AOTBlockStack* stack) {
    AOTBlock* block = stack.block_list_end;
    bh_assert(stack.block_list_end);
    if (stack.block_list_head == stack.block_list_end)
        stack.block_list_head = stack.block_list_end = null;
    else {
        stack.block_list_end = stack.block_list_end.prev;
        stack.block_list_end.next = null;
        block.prev = null;
    }
    return block;
}
void aot_block_stack_destroy(AOTBlockStack* stack) {
    AOTBlock* block = stack.block_list_head, p = void;
    while (block) {
        p = block.next;
        aot_value_stack_destroy(&block.value_stack);
        aot_block_destroy(block);
        block = p;
    }
    stack.block_list_head = null;
    stack.block_list_end = null;
}
void aot_block_destroy(AOTBlock* block) {
    aot_value_stack_destroy(&block.value_stack);
    if (block.param_types)
        wasm_runtime_free(block.param_types);
    if (block.param_phis)
        wasm_runtime_free(block.param_phis);
    if (block.else_param_phis)
        wasm_runtime_free(block.else_param_phis);
    if (block.result_types)
        wasm_runtime_free(block.result_types);
    if (block.result_phis)
        wasm_runtime_free(block.result_phis);
    wasm_runtime_free(block);
}
bool aot_checked_addr_list_add(AOTFuncContext* func_ctx, uint local_idx, uint offset, uint bytes) {
    AOTCheckedAddr* node = func_ctx.checked_addr_list;
    if (((node = wasm_runtime_malloc(AOTCheckedAddr.sizeof)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return false;
    }
    node.local_idx = local_idx;
    node.offset = offset;
    node.bytes = bytes;
    node.next = func_ctx.checked_addr_list;
    func_ctx.checked_addr_list = node;
    return true;
}
void aot_checked_addr_list_del(AOTFuncContext* func_ctx, uint local_idx) {
    AOTCheckedAddr* node = func_ctx.checked_addr_list;
    AOTCheckedAddr* node_prev = null, node_next = void;
    while (node) {
        node_next = node.next;
        if (node.local_idx == local_idx) {
            if (!node_prev)
                func_ctx.checked_addr_list = node_next;
            else
                node_prev.next = node_next;
            wasm_runtime_free(node);
        }
        else {
            node_prev = node;
        }
        node = node_next;
    }
}
bool aot_checked_addr_list_find(AOTFuncContext* func_ctx, uint local_idx, uint offset, uint bytes) {
    AOTCheckedAddr* node = func_ctx.checked_addr_list;
    while (node) {
        if (node.local_idx == local_idx && node.offset == offset
            && node.bytes >= bytes) {
            return true;
        }
        node = node.next;
    }
    return false;
}
void aot_checked_addr_list_destroy(AOTFuncContext* func_ctx) {
    AOTCheckedAddr* node = func_ctx.checked_addr_list, node_next = void;
    while (node) {
        node_next = node.next;
        wasm_runtime_free(node);
        node = node_next;
    }
    func_ctx.checked_addr_list = null;
}
bool aot_build_zero_function_ret(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, AOTFuncType* func_type) {
    LLVMValueRef ret = null;
    if (func_type.result_count) {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
                ret = LLVMBuildRet(comp_ctx.builder, I32_ZERO);
                break;
            case VALUE_TYPE_I64:
                ret = LLVMBuildRet(comp_ctx.builder, I64_ZERO);
                break;
            case VALUE_TYPE_F32:
                ret = LLVMBuildRet(comp_ctx.builder, F32_ZERO);
                break;
            case VALUE_TYPE_F64:
                ret = LLVMBuildRet(comp_ctx.builder, F64_ZERO);
                break;
            case VALUE_TYPE_V128:
                ret =
                    LLVMBuildRet(comp_ctx.builder, LLVM_CONST(i64x2_vec_zero));
                break;
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
                ret = LLVMBuildRet(comp_ctx.builder, REF_NULL);
                break;
            default:
                bh_assert(0);
        }
    }
    else {
        ret = LLVMBuildRetVoid(comp_ctx.builder);
    }
    if (!ret) {
        aot_set_last_error("llvm build ret failed.");
        return false;
    }
    return true;
}
private LLVMValueRef __call_llvm_intrinsic(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, const(char)* name, LLVMTypeRef ret_type, LLVMTypeRef* param_types, int param_count, LLVMValueRef* param_values) {
    LLVMValueRef func = void, ret = void;
    LLVMTypeRef func_type = void;
    const(char)* symname = void;
    int func_idx = void;
    if (comp_ctx.disable_llvm_intrinsics
        && aot_intrinsic_check_capability(comp_ctx, name)) {
        if (func_ctx == null) {
            aot_set_last_error_v("invalid func_ctx for intrinsic: %s", name);
            return null;
        }
        if (((func_type = LLVMFunctionType(ret_type, param_types,
                                           cast(uint)param_count, false)) == 0)) {
            aot_set_last_error("create LLVM intrinsic function type failed.");
            return null;
        }
        if (((func_type = LLVMPointerType(func_type, 0)) == 0)) {
            aot_set_last_error(
                "create LLVM intrinsic function pointer type failed.");
            return null;
        }
        if (((symname = aot_intrinsic_get_symbol(name)) == 0)) {
            aot_set_last_error_v("runtime intrinsic not implemented: %s\n",
                                 name);
            return null;
        }
        func_idx =
            aot_get_native_symbol_index(cast(AOTCompContext*)comp_ctx, symname);
        if (func_idx < 0) {
            aot_set_last_error_v("get runtime intrinsc index failed: %s\n",
                                 name);
            return null;
        }
        if (((func = aot_get_func_from_table(comp_ctx, func_ctx.native_symbol,
                                             func_type, func_idx)) == 0)) {
            aot_set_last_error_v("get runtime intrinsc failed: %s\n", name);
            return null;
        }
    }
    else {
        /* Declare llvm intrinsic function if necessary */
        if (((func = LLVMGetNamedFunction(func_ctx.module_, name)) == 0)) {
            if (((func_type = LLVMFunctionType(ret_type, param_types,
                                               cast(uint)param_count, false)) == 0)) {
                aot_set_last_error(
                    "create LLVM intrinsic function type failed.");
                return null;
            }
            if (((func = LLVMAddFunction(func_ctx.module_, name, func_type)) == 0)) {
                aot_set_last_error("add LLVM intrinsic function failed.");
                return null;
            }
        }
    }
    /* Call the LLVM intrinsic function */
    if (((ret = LLVMBuildCall(comp_ctx.builder, func, param_values, cast(uint)param_count, "call")) == 0)) {
        aot_set_last_error("llvm build intrinsic call failed.");
        return null;
    }
    return ret;
}
LLVMValueRef aot_call_llvm_intrinsic(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, const(char)* intrinsic, LLVMTypeRef ret_type, LLVMTypeRef* param_types, int param_count, ...) {
    LLVMValueRef* param_values = void; LLVMValueRef ret = void;
    va_list argptr = void;
    ulong total_size = void;
    int i = 0;
    /* Create param values */
    total_size = LLVMValueRef.sizeof * cast(ulong)param_count;
    if (total_size >= UINT32_MAX
        || ((param_values = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
        aot_set_last_error("allocate memory for param values failed.");
        return false;
    }
    /* Load each param value */
    va_start(argptr, param_count);
    while (i < param_count)
        param_values[i++] = va_arg(argptr, LLVMValueRef);
    va_end(argptr);
    ret = __call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic, ret_type,
                                param_types, param_count, param_values);
    wasm_runtime_free(param_values);
    return ret;
}
LLVMValueRef aot_call_llvm_intrinsic_v(const(AOTCompContext)* comp_ctx, const(AOTFuncContext)* func_ctx, const(char)* intrinsic, LLVMTypeRef ret_type, LLVMTypeRef* param_types, int param_count, va_list param_value_list) {
    LLVMValueRef* param_values = void; LLVMValueRef ret = void;
    ulong total_size = void;
    int i = 0;
    /* Create param values */
    total_size = LLVMValueRef.sizeof * cast(ulong)param_count;
    if (total_size >= UINT32_MAX
        || ((param_values = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
        aot_set_last_error("allocate memory for param values failed.");
        return false;
    }
    /* Load each param value */
    while (i < param_count)
        param_values[i++] = va_arg(param_value_list, LLVMValueRef);
    ret = __call_llvm_intrinsic(comp_ctx, func_ctx, intrinsic, ret_type,
                                param_types, param_count, param_values);
    wasm_runtime_free(param_values);
    return ret;
}
LLVMValueRef aot_get_func_from_table(const(AOTCompContext)* comp_ctx, LLVMValueRef base, LLVMTypeRef func_type, int index) {
    LLVMValueRef func = void;
    LLVMValueRef func_addr = void;
    if (((func_addr = I32_CONST(index)) == 0)) {
        aot_set_last_error("construct function index failed.");
        goto fail;
    }
    if (((func_addr =
              LLVMBuildInBoundsGEP(comp_ctx.builder, base, &func_addr, 1, "func_addr")) == 0)) {
        aot_set_last_error("get function addr by index failed.");
        goto fail;
    }
    func =
        LLVMBuildLoad(comp_ctx.builder, func_addr, "func_tmp");
    if (func == null) {
        aot_set_last_error("get function pointer failed.");
        goto fail;
    }
    if (((func =
              LLVMBuildBitCast(comp_ctx.builder, func, func_type, "func")) == 0)) {
        aot_set_last_error("cast function fialed.");
        goto fail;
    }
    return func;
fail:
    return null;
}
LLVMValueRef aot_load_const_from_table(AOTCompContext* comp_ctx, LLVMValueRef base, const(WASMValue)* value, ubyte value_type) {
    LLVMValueRef const_index = void, const_addr = void, const_value = void;
    LLVMTypeRef const_ptr_type = void, const_type = void;
    char[128] buf = 0;
    int index = void;
    switch (value_type) {
        case VALUE_TYPE_I32:
            /* Store the raw int bits of i32 const as a hex string */
            snprintf(buf.ptr, buf.sizeof, "i32#%08X", value.i32);
            const_ptr_type = INT32_PTR_TYPE;
            const_type = I32_TYPE;
            break;
        case VALUE_TYPE_I64:
            /* Store the raw int bits of i64 const as a hex string */
            snprintf(buf.ptr, buf.sizeof, "i64#%016X", value.i64);
            const_ptr_type = INT64_PTR_TYPE;
            const_type = I64_TYPE;
            break;
        case VALUE_TYPE_F32:
            /* Store the raw int bits of f32 const as a hex string */
            snprintf(buf.ptr, buf.sizeof, "f32#%08X", value.i32);
            const_ptr_type = F32_PTR_TYPE;
            const_type = F32_TYPE;
            break;
        case VALUE_TYPE_F64:
            /* Store the raw int bits of f64 const as a hex string */
            snprintf(buf.ptr, buf.sizeof, "f64#%016X", value.i64);
            const_ptr_type = F64_PTR_TYPE;
            const_type = F64_TYPE;
            break;
        default:
            bh_assert(0);
            return null;
    }
    /* Load f32/f64 const from exec_env->native_symbol[index] */
    index = aot_get_native_symbol_index(comp_ctx, buf.ptr);
    if (index < 0) {
        return null;
    }
    if (((const_index = I32_CONST(index)) == 0)) {
        aot_set_last_error("construct const index failed.");
        return null;
    }
    if (((const_addr =
              LLVMBuildInBoundsGEP(comp_ctx.builder, base, &const_index, 1, "const_addr_tmp")) == 0)) {
        aot_set_last_error("get const addr by index failed.");
        return null;
    }
    if (((const_addr = LLVMBuildBitCast(comp_ctx.builder, const_addr,
                                        const_ptr_type, "const_addr")) == 0)) {
        aot_set_last_error("cast const fialed.");
        return null;
    }
    if (((const_value = LLVMBuildLoad(comp_ctx.builder, const_addr, "const_value")) == 0)) {
        aot_set_last_error("load const failed.");
        return null;
    }
    cast(void)const_type;
    return const_value;
}
