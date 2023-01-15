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
module tagion.iwasm.fast_jit.fe.jit_emit_parametric;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.basic;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_ir :  JitReg, JitValue,
 jit_insn_new_CMP, jit_insn_new_SELECTNE,
jit_block_stack_top,
jit_block_stack_pop,
jit_value_stack_pop
;
import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_utils;
import tagion.iwasm.interpreter.wasm : ValueType;
import tagion.iwasm.share.utils.bh_assert;

private bool pop_value_from_wasm_stack(JitCompContext* cc, bool is_32bit, JitReg* p_value, ValueType* p_type) {
    JitValue* jit_value = void;
    JitReg value = void;
    ValueType type = void;
    if (!jit_block_stack_top(&cc.block_stack)) {
        cc.jit_set_last_error("WASM block stack underflow.");
        return false;
    }
    if (!jit_block_stack_top(&cc.block_stack).value_stack.value_list_end) {
        cc.jit_set_last_error("WASM data stack underflow.");
        return false;
    }
    jit_value = jit_value_stack_pop(
        &jit_block_stack_top(&cc.block_stack).value_stack);
    type = jit_value.type;
    if (p_type != null) {
        *p_type = jit_value.type;
    }
    jit_free(jit_value);
    /* is_32: i32, f32, ref.func, ref.extern, v128 */
    if (is_32bit
        && !(type == ValueType.I32 || type == ValueType.F32
|| ((ver.WASM_ENABLE_REF_TYPES)
             && ( type == ValueType.FUNCREF || type == ValueType.EXTERNREF))
             || type == ValueType.V128)) {
        cc.jit_set_last_error("invalid WASM stack data type.");
        return false;
    }
    /* !is_32: i64, f64 */
    if (!is_32bit && !(type == ValueType.I64 || type == ValueType.F64)) {
        cc.jit_set_last_error("invalid WASM stack data type.");
        return false;
    }
    switch (type) {
        case ValueType.I32:
static if (ver.WASM_ENABLE_REF_TYPES) {
        case ValueType.FUNCREF:
        case ValueType.EXTERNREF:
}
            cc.pop_i32(value);
            break;
        case ValueType.I64:
            cc.pop_i64(value);
            break;
        case ValueType.F32:
            cc.pop_f32(value);
            break;
        case ValueType.F64:
            cc.pop_f64(value);
            break;
        default:
            bh_assert(0);
            return false;
    }
    if (p_value != null) {
        *p_value = value;
    }
    return true;
}
bool jit_compile_op_drop(JitCompContext* cc, bool is_drop_32) {
    if (!pop_value_from_wasm_stack(cc, is_drop_32, null, null))
        return false;
    return true;
}
bool jit_compile_op_select(JitCompContext* cc, bool is_select_32) {
    JitReg val1 = void, val2 = void, cond = void, selected = void;
    ValueType val1_type = void, val2_type = void;
    cc.pop_i32(cond);
    if (!pop_value_from_wasm_stack(cc, is_select_32, &val2, &val2_type)
        || !pop_value_from_wasm_stack(cc, is_select_32, &val1, &val1_type)) {
        return false;
    }
    if (val1_type != val2_type) {
        cc.jit_set_last_error( "invalid stack values with different type");
        return false;
    }
    switch (val1_type) {
        case ValueType.I32:
            selected = cc.new_reg_I32;
            break;
        case ValueType.I64:
            selected = cc.new_reg_I64;
            break;
        case ValueType.F32:
            selected = cc.new_reg_F32;
            break;
        case ValueType.F64:
            selected = cc.new_reg_F64;
            break;
        default:
            bh_assert(0);
            return false;
    }
    cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_SELECTNE(selected, cc.cmp_reg, val1, val2)));
    cc.push(selected, val1_type);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */