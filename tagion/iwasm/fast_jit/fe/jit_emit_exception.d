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
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BEQ(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BNE:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BNE(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BGTS:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BGTS(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BGES:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BGES(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BLTS:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BLTS(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BLES:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BLES(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BGTU:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BGTU(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BGEU:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BGEU(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BLTU:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BLTU(cond_br_if, 0, else_label)));
                break;
            case JIT_OP_BLEU:
                insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_BLEU(cond_br_if, 0, else_label)));
                break;
        default: break;}
        if (!insn) {
            jit_set_last_error(cc, "generate cond br insn failed");
            return false;
        }
    }
    else if (jit_opcode == JIT_OP_JMP) {
        insn = _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_JMP(0)));
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
