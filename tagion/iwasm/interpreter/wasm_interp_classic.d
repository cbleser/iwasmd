module wasm_interp_classic;
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
static if (WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0) {
public import ...libraries.thread-mgr.thread_manager;
public import ...libraries.debug-engine.debug_engine;
}
static if (WASM_ENABLE_FAST_JIT != 0) {
public import ...fast-jit.jit_compiler;
}

alias CellType_I32 = int;
alias CellType_I64 = long;
alias CellType_F32 = float32;
alias CellType_F64 = float64;

enum BR_TABLE_TMP_BUF_LEN = 32;

static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK" \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0) {
enum string CHECK_MEMORY_OVERFLOW(string bytes) = `                            \
    do {                                                        \
        uint64 offset1 = (uint64)offset + (uint64)addr;         \
        if (offset1 + bytes <= (uint64)linear_mem_size)         \
            /* If offset1 is in valid range, maddr must also    \
               be in valid range, no need to check it again. */ \
            maddr = memory->memory_data + offset1;              \
        else                                                    \
            goto out_of_bounds;                                 \
    } while (0)`;

enum string CHECK_BULK_MEMORY_OVERFLOW(string start, string bytes, string maddr) = ` \
    do {                                                \
        uint64 offset1 = (uint32)(start);               \
        if (offset1 + bytes <= (uint64)linear_mem_size) \
            /* App heap space is not valid space for    \
             bulk memory operation */                   \
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

enum string CHECK_ATOMIC_MEMORY_ACCESS() = `                                 \
    do {                                                             \
        if (((uintptr_t)maddr & (((uintptr_t)1 << align) - 1)) != 0) \
            goto unaligned_atomic;                                   \
    } while (0)`;

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
enum string TRIGGER_WATCHPOINT_SIGTRAP() = `                              \
    do {                                                          \
        wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP); \
        CHECK_SUSPEND_FLAGS();                                    \
    } while (0)`;

enum string CHECK_WATCHPOINT(string list, string current_addr) = `                               \
    do {                                                                   \
        WASMDebugWatchPoint *watchpoint = bh_list_first_elem(list);        \
        while (watchpoint) {                                               \
            WASMDebugWatchPoint *next = bh_list_elem_next(watchpoint);     \
            if (watchpoint->addr <= current_addr                           \
                && watchpoint->addr + watchpoint->length > current_addr) { \
                TRIGGER_WATCHPOINT_SIGTRAP();                              \
            }                                                              \
            watchpoint = next;                                             \
        }                                                                  \
    } while (0)`;

enum string CHECK_READ_WATCHPOINT(string addr, string offset) = ` \
    CHECK_WATCHPOINT(watch_point_list_read, WASM_ADDR_OFFSET(addr + offset))`;
enum string CHECK_WRITE_WATCHPOINT(string addr, string offset) = ` \
    CHECK_WATCHPOINT(watch_point_list_write, WASM_ADDR_OFFSET(addr + offset))`;
} else {
enum string CHECK_READ_WATCHPOINT(string addr, string offset) = ` (void)0`;
enum string CHECK_WRITE_WATCHPOINT(string addr, string offset) = ` (void)0`;
}

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

private ulong read_leb(const(ubyte)* buf, uint* p_offset, uint maxbits, bool sign) {
    ulong result = 0, byte_ = void;
    uint offset = *p_offset;
    uint shift = 0;

    while (true) {
        byte_ = buf[offset++];
        result |= ((byte_ & 0x7f) << shift);
        shift += 7;
        if ((byte_ & 0x80) == 0) {
            break;
        }
    }
    if (sign && (shift < maxbits) && (byte_ & 0x40)) {
        /* Sign extend */
        result |= (~(cast(ulong)0)) << shift;
    }
    *p_offset = offset;
    return result;
}

enum string skip_leb(string p) = ` while (*p++ & 0x80)`;

enum string PUSH_I32(string value) = `                        \
    do {                                       \
        *(int32 *)frame_sp++ = (int32)(value); \
    } while (0)`;

enum string PUSH_F32(string value) = `                            \
    do {                                           \
        *(float32 *)frame_sp++ = (float32)(value); \
    } while (0)`;

enum string PUSH_I64(string value) = `                   \
    do {                                  \
        PUT_I64_TO_ADDR(frame_sp, value); \
        frame_sp += 2;                    \
    } while (0)`;

enum string PUSH_F64(string value) = `                   \
    do {                                  \
        PUT_F64_TO_ADDR(frame_sp, value); \
        frame_sp += 2;                    \
    } while (0)`;

enum string PUSH_CSP(string _label_type, string param_cell_num, string cell_num, string _target_addr) = ` \
    do {                                                              \
        bh_assert(frame_csp < frame->csp_boundary);                   \
        /* frame_csp->label_type = _label_type; */                    \
        frame_csp->cell_num = cell_num;                               \
        frame_csp->begin_addr = frame_ip;                             \
        frame_csp->target_addr = _target_addr;                        \
        frame_csp->frame_sp = frame_sp - param_cell_num;              \
        frame_csp++;                                                  \
    } while (0)`;

enum string POP_I32() = ` (--frame_sp, *(int32 *)frame_sp)`;

enum string POP_F32() = ` (--frame_sp, *(float32 *)frame_sp)`;

enum string POP_I64() = ` (frame_sp -= 2, GET_I64_FROM_ADDR(frame_sp))`;

enum string POP_F64() = ` (frame_sp -= 2, GET_F64_FROM_ADDR(frame_sp))`;

enum string POP_CSP_CHECK_OVERFLOW(string n) = `                      \
    do {                                               \
        bh_assert(frame_csp - n >= frame->csp_bottom); \
    } while (0)`;

enum string POP_CSP() = `                  \
    do {                           \
        POP_CSP_CHECK_OVERFLOW(1); \
        --frame_csp;               \
    } while (0)`;

enum string POP_CSP_N(string n) = `                                             \
    do {                                                         \
        uint32 *frame_sp_old = frame_sp;                         \
        uint32 cell_num_to_copy;                                 \
        POP_CSP_CHECK_OVERFLOW(n + 1);                           \
        frame_csp -= n;                                          \
        frame_ip = (frame_csp - 1)->target_addr;                 \
        /* copy arity values of block */                         \
        frame_sp = (frame_csp - 1)->frame_sp;                    \
        cell_num_to_copy = (frame_csp - 1)->cell_num;            \
        if (cell_num_to_copy > 0) {                              \
            word_copy(frame_sp, frame_sp_old - cell_num_to_copy, \
                      cell_num_to_copy);                         \
        }                                                        \
        frame_sp += cell_num_to_copy;                            \
    } while (0)`;

/* Pop the given number of elements from the given frame's stack.  */
enum string POP(string N) = `         \
    do {               \
        int n = (N);   \
        frame_sp -= n; \
    } while (0)`;

enum string SYNC_ALL_TO_FRAME() = `     \
    do {                        \
        frame->sp = frame_sp;   \
        frame->ip = frame_ip;   \
        frame->csp = frame_csp; \
    } while (0)`;

enum string UPDATE_ALL_FROM_FRAME() = ` \
    do {                        \
        frame_sp = frame->sp;   \
        frame_ip = frame->ip;   \
        frame_csp = frame->csp; \
    } while (0)`;

enum string read_leb_int64(string p, string p_end, string res) = `              \
    do {                                           \
        uint8 _val = *p;                           \
        if (!(_val & 0x80)) {                      \
            res = (int64)_val;                     \
            if (_val & 0x40)                       \
                /* sign extend */                  \
                res |= 0xFFFFFFFFFFFFFF80LL;       \
            p++;                                   \
            break;                                 \
        }                                          \
        uint32 _off = 0;                           \
        res = (int64)read_leb(p, &_off, 64, true); \
        p += _off;                                 \
    } while (0)`;

enum string read_leb_uint32(string p, string p_end, string res) = `               \
    do {                                             \
        uint8 _val = *p;                             \
        if (!(_val & 0x80)) {                        \
            res = _val;                              \
            p++;                                     \
            break;                                   \
        }                                            \
        uint32 _off = 0;                             \
        res = (uint32)read_leb(p, &_off, 32, false); \
        p += _off;                                   \
    } while (0)`;

enum string read_leb_int32(string p, string p_end, string res) = `              \
    do {                                           \
        uint8 _val = *p;                           \
        if (!(_val & 0x80)) {                      \
            res = (int32)_val;                     \
            if (_val & 0x40)                       \
                /* sign extend */                  \
                res |= 0xFFFFFF80;                 \
            p++;                                   \
            break;                                 \
        }                                          \
        uint32 _off = 0;                           \
        res = (int32)read_leb(p, &_off, 32, true); \
        p += _off;                                 \
    } while (0)`;

static if (WASM_ENABLE_LABELS_AS_VALUES == 0) {
enum string RECOVER_FRAME_IP_END() = ` frame_ip_end = wasm_get_func_code_end(cur_func)`;
} else {
enum string RECOVER_FRAME_IP_END() = ` (void)0`;
}

enum string RECOVER_CONTEXT(string new_frame) = `      \
    do {                                \
        frame = (new_frame);            \
        cur_func = frame->function;     \
        prev_frame = frame->prev_frame; \
        frame_ip = frame->ip;           \
        RECOVER_FRAME_IP_END();         \
        frame_lp = frame->lp;           \
        frame_sp = frame->sp;           \
        frame_csp = frame->csp;         \
    } while (0)`;

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
enum string GET_OPCODE() = ` opcode = *(frame_ip - 1);`;
} else {
enum string GET_OPCODE() = ` (void)0`;
}

enum string DEF_OP_I_CONST(string ctype, string src_op_type) = `              \
    do {                                                \
        ctype cval;                                     \
        read_leb_##ctype(frame_ip, frame_ip_end, cval); \
        PUSH_##src_op_type(cval);                       \
    } while (0)`;

enum string DEF_OP_EQZ(string src_op_type) = `             \
    do {                                    \
        int32 pop_val;                      \
        pop_val = POP_##src_op_type() == 0; \
        PUSH_I32(pop_val);                  \
    } while (0)`;

enum string DEF_OP_CMP(string src_type, string src_op_type, string cond) = ` \
    do {                                        \
        uint32 res;                             \
        src_type val1, val2;                    \
        val2 = (src_type)POP_##src_op_type();   \
        val1 = (src_type)POP_##src_op_type();   \
        res = val1 cond val2;                   \
        PUSH_I32(res);                          \
    } while (0)`;

enum string DEF_OP_BIT_COUNT(string src_type, string src_op_type, string operation) = ` \
    do {                                                   \
        src_type val1, val2;                               \
        val1 = (src_type)POP_##src_op_type();              \
        val2 = (src_type)operation(val1);                  \
        PUSH_##src_op_type(val2);                          \
    } while (0)`;

enum string DEF_OP_NUMERIC(string src_type1, string src_type2, string src_op_type, string operation) = `  \
    do {                                                              \
        frame_sp -= sizeof(src_type2) / sizeof(uint32);               \
        *(src_type1 *)(frame_sp - sizeof(src_type1) / sizeof(uint32)) \
            operation## = *(src_type2 *)(frame_sp);                   \
    } while (0)`;

static if (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0) {
enum DEF_OP_NUMERIC_64 = DEF_OP_NUMERIC;
} else {
enum string DEF_OP_NUMERIC_64(string src_type1, string src_type2, string src_op_type, string operation) = ` \
    do {                                                                \
        src_type1 val1;                                                 \
        src_type2 val2;                                                 \
        frame_sp -= 2;                                                  \
        val1 = (src_type1)GET_##src_op_type##_FROM_ADDR(frame_sp - 2);  \
        val2 = (src_type2)GET_##src_op_type##_FROM_ADDR(frame_sp);      \
        val1 operation## = val2;                                        \
        PUT_##src_op_type##_TO_ADDR(frame_sp - 2, val1);                \
    } while (0)`;
}

enum string DEF_OP_NUMERIC2(string src_type1, string src_type2, string src_op_type, string operation) = ` \
    do {                                                              \
        frame_sp -= sizeof(src_type2) / sizeof(uint32);               \
        *(src_type1 *)(frame_sp - sizeof(src_type1) / sizeof(uint32)) \
            operation## = (*(src_type2 *)(frame_sp) % 32);            \
    } while (0)`;

enum string DEF_OP_NUMERIC2_64(string src_type1, string src_type2, string src_op_type, string operation) = ` \
    do {                                                                 \
        src_type1 val1;                                                  \
        src_type2 val2;                                                  \
        frame_sp -= 2;                                                   \
        val1 = (src_type1)GET_##src_op_type##_FROM_ADDR(frame_sp - 2);   \
        val2 = (src_type2)GET_##src_op_type##_FROM_ADDR(frame_sp);       \
        val1 operation## = (val2 % 64);                                  \
        PUT_##src_op_type##_TO_ADDR(frame_sp - 2, val1);                 \
    } while (0)`;

enum string DEF_OP_MATH(string src_type, string src_op_type, string method) = ` \
    do {                                           \
        src_type src_val;                          \
        src_val = POP_##src_op_type();             \
        PUSH_##src_op_type(method(src_val));       \
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

private bool trunc_f32_to_int(WASMModuleInstance* module_, uint* frame_sp, float32 src_min, float32 src_max, bool saturating, bool is_i32, bool is_sign) {
    float32 src_value = POP_F32();
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
        PUSH_I32(dst_value_i32);
    }
    else {
        ulong dst_min = is_sign ? INT64_MIN : 0;
        ulong dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f32_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        PUSH_I64(dst_value_i64);
    }
    return true;
}

private bool trunc_f64_to_int(WASMModuleInstance* module_, uint* frame_sp, float64 src_min, float64 src_max, bool saturating, bool is_i32, bool is_sign) {
    float64 src_value = POP_F64();
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
        PUSH_I32(dst_value_i32);
    }
    else {
        ulong dst_min = is_sign ? INT64_MIN : 0;
        ulong dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f64_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        PUSH_I64(dst_value_i64);
    }
    return true;
}

enum string DEF_OP_TRUNC_F32(string min, string max, string is_i32, string is_sign) = `                      \
    do {                                                                 \
        if (!trunc_f32_to_int(module, frame_sp, min, max, false, is_i32, \
                              is_sign))                                  \
            goto got_exception;                                          \
    } while (0)`;

enum string DEF_OP_TRUNC_F64(string min, string max, string is_i32, string is_sign) = `                      \
    do {                                                                 \
        if (!trunc_f64_to_int(module, frame_sp, min, max, false, is_i32, \
                              is_sign))                                  \
            goto got_exception;                                          \
    } while (0)`;

enum string DEF_OP_TRUNC_SAT_F32(string min, string max, string is_i32, string is_sign) = `                  \
    do {                                                                 \
        (void)trunc_f32_to_int(module, frame_sp, min, max, true, is_i32, \
                               is_sign);                                 \
    } while (0)`;

enum string DEF_OP_TRUNC_SAT_F64(string min, string max, string is_i32, string is_sign) = `                  \
    do {                                                                 \
        (void)trunc_f64_to_int(module, frame_sp, min, max, true, is_i32, \
                               is_sign);                                 \
    } while (0)`;

enum string DEF_OP_CONVERT(string dst_type, string dst_op_type, string src_type, string src_op_type) = ` \
    do {                                                             \
        dst_type value = (dst_type)(src_type)POP_##src_op_type();    \
        PUSH_##dst_op_type(value);                                   \
    } while (0)`;

enum string GET_LOCAL_INDEX_TYPE_AND_OFFSET() = `                                \
    do {                                                                 \
        uint32 param_count = cur_func->param_count;                      \
        read_leb_uint32(frame_ip, frame_ip_end, local_idx);              \
        bh_assert(local_idx < param_count + cur_func->local_count);      \
        local_offset = cur_func->local_offsets[local_idx];               \
        if (local_idx < param_count)                                     \
            local_type = cur_func->param_types[local_idx];               \
        else                                                             \
            local_type = cur_func->local_types[local_idx - param_count]; \
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
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint32)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U) { \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint32)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else {                                                       \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
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
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##16_U) { \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##32_U) { \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            os_mutex_lock(&module->e->mem_lock);                     \
            readv = (uint64)LOAD_U32(maddr);                         \
            STORE_U32(maddr, (uint32)(readv op sval));               \
            os_mutex_unlock(&module->e->mem_lock);                   \
        }                                                            \
        else {                                                       \
            uint64 op_result;                                        \
            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);     \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
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
    char[128] buf = void;
    bool ret = void;

    if (((frame = ALLOC_FRAME(exec_env,
                              wasm_interp_interp_frame_size(local_cell_num),
                              prev_frame)) == 0))
        return;

    frame.function_ = cur_func;
    frame.ip = null;
    frame.sp = frame.lp + local_cell_num;

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
        snprintf(buf.ptr, buf.sizeof,
                 "failed to call unlinked import function (%s, %s)",
                 func_import.module_name, func_import.field_name);
        wasm_set_exception(module_inst, buf.ptr);
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
        prev_frame.sp[0] = argv_ret[0];
        prev_frame.sp++;
    }
    else if (cur_func.ret_cell_num == 2) {
        prev_frame.sp[0] = argv_ret[0];
        prev_frame.sp[1] = argv_ret[1];
        prev_frame.sp += 2;
    }

    FREE_FRAME(exec_env, frame);
    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
}

static if (WASM_ENABLE_FAST_JIT != 0) {
bool fast_jit_invoke_native(WASMExecEnv* exec_env, uint func_idx, WASMInterpFrame* prev_frame) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)exec_env.module_inst;
    WASMFunctionInstance* cur_func = module_inst.e.functions + func_idx;

    wasm_interp_call_func_native(module_inst, exec_env, cur_func, prev_frame);
    return wasm_get_exception(module_inst) ? false : true;
}
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
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
enum string CHECK_SUSPEND_FLAGS() = `                                          \
    do {                                                               \
        if (IS_WAMR_TERM_SIG(exec_env->current_status->signal_flag)) { \
            return;                                                    \
        }                                                              \
        if (IS_WAMR_STOP_SIG(exec_env->current_status->signal_flag)) { \
            SYNC_ALL_TO_FRAME();                                       \
            wasm_cluster_thread_stopped(exec_env);                     \
            wasm_cluster_thread_waiting_run(exec_env);                 \
        }                                                              \
    } while (0)`;
} else {
enum string CHECK_SUSPEND_FLAGS() = `                                             \
    do {                                                                  \
        if (exec_env->suspend_flags.flags != 0) {                         \
            if (exec_env->suspend_flags.flags & 0x01) {                   \
                /* terminate current thread */                            \
                return;                                                   \
            }                                                             \
            while (exec_env->suspend_flags.flags & 0x02) {                \
                /* suspend current thread */                              \
                os_cond_wait(&exec_env->wait_cond, &exec_env->wait_lock); \
            }                                                             \
        }                                                                 \
    } while (0)`;
} /* WASM_ENABLE_DEBUG_INTERP */
} /* WASM_ENABLE_THREAD_MGR */

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {

enum string HANDLE_OP(string opcode) = ` HANDLE_##opcode:`;
enum string FETCH_OPCODE_AND_DISPATCH() = ` goto *handle_table[*frame_ip++]`;

static if (WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0) {
enum string HANDLE_OP_END() = `                                                   \
    do {                                                                  \
        /* Record the current frame_ip, so when exception occurs,         \
           debugger can know the exact opcode who caused the exception */ \
        frame_ip_orig = frame_ip;                                         \
        while (exec_env->current_status->signal_flag == WAMR_SIG_SINGSTEP \
               && exec_env->current_status->step_count++ == 1) {          \
            exec_env->current_status->step_count = 0;                     \
            SYNC_ALL_TO_FRAME();                                          \
            wasm_cluster_thread_stopped(exec_env);                        \
            wasm_cluster_thread_waiting_run(exec_env);                    \
        }                                                                 \
        goto *handle_table[*frame_ip++];                                  \
    } while (0)`;
} else {
enum string HANDLE_OP_END() = ` FETCH_OPCODE_AND_DISPATCH()`;
}

} else { /* else of WASM_ENABLE_LABELS_AS_VALUES */
enum string HANDLE_OP(string opcode) = ` case opcode:`;
static if (WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0) {
enum string HANDLE_OP_END() = `                                            \
    if (exec_env->current_status->signal_flag == WAMR_SIG_SINGSTEP \
        && exec_env->current_status->step_count++ == 2) {          \
        exec_env->current_status->step_count = 0;                  \
        SYNC_ALL_TO_FRAME();                                       \
        wasm_cluster_thread_stopped(exec_env);                     \
        wasm_cluster_thread_waiting_run(exec_env);                 \
    }                                                              \
    continue`;
} else {
enum string HANDLE_OP_END() = ` continue`;
}

} /* end of WASM_ENABLE_LABELS_AS_VALUES */

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
    ubyte* global_data = module_.global_data;
static if (!HasVersion!"OS_ENABLE_HW_BOUND_CHECK"              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0) {
    uint num_bytes_per_page = memory ? memory.num_bytes_per_page : 0;
    uint linear_mem_size = memory ? num_bytes_per_page * memory.cur_page_count : 0;
}
    WASMType** wasm_types = module_.module_.types;
    WASMGlobalInstance* globals = module_.e.globals, global;
    ubyte opcode_IMPDEP = WASM_OP_IMPDEP;
    WASMInterpFrame* frame = null;
    /* Points to this special opcode so as to jump to the
     * call_method_from_entry.  */
    ubyte* frame_ip = &opcode_IMPDEP; /* cache of frame->ip */
    uint* frame_lp = null;          /* cache of frame->lp */
    uint* frame_sp = null;          /* cache of frame->sp */
    WASMBranchBlock* frame_csp = null;
    BlockAddr* cache_items;
    ubyte* frame_ip_end = frame_ip + 1;
    ubyte opcode;
    uint i, depth, cond, count, fidx, tidx, lidx, frame_size = 0;
    uint all_cell_num = 0;
    int val;
    ubyte* else_addr, end_addr, maddr = null;
    uint local_idx, local_offset, global_idx;
    ubyte local_type; ubyte* global_addr;
    uint cache_index, type_index, param_cell_num, cell_num;
    ubyte value_type;

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    ubyte* frame_ip_orig = null;
    WASMDebugInstance* debug_instance = wasm_exec_env_get_instance(exec_env);
    bh_list* watch_point_list_read = debug_instance ? &debug_instance.watch_point_list_read : null;
    bh_list* watch_point_list_write = debug_instance ? &debug_instance.watch_point_list_write : null;
}

static if (WASM_ENABLE_LABELS_AS_VALUES != 0) {
enum string HANDLE_OPCODE(string op) = ` &&HANDLE_##op`;
    DEFINE_GOTO_TABLE(void, handle_table);
}

#if WASM_ENABLE_LABELS_AS_VALUES == 0
    while (frame_ip < frame_ip_end) {
        opcode = *frame_ip++;
        switch (opcode) {
//! #else
    FETCH_OPCODE_AND_DISPATCH();
//! #endif
            /* control instructions */
            HANDLE_OP(WASM_OP_UNREACHABLE)
            {
                wasm_set_exception(module_, "unreachable");
                goto got_exception;
            }

            HANDLE_OP WASM_OP_NOP { HANDLE_OP_END(); }

            HANDLE_OP EXT_OP_BLOCK {
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num = wasm_types[type_index].param_cell_num;
                cell_num = wasm_types[type_index].ret_cell_num;
                goto handle_op_block;
            }

            HANDLE_OP WASM_OP_BLOCK {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = wasm_value_type_cell_num(value_type);
            handle_op_block:
                cache_index = (cast(uintptr_t)frame_ip)
                              & cast(uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                cache_items = exec_env.block_addr_cache[cache_index];
                if (cache_items[0].start_addr == frame_ip) {
                    end_addr = cache_items[0].end_addr;
                }
                else if (cache_items[1].start_addr == frame_ip) {
                    end_addr = cache_items[1].end_addr;
                }
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
                else if(wasm_loader_find_block_addr, LABEL_TYPE_BLOCK, else_addr, end_addr) {
                    wasm_set_exception(module_, "find block address failed");
                    goto got_exception;
                }
}
                else end_addr = null;
                }
                PUSH_CSP(LABEL_TYPE_BLOCK, param_cell_num, cell_num, end_addr);
                HANDLE_OP_END();
            default: break;}

            HANDLE_OP EXT_OP_LOOP {
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num = wasm_types[type_index].param_cell_num;
                cell_num = wasm_types[type_index].param_cell_num;
                goto handle_op_loop;
            }

            HANDLE_OP WASM_OP_LOOP {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = 0;
            handle_op_loop:
                PUSH_CSP(LABEL_TYPE_LOOP, param_cell_num, cell_num, frame_ip);
                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_IF {
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num = wasm_types[type_index].param_cell_num;
                cell_num = wasm_types[type_index].ret_cell_num;
                goto handle_op_if;
            }

            HANDLE_OP WASM_OP_IF {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = wasm_value_type_cell_num(value_type);
            handle_op_if:
                cache_index = (cast(uintptr_t)frame_ip)
                              & cast(uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                cache_items = exec_env.block_addr_cache[cache_index];
                if (cache_items[0].start_addr == frame_ip) {
                    else_addr = cache_items[0].else_addr;
                    end_addr = cache_items[0].end_addr;
                }
                else if (cache_items[1].start_addr == frame_ip) {
                    else_addr = cache_items[1].else_addr;
                    end_addr = cache_items[1].end_addr;
                }
                else if (!wasm_loader_find_block_addr(
                             exec_env, cast(BlockAddr*)exec_env.block_addr_cache,
                             frame_ip, cast(ubyte*)-1, LABEL_TYPE_IF, &else_addr,
                             &end_addr)) {
                    wasm_set_exception(module_, "find block address failed");
                    goto got_exception;
                }

                cond = cast(uint)POP_I32();

                if (cond) { /* if branch is met */
                    PUSH_CSP(LABEL_TYPE_IF, param_cell_num, cell_num, end_addr);
                }
                else { /* if branch is not met */
                    /* if there is no else branch, go to the end addr */
                    if (else_addr == null) {
                        frame_ip = end_addr + 1;
                    }
                    /* if there is an else branch, go to the else addr */
                    else {
                        PUSH_CSP(LABEL_TYPE_IF, param_cell_num, cell_num,
                                 end_addr);
                        frame_ip = else_addr + 1;
                    }
                }
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_ELSE {
                /* comes from the if branch in WASM_OP_IF */
                frame_ip = (frame_csp - 1).target_addr;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_END {
                if (frame_csp > frame.csp_bottom + 1) {
                    POP_CSP();
                }
                else { /* end of function, treat as WASM_OP_RETURN */
                    frame_sp -= cur_func.ret_cell_num;
                    for (i = 0; i < cur_func.ret_cell_num; i++) {
                        *prev_frame.sp++ = frame_sp[i];
                    }
                    goto return_func;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_BR {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                read_leb_uint32(frame_ip, frame_ip_end, depth);
            label_pop_csp_n:
                POP_CSP_N(depth);
                if (!frame_ip) { /* must be label pushed by WASM_OP_BLOCK */
                    if (!wasm_loader_find_block_addr(
                            exec_env, cast(BlockAddr*)exec_env.block_addr_cache,
                            (frame_csp - 1).begin_addr, cast(ubyte*)-1,
                            LABEL_TYPE_BLOCK, &else_addr, &end_addr)) {
                        wasm_set_exception(module_, "find block address failed");
                        goto got_exception;
                    }
                    frame_ip = end_addr;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_BR_IF {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                read_leb_uint32(frame_ip, frame_ip_end, depth);
                cond = cast(uint)POP_I32();
                if (cond)
                    goto label_pop_csp_n;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_BR_TABLE {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                read_leb_uint32(frame_ip, frame_ip_end, count);
                lidx = POP_I32();
                if (lidx > count)
                    lidx = count;
                depth = frame_ip[lidx];
                goto label_pop_csp_n;
            }

            HANDLE_OP EXT_OP_BR_TABLE_CACHE {
                BrTableCache* node = bh_list_first_elem(module_.module_.br_table_cache_list);
                BrTableCache* node_next = void;

static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                lidx = POP_I32();

                while (node) {
                    node_next = bh_list_elem_next(node);
                    if (node.br_table_op_addr == frame_ip - 1) {
                        depth = node.br_depths[lidx];
                        goto label_pop_csp_n;
                    }
                    node = node_next;
                }
                bh_assert(0);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_RETURN {
                frame_sp -= cur_func.ret_cell_num;
                for (i = 0; i < cur_func.ret_cell_num; i++) {
                    *prev_frame.sp++ = frame_sp[i];
                }
                goto return_func;
            }

            HANDLE_OP WASM_OP_CALL {
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}
                read_leb_uint32(frame_ip, frame_ip_end, fidx);
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
                read_leb_uint32(frame_ip, frame_ip_end, fidx);
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

            HANDLE_OP(WASM_OP_CALL_INDIRECT)
static if (WASM_ENABLE_TAIL_CALL != 0) {
            HANDLE_OP(WASM_OP_RETURN_CALL_INDIRECT)
}
            {
                WASMType* cur_type, cur_func_type;
                WASMTableInstance* tbl_inst;
                uint tbl_idx;
static if (WASM_ENABLE_TAIL_CALL != 0) {
                opcode = *(frame_ip - 1);
}
static if (WASM_ENABLE_THREAD_MGR != 0) {
                CHECK_SUSPEND_FLAGS();
}

                /**
                 * type check. compiler will make sure all like
                 * (call_indirect (type $x) (i32.const 1))
                 * the function type has to be defined in the module also
                 * no matter it is used or not
                 */
                read_leb_uint32(frame_ip, frame_ip_end, tidx);
                bh_assert(tidx < module_.module_.type_count);
                cur_type = wasm_types[tidx];

                read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                bh_assert(tbl_idx < module_.table_count);

                tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                val = POP_I32();
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
                 * another module. In that case, we don't validate
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
            HANDLE_OP WASM_OP_DROP {
                frame_sp--;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_DROP_64 {
                frame_sp -= 2;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SELECT {
                cond = cast(uint)POP_I32();
                frame_sp--;
                if (!cond)
                    *(frame_sp - 1) = *frame_sp;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SELECT_64 {
                cond = cast(uint)POP_I32();
                frame_sp -= 2;
                if (!cond) {
                    *(frame_sp - 2) = *frame_sp;
                    *(frame_sp - 1) = *(frame_sp + 1);
                }
                HANDLE_OP_END();
            }

static if (WASM_ENABLE_REF_TYPES != 0) {
            HANDLE_OP WASM_OP_SELECT_T {
                uint vec_len = void;
                ubyte type = void;

                read_leb_uint32(frame_ip, frame_ip_end, vec_len);
                type = *frame_ip++;

                cond = cast(uint)POP_I32();
                if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64) {
                    frame_sp -= 2;
                    if (!cond) {
                        *(frame_sp - 2) = *frame_sp;
                        *(frame_sp - 1) = *(frame_sp + 1);
                    }
                }
                else {
                    frame_sp--;
                    if (!cond)
                        *(frame_sp - 1) = *frame_sp;
                }

                cast(void)vec_len;
                HANDLE_OP_END();
            }
            HANDLE_OP WASM_OP_TABLE_GET {
                uint tbl_idx = void, elem_idx = void;
                WASMTableInstance* tbl_inst = void;

                read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
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

                read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
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
                uint ref_type = void;
                read_leb_uint32(frame_ip, frame_ip_end, ref_type);
                PUSH_I32(NULL_REF);
                cast(void)ref_type;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_REF_IS_NULL {
                uint ref_val = void;
                ref_val = POP_I32();
                PUSH_I32(ref_val == NULL_REF ? 1 : 0);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_REF_FUNC {
                uint func_idx = void;
                read_leb_uint32(frame_ip, frame_ip_end, func_idx);
                PUSH_I32(func_idx);
                HANDLE_OP_END();
            }
} /* WASM_ENABLE_REF_TYPES */

            /* variable instructions */
            HANDLE_OP WASM_OP_GET_LOCAL {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

                switch (local_type) {
                    case VALUE_TYPE_I32:
                    case VALUE_TYPE_F32:
static if (WASM_ENABLE_REF_TYPES != 0) {
                    case VALUE_TYPE_FUNCREF:
                    case VALUE_TYPE_EXTERNREF:
}
                        PUSH_I32(*cast(int*)(frame_lp + local_offset));
                        break;
                    case VALUE_TYPE_I64:
                    case VALUE_TYPE_F64:
                        PUSH_I64(GET_I64_FROM_ADDR(frame_lp + local_offset));
                        break;
                    default:
                        wasm_set_exception(module_, "invalid local type");
                        goto got_exception;
                }

                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_GET_LOCAL_FAST {
                local_offset = *frame_ip++;
                if (local_offset & 0x80)
                    PUSH_I64(
                        GET_I64_FROM_ADDR(frame_lp + (local_offset & 0x7F)));
                else
                    PUSH_I32(*cast(int*)(frame_lp + local_offset));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SET_LOCAL {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

                switch (local_type) {
                    case VALUE_TYPE_I32:
                    case VALUE_TYPE_F32:
static if (WASM_ENABLE_REF_TYPES != 0) {
                    case VALUE_TYPE_FUNCREF:
                    case VALUE_TYPE_EXTERNREF:
}
                        *cast(int*)(frame_lp + local_offset) = POP_I32();
                        break;
                    case VALUE_TYPE_I64:
                    case VALUE_TYPE_F64:
                        PUT_I64_TO_ADDR(cast(uint*)(frame_lp + local_offset),
                                        POP_I64());
                        break;
                    default:
                        wasm_set_exception(module_, "invalid local type");
                        goto got_exception;
                }

                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_SET_LOCAL_FAST {
                local_offset = *frame_ip++;
                if (local_offset & 0x80)
                    PUT_I64_TO_ADDR(
                        cast(uint*)(frame_lp + (local_offset & 0x7F)),
                        POP_I64());
                else
                    *cast(int*)(frame_lp + local_offset) = POP_I32();
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_TEE_LOCAL {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

                switch (local_type) {
                    case VALUE_TYPE_I32:
                    case VALUE_TYPE_F32:
static if (WASM_ENABLE_REF_TYPES != 0) {
                    case VALUE_TYPE_FUNCREF:
                    case VALUE_TYPE_EXTERNREF:
}
                        *cast(int*)(frame_lp + local_offset) =
                            *cast(int*)(frame_sp - 1);
                        break;
                    case VALUE_TYPE_I64:
                    case VALUE_TYPE_F64:
                        PUT_I64_TO_ADDR(cast(uint*)(frame_lp + local_offset),
                                        GET_I64_FROM_ADDR(frame_sp - 2));
                        break;
                    default:
                        wasm_set_exception(module_, "invalid local type");
                        goto got_exception;
                }

                HANDLE_OP_END();
            }

            HANDLE_OP EXT_OP_TEE_LOCAL_FAST {
                local_offset = *frame_ip++;
                if (local_offset & 0x80)
                    PUT_I64_TO_ADDR(
                        cast(uint*)(frame_lp + (local_offset & 0x7F)),
                        GET_I64_FROM_ADDR(frame_sp - 2));
                else
                    *cast(int*)(frame_lp + local_offset) =
                        *cast(int*)(frame_sp - 1);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_GET_GLOBAL {
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                PUSH_I32(*cast(uint*)global_addr);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_GET_GLOBAL_64 {
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                PUSH_I64(GET_I64_FROM_ADDR(cast(uint*)global_addr));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SET_GLOBAL {
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                *cast(int*)global_addr = POP_I32();
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_SET_GLOBAL_AUX_STACK {
                uint aux_stack_top = void;

                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                aux_stack_top = *cast(uint*)(frame_sp - 1);
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
                frame_sp--;
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
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module_.e.global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                PUT_I64_TO_ADDR(cast(uint*)global_addr, POP_I64());
                HANDLE_OP_END();
            }

            /* memory load instructions */
             HANDLE_OP(WASM_OP_F32_LOAD) {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(4);
                PUSH_I32(LOAD_I32(maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_F64_LOAD) {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(8);
                PUSH_I64(LOAD_I64(maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD8_S {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I32(sign_ext_8_32(*cast(byte*)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD8_U {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I32((uint32)(*cast(ubyte*)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD16_S {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I32(sign_ext_16_32(LOAD_I16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_LOAD16_U {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I32((uint32)(LOAD_U16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD8_S {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I64(sign_ext_8_64(*cast(byte*)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD8_U {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I64((uint64)(*cast(ubyte*)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD16_S {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I64(sign_ext_16_64(LOAD_I16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD16_U {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I64((uint64)(LOAD_U16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD32_S {
                uint offset = void, flags = void, addr = void;

                opcode = *(frame_ip - 1);
                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(4);
                PUSH_I64(sign_ext_32_64(LOAD_I32(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_LOAD32_U {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(4);
                PUSH_I64((uint64)(LOAD_U32(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            /* memory store instructions */
             HANDLE_OP(WASM_OP_F32_STORE) {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                frame_sp--;
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(4);
                STORE_U32(maddr, frame_sp[1]);
                CHECK_WRITE_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_F64_STORE) {
                uint offset = void, flags = void, addr = void;

                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                frame_sp -= 2;
                addr = POP_I32();
                CHECK_MEMORY_OVERFLOW(8);
                PUT_I64_TO_ADDR(cast(uint*)maddr,
                                GET_I64_FROM_ADDR(frame_sp + 1));
                CHECK_WRITE_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_I32_STORE16) {
                uint offset = void, flags = void, addr = void;
                uint sval = void;

                opcode = *(frame_ip - 1);
                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                sval = cast(uint)POP_I32();
                addr = POP_I32();

                if (opcode == WASM_OP_I32_STORE8) {
                    CHECK_MEMORY_OVERFLOW(1);
                    *cast(ubyte*)maddr = cast(ubyte)sval;
                }
                else {
                    CHECK_MEMORY_OVERFLOW(2);
                    STORE_U16(maddr, cast(ushort)sval);
                }
                CHECK_WRITE_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

             HANDLE_OP(WASM_OP_I64_STORE16);
            HANDLE_OP WASM_OP_I64_STORE32 {
                uint offset = void, flags = void, addr = void;
                ulong sval = void;

                opcode = *(frame_ip - 1);
                read_leb_uint32(frame_ip, frame_ip_end, flags);
                read_leb_uint32(frame_ip, frame_ip_end, offset);
                sval = cast(ulong)POP_I64();
                addr = POP_I32();

                if (opcode == WASM_OP_I64_STORE8) {
                    CHECK_MEMORY_OVERFLOW(1);
                    *cast(ubyte*)maddr = cast(ubyte)sval;
                }
                else if (opcode == WASM_OP_I64_STORE16) {
                    CHECK_MEMORY_OVERFLOW(2);
                    STORE_U16(maddr, cast(ushort)sval);
                }
                else {
                    CHECK_MEMORY_OVERFLOW(4);
                    STORE_U32(maddr, cast(uint)sval);
                }
                CHECK_WRITE_WATCHPOINT(addr, offset);
                cast(void)flags;
                HANDLE_OP_END();
            }

            /* memory size and memory grow instructions */
            HANDLE_OP WASM_OP_MEMORY_SIZE {
                uint reserved = void;
                read_leb_uint32(frame_ip, frame_ip_end, reserved);
                PUSH_I32(memory.cur_page_count);
                cast(void)reserved;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_MEMORY_GROW {
                uint reserved = void, delta = void, prev_page_count = memory.cur_page_count;

                read_leb_uint32(frame_ip, frame_ip_end, reserved);
                delta = cast(uint)POP_I32();

                if (!wasm_enlarge_memory(module_, delta)) {
                    /* failed to memory.grow, return -1 */
                    PUSH_I32(-1);
                }
                else {
                    /* success, return previous page count */
                    PUSH_I32(prev_page_count);
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
             DEF_OP_I_CONST(int, I32);
            HANDLE_OP_END();

             DEF_OP_I_CONST(long, I64);
            HANDLE_OP_END();

            HANDLE_OP WASM_OP_F32_CONST {
                ubyte* p_float = cast(ubyte*)frame_sp++;
                for (i = 0; i < float32.sizeof; i++)
                    *p_float++ = *frame_ip++;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_CONST {
                ubyte* p_float = cast(ubyte*)frame_sp++;
                frame_sp++;
                for (i = 0; i < float64.sizeof; i++)
                    *p_float++ = *frame_ip++;
                HANDLE_OP_END();
            }

            /* comparison instructions of i32 */
            HANDLE_OP WASM_OP_I32_EQZ {
                DEF_OP_EQZ(I32);
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
                DEF_OP_EQZ(I64);
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

                b = POP_I32();
                a = POP_I32();
                if (a == cast(int)0x80000000 && b == -1) {
                    wasm_set_exception(module_, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_DIV_U {
                uint a = void, b = void;

                b = cast(uint)POP_I32();
                a = cast(uint)POP_I32();
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_REM_S {
                int a = void, b = void;

                b = POP_I32();
                a = POP_I32();
                if (a == cast(int)0x80000000 && b == -1) {
                    PUSH_I32(0);
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_REM_U {
                uint a = void, b = void;

                b = cast(uint)POP_I32();
                a = cast(uint)POP_I32();
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a % b);
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

                b = cast(uint)POP_I32();
                a = cast(uint)POP_I32();
                PUSH_I32(rotl32(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_ROTR {
                uint a = void, b = void;

                b = cast(uint)POP_I32();
                a = cast(uint)POP_I32();
                PUSH_I32(rotr32(a, b));
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

                b = POP_I64();
                a = POP_I64();
                if (a == cast(long)0x8000000000000000LL && b == -1) {
                    wasm_set_exception(module_, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_DIV_U {
                ulong a = void, b = void;

                b = cast(ulong)POP_I64();
                a = cast(ulong)POP_I64();
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_REM_S {
                long a = void, b = void;

                b = POP_I64();
                a = POP_I64();
                if (a == cast(long)0x8000000000000000LL && b == -1) {
                    PUSH_I64(0);
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_REM_U {
                ulong a = void, b = void;

                b = cast(ulong)POP_I64();
                a = cast(ulong)POP_I64();
                if (b == 0) {
                    wasm_set_exception(module_, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a % b);
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

                b = cast(ulong)POP_I64();
                a = cast(ulong)POP_I64();
                PUSH_I64(rotl64(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_ROTR {
                ulong a = void, b = void;

                b = cast(ulong)POP_I64();
                a = cast(ulong)POP_I64();
                PUSH_I64(rotr64(a, b));
                HANDLE_OP_END();
            }

            /* numberic instructions of f32 */
            HANDLE_OP WASM_OP_F32_ABS {
                DEF_OP_MATH(float32, F32, fabsf);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_NEG {
                uint u32 = frame_sp[-1];
                uint sign_bit = u32 & (cast(uint)1 << 31);
                if (sign_bit)
                    frame_sp[-1] = u32 & ~(cast(uint)1 << 31);
                else
                    frame_sp[-1] = u32 | (cast(uint)1 << 31);
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

                b = POP_F32();
                a = POP_F32();

                PUSH_F32(f32_min(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_MAX {
                float32 a = void, b = void;

                b = POP_F32();
                a = POP_F32();

                PUSH_F32(f32_max(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F32_COPYSIGN {
                float32 a = void, b = void;

                b = POP_F32();
                a = POP_F32();
                PUSH_F32(local_copysignf(a, b));
                HANDLE_OP_END();
            }

            /* numberic instructions of f64 */
            HANDLE_OP WASM_OP_F64_ABS {
                DEF_OP_MATH(float64, F64, fabs);
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_F64_NEG {
                ulong u64 = GET_I64_FROM_ADDR(frame_sp - 2);
                ulong sign_bit = u64 & ((cast(ulong)1) << 63);
                if (sign_bit)
                    PUT_I64_TO_ADDR(frame_sp - 2, (u64 & ~((cast(ulong)1) << 63)));
                else
                    PUT_I64_TO_ADDR(frame_sp - 2, (u64 | ((cast(ulong)1) << 63)));
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
                   represent all int32/uint32/int64/uint64 values, e.g.
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
                /* frame_sp can't be moved in trunc function, we need to
                  manually adjust it if src and dst op's cell num is
                  different */
                frame_sp--;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I32_TRUNC_U_F64 {
                DEF_OP_TRUNC_F64(-1.0, 4294967296.0, true, false);
                frame_sp--;
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
                frame_sp++;
                HANDLE_OP_END();
            }

            HANDLE_OP WASM_OP_I64_TRUNC_U_F32 {
                DEF_OP_TRUNC_F32(-1.0f, 18446744073709551616.0f, false, false);
                frame_sp++;
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
             HANDLE_OP(WASM_OP_I64_REINTERPRET_F64);
             HANDLE_OP(WASM_OP_F64_REINTERPRET_I64) { HANDLE_OP_END(); }

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
                uint opcode1 = void;

                read_leb_uint32(frame_ip, frame_ip_end, opcode1);
                opcode = cast(ubyte)opcode1;

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
                        frame_sp--;
                        break;
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0, 4294967296.0, true, false);
                        frame_sp--;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                        DEF_OP_TRUNC_SAT_F32(-9223373136366403584.0f,
                                             9223372036854775808.0f, false,
                                             true);
                        frame_sp++;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        DEF_OP_TRUNC_SAT_F32(-1.0f, 18446744073709551616.0f,
                                             false, false);
                        frame_sp++;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                        DEF_OP_TRUNC_SAT_F64(-9223372036854777856.0,
                                             9223372036854775808.0, false,
                                             true);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0f, 18446744073709551616.0,
                                             false, false);
                        break;
static if (WASM_ENABLE_BULK_MEMORY != 0) {
                    case WASM_OP_MEMORY_INIT:
                    {
                        uint addr = void, segment = void;
                        ulong bytes = void, offset = void, seg_len = void;
                        ubyte* data = void;

                        read_leb_uint32(frame_ip, frame_ip_end, segment);
                        /* skip memory index */
                        frame_ip++;

                        bytes = cast(ulong)cast(uint)POP_I32();
                        offset = cast(ulong)cast(uint)POP_I32();
                        addr = cast(uint)POP_I32();

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

                        read_leb_uint32(frame_ip, frame_ip_end, segment);
                        module_.module_.data_segments[segment].data_length = 0;
                        break;
                    }
                    case WASM_OP_MEMORY_COPY:
                    {
                        uint dst = void, src = void, len = void;
                        ubyte* mdst = void, msrc = void;

                        frame_ip += 2;

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
                        frame_ip++;

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

                        read_leb_uint32(frame_ip, frame_ip_end, elem_idx);
                        bh_assert(elem_idx < module_.module_.table_seg_count);

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module_.module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        n = cast(uint)POP_I32();
                        s = cast(uint)POP_I32();
                        d = cast(uint)POP_I32();

                        /* TODO: what if the element is not passive? */

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
                        uint elem_idx = void;
                        read_leb_uint32(frame_ip, frame_ip_end, elem_idx);
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

                        read_leb_uint32(frame_ip, frame_ip_end, dst_tbl_idx);
                        bh_assert(dst_tbl_idx < module_.table_count);

                        dst_tbl_inst = wasm_get_table_inst(module_, dst_tbl_idx);

                        read_leb_uint32(frame_ip, frame_ip_end, src_tbl_idx);
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

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
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

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        PUSH_I32(tbl_inst.cur_size);
                        break;
                    }
                    case WASM_OP_TABLE_FILL:
                    {
                        uint tbl_idx = void, n = void, fill_val = void;
                        WASMTableInstance* tbl_inst = void;

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module_.table_count);

                        tbl_inst = wasm_get_table_inst(module_, tbl_idx);

                        n = POP_I32();
                        fill_val = POP_I32();
                        i = POP_I32();

                        /* TODO: what if the element is not passive? */
                        /* TODO: what if the element is dropped? */

                        if (i + n > tbl_inst.cur_size) {
                            /* TODO: verify warning content */
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
                uint offset = 0, align_ = void, addr = void;

                opcode = *frame_ip++;

                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    read_leb_uint32(frame_ip, frame_ip_end, align_);
                    read_leb_uint32(frame_ip, frame_ip_end, offset);
                }

                switch (opcode) {
                    case WASM_OP_ATOMIC_NOTIFY:
                    {
                        uint notify_count = void, ret = void;

                        notify_count = POP_I32();
                        addr = POP_I32();
                        CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                        CHECK_ATOMIC_MEMORY_ACCESS();

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
                        CHECK_ATOMIC_MEMORY_ACCESS();

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
                        CHECK_ATOMIC_MEMORY_ACCESS();

                        ret = wasm_runtime_atomic_wait(
                            cast(WASMModuleInstanceCommon*)module_, maddr, expect,
                            timeout, true);
                        if (ret == (uint32)-1)
                            goto got_exception;

                        PUSH_I32(ret);
                        break;
                    }
                    case WASM_OP_ATOMIC_FENCE:
                    {
                        /* Skip the memory index */
                        frame_ip++;
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
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint32)(*cast(ubyte*)maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_LOAD16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(uint)LOAD_U16(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
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
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint64)(*cast(ubyte*)maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U16(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD32_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U32(maddr);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
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
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            *cast(ubyte*)maddr = cast(ubyte)sval;
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_STORE16) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U16(maddr, cast(ushort)sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U32(maddr, frame_sp[1]);
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
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            *cast(ubyte*)maddr = cast(ubyte)sval;
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE16) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U16(maddr, cast(ushort)sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE32) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            STORE_U32(maddr, cast(uint)sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            os_mutex_lock(&module_.e.mem_lock);
                            PUT_I64_TO_ADDR(cast(uint*)maddr,
                                            GET_I64_FROM_ADDR(frame_sp + 1));
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
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = cast(ubyte)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint32)(*cast(ubyte*)maddr);
                            if (readv == expect)
                                *cast(ubyte*)maddr = (uint8)(sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = cast(ushort)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(uint)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();

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
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = cast(ubyte)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = (uint64)(*cast(ubyte*)maddr);
                            if (readv == expect)
                                *cast(ubyte*)maddr = (uint8)(sval);
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 2, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = cast(ushort)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U) {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 4, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = cast(uint)expect;
                            os_mutex_lock(&module_.e.mem_lock);
                            readv = cast(ulong)LOAD_U32(maddr);
                            if (readv == expect)
                                STORE_U32(maddr, (uint32)(sval));
                            os_mutex_unlock(&module_.e.mem_lock);
                        }
                        else {
                            CHECK_BULK_MEMORY_OVERFLOW(addr + offset, 8, maddr);
                            CHECK_ATOMIC_MEMORY_ACCESS();

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
                frame_sp = frame.sp;
                frame_csp = frame.csp;
                goto call_func_from_entry;
            }

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
            HANDLE_OP DEBUG_OP_BREAK {
                wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP);
                exec_env.suspend_flags.flags |= 2;
                frame_ip--;
                SYNC_ALL_TO_FRAME();
                CHECK_SUSPEND_FLAGS();
                HANDLE_OP_END();
            }
}
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
         HANDLE_OP(WASM_OP_TABLE_GET);
         HANDLE_OP(WASM_OP_REF_NULL);
         HANDLE_OP(WASM_OP_REF_FUNC);
}
         HANDLE_OP(WASM_OP_UNUSED_0x15);
         HANDLE_OP(WASM_OP_UNUSED_0x17);
         HANDLE_OP(WASM_OP_UNUSED_0x19);
         HANDLE_OP(EXT_OP_SET_LOCAL_FAST_I64);
         HANDLE_OP(EXT_OP_COPY_STACK_TOP);
         HANDLE_OP(EXT_OP_COPY_STACK_VALUES) {
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
        POP(cur_func.param_cell_num);
        if (cur_func.param_cell_num > 0) {
            word_copy(frame.lp, frame_sp, cur_func.param_cell_num);
        }
        FREE_FRAME(exec_env, frame);
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);
        goto call_func_from_entry;
    }
}
    call_func_from_interp:
    {
        /* Only do the copy when it's called from interpreter.  */
        WASMInterpFrame* outs_area = wasm_exec_env_wasm_stack_top(exec_env);
        POP(cur_func.param_cell_num);
        SYNC_ALL_TO_FRAME();
        if (cur_func.param_cell_num > 0) {
            word_copy(outs_area.lp, frame_sp, cur_func.param_cell_num);
        }
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
            WASMType* func_type;

            func_type = cur_wasm_func.func_type;

            all_cell_num = cur_func.param_cell_num + cur_func.local_cell_num
                           + cur_wasm_func.max_stack_cell_num
                           + cur_wasm_func.max_block_num
                                 * cast(uint)WASMBranchBlock.sizeof / 4;
            /* param_cell_num, local_cell_num, max_stack_cell_num and
               max_block_num are all no larger than UINT16_MAX (checked
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
            frame_lp = frame.lp;

            frame_sp = frame.sp_bottom =
                frame_lp + cur_func.param_cell_num + cur_func.local_cell_num;
            frame.sp_boundary =
                frame.sp_bottom + cur_wasm_func.max_stack_cell_num;

            frame_csp = frame.csp_bottom =
                cast(WASMBranchBlock*)frame.sp_boundary;
            frame.csp_boundary =
                frame.csp_bottom + cur_wasm_func.max_block_num;

            /* Initialize the local variables */
            memset(frame_lp + cur_func.param_cell_num, 0,
                   (uint32)(cur_func.local_cell_num * 4));

            /* Push function block as first block */
            cell_num = func_type.ret_cell_num;
            PUSH_CSP(LABEL_TYPE_FUNCTION, 0, cell_num, frame_ip_end - 1);

            wasm_exec_env_set_cur_frame(exec_env, frame);
static if (WASM_ENABLE_THREAD_MGR != 0) {
            CHECK_SUSPEND_FLAGS();
}
        }
        HANDLE_OP_END();
    }

    return_func:
    {
        FREE_FRAME(exec_env, frame);
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);

        if (!prev_frame.ip)
            /* Called from native. */
            return;

        RECOVER_CONTEXT(prev_frame);
        HANDLE_OP_END();
    }

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
static if (WASM_ENABLE_DEBUG_INTERP != 0) {
        if (wasm_exec_env_get_instance(exec_env) != null) {
            ubyte* frame_ip_temp = frame_ip;
            frame_ip = frame_ip_orig;
            wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP);
            CHECK_SUSPEND_FLAGS();
            frame_ip = frame_ip_temp;
        }
}
        SYNC_ALL_TO_FRAME();
        return;

static if (WASM_ENABLE_LABELS_AS_VALUES == 0) {
    }
} else {
    FETCH_OPCODE_AND_DISPATCH();
}
}

static if (WASM_ENABLE_FAST_JIT != 0) {
private void fast_jit_call_func_bytecode(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* function_, WASMInterpFrame* frame) {
    JitGlobals* jit_globals = jit_compiler_get_jit_globals();
    JitInterpSwitchInfo info = void;
    WASMModule* module_ = module_inst.module_;
    WASMType* func_type = function_.u.func.func_type;
    ubyte type = func_type.result_count
                     ? func_type.types[func_type.param_count]
                     : VALUE_TYPE_VOID;
    uint func_idx = (uint32)(function_ - module_inst.e.functions);
    uint func_idx_non_import = func_idx - module_.import_function_count;
    int action = void;

static if (WASM_ENABLE_REF_TYPES != 0) {
    if (type == VALUE_TYPE_EXTERNREF || type == VALUE_TYPE_FUNCREF)
        type = VALUE_TYPE_I32;
}

static if (WASM_ENABLE_LAZY_JIT != 0) {
    if (!jit_compiler_compile(module_, func_idx)) {
        wasm_set_exception(module_inst, "failed to compile fast jit function");
        return;
    }
}
    bh_assert(jit_compiler_is_compiled(module_, func_idx));

    /* Switch to jitted code to call the jit function */
    info.out_.ret.last_return_type = type;
    info.frame = frame;
    frame.jitted_return_addr =
        cast(ubyte*)jit_globals.return_to_interp_from_jitted;
    action = jit_interp_switch_to_jitted(
        exec_env, &info, func_idx,
        module_inst.fast_jit_func_ptrs[func_idx_non_import]);
    bh_assert(action == JIT_INTERP_ACTION_NORMAL
              || (action == JIT_INTERP_ACTION_THROWN
                  && wasm_runtime_get_exception(exec_env.module_inst)));

    /* Get the return values form info.out.ret */
    if (func_type.result_count) {
        switch (type) {
            case VALUE_TYPE_I32:
                *(frame.sp - function_.ret_cell_num) = info.out_.ret.ival[0];
                break;
            case VALUE_TYPE_I64:
                *(frame.sp - function_.ret_cell_num) = info.out_.ret.ival[0];
                *(frame.sp - function_.ret_cell_num + 1) =
                    info.out_.ret.ival[1];
                break;
            case VALUE_TYPE_F32:
                *(frame.sp - function_.ret_cell_num) = info.out_.ret.fval[0];
                break;
            case VALUE_TYPE_F64:
                *(frame.sp - function_.ret_cell_num) = info.out_.ret.fval[0];
                *(frame.sp - function_.ret_cell_num + 1) =
                    info.out_.ret.fval[1];
                break;
            default:
                bh_assert(0);
                break;
        }
    }
    cast(void)action;
    cast(void)func_idx;
}
} /* end of WASM_ENABLE_FAST_JIT != 0 */

static if (WASM_ENABLE_JIT != 0) {
private bool clear_wasi_proc_exit_exception(WASMModuleInstance* module_inst) {
static if (WASM_ENABLE_LIBC_WASI != 0) {
    const(char)* exception = wasm_get_exception(module_inst);
    if (exception && !strcmp(exception, "Exception: wasi proc exit")) {
        /* The "wasi proc exit" exception is thrown by native lib to
           let wasm app exit, which is a normal behavior, we clear
           the exception here. */
        wasm_set_exception(module_inst, null);
        return true;
    }
    return false;
} else {
    return false;
}
}

private bool llvm_jit_call_func_bytecode(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv) {
    WASMType* func_type = function_.u.func.func_type;
    uint result_count = func_type.result_count;
    uint ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    uint func_idx = (uint32)(function_ - module_inst.e.functions);
    bool ret = void;

static if ((WASM_ENABLE_DUMP_CALL_STACK != 0) || (WASM_ENABLE_PERF_PROFILING != 0)) {
    if (!llvm_jit_alloc_frame(exec_env, function_ - module_inst.e.functions)) {
        /* wasm operand stack overflow has been thrown,
           no need to throw again */
        return false;
    }
}

    if (ext_ret_count > 0) {
        uint cell_num = 0, i = void;
        ubyte* ext_ret_types = func_type.types + func_type.param_count + 1;
        uint[32] argv1_buf = void; uint* argv1 = argv1_buf, ext_rets = null;
        uint* argv_ret = argv;
        uint ext_ret_cell = wasm_get_cell_num(ext_ret_types, ext_ret_count);
        ulong size = void;

        /* Allocate memory all arguments */
        size =
            sizeof(uint32) * cast(ulong)argc /* original arguments */
            + sizeofcast(void*)
                  * cast(ulong)ext_ret_count /* extra result values' addr */
            + sizeof(uint32) * cast(ulong)ext_ret_cell; /* extra result values */
        if (size > argv1_buf.sizeof) {
            if (size > UINT32_MAX
                || ((argv1 = wasm_runtime_malloc(cast(uint)size)) == 0)) {
                wasm_set_exception(module_inst, "allocate memory failed");
                return false;
            }
        }

        /* Copy original arguments */
        bh_memcpy_s(argv1, cast(uint)size, argv, sizeof(uint32) * argc);

        /* Get the extra result value's address */
        ext_rets =
            argv1 + argc + (void*).sizeof / sizeof(uint32) * ext_ret_count;

        /* Append each extra result value's address to original arguments */
        for (i = 0; i < ext_ret_count; i++) {
            *cast(uintptr_t*)(argv1 + argc + (void*).sizeof / sizeof(uint32) * i) =
                cast(uintptr_t)(ext_rets + cell_num);
            cell_num += wasm_value_type_cell_num(ext_ret_types[i]);
        }

        ret = wasm_runtime_invoke_native(
            exec_env, module_inst.func_ptrs[func_idx], func_type, null, null,
            argv1, argc, argv);

        if (!ret || wasm_get_exception(module_inst)) {
            if (clear_wasi_proc_exit_exception(module_inst))
                ret = true;
            else
                ret = false;
        }

        if (!ret) {
            if (argv1 != argv1_buf.ptr)
                wasm_runtime_free(argv1);
            return ret;
        }

        /* Get extra result values */
        switch (func_type.types[func_type.param_count]) {
            case VALUE_TYPE_I32:
            case VALUE_TYPE_F32:
static if (WASM_ENABLE_REF_TYPES != 0) {
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
}
                argv_ret++;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                argv_ret += 2;
                break;
static if (WASM_ENABLE_SIMD != 0) {
            case VALUE_TYPE_V128:
                argv_ret += 4;
                break;
}
            default:
                bh_assert(0);
                break;
        }

        ext_rets =
            argv1 + argc + (void*).sizeof / sizeof(uint32) * ext_ret_count;
        bh_memcpy_s(argv_ret, sizeof(uint32) * cell_num, ext_rets,
                    sizeof(uint32) * cell_num);

        if (argv1 != argv1_buf.ptr)
            wasm_runtime_free(argv1);
        return true;
    }
    else {
        ret = wasm_runtime_invoke_native(
            exec_env, module_inst.func_ptrs[func_idx], func_type, null, null,
            argv, argc, argv);

        if (clear_wasi_proc_exit_exception(module_inst))
            ret = true;

        return ret && !wasm_get_exception(module_inst) ? true : false;
    }
}
} /* end of WASM_ENABLE_JIT != 0 */

void wasm_interp_call_wasm(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv) {
    WASMRuntimeFrame* prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    WASMInterpFrame* frame = void, outs_area = void;
    /* Allocate sufficient cells for all kinds of return values.  */
    uint all_cell_num = function_.ret_cell_num > 2 ? function_.ret_cell_num : 2;
    /* This frame won't be used by JITed code, so only allocate interp
       frame here.  */
    uint frame_size = wasm_interp_interp_frame_size(all_cell_num);
    uint i = void;
    bool copy_argv_from_frame = true;

    if (argc < function_.param_cell_num) {
        char[128] buf = void;
        snprintf(buf.ptr, buf.sizeof,
                 "invalid argument count %" PRIu32
                 ~ ", must be no smaller than %u",
                 argc, function_.param_cell_num);
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

    if (((frame = ALLOC_FRAME(exec_env, frame_size, prev_frame)) == 0))
        return;

    outs_area = wasm_exec_env_wasm_stack_top(exec_env);
    frame.function_ = null;
    frame.ip = null;
    /* There is no local variable. */
    frame.sp = frame.lp + 0;

    if (cast(ubyte*)(outs_area.lp + function_.param_cell_num)
        > exec_env.wasm_stack.s.top_boundary) {
        wasm_set_exception(module_inst, "wasm operand stack overflow");
        return;
    }

    if (argc > 0)
        word_copy(outs_area.lp, argv, argc);

    wasm_exec_env_set_cur_frame(exec_env, frame);

    if (function_.is_import_func) {
static if (WASM_ENABLE_MULTI_MODULE != 0) {
        if (function_.import_module_inst) {
            wasm_interp_call_func_import(module_inst, exec_env, function_,
                                         frame);
        }
        else
}
        {
            /* it is a native function */
            wasm_interp_call_func_native(module_inst, exec_env, function_,
                                         frame);
        }
    }
    else {
static if (WASM_ENABLE_LAZY_JIT != 0) {

        /* Fast JIT to LLVM JIT tier-up is enabled */
static if (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0) {
        /* Fast JIT and LLVM JIT are both enabled, call llvm jit function
           if it is compiled, else call fast jit function */
        uint func_idx = (uint32)(function_ - module_inst.e.functions);
        if (module_inst.module_.func_ptrs_compiled
                [func_idx - module_inst.module_.import_function_count]) {
            llvm_jit_call_func_bytecode(module_inst, exec_env, function_, argc,
                                        argv);
            /* For llvm jit, the results have been stored in argv,
               no need to copy them from stack frame again */
            copy_argv_from_frame = false;
        }
        else {
            fast_jit_call_func_bytecode(module_inst, exec_env, function_, frame);
        }
} else static if (WASM_ENABLE_JIT != 0) {
        /* Only LLVM JIT is enabled */
        llvm_jit_call_func_bytecode(module_inst, exec_env, function_, argc,
                                    argv);
        /* For llvm jit, the results have been stored in argv,
           no need to copy them from stack frame again */
        copy_argv_from_frame = false;
} else static if (WASM_ENABLE_FAST_JIT != 0) {
        /* Only Fast JIT is enabled */
        fast_jit_call_func_bytecode(module_inst, exec_env, function_, frame);
} else {
        /* Both Fast JIT and LLVM JIT are disabled */
        wasm_interp_call_func_bytecode(module_inst, exec_env, function_, frame);
}

} else { /* else of WASM_ENABLE_LAZY_JIT != 0 */

        /* Fast JIT to LLVM JIT tier-up is enabled */
static if (WASM_ENABLE_JIT != 0) {
        /* LLVM JIT is enabled */
        llvm_jit_call_func_bytecode(module_inst, exec_env, function_, argc,
                                    argv);
        /* For llvm jit, the results have been stored in argv,
           no need to copy them from stack frame again */
        copy_argv_from_frame = false;
} else static if (WASM_ENABLE_FAST_JIT != 0) {
        /* Fast JIT is enabled */
        fast_jit_call_func_bytecode(module_inst, exec_env, function_, frame);
} else {
        /* Both Fast JIT and LLVM JIT are disabled */
        wasm_interp_call_func_bytecode(module_inst, exec_env, function_, frame);
}

} /* end of WASM_ENABLE_LAZY_JIT != 0 */

        cast(void)wasm_interp_call_func_bytecode;
static if (WASM_ENABLE_FAST_JIT != 0) {
        cast(void)fast_jit_call_func_bytecode;
}
    }

    /* Output the return value to the caller */
    if (!wasm_get_exception(module_inst)) {
        if (copy_argv_from_frame) {
            for (i = 0; i < function_.ret_cell_num; i++) {
                argv[i] = *(frame.sp + i - function_.ret_cell_num);
            }
        }
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
}
