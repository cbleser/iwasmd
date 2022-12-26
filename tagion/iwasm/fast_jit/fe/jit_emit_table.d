module jit_emit_table;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_emit_table;
public import jit_emit_exception;
public import jit_emit_function;
public import ......interpreter.wasm_runtime;
public import ...jit_frontend;

static if (WASM_ENABLE_REF_TYPES != 0) {
bool jit_compile_op_elem_drop(JitCompContext* cc, uint tbl_seg_idx) {
    JitReg module_ = void, tbl_segs = void;

    module_ = get_module_reg(cc.jit_frame);

    tbl_segs = jit_cc_new_reg_ptr(cc);
    GEN_INSN(LDPTR, tbl_segs, module_,
             NEW_CONST(I32, WASMModule.table_segments.offsetof));

    GEN_INSN(STI32, NEW_CONST(I32, true), tbl_segs,
             NEW_CONST(I32, tbl_seg_idx * sizeof(WASMTableSeg)
                                + WASMTableSeg.is_dropped.offsetof));
    return true;
}

bool jit_compile_op_table_get(JitCompContext* cc, uint tbl_idx) {
    JitReg elem_idx = void, tbl_sz = void, tbl_elems = void, elem_idx_long = void, offset = void, res = void;

    POP_I32(elem_idx);

    /* if (elem_idx >= tbl_sz) goto exception; */
    tbl_sz = get_table_cur_size_reg(cc.jit_frame, tbl_idx);
    GEN_INSN(CMP, cc.cmp_reg, elem_idx, tbl_sz);
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS, JIT_OP_BGEU,
                            cc.cmp_reg, null))
        goto fail;

    elem_idx_long = jit_cc_new_reg_I64(cc);
    GEN_INSN(I32TOI64, elem_idx_long, elem_idx);

    offset = jit_cc_new_reg_I64(cc);
    GEN_INSN(MUL, offset, elem_idx_long, NEW_CONST(I64, uint32.sizeof));

    res = jit_cc_new_reg_I32(cc);
    tbl_elems = get_table_elems_reg(cc.jit_frame, tbl_idx);
    GEN_INSN(LDI32, res, tbl_elems, offset);
    PUSH_I32(res);

    return true;
fail:
    return false;
}

bool jit_compile_op_table_set(JitCompContext* cc, uint tbl_idx) {
    JitReg elem_idx = void, elem_val = void, tbl_sz = void, tbl_elems = void, elem_idx_long = void, offset = void;

    POP_I32(elem_val);
    POP_I32(elem_idx);

    /* if (elem_idx >= tbl_sz) goto exception; */
    tbl_sz = get_table_cur_size_reg(cc.jit_frame, tbl_idx);
    GEN_INSN(CMP, cc.cmp_reg, elem_idx, tbl_sz);
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS, JIT_OP_BGEU,
                            cc.cmp_reg, null))
        goto fail;

    elem_idx_long = jit_cc_new_reg_I64(cc);
    GEN_INSN(I32TOI64, elem_idx_long, elem_idx);

    offset = jit_cc_new_reg_I64(cc);
    GEN_INSN(MUL, offset, elem_idx_long, NEW_CONST(I64, uint32.sizeof));

    tbl_elems = get_table_elems_reg(cc.jit_frame, tbl_idx);
    GEN_INSN(STI32, elem_val, tbl_elems, offset);

    return true;
fail:
    return false;
}

private int wasm_init_table(WASMModuleInstance* inst, uint tbl_idx, uint elem_idx, uint dst, uint len, uint src) {
    WASMTableInstance* tbl = void;
    uint tbl_sz = void;
    WASMTableSeg* elem = void;
    uint elem_len = void;

    tbl = inst.tables[tbl_idx];
    tbl_sz = tbl.cur_size;
    if (dst > tbl_sz || tbl_sz - dst < len)
        goto out_of_bounds;

    elem = inst.module_.table_segments + elem_idx;
    elem_len = elem.function_count;
    if (src > elem_len || elem_len - src < len)
        goto out_of_bounds;

    bh_memcpy_s(cast(ubyte*)tbl + WASMTableInstance.elems.offsetof
                    + dst * uint32.sizeof,
                (uint32)((tbl_sz - dst) * uint32.sizeof),
                elem.func_indexes + src, (uint32)(len * uint32.sizeof));

    return 0;
out_of_bounds:
    wasm_set_exception(inst, "out of bounds table access");
    return -1;
}

bool jit_compile_op_table_init(JitCompContext* cc, uint tbl_idx, uint tbl_seg_idx) {
    JitReg len = void, src = void, dst = void, res = void;
    JitReg[6] args = 0;

    POP_I32(len);
    POP_I32(src);
    POP_I32(dst);

    res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, tbl_idx);
    args[2] = NEW_CONST(I32, tbl_seg_idx);
    args[3] = dst;
    args[4] = len;
    args[5] = src;

    if (!jit_emit_callnative(cc, &wasm_init_table, res, args.ptr,
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

private int wasm_copy_table(WASMModuleInstance* inst, uint src_tbl_idx, uint dst_tbl_idx, uint dst_offset, uint len, uint src_offset) {
    WASMTableInstance* src_tbl = void, dst_tbl = void;
    uint src_tbl_sz = void, dst_tbl_sz = void;

    src_tbl = inst.tables[src_tbl_idx];
    src_tbl_sz = src_tbl.cur_size;
    if (src_offset > src_tbl_sz || src_tbl_sz - src_offset < len)
        goto out_of_bounds;

    dst_tbl = inst.tables[dst_tbl_idx];
    dst_tbl_sz = dst_tbl.cur_size;
    if (dst_offset > dst_tbl_sz || dst_tbl_sz - dst_offset < len)
        goto out_of_bounds;

    bh_memmove_s(cast(ubyte*)dst_tbl + WASMTableInstance.elems.offsetof
                     + dst_offset * uint32.sizeof,
                 (uint32)((dst_tbl_sz - dst_offset) * uint32.sizeof),
                 cast(ubyte*)src_tbl + WASMTableInstance.elems.offsetof
                     + src_offset * uint32.sizeof,
                 (uint32)(len * uint32.sizeof));

    return 0;
out_of_bounds:
    wasm_set_exception(inst, "out of bounds table access");
    return -1;
}

bool jit_compile_op_table_copy(JitCompContext* cc, uint src_tbl_idx, uint dst_tbl_idx) {
    JitReg len = void, src = void, dst = void, res = void;
    JitReg[6] args = 0;

    POP_I32(len);
    POP_I32(src);
    POP_I32(dst);

    res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, src_tbl_idx);
    args[2] = NEW_CONST(I32, dst_tbl_idx);
    args[3] = dst;
    args[4] = len;
    args[5] = src;

    if (!jit_emit_callnative(cc, &wasm_copy_table, res, args.ptr,
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

bool jit_compile_op_table_size(JitCompContext* cc, uint tbl_idx) {
    JitReg res = void;

    res = get_table_cur_size_reg(cc.jit_frame, tbl_idx);
    PUSH_I32(res);

    return true;
fail:
    return false;
}

bool jit_compile_op_table_grow(JitCompContext* cc, uint tbl_idx) {
    JitReg tbl_sz = void, n = void, val = void, enlarge_ret = void, res = void;
    JitReg[4] args = 0;

    POP_I32(n);
    POP_I32(val);

    tbl_sz = get_table_cur_size_reg(cc.jit_frame, tbl_idx);

    enlarge_ret = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, tbl_idx);
    args[2] = n;
    args[3] = val;

    if (!jit_emit_callnative(cc, wasm_enlarge_table, enlarge_ret, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;

    /* Convert bool to uint32 */
    GEN_INSN(AND, enlarge_ret, enlarge_ret, NEW_CONST(I32, 0xFF));

    res = jit_cc_new_reg_I32(cc);
    GEN_INSN(CMP, cc.cmp_reg, enlarge_ret, NEW_CONST(I32, 1));
    GEN_INSN(SELECTEQ, res, cc.cmp_reg, tbl_sz, NEW_CONST(I32, -1));
    PUSH_I32(res);

    /* Ensure a refresh in next get memory related registers */
    clear_table_regs(cc.jit_frame);
    return true;
fail:
    return false;
}

private int wasm_fill_table(WASMModuleInstance* inst, uint tbl_idx, uint dst, uint val, uint len) {
    WASMTableInstance* tbl = void;
    uint tbl_sz = void;

    tbl = inst.tables[tbl_idx];
    tbl_sz = tbl.cur_size;

    if (dst > tbl_sz || tbl_sz - dst < len)
        goto out_of_bounds;

    for (; len != 0; dst++, len--) {
        tbl.elems[dst] = val;
    }

    return 0;
out_of_bounds:
    wasm_set_exception(inst, "out of bounds table access");
    return -1;
}

bool jit_compile_op_table_fill(JitCompContext* cc, uint tbl_idx) {
    JitReg len = void, val = void, dst = void, res = void;
    JitReg[5] args = 0;

    POP_I32(len);
    POP_I32(val);
    POP_I32(dst);

    res = jit_cc_new_reg_I32(cc);
    args[0] = get_module_inst_reg(cc.jit_frame);
    args[1] = NEW_CONST(I32, tbl_idx);
    args[2] = dst;
    args[3] = val;
    args[4] = len;

    if (!jit_emit_callnative(cc, &wasm_fill_table, res, args.ptr,
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

/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...jit_compiler;

version (none) {
extern "C" {
//! #endif

static if (WASM_ENABLE_REF_TYPES != 0) {
bool jit_compile_op_elem_drop(JitCompContext* cc, uint tbl_seg_idx);

bool jit_compile_op_table_get(JitCompContext* cc, uint tbl_idx);

bool jit_compile_op_table_set(JitCompContext* cc, uint tbl_idx);

bool jit_compile_op_table_init(JitCompContext* cc, uint tbl_idx, uint tbl_seg_idx);

bool jit_compile_op_table_copy(JitCompContext* cc, uint src_tbl_idx, uint dst_tbl_idx);

bool jit_compile_op_table_size(JitCompContext* cc, uint tbl_idx);

bool jit_compile_op_table_grow(JitCompContext* cc, uint tbl_idx);

bool jit_compile_op_table_fill(JitCompContext* cc, uint tbl_idx);
}

version (none) {}
} /* end of extern "C" */
}

