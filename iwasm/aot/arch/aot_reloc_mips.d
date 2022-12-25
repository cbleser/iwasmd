module aot_reloc_mips;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_reloc;

enum R_MIPS_32 = 2 /* Direct 32 bit */;
enum R_MIPS_26 = 4 /* Direct 26 bit shifted */;

/* clang-format off */
private SymbolMap[1] target_sym_map = [
    REG_COMMON_SYMBOLS
];
/* clang-format on */

SymbolMap* get_target_symbol_map(uint* sym_num) {
    *sym_num = target_sym_map.sizeof / SymbolMap.sizeof;
    return target_sym_map;
}

void get_current_target(char* target_buf, uint target_buf_size) {
    snprintf(target_buf, target_buf_size, "mips");
}

private uint get_plt_item_size() {
    return 0;
}

void init_plt_table(ubyte* plt) {
    cast(void)plt;
}

uint get_plt_table_size() {
    return get_plt_item_size() * (target_sym_map.sizeof / SymbolMap.sizeof);
}

bool apply_relocation(AOTModule* module_, ubyte* target_section_addr, uint target_section_size, ulong reloc_offset, long reloc_addend, uint reloc_type, void* symbol_addr, int symbol_index, char* error_buf, uint error_buf_size) {
    switch (reloc_type) {
        /* TODO: implement relocation for mips */
        case R_MIPS_26:
        case R_MIPS_32:

        default:
            if (error_buf != null)
                snprintf(error_buf, error_buf_size,
                         "Load relocation section failed: "
                         ~ "invalid relocation type %d.",
                         reloc_type);
            return false;
    }

    return true;
}
