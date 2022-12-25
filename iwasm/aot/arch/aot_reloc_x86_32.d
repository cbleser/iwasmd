module aot_reloc_x86_32;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_reloc;

enum R_386_32 = 1    /* Direct 32 bit  */;
enum R_386_PC32 = 2  /* PC relative 32 bit */;
enum R_386_PLT32 = 4 /* 32-bit address ProcedureLinkageTable */;

static if (!HasVersion!"Windows" && !HasVersion!"_WIN32_") {
/* clang-format off */
void __divdi3();
void __udivdi3();
void __moddi3();
void __umoddi3();
/* clang-format on */
} else {
#pragma function(floor)
#pragma function(ceil)

private long __divdi3(long a, long b) {
    return a / b;
}

private ulong __udivdi3(ulong a, ulong b) {
    return a / b;
}

private long __moddi3(long a, long b) {
    return a % b;
}

private ulong __umoddi3(ulong a, ulong b) {
    return a % b;
}
}

/* clang-format off */
private SymbolMap[4] target_sym_map = [
    REG_COMMON_SYMBOLS
    /* compiler-rt symbols that come from compiler(e.g. gcc) */
    REG_SYM(&__divdi3),
    REG_SYM(&__udivdi3),
    REG_SYM(&__moddi3),
    REG_SYM(&__umoddi3)
];
/* clang-format on */

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null)
        snprintf(error_buf, error_buf_size, "%s", string);
}

SymbolMap* get_target_symbol_map(uint* sym_num) {
    *sym_num = target_sym_map.sizeof / SymbolMap.sizeof;
    return target_sym_map;
}

void get_current_target(char* target_buf, uint target_buf_size) {
    snprintf(target_buf, target_buf_size, "i386");
}

uint get_plt_table_size() {
    return 0;
}

void init_plt_table(ubyte* plt) {
    cast(void)plt;
}

private bool check_reloc_offset(uint target_section_size, ulong reloc_offset, uint reloc_data_size, char* error_buf, uint error_buf_size) {
    if (!(reloc_offset < cast(ulong)target_section_size
          && reloc_offset + reloc_data_size <= cast(ulong)target_section_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "AOT module load failed: invalid relocation offset.");
        return false;
    }
    return true;
}

bool apply_relocation(AOTModule* module_, ubyte* target_section_addr, uint target_section_size, ulong reloc_offset, long reloc_addend, uint reloc_type, void* symbol_addr, int symbol_index, char* error_buf, uint error_buf_size) {
    switch (reloc_type) {
        case R_386_32:
        {
            intptr_t value = void;

            CHECK_RELOC_OFFSET((void*).sizeof);
            value = *cast(intptr_t*)(target_section_addr + cast(uint)reloc_offset);
            *cast(uintptr_t*)(target_section_addr + reloc_offset) =
                cast(uintptr_t)symbol_addr + cast(intptr_t)reloc_addend
                + value; /* S + A */
            break;
        }

        /*
         * Handle R_386_PLT32 like R_386_PC32 since it should be able to reach
         * any 32 bit address
         */
        case R_386_PLT32:
        case R_386_PC32:
        {
            int value = void;

            CHECK_RELOC_OFFSET((void*).sizeof);
            value = *cast(int*)(target_section_addr + cast(uint)reloc_offset);
            *cast(uint*)(target_section_addr + cast(uint)reloc_offset) =
                (uint32)(cast(uintptr_t)symbol_addr + cast(intptr_t)reloc_addend
                         - cast(uintptr_t)(target_section_addr
                                       + cast(uint)reloc_offset)
                         + value); /* S + A - P */
            break;
        }

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
