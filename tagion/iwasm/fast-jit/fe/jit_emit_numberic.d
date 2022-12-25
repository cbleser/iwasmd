module jit_emit_numberic;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_emit_numberic;
public import jit_emit_exception;
public import jit_emit_control;
public import jit_emit_function;
public import ...jit_frontend;
public import ...jit_codegen;

enum string PUSH_INT(string v) = `      \
    do {                 \
        if (is_i32)      \
            PUSH_I32(v); \
        else             \
            PUSH_I64(v); \
    } while (0)`;

enum string POP_INT(string v) = `      \
    do {                \
        if (is_i32)     \
            POP_I32(v); \
        else            \
            POP_I64(v); \
    } while (0)`;

enum string PUSH_FLOAT(string v) = `    \
    do {                 \
        if (is_f32)      \
            PUSH_F32(v); \
        else             \
            PUSH_F64(v); \
    } while (0)`;

enum string POP_FLOAT(string v) = `    \
    do {                \
        if (is_f32)     \
            POP_F32(v); \
        else            \
            POP_F64(v); \
    } while (0)`;

enum string DEF_INT_UNARY_OP(string op, string err) = `            \
    do {                                     \
        JitReg res, operand;                 \
        POP_INT(operand);                    \
        if (!(res = op)) {                   \
            if (err)                         \
                jit_set_last_error(cc, err); \
            goto fail;                       \
        }                                    \
        PUSH_INT(res);                       \
    } while (0)`;

enum string DEF_INT_BINARY_OP(string op, string err) = `           \
    do {                                     \
        JitReg res, left, right;             \
        POP_INT(right);                      \
        POP_INT(left);                       \
        if (!(res = op)) {                   \
            if (err)                         \
                jit_set_last_error(cc, err); \
            goto fail;                       \
        }                                    \
        PUSH_INT(res);                       \
    } while (0)`;

enum string DEF_FP_UNARY_OP(string op, string err) = `             \
    do {                                     \
        JitReg res, operand;                 \
        POP_FLOAT(operand);                  \
        if (!(res = op)) {                   \
            if (err)                         \
                jit_set_last_error(cc, err); \
            goto fail;                       \
        }                                    \
        PUSH_FLOAT(res);                     \
    } while (0)`;

enum string DEF_FP_BINARY_OP(string op, string err) = `            \
    do {                                     \
        JitReg res, left, right;             \
        POP_FLOAT(right);                    \
        POP_FLOAT(left);                     \
        if (!(res = op)) {                   \
            if (err)                         \
                jit_set_last_error(cc, err); \
            goto fail;                       \
        }                                    \
        PUSH_FLOAT(res);                     \
    } while (0)`;

private uint clz32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 0x80000000)) {
        num++;
        type <<= 1;
    }
    return num;
}

private ulong clz64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 0x8000000000000000LL)) {
        num++;
        type <<= 1;
    }
    return num;
}

private uint ctz32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

private ulong ctz64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

private uint popcnt32(uint u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

private ulong popcnt64(ulong u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

bool jit_compile_op_i32_clz(JitCompContext* cc) {
    JitReg value = void, res = void;

    POP_I32(value);
    if (jit_reg_is_const(value)) {
        uint i32 = jit_cc_get_const_I32(cc, value);
        PUSH_I32(NEW_CONST(I32, clz32(i32)));
        return true;
    }

    res = jit_cc_new_reg_I32(cc);
    GEN_INSN(CLZ, res, value);
    PUSH_I32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_ctz(JitCompContext* cc) {
    JitReg value = void, res = jit_cc_new_reg_I32(cc);

    POP_I32(value);
    if (jit_reg_is_const(value)) {
        uint i32 = jit_cc_get_const_I32(cc, value);
        PUSH_I32(NEW_CONST(I32, ctz32(i32)));
        return true;
    }

    res = jit_cc_new_reg_I32(cc);
    GEN_INSN(CTZ, res, value);
    PUSH_I32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_popcnt(JitCompContext* cc) {
    JitReg value = void, res = void;

    POP_I32(value);
    if (jit_reg_is_const(value)) {
        uint i32 = jit_cc_get_const_I32(cc, value);
        PUSH_I32(NEW_CONST(I32, popcnt32(i32)));
        return true;
    }

    res = jit_cc_new_reg_I32(cc);
    GEN_INSN(POPCNT, res, value);
    PUSH_I32(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_clz(JitCompContext* cc) {
    JitReg value = void, res = void;

    POP_I64(value);
    if (jit_reg_is_const(value)) {
        ulong i64 = jit_cc_get_const_I64(cc, value);
        PUSH_I64(NEW_CONST(I64, clz64(i64)));
        return true;
    }

    res = jit_cc_new_reg_I64(cc);
    GEN_INSN(CLZ, res, value);
    PUSH_I64(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_ctz(JitCompContext* cc) {
    JitReg value = void, res = void;

    POP_I64(value);
    if (jit_reg_is_const(value)) {
        ulong i64 = jit_cc_get_const_I64(cc, value);
        PUSH_I64(NEW_CONST(I64, ctz64(i64)));
        return true;
    }

    res = jit_cc_new_reg_I64(cc);
    GEN_INSN(CTZ, res, value);
    PUSH_I64(res);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_popcnt(JitCompContext* cc) {
    JitReg value = void, res = void;

    POP_I64(value);
    if (jit_reg_is_const(value)) {
        ulong i64 = jit_cc_get_const_I64(cc, value);
        PUSH_I64(NEW_CONST(I64, popcnt64(i64)));
        return true;
    }

    res = jit_cc_new_reg_I64(cc);
    GEN_INSN(POPCNT, res, value);
    PUSH_I64(res);
    return true;
fail:
    return false;
}

enum string IS_CONST_ALL_ONE(string val, string is_i32) = `                    \
    (jit_reg_is_const(val)                               \
     && ((is_i32 && jit_cc_get_const_I32(cc, val) == -1) \
         || (!is_i32 && jit_cc_get_const_I64(cc, val) == -1LL)))`;

enum string IS_CONST_ZERO(string val) = `                              \
    (jit_reg_is_const(val)                              \
     && ((is_i32 && jit_cc_get_const_I32(cc, val) == 0) \
         || (!is_i32 && jit_cc_get_const_I64(cc, val) == 0)))`;

/* macros for integer binary operations (ibinop) */

enum string __DEF_BI_INT_CONST_OPS(string bits, string opname, string op) = `                               \
    static int##bits do_i##bits##_const_##opname(int##bits lhs, int##bits rhs) \
    {                                                                          \
        return lhs op rhs;                                                     \
    }`;

enum string DEF_BI_INT_CONST_OPS(string opname, string op) = `   \
    __DEF_BI_INT_CONST_OPS(32, opname, op) \
    __DEF_BI_INT_CONST_OPS(64, opname, op)`;

enum string DEF_UNI_INT_CONST_OPS(string opname) = `            \
    static JitReg compile_int_##opname##_consts( \
        JitCompContext *cc, JitReg left, JitReg right, bool is_i32)`;

alias uni_const_handler = JitReg function(JitCompContext*, JitReg, JitReg, bool);
alias bin_i32_consts_handler = int function(int, int);
alias bin_i64_consts_handler = long function(long, long);

/* ibinopt for integer binary operations */
private JitReg compile_op_ibinopt_const(JitCompContext* cc, JitReg left, JitReg right, bool is_i32, uni_const_handler handle_one_const, bin_i32_consts_handler handle_two_i32_const, bin_i64_consts_handler handle_two_i64_const) {
    JitReg res = void;

    if (jit_reg_is_const(left) && jit_reg_is_const(right)) {
        if (is_i32) {
            int left_val = jit_cc_get_const_I32(cc, left);
            int right_val = jit_cc_get_const_I32(cc, right);
            res = NEW_CONST(I32, handle_two_i32_const(left_val, right_val));
        }
        else {
            long left_val = jit_cc_get_const_I64(cc, left);
            long right_val = jit_cc_get_const_I64(cc, right);
            res = NEW_CONST(I64, handle_two_i64_const(left_val, right_val));
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

enum string CHECK_AND_PROCESS_INT_CONSTS(string cc, string left, string right, string is_i32, string opname) = ` \
    compile_op_ibinopt_const(cc, left, right, is_i32,                 \
                             compile_int_##opname##_consts,           \
                             do_i32_const_##opname, do_i64_const_##opname)`;

DEF_UNI_INT_CONST_OPS add {
    /* If one of the operands is 0, just return the other */
    if (IS_CONST_ZERO(left))
        return right;
    if (IS_CONST_ZERO(right))
        return left;

    return 0;
}

DEF_BI_INT_CONST_OPS(add, +)

static JitReg
compile_int_add(JitCompContext *cc, JitReg left, JitReg right, bool_ is_i32)
{
    JitReg res;

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, add);
    if (res)
        goto shortcut;

    /* Build add */
    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
    GEN_INSN(ADD, res, left, right);

shortcut:
    return res;
}

DEF_UNI_INT_CONST_OPS sub {
    /* If the right operand is 0, just return the left */
    if (IS_CONST_ZERO(right))
        return left;

    return 0;
}

DEF_BI_INT_CONST_OPS(sub, -)

static JitReg
compile_int_sub(JitCompContext *cc, JitReg left, JitReg right, bool_ is_i32)
{
    JitReg res;

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, sub);
    if (res)
        goto shortcut;

    /* Build sub */
    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
    GEN_INSN(SUB, res, left, right);

shortcut:
    return res;
}

DEF_UNI_INT_CONST_OPS mul {
    /* If one of the operands is 0, just return constant 0 */
    if (IS_CONST_ZERO(left) || IS_CONST_ZERO(right))
        return is_i32 ? NEW_CONST(I32, 0) : NEW_CONST(I64, 0);

    return 0;
}

private int do_i32_const_mul(int lhs, int rhs) {
    return (int32)(cast(ulong)lhs * cast(ulong)rhs);
}

private long do_i64_const_mul(long lhs, long rhs) {
    return (int64)(cast(ulong)lhs * cast(ulong)rhs);
}

private JitReg compile_int_mul(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, mul);
    if (res)
        goto shortcut;

    /* Build mul */
    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
    GEN_INSN(MUL, res, left, right);

shortcut:
    return res;
}

private bool compile_int_div_no_check(JitCompContext* cc, IntArithmetic arith_op, bool is_i32, JitReg left, JitReg right, JitReg res) {
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    JitReg eax_hreg = jit_codegen_get_hreg_by_name("eax");
    JitReg edx_hreg = jit_codegen_get_hreg_by_name("edx");
    JitReg rax_hreg = jit_codegen_get_hreg_by_name("rax");
    JitReg rdx_hreg = jit_codegen_get_hreg_by_name("rdx");
}

    if (jit_reg_is_const(right) && jit_reg_is_const(left)) {
        if (INT_DIV_S == arith_op || INT_REM_S == arith_op) {
            if (is_i32) {
                int lhs = jit_cc_get_const_I32(cc, left);
                int rhs = jit_cc_get_const_I32(cc, right);
                if (INT_DIV_S == arith_op) {
                    res = NEW_CONST(I32, lhs / rhs);
                }
                else {
                    res = NEW_CONST(I32, lhs % rhs);
                }
                PUSH_I32(res);
                return true;
            }
            else {
                long lhs = jit_cc_get_const_I64(cc, left);
                long rhs = jit_cc_get_const_I64(cc, right);
                if (INT_DIV_S == arith_op) {
                    res = NEW_CONST(I64, lhs / rhs);
                }
                else {
                    res = NEW_CONST(I64, lhs % rhs);
                }
                PUSH_I64(res);
                return true;
            }
        }
        else {
            if (is_i32) {
                uint lhs = cast(uint)jit_cc_get_const_I32(cc, left);
                uint rhs = cast(uint)jit_cc_get_const_I32(cc, right);
                if (INT_DIV_U == arith_op) {
                    res = NEW_CONST(I32, lhs / rhs);
                }
                else {
                    res = NEW_CONST(I32, lhs % rhs);
                }
                PUSH_I32(res);
                return true;
            }
            else {
                ulong lhs = cast(ulong)jit_cc_get_const_I64(cc, left);
                ulong rhs = cast(ulong)jit_cc_get_const_I64(cc, right);
                if (INT_DIV_U == arith_op) {
                    res = NEW_CONST(I64, lhs / rhs);
                }
                else {
                    res = NEW_CONST(I64, lhs % rhs);
                }
                PUSH_I64(res);
                return true;
            }
        }
    }

    switch (arith_op) {
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
        case INT_DIV_S:
        case INT_DIV_U:
        {
            JitInsn* insn = null, insn1 = null;

            if (is_i32) {
                GEN_INSN(MOV, eax_hreg, left);
                if (arith_op == INT_DIV_S)
                    insn = GEN_INSN(DIV_S, eax_hreg, eax_hreg, right);
                else
                    insn = GEN_INSN(DIV_U, eax_hreg, eax_hreg, right);
            }
            else {
                GEN_INSN(MOV, rax_hreg, left);
                if (arith_op == INT_DIV_S)
                    insn = GEN_INSN(DIV_S, rax_hreg, rax_hreg, right);
                else
                    insn = GEN_INSN(DIV_U, rax_hreg, rax_hreg, right);
            }

            if (!insn) {
                goto fail;
            }
            if (!jit_lock_reg_in_insn(cc, insn, eax_hreg)
                || !jit_lock_reg_in_insn(cc, insn, edx_hreg)) {
                goto fail;
            }

            if (is_i32) {
                res = jit_cc_new_reg_I32(cc);
                insn1 = jit_insn_new_MOV(res, eax_hreg);
            }
            else {
                res = jit_cc_new_reg_I64(cc);
                insn1 = jit_insn_new_MOV(res, rax_hreg);
            }

            if (!insn1) {
                jit_set_last_error(cc, "generate insn failed");
                goto fail;
            }

            jit_insn_insert_after(insn, insn1);
            break;
        }
        case INT_REM_S:
        case INT_REM_U:
        {
            JitInsn* insn = null, insn1 = null;

            if (is_i32) {
                GEN_INSN(MOV, eax_hreg, left);
                if (arith_op == INT_REM_S)
                    insn = GEN_INSN(REM_S, edx_hreg, eax_hreg, right);
                else
                    insn = GEN_INSN(REM_U, edx_hreg, eax_hreg, right);
            }
            else {
                GEN_INSN(MOV, rax_hreg, left);
                if (arith_op == INT_REM_S)
                    insn = GEN_INSN(REM_S, rdx_hreg, rax_hreg, right);
                else
                    insn = GEN_INSN(REM_U, rdx_hreg, rax_hreg, right);
            }

            if (!insn) {
                goto fail;
            }
            if (!jit_lock_reg_in_insn(cc, insn, eax_hreg)
                || !jit_lock_reg_in_insn(cc, insn, edx_hreg)) {
                goto fail;
            }

            if (is_i32) {
                res = jit_cc_new_reg_I32(cc);
                insn1 = jit_insn_new_MOV(res, edx_hreg);
            }
            else {
                res = jit_cc_new_reg_I64(cc);
                insn1 = jit_insn_new_MOV(res, rdx_hreg);
            }

            if (!insn1) {
                jit_set_last_error(cc, "generate insn failed");
                goto fail;
            }

            jit_insn_insert_after(insn, insn1);
            break;
        }
} else {
        case INT_DIV_S:
            GEN_INSN(DIV_S, res, left, right);
            break;
        case INT_DIV_U:
            GEN_INSN(DIV_U, res, left, right);
            break;
        case INT_REM_S:
            GEN_INSN(REM_S, res, left, right);
            break;
        case INT_REM_U:
            GEN_INSN(REM_U, res, left, right);
            break;
} /* defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64) */
        default:
            bh_assert(0);
            return false;
    }

    if (is_i32)
        PUSH_I32(res);
    else
        PUSH_I64(res);
    return true;
fail:
    return false;
}

private bool compile_int_div(JitCompContext* cc, IntArithmetic arith_op, bool is_i32, ubyte** p_frame_ip) {
    JitReg left = void, right = void, res = void;

    bh_assert(arith_op == INT_DIV_S || arith_op == INT_DIV_U
              || arith_op == INT_REM_S || arith_op == INT_REM_U);

    if (is_i32) {
        POP_I32(right);
        POP_I32(left);
        res = jit_cc_new_reg_I32(cc);
    }
    else {
        POP_I64(right);
        POP_I64(left);
        res = jit_cc_new_reg_I64(cc);
    }

    if (jit_reg_is_const(right)) {
        long right_val = is_i32 ? cast(long)jit_cc_get_const_I32(cc, right)
                                 : jit_cc_get_const_I64(cc, right);

        switch (right_val) {
            case 0:
            {
                /* Directly throw exception if divided by zero */
                if (!(jit_emit_exception(cc, EXCE_INTEGER_DIVIDE_BY_ZERO,
                                         JIT_OP_JMP, 0, null)))
                    goto fail;

                return jit_handle_next_reachable_block(cc, p_frame_ip);
            }
            case 1:
            {
                if (arith_op == INT_DIV_S || arith_op == INT_DIV_U) {
                    if (is_i32)
                        PUSH_I32(left);
                    else
                        PUSH_I64(left);
                }
                else {
                    if (is_i32)
                        PUSH_I32(NEW_CONST(I32, 0));
                    else
                        PUSH_I64(NEW_CONST(I64, 0));
                }
                return true;
            }
            case -1:
            {
                if (arith_op == INT_DIV_S) {
                    if (is_i32)
                        GEN_INSN(CMP, cc.cmp_reg, left,
                                 NEW_CONST(I32, INT32_MIN));
                    else
                        GEN_INSN(CMP, cc.cmp_reg, left,
                                 NEW_CONST(I64, INT64_MIN));

                    /* Throw integer overflow exception if left is
                       INT32_MIN or INT64_MIN */
                    if (!(jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW,
                                             JIT_OP_BEQ, cc.cmp_reg, null)))
                        goto fail;

                    /* Push -(left) to stack */
                    GEN_INSN(NEG, res, left);
                    if (is_i32)
                        PUSH_I32(res);
                    else
                        PUSH_I64(res);
                    return true;
                }
                else if (arith_op == INT_REM_S) {
                    if (is_i32)
                        PUSH_I32(NEW_CONST(I32, 0));
                    else
                        PUSH_I64(NEW_CONST(I64, 0));
                    return true;
                }
                else {
                    /* Build default div and rem */
                    return compile_int_div_no_check(cc, arith_op, is_i32, left,
                                                    right, res);
                }
            }
            default:
            {
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left,
                                                right, res);
            }
        }
    }
    else {
        JitReg cmp1 = jit_cc_new_reg_I32(cc);
        JitReg cmp2 = jit_cc_new_reg_I32(cc);

        GEN_INSN(CMP, cc.cmp_reg, right,
                 is_i32 ? NEW_CONST(I32, 0) : NEW_CONST(I64, 0));
        /* Throw integer divided by zero exception if right is zero */
        if (!(jit_emit_exception(cc, EXCE_INTEGER_DIVIDE_BY_ZERO, JIT_OP_BEQ,
                                 cc.cmp_reg, null)))
            goto fail;

        switch (arith_op) {
            case INT_DIV_S:
            {
                /* Check integer overflow */
                GEN_INSN(CMP, cc.cmp_reg, left,
                         is_i32 ? NEW_CONST(I32, INT32_MIN)
                                : NEW_CONST(I64, INT64_MIN));
                GEN_INSN(SELECTEQ, cmp1, cc.cmp_reg, NEW_CONST(I32, 1),
                         NEW_CONST(I32, 0));
                GEN_INSN(CMP, cc.cmp_reg, right,
                         is_i32 ? NEW_CONST(I32, -1) : NEW_CONST(I64, -1LL));
                GEN_INSN(SELECTEQ, cmp2, cc.cmp_reg, NEW_CONST(I32, 1),
                         NEW_CONST(I32, 0));
                GEN_INSN(AND, cmp1, cmp1, cmp2);
                GEN_INSN(CMP, cc.cmp_reg, cmp1, NEW_CONST(I32, 1));
                /* Throw integer overflow exception if left is INT32_MIN or
                   INT64_MIN, and right is -1 */
                if (!(jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW, JIT_OP_BEQ,
                                         cc.cmp_reg, null)))
                    goto fail;

                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left,
                                                right, res);
            }
            case INT_REM_S:
            {
                JitReg left1 = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);

                GEN_INSN(CMP, cc.cmp_reg, right,
                         is_i32 ? NEW_CONST(I32, -1) : NEW_CONST(I64, -1LL));
                /* Don't generate `SELECTEQ left, cmp_reg, 0, left` since
                   left might be const, use left1 instead */
                if (is_i32)
                    GEN_INSN(SELECTEQ, left1, cc.cmp_reg, NEW_CONST(I32, 0),
                             left);
                else
                    GEN_INSN(SELECTEQ, left1, cc.cmp_reg, NEW_CONST(I64, 0),
                             left);
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left1,
                                                right, res);
            }
            default:
            {
                /* Build default div and rem */
                return compile_int_div_no_check(cc, arith_op, is_i32, left,
                                                right, res);
            }
        }
    }

fail:
    return false;
}

private bool compile_op_int_arithmetic(JitCompContext* cc, IntArithmetic arith_op, bool is_i32, ubyte** p_frame_ip) {
    switch (arith_op) {
        case INT_ADD:
            DEF_INT_BINARY_OP(compile_int_add(cc, left, right, is_i32),
                              "compile int add fail.");
            return true;
        case INT_SUB:
            DEF_INT_BINARY_OP(compile_int_sub(cc, left, right, is_i32),
                              "compile int sub fail.");
            return true;
        case INT_MUL:
            DEF_INT_BINARY_OP(compile_int_mul(cc, left, right, is_i32),
                              "compile int mul fail.");
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

bool jit_compile_op_i32_arithmetic(JitCompContext* cc, IntArithmetic arith_op, ubyte** p_frame_ip) {
    return compile_op_int_arithmetic(cc, arith_op, true, p_frame_ip);
}

bool jit_compile_op_i64_arithmetic(JitCompContext* cc, IntArithmetic arith_op, ubyte** p_frame_ip) {
    return compile_op_int_arithmetic(cc, arith_op, false, p_frame_ip);
}

DEF_UNI_INT_CONST_OPS and {
    JitReg res = void;
    if (IS_CONST_ZERO(left) || IS_CONST_ZERO(right)) {
        res = is_i32 ? NEW_CONST(I32, 0) : NEW_CONST(I64, 0);
        goto shortcut;
    }

    if (IS_CONST_ALL_ONE(left, is_i32)) {
        res = right;
        goto shortcut;
    }

    if (IS_CONST_ALL_ONE(right, is_i32)) {
        res = left;
        goto shortcut;
    }

    return 0;
shortcut:
    return res;
}

DEF_BI_INT_CONST_OPS(and, &)

static JitReg
compile_int_and(JitCompContext *cc, JitReg left, JitReg right, bool_ is_i32)
{
    JitReg res;

    /* shortcuts */
    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, and);
    if (res)
        goto shortcut;

    /* do and */
    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
    GEN_INSN(AND, res, left, right);

shortcut:
    return res;
}

DEF_UNI_INT_CONST_OPS or {
    JitReg res = void;

    if (IS_CONST_ZERO(left)) {
        res = right;
        goto shortcut;
    }

    if (IS_CONST_ZERO(right)) {
        res = left;
        goto shortcut;
    }

    if (IS_CONST_ALL_ONE(left, is_i32) || IS_CONST_ALL_ONE(right, is_i32)) {
        res = is_i32 ? NEW_CONST(I32, -1) : NEW_CONST(I64, -1LL);
        goto shortcut;
    }

    return 0;
shortcut:
    return res;
}

DEF_BI_INT_CONST_OPS(or, |)

static JitReg
compile_int_or(JitCompContext *cc, JitReg left, JitReg right, bool_ is_i32)
{
    JitReg res;

    /* shortcuts */
    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, or);
    if (res)
        goto shortcut;

    /* do or */
    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
    GEN_INSN(OR, res, left, right);

shortcut:
    return res;
}

DEF_UNI_INT_CONST_OPS xor {
    if (IS_CONST_ZERO(left))
        return right;

    if (IS_CONST_ZERO(right))
        return left;

    return 0;
}

DEF_BI_INT_CONST_OPS(xor, ^)

static JitReg
compile_int_xor(JitCompContext *cc, JitReg left, JitReg right, bool_ is_i32)
{
    JitReg res;

    /* shortcuts */
    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, xor);
    if (res)
        goto shortcut;

    /* do xor */
    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
    GEN_INSN(XOR, res, left, right);

shortcut:
    return res;
}

private bool compile_op_int_bitwise(JitCompContext* cc, IntBitwise arith_op, bool is_i32) {
    JitReg left = void, right = void, res = void;

    POP_INT(right);
    POP_INT(left);

    switch (arith_op) {
        case INT_AND:
        {
            res = compile_int_and(cc, left, right, is_i32);
            break;
        }
        case INT_OR:
        {
            res = compile_int_or(cc, left, right, is_i32);
            break;
        }
        case INT_XOR:
        {
            res = compile_int_xor(cc, left, right, is_i32);
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    PUSH_INT(res);
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

DEF_UNI_INT_CONST_OPS shl {
    if (IS_CONST_ZERO(right) || IS_CONST_ZERO(left)) {
        return left;
    }

    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
        GEN_INSN(SHL, res, left, right);
        return res;
    }
    return 0;
}

DEF_UNI_INT_CONST_OPS shrs {
    if (IS_CONST_ZERO(right) || IS_CONST_ZERO(left)
        || IS_CONST_ALL_ONE(left, is_i32)) {
        return left;
    }

    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
        GEN_INSN(SHRS, res, left, right);
        return res;
    }
    return 0;
}

DEF_UNI_INT_CONST_OPS shru {
    if (IS_CONST_ZERO(right) || IS_CONST_ZERO(left)) {
        return left;
    }

    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
        GEN_INSN(SHRU, res, left, right);
        return res;
    }
    return 0;
}

private int do_i32_const_shl(int lhs, int rhs) {
    return (int32)(cast(uint)lhs << cast(uint)rhs);
}

private long do_i64_const_shl(long lhs, long rhs) {
    return (int32)(cast(ulong)lhs << cast(ulong)rhs);
}

DEF_BI_INT_CONST_OPS(shrs, >>)

static int32
do_i32_const_shru(int32 lhs, int32 rhs)
{
    return (uint32)lhs >> rhs;
}

static int64
do_i64_const_shru(int64 lhs, int64 rhs)
{
    return (uint64)lhs >> rhs;
}

typedef enum { SHL, SHRS, SHRU, ROTL, ROTR } SHIFT_OP;

private JitReg compile_int_shift_modulo(JitCompContext* cc, JitReg rhs, bool is_i32, SHIFT_OP op) {
    JitReg res = void;

    if (jit_reg_is_const(rhs)) {
        if (is_i32) {
            int val = jit_cc_get_const_I32(cc, rhs);
            val = val & 0x1f;
            res = NEW_CONST(I32, val);
        }
        else {
            long val = jit_cc_get_const_I64(cc, rhs);
            val = val & 0x3f;
            res = NEW_CONST(I64, val);
        }
    }
    else {
        if (op == ROTL || op == ROTR) {
            /* No need to generate AND insn as the result
               is same for rotate shift */
            res = rhs;
        }
        else if (is_i32) {
            res = jit_cc_new_reg_I32(cc);
            GEN_INSN(AND, res, rhs, NEW_CONST(I32, 0x1f));
        }
        else {
            res = jit_cc_new_reg_I64(cc);
            GEN_INSN(AND, res, rhs, NEW_CONST(I64, 0x3f));
        }
    }

    return res;
}

private JitReg mov_left_to_reg(JitCompContext* cc, bool is_i32, JitReg left) {
    JitReg res = left;
    /* left needs to be a variable */
    if (jit_reg_is_const(left)) {
        res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
        GEN_INSN(MOV, res, left);
    }
    return res;
}

private JitReg compile_int_shl(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    JitReg ecx_hreg = jit_codegen_get_hreg_by_name("ecx");
    JitReg rcx_hreg = jit_codegen_get_hreg_by_name("rcx");
    JitInsn* insn = null;
}

    right = compile_int_shift_modulo(cc, right, is_i32, SHL);

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, shl);
    if (res)
        goto shortcut;

    left = mov_left_to_reg(cc, is_i32, left);

    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    GEN_INSN(MOV, is_i32 ? ecx_hreg : rcx_hreg, right);
    insn = GEN_INSN(SHL, res, left, is_i32 ? ecx_hreg : rcx_hreg);
    if (jit_get_last_error(cc) || !jit_lock_reg_in_insn(cc, insn, ecx_hreg)) {
        goto fail;
    }
} else {
    GEN_INSN(SHL, res, left, right);
    if (jit_get_last_error(cc)) {
        goto fail;
    }
}

shortcut:
    return res;
fail:
    return cast(JitReg)0;
}

private JitReg compile_int_shrs(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    JitReg ecx_hreg = jit_codegen_get_hreg_by_name("ecx");
    JitReg rcx_hreg = jit_codegen_get_hreg_by_name("rcx");
    JitInsn* insn = null;
}

    right = compile_int_shift_modulo(cc, right, is_i32, SHRS);

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, shrs);
    if (res)
        goto shortcut;

    left = mov_left_to_reg(cc, is_i32, left);

    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    GEN_INSN(MOV, is_i32 ? ecx_hreg : rcx_hreg, right);
    insn = GEN_INSN(SHRS, res, left, is_i32 ? ecx_hreg : rcx_hreg);
    if (jit_get_last_error(cc) || !jit_lock_reg_in_insn(cc, insn, ecx_hreg)) {
        goto fail;
    }
} else {
    GEN_INSN(SHRS, res, left, right);
    if (jit_get_last_error(cc)) {
        goto fail;
    }
}

shortcut:
    return res;
fail:
    return cast(JitReg)0;
}

private JitReg compile_int_shru(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    JitReg ecx_hreg = jit_codegen_get_hreg_by_name("ecx");
    JitReg rcx_hreg = jit_codegen_get_hreg_by_name("rcx");
    JitInsn* insn = null;
}

    right = compile_int_shift_modulo(cc, right, is_i32, SHRU);

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, shru);
    if (res)
        goto shortcut;

    left = mov_left_to_reg(cc, is_i32, left);

    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    GEN_INSN(MOV, is_i32 ? ecx_hreg : rcx_hreg, right);
    insn = GEN_INSN(SHRU, res, left, is_i32 ? ecx_hreg : rcx_hreg);
    if (jit_get_last_error(cc) || !jit_lock_reg_in_insn(cc, insn, ecx_hreg)) {
        goto fail;
    }
} else {
    GEN_INSN(SHRU, res, left, right);
    if (jit_get_last_error(cc)) {
        goto fail;
    }
}

shortcut:
    return res;
fail:
    return cast(JitReg)0;
}

DEF_UNI_INT_CONST_OPS rotl {
    if (IS_CONST_ZERO(right) || IS_CONST_ZERO(left)
        || IS_CONST_ALL_ONE(left, is_i32))
        return left;

    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
        GEN_INSN(ROTL, res, left, right);
        return res;
    }

    return 0;
}

private int do_i32_const_rotl(int lhs, int rhs) {
    uint n = cast(uint)lhs;
    uint d = cast(uint)rhs;
    return (n << d) | (n >> (32 - d));
}

private long do_i64_const_rotl(long lhs, long rhs) {
    ulong n = cast(ulong)lhs;
    ulong d = cast(ulong)rhs;
    return (n << d) | (n >> (64 - d));
}

private JitReg compile_int_rotl(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    JitReg ecx_hreg = jit_codegen_get_hreg_by_name("ecx");
    JitReg rcx_hreg = jit_codegen_get_hreg_by_name("rcx");
    JitInsn* insn = null;
}

    right = compile_int_shift_modulo(cc, right, is_i32, ROTL);

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, rotl);
    if (res)
        goto shortcut;

    left = mov_left_to_reg(cc, is_i32, left);

    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    GEN_INSN(MOV, is_i32 ? ecx_hreg : rcx_hreg, right);
    insn = GEN_INSN(ROTL, res, left, is_i32 ? ecx_hreg : rcx_hreg);
    if (jit_get_last_error(cc) || !jit_lock_reg_in_insn(cc, insn, ecx_hreg)) {
        goto fail;
    }
} else {
    GEN_INSN(ROTL, res, left, right);
    if (jit_get_last_error(cc)) {
        goto fail;
    }
}

shortcut:
    return res;
fail:
    return cast(JitReg)0;
}

DEF_UNI_INT_CONST_OPS rotr {
    if (IS_CONST_ZERO(right) || IS_CONST_ZERO(left)
        || IS_CONST_ALL_ONE(left, is_i32))
        return left;

    if (jit_reg_is_const(right)) {
        JitReg res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
        GEN_INSN(ROTR, res, left, right);
        return res;
    }

    return 0;
}

private int do_i32_const_rotr(int lhs, int rhs) {
    uint n = cast(uint)lhs;
    uint d = cast(uint)rhs;
    return (n >> d) | (n << (32 - d));
}

private long do_i64_const_rotr(long lhs, long rhs) {
    ulong n = cast(ulong)lhs;
    ulong d = cast(ulong)rhs;
    return (n >> d) | (n << (64 - d));
}

private JitReg compile_int_rotr(JitCompContext* cc, JitReg left, JitReg right, bool is_i32) {
    JitReg res = void;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    JitReg ecx_hreg = jit_codegen_get_hreg_by_name("ecx");
    JitReg rcx_hreg = jit_codegen_get_hreg_by_name("rcx");
    JitInsn* insn = null;
}

    right = compile_int_shift_modulo(cc, right, is_i32, ROTR);

    res = CHECK_AND_PROCESS_INT_CONSTS(cc, left, right, is_i32, rotr);
    if (res)
        goto shortcut;

    left = mov_left_to_reg(cc, is_i32, left);

    res = is_i32 ? jit_cc_new_reg_I32(cc) : jit_cc_new_reg_I64(cc);
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    GEN_INSN(MOV, is_i32 ? ecx_hreg : rcx_hreg, right);
    insn = GEN_INSN(ROTR, res, left, is_i32 ? ecx_hreg : rcx_hreg);
    if (jit_get_last_error(cc) || !jit_lock_reg_in_insn(cc, insn, ecx_hreg)) {
        goto fail;
    }
} else {
    GEN_INSN(ROTR, res, left, right);
    if (jit_get_last_error(cc)) {
        goto fail;
    }
}

shortcut:
    return res;
fail:
    return cast(JitReg)0;
}

private bool compile_op_int_shift(JitCompContext* cc, IntShift shift_op, bool is_i32) {
    JitReg left = void, right = void, res = void;

    POP_INT(right);
    POP_INT(left);

    switch (shift_op) {
        case INT_SHL:
        {
            res = compile_int_shl(cc, left, right, is_i32);
            break;
        }
        case INT_SHR_S:
        {
            res = compile_int_shrs(cc, left, right, is_i32);
            break;
        }
        case INT_SHR_U:
        {
            res = compile_int_shru(cc, left, right, is_i32);
            break;
        }
        case INT_ROTL:
        {
            res = compile_int_rotl(cc, left, right, is_i32);
            break;
        }
        case INT_ROTR:
        {
            res = compile_int_rotr(cc, left, right, is_i32);
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    PUSH_INT(res);
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

private float32 negf(float32 f32) {
    return -f32;
}

private float64 neg(float64 f64) {
    return -f64;
}

private bool compile_op_float_math(JitCompContext* cc, FloatMath math_op, bool is_f32) {
    JitReg value = void, res = void;
    void* func = null;

    if (is_f32)
        res = jit_cc_new_reg_F32(cc);
    else
        res = jit_cc_new_reg_F64(cc);

    if (is_f32)
        POP_F32(value);
    else
        POP_F64(value);

    switch (math_op) {
        case FLOAT_ABS:
            /* TODO: andps 0x7fffffffffffffff */
            func = is_f32 ? cast(void*)fabsf : cast(void*)fabs;
            break;
        case FLOAT_NEG:
            /* TODO: xorps 0x8000000000000000 */
            func = is_f32 ? cast(void*)negf : cast(void*)neg;
            break;
        case FLOAT_CEIL:
            func = is_f32 ? cast(void*)ceilf : cast(void*)ceil;
            break;
        case FLOAT_FLOOR:
            func = is_f32 ? cast(void*)floorf : cast(void*)floor;
            break;
        case FLOAT_TRUNC:
            func = is_f32 ? cast(void*)truncf : cast(void*)trunc;
            break;
        case FLOAT_NEAREST:
            func = is_f32 ? cast(void*)rintf : cast(void*)rint;
            break;
        case FLOAT_SQRT:
            func = is_f32 ? cast(void*)sqrtf : cast(void*)sqrt;
            break;
        default:
            bh_assert(0);
            goto fail;
    }

    if (!jit_emit_callnative(cc, func, res, &value, 1)) {
        goto fail;
    }

    if (is_f32)
        PUSH_F32(res);
    else
        PUSH_F64(res);

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

private float32 f32_min(float32 a, float32 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

private float32 f32_max(float32 a, float32 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

private float64 f64_min(float64 a, float64 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

private float64 f64_max(float64 a, float64 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

private bool compile_op_float_min_max(JitCompContext* cc, FloatArithmetic arith_op, bool is_f32, JitReg lhs, JitReg rhs, JitReg* out_) {
    JitReg res = void; JitReg[2] args = void;
    void* func = void;

    res = is_f32 ? jit_cc_new_reg_F32(cc) : jit_cc_new_reg_F64(cc);
    if (arith_op == FLOAT_MIN)
        func = is_f32 ? cast(void*)f32_min : cast(void*)f64_min;
    else
        func = is_f32 ? cast(void*)f32_max : cast(void*)f64_max;

    args[0] = lhs;
    args[1] = rhs;
    if (!jit_emit_callnative(cc, func, res, args.ptr, 2))
        return false;

    *out_ = res;
    return true;
}

private bool compile_op_float_arithmetic(JitCompContext* cc, FloatArithmetic arith_op, bool is_f32) {
    JitReg lhs = void, rhs = void, res = void;

    if (is_f32) {
        POP_F32(rhs);
        POP_F32(lhs);
        res = jit_cc_new_reg_F32(cc);
    }
    else {
        POP_F64(rhs);
        POP_F64(lhs);
        res = jit_cc_new_reg_F64(cc);
    }

    switch (arith_op) {
        case FLOAT_ADD:
        {
            GEN_INSN(ADD, res, lhs, rhs);
            break;
        }
        case FLOAT_SUB:
        {
            GEN_INSN(SUB, res, lhs, rhs);
            break;
        }
        case FLOAT_MUL:
        {
            GEN_INSN(MUL, res, lhs, rhs);
            break;
        }
        case FLOAT_DIV:
        {
            GEN_INSN(DIV_S, res, lhs, rhs);
            break;
        }
        case FLOAT_MIN:
        case FLOAT_MAX:
        {
            if (!compile_op_float_min_max(cc, arith_op, is_f32, lhs, rhs, &res))
                goto fail;
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    if (is_f32)
        PUSH_F32(res);
    else
        PUSH_F64(res);

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

    POP_F32(args[1]);
    POP_F32(args[0]);

    res = jit_cc_new_reg_F32(cc);
    if (!jit_emit_callnative(cc, copysignf, res, args.ptr, 2))
        goto fail;

    PUSH_F32(res);

    return true;
fail:
    return false;
}

bool jit_compile_op_f64_copysign(JitCompContext* cc) {
    JitReg res = void;
    JitReg[2] args = 0;

    POP_F64(args[1]);
    POP_F64(args[0]);

    res = jit_cc_new_reg_F64(cc);
    if (!jit_emit_callnative(cc, copysign, res, args.ptr, 2))
        goto fail;

    PUSH_F64(res);

    return true;
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

bool jit_compile_op_i32_clz(JitCompContext* cc);

bool jit_compile_op_i32_ctz(JitCompContext* cc);

bool jit_compile_op_i32_popcnt(JitCompContext* cc);

bool jit_compile_op_i64_clz(JitCompContext* cc);

bool jit_compile_op_i64_ctz(JitCompContext* cc);

bool jit_compile_op_i64_popcnt(JitCompContext* cc);

bool jit_compile_op_i32_arithmetic(JitCompContext* cc, IntArithmetic arith_op, ubyte** p_frame_ip);

bool jit_compile_op_i64_arithmetic(JitCompContext* cc, IntArithmetic arith_op, ubyte** p_frame_ip);

bool jit_compile_op_i32_bitwise(JitCompContext* cc, IntBitwise bitwise_op);

bool jit_compile_op_i64_bitwise(JitCompContext* cc, IntBitwise bitwise_op);

bool jit_compile_op_i32_shift(JitCompContext* cc, IntShift shift_op);

bool jit_compile_op_i64_shift(JitCompContext* cc, IntShift shift_op);

bool jit_compile_op_f32_math(JitCompContext* cc, FloatMath math_op);

bool jit_compile_op_f64_math(JitCompContext* cc, FloatMath math_op);

bool jit_compile_op_f32_arithmetic(JitCompContext* cc, FloatArithmetic arith_op);

bool jit_compile_op_f64_arithmetic(JitCompContext* cc, FloatArithmetic arith_op);

bool jit_compile_op_f32_copysign(JitCompContext* cc);

bool jit_compile_op_f64_copysign(JitCompContext* cc);

version (none) {}
} /* end of extern "C" */
}

 /* end of _JIT_EMIT_NUMBERIC_H_ */
