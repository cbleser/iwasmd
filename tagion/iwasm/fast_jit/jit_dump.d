module jit_dump_tmp;
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
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.basic;
import tagion.iwasm.fast_jit.jit_compiler;
import tagion.iwasm.fast_jit.jit_codegen;
import tagion.iwasm.fast_jit.jit_ir;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.share.utils.bh_assert;
import tagion.iwasm.interpreter.wasm : WASMModule, EXPORT_KIND_FUNC;
void jit_dump_reg(JitCompContext* cc, JitReg reg) {
    uint kind = jit_reg_kind(reg);
    uint no = jit_reg_no(reg);
    switch (kind) {
        case JitRegKind.VOID:
            os_printf("VOID");
            break;

        case JitRegKind.I32:
            if (jit_reg_is_const(reg)) {
                uint rel = jit_cc_get_const_I32_rel(cc, reg);
                os_printf("0x%x", jit_cc_get_const_I32(cc, reg));
                if (rel)
                    os_printf("(rel: 0x%x)", rel);
            }
            else
                os_printf("i%d", no);
            break;

        case JitRegKind.I64:
            if (jit_reg_is_const(reg))
                os_printf("0x%llxL", jit_cc_get_const_I64(cc, reg));
            else
                os_printf("I%d", no);
            break;

        case JitRegKind.F32:
            if (jit_reg_is_const(reg))
                os_printf("%f", jit_cc_get_const_F32(cc, reg));
            else
                os_printf("f%d", no);
            break;

        case JitRegKind.F64:
            if (jit_reg_is_const(reg))
                os_printf("%fL", jit_cc_get_const_F64(cc, reg));
            else
                os_printf("D%d", no);
            break;

        case JitRegKind.L32:
            os_printf("L%d", no);
            break;
        default:
            bh_assert(0, "Unsupported register kind.");
    }
}
private void jit_dump_insn_Reg(JitCompContext* cc, JitInsn* insn, uint opnd_num) {
    uint i = void;
    for (i = 0; i < opnd_num; i++) {
        os_printf(i == 0 ? " " : ", ");
        jit_dump_reg(cc, *(jit_insn_opnd(insn, i)));
    }
    os_printf("\n");
}
private void jit_dump_insn_VReg(JitCompContext* cc, JitInsn* insn, uint opnd_num) {
    uint i = void;
    opnd_num = jit_insn_opndv_num(insn);
    for (i = 0; i < opnd_num; i++) {
        os_printf(i == 0 ? " " : ", ");
        jit_dump_reg(cc, *(jit_insn_opndv(insn, i)));
    }
    os_printf("\n");
}
private void jit_dump_insn_LookupSwitch(JitCompContext* cc, JitInsn* insn, uint opnd_num) {
    uint i = void;
    JitOpndLookupSwitch* opnd = jit_insn_opndls(insn);
    os_printf(" ");
    jit_dump_reg(cc, opnd.value);
    os_printf("\n%16s: ", "default".ptr);
    jit_dump_reg(cc, opnd.default_target);
    os_printf("\n");
    for (i = 0; i < opnd.match_pairs_num; i++) {
        os_printf("%18d: ", opnd.match_pairs[i].value);
        jit_dump_reg(cc, opnd.match_pairs[i].target);
        os_printf("\n");
    }
}
void jit_dump_insn(JitCompContext* cc, JitInsn* insn) {
    switch (insn.opcode) {
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
case JIT_OP_MOV: os_printf("    %-15s", "MOV".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_PHI: os_printf("    %-15s", "PHI".ptr); jit_dump_insn_VReg(cc, insn, 1); break;
/* conversion. will extend or truncate */
case JIT_OP_I8TOI32: os_printf("    %-15s", "I8TOI32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I8TOI64: os_printf("    %-15s", "I8TOI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I16TOI32: os_printf("    %-15s", "I16TOI32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I16TOI64: os_printf("    %-15s", "I16TOI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOI8: os_printf("    %-15s", "I32TOI8".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOU8: os_printf("    %-15s", "I32TOU8".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOI16: os_printf("    %-15s", "I32TOI16".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOU16: os_printf("    %-15s", "I32TOU16".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOI64: os_printf("    %-15s", "I32TOI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOF32: os_printf("    %-15s", "I32TOF32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I32TOF64: os_printf("    %-15s", "I32TOF64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_U32TOI64: os_printf("    %-15s", "U32TOI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_U32TOF32: os_printf("    %-15s", "U32TOF32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_U32TOF64: os_printf("    %-15s", "U32TOF64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I64TOI8: os_printf("    %-15s", "I64TOI8".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I64TOI16: os_printf("    %-15s", "I64TOI16".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I64TOI32: os_printf("    %-15s", "I64TOI32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I64TOF32: os_printf("    %-15s", "I64TOF32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I64TOF64: os_printf("    %-15s", "I64TOF64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F32TOI32: os_printf("    %-15s", "F32TOI32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F32TOI64: os_printf("    %-15s", "F32TOI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F32TOF64: os_printf("    %-15s", "F32TOF64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F32TOU32: os_printf("    %-15s", "F32TOU32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F64TOI32: os_printf("    %-15s", "F64TOI32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F64TOI64: os_printf("    %-15s", "F64TOI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F64TOF32: os_printf("    %-15s", "F64TOF32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F64TOU32: os_printf("    %-15s", "F64TOU32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
/**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
case JIT_OP_I32CASTF32: os_printf("    %-15s", "I32CASTF32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_I64CASTF64: os_printf("    %-15s", "I64CASTF64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F32CASTI32: os_printf("    %-15s", "F32CASTI32".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_F64CASTI64: os_printf("    %-15s", "F64CASTI64".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
/* Arithmetic and bitwise instructions: */
case JIT_OP_NEG: os_printf("    %-15s", "NEG".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_NOT: os_printf("    %-15s", "NOT".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_ADD: os_printf("    %-15s", "ADD".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_SUB: os_printf("    %-15s", "SUB".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_MUL: os_printf("    %-15s", "MUL".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_DIV_S: os_printf("    %-15s", "DIV_S".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_REM_S: os_printf("    %-15s", "REM_S".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_DIV_U: os_printf("    %-15s", "DIV_U".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_REM_U: os_printf("    %-15s", "REM_U".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_SHL: os_printf("    %-15s", "SHL".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_SHRS: os_printf("    %-15s", "SHRS".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_SHRU: os_printf("    %-15s", "SHRU".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_ROTL: os_printf("    %-15s", "ROTL".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_ROTR: os_printf("    %-15s", "ROTR".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_OR: os_printf("    %-15s", "OR".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_XOR: os_printf("    %-15s", "XOR".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_AND: os_printf("    %-15s", "AND".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_CMP: os_printf("    %-15s", "CMP".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_MAX: os_printf("    %-15s", "MAX".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_MIN: os_printf("    %-15s", "MIN".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_CLZ: os_printf("    %-15s", "CLZ".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_CTZ: os_printf("    %-15s", "CTZ".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
case JIT_OP_POPCNT: os_printf("    %-15s", "POPCNT".ptr); jit_dump_insn_Reg(cc, insn, 2); break;
/* Select instruction: */
case JIT_OP_SELECTEQ: os_printf("    %-15s", "SELECTEQ".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTNE: os_printf("    %-15s", "SELECTNE".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTGTS: os_printf("    %-15s", "SELECTGTS".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTGES: os_printf("    %-15s", "SELECTGES".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTLTS: os_printf("    %-15s", "SELECTLTS".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTLES: os_printf("    %-15s", "SELECTLES".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTGTU: os_printf("    %-15s", "SELECTGTU".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTGEU: os_printf("    %-15s", "SELECTGEU".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTLTU: os_printf("    %-15s", "SELECTLTU".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_SELECTLEU: os_printf("    %-15s", "SELECTLEU".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
/* Memory access instructions: */
case JIT_OP_LDEXECENV: os_printf("    %-15s", "LDEXECENV".ptr); jit_dump_insn_Reg(cc, insn, 1); break;
case JIT_OP_LDJITINFO: os_printf("    %-15s", "LDJITINFO".ptr); jit_dump_insn_Reg(cc, insn, 1); break;
case JIT_OP_LDI8: os_printf("    %-15s", "LDI8".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDU8: os_printf("    %-15s", "LDU8".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDI16: os_printf("    %-15s", "LDI16".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDU16: os_printf("    %-15s", "LDU16".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDI32: os_printf("    %-15s", "LDI32".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDU32: os_printf("    %-15s", "LDU32".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDI64: os_printf("    %-15s", "LDI64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDU64: os_printf("    %-15s", "LDU64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDF32: os_printf("    %-15s", "LDF32".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDF64: os_printf("    %-15s", "LDF64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDPTR: os_printf("    %-15s", "LDPTR".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDV64: os_printf("    %-15s", "LDV64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDV128: os_printf("    %-15s", "LDV128".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LDV256: os_printf("    %-15s", "LDV256".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STI8: os_printf("    %-15s", "STI8".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STI16: os_printf("    %-15s", "STI16".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STI32: os_printf("    %-15s", "STI32".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STI64: os_printf("    %-15s", "STI64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STF32: os_printf("    %-15s", "STF32".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STF64: os_printf("    %-15s", "STF64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STPTR: os_printf("    %-15s", "STPTR".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STV64: os_printf("    %-15s", "STV64".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STV128: os_printf("    %-15s", "STV128".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_STV256: os_printf("    %-15s", "STV256".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
/* Control instructions */
case JIT_OP_JMP: os_printf("    %-15s", "JMP".ptr); jit_dump_insn_Reg(cc, insn, 1); break;
case JIT_OP_BEQ: os_printf("    %-15s", "BEQ".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BNE: os_printf("    %-15s", "BNE".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BGTS: os_printf("    %-15s", "BGTS".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BGES: os_printf("    %-15s", "BGES".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BLTS: os_printf("    %-15s", "BLTS".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BLES: os_printf("    %-15s", "BLES".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BGTU: os_printf("    %-15s", "BGTU".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BGEU: os_printf("    %-15s", "BGEU".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BLTU: os_printf("    %-15s", "BLTU".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_BLEU: os_printf("    %-15s", "BLEU".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_LOOKUPSWITCH: os_printf("    %-15s", "LOOKUPSWITCH".ptr); jit_dump_insn_LookupSwitch(cc, insn, 1); break;
/* Call and return instructions */
case JIT_OP_CALLNATIVE: os_printf("    %-15s", "CALLNATIVE".ptr); jit_dump_insn_VReg(cc, insn, 2); break;
case JIT_OP_CALLBC: os_printf("    %-15s", "CALLBC".ptr); jit_dump_insn_Reg(cc, insn, 4); break;
case JIT_OP_RETURNBC: os_printf("    %-15s", "RETURNBC".ptr); jit_dump_insn_Reg(cc, insn, 3); break;
case JIT_OP_RETURN: os_printf("    %-15s", "RETURN".ptr); jit_dump_insn_Reg(cc, insn, 1); break;
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

    default: break;}
}
void jit_dump_basic_block(JitCompContext* cc, JitBasicBlock* block) {
    uint i = void, label_index = void;
    void* begin_addr = void, end_addr = void;
    JitBasicBlock* block_next = void;
    JitInsn* insn = void;
    JitRegVec preds = jit_basic_block_preds(block);
    JitRegVec succs = jit_basic_block_succs(block);
    JitReg label = jit_basic_block_label(block), label_next = void;
    JitReg* reg = void;
    jit_dump_reg(cc, label);
    os_printf(":\n    ; PREDS(");

    //JIT_REG_VEC_FOREACH(preds, (i, reg)
    for (i = 0, reg = preds._base; i < preds.num; i++, reg += preds._stride)
    {
        if (i > 0)
            os_printf(" ");
        jit_dump_reg(cc, *reg);
    }
    os_printf(")\n    ;");
    if (jit_annl_is_enabled_begin_bcip(cc))
        os_printf(" BEGIN_BCIP=0x%04tx",
                  *(cc.jit_annl_begin_bcip(label))
                      - cast(ubyte*)cc.cur_wasm_module.load_addr);
    if (jit_annl_is_enabled_end_bcip(cc))
        os_printf(" END_BCIP=0x%04tx",
                  *(cc.jit_annl_end_bcip(label))
                      - cast(ubyte*)cc.cur_wasm_module.load_addr);
    os_printf("\n");
    if (jit_annl_is_enabled_jitted_addr(cc)) {
        begin_addr = *(cc.jit_annl_jitted_addr(label));
        if (label == cc.entry_label) {
            block_next = cc._ann._label_basic_block[2];
            label_next = jit_basic_block_label(block_next);
            end_addr = *(cc.jit_annl_jitted_addr(label_next));
        }
        else if (label == cc.exit_label) {
            end_addr = cc.jitted_addr_end;
        }
        else {
            label_index = jit_reg_no(label);
            if (label_index < jit_cc_label_num(cc) - 1)
                block_next = cc._ann._label_basic_block[label_index + 1];
            else
                block_next = cc._ann._label_basic_block[1];
            label_next = jit_basic_block_label(block_next);
            end_addr = *(cc.jit_annl_jitted_addr(label_next));
        }
        jit_codegen_dump_native(begin_addr, end_addr);
    }
    else {
        /* Dump IR.  */
        //JIT_FOREACH_INSN(block, insn); jit_dump_insn(cc, insn);
        for (insn = jit_basic_block_first_insn(block); insn	 != jit_basic_block_end_insn(block); 
         insn = insn.next) {
jit_dump_insn(cc, insn);
		}
}

    os_printf("    ; SUCCS(");

    //JIT_REG_VEC_FOREACH(succs,  (i, reg)
    for (i = 0, reg = succs._base; i < succs.num; i++, reg += succs._stride)
    {
        if (i > 0)
            os_printf(" ");
        jit_dump_reg(cc, *reg);
    }
    os_printf(")\n\n");
}
private void dump_func_name(JitCompContext* cc) {
    const(char)* func_name = null;
    WASMModule* module_ = cc.cur_wasm_module;

version (WASM_ENABLE_CUSTOM_NAME_SECTION ) {
    func_name = cc.cur_wasm_func.field_name;
}

    /* if custom name section is not generated,
       search symbols from export table */
    if (!func_name) {
        uint i = void;
        for (i = 0; i < module_.export_count; i++) {
            if (module_.exports[i].kind == EXPORT_KIND_FUNC
                && module_.exports[i].index == cc.cur_wasm_func_idx) {
                func_name = module_.exports[i].name;
                break;
            }
        }
    }
    /* function name not exported, print number instead */
    if (func_name == null) {
        os_printf("$f%d", cc.cur_wasm_func_idx);
    }
    else {
        os_printf("%s", func_name);
    }
}
private void dump_cc_ir(JitCompContext* cc) {
    uint i = void, end = void;
    JitBasicBlock* block = void;
    JitReg label = void;
    const(char)*[8] kind_names = [ "VOID", "I32", "I64",  "F32",
                                 "F64",  "V64", "V128", "V256" ];

    os_printf("; Function: ");
    dump_func_name(cc);
    os_printf("\n");
    os_printf("; Constant table sizes:");

    for (i = 0; i < JitRegKind.L32; i++)
        os_printf(" %s=%d", kind_names[i], cc._const_val._num[i]);
    os_printf("\n; Label number: %d", jit_cc_label_num(cc));
    os_printf("\n; Instruction number: %d", cc.insn_num);
    os_printf("\n; Register numbers:");
    for (i = 0; i < JIT_REG_KIND_L32; i++)
        os_printf(" %s=%d", kind_names[i], cc.reg_num(i));
    os_printf("\n; Label annotations:");
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

    for (i = 0; i < JitRegKind.L32; i++)
        os_printf(" %s=%d", kind_names[i], cc.reg_num(i));

/* conversion. will extend or truncate */

	enum string ANN_LABEL(string TYPE, string NAME) = `           \
    if (jit_annl_is_enabled_##NAME(cc)) \
        os_printf(" %s", #NAME);`;


























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
if (jit_annl_is_enabled_basic_block(cc)) os_printf(" %s", "basic_block".ptr);
/* Predecessor number of the block that is only used in
   jit_cc_update_cfg for updating the CFG.  */
if (jit_annl_is_enabled_pred_num(cc)) os_printf(" %s", "pred_num".ptr);
/* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
if (jit_annl_is_enabled_freq(cc)) os_printf(" %s", "freq".ptr);
/* Begin bytecode instruction pointer of the block.  */
if (jit_annl_is_enabled_begin_bcip(cc)) os_printf(" %s", "begin_bcip".ptr);
/* End bytecode instruction pointer of the block.  */
if (jit_annl_is_enabled_end_bcip(cc)) os_printf(" %s", "end_bcip".ptr);
/* Stack pointer offset at the end of the block.  */
if (jit_annl_is_enabled_end_sp(cc)) os_printf(" %s", "end_sp".ptr);
/* The label of the next physically adjacent block.  */
if (jit_annl_is_enabled_next_label(cc)) os_printf(" %s", "next_label".ptr);
/* Compiled code address of the block.  */
if (jit_annl_is_enabled_jitted_addr(cc)) os_printf(" %s", "jitted_addr".ptr);
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

    os_printf("\n; Instruction annotations:");
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
if (jit_anni_is_enabled__hash_link(cc)) os_printf(" %s", "_hash_link".ptr);
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

    os_printf("\n; Register annotations:");
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
if (jit_annr_is_enabled_def_insn(cc)) os_printf(" %s", "def_insn".ptr);
    os_printf("\n\n");
    if (jit_annl_is_enabled_next_label(cc)) {
        /* Blocks have been reordered, use that order to dump.  */
        for (label = cc.entry_label; label;
             label = *(cc.jit_annl_next_label(label)))
            jit_dump_basic_block(cc, *(cc.jit_annl_basic_block(label)));
    }
    else {
        /* Otherwise, use the default order.  */
        jit_dump_basic_block(cc, cc.entry_basic_block);

//        JIT_FOREACH_BLOCK(cc, i, end, block) jit_dump_basic_block(cc, block);
     for (i = 2, end = cc._ann._label_num; i < end; i++) { 
        if ((block = cc._ann._label_basic_block[i]) !is null) {
		jit_dump_basic_block(cc, block);
        
		}
		}

   }
}
void jit_dump_cc(JitCompContext* cc) {
    if (jit_cc_label_num(cc) <= 2)
        return;
    dump_cc_ir(cc);
}
bool jit_pass_dump(JitCompContext* cc) {
    const(JitGlobals)* jit_globals = jit_compiler_get_jit_globals();
    const(ubyte)* passes = jit_globals.passes;
    ubyte pass_no = cc.cur_pass_no;
    const(char)* pass_name = pass_no > 0 ? jit_compiler_get_pass_name(passes[pass_no - 1]) : "NULL";

static if (ver.BUILD_TARGET_X86_64 || ver.BUILD_TARGET_AMD_64) {
    if (!strcmp(pass_name, "lower_cg"))
        /* Ignore lower codegen pass as it does nothing in x86-64 */
        return true;
}

    os_printf("JIT.COMPILER.DUMP: PASS_NO=%d PREV_PASS=%s\n\n", pass_no,
              pass_name);
    jit_dump_cc(cc);
    os_printf("\n");
    return true;
}
bool jit_pass_update_cfg(JitCompContext* cc) {
    return jit_cc_update_cfg(cc);
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
/**
 * Dump a register.
 *
 * @param cc compilation context of the register
 * @param reg register to be dumped
 */
void jit_dump_reg(JitCompContext* cc, JitReg reg);

/**
 * Dump an instruction.
 *
 * @param cc compilation context of the instruction
 * @param insn instruction to be dumped
 */
void jit_dump_insn(JitCompContext* cc, JitInsn* insn);

/**
 * Dump a block.
 *
 * @param cc compilation context of the block
 * @param block block to be dumped
 */
void jit_dump_block(JitCompContext* cc, JitBlock* block);

/**
 * Dump a compilation context.
 *
 * @param cc compilation context to be dumped
 */
void jit_dump_cc(JitCompContext* cc);

