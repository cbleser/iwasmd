module jit_emit_memory;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_emit_memory;
public import jit_emit_exception;
public import jit_emit_function;
public import ...jit_frontend;
public import ...jit_codegen;
public import ......interpreter.wasm_runtime;

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
private JitReg get_memory_boundary(JitCompContext* cc, uint mem_idx, uint bytes) {
    JitReg memory_boundary = void;

    switch (bytes) {
        case 1:
        {
            memory_boundary =
                get_mem_bound_check_1byte_reg(cc.jit_frame, mem_idx);
            break;
        }
        case 2:
        {
            memory_boundary =
                get_mem_bound_check_2bytes_reg(cc.jit_frame, mem_idx);
            break;
        }
        case 4:
        {
            memory_boundary =
                get_mem_bound_check_4bytes_reg(cc.jit_frame, mem_idx);
            break;
        }
        case 8:
        {
            memory_boundary =
                get_mem_bound_check_8bytes_reg(cc.jit_frame, mem_idx);
            break;
        }
        case 16:
        {
            memory_boundary =
                get_mem_bound_check_16bytes_reg(cc.jit_frame, mem_idx);
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    return memory_boundary;
fail:
    return 0;
}
}

static if (UINTPTR_MAX == UINT64_MAX) {
private JitReg check_and_seek_on_64bit_platform(JitCompContext* cc, JitReg addr, JitReg offset, JitReg memory_boundary) {
    JitReg long_addr = void, offset1 = void;

    /* long_addr = (int64_t)addr */
    long_addr = jit_cc_new_reg_I64(cc);
    GEN_INSN(U32TOI64, long_addr, addr);

    /* offset1 = offset + long_addr */
    offset1 = jit_cc_new_reg_I64(cc);
    GEN_INSN(ADD, offset1, offset, long_addr);

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    /* if (offset1 > memory_boundary) goto EXCEPTION */
    GEN_INSN(CMP, cc.cmp_reg, offset1, memory_boundary);
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, JIT_OP_BGTU,
                            cc.cmp_reg, null)) {
        goto fail;
    }
}

    return offset1;
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
fail:
    return 0;
}
}
} else {
private JitReg check_and_seek_on_32bit_platform(JitCompContext* cc, JitReg addr, JitReg offset, JitReg memory_boundary) {
    JitReg offset1 = void;

    /* offset1 = offset + addr */
    offset1 = jit_cc_new_reg_I32(cc);
    GEN_INSN(ADD, offset1, offset, addr);

    /* if (offset1 < addr) goto EXCEPTION */
    GEN_INSN(CMP, cc.cmp_reg, offset1, addr);
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, JIT_OP_BLTU,
                            cc.cmp_reg, null)) {
        goto fail;
    }

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    /* if (offset1 > memory_boundary) goto EXCEPTION */
    GEN_INSN(CMP, cc.cmp_reg, offset1, memory_boundary);
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS, JIT_OP_BGTU,
                            cc.cmp_reg, null)) {
        goto fail;
    }
}

    return offset1;
fail:
    return 0;
}
}

private JitReg check_and_seek(JitCompContext* cc, JitReg addr, uint offset, uint bytes) {
    JitReg memory_boundary = 0, offset1 = void;
version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    /* the default memory */
    uint mem_idx = 0;
}

version (OS_ENABLE_HW_BOUND_CHECK) {} else {
    /* ---------- check ---------- */
    /* 1. shortcut if the memory size is 0 */
    if (0 == cc.cur_wasm_module.memories[mem_idx].init_page_count) {
        JitReg module_inst = void, cur_page_count = void;
        uint cur_page_count_offset = cast(uint)offsetof(WASMModuleInstance, global_table_data.bytes)
            + cast(uint)WASMMemoryInstance.cur_page_count.offsetof;

        /* if (cur_mem_page_count == 0) goto EXCEPTION */
        module_inst = get_module_inst_reg(cc.jit_frame);
        cur_page_count = jit_cc_new_reg_I32(cc);
        GEN_INSN(LDI32, cur_page_count, module_inst,
                 NEW_CONST(I32, cur_page_count_offset));
        GEN_INSN(CMP, cc.cmp_reg, cur_page_count, NEW_CONST(I32, 0));
        if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS,
                                JIT_OP_BEQ, cc.cmp_reg, null)) {
            goto fail;
        }
    }

    /* 2. a complete boundary check */
    memory_boundary = get_memory_boundary(cc, mem_idx, bytes);
    if (!memory_boundary)
        goto fail;
}

static if (UINTPTR_MAX == UINT64_MAX) {
    offset1 = check_and_seek_on_64bit_platform(cc, addr, NEW_CONST(I64, offset),
                                               memory_boundary);
    if (!offset1)
        goto fail;
} else {
    offset1 = check_and_seek_on_32bit_platform(cc, addr, NEW_CONST(I32, offset),
                                               memory_boundary);
    if (!offset1)
        goto fail;
}

    return offset1;
fail:
    return 0;
}

bool jit_compile_op_i32_load(JitCompContext* cc, uint align_, uint offset, uint bytes, bool sign, bool atomic) {
    JitReg addr = void, offset1 = void, value = void, memory_data = void;

    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, bytes);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    value = jit_cc_new_reg_I32(cc);
    switch (bytes) {
        case 1:
        {
            if (sign) {
                GEN_INSN(LDI8, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU8, value, memory_data, offset1);
            }
            break;
        }
        case 2:
        {
            if (sign) {
                GEN_INSN(LDI16, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU16, value, memory_data, offset1);
            }
            break;
        }
        case 4:
        {
            if (sign) {
                GEN_INSN(LDI32, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU32, value, memory_data, offset1);
            }
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    PUSH_I32(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_load(JitCompContext* cc, uint align_, uint offset, uint bytes, bool sign, bool atomic) {
    JitReg addr = void, offset1 = void, value = void, memory_data = void;

    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, bytes);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    value = jit_cc_new_reg_I64(cc);
    switch (bytes) {
        case 1:
        {
            if (sign) {
                GEN_INSN(LDI8, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU8, value, memory_data, offset1);
            }
            break;
        }
        case 2:
        {
            if (sign) {
                GEN_INSN(LDI16, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU16, value, memory_data, offset1);
            }
            break;
        }
        case 4:
        {
            if (sign) {
                GEN_INSN(LDI32, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU32, value, memory_data, offset1);
            }
            break;
        }
        case 8:
        {
            if (sign) {
                GEN_INSN(LDI64, value, memory_data, offset1);
            }
            else {
                GEN_INSN(LDU64, value, memory_data, offset1);
            }
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    PUSH_I64(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_f32_load(JitCompContext* cc, uint align_, uint offset) {
    JitReg addr = void, offset1 = void, value = void, memory_data = void;

    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, 4);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    value = jit_cc_new_reg_F32(cc);
    GEN_INSN(LDF32, value, memory_data, offset1);

    PUSH_F32(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_f64_load(JitCompContext* cc, uint align_, uint offset) {
    JitReg addr = void, offset1 = void, value = void, memory_data = void;

    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, 8);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    value = jit_cc_new_reg_F64(cc);
    GEN_INSN(LDF64, value, memory_data, offset1);

    PUSH_F64(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_i32_store(JitCompContext* cc, uint align_, uint offset, uint bytes, bool atomic) {
    JitReg value = void, addr = void, offset1 = void, memory_data = void;

    POP_I32(value);
    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, bytes);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    switch (bytes) {
        case 1:
        {
            GEN_INSN(STI8, value, memory_data, offset1);
            break;
        }
        case 2:
        {
            GEN_INSN(STI16, value, memory_data, offset1);
            break;
        }
        case 4:
        {
            GEN_INSN(STI32, value, memory_data, offset1);
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    return true;
fail:
    return false;
}

bool jit_compile_op_i64_store(JitCompContext* cc, uint align_, uint offset, uint bytes, bool atomic) {
    JitReg value = void, addr = void, offset1 = void, memory_data = void;

    POP_I64(value);
    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, bytes);
    if (!offset1) {
        goto fail;
    }

    if (jit_reg_is_const(value) && bytes < 8) {
        value = NEW_CONST(I32, cast(int)jit_cc_get_const_I64(cc, value));
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    switch (bytes) {
        case 1:
        {
            GEN_INSN(STI8, value, memory_data, offset1);
            break;
        }
        case 2:
        {
            GEN_INSN(STI16, value, memory_data, offset1);
            break;
        }
        case 4:
        {
            GEN_INSN(STI32, value, memory_data, offset1);
            break;
        }
        case 8:
        {
            GEN_INSN(STI64, value, memory_data, offset1);
            break;
        }
        default:
        {
            bh_assert(0);
            goto fail;
        }
    }

    return true;
fail:
    return false;
}

bool jit_compile_op_f32_store(JitCompContext* cc, uint align_, uint offset) {
    JitReg value = void, addr = void, offset1 = void, memory_data = void;

    POP_F32(value);
    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, 4);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    GEN_INSN(STF32, value, memory_data, offset1);

    return true;
fail:
    return false;
}

bool jit_compile_op_f64_store(JitCompContext* cc, uint align_, uint offset) {
    JitReg value = void, addr = void, offset1 = void, memory_data = void;

    POP_F64(value);
    POP_I32(addr);

    offset1 = check_and_seek(cc, addr, offset, 8);
    if (!offset1) {
        goto fail;
    }

    memory_data = get_memory_data_reg(cc.jit_frame, 0);

    GEN_INSN(STF64, value, memory_data, offset1);

    return true;
fail:
    return false;
}

bool jit_compile_op_memory_size(JitCompContext* cc, uint mem_idx) {
    JitReg module_inst = void, cur_page_count = void;
    uint cur_page_count_offset = cast(uint)offsetof(WASMModuleInstance, global_table_data.bytes)
        + cast(uint)WASMMemoryInstance.cur_page_count.offsetof;

    module_inst = get_module_inst_reg(cc.jit_frame);
    cur_page_count = jit_cc_new_reg_I32(cc);
    GEN_INSN(LDI32, cur_page_count, module_inst,
             NEW_CONST(I32, cur_page_count_offset));

    PUSH_I32(cur_page_count);

    return true;
fail:
    return false;
}

bool jit_compile_op_memory_grow(JitCompContext* cc, uint mem_idx) {
    JitReg module_inst = void, grow_res = void, res = void;
    JitReg prev_page_count = void, inc_page_count = void; JitReg[2] args = void;

    /* Get current page count */
    uint cur_page_count_offset = cast(uint)offsetof(WASMModuleInstance, global_table_data.bytes)
        + cast(uint)WASMMemoryInstance.cur_page_count.offsetof;

    module_inst = get_module_inst_reg(cc.jit_frame);
    prev_page_count = jit_cc_new_reg_I32(cc);
    GEN_INSN(LDI32, prev_page_count, module_inst,
             NEW_CONST(I32, cur_page_count_offset));

    /* Call wasm_enlarge_memory */
    POP_I32(inc_page_count);

    grow_res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = inc_page_count;

    if (!jit_emit_callnative(cc, wasm_enlarge_memory, grow_res, args.ptr, 2)) {
        goto fail;
    }
    /* Convert bool to uint32 */
    GEN_INSN(AND, grow_res, grow_res, NEW_CONST(I32, 0xFF));

    /* return different values according to memory.grow result */
    res = jit_cc_new_reg_I32(cc);
    GEN_INSN(CMP, cc.cmp_reg, grow_res, NEW_CONST(I32, 0));
    GEN_INSN(SELECTNE, res, cc.cmp_reg, prev_page_count,
             NEW_CONST(I32, (int32)-1));
    PUSH_I32(res);

    /* Ensure a refresh in next get memory related registers */
    clear_memory_regs(cc.jit_frame);

    return true;
fail:
    return false;
}

static if (WASM_ENABLE_BULK_MEMORY != 0) {
private int wasm_init_memory(WASMModuleInstance* inst, uint mem_idx, uint seg_idx, uint len, uint mem_offset, uint data_offset) {
    WASMMemoryInstance* mem_inst = void;
    WASMDataSeg* data_segment = void;
    uint mem_size = void;
    ubyte* mem_addr = void, data_addr = void;

    /* if d + n > the length of mem.data */
    mem_inst = inst.memories[mem_idx];
    mem_size = mem_inst.cur_page_count * mem_inst.num_bytes_per_page;
    if (mem_size < mem_offset || mem_size - mem_offset < len)
        goto out_of_bounds;

    /* if s + n > the length of data.data */
    bh_assert(seg_idx < inst.module_.data_seg_count);
    data_segment = inst.module_.data_segments[seg_idx];
    if (data_segment.data_length < data_offset
        || data_segment.data_length - data_offset < len)
        goto out_of_bounds;

    mem_addr = mem_inst.memory_data + mem_offset;
    data_addr = data_segment.data + data_offset;
    bh_memcpy_s(mem_addr, mem_size - mem_offset, data_addr, len);

    return 0;
out_of_bounds:
    wasm_set_exception(inst, "out of bounds memory access");
    return -1;
}

bool jit_compile_op_memory_init(JitCompContext* cc, uint mem_idx, uint seg_idx) {
    JitReg len = void, mem_offset = void, data_offset = void, res = void;
    JitReg[6] args = 0;

    POP_I32(len);
    POP_I32(data_offset);
    POP_I32(mem_offset);

    res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, mem_idx);
    args[2] = NEW_CONST(I32, seg_idx);
    args[3] = len;
    args[4] = mem_offset;
    args[5] = data_offset;

    if (!jit_emit_callnative(cc, &wasm_init_memory, res, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;

    GEN_INSN(CMP, cc.cmp_reg, res, NEW_CONST(I32, 0));
    if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BLTS, cc.cmp_reg,
                            null))
        goto fail;

    return true;
fail:
    return false;
}

bool jit_compile_op_data_drop(JitCompContext* cc, uint seg_idx) {
    JitReg module_ = get_module_reg(cc.jit_frame);
    JitReg data_segments = jit_cc_new_reg_ptr(cc);
    JitReg data_segment = jit_cc_new_reg_ptr(cc);

    GEN_INSN(LDPTR, data_segments, module_,
             NEW_CONST(I32, WASMModule.data_segments.offsetof));
    GEN_INSN(LDPTR, data_segment, data_segments,
             NEW_CONST(I32, seg_idx * (WASMDataSeg*).sizeof));
    GEN_INSN(STI32, NEW_CONST(I32, 0), data_segment,
             NEW_CONST(I32, WASMDataSeg.data_length.offsetof));

    return true;
}

private int wasm_copy_memory(WASMModuleInstance* inst, uint src_mem_idx, uint dst_mem_idx, uint len, uint src_offset, uint dst_offset) {
    WASMMemoryInstance* src_mem = void, dst_mem = void;
    uint src_mem_size = void, dst_mem_size = void;
    ubyte* src_addr = void, dst_addr = void;

    src_mem = inst.memories[src_mem_idx];
    dst_mem = inst.memories[dst_mem_idx];
    src_mem_size = src_mem.cur_page_count * src_mem.num_bytes_per_page;
    dst_mem_size = dst_mem.cur_page_count * dst_mem.num_bytes_per_page;

    /* if s + n > the length of mem.data */
    if (src_mem_size < src_offset || src_mem_size - src_offset < len)
        goto out_of_bounds;

    /* if d + n > the length of mem.data */
    if (dst_mem_size < dst_offset || dst_mem_size - dst_offset < len)
        goto out_of_bounds;

    src_addr = src_mem.memory_data + src_offset;
    dst_addr = dst_mem.memory_data + dst_offset;
    /* allowing the destination and source to overlap */
    bh_memmove_s(dst_addr, dst_mem_size - dst_offset, src_addr, len);

    return 0;
out_of_bounds:
    wasm_set_exception(inst, "out of bounds memory access");
    return -1;
}

bool jit_compile_op_memory_copy(JitCompContext* cc, uint src_mem_idx, uint dst_mem_idx) {
    JitReg len = void, src = void, dst = void, res = void;
    JitReg[6] args = 0;

    POP_I32(len);
    POP_I32(src);
    POP_I32(dst);

    res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, src_mem_idx);
    args[2] = NEW_CONST(I32, dst_mem_idx);
    args[3] = len;
    args[4] = src;
    args[5] = dst;

    if (!jit_emit_callnative(cc, &wasm_copy_memory, res, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;

    GEN_INSN(CMP, cc.cmp_reg, res, NEW_CONST(I32, 0));
    if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BLTS, cc.cmp_reg,
                            null))
        goto fail;

    return true;
fail:
    return false;
}

private int wasm_fill_memory(WASMModuleInstance* inst, uint mem_idx, uint len, uint val, uint dst) {
    WASMMemoryInstance* mem_inst = void;
    uint mem_size = void;
    ubyte* dst_addr = void;

    mem_inst = inst.memories[mem_idx];
    mem_size = mem_inst.cur_page_count * mem_inst.num_bytes_per_page;

    if (mem_size < dst || mem_size - dst < len)
        goto out_of_bounds;

    dst_addr = mem_inst.memory_data + dst;
    memset(dst_addr, val, len);

    return 0;
out_of_bounds:
    wasm_set_exception(inst, "out of bounds memory access");
    return -1;
}

bool jit_compile_op_memory_fill(JitCompContext* cc, uint mem_idx) {
    JitReg res = void, len = void, val = void, dst = void;
    JitReg[5] args = 0;

    POP_I32(len);
    POP_I32(val);
    POP_I32(dst);

    res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, mem_idx);
    args[2] = len;
    args[3] = val;
    args[4] = dst;

    if (!jit_emit_callnative(cc, &wasm_fill_memory, res, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;

    GEN_INSN(CMP, cc.cmp_reg, res, NEW_CONST(I32, 0));
    if (!jit_emit_exception(cc, EXCE_ALREADY_THROWN, JIT_OP_BLTS, cc.cmp_reg,
                            null))
        goto fail;

    return true;
fail:
    return false;
}
}

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
bool jit_compile_op_atomic_rmw(JitCompContext* cc, ubyte atomic_op, ubyte op_type, uint align_, uint offset, uint bytes) {
    return false;
}

bool jit_compile_op_atomic_cmpxchg(JitCompContext* cc, ubyte op_type, uint align_, uint offset, uint bytes) {
    return false;
}

bool jit_compile_op_atomic_wait(JitCompContext* cc, ubyte op_type, uint align_, uint offset, uint bytes) {
    return false;
}

bool jit_compiler_op_atomic_notify(JitCompContext* cc, uint align_, uint offset, uint bytes) {
    return false;
}
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...jit_compiler;
static if (WASM_ENABLE_SHARED_MEMORY != 0) {
public import ......common.wasm_shared_memory;
}

version (none) {
extern "C" {
//! #endif

bool jit_compile_op_i32_load(JitCompContext* cc, uint align_, uint offset, uint bytes, bool sign, bool atomic);

bool jit_compile_op_i64_load(JitCompContext* cc, uint align_, uint offset, uint bytes, bool sign, bool atomic);

bool jit_compile_op_f32_load(JitCompContext* cc, uint align_, uint offset);

bool jit_compile_op_f64_load(JitCompContext* cc, uint align_, uint offset);

bool jit_compile_op_i32_store(JitCompContext* cc, uint align_, uint offset, uint bytes, bool atomic);

bool jit_compile_op_i64_store(JitCompContext* cc, uint align_, uint offset, uint bytes, bool atomic);

bool jit_compile_op_f32_store(JitCompContext* cc, uint align_, uint offset);

bool jit_compile_op_f64_store(JitCompContext* cc, uint align_, uint offset);

bool jit_compile_op_memory_size(JitCompContext* cc, uint mem_idx);

bool jit_compile_op_memory_grow(JitCompContext* cc, uint mem_idx);

static if (WASM_ENABLE_BULK_MEMORY != 0) {
bool jit_compile_op_memory_init(JitCompContext* cc, uint mem_idx, uint seg_idx);

bool jit_compile_op_data_drop(JitCompContext* cc, uint seg_idx);

bool jit_compile_op_memory_copy(JitCompContext* cc, uint src_mem_idx, uint dst_mem_idx);

bool jit_compile_op_memory_fill(JitCompContext* cc, uint mem_idx);
}

static if (WASM_ENABLE_SHARED_MEMORY != 0) {
bool jit_compile_op_atomic_rmw(JitCompContext* cc, ubyte atomic_op, ubyte op_type, uint align_, uint offset, uint bytes);

bool jit_compile_op_atomic_cmpxchg(JitCompContext* cc, ubyte op_type, uint align_, uint offset, uint bytes);

bool jit_compile_op_atomic_wait(JitCompContext* cc, ubyte op_type, uint align_, uint offset, uint bytes);

bool jit_compiler_op_atomic_notify(JitCompContext* cc, uint align_, uint offset, uint bytes);
}

version (none) {}
} /* end of extern "C" */
}

 /* end of _JIT_EMIT_MEMORY_H_ */
