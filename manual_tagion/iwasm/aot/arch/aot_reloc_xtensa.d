module aot_reloc_xtensa;
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

enum R_XTENSA_32 = 1        /* Direct 32 bit */;
enum R_XTENSA_SLOT0_OP = 20 /* PC relative */;

/* clang-format off */
/* for soft-float */
void __floatsidf();
void __divdf3();
void __ltdf2();

/* for mul32 */
void __mulsi3();
void __muldi3();

void __modsi3();

void __divdi3();

void __udivdi3();
void __unorddf2();
void __adddf3();
void __eqdf2();
void __muldf3();
void __gedf2();
void __ledf2();
void __fixunsdfsi();
void __floatunsidf();
void __subdf3();
void __nedf2();
void __fixdfsi();
void __moddi3();
void __extendsfdf2();
void __truncdfsf2();
void __gtdf2();
void __umoddi3();
void __floatdidf();
void __divsf3();
void __fixdfdi();
void __floatundidf();


private SymbolMap[29] target_sym_map = [
    REG_COMMON_SYMBOLS

    /* API's for soft-float */
    /* TODO: only register these symbols when Floating-Point Coprocessor
     * Option is not enabled */
    REG_SYM(&__floatsidf),
    REG_SYM(&__divdf3),
    REG_SYM(&__ltdf2),

    /* API's for 32-bit integer multiply */
    /* TODO: only register these symbols when 32-bit Integer Multiply Option
     * is not enabled */
    REG_SYM(&__mulsi3),
    REG_SYM(&__muldi3),

    REG_SYM(&__modsi3),
    REG_SYM(&__divdi3),

    REG_SYM(&__udivdi3),
    REG_SYM(&__unorddf2),
    REG_SYM(&__adddf3),
    REG_SYM(&__eqdf2),
    REG_SYM(&__muldf3),
    REG_SYM(&__gedf2),
    REG_SYM(&__ledf2),
    REG_SYM(&__fixunsdfsi),
    REG_SYM(&__floatunsidf),
    REG_SYM(&__subdf3),
    REG_SYM(&__nedf2),
    REG_SYM(&__fixdfsi),
    REG_SYM(&__moddi3),
    REG_SYM(&__extendsfdf2),
    REG_SYM(&__truncdfsf2),
    REG_SYM(&__gtdf2),
    REG_SYM(&__umoddi3),
    REG_SYM(&__floatdidf),
    REG_SYM(&__divsf3),
    REG_SYM(&__fixdfdi),
    REG_SYM(&__floatundidf),
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
    snprintf(target_buf, target_buf_size, "xtensa");
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

private bool check_reloc_offset(uint target_section_size, ulong reloc_offset, uint reloc_data_size, char* error_buf, uint error_buf_size) {
    if (!(reloc_offset < cast(ulong)target_section_size
          && reloc_offset + reloc_data_size <= cast(ulong)target_section_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "AOT module load failed: invalid relocation offset.");
        return false;
    }
    return true;
}

/*
 * CPU like esp32 can read and write data through the instruction bus, but only
 * in a word aligned manner; non-word-aligned access will cause a CPU exception.
 * This function uses a world aligned manner to write 16bit value to instruction
 * addreess.
 */
private void put_imm16_to_addr(short imm16, short* addr) {
    byte[8] bytes = void;
    int* addr_aligned1 = void, addr_aligned2 = void;

    addr_aligned1 = cast(int*)(cast(intptr_t)addr & ~3);

    if (cast(intptr_t)addr % 4 != 3) {
        *cast(int*)bytes = *addr_aligned1;
        *cast(short*)(bytes.ptr + (cast(intptr_t)addr % 4)) = imm16;
        *addr_aligned1 = *cast(int*)bytes;
    }
    else {
        addr_aligned2 = cast(int*)((cast(intptr_t)addr + 3) & ~3);
        *cast(int*)bytes = *addr_aligned1;
        *cast(int*)(bytes.ptr + 4) = *addr_aligned2;
        *cast(short*)(bytes.ptr + 3) = imm16;
        memcpy(addr_aligned1, bytes.ptr, 8);
    }
}

union ___ue {
    int a;
    char b = 0;
}private ___ue __ue = { a: 1 };

enum string is_little_endian() = ` (__ue.b == 1)`;

static if (!HasVersion!"__packed") {
/*
 * Note: This version check is a bit relaxed.
 * The __packed__ attribute has been there since gcc 2 era.
 */
static if (__GNUC__ >= 3) {
enum __packed = __attribute__((__packed__));
}
}

union _L32r_insn_t {
    struct l32r_le {
        byte other;
        short imm16;
    }l32r_le __packed;

    struct l32r_be {
        short imm16;
        byte other;
    }l32r_be __packed;
}alias l32r_insn_t = _L32r_insn_t;

bool apply_relocation(AOTModule* module_, ubyte* target_section_addr, uint target_section_size, ulong reloc_offset, long reloc_addend, uint reloc_type, void* symbol_addr, int symbol_index, char* error_buf, uint error_buf_size) {
    switch (reloc_type) {
        case R_XTENSA_32:
        {
            ubyte* insn_addr = target_section_addr + reloc_offset;
            int initial_addend = void;
            /* (S + A) */
            if (cast(intptr_t)insn_addr & 3) {
                set_error_buf(error_buf, error_buf_size,
                              "AOT module load failed: "
                              ~ "instruction address unaligned.");
                return false;
            }
            CHECK_RELOC_OFFSET(4);
            initial_addend = *cast(int*)insn_addr;
            *cast(uintptr_t*)insn_addr = cast(uintptr_t)symbol_addr + initial_addend
                                      + cast(intptr_t)reloc_addend;
            break;
        }

        case R_XTENSA_SLOT0_OP:
        {
            ubyte* insn_addr = target_section_addr + reloc_offset;
            /* Currently only l32r instruction generates R_XTENSA_SLOT0_OP
             * relocation */
            l32r_insn_t* l32r_insn = cast(l32r_insn_t*)insn_addr;
            ubyte* reloc_addr = void;
            int relative_offset = void;
            short imm16 = void;

            CHECK_RELOC_OFFSET(3); /* size of l32r instruction */

            /*
            imm16 = is_little_endian() ?
                    l32r_insn->l.imm16 : l32r_insn->b.imm16;
            initial_addend = (int32)imm16 << 2;
            */

            reloc_addr =
                cast(ubyte*)(cast(uintptr_t)symbol_addr + cast(intptr_t)reloc_addend);

            if (cast(intptr_t)reloc_addr & 3) {
                set_error_buf(error_buf, error_buf_size,
                              "AOT module load failed: "
                              ~ "relocation address unaligned.");
                return false;
            }

            relative_offset =
                (int32)(cast(intptr_t)reloc_addr
                        - ((cast(intptr_t)insn_addr + 3) & ~cast(intptr_t)3));
            /* relative_offset += initial_addend; */

            /* check relative offset boundary */
            if (relative_offset < -256 * BH_KB || relative_offset > -4) {
                set_error_buf(error_buf, error_buf_size,
                              "AOT module load failed: "
                              ~ "target address out of range.\n"
                              ~ "Try using `wamrc --size-level=0` to generate "
                              ~ ".literal island.");
                return false;
            }

            imm16 = (int16)(relative_offset >> 2);

            /* write back the imm16 to the l32r instruction */

            /* GCC >= 9 complains if we have a pointer that could be
             * unaligned. This can happen because the struct is packed.
             * These pragma are to suppress the warnings because the
             * function put_imm16_to_addr already handles unaligned
             * pointers correctly. */
static if (__GNUC__ >= 9) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Waddress-of-packed-member"
}
            if (is_little_endian())
                put_imm16_to_addr(imm16, &l32r_insn.l.imm16);
            else
                put_imm16_to_addr(imm16, &l32r_insn.b.imm16);
static if (__GNUC__ >= 9) {
#pragma GCC diagnostic pop
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
}
