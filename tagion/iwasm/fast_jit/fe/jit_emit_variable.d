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
module jit_emit_variable_tmp;
@nogc nothrow:
extern (C):
__gshared:
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
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.interpreter.wasm : WASMFunction, WASMModule, ValueType;
import tagion.iwasm.interpreter.wasm_runtime :  EXCE_AUX_STACK_OVERFLOW,EXCE_AUX_STACK_UNDERFLOW ;
import tagion.iwasm.fast_jit.jit_ir : JitReg, JitOpcode,
jit_insn_new_LDI32,
jit_insn_new_LDI64,
jit_insn_new_LDF32,
jit_insn_new_LDF64,
jit_insn_new_CMP,
jit_insn_new_STI32,
jit_insn_new_STI64,
jit_insn_new_STF32,
jit_insn_new_STF64;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.fast_jit.jit_frontend : jit_frontend_get_global_data_offset;
import tagion.iwasm.fast_jit.fe.jit_emit_exception : jit_emit_exception;
import tagion.iwasm.share.utils.bh_assert;

//#include "../jit_compiler.h"
bool jit_compile_op_get_local(JitCompContext* cc, uint local_idx);
bool jit_compile_op_set_local(JitCompContext* cc, uint local_idx);
bool jit_compile_op_tee_local(JitCompContext* cc, uint local_idx);
bool jit_compile_op_get_global(JitCompContext* cc, uint global_idx);
bool jit_compile_op_set_global(JitCompContext* cc, uint global_idx, bool is_aux_stack);
//#include "jit_emit_exception.h"
//#include "../jit_frontend.h"
private ValueType get_local_type(const(WASMFunction)* wasm_func, uint local_idx) {
    const param_count = wasm_func.func_type.param_count;
    return local_idx < param_count
        ? wasm_func.func_type.types[local_idx] : wasm_func.local_types[local_idx - param_count];
}

bool jit_compile_op_get_local(JitCompContext* cc, uint local_idx) {
    WASMFunction* wasm_func = cc.cur_wasm_func;
    ushort* local_offsets = wasm_func.local_offsets;
    ushort local_offset = void;
    ValueType local_type = void;
    JitReg value = 0;
    do {
        if (local_idx >= wasm_func.func_type.param_count + wasm_func.local_count) {
            cc.jit_set_last_error("local index out of range");
            goto fail;
        }
    }
    while (0);
    local_offset = local_offsets[local_idx];
    local_type = get_local_type(wasm_func, local_idx);
    switch (local_type) {
    case ValueType.I32:
        value = cc.jit_frame.local_i32(local_offset);
        break;
    case ValueType.I64:
        value = cc.jit_frame.local_i64(local_offset);
        break;
    case ValueType.F32:
        value = cc.jit_frame.local_f32(local_offset);
        break;
    case ValueType.F64:
        value = cc.jit_frame.local_f64(local_offset);
        break;
    default:
        bh_assert(0);
        break;
    }
    cc.push(value, local_type);
    return true;
fail:
    return false;
}

bool jit_compile_op_set_local(JitCompContext* cc, uint local_idx) {
    WASMFunction* wasm_func = cc.cur_wasm_func;
    ushort* local_offsets = wasm_func.local_offsets;
    ushort local_offset = void;
    ValueType local_type = void;
    JitReg value = void;
    do {
        if (local_idx >= wasm_func.func_type.param_count + wasm_func.local_count) {
            cc.jit_set_last_error("local index out of range");
            goto fail;
        }
    }
    while (0);
    local_offset = local_offsets[local_idx];
    local_type = get_local_type(wasm_func, local_idx);
    switch (local_type) {
    case ValueType.I32:
        cc.pop_i32(value);
        cc.jit_frame.set_local_i32(local_offset, value);
        break;
    case ValueType.I64:
        cc.pop_i64(value);
        cc.jit_frame.set_local_i64(local_offset, value);
        break;
    case ValueType.F32:
        cc.pop_f32(value);
        cc.jit_frame.set_local_f32(local_offset, value);
        break;
    case ValueType.F64:
        cc.pop_f64(value);
        cc.jit_frame.set_local_f64(local_offset, value);
        break;
    default:
        bh_assert(0);
        break;
    }
    return true;
fail:
    return false;
}

bool jit_compile_op_tee_local(JitCompContext* cc, uint local_idx) {
    WASMFunction* wasm_func = cc.cur_wasm_func;
    ushort* local_offsets = wasm_func.local_offsets;
    ushort local_offset = void;
    ValueType local_type = void;
    JitReg value = 0;
    do {
        if (local_idx >= wasm_func.func_type.param_count + wasm_func.local_count) {
            cc.jit_set_last_error("local index out of range");
            goto fail;
        }
    }
    while (0);
    local_offset = local_offsets[local_idx];
    local_type = get_local_type(wasm_func, local_idx);
    switch (local_type) {
    case ValueType.I32:
        cc.pop_i32(value);
        cc.jit_frame.set_local_i32(local_offset, value);
        cc.push_i32(value);
        break;
    case ValueType.I64:
        cc.pop_i64(value);
        cc.jit_frame.set_local_i64(local_offset, value);
        cc.push_i64(value);
        break;
    case ValueType.F32:
        cc.pop_f32(value);
        cc.jit_frame.set_local_f32(local_offset, value);
        cc.push_f32(value);
        break;
    case ValueType.F64:
        cc.pop_f64(value);
        cc.jit_frame.set_local_f64(local_offset, value);
        cc.push_f64(value);
        break;
    default:
        bh_assert(0);
        goto fail;
    }
    return true;
fail:
    return false;
}

ValueType get_global_type(const(WASMModule)* module_, uint global_idx) {
    if (global_idx < module_.import_global_count) {
        const(WASMGlobalImport)* import_global = &((module_.import_globals + global_idx).u.global);
        return import_global.type;
    }
    else {
        const(WASMGlobal)* global = module_.globals + (global_idx - module_.import_global_count);
        return global.type;
    }
}

bool jit_compile_op_get_global(JitCompContext* cc, uint global_idx) {
    uint data_offset = void;
    ValueType global_type;
    JitReg value = 0;
    bh_assert(global_idx < cc.cur_wasm_module.import_global_count
            + cc.cur_wasm_module.global_count);
    data_offset =
        jit_frontend_get_global_data_offset(cc.cur_wasm_module, global_idx);
    global_type = get_global_type(cc.cur_wasm_module, global_idx);
    switch (global_type) {
    case ValueType.I32: {
            value = cc.new_reg_I32;
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_LDI32(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    case ValueType.I64: {
            value = cc.new_reg_I64;
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_LDI64(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    case ValueType.F32: {
            value = cc.new_reg_F32;
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_LDF32(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    case ValueType.F64: {
            value = cc.new_reg_F64;
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_LDF64(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    default: {
            cc.jit_set_last_error("unexpected global type");
            goto fail;
        }
    }
    cc.push(value, global_type);
    return true;
fail:
    return false;
}

bool jit_compile_op_set_global(JitCompContext* cc, uint global_idx, bool is_aux_stack) {
    uint data_offset = void;
    ValueType global_type;
    JitReg value = 0;
    bh_assert(global_idx < cc.cur_wasm_module.import_global_count
            + cc.cur_wasm_module.global_count);
    data_offset =
        jit_frontend_get_global_data_offset(cc.cur_wasm_module, global_idx);
    global_type = get_global_type(cc.cur_wasm_module, global_idx);
    switch (global_type) {
    case ValueType.I32: {
            cc.pop_i32(value);
            if (is_aux_stack) {
                JitReg aux_stack_bound = cc.jit_frame.aux_stack_bound_reg;
                JitReg aux_stack_bottom = cc.jit_frame.aux_stack_bottom_reg;
                cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_CMP(cc.cmp_reg, value, aux_stack_bound)));
                if (!(jit_emit_exception(cc, EXCE_AUX_STACK_OVERFLOW,
                        JitOpcode.JIT_OP_BLEU, cc.cmp_reg, null)))
                    goto fail;
                cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_CMP(cc.cmp_reg, value, aux_stack_bottom)));
                if (!(jit_emit_exception(cc, EXCE_AUX_STACK_UNDERFLOW,
                        JitOpcode.JIT_OP_BGTU, cc.cmp_reg, null)))
                    goto fail;
            }
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_STI32(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    case ValueType.I64: {
            cc.pop_i64(value);
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_STI64(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    case ValueType.F32: {
            cc.pop_f32(value);
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_STF32(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    case ValueType.F64: {
            cc.pop_f64(value);
            cc._gen_insn(cc._set_insn_uid_for_new_insn(jit_insn_new_STF64(value,
			cc.jit_frame.module_inst_reg, cc.new_const_I32(data_offset))));
            break;
        }
    default: {
            cc.jit_set_last_error("unexpected global type");
            goto fail;
        }
    }
    return true;
fail:
    return false;
}
