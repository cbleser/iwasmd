module aot_reloc_x86_64;
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

static if (!HasVersion!"BH_PLATFORM_WINDOWS") {
enum R_X86_64_64 = 1    /* Direct 64 bit  */;
enum R_X86_64_PC32 = 2  /* PC relative 32 bit signed */;
enum R_X86_64_PLT32 = 4 /* 32 bit PLT address */;
enum R_X86_64_32 = 10   /* Direct 32 bit zero extended */;
enum R_X86_64_32S = 11  /* Direct 32 bit sign extended */;
} else {
version (IMAGE_REL_AMD64_ADDR64) {} else {
enum IMAGE_REL_AMD64_ADDR64 = 1 /* The 64-bit VA of the relocation target */;
enum IMAGE_REL_AMD64_ADDR32 = 2 /* The 32-bit VA of the relocation target */;
/* clang-format off */
enum IMAGE_REL_AMD64_REL32 =  4 /* The 32-bit relative address from;
                                    the byte_; following the; relocation*/
/* clang-format on */
}
}

version (BH_PLATFORM_WINDOWS) {
#pragma function(floor)
#pragma function(ceil)
#pragma function(floorf)
#pragma function(ceilf)
}

/* clang-format off */
private SymbolMap[1] target_sym_map = [
    REG_COMMON_SYMBOLS
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
    snprintf(target_buf, target_buf_size, "x86_64");
}

private uint get_plt_item_size() {
    /* size of mov instruction and jmp instruction */
    return 12;
}

uint get_plt_table_size() {
    uint size = get_plt_item_size() * (target_sym_map.sizeof / SymbolMap.sizeof);
static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
    size += get_plt_item_size() + AOTUnwindInfo.sizeof;
}
    return size;
}

void init_plt_table(ubyte* plt) {
    uint i = void, num = target_sym_map.sizeof / SymbolMap.sizeof;
    ubyte* p = void;

    for (i = 0; i < num; i++) {
        p = plt;
        /* mov symbol_addr, rax */
        *p++ = 0x48;
        *p++ = 0xB8;
        *cast(ulong*)p = cast(ulong)cast(uintptr_t)target_sym_map[i].symbol_addr;
        p += uint64.sizeof;
        /* jmp rax */
        *p++ = 0xFF;
        *p++ = 0xE0;
        plt += get_plt_item_size();
    }

static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
    p = plt;
    /* mov exception_handler, rax */
    *p++ = 0x48;
    *p++ = 0xB8;
    *cast(ulong*)p = 0; /*(uint64)(uintptr_t)aot_exception_handler;*/
    p += uint64.sizeof;
    /* jmp rax */
    *p++ = 0xFF;
    *p++ = 0xE0;
}
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
static if (!HasVersion!"BH_PLATFORM_WINDOWS") {
        case R_X86_64_64:
} else {
        case IMAGE_REL_AMD64_ADDR64:
}
        {
            intptr_t value = void;

            CHECK_RELOC_OFFSET((void*).sizeof);
            value = *cast(intptr_t*)(target_section_addr + cast(uint)reloc_offset);
            *cast(uintptr_t*)(target_section_addr + reloc_offset) =
                cast(uintptr_t)symbol_addr + reloc_addend + value; /* S + A */
            break;
        }
version (BH_PLATFORM_WINDOWS) {
        case IMAGE_REL_AMD64_ADDR32:
        {
            int value = void;
            uintptr_t target_addr = void;

            CHECK_RELOC_OFFSET((void*).sizeof);
            value = *cast(int*)(target_section_addr + cast(uint)reloc_offset);
            target_addr = cast(uintptr_t)symbol_addr + reloc_addend + value;
            if (cast(int)target_addr != target_addr) {
                set_error_buf(error_buf, error_buf_size,
                              "AOT module load failed: "
                              ~ "relocation truncated to fit "
                              ~ "IMAGE_REL_AMD64_ADDR32 failed. "
                              ~ "Try using wamrc with --size-level=1 option.");
                return false;
            }

            *cast(int*)(target_section_addr + reloc_offset) = cast(int)target_addr;
            break;
        }
}
static if (!HasVersion!"BH_PLATFORM_WINDOWS") {
        case R_X86_64_PC32:
        {
            intptr_t target_addr = cast(intptr_t) /* S + A - P */
                (cast(uintptr_t)symbol_addr + reloc_addend
                 - cast(uintptr_t)(target_section_addr + reloc_offset));

            CHECK_RELOC_OFFSET(int32.sizeof);
            if (cast(int)target_addr != target_addr) {
                set_error_buf(
                    error_buf, error_buf_size,
                    "AOT module load failed: "
                    ~ "relocation truncated to fit R_X86_64_PC32 failed. "
                    ~ "Try using wamrc with --size-level=1 option.");
                return false;
            }

            *cast(int*)(target_section_addr + reloc_offset) = cast(int)target_addr;
            break;
        }
        case R_X86_64_32:
        case R_X86_64_32S:
        {
            char[128] buf = void;
            uintptr_t target_addr = cast(uintptr_t)symbol_addr + reloc_addend;

            CHECK_RELOC_OFFSET(int32.sizeof);

            if ((reloc_type == R_X86_64_32
                 && cast(uint)target_addr != cast(ulong)target_addr)
                || (reloc_type == R_X86_64_32S
                    && cast(int)target_addr != cast(long)target_addr)) {
                snprintf(buf.ptr, buf.sizeof,
                         "AOT module load failed: "
                         ~ "relocation truncated to fit %s failed. "
                         ~ "Try using wamrc with --size-level=1 option.",
                         reloc_type == R_X86_64_32 ? "R_X86_64_32"
                                                   : "R_X86_64_32S");
                set_error_buf(error_buf, error_buf_size, buf.ptr);
                return false;
            }

            *cast(int*)(target_section_addr + reloc_offset) = cast(int)target_addr;
            break;
        }
}
static if (!HasVersion!"BH_PLATFORM_WINDOWS") {
        case R_X86_64_PLT32:
} else {
        case IMAGE_REL_AMD64_REL32:
}
        {
            ubyte* plt = void;
            intptr_t target_addr = 0;

            CHECK_RELOC_OFFSET(int32.sizeof);

            if (symbol_index >= 0) {
                plt = cast(ubyte*)module_.code + module_.code_size
                      - get_plt_table_size()
                      + get_plt_item_size() * symbol_index;
                target_addr = cast(intptr_t) /* L + A - P */
                    (cast(uintptr_t)plt + reloc_addend
                     - cast(uintptr_t)(target_section_addr + reloc_offset));
            }
            else {
                target_addr = cast(intptr_t) /* L + A - P */
                    (cast(uintptr_t)symbol_addr + reloc_addend
                     - cast(uintptr_t)(target_section_addr + reloc_offset));
            }

version (BH_PLATFORM_WINDOWS) {
            target_addr -= int32.sizeof;
}
            if (cast(int)target_addr != target_addr) {
                set_error_buf(error_buf, error_buf_size,
                              "AOT module load failed: "
                              ~ "relocation truncated to fit "
#if !defined(BH_PLATFORM_WINDOWS)
                              "R_X86_64_PLT32 failed. "
#else
                              ~ "IMAGE_REL_AMD64_32 failed."
#endif
                              ~ "Try using wamrc with --size-level=1 option.");
                return false;
            }
            *cast(int*)(target_section_addr + reloc_offset) = cast(int)target_addr;
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
