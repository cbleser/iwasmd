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
module tagion.iwasm.fast_jit.fe.jit_emit_table;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.basic;
public import tagion.iwasm.fast_jit.fe.jit_emit_exception;
public import tagion.iwasm.fast_jit.fe.jit_emit_function;
public import tagion.iwasm.interpreter.wasm_runtime;
public import tagion.iwasm.fast_jit.jit_frontend;
static if (ver.WASM_ENABLE_REF_TYPES) {
bool jit_compile_op_elem_drop(JitCompContext* cc, uint tbl_seg_idx) {
    JitReg module_ = void, tbl_segs = void;
    module_ = get_module_reg(cc.jit_frame);
    tbl_segs = jit_cc_new_reg_ptr(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(tbl_segs, module_, jit_cc_new_const_I32(cc, WASMModule.table_segments.offsetof))));
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(jit_cc_new_const_I32(cc, true), tbl_segs, jit_cc_new_const_I32(cc, tbl_seg_idx * sizeof(WASMTableSeg) + WASMTableSeg.is_dropped.offsetof))));
    return true;
}
bool jit_compile_op_table_get(JitCompContext* cc, uint tbl_idx) {
    JitReg elem_idx = void, tbl_sz = void, tbl_elems = void, elem_idx_long = void, offset = void, res = void;
    POP_I32(elem_idx);
    /* if (elem_idx >= tbl_sz) goto exception; */
    tbl_sz = get_table_cur_size_reg(cc.jit_frame, tbl_idx);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, elem_idx, tbl_sz)));
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS, JIT_OP_BGEU,
                            cc.cmp_reg, null))
        goto fail;
    elem_idx_long = jit_cc_new_reg_I64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(elem_idx_long, elem_idx)));
    offset = jit_cc_new_reg_I64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MUL(offset, elem_idx_long, jit_cc_new_const_I64(cc, uint32.sizeof))));
    res = jit_cc_new_reg_I32(cc);
    tbl_elems = get_table_elems_reg(cc.jit_frame, tbl_idx);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(res, tbl_elems, offset)));
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
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, elem_idx, tbl_sz)));
    if (!jit_emit_exception(cc, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS, JIT_OP_BGEU,
                            cc.cmp_reg, null))
        goto fail;
    elem_idx_long = jit_cc_new_reg_I64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_I32TOI64(elem_idx_long, elem_idx)));
    offset = jit_cc_new_reg_I64(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_MUL(offset, elem_idx_long, jit_cc_new_const_I64(cc, uint32.sizeof))));
    tbl_elems = get_table_elems_reg(cc.jit_frame, tbl_idx);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(elem_val, tbl_elems, offset)));
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
                cast(uint)((tbl_sz - dst) * uint32.sizeof),
                elem.func_indexes + src, cast(uint)(len * uint32.sizeof));
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
    args[1] = jit_cc_new_const_I32(cc, tbl_idx);
    args[2] = jit_cc_new_const_I32(cc, tbl_seg_idx);
    args[3] = dst;
    args[4] = len;
    args[5] = src;
    if (!jit_emit_callnative(cc, &wasm_init_table, res, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, res, jit_cc_new_const_I32(cc, 0))));
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
                 cast(uint)((dst_tbl_sz - dst_offset) * uint32.sizeof),
                 cast(ubyte*)src_tbl + WASMTableInstance.elems.offsetof
                     + src_offset * uint32.sizeof,
                 cast(uint)(len * uint32.sizeof));
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
    args[1] = jit_cc_new_const_I32(cc, src_tbl_idx);
    args[2] = jit_cc_new_const_I32(cc, dst_tbl_idx);
    args[3] = dst;
    args[4] = len;
    args[5] = src;
    if (!jit_emit_callnative(cc, &wasm_copy_table, res, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, res, jit_cc_new_const_I32(cc, 0))));
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
    args[1] = jit_cc_new_const_I32(cc, tbl_idx);
    args[2] = n;
    args[3] = val;
    if (!jit_emit_callnative(cc, wasm_enlarge_table, enlarge_ret, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;
    /* Convert bool to uint32 */
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_AND(enlarge_ret, enlarge_ret, jit_cc_new_const_I32(cc, 0xFF))));
    res = jit_cc_new_reg_I32(cc);
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, enlarge_ret, jit_cc_new_const_I32(cc, 1))));
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTEQ(res, cc.cmp_reg, tbl_sz, jit_cc_new_const_I32(cc, -1))));
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
    args[1] = jit_cc_new_const_I32(cc, tbl_idx);
    args[2] = dst;
    args[3] = val;
    args[4] = len;
    if (!jit_emit_callnative(cc, &wasm_fill_table, res, args.ptr,
                             args.sizeof / typeof(args[0]).sizeof))
        goto fail;
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, res, jit_cc_new_const_I32(cc, 0))));
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
