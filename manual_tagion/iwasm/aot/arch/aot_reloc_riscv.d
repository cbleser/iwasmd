module aot_reloc_riscv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 XiaoMi Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_reloc;

enum R_RISCV_32 = 1;
enum R_RISCV_64 = 2;
enum R_RISCV_CALL = 18;
enum R_RISCV_CALL_PLT = 19;
enum R_RISCV_HI20 = 26;
enum R_RISCV_LO12_I = 27;
enum R_RISCV_LO12_S = 28;

enum RV_OPCODE_SW = 0x23;

/* clang-format off */
void __adddf3();
void __addsf3();
void __divdi3();
void __divsi3();
void __divsf3();
void __eqsf2();
void __eqdf2();
void __extendsfdf2();
void __fixdfdi();
void __fixdfsi();
void __fixsfdi();
void __fixsfsi();
void __fixunsdfdi();
void __fixunsdfsi();
void __fixunssfdi();
void __fixunssfsi();
void __floatdidf();
void __floatdisf();
void __floatsisf();
void __floatsidf();
void __floatundidf();
void __floatundisf();
void __floatunsisf();
void __floatunsidf();
void __gedf2();
void __gesf2();
void __gtsf2();
void __ledf2();
void __lesf2();
void __moddi3();
void __modsi3();
void __muldf3();
void __muldi3();
void __mulsf3();
void __mulsi3();
void __nedf2();
void __nesf2();
void __subdf3();
void __subsf3();
void __truncdfsf2();
void __udivdi3();
void __udivsi3();
void __umoddi3();
void __umodsi3();
void __unorddf2();
void __unordsf2();
/* clang-format on */

private SymbolMap[47] target_sym_map = [
    /* clang-format off */
    REG_COMMON_SYMBOLS
#ifndef __riscv_flen
    REG_SYM(&__adddf3),
    REG_SYM(&__addsf3),
    REG_SYM(&__divsf3),
    REG_SYM(&__gedf2),
    REG_SYM(&__gesf2),
    REG_SYM(&__gtsf2),
    REG_SYM(&__ledf2),
    REG_SYM(&__lesf2),
    REG_SYM(&__muldf3),
    REG_SYM(&__nedf2),
    REG_SYM(&__nesf2),
    REG_SYM(&__eqsf2),
    REG_SYM(&__eqdf2),
    REG_SYM(&__extendsfdf2),
    REG_SYM(&__fixunsdfdi),
    REG_SYM(&__fixunsdfsi),
    REG_SYM(&__fixunssfsi),
    REG_SYM(&__subdf3),
    REG_SYM(&__subsf3),
    REG_SYM(&__truncdfsf2),
    REG_SYM(&__unorddf2),
    REG_SYM(&__unordsf2),
#endif
    REG_SYM(&__divdi3),
    REG_SYM(&__divsi3),
#if __riscv_xlen == 32
    REG_SYM(&__fixdfdi),
    REG_SYM(&__fixdfsi),
    REG_SYM(&__fixsfdi),
    REG_SYM(&__fixsfsi),
#endif
    REG_SYM(&__fixunssfdi),
#if __riscv_xlen == 32
    REG_SYM(&__floatdidf),
    REG_SYM(&__floatdisf),
    REG_SYM(&__floatsisf),
    REG_SYM(&__floatsidf),
    REG_SYM(&__floatundidf),
    REG_SYM(&__floatundisf),
    REG_SYM(&__floatunsisf),
    REG_SYM(&__floatunsidf),
#endif
    REG_SYM(&__moddi3),
    REG_SYM(&__modsi3),
    REG_SYM(&__muldi3),
#if __riscv_xlen == 32
    REG_SYM(&__mulsf3),
    REG_SYM(&__mulsi3),
#endif
    REG_SYM(&__udivdi3),
    REG_SYM(&__udivsi3),
    REG_SYM(&__umoddi3),
    REG_SYM(&__umodsi3),
    /* clang-format on */
];

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null)
        snprintf(error_buf, error_buf_size, "%s", string);
}

void get_current_target(char* target_buf, uint target_buf_size) {
    snprintf(target_buf, target_buf_size, "riscv");
}

uint get_plt_item_size() {
static if (__riscv_xlen == 64) {
    /* auipc + ld + jalr + nop + addr */
    return 20;
} else {
    return 0;
}
}

SymbolMap* get_target_symbol_map(uint* sym_num) {
    *sym_num = target_sym_map.sizeof / SymbolMap.sizeof;
    return target_sym_map;
}

/* Get a val from given address */
private uint rv_get_val(ushort* addr) {
    uint ret = void;
    ret = *addr | (*(addr + 1)) << 16;
    return ret;
}

/* Set a val to given address */
private void rv_set_val(ushort* addr, uint val) {
    *addr = (val & 0xffff);
    *(addr + 1) = (val >> 16);

    __asm__ volatile("fence.i");
}

/* Add a val to given address */
private void rv_add_val(ushort* addr, uint val) {
    uint cur = rv_get_val(addr);
    rv_set_val(addr, cur + val);
}

/**
 * Get imm_hi and imm_lo from given integer
 *
 * @param imm given integer, signed 32bit
 * @param imm_hi signed 20bit
 * @param imm_lo signed 12bit
 *
 */
private void rv_calc_imm(int imm, int* imm_hi, int* imm_lo) {
    int lo = void;
    int hi = imm / 4096;
    int r = imm % 4096;

    if (2047 < r) {
        hi++;
    }
    else if (r < -2048) {
        hi--;
    }

    lo = imm - (hi * 4096);

    *imm_lo = lo;
    *imm_hi = hi;
}

uint get_plt_table_size() {
    return get_plt_item_size() * (target_sym_map.sizeof / SymbolMap.sizeof);
}

void init_plt_table(ubyte* plt) {
static if (__riscv_xlen == 64) {
    uint i = void, num = target_sym_map.sizeof / SymbolMap.sizeof;
    ubyte* p = void;

    for (i = 0; i < num; i++) {
        p = plt;
        /* auipc t1, 0 */
        *cast(ushort*)p = 0x0317;
        p += 2;
        *cast(ushort*)p = 0x0000;
        p += 2;
        /* ld t1, 8(t1) */
        *cast(ushort*)p = 0x3303;
        p += 2;
        *cast(ushort*)p = 0x00C3;
        p += 2;
        /* jr t1 */
        *cast(ushort*)p = 0x8302;
        p += 2;
        /* nop */
        *cast(ushort*)p = 0x0001;
        p += 2;
        bh_memcpy_s(p, 8, &target_sym_map[i].symbol_addr, 8);
        p += 8;
        plt += get_plt_item_size();
    }
}
}

struct RelocTypeStrMap {
    uint reloc_type;
    char* reloc_str;
}

enum string RELOC_TYPE_MAP(string reloc_type) = ` \
    {                              \
        reloc_type, #reloc_type    \
    }`;

private RelocTypeStrMap[7] reloc_type_str_maps = [
    RELOC_TYPE_MAP(R_RISCV_32),       RELOC_TYPE_MAP(R_RISCV_CALL),
    RELOC_TYPE_MAP(R_RISCV_CALL_PLT), RELOC_TYPE_MAP(R_RISCV_HI20),
    RELOC_TYPE_MAP(R_RISCV_LO12_I),   RELOC_TYPE_MAP(R_RISCV_LO12_S),
];

private const(char)* reloc_type_to_str(uint reloc_type) {
    uint i = void;

    for (i = 0; i < reloc_type_str_maps.sizeof / RelocTypeStrMap.sizeof;
         i++) {
        if (reloc_type_str_maps[i].reloc_type == reloc_type)
            return reloc_type_str_maps[i].reloc_str;
    }

    return "Unknown_Reloc_Type";
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
    int val = void, imm_hi = void, imm_lo = void, insn = void;
    ubyte* addr = target_section_addr + reloc_offset;
    char[128] buf = void;

    switch (reloc_type) {
        case R_RISCV_32:
        {
            uint val_32 = (uint32)(cast(uintptr_t)symbol_addr + cast(intptr_t)reloc_addend);

            CHECK_RELOC_OFFSET(uint32.sizeof);
            if (val_32 != (cast(uintptr_t)symbol_addr + cast(intptr_t)reloc_addend)) {
                goto fail_addr_out_of_range;
            }

            rv_set_val(cast(ushort*)addr, val_32);
            break;
        }
        case R_RISCV_64:
        {
            ulong val_64 = (uint64)(cast(uintptr_t)symbol_addr + cast(intptr_t)reloc_addend);
            CHECK_RELOC_OFFSET(uint64.sizeof);
            bh_memcpy_s(addr, 8, &val_64, 8);
            break;
        }
        case R_RISCV_CALL:
        case R_RISCV_CALL_PLT:
        {
            val = (int32)(intptr_t)(cast(ubyte*)symbol_addr - addr);

            CHECK_RELOC_OFFSET(uint32.sizeof);
            if (val != cast(intptr_t)(cast(ubyte*)symbol_addr - addr)) {
                if (symbol_index >= 0) {
                    /* Call runtime function by plt code */
                    symbol_addr = cast(ubyte*)module_.code + module_.code_size
                                  - get_plt_table_size()
                                  + get_plt_item_size() * symbol_index;
                    val = (int32)(intptr_t)(cast(ubyte*)symbol_addr - addr);
                }
            }

            if (val != cast(intptr_t)(cast(ubyte*)symbol_addr - addr)) {
                goto fail_addr_out_of_range;
            }

            rv_calc_imm(val, &imm_hi, &imm_lo);

            rv_add_val(cast(ushort*)addr, (imm_hi << 12));
            if ((rv_get_val(cast(ushort*)(addr + 4)) & 0x7f) == RV_OPCODE_SW) {
                /* Adjust imm for SW : S-type */
                val = ((cast(int)imm_lo >> 5) << 25)
                      + ((cast(int)imm_lo & 0x1f) << 7);

                rv_add_val(cast(ushort*)(addr + 4), val);
            }
            else {
                /* Adjust imm for MV(ADDI)/JALR : I-type */
                rv_add_val(cast(ushort*)(addr + 4), (cast(int)imm_lo << 20));
            }
            break;
        }

        case R_RISCV_HI20:
        {
            val = (int32)(cast(intptr_t)symbol_addr + cast(intptr_t)reloc_addend);

            CHECK_RELOC_OFFSET(uint32.sizeof);
            if (val != (cast(intptr_t)symbol_addr + cast(intptr_t)reloc_addend)) {
                goto fail_addr_out_of_range;
            }

            addr = target_section_addr + reloc_offset;
            insn = rv_get_val(cast(ushort*)addr);
            rv_calc_imm(val, &imm_hi, &imm_lo);
            insn = (insn & 0x00000fff) | (imm_hi << 12);
            rv_set_val(cast(ushort*)addr, insn);
            break;
        }

        case R_RISCV_LO12_I:
        {
            val = (int32)(cast(intptr_t)symbol_addr + cast(intptr_t)reloc_addend);

            CHECK_RELOC_OFFSET(uint32.sizeof);
            if (val != cast(intptr_t)symbol_addr + cast(intptr_t)reloc_addend) {
                goto fail_addr_out_of_range;
            }

            addr = target_section_addr + reloc_offset;
            insn = rv_get_val(cast(ushort*)addr);
            rv_calc_imm(val, &imm_hi, &imm_lo);
            insn = (insn & 0x000fffff) | (imm_lo << 20);
            rv_set_val(cast(ushort*)addr, insn);
            break;
        }

        case R_RISCV_LO12_S:
        {
            val = (int32)(cast(intptr_t)symbol_addr + cast(intptr_t)reloc_addend);

            CHECK_RELOC_OFFSET(uint32.sizeof);
            if (val != (cast(intptr_t)symbol_addr + cast(intptr_t)reloc_addend)) {
                goto fail_addr_out_of_range;
            }

            addr = target_section_addr + reloc_offset;
            rv_calc_imm(val, &imm_hi, &imm_lo);
            val = ((cast(int)imm_lo >> 5) << 25) + ((cast(int)imm_lo & 0x1f) << 7);
            rv_add_val(cast(ushort*)addr, val);
            break;
        }

        default:
            if (error_buf != null)
                snprintf(error_buf, error_buf_size,
                         "Load relocation section failed: "
                         ~ "invalid relocation type %" PRIu32 ~ ".",
                         reloc_type);
            return false;
    }

    return true;

fail_addr_out_of_range:
    snprintf(buf.ptr, buf.sizeof,
             "AOT module load failed: "
             ~ "relocation truncated to fit %s failed.",
             reloc_type_to_str(reloc_type));
    set_error_buf(error_buf, error_buf_size, buf.ptr);
    return false;
}
