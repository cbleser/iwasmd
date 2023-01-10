module tagion.iwasm.aot.aot_intrinsic;
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
 * Copyright (C) 2021 XiaoMi Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2021 XiaoMi Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.aot.aot_runtime;
import tagion.iwasm.compilation.aot_llvm;
/* Use uint64 as flag container:
 *   - The upper 16 bits are the intrinsic group number
 *   - The lower 48 bits are the intrinsic capability mask
 */
/* clang-format off */
/* clang-format on */
float aot_intrinsic_fadd_f32(float a, float b);
double aot_intrinsic_fadd_f64(double a, double b);
float aot_intrinsic_fsub_f32(float a, float b);
double aot_intrinsic_fsub_f64(double a, double b);
float aot_intrinsic_fmul_f32(float a, float b);
double aot_intrinsic_fmul_f64(double a, double b);
float aot_intrinsic_fdiv_f32(float a, float b);
double aot_intrinsic_fdiv_f64(double a, double b);
float aot_intrinsic_fabs_f32(float a);
double aot_intrinsic_fabs_f64(double a);
float aot_intrinsic_ceil_f32(float a);
double aot_intrinsic_ceil_f64(double a);
float aot_intrinsic_floor_f32(float a);
double aot_intrinsic_floor_f64(double a);
float aot_intrinsic_trunc_f32(float a);
double aot_intrinsic_trunc_f64(double a);
float aot_intrinsic_rint_f32(float a);
double aot_intrinsic_rint_f64(double a);
float aot_intrinsic_sqrt_f32(float a);
double aot_intrinsic_sqrt_f64(double a);
float aot_intrinsic_copysign_f32(float a, float b);
double aot_intrinsic_copysign_f64(double a, double b);
float aot_intrinsic_fmin_f32(float a, float b);
double aot_intrinsic_fmin_f64(double a, double b);
float aot_intrinsic_fmax_f32(float a, float b);
double aot_intrinsic_fmax_f64(double a, double b);
uint aot_intrinsic_clz_i32(uint type);
uint aot_intrinsic_clz_i64(ulong type);
uint aot_intrinsic_ctz_i32(uint type);
uint aot_intrinsic_ctz_i64(ulong type);
uint aot_intrinsic_popcnt_i32(uint u);
uint aot_intrinsic_popcnt_i64(ulong u);
float aot_intrinsic_i32_to_f32(int i);
float aot_intrinsic_u32_to_f32(uint u);
double aot_intrinsic_i32_to_f64(int i);
double aot_intrinsic_u32_to_f64(uint u);
float aot_intrinsic_i64_to_f32(long i);
float aot_intrinsic_u64_to_f32(ulong u);
double aot_intrinsic_i64_to_f64(long i);
double aot_intrinsic_u64_to_f64(ulong u);
int aot_intrinsic_f32_to_i32(float f);
uint aot_intrinsic_f32_to_u32(float f);
long aot_intrinsic_f32_to_i64(float f);
ulong aot_intrinsic_f32_to_u64(float f);
int aot_intrinsic_f64_to_i32(double f);
uint aot_intrinsic_f64_to_u32(double f);
long aot_intrinsic_f64_to_i64(double f);
ulong aot_intrinsic_f64_to_u64(double f);
double aot_intrinsic_f32_to_f64(float f);
float aot_intrinsic_f64_to_f32(double f);
int aot_intrinsic_f32_cmp(AOTFloatCond cond, float lhs, float rhs);
int aot_intrinsic_f64_cmp(AOTFloatCond cond, double lhs, double rhs);
long aot_intrinsic_i64_div_s(long l, long r);
int aot_intrinsic_i32_div_s(int l, int r);
uint aot_intrinsic_i32_div_u(uint l, uint r);
int aot_intrinsic_i32_rem_s(int l, int r);
uint aot_intrinsic_i32_rem_u(uint l, uint r);
ulong aot_intrinsic_i64_div_u(ulong l, ulong r);
long aot_intrinsic_i64_rem_s(long l, long r);
ulong aot_intrinsic_i64_rem_u(ulong l, ulong r);
ulong aot_intrinsic_i64_bit_or(ulong l, ulong r);
ulong aot_intrinsic_i64_bit_and(ulong l, ulong r);
const(char)* aot_intrinsic_get_symbol(const(char)* llvm_intrinsic);
bool aot_intrinsic_check_capability(const(AOTCompContext)* comp_ctx, const(char)* llvm_intrinsic);
void aot_intrinsic_fill_capability_flags(AOTCompContext* comp_ctx);
struct Aot_intrinsic {
    string llvm_intrinsic;
    string native_intrinsic;
    ulong flag;
}
//alias aot_intrinsic = _Aot_intrinsic;
/* clang-format off */
immutable(Aot_intrinsic[]) g_intrinsic_mapping = [
    Aot_intrinsic( "llvm.experimental.constrained.fadd.f32", "aot_intrinsic_fadd_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 0)) ),
Aot_intrinsic( "llvm.experimental.constrained.fadd.f64", "aot_intrinsic_fadd_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 0)) ),
    Aot_intrinsic( "llvm.experimental.constrained.fsub.f32", "aot_intrinsic_fsub_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 1)) ),
    Aot_intrinsic( "llvm.experimental.constrained.fsub.f64", "aot_intrinsic_fsub_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 1)) ),
    Aot_intrinsic( "llvm.experimental.constrained.fmul.f32", "aot_intrinsic_fmul_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 2)) ),
    Aot_intrinsic( "llvm.experimental.constrained.fmul.f64", "aot_intrinsic_fmul_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 2)) ),
    Aot_intrinsic( "llvm.experimental.constrained.fdiv.f32", "aot_intrinsic_fdiv_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 3)) ),
    Aot_intrinsic( "llvm.experimental.constrained.fdiv.f64", "aot_intrinsic_fdiv_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 3)) ),
    Aot_intrinsic( "llvm.fabs.f32", "aot_intrinsic_fabs_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 4)) ),
    Aot_intrinsic( "llvm.fabs.f64", "aot_intrinsic_fabs_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 4)) ),
    Aot_intrinsic( "llvm.ceil.f32", "aot_intrinsic_ceil_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 5)) ),
    Aot_intrinsic( "llvm.ceil.f64", "aot_intrinsic_ceil_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 5)) ),
    Aot_intrinsic( "llvm.floor.f32", "aot_intrinsic_floor_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 6)) ),
    Aot_intrinsic( "llvm.floor.f64", "aot_intrinsic_floor_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 6)) ),
    Aot_intrinsic( "llvm.trunc.f32", "aot_intrinsic_trunc_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 7)) ),
    Aot_intrinsic( "llvm.trunc.f64", "aot_intrinsic_trunc_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 7)) ),
    Aot_intrinsic( "llvm.rint.f32", "aot_intrinsic_rint_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 8)) ),
    Aot_intrinsic( "llvm.rint.f64", "aot_intrinsic_rint_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 8)) ),
    Aot_intrinsic( "llvm.sqrt.f32", "aot_intrinsic_sqrt_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 9)) ),
    Aot_intrinsic( "llvm.sqrt.f64", "aot_intrinsic_sqrt_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 9)) ),
    Aot_intrinsic( "llvm.copysign.f32", "aot_intrinsic_copysign_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 10)) ),
    Aot_intrinsic( "llvm.copysign.f64", "aot_intrinsic_copysign_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 10)) ),
    Aot_intrinsic( "llvm.minnum.f32", "aot_intrinsic_fmin_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 11)) ),
    Aot_intrinsic( "llvm.minnum.f64", "aot_intrinsic_fmin_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 11)) ),
    Aot_intrinsic( "llvm.maxnum.f32", "aot_intrinsic_fmax_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 12)) ),
    Aot_intrinsic( "llvm.maxnum.f64", "aot_intrinsic_fmax_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 12)) ),
    Aot_intrinsic( "llvm.ctlz.i32", "aot_intrinsic_clz_i32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 13)) ),
    Aot_intrinsic( "llvm.ctlz.i64", "aot_intrinsic_clz_i64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 13)) ),
    Aot_intrinsic( "llvm.cttz.i32", "aot_intrinsic_ctz_i32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 14)) ),
    Aot_intrinsic( "llvm.cttz.i64", "aot_intrinsic_ctz_i64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 14)) ),
    Aot_intrinsic( "llvm.ctpop.i32", "aot_intrinsic_popcnt_i32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 15)) ),
    Aot_intrinsic( "llvm.ctpop.i64", "aot_intrinsic_popcnt_i64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 15)) ),
    Aot_intrinsic( "f64_convert_i32_s", "aot_intrinsic_i32_to_f64", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 18)) ),
    Aot_intrinsic( "f64_convert_i32_u", "aot_intrinsic_u32_to_f64", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 19)) ),
    Aot_intrinsic( "f32_convert_i32_s", "aot_intrinsic_i32_to_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 16)) ),
    Aot_intrinsic( "f32_convert_i32_u", "aot_intrinsic_u32_to_f32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 17)) ),
    Aot_intrinsic( "f64_convert_i64_s", "aot_intrinsic_i64_to_f64", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 18)) ),
    Aot_intrinsic( "f64_convert_i64_u", "aot_intrinsic_u64_to_f64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 19)) ),
    Aot_intrinsic( "f32_convert_i64_s", "aot_intrinsic_i64_to_f32", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 16)) ),
    Aot_intrinsic( "f32_convert_i64_u", "aot_intrinsic_u64_to_f32", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 17)) ),
    Aot_intrinsic( "i32_trunc_f32_u", "aot_intrinsic_f32_to_u32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 21)) ),
    Aot_intrinsic( "i32_trunc_f32_s", "aot_intrinsic_f32_to_i32", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 20)) ),
    Aot_intrinsic( "i32_trunc_f64_u", "aot_intrinsic_f64_to_u32", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 21)) ),
    Aot_intrinsic( "i32_trunc_f64_s", "aot_intrinsic_f64_to_i32", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 20)) ),
    Aot_intrinsic( "i64_trunc_f64_u", "aot_intrinsic_f64_to_u64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 23)) ),
    Aot_intrinsic( "i64_trunc_f64_s", "aot_intrinsic_f64_to_i64", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 22)) ),
    Aot_intrinsic( "f32_demote_f64", "aot_intrinsic_f64_to_f32", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 24)) ),
    Aot_intrinsic( "f64_promote_f32", "aot_intrinsic_f32_to_f64", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 24)) ),
    Aot_intrinsic( "f32_cmp", "aot_intrinsic_f32_cmp", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 25)) ),
    Aot_intrinsic( "f64_cmp", "aot_intrinsic_f64_cmp", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 25)) ),
    Aot_intrinsic( "i32.const", null, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 27)) ),
    Aot_intrinsic( "i64.const", null, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 27)) ),
    Aot_intrinsic( "f32.const", null, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 26)) ),
    Aot_intrinsic( "f64.const", null, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 26)) ),
    Aot_intrinsic( "i64.div_s", "aot_intrinsic_i64_div_s", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 28))),
    Aot_intrinsic( "i32.div_s", "aot_intrinsic_i32_div_s", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 31))),
    Aot_intrinsic( "i32.div_u", "aot_intrinsic_i32_div_u", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 28))),
    Aot_intrinsic( "i32.rem_s", "aot_intrinsic_i32_rem_s", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 29))),
    Aot_intrinsic( "i32.rem_u", "aot_intrinsic_i32_rem_u", (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 30))),
    Aot_intrinsic( "i64.div_u", "aot_intrinsic_i64_div_u", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 29))),
    Aot_intrinsic( "i64.rem_s", "aot_intrinsic_i64_rem_s", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 30))),
    Aot_intrinsic( "i64.rem_u", "aot_intrinsic_i64_rem_u", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 31))),
    Aot_intrinsic( "i64.or", "aot_intrinsic_i64_bit_or", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 32))),
    Aot_intrinsic( "i64.and", "aot_intrinsic_i64_bit_and", (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 33))),
];
/* clang-format on */
enum g_intrinsic_count = g_intrinsic_mapping.length;

float aot_intrinsic_fadd_f32(float a, float b) {
    return a + b;
}
double aot_intrinsic_fadd_f64(double a, double b) {
    return a + b;
}
float aot_intrinsic_fsub_f32(float a, float b) {
    return a - b;
}
double aot_intrinsic_fsub_f64(double a, double b) {
    return a - b;
}
float aot_intrinsic_fmul_f32(float a, float b) {
    return a * b;
}
double aot_intrinsic_fmul_f64(double a, double b) {
    return a * b;
}
float aot_intrinsic_fdiv_f32(float a, float b) {
    return a / b;
}
double aot_intrinsic_fdiv_f64(double a, double b) {
    return a / b;
}
float aot_intrinsic_fabs_f32(float a) {
    return cast(float)fabs(a);
}
double aot_intrinsic_fabs_f64(double a) {
    return fabs(a);
}
float aot_intrinsic_ceil_f32(float a) {
    return cast(float)ceilf(a);
}
double aot_intrinsic_ceil_f64(double a) {
    return ceil(a);
}
float aot_intrinsic_floor_f32(float a) {
    return cast(float)floorf(a);
}
double aot_intrinsic_floor_f64(double a) {
    return floor(a);
}
float aot_intrinsic_trunc_f32(float a) {
    return cast(float)trunc(a);
}
double aot_intrinsic_trunc_f64(double a) {
    return trunc(a);
}
float aot_intrinsic_rint_f32(float a) {
    return cast(float)rint(a);
}
double aot_intrinsic_rint_f64(double a) {
    return rint(a);
}
float aot_intrinsic_sqrt_f32(float a) {
    return cast(float)sqrt(a);
}
double aot_intrinsic_sqrt_f64(double a) {
    return sqrt(a);
}
float aot_intrinsic_copysign_f32(float a, float b) {
    return signbit(b) ?cast(float)-fabs(a) : cast(float)fabs(a);
}
double aot_intrinsic_copysign_f64(double a, double b) {
    return signbit(b) ? -fabs(a) : fabs(a);
}
float aot_intrinsic_fmin_f32(float a, float b) {
    if (isnan(a))
        return a;
    else if (isnan(b))
        return b;
    else
        return cast(float)fmin(a, b);
}
double aot_intrinsic_fmin_f64(double a, double b) {
    double c = fmin(a, b);
    if (c == 0 && a == b)
        return signbit(a) ? a : b;
    return c;
}
float aot_intrinsic_fmax_f32(float a, float b) {
    if (isnan(a))
        return a;
    else if (isnan(b))
        return b;
    else
        return cast(float)fmax(a, b);
}
double aot_intrinsic_fmax_f64(double a, double b) {
    double c = fmax(a, b);
    if (c == 0 && a == b)
        return signbit(a) ? b : a;
    return c;
}
uint aot_intrinsic_clz_i32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 0x80000000)) {
        num++;
        type <<= 1;
    }
    return num;
}
uint aot_intrinsic_clz_i64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 0x8000000000000000L)) {
        num++;
        type <<= 1;
    }
    return num;
}
uint aot_intrinsic_ctz_i32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}
uint aot_intrinsic_ctz_i64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}
uint aot_intrinsic_popcnt_i32(uint u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}
uint aot_intrinsic_popcnt_i64(ulong u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}
float aot_intrinsic_i32_to_f32(int i) {
    return cast(float)i;
}
float aot_intrinsic_u32_to_f32(uint u) {
    return cast(float)u;
}
double aot_intrinsic_i32_to_f64(int i) {
    return cast(double)i;
}
double aot_intrinsic_u32_to_f64(uint u) {
    return cast(double)u;
}
float aot_intrinsic_i64_to_f32(long i) {
    return cast(float)i;
}
float aot_intrinsic_u64_to_f32(ulong u) {
    return cast(float)u;
}
double aot_intrinsic_i64_to_f64(long i) {
    return cast(double)i;
}
double aot_intrinsic_u64_to_f64(ulong u) {
    return cast(double)u;
}
int aot_intrinsic_f32_to_i32(float f) {
    return cast(int)f;
}
uint aot_intrinsic_f32_to_u32(float f) {
    return cast(uint)f;
}
long aot_intrinsic_f32_to_i64(float f) {
    return cast(long)f;
}
ulong aot_intrinsic_f32_to_u64(float f) {
    return cast(ulong)f;
}
int aot_intrinsic_f64_to_i32(double f) {
    return cast(int)f;
}
uint aot_intrinsic_f64_to_u32(double f) {
    return cast(uint)f;
}
long aot_intrinsic_f64_to_i64(double f) {
    return cast(long)f;
}
ulong aot_intrinsic_f64_to_u64(double f) {
    return cast(ulong)f;
}
double aot_intrinsic_f32_to_f64(float f) {
    return cast(double)f;
}
float aot_intrinsic_f64_to_f32(double f) {
    return cast(float)f;
}
int aot_intrinsic_f32_cmp(AOTFloatCond cond, float lhs, float rhs) {
    switch (cond) {
        case FLOAT_EQ:
            return cast(float)fabs(lhs - rhs) <= WA_FLT_EPSILON ? 1 : 0;
        case FLOAT_LT:
            return lhs < rhs ? 1 : 0;
        case FLOAT_GT:
            return lhs > rhs ? 1 : 0;
        case FLOAT_LE:
            return lhs <= rhs ? 1 : 0;
        case FLOAT_GE:
            return lhs >= rhs ? 1 : 0;
        case FLOAT_NE:
            return (isnan(lhs) || isnan(rhs) || lhs != rhs) ? 1 : 0;
        case FLOAT_UNO:
            return (isnan(lhs) || isnan(rhs)) ? 1 : 0;
        default:
            break;
    }
    return 0;
}
int aot_intrinsic_f64_cmp(AOTFloatCond cond, double lhs, double rhs) {
    switch (cond) {
        case FLOAT_EQ:
            return fabs(lhs - rhs) <= WA_DBL_EPSILON ? 1 : 0;
        case FLOAT_LT:
            return lhs < rhs ? 1 : 0;
        case FLOAT_GT:
            return lhs > rhs ? 1 : 0;
        case FLOAT_LE:
            return lhs <= rhs ? 1 : 0;
        case FLOAT_GE:
            return lhs >= rhs ? 1 : 0;
        case FLOAT_NE:
            return (isnan(lhs) || isnan(rhs) || lhs != rhs) ? 1 : 0;
        case FLOAT_UNO:
            return (isnan(lhs) || isnan(rhs)) ? 1 : 0;
        default:
            break;
    }
    return 0;
}
long aot_intrinsic_i64_div_s(long l, long r) {
    return l / r;
}
int aot_intrinsic_i32_div_s(int l, int r) {
    return l / r;
}
uint aot_intrinsic_i32_div_u(uint l, uint r) {
    return l / r;
}
int aot_intrinsic_i32_rem_s(int l, int r) {
    return l % r;
}
uint aot_intrinsic_i32_rem_u(uint l, uint r) {
    return l % r;
}
ulong aot_intrinsic_i64_div_u(ulong l, ulong r) {
    return l / r;
}
long aot_intrinsic_i64_rem_s(long l, long r) {
    return l % r;
}
ulong aot_intrinsic_i64_rem_u(ulong l, ulong r) {
    return l % r;
}
ulong aot_intrinsic_i64_bit_or(ulong l, ulong r) {
    return l | r;
}
ulong aot_intrinsic_i64_bit_and(ulong l, ulong r) {
    return l & r;
}
const(char)* aot_intrinsic_get_symbol(const(char)* llvm_intrinsic) {
    uint cnt = void;
    for (cnt = 0; cnt < g_intrinsic_count; cnt++) {
        if (!strcmp(llvm_intrinsic, g_intrinsic_mappingAot_intrinsic(cnt).llvm_intrinsic)) {
            return g_intrinsic_mappingAot_intrinsic(cnt).native_intrinsic;
        }
    }
    return null;
}
private void add_intrinsic_capability(AOTCompContext* comp_ctx, ulong flag) {
    ulong group = (((cast(ulong)flag) >> 48) & 0xffffL);
    if (group < sizeof(comp_ctx.flags) / uint64.sizeof) {
        comp_ctx.flagsAot_intrinsic(group) |= flag;
    }
    else {
        bh_log(BH_LOG_LEVEL_WARNING, "aot_intrinsic.c", 584,
               "intrinsic exceeds max limit.");
    }
}
private void add_i64_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 28)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 29)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 30)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 31)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 32)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 33)));
}
private void add_i32_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 31)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 28)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 29)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 30)));
}
private void add_f32_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 4)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 0)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 1)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 2)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 3)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 9)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 25)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 11)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 12)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 5)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 6)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 7)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 8)));
}
private void add_f64_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 4)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 0)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 1)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 2)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 3)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 9)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 25)));
}
private void add_common_float_integer_convertion(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 16)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 17)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 18)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 19)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 16)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 17)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 18)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 19)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 20)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 21)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 22)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 23)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 20)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 21)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 22)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 23)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 24)));
    add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 24)));
}
bool aot_intrinsic_check_capability(const(AOTCompContext)* comp_ctx, const(char)* llvm_intrinsic) {
    uint cnt = void;
    ulong flag = void;
    ulong group = void;
    for (cnt = 0; cnt < g_intrinsic_count; cnt++) {
        if (!strcmp(llvm_intrinsic, g_intrinsic_mappingAot_intrinsic(cnt).llvm_intrinsic)) {
            flag = g_intrinsic_mappingAot_intrinsic(cnt).flag;
            group = (((cast(ulong)flag) >> 48) & 0xffffL);
            flag &= (0x0000ffffffffffffL);
            if (group < sizeof(comp_ctx.flags) / uint64.sizeof) {
                if (comp_ctx.flagsAot_intrinsic(group) & flag) {
                    return true;
                }
            }
            else {
                bh_log(BH_LOG_LEVEL_WARNING, "aot_intrinsic.c", 685,
                       "intrinsic exceeds max limit.");
            }
        }
    }
    return false;
}
void aot_intrinsic_fill_capability_flags(AOTCompContext* comp_ctx) {
    memset(comp_ctx.flags, 0, typeof(comp_ctx.flags).sizeof);
    if (!comp_ctx.target_cpu)
        return;
    if (!strncmp(comp_ctx.target_arch, "thumb", 5)) {
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 27)));
        add_i32_common_intrinsics(comp_ctx);
        if (!strcmp(comp_ctx.target_cpu, "cortex-m7")) {
        }
        else if (!strcmp(comp_ctx.target_cpu, "cortex-m4")) {
            add_f64_common_intrinsics(comp_ctx);
        }
        else {
            add_f32_common_intrinsics(comp_ctx);
            add_f64_common_intrinsics(comp_ctx);
            add_i64_common_intrinsics(comp_ctx);
            add_common_float_integer_convertion(comp_ctx);
        }
    }
    else if (!strncmp(comp_ctx.target_arch, "riscv", 5)) {
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 27)));
        /*
         * Note: Use builtin intrinsics since hardware float operation
         * will cause rodata relocation
         */
        add_f32_common_intrinsics(comp_ctx);
        add_f64_common_intrinsics(comp_ctx);
        add_common_float_integer_convertion(comp_ctx);
        if (!strncmp(comp_ctx.target_arch, "riscv32", 7)) {
            add_i64_common_intrinsics(comp_ctx);
        }
    }
    else if (!strncmp(comp_ctx.target_arch, "xtensa", 6)) {
        /*
         * Note: Use builtin intrinsics since hardware float operation
         * will cause rodata relocation
         */
        add_f32_common_intrinsics(comp_ctx);
        add_i32_common_intrinsics(comp_ctx);
        add_f64_common_intrinsics(comp_ctx);
        add_i64_common_intrinsics(comp_ctx);
        add_common_float_integer_convertion(comp_ctx);
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 26)));
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 26)));
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 27)));
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 27)));
    }
    else {
        /*
         * Use constant value table by default
         */
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(0 & 0xffffL)) << 48) | (cast(ulong)1 << 26)));
        add_intrinsic_capability(comp_ctx, (((cast(ulong)(1 & 0xffffL)) << 48) | (cast(ulong)1 << 26)));
    }
}
