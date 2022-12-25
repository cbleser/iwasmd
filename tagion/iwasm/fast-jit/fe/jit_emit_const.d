module jit_emit_const;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_emit_const;
public import ...jit_frontend;

bool jit_compile_op_i32_const(JitCompContext* cc, int i32_const) {
    JitReg value = NEW_CONST(I32, i32_const);
    PUSH_I32(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_i64_const(JitCompContext* cc, long i64_const) {
    JitReg value = NEW_CONST(I64, i64_const);
    PUSH_I64(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_f32_const(JitCompContext* cc, float32 f32_const) {
    JitReg value = NEW_CONST(F32, f32_const);
    PUSH_F32(value);
    return true;
fail:
    return false;
}

bool jit_compile_op_f64_const(JitCompContext* cc, float64 f64_const) {
    JitReg value = NEW_CONST(F64, f64_const);
    PUSH_F64(value);
    return true;
fail:
    return false;
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import ...jit_compiler;

version (none) {
extern "C" {
//! #endif

bool jit_compile_op_i32_const(JitCompContext* cc, int i32_const);

bool jit_compile_op_i64_const(JitCompContext* cc, long i64_const);

bool jit_compile_op_f32_const(JitCompContext* cc, float32 f32_const);

bool jit_compile_op_f64_const(JitCompContext* cc, float64 f64_const);

version (none) {}
} /* end of extern "C" */
}

 /* end of _JIT_EMIT_CONST_H_ */
