module elf64;
@nogc nothrow:
extern(C): __gshared:
/****************************************************************************
 * include/elf64.h
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

/* See ELF-64 Object File Format: Version 1.5 Draft 2 */

/* Definitions for Elf64_Rel*::r_info */

enum string ELF64_R_SYM(string i) = ` ((i) >> 32)`;
enum string ELF64_R_TYPE(string i) = ` ((i)&0xffffffffL)`;
enum string ELF64_R_INFO(string s, string t) = ` (((s) << 32) + ((t)&0xffffffffL))`;

version (none) {
enum string ELF_R_SYM(string i) = ` ELF64_R_SYM(i)`;
}

/****************************************************************************
 * Public Type Definitions
 ****************************************************************************/

/* Table 1: ELF-64 Data Types */

alias Elf64_Addr = ulong;  /* Unsigned program address */
alias Elf64_Off = ulong;   /* Unsigned file offset */
alias Elf64_Half = ushort;  /* Unsigned medium integer */
alias Elf64_Word = uint;  /* Unsigned long integer */
alias Elf64_Sword = int;  /* Signed integer */
alias Elf64_Xword = ulong; /* Unsigned long integer */
alias Elf64_Sxword = long; /* Signed large integer */

/* Figure 2: ELF-64 Header */

struct _Elf64_Ehdr {
    ubyte[EI_NIDENT] e_ident; /* ELF identification */
    Elf64_Half e_type;                /* Object file type */
    Elf64_Half e_machine;             /* Machine type */
    Elf64_Word e_version;             /* Object file version */
    Elf64_Addr e_entry;               /* Entry point address */
    Elf64_Off e_phoff;                /* Program header offset */
    Elf64_Off e_shoff;                /* Section header offset */
    Elf64_Word e_flags;               /* Processor-specific flags */
    Elf64_Half e_ehsize;              /* ELF header size */
    Elf64_Half e_phentsize;           /* Size of program header entry */
    Elf64_Half e_phnum;               /* Number of program header entry */
    Elf64_Half e_shentsize;           /* Size of section header entry */
    Elf64_Half e_shnum;               /* Number of section header entries */
    Elf64_Half e_shstrndx;            /* Section name string table index */
}alias Elf64_Ehdr = _Elf64_Ehdr;

/* Figure 3: ELF-64 Section Header */

struct _Elf64_Shdr {
    Elf64_Word sh_name;       /* Section name */
    Elf64_Word sh_type;       /* Section type */
    Elf64_Xword sh_flags;     /* Section attributes */
    Elf64_Addr sh_addr;       /* Virtual address in memory */
    Elf64_Off sh_offset;      /* Offset in file */
    Elf64_Xword sh_size;      /* Size of section */
    Elf64_Word sh_link;       /* Link to other section */
    Elf64_Word sh_info;       /* Miscellaneous information */
    Elf64_Xword sh_addralign; /* Address alignment boundary */
    Elf64_Xword sh_entsize;   /* Size of entries, if section has table */
}alias Elf64_Shdr = _Elf64_Shdr;

/* Figure 4: ELF-64 Symbol Table Entry */

struct _Elf64_Sym {
    Elf64_Word st_name;     /* Symbol name */
    ubyte st_info;  /* Type and Binding attributes */
    ubyte st_other; /* Reserved */
    Elf64_Half st_shndx;    /* Section table index */
    Elf64_Addr st_value;    /* Symbol value */
    Elf64_Xword st_size;    /* Size of object (e.g., common) */
}alias Elf64_Sym = _Elf64_Sym;

/* Figure 5: ELF-64 Relocation Entries */

struct _Elf64_Rel {
    Elf64_Addr r_offset; /* Address of reference */
    Elf64_Xword r_info;  /* Symbol index and type of relocation */
}alias Elf64_Rel = _Elf64_Rel;

struct _Elf64_Rela {
    Elf64_Addr r_offset;   /* Address of reference */
    Elf64_Xword r_info;    /* Symbol index and type of relocation */
    Elf64_Sxword r_addend; /* Constant part of expression */
}alias Elf64_Rela = _Elf64_Rela;

/* Figure 6: ELF-64 Program Header Table Entry */

struct _Elf64_Phdr {
    Elf64_Word p_type;   /* Type of segment */
    Elf64_Word p_flags;  /* Segment attributes */
    Elf64_Off p_offset;  /* Offset in file */
    Elf64_Addr p_vaddr;  /* Virtual address in memory */
    Elf64_Addr p_paddr;  /* Reserved */
    Elf64_Word p_filesz; /* Size of segment in file */
    Elf64_Word p_memsz;  /* Size of segment in memory */
    Elf64_Word p_align;  /* Alignment of segment */
}alias Elf64_Phdr = _Elf64_Phdr;

/* Figure 7. Format of a Note Section */

struct _Elf64_Nhdr {
    Elf64_Word n_namesz; /* Length of the note's name.  */
    Elf64_Word n_descsz; /* Length of the note's descriptor.  */
    Elf64_Word n_type;   /* Type of the note.  */
}alias Elf64_Nhdr = _Elf64_Nhdr;

/* Figure 8: Dynamic Table Structure */

struct _Elf64_Dyn {
    Elf64_Sxword d_tag;
    union _D_un {
        Elf64_Xword d_val;
        Elf64_Addr d_ptr;
    }_D_un d_un;
}alias Elf64_Dyn = _Elf64_Dyn;

version (none) {
alias Elf_Addr = Elf64_Addr;
alias Elf_Ehdr = Elf64_Ehdr;
alias Elf_Rel = Elf64_Rel;
alias Elf_Rela = Elf64_Rela;
alias Elf_Nhdr = Elf64_Nhdr;
alias Elf_Phdr = Elf64_Phdr;
alias Elf_Sym = Elf64_Sym;
alias Elf_Shdr = Elf64_Shdr;
alias Elf_Word = Elf64_Word;
}

 /* __INCLUDE_ELF64_H */
