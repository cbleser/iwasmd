module tagion.iwasm.fast_jit.fe.jit_emit_exception;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_ir : JitCompContext, JitReg, JitBasicBlock;
bool jit_emit_exception(JitCompContext* cc, int exception_id, ubyte jit_opcode, JitReg cond_br_if, JitBasicBlock* cond_br_else_block) {
    JitInsn* insn = null;
    JitIncomingInsn* incoming_insn = void;
    JitReg else_label = void;

    bh_assert(exception_id < EXCE_NUM);

    if (jit_opcode >= JIT_OP_BEQ && jit_opcode <= JIT_OP_BLEU) {
        bh_assert(cond_br_if == cc.cmp_reg);
        else_label =
            cond_br_else_block ? jit_basic_block_label(cond_br_else_block) : 0;
        switch (jit_opcode) {
            case JIT_OP_BEQ:
                insn = GEN_INSN(BEQ, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BNE:
                insn = GEN_INSN(BNE, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BGTS:
                insn = GEN_INSN(BGTS, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BGES:
                insn = GEN_INSN(BGES, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BLTS:
                insn = GEN_INSN(BLTS, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BLES:
                insn = GEN_INSN(BLES, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BGTU:
                insn = GEN_INSN(BGTU, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BGEU:
                insn = GEN_INSN(BGEU, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BLTU:
                insn = GEN_INSN(BLTU, cond_br_if, 0, else_label);
                break;
            case JIT_OP_BLEU:
                insn = GEN_INSN(BLEU, cond_br_if, 0, else_label);
                break;
        default: break;}
        if (!insn) {
            jit_set_last_error(cc, "generate cond br insn failed");
            return false;
        }
    }
    else if (jit_opcode == JIT_OP_JMP) {
        insn = GEN_INSN(JMP, 0);
        if (!insn) {
            jit_set_last_error(cc, "generate jmp insn failed");
            return false;
        }
    }

    incoming_insn = jit_calloc(JitIncomingInsn.sizeof);
    if (!incoming_insn) {
        jit_set_last_error(cc, "allocate memory failed");
        return false;
    }

    incoming_insn.insn = insn;
    incoming_insn.next = cc.incoming_insns_for_exec_bbs[exception_id];
    cc.incoming_insns_for_exec_bbs[exception_id] = incoming_insn;
    return true;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
