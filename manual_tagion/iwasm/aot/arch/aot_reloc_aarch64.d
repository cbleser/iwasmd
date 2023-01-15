module aot_reloc_aarch64;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2020 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_reloc;

enum R_AARCH64_MOVW_UABS_G0 = 263;
enum R_AARCH64_MOVW_UABS_G0_NC = 264;
enum R_AARCH64_MOVW_UABS_G1 = 265;
enum R_AARCH64_MOVW_UABS_G1_NC = 266;
enum R_AARCH64_MOVW_UABS_G2 = 267;
enum R_AARCH64_MOVW_UABS_G2_NC = 268;
enum R_AARCH64_MOVW_UABS_G3 = 269;

enum R_AARCH64_MOVW_SABS_G0 = 270;
enum R_AARCH64_MOVW_SABS_G1 = 271;
enum R_AARCH64_MOVW_SABS_G2 = 272;

enum R_AARCH64_ADR_PREL_LO19 = 273;
enum R_AARCH64_ADR_PREL_LO21 = 274;
enum R_AARCH64_ADR_PREL_PG_HI21 = 275;
enum R_AARCH64_ADR_PREL_PG_HI21_NC = 276;

enum R_AARCH64_ADD_ABS_LO12_NC = 277;

enum R_AARCH64_LDST8_ABS_LO12_NC = 278;
enum R_AARCH64_LDST16_ABS_LO12_NC = 284;
enum R_AARCH64_LDST32_ABS_LO12_NC = 285;
enum R_AARCH64_LDST64_ABS_LO12_NC = 286;
enum R_AARCH64_LDST128_ABS_LO12_NC = 299;

enum R_AARCH64_JUMP26 = 282;
enum R_AARCH64_CALL26 = 283;

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

enum BUILD_TARGET_AARCH64_DEFAULT = "aarch64v8";
void get_current_target(char* target_buf, uint target_buf_size) {
    const(char)* s = BUILD_TARGET;
    size_t s_size = BUILD_TARGET.sizeof;
    char* d = target_buf;

    /* Set to "aarch64v8" by default if sub version isn't specified */
    if (strcmp(s, "AARCH64") == 0) {
        s = BUILD_TARGET_AARCH64_DEFAULT;
        s_size = BUILD_TARGET_AARCH64_DEFAULT.sizeof;
    }
    if (target_buf_size < s_size) {
        s_size = target_buf_size;
    }
    while (--s_size) {
        if (*s >= 'A' && *s <= 'Z')
            *d++ = *s++ + 'a' - 'A';
        else
            *d++ = *s++;
    }
    /* Ensure the string is null byte ('\0') terminated */
    *d = '\0';
}
private uint get_plt_item_size() {
    /* 6*4 bytes instructions and 8 bytes symbol address */
    return 32;
}

void init_plt_table(ubyte* plt) {
    uint i = void, num = target_sym_map.sizeof / SymbolMap.sizeof;
    for (i = 0; i < num; i++) {
        uint* p = cast(uint*)plt;
        *p++ = 0xf81f0ffe; /* str  x30, [sp, #-16]! */
        *p++ = 0x100000be; /* adr  x30, #20; symbol addr is PC + 5 instructions
                              below */
        *p++ = 0xf94003de; /* ldr  x30, [x30]   */
        *p++ = 0xd63f03c0; /* blr  x30          */
        *p++ = 0xf84107fe; /* ldr  x30, [sp], #16  */
        *p++ = 0xd61f03c0; /* br   x30          */
        /* symbol addr */
        *cast(ulong*)p = cast(ulong)cast(uintptr_t)target_sym_map[i].symbol_addr;
        p += 2;
        plt += get_plt_item_size();
    }
}

uint get_plt_table_size() {
    return get_plt_item_size() * (target_sym_map.sizeof / SymbolMap.sizeof);
}

enum string SIGN_EXTEND_TO_INT64(string val, string bits, string val_ext) = `    \
    do {                                            \
        int64 m = (int64)((uint64)1 << (bits - 1)); \
        val_ext = ((int64)val ^ m) - m;             \
    } while (0)`;

enum string Page(string expr) = ` ((expr) & ~0xFFF)`;

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
        case R_AARCH64_CALL26:
        case R_AARCH64_JUMP26:
        {
            void* S = void, P = cast(void*)(target_section_addr + reloc_offset);
            long X = void, A = void, initial_addend = void;
            int insn = void, imm26 = void;

            CHECK_RELOC_OFFSET(int32.sizeof);

            insn = *cast(int*)P;
            imm26 = insn & 0x3FFFFFF;
            SIGN_EXTEND_TO_INT64(imm26 << 2, 28, initial_addend);
            A = initial_addend;
            A += cast(long)reloc_addend;

            if (symbol_index < 0) {
                /* Symbol address itself is an AOT function.
                 * Apply relocation with the symbol directly.
                 * Suppose the symbol address is in +-128MB relative
                 * to the relocation address.
                 */
                S = symbol_addr;
            }
            else {
                ubyte* plt = void;
                if (reloc_addend > 0) {
                    set_error_buf(
                        error_buf, error_buf_size,
                        "AOT module load failed: relocate to plt table "
                        ~ "with reloc addend larger than 0 is unsupported.");
                    return false;
                }
                /* Symbol address is not an AOT function,
                 * but a function of runtime or native. Its address is
                 * beyond of the +-128MB space. Apply relocation with
                 * the PLT which branch to the target symbol address.
                 */
                S = plt = cast(ubyte*)module_.code + module_.code_size
                          - get_plt_table_size()
                          + get_plt_item_size() * symbol_index;
            }

            /* S + A - P */
            X = cast(long)S + A - cast(long)P;

            /* Check overflow: +-128MB */
            if (X > (128 * BH_MB) || X < (-128 * BH_MB)) {
                set_error_buf(error_buf, error_buf_size,
                              "AOT module load failed: "
                              ~ "target address out of range.");
                return false;
            }

            /* write the imm26 back to instruction */
            *cast(int*)P = (insn & 0xFC000000) | ((int32)((X >> 2) & 0x3FFFFFF));
            break;
        }

        case R_AARCH64_MOVW_UABS_G0:
        case R_AARCH64_MOVW_UABS_G0_NC:
        case R_AARCH64_MOVW_UABS_G1:
        case R_AARCH64_MOVW_UABS_G1_NC:
        case R_AARCH64_MOVW_UABS_G2:
        case R_AARCH64_MOVW_UABS_G2_NC:
        case R_AARCH64_MOVW_UABS_G3:
        {
            void* S = symbol_addr, P = cast(void*)(target_section_addr + reloc_offset);
            long X = void, A = void, initial_addend = void;
            int insn = void, imm16 = void;

            CHECK_RELOC_OFFSET(int32.sizeof);

            insn = *cast(int*)P;
            imm16 = (insn >> 5) & 0xFFFF;

            SIGN_EXTEND_TO_INT64(imm16, 16, initial_addend);
            A = initial_addend;
            A += cast(long)reloc_addend;

            /* S + A */
            X = cast(long)S + A;

            /* No need to check overflow for this relocation type */
            switch (reloc_type) {
                case R_AARCH64_MOVW_UABS_G0:
                    if (X < 0 || X >= (1LL << 16))
                        goto overflow_check_fail;
                    break;
                case R_AARCH64_MOVW_UABS_G1:
                    if (X < 0 || X >= (1LL << 32))
                        goto overflow_check_fail;
                    break;
                case R_AARCH64_MOVW_UABS_G2:
                    if (X < 0 || X >= (1LL << 48))
                        goto overflow_check_fail;
                    break;
                default:
                    break;
            }

            /* write the imm16 back to bits[5:20] of instruction */
            switch (reloc_type) {
                case R_AARCH64_MOVW_UABS_G0:
                case R_AARCH64_MOVW_UABS_G0_NC:
                    *cast(int*)P =
                        (insn & 0xFFE0001F) | ((int32)((X & 0xFFFF) << 5));
                    break;
                case R_AARCH64_MOVW_UABS_G1:
                case R_AARCH64_MOVW_UABS_G1_NC:
                    *cast(int*)P = (insn & 0xFFE0001F)
                                  | ((int32)(((X >> 16) & 0xFFFF) << 5));
                    break;
                case R_AARCH64_MOVW_UABS_G2:
                case R_AARCH64_MOVW_UABS_G2_NC:
                    *cast(int*)P = (insn & 0xFFE0001F)
                                  | ((int32)(((X >> 32) & 0xFFFF) << 5));
                    break;
                case R_AARCH64_MOVW_UABS_G3:
                    *cast(int*)P = (insn & 0xFFE0001F)
                                  | ((int32)(((X >> 48) & 0xFFFF) << 5));
                    break;
                default:
                    bh_assert(0);
                    break;
            }
            break;
        }

        case R_AARCH64_ADR_PREL_PG_HI21:
        case R_AARCH64_ADR_PREL_PG_HI21_NC:
        {
            void* S = symbol_addr, P = cast(void*)(target_section_addr + reloc_offset);
            long X = void, A = void, initial_addend = void;
            int insn = void, immhi19 = void, immlo2 = void, imm21 = void;

            CHECK_RELOC_OFFSET(int32.sizeof);

            insn = *cast(int*)P;
            immhi19 = (insn >> 5) & 0x7FFFF;
            immlo2 = (insn >> 29) & 0x3;
            imm21 = (immhi19 << 2) | immlo2;

            SIGN_EXTEND_TO_INT64(imm21 << 12, 33, initial_addend);
            A = initial_addend;
            A += cast(long)reloc_addend;

            /* Page(S+A) - Page(P) */
            X = Page(cast(long)S + A) - Page(cast(long)P);

            /* Check overflow: +-4GB */
            if (reloc_type == R_AARCH64_ADR_PREL_PG_HI21
                && (X > (cast(long)4 * BH_GB) || X < (cast(long)-4 * BH_GB)))
                goto overflow_check_fail;

            /* write the imm21 back to instruction */
            immhi19 = (int32)(((X >> 12) >> 2) & 0x7FFFF);
            immlo2 = (int32)((X >> 12) & 0x3);
            *cast(int*)P = (insn & 0x9F00001F) | (immlo2 << 29) | (immhi19 << 5);

            break;
        }

        case R_AARCH64_ADD_ABS_LO12_NC:
        {
            void* S = symbol_addr, P = cast(void*)(target_section_addr + reloc_offset);
            long X = void, A = void, initial_addend = void;
            int insn = void, imm12 = void;

            CHECK_RELOC_OFFSET(int32.sizeof);

            insn = *cast(int*)P;
            imm12 = (insn >> 10) & 0xFFF;

            SIGN_EXTEND_TO_INT64(imm12, 12, initial_addend);
            A = initial_addend;
            A += cast(long)reloc_addend;

            /* S + A */
            X = cast(long)S + A;

            /* No need to check overflow for this relocation type */

            /* write the imm12 back to instruction */
            *cast(int*)P = (insn & 0xFFC003FF) | ((int32)((X & 0xFFF) << 10));
            break;
        }

        case R_AARCH64_LDST8_ABS_LO12_NC:
        case R_AARCH64_LDST16_ABS_LO12_NC:
        case R_AARCH64_LDST32_ABS_LO12_NC:
        case R_AARCH64_LDST64_ABS_LO12_NC:
        case R_AARCH64_LDST128_ABS_LO12_NC:
        {
            void* S = symbol_addr, P = cast(void*)(target_section_addr + reloc_offset);
            long X = void, A = void, initial_addend = void;
            int insn = void, imm12 = void;

            CHECK_RELOC_OFFSET(int32.sizeof);

            insn = *cast(int*)P;
            imm12 = (insn >> 10) & 0xFFF;

            SIGN_EXTEND_TO_INT64(imm12, 12, initial_addend);
            A = initial_addend;
            A += cast(long)reloc_addend;

            /* S + A */
            X = cast(long)S + A;

            /* No need to check overflow for this relocation type */

            /* write the imm12 back to instruction */
            switch (reloc_type) {
                case R_AARCH64_LDST8_ABS_LO12_NC:
                    *cast(int*)P =
                        (insn & 0xFFC003FF) | ((int32)((X & 0xFFF) << 10));
                    break;
                case R_AARCH64_LDST16_ABS_LO12_NC:
                    *cast(int*)P = (insn & 0xFFC003FF)
                                  | ((int32)(((X & 0xFFF) >> 1) << 10));
                    break;
                case R_AARCH64_LDST32_ABS_LO12_NC:
                    *cast(int*)P = (insn & 0xFFC003FF)
                                  | ((int32)(((X & 0xFFF) >> 2) << 10));
                    break;
                case R_AARCH64_LDST64_ABS_LO12_NC:
                    *cast(int*)P = (insn & 0xFFC003FF)
                                  | ((int32)(((X & 0xFFF) >> 3) << 10));
                    break;
                case R_AARCH64_LDST128_ABS_LO12_NC:
                    *cast(int*)P = (insn & 0xFFC003FF)
                                  | ((int32)(((X & 0xFFF) >> 4) << 10));
                    break;
                default:
                    bh_assert(0);
                    break;
            }
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

overflow_check_fail:
    set_error_buf(error_buf, error_buf_size,
                  "AOT module load failed: "
                  ~ "target address out of range.");
    return false;
}
