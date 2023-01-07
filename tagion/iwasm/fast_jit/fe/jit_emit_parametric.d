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
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_ir :  JitReg;
public import tagion.iwasm.fast_jit.jit_frontend;
private bool pop_value_from_wasm_stack(JitCompContext* cc, bool is_32bit, JitReg* p_value, ubyte* p_type) {
    JitValue* jit_value = void;
    JitReg value = void;
    ubyte type = void;
    if (!jit_block_stack_top(&cc.block_stack)) {
        jit_set_last_error(cc, "WASM block stack underflow.");
        return false;
    }
    if (!jit_block_stack_top(&cc.block_stack).value_stack.value_list_end) {
        jit_set_last_error(cc, "WASM data stack underflow.");
        return false;
    }
    jit_value = jit_value_stack_pop(
        &jit_block_stack_top(&cc.block_stack).value_stack);
    type = jit_value.type;
    if (p_type != null) {
        *p_type = jit_value.type;
    }
    wasm_runtime_free(jit_value);
    /* is_32: i32, f32, ref.func, ref.extern, v128 */
    if (is_32bit
        && !(type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32
|| ((WASM_ENABLE_REF_TYPES != 0)
             && ( type == VALUE_TYPE_FUNCREF || type == VALUE_TYPE_EXTERNREF))
             || type == VALUE_TYPE_V128)) {
        jit_set_last_error(cc, "invalid WASM stack data type.");
        return false;
    }
    /* !is_32: i64, f64 */
    if (!is_32bit && !(type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64)) {
        jit_set_last_error(cc, "invalid WASM stack data type.");
        return false;
    }
    switch (type) {
        case VALUE_TYPE_I32:
static if (WASM_ENABLE_REF_TYPES != 0) {
        case VALUE_TYPE_FUNCREF:
        case VALUE_TYPE_EXTERNREF:
}
            value = pop_i32(cc.jit_frame);
            break;
        case VALUE_TYPE_I64:
            value = pop_i64(cc.jit_frame);
            break;
        case VALUE_TYPE_F32:
            value = pop_f32(cc.jit_frame);
            break;
        case VALUE_TYPE_F64:
            value = pop_f64(cc.jit_frame);
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
    ubyte val1_type = void, val2_type = void;
    POP_I32(cond);
    if (!pop_value_from_wasm_stack(cc, is_select_32, &val2, &val2_type)
        || !pop_value_from_wasm_stack(cc, is_select_32, &val1, &val1_type)) {
        return false;
    }
    if (val1_type != val2_type) {
        jit_set_last_error(cc, "invalid stack values with different type");
        return false;
    }
    switch (val1_type) {
        case VALUE_TYPE_I32:
            selected = jit_cc_new_reg_I32(cc);
            break;
        case VALUE_TYPE_I64:
            selected = jit_cc_new_reg_I64(cc);
            break;
        case VALUE_TYPE_F32:
            selected = jit_cc_new_reg_F32(cc);
            break;
        case VALUE_TYPE_F64:
            selected = jit_cc_new_reg_F64(cc);
            break;
        default:
            bh_assert(0);
            return false;
    }
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_CMP(cc.cmp_reg, cond, jit_cc_new_const_I32(cc, 0))));
    _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_SELECTNE(selected, cc.cmp_reg, val1, val2)));
    PUSH(selected, val1_type);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
