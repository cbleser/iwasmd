module tagion.iwasm.fast_jit.jit_ir;
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
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
//#include "bh_platform.h"
//#include "../interpreter/wasm.h"
//#include "jit_utils.h"
/**
 * Register (operand) representation of JIT IR.
 *
 * Encoding: [4-bit: kind, 28-bit register no.]
 *
 * Registers in JIT IR are classified into different kinds according
 * to types of values they can hold. The classification is based on
 * most processors' hardware register classifications, which include
 * various sets of integer, floating point and vector registers with
 * different sizes. These registers can be mapped onto corresponding
 * kinds of hardware registers by register allocator. Instructions
 * can only operate on allowed kinds of registers. For example, an
 * integer instruction cannot operate on floating point or vector
 * registers. Some encodings of these kinds of registers also
 * represent immediate constant values and indexes to constant tables
 * (see below). In that case, those registers are read-only. Writing
 * to them is illegal. Reading from an immediate constant value
 * register always returns the constant value encoded in the register
 * no. Reading from a constant table index register always returns
 * the constant value stored at the encoded index of the constant
 * table of the register's kind. Immediate constant values and values
 * indexed by constant table indexes can only be loaded into the
 * corresponding kinds of registers if they must be loaded into
 * registers. Besides these common kinds of registers, labels of
 * basic blocks are also treated as registers of a special kind, which
 * hold code addresses of basic block labels and are read-only. Each
 * basic block is assigned one unique label register. With this
 * unification, we can use the same set of load instructions to load
 * values either from addresses stored in normal registers or from
 * addresses of labels. Besides these register kinds, the void kind
 * is a special kind of registers to denote some error occurs when a
 * normal register is expected. Or it can be used as result operand
 * of call and invoke instructions to denote no return values. The
 * variable registers are classified into two sets: the hard registers
 * whose register numbers are less than the hard register numbers of
 * their kinds and the virtual registers whose register numbers are
 * greater than or equal to the hard register numbers. Before
 * register allocation is done, hard registers may appear in the IR
 * due to special usages of passes frontend (e.g. fp_reg and exec_env_reg)
 * or lower_cg. In the mean time (including during register
 * allocation), those hard registers are treated same as virtual
 * registers except that they may not be SSA and they can only be
 * allocated to the hard registers of themselves.
 *
 * Classification of registers:
 *   + void register (kind == JIT_REG_KIND_VOID, no. must be 0)
 *   + label registers (kind == JIT_REG_KIND_L32)
 *   + value registers (kind == JIT_REG_KIND_I32/I64/F32/F64/V64/V128/V256)
 *   | + constants (_JIT_REG_CONST_VAL_FLAG | _JIT_REG_CONST_IDX_FLAG)
 *   | | + constant values (_JIT_REG_CONST_VAL_FLAG)
 *   | | + constant indexes (_JIT_REG_CONST_IDX_FLAG)
 *   | + variables (!(_JIT_REG_CONST_VAL_FLAG | _JIT_REG_CONST_IDX_FLAG))
 *   | | + hard registers (no. < hard register number)
 *   | | + virtual registers (no. >= hard register number)
 */
alias JitReg = uint;
/*
 * Mask and shift bits of register kind.
 */
enum _JIT_REG_KIND_MASK = 0xf0000000;
enum _JIT_REG_KIND_SHIFT = 28;
/*
 * Mask of register no. which must be the least significant bits.
 */
enum _JIT_REG_NO_MASK = (~_JIT_REG_KIND_MASK);
/*
 * Constant value flag (the most significant bit) of register
 * no. field of integer, floating point and vector registers. If this
 * flag is set in the register no., the rest bits of register
 * no. represent a signed (27-bit) integer constant value of the
 * corresponding type of the register and the register is read-only.
 */
enum _JIT_REG_CONST_VAL_FLAG = ((_JIT_REG_NO_MASK >> 1) + 1);
/*
 * Constant index flag of non-constant-value (constant value flag is
 * not set in register no. field) integer, floating point and vector
 * regisers. If this flag is set, the rest bits of the register
 * no. represent an index to the constant value table of the
 * corresponding type of the register and the register is read-only.
 */
enum _JIT_REG_CONST_IDX_FLAG = (_JIT_REG_CONST_VAL_FLAG >> 1);
/**
 * Register kinds. Don't change the order of the defined values. The
 * L32 kind must be after all normal kinds (see _const_val and _reg_ann
 * of JitCompContext).
 */
import core.stdc.string : memset, memcpy, memcmp;
import core.stdc.stdint : uintptr_t;
import core.stdc.stdarg;
import core.stdc.stdio : snprintf, vsnprintf;
import tagion.iwasm.interpreter.wasm_runtime : EXCE_NUM;
import tagion.iwasm.fast_jit.jit_utils;
import tagion.iwasm.share.utils.bh_assert;
import tagion.iwasm.interpreter.wasm : WASMModule, WASMFunction, 
VALUE_TYPE_I32, VALUE_TYPE_I64, VALUE_TYPE_F32, VALUE_TYPE_F64;
import tagion.iwasm.fast_jit.insn_opnd;
import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_frame : JitValueSlot;
import tagion.iwasm.fast_jit.jit_codegen : jit_codegen_get_hreg_info;
enum JitRegKind {
    VOID = 0x00, /* void type */
    I32 = 0x01, /* 32-bit signed or unsigned integer */
    I64 = 0x02, /* 64-bit signed or unsigned integer */
    F32 = 0x03, /* 32-bit floating point */
    F64 = 0x04, /* 64-bit floating point */
    V64 = 0x05, /* 64-bit vector */
    V128 = 0x06, /* 128-bit vector */
    V256 = 0x07, /* 256-bit vector */
    L32 = 0x08, /* 32-bit label address */
    NUM /* number of register kinds */
}

alias JIT_REG_KIND_VOID = JitRegKind.VOID;
alias JIT_REG_KIND_I32 = JitRegKind.I32;
alias JIT_REG_KIND_I64 = JitRegKind.I64;
alias JIT_REG_KIND_F32 = JitRegKind.F32;
alias JIT_REG_KIND_F64 = JitRegKind.F64;
alias JIT_REG_KIND_V64 = JitRegKind.V64;
alias JIT_REG_KIND_V128 = JitRegKind.V128;
alias JIT_REG_KIND_V256 = JitRegKind.V256;
alias JIT_REG_KIND_L32 = JitRegKind.L32;
alias JIT_REG_KIND_NUM = JitRegKind.NUM;

static if (uintptr_t.max == ulong.max) {
    enum JIT_REG_KIND_PTR = JIT_REG_KIND_I64;
}
else {
    enum JIT_REG_KIND_PTR = JIT_REG_KIND_I32;
}
/**
 * Construct a new JIT IR register from the kind and no.
 *
 * @param reg_kind register kind
 * @param reg_no register no.
 *
 * @return the new register with the given kind and no.
 */
pragma(inline, true) JitReg jit_reg_new(uint reg_kind, uint reg_no) {
    return cast(JitReg)((reg_kind << _JIT_REG_KIND_SHIFT) | reg_no);
}
/**
 * Get the register kind of the given register.
 *
 * @param r a JIT IR register
 *
 * @return the register kind of register r
 */
pragma(inline, true) int jit_reg_kind(JitReg r) {
    return (r & _JIT_REG_KIND_MASK) >> _JIT_REG_KIND_SHIFT;
}
/**
 * Get the register no. of the given JIT IR register.
 *
 * @param r a JIT IR register
 *
 * @return the register no. of register r
 */
pragma(inline, true) int jit_reg_no(JitReg r) {
    return r & _JIT_REG_NO_MASK;
}
/**
 * Check whether the given register is a normal value register.
 *
 * @param r a JIT IR register
 *
 * @return true iff the register is a normal value register
 */
pragma(inline, true) bool jit_reg_is_value(JitReg r) {
    uint kind = jit_reg_kind(r);
    return kind > JIT_REG_KIND_VOID && kind < JIT_REG_KIND_L32;
}
/**
 * Check whether the given register is a constant value.
 *
 * @param r a JIT IR register
 *
 * @return true iff register r is a constant value
 */
pragma(inline, true) bool jit_reg_is_const_val(JitReg r) {
    return jit_reg_is_value(r) && (r & _JIT_REG_CONST_VAL_FLAG);
}
/**
 * Check whether the given register is a constant table index.
 *
 * @param r a JIT IR register
 *
 * @return true iff register r is a constant table index
 */
pragma(inline, true) bool jit_reg_is_const_idx(JitReg r) {
    return (jit_reg_is_value(r) && !jit_reg_is_const_val(r)
            && (r & _JIT_REG_CONST_IDX_FLAG));
}
/**
 * Check whether the given register is a constant.
 *
 * @param r a JIT IR register
 *
 * @return true iff register r is a constant
 */
pragma(inline, true) bool jit_reg_is_const(JitReg r) {
    return (jit_reg_is_value(r)
            && (r & (_JIT_REG_CONST_VAL_FLAG | _JIT_REG_CONST_IDX_FLAG)));
}
/**
 * Check whether the given register is a normal variable register.
 *
 * @param r a JIT IR register
 *
 * @return true iff the register is a normal variable register
 */
pragma(inline, true) bool jit_reg_is_variable(JitReg r) {
    return (jit_reg_is_value(r)
            && !(r & (_JIT_REG_CONST_VAL_FLAG | _JIT_REG_CONST_IDX_FLAG)));
}
/**
 * Test whether the register is the given kind.
 *
 * @param KIND register kind name
 * @param R register
 *
 * @return true if the register is the given kind
 */
//#define jit_reg_is_kind(KIND, R) (jit_reg_kind(R) == JIT_REG_KIND_##KIND)
/**
 * Construct a zero IR register with given the kind.
 *
 * @param kind the kind of the value
 *
 * @return a constant register of zero
 */
pragma(inline, true) JitReg jit_reg_new_zero(uint kind) {
    bh_assert(kind != JIT_REG_KIND_VOID && kind < JIT_REG_KIND_L32);
    return jit_reg_new(kind, _JIT_REG_CONST_VAL_FLAG);
}
/**
 * Test whether the register is a zero constant value.
 *
 * @param reg an IR register
 *
 * @return true iff the register is a constant zero
 */
pragma(inline, true) JitReg jit_reg_is_zero(JitReg reg) {
    return (jit_reg_is_value(reg)
            && jit_reg_no(reg) == _JIT_REG_CONST_VAL_FLAG);
}
/**
 * Operand of instructions with fixed-number register operand(s).
 */
alias JitOpndReg = JitReg;
/**
 * Operand of instructions with variable-number register operand(s).
 */
struct JitOpndVReg {
    uint _reg_num;
    JitReg[1] _reg;
}
/**
 * Operand of lookupswitch instruction.
 */
struct JitOpndLookupSwitch {
    /* NOTE: distance between JitReg operands must be the same (see
       jit_insn_opnd_regs). */
    JitReg value; /* the value to be compared */
    uint match_pairs_num; /* match pairs number */
    /* NOTE: offset between adjacent targets must be sizeof
       (match_pairs[0]) (see implementation of jit_basic_block_succs),
       so the default_target field must be here. */
    JitReg default_target; /* default target BB */
    struct _Match_pairs {
        int value; /* match value of the match pair */
        JitReg target; /* target BB of the match pair */
    }

    _Match_pairs[1] match_pairs; /* match pairs of the instruction */
}
/**
 * Instruction of JIT IR.
 */
struct JitInsn {
    /* Pointers to the previous and next instructions. */
    JitInsn* prev;
    JitInsn* next;
    /* Opcode of the instruction. */
    JitOpcode opcode;
    /* Reserved field that may be used by optimizations locally. */
    ubyte flags_u8;
    /* The unique ID of the instruction. */
    ushort uid;
    /* Operands for different kinds of instructions. */
    union __opnd {
        /* For instructions with fixed-number register operand(s). */
        JitOpndReg[1] _opnd_Reg;
        /* For instructions with variable-number register operand(s). */
        JitOpndVReg _opnd_VReg;
        /* For lookupswitch instruction. */
        JitOpndLookupSwitch _opnd_LookupSwitch;
    }

    __opnd _opnd;
}
/**
 * Opcodes of IR instructions.
 */
enum JitOpcode : ubyte {
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
    JIT_OP_MOV,
    JIT_OP_PHI,
    /* conversion. will extend or truncate */
    JIT_OP_I8TOI32,
    JIT_OP_I8TOI64,
    JIT_OP_I16TOI32,
    JIT_OP_I16TOI64,
    JIT_OP_I32TOI8,
    JIT_OP_I32TOU8,
    JIT_OP_I32TOI16,
    JIT_OP_I32TOU16,
    JIT_OP_I32TOI64,
    JIT_OP_I32TOF32,
    JIT_OP_I32TOF64,
    JIT_OP_U32TOI64,
    JIT_OP_U32TOF32,
    JIT_OP_U32TOF64,
    JIT_OP_I64TOI8,
    JIT_OP_I64TOI16,
    JIT_OP_I64TOI32,
    JIT_OP_I64TOF32,
    JIT_OP_I64TOF64,
    JIT_OP_F32TOI32,
    JIT_OP_F32TOI64,
    JIT_OP_F32TOF64,
    JIT_OP_F32TOU32,
    JIT_OP_F64TOI32,
    JIT_OP_F64TOI64,
    JIT_OP_F64TOF32,
    JIT_OP_F64TOU32,
    /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
    JIT_OP_I32CASTF32,
    JIT_OP_I64CASTF64,
    JIT_OP_F32CASTI32,
    JIT_OP_F64CASTI64,
    /* Arithmetic and bitwise instructions: */
    JIT_OP_NEG,
    JIT_OP_NOT,
    JIT_OP_ADD,
    JIT_OP_SUB,
    JIT_OP_MUL,
    JIT_OP_DIV_S,
    JIT_OP_REM_S,
    JIT_OP_DIV_U,
    JIT_OP_REM_U,
    JIT_OP_SHL,
    JIT_OP_SHRS,
    JIT_OP_SHRU,
    JIT_OP_ROTL,
    JIT_OP_ROTR,
    JIT_OP_OR,
    JIT_OP_XOR,
    JIT_OP_AND,
    JIT_OP_CMP,
    JIT_OP_MAX,
    JIT_OP_MIN,
    JIT_OP_CLZ,
    JIT_OP_CTZ,
    JIT_OP_POPCNT,
    /* Select instruction: */
    JIT_OP_SELECTEQ,
    JIT_OP_SELECTNE,
    JIT_OP_SELECTGTS,
    JIT_OP_SELECTGES,
    JIT_OP_SELECTLTS,
    JIT_OP_SELECTLES,
    JIT_OP_SELECTGTU,
    JIT_OP_SELECTGEU,
    JIT_OP_SELECTLTU,
    JIT_OP_SELECTLEU,
    /* Memory access instructions: */
    JIT_OP_LDEXECENV,
    JIT_OP_LDJITINFO,
    JIT_OP_LDI8,
    JIT_OP_LDU8,
    JIT_OP_LDI16,
    JIT_OP_LDU16,
    JIT_OP_LDI32,
    JIT_OP_LDU32,
    JIT_OP_LDI64,
    JIT_OP_LDU64,
    JIT_OP_LDF32,
    JIT_OP_LDF64,
    JIT_OP_LDPTR,
    JIT_OP_LDV64,
    JIT_OP_LDV128,
    JIT_OP_LDV256,
    JIT_OP_STI8,
    JIT_OP_STI16,
    JIT_OP_STI32,
    JIT_OP_STI64,
    JIT_OP_STF32,
    JIT_OP_STF64,
    JIT_OP_STPTR,
    JIT_OP_STV64,
    JIT_OP_STV128,
    JIT_OP_STV256,
    /* Control instructions */
    JIT_OP_JMP,
    JIT_OP_BEQ,
    JIT_OP_BNE,
    JIT_OP_BGTS,
    JIT_OP_BGES,
    JIT_OP_BLTS,
    JIT_OP_BLES,
    JIT_OP_BGTU,
    JIT_OP_BGEU,
    JIT_OP_BLTU,
    JIT_OP_BLEU,
    JIT_OP_LOOKUPSWITCH,
    /* Call and return instructions */
    JIT_OP_CALLNATIVE,
    JIT_OP_CALLBC,
    JIT_OP_RETURNBC,
    JIT_OP_RETURN,
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
    /* A annotation for linking instructions with the same hash
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

    JIT_OP_OPCODE_NUMBER
}

alias JIT_OP_MOV = JitOpcode.JIT_OP_MOV;
alias JIT_OP_PHI = JitOpcode.JIT_OP_PHI;
alias JIT_OP_I8TOI32 = JitOpcode.JIT_OP_I8TOI32;
alias JIT_OP_I8TOI64 = JitOpcode.JIT_OP_I8TOI64;
alias JIT_OP_I16TOI32 = JitOpcode.JIT_OP_I16TOI32;
alias JIT_OP_I16TOI64 = JitOpcode.JIT_OP_I16TOI64;
alias JIT_OP_I32TOI8 = JitOpcode.JIT_OP_I32TOI8;
alias JIT_OP_I32TOU8 = JitOpcode.JIT_OP_I32TOU8;
alias JIT_OP_I32TOI16 = JitOpcode.JIT_OP_I32TOI16;
alias JIT_OP_I32TOU16 = JitOpcode.JIT_OP_I32TOU16;
alias JIT_OP_I32TOI64 = JitOpcode.JIT_OP_I32TOI64;
alias JIT_OP_I32TOF32 = JitOpcode.JIT_OP_I32TOF32;
alias JIT_OP_I32TOF64 = JitOpcode.JIT_OP_I32TOF64;
alias JIT_OP_U32TOI64 = JitOpcode.JIT_OP_U32TOI64;
alias JIT_OP_U32TOF32 = JitOpcode.JIT_OP_U32TOF32;
alias JIT_OP_U32TOF64 = JitOpcode.JIT_OP_U32TOF64;
alias JIT_OP_I64TOI8 = JitOpcode.JIT_OP_I64TOI8;
alias JIT_OP_I64TOI16 = JitOpcode.JIT_OP_I64TOI16;
alias JIT_OP_I64TOI32 = JitOpcode.JIT_OP_I64TOI32;
alias JIT_OP_I64TOF32 = JitOpcode.JIT_OP_I64TOF32;
alias JIT_OP_I64TOF64 = JitOpcode.JIT_OP_I64TOF64;
alias JIT_OP_F32TOI32 = JitOpcode.JIT_OP_F32TOI32;
alias JIT_OP_F32TOI64 = JitOpcode.JIT_OP_F32TOI64;
alias JIT_OP_F32TOF64 = JitOpcode.JIT_OP_F32TOF64;
alias JIT_OP_F32TOU32 = JitOpcode.JIT_OP_F32TOU32;
alias JIT_OP_F64TOI32 = JitOpcode.JIT_OP_F64TOI32;
alias JIT_OP_F64TOI64 = JitOpcode.JIT_OP_F64TOI64;
alias JIT_OP_F64TOF32 = JitOpcode.JIT_OP_F64TOF32;
alias JIT_OP_F64TOU32 = JitOpcode.JIT_OP_F64TOU32;
alias JIT_OP_I32CASTF32 = JitOpcode.JIT_OP_I32CASTF32;
alias JIT_OP_I64CASTF64 = JitOpcode.JIT_OP_I64CASTF64;
alias JIT_OP_F32CASTI32 = JitOpcode.JIT_OP_F32CASTI32;
alias JIT_OP_F64CASTI64 = JitOpcode.JIT_OP_F64CASTI64;
alias JIT_OP_NEG = JitOpcode.JIT_OP_NEG;
alias JIT_OP_NOT = JitOpcode.JIT_OP_NOT;
alias JIT_OP_ADD = JitOpcode.JIT_OP_ADD;
alias JIT_OP_SUB = JitOpcode.JIT_OP_SUB;
alias JIT_OP_MUL = JitOpcode.JIT_OP_MUL;
alias JIT_OP_DIV_S = JitOpcode.JIT_OP_DIV_S;
alias JIT_OP_REM_S = JitOpcode.JIT_OP_REM_S;
alias JIT_OP_DIV_U = JitOpcode.JIT_OP_DIV_U;
alias JIT_OP_REM_U = JitOpcode.JIT_OP_REM_U;
alias JIT_OP_SHL = JitOpcode.JIT_OP_SHL;
alias JIT_OP_SHRS = JitOpcode.JIT_OP_SHRS;
alias JIT_OP_SHRU = JitOpcode.JIT_OP_SHRU;
alias JIT_OP_ROTL = JitOpcode.JIT_OP_ROTL;
alias JIT_OP_ROTR = JitOpcode.JIT_OP_ROTR;
alias JIT_OP_OR = JitOpcode.JIT_OP_OR;
alias JIT_OP_XOR = JitOpcode.JIT_OP_XOR;
alias JIT_OP_AND = JitOpcode.JIT_OP_AND;
alias JIT_OP_CMP = JitOpcode.JIT_OP_CMP;
alias JIT_OP_MAX = JitOpcode.JIT_OP_MAX;
alias JIT_OP_MIN = JitOpcode.JIT_OP_MIN;
alias JIT_OP_CLZ = JitOpcode.JIT_OP_CLZ;
alias JIT_OP_CTZ = JitOpcode.JIT_OP_CTZ;
alias JIT_OP_POPCNT = JitOpcode.JIT_OP_POPCNT;
alias JIT_OP_SELECTEQ = JitOpcode.JIT_OP_SELECTEQ;
alias JIT_OP_SELECTNE = JitOpcode.JIT_OP_SELECTNE;
alias JIT_OP_SELECTGTS = JitOpcode.JIT_OP_SELECTGTS;
alias JIT_OP_SELECTGES = JitOpcode.JIT_OP_SELECTGES;
alias JIT_OP_SELECTLTS = JitOpcode.JIT_OP_SELECTLTS;
alias JIT_OP_SELECTLES = JitOpcode.JIT_OP_SELECTLES;
alias JIT_OP_SELECTGTU = JitOpcode.JIT_OP_SELECTGTU;
alias JIT_OP_SELECTGEU = JitOpcode.JIT_OP_SELECTGEU;
alias JIT_OP_SELECTLTU = JitOpcode.JIT_OP_SELECTLTU;
alias JIT_OP_SELECTLEU = JitOpcode.JIT_OP_SELECTLEU;
alias JIT_OP_LDEXECENV = JitOpcode.JIT_OP_LDEXECENV;
alias JIT_OP_LDJITINFO = JitOpcode.JIT_OP_LDJITINFO;
alias JIT_OP_LDI8 = JitOpcode.JIT_OP_LDI8;
alias JIT_OP_LDU8 = JitOpcode.JIT_OP_LDU8;
alias JIT_OP_LDI16 = JitOpcode.JIT_OP_LDI16;
alias JIT_OP_LDU16 = JitOpcode.JIT_OP_LDU16;
alias JIT_OP_LDI32 = JitOpcode.JIT_OP_LDI32;
alias JIT_OP_LDU32 = JitOpcode.JIT_OP_LDU32;
alias JIT_OP_LDI64 = JitOpcode.JIT_OP_LDI64;
alias JIT_OP_LDU64 = JitOpcode.JIT_OP_LDU64;
alias JIT_OP_LDF32 = JitOpcode.JIT_OP_LDF32;
alias JIT_OP_LDF64 = JitOpcode.JIT_OP_LDF64;
alias JIT_OP_LDPTR = JitOpcode.JIT_OP_LDPTR;
alias JIT_OP_LDV64 = JitOpcode.JIT_OP_LDV64;
alias JIT_OP_LDV128 = JitOpcode.JIT_OP_LDV128;
alias JIT_OP_LDV256 = JitOpcode.JIT_OP_LDV256;
alias JIT_OP_STI8 = JitOpcode.JIT_OP_STI8;
alias JIT_OP_STI16 = JitOpcode.JIT_OP_STI16;
alias JIT_OP_STI32 = JitOpcode.JIT_OP_STI32;
alias JIT_OP_STI64 = JitOpcode.JIT_OP_STI64;
alias JIT_OP_STF32 = JitOpcode.JIT_OP_STF32;
alias JIT_OP_STF64 = JitOpcode.JIT_OP_STF64;
alias JIT_OP_STPTR = JitOpcode.JIT_OP_STPTR;
alias JIT_OP_STV64 = JitOpcode.JIT_OP_STV64;
alias JIT_OP_STV128 = JitOpcode.JIT_OP_STV128;
alias JIT_OP_STV256 = JitOpcode.JIT_OP_STV256;
alias JIT_OP_JMP = JitOpcode.JIT_OP_JMP;
alias JIT_OP_BEQ = JitOpcode.JIT_OP_BEQ;
alias JIT_OP_BNE = JitOpcode.JIT_OP_BNE;
alias JIT_OP_BGTS = JitOpcode.JIT_OP_BGTS;
alias JIT_OP_BGES = JitOpcode.JIT_OP_BGES;
alias JIT_OP_BLTS = JitOpcode.JIT_OP_BLTS;
alias JIT_OP_BLES = JitOpcode.JIT_OP_BLES;
alias JIT_OP_BGTU = JitOpcode.JIT_OP_BGTU;
alias JIT_OP_BGEU = JitOpcode.JIT_OP_BGEU;
alias JIT_OP_BLTU = JitOpcode.JIT_OP_BLTU;
alias JIT_OP_BLEU = JitOpcode.JIT_OP_BLEU;
alias JIT_OP_LOOKUPSWITCH = JitOpcode.JIT_OP_LOOKUPSWITCH;
alias JIT_OP_CALLNATIVE = JitOpcode.JIT_OP_CALLNATIVE;
alias JIT_OP_CALLBC = JitOpcode.JIT_OP_CALLBC;
alias JIT_OP_RETURNBC = JitOpcode.JIT_OP_RETURNBC;
alias JIT_OP_RETURN = JitOpcode.JIT_OP_RETURN;
alias JIT_OP_OPCODE_NUMBER = JitOpcode.JIT_OP_OPCODE_NUMBER;

/*
 * Helper functions for creating new instructions.  Don't call them
 * directly.  Use jit_insn_new_NAME, such as jit_insn_new_MOV instead.
 */
JitInsn* _jit_insn_new_Reg_1(JitOpcode opc, JitReg r0);
JitInsn* _jit_insn_new_Reg_2(JitOpcode opc, JitReg r0, JitReg r1);
JitInsn* _jit_insn_new_Reg_3(JitOpcode opc, JitReg r0, JitReg r1, JitReg r2);
JitInsn* _jit_insn_new_Reg_4(JitOpcode opc, JitReg r0, JitReg r1, JitReg r2, JitReg r3);
JitInsn* _jit_insn_new_Reg_5(JitOpcode opc, JitReg r0, JitReg r1, JitReg r2, JitReg r3, JitReg r4);
JitInsn* _jit_insn_new_VReg_1(JitOpcode opc, JitReg r0, int n);
JitInsn* _jit_insn_new_VReg_2(JitOpcode opc, JitReg r0, JitReg r1, int n);
JitInsn* _jit_insn_new_LookupSwitch_1(JitOpcode opc, JitReg value, uint num);
/*
 * Instruction creation functions jit_insn_new_NAME, where NAME is the
 * name of the instruction defined in jit_ir.def.
 */
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
pragma(inline, true) JitInsn* jit_insn_new_MOV(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_MOV, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_PHI(JitReg r0, int n) {
    return _jit_insn_new_VReg_1(JIT_OP_PHI, r0, n);
}
/* conversion. will extend or truncate */
pragma(inline, true) JitInsn* jit_insn_new_I8TOI32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I8TOI32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I8TOI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I8TOI64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I16TOI32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I16TOI32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I16TOI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I16TOI64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOI8(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOI8, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOU8(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOU8, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOI16(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOI16, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOU16(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOU16, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOI64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOF32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOF32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I32TOF64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32TOF64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_U32TOI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_U32TOI64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_U32TOF32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_U32TOF32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_U32TOF64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_U32TOF64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I64TOI8(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I64TOI8, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I64TOI16(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I64TOI16, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I64TOI32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I64TOI32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I64TOF32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I64TOF32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I64TOF64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I64TOF64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F32TOI32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F32TOI32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F32TOI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F32TOI64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F32TOF64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F32TOF64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F32TOU32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F32TOU32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F64TOI32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F64TOI32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F64TOI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F64TOI64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F64TOF32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F64TOF32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F64TOU32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F64TOU32, r0, r1);
}
/**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
pragma(inline, true) JitInsn* jit_insn_new_I32CASTF32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I32CASTF32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_I64CASTF64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_I64CASTF64, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F32CASTI32(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F32CASTI32, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_F64CASTI64(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_F64CASTI64, r0, r1);
}
/* Arithmetic and bitwise instructions: */
pragma(inline, true) JitInsn* jit_insn_new_NEG(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_NEG, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_NOT(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_NOT, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_ADD(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_ADD, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_SUB(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_SUB, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_MUL(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_MUL, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_DIV_S(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_DIV_S, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_REM_S(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_REM_S, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_DIV_U(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_DIV_U, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_REM_U(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_REM_U, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_SHL(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_SHL, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_SHRS(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_SHRS, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_SHRU(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_SHRU, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_ROTL(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_ROTL, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_ROTR(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_ROTR, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_OR(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_OR, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_XOR(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_XOR, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_AND(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_AND, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_CMP(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_CMP, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_MAX(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_MAX, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_MIN(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_MIN, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_CLZ(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_CLZ, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_CTZ(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_CTZ, r0, r1);
}

pragma(inline, true) JitInsn* jit_insn_new_POPCNT(JitReg r0, JitReg r1) {
    return _jit_insn_new_Reg_2(JIT_OP_POPCNT, r0, r1);
}
/* Select instruction: */
pragma(inline, true) JitInsn* jit_insn_new_SELECTEQ(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTEQ, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTNE(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTNE, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTGTS(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTGTS, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTGES(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTGES, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTLTS(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTLTS, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTLES(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTLES, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTGTU(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTGTU, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTGEU(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTGEU, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTLTU(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTLTU, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_SELECTLEU(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_SELECTLEU, r0, r1, r2, r3);
}
/* Memory access instructions: */
pragma(inline, true) JitInsn* jit_insn_new_LDEXECENV(JitReg r0) {
    return _jit_insn_new_Reg_1(JIT_OP_LDEXECENV, r0);
}

pragma(inline, true) JitInsn* jit_insn_new_LDJITINFO(JitReg r0) {
    return _jit_insn_new_Reg_1(JIT_OP_LDJITINFO, r0);
}

pragma(inline, true) JitInsn* jit_insn_new_LDI8(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDI8, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDU8(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDU8, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDI16(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDI16, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDU16(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDU16, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDI32(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDI32, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDU32(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDU32, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDI64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDI64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDU64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDU64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDF32(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDF32, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDF64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDF64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDPTR(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDPTR, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDV64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDV64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDV128(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDV128, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LDV256(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_LDV256, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STI8(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STI8, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STI16(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STI16, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STI32(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STI32, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STI64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STI64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STF32(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STF32, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STF64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STF64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STPTR(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STPTR, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STV64(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STV64, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STV128(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STV128, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_STV256(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_STV256, r0, r1, r2);
}
/* Control instructions */
pragma(inline, true) JitInsn* jit_insn_new_JMP(JitReg r0) {
    return _jit_insn_new_Reg_1(JIT_OP_JMP, r0);
}

pragma(inline, true) JitInsn* jit_insn_new_BEQ(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BEQ, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BNE(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BNE, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BGTS(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BGTS, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BGES(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BGES, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BLTS(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BLTS, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BLES(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BLES, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BGTU(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BGTU, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BGEU(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BGEU, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BLTU(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BLTU, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_BLEU(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_BLEU, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_LOOKUPSWITCH(JitReg value, uint num) {
    return _jit_insn_new_LookupSwitch_1(JIT_OP_LOOKUPSWITCH, value, num);
}
/* Call and return instructions */
pragma(inline, true) JitInsn* jit_insn_new_CALLNATIVE(JitReg r0, JitReg r1, int n) {
    return _jit_insn_new_VReg_2(JIT_OP_CALLNATIVE, r0, r1, n);
}

pragma(inline, true) JitInsn* jit_insn_new_CALLBC(JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    return _jit_insn_new_Reg_4(JIT_OP_CALLBC, r0, r1, r2, r3);
}

pragma(inline, true) JitInsn* jit_insn_new_RETURNBC(JitReg r0, JitReg r1, JitReg r2) {
    return _jit_insn_new_Reg_3(JIT_OP_RETURNBC, r0, r1, r2);
}

pragma(inline, true) JitInsn* jit_insn_new_RETURN(JitReg r0) {
    return _jit_insn_new_Reg_1(JIT_OP_RETURN, r0);
}
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
/* A annotation for linking instructions with the same hash
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

/**
 * Delete an instruction
 *
 * @param insn an instruction to be deleted
 */
pragma(inline, true) void jit_insn_delete(JitInsn* insn) {
    jit_free(insn);
}
/*
 * Runtime type check functions that check whether accessing the n-th
 * operand is legal. They are only used for in self-verification
 * mode.
 *
 * @param insn any JIT IR instruction
 * @param n index of the operand to access
 *
 * @return true if the access is legal
 */
bool _jit_insn_check_opnd_access_Reg(const(JitInsn)* insn, uint n);
bool _jit_insn_check_opnd_access_VReg(const(JitInsn)* insn, uint n);
bool _jit_insn_check_opnd_access_LookupSwitch(const(JitInsn)* insn);
/**
 * Get the pointer to the n-th register operand of the given
 * instruction. The instruction format must be Reg.
 *
 * @param insn a Reg format instruction
 * @param n index of the operand to get
 *
 * @return pointer to the n-th operand
 */
pragma(inline, true) JitReg* jit_insn_opnd(JitInsn* insn, int n) {
    bh_assert(_jit_insn_check_opnd_access_Reg(insn, n));
    return &insn._opnd._opnd_Reg[n];
}
/**
 * Get the pointer to the n-th register operand of the given
 * instruction. The instruction format must be VReg.
 *
 * @param insn a VReg format instruction
 * @param n index of the operand to get
 *
 * @return pointer to the n-th operand
 */
pragma(inline, true) JitReg* jit_insn_opndv(JitInsn* insn, int n) {
    bh_assert(_jit_insn_check_opnd_access_VReg(insn, n));
    return &insn._opnd._opnd_VReg._reg[n];
}
/**
 * Get the operand number of the given instruction. The instruction
 * format must be VReg.
 *
 * @param insn a VReg format instruction
 *
 * @return operand number of the instruction
 */
pragma(inline, true) uint jit_insn_opndv_num(const(JitInsn)* insn) {
    bh_assert(_jit_insn_check_opnd_access_VReg(insn, 0));
    return insn._opnd._opnd_VReg._reg_num;
}
/**
 * Get the pointer to the LookupSwitch operand of the given
 * instruction. The instruction format must be LookupSwitch.
 *
 * @param insn a LookupSwitch format instruction
 *
 * @return pointer to the operand
 */
pragma(inline, true) JitOpndLookupSwitch* jit_insn_opndls(JitInsn* insn) {
    bh_assert(_jit_insn_check_opnd_access_LookupSwitch(insn));
    return &insn._opnd._opnd_LookupSwitch;
}
/**
 * Insert instruction @p insn2 before instruction @p insn1.
 *
 * @param insn1 any instruction
 * @param insn2 any instruction
 */
void jit_insn_insert_before(JitInsn* insn1, JitInsn* insn2);
/**
 * Insert instruction @p insn2 after instruction @p insn1.
 *
 * @param insn1 any instruction
 * @param insn2 any instruction
 */
void jit_insn_insert_after(JitInsn* insn1, JitInsn* insn2);
/**
 * Unlink the instruction @p insn from the containing list.
 *
 * @param insn an instruction
 */
void jit_insn_unlink(JitInsn* insn);
/**
 * Get the hash value of the comparable instruction (pure functions
 * and exception check instructions).
 *
 * @param insn an instruction
 *
 * @return hash value of the instruction
 */
uint jit_insn_hash(JitInsn* insn);
/**
 * Compare whether the two comparable instructions are the same.
 *
 * @param insn1 the first instruction
 * @param insn2 the second instruction
 *
 * @return true if the two instructions are the same
 */
bool jit_insn_equal(JitInsn* insn1, JitInsn* insn2);
/**
 * Register vector for accessing predecessors and successors of a
 * basic block.
 */
struct JitRegVec {
    JitReg* _base; /* points to the first register */
    int _stride; /* stride to the next register */
    uint num; /* number of registers */
}
/**
 * Get the address of the i-th register in the register vector.
 *
 * @param vec a register vector
 * @param i index to the register vector
 *
 * @return the address of the i-th register in the vector
 */
pragma(inline, true) JitReg* jit_reg_vec_at(JitRegVec* vec, uint i) {
    bh_assert(i < vec.num);
    return vec._base + vec._stride * i;
}
/**
 * Visit each element in a register vector.
 *
 * @param V (JitRegVec) the register vector
 * @param I (unsigned) index variable in the vector
 * @param R (JitReg *) resiger pointer variable
 */
/**
 * Visit each register defined by an instruction.
 *
 * @param V (JitRegVec) register vector of the instruction
 * @param I (unsigned) index variable in the vector
 * @param R (JitReg *) resiger pointer variable
 * @param F index of the first used register
 */
/**
 * Visit each register used by an instruction.
 *
 * @param V (JitRegVec) register vector of the instruction
 * @param I (unsigned) index variable in the vector
 * @param R (JitReg *) resiger pointer variable
 * @param F index of the first used register
 */
/**
 * Get a generic register vector that contains all register operands.
 * The registers defined by the instruction, if any, appear before the
 * registers used by the instruction.
 *
 * @param insn an instruction
 *
 * @return a register vector containing register operands
 */
JitRegVec jit_insn_opnd_regs(JitInsn* insn);
/**
 * Get the index of the first use register in the register vector
 * returned by jit_insn_opnd_regs.
 *
 * @param insn an instruction
 *
 * @return the index of the first use register in the register vector
 */
uint jit_insn_opnd_first_use(JitInsn* insn);
/**
 * Basic Block of JIT IR. It is a basic block only if the IR is not in
 * non-BB form. The block is represented by a special phi node, whose
 * result and arguments are label registers. The result label is the
 * containing block's label. The arguments are labels of predecessors
 * of the block. Successor labels are stored in the last instruction,
 * which must be a control flow instruction. Instructions of a block
 * are linked in a circular linked list with the block phi node as the
 * end of the list. The next and prev field of the block phi node
 * point to the first and last instructions of the block.
 */
alias JitBasicBlock = JitInsn;
/**
 * Create a new basic block instance.
 *
 * @param label the label of the new basic block
 * @param n number of predecessors
 *
 * @return the created new basic block instance
 */
JitBasicBlock* jit_basic_block_new(JitReg label, int n);
/**
 * Delete a basic block instance and all instructions init.
 *
 * @param block the basic block to be deleted
 */
void jit_basic_block_delete(JitBasicBlock* block);
/**
 * Get the label of the basic block.
 *
 * @param block a basic block instance
 *
 * @return the label of the basic block
 */
pragma(inline, true) JitReg jit_basic_block_label(JitBasicBlock* block) {
    return *(jit_insn_opndv(block, 0));
}
/**
 * Get the first instruction of the basic block.
 *
 * @param block a basic block instance
 *
 * @return the first instruction of the basic block
 */
pragma(inline, true) JitInsn* jit_basic_block_first_insn(JitBasicBlock* block) {
    return block.next;
}
/**
 * Get the last instruction of the basic block.
 *
 * @param block a basic block instance
 *
 * @return the last instruction of the basic block
 */
pragma(inline, true) JitInsn* jit_basic_block_last_insn(JitBasicBlock* block) {
    return block.prev;
}
/**
 * Get the end of instruction list of the basic block (which is always
 * the block itself).
 *
 * @param block a basic block instance
 *
 * @return the end of instruction list of the basic block
 */
pragma(inline, true) JitInsn* jit_basic_block_end_insn(JitBasicBlock* block) {
    return block;
}
/**
 * Visit each instruction in the block from the first to the last. In
 * the code block, the instruction pointer @p I must be a valid
 * pointer to an instruction in the block. That means if the
 * instruction may be deleted, @p I must point to the previous or next
 * valid instruction before the next iteration.
 *
 * @param B (JitBasicBlock *) the block
 * @param I (JitInsn *) instruction visited
 */
/**
 * Visit each instruction in the block from the last to the first. In
 * the code block, the instruction pointer @p I must be a valid
 * pointer to an instruction in the block. That means if the
 * instruction may be deleted, @p I must point to the previous or next
 * valid instruction before the next iteration.
 *
 * @param B (JitBasicBlock *) the block
 * @param I (JitInsn *) instruction visited
 */
/**
 * Prepend an instruction in the front of the block. The position is
 * just after the block phi node (the block instance itself).
 *
 * @param block a block
 * @param insn an instruction to be prepended
 */
pragma(inline, true) void jit_basic_block_prepend_insn(JitBasicBlock* block, JitInsn* insn) {
    jit_insn_insert_after(block, insn);
}
/**
 * Append an instruction to the end of the basic block.
 *
 * @param block a basic block
 * @param insn an instruction to be appended
 */
pragma(inline, true) void jit_basic_block_append_insn(JitBasicBlock* block, JitInsn* insn) {
    jit_insn_insert_before(block, insn);
}
/**
 * Get the register vector of predecessors of a basic block.
 *
 * @param block a JIT IR block
 *
 * @return register vector of the predecessors
 */
JitRegVec jit_basic_block_preds(JitBasicBlock* block);
/**
 * Get the register vector of successors of a basic block.
 *
 * @param block a JIT IR basic block
 *
 * @return register vector of the successors
 */
JitRegVec jit_basic_block_succs(JitBasicBlock* block);
/**
 * Hard register information of one kind.
 */
struct JitHardRegInfo {
    struct _Info {
        /* Hard register number of this kind. */
        uint num;
        /* Whether each register is fixed. */
        const(ubyte)* fixed;
        /* Whether each register is caller-saved in the native ABI. */
        const(ubyte)* caller_saved_native;
        /* Whether each register is caller-saved in the JITed ABI. */
        const(ubyte)* caller_saved_jitted;
    }

    _Info[JIT_REG_KIND_L32] info;
    /* The indexes of hard registers of frame pointer, exec_env and cmp. */
    uint fp_hreg_index;
    uint exec_env_hreg_index;
    uint cmp_hreg_index;
}
/**
 * Value in the WASM operation stack, each stack element
 * is a Jit register
 */
struct JitValue {
    JitValue* next;
    JitValue* prev;
    JitValueSlot* value;
    /* VALUE_TYPE_I32/I64/F32/F64/VOID */
    ubyte type;
}
/**
 * Value stack, represents stack elements in a WASM block
 */
struct JitValueStack {
    JitValue* value_list_head;
    JitValue* value_list_end;
}
struct JitMemRegs {
    /* The following registers should be re-loaded after
       memory.grow, callbc and callnative */
    JitReg memory_data;
    JitReg memory_data_end;
    JitReg mem_bound_check_1byte;
    JitReg mem_bound_check_2bytes;
    JitReg mem_bound_check_4bytes;
    JitReg mem_bound_check_8bytes;
    JitReg mem_bound_check_16bytes;
}

struct JitTableRegs {
    JitReg table_elems;
    /* Should be re-loaded after table.grow,
       callbc and callnative */
    JitReg table_cur_size;
}
struct JitIncomingInsn {
    JitIncomingInsn* next;
    JitInsn* insn;
    uint opnd_idx;
}

alias JitIncomingInsnList = JitIncomingInsn*;
struct JitBlock {
    JitBlock* next;
    JitBlock* prev;
    /* The current Jit Block */
    JitCompContext* cc;
    /* LABEL_TYPE_BLOCK/LOOP/IF/FUNCTION */
    uint label_type;
    /* code of else opcode of this block, if it is a IF block  */
    ubyte* wasm_code_else;
    /* code of end opcode of this block */
    ubyte* wasm_code_end;
    /* JIT label points to code begin */
    JitBasicBlock* basic_block_entry;
    /* JIT label points to code else */
    JitBasicBlock* basic_block_else;
    /* JIT label points to code end */
    JitBasicBlock* basic_block_end;
    /* Incoming INSN for basic_block_else */
    JitInsn* incoming_insn_for_else_bb;
    /* Incoming INSNs for basic_block_end */
    JitIncomingInsnList incoming_insns_for_end_bb;
    /* WASM operation stack */
    JitValueStack value_stack;
    /* Param count/types/PHIs of this block */
    uint param_count;
    ubyte* param_types;
    /* Result count/types/PHIs of this block */
    uint result_count;
    ubyte* result_types;
    /* The begin frame stack pointer of this block */
    JitValueSlot* frame_sp_begin;
}
/**
 * Block stack, represents WASM block stack elements
 */
struct JitBlockStack {
    JitBlock* block_list_head;
    JitBlock* block_list_end;
}
/*
 * Annotation accessing functions jit_annl_NAME, jit_anni_NAME and
 * jit_annr_NAME.
 */
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
/*
 * Annotation enabling functions jit_annl_enable_NAME,
 * jit_anni_enable_NAME and jit_annr_enable_NAME, which allocate
 * sufficient memory for the annotations.
 */
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
bool jit_annl_enable_basic_block(JitCompContext* cc);
/* Predecessor number of the block that is only used in
   jit_cc_update_cfg for updating the CFG.  */
bool jit_annl_enable_pred_num(JitCompContext* cc);
/* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
bool jit_annl_enable_freq(JitCompContext* cc);
/* Begin bytecode instruction pointer of the block.  */
bool jit_annl_enable_begin_bcip(JitCompContext* cc);
/* End bytecode instruction pointer of the block.  */
bool jit_annl_enable_end_bcip(JitCompContext* cc);
/* Stack pointer offset at the end of the block.  */
bool jit_annl_enable_end_sp(JitCompContext* cc);
/* The label of the next physically adjacent block.  */
bool jit_annl_enable_next_label(JitCompContext* cc);
/* Compiled code address of the block.  */
bool jit_annl_enable_jitted_addr(JitCompContext* cc);
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
/* A annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
bool jit_anni_enable__hash_link(JitCompContext* cc);
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
bool jit_annr_enable_def_insn(JitCompContext* cc);
/*
 * Annotation disabling functions jit_annl_disable_NAME,
 * jit_anni_disable_NAME and jit_annr_disable_NAME, which release
 * memory of the annotations.  Before calling these functions,
 * resources owned by the annotations must be explictely released.
 */
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
void jit_annl_disable_basic_block(JitCompContext* cc);
/* Predecessor number of the block that is only used in
   jit_cc_update_cfg for updating the CFG.  */
void jit_annl_disable_pred_num(JitCompContext* cc);
/* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
void jit_annl_disable_freq(JitCompContext* cc);
/* Begin bytecode instruction pointer of the block.  */
void jit_annl_disable_begin_bcip(JitCompContext* cc);
/* End bytecode instruction pointer of the block.  */
void jit_annl_disable_end_bcip(JitCompContext* cc);
/* Stack pointer offset at the end of the block.  */
void jit_annl_disable_end_sp(JitCompContext* cc);
/* The label of the next physically adjacent block.  */
void jit_annl_disable_next_label(JitCompContext* cc);
/* Compiled code address of the block.  */
void jit_annl_disable_jitted_addr(JitCompContext* cc);
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
/* A annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
void jit_anni_disable__hash_link(JitCompContext* cc);
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
void jit_annr_disable_def_insn(JitCompContext* cc);
/*
 * Functions jit_annl_is_enabled_NAME, jit_anni_is_enabled_NAME and
 * jit_annr_is_enabled_NAME for checking whether an annotation is
 * enabled.
 */
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
pragma(inline, true) bool jit_annl_is_enabled_basic_block(JitCompContext* cc) {
    return !!cc._ann._label_basic_block_enabled;
}
/* Predecessor number of the block that is only used in
   jit_cc_update_cfg for updating the CFG.  */
pragma(inline, true) bool jit_annl_is_enabled_pred_num(JitCompContext* cc) {
    return !!cc._ann._label_pred_num_enabled;
}
/* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
pragma(inline, true) bool jit_annl_is_enabled_freq(JitCompContext* cc) {
    return !!cc._ann._label_freq_enabled;
}
/* Begin bytecode instruction pointer of the block.  */
pragma(inline, true) bool jit_annl_is_enabled_begin_bcip(JitCompContext* cc) {
    return !!cc._ann._label_begin_bcip_enabled;
}
/* End bytecode instruction pointer of the block.  */
pragma(inline, true) bool jit_annl_is_enabled_end_bcip(JitCompContext* cc) {
    return !!cc._ann._label_end_bcip_enabled;
}
/* Stack pointer offset at the end of the block.  */
pragma(inline, true) bool jit_annl_is_enabled_end_sp(JitCompContext* cc) {
    return !!cc._ann._label_end_sp_enabled;
}
/* The label of the next physically adjacent block.  */
pragma(inline, true) bool jit_annl_is_enabled_next_label(JitCompContext* cc) {
    return !!cc._ann._label_next_label_enabled;
}
/* Compiled code address of the block.  */
pragma(inline, true) bool jit_annl_is_enabled_jitted_addr(JitCompContext* cc) {
    return !!cc._ann._label_jitted_addr_enabled;
}
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
/* A annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
pragma(inline, true) bool jit_anni_is_enabled__hash_link(JitCompContext* cc) {
    return !!cc._ann._insn__hash_link_enabled;
}
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
pragma(inline, true) bool jit_annr_is_enabled_def_insn(JitCompContext* cc) {
    return !!cc._ann._reg_def_insn_enabled;
}
/**
 * Initialize a compilation context.
 *
 * @param cc the compilation context
 * @param htab_size the initial hash table size of constant pool
 *
 * @return cc if succeeds, NULL otherwise
 */
JitCompContext* jit_cc_init(JitCompContext* cc, uint htab_size);
/**
 * Release all resources of a compilation context, which doesn't
 * include the compilation context itself.
 *
 * @param cc the compilation context
 */
void jit_cc_destroy(JitCompContext* cc);
/**
 * Increase the reference count of the compilation context.
 *
 * @param cc the compilation context
 */
pragma(inline, true) void jit_cc_inc_ref(JitCompContext* cc) {
    cc._reference_count++;
}
/**
 * Decrease the reference_count and destroy and free the compilation
 * context if the reference_count is decreased to zero.
 *
 * @param cc the compilation context
 */
void jit_cc_delete(JitCompContext* cc);
char* jit_get_last_error(JitCompContext* cc);
void jit_set_last_error(JitCompContext* cc, const(char)* error);
void jit_set_last_error_v(JitCompContext* cc, const(char)* format, ...);
/**
 * Create a F32 constant value into the compilation context.
 *
 * @param cc compilation context
 * @param val a F32 value
 *
 * @return a constant register containing the value
 */
JitReg jit_cc_new_const_F32(JitCompContext* cc, float val);
/**
 * Create a F64 constant value into the compilation context.
 *
 * @param cc compilation context
 * @param val a F64 value
 *
 * @return a constant register containing the value
 */
JitReg jit_cc_new_const_F64(JitCompContext* cc, double val);
/**
 * Get the relocation info of a I32 constant register.
 *
 * @param cc compilation context
 * @param reg constant register
 *
 * @return the relocation info of the constant
 */
uint jit_cc_get_const_I32_rel(JitCompContext* cc, JitReg reg);
/**
 * Get the constant value of a I32 constant register.
 *
 * @param cc compilation context
 * @param reg constant register
 *
 * @return the constant value
 */
int jit_cc_get_const_I32(JitCompContext* cc, JitReg reg);
/**
 * Get the constant value of a I64 constant register.
 *
 * @param cc compilation context
 * @param reg constant register
 *
 * @return the constant value
 */
long jit_cc_get_const_I64(JitCompContext* cc, JitReg reg);
/**
 * Get the constant value of a F32 constant register.
 *
 * @param cc compilation context
 * @param reg constant register
 *
 * @return the constant value
 */
float jit_cc_get_const_F32(JitCompContext* cc, JitReg reg);
/**
 * Get the constant value of a F64 constant register.
 *
 * @param cc compilation context
 * @param reg constant register
 *
 * @return the constant value
 */
double jit_cc_get_const_F64(JitCompContext* cc, JitReg reg);
/**
 * Get the number of total created labels.
 *
 * @param cc the compilation context
 *
 * @return the number of total created labels
 */
pragma(inline, true) uint jit_cc_label_num(JitCompContext* cc) {
    return cc._ann._label_num;
}
/**
 * Create a new label in the compilation context.
 *
 * @param cc the compilation context
 *
 * @return a new label in the compilation context
 */
JitReg jit_cc_new_label(JitCompContext* cc);
/**
 * Create a new block with a new label in the compilation context.
 *
 * @param cc the compilation context
 * @param n number of predecessors
 *
 * @return a new block with a new label in the compilation context
 */
JitBasicBlock* jit_cc_new_basic_block(JitCompContext* cc, int n);
/**
 * Resize the predecessor number of a block.
 *
 * @param cc the containing compilation context
 * @param block block to be resized
 * @param n new number of predecessors
 *
 * @return the new block if succeeds, NULL otherwise
 */
JitBasicBlock* jit_cc_resize_basic_block(JitCompContext* cc, JitBasicBlock* block, int n);
/**
 * Initialize the instruction hash table to the given size and enable
 * the instruction's _hash_link annotation.
 *
 * @param cc the containing compilation context
 * @param n size of the hash table
 *
 * @return true if succeeds, false otherwise
 */
bool jit_cc_enable_insn_hash(JitCompContext* cc, uint n);
/**
 * Destroy the instruction hash table and disable the instruction's
 * _hash_link annotation.
 *
 * @param cc the containing compilation context
 */
void jit_cc_disable_insn_hash(JitCompContext* cc);
/**
 * Reset the hash table entries.
 *
 * @param cc the containing compilation context
 */
void jit_cc_reset_insn_hash(JitCompContext* cc);
/**
 * Allocate a new instruction ID in the compilation context and set it
 * to the given instruction.
 *
 * @param cc the compilation context
 * @param insn IR instruction
 *
 * @return the insn with uid being set
 */
JitInsn* jit_cc_set_insn_uid(JitCompContext* cc, JitInsn* insn);
/*
 * Similar to jit_cc_set_insn_uid except that if setting uid failed,
 * delete the insn.  Only used by jit_cc_new_insn
 */
JitInsn* _jit_cc_set_insn_uid_for_new_insn(JitCompContext* cc, JitInsn* insn);
/**
 * Create a new instruction in the compilation context.
 *
 * @param cc the compilationo context
 * @param NAME instruction name
 *
 * @return a new instruction in the compilation context
 */
/*
 * Helper function for jit_cc_new_insn_norm.
 */
JitInsn* _jit_cc_new_insn_norm(JitCompContext* cc, JitReg* result, JitInsn* insn);
void jit_value_stack_push(JitValueStack* stack, JitValue* value);
JitValue* jit_value_stack_pop(JitValueStack* stack);
void jit_value_stack_destroy(JitValueStack* stack);
void jit_block_stack_push(JitBlockStack* stack, JitBlock* block);
JitBlock* jit_block_stack_pop(JitBlockStack* stack);
void jit_block_stack_destroy(JitBlockStack* stack);
bool jit_block_add_incoming_insn(JitBlock* block, JitInsn* insn, uint opnd_idx);
void jit_block_destroy(JitBlock* block);
bool jit_cc_push_value(JitCompContext* cc, ubyte type, JitReg value);
bool jit_lock_reg_in_insn(JitCompContext* cc, JitInsn* the_insn, JitReg reg_to_lock);
/**
 * Update the control flow graph after successors of blocks are
 * changed so that the predecessor vector of each block represents the
 * updated status. The predecessors may not be required by all
 * passes, so we don't need to keep them always being updated.
 *
 * @param cc the compilation context
 *
 * @return true if succeeds, false otherwise
 */
bool jit_cc_update_cfg(JitCompContext* cc);
/**
 * Visit each normal block (which is not entry nor exit block) in a
 * compilation context. New blocks can be added in the loop body, but
 * they won't be visited. Blocks can also be removed safely (by
 * setting the label's block annotation to NULL) in the loop body.
 *
 * @param CC (JitCompContext *) the compilation context
 * @param I (unsigned) index variable of the block (label no)
 * @param E (unsigned) end index variable of block (last index + 1)
 * @param B (JitBasicBlock *) block pointer variable
 */
/**
 * The version that includes entry and exit block.
 */
/**
 * Visit each normal block (which is not entry nor exit block) in a
 * compilation context in reverse order. New blocks can be added in
 * the loop body, but they won't be visited. Blocks can also be
 * removed safely (by setting the label's block annotation to NULL) in
 * the loop body.
 *
 * @param CC (JitCompContext *) the compilation context
 * @param I (unsigned) index of the block (label no)
 * @param B (JitBasicBlock *) block pointer
 */
/**
 * The version that includes entry and exit block.
 */
//#include "jit_codegen.h"
////#include "jit_frontend.h"
JitInsn* _jit_insn_new_Reg_1(JitOpcode opc, JitReg r0) {
    JitInsn* insn = jit_calloc(JitInsn._opnd.offsetof + JitReg.sizeof * (1));
    if (insn) {
        insn.opcode = opc;

        *jit_insn_opnd(insn, 0) = r0;
    }
    return insn;
}

JitInsn* _jit_insn_new_Reg_2(JitOpcode opc, JitReg r0, JitReg r1) {
    JitInsn* insn = jit_calloc(JitInsn._opnd.offsetof + JitReg.sizeof * (2));
    if (insn) {
        insn.opcode = opc;

        *jit_insn_opnd(insn, 0) = r0;

        *jit_insn_opnd(insn, 1) = r1;
    }
    return insn;
}

JitInsn* _jit_insn_new_Reg_3(JitOpcode opc, JitReg r0, JitReg r1, JitReg r2) {
    JitInsn* insn = jit_calloc(JitInsn._opnd.offsetof + JitReg.sizeof * (3));
    if (insn) {
        insn.opcode = opc;

        *jit_insn_opnd(insn, 0) = r0;

        *jit_insn_opnd(insn, 1) = r1;

        *jit_insn_opnd(insn, 2) = r2;
    }
    return insn;
}

JitInsn* _jit_insn_new_Reg_4(JitOpcode opc, JitReg r0, JitReg r1, JitReg r2, JitReg r3) {
    JitInsn* insn = jit_calloc(JitInsn._opnd.offsetof + JitReg.sizeof * (4));
    if (insn) {
        insn.opcode = opc;

        *jit_insn_opnd(insn, 0) = r0;

        *jit_insn_opnd(insn, 1) = r1;

        *jit_insn_opnd(insn, 2) = r2;

        *jit_insn_opnd(insn, 3) = r3;
    }
    return insn;
}

JitInsn* _jit_insn_new_Reg_5(JitOpcode opc, JitReg r0, JitReg r1, JitReg r2, JitReg r3, JitReg r4) {
    JitInsn* insn = jit_calloc(JitInsn._opnd.offsetof + JitReg.sizeof * (5));
    if (insn) {
        insn.opcode = opc;

        *jit_insn_opnd(insn, 0) = r0;

        *jit_insn_opnd(insn, 1) = r1;

        *jit_insn_opnd(insn, 2) = r2;

        *jit_insn_opnd(insn, 3) = r3;

        *jit_insn_opnd(insn, 4) = r4;
    }
    return insn;
}

JitInsn* _jit_insn_new_VReg_1(JitOpcode opc, JitReg r0, int n) {
    JitInsn* insn = jit_calloc(cast(uint)(JitInsn._opnd._opnd_VReg._reg.offsetof + JitReg.sizeof * (1 + n)));
    if (insn) {
        insn.opcode = opc;
        insn._opnd._opnd_VReg._reg_num = 1 + n;

        *(jit_insn_opndv(insn, 0)) = r0;
    }
    return insn;
}

JitInsn* _jit_insn_new_VReg_2(JitOpcode opc, JitReg r0, JitReg r1, int n) {
    JitInsn* insn = jit_calloc(cast(uint)(JitInsn._opnd._opnd_VReg._reg.offsetof + JitReg.sizeof * (2 + n)));
    if (insn) {
        insn.opcode = opc;
        insn._opnd._opnd_VReg._reg_num = 2 + n;

        *(jit_insn_opndv(insn, 0)) = r0;

        *(jit_insn_opndv(insn, 1)) = r1;
    }
    return insn;
}

JitInsn* _jit_insn_new_LookupSwitch_1(JitOpcode opc, JitReg value, uint num) {
    JitOpndLookupSwitch* opnd = null;
    JitInsn* insn = jit_calloc(cast(uint)(JitInsn._opnd._opnd_LookupSwitch.match_pairs.offsetof
            + opnd.match_pairs[0].sizeof * num));
    if (insn) {
        insn.opcode = opc;
        opnd = jit_insn_opndls(insn);
        opnd.value = value;
        opnd.match_pairs_num = num;
    }
    return insn;
}

void jit_insn_insert_before(JitInsn* insn1, JitInsn* insn2) {
    bh_assert(insn1.prev !is null);
    insn1.prev.next = insn2;
    insn2.prev = insn1.prev;
    insn2.next = insn1;
    insn1.prev = insn2;
}

void jit_insn_insert_after(JitInsn* insn1, JitInsn* insn2) {
    bh_assert(insn1.next !is null);
    insn1.next.prev = insn2;
    insn2.next = insn1.next;
    insn2.prev = insn1;
    insn1.next = insn2;
}

void jit_insn_unlink(JitInsn* insn) {
    bh_assert(insn.prev !is null);
    insn.prev.next = insn.next;
    bh_assert(insn.next !is null);
    insn.next.prev = insn.prev;
    insn.prev = insn.next = null;
}

uint jit_insn_hash(JitInsn* insn) {
    const(ubyte) opcode = insn.opcode;
    uint hash = opcode, i = void;
    /* Currently, only instructions with Reg kind operand require
       hashing.  For others, simply use opcode as the hash value.  */
    if (insn_opnd[opcode].kind != JIT_OPND_KIND.Reg
        || insn_opnd[opcode].num < 1)
    return hash;
    /* All the instructions with hashing support must be in the
       assignment format, i.e. the first operand is the result (hence
       being ignored) and all the others are operands.  This is also
       true for CHK instructions, whose first operand is the instruction
       pointer.  */
    for (i = 1; i < insn_opnd[opcode].num; i++)
    hash = ((hash << 5) - hash) + *(jit_insn_opnd(insn, i));
    return hash;
}

bool jit_insn_equal(JitInsn* insn1, JitInsn* insn2) {
    const(ubyte) opcode = insn1.opcode;
    uint i = void;
    if (insn2.opcode != opcode)
        return false;
    if (insn_opnd[opcode].kind != JIT_OPND_KIND.Reg
        || insn_opnd[opcode].num < 1)
    return false;
    for (i = 1; i < insn_opnd[opcode].num; i++)
    if (*(jit_insn_opnd(insn1, i)) != *(jit_insn_opnd(insn2, i)))
        return false;
    return true;
}

JitRegVec jit_insn_opnd_regs(JitInsn* insn) {
    JitRegVec vec;
    JitOpndLookupSwitch* ls = void;
    vec._stride = 1;
    switch (insn_opnd[insn.opcode].kind) {
    case JIT_OPND_KIND.Reg:
        vec.num = insn_opnd[insn.opcode].num;
        vec._base = jit_insn_opnd(insn, 0);
        break;
        case JIT_OPND_KIND.VReg:
        vec.num = jit_insn_opndv_num(insn);
        vec._base = jit_insn_opndv(insn, 0);
        break;
        case JIT_OPND_KIND.LookupSwitch:
        ls = jit_insn_opndls(insn);
        vec.num = ls.match_pairs_num + 2;
        vec._base = &ls.value;
        vec._stride = ls.match_pairs[0].sizeof / typeof(*vec._base).sizeof;
        break;
        default:
        break;
    }
    return vec;
}

ubyte jit_insn_opnd_first_use(JitInsn* insn) {
    return insn_opnd[insn.opcode].first_use;
}

JitBasicBlock* jit_basic_block_new(JitReg label, int n) {
    JitBasicBlock* block = jit_insn_new_PHI(label, n);
    if (!block)
        return null;
    block.prev = block.next = block;
    return block;
}

void jit_basic_block_delete(JitBasicBlock* block) {
    JitInsn* insn = void, next_insn = void, end = void;
    if (!block)
        return;
    insn = jit_basic_block_first_insn(block);
    end = jit_basic_block_end_insn(block);
    for (; insn != end; insn = next_insn) {
        next_insn = insn.next;
        jit_insn_delete(insn);
    }
    jit_insn_delete(block);
}

JitRegVec jit_basic_block_preds(JitBasicBlock* block) {
    JitRegVec vec = void;
    vec.num = jit_insn_opndv_num(block) - 1;
    vec._base = vec.num > 0 ? jit_insn_opndv(block, 1) : null;
    vec._stride = 1;
    return vec;
}

JitRegVec jit_basic_block_succs(JitBasicBlock* block) {
    JitInsn* last_insn = jit_basic_block_last_insn(block);
    JitRegVec vec = void;
    vec.num = 0;
    vec._base = null;
    vec._stride = 1;
    switch (last_insn.opcode) {
    case JIT_OP_JMP:
        vec.num = 1;
        vec._base = jit_insn_opnd(last_insn, 0);
        break;
    case JIT_OP_BEQ:
    case JIT_OP_BNE:
    case JIT_OP_BGTS:
    case JIT_OP_BGES:
    case JIT_OP_BLTS:
    case JIT_OP_BLES:
    case JIT_OP_BGTU:
    case JIT_OP_BGEU:
    case JIT_OP_BLTU:
    case JIT_OP_BLEU:
        vec.num = 2;
        vec._base = jit_insn_opnd(last_insn, 1);
        break;
    case JIT_OP_LOOKUPSWITCH: {
            JitOpndLookupSwitch* opnd = jit_insn_opndls(last_insn);
            vec.num = opnd.match_pairs_num + 1;
            vec._base = &opnd.default_target;
            vec._stride = opnd.match_pairs[0].sizeof / typeof(*vec._base).sizeof;
            break;
        }
    default:
        vec._stride = 0;
    }
    return vec;
}

JitCompContext* jit_cc_init(JitCompContext* cc, uint htab_size) {
    JitBasicBlock* entry_block = void, exit_block = void;
    uint i = void, num = void;
    memset(cc, 0, typeof(*cc).sizeof);
    cc._reference_count = 1;
    jit_annl_enable_basic_block(cc);
    /* Create entry and exit blocks.  They must be the first two
       blocks respectively.  */
    if (((entry_block = cc.new_basic_block( 0)) is null))
        goto fail;
    if (((exit_block = cc.new_basic_block( 0)) is null)) {
        jit_basic_block_delete(entry_block);
        goto fail;
    }
    /* Record the entry and exit labels, whose indexes must be 0 and 1
       respectively.  */
    cc.entry_label = jit_basic_block_label(entry_block);
    cc.exit_label = jit_basic_block_label(exit_block);
    bh_assert(jit_reg_no(cc.entry_label) == 0
            && jit_reg_no(cc.exit_label) == 1);
    if (((cc.exce_basic_blocks =
            jit_calloc_ref((JitBasicBlock*).sizeof * EXCE_NUM)) is null))
        goto fail;
    if (((cc.incoming_insns_for_exec_bbs =
            jit_calloc_list(JitIncomingInsnList.sizeof * EXCE_NUM)) is null))
        goto fail;
    cc.hreg_info = jit_codegen_get_hreg_info();
    bh_assert(cc.hreg_info.info[JIT_REG_KIND_I32].num > 3);
    /* Initialize virtual registers for hard registers.  */
    for (i = JIT_REG_KIND_VOID; i < JIT_REG_KIND_L32; i++) {
        if ((num = cc.hreg_info.info[i].num) != 0) {
            /* Initialize the capacity to be large enough.  */
            cc.new_reg( i);
            bh_assert(cc._ann._reg_capacity[i] > num);
            cc._ann._reg_num[i] = num;
        }
    }
    /* Create registers for frame pointer, exec_env and cmp.  */
    cc.fp_reg = jit_reg_new(JIT_REG_KIND_PTR, cc.hreg_info.fp_hreg_index);
    cc.exec_env_reg =
        jit_reg_new(JIT_REG_KIND_PTR, cc.hreg_info.exec_env_hreg_index);
    cc.cmp_reg = jit_reg_new(JIT_REG_KIND_I32, cc.hreg_info.cmp_hreg_index);
    cc._const_val._hash_table_size = htab_size;
    if ((cc._const_val._hash_table =
            jit_calloc_reg(cast(uint)(htab_size * typeof(*cc._const_val._hash_table).sizeof))) is null)
        goto fail;
    return cc;
fail:
    jit_cc_destroy(cc);
    return null;
}

void jit_cc_delete(JitCompContext* cc) {
    if (cc && --cc._reference_count == 0) {
        jit_cc_destroy(cc);
        jit_free(cc);
    }
}
private uint hash_of_const(uint kind, uint size, void* val) {
    ubyte* p = cast(ubyte*) val, end = p + size;
    uint hash = kind;
    do
        hash = ((hash << 5) - hash) + *p++;
    while (p != end);
    return hash;
}

pragma(inline, true) void* address_of_const(JitCompContext* cc, JitReg reg, uint size) {
    int kind = jit_reg_kind(reg);
    uint no = jit_reg_no(reg);
    uint idx = no & ~_JIT_REG_CONST_IDX_FLAG;
    bh_assert(jit_reg_is_const_idx(reg) && idx < cc._const_val._num[kind]);
    return cc._const_val._value[kind] + size * idx;
}

pragma(inline, true) JitReg next_of_const(JitCompContext* cc, JitReg reg) {
    int kind = jit_reg_kind(reg);
    uint no = jit_reg_no(reg);
    uint idx = no & ~_JIT_REG_CONST_IDX_FLAG;
    bh_assert(jit_reg_is_const_idx(reg) && idx < cc._const_val._num[kind]);
    return cc._const_val._next[kind][idx];
}
/**
 * Put a constant value into the compilation context.
 *
 * @param cc compilation context
 * @param kind register kind
 * @param size size of the value
 * @param val pointer to value which must be aligned
 *
 * @return a constant register containing the value
 */
private JitReg _jit_cc_new_const(JitCompContext* cc, int kind, uint size, void* val) {
    uint num = cc._const_val._num[kind], slot = void;
    uint capacity = cc._const_val._capacity[kind];
    ubyte* new_value = void;
    JitReg r = void;
    JitReg* new_next = void;
    bh_assert(num <= capacity);
    /* Find the existing value first.  */
    slot = hash_of_const(kind, size, val) % cc._const_val._hash_table_size;
    r = cc._const_val._hash_table[slot];
    for (; r; r = next_of_const(cc, r))
        if (jit_reg_kind(r) == kind
                && !memcmp(val, address_of_const(cc, r, size), size))
            return r;
    if (num == capacity) {
        /* Increase the space of value and next.  */
        capacity = capacity > 0 ? (capacity + capacity / 2) : 16;
        new_value = jit_realloc_buffer(cc._const_val._value[kind], size * capacity,
        size * num);
        new_next =
            jit_realloc_reg(cc._const_val._next[kind],
        cast(uint)((*new_next).sizeof * capacity), cast(uint)((*new_next).sizeof * num));
        if (new_value && new_next) {
            cc._const_val._value[kind] = new_value;
            cc._const_val._next[kind] = new_next;
        }
        else {
            jit_set_last_error(cc, "create const register failed");
            jit_free(new_value);
            jit_free(new_next);
            return 0;
        }
        cc._const_val._capacity[kind] = capacity;
    }
    bh_assert(num + 1 < cast(uint) _JIT_REG_CONST_IDX_FLAG);
    r = jit_reg_new(kind, _JIT_REG_CONST_IDX_FLAG | num);
    memcpy(cc._const_val._value[kind] + size * num, val, size);
    cc._const_val._next[kind][num] = cc._const_val._hash_table[slot];
    cc._const_val._hash_table[slot] = r;
    cc._const_val._num[kind] = num + 1;
    return r;
}

pragma(inline, true) int get_const_val_in_reg(JitReg reg) {
    int shift = 8 * reg.sizeof - _JIT_REG_KIND_SHIFT + 1;
    return (cast(int)(reg << shift)) >> shift;
}

void jit_value_stack_push(JitValueStack* stack, JitValue* value) {
    if (!stack.value_list_head)
        stack.value_list_head = stack.value_list_end = value;
    else {
        stack.value_list_end.next = value;
        value.prev = stack.value_list_end;
        stack.value_list_end = value;
    }
}

JitValue* jit_value_stack_pop(JitValueStack* stack) {
    JitValue* value = stack.value_list_end;
    bh_assert(stack.value_list_end !is null);
    if (stack.value_list_head == stack.value_list_end)
        stack.value_list_head = stack.value_list_end = null;
    else {
        stack.value_list_end = stack.value_list_end.prev;
        stack.value_list_end.next = null;
        value.prev = null;
    }
    return value;
}

void jit_value_stack_destroy(JitValueStack* stack) {
    JitValue* value = stack.value_list_head, p = void;
    while (value) {
        p = value.next;
        jit_free(value);
        value = p;
    }
    stack.value_list_head = null;
    stack.value_list_end = null;
}

void jit_block_stack_push(JitBlockStack* stack, JitBlock* block) {
    if (!stack.block_list_head)
        stack.block_list_head = stack.block_list_end = block;
    else {
        stack.block_list_end.next = block;
        block.prev = stack.block_list_end;
        stack.block_list_end = block;
    }
}

JitBlock* jit_block_stack_top(JitBlockStack* stack) {
    return stack.block_list_end;
}

JitBlock* jit_block_stack_pop(JitBlockStack* stack) {
    JitBlock* block = stack.block_list_end;
    bh_assert(stack.block_list_end !is null);
    if (stack.block_list_head == stack.block_list_end)
        stack.block_list_head = stack.block_list_end = null;
    else {
        stack.block_list_end = stack.block_list_end.prev;
        stack.block_list_end.next = null;
        block.prev = null;
    }
    return block;
}

void jit_block_stack_destroy(JitBlockStack* stack) {
    JitBlock* block = stack.block_list_head, p = void;
    while (block) {
        p = block.next;
        jit_value_stack_destroy(&block.value_stack);
        jit_block_destroy(block);
        block = p;
    }
    stack.block_list_head = null;
    stack.block_list_end = null;
}

bool jit_block_add_incoming_insn(JitBlock* block, JitInsn* insn, uint opnd_idx) {
    JitIncomingInsn* incoming_insn = void;
    if (((incoming_insn = jit_calloc_incoming(cast(uint) JitIncomingInsn.sizeof)) is null))
        return false;
    incoming_insn.insn = insn;
    incoming_insn.opnd_idx = opnd_idx;
    incoming_insn.next = block.incoming_insns_for_end_bb;
    block.incoming_insns_for_end_bb = incoming_insn;
    return true;
}

void jit_block_destroy(JitBlock* block) {
    JitIncomingInsn* incoming_insn = void, incoming_insn_next = void;
    jit_value_stack_destroy(&block.value_stack);
    if (block.param_types)
        jit_free(block.param_types);
    if (block.result_types)
        jit_free(block.result_types);
    incoming_insn = block.incoming_insns_for_end_bb;
    while (incoming_insn) {
        incoming_insn_next = incoming_insn.next;
        jit_free(incoming_insn);
        incoming_insn = incoming_insn_next;
    }
    jit_free(block);
}

pragma(inline, true) ubyte to_stack_value_type(ubyte type) {
    return type;
}


bool _jit_insn_check_opnd_access_Reg(const(JitInsn)* insn, uint n) {
    uint opcode = insn.opcode;
    return (insn_opnd[opcode].kind == JIT_OPND_KIND.Reg
        && n < insn_opnd[opcode].num);
}

bool _jit_insn_check_opnd_access_VReg(const(JitInsn)* insn, uint n) {
    uint opcode = insn.opcode;
    return (insn_opnd[opcode].kind == JIT_OPND_KIND.VReg
        && n < insn._opnd._opnd_VReg._reg_num);
}

bool _jit_insn_check_opnd_access_LookupSwitch(const(JitInsn)* insn) {
    uint opcode = insn.opcode;
    return (insn_opnd[opcode].kind == JIT_OPND_KIND.LookupSwitch);
}


