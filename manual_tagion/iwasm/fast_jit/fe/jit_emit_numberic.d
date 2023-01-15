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
module tagion.iwasm.fast_jit.fe.jit_emit_numberic;
@nogc nothrow:
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
import core.stdc.math : copysign, copysignf;
import core.stdc.math;
import tagion.iwasm.fast_jit.jit_compiler;
import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.fe.jit_emit_function : jit_emit_callnative;
import tagion.iwasm.fast_jit.fe.jit_emit_exception : jit_emit_exception;
import tagion.iwasm.fast_jit.fe.jit_emit_control : jit_handle_next_reachable_block;
import tagion.iwasm.share.utils.bh_assert;

uint clz32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 0x80000000)) {
        num++;
        type <<= 1;
    }
    return num;
}

ulong clz64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 0x8000000000000000L)) {
        num++;
        type <<= 1;
    }
    return num;
}

uint ctz32(uint type) {
    uint num = 0;
    if (type == 0) {
        return 32;
}
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

ulong ctz64(ulong type) {
    uint num = 0;
    if (type == 0) {
        return 64;
	}
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

uint popcnt32(uint u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

ulong popcnt64(ulong u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

bool jit_compile_op_i32_clz(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i32(value);
    if (jit_reg_is_const(value)) {
        uint i32 = cc.get_const_I32(value);
        cc.push_i32(cc.new_const_I32(clz32(i32)));
        return true;
    }
    res = cc.new_reg_I32;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CLZ(res, value)));
    cc.push_i32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_ctz(JitCompContext* cc) {
    JitReg value = void, res = cc.new_reg_I32;
    cc.pop_i32(value);
    if (jit_reg_is_const(value)) {
        uint i32 = cc.get_const_I32(value);
        cc.push_i32(cc.new_const_I32(ctz32(i32)));
        return true;
    }
    res = cc.new_reg_I32;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CTZ(res, value)));
    cc.push_i32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_popcnt(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i32(value);
    if (jit_reg_is_const(value)) {
        uint i32 = cc.get_const_I32(value);
        cc.push_i32(cc.new_const_I32(popcnt32(i32)));
        return true;
    }
    res = cc.new_reg_I32;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_POPCNT(res, value)));
    cc.push_i32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_clz(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i64(value);
    if (jit_reg_is_const(value)) {
        ulong i64 = cc.get_const_I64(value);
        cc.push_i64(cc.new_const_I64(clz64(i64)));
        return true;
    }
    res = cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CLZ(res, value)));
    cc.push_i64(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_ctz(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i64(value);
    if (jit_reg_is_const(value)) {
        ulong i64 = cc.get_const_I64(value);
        cc.push_i64(cc.new_const_I64(ctz64(i64)));
        return true;
    }
    res = cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CTZ(res, value)));
    cc.push_i64(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_popcnt(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i64(value);
    if (jit_reg_is_const(value)) {
        ulong i64 = cc.get_const_I64(value);
        cc.push_i64(cc.new_const_I64(popcnt64(i64)));
        return true;
    }
    res = cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_POPCNT(res, value)));
    cc.push_i64(res);
    return true;
fail:
    return false;
}
/* macros for integer binary operations (ibinop) */
alias uni_const_handler = JitReg function(JitCompContext*, JitReg, JitReg, bool);
alias bin_i32_consts_handler = int function(int, int);
alias bin_i64_consts_handler = long function(long, long);
/* ibinopt for integer binary operations */
JitReg compile_op_ibinopt_const(JitCompContext* cc, JitReg left, JitReg right, bool is_i32, uni_const_handler handle_one_const, bin_i32_consts_handler handle_two_i32_const, bin_i64_consts_handler handle_two_i64_const) {
    JitReg res = void;
    if (jit_reg_is_const(left) && jit_reg_is_const(right)) {
        if (is_i32) {
            int left_val = cc.get_const_I32(left);
            int right_val = cc.get_const_I32(right);
            res = cc.new_const_I32(handle_two_i32_const(left_val, right_val));
        }
        else {
            long left_val = cc.get_const_I64(left);
            long right_val = cc.get_const_I64(right);
            res = cc.new_const_I64(handle_two_i64_const(left_val, right_val));
        }
        goto shortcut;
    }
    if (jit_reg_is_const(left) || jit_reg_is_const(right)) {
        res = handle_one_const(cc, left, right, is_i32);
        if (res)
            goto shortcut;
    }
    return 0;
shortcut:
    return res;
}

JitReg compile_int_add_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    /* If one of the operands is 0, just return the other */
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0))))
        return right;
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))))
        return left;
    return 0;
}

int do_i32_const_add(int lhs, int rhs) {
    return lhs + rhs;
}

long do_i64_const_add(long lhs, long rhs) {
    return lhs + rhs;
}

JitReg compile_int_add(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_add_consts, &do_i32_const_add, &do_i64_const_add);
    if (res)
        goto shortcut;
    /* Build add */
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(res, left, right)));
shortcut:
    return res;
}

JitReg compile_int_sub_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    /* If the right operand is 0, just return the left */
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))))
        return left;
    return 0;
}

int do_i32_const_sub(int lhs, int rhs) {
    return lhs - rhs;
}

long do_i64_const_sub(long lhs, long rhs) {
    return lhs - rhs;
}

JitReg compile_int_sub(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_sub_consts, &do_i32_const_sub, &do_i64_const_sub);
    if (res)
        goto shortcut;
    /* Build sub */
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SUB(res, left, right)));
shortcut:
    return res;
}

JitReg compile_int_mul_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    /* If one of the operands is 0, just return constant 0 */
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0))) || (
            jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))))
        return is_i32 ? cc.new_const_I32(0) : cc.new_const_I64(0);
    return 0;
}

int do_i32_const_mul(int lhs, int rhs) {
    return cast(int)(cast(ulong) lhs * cast(ulong) rhs);
}

long do_i64_const_mul(long lhs, long rhs) {
    return cast(long)(cast(ulong) lhs * cast(ulong) rhs);
}

JitReg compile_int_mul(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_mul_consts, &do_i32_const_mul, &do_i64_const_mul);
    if (res)
        goto shortcut;
    /* Build mul */
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MUL(res, left, right)));
shortcut:
    return res;
}

bool compile_int_div_no_check(JitCompContext* cc, IntArithmetic arith_op, bool is_i32, JitReg left, JitReg right, JitReg res) {
    if (jit_reg_is_const(right) && jit_reg_is_const(left)) {
        if (INT_DIV_S == arith_op || INT_REM_S == arith_op) {
            if (is_i32) {
                int lhs = cc.get_const_I32(left);
                int rhs = cc.get_const_I32(right);
                if (INT_DIV_S == arith_op) {
                    res = cc.new_const_I32(lhs / rhs);
                }
                else {
                    res = cc.new_const_I32(lhs % rhs);
                }
                cc.push_i32(res);
                return true;
            }
            else {
                long lhs = cc.get_const_I64(left);
                long rhs = cc.get_const_I64(right);
                if (INT_DIV_S == arith_op) {
                    res = cc.new_const_I64(lhs / rhs);
                }
                else {
                    res = cc.new_const_I64(lhs % rhs);
                }
                cc.push_i64(res);
                return true;
            }
        }
        else {
            if (is_i32) {
                uint lhs = cast(uint) cc.get_const_I32(left);
                uint rhs = cast(uint) cc.get_const_I32(right);
                if (INT_DIV_U == arith_op) {
                    res = cc.new_const_I32(lhs / rhs);
                }
                else {
                    res = cc.new_const_I32(lhs % rhs);
                }
                cc.push_i32(res);
                return true;
            }
            else {
                ulong lhs = cast(ulong) cc.get_const_I64(left);
                ulong rhs = cast(ulong) cc.get_const_I64(right);
                if (INT_DIV_U == arith_op) {
                    res = cc.new_const_I64(lhs / rhs);
                }
                else {
                    res = cc.new_const_I64(lhs % rhs);
                }
                cc.push_i64(res);
                return true;
            }
        }
    }
    switch (arith_op) {
    case INT_DIV_S:
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_DIV_S(res, left, right)));
        break;
    case INT_DIV_U:
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_DIV_U(res, left, right)));
        break;
    case INT_REM_S:
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_REM_S(res, left, right)));
        break;
    case INT_REM_U:
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_REM_U(res, left, right)));
        break;
    default:
        bh_assert(0);
        return false;
    }
    if (is_i32)
        cc.push_i32(res);
    else
        cc.push_i64(res);
    return true;
fail:
    return false;
}

bool compile_int_div(JitCompContext* cc, IntArithmetic arith_op, bool is_i32, const(ubyte)** p_frame_ip) {
    JitReg left = void, right = void, res = void;
    bh_assert(arith_op == INT_DIV_S || arith_op == INT_DIV_U
            || arith_op == INT_REM_S || arith_op == INT_REM_U);
    if (is_i32) {
        cc.pop_i32(right);
        cc.pop_i32(left);
        res = cc.new_reg_I32;
    }
    else {
        cc.pop_i64(right);
        cc.pop_i64(left);
        res = cc.new_reg_I64;
    }
    if (jit_reg_is_const(right)) {
        long right_val = is_i32 ? cast(long) cc.get_const_I32(right) : cc.get_const_I64(right);
        switch (right_val) {
        case 0: {
                /* Directly throw exception if divided by zero */
                if (!(jit_emit_exception(cc, EXCE_INTEGER_DIVIDE_BY_ZERO,
                        JIT_OP_JMP, 0, null)))
                    goto fail;
                return jit_handle_next_reachable_block(cc, p_frame_ip);
            }
        case 1: {
                if (arith_op == INT_DIV_S || arith_op == INT_DIV_U) {
                    if (is_i32)
                        cc.push_i32(left);
                    else
                        cc.push_i64(left);
                }
                else {
                    if (is_i32)
                        cc.push_i32(cc.new_const_I32(0));
                    else
                        cc.push_i64(cc.new_const_I64(0));
                }
                return true;
            }
        case -1: {
                if (arith_op == INT_DIV_S) {
                    if (is_i32)
                        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, left, cc
                                .new_const_I32(int.min))));
                    else
                        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, left, cc
                                .new_const_I64(long.min))));
                    /* Throw integer overflow exception if left is
                       int.min or long.min */
                    if (!(jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW,
                            JIT_OP_BEQ, cc.cmp_reg, null)))
                        goto fail;
                    /* Push -(left) to stack */
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_NEG(res, left)));
                    if (is_i32)
                        cc.push_i32(res);
                    else
                        cc.push_i64(res);
                    return true;
                }
                else if (arith_op == INT_REM_S) {
                    if (is_i32)
                        cc.push_i32(cc.new_const_I32(0));
                    else
                        cc.push_i64(cc.new_const_I64(0));
                    return true;
                }
                else {
                    /* Build default div and rem */
                    return compile_int_div_no_check(cc, arith_op, is_i32, left,
                            right, res);
                }
            }
        default: {
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left,
                        right, res);
            }
        }
    }
    else {
        JitReg cmp1 = cc.new_reg_I32;
        JitReg cmp2 = cc.new_reg_I32;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, right, is_i32 ? cc
                .new_const_I32(0) : cc.new_const_I64(0))));
        /* Throw integer divided by zero exception if right is zero */
        if (!(jit_emit_exception(cc, EXCE_INTEGER_DIVIDE_BY_ZERO, JIT_OP_BEQ,
                cc.cmp_reg, null)))
            goto fail;
        switch (arith_op) {
        case INT_DIV_S: {
                /* Check integer overflow */
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, left, is_i32 ? cc
                        .new_const_I32(int.min) : cc.new_const_I64(long.min))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(cmp1, cc.cmp_reg, cc
                        .new_const_I32(1), cc.new_const_I32(0))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, right, is_i32 ? cc
                        .new_const_I32(-1) : cc.new_const_I64(-1L))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(cmp2, cc.cmp_reg, cc
                        .new_const_I32(1), cc.new_const_I32(0))));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(cmp1, cmp1, cmp2)));
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, cmp1, cc.new_const_I32(1))));
                /* Throw integer overflow exception if left is int.min or
                   long.min, and right is -1 */
                if (!(jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW, JIT_OP_BEQ,
                        cc.cmp_reg, null)))
                    goto fail;
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left,
                        right, res);
            }
        case INT_REM_S: {
                JitReg left1 = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
                cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, right, is_i32 ? cc
                        .new_const_I32(-1) : cc.new_const_I64(-1L))));
                /* Don't generate `SELECTEQ left, cmp_reg, 0, left` since
                   left might be const, use left1 instead */
                if (is_i32)
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(left1, cc.cmp_reg, cc
                            .new_const_I32(0), left)));
                else
                    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(left1, cc.cmp_reg, cc
                            .new_const_I64(0), left)));
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left1,
                        right, res);
            }
        default: {
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left,
                        right, res);
            }
        }
    }
fail:
    return false;
}

bool compile_op_int_arithmetic(JitCompContext* cc, IntArithmetic arith_op, bool is_i32, const(ubyte)** p_frame_ip) {
    switch (arith_op) {
    case INT_ADD:
        do {
            JitReg res = void, left = void, right = void;
            do {
                if (is_i32)
                    cc.pop_i32(right);
                else
                    cc.pop_i64(right);
            }
            while (0);
            do {
                if (is_i32)
                    cc.pop_i32(left);
                else
                    cc.pop_i64(left);
            }
            while (0);
            if (((res = compile_int_add(cc, left, right, is_i32)) == 0)) {
                if ("compile int add fail.")
                    jit_set_last_error(cc, "compile int add fail.");
                goto fail;
            }
            do {
                if (is_i32)
                    cc.push_i32(res);
                else
                    cc.push_i64(res);
            }
            while (0);
        }
        while (0);
        return true;
    case INT_SUB:
        do {
            JitReg res = void, left = void, right = void;
            do {
                if (is_i32)
                    cc.pop_i32(right);
                else
                    cc.pop_i64(right);
            }
            while (0);
            do {
                if (is_i32)
                    cc.pop_i32(left);
                else
                    cc.pop_i64(left);
            }
            while (0);
            if (((res = compile_int_sub(cc, left, right, is_i32)) == 0)) {
                if ("compile int sub fail.")
                    jit_set_last_error(cc, "compile int sub fail.");
                goto fail;
            }
            do {
                if (is_i32)
                    cc.push_i32(res);
                else
                    cc.push_i64(res);
            }
            while (0);
        }
        while (0);
        return true;
    case INT_MUL:
        do {
            JitReg res = void, left = void, right = void;
            do {
                if (is_i32)
                    cc.pop_i32(right);
                else
                    cc.pop_i64(right);
            }
            while (0);
            do {
                if (is_i32)
                    cc.pop_i32(left);
                else
                    cc.pop_i64(left);
            }
            while (0);
            if (((res = compile_int_mul(cc, left, right, is_i32)) == 0)) {
                if ("compile int mul fail.")
                    jit_set_last_error(cc, "compile int mul fail.");
                goto fail;
            }
            do {
                if (is_i32)
                    cc.push_i32(res);
                else
                    cc.push_i64(res);
            }
            while (0);
        }
        while (0);
        return true;
    case INT_DIV_S:
    case INT_DIV_U:
    case INT_REM_S:
    case INT_REM_U:
        return compile_int_div(cc, arith_op, is_i32, p_frame_ip);
    default:
        bh_assert(0);
        return false;
    }
fail:
    return false;
}

bool jit_compile_op_i32_arithmetic(JitCompContext* cc, IntArithmetic arith_op, const(ubyte)** p_frame_ip) {
    return compile_op_int_arithmetic(cc, arith_op, true, p_frame_ip);
}

bool jit_compile_op_i64_arithmetic(JitCompContext* cc, IntArithmetic arith_op, const(ubyte)** p_frame_ip) {
    return compile_op_int_arithmetic(cc, arith_op, false, p_frame_ip);
}

JitReg compile_int_and_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0))) || (
            jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0)))) {
        res = is_i32 ? cc.new_const_I32(0) : cc.new_const_I64(0);
        goto shortcut;
    }
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == -1) || (!is_i32 && cc.get_const_I64(left) == -1L)))) {
        res = right;
        goto shortcut;
    }
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == -1) || (!is_i32 && cc.get_const_I64(right) == -1L)))) {
        res = left;
        goto shortcut;
    }
    return 0;
shortcut:
    return res;
}

int do_i32_const_and(int lhs, int rhs) {
    return lhs & rhs;
}

long do_i64_const_and(long lhs, long rhs) {
    return lhs & rhs;
}

JitReg compile_int_and(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    /* shortcuts */
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_and_consts, &do_i32_const_and, &do_i64_const_and);
    if (res)
        goto shortcut;
    /* do and */
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(res, left, right)));
shortcut:
    return res;
}

JitReg compile_int_or_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0)))) {
        res = right;
        goto shortcut;
    }
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0)))) {
        res = left;
        goto shortcut;
    }
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == -1) || (!is_i32 && cc.get_const_I64(left) == -1L))) || (
            jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == -1) || (!is_i32 && cc.get_const_I64(right) == -1L)))) {
        res = is_i32 ? cc.new_const_I32(-1) : cc.new_const_I64(-1L);
        goto shortcut;
    }
    return 0;
shortcut:
    return res;
}

int do_i32_const_or(int lhs, int rhs) {
    return lhs | rhs;
}

long do_i64_const_or(long lhs, long rhs) {
    return lhs | rhs;
}

JitReg compile_int_or(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    /* shortcuts */
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_or_consts, &do_i32_const_or, &do_i64_const_or);
    if (res)
        goto shortcut;
    /* do or */
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_OR(res, left, right)));
shortcut:
    return res;
}

JitReg compile_int_xor_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    if ((jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0))))
        return right;
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))))
        return left;
    return 0;
}

int do_i32_const_xor(int lhs, int rhs) {
    return lhs ^ rhs;
}

long do_i64_const_xor(long lhs, long rhs) {
    return lhs ^ rhs;
}

JitReg compile_int_xor(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    /* shortcuts */
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_xor_consts, &do_i32_const_xor, &do_i64_const_xor);
    if (res)
        goto shortcut;
    /* do xor */
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_XOR(res, left, right)));
shortcut:
    return res;
}

bool compile_op_int_bitwise(JitCompContext* cc, IntBitwise arith_op, bool is_i32) {
    JitReg left = void, right = void, res = void;
    do {
        if (is_i32)
            cc.pop_i32(right);
        else
            cc.pop_i64(right);
    }
    while (0);
    do {
        if (is_i32)
            cc.pop_i32(left);
        else
            cc.pop_i64(left);
    }
    while (0);
    switch (arith_op) {
    case INT_AND: {
            res = compile_int_and(cc, left, right, is_i32);
            break;
        }
    case INT_OR: {
            res = compile_int_or(cc, left, right, is_i32);
            break;
        }
    case INT_XOR: {
            res = compile_int_xor(cc, left, right, is_i32);
            break;
        }
    default: {
            bh_assert(0);
            goto fail;
        }
    }
    do {
        if (is_i32)
            cc.push_i32(res);
        else
            cc.push_i64(res);
    }
    while (0);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_bitwise(JitCompContext* cc, IntBitwise bitwise_op) {
    return compile_op_int_bitwise(cc, bitwise_op, true);
}

bool jit_compile_op_i64_bitwise(JitCompContext* cc, IntBitwise bitwise_op) {
    return compile_op_int_bitwise(cc, bitwise_op, false);
}

JitReg compile_int_shl_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))) || (
            jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0)))) {
        return left;
    }
    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(res, left, right)));
        return res;
    }
    return 0;
}

JitReg compile_int_shrs_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))) || (
            jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0)))
            || (jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == -1) || (!is_i32 && cc.get_const_I64(left) == -1L)))) {
        return left;
    }
    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHRS(res, left, right)));
        return res;
    }
    return 0;
}

JitReg compile_int_shru_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))) || (
            jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0)))) {
        return left;
    }
    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHRU(res, left, right)));
        return res;
    }
    return 0;
}

int do_i32_const_shl(int lhs, int rhs) {
    return cast(int)(cast(uint) lhs << cast(uint) rhs);
}

long do_i64_const_shl(long lhs, long rhs) {
    return cast(int)(cast(ulong) lhs << cast(ulong) rhs);
}

int do_i32_const_shrs(int lhs, int rhs) {
    return lhs >> rhs;
}

long do_i64_const_shrs(long lhs, long rhs) {
    return lhs >> rhs;
}

int do_i32_const_shru(int lhs, int rhs) {
    return cast(uint) lhs >> rhs;
}

long do_i64_const_shru(long lhs, long rhs) {
    return cast(ulong) lhs >> rhs;
}

enum ShiftOp : ubyte {
    SHL,
    SHRS,
    SHRU,
    ROTL,
    ROTR
}

JitReg compile_int_shift_modulo(JitCompContext* cc, JitReg rhs, bool is_i32, ShiftOp op) {
    JitReg res = void;
    if (jit_reg_is_const(rhs)) {
        if (is_i32) {
            int val = cc.get_const_I32(rhs);
            val = val & 0x1f;
            res = cc.new_const_I32(val);
        }
        else {
            long val = cc.get_const_I64(rhs);
            val = val & 0x3f;
            res = cc.new_const_I64(val);
        }
    }
    else {
        if (op == ShiftOp.ROTL || op == ShiftOp.ROTR) {
            /* No need to generate AND insn as the result
               is same for rotate shift */
            res = rhs;
        }
        else if (is_i32) {
            res = cc.new_reg_I32;
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(res, rhs, cc.new_const_I32(0x1f))));
        }
        else {
            res = cc.new_reg_I64;
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(res, rhs, cc.new_const_I64(0x3f))));
        }
    }
    return res;
}

JitReg mov_left_to_reg(JitCompContext* cc, bool is_i32, JitReg left) {
    JitReg res = left;
    /* left needs to be a variable */
    if (jit_reg_is_const(left)) {
        res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MOV(res, left)));
    }
    return res;
}

JitReg compile_int_shl(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    right = compile_int_shift_modulo(cc, right, is_i32, ShiftOp.SHL);
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_shl_consts, &do_i32_const_shl, &do_i64_const_shl);
    if (res)
        goto shortcut;
    left = mov_left_to_reg(cc, is_i32, left);
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHL(res, left, right)));
    if (jit_get_last_error(cc)) {
        goto fail;
    }
shortcut:
    return res;
fail:
    return cast(JitReg) 0;
}

JitReg compile_int_shrs(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    right = compile_int_shift_modulo(cc, right, is_i32, ShiftOp.SHRS);
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_shrs_consts, &do_i32_const_shrs, &do_i64_const_shrs);
    if (res)
        goto shortcut;
    left = mov_left_to_reg(cc, is_i32, left);
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHRS(res, left, right)));
    if (jit_get_last_error(cc)) {
        goto fail;
    }
shortcut:
    return res;
fail:
    return cast(JitReg) 0;
}

JitReg compile_int_shru(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    right = compile_int_shift_modulo(cc, right, is_i32, ShiftOp.SHRU);
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_shru_consts, &do_i32_const_shru, &do_i64_const_shru);
    if (res)
        goto shortcut;
    left = mov_left_to_reg(cc, is_i32, left);
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SHRU(res, left, right)));
    if (jit_get_last_error(cc)) {
        goto fail;
    }
shortcut:
    return res;
fail:
    return cast(JitReg) 0;
}

JitReg compile_int_rotl_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))) || (
            jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0)))
            || (jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == -1) || (!is_i32 && cc.get_const_I64(left) == -1L))))
        return left;
    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ROTL(res, left, right)));
        return res;
    }
    return 0;
}

int do_i32_const_rotl(int lhs, int rhs) {
    uint n = cast(uint) lhs;
    uint d = cast(uint) rhs;
    return (n << d) | (n >> (32 - d));
}

long do_i64_const_rotl(long lhs, long rhs) {
    ulong n = cast(ulong) lhs;
    ulong d = cast(ulong) rhs;
    return (n << d) | (n >> (64 - d));
}

JitReg compile_int_rotl(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    right = compile_int_shift_modulo(cc, right, is_i32, ShiftOp.ROTL);
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_rotl_consts, &do_i32_const_rotl, &do_i64_const_rotl);
    if (res)
        goto shortcut;
    left = mov_left_to_reg(cc, is_i32, left);
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ROTL(res, left, right)));
    if (jit_get_last_error(cc)) {
        goto fail;
    }
shortcut:
    return res;
fail:
    return cast(JitReg) 0;
}

JitReg compile_int_rotr_consts(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    if ((jit_reg_is_const(right) && ((is_i32 && cc.get_const_I32(right) == 0) || (!is_i32 && cc.get_const_I64(right) == 0))) || (
            jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == 0) || (!is_i32 && cc.get_const_I64(left) == 0)))
            || (jit_reg_is_const(left) && ((is_i32 && cc.get_const_I32(left) == -1) || (!is_i32 && cc.get_const_I64(left) == -1L))))
        return left;
    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
        cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ROTR(res, left, right)));
        return res;
    }
    return 0;
}

int do_i32_const_rotr(int lhs, int rhs) {
    uint n = cast(uint) lhs;
    uint d = cast(uint) rhs;
    return (n >> d) | (n << (32 - d));
}

long do_i64_const_rotr(long lhs, long rhs) {
    ulong n = cast(ulong) lhs;
    ulong d = cast(ulong) rhs;
    return (n >> d) | (n << (64 - d));
}

JitReg compile_int_rotr(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
    right = compile_int_shift_modulo(cc, right, is_i32, ShiftOp.ROTR);
    res = compile_op_ibinopt_const(cc, left, right, is_i32, &compile_int_rotr_consts, &do_i32_const_rotr, &do_i64_const_rotr);
    if (res)
        goto shortcut;
    left = mov_left_to_reg(cc, is_i32, left);
    res = is_i32 ? cc.new_reg_I32 : cc.new_reg_I64;
    cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ROTR(res, left, right)));
    if (jit_get_last_error(cc)) {
        goto fail;
    }
shortcut:
    return res;
fail:
    return cast(JitReg) 0;
}

bool compile_op_int_shift(JitCompContext* cc, IntShift shift_op, bool is_i32) {
    JitReg left = void, right = void, res = void;
    do {
        if (is_i32)
            cc.pop_i32(right);
        else
            cc.pop_i64(right);
    }
    while (0);
    do {
        if (is_i32)
            cc.pop_i32(left);
        else
            cc.pop_i64(left);
    }
    while (0);
    switch (shift_op) {
    case INT_SHL: {
            res = compile_int_shl(cc, left, right, is_i32);
            break;
        }
    case INT_SHR_S: {
            res = compile_int_shrs(cc, left, right, is_i32);
            break;
        }
    case INT_SHR_U: {
            res = compile_int_shru(cc, left, right, is_i32);
            break;
        }
    case INT_ROTL: {
            res = compile_int_rotl(cc, left, right, is_i32);
            break;
        }
    case INT_ROTR: {
            res = compile_int_rotr(cc, left, right, is_i32);
            break;
        }
    default: {
            bh_assert(0);
            goto fail;
        }
    }
    do {
        if (is_i32)
            cc.push_i32(res);
        else
            cc.push_i64(res);
    }
    while (0);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_shift(JitCompContext* cc, IntShift shift_op) {
    return compile_op_int_shift(cc, shift_op, true);
}

bool jit_compile_op_i64_shift(JitCompContext* cc, IntShift shift_op) {
    return compile_op_int_shift(cc, shift_op, false);
}

float negf(float f32) {
    return -f32;
}

double neg(double f64) {
    return -f64;
}

bool compile_op_float_math(JitCompContext* cc, FloatMath math_op, bool is_f32) {
    JitReg value = void, res = void;
    void* func = null;
    if (is_f32)
        res = cc.new_reg_F32;
    else
        res = cc.new_reg_F64;
    if (is_f32)
        cc.pop_f32(value);
    else
        cc.pop_f64(value);
    switch (math_op) {
    case FLOAT_ABS:
        /* TODO: andps 0x7fffffffffffffff */
        func = is_f32 ? cast(void*) &fabsf : cast(void*) &fabs;
        break;
    case FLOAT_NEG:
        /* TODO: xorps 0x8000000000000000 */
        func = is_f32 ? cast(void*) &negf : cast(void*) &neg;
        break;
    case FLOAT_CEIL:
        func = is_f32 ? cast(void*) &ceilf : cast(void*) &ceil;
        break;
    case FLOAT_FLOOR:
        func = is_f32 ? cast(void*) &floorf : cast(void*) &floor;
        break;
    case FLOAT_TRUNC:
        func = is_f32 ? cast(void*) &truncf : cast(void*) &trunc;
        break;
    case FLOAT_NEAREST:
        func = is_f32 ? cast(void*) &rintf : cast(void*) &rint;
        break;
    case FLOAT_SQRT:
        func = is_f32 ? cast(void*) &sqrtf : cast(void*) &sqrt;
        break;
    default:
        bh_assert(0);
        goto fail;
    }
    if (!jit_emit_callnative(cc, func, res, &value, 1)) {
        goto fail;
    }
    if (is_f32)
        cc.push_f32(res);
    else
        cc.push_f64(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_f32_math(JitCompContext* cc, FloatMath math_op) {
    return compile_op_float_math(cc, math_op, true);
}

bool jit_compile_op_f64_math(JitCompContext* cc, FloatMath math_op) {
    return compile_op_float_math(cc, math_op, false);
}

float f32_min(float a, float b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

float f32_max(float a, float b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

double f64_min(double a, double b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

double f64_max(double a, double b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

bool compile_op_float_min_max(JitCompContext* cc, FloatArithmetic arith_op, bool is_f32, JitReg lhs, JitReg rhs, JitReg* out_) {
    JitReg res = void;
    JitReg[2] args = void;
    void* func = void;
    res = is_f32 ? cc.new_reg_F32 : cc.new_reg_F64;
    if (arith_op == FLOAT_MIN)
        func = is_f32 ? cast(void*) &f32_min : cast(void*) &f64_min;
    else
        func = is_f32 ? cast(void*) &f32_max : cast(void*) &f64_max;
    args[0] = lhs;
    args[1] = rhs;
    if (!jit_emit_callnative(cc, func, res, args.ptr, 2))
        return false;
    *out_ = res;
    return true;
}

bool compile_op_float_arithmetic(JitCompContext* cc, FloatArithmetic arith_op, bool is_f32) {
    JitReg lhs = void, rhs = void, res = void;
    if (is_f32) {
        cc.pop_f32(rhs);
        cc.pop_f32(lhs);
        res = cc.new_reg_F32;
    }
    else {
        cc.pop_f64(rhs);
        cc.pop_f64(lhs);
        res = cc.new_reg_F64;
    }
    switch (arith_op) {
    case FLOAT_ADD: {
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(res, lhs, rhs)));
            break;
        }
    case FLOAT_SUB: {
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SUB(res, lhs, rhs)));
            break;
        }
    case FLOAT_MUL: {
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MUL(res, lhs, rhs)));
            break;
        }
    case FLOAT_DIV: {
            cc._gen_insn(_jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_DIV_S(res, lhs, rhs)));
            break;
        }
    case FLOAT_MIN:
    case FLOAT_MAX: {
            if (!compile_op_float_min_max(cc, arith_op, is_f32, lhs, rhs, &res))
                goto fail;
            break;
        }
    default: {
            bh_assert(0);
            goto fail;
        }
    }
    if (is_f32)
        cc.push_f32(res);
    else
        cc.push_f64(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_f32_arithmetic(JitCompContext* cc, FloatArithmetic arith_op) {
    return compile_op_float_arithmetic(cc, arith_op, true);
}

bool jit_compile_op_f64_arithmetic(JitCompContext* cc, FloatArithmetic arith_op) {
    return compile_op_float_arithmetic(cc, arith_op, false);
}

bool jit_compile_op_f32_copysign(JitCompContext* cc) {
    JitReg res = void;
    JitReg[2] args = 0;
    cc.pop_f32(args[1]);
    cc.pop_f32(args[0]);
    res = cc.new_reg_F32;
    if (!jit_emit_callnative(cc, &copysignf, res, args.ptr, 2))
        goto fail;
    cc.push_f32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_f64_copysign(JitCompContext* cc) {
    JitReg res = void;
    JitReg[2] args = 0;
    cc.pop_f64(args[1]);
    cc.pop_f64(args[0]);
    res = cc.new_reg_F64;
    if (!jit_emit_callnative(cc, &copysign, res, args.ptr, 2))
        goto fail;
    cc.push_f64(res);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */