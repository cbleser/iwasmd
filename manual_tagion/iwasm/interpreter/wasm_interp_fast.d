module wasm_interp_fast;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wasm_interp;
public import bh_log;
public import wasm_runtime;
public import wasm_opcode;
public import wasm_loader;
public import ...common.wasm_exec_env;
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
public import ...common.wasm_shared_memory;
}

alias CellType_I32 = int;
alias CellType_I64 = long;
alias CellType_F32 = float32;
alias CellType_F64 = float64;

static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK" \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
enum string CHECK_MEMORY_OVERFLOW(string bytes) = `                             \
    do {                                                         \
        uint64 offset1 = (uint64)offset + (uint64)addr;          \
        if (offset1 + bytes <= (uint64)linear_mem_size)          \
            /* If offset1 is in valid range, maddr must also     \
                be in valid range, no need to check it again. */ \
            maddr = memory->memory_data + offset1;               \
        else                                                     \
            goto out_of_bounds;                                  \
    } while (0)`;

enum string CHECK_BULK_MEMORY_OVERFLOW(string start, string bytes, string maddr) = ` \
    do {                                                \
        uint64 offset1 = (uint32)(start);               \
        if (offset1 + bytes <= linear_mem_size)         \
            /* App heap space is not valid space for    \
               bulk memory operation */                 \
            maddr = memory->memory_data + offset1;      \
        else                                            \
            goto out_of_bounds;                         \
    } while (0)`;
} else {
enum string CHECK_MEMORY_OVERFLOW(string bytes) = `                    \
    do {                                                \
        uint64 offset1 = (uint64)offset + (uint64)addr; \
        maddr = memory->memory_data + offset1;          \
    } while (0)`;

enum string CHECK_BULK_MEMORY_OVERFLOW(string start, string bytes, string maddr) = ` \
    do {                                                \
        maddr = memory->memory_data + (uint32)(start);  \
    } while (0)`;
} /* !defined(OS_ENABLE_HW_BOUND_CHECK) \
          || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 */

enum string CHECK_ATOMIC_MEMORY_ACCESS(string align_) = `          \
    do {                                           \
        if (((uintptr_t)maddr & (align - 1)) != 0) \
            goto unaligned_atomic;                 \
    } while (0)`;

pragma(inline, true) private uint rotl32(uint n, uint c) {
    const(uint) mask = (31);
    c = c % 32;
    c &= mask;
    return (n << c) | (n >> ((0 - c) & mask));
}

pragma(inline, true) private uint rotr32(uint n, uint c) {
    const(uint) mask = (31);
    c = c % 32;
    c &= mask;
    return (n >> c) | (n << ((0 - c) & mask));
}

pragma(inline, true) private ulong rotl64(ulong n, ulong c) {
    const(ulong) mask = (63);
    c = c % 64;
    c &= mask;
    return (n << c) | (n >> ((0 - c) & mask));
}

pragma(inline, true) private ulong rotr64(ulong n, ulong c) {
    const(ulong) mask = (63);
    c = c % 64;
    c &= mask;
    return (n >> c) | (n << ((0 - c) & mask));
}

pragma(inline, true) private float32 f32_min(float32 a, float32 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

pragma(inline, true) private float32 f32_max(float32 a, float32 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

pragma(inline, true) private float64 f64_min(float64 a, float64 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

pragma(inline, true) private float64 f64_max(float64 a, float64 b) {
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

pragma(inline, true) private uint clz32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 0x80000000)) {
        num++;
        type <<= 1;
    }
    return num;
}

pragma(inline, true) private uint clz64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 0x8000000000000000LL)) {
        num++;
        type <<= 1;
    }
    return num;
}

pragma(inline, true) private uint ctz32(uint type) {
    uint num = 0;
    if (type == 0)
        return 32;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

pragma(inline, true) private uint ctz64(ulong type) {
    uint num = 0;
    if (type == 0)
        return 64;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

pragma(inline, true) private uint popcount32(uint u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

pragma(inline, true) private uint popcount64(ulong u) {
    uint ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

private float local_copysignf(float x, float y) {
    union _Ux {
        float f = void;
        uint i = void;
    }_Ux ux = { x };  uy = { y };
    ux.i &= 0x7fffffff;
    ux.i |= uy.i & 0x80000000;
    return ux.f;
}

private double local_copysign(double x, double y) {
    union _Ux {
        double f = void;
        ulong i = void;
    }_Ux ux = { x };  uy = { y };
    ux.i &= -1ULL / 2;
    ux.i |= uy.i & 1ULL << 63;
    return ux.f;
}

static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
enum string LOAD_U32_WITH_2U16S(string addr) = ` (*(uint32 *)(addr))`;
enum string LOAD_PTR(string addr) = ` (*(void **)(addr))`;
} else { /* else of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
pragma(inline, true) private uint LOAD_U32_WITH_2U16S(void* addr) {
    union _U {
        uint val = void;
        ushort[2] u16 = void;
    }_U u = void;

    bh_assert((cast(uintptr_t)addr & 1) == 0);
    u.u16[0] = (cast(ushort*)addr)[0];
    u.u16[1] = (cast(ushort*)addr)[1];
    return u.val;
}
static if (UINTPTR_MAX == UINT32_MAX) {
enum string LOAD_PTR(string addr) = ` ((void *)LOAD_U32_WITH_2U16S(addr))`;
} else static if (UINTPTR_MAX == UINT64_MAX) {
pragma(inline, true) private void* LOAD_PTR(void* addr) {
    uintptr_t addr1 = cast(uintptr_t)addr;
    union _U {
        void* val = void;
        uint[2] u32 = void;
        ushort[4] u16 = void;
    }_U u = void;

    bh_assert((cast(uintptr_t)addr & 1) == 0);
    if ((addr1 & cast(uintptr_t)7) == 0)
        return *cast(void**)addr;

    if ((addr1 & cast(uintptr_t)3) == 0) {
        u.u32[0] = (cast(uint*)addr)[0];
        u.u32[1] = (cast(uint*)addr)[1];
    }
    else {
        u.u16[0] = (cast(ushort*)addr)[0];
        u.u16[1] = (cast(ushort*)addr)[1];
        u.u16[2] = (cast(ushort*)addr)[2];
        u.u16[3] = (cast(ushort*)addr)[3];
    }
    return u.val;
}
} /* end of UINTPTR_MAX */
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */

enum string read_uint32(string p) = ` \
    (p += sizeof(uint32), LOAD_U32_WITH_2U16S(p - sizeof(uint32)))`;

enum string GET_LOCAL_INDEX_TYPE_AND_OFFSET() = `                                \
    do {                                                                 \
        uint32 param_count = cur_func->param_count;                      \
        local_idx = read_uint32(frame_ip);                               \
        bh_assert(local_idx < param_count + cur_func->local_count);      \
        local_offset = cur_func->local_offsets[local_idx];               \
        if (local_idx < param_count)                                     \
            local_type = cur_func->param_types[local_idx];               \
        else                                                             \
            local_type = cur_func->local_types[local_idx - param_count]; \
    } while (0)`;

enum string GET_OFFSET() = ` (frame_ip += 2, *(int16 *)(frame_ip - 2))`;

enum string SET_OPERAND_I32(string off, string value) = `                                 \
    do {                                                            \
        *(uint32 *)(frame_lp + *(int16 *)(frame_ip + off)) = value; \
    } while (0)`;
enum string SET_OPERAND_F32(string off, string value) = `                                  \
    do {                                                             \
        *(float32 *)(frame_lp + *(int16 *)(frame_ip + off)) = value; \
    } while (0)`;
enum string SET_OPERAND_I64(string off, string value) = `                               \
    do {                                                          \
        uint32 *addr_tmp = frame_lp + *(int16 *)(frame_ip + off); \
        PUT_I64_TO_ADDR(addr_tmp, value);                         \
    } while (0)`;
enum string SET_OPERAND_F64(string off, string value) = `                               \
    do {                                                          \
        uint32 *addr_tmp = frame_lp + *(int16 *)(frame_ip + off); \
        PUT_F64_TO_ADDR(addr_tmp, value);                         \
    } while (0)`;

enum string SET_OPERAND(string op_type, string off, string value) = ` SET_OPERAND_##op_type(off, value)`;

enum string GET_OPERAND_I32(string type, string off) = ` \
    *(type *)(frame_lp + *(int16 *)(frame_ip + off))`;
enum string GET_OPERAND_F32(string type, string off) = ` \
    *(type *)(frame_lp + *(int16 *)(frame_ip + off))`;
enum string GET_OPERAND_I64(string type, string off) = ` \
    (type) GET_I64_FROM_ADDR(frame_lp + *(int16 *)(frame_ip + off))`;
enum string GET_OPERAND_F64(string type, string off) = ` \
    (type) GET_F64_FROM_ADDR(frame_lp + *(int16 *)(frame_ip + off))`;

enum string GET_OPERAND(string type, string op_type, string off) = ` GET_OPERAND_##op_type(type, off)`;

enum string PUSH_I32(string value) = `                              \
    do {                                             \
        *(int32 *)(frame_lp + GET_OFFSET()) = value; \
    } while (0)`;

enum string PUSH_F32(string value) = `                                \
    do {                                               \
        *(float32 *)(frame_lp + GET_OFFSET()) = value; \
    } while (0)`;

enum string PUSH_I64(string value) = `                             \
    do {                                            \
        uint32 *addr_tmp = frame_lp + GET_OFFSET(); \
        PUT_I64_TO_ADDR(addr_tmp, value);           \
    } while (0)`;

enum string PUSH_F64(string value) = `                             \
    do {                                            \
        uint32 *addr_tmp = frame_lp + GET_OFFSET(); \
        PUT_F64_TO_ADDR(addr_tmp, value);           \
    } while (0)`;

enum string POP_I32() = ` (*(int32 *)(frame_lp + GET_OFFSET()))`;

enum string POP_F32() = ` (*(float32 *)(frame_lp + GET_OFFSET()))`;

enum string POP_I64() = ` (GET_I64_FROM_ADDR(frame_lp + GET_OFFSET()))`;

enum string POP_F64() = ` (GET_F64_FROM_ADDR(frame_lp + GET_OFFSET()))`;

enum string SYNC_ALL_TO_FRAME() = `   \
    do {                      \
        frame->ip = frame_ip; \
    } while (0)`;

enum string UPDATE_ALL_FROM_FRAME() = ` \
    do {                        \
        frame_ip = frame->ip;   \
    } while (0)`;

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
enum string UPDATE_FRAME_IP_END() = ` (void)0`;
} else {
enum string UPDATE_FRAME_IP_END() = ` frame_ip_end = wasm_get_func_code_end(cur_func)`;
}

enum string RECOVER_CONTEXT(string new_frame) = `      \
    do {                                \
        frame = (new_frame);            \
        cur_func = frame->function;     \
        prev_frame = frame->prev_frame; \
        frame_ip = frame->ip;           \
        UPDATE_FRAME_IP_END();          \
        frame_lp = frame->lp;           \
    } while (0)`;

static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
enum string GET_OPCODE() = ` opcode = *frame_ip++;`;
} else {
enum string GET_OPCODE() = `    \
    opcode = *frame_ip; \
    frame_ip += 2;`;
}

enum string DEF_OP_EQZ(string ctype, string src_op_type) = `                                  \
    do {                                                                \
        SET_OPERAND(I32, 2, (GET_OPERAND(ctype, src_op_type, 0) == 0)); \
        frame_ip += 4;                                                  \
    } while (0)`;

enum string DEF_OP_CMP(string src_type, string src_op_type, string cond) = `                      \
    do {                                                             \
        SET_OPERAND(I32, 4,                                          \
                    GET_OPERAND(src_type, src_op_type, 2)            \
                        cond GET_OPERAND(src_type, src_op_type, 0)); \
        frame_ip += 6;                                               \
    } while (0)`;

enum string DEF_OP_BIT_COUNT(string src_type, string src_op_type, string operation) = `               \
    do {                                                                 \
        SET_OPERAND(                                                     \
            src_op_type, 2,                                              \
            (src_type)operation(GET_OPERAND(src_type, src_op_type, 0))); \
        frame_ip += 4;                                                   \
    } while (0)`;

enum string DEF_OP_NUMERIC(string src_type1, string src_type2, string src_op_type, string operation) = `       \
    do {                                                                   \
        SET_OPERAND(src_op_type, 4,                                        \
                    GET_OPERAND(src_type1, src_op_type, 2)                 \
                        operation GET_OPERAND(src_type2, src_op_type, 0)); \
        frame_ip += 6;                                                     \
    } while (0)`;

enum string DEF_OP_REINTERPRET(string src_type, string src_op_type) = `                           \
    do {                                                                    \
        SET_OPERAND(src_op_type, 2, GET_OPERAND(src_type, src_op_type, 0)); \
        frame_ip += 4;                                                      \
    } while (0)`;

enum DEF_OP_NUMERIC_64 = DEF_OP_NUMERIC;

enum string DEF_OP_NUMERIC2(string src_type1, string src_type2, string src_op_type, string operation) = `  \
    do {                                                               \
        SET_OPERAND(src_op_type, 4,                                    \
                    GET_OPERAND(src_type1, src_op_type, 2) operation(  \
                        GET_OPERAND(src_type2, src_op_type, 0) % 32)); \
        frame_ip += 6;                                                 \
    } while (0)`;

enum string DEF_OP_NUMERIC2_64(string src_type1, string src_type2, string src_op_type, string operation) = ` \
    do {                                                                 \
        SET_OPERAND(src_op_type, 4,                                      \
                    GET_OPERAND(src_type1, src_op_type, 2) operation(    \
                        GET_OPERAND(src_type2, src_op_type, 0) % 64));   \
        frame_ip += 6;                                                   \
    } while (0)`;

enum string DEF_ATOMIC_RMW_OPCODE(string OP_NAME, string op) = `                           \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME:                           \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME##8_U:                      \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U:                     \
    {                                                                \
        uint32 readv, sval;                                          \
                                                                     \
        sval = POP_I32();                                            \
        addr = POP_I32();                                            \
                                                                     \
        if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##8_U) {       \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(1);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint32)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U) { \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(2);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint32)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else {                                                       \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(4);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = LOAD_I32(maddr);                                 \
            STORE_U32(maddr, readv op sval);                         \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        PUSH_I32(readv);                                             \
        break;                                                       \
    }                                                                \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME:                           \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME##8_U:                      \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME##16_U:                     \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME##32_U:                     \
    {                                                                \
        uint64 readv, sval;                                          \
                                                                     \
        sval = (uint64)POP_I64();                                    \
        addr = POP_I32();                                            \
                                                                     \
        if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##8_U) {       \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(1);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##16_U) { \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(2);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##32_U) { \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(4);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)LOAD_U32(maddr);                         \
            STORE_U32(maddr, (uint32)(readv op sval));               \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else {                                                       \
            uint64 op_result;                                        \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS(8);                           \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)LOAD_I64(maddr);                         \
            op_result = readv op sval;                               \
            STORE_I64(maddr, op_result);                             \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        PUSH_I64(readv);                                             \
        break;                                                       \
    }`;

enum string DEF_OP_MATH(string src_type, string src_op_type, string method) = `                            \
    do {                                                                      \
        SET_OPERAND(src_op_type, 2,                                           \
                    (src_type)method(GET_OPERAND(src_type, src_op_type, 0))); \
        frame_ip += 4;                                                        \
    } while (0)`;

enum string TRUNC_FUNCTION(string func_name, string src_type, string dst_type, string signed_type) = `  \
    static dst_type func_name(src_type src_value, src_type src_min, \
                              src_type src_max, dst_type dst_min,   \
                              dst_type dst_max, bool is_sign)       \
    {                                                               \
        dst_type dst_value = 0;                                     \
        if (!isnan(src_value)) {                                    \
            if (src_value <= src_min)                               \
                dst_value = dst_min;                                \
            else if (src_value >= src_max)                          \
                dst_value = dst_max;                                \
            else {                                                  \
                if (is_sign)                                        \
                    dst_value = (dst_type)(signed_type)src_value;   \
                else                                                \
                    dst_value = (dst_type)src_value;                \
            }                                                       \
        }                                                           \
        return dst_value;                                           \
    }`;

TRUNC_FUNCTION(trunc_f32_to_i32, float32, uint32, int32)
TRUNC_FUNCTION(trunc_f32_to_i64, float32, uint64, int64)
TRUNC_FUNCTION(trunc_f64_to_i32, float64, uint32, int32)
TRUNC_FUNCTION(trunc_f64_to_i64, float64, uint64, int64)

private bool trunc_f32_to_int(WASMModuleInstance* module_, ubyte* frame_ip, uint* frame_lp, float32 src_min, float32 src_max, bool saturating, bool is_i32, bool is_sign) {
    float32 src_value = GET_OPERAND(float32, F32, 0);
    ulong dst_value_i64 = void;
    uint dst_value_i32 = void;

    if (!saturating) {
        if (isnan(src_value)) {
            wasm_set_exception(module_, "invalid conversion to integer");
            return false;
        }
        else if (src_value <= src_min || src_value >= src_max) {
            wasm_set_exception(module_, "integer overflow");
            return false;
        }
    }

    if (is_i32) {
        uint dst_min = is_sign ? INT32_MIN : 0;
        uint dst_max = is_sign ? INT32_MAX : UINT32_MAX;
        dst_value_i32 = trunc_f32_to_i32(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I32, 2, dst_value_i32);
    }
    else {
        ulong dst_min = is_sign ? INT64_MIN : 0;
        ulong dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f32_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I64, 2, dst_value_i64);
    }
    return true;
}

private bool trunc_f64_to_int(WASMModuleInstance* module_, ubyte* frame_ip, uint* frame_lp, float64 src_min, float64 src_max, bool saturating, bool is_i32, bool is_sign) {
    float64 src_value = GET_OPERAND(float64, F64, 0);
    ulong dst_value_i64 = void;
    uint dst_value_i32 = void;

    if (!saturating) {
        if (isnan(src_value)) {
            wasm_set_exception(module_, "invalid conversion to integer");
            return false;
        }
        else if (src_value <= src_min || src_value >= src_max) {
            wasm_set_exception(module_, "integer overflow");
            return false;
        }
    }

    if (is_i32) {
        uint dst_min = is_sign ? INT32_MIN : 0;
        uint dst_max = is_sign ? INT32_MAX : UINT32_MAX;
        dst_value_i32 = trunc_f64_to_i32(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I32, 2, dst_value_i32);
    }
    else {
        ulong dst_min = is_sign ? INT64_MIN : 0;
        ulong dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f64_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I64, 2, dst_value_i64);
    }
    return true;
}

enum string DEF_OP_TRUNC_F32(string min, string max, string is_i32, string is_sign) = `                        \
    do {                                                                   \
        if (!trunc_f32_to_int(module, frame_ip, frame_lp, min, max, false, \
                              is_i32, is_sign))                            \
            goto got_exception;                                            \
        frame_ip += 4;                                                     \
    } while (0)`;

enum string DEF_OP_TRUNC_F64(string min, string max, string is_i32, string is_sign) = `                        \
    do {                                                                   \
        if (!trunc_f64_to_int(module, frame_ip, frame_lp, min, max, false, \
                              is_i32, is_sign))                            \
            goto got_exception;                                            \
        frame_ip += 4;                                                     \
    } while (0)`;

enum string DEF_OP_TRUNC_SAT_F32(string min, string max, string is_i32, string is_sign) = `                    \
    do {                                                                   \
        (void)trunc_f32_to_int(module, frame_ip, frame_lp, min, max, true, \
                               is_i32, is_sign);                           \
        frame_ip += 4;                                                     \
    } while (0)`;

enum string DEF_OP_TRUNC_SAT_F64(string min, string max, string is_i32, string is_sign) = `                    \
    do {                                                                   \
        (void)trunc_f64_to_int(module, frame_ip, frame_lp, min, max, true, \
                               is_i32, is_sign);                           \
        frame_ip += 4;                                                     \
    } while (0)`;

enum string DEF_OP_CONVERT(string dst_type, string dst_op_type, string src_type, string src_op_type) = ` \
    do {                                                             \
        dst_type value = (dst_type)(src_type)POP_##src_op_type();    \
        PUSH_##dst_op_type(value);                                   \
    } while (0)`;

static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
enum CELL_SIZE = sizeof(uint8);
} else {
enum CELL_SIZE = (sizeof(uint8) * 2);
}

private bool copy_stack_values(WASMModuleInstance* module_, uint* frame_lp, uint arity, uint total_cell_num, const(ubyte)* cells, const(short)* src_offsets, const(ushort)* dst_offsets) {
    /* To avoid the overlap issue between src offsets and dst offset,
     * we use 2 steps to do the copy. First step, copy the src values
     * to a tmp buf. Second step, copy the values from tmp buf to dst.
     */
    uint[16] buf = 0; uint i = void;
    uint* tmp_buf = buf;
    ubyte cell = void;
    short src = void, buf_index = 0;
    ushort dst = void;

    /* Allocate memory if the buf is not large enough */
    if (total_cell_num > buf.sizeof / uint32.sizeof) {
        ulong total_size = sizeof(uint32) * cast(ulong)total_cell_num;
        if (total_size >= UINT32_MAX
            || ((tmp_buf = wasm_runtime_malloc(cast(uint)total_size)) == 0)) {
            wasm_set_exception(module_, "allocate memory failed");
            return false;
        }
    }

    /* 1) Copy values from src to tmp buf */
    for (i = 0; i < arity; i++) {
        cell = cells[i * CELL_SIZE];
        src = src_offsets[i];
        if (cell == 1)
            tmp_buf[buf_index] = frame_lp[src];
        else {
            tmp_buf[buf_index] = frame_lp[src];
            tmp_buf[buf_index + 1] = frame_lp[src + 1];
        }
        buf_index += cell;
    }

    /* 2) Copy values from tmp buf to dest */
    buf_index = 0;
    for (i = 0; i < arity; i++) {
        cell = cells[i * CELL_SIZE];
        dst = dst_offsets[i];
        if (cell == 1)
            frame_lp[dst] = tmp_buf[buf_index];
        else {
            frame_lp[dst] = tmp_buf[buf_index];
            frame_lp[dst + 1] = tmp_buf[buf_index + 1];
        }
        buf_index += cell;
    }

    if (tmp_buf != buf.ptr) {
        wasm_runtime_free(tmp_buf);
    }

    return true;
}

enum string RECOVER_BR_INFO() = `                                                   \
    do {                                                                    \
        uint32 arity;                                                       \
        /* read arity */                                                    \
        arity = read_uint32(frame_ip);                                      \
        if (arity) {                                                        \
            uint32 total_cell;                                              \
            uint16 *dst_offsets = NULL;                                     \
            uint8 *cells;                                                   \
            int16 *src_offsets = NULL;                                      \
            /* read total cell num */                                       \
            total_cell = read_uint32(frame_ip);                             \
            /* cells */                                                     \
            cells = (uint8 *)frame_ip;                                      \
            frame_ip += arity * CELL_SIZE;                                  \
            /* src offsets */                                               \
            src_offsets = (int16 *)frame_ip;                                \
            frame_ip += arity * sizeof(int16);                              \
            /* dst offsets */                                               \
            dst_offsets = (uint16 *)frame_ip;                               \
            frame_ip += arity * sizeof(uint16);                             \
            if (arity == 1) {                                               \
                if (cells[0] == 1)                                          \
                    frame_lp[dst_offsets[0]] = frame_lp[src_offsets[0]];    \
                else if (cells[0] == 2) {                                   \
                    frame_lp[dst_offsets[0]] = frame_lp[src_offsets[0]];    \
                    frame_lp[dst_offsets[0] + 1] =                          \
                        frame_lp[src_offsets[0] + 1];                       \
                }                                                           \
            }                                                               \
            else {                                                          \
                if (!copy_stack_values(module, frame_lp, arity, total_cell, \
                                       cells, src_offsets, dst_offsets))    \
                    goto got_exception;                                     \
            }                                                               \
        }                                                                   \
        frame_ip = (uint8 *)LOAD_PTR(frame_ip);                             \
    } while (0)`;

enum string SKIP_BR_INFO() = `                                                        \
    do {                                                                      \
        uint32 arity;                                                         \
        /* read and skip arity */                                             \
        arity = read_uint32(frame_ip);                                        \
        if (arity) {                                                          \
            /* skip total cell num */                                         \
            frame_ip += sizeof(uint32);                                       \
            /* skip cells, src offsets and dst offsets */                     \
            frame_ip += (CELL_SIZE + sizeof(int16) + sizeof(uint16)) * arity; \
        }                                                                     \
        /* skip target address */                                             \
        frame_ip += sizeof(uint8 *);                                          \
    } while (0)`;

pragma(inline, true) private int sign_ext_8_32(byte val) {
    if (val & 0x80)
        return cast(int)val | cast(int)0xffffff00;
    return val;
}

pragma(inline, true) private int sign_ext_16_32(short val) {
    if (val & 0x8000)
        return cast(int)val | cast(int)0xffff0000;
    return val;
}

pragma(inline, true) private long sign_ext_8_64(byte val) {
    if (val & 0x80)
        return cast(long)val | cast(long)0xffffffffffffff00LL;
    return val;
}

pragma(inline, true) private long sign_ext_16_64(short val) {
    if (val & 0x8000)
        return cast(long)val | cast(long)0xffffffffffff0000LL;
    return val;
}

pragma(inline, true) private long sign_ext_32_64(int val) {
    if (val & cast(int)0x80000000)
        return cast(long)val | cast(long)0xffffffff00000000LL;
    return val;
}

pragma(inline, true) private void word_copy(uint* dest, uint* src, uint num) {
    bh_assert(dest != null);
    bh_assert(src != null);
    bh_assert(num > 0);
    if (dest != src) {
        /* No overlap buffer */
        bh_assert(!((src < dest) && (dest < src + num)));
        for (; num > 0; num--)
            *dest++ = *src++;
    }
}

pragma(inline, true) private WASMInterpFrame* ALLOC_FRAME(WASMExecEnv* exec_env, uint size, WASMInterpFrame* prev_frame) {
    WASMInterpFrame* frame = wasm_exec_env_alloc_wasm_frame(exec_env, size);

    if (frame) {
        frame.prev_frame = prev_frame;
static if (WASM_ENABLE_PERF_PROFILING != 0) {
        frame.time_started = os_time_get_boot_microsecond();
}
    }
    else {
        wasm_set_exception(cast(WASMModuleInstance*)exec_env.module_inst,
                           "wasm operand stack overflow");
    }

    return frame;
}

pragma(inline, true) private void FREE_FRAME(WASMExecEnv* exec_env, WASMInterpFrame* frame) {
static if (WASM_ENABLE_PERF_PROFILING != 0) {
    if (frame.function_) {
        frame.function_.total_exec_time +=
            os_time_get_boot_microsecond() - frame.time_started;
        frame.function_.total_exec_cnt++;
    }
}
    wasm_exec_env_free_wasm_frame(exec_env, frame);
}

private void wasm_interp_call_func_native(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* cur_func, WASMInterpFrame* prev_frame) {
    WASMFunctionImport* func_import = cur_func.u.func_import;
    CApiFuncImport* c_api_func_import = null;
    uint local_cell_num = 2;
    WASMInterpFrame* frame = void;
    uint[2] argv_ret = void; uint cur_func_index = void;
    void* native_func_pointer = null;
    bool ret = void;

    if (((frame = ALLOC_FRAME(exec_env,
                              wasm_interp_interp_frame_size(local_cell_num),
                              prev_frame)) == 0))
        return;

    frame.function_ = cur_func;
    frame.ip = null;
    frame.lp = frame.operand;

    wasm_exec_env_set_cur_frame(exec_env, frame);

    cur_func_index = (uint32)(cur_func - module_inst.e.functions);
    bh_assert(cur_func_index < module_inst.module_.import_function_count);
    if (!func_import.call_conv_wasm_c_api) {
        native_func_pointer = module_inst.import_func_ptrs[cur_func_index];
    }
    else {
        c_api_func_import = module_inst.e.c_api_func_imports + cur_func_index;
        native_func_pointer = c_api_func_import.func_ptr_linked;
    }

    if (!native_func_pointer) {
        char[128] buf = void;
        snprintf(buf.ptr, buf.sizeof,
                 "failed to call unlinked import function (%s, %s)",
                 func_import.module_name, func_import.field_name);
        wasm_set_exception(cast(WASMModuleInstance*)module_inst, buf.ptr);
        return;
    }

    if (func_import.call_conv_wasm_c_api) {
        ret = wasm_runtime_invoke_c_api_native(
            cast(WASMModuleInstanceCommon*)module_inst, native_func_pointer,
            func_import.func_type, cur_func.param_cell_num, frame.lp,
            c_api_func_import.with_env_arg, c_api_func_import.env_arg);
        if (ret) {
            argv_ret[0] = frame.lp[0];
            argv_ret[1] = frame.lp[1];
        }
    }
    else if (!func_import.call_conv_raw) {
        ret = wasm_runtime_invoke_native(
            exec_env, native_func_pointer, func_import.func_type,
            func_import.signature, func_import.attachment, frame.lp,
            cur_func.param_cell_num, argv_ret.ptr);
    }
    else {
        ret = wasm_runtime_invoke_native_raw(
            exec_env, native_func_pointer, func_import.func_type,
            func_import.signature, func_import.attachment, frame.lp,
            cur_func.param_cell_num, argv_ret.ptr);
    }

    if (!ret)
        return;

    if (cur_func.ret_cell_num == 1) {
        prev_frame.lp[prev_frame.ret_offset] = argv_ret[0];
    }
    else if (cur_func.ret_cell_num == 2) {
        prev_frame.lp[prev_frame.ret_offset] = argv_ret[0];
        prev_frame.lp[prev_frame.ret_offset + 1] = argv_ret[1];
    }

    FREE_FRAME(exec_env, frame);
    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
}

static if (WASM_ENABLE_MULTI_MODULE != 0) {
private void wasm_interp_call_func_bytecode(WASMModuleInstance* module_, WASMExecEnv* exec_env, WASMFunctionInstance* cur_func, WASMInterpFrame* prev_frame);

private void wasm_interp_call_func_import(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* cur_func, WASMInterpFrame* prev_frame) {
    WASMModuleInstance* sub_module_inst = cur_func.import_module_inst;
    WASMFunctionInstance* sub_func_inst = cur_func.import_func_inst;
    WASMFunctionImport* func_import = cur_func.u.func_import;
    ubyte* ip = prev_frame.ip;
    char[128] buf = void;
    WASMExecEnv* sub_module_exec_env = null;
    uint aux_stack_origin_boundary = 0;
    uint aux_stack_origin_bottom = 0;

    if (!sub_func_inst) {
        snprintf(buf.ptr, buf.sizeof,
                 "failed to call unlinked import function (%s, %s)",
                 func_import.module_name, func_import.field_name);
        wasm_set_exception(module_inst, buf.ptr);
        return;
    }

    /* Switch exec_env but keep using the same one by replacing necessary
     * variables */
    sub_module_exec_env = wasm_runtime_get_exec_env_singleton(
        cast(WASMModuleInstanceCommon*)sub_module_inst);
    if (!sub_module_exec_env) {
        wasm_set_exception(module_inst, "create singleton exec_env failed");
        return;
    }

    /* - module_inst */
    exec_env.module_inst = cast(WASMModuleInstanceCommon*)sub_module_inst;
    /* - aux_stack_boundary */
    aux_stack_origin_boundary = exec_env.aux_stack_boundary.boundary;
    exec_env.aux_stack_boundary.boundary =
        sub_module_exec_env.aux_stack_boundary.boundary;
    /* - aux_stack_bottom */
    aux_stack_origin_bottom = exec_env.aux_stack_bottom.bottom;
    exec_env.aux_stack_bottom.bottom =
        sub_module_exec_env.aux_stack_bottom.bottom;

    /* set ip NULL to make call_func_bytecode return after executing
       this function */
    prev_frame.ip = null;

    /* call function of sub-module*/
    wasm_interp_call_func_bytecode(sub_module_inst, exec_env, sub_func_inst,
                                   prev_frame);

    /* restore ip and other replaced */
    prev_frame.ip = ip;
    exec_env.aux_stack_boundary.boundary = aux_stack_origin_boundary;
    exec_env.aux_stack_bottom.bottom = aux_stack_origin_bottom;
    exec_env.module_inst = cast(WASMModuleInstanceCommon*)module_inst;

    /* transfer exception if it is thrown */
    if (wasm_get_exception(sub_module_inst)) {
        bh_memcpy_s(module_inst.cur_exception,
                    typeof(module_inst.cur_exception).sizeof,
                    sub_module_inst.cur_exception,
                    typeof(sub_module_inst.cur_exception).sizeof);
    }
}
}

static if (WASM_ENABLE_THREAD_MGR != 0) {
enum string CHECK_SUSPEND_FLAGS() = `                           \
    do {                                                \
        if (exec_env->suspend_flags.flags != 0) {       \
            if (exec_env->suspend_flags.flags & 0x01) { \
                /* terminate current thread */          \
                return;                                 \
            }                                           \
            /* TODO: support suspend and breakpoint */  \
        }                                               \
    } while (0)`;
}

static if (WASM_ENABLE_OPCODE_COUNTER != 0) {
struct OpcodeInfo {
    char* name;
    ulong count;
}

/* clang-format off */
enum string HANDLE_OPCODE(string op) = ` \
    {                     \
        #op, 0            \
    }`;
DEFINE_GOTO_TABLE(OpcodeInfo, opcode_table);
/* clang-format on */

private void wasm_interp_dump_op_count() {
    uint i = void;
    ulong total_count = 0;
    for (i = 0; i < WASM_OP_IMPDEP; i++)
        total_count += opcode_table[i].count;

    printf("total opcode count: %ld\n", total_count);
    for (i = 0; i < WASM_OP_IMPDEP; i++)
        if (opcode_table[i].count > 0)
            printf("\t\t%s count:\t\t%ld,\t\t%.2f%%\n", opcode_table[i].name,
                   opcode_table[i].count,
                   opcode_table[i].count * 100.0f / total_count);
}
}

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {

/* #define HANDLE_OP(opcode) HANDLE_##opcode:printf(#opcode"\n"); */
static if (WASM_ENABLE_OPCODE_COUNTER != 0) {
enum string HANDLE_OP(string opcode) = ` HANDLE_##opcode : opcode_table[opcode].count++;`;
} else {
enum string HANDLE_OP(string opcode) = ` HANDLE_##opcode:`;
}
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
enum string FETCH_OPCODE_AND_DISPATCH() = `                    \
    do {                                               \
        const void *p_label_addr = *(void **)frame_ip; \
        frame_ip += sizeof(void *);                    \
        goto *p_label_addr;                            \
    } while (0)`;
} else {
enum string FETCH_OPCODE_AND_DISPATCH() = `                                 \
    do {                                                            \
        const void *p_label_addr = label_base + *(int16 *)frame_ip; \
        frame_ip += sizeof(int16);                                  \
        goto *p_label_addr;                                         \
    } while (0)`;
} /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
enum string HANDLE_OP_END() = ` FETCH_OPCODE_AND_DISPATCH()`;

} else { /* else of WASM_ENABLE_LABELS_AS_VALUES */

enum string HANDLE_OP(string opcode) = ` case opcode:`;
enum string HANDLE_OP_END() = ` continue`;

} /* end of WASM_ENABLE_LABELS_AS_VALUES */

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
private void** global_handle_table;
}

pragma(inline, true) private ubyte* get_global_addr(ubyte* global_data, WASMGlobalInstance* global) {
static if (WASM_ENABLE_MULTI_MODULE == 0) {
    return global_data + global.data_offset;
} else {
    return global.import_global_inst
               ? global.import_module_inst.global_data
                     + global.import_global_inst.data_offset
               : global_data + global.data_offset;
}
}

static void
wasm_interp_call_func_bytecode(WASMModuleInstance* module_,
                               WASMExecEnv* exec_env,
                               WASMFunctionInstance* cur_func,
                               WASMInterpFrame* prev_frame)
{
    WASMMemoryInstance* memory = wasm_get_default_memory(module_);
static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK"              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0) {
    uint num_bytes_per_page = memory ? memory.num_bytes_per_page : 0;
    uint linear_mem_size = memory ? num_bytes_per_page * memory.cur_page_count : 0;
}
    ubyte* global_data = module_.global_data;
    WASMGlobalInstance* globals = module_.e ? module_.e.globals : null;
    WASMGlobalInstance* global;
    ubyte opcode_IMPDEP = WASM_OP_IMPDEP;
    WASMInterpFrame* frame = null;
    /* Points to this special opcode so as to jump to the
     * call_method_from_entry.  */
    ubyte* frame_ip = &opcode_IMPDEP; /* cache of frame->ip */
    uint* frame_lp = null;          /* cache of frame->lp */
static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
    /* cache of label base addr */
    ubyte* label_base = &&HANDLE_WASM_OP_UNREACHABLE;
}
}
    ubyte* frame_ip_end = frame_ip + 1;
    uint cond, count, fidx, tidx, frame_size = 0;
    uint all_cell_num = 0;
    short addr1, addr2, addr_ret = 0;
    int didx, val;
    ubyte* maddr = null;
    uint local_idx, local_offset, global_idx;
    ubyte opcode, local_type; ubyte* global_addr;

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
enum string HANDLE_OPCODE(string op) = ` &&HANDLE_##op`;
    DEFINE_GOTO_TABLE(void, handle_table);
    if (exec_env == null) {
        global_handle_table = cast(void**)handle_table;
        return;
    }
}

#if WASM_ENABLE_LABELS_AS_VALUES == 0
    while (frame_ip < frame_ip_end) {
        opcode = *frame_ip++;
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
        frame_ip++;
}
        switch (opcode) {
//! #else
    goto *handle_table[WASM_OP_IMPDEP];
//! #endif
            /* control instructions */
            HANDLE_OP(WASM_OP_UNREACHABLE)
            {
                wasm_set_exception(module_, "unreachable");
                goto got_exception;
            }

            HANDLE_OP WASM_OP_IF {
                cond = cast(uint)POP_I32();

                if (cond == 0) {
                    ubyte* else_addr = cast(ubyte*)LOAD_PTR(frame_ip);
                    if (else_addr == null) {
                        frame_ip =
                            cast(ubyte*)LOAD_PTR(frame_ip + (ubyte*).sizeof);
                    }
                    else {
                        frame_ip = else_addr;
                    }
                }
                else {
                    frame_ip += (ubyte*).sizeof * 2;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_ELSE {
                frame_ip = cast(ubyte*)LOAD_PTR(frame_ip);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_BR {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
            recover_br_info:
                RECOVER_BR_INFO();
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_BR_IF {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                cond = frame_lp[GET_OFFSET()];

                if (cond)
                    goto recover_br_info;
                else
                    SKIP_BR_INFO();

                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_BR_TABLE {
                uint arity = void, br_item_size = void;

static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                count = read_uint32(frame_ip);
                didx = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;

                if (!(didx >= 0 && cast(uint)didx < count))
                    didx = count;

                /* all br items must have the same arity and item size,
                   so we only calculate the first item size */
                arity = LOAD_U32_WITH_2U16S(frame_ip);
                br_item_size = uint32.sizeof; /* arity */
                if (arity) {
                    /* total cell num */
                    br_item_size += uint32.sizeof;
                    /* cells, src offsets and dst offsets */
                    br_item_size +=
                        (CELL_SIZE + sizeof(int16) + uint16.sizeof) * arity;
                }
                /* target address */
                br_item_size += (ubyte*).sizeof;

                frame_ip += br_item_size * didx;
                goto recover_br_info;
            }

            HANDLE_OP WASM_OP_RETURN {
                uint ret_idx = void;
                WASMType* func_type = void;
                uint off = void, ret_offset = void;
                ubyte* ret_types = void;
                if (cur_func.is_import_func)
                    func_type = cur_func.u.func_import.func_type;
                else
                    func_type = cur_func.u.func.func_type;

                /* types of each return value */
                ret_types = func_type.types + func_type.param_count;
                ret_offset = prev_frame.ret_offset;

                for (ret_idx = 0,
                    off = sizeof(int16) * (func_type.result_count - 1);
                     ret_idx < func_type.result_count;
                     ret_idx++, off -= int16.sizeof) {
                    if (ret_types[ret_idx] == VALUE_TYPE_I64
                        || ret_types[ret_idx] == VALUE_TYPE_F64) {
                        PUT_I64_TO_ADDR(prev_frame.lp + ret_offset,
                                        GET_OPERAND(uint64, I64, off));
                        ret_offset += 2;
                    }
                    else {
                        prev_frame.lp[ret_offset] =
                            GET_OPERAND(uint32, I32, off);
                        ret_offset++;
                    }
                }
                goto return_func;
            }

            HANDLE_OP(WASM_OP_CALL_INDIRECT)
static if (WASM_ENABLE_TAIL_CALL != 0) {
            HANDLE_OP(WASM_OP_RETURN_CALL_INDIRECT)
}
            {
                WASMType* cur_type, cur_func_type;
                WASMTableInstance* tbl_inst;
                uint tbl_idx;

static if (WASM_ENABLE_TAIL_CALL != 0) {
                GET_OPCODE();
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}

                tidx = read_uint32(frame_ip);
                cur_type = module_.module_.types[tidx];

                tbl_idx = read_uint32(frame_ip);
                bh_assert(tbl_idx < module_.table_count);

                tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                val = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;

                if (cast(uint)val >= tbl_inst.cur_size) {
                    wasm_set_exception(module_, "undefined element");
                    goto got_exception;
                }

                fidx = tbl_inst.elems[val];
                if (fidx == NULL_REF) {
                    wasm_set_exception(module_, "uninitialized element");
                    goto got_exception;
                }

                /*
                 * we might be using a table injected by host or
                 * another module. in that case, we don't validate
                 * the elem value while loading
                 */
                if (fidx >= module_.e.function_count) {
                    wasm_set_exception(module_, "unknown function");
                    goto got_exception;
                }

                /* always call module own functions */
                cur_func = module_.e.functions + fidx;

                if (cur_func.is_import_func)
                    cur_func_type = cur_func.u.func_import.func_type;
                else
                    cur_func_type = cur_func.u.func.func_type;

                if (cur_type != cur_func_type) {
                    wasm_set_exception(module_, "indirect call type mismatch");
                    goto got_exception;
                }

static if (WASM_ENABLE_TAIL_CALL != 0) {
                if (opcode == WASM_OP_RETURN_CALL_INDIRECT)
                    goto call_func_from_return_call;
}
                goto call_func_from_interp;
            }

            /* parametric instructions */
            HANDLE_OP WASM_OP_SELECT {
                cond = frame_lp[GET_OFFSET()];
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                if (!cond) {
                    if (addr_ret != addr1)
                        frame_lp[addr_ret] = frame_lp[addr1];
                }
                else {
                    if (addr_ret != addr2)
                        frame_lp[addr_ret] = frame_lp[addr2];
                }
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SELECT_64 {
                cond = frame_lp[GET_OFFSET()];
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                if (!cond) {
                    if (addr_ret != addr1)
                        PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                        GET_I64_FROM_ADDR(frame_lp + addr1));
                }
                else {
                    if (addr_ret != addr2)
                        PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                        GET_I64_FROM_ADDR(frame_lp + addr2));
                }
                HANDLE_OP_END();
            }

static if (WASM_ENABLE_REF_TYPES != 0) {
            HANDLE_OP WASM_OP_TABLE_GET {
                uint tbl_idx = void, elem_idx = void;
                WASMTableInstance* tbl_inst = void;

                tbl_idx = read_uint32(frame_ip);
                bh_assert(tbl_idx < module_.table_count);

                tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                elem_idx = POP_I32();
                if (elem_idx >= tbl_inst.cur_size) {
                    wasm_set_exception(module_, "out of bounds table access");
                    goto got_exception;
                }

                PUSH_I32(tbl_inst.elems[elem_idx]);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_TABLE_SET {
                uint tbl_idx = void, elem_idx = void, elem_val = void;
                WASMTableInstance* tbl_inst = void;

                tbl_idx = read_uint32(frame_ip);
                bh_assert(tbl_idx < module_.table_count);

                tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                elem_val = POP_I32();
                elem_idx = POP_I32();
                if (elem_idx >= tbl_inst.cur_size) {
                    wasm_set_exception(module_, "out of bounds table access");
                    goto got_exception;
                }

                tbl_inst.elems[elem_idx] = elem_val;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_REF_NULL {
                PUSH_I32(NULL_REF);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_REF_IS_NULL {
                uint ref_val = void;
                ref_val = POP_I32();
                PUSH_I32(ref_val == NULL_REF ? 1 : 0);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_REF_FUNC {
                uint func_idx = read_uint32(frame_ip);
                PUSH_I32(func_idx);
                HANDLE_OP_END();
            }
} /* WASM_ENABLE_REF_TYPES */

            /* variable instructions */
             HANDLE_OP(EXT_OP_TEE_LOCAL_FAST) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
                local_offset = *frame_ip++;
} else {
        /* clang-format off */
                local_offset = *frame_ip;
                frame_ip += 2;
        /* clang-format on */
}
                *cast(uint*)(frame_lp + local_offset) =
                    GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                HANDLE_OP_END();
            }

             HANDLE_OP(EXT_OP_TEE_LOCAL_FAST_I64) {
static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
                local_offset = *frame_ip++;
} else {
        /* clang-format off */
                local_offset = *frame_ip;
                frame_ip += 2;
        /* clang-format on */
}
                PUT_I64_TO_ADDR(cast(uint*)(frame_lp + local_offset),
                                GET_OPERAND(uint64, I64, 0));
                frame_ip += 2;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_GET_GLOBAL {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr_ret = GET_OFFSET();
                frame_lp[addr_ret] = *cast(uint*)global_addr;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_GET_GLOBAL_64 {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr_ret = GET_OFFSET();
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                GET_I64_FROM_ADDR(cast(uint*)global_addr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SET_GLOBAL {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr1 = GET_OFFSET();
                *cast(int*)global_addr = frame_lp[addr1];
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SET_GLOBAL_AUX_STACK {
                uint aux_stack_top = void;

                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                aux_stack_top = frame_lp[GET_OFFSET()];
                if (aux_stack_top <= exec_env.aux_stack_boundary.boundary) {
                    wasm_set_exception(module_, "wasm auxiliary stack overflow");
                    goto got_exception;
                }
                if (aux_stack_top > exec_env.aux_stack_bottom.bottom) {
                    wasm_set_exception(module_,
                                       "wasm auxiliary stack underflow");
                    goto got_exception;
                }
                *cast(int*)global_addr = aux_stack_top;
static if (WASM_ENABLE_MEMORY_PROFILING != 0) {
                if (module_.module_.aux_stack_top_global_index != (uint32)-1) {
                    uint aux_stack_used = module_.module_.aux_stack_bottom
                                            - *cast(uint*)global_addr;
                    if (aux_stack_used > module_.e.max_aux_stack_used)
                        module_.e.max_aux_stack_used = aux_stack_used;
                }
}
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SET_GLOBAL_64 {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr1 = GET_OFFSET();
                PUT_I64_TO_ADDR(cast(uint*)global_addr,
                                GET_I64_FROM_ADDR(frame_lp + addr1));
                HANDLE_OP_END();
            }

            /* memory load instructions */
            HANDLE_OP WASM_OP_I32_LOAD {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                frame_lp[addr_ret] = LOAD_I32(maddr);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(8);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, LOAD_I64(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD8_S {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                frame_lp[addr_ret] = sign_ext_8_32(*cast(byte*)maddr);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD8_U {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                frame_lp[addr_ret] = (uint32)(*cast(ubyte*)maddr);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD16_S {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                frame_lp[addr_ret] = sign_ext_16_32(LOAD_I16(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD16_U {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                frame_lp[addr_ret] = (uint32)(LOAD_U16(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD8_S {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                sign_ext_8_64(*cast(byte*)maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD8_U {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, (uint64)(*cast(ubyte*)maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD16_S {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                sign_ext_16_64(LOAD_I16(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD16_U {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, (uint64)(LOAD_U16(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD32_S {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                sign_ext_32_64(LOAD_I32(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD32_U {
                uint offset = void, addr = void;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, (uint64)(LOAD_U32(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_STORE {
                uint offset = void, addr = void;
                uint sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint32, I32, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(4);
                STORE_U32(maddr, sval);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_STORE8 {
                uint offset = void, addr = void;
                uint sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint32, I32, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(1);
                *cast(ubyte*)maddr = cast(ubyte)sval;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_STORE16 {
                uint offset = void, addr = void;
                uint sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint32, I32, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(2);
                STORE_U16(maddr, cast(ushort)sval);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_STORE {
                uint offset = void, addr = void;
                ulong sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(8);
                STORE_I64(maddr, sval);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_STORE8 {
                uint offset = void, addr = void;
                ulong sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(1);
                *cast(ubyte*)maddr = cast(ubyte)sval;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_STORE16 {
                uint offset = void, addr = void;
                ulong sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(2);
                STORE_U16(maddr, cast(ushort)sval);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_STORE32 {
                uint offset = void, addr = void;
                ulong sval = void;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(4);
                STORE_U32(maddr, cast(uint)sval);
                HANDLE_OP_END();
            }

            /* memory size and memory grow instructions */
            HANDLE_OP WASM_OP_MEMORY_SIZE {
                uint reserved = void;
                addr_ret = GET_OFFSET();
                frame_lp[addr_ret] = memory.cur_page_count;
                cast(void)reserved;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_MEMORY_GROW {
                uint reserved = void, delta = void, prev_page_count = memory.cur_page_count;

                addr1 = GET_OFFSET();
                addr_ret = GET_OFFSET();
                delta = cast(uint)frame_lp[addr1];

                if (!wasm_enlarge_memory(module_, delta)) {
                    /* failed to memory.grow, return -1 */
                    frame_lp[addr_ret] = -1;
                }
                else {
                    /* success, return previous page count */
                    frame_lp[addr_ret] = prev_page_count;
                    /* update memory size, no need to update memory ptr as
                       it isn't changed in wasm_enlarge_memory */
static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK"              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0) {
                    linear_mem_size =
                        num_bytes_per_page * memory.cur_page_count;
}
                }

                cast(void)reserved;
                HANDLE_OP_END();
            }

            /* constant instructions */
             HANDLE_OP(WASM_OP_I64_CONST) {
                ubyte* orig_ip = frame_ip;

                frame_ip += uint64.sizeof;
                addr_ret = GET_OFFSET();

                bh_memcpy_s(frame_lp + addr_ret, uint64.sizeof, orig_ip,
                            uint64.sizeof);
                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_I32_CONST) {
                ubyte* orig_ip = frame_ip;

                frame_ip += uint32.sizeof;
                addr_ret = GET_OFFSET();

                bh_memcpy_s(frame_lp + addr_ret, uint32.sizeof, orig_ip,
                            uint32.sizeof);
                HANDLE_OP_END();
            }

            /* comparison instructions of i32 */
            HANDLE_OP WASM_OP_I32_EQZ {
                DEF_OP_EQZ(int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_EQ {
                DEF_OP_CMP(uint32, I32, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_NE {
                DEF_OP_CMP(uint32, I32, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LT_S {
                DEF_OP_CMP(int32, I32, <);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LT_U {
                DEF_OP_CMP(uint32, I32, <);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_GT_S {
                DEF_OP_CMP(int32, I32, >);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_GT_U {
                DEF_OP_CMP(uint32, I32, >);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LE_S {
                DEF_OP_CMP(int32, I32, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LE_U {
                DEF_OP_CMP(uint32, I32, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_GE_S {
                DEF_OP_CMP(int32, I32, >=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_GE_U {
                DEF_OP_CMP(uint32, I32, >=);
                HANDLE_OP_END();
            }

            /* comparison instructions of i64 */
            HANDLE_OP WASM_OP_I64_EQZ {
                DEF_OP_EQZ(int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_EQ {
                DEF_OP_CMP(uint64, I64, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_NE {
                DEF_OP_CMP(uint64, I64, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LT_S {
                DEF_OP_CMP(int64, I64, <);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LT_U {
                DEF_OP_CMP(uint64, I64, <);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_GT_S {
                DEF_OP_CMP(int64, I64, >);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_GT_U {
                DEF_OP_CMP(uint64, I64, >);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LE_S {
                DEF_OP_CMP(int64, I64, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LE_U {
                DEF_OP_CMP(uint64, I64, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_GE_S {
                DEF_OP_CMP(int64, I64, >=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_GE_U {
                DEF_OP_CMP(uint64, I64, >=);
                HANDLE_OP_END();
            }

            /* comparison instructions of f32 */
            HANDLE_OP WASM_OP_F32_EQ {
                DEF_OP_CMP(float32, F32, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_NE {
                DEF_OP_CMP(float32, F32, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_LT {
                DEF_OP_CMP(float32, F32, <);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_GT {
                DEF_OP_CMP(float32, F32, >);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_LE {
                DEF_OP_CMP(float32, F32, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_GE {
                DEF_OP_CMP(float32, F32, >=);
                HANDLE_OP_END();
            }

            /* comparison instructions of f64 */
            HANDLE_OP WASM_OP_F64_EQ {
                DEF_OP_CMP(float64, F64, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_NE {
                DEF_OP_CMP(float64, F64, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_LT {
                DEF_OP_CMP(float64, F64, <);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_GT {
                DEF_OP_CMP(float64, F64, >);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_LE {
                DEF_OP_CMP(float64, F64, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_GE {
                DEF_OP_CMP(float64, F64, >=);
                HANDLE_OP_END();
            }

            /* numberic instructions of i32 */
            HANDLE_OP WASM_OP_I32_CLZ {
                DEF_OP_BIT_COUNT(uint32, I32, &clz32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_CTZ {
                DEF_OP_BIT_COUNT(uint32, I32, &ctz32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_POPCNT {
                DEF_OP_BIT_COUNT(uint32, I32, &popcount32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_ADD {
                DEF_OP_NUMERIC(uint32, uint32, I32, +);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_SUB {
                DEF_OP_NUMERIC(uint32, uint32, I32, -);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_MUL {
                DEF_OP_NUMERIC(uint32, uint32, I32, *);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_DIV_S {
                int a = void, b = void;

                b = frame_lp[GET_OFFSET()];
                a = frame_lp[GET_OFFSET()];
                addr_ret = GET_OFFSET();
                if (a == cast(int)0x80000000 && b == -1) {
                    wasm_set_exception(module_, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_DIV_U {
                uint a = void, b = void;

                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                b = cast(uint)frame_lp[addr1];
                a = cast(uint)frame_lp[addr2];
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_REM_S {
                int a = void, b = void;

                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                b = frame_lp[addr1];
                a = frame_lp[addr2];
                if (a == cast(int)0x80000000 && b == -1) {
                    frame_lp[addr_ret] = 0;
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_REM_U {
                uint a = void, b = void;

                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                b = cast(uint)frame_lp[addr1];
                a = cast(uint)frame_lp[addr2];
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_AND {
                DEF_OP_NUMERIC(uint32, uint32, I32, &);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_OR {
                DEF_OP_NUMERIC(uint32, uint32, I32, |);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_XOR {
                DEF_OP_NUMERIC(uint32, uint32, I32, ^);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_SHL {
                DEF_OP_NUMERIC2(uint32, uint32, I32, <<);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_SHR_S {
                DEF_OP_NUMERIC2(int32, uint32, I32, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_SHR_U {
                DEF_OP_NUMERIC2(uint32, uint32, I32, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_ROTL {
                uint a = void, b = void;

                b = cast(uint)frame_lp[GET_OFFSET()];
                a = cast(uint)frame_lp[GET_OFFSET()];
                frame_lp[GET_OFFSET()] = rotl32(a, b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_ROTR {
                uint a = void, b = void;

                b = cast(uint)frame_lp[GET_OFFSET()];
                a = cast(uint)frame_lp[GET_OFFSET()];
                frame_lp[GET_OFFSET()] = rotr32(a, b);
                HANDLE_OP_END();
            }

            /* numberic instructions of i64 */
            HANDLE_OP WASM_OP_I64_CLZ {
                DEF_OP_BIT_COUNT(uint64, I64, &clz64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_CTZ {
                DEF_OP_BIT_COUNT(uint64, I64, &ctz64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_POPCNT {
                DEF_OP_BIT_COUNT(uint64, I64, &popcount64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_ADD {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, +);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_SUB {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, -);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_MUL {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, *);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_DIV_S {
                long a = void, b = void;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (a == cast(long)0x8000000000000000LL && b == -1) {
                    wasm_set_exception(module_, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_DIV_U {
                ulong a = void, b = void;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_REM_S {
                long a = void, b = void;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (a == cast(long)0x8000000000000000LL && b == -1) {
                    *cast(long*)(frame_lp + GET_OFFSET()) = 0;
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_REM_U {
                ulong a = void, b = void;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_AND {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, &);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_OR {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, |);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_XOR {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, ^);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_SHL {
                DEF_OP_NUMERIC2_64(uint64, uint64, I64, <<);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_SHR_S {
                DEF_OP_NUMERIC2_64(int64, uint64, I64, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_SHR_U {
                DEF_OP_NUMERIC2_64(uint64, uint64, I64, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_ROTL {
                ulong a = void, b = void;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), rotl64(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_ROTR {
                ulong a = void, b = void;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), rotr64(a, b));
                HANDLE_OP_END();
            }

            /* numberic instructions of f32 */
            HANDLE_OP WASM_OP_F32_ABS {
                DEF_OP_MATH(float32, F32, fabsf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_NEG {
                uint u32 = frame_lp[GET_OFFSET()];
                uint sign_bit = u32 & (cast(uint)1 << 31);
                addr_ret = GET_OFFSET();
                if (sign_bit)
                    frame_lp[addr_ret] = u32 & ~(cast(uint)1 << 31);
                else
                    frame_lp[addr_ret] = u32 | (cast(uint)1 << 31);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_CEIL {
                DEF_OP_MATH(float32, F32, ceilf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_FLOOR {
                DEF_OP_MATH(float32, F32, floorf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_TRUNC {
                DEF_OP_MATH(float32, F32, truncf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_NEAREST {
                DEF_OP_MATH(float32, F32, rintf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_SQRT {
                DEF_OP_MATH(float32, F32, sqrtf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_ADD {
                DEF_OP_NUMERIC(float32, float32, F32, +);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_SUB {
                DEF_OP_NUMERIC(float32, float32, F32, -);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_MUL {
                DEF_OP_NUMERIC(float32, float32, F32, *);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_DIV {
                DEF_OP_NUMERIC(float32, float32, F32, /);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_MIN {
                float32 a = void, b = void;

                b = *cast(float32*)(frame_lp + GET_OFFSET());
                a = *cast(float32*)(frame_lp + GET_OFFSET());

                *cast(float32*)(frame_lp + GET_OFFSET()) = f32_min(a, b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_MAX {
                float32 a = void, b = void;

                b = *cast(float32*)(frame_lp + GET_OFFSET());
                a = *cast(float32*)(frame_lp + GET_OFFSET());

                *cast(float32*)(frame_lp + GET_OFFSET()) = f32_max(a, b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_COPYSIGN {
                float32 a = void, b = void;

                b = *cast(float32*)(frame_lp + GET_OFFSET());
                a = *cast(float32*)(frame_lp + GET_OFFSET());
                *cast(float32*)(frame_lp + GET_OFFSET()) = local_copysignf(a, b);
                HANDLE_OP_END();
            }

            /* numberic instructions of f64 */
            HANDLE_OP WASM_OP_F64_ABS {
                DEF_OP_MATH(float64, F64, fabs);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_NEG {
                ulong u64 = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                ulong sign_bit = u64 & ((cast(ulong)1) << 63);
                if (sign_bit)
                    PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(),
                                    (u64 & ~((cast(ulong)1) << 63)));
                else
                    PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(),
                                    (u64 | ((cast(ulong)1) << 63)));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_CEIL {
                DEF_OP_MATH(float64, F64, ceil);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_FLOOR {
                DEF_OP_MATH(float64, F64, floor);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_TRUNC {
                DEF_OP_MATH(float64, F64, trunc);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_NEAREST {
                DEF_OP_MATH(float64, F64, rint);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_SQRT {
                DEF_OP_MATH(float64, F64, sqrt);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_ADD {
                DEF_OP_NUMERIC_64(float64, float64, F64, +);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_SUB {
                DEF_OP_NUMERIC_64(float64, float64, F64, -);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_MUL {
                DEF_OP_NUMERIC_64(float64, float64, F64, *);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_DIV {
                DEF_OP_NUMERIC_64(float64, float64, F64, /);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_MIN {
                float64 a = void, b = void;

                b = POP_F64();
                a = POP_F64();

                PUSH_F64(f64_min(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_MAX {
                float64 a = void, b = void;

                b = POP_F64();
                a = POP_F64();

                PUSH_F64(f64_max(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_COPYSIGN {
                float64 a = void, b = void;

                b = POP_F64();
                a = POP_F64();
                PUSH_F64(local_copysign(a, b));
                HANDLE_OP_END();
            }

            /* conversions of i32 */
            HANDLE_OP WASM_OP_I32_WRAP_I64 {
                int value = (int32)(POP_I64() & 0xFFFFFFFFLL);
                PUSH_I32(value);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_TRUNC_S_F32 {
                /* We don't use INT32_MIN/INT32_MAX/UINT32_MIN/UINT32_MAX,
                   since float/double values of ieee754 cannot precisely
                   represent all int32/uint32/int64/uint64 values, e.g.:
                   UINT32_MAX is 4294967295, but (float32)4294967295 is
                   4294967296.0f, but not 4294967295.0f. */
                DEF_OP_TRUNC_F32(-2147483904.0f, 2147483648.0f, true, true);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_TRUNC_U_F32 {
                DEF_OP_TRUNC_F32(-1.0f, 4294967296.0f, true, false);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_TRUNC_S_F64 {
                DEF_OP_TRUNC_F64(-2147483649.0, 2147483648.0, true, true);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_TRUNC_U_F64 {
                DEF_OP_TRUNC_F64(-1.0, 4294967296.0, true, false);
                HANDLE_OP_END();
            }

            /* conversions of i64 */
            HANDLE_OP WASM_OP_I64_EXTEND_S_I32 {
                DEF_OP_CONVERT(int64, I64, int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_EXTEND_U_I32 {
                DEF_OP_CONVERT(int64, I64, uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_TRUNC_S_F32 {
                DEF_OP_TRUNC_F32(-9223373136366403584.0f,
                                 9223372036854775808.0f, false, true);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_TRUNC_U_F32 {
                DEF_OP_TRUNC_F32(-1.0f, 18446744073709551616.0f, false, false);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_TRUNC_S_F64 {
                DEF_OP_TRUNC_F64(-9223372036854777856.0, 9223372036854775808.0,
                                 false, true);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_TRUNC_U_F64 {
                DEF_OP_TRUNC_F64(-1.0, 18446744073709551616.0, false, false);
                HANDLE_OP_END();
            }

            /* conversions of f32 */
            HANDLE_OP WASM_OP_F32_CONVERT_S_I32 {
                DEF_OP_CONVERT(float32, F32, int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_CONVERT_U_I32 {
                DEF_OP_CONVERT(float32, F32, uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_CONVERT_S_I64 {
                DEF_OP_CONVERT(float32, F32, int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_CONVERT_U_I64 {
                DEF_OP_CONVERT(float32, F32, uint64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_DEMOTE_F64 {
                DEF_OP_CONVERT(float32, F32, float64, F64);
                HANDLE_OP_END();
            }

            /* conversions of f64 */
            HANDLE_OP WASM_OP_F64_CONVERT_S_I32 {
                DEF_OP_CONVERT(float64, F64, int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_CONVERT_U_I32 {
                DEF_OP_CONVERT(float64, F64, uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_CONVERT_S_I64 {
                DEF_OP_CONVERT(float64, F64, int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_CONVERT_U_I64 {
                DEF_OP_CONVERT(float64, F64, uint64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_PROMOTE_F32 {
                DEF_OP_CONVERT(float64, F64, float32, F32);
                HANDLE_OP_END();
            }

            /* reinterpretations */
             HANDLE_OP(WASM_OP_F32_REINTERPRET_I32) {
                DEF_OP_REINTERPRET(uint32, I32);
                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_F64_REINTERPRET_I64) {
                DEF_OP_REINTERPRET(int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_COPY_STACK_TOP {
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                frame_lp[addr2] = frame_lp[addr1];
                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_COPY_STACK_TOP_I64 {
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                frame_lp[addr2] = frame_lp[addr1];
                frame_lp[addr2 + 1] = frame_lp[addr1 + 1];
                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_COPY_STACK_VALUES {
                uint values_count = void, total_cell = void;
                ubyte* cells = void;
                short* src_offsets = null;
                ushort* dst_offsets = null;

                /* read values_count */
                values_count = read_uint32(frame_ip);
                /* read total cell num */
                total_cell = read_uint32(frame_ip);
                /* cells */
                cells = cast(ubyte*)frame_ip;
                frame_ip += values_count * CELL_SIZE;
                /* src offsets */
                src_offsets = cast(short*)frame_ip;
                frame_ip += values_count * int16.sizeof;
                /* dst offsets */
                dst_offsets = cast(ushort*)frame_ip;
                frame_ip += values_count * uint16.sizeof;

                if (!copy_stack_values(module_, frame_lp, values_count,
                                       total_cell, cells, src_offsets,
                                       dst_offsets))
                    goto got_exception;

                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_TEE_LOCAL) {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
                addr1 = GET_OFFSET();

                if (local_type == VALUE_TYPE_I32
                    || local_type == VALUE_TYPE_F32) {
                    *cast(int*)(frame_lp + local_offset) = frame_lp[addr1];
                }
                else if (local_type == VALUE_TYPE_I64
                         || local_type == VALUE_TYPE_F64) {
                    PUT_I64_TO_ADDR(cast(uint*)(frame_lp + local_offset),
                                    GET_I64_FROM_ADDR(frame_lp + addr1));
                }
                else {
                    wasm_set_exception(module_, "invalid local type");
                    goto got_exception;
                }

                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_EXTEND8_S {
                DEF_OP_CONVERT(int32, I32, int8, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_EXTEND16_S {
                DEF_OP_CONVERT(int32, I32, int16, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_EXTEND8_S {
                DEF_OP_CONVERT(int64, I64, int8, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_EXTEND16_S {
                DEF_OP_CONVERT(int64, I64, int16, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_EXTEND32_S {
                DEF_OP_CONVERT(int64, I64, int32, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_MISC_PREFIX {
                GET_OPCODE();
                switch (opcode) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                        DEF_OP_TRUNC_SAT_F32(-2147483904.0f, 2147483648.0f,
                                             true, true);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                        DEF_OP_TRUNC_SAT_F32(-1.0f, 4294967296.0f, true, false);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                        DEF_OP_TRUNC_SAT_F64(-2147483649.0, 2147483648.0, true,
                                             true);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0, 4294967296.0, true, false);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                        DEF_OP_TRUNC_SAT_F32(-9223373136366403584.0f,
                                             9223372036854775808.0f, false,
                                             true);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        DEF_OP_TRUNC_SAT_F32(-1.0f, 18446744073709551616.0f,
                                             false, false);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                        DEF_OP_TRUNC_SAT_F64(-9223372036854777856.0,
                                             9223372036854775808.0, false,
                                             true);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0, 18446744073709551616.0,
                                             false, false);
                        break;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
                    case WASM_OP_MEMORY_INIT:
                    {
                        uint addr = void, segment = void;
                        ulong bytes = void, offset = void, seg_len = void;
                        ubyte* data = void;

                        segment = read_uint32(frame_ip);

                        bytes = cast(ulong)POP_I32();
                        offset = cast(ulong)POP_I32();
                        addr = POP_I32();

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
                        CHECK_BULK_MEMORY_OVERFLOW(addr, bytes, maddr);
} version (OS_ENABLE_HW_BOUND_CHECK) {
                        if (cast(ulong)cast(uint)addr + bytes
                            > cast(ulong)linear_mem_size)
                            goto out_of_bounds;
                        maddr = memory.memory_data + cast(uint)addr;
}

                        seg_len = cast(ulong)module_.module_.data_segments[segment]
                                      .data_length;
                        data = module_.module_.data_segments[segment].data;
                        if (offset + bytes > seg_len)
                            goto out_of_bounds;

                        bh_memcpy_s(maddr, linear_mem_size - addr,
                                    data + offset, cast(uint)bytes);
                        break;
                    }
                    case WASM_OP_DATA_DROP:
                    {
                        uint segment = void;

                        segment = read_uint32(frame_ip);

                        module_.module_.data_segments[segment].data_length = 0;
                        break;
                    }
                    case WASM_OP_MEMORY_COPY:
                    {
                        uint dst = void, src = void, len = void;
                        ubyte* mdst = void, msrc = void;

                        len = POP_I32();
                        src = POP_I32();
                        dst = POP_I32();

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
                        CHECK_BULK_MEMORY_OVERFLOW(src, len, msrc);
                        CHECK_BULK_MEMORY_OVERFLOW(dst, len, mdst);
} version (OS_ENABLE_HW_BOUND_CHECK) {
                        if (cast(ulong)cast(uint)src + len > cast(ulong)linear_mem_size)
                            goto out_of_bounds;
                        msrc = memory.memory_data + cast(uint)src;

                        if (cast(ulong)cast(uint)dst + len > cast(ulong)linear_mem_size)
                            goto out_of_bounds;
                        mdst = memory.memory_data + cast(uint)dst;
}

                        /* allowing the destination and source to overlap */
                        bh_memmove_s(mdst, linear_mem_size - dst, msrc, len);
                        break;
                    }
                    case WASM_OP_MEMORY_FILL:
                    {
                        uint dst = void, len = void;
                        ubyte fill_val = void; ubyte* mdst = void;

                        len = POP_I32();
                        fill_val = POP_I32();
                        dst = POP_I32();

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
                        CHECK_BULK_MEMORY_OVERFLOW(dst, len, mdst);
} version (OS_ENABLE_HW_BOUND_CHECK) {
                        if (cast(ulong)cast(uint)dst + len > cast(ulong)linear_mem_size)
                            goto out_of_bounds;
                        mdst = memory.memory_data + cast(uint)dst;
}

                        memset(mdst, fill_val, len);
                        break;
                    }
} /* WASM_ENABLE_BULK_MEMORY */
static if (WASM_ENABLE_REF_TYPES != 0) {
                    case WASM_OP_TABLE_INIT:
                    {
                        uint tbl_idx = void, elem_idx = void;
                        ulong n = void, s = void, d = void;
                        WASMTableInstance* tbl_inst = void;

                        elem_idx = read_uint32(frame_ip);
                        bh_assert(elem_idx < module_.module_.table_seg_count);

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module_.module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        n = cast(uint)POP_I32();
                        s = cast(uint)POP_I32();
                        d = cast(uint)POP_I32();

                        if (!n) {
                            break;
                        }

                        if (n + s > module_.module_.table_segments[elem_idx]
                                        .function_count
                            || d + n > tbl_inst.cur_size) {
                            wasm_set_exception(module_,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        if (module_.module_.table_segments[elem_idx]
                                .is_dropped) {
                            wasm_set_exception(module_,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        if (!wasm_elem_is_passive(
                                module_.module_.table_segments[elem_idx]
                                    .mode)) {
                            wasm_set_exception(module_,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        bh_memcpy_s(
                            cast(ubyte*)tbl_inst
                                + WASMTableInstance.elems.offsetof
                                + d * uint32.sizeof,
                            (uint32)((tbl_inst.cur_size - d) * uint32.sizeof),
                            module_.module_.table_segments[elem_idx]
                                    .func_indexes
                                + s,
                            (uint32)(n * uint32.sizeof));
                        break;
                    }
                    case WASM_OP_ELEM_DROP:
                    {
                        uint elem_idx = read_uint32(frame_ip);
                        bh_assert(elem_idx < module_.module_.table_seg_count);

                        module_.module_.table_segments[elem_idx].is_dropped =
                            true;
                        break;
                    }
                    case WASM_OP_TABLE_COPY:
                    {
                        uint src_tbl_idx = void, dst_tbl_idx = void;
                        ulong n = void, s = void, d = void;
                        WASMTableInstance* src_tbl_inst = void, dst_tbl_inst = void;

                        dst_tbl_idx = read_uint32(frame_ip);
                        bh_assert(dst_tbl_idx < module_.table_count);

                        dst_tbl_inst = wasm_get_table_inst(module_, dst_tbl_idx);

                        src_tbl_idx = read_uint32(frame_ip);
                        bh_assert(src_tbl_idx < module_.table_count);

                        src_tbl_inst = wasm_get_table_inst(module_, src_tbl_idx);

                        n = cast(uint)POP_I32();
                        s = cast(uint)POP_I32();
                        d = cast(uint)POP_I32();

                        if (d + n > dst_tbl_inst.cur_size
                            || s + n > src_tbl_inst.cur_size) {
                            wasm_set_exception(module_,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        /* if s >= d, copy from front to back */
                        /* if s < d, copy from back to front */
                        /* merge all together */
                        bh_memmove_s(cast(ubyte*)dst_tbl_inst
                                         + WASMTableInstance.elems.offsetof
                                         + d * uint32.sizeof,
                                     (uint32)((dst_tbl_inst.cur_size - d)
                                              * uint32.sizeof),
                                     cast(ubyte*)src_tbl_inst
                                         + WASMTableInstance.elems.offsetof
                                         + s * uint32.sizeof,
                                     (uint32)(n * uint32.sizeof));
                        break;
                    }
                    case WASM_OP_TABLE_GROW:
                    {
                        uint tbl_idx = void, n = void, init_val = void, orig_tbl_sz = void;
                        WASMTableInstance* tbl_inst = void;

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        orig_tbl_sz = tbl_inst.cur_size;

                        n = POP_I32();
                        init_val = POP_I32();

                        if (!wasm_enlarge_table(module_, tbl_idx, n, init_val)) {
                            PUSH_I32(-1);
                        }
                        else {
                            PUSH_I32(orig_tbl_sz);
                        }

                        break;
                    }
                    case WASM_OP_TABLE_SIZE:
                    {
                        uint tbl_idx = void;
                        WASMTableInstance* tbl_inst = void;

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        PUSH_I32(tbl_inst.cur_size);
                        break;
                    }
                    case WASM_OP_TABLE_FILL:
                    {
                        uint tbl_idx = void, n = void, fill_val = void, i = void;
                        WASMTableInstance* tbl_inst = void;

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        n = POP_I32();
                        fill_val = POP_I32();
                        i = POP_I32();

                        if (i + n > tbl_inst.cur_size) {
                            wasm_set_exception(module_,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        for (; n != 0; i++, n--) {
                            tbl_inst.elems[i] = fill_val;
                        }

                        break;
                    }
} /* WASM_ENABLE_REF_TYPES */
                    default:
                        wasm_set_exception(module_, "unsupported opcode");
                        goto got_exception;
                }
                HANDLE_OP_END();
            }

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
            HANDLE_OP WASM_OP_ATOMIC_PREFIX {
                uint offset = 0, addr = void;

                GET_OPCODE();

                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    offset = read_uint32(frame_ip);
                }

                switch (opcode) {
                    case WASM_OP_ATOMIC_NOTIFY:
                    {
                        uint notify_count = void, ret = void;

                        notify_count = POP_I32();
                        addr = POP_I32();
                        CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                        CHECK_ATOMIC_MEMORY_ACCESS(4);

                        ret = wasm_runtime_atomic_notify(
                            cast(WASMModuleInstanceCommon*)module_, maddr,
                            notify_count);
                        bh_assert(cast(int)ret >= 0);

                        PUSH_I32(ret);
                        break;
                    }
                    case WASM_OP_ATOMIC_WAIT32:
                    {
                        ulong timeout = void;
                        uint expect = void, ret = void;

                        timeout = POP_I64();
                        expect = POP_I32();
                        addr = POP_I32();
                        CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                        CHECK_ATOMIC_MEMORY_ACCESS(4);

                        ret = wasm_runtime_atomic_wait(
                            cast(WASMModuleInstanceCommon*)module_, maddr,
                            cast(ulong)expect, timeout, false);
                        if (ret == (uint32)-1)
                            goto got_exception;

                        PUSH_I32(ret);
                        break;
                    }
                    case WASM_OP_ATOMIC_WAIT64:
                    {
                        ulong timeout = void, expect = void;
                        uint ret = void;

                        timeout = POP_I64();
                        expect = POP_I64();
                        addr = POP_I32();
                        CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                        CHECK_ATOMIC_MEMORY_ACCESS(8);

                        ret = wasm_runtime_atomic_wait(
                            cast(WASMModuleInstanceCommon*)module_, maddr, expect,
                            timeout, true);
                        if (ret == (uint32)-1)
                            goto got_exception;

                        PUSH_I32(ret);
                        break;
                    }

                    case WASM_OP_ATOMIC_I32_LOAD:
                    case WASM_OP_ATOMIC_I32_LOAD8_U:
                    case WASM_OP_ATOMIC_I32_LOAD16_U:
                    {
                        uint readv = void;

                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I32_LOAD8_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint32)(*cast(ubyte*)maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_LOAD16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(uint)LOAD_U16(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = LOAD_I32(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }

                        PUSH_I32(readv);
                        break;
                    }

                    case WASM_OP_ATOMIC_I64_LOAD:
                    case WASM_OP_ATOMIC_I64_LOAD8_U:
                    case WASM_OP_ATOMIC_I64_LOAD16_U:
                    case WASM_OP_ATOMIC_I64_LOAD32_U:
                    {
                        ulong readv = void;

                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I64_LOAD8_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint64)(*cast(ubyte*)maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U16(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD32_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U32(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(8);
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = LOAD_I64(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }

                        PUSH_I64(readv);
                        break;
                    }
                    case WASM_OP_ATOMIC_I32_STORE:
                    case WASM_OP_ATOMIC_I32_STORE8:
                    case WASM_OP_ATOMIC_I32_STORE16:
                    {
                        uint sval = void;

                        sval = cast(uint)POP_I32();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I32_STORE8) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            os_mutex_lock(&module_.e.mem_lock);
                            *cast(ubyte*)maddr = cast(ubyte)sval;
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_STORE16) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U16(maddr, cast(ushort)sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U32(maddr, sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        break;
                    }

                    case WASM_OP_ATOMIC_I64_STORE:
                    case WASM_OP_ATOMIC_I64_STORE8:
                    case WASM_OP_ATOMIC_I64_STORE16:
                    case WASM_OP_ATOMIC_I64_STORE32:
                    {
                        ulong sval = void;

                        sval = cast(ulong)POP_I64();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I64_STORE8) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            os_mutex_lock(&module_.e.mem_lock);
                            *cast(ubyte*)maddr = cast(ubyte)sval;
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE16) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U16(maddr, cast(ushort)sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE32) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U32(maddr, cast(uint)sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(8);
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_I64(maddr, sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        break;
                    }

                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U:
                    {
                        uint readv = void, sval = void, expect = void;

                        sval = POP_I32();
                        expect = POP_I32();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);

                            expect = cast(ubyte)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint32)(*cast(ubyte*)maddr);
                            if (readv == expect)
                                *cast(ubyte*)maddr = (uint8)(sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);

                            expect = cast(ushort)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(uint)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);

                            os_mutex_lock(&module_.e.mem_lock);
                            readv = LOAD_I32(maddr);
                            if (readv == expect)
                                STORE_U32(maddr, sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        PUSH_I32(readv);
                        break;
                    }
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U:
                    {
                        ulong readv = void, sval = void, expect = void;

                        sval = cast(ulong)POP_I64();
                        expect = cast(ulong)POP_I64();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 1, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);

                            expect = cast(ubyte)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint64)(*cast(ubyte*)maddr);
                            if (readv == expect)
                                *cast(ubyte*)maddr = (uint8)(sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);

                            expect = cast(ushort)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);

                            expect = cast(uint)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U32(maddr);
                            if (readv == expect)
                                STORE_U32(maddr, (uint32)(sval));
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS(8);

                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_I64(maddr);
                            if (readv == expect) {
                                STORE_I64(maddr, sval);
                            }
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        PUSH_I64(readv);
                        break;
                    }

                        DEF_ATOMIC_RMW_OPCODE(ADD, +);
                        DEF_ATOMIC_RMW_OPCODE(SUB, -);
                        DEF_ATOMIC_RMW_OPCODE(AND, &);
                        DEF_ATOMIC_RMW_OPCODE(OR, |);
                        DEF_ATOMIC_RMW_OPCODE(XOR, ^);
                        /* xchg, ignore the read value, and store the given
                          value: readv * 0 + sval */
                        DEF_ATOMIC_RMW_OPCODE(XCHG, *0 +);
                default: break;}

                HANDLE_OP_END();
            }
}

            HANDLE_OP WASM_OP_IMPDEP {
                frame = prev_frame;
                frame_ip = frame.ip;
                goto call_func_from_entry;
            }

            HANDLE_OP WASM_OP_CALL {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                fidx = read_uint32(frame_ip);
static if (WASM_ENABLE_MULTI_MODULE != 0) {
                if (fidx >= module_.e.function_count) {
                    wasm_set_exception(module_, "unknown function");
                    goto got_exception;
                }
}
                cur_func = module_.e.functions + fidx;
                goto call_func_from_interp;
            }

static if (WASM_ENABLE_TAIL_CALL != 0) {
            HANDLE_OP WASM_OP_RETURN_CALL {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                fidx = read_uint32(frame_ip);
static if (WASM_ENABLE_MULTI_MODULE != 0) {
                if (fidx >= module_.e.function_count) {
                    wasm_set_exception(module_, "unknown function");
                    goto got_exception;
                }
}
                cur_func = module_.e.functions + fidx;
                goto call_func_from_return_call;
            }
} /* WASM_ENABLE_TAIL_CALL */

static if (WASM_ENABLE_LABELS_AS_VALUES == 0) {
            default:
                wasm_set_exception(module_, "unsupported opcode");
                goto got_exception;
        }
}

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
         HANDLE_OP(WASM_OP_UNUSED_0x07);
         HANDLE_OP(WASM_OP_UNUSED_0x09);
        HANDLE_OP(WASM_OP_UNUSED_0x0a)
static if (WASM_ENABLE_TAIL_CALL == 0) {
         HANDLE_OP(WASM_OP_RETURN_CALL_INDIRECT);
}
static if (WASM_ENABLE_SHARED_MEMORY == 0) {
        HANDLE_OP(WASM_OP_ATOMIC_PREFIX)
}
static if (WASM_ENABLE_REF_TYPES == 0) {
         HANDLE_OP(WASM_OP_TABLE_SET);
         HANDLE_OP(WASM_OP_REF_IS_NULL);
        HANDLE_OP(WASM_OP_REF_FUNC)
}
        /* SELECT_T is converted to SELECT or SELECT_64 */
         HANDLE_OP(WASM_OP_UNUSED_0x14);
         HANDLE_OP(WASM_OP_UNUSED_0x16);
         HANDLE_OP(WASM_OP_UNUSED_0x18);
         HANDLE_OP(WASM_OP_UNUSED_0x27);
         HANDLE_OP(WASM_OP_F64_STORE);
         HANDLE_OP(WASM_OP_F64_LOAD);
         HANDLE_OP(WASM_OP_GET_LOCAL);
         HANDLE_OP(WASM_OP_DROP_64);
         HANDLE_OP(WASM_OP_LOOP);
         HANDLE_OP(WASM_OP_NOP);
         HANDLE_OP(EXT_OP_LOOP);
         HANDLE_OP(EXT_OP_BR_TABLE_CACHE) {
            wasm_set_exception(module_, "unsupported opcode");
            goto got_exception;
        }
}

static if (WASM_ENABLE_LABELS_AS_VALUES == 0) {
        continue;
} else {
    FETCH_OPCODE_AND_DISPATCH();
}

static if (WASM_ENABLE_TAIL_CALL != 0) {
    call_func_from_return_call:
    {
        uint* lp_base;
        uint* lp;
        int i;

        if (((lp_base = lp = wasm_runtime_malloc(cur_func.param_cell_num
                                                 * uint32.sizeof)) == 0)) {
            wasm_set_exception(module_, "allocate memory failed");
            goto got_exception;
        }
        for (i = 0; i < cur_func.param_count; i++) {
            if (cur_func.param_types[i] == VALUE_TYPE_I64
                || cur_func.param_types[i] == VALUE_TYPE_F64) {
                PUT_I64_TO_ADDR(
                    lp, GET_OPERAND(uint64, I64,
                                    2 * (cur_func.param_count - i - 1)));
                lp += 2;
            }
            else {
                *lp = GET_OPERAND(uint32, I32,
                                  (2 * (cur_func.param_count - i - 1)));
                lp++;
            }
        }
        frame.lp = frame.operand + cur_func.const_cell_num;
        if (lp - lp_base > 0) {
            word_copy(frame.lp, lp_base, lp - lp_base);
        }
        wasm_runtime_free(lp_base);
        FREE_FRAME(exec_env, frame);
        frame_ip += cur_func.param_count * int16.sizeof;
        wasm_exec_env_set_cur_frame(exec_env, cast(WASMRuntimeFrame*)prev_frame);
        goto call_func_from_entry;
    }
} /* WASM_ENABLE_TAIL_CALL */

    call_func_from_interp:
    {
        /* Only do the copy when it's called from interpreter. */
        WASMInterpFrame* outs_area = wasm_exec_env_wasm_stack_top(exec_env);
        int i;

static if (WASM_ENABLE_MULTI_MODULE != 0) {
        if (cur_func.is_import_func) {
            outs_area.lp = outs_area.operand
                            + (cur_func.import_func_inst
                                   ? cur_func.import_func_inst.const_cell_num
                                   : 0);
        }
        else
}
        {
            outs_area.lp = outs_area.operand + cur_func.const_cell_num;
        }

        if (cast(ubyte*)(outs_area.lp + cur_func.param_cell_num)
            > exec_env.wasm_stack.s.top_boundary) {
            wasm_set_exception(module_, "wasm operand stack overflow");
            goto got_exception;
        }

        for (i = 0; i < cur_func.param_count; i++) {
            if (cur_func.param_types[i] == VALUE_TYPE_I64
                || cur_func.param_types[i] == VALUE_TYPE_F64) {
                PUT_I64_TO_ADDR(
                    outs_area.lp,
                    GET_OPERAND(uint64, I64,
                                2 * (cur_func.param_count - i - 1)));
                outs_area.lp += 2;
            }
            else {
                *outs_area.lp = GET_OPERAND(
                    uint32, I32, (2 * (cur_func.param_count - i - 1)));
                outs_area.lp++;
            }
        }
        frame_ip += cur_func.param_count * int16.sizeof;
        if (cur_func.ret_cell_num != 0) {
            /* Get the first return value's offset. Since loader emit
             * all return values' offset so we must skip remain return
             * values' offsets.
             */
            WASMType* func_type;
            if (cur_func.is_import_func)
                func_type = cur_func.u.func_import.func_type;
            else
                func_type = cur_func.u.func.func_type;
            frame.ret_offset = GET_OFFSET();
            frame_ip += 2 * (func_type.result_count - 1);
        }
        SYNC_ALL_TO_FRAME();
        prev_frame = frame;
    }

    call_func_from_entry:
    {
        if (cur_func.is_import_func) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
            if (cur_func.import_func_inst) {
                wasm_interp_call_func_import(module_, exec_env, cur_func,
                                             prev_frame);
            }
            else
}
            {
                wasm_interp_call_func_native(module_, exec_env, cur_func,
                                             prev_frame);
            }

            prev_frame = frame.prev_frame;
            cur_func = frame.function_;
            UPDATE_ALL_FROM_FRAME();

            /* update memory size, no need to update memory ptr as
               it isn't changed in wasm_enlarge_memory */
static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK"              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0) {
            if (memory)
                linear_mem_size = num_bytes_per_page * memory.cur_page_count;
}
            if (wasm_get_exception(module_))
                goto got_exception;
        }
        else {
            WASMFunction* cur_wasm_func = cur_func.u.func;

            all_cell_num = cur_func.param_cell_num + cur_func.local_cell_num
                           + cur_func.const_cell_num
                           + cur_wasm_func.max_stack_cell_num;
            /* param_cell_num, local_cell_num, const_cell_num and
               max_stack_cell_num are all no larger than UINT16_MAX (checked
               in loader), all_cell_num must be smaller than 1MB */
            bh_assert(all_cell_num < 1 * BH_MB);

            frame_size = wasm_interp_interp_frame_size(all_cell_num);
            if (((frame = ALLOC_FRAME(exec_env, frame_size, prev_frame)) == 0)) {
                frame = prev_frame;
                goto got_exception;
            }

            /* Initialize the interpreter context. */
            frame.function_ = cur_func;
            frame_ip = wasm_get_func_code(cur_func);
            frame_ip_end = wasm_get_func_code_end(cur_func);

            frame_lp = frame.lp =
                frame.operand + cur_wasm_func.const_cell_num;

            /* Initialize the consts */
            if (cur_wasm_func.const_cell_num > 0) {
                word_copy(frame.operand, cast(uint*)cur_wasm_func.consts,
                          cur_wasm_func.const_cell_num);
            }

            /* Initialize the local variables */
            memset(frame_lp + cur_func.param_cell_num, 0,
                   (uint32)(cur_func.local_cell_num * 4));

            wasm_exec_env_set_cur_frame(exec_env, cast(WASMRuntimeFrame*)frame);
        }
        HANDLE_OP_END();
    }

    return_func:
    {
        FREE_FRAME(exec_env, frame);
        wasm_exec_env_set_cur_frame(exec_env, cast(WASMRuntimeFrame*)prev_frame);

        if (!prev_frame.ip)
            /* Called from native. */
            return;

        RECOVER_CONTEXT(prev_frame);
        HANDLE_OP_END();
    }

        cast(void)frame_ip_end;

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
    unaligned_atomic:
        wasm_set_exception(module_, "unaligned atomic");
        goto got_exception;
}

static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK"              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0) {
    out_of_bounds:
        wasm_set_exception(module_, "out of bounds memory access");
}

    got_exception:
        SYNC_ALL_TO_FRAME();
        return;

static if (WASM_ENABLE_LABELS_AS_VALUES == 0) {
    }
} else {
    FETCH_OPCODE_AND_DISPATCH();
}
}

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
void** wasm_interp_get_handle_table() {
    WASMModuleInstance module_ = void;
    memset(&module_, 0, WASMModuleInstance.sizeof);
    wasm_interp_call_func_bytecode(&module_, null, null, null);
    return global_handle_table;
}
}

void wasm_interp_call_wasm(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv) {
    WASMRuntimeFrame* prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    WASMInterpFrame* frame = void, outs_area = void;

    /* Allocate sufficient cells for all kinds of return values.  */
    uint all_cell_num = function_.ret_cell_num > 2 ? function_.ret_cell_num : 2, i = void;
    /* This frame won't be used by JITed code, so only allocate interp
       frame here.  */
    uint frame_size = wasm_interp_interp_frame_size(all_cell_num);

    if (argc < function_.param_cell_num) {
        char[128] buf = void;
        snprintf(buf.ptr, buf.sizeof,
                 "invalid argument count %" PRIu32
                 ~ ", must be no smaller than %" PRIu32,
                 argc, cast(uint)function_.param_cell_num);
        wasm_set_exception(module_inst, buf.ptr);
        return;
    }
    argc = function_.param_cell_num;

static if (!(HasVersion!"OS_ENABLE_HW_BOUND_CHECK" \
      && WASM_DISABLE_STACK_HW_BOUND_CHECK == 0)) {
    if (cast(ubyte*)&prev_frame < exec_env.native_stack_boundary) {
        wasm_set_exception(cast(WASMModuleInstance*)exec_env.module_inst,
                           "native stack overflow");
        return;
    }
}

    if (((frame =
              ALLOC_FRAME(exec_env, frame_size, cast(WASMInterpFrame*)prev_frame)) == 0))
        return;

    outs_area = wasm_exec_env_wasm_stack_top(exec_env);
    frame.function_ = null;
    frame.ip = null;
    /* There is no local variable. */
    frame.lp = frame.operand + 0;
    frame.ret_offset = 0;

    if (cast(ubyte*)(outs_area.operand + function_.const_cell_num + argc)
        > exec_env.wasm_stack.s.top_boundary) {
        wasm_set_exception(cast(WASMModuleInstance*)exec_env.module_inst,
                           "wasm operand stack overflow");
        return;
    }

    if (argc > 0)
        word_copy(outs_area.operand + function_.const_cell_num, argv, argc);

    wasm_exec_env_set_cur_frame(exec_env, frame);

    if (function_.is_import_func) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        if (function_.import_module_inst) {
            LOG_DEBUG("it is a function of a sub module");
            wasm_interp_call_func_import(module_inst, exec_env, function_,
                                         frame);
        }
        else
}
        {
            LOG_DEBUG("it is an native function");
            wasm_interp_call_func_native(module_inst, exec_env, function_,
                                         frame);
        }
    }
    else {
        wasm_interp_call_func_bytecode(module_inst, exec_env, function_, frame);
    }

    /* Output the return value to the caller */
    if (!wasm_get_exception(module_inst)) {
        for (i = 0; i < function_.ret_cell_num; i++)
            argv[i] = *(frame.lp + i);
    }
    else {
static if (WASM_ENABLE_DUMP_CALL_STACK != 0) {
        if (wasm_interp_create_call_stack(exec_env)) {
            wasm_interp_dump_call_stack(exec_env, true, null, 0);
        }
}
        LOG_DEBUG("meet an exception %s", wasm_get_exception(module_inst));
    }

    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
    FREE_FRAME(exec_env, frame);
static if (WASM_ENABLE_OPCODE_COUNTER != 0) {
    wasm_interp_dump_op_count();
}
}
