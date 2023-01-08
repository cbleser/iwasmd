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
module tagion.iwasm.fast_jit.fe.jit_emit_function;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import core.stdc.stdint : uintptr_t;
import tagion.iwasm.basic;
import tagion.iwasm.fast_jit.fe.jit_emit_exception;
import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_codegen;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_frame;
import tagion.iwasm.fast_jit.jit_utils;
import tagion.iwasm.share.utils.bh_assert; 
//import tagion.iwasm.interpreter.wasm_runtime;
import tagion.iwasm.interpreter.wasm;
import tagion.iwasm.common.wasm_exec_env : WASMExecEnv;
private bool emit_callnative(JitCompContext* cc, JitReg native_func_reg, JitReg res, JitReg* params, uint param_count);
/* Prepare parameters for the function to call */
private bool pre_call(JitCompContext* cc, const(WASMType)* func_type) {
    JitReg value = void;
    uint i = void, outs_off = void;
    /* Prepare parameters for the function to call */
    outs_off =
        cc.total_frame_size + WASMInterpFrame.lp.offsetof
        + wasm_get_cell_num(func_type.types, func_type.param_count) * 4;
    for (i = 0; i < func_type.param_count; i++) {
        switch (func_type.types[func_type.param_count - 1 - i]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                POP_I32(value);
                outs_off -= 4;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(value, cc.fp_reg, cc.new_const_I32( outs_off))));
                break;
            case VALUE_TYPE_I64:
                POP_I64(value);
                outs_off -= 8;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI64(value, cc.fp_reg, cc.new_const_I32( outs_off))));
                break;
            case VALUE_TYPE_F32:
                POP_F32(value);
                outs_off -= 4;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF32(value, cc.fp_reg, cc.new_const_I32( outs_off))));
                break;
            case VALUE_TYPE_F64:
                POP_F64(value);
                outs_off -= 8;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF64(value, cc.fp_reg, cc.new_const_I32( outs_off))));
                break;
            default:
                bh_assert(0);
                goto fail;
        }
    }
    /* Commit sp as the callee may use it to store the results */
    gen_commit_sp_ip(cc.jit_frame);
    return true;
fail:
    return false;
}
/* Push results */
private bool post_return(JitCompContext* cc, const(WASMType)* func_type, JitReg first_res, bool update_committed_sp) {
    uint i = void, n = void;
    JitReg value = void;
    n = cc.jit_frame.sp - cc.jit_frame.lp;
    for (i = 0; i < func_type.result_count; i++) {
        switch (func_type.types[func_type.param_count + i]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                if (i == 0 && first_res) {
                    bh_assert(jit_reg_kind(first_res) == JitRegKind.I32);
                    value = first_res;
                }
                else {
                    value = cc.new_reg_I32;
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(value, cc.fp_reg, cc.new_const_I32( offset_of_local(n)))));
                }
                PUSH_I32(value);
                n++;
                break;
            case VALUE_TYPE_I64:
                if (i == 0 && first_res) {
                    bh_assert(jit_reg_kind(first_res) == JitRegKind.I64);
                    value = first_res;
                }
                else {
                    value = cc.new_reg_I64;
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(value, cc.fp_reg, cc.new_const_I32( offset_of_local(n)))));
                }
                PUSH_I64(value);
                n += 2;
                break;
            case VALUE_TYPE_F32:
                if (i == 0 && first_res) {
                    bh_assert(jit_reg_kind(first_res) == JitRegKind.F32);
                    value = first_res;
                }
                else {
                    value = cc.new_reg_F32;
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDF32(value, cc.fp_reg, cc.new_const_I32( offset_of_local(n)))));
                }
                cc.push_f32(value);
                n++;
                break;
            case VALUE_TYPE_F64:
                if (i == 0 && first_res) {
                    bh_assert(jit_reg_kind(first_res) == JitRegKind.F64);
                    value = first_res;
                }
                else {
                    value = cc.new_reg_F64;
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDF64(value, cc.fp_reg, cc.new_const_I32( offset_of_local(n)))));
                }
                PUSH_F64(value);
                n += 2;
                break;
            default:
                bh_assert(0);
                goto fail;
        }
    }
    if (update_committed_sp)
        /* Update the committed_sp as the callee has updated the frame sp */
        cc.jit_frame.committed_sp = cc.jit_frame.sp;
    return true;
fail:
    return false;
}
private bool pre_load(JitCompContext* cc, JitReg* argvs, const(WASMType)* func_type) {
    JitReg value = void;
    uint i = void;
    /* Prepare parameters for the function to call */
    for (i = 0; i < func_type.param_count; i++) {
        switch (func_type.types[func_type.param_count - 1 - i]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                POP_I32(value);
                argvs[func_type.param_count - 1 - i] = value;
                break;
            case VALUE_TYPE_I64:
                POP_I64(value);
                argvs[func_type.param_count - 1 - i] = value;
                break;
            case VALUE_TYPE_F32:
                POP_F32(value);
                argvs[func_type.param_count - 1 - i] = value;
                break;
            case VALUE_TYPE_F64:
                POP_F64(value);
                argvs[func_type.param_count - 1 - i] = value;
                break;
            default:
                bh_assert(0);
                goto fail;
        }
    }
    gen_commit_sp_ip(cc.jit_frame);
    return true;
fail:
    return false;
}
private JitReg create_first_res_reg(JitCompContext* cc, const(WASMType)* func_type) {
    if (func_type.result_count) {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                return cc.new_reg_I32;
            case VALUE_TYPE_I64:
                return cc.new_reg_I64;
            case VALUE_TYPE_F32:
                return cc.new_reg_F32;
            case VALUE_TYPE_F64:
                return cc.new_reg_F64;
            default:
                bh_assert(0);
                return 0;
        }
    }
    return 0;
}
bool jit_compile_op_call(JitCompContext* cc, uint func_idx, bool tail_call) {
    WASMModule* wasm_module = cc.cur_wasm_module;
    WASMFunctionImport* func_import = void;
    WASMFunction* func = void;
    WASMType* func_type = void;
    JitFrame* jit_frame = cc.jit_frame;
    JitReg fast_jit_func_ptrs = void, jitted_code = 0;
    JitReg native_func = void; JitReg* argvs = null, argvs1 = null; JitReg[5] func_params = void;
    JitReg native_addr_ptr = void, module_inst_reg = void, ret = void, res = void;
    uint jitted_func_idx = void, i = void;
    ulong total_size = void;
    const(char)* signature = null;
    /* Whether the argument is a pointer/str argument and
       need to call jit_check_app_addr_and_convert */
    bool is_pointer_arg = void;
    bool return_value = false;
    if (func_idx < wasm_module.import_function_count) {
        /* The function to call is an import function */
        func_import = &wasm_module.import_functions[func_idx].u.function_;
        func_type = func_import.func_type;
        /* Call fast_jit_invoke_native in some cases */
        if (!func_import.func_ptr_linked /* import func hasn't been linked */
            || func_import.call_conv_wasm_c_api /* linked by wasm_c_api */
            || func_import.call_conv_raw /* registered as raw mode */
            || func_type.param_count >= 5 /* registered as normal mode, but
                                              jit_emit_callnative only supports
                                              maximum 6 registers now
                                              (include exec_nev) */) {
            JitReg[3] arg_regs = void;
            if (!pre_call(cc, func_type)) {
                goto fail;
            }
            /* Call fast_jit_invoke_native */
            ret = cc.new_reg_I32;
            arg_regs[0] = cc.exec_env_reg;
            arg_regs[1] = cc.new_const_I32( func_idx);
            arg_regs[2] = cc.fp_reg;
            if (!jit_emit_callnative(cc, &fast_jit_invoke_native, ret, arg_regs.ptr,
                                     3)) {
                goto fail;
            }
            /* Convert the return value from bool to uint32 */
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(ret, ret, cc.new_const_I32( 0xFF))));
            /* Check whether there is exception thrown */
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, ret, cc.new_const_I32( 0))));
            if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BEQ,
                                    cc.cmp_reg, null)) {
                goto fail;
            }
            if (!post_return(cc, func_type, 0, true)) {
                goto fail;
            }
            return true;
        }
        /* Import function was registered as normal mode, and its argument count
           is no more than 5, we directly call it */
        signature = func_import.signature;
        bh_assert(signature !is null);
        /* Allocate memory for argvs*/
        total_size = JitReg.sizeof * cast(ulong)(func_type.param_count);
        if (total_size > 0) {
            if (total_size >= uint.max
                || ((argvs = jit_malloc!uint(total_size)) is null)) {
                goto fail;
            }
        }
        /* Pop function params from stack and store them into argvs */
        if (!pre_load(cc, argvs, func_type)) {
            goto fail;
        }
        ret = cc.new_reg_I32;
        func_params[0] = module_inst_reg = jit_frame.module_inst_reg;
        func_params[4] = native_addr_ptr = cc.new_reg_ptr;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(native_addr_ptr, cc.exec_env_reg, cc.new_const_PTR( WASMExecEnv.jit_cache.offsetof))));
        /* Traverse each pointer/str argument, call
           jit_check_app_addr_and_convert to check whether it is
           in the range of linear memory and and convert it from
           app offset into native address */
        for (i = 0; i < func_type.param_count; i++) {
            is_pointer_arg = false;
            if (signature[i + 1] == '*') {
                /* param is a pointer */
                is_pointer_arg = true;
                func_params[1] = cc.new_const_I32( false); /* is_str = false */
                func_params[2] = argvs[i];
                if (signature[i + 2] == '~') {
                    /* pointer with length followed */
                    func_params[3] = argvs[i + 1];
                }
                else {
                    /* pointer with length followed */
                    func_params[3] = cc.new_const_I32( 1);
                }
            }
            else if (signature[i + 1] == '$') {
                /* param is a string */
                is_pointer_arg = true;
                func_params[1] = cc.new_const_I32( true); /* is_str = true */
                func_params[2] = argvs[i];
                func_params[3] = cc.new_const_I32( 1);
            }
            if (is_pointer_arg) {
                if (!jit_emit_callnative(cc, &jit_check_app_addr_and_convert,
                                         ret, func_params.ptr, 5)) {
                    goto fail;
                }
                /* Convert the return value from bool to uint32 */
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(ret, ret, cc.new_const_I32( 0xFF))));
                /* Check whether there is exception thrown */
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, ret, cc.new_const_I32( 0))));
                if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BEQ,
                                        cc.cmp_reg, null)) {
                    return false;
                }
                /* Load native addr from pointer of native addr,
                   or exec_env->jit_cache */
                argvs[i] = cc.new_reg_ptr;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(argvs[i], native_addr_ptr, cc.new_const_I32( 0))));
            }
        }
        res = create_first_res_reg(cc, func_type);
        /* Prepare arguments of the native function */
        if (((argvs1 =
                  jit_calloc_reg(JitReg.sizeof * (func_type.param_count + 1))) is null)) {
            goto fail;
        }
        argvs1[0] = cc.exec_env_reg;
        for (i = 0; i < func_type.param_count; i++) {
            argvs1[i + 1] = argvs[i];
        }
        /* Call the native function */
        native_func = cc.new_const_PTR( cast(uintptr_t)func_import.func_ptr_linked);
        if (!emit_callnative(cc, native_func, res, argvs1,
                             func_type.param_count + 1)) {
            jit_free(argvs1);
            goto fail;
        }
        jit_free(argvs1);
        /* Check whether there is exception thrown */
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI8(ret, module_inst_reg, cc.new_const_I32( WASMModuleInstance.cur_exception.offsetof))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, ret, cc.new_const_I32( 0))));
        if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BNE,
                                cc.cmp_reg, null)) {
            goto fail;
        }
        if (!post_return(cc, func_type, res, false)) {
            goto fail;
        }
    }
    else {
        /* The function to call is a bytecode function */
        func = wasm_module
                   .functions[func_idx - wasm_module.import_function_count];
        func_type = func.func_type;
        /* jitted_code = func_ptrs[func_idx - import_function_count] */
        fast_jit_func_ptrs = jit_frame.fast_jit_func_ptrs_reg;
        jitted_code = cc.new_reg_ptr;
        jitted_func_idx = func_idx - wasm_module.import_function_count;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(jitted_code, fast_jit_func_ptrs, cc.new_const_I32( cast(uint)(void*).sizeof * jitted_func_idx))));
        if (!pre_call(cc, func_type)) {
            goto fail;
        }
        res = create_first_res_reg(cc, func_type);
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CALLBC(res, 0, jitted_code, cc.new_const_I32( func_idx))));
        if (!post_return(cc, func_type, res, true)) {
            goto fail;
        }
    }
    /* Clear part of memory regs and table regs as their values
       may be changed in the function call */
	pragma(msg, "fixme(cbr): why is the memory cleared two times");
    if (cc.cur_wasm_module.possible_memory_grow)
        jit_frame.clear_memory_regs;
    jit_frame.clear_table_regs;
    /* Ignore tail call currently */
    cast(void)tail_call;
    return_value = true;
fail:
    if (argvs)
        jit_free(argvs);
    return return_value;
}
private JitReg pack_argv(JitCompContext* cc) {
    /* reuse the stack of the next frame */
    uint stack_base = void;
    JitReg argv = void;
    stack_base = cc.total_frame_size + WASMInterpFrame.lp.offsetof;
    argv = cc.new_reg_ptr;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(argv, cc.fp_reg, cc.new_const_PTR( stack_base))));
    if (jit_get_last_error(cc)) {
        return cast(JitReg)0;
    }
    return argv;
}
bool jit_compile_op_call_indirect(JitCompContext* cc, uint type_idx, uint tbl_idx) {
    WASMModule* wasm_module = cc.cur_wasm_module;
    JitBasicBlock* block_import = void, block_nonimport = void, func_return = void;
    JitReg elem_idx = void, native_ret = void, argv = void; JitReg[6] arg_regs = void;
    JitFrame* jit_frame = cc.jit_frame;
    JitReg tbl_size = void, offset = void, offset_i32 = void;
    JitReg func_import = void, func_idx = void, tbl_elems = void, func_count = void;
    JitReg func_type_indexes = void, func_type_idx = void, fast_jit_func_ptrs = void;
    JitReg offset1_i32 = void, offset1 = void, func_type_idx1 = void, res = void;
    JitReg import_func_ptrs = void, jitted_code_idx = void, jitted_code = void;
    WASMType* func_type = void;
//    uint n = void;
    if (cc.pop_i32(elem_idx)) goto fail;
    /* check elem_idx */
    tbl_size = jit_frame.table_cur_size_reg( tbl_idx);
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, elem_idx, tbl_size)));
    if (!jit_emit_exception(cc, EXCE_UNDEFINED_ELEMENT, JIT_OP_BGEU,
                            cc.cmp_reg, null))
        goto fail;
    /* check func_idx */
    if (uintptr_t.max == ulong.max) {
        offset_i32 = cc.new_reg_I32;
        offset = cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(offset_i32, elem_idx, cc.new_const_I32( 2))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(offset, offset_i32)));
    }
    else {
        offset = cc.new_reg_I32;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(offset, elem_idx, cc.new_const_I32( 2))));
    }
    func_idx = cc.new_reg_I32;
    tbl_elems = jit_frame.table_elems_reg( tbl_idx);
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(func_idx, tbl_elems, offset)));
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, func_idx, cc.new_const_I32( -1))));
    if (!jit_emit_exception(cc, EXCE_UNINITIALIZED_ELEMENT, JIT_OP_BEQ,
                            cc.cmp_reg, null))
        goto fail;
    func_count = cc.new_const_I32( wasm_module.import_function_count + wasm_module.function_count);
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, func_idx, func_count)));
    if (!jit_emit_exception(cc, EXCE_INVALID_FUNCTION_INDEX, JIT_OP_BGTU,
                            cc.cmp_reg, null))
        goto fail;
    /* check func_type */
    /* get func_type_idx from func_type_indexes */
    if (uintptr_t.max == ulong.max) {
        offset1_i32 = cc.new_reg_I32;
        offset1 = cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(offset1_i32, func_idx, cc.new_const_I32( 2))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(offset1, offset1_i32)));
    }
    else {
        offset1 = cc.new_reg_I32;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(offset1, func_idx, cc.new_const_I32( 2))));
    }
    func_type_indexes = jit_frame.func_type_indexes_reg;
    func_type_idx = cc.new_reg_I32;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(func_type_idx, func_type_indexes, offset1)));
    type_idx = wasm_get_smallest_type_idx(wasm_module.types,
                                          wasm_module.type_count, type_idx);
    func_type_idx1 = cc.new_const_I32( type_idx);
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, func_type_idx, func_type_idx1)));
    if (!jit_emit_exception(cc, EXCE_INVALID_FUNCTION_TYPE_INDEX, JIT_OP_BNE,
                            cc.cmp_reg, null))
        goto fail;
    /* pop function arguments and store it to out area of callee stack frame */
    func_type = wasm_module.types[type_idx];
    if (!pre_call(cc, func_type)) {
        goto fail;
    }
    /* store elem_idx and func_idx to exec_env->jit_cache */
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(elem_idx, cc.exec_env_reg, cc.new_const_I32( WASMExecEnv.jit_cache.offsetof))));
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(func_idx, cc.exec_env_reg, cc.new_const_I32( WASMExecEnv.jit_cache.offsetof + 4))));
    block_import = cc.new_basic_block( 0);
    block_nonimport = cc.new_basic_block( 0);
    func_return = cc.new_basic_block( 0);
    if (!block_import || !block_nonimport || !func_return) {
        goto fail;
    }
    /* Commit register values to locals and stacks */
    jit_frame.gen_commit_values;//( jit_frame.lp, jit_frame.sp);
    /* Clear frame values */
    jit_frame.clear_values;
    /* jump to block_import or block_nonimport */
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, func_idx, cc.new_const_I32( cc.cur_wasm_module.import_function_count))));
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BLTU(cc.cmp_reg, jit_basic_block_label(block_import), jit_basic_block_label(block_nonimport))));
    /* block_import */
    cc.cur_basic_block = block_import;
    elem_idx = cc.new_reg_I32;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(elem_idx, cc.exec_env_reg, cc.new_const_I32( WASMExecEnv.jit_cache.offsetof))));
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(func_idx, cc.exec_env_reg, cc.new_const_I32( WASMExecEnv.jit_cache.offsetof + 4))));
    argv = pack_argv(cc);
    if (!argv) {
        goto fail;
    }
    native_ret = cc.new_reg_I32;
    arg_regs[0] = cc.exec_env_reg;
    arg_regs[1] = cc.new_const_I32( tbl_idx);
    arg_regs[2] = elem_idx;
    arg_regs[3] = cc.new_const_I32( type_idx);
    arg_regs[4] = cc.new_const_I32( func_type.param_cell_num);
    arg_regs[5] = argv;
    import_func_ptrs = jit_frame.import_func_ptrs_reg;
    func_import = cc.new_reg_ptr;
    if (uintptr_t.max == ulong.max) {
        JitReg func_import_offset = cc.new_reg_I32;
        JitReg func_import_offset_i64 = cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(func_import_offset, func_idx, cc.new_const_I32( 3))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(func_import_offset_i64, func_import_offset)));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(func_import, import_func_ptrs, func_import_offset_i64)));
    }
    else {
        JitReg func_import_offset = cc.new_reg_I32;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(func_import_offset, func_idx, cc.new_const_I32( 2))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(func_import, import_func_ptrs, func_import_offset)));
    }
    if (!jit_emit_callnative(cc, &fast_jit_call_indirect, native_ret, arg_regs.ptr,
                             6)) {
        goto fail;
    }
    /* Convert bool to uint32 */
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(native_ret, native_ret, cc.new_const_I32( 0xFF))));
    /* Check whether there is exception thrown */
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, native_ret, cc.new_const_I32( 0))));
    if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BEQ, cc.cmp_reg,
                            null)) {
        return false;
    }
    /* Store res into current frame, so that post_return in
        block func_return can get the value */
 //   n = cc.jit_frame.sp - cc.jit_frame.lp;
    if (func_type.result_count > 0) {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                res = cc.new_reg_I32;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(res, argv, cc.new_const_I32( 0))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            case VALUE_TYPE_I64:
                res = cc.new_reg_I64;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(res, argv, cc.new_const_I32( 0))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI64(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            case VALUE_TYPE_F32:
                res = cc.new_reg_F32;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDF32(res, argv, cc.new_const_I32( 0))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF32(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            case VALUE_TYPE_F64:
                res = cc.new_reg_F64;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDF64(res, argv, cc.new_const_I32( 0))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF64(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            default:
                bh_assert(0);
                goto fail;
        }
    }
    jit_frame.gen_commit_values;
    jit_frame.clear_values;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(jit_basic_block_label(func_return))));
    /* basic_block non_import */
    cc.cur_basic_block = block_nonimport;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(func_idx, cc.exec_env_reg, cc.new_const_I32( WASMExecEnv.jit_cache.offsetof + 4))));
    /* get jitted_code */
    fast_jit_func_ptrs = jit_frame.fast_jit_func_ptrs_reg;
    jitted_code_idx = cc.new_reg_I32;
    jitted_code = cc.new_reg_ptr;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SUB(jitted_code_idx, func_idx, cc.new_const_I32( cc.cur_wasm_module.import_function_count))));
    if (uintptr_t.max == ulong.max) {
        JitReg jitted_code_offset = cc.new_reg_I32;
        JitReg jitted_code_offset_64 = cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(jitted_code_offset, jitted_code_idx, cc.new_const_I32( 3))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(jitted_code_offset_64, jitted_code_offset)));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(jitted_code, fast_jit_func_ptrs, jitted_code_offset_64)));
    }
    else {
        JitReg jitted_code_offset = cc.new_reg_I32;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(jitted_code_offset, jitted_code_idx, cc.new_const_I32( 2))));
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(jitted_code, fast_jit_func_ptrs, jitted_code_offset)));
    }
    res = 0;
    if (func_type.result_count > 0) {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                res = cc.new_reg_I32;
                break;
            case VALUE_TYPE_I64:
                res = cc.new_reg_I64;
                break;
            case VALUE_TYPE_F32:
                res = cc.new_reg_F32;
                break;
            case VALUE_TYPE_F64:
                res = cc.new_reg_F64;
                break;
            default:
                bh_assert(0);
                goto fail;
        }
    }
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CALLBC(res, 0, jitted_code, func_idx)));
    /* Store res into current frame, so that post_return in
        block func_return can get the value */
//    n = cc.jit_frame.sp - cc.jit_frame.lp;
    if (func_type.result_count > 0) {
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
            case VALUE_TYPE_EXTERNREF:
            case VALUE_TYPE_FUNCREF:
}
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            case VALUE_TYPE_I64:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI64(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            case VALUE_TYPE_F32:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF32(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            case VALUE_TYPE_F64:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF64(res, cc.fp_reg, cc.new_const_I32( offset_of_local(cc.jit_frame.local_offset)))));
                break;
            default:
                bh_assert(0);
                goto fail;
        }
    }
    /* commit and clear jit frame, then jump to block func_ret */
    jit_frame.gen_commit_values;
    jit_frame.clear_values;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(jit_basic_block_label(func_return))));
    /* translate block func_return */
    cc.cur_basic_block = func_return;
    if (!post_return(cc, func_type, 0, true)) {
        goto fail;
    }
    /* Clear part of memory regs and table regs as their values
       may be changed in the function call */
	pragma(msg, "fix,e(cbr): Again why double clean");
    if (cc.cur_wasm_module.possible_memory_grow)
        cc.jit_frame.clear_memory_regs;
    cc.jit_frame.clear_table_regs;
    return true;
fail:
    return false;
}
static if (ver.WASM_ENABLE_REF_TYPES) {
bool jit_compile_op_ref_null(JitCompContext* cc, uint ref_type) {
    PUSH_I32(cc.new_const_I32( NULL_REF));
    cast(void)ref_type;
    return true;
fail:
    return false;
}
bool jit_compile_op_ref_is_null(JitCompContext* cc) {
    JitReg ref_ = void, res = void;
    POP_I32(ref_);
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, ref_, cc.new_const_I32( NULL_REF))));
    res = cc.new_reg_I32;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(res, cc.cmp_reg, cc.new_const_I32( 1), jit_cc_new_const_I32(cc, 0))));
    PUSH_I32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_ref_func(JitCompContext* cc, uint func_idx) {
    PUSH_I32(cc.new_const_I32( func_idx));
    return true;
fail:
    return false;
}
}
static if (ver.BUILD_TARGET_X86_64 || ver.BUILD_TARGET_AMD_64) {
private bool emit_callnative(JitCompContext* cc, JitReg native_func_reg, JitReg res, JitReg* params, uint param_count) {
    JitInsn* insn = void;
    char*[6] i64_arg_names = [ "rdi", "rsi", "rdx", "rcx", "r8", "r9" ];
    char*[6] f32_arg_names = [ "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5" ];
    char*[6] f64_arg_names = [ "xmm0_f64", "xmm1_f64", "xmm2_f64",
                              "xmm3_f64", "xmm4_f64", "xmm5_f64" ];
    JitReg[6] i64_arg_regs = void, f32_arg_regs = void, f64_arg_regs = void; JitReg res_reg = 0;
    JitReg eax_hreg = jit_codegen_get_hreg_by_name("eax");
    JitReg xmm0_hreg = jit_codegen_get_hreg_by_name("xmm0");
    uint i = void, i64_reg_idx = void, float_reg_idx = void;
    bh_assert(param_count <= 6);
    for (i = 0; i < 6; i++) {
        i64_arg_regs[i] = jit_codegen_get_hreg_by_name(i64_arg_names[i]);
        f32_arg_regs[i] = jit_codegen_get_hreg_by_name(f32_arg_names[i]);
        f64_arg_regs[i] = jit_codegen_get_hreg_by_name(f64_arg_names[i]);
    }
    i64_reg_idx = float_reg_idx = 0;
    for (i = 0; i < param_count; i++) {
        switch (jit_reg_kind(params[i])) {
            case JitRegKind.I32:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(i64_arg_regs[i64_reg_idx++], params[i])));
                break;
            case JitRegKind.I64:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MOV(i64_arg_regs[i64_reg_idx++], params[i])));
                break;
            case JitRegKind.F32:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MOV(f32_arg_regs[float_reg_idx++], params[i])));
                break;
            case JitRegKind.F64:
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MOV(f64_arg_regs[float_reg_idx++], params[i])));
                break;
            default:
                bh_assert(0);
                return false;
        }
    }
    if (res) {
        switch (jit_reg_kind(res)) {
            case JitRegKind.I32:
                res_reg = eax_hreg;
                break;
            case JitRegKind.I64:
                res_reg = res;
                break;
            case JitRegKind.F32:
                res_reg = xmm0_hreg;
                break;
            case JitRegKind.F64:
                res_reg = res;
                break;
            default:
                bh_assert(0);
                return false;
        }
    }
    insn = cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CALLNATIVE(res_reg, native_func_reg, param_count)));
    if (!insn) {
        return false;
    }
    i64_reg_idx = float_reg_idx = 0;
    for (i = 0; i < param_count; i++) {
        switch (jit_reg_kind(params[i])) {
            case JitRegKind.I32:
            case JitRegKind.I64:
                *(jit_insn_opndv(insn, i + 2)) = i64_arg_regs[i64_reg_idx++];
                break;
            case JitRegKind.F32:
                *(jit_insn_opndv(insn, i + 2)) = f32_arg_regs[float_reg_idx++];
                break;
            case JitRegKind.F64:
                *(jit_insn_opndv(insn, i + 2)) = f64_arg_regs[float_reg_idx++];
                break;
            default:
                bh_assert(0);
                return false;
        }
    }
    if (res && res != res_reg) {
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MOV(res, res_reg)));
    }
    return true;
}
} else {
private bool emit_callnative(JitCompContext* cc, JitReg native_func_reg, JitReg res, JitReg* params, uint param_count) {
    JitInsn* insn = void;
    uint i = void;
    bh_assert(param_count <= 6);
    insn = cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CALLNATIVE(res, native_func_reg, param_count)));
    if (!insn)
        return false;
    for (i = 0; i < param_count; i++) {
        *(jit_insn_opndv(insn, i + 2)) = params[i];
    }
    return true;
}
}
bool jit_emit_callnative(JitCompContext* cc, void* native_func, JitReg res, JitReg* params, uint param_count) {
    return emit_callnative(cc, cc.new_const_PTR( cast(uintptr_t)native_func), res,
                           params, param_count);
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
