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
import core.stdc.math : isinf, isnan;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_ir :  JitReg, JitRegKind, JitOpcode,
jit_reg_kind,
jit_insn_new_CMP,

jit_insn_new_I32TOI8,
jit_insn_new_I8TOI32,
jit_insn_new_I8TOI64,

jit_insn_new_I16TOI32,
jit_insn_new_I16TOI64,

jit_insn_new_I32TOI16,
jit_insn_new_I32TOI64,
jit_insn_new_I32TOF32,
jit_insn_new_I32TOF64,

jit_insn_new_U32TOI64,
jit_insn_new_U32TOF32,
jit_insn_new_U32TOF64,

jit_insn_new_I64TOI8,
jit_insn_new_I64TOI16,
jit_insn_new_I64TOI32,
jit_insn_new_I64TOF32,
jit_insn_new_I64TOF64,

jit_insn_new_F32TOI32,
jit_insn_new_F32TOU32,
jit_insn_new_F32TOI64,
jit_insn_new_F32TOF64,

jit_insn_new_F64TOI32,
jit_insn_new_F64TOU32,
jit_insn_new_F64TOI64,
jit_insn_new_F64TOF32,

jit_insn_new_F32CASTI32,
jit_insn_new_F64CASTI64,
jit_insn_new_I32CASTF32,
jit_insn_new_I64CASTF64;

import tagion.iwasm.fast_jit.fe.jit_emit_function : jit_emit_callnative;
import tagion.iwasm.fast_jit.fe.jit_emit_exception : jit_emit_exception;
import tagion.iwasm.interpreter.wasm_runtime : EXCE_INTEGER_OVERFLOW, EXCE_INVALID_CONVERSION_TO_INTEGER;
import tagion.iwasm.share.utils.bh_assert;
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
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? int.min : int.max; }
    if (fp <= F32_I32_S_MIN) { return int.min; }
    if (fp >= F32_I32_S_MAX) { return int.max; }
    return cast(int)fp;
}
private uint u32_trunc_f32_sat(float fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : uint.max; }
    if (fp <= F32_I32_U_MIN) { return 0; }
    if (fp >= F32_I32_U_MAX) { return uint.max; }
    return cast(uint)fp;
}
private int i32_trunc_f64_sat(double fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? int.min : int.max; }
    if (fp <= F64_I32_S_MIN) { return int.min; }
    if (fp >= F64_I32_S_MAX) { return int.max; }
    return cast(int)fp;
}
private uint u32_trunc_f64_sat(double fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : uint.max; }
    if (fp <= F64_I32_U_MIN) { return 0; }
    if (fp >= F64_I32_U_MAX) { return uint.max; }
    return cast(uint)fp;
}
private long i64_trunc_f32_sat(float fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? long.min : long.max; }
    if (fp <= F32_I64_S_MIN) { return long.min; }
    if (fp >= F32_I64_S_MAX) { return long.max; }
    return cast(long)fp;
}
private ulong u64_trunc_f32(float fp) {
    return cast(ulong)fp;
}
private ulong u64_trunc_f32_sat(float fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : ulong.max; }
    if (fp <= F32_I64_U_MIN) { return 0; }
    if (fp >= F32_I64_U_MAX) { return ulong.max; }
    return cast(ulong)fp;
}
private long i64_trunc_f64_sat(double fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? long.min : long.max; }
    if (fp <= F64_I64_S_MIN) { return long.min; }
    if (fp >= F64_I64_S_MAX) { return long.max; }
    return cast(long)fp;
}
private ulong u64_trunc_f64(double fp) {
    return cast(ulong)fp;
}
private ulong u64_trunc_f64_sat(double fp) {
    if (fp.isnan) { return 0; }
    if (isinf(fp)) { return fp < 0 ? 0 : ulong.max; }
    if (fp <= F64_I64_U_MIN) { return 0; }
    if (fp >= F64_I64_U_MAX) { return ulong.max; }
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
    cc.pop_i64(num);
    res = cc.new_reg_I32;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64TOI32(res, num)));
    cc.push_i32(res);
    return true;
fail:
    return false;
}
private bool jit_compile_check_value_range(JitCompContext* cc, JitReg value, JitReg min_fp, JitReg max_fp) {
    JitReg nan_ret = cc.new_reg_I32;
    JitRegKind kind = jit_reg_kind(value);
    bool emit_ret = false;
    bh_assert(JitRegKind.F32 == kind || JitRegKind.F64 == kind);
    /* If value is NaN, throw exception */
    if (JitRegKind.F32 == kind)
        emit_ret = jit_emit_callnative(cc, &local_isnanf, nan_ret, &value, 1);
    else
        emit_ret = jit_emit_callnative(cc, &local_isnan, nan_ret, &value, 1);
    if (!emit_ret)
        goto fail;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_CMP(cc.cmp_reg, nan_ret, cc.new_const_I32(1))));
    if (!jit_emit_exception(cc, EXCE_INVALID_CONVERSION_TO_INTEGER, JitOpcode.JIT_OP_BEQ,
                            cc.cmp_reg, null))
        goto fail;
    /* If value is out of integer range, throw exception */
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_CMP(cc.cmp_reg, min_fp, value)));
    if (!jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW, JitOpcode.JIT_OP_BGES, cc.cmp_reg,
                            null))
        goto fail;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_CMP(cc.cmp_reg, value, max_fp)));
    if (!jit_emit_exception(cc, EXCE_INTEGER_OVERFLOW, JitOpcode.JIT_OP_BGES, cc.cmp_reg,
                            null))
        goto fail;
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_trunc_f32(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    cc.pop_f32(value);
    res = cc.new_reg_I32;
    if (!sat) {
        JitReg min_fp = cc.new_const_F32(sign ? F32_I32_S_MIN : F32_I32_U_MIN);
        JitReg max_fp = cc.new_const_F32(sign ? F32_I32_S_MAX : F32_I32_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign)
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F32TOI32(res, value)));
        else
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F32TOU32(res, value)));
    }
    else {
		pragma(msg, typeof(&i32_trunc_f32_sat));
		pragma(msg, typeof(&u32_trunc_f32_sat));

        if (!jit_emit_callnative(cc, 
                                 sign ? cast(void*)&i32_trunc_f32_sat
                                      : cast(void*)&u32_trunc_f32_sat,
                                 res, &value, 1))
            goto fail;
    }
    cc.push_i32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_trunc_f64(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    cc.pop_f64(value);
    res = cc.new_reg_I32;
    if (!sat) {
        JitReg min_fp = cc.new_const_F64(sign ? F64_I32_S_MIN : F64_I32_U_MIN);
        JitReg max_fp = cc.new_const_F64(sign ? F64_I32_S_MAX : F64_I32_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign)
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F64TOI32(res, value)));
        else
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F64TOU32(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)&i32_trunc_f64_sat
                                      : cast(void*)&u32_trunc_f64_sat,
                                 res, &value, 1))
            goto fail;
    }
    cc.push_i32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_extend_i32(JitCompContext* cc, bool sign) {
    JitReg num = void, res = void;
    cc.pop_i32(num);
    res = cc.new_reg_I64;
    if (sign)
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32TOI64(res, num)));
    else
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_U32TOI64(res, num)));
    cc.push_i64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_extend_i64(JitCompContext* cc, byte bitwidth) {
    JitReg value = void, tmp = void, res = void;
    cc.pop_i64(value);
    tmp = cc.new_reg_I32;
    res = cc.new_reg_I64;
    switch (bitwidth) {
        case 8:
        {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64TOI8(tmp, value)));
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I8TOI64(res, tmp)));
            break;
        }
        case 16:
        {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64TOI16(tmp, value)));
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I16TOI64(res, tmp)));
            break;
        }
        case 32:
        {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64TOI32(tmp, value)));
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32TOI64(res, tmp)));
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }
    cc.push_i64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_extend_i32(JitCompContext* cc, byte bitwidth) {
    JitReg value = void, tmp = void, res = void;
    cc.pop_i32(value);
    tmp = cc.new_reg_I32;
    res = cc.new_reg_I32;
    switch (bitwidth) {
        case 8:
        {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32TOI8(tmp, value)));
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I8TOI32(res, tmp)));
            break;
        }
        case 16:
        {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32TOI16(tmp, value)));
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I16TOI32(res, tmp)));
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }
    cc.push_i32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_trunc_f32(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    cc.pop_f32(value);
    res = cc.new_reg_I64;
    if (!sat) {
        JitReg min_fp = cc.new_const_F32(sign ? F32_I64_S_MIN : F32_I64_U_MIN);
        JitReg max_fp = cc.new_const_F32(sign ? F32_I64_S_MAX : F32_I64_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign) {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F32TOI64(res, value)));
        }
        else {
            if (!jit_emit_callnative(cc, &u64_trunc_f32, res, &value, 1))
                goto fail;
        }
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)&i64_trunc_f32_sat
                                      : cast(void*)&u64_trunc_f32_sat,
                                 res, &value, 1))
            goto fail;
    }
    cc.push_i64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_trunc_f64(JitCompContext* cc, bool sign, bool sat) {
    JitReg value = void, res = void;
    cc.pop_f64(value);
    res = cc.new_reg_I64;
    if (!sat) {
        JitReg min_fp = cc.new_const_F64(sign ? F64_I64_S_MIN : F64_I64_U_MIN);
        JitReg max_fp = cc.new_const_F64(sign ? F64_I64_S_MAX : F64_I64_U_MAX);
        if (!jit_compile_check_value_range(cc, value, min_fp, max_fp))
            goto fail;
        if (sign) {
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F64TOI64(res, value)));
        }
        else {
            if (!jit_emit_callnative(cc, &u64_trunc_f64, res, &value, 1))
                goto fail;
        }
    }
    else {
        if (!jit_emit_callnative(cc,
                                 sign ? cast(void*)&i64_trunc_f64_sat
                                      : cast(void*)&u64_trunc_f64_sat,
                                 res, &value, 1))
            goto fail;
    }
    cc.push_i64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_convert_i32(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    cc.pop_i32(value);
    res = cc.new_reg_F32;
    if (sign) {
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32TOF32(res, value)));
    }
    else {
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_U32TOF32(res, value)));
    }
    cc.push_f32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_convert_i64(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    cc.pop_i64(value);
    res = cc.new_reg_F32;
    if (sign) {
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64TOF32(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc, &f32_convert_u64, res, &value, 1)) {
            goto fail;
        }
    }
    cc.push_f32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_demote_f64(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_f64(value);
    res = cc.new_reg_F32;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F64TOF32(res, value)));
    cc.push_f32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_convert_i32(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    cc.pop_i32(value);
    res = cc.new_reg_F64;
    if (sign)
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32TOF64(res, value)));
    else
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_U32TOF64(res, value)));
    cc.push_f64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_convert_i64(JitCompContext* cc, bool sign) {
    JitReg value = void, res = void;
    cc.pop_i64(value);
    res = cc.new_reg_F64;
    if (sign) {
        cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64TOF64(res, value)));
    }
    else {
        if (!jit_emit_callnative(cc, &f64_convert_u64, res, &value, 1)) {
            goto fail;
        }
    }
    cc.push_f64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_promote_f32(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_f32(value);
    res = cc.new_reg_F64;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F32TOF64(res, value)));
    cc.push_f64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i64_reinterpret_f64(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_f64(value);
    res = cc.new_reg_I64;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F64CASTI64(res, value)));
    cc.push_i64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_i32_reinterpret_f32(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_f32(value);
    res = cc.new_reg_I32;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_F32CASTI32(res, value)));
    cc.push_i32(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f64_reinterpret_i64(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i64(value);
    res = cc.new_reg_F64;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I64CASTF64(res, value)));
    cc.push_f64(res);
    return true;
fail:
    return false;
}
bool jit_compile_op_f32_reinterpret_i32(JitCompContext* cc) {
    JitReg value = void, res = void;
    cc.pop_i32(value);
    res = cc.new_reg_F32;
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_I32CASTF32(res, value)));
    cc.push_f32(res);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */