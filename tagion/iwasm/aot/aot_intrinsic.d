module tagion.iwasm.aot.aot_intrinsic;

@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 XiaoMi Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


struct _Aot_intrinsic {
    const(char)* llvm_intrinsic;
    const(char)* native_intrinsic;
    ulong flag;
}

alias aot_intrinsic = _Aot_intrinsic;

/* clang-format off */
private const(aot_intrinsic)[65] g_intrinsic_mapping = [
    [ "llvm.experimental.constrained.fadd.f32", "aot_intrinsic_fadd_f32", AOT_INTRINSIC_FLAG_F32_FADD ],
    [ "llvm.experimental.constrained.fadd.f64", "aot_intrinsic_fadd_f64", AOT_INTRINSIC_FLAG_F64_FADD ],
    [ "llvm.experimental.constrained.fsub.f32", "aot_intrinsic_fsub_f32", AOT_INTRINSIC_FLAG_F32_FSUB ],
    [ "llvm.experimental.constrained.fsub.f64", "aot_intrinsic_fsub_f64", AOT_INTRINSIC_FLAG_F64_FSUB ],
    [ "llvm.experimental.constrained.fmul.f32", "aot_intrinsic_fmul_f32", AOT_INTRINSIC_FLAG_F32_FMUL ],
    [ "llvm.experimental.constrained.fmul.f64", "aot_intrinsic_fmul_f64", AOT_INTRINSIC_FLAG_F64_FMUL ],
    [ "llvm.experimental.constrained.fdiv.f32", "aot_intrinsic_fdiv_f32", AOT_INTRINSIC_FLAG_F32_FDIV ],
    [ "llvm.experimental.constrained.fdiv.f64", "aot_intrinsic_fdiv_f64", AOT_INTRINSIC_FLAG_F64_FDIV ],
    [ "llvm.fabs.f32", "aot_intrinsic_fabs_f32", AOT_INTRINSIC_FLAG_F32_FABS ],
    [ "llvm.fabs.f64", "aot_intrinsic_fabs_f64", AOT_INTRINSIC_FLAG_F64_FABS ],
    [ "llvm.ceil.f32", "aot_intrinsic_ceil_f32", AOT_INTRINSIC_FLAG_F32_CEIL ],
    [ "llvm.ceil.f64", "aot_intrinsic_ceil_f64", AOT_INTRINSIC_FLAG_F64_CEIL ],
    [ "llvm.floor.f32", "aot_intrinsic_floor_f32", AOT_INTRINSIC_FLAG_F32_FLOOR ],
    [ "llvm.floor.f64", "aot_intrinsic_floor_f64", AOT_INTRINSIC_FLAG_F64_FLOOR ],
    [ "llvm.trunc.f32", "aot_intrinsic_trunc_f32", AOT_INTRINSIC_FLAG_F32_TRUNC ],
    [ "llvm.trunc.f64", "aot_intrinsic_trunc_f64", AOT_INTRINSIC_FLAG_F64_TRUNC ],
    [ "llvm.rint.f32", "aot_intrinsic_rint_f32", AOT_INTRINSIC_FLAG_F32_RINT ],
    [ "llvm.rint.f64", "aot_intrinsic_rint_f64", AOT_INTRINSIC_FLAG_F64_RINT ],
    [ "llvm.sqrt.f32", "aot_intrinsic_sqrt_f32", AOT_INTRINSIC_FLAG_F32_SQRT ],
    [ "llvm.sqrt.f64", "aot_intrinsic_sqrt_f64", AOT_INTRINSIC_FLAG_F64_SQRT ],
    [ "llvm.copysign.f32", "aot_intrinsic_copysign_f32", AOT_INTRINSIC_FLAG_F32_COPYSIGN ],
    [ "llvm.copysign.f64", "aot_intrinsic_copysign_f64", AOT_INTRINSIC_FLAG_F64_COPYSIGN ],
    [ "llvm.minnum.f32", "aot_intrinsic_fmin_f32", AOT_INTRINSIC_FLAG_F32_MIN ],
    [ "llvm.minnum.f64", "aot_intrinsic_fmin_f64", AOT_INTRINSIC_FLAG_F64_MIN ],
    [ "llvm.maxnum.f32", "aot_intrinsic_fmax_f32", AOT_INTRINSIC_FLAG_F32_MAX ],
    [ "llvm.maxnum.f64", "aot_intrinsic_fmax_f64", AOT_INTRINSIC_FLAG_F64_MAX ],
    [ "llvm.ctlz.i32", "aot_intrinsic_clz_i32", AOT_INTRINSIC_FLAG_I32_CLZ ],
    [ "llvm.ctlz.i64", "aot_intrinsic_clz_i64", AOT_INTRINSIC_FLAG_I64_CLZ ],
    [ "llvm.cttz.i32", "aot_intrinsic_ctz_i32", AOT_INTRINSIC_FLAG_I32_CTZ ],
    [ "llvm.cttz.i64", "aot_intrinsic_ctz_i64", AOT_INTRINSIC_FLAG_I64_CTZ ],
    [ "llvm.ctpop.i32", "aot_intrinsic_popcnt_i32", AOT_INTRINSIC_FLAG_I32_POPCNT ],
    [ "llvm.ctpop.i64", "aot_intrinsic_popcnt_i64", AOT_INTRINSIC_FLAG_I64_POPCNT ],
    [ "f64_convert_i32_s", "aot_intrinsic_i32_to_f64", AOT_INTRINSIC_FLAG_I32_TO_F64 ],
    [ "f64_convert_i32_u", "aot_intrinsic_u32_to_f64", AOT_INTRINSIC_FLAG_U32_TO_F64 ],
    [ "f32_convert_i32_s", "aot_intrinsic_i32_to_f32", AOT_INTRINSIC_FLAG_I32_TO_F32 ],
    [ "f32_convert_i32_u", "aot_intrinsic_u32_to_f32", AOT_INTRINSIC_FLAG_U32_TO_F32 ],
    [ "f64_convert_i64_s", "aot_intrinsic_i64_to_f64", AOT_INTRINSIC_FLAG_I32_TO_F64 ],
    [ "f64_convert_i64_u", "aot_intrinsic_u64_to_f64", AOT_INTRINSIC_FLAG_U64_TO_F64 ],
    [ "f32_convert_i64_s", "aot_intrinsic_i64_to_f32", AOT_INTRINSIC_FLAG_I64_TO_F32 ],
    [ "f32_convert_i64_u", "aot_intrinsic_u64_to_f32", AOT_INTRINSIC_FLAG_U64_TO_F32 ],
    [ "i32_trunc_f32_u", "aot_intrinsic_f32_to_u32", AOT_INTRINSIC_FLAG_F32_TO_U32 ],
    [ "i32_trunc_f32_s", "aot_intrinsic_f32_to_i32", AOT_INTRINSIC_FLAG_F32_TO_I32 ],
    [ "i32_trunc_f64_u", "aot_intrinsic_f64_to_u32", AOT_INTRINSIC_FLAG_F64_TO_U32 ],
    [ "i32_trunc_f64_s", "aot_intrinsic_f64_to_i32", AOT_INTRINSIC_FLAG_F64_TO_I32 ],
    [ "i64_trunc_f64_u", "aot_intrinsic_f64_to_u64", AOT_INTRINSIC_FLAG_F64_TO_U64 ],
    [ "i64_trunc_f64_s", "aot_intrinsic_f64_to_i64", AOT_INTRINSIC_FLAG_F64_TO_I64 ],
    [ "f32_demote_f64", "aot_intrinsic_f64_to_f32", AOT_INTRINSIC_FLAG_F64_TO_F32 ],
    [ "f64_promote_f32", "aot_intrinsic_f32_to_f64", AOT_INTRINSIC_FLAG_F32_TO_F64 ],
    [ "f32_cmp", "aot_intrinsic_f32_cmp", AOT_INTRINSIC_FLAG_F32_CMP ],
    [ "f64_cmp", "aot_intrinsic_f64_cmp", AOT_INTRINSIC_FLAG_F64_CMP ],
    [ "i32.const", null, AOT_INTRINSIC_FLAG_I32_CONST ],
    [ "i64.const", null, AOT_INTRINSIC_FLAG_I64_CONST ],
    [ "f32.const", null, AOT_INTRINSIC_FLAG_F32_CONST ],
    [ "f64.const", null, AOT_INTRINSIC_FLAG_F64_CONST ],
    [ "i64.div_s", "aot_intrinsic_i64_div_s", AOT_INTRINSIC_FLAG_I64_DIV_S],
    [ "i32.div_s", "aot_intrinsic_i32_div_s", AOT_INTRINSIC_FLAG_I32_DIV_S],
    [ "i32.div_u", "aot_intrinsic_i32_div_u", AOT_INTRINSIC_FLAG_I32_DIV_U],
    [ "i32.rem_s", "aot_intrinsic_i32_rem_s", AOT_INTRINSIC_FLAG_I32_REM_S],
    [ "i32.rem_u", "aot_intrinsic_i32_rem_u", AOT_INTRINSIC_FLAG_I32_REM_U],
    [ "i64.div_u", "aot_intrinsic_i64_div_u", AOT_INTRINSIC_FLAG_I64_DIV_U],
    [ "i64.rem_s", "aot_intrinsic_i64_rem_s", AOT_INTRINSIC_FLAG_I64_REM_S],
    [ "i64.rem_u", "aot_intrinsic_i64_rem_u", AOT_INTRINSIC_FLAG_I64_REM_U],
    [ "i64.or", "aot_intrinsic_i64_bit_or", AOT_INTRINSIC_FLAG_I64_BIT_OR],
    [ "i64.and", "aot_intrinsic_i64_bit_and", AOT_INTRINSIC_FLAG_I64_BIT_AND],
];
/* clang-format on */

private const(uint) g_intrinsic_count = g_intrinsic_mapping.sizeof / aot_intrinsic.sizeof;

float32 aot_intrinsic_fadd_f32(float32 a, float32 b) {
    return a + b;
}

float64 aot_intrinsic_fadd_f64(float64 a, float64 b) {
    return a + b;
}

float32 aot_intrinsic_fsub_f32(float32 a, float32 b) {
    return a - b;
}

float64 aot_intrinsic_fsub_f64(float64 a, float64 b) {
    return a - b;
}

float32 aot_intrinsic_fmul_f32(float32 a, float32 b) {
    return a * b;
}

float64 aot_intrinsic_fmul_f64(float64 a, float64 b) {
    return a * b;
}

float32 aot_intrinsic_fdiv_f32(float32 a, float32 b) {
    return a / b;
}

float64 aot_intrinsic_fdiv_f64(float64 a, float64 b) {
    return a / b;
}

float32 aot_intrinsic_fabs_f32(float32 a) {
    return cast(float32)fabs(a);
}

float64 aot_intrinsic_fabs_f64(float64 a) {
    return fabs(a);
}

float32 aot_intrinsic_ceil_f32(float32 a) {
    return cast(float32)ceilf(a);
}

float64 aot_intrinsic_ceil_f64(float64 a) {
    return ceil(a);
}

float32 aot_intrinsic_floor_f32(float32 a) {
    return cast(float32)floorf(a);
}

float64 aot_intrinsic_floor_f64(float64 a) {
    return floor(a);
}

float32 aot_intrinsic_trunc_f32(float32 a) {
    return cast(float32)trunc(a);
}

float64 aot_intrinsic_trunc_f64(float64 a) {
    return trunc(a);
}

float32 aot_intrinsic_rint_f32(float32 a) {
    return cast(float32)rint(a);
}

float64 aot_intrinsic_rint_f64(float64 a) {
    return rint(a);
}

float32 aot_intrinsic_sqrt_f32(float32 a) {
    return cast(float32)sqrt(a);
}

float64 aot_intrinsic_sqrt_f64(float64 a) {
    return sqrt(a);
}

float32 aot_intrinsic_copysign_f32(float32 a, float32 b) {
    return signbit(b) ? (float32)-fabs(a) : cast(float32)fabs(a);
}

float64 aot_intrinsic_copysign_f64(float64 a, float64 b) {
    return signbit(b) ? -fabs(a) : fabs(a);
}

float32 aot_intrinsic_fmin_f32(float32 a, float32 b) {
    if (isnan(a))
        return a;
    else if (isnan(b))
        return b;
    else
        return cast(float32)fmin(a, b);
}

float64 aot_intrinsic_fmin_f64(float64 a, float64 b) {
    float64 c = fmin(a, b);
    if (c == 0 && a == b)
        return signbit(a) ? a : b;
    return c;
}

float32 aot_intrinsic_fmax_f32(float32 a, float32 b) {
    if (isnan(a))
        return a;
    else if (isnan(b))
        return b;
    else
        return cast(float32)fmax(a, b);
}

float64 aot_intrinsic_fmax_f64(float64 a, float64 b) {
    float64 c = fmax(a, b);
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

float32 aot_intrinsic_i32_to_f32(int i) {
    return cast(float32)i;
}

float32 aot_intrinsic_u32_to_f32(uint u) {
    return cast(float32)u;
}

float64 aot_intrinsic_i32_to_f64(int i) {
    return cast(float64)i;
}

float64 aot_intrinsic_u32_to_f64(uint u) {
    return cast(float64)u;
}

float32 aot_intrinsic_i64_to_f32(long i) {
    return cast(float32)i;
}

float32 aot_intrinsic_u64_to_f32(ulong u) {
    return cast(float32)u;
}

float64 aot_intrinsic_i64_to_f64(long i) {
    return cast(float64)i;
}

float64 aot_intrinsic_u64_to_f64(ulong u) {
    return cast(float64)u;
}

int aot_intrinsic_f32_to_i32(float32 f) {
    return cast(int)f;
}

uint aot_intrinsic_f32_to_u32(float32 f) {
    return cast(uint)f;
}

long aot_intrinsic_f32_to_i64(float32 f) {
    return cast(long)f;
}

ulong aot_intrinsic_f32_to_u64(float32 f) {
    return cast(ulong)f;
}

int aot_intrinsic_f64_to_i32(float64 f) {
    return cast(int)f;
}

uint aot_intrinsic_f64_to_u32(float64 f) {
    return cast(uint)f;
}

long aot_intrinsic_f64_to_i64(float64 f) {
    return cast(long)f;
}

ulong aot_intrinsic_f64_to_u64(float64 f) {
    return cast(ulong)f;
}

float64 aot_intrinsic_f32_to_f64(float32 f) {
    return cast(float64)f;
}

float32 aot_intrinsic_f64_to_f32(float64 f) {
    return cast(float32)f;
}

int aot_intrinsic_f32_cmp(AOTFloatCond cond, float32 lhs, float32 rhs) {
    switch (cond) {
        case FLOAT_EQ:
            return cast(float32)fabs(lhs - rhs) <= WA_FLT_EPSILON ? 1 : 0;

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

int aot_intrinsic_f64_cmp(AOTFloatCond cond, float64 lhs, float64 rhs) {
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
        if (!strcmp(llvm_intrinsic, g_intrinsic_mapping[cnt].llvm_intrinsic)) {
            return g_intrinsic_mapping[cnt].native_intrinsic;
        }
    }
    return null;
}

static if (WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0) {

private void add_intrinsic_capability(AOTCompContext* comp_ctx, ulong flag) {
    ulong group = AOT_INTRINSIC_GET_GROUP_FROM_FLAG(flag);
    if (group < sizeof(comp_ctx.flags) / uint64.sizeof) {
        comp_ctx.flags[group] |= flag;
    }
    else {
        bh_log(BH_LOG_LEVEL_WARNING, __FILE__, __LINE__,
               "intrinsic exceeds max limit.");
    }
}

private void add_i64_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_DIV_S);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_DIV_U);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_REM_S);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_REM_U);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_BIT_OR);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_BIT_AND);
}

private void add_i32_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_DIV_S);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_DIV_U);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_REM_S);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_REM_U);
}

private void add_f32_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_FABS);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_FADD);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_FSUB);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_FMUL);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_FDIV);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_SQRT);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_CMP);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_MIN);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_MAX);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_CEIL);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_FLOOR);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_TRUNC);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_RINT);
}

private void add_f64_common_intrinsics(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_FABS);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_FADD);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_FSUB);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_FMUL);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_FDIV);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_SQRT);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_CMP);
}

private void add_common_float_integer_convertion(AOTCompContext* comp_ctx) {
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_TO_F32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_U32_TO_F32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_TO_F64);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_U32_TO_F64);

    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_TO_F32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_U64_TO_F32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_TO_F64);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_U64_TO_F64);

    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_TO_I32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_TO_U32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_TO_I64);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_TO_U64);

    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_TO_I32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_TO_U32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_TO_I64);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_TO_U64);

    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_TO_F32);
    add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_TO_F64);
}

bool aot_intrinsic_check_capability(const(AOTCompContext)* comp_ctx, const(char)* llvm_intrinsic) {
    uint cnt = void;
    ulong flag = void;
    ulong group = void;

    for (cnt = 0; cnt < g_intrinsic_count; cnt++) {
        if (!strcmp(llvm_intrinsic, g_intrinsic_mapping[cnt].llvm_intrinsic)) {
            flag = g_intrinsic_mapping[cnt].flag;
            group = AOT_INTRINSIC_GET_GROUP_FROM_FLAG(flag);
            flag &= AOT_INTRINSIC_FLAG_MASK;
            if (group < sizeof(comp_ctx.flags) / uint64.sizeof) {
                if (comp_ctx.flags[group] & flag) {
                    return true;
                }
            }
            else {
                bh_log(BH_LOG_LEVEL_WARNING, __FILE__, __LINE__,
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
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_CONST);
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
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_CONST);
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
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_CONST);
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_CONST);
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I32_CONST);
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_I64_CONST);
    }
    else {
        /*
         * Use constant value table by default
         */
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F32_CONST);
        add_intrinsic_capability(comp_ctx, AOT_INTRINSIC_FLAG_F64_CONST);
    }
}

} /* WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0 */
/*
 * Copyright (C) 2021 XiaoMi Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
import tagion.iwasm.aot.aot_runtime;
static if (WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0) {
public import aot_llvm;
}

version (none) {
extern (C) {
//! #endif

enum AOT_INTRINSIC_GROUPS = 2;

/* Use uint64 as flag container:
 *   - The upper 16 bits are the intrinsic group number
 *   - The lower 48 bits are the intrinsic capability mask
 */

enum string AOT_INTRINSIC_FLAG(string group, string number) = ` \
    ((((uint64)(group & 0xffffLL)) << 48) | ((uint64)1 << number))`;

enum AOT_INTRINSIC_FLAG_MASK = (0x0000ffffffffffffL);

enum string AOT_INTRINSIC_GET_GROUP_FROM_FLAG(string flag) = ` \
    ((((uint64)flag) >> 48) & 0xffffLL)`;

/* clang-format off */
enum AOT_INTRINSIC_FLAG_F32_FADD =     AOT_INTRINSIC_FLAG(0, 0);
enum AOT_INTRINSIC_FLAG_F32_FSUB =     AOT_INTRINSIC_FLAG(0, 1);
enum AOT_INTRINSIC_FLAG_F32_FMUL =     AOT_INTRINSIC_FLAG(0, 2);
enum AOT_INTRINSIC_FLAG_F32_FDIV =     AOT_INTRINSIC_FLAG(0, 3);
enum AOT_INTRINSIC_FLAG_F32_FABS =     AOT_INTRINSIC_FLAG(0, 4);
enum AOT_INTRINSIC_FLAG_F32_CEIL =     AOT_INTRINSIC_FLAG(0, 5);
enum AOT_INTRINSIC_FLAG_F32_FLOOR =    AOT_INTRINSIC_FLAG(0, 6);
enum AOT_INTRINSIC_FLAG_F32_TRUNC =    AOT_INTRINSIC_FLAG(0, 7);
enum AOT_INTRINSIC_FLAG_F32_RINT =     AOT_INTRINSIC_FLAG(0, 8);
enum AOT_INTRINSIC_FLAG_F32_SQRT =     AOT_INTRINSIC_FLAG(0, 9);
enum AOT_INTRINSIC_FLAG_F32_COPYSIGN = AOT_INTRINSIC_FLAG(0, 10);
enum AOT_INTRINSIC_FLAG_F32_MIN =      AOT_INTRINSIC_FLAG(0, 11);
enum AOT_INTRINSIC_FLAG_F32_MAX =      AOT_INTRINSIC_FLAG(0, 12);
enum AOT_INTRINSIC_FLAG_I32_CLZ =      AOT_INTRINSIC_FLAG(0, 13);
enum AOT_INTRINSIC_FLAG_I32_CTZ =      AOT_INTRINSIC_FLAG(0, 14);
enum AOT_INTRINSIC_FLAG_I32_POPCNT =   AOT_INTRINSIC_FLAG(0, 15);
enum AOT_INTRINSIC_FLAG_I32_TO_F32 =   AOT_INTRINSIC_FLAG(0, 16);
enum AOT_INTRINSIC_FLAG_U32_TO_F32 =   AOT_INTRINSIC_FLAG(0, 17);
enum AOT_INTRINSIC_FLAG_I32_TO_F64 =   AOT_INTRINSIC_FLAG(0, 18);
enum AOT_INTRINSIC_FLAG_U32_TO_F64 =   AOT_INTRINSIC_FLAG(0, 19);
enum AOT_INTRINSIC_FLAG_F32_TO_I32 =   AOT_INTRINSIC_FLAG(0, 20);
enum AOT_INTRINSIC_FLAG_F32_TO_U32 =   AOT_INTRINSIC_FLAG(0, 21);
enum AOT_INTRINSIC_FLAG_F32_TO_I64 =   AOT_INTRINSIC_FLAG(0, 22);
enum AOT_INTRINSIC_FLAG_F32_TO_U64 =   AOT_INTRINSIC_FLAG(0, 23);
enum AOT_INTRINSIC_FLAG_F32_TO_F64 =   AOT_INTRINSIC_FLAG(0, 24);
enum AOT_INTRINSIC_FLAG_F32_CMP =      AOT_INTRINSIC_FLAG(0, 25);
enum AOT_INTRINSIC_FLAG_F32_CONST =    AOT_INTRINSIC_FLAG(0, 26);
enum AOT_INTRINSIC_FLAG_I32_CONST =    AOT_INTRINSIC_FLAG(0, 27);
enum AOT_INTRINSIC_FLAG_I32_DIV_U =    AOT_INTRINSIC_FLAG(0, 28);
enum AOT_INTRINSIC_FLAG_I32_REM_S =    AOT_INTRINSIC_FLAG(0, 29);
enum AOT_INTRINSIC_FLAG_I32_REM_U =    AOT_INTRINSIC_FLAG(0, 30);
enum AOT_INTRINSIC_FLAG_I32_DIV_S =    AOT_INTRINSIC_FLAG(0, 31);

enum AOT_INTRINSIC_FLAG_F64_FADD =     AOT_INTRINSIC_FLAG(1, 0);
enum AOT_INTRINSIC_FLAG_F64_FSUB =     AOT_INTRINSIC_FLAG(1, 1);
enum AOT_INTRINSIC_FLAG_F64_FMUL =     AOT_INTRINSIC_FLAG(1, 2);
enum AOT_INTRINSIC_FLAG_F64_FDIV =     AOT_INTRINSIC_FLAG(1, 3);
enum AOT_INTRINSIC_FLAG_F64_FABS =     AOT_INTRINSIC_FLAG(1, 4);
enum AOT_INTRINSIC_FLAG_F64_CEIL =     AOT_INTRINSIC_FLAG(1, 5);
enum AOT_INTRINSIC_FLAG_F64_FLOOR =    AOT_INTRINSIC_FLAG(1, 6);
enum AOT_INTRINSIC_FLAG_F64_TRUNC =    AOT_INTRINSIC_FLAG(1, 7);
enum AOT_INTRINSIC_FLAG_F64_RINT =     AOT_INTRINSIC_FLAG(1, 8);
enum AOT_INTRINSIC_FLAG_F64_SQRT =     AOT_INTRINSIC_FLAG(1, 9);
enum AOT_INTRINSIC_FLAG_F64_COPYSIGN = AOT_INTRINSIC_FLAG(1, 10);
enum AOT_INTRINSIC_FLAG_F64_MIN =      AOT_INTRINSIC_FLAG(1, 11);
enum AOT_INTRINSIC_FLAG_F64_MAX =      AOT_INTRINSIC_FLAG(1, 12);
enum AOT_INTRINSIC_FLAG_I64_CLZ =      AOT_INTRINSIC_FLAG(1, 13);
enum AOT_INTRINSIC_FLAG_I64_CTZ =      AOT_INTRINSIC_FLAG(1, 14);
enum AOT_INTRINSIC_FLAG_I64_POPCNT =   AOT_INTRINSIC_FLAG(1, 15);
enum AOT_INTRINSIC_FLAG_I64_TO_F32 =   AOT_INTRINSIC_FLAG(1, 16);
enum AOT_INTRINSIC_FLAG_U64_TO_F32 =   AOT_INTRINSIC_FLAG(1, 17);
enum AOT_INTRINSIC_FLAG_I64_TO_F64 =   AOT_INTRINSIC_FLAG(1, 18);
enum AOT_INTRINSIC_FLAG_U64_TO_F64 =   AOT_INTRINSIC_FLAG(1, 19);
enum AOT_INTRINSIC_FLAG_F64_TO_I32 =   AOT_INTRINSIC_FLAG(1, 20);
enum AOT_INTRINSIC_FLAG_F64_TO_U32 =   AOT_INTRINSIC_FLAG(1, 21);
enum AOT_INTRINSIC_FLAG_F64_TO_I64 =   AOT_INTRINSIC_FLAG(1, 22);
enum AOT_INTRINSIC_FLAG_F64_TO_U64 =   AOT_INTRINSIC_FLAG(1, 23);
enum AOT_INTRINSIC_FLAG_F64_TO_F32 =   AOT_INTRINSIC_FLAG(1, 24);
enum AOT_INTRINSIC_FLAG_F64_CMP =      AOT_INTRINSIC_FLAG(1, 25);
enum AOT_INTRINSIC_FLAG_F64_CONST =    AOT_INTRINSIC_FLAG(1, 26);
enum AOT_INTRINSIC_FLAG_I64_CONST =    AOT_INTRINSIC_FLAG(1, 27);
enum AOT_INTRINSIC_FLAG_I64_DIV_S =    AOT_INTRINSIC_FLAG(1, 28);
enum AOT_INTRINSIC_FLAG_I64_DIV_U =    AOT_INTRINSIC_FLAG(1, 29);
enum AOT_INTRINSIC_FLAG_I64_REM_S =    AOT_INTRINSIC_FLAG(1, 30);
enum AOT_INTRINSIC_FLAG_I64_REM_U =    AOT_INTRINSIC_FLAG(1, 31);
enum AOT_INTRINSIC_FLAG_I64_BIT_OR =   AOT_INTRINSIC_FLAG(1, 32);
enum AOT_INTRINSIC_FLAG_I64_BIT_AND =  AOT_INTRINSIC_FLAG(1, 33);

/* clang-format on */

float32 aot_intrinsic_fadd_f32(float32 a, float32 b);

float64 aot_intrinsic_fadd_f64(float64 a, float64 b);

float32 aot_intrinsic_fsub_f32(float32 a, float32 b);

float64 aot_intrinsic_fsub_f64(float64 a, float64 b);

float32 aot_intrinsic_fmul_f32(float32 a, float32 b);

float64 aot_intrinsic_fmul_f64(float64 a, float64 b);

float32 aot_intrinsic_fdiv_f32(float32 a, float32 b);

float64 aot_intrinsic_fdiv_f64(float64 a, float64 b);

float32 aot_intrinsic_fabs_f32(float32 a);

float64 aot_intrinsic_fabs_f64(float64 a);

float32 aot_intrinsic_ceil_f32(float32 a);

float64 aot_intrinsic_ceil_f64(float64 a);

float32 aot_intrinsic_floor_f32(float32 a);

float64 aot_intrinsic_floor_f64(float64 a);

float32 aot_intrinsic_trunc_f32(float32 a);

float64 aot_intrinsic_trunc_f64(float64 a);

float32 aot_intrinsic_rint_f32(float32 a);

float64 aot_intrinsic_rint_f64(float64 a);

float32 aot_intrinsic_sqrt_f32(float32 a);

float64 aot_intrinsic_sqrt_f64(float64 a);

float32 aot_intrinsic_copysign_f32(float32 a, float32 b);

float64 aot_intrinsic_copysign_f64(float64 a, float64 b);

float32 aot_intrinsic_fmin_f32(float32 a, float32 b);

float64 aot_intrinsic_fmin_f64(float64 a, float64 b);

float32 aot_intrinsic_fmax_f32(float32 a, float32 b);

float64 aot_intrinsic_fmax_f64(float64 a, float64 b);

uint aot_intrinsic_clz_i32(uint type);

uint aot_intrinsic_clz_i64(ulong type);

uint aot_intrinsic_ctz_i32(uint type);

uint aot_intrinsic_ctz_i64(ulong type);

uint aot_intrinsic_popcnt_i32(uint u);

uint aot_intrinsic_popcnt_i64(ulong u);

float32 aot_intrinsic_i32_to_f32(int i);

float32 aot_intrinsic_u32_to_f32(uint u);

float64 aot_intrinsic_i32_to_f64(int i);

float64 aot_intrinsic_u32_to_f64(uint u);

float32 aot_intrinsic_i64_to_f32(long i);

float32 aot_intrinsic_u64_to_f32(ulong u);

float64 aot_intrinsic_i64_to_f64(long i);

float64 aot_intrinsic_u64_to_f64(ulong u);

int aot_intrinsic_f32_to_i32(float32 f);

uint aot_intrinsic_f32_to_u32(float32 f);

long aot_intrinsic_f32_to_i64(float32 f);

ulong aot_intrinsic_f32_to_u64(float32 f);

int aot_intrinsic_f64_to_i32(float64 f);

uint aot_intrinsic_f64_to_u32(float64 f);

long aot_intrinsic_f64_to_i64(float64 f);

ulong aot_intrinsic_f64_to_u64(float64 f);

float64 aot_intrinsic_f32_to_f64(float32 f);

float32 aot_intrinsic_f64_to_f32(float64 f);

int aot_intrinsic_f32_cmp(AOTFloatCond cond, float32 lhs, float32 rhs);

int aot_intrinsic_f64_cmp(AOTFloatCond cond, float64 lhs, float64 rhs);

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

static if (WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0) {
bool aot_intrinsic_check_capability(const(AOTCompContext)* comp_ctx, const(char)* llvm_intrinsic);

void aot_intrinsic_fill_capability_flags(AOTCompContext* comp_ctx);
}

version (none) {}
}
}

 /* end of _AOT_INTRINSIC_H */
