module wasm_interp;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import wasm;

version (none) {
extern "C" {
//! #endif

struct WASMModuleInstance;;
struct WASMFunctionInstance;;
struct WASMExecEnv;;

struct WASMInterpFrame {
    /* The frame of the caller that are calling the current function. */
    WASMInterpFrame* prev_frame;

    /* The current WASM function. */
    WASMFunctionInstance* function_;

    /* Instruction pointer of the bytecode array.  */
    ubyte* ip;

static if (WASM_ENABLE_FAST_JIT != 0) {
    ubyte* jitted_return_addr;
}

static if (WASM_ENABLE_PERF_PROFILING != 0) {
    ulong time_started;
}

static if (WASM_ENABLE_FAST_INTERP != 0) {
    /* Return offset of the first return value of current frame,
       the callee will put return values here continuously */
    uint ret_offset;
    uint* lp;
    uint[1] operand;
} else {
    /* Operand stack top pointer of the current frame. The bottom of
       the stack is the next cell after the last local variable. */
    uint* sp_bottom;
    uint* sp_boundary;
    uint* sp;

    WASMBranchBlock* csp_bottom;
    WASMBranchBlock* csp_boundary;
    WASMBranchBlock* csp;

    /**
     * Frame data, the layout is:
     *  lp: parameters and local variables
     *  sp_bottom to sp_boundary: wasm operand stack
     *  csp_bottom to csp_boundary: wasm label stack
     *  jit spill cache: only available for fast jit
     */
    uint[1] lp;
}
}

/**
 * Calculate the size of interpreter area of frame of a function.
 *
 * @param all_cell_num number of all cells including local variables
 * and the working stack slots
 *
 * @return the size of interpreter area of the frame
 */
pragma(inline, true) private uint wasm_interp_interp_frame_size(uint all_cell_num) {
    uint frame_size = void;

static if (WASM_ENABLE_FAST_INTERP == 0) {
    frame_size = cast(uint)WASMInterpFrame.lp.offsetof + all_cell_num * 4;
} else {
    frame_size = cast(uint)WASMInterpFrame.operand.offsetof + all_cell_num * 4;
}
    return align_uint(frame_size, 4);
}

void wasm_interp_call_wasm(WASMModuleInstance* module_inst, WASMExecEnv* exec_env, WASMFunctionInstance* function_, uint argc, uint* argv);

version (none) {}
}
}

 /* end of _WASM_INTERP_H */
