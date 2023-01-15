module aot_export;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdint;
public import stdbool;

version (none) {
extern "C" {
//! #endif

struct AOTCompData;;
alias aot_comp_data_t = AOTCompData*;

struct AOTCompContext;;
alias aot_comp_context_t = AOTCompContext*;

aot_comp_data_t aot_create_comp_data(void* wasm_module);

void aot_destroy_comp_data(aot_comp_data_t comp_data);

static if (WASM_ENABLE_DEBUG_AOT != 0) {
alias dwar_extractor_handle_t = void*;
dwar_extractor_handle_t create_dwarf_extractor(aot_comp_data_t comp_data, char* file_name);
}

enum {
    AOT_FORMAT_FILE,
    AOT_OBJECT_FILE,
    AOT_LLVMIR_UNOPT_FILE,
    AOT_LLVMIR_OPT_FILE,
};

struct AOTCompOption {
    bool is_jit_mode;
    bool is_indirect_mode;
    char* target_arch;
    char* target_abi;
    char* target_cpu;
    char* cpu_features;
    bool is_sgx_platform;
    bool enable_bulk_memory;
    bool enable_thread_mgr;
    bool enable_tail_call;
    bool enable_simd;
    bool enable_ref_types;
    bool enable_aux_stack_check;
    bool enable_aux_stack_frame;
    bool disable_llvm_intrinsics;
    bool disable_llvm_lto;
    uint opt_level;
    uint size_level;
    uint output_format;
    uint bounds_checks;
    uint stack_bounds_checks;
    char** custom_sections;
    uint custom_sections_count;
}alias aot_comp_option_t = AOTCompOption*;

bool aot_compiler_init();

void aot_compiler_destroy();

aot_comp_context_t aot_create_comp_context(aot_comp_data_t comp_data, aot_comp_option_t option);

void aot_destroy_comp_context(aot_comp_context_t comp_ctx);

bool aot_compile_wasm(aot_comp_context_t comp_ctx);

bool aot_emit_llvm_file(aot_comp_context_t comp_ctx, const(char)* file_name);

bool aot_emit_object_file(aot_comp_context_t comp_ctx, const(char)* file_name);

bool aot_emit_aot_file(aot_comp_context_t comp_ctx, aot_comp_data_t comp_data, const(char)* file_name);

void aot_destroy_aot_file(ubyte* aot_file);

char* aot_get_last_error();

uint aot_get_plt_table_size();

version (none) {}
}
}

 /* end of _AOT_EXPORT_H */
