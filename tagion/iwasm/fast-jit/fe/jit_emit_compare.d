module jit_emit_compare;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_emit_compare;
public import jit_emit_function;
public import ...jit_frontend;
public import ...jit_codegen;

private bool jit_compile_op_compare_integer(JitCompContext* cc, IntCond cond, bool is64Bit) {
    JitReg lhs = void, rhs = void, res = void, const_zero = void, const_one = void;

    if (cond < INT_EQZ || cond > INT_GE_U) {
        jit_set_last_error(cc, "unsupported comparation operation");
        goto fail;
    }

    res = jit_cc_new_reg_I32(cc);
    const_zero = NEW_CONST(I32, 0);
    const_one = NEW_CONST(I32, 1);

    if (is64Bit) {
        if (INT_EQZ == cond) {
            rhs = NEW_CONST(I64, 0);
        }
        else {
            POP_I64(rhs);
        }
        POP_I64(lhs);
    }
    else {
        if (INT_EQZ == cond) {
            rhs = NEW_CONST(I32, 0);
        }
        else {
            POP_I32(rhs);
        }
        POP_I32(lhs);
    }

    GEN_INSN(CMP, cc.cmp_reg, lhs, rhs);
    switch (cond) {
        case INT_EQ:
        case INT_EQZ:
        {
            GEN_INSN(SELECTEQ, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_NE:
        {
            GEN_INSN(SELECTNE, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_LT_S:
        {
            GEN_INSN(SELECTLTS, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_LT_U:
        {
            GEN_INSN(SELECTLTU, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_GT_S:
        {
            GEN_INSN(SELECTGTS, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_GT_U:
        {
            GEN_INSN(SELECTGTU, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_LE_S:
        {
            GEN_INSN(SELECTLES, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_LE_U:
        {
            GEN_INSN(SELECTLEU, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        case INT_GE_S:
        {
            GEN_INSN(SELECTGES, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
        default: /* INT_GE_U */
        {
            GEN_INSN(SELECTGEU, res, cc.cmp_reg, const_one, const_zero);
            break;
        }
    }

    PUSH_I32(res);
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
            func = (kind == JIT_REG_KIND_F32) ? cast(void*)float_cmp_eq
                                              : cast(void*)double_cmp_eq;
        else
            func = (kind == JIT_REG_KIND_F32) ? cast(void*)float_cmp_ne
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
        const_zero = NEW_CONST(I32, 0);
        const_one = NEW_CONST(I32, 1);
        switch (cond) {
            case FLOAT_LT:
            {
                GEN_INSN(CMP, cc.cmp_reg, rhs, lhs);
                GEN_INSN(SELECTGTS, res, cc.cmp_reg, const_one, const_zero);
                break;
            }
            case FLOAT_GT:
            {
                GEN_INSN(CMP, cc.cmp_reg, lhs, rhs);
                GEN_INSN(SELECTGTS, res, cc.cmp_reg, const_one, const_zero);
                break;
            }
            case FLOAT_LE:
            {
                GEN_INSN(CMP, cc.cmp_reg, rhs, lhs);
                GEN_INSN(SELECTGES, res, cc.cmp_reg, const_one, const_zero);
                break;
            }
            case FLOAT_GE:
            {
                GEN_INSN(CMP, cc.cmp_reg, lhs, rhs);
                GEN_INSN(SELECTGES, res, cc.cmp_reg, const_one, const_zero);
                break;
            }
            default:
            {
                bh_assert(!"unknown FloatCond");
                goto fail;
            }
        }
    }
    PUSH_I32(res);

    return true;
fail:
    return false;
}

bool jit_compile_op_f32_compare(JitCompContext* cc, FloatCond cond) {
    JitReg res = void, const_zero = void, const_one = void;
    JitReg lhs = void, rhs = void;

    POP_F32(rhs);
    POP_F32(lhs);

    if (jit_reg_is_const_val(lhs) && jit_reg_is_const_val(rhs)) {
        float32 lvalue = jit_cc_get_const_F32(cc, lhs);
        float32 rvalue = jit_cc_get_const_F32(cc, rhs);

        const_zero = NEW_CONST(I32, 0);
        const_one = NEW_CONST(I32, 1);

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

        PUSH_I32(res);
        return true;
    }

    return jit_compile_op_compare_float_point(cc, cond, lhs, rhs);
fail:
    return false;
}

bool jit_compile_op_f64_compare(JitCompContext* cc, FloatCond cond) {
    JitReg res = void, const_zero = void, const_one = void;
    JitReg lhs = void, rhs = void;

    POP_F64(rhs);
    POP_F64(lhs);

    if (jit_reg_is_const_val(lhs) && jit_reg_is_const_val(rhs)) {
        float64 lvalue = jit_cc_get_const_F64(cc, lhs);
        float64 rvalue = jit_cc_get_const_F64(cc, rhs);

        const_zero = NEW_CONST(I32, 0);
        const_one = NEW_CONST(I32, 1);

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

        PUSH_I32(res);
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

 
public import ...jit_compiler;
public import ...jit_frontend;

version (none) {
extern "C" {
//! #endif

bool jit_compile_op_i32_compare(JitCompContext* cc, IntCond cond);

bool jit_compile_op_i64_compare(JitCompContext* cc, IntCond cond);

bool jit_compile_op_f32_compare(JitCompContext* cc, FloatCond cond);

bool jit_compile_op_f64_compare(JitCompContext* cc, FloatCond cond);

version (none) {}
} /* end of extern "C" */
}

 /* end of _JIT_EMIT_COMPARE_H_ */
