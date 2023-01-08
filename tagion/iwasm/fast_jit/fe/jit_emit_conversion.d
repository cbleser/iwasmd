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
module tagion.iwasm.fast_jit.fe.jit_emit_conversion;
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
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_ir :  JitReg;
//#include "jit_emit_conversion.h #include "jit_emit_exception.h"
//#include "jit_emit_function.h"
//#include "../jit_codegen.h"
//#include "../jit_frontend.h"
enum F32_I32_S_MIN=-2147483904.0f;
enum F32_I32_S_MAX=2147483648.0f;
enum F32_I32_U_MIN=-1.0f;
enum F32_I32_U_MAX=4294967296.0f;
enum F32_I64_S_MIN=-9223373136366403584.0f;
enum F32_I64_S_MAX=9223372036854775808.0f;
enum F32_I64_U_MIN=-1.0f;
enum F32_I64_U_MAX=18446744073709551616.0f;
enum F64_I32_S_MIN=-2147483649.0;
enum F64_I32_S_MAX=2147483648.0;
enum F64_I32_U_MIN=-1.0;
enum F64_I32_U_MAX=4294967296.0;
enum F64_I64_S_MIN=-9223372036854777856.0;
enum F64_I64_S_MAX=9223372036854775808.0;
enum F64_I64_U_MIN=-1.0;
enum F64_I64_U_MAX=18446744073709551616.0;
private int local_isnan(double x) {
    return isnan(x);
}
private int local_isnanf(float x) {
    return isnan(x);
}
private int i32_trunc_f32_sat(float fp) {
    if (local_isnanf(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? INT32_MIN : INT32_MAX; }
    if (fp <= F32_I32_S_MIN) { return INT32_MIN; }
    if (fp >= F32_I32_S_MAX) { return INT32_MAX; }
    return cast(int)fp;
}
private uint u32_trunc_f32_sat(float fp) {
    if (local_isnanf(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : UINT32_MAX; }
    if (fp <= F32_I32_U_MIN) { return 0; }
    if (fp >= F32_I32_U_MAX) { return UINT32_MAX; }
    return cast(uint)fp;
}
private int i32_trunc_f64_sat(double fp) {
    if (local_isnan(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? INT32_MIN : INT32_MAX; }
    if (fp <= F64_I32_S_MIN) { return INT32_MIN; }
    if (fp >= F64_I32_S_MAX) { return INT32_MAX; }
    return cast(int)fp;
}
private uint u32_trunc_f64_sat(double fp) {
    if (local_isnan(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : UINT32_MAX; }
    if (fp <= F64_I32_U_MIN) { return 0; }
    if (fp >= F64_I32_U_MAX) { return UINT32_MAX; }
    return cast(uint)fp;
}
private long i64_trunc_f32_sat(float fp) {
    if (local_isnanf(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? INT64_MIN : INT64_MAX; }
    if (fp <= F32_I64_S_MIN) { return INT64_MIN; }
    if (fp >= F32_I64_S_MAX) { return INT64_MAX; }
    return cast(long)fp;
}
private ulong u64_trunc_f32(float fp) {
    return cast(ulong)fp;
}
private ulong u64_trunc_f32_sat(float fp) {
    if (local_isnanf(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : UINT64_MAX; }
    if (fp <= F32_I64_U_MIN) { return 0; }
    if (fp >= F32_I64_U_MAX) { return UINT64_MAX; }
    return cast(ulong)fp;
}
private long i64_trunc_f64_sat(double fp) {
    if (local_isnanf(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? INT64_MIN : INT64_MAX; }
    if (fp <= F64_I64_S_MIN) { return INT64_MIN; }
    if (fp >= F64_I64_S_MAX) { return INT64_MAX; }
    return cast(long)fp;
}
private ulong u64_trunc_f64(double fp) {
    return cast(ulong)fp;
}
private ulong u64_trunc_f64_sat(double fp) {
    if (local_isnanf(fp)) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : UINT64_MAX; }
    if (fp <= F64_I64_U_MIN) { return 0; }
    if (fp >= F64_I64_U_MAX) { return UINT64_MAX; }
    return cast(ulong)fp;
}
private float f32_convert_u64(ulong i) {
    return cast(float)i;
}
private double f64_convert_u64(ulong i) {
    return cast(double)i;
}
bool jit_compile_op_i32_wrap_i64(JitCompContext* cc) {
    JitReg num = void, res = void;
    POP_I64(num);
    res = jit_cc_new_reg_I32(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64TOI32(res, num)));
    PUSH_I32(res);
    return true;
fail:
    return false;
}
private bool jit_compile_check_value_range(JitCompContext* cc, JitReg value, JitReg min_fp, JitReg max_fp) {
    JitReg nan_ret = jit_cc_new_reg_I32(cc);
    JitRegKind kind = jit_reg_kind(value);
    bool emit_ret = false;
    bh_assert(JIT_REG_KIND_F32 == kind || JIT_REG_KIND_F64 == kind);
    /* If value is NaN, throw exception */
    if (JIT_REG_KIND_F32 == kind)
        emit_ret = jit_emit_callnative(cc, &local_isnanf, nan_ret, &value, 1);
    else
        emit_ret = jit_emit_callnative(cc, &local_isnan, nan_ret, &value, 1);
    if (!emit_ret)
        goto fail;
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, nan_ret, jit_cc_new_const_I32(cc, 1))));
    if (!jit_emit_exception(cc, EXCE_INVALID_CONVERSION_TO_INTEGER, JIT_OP_BEQ,
                            cc.cmp_reg, null))
        goto fail;
    /* If value is out of integer range, throw exception */
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, min_fp, value)));
    if (!jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW, JIT_OP_BGES, cc.cmp_reg,
                            null))
        goto fail;
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, value, max_fp)));
    if (!jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW, JIT_OP_BGES, cc.cmp_reg,
                            null))
        goto fail;
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_trunc_f32(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    POP_F32(value);
    res = jit_cc_new_reg_I32(cc);
    if (!sat) {
        JitReg min_fp = jit_cc_new_const_F32(cc, sign ? F32_I32_S_MIN : F32_I32_U_MIN);
        JitReg max_fp = jit_cc_new_const_F32(cc, sign ? F32_I32_S_MAX : F32_I32_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign)
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F32TOI32(res, value)));
        else
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F32TOU32(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)i32_trunc_f32_sat
                                      : cast(void*)u32_trunc_f32_sat,
                                 res, &value, 1))
            goto fail;
    }
    PUSH_I32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_trunc_f64(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    POP_F64(value);
    res = jit_cc_new_reg_I32(cc);
    if (!sat) {
        JitReg min_fp = jit_cc_new_const_F64(cc, sign ? F64_I32_S_MIN : F64_I32_U_MIN);
        JitReg max_fp = jit_cc_new_const_F64(cc, sign ? F64_I32_S_MAX : F64_I32_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign)
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F64TOI32(res, value)));
        else
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F64TOU32(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)i32_trunc_f64_sat
                                      : cast(void*)u32_trunc_f64_sat,
                                 res, &value, 1))
            goto fail;
    }
    PUSH_I32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_extend_i32(JitCompContext* cc, bool sign) {
    JitReg num = void, res = void;
    POP_I32(num);
    res = jit_cc_new_reg_I64(cc);
    if (sign)
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(res, num)));
    else
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_U32TOI64(res, num)));
    PUSH_I64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_extend_i64(JitCompContext* cc, byte bitwidth) {
    JitReg value = void, tmp = void, res = void;
    POP_I64(value);
    tmp = jit_cc_new_reg_I32(cc);
    res = jit_cc_new_reg_I64(cc);
    switch (bitwidth) {
        case 8:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64TOI8(tmp, value)));
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I8TOI64(res, tmp)));
            break;
        }
        case 16:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64TOI16(tmp, value)));
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I16TOI64(res, tmp)));
            break;
        }
        case 32:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64TOI32(tmp, value)));
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(res, tmp)));
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }
    PUSH_I64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_extend_i32(JitCompContext* cc, byte bitwidth) {
    JitReg value = void, tmp = void, res = void;
    POP_I32(value);
    tmp = jit_cc_new_reg_I32(cc);
    res = jit_cc_new_reg_I32(cc);
    switch (bitwidth) {
        case 8:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI8(tmp, value)));
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I8TOI32(res, tmp)));
            break;
        }
        case 16:
        {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI16(tmp, value)));
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I16TOI32(res, tmp)));
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }
    PUSH_I32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_trunc_f32(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    POP_F32(value);
    res = jit_cc_new_reg_I64(cc);
    if (!sat) {
        JitReg min_fp = jit_cc_new_const_F32(cc, sign ? F32_I64_S_MIN : F32_I64_U_MIN);
        JitReg max_fp = jit_cc_new_const_F32(cc, sign ? F32_I64_S_MAX : F32_I64_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign) {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F32TOI64(res, value)));
        }
        else {
            if (!jit_emit_callnative(cc, &u64_trunc_f32, res, &value, 1))
                goto fail;
        }
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)i64_trunc_f32_sat
                                      : cast(void*)u64_trunc_f32_sat,
                                 res, &value, 1))
            goto fail;
    }
    PUSH_I64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_trunc_f64(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    POP_F64(value);
    res = jit_cc_new_reg_I64(cc);
    if (!sat) {
        JitReg min_fp = jit_cc_new_const_F64(cc, sign ? F64_I64_S_MIN : F64_I64_U_MIN);
        JitReg max_fp = jit_cc_new_const_F64(cc, sign ? F64_I64_S_MAX : F64_I64_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign) {
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F64TOI64(res, value)));
        }
        else {
            if (!jit_emit_callnative(cc, &u64_trunc_f64, res, &value, 1))
                goto fail;
        }
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)i64_trunc_f64_sat
                                      : cast(void*)u64_trunc_f64_sat,
                                 res, &value, 1))
            goto fail;
    }
    PUSH_I64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_convert_i32(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    POP_I32(value);
    res = jit_cc_new_reg_F32(cc);
    if (sign) {
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOF32(res, value)));
    }
    else {
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_U32TOF32(res, value)));
    }
    PUSH_F32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_convert_i64(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    POP_I64(value);
    res = jit_cc_new_reg_F32(cc);
    if (sign) {
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64TOF32(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc, &f32_convert_u64, res, &value, 1)) {
            goto fail;
        }
    }
    PUSH_F32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_demote_f64(JitCompContext* cc) {
    JitReg value = void, res = void;
    POP_F64(value);
    res = jit_cc_new_reg_F32(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F64TOF32(res, value)));
    PUSH_F32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_convert_i32(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    POP_I32(value);
    res = jit_cc_new_reg_F64(cc);
    if (sign)
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOF64(res, value)));
    else
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_U32TOF64(res, value)));
    PUSH_F64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_convert_i64(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    POP_I64(value);
    res = jit_cc_new_reg_F64(cc);
    if (sign) {
        _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64TOF64(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc, &f64_convert_u64, res, &value, 1)) {
            goto fail;
        }
    }
    PUSH_F64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_promote_f32(JitCompContext* cc) {
    JitReg value = void, res = void;
    POP_F32(value);
    res = jit_cc_new_reg_F64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F32TOF64(res, value)));
    PUSH_F64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_reinterpret_f64(JitCompContext* cc) {
    JitReg value = void, res = void;
    POP_F64(value);
    res = jit_cc_new_reg_I64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F64CASTI64(res, value)));
    PUSH_I64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_reinterpret_f32(JitCompContext* cc) {
    JitReg value = void, res = void;
    POP_F32(value);
    res = jit_cc_new_reg_I32(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_F32CASTI32(res, value)));
    PUSH_I32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_reinterpret_i64(JitCompContext* cc) {
    JitReg value = void, res = void;
    POP_I64(value);
    res = jit_cc_new_reg_F64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I64CASTF64(res, value)));
    PUSH_F64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_reinterpret_i32(JitCompContext* cc) {
    JitReg value = void, res = void;
    POP_I32(value);
    res = jit_cc_new_reg_F32(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32CASTF32(res, value)));
    PUSH_F32(res);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
