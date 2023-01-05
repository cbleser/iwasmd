module jit_emit_variable_tmp;
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
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
//#include "../jit_compiler.h"
bool jit_compile_op_get_local(JitCompContext* cc, uint local_idx);
bool jit_compile_op_set_local(JitCompContext* cc, uint local_idx);
bool jit_compile_op_tee_local(JitCompContext* cc, uint local_idx);
bool jit_compile_op_get_global(JitCompContext* cc, uint global_idx);
bool jit_compile_op_set_global(JitCompContext* cc, uint global_idx, bool is_aux_stack);
//#include "jit_emit_exception.h"
//#include "../jit_frontend.h"
private ubyte get_local_type(const(WASMFunction)* wasm_func, uint local_idx) {
    uint param_count = wasm_func.func_type.param_count;
    return local_idx < param_count
               ? wasm_func.func_type.types[local_idx]
               : wasm_func.local_types[local_idx - param_count];
}
bool jit_compile_op_get_local(JitCompContext* cc, uint local_idx) {
    WASMFunction* wasm_func = cc.cur_wasm_func;
    ushort* local_offsets = wasm_func.local_offsets;
    ushort local_offset = void;
    ubyte local_type = void;
    JitReg value = 0;
    do { if (local_idx >= wasm_func.func_type.param_count + wasm_func.local_count) { jit_set_last_error(cc, "local index out of range"); goto fail; } } while (0);
    local_offset = local_offsets[local_idx];
    local_type = get_local_type(wasm_func, local_idx);
    switch (local_type) {
        case VALUE_TYPE_I32:
            value = local_i32(cc.jit_frame, local_offset);
            break;
        case VALUE_TYPE_I64:
            value = local_i64(cc.jit_frame, local_offset);
            break;
        case VALUE_TYPE_F32:
            value = local_f32(cc.jit_frame, local_offset);
            break;
        case VALUE_TYPE_F64:
            value = local_f64(cc.jit_frame, local_offset);
            break;
        default:
            bh_assert(0);
            break;
    }
    PUSH(value, local_type);
    return true;
fail:
    return false;
}
bool jit_compile_op_set_local(JitCompContext* cc, uint local_idx) {
    WASMFunction* wasm_func = cc.cur_wasm_func;
    ushort* local_offsets = wasm_func.local_offsets;
    ushort local_offset = void;
    ubyte local_type = void;
    JitReg value = void;
    do { if (local_idx >= wasm_func.func_type.param_count + wasm_func.local_count) { jit_set_last_error(cc, "local index out of range"); goto fail; } } while (0);
    local_offset = local_offsets[local_idx];
    local_type = get_local_type(wasm_func, local_idx);
    switch (local_type) {
        case VALUE_TYPE_I32:
            POP_I32(value);
            set_local_i32(cc.jit_frame, local_offset, value);
            break;
        case VALUE_TYPE_I64:
            POP_I64(value);
            set_local_i64(cc.jit_frame, local_offset, value);
            break;
        case VALUE_TYPE_F32:
            POP_F32(value);
            set_local_f32(cc.jit_frame, local_offset, value);
            break;
        case VALUE_TYPE_F64:
            POP_F64(value);
            set_local_f64(cc.jit_frame, local_offset, value);
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
    ubyte local_type = void;
    JitReg value = 0;
    do { if (local_idx >= wasm_func.func_type.param_count + wasm_func.local_count) { jit_set_last_error(cc, "local index out of range"); goto fail; } } while (0);
    local_offset = local_offsets[local_idx];
    local_type = get_local_type(wasm_func, local_idx);
    switch (local_type) {
        case VALUE_TYPE_I32:
            POP_I32(value);
            set_local_i32(cc.jit_frame, local_offset, value);
            PUSH_I32(value);
            break;
        case VALUE_TYPE_I64:
            POP_I64(value);
            set_local_i64(cc.jit_frame, local_offset, value);
            PUSH_I64(value);
            break;
        case VALUE_TYPE_F32:
            POP_F32(value);
            set_local_f32(cc.jit_frame, local_offset, value);
            PUSH_F32(value);
            break;
        case VALUE_TYPE_F64:
            POP_F64(value);
            set_local_f64(cc.jit_frame, local_offset, value);
            PUSH_F64(value);
            break;
        default:
            bh_assert(0);
            goto fail;
    }
    return true;
fail:
    return false;
}
private ubyte get_global_type(const(WASMModule)* module_, uint global_idx) {
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
    ubyte global_type = 0;
    JitReg value = 0;
    bh_assert(global_idx < cc.cur_wasm_module.import_global_count
                               + cc.cur_wasm_module.global_count);
    data_offset =
        jit_frontend_get_global_data_offset(cc.cur_wasm_module, global_idx);
    global_type = get_global_type(cc.cur_wasm_module, global_idx);
    switch (global_type) {
        case VALUE_TYPE_I32:
        {
            value = jit_cc_new_reg_I32(cc);
            GEN_INSN(LDI32, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        case VALUE_TYPE_I64:
        {
            value = jit_cc_new_reg_I64(cc);
            GEN_INSN(LDI64, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        case VALUE_TYPE_F32:
        {
            value = jit_cc_new_reg_F32(cc);
            GEN_INSN(LDF32, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        case VALUE_TYPE_F64:
        {
            value = jit_cc_new_reg_F64(cc);
            GEN_INSN(LDF64, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        default:
        {
            jit_set_last_error(cc, "unexpected global type");
            goto fail;
        }
    }
    PUSH(value, global_type);
    return true;
fail:
    return false;
}
bool jit_compile_op_set_global(JitCompContext* cc, uint global_idx, bool is_aux_stack) {
    uint data_offset = void;
    ubyte global_type = 0;
    JitReg value = 0;
    bh_assert(global_idx < cc.cur_wasm_module.import_global_count
                               + cc.cur_wasm_module.global_count);
    data_offset =
        jit_frontend_get_global_data_offset(cc.cur_wasm_module, global_idx);
    global_type = get_global_type(cc.cur_wasm_module, global_idx);
    switch (global_type) {
        case VALUE_TYPE_I32:
        {
            POP_I32(value);
            if (is_aux_stack) {
                JitReg aux_stack_bound = get_aux_stack_bound_reg(cc.jit_frame);
                JitReg aux_stack_bottom = get_aux_stack_bottom_reg(cc.jit_frame);
                GEN_INSN(CMP, cc.cmp_reg, value, aux_stack_bound);
                if (!(jit_emit_exception(cc, EXCE_AUX_STACK_OVERFLOW,
                                         JIT_OP_BLEU, cc.cmp_reg, null)))
                    goto fail;
                GEN_INSN(CMP, cc.cmp_reg, value, aux_stack_bottom);
                if (!(jit_emit_exception(cc, EXCE_AUX_STACK_UNDERFLOW,
                                         JIT_OP_BGTU, cc.cmp_reg, null)))
                    goto fail;
            }
            GEN_INSN(STI32, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        case VALUE_TYPE_I64:
        {
            POP_I64(value);
            GEN_INSN(STI64, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        case VALUE_TYPE_F32:
        {
            POP_F32(value);
            GEN_INSN(STF32, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        case VALUE_TYPE_F64:
        {
            POP_F64(value);
            GEN_INSN(STF64, value, get_module_inst_reg(cc.jit_frame),
                     NEW_CONST(I32, data_offset));
            break;
        }
        default:
        {
            jit_set_last_error(cc, "unexpected global type");
            goto fail;
        }
    }
    return true;
fail:
    return false;
}
