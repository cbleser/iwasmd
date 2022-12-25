module dwarf_extractor;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import llvm-c.DebugInfo;

version (none) {
extern "C" {
//! #endif

alias LLDBLangType = uint;
enum string LLDB_TO_LLVM_LANG_TYPE(string lldb_lang_type) = ` \
    (LLVMDWARFSourceLanguage)(((lldb_lang_type) > 0 ? (lldb_lang_type)-1 : 1))`;

struct AOTCompData;;
alias aot_comp_data_t = AOTCompData*;
alias dwar_extractor_handle_t = void*;

struct AOTCompContext;;


struct AOTFuncContext;;


dwar_extractor_handle_t create_dwarf_extractor(aot_comp_data_t comp_data, char* file_name);

LLVMMetadataRef dwarf_gen_file_info(AOTCompContext* comp_ctx);

LLVMMetadataRef dwarf_gen_comp_unit_info(AOTCompContext* comp_ctx);

LLVMMetadataRef dwarf_gen_func_info(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

LLVMMetadataRef dwarf_gen_location(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, ulong vm_offset);

LLVMMetadataRef dwarf_gen_func_ret_location(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx);

void dwarf_get_func_name(AOTCompContext* comp_ctx, AOTFuncContext* func_ctx, char* name, int len);

version (none) {}
}
}


