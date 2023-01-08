module tagion.iwasm.fast_jit.fe.jit_emit_const;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.fast_jit.jit_frontend;
import tagion.iwasm.fast_jit.jit_ir : JitReg;
import tagion.iwasm.fast_jit.jit_context : JitCompContext;

bool jit_compile_op_i32_const(JitCompContext* cc, int i32_const) {
    JitReg value = cc.new_const_I32(i32_const);
    cc.push_i32(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_const(JitCompContext* cc, long i64_const) {
    JitReg value = cc.new_const_I64(i64_const);
    cc.push_i64(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_f32_const(JitCompContext* cc, float f32_const) {
    JitReg value = cc.new_const_F32(f32_const);
    cc.push_f32(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_f64_const(JitCompContext* cc, double f64_const) {
    JitReg value = cc.new_const_F64(f64_const);
    cc.push_f64(value);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
