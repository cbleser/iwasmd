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
module insn_opnd_tmp;
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
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_ir : JitReg, JitInsn;
/**
 * Operand kinds of instructions.
 */
enum JIT_OPND_KIND : ubyte {
    Reg,
    VReg,
    LookupSwitch
};
struct JitOpnd {
align(1):
    JIT_OPND_KIND kind;
    ubyte num;
    ubyte first_use;
}

immutable(JitOpnd[]) insn_opnd = [
    /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
    /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
    /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
    /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.VReg, 1, 1),
    /* conversion. will extend or truncate */
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    /* Arithmetic and bitwise instructions: */
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 2, 1),
    /* Select instruction: */
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 1),
    /* Memory access instructions: */
    JitOpnd(JIT_OPND_KIND.Reg, 1, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 1, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 1),
    /* Control instructions */
    JitOpnd(JIT_OPND_KIND.Reg, 1, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.LookupSwitch, 1, 0),
    /* Call and return instructions */
    JitOpnd(JIT_OPND_KIND.VReg, 2, 1),
    JitOpnd(JIT_OPND_KIND.Reg, 4, 2),
    JitOpnd(JIT_OPND_KIND.Reg, 3, 0),
    JitOpnd(JIT_OPND_KIND.Reg, 1, 0),
    /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Basic Block of a label.  */
    /* Predecessor number of the block that is only used in
   jit_cc_update_cfg for updating the CFG.  */
    /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
    /* Begin bytecode instruction pointer of the block.  */
    /* End bytecode instruction pointer of the block.  */
    /* Stack pointer offset at the end of the block.  */
    /* The label of the next physically adjacent block.  */
    /* Compiled code address of the block.  */
    /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
    /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Defining instruction of registers satisfying SSA property.  */
];
void jit_cc_destroy(JitCompContext* cc) {
    uint i = void, end = void;
    JitBasicBlock* block = void;
    JitIncomingInsn* incoming_insn = void, incoming_insn_next = void;
    jit_block_stack_destroy(&cc.block_stack);
    if (cc.jit_frame) {
        if (cc.jit_frame.memory_regs)
            jit_free(cc.jit_frame.memory_regs);
        if (cc.jit_frame.table_regs)
            jit_free(cc.jit_frame.table_regs);
        jit_free(cc.jit_frame);
    }
    if (cc.memory_regs)
        jit_free(cc.memory_regs);
    if (cc.table_regs)
        jit_free(cc.table_regs);
    jit_free(cc._const_val._hash_table);
    /* Release the instruction hash table.  */
    jit_cc_disable_insn_hash(cc);
    jit_free(cc.exce_basic_blocks);
    if (cc.incoming_insns_for_exec_bbs) {
        for (i = 0; i < EXCE_NUM; i++) {
            incoming_insn = cc.incoming_insns_for_exec_bbs[i];
            while (incoming_insn) {
                incoming_insn_next = incoming_insn.next;
                jit_free(incoming_insn);
                incoming_insn = incoming_insn_next;
            }
        }
        jit_free(cc.incoming_insns_for_exec_bbs);
    }
    /* Release entry and exit blocks.  */
    if (0 != cc.entry_label)
        jit_basic_block_delete(jit_cc_entry_basic_block(cc));
    if (0 != cc.exit_label)
        jit_basic_block_delete(jit_cc_exit_basic_block(cc));
    /* clang-format off */
    /* Release blocks and instructions.  */
    //    JIT_FOREACH_BLOCK(cc, i, end, block)
    for (i = 0, end = cc._ann._label_num; i < end; i++)
        if ((block = cc._ann._label_basic_block[i])) {
        jit_basic_block_delete(block);
    }
    /* clang-format on */
    /* Release constant values.  */
    for (i = JIT_REG_KIND_VOID; i < JIT_REG_KIND_L32; i++) {
        jit_free(cc._const_val._value[i]);
        jit_free(cc._const_val._next[i]);
    }
    /* Release storage of annotations.  */
    /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
    /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
    /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
    /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
    /* conversion. will extend or truncate */
    /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
    /* Arithmetic and bitwise instructions: */
    /* Select instruction: */
    /* Memory access instructions: */
    /* Control instructions */
    /* Call and return instructions */
    /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Basic Block of a label.  */
    jit_annl_disable_basic_block(cc);
    /* Predecessor number of the block that is only used in
   jit_cc_update_cfg for updating the CFG.  */
    jit_annl_disable_pred_num(cc);
    /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
    jit_annl_disable_freq(cc);
    /* Begin bytecode instruction pointer of the block.  */
    jit_annl_disable_begin_bcip(cc);
    /* End bytecode instruction pointer of the block.  */
    jit_annl_disable_end_bcip(cc);
    /* Stack pointer offset at the end of the block.  */
    jit_annl_disable_end_sp(cc);
    /* The label of the next physically adjacent block.  */
    jit_annl_disable_next_label(cc);
    /* Compiled code address of the block.  */
    jit_annl_disable_jitted_addr(cc);
    /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
    jit_anni_disable__hash_link(cc);
    /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Defining instruction of registers satisfying SSA property.  */
    jit_annr_disable_def_insn(cc);
}


