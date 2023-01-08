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
module tagion.iwasm.fast_jit.fe.jit_emit_compare;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.fast_jit.fe.jit_emit_function;
import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_codegen;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.share.utils.bh_assert;

private bool jit_compile_op_compare_integer(JitCompContext* cc, IntCond cond, bool is64Bit) {
    JitReg lhs = void, rhs = void, res = void, const_zero = void, const_one = void;
    if (cond < INT_EQZ || cond > INT_GE_U) {
        jit_set_last_error(cc, "unsupported comparation operation");
        goto fail;
    }
    res = jit_cc_new_reg_I32(cc);
    const_zero = cc.new_const_I32(0);
    const_one = cc.new_const_I32(1);
    if (is64Bit) {
        if (INT_EQZ == cond) {
            rhs = cc.new_const_I64(0);
        }
        else {
            cc.pop_i64(rhs);
        }
        cc.pop_i64(lhs);
    }
    else {
        if (INT_EQZ == cond) {
            rhs = cc.new_const_I32(0);
        }
        else {
            cc.pop_i32(rhs);
        }
        cc.pop_i32(lhs);
    }
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, lhs, rhs)));
    switch (cond) {
        case INT_EQ:
        case INT_EQZ:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_NE:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTNE(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_LT_S:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTLTS(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_LT_U:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTLTU(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_GT_S:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGTS(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_GT_U:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGTU(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_LE_S:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTLES(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_LE_U:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTLEU(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        case INT_GE_S:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGES(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
        default: /* INT_GE_U */
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGEU(res, cc.cmp_reg, const_one, const_zero)));
            break;
        }
    }
    cc.push_i32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_compare(JitCompContext* cc, IntCond cond) {
    return jit_compile_op_compare_integer(cc, cond, false);
}
bool jit_compile_op_i64_compare(JitCompContext* cc, IntCond cond) {
    return jit_compile_op_compare_integer(cc, cond, true);
}
private int float_cmp_eq(float f1, float f2) {
    if (isnan(f1) || isnan(f2))
        return 0;
    return f1 == f2;
}
private int float_cmp_ne(float f1, float f2) {
    if (isnan(f1) || isnan(f2))
        return 1;
    return f1 != f2;
}
private int double_cmp_eq(double d1, double d2) {
    if (isnan(d1) || isnan(d2))
        return 0;
    return d1 == d2;
}
private int double_cmp_ne(double d1, double d2) {
    if (isnan(d1) || isnan(d2))
        return 1;
    return d1 != d2;
}
private bool jit_compile_op_compare_float_point(JitCompContext* cc, FloatCond cond, JitReg lhs, JitReg rhs) {
    JitReg res = void; JitReg[2] args = void; JitReg const_zero = void, const_one = void;
    JitRegKind kind = void;
    void* func = void;
    if (cond == FLOAT_EQ || cond == FLOAT_NE) {
        kind = jit_reg_kind(lhs);
        if (cond == FLOAT_EQ)
            func = (kind == JitRegKind.F32) ? cast(void*)float_cmp_eq
                                              : cast(void*)double_cmp_eq;
        else
            func = (kind == JitRegKind.F32) ? cast(void*)float_cmp_ne
                                              : cast(void*)double_cmp_ne;
        res = jit_cc_new_reg_I32(cc);
        args[0] = lhs;
        args[1] = rhs;
        if (!jit_emit_callnative(cc, func, res, args.ptr, 2)) {
            goto fail;
        }
    }
    else {
        res = jit_cc_new_reg_I32(cc);
        const_zero = cc.new_const_I32(0);
        const_one = cc.new_const_I32(1);
        switch (cond) {
            case FLOAT_LT:
            {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, rhs, lhs)));
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGTS(res, cc.cmp_reg, const_one, const_zero)));
                break;
            }
            case FLOAT_GT:
            {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, lhs, rhs)));
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGTS(res, cc.cmp_reg, const_one, const_zero)));
                break;
            }
            case FLOAT_LE:
            {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, rhs, lhs)));
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGES(res, cc.cmp_reg, const_one, const_zero)));
                break;
            }
            case FLOAT_GE:
            {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, lhs, rhs)));
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTGES(res, cc.cmp_reg, const_one, const_zero)));
                break;
            }
            default:
            {
                bh_assert(!"unknown FloatCond");
                goto fail;
            }
        }
    }
    cc.push_i32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_compare(JitCompContext* cc, FloatCond cond) {
    JitReg res = void, const_zero = void, const_one = void;
    JitReg lhs = void, rhs = void;
    cc.pop_f32(rhs);
    cc.pop_f32(lhs);
    if (jit_reg_is_const_val(lhs) && jit_reg_is_const_val(rhs)) {
        float lvalue = cc.get_const_F32(lhs);
        float rvalue = cc.get_const_F32(rhs);
        const_zero = cc.new_const_I32(0);
        const_one = cc.new_const_I32(1);
        switch (cond) {
            case FLOAT_EQ:
            {
                res = (lvalue == rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_NE:
            {
                res = (lvalue != rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_LT:
            {
                res = (lvalue < rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_GT:
            {
                res = (lvalue > rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_LE:
            {
                res = (lvalue <= rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_GE:
            {
                res = (lvalue >= rvalue) ? const_one : const_zero;
                break;
            }
            default:
            {
                bh_assert(!"unknown FloatCond");
                goto fail;
            }
        }
        cc.push_i32(res);
        return true;
    }
    return jit_compile_op_compare_float_point(cc, cond, lhs, rhs);
fail:
    return false;
}
bool jit_compile_op_f64_compare(JitCompContext* cc, FloatCond cond) {
    JitReg res = void, const_zero = void, const_one = void;
    JitReg lhs = void, rhs = void;
    cc.pop_f64(rhs);
    cc.pop_f64(lhs);
    if (jit_reg_is_const_val(lhs) && jit_reg_is_const_val(rhs)) {
        double lvalue = cc.get_const_F64(lhs);
        double rvalue = cc.get_const_F64(rhs);
        const_zero = cc.new_const_I32(0);
        const_one = cc.new_const_I32(1);
        switch (cond) {
            case FLOAT_EQ:
            {
                res = (lvalue == rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_NE:
            {
                res = (lvalue != rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_LT:
            {
                res = (lvalue < rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_GT:
            {
                res = (lvalue > rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_LE:
            {
                res = (lvalue <= rvalue) ? const_one : const_zero;
                break;
            }
            case FLOAT_GE:
            {
                res = (lvalue >= rvalue) ? const_one : const_zero;
                break;
            }
            default:
            {
                bh_assert(!"unknown FloatCond");
                goto fail;
            }
        }
        cc.push_i32(res);
        return true;
    }
    return jit_compile_op_compare_float_point(cc, cond, lhs, rhs);
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
