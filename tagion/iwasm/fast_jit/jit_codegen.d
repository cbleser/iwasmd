module tagion.iwasm.fast_jit.jit_codegen;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.fast_jit.jit_compiler;

bool jit_pass_lower_cg(JitCompContext* cc) {
    return jit_codegen_lower(cc);
}

bool jit_pass_codegen(JitCompContext* cc) {
    if (!jit_annl_enable_jitted_addr(cc))
        return false;

    return jit_codegen_gen_native(cc);
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
import tagion.iwasm.app_framework.base.app.bh_platform;
public import tagion.iwasm.fast_jit.jit_compiler;

version (none) {
extern (C) {
//! #endif

/**
 * Initialize codegen module, such as instruction encoder.
 *
 * @return true if succeeded; false if failed.
 */
bool jit_codegen_init();

/**
 * Destroy codegen module, such as instruction encoder.
 */
void jit_codegen_destroy();

/**
 * Get hard register information of each kind.
 *
 * @return the JitHardRegInfo array of each kind
 */
const(JitHardRegInfo)* jit_codegen_get_hreg_info();

/**
 * Get hard register by name.
 *
 * @param name the name of the hard register
 *
 * @return the hard register of the name
 */
JitReg jit_codegen_get_hreg_by_name(const(char)* name);

/**
 * Generate native code for the given compilation context
 *
 * @param cc the compilation context that is ready to do codegen
 *
 * @return true if succeeds, false otherwise
 */
bool jit_codegen_gen_native(JitCompContext* cc);

/**
 * lower unsupported operations to supported ones for the target.
 *
 * @param cc the compilation context that is ready to do codegen
 *
 * @return true if succeeds, false otherwise
 */
bool jit_codegen_lower(JitCompContext* cc);

static if (WASM_ENABLE_LAZY_JIT != 0 && WASM_ENABLE_JIT != 0) {
void* jit_codegen_compile_call_to_llvm_jit(const(WASMType)* func_type);

void* jit_codegen_compile_call_to_fast_jit(const(WASMModule)* module_, uint func_idx);
}

/**
 * Dump native code in the given range to assembly.
 *
 * @param begin_addr begin address of the native code
 * @param end_addr end address of the native code
 */
void jit_codegen_dump_native(void* begin_addr, void* end_addr);

int jit_codegen_interp_jitted_glue(void* self, JitInterpSwitchInfo* info, uint func_idx, void* pc);
}
}

 /* end of _JIT_CODEGEN_H_ */
