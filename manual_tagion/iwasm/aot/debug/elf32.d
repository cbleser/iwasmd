module elf32;
@nogc nothrow:
extern(C): __gshared:
/****************************************************************************
 * include/elf32.h
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ****************************************************************************/

 
/****************************************************************************
 * Included Files
 ****************************************************************************/

public import core.stdc.stdint;

/****************************************************************************
 * Pre-processor Definitions
 ****************************************************************************/

enum string ELF32_ST_BIND(string i) = ` ((i) >> 4)`;
enum string ELF32_ST_TYPE(string i) = ` ((i)&0xf)`;
enum string ELF32_ST_INFO(string b, string t) = ` (((b) << 4) | ((t)&0xf))`;

/* Definitions for Elf32_Rel*::r_info */

enum string ELF32_R_SYM(string i) = ` ((i) >> 8)`;
enum string ELF32_R_TYPE(string i) = ` ((i)&0xff)`;
enum string ELF32_R_INFO(string s, string t) = ` (((s) << 8) | ((t)&0xff))`;

version (none) {
enum string ELF_R_SYM(string i) = ` ELF32_R_SYM(i)`;
}

/****************************************************************************
 * Public Type Definitions
 ****************************************************************************/

/* Figure 4.2: 32-Bit Data Types */

alias Elf32_Addr = uint; /* Unsigned program address */
alias Elf32_Half = ushort; /* Unsigned medium integer */
alias Elf32_Off = uint;  /* Unsigned file offset */
alias Elf32_Sword = int; /* Signed large integer */
alias Elf32_Word = uint; /* Unsigned large integer */

/* Figure 4-3: ELF Header */

struct _Elf32_Ehdr {
    ubyte[EI_NIDENT] e_ident;
    Elf32_Half e_type;
    Elf32_Half e_machine;
    Elf32_Word e_version;
    Elf32_Addr e_entry;
    Elf32_Off e_phoff;
    Elf32_Off e_shoff;
    Elf32_Word e_flags;
    Elf32_Half e_ehsize;
    Elf32_Half e_phentsize;
    Elf32_Half e_phnum;
    Elf32_Half e_shentsize;
    Elf32_Half e_shnum;
    Elf32_Half e_shstrndx;
}alias Elf32_Ehdr = _Elf32_Ehdr;

/* Figure 4-8: Section Header */

struct _Elf32_Shdr {
    Elf32_Word sh_name;
    Elf32_Word sh_type;
    Elf32_Word sh_flags;
    Elf32_Addr sh_addr;
    Elf32_Off sh_offset;
    Elf32_Word sh_size;
    Elf32_Word sh_link;
    Elf32_Word sh_info;
    Elf32_Word sh_addralign;
    Elf32_Word sh_entsize;
}alias Elf32_Shdr = _Elf32_Shdr;

/* Figure 4-15: Symbol Table Entry */

struct _Elf32_Sym {
    Elf32_Word st_name;
    Elf32_Addr st_value;
    Elf32_Word st_size;
    ubyte st_info;
    ubyte st_other;
    Elf32_Half st_shndx;
}alias Elf32_Sym = _Elf32_Sym;

/* Figure 4-19: Relocation Entries */

struct _Elf32_Rel {
    Elf32_Addr r_offset;
    Elf32_Word r_info;
}alias Elf32_Rel = _Elf32_Rel;

struct _Elf32_Rela {
    Elf32_Addr r_offset;
    Elf32_Word r_info;
    Elf32_Sword r_addend;
}alias Elf32_Rela = _Elf32_Rela;

/* Figure 5-1: Program Header */

struct _Elf32_Phdr {
    Elf32_Word p_type;
    Elf32_Off p_offset;
    Elf32_Addr p_vaddr;
    Elf32_Addr p_paddr;
    Elf32_Word p_filesz;
    Elf32_Word p_memsz;
    Elf32_Word p_flags;
    Elf32_Word p_align;
}alias Elf32_Phdr = _Elf32_Phdr;

/* Figure 5-7: Note Information */

struct _Elf32_Nhdr {
    Elf32_Word n_namesz; /* Length of the note's name.  */
    Elf32_Word n_descsz; /* Length of the note's descriptor.  */
    Elf32_Word n_type;   /* Type of the note.  */
}alias Elf32_Nhdr = _Elf32_Nhdr;

/* Figure 5-9: Dynamic Structure */

struct _Elf32_Dyn {
    Elf32_Sword d_tag;
    union _D_un {
        Elf32_Word d_val;
        Elf32_Addr d_ptr;
    }_D_un d_un;
}alias Elf32_Dyn = _Elf32_Dyn;

version (none) {
alias Elf_Addr = Elf32_Addr;
alias Elf_Ehdr = Elf32_Ehdr;
alias Elf_Rel = Elf32_Rel;
alias Elf_Rela = Elf32_Rela;
alias Elf_Nhdr = Elf32_Nhdr;
alias Elf_Phdr = Elf32_Phdr;
alias Elf_Sym = Elf32_Sym;
alias Elf_Shdr = Elf32_Shdr;
alias Elf_Word = Elf32_Word;
}

 /* __INCLUDE_ELF32_H */
