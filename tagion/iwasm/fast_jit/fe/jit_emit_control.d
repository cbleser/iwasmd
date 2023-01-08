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
module jit_emit_control_tmp;
@nogc nothrow:
extern (C):
__gshared:
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
import tagion.iwasm.config : BLOCK_ADDR_CACHE_SIZE, BLOCK_ADDR_CONFLICT_SIZE;
import tagion.iwasm.interpreter.wasm : BlockAddr, LABEL_TYPE_BLOCK, LABEL_TYPE_LOOP, LABEL_TYPE_IF;
import tagion.iwasm.interpreter.wasm_loader : wasm_loader_find_block_addr;
import tagion.iwasm.fast_jit.jit_context : JitCompContext;
import tagion.iwasm.fast_jit.jit_utils;
import tagion.iwasm.fast_jit.jit_frame;
import tagion.iwasm.fast_jit.jit_compiler;
import tagion.iwasm.fast_jit.jit_frontend : POP_I32, POP_I64;
import tagion.iwasm.fast_jit.fe.jit_emit_exception : jit_emit_exception;
import tagion.iwasm.share.utils.bh_assert;

bool jit_compile_op_block(JitCompContext* cc, ubyte** p_frame_ip, ubyte* frame_ip_end, uint label_type, uint param_count, ubyte* param_types, uint result_count, ubyte* result_types, bool merge_cmp_and_if);
bool jit_compile_op_else(JitCompContext* cc, ubyte** p_frame_ip);
bool jit_compile_op_end(JitCompContext* cc, ubyte** p_frame_ip);
bool jit_compile_op_br(JitCompContext* cc, uint br_depth, ubyte** p_frame_ip);
bool jit_compile_op_br_if(JitCompContext* cc, uint br_depth, bool merge_cmp_and_br_if, ubyte** p_frame_ip);
bool jit_compile_op_br_table(JitCompContext* cc, uint* br_depths, uint br_count, ubyte** p_frame_ip);
bool jit_compile_op_return(JitCompContext* cc, ubyte** p_frame_ip);
bool jit_compile_op_unreachable(JitCompContext* cc, ubyte** p_frame_ip);
bool jit_handle_next_reachable_block(JitCompContext* cc, ubyte** p_frame_ip);
//#include "jit_emit_exception.h"
//#include "jit_emit_function.h"
//#include "../jit_frontend.h"
//#include "../interpreter/wasm_loader.h"
private JitBlock* get_target_block(JitCompContext* cc, uint br_depth) {
    uint i = br_depth;
    JitBlock* block = jit_block_stack_top(&cc.block_stack);
    while (i-- > 0 && block) {
        block = block.prev;
    }
    if (!block) {
        jit_set_last_error(cc, "WASM block stack underflow");
        return null;
    }
    return block;
}

private bool load_block_params(JitCompContext* cc, JitBlock* block) {
    JitFrame* jit_frame = cc.jit_frame;
    uint offset = void, i = void;
    JitReg value = 0;
    /* Clear jit frame's locals and stacks */
    clear_values(jit_frame);
    /* Restore jit frame's sp to block's sp begin */
    jit_frame.sp = block.frame_sp_begin;
    /* Load params to new block */
    offset = cast(uint)(jit_frame.sp - jit_frame.lp);
    for (i = 0; i < block.param_count; i++) {
        switch (block.param_types[i]) {
        case VALUE_TYPE_I32:
            value = gen_load_i32(jit_frame, offset);
            offset++;
            break;
            case VALUE_TYPE_I64:
            value = gen_load_i64(jit_frame, offset);
            offset += 2;
            break;
            case VALUE_TYPE_F32:
            value = gen_load_f32(jit_frame, offset);
            offset++;
            break;
            case VALUE_TYPE_F64:
            value = gen_load_f64(jit_frame, offset);
            offset += 2;
            break;
            default:
            bh_assert(0);
            break;
        }
        PUSH(value, block.param_types[i]);
    }
    return true;
fail:
    return false;
}

private bool load_block_results(JitCompContext* cc, JitBlock* block) {
    JitFrame* jit_frame = cc.jit_frame;
    uint offset = void, i = void;
    JitReg value = 0;
    /* Restore jit frame's sp to block's sp begin */
    jit_frame.sp = block.frame_sp_begin;
    /* Load results to new block */
    offset = cast(uint)(jit_frame.sp - jit_frame.lp);
    for (i = 0; i < block.result_count; i++) {
        switch (block.result_types[i]) {
        case VALUE_TYPE_I32:
            value = gen_load_i32(jit_frame, offset);
            offset++;
            break;
            case VALUE_TYPE_I64:
            value = gen_load_i64(jit_frame, offset);
            offset += 2;
            break;
            case VALUE_TYPE_F32:
            value = gen_load_f32(jit_frame, offset);
            offset++;
            break;
            case VALUE_TYPE_F64:
            value = gen_load_f64(jit_frame, offset);
            offset += 2;
            break;
            default:
            bh_assert(0);
            break;
        }
        PUSH(value, block.result_types[i]);
    }
    return true;
fail:
    return false;
}

private bool jit_reg_is_i32_const(JitCompContext* cc, JitReg reg, int val) {
    return (jit_reg_kind(reg) == JIT_REG_KIND_I32 && jit_reg_is_const(reg)
            && cc.get_const_I32( reg) == val)
        ? true : false;
}
/**
 * get the last two insns:
 *     CMP cmp_reg, r0, r1
 *     SELECTcc r2, cmp_reg, 1, 0
 */
private void get_last_cmp_and_selectcc(JitCompContext* cc, JitReg cond, JitInsn** p_insn_cmp, JitInsn** p_insn_select) {
    JitInsn* insn = jit_basic_block_last_insn(cc.cur_basic_block);
    if (insn && insn.prev && insn.prev.opcode == JIT_OP_CMP
            && insn.opcode >= JIT_OP_SELECTEQ && insn.opcode <= JIT_OP_SELECTLEU
            && *jit_insn_opnd(insn, 0) == cond
            && jit_reg_is_i32_const(cc, *jit_insn_opnd(insn, 2), 1)
            && jit_reg_is_i32_const(cc, *jit_insn_opnd(insn, 3), 0)) {
        *p_insn_cmp = insn.prev;
        *p_insn_select = insn;
    }
}

private bool push_jit_block_to_stack_and_pass_params(JitCompContext* cc, JitBlock* block, JitBasicBlock* basic_block, JitReg cond, bool merge_cmp_and_if) {
    JitFrame* jit_frame = cc.jit_frame;
    JitValue* value_list_head = null, value_list_end = null, jit_value = void;
    JitInsn* insn = void;
    JitReg value = void;
    uint i = void, param_index = void, cell_num = void;
    if (cc.cur_basic_block == basic_block) {
        /* Reuse the current basic block and no need to commit values,
           we just move param values from current block's value stack to
           the new block's value stack */
        for (i = 0; i < block.param_count; i++) {
            jit_value = jit_value_stack_pop(
                    &jit_block_stack_top(&cc.block_stack).value_stack);
            if (!value_list_head) {
                value_list_head = value_list_end = jit_value;
                jit_value.prev = jit_value.next = null;
            }
            else {
                jit_value.prev = null;
                jit_value.next = value_list_head;
                value_list_head.prev = jit_value;
                value_list_head = jit_value;
            }
        }
        block.value_stack.value_list_head = value_list_head;
        block.value_stack.value_list_end = value_list_end;
        /* Save block's begin frame sp */
        cell_num = wasm_get_cell_num(block.param_types, block.param_count);
        block.frame_sp_begin = jit_frame.sp - cell_num;
        /* Push the new block to block stack */
        jit_block_stack_push(&cc.block_stack, block);
        /* Continue to translate current block */
    }
    else {
        JitInsn* insn_select = null, insn_cmp = null;
        if (merge_cmp_and_if) {
            get_last_cmp_and_selectcc(cc, cond, &insn_cmp, &insn_select);
        }
        /* Commit register values to locals and stacks */
        gen_commit_values(jit_frame, jit_frame.lp, jit_frame.sp);
        /* Pop param values from current block's value stack */
        for (i = 0; i < block.param_count; i++) {
            param_index = block.param_count - 1 - i;
            POP(value, block.param_types[param_index]);
        }
        /* Clear frame values */
        clear_values(jit_frame);
        /* Save block's begin frame sp */
        block.frame_sp_begin = jit_frame.sp;
        /* Push the new block to block stack */
        jit_block_stack_push(&cc.block_stack, block);
        if (block.label_type == LABEL_TYPE_LOOP) {
            if (!cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(jit_basic_block_label(basic_block))))) {
                jit_set_last_error(cc, "generate jmp insn failed");
                goto fail;
            }
        }
        else {
            /* IF block with condition br insn */
            if (insn_select && insn_cmp) {
                /* Change `CMP + SELECTcc` into `CMP + Bcc` */
                if (((insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BEQ(cc.cmp_reg, jit_basic_block_label(
                        basic_block), 0)))) == 0)) {
                    jit_set_last_error(cc, "generate cond br failed");
                    goto fail;
                }
                insn.opcode =
                    JIT_OP_BEQ + (insn_select.opcode - JIT_OP_SELECTEQ);
                jit_insn_unlink(insn_select);
                jit_insn_delete(insn_select);
            }
            else {
                if (!cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, cond, jit_cc_new_const_I32(
                        cc, 0))))
                        || ((insn =
                            cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BNE(cc.cmp_reg, jit_basic_block_label(
                            basic_block), 0)))) == 0)) {
                    jit_set_last_error(cc, "generate cond br failed");
                    goto fail;
                }
            }
            /* Don't create else basic block or end basic block now, just
               save its incoming BNE insn, and patch the insn's else label
               when the basic block is lazily created */
            if (block.wasm_code_else) {
                block.incoming_insn_for_else_bb = insn;
            }
            else {
                if (!jit_block_add_incoming_insn(block, insn, 2)) {
                    jit_set_last_error(cc, "add incoming insn failed");
                    goto fail;
                }
            }
        }
        /* Start to translate the block */
        cc.cur_basic_block = basic_block;
        /* Push the block parameters */
        if (!load_block_params(cc, block)) {
            goto fail;
        }
    }
    return true;
fail:
    return false;
}

private void copy_block_arities(JitCompContext* cc, JitReg dst_frame_sp, ubyte* dst_types, uint dst_type_count, JitReg* p_first_res_reg) {
    JitFrame* jit_frame = void;
    uint offset_src = void, offset_dst = void, i = void;
    JitReg value = void;
    jit_frame = cc.jit_frame;
    offset_src = cast(uint)(jit_frame.sp - jit_frame.lp)
        - wasm_get_cell_num(dst_types, dst_type_count);
    offset_dst = 0;
    /* pop values from stack and store to dest frame */
    for (i = 0; i < dst_type_count; i++) {
        switch (dst_types[i]) {
        case VALUE_TYPE_I32:
            value = gen_load_i32(jit_frame, offset_src);
            if (i == 0 && p_first_res_reg)
                *p_first_res_reg = value;
            else
                cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(value, dst_frame_sp, jit_cc_new_const_I32(
                        cc, offset_dst * 4))));
            offset_src++;
            offset_dst++;
            break;
            case VALUE_TYPE_I64:
            value = gen_load_i64(jit_frame, offset_src);
            if (i == 0 && p_first_res_reg)
                *p_first_res_reg = value;
            else
                cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI64(value, dst_frame_sp, jit_cc_new_const_I32(
                        cc, offset_dst * 4))));
            offset_src += 2;
            offset_dst += 2;
            break;
            case VALUE_TYPE_F32:
            value = gen_load_f32(jit_frame, offset_src);
            if (i == 0 && p_first_res_reg)
                *p_first_res_reg = value;
            else
                cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF32(value, dst_frame_sp, jit_cc_new_const_I32(
                        cc, offset_dst * 4))));
            offset_src++;
            offset_dst++;
            break;
            case VALUE_TYPE_F64:
            value = gen_load_f64(jit_frame, offset_src);
            if (i == 0 && p_first_res_reg)
                *p_first_res_reg = value;
            else
                cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF64(value, dst_frame_sp, jit_cc_new_const_I32(
                        cc, offset_dst * 4))));
            offset_src += 2;
            offset_dst += 2;
            break;
            default:
            bh_assert(0);
            break;
        }
    }
}

private bool handle_func_return(JitCompContext* cc, JitBlock* block) {
    JitReg prev_frame = void, prev_frame_sp = void;
    JitReg ret_reg = 0;
    prev_frame = jit_cc_new_reg_ptr(cc);
    prev_frame_sp = jit_cc_new_reg_ptr(cc);
    /* prev_frame = cur_frame->prev_frame */
    cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(prev_frame, cc.fp_reg, jit_cc_new_const_I32(
            cc, WASMInterpFrame.prev_frame.offsetof))));
    cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(prev_frame_sp, prev_frame, jit_cc_new_const_I32(
            cc, WASMInterpFrame.sp.offsetof))));
    if (block.result_count) {
        uint cell_num = wasm_get_cell_num(block.result_types, block.result_count);
        copy_block_arities(cc, prev_frame_sp, block.result_types,
                block.result_count, &ret_reg);
        /* prev_frame->sp += cell_num */
        cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(prev_frame_sp, prev_frame_sp, jit_cc_new_const_PTR(
                cc, cell_num * 4))));
        cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STPTR(prev_frame_sp, prev_frame, jit_cc_new_const_I32(
                cc, WASMInterpFrame.sp.offsetof))));
    }
    /* Free stack space of the current frame:
       exec_env->wasm_stack.s.top = cur_frame */
    cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STPTR(cc.fp_reg, cc.exec_env_reg, jit_cc_new_const_I32(
            cc, offsetof(WASMExecEnv, wasm_stack.s.top)))));
    /* Set the prev_frame as the current frame:
       exec_env->cur_frame = prev_frame */
    cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STPTR(prev_frame, cc.exec_env_reg, jit_cc_new_const_I32(
            cc, WASMExecEnv.cur_frame.offsetof))));
    /* fp_reg = prev_frame */
    cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MOV(cc.fp_reg, prev_frame)));
    /* return 0 */
    cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_RETURNBC(cc.new_const_I32( JIT_INTERP_ACTION_NORMAL), ret_reg, 0)));
    return true;
}
/**
 * is_block_polymorphic: whether current block's stack is in polymorphic state,
 * if the opcode is one of unreachable/br/br_table/return, stack is marked
 * to polymorphic state until the block's 'end' opcode is processed
 */
private bool handle_op_end(JitCompContext* cc, ubyte** p_frame_ip, bool is_block_polymorphic) {
    JitFrame* jit_frame = cc.jit_frame;
    JitBlock* block = void, block_prev = void;
    JitIncomingInsn* incoming_insn = void;
    JitInsn* insn = void;
    /* Check block stack */
    if (((block = jit_block_stack_top(&cc.block_stack)) == 0)) {
        jit_set_last_error(cc, "WASM block stack underflow");
        return false;
    }
    if (!block.incoming_insns_for_end_bb) {
        /* No other basic blocks jumping to this end, no need to
           create the end basic block, just continue to translate
           the following opcodes */
        if (block.label_type == LABEL_TYPE_FUNCTION) {
            if (!handle_func_return(cc, block)) {
                return false;
            }
            *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
            clear_values(jit_frame);
        }
        else if (block.result_count > 0) {
            JitValue* value_list_head = null, value_list_end = null;
            JitValue* jit_value = void;
            uint i = void;
            /* No need to change cc->jit_frame, just move result values
               from current block's value stack to previous block's
               value stack */
            block_prev = block.prev;
            for (i = 0; i < block.result_count; i++) {
                jit_value = jit_value_stack_pop(&block.value_stack);
                bh_assert(jit_value);
                if (!value_list_head) {
                    value_list_head = value_list_end = jit_value;
                    jit_value.prev = jit_value.next = null;
                }
                else {
                    jit_value.prev = null;
                    jit_value.next = value_list_head;
                    value_list_head.prev = jit_value;
                    value_list_head = jit_value;
                }
            }
            if (!block_prev.value_stack.value_list_head) {
                block_prev.value_stack.value_list_head = value_list_head;
                block_prev.value_stack.value_list_end = value_list_end;
            }
            else {
                /* Link to the end of previous block's value stack */
                block_prev.value_stack.value_list_end.next = value_list_head;
                value_list_head.prev = block_prev.value_stack.value_list_end;
                block_prev.value_stack.value_list_end = value_list_end;
            }
        }
        /* Pop block and destroy the block */
        block = jit_block_stack_pop(&cc.block_stack);
        jit_block_destroy(block);
        return true;
    }
    else {
        /* Commit register values to locals and stacks */
        gen_commit_values(jit_frame, jit_frame.lp, jit_frame.sp);
        /* Clear frame values */
        clear_values(jit_frame);
        /* Create the end basic block */
        bh_assert(!block.basic_block_end);
        if (((block.basic_block_end = cc.new_basic_block( 0)) == 0)) {
            jit_set_last_error(cc, "create basic block failed");
            goto fail;
        }
        *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
        *(cc.jit_annl_begin_bcip( jit_basic_block_label(block.basic_block_end))) = *p_frame_ip;
        /* No need to create 'JMP' insn if block is in stack polymorphic
           state, as previous br/br_table opcode has created 'JMP' insn
           to this end basic block */
        if (!is_block_polymorphic) {
            /* Jump to the end basic block */
            if (!cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(jit_basic_block_label(block
                    .basic_block_end))))) {
                jit_set_last_error(cc, "generate jmp insn failed");
                goto fail;
            }
        }
        /* Patch the INSNs which jump to this basic block */
        incoming_insn = block.incoming_insns_for_end_bb;
        while (incoming_insn) {
            insn = incoming_insn.insn;
            bh_assert(
                    insn.opcode == JIT_OP_JMP
                    || (insn.opcode >= JIT_OP_BEQ && insn.opcode <= JIT_OP_BLEU)
                    || insn.opcode == JIT_OP_LOOKUPSWITCH);
            if (insn.opcode == JIT_OP_JMP
                    || (insn.opcode >= JIT_OP_BEQ
                        && insn.opcode <= JIT_OP_BLEU)) {
                *(jit_insn_opnd(insn, incoming_insn.opnd_idx)) =
                    jit_basic_block_label(block.basic_block_end);
            }
            else {
                /* Patch LOOKUPSWITCH INSN */
                JitOpndLookupSwitch* opnd = jit_insn_opndls(insn);
                if (incoming_insn.opnd_idx < opnd.match_pairs_num) {
                    opnd.match_pairs[incoming_insn.opnd_idx].target =
                        jit_basic_block_label(block.basic_block_end);
                }
                else {
                    opnd.default_target =
                        jit_basic_block_label(block.basic_block_end);
                }
            }
            incoming_insn = incoming_insn.next;
        }
        cc.cur_basic_block = block.basic_block_end;
        /* Pop block and load block results */
        block = jit_block_stack_pop(&cc.block_stack);
        if (block.label_type == LABEL_TYPE_FUNCTION) {
            if (!handle_func_return(cc, block)) {
                jit_block_destroy(block);
                goto fail;
            }
            *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
            clear_values(jit_frame);
        }
        else {
            if (!load_block_results(cc, block)) {
                jit_block_destroy(block);
                goto fail;
            }
        }
        jit_block_destroy(block);
        return true;
    }
    return true;
fail:
    return false;
}
/**
 * is_block_polymorphic: whether current block's stack is in polymorphic state,
 * if the opcode is one of unreachable/br/br_table/return, stack is marked
 * to polymorphic state until the block's 'end' opcode is processed
 */
private bool handle_op_else(JitCompContext* cc, ubyte** p_frame_ip, bool is_block_polymorphic) {
    JitBlock* block = jit_block_stack_top(&cc.block_stack);
    JitFrame* jit_frame = cc.jit_frame;
    JitInsn* insn = void;
    /* Check block */
    if (!block) {
        jit_set_last_error(cc, "WASM block stack underflow");
        return false;
    }
    if (block.label_type != LABEL_TYPE_IF) {
        jit_set_last_error(cc, "Invalid WASM block type");
        return false;
    }
    if (!block.incoming_insn_for_else_bb) {
        /* The if branch is handled like OP_BLOCK (cond is const and != 0),
           just skip the else branch and handle OP_END */
        *p_frame_ip = block.wasm_code_end + 1;
        return handle_op_end(cc, p_frame_ip, false);
    }
    else {
        /* Has else branch and need to translate else branch */
        /* Commit register values to locals and stacks */
        gen_commit_values(jit_frame, jit_frame.lp, jit_frame.sp);
        /* Clear frame values */
        clear_values(jit_frame);
        /* No need to create 'JMP' insn if block is in stack polymorphic
           state, as previous br/br_table opcode has created 'JMP' insn
           to this end basic block */
        if (!is_block_polymorphic) {
            /* Jump to end basic block */
            if (((insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(0)))) == 0)) {
                jit_set_last_error(cc, "generate jmp insn failed");
                return false;
            }
            if (!jit_block_add_incoming_insn(block, insn, 0)) {
                jit_set_last_error(cc, "add incoming insn failed");
                return false;
            }
        }
        /* Clear value stack, restore param values and
           start to translate the else branch. */
        jit_value_stack_destroy(&block.value_stack);
        /* create else basic block */
        bh_assert(!block.basic_block_else);
        if (((block.basic_block_else = cc.new_basic_block( 0)) == 0)) {
            jit_set_last_error(cc, "create basic block failed");
            goto fail;
        }
        *(cc.jit_annl_end_bcip( jit_basic_block_label(block.basic_block_entry))) = *p_frame_ip - 1;
        *(cc.jit_annl_begin_bcip( jit_basic_block_label(block.basic_block_else))) = *p_frame_ip;
        /* Patch the insn which conditionly jumps to the else basic block */
        insn = block.incoming_insn_for_else_bb;
        *(jit_insn_opnd(insn, 2)) =
            jit_basic_block_label(block.basic_block_else);
        cc.cur_basic_block = block.basic_block_else;
        /* Reload block parameters */
        if (!load_block_params(cc, block)) {
            return false;
        }
        return true;
    }
    return true;
fail:
    return false;
}

private bool handle_next_reachable_block(JitCompContext* cc, ubyte** p_frame_ip) {
    JitBlock* block = jit_block_stack_top(&cc.block_stack);
    bh_assert(block);
    do {
        if (block.label_type == LABEL_TYPE_IF
                && block.incoming_insn_for_else_bb
                && *p_frame_ip <= block.wasm_code_else) {
            /* Else branch hasn't been translated,
               start to translate the else branch */
            *p_frame_ip = block.wasm_code_else + 1;
            /* Restore jit frame's sp to block's sp begin */
            cc.jit_frame.sp = block.frame_sp_begin;
            return handle_op_else(cc, p_frame_ip, true);
        }
        else if (block.incoming_insns_for_end_bb) {
            *p_frame_ip = block.wasm_code_end + 1;
            /* Restore jit frame's sp to block's sp end  */
            cc.jit_frame.sp =
                block.frame_sp_begin
                + wasm_get_cell_num(block.result_types, block.result_count);
            return handle_op_end(cc, p_frame_ip, true);
        }
        else {
            *p_frame_ip = block.wasm_code_end + 1;
            jit_block_stack_pop(&cc.block_stack);
            jit_block_destroy(block);
            block = jit_block_stack_top(&cc.block_stack);
        }
    }
    while (block != null);
    return true;
}

bool jit_compile_op_block(JitCompContext* cc, ubyte** p_frame_ip, ubyte* frame_ip_end, uint label_type, uint param_count, ubyte* param_types, uint result_count, ubyte* result_types, bool merge_cmp_and_if) {
    BlockAddr[BLOCK_ADDR_CONFLICT_SIZE][BLOCK_ADDR_CACHE_SIZE] block_addr_cache = void;
    JitBlock* block = void;
    JitReg value = void;
    ubyte* else_addr = void, end_addr = void;
    /* Check block stack */
    if (!jit_block_stack_top(&cc.block_stack)) {
        jit_set_last_error(cc, "WASM block stack underflow");
        return false;
    }
    memset(block_addr_cache.ptr, 0, block_addr_cache.sizeof);
    /* Get block info */
    if (!(wasm_loader_find_block_addr(
            null, cast(BlockAddr*) block_addr_cache, *p_frame_ip, frame_ip_end,
            cast(ubyte) label_type, &else_addr, &end_addr))) {
        jit_set_last_error(cc, "find block end addr failed");
        return false;
    }
    /* Allocate memory */
    if (((block = jit_calloc_block(JitBlock.sizeof)) is null)) {
        jit_set_last_error(cc, "allocate memory failed");
        return false;
    }
    if (param_count && ((block.param_types = jit_calloc_buffer(param_count)) is null)) {
        jit_set_last_error(cc, "allocate memory failed");
        goto fail;
    }
    if (result_count && ((block.result_types = jit_calloc_buffer(result_count)) is null)) {
        jit_set_last_error(cc, "allocate memory failed");
        goto fail;
    }
    /* Initialize block data */
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
    if (label_type == LABEL_TYPE_BLOCK) {
        /* Push the new jit block to block stack and continue to
           translate current basic block */
        if (!push_jit_block_to_stack_and_pass_params(
                cc, block, cc.cur_basic_block, 0, false))
            goto fail;
    }
    else if (label_type == LABEL_TYPE_LOOP) {
        bh_assert(!block.basic_block_entry);
        if (((block.basic_block_entry = cc.new_basic_block( 0)) is null)) {
            jit_set_last_error(cc, "create basic block failed");
            goto fail;
        }
        *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
        *(cc.jit_annl_begin_bcip( jit_basic_block_label(block.basic_block_entry))) = *p_frame_ip;
        /* Push the new jit block to block stack and continue to
           translate the new basic block */
        if (!push_jit_block_to_stack_and_pass_params(
                cc, block, block.basic_block_entry, 0, false))
            goto fail;
    }
    else if (label_type == LABEL_TYPE_IF) {
        if (cc.pop_i32(value))
            goto fail;
        if (!jit_reg_is_const_val(value)) {
            /* Compare value is not constant, create condition br IR */
            /* Create entry block */
            do {
                bh_assert(!block.basic_block_entry);
                if (((block.basic_block_entry = cc.new_basic_block( 0)) is null)) {
                    jit_set_last_error(cc, "create basic block failed");
                    goto fail;
                }
            }
            while (0);
            *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
            *(cc.jit_annl_begin_bcip( jit_basic_block_label(block.basic_block_entry))) = *p_frame_ip;
            if (!push_jit_block_to_stack_and_pass_params(
                    cc, block, block.basic_block_entry, value,
                    merge_cmp_and_if))
                goto fail;
        }
        else {
            if (cc.get_const_I32( value) != 0) {
                /* Compare value is not 0, condition is true, else branch of
                   BASIC_BLOCK if cannot be reached, we treat it same as
                   LABEL_TYPE_BLOCK and start to translate if branch */
                if (!push_jit_block_to_stack_and_pass_params(
                        cc, block, cc.cur_basic_block, 0, false))
                    goto fail;
            }
            else {
                if (else_addr) {
                    /* Compare value is not 0, condition is false, if branch of
                       BASIC_BLOCK if cannot be reached, we treat it same as
                       LABEL_TYPE_BLOCK and start to translate else branch */
                    if (!push_jit_block_to_stack_and_pass_params(
                            cc, block, cc.cur_basic_block, 0, false))
                        goto fail;
                    *p_frame_ip = else_addr + 1;
                }
                else {
                    /* The whole if block cannot be reached, skip it */
                    jit_block_destroy(block);
                    *p_frame_ip = end_addr + 1;
                }
            }
        }
    }
    else {
        jit_set_last_error(cc, "Invalid block type");
        goto fail;
    }
    return true;
fail:
    /* Only destroy the block if it hasn't been pushed into
      the block stack, or if will be destroyed again when
      destroying the block stack */
    if (jit_block_stack_top(&cc.block_stack) != block)
        jit_block_destroy(block);
    return false;
}

bool jit_compile_op_else(JitCompContext* cc, ubyte** p_frame_ip) {
    return handle_op_else(cc, p_frame_ip, false);
}

bool jit_compile_op_end(JitCompContext* cc, ubyte** p_frame_ip) {
    return handle_op_end(cc, p_frame_ip, false);
}
/* Check whether need to copy arities when jumping from current block
   to the dest block */
private bool check_copy_arities(const(JitBlock)* block_dst, JitFrame* jit_frame) {
    JitValueSlot* frame_sp_src = null;
    if (block_dst.label_type == LABEL_TYPE_LOOP) {
        frame_sp_src =
            jit_frame.sp
            - wasm_get_cell_num(block_dst.param_types, block_dst.param_count);
        /* There are parameters to copy and the src/dst addr are different */
        return (block_dst.param_count > 0
                && block_dst.frame_sp_begin != frame_sp_src)
            ? true : false;
    }
    else {
        frame_sp_src = jit_frame.sp
            - wasm_get_cell_num(block_dst.result_types,
                    block_dst.result_count);
        /* There are results to copy and the src/dst addr are different */
        return (block_dst.result_count > 0
                && block_dst.frame_sp_begin != frame_sp_src)
            ? true : false;
    }
}

private bool handle_op_br(JitCompContext* cc, uint br_depth, ubyte** p_frame_ip) {
    JitFrame* jit_frame = void;
    JitBlock* block_dst = void, block = void;
    JitReg frame_sp_dst = void;
    JitInsn* insn = void;
    bool copy_arities = void;
    uint offset = void;
    /* Check block stack */
    if (((block = jit_block_stack_top(&cc.block_stack)) == 0)) {
        jit_set_last_error(cc, "WASM block stack underflow");
        return false;
    }
    if (((block_dst = get_target_block(cc, br_depth)) == 0)) {
        return false;
    }
    jit_frame = cc.jit_frame;
    /* Only opy parameters or results when their count > 0 and
       the src/dst addr are different */
    copy_arities = check_copy_arities(block_dst, jit_frame);
    if (copy_arities) {
        frame_sp_dst = jit_cc_new_reg_ptr(cc);
        offset = WASMInterpFrame.lp.offsetof
            + (block_dst.frame_sp_begin - jit_frame.lp) * 4;
        cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(frame_sp_dst, cc.fp_reg, jit_cc_new_const_PTR(
                cc, offset))));
        /* No need to commit results as they will be copied to dest block */
        gen_commit_values(jit_frame, jit_frame.lp, block.frame_sp_begin);
    }
    else {
        /* Commit all including results as they won't be copied */
        gen_commit_values(jit_frame, jit_frame.lp, jit_frame.sp);
    }
    if (block_dst.label_type == LABEL_TYPE_LOOP) {
        if (copy_arities) {
            /* Dest block is Loop block, copy loop parameters */
            copy_block_arities(cc, frame_sp_dst, block_dst.param_types,
                    block_dst.param_count, null);
        }
        clear_values(jit_frame);
        /* Jump to the begin basic block */
        if (!cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(jit_basic_block_label(block_dst
                .basic_block_entry))))) {
            jit_set_last_error(cc, "generate jmp insn failed");
            goto fail;
        }
        *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
    }
    else {
        if (copy_arities) {
            /* Dest block is Block/If/Function block, copy block results */
            copy_block_arities(cc, frame_sp_dst, block_dst.result_types,
                    block_dst.result_count, null);
        }
        clear_values(jit_frame);
        /* Jump to the end basic block */
        if (((insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(0)))) == 0)) {
            jit_set_last_error(cc, "generate jmp insn failed");
            goto fail;
        }
        if (!jit_block_add_incoming_insn(block_dst, insn, 0)) {
            jit_set_last_error(cc, "add incoming insn failed");
            goto fail;
        }
        *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
    }
    return true;
fail:
    return false;
}

bool jit_compile_op_br(JitCompContext* cc, uint br_depth, ubyte** p_frame_ip) {
    return handle_op_br(cc, br_depth, p_frame_ip)
        && handle_next_reachable_block(cc, p_frame_ip);
}

private JitFrame* jit_frame_clone(const(JitFrame)* jit_frame) {
    JitFrame* jit_frame_cloned = void;
    uint max_locals = jit_frame.max_locals;
    uint max_stacks = jit_frame.max_stacks;
    uint total_size = void;
    total_size = cast(uint)(JitFrame.lp.offsetof
            + sizeof(*jit_frame.lp) * (max_locals + max_stacks));
    jit_frame_cloned = jit_calloc(total_size);
    if (jit_frame_cloned) {
        bh_memcpy_s(jit_frame_cloned, total_size, jit_frame, total_size);
        jit_frame_cloned.sp =
            jit_frame_cloned.lp + (jit_frame.sp - jit_frame.lp);
    }
    return jit_frame_cloned;
}

private void jit_frame_copy(JitFrame* jit_frame_dst, const(JitFrame)* jit_frame_src) {
    uint max_locals = jit_frame_src.max_locals;
    uint max_stacks = jit_frame_src.max_stacks;
    uint total_size = void;
    total_size =
        cast(uint)(JitFrame.lp.offsetof
                + sizeof(*jit_frame_src.lp) * (max_locals + max_stacks));
    bh_memcpy_s(jit_frame_dst, total_size, jit_frame_src, total_size);
    jit_frame_dst.sp =
        jit_frame_dst.lp + (jit_frame_src.sp - jit_frame_src.lp);
}

bool jit_compile_op_br_if(JitCompContext* cc, uint br_depth, bool merge_cmp_and_br_if, ubyte** p_frame_ip) {
    JitFrame* jit_frame, jit_frame_cloned;
    JitBlock* block_dst;
    JitReg cond = void;
    JitBasicBlock* cur_basic_block, if_basic_block;
    JitInsn* insn, insn_select, insn_cmp;
    bool copy_arities = void;
    if (((block_dst = get_target_block(cc, br_depth)) is null)) {
        return false;
    }
    /* append IF to current basic block */
    if (cc.pop_i32(cond))
        goto fail;
    if (merge_cmp_and_br_if) {
        get_last_cmp_and_selectcc(cc, cond, &insn_cmp, &insn_select);
    }
    jit_frame = cc.jit_frame;
    cur_basic_block = cc.cur_basic_block;
    //    gen_commit_values(jit_frame, jit_frame.lp, jit_frame.sp);
    jit_frame.gen_commit_values; //(jit_frame, jit_frame.lp, jit_frame.sp);
    if (!(insn_select && insn_cmp)) {
        if (!cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, cond, 
		cc.new_const_I32( 0))))) {
            jit_set_last_error(cc, "generate cmp insn failed");
            goto fail;
        }
    }
    /* Only opy parameters or results when their count > 0 and
       the src/dst addr are different */
    copy_arities = check_copy_arities(block_dst, jit_frame);
    if (!copy_arities) {
        if (block_dst.label_type == LABEL_TYPE_LOOP) {
            if (((insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BNE(cc.cmp_reg, jit_basic_block_label(
                    block_dst.basic_block_entry), 0)))) is null)) {
                jit_set_last_error(cc, "generate bne insn failed");
                goto fail;
            }
        }
        else {
            if (((insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BNE(cc.cmp_reg, 0, 0)))) is null)) {
                jit_set_last_error(cc, "generate bne insn failed");
                goto fail;
            }
            if (!jit_block_add_incoming_insn(block_dst, insn, 1)) {
                jit_set_last_error(cc, "add incoming insn failed");
                goto fail;
            }
        }
        if (insn_select && insn_cmp) {
            /* Change `CMP + SELECTcc` into `CMP + Bcc` */
            insn.opcode = cast(JitOpcode)(JIT_OP_BEQ + (insn_select.opcode - JIT_OP_SELECTEQ));
            jit_insn_unlink(insn_select);
            jit_insn_delete(insn_select);
        }
        return true;
    }
    bh_assert(!if_basic_block);
    if (((if_basic_block = cc.new_basic_block( 0)) is null)) {
        jit_set_last_error(cc, "create basic block failed");
        goto fail;
    }
    if (((insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BNE(cc.cmp_reg, jit_basic_block_label(if_basic_block), 0)))) is null)) {
        jit_set_last_error(cc, "generate bne insn failed");
        goto fail;
    }
    if (insn_select && insn_cmp) {
        /* Change `CMP + SELECTcc` into `CMP + Bcc` */
        insn.opcode = cast(JitOpcode)(JIT_OP_BEQ + (insn_select.opcode - JIT_OP_SELECTEQ));
        jit_insn_unlink(insn_select);
        jit_insn_delete(insn_select);
    }
    cc.cur_basic_block = if_basic_block;
    *(cc.jit_annl_begin_bcip( jit_basic_block_label(if_basic_block))) = *p_frame_ip - 1;
    /* Clone current jit frame to a new jit fame */
    if (((jit_frame_cloned = jit_frame_clone(jit_frame)) is null)) {
        jit_set_last_error(cc, "allocate memory failed");
        goto fail;
    }
    /* Clear current jit frame so that the registers
       in the new basic block will be loaded again */
    jit_frame.clear_values;
    if (!handle_op_br(cc, br_depth, p_frame_ip)) {
        jit_free(jit_frame_cloned);
        goto fail;
    }
    /* Restore the jit frame so that the registers can
       be used again in current basic block */
    jit_frame_copy(jit_frame, jit_frame_cloned);
    jit_free(jit_frame_cloned);
    /* Continue processing opcodes after BR_IF */
    cc.cur_basic_block = cur_basic_block;
    return true;
fail:
    return false;
}

bool jit_compile_op_br_table(JitCompContext* cc, uint* br_depths, uint br_count, ubyte** p_frame_ip) {
    JitBasicBlock* cur_basic_block = void;
    JitReg value = void;
    JitInsn* insn = void;
    uint i = 0;
    JitOpndLookupSwitch* opnd = null;
    cur_basic_block = cc.cur_basic_block;
    cc.pop_i32(value);
    /* append LOOKUPSWITCH to current basic block */
    //gen_commit_values(cc.jit_frame, cc.jit_frame.lp, cc.jit_frame.sp);
    cc.jit_frame.gen_commit_values;
    /* Clear frame values */
    //clear_values(cc.jit_frame);
    cc.jit_frame.clear_values;
    *(cc.jit_annl_end_bcip( jit_basic_block_label(cur_basic_block))) = *p_frame_ip - 1;
    /* prepare basic blocks for br */
    insn = cc._gen_insn( _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LOOKUPSWITCH(value, br_count)));
    if (null == insn) {
        jit_set_last_error(cc, "generate insn LOOKUPSWITCH failed");
        goto fail;
    }
    for (i = 0, opnd = jit_insn_opndls(insn); i < br_count + 1; i++) {
        JitBasicBlock* basic_block = null;
        JitBlock* block_dst = void;
        bool copy_arities = void;
        if (((block_dst = get_target_block(cc, br_depths[i])) is null)) {
            goto fail;
        }
        /* Only opy parameters or results when their count > 0 and
           the src/dst addr are different */
        copy_arities = check_copy_arities(block_dst, cc.jit_frame);
        if (!copy_arities) {
            /* No need to create new basic block, direclty jump to
               the existing basic block when no need to copy arities */
            if (i == br_count) {
                if (block_dst.label_type == LABEL_TYPE_LOOP) {
                    opnd.default_target =
                        jit_basic_block_label(block_dst.basic_block_entry);
                }
                else {
                    bh_assert(!block_dst.basic_block_end);
                    if (!jit_block_add_incoming_insn(block_dst, insn, i)) {
                        jit_set_last_error(cc, "add incoming insn failed");
                        goto fail;
                    }
                }
            }
            else {
                opnd.match_pairs[i].value = i;
                if (block_dst.label_type == LABEL_TYPE_LOOP) {
                    opnd.match_pairs[i].target =
                        jit_basic_block_label(block_dst.basic_block_entry);
                }
                else {
                    bh_assert(!block_dst.basic_block_end);
                    if (!jit_block_add_incoming_insn(block_dst, insn, i)) {
                        jit_set_last_error(cc, "add incoming insn failed");
                        goto fail;
                    }
                }
            }
            continue;
        }
        /* Create new basic block when need to copy arities */
        bh_assert(!basic_block);
        if (((basic_block = cc.new_basic_block( 0)) is null)) {
            jit_set_last_error(cc, "create basic block failed");
            goto fail;
        }
        *(cc.jit_annl_begin_bcip( jit_basic_block_label(basic_block))) = *p_frame_ip - 1;
        if (i == br_count) {
            opnd.default_target = jit_basic_block_label(basic_block);
        }
        else {
            opnd.match_pairs[i].value = i;
            opnd.match_pairs[i].target = jit_basic_block_label(basic_block);
        }
        cc.cur_basic_block = basic_block;
        if (!handle_op_br(cc, br_depths[i], p_frame_ip))
        goto fail;
    }
    /* Search next available block to handle */
    return handle_next_reachable_block(cc, p_frame_ip);
fail:
    return false;
}

bool jit_compile_op_return(JitCompContext* cc, ubyte** p_frame_ip) {
    JitBlock* block_func = cc.block_stack.block_list_head;
    bh_assert(block_func !is null);
    if (!handle_func_return(cc, block_func)) {
        return false;
    }
    *(cc.jit_annl_end_bcip( jit_basic_block_label(cc.cur_basic_block))) = *p_frame_ip - 1;
    //clear_values(cc.jit_frame);
    cc.jit_frame.clear_values;
    return handle_next_reachable_block(cc, p_frame_ip);
}

bool jit_compile_op_unreachable(JitCompContext* cc, ubyte** p_frame_ip) {
    if (!jit_emit_exception(cc, EXCE_UNREACHABLE, JIT_OP_JMP, 0, null))
        return false;
    return handle_next_reachable_block(cc, p_frame_ip);
}

bool jit_handle_next_reachable_block(JitCompContext* cc, ubyte** p_frame_ip) {
    return handle_next_reachable_block(cc, p_frame_ip);
}
