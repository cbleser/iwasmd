module elf;
@nogc nothrow:
extern(C): __gshared:
/****************************************************************************
 * include/elf.h
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

enum EI_NIDENT = 16 /* Size of e_ident[] */;

/* NOTE: elf64.h and elf32.h refer EI_NIDENT defined above */

public import elf64;
public import elf32;

/****************************************************************************
 * Pre-processor Definitions
 ****************************************************************************/

/* Values for Elf_Ehdr::e_type */

enum ET_NONE = 0        /* No file type */;
enum ET_REL = 1         /* Relocatable file */;
enum ET_EXEC = 2        /* Executable file */;
enum ET_DYN = 3         /* Shared object file */;
enum ET_CORE = 4        /* Core file */;
enum ET_LOPROC = 0xff00 /* Processor-specific */;
enum ET_HIPROC = 0xffff /* Processor-specific */;

/* Values for Elf_Ehdr::e_machine (most of this were not included in the
 * original SCO document but have been gleaned from elsewhere).
 */

enum EM_NONE = 0         /* No machine */;
enum EM_M32 = 1          /* AT&T WE 32100 */;
enum EM_SPARC = 2        /* SPARC */;
enum EM_386 = 3          /* Intel 80386 */;
enum EM_68K = 4          /* Motorola 68000 */;
enum EM_88K = 5          /* Motorola 88000 */;
enum EM_486 = 6          /* Intel 486+ */;
enum EM_860 = 7          /* Intel 80860 */;
enum EM_MIPS = 8         /* MIPS R3000 Big-Endian */;
enum EM_MIPS_RS4_BE = 10 /* MIPS R4000 Big-Endian */;
enum EM_PARISC = 15      /* HPPA */;
enum EM_SPARC32PLUS = 18 /* Sun's "v8plus" */;
enum EM_PPC = 20         /* PowerPC */;
enum EM_PPC64 = 21       /* PowerPC64 */;
enum EM_ARM = 40         /* ARM */;
enum EM_SH = 42          /* SuperH */;
enum EM_SPARCV9 = 43     /* SPARC v9 64-bit */;
enum EM_H8_300 = 46;
enum EM_IA_64 = 50  /* HP/Intel IA-64 */;
enum EM_X86_64 = 62 /* AMD x86-64 */;
enum EM_S390 = 22   /* IBM S/390 */;
enum EM_CRIS = 76   /* Axis Communications 32-bit embedded processor */;
enum EM_V850 = 87   /* NEC v850 */;
enum EM_M32R = 88   /* Renesas M32R */;
enum EM_XTENSA = 94 /* Tensilica Xtensa */;
enum EM_RISCV = 243 /* RISC-V */;
enum EM_ALPHA = 0x9026;
enum EM_CYGNUS_V850 = 0x9080;
enum EM_CYGNUS_M32R = 0x9041;
enum EM_S390_OLD = 0xa390;
enum EM_FRV = 0x5441;

/* Values for Elf_Ehdr::e_version */

enum EV_NONE = 0    /* Invalid version */;
enum EV_CURRENT = 1 /* The current version */;

/* Table 2. Ehe ELF identifier */

enum EI_MAG0 = 0 /* File identification */;
enum EI_MAG1 = 1;
enum EI_MAG2 = 2;
enum EI_MAG3 = 3;
enum EI_CLASS = 4   /* File class */;
enum EI_DATA = 5    /* Data encoding */;
enum EI_VERSION = 6 /* File version */;
enum EI_OSABI = 7   /* OS ABI */;
enum EI_PAD = 8     /* Start of padding bytes */;

/* EI_NIDENT is defined in "Included Files" section */

enum EI_MAGIC_SIZE = 4;
enum EI_MAGIC =            \
    {                       \
        0x7f, 'E', 'L', 'F' \
    };

enum ELFMAG0 = 0x7f /* EI_MAG */;
enum ELFMAG1 = 'E';
enum ELFMAG2 = 'L';
enum ELFMAG3 = 'F';
enum ELFMAG = "\177ELF";

/* Table 3. Values for EI_CLASS */

enum ELFCLASSNONE = 0 /* Invalid class */;
enum ELFCLASS32 = 1   /* 32-bit objects */;
enum ELFCLASS64 = 2   /* 64-bit objects */;

/* Table 4. Values for EI_DATA */

enum ELFDATANONE = 0 /* Invalid data encoding */;
enum ELFDATA2LSB =                                                          \
    1                 /* Least significant byte occupying the lowest address \
                       */;
enum ELFDATA2MSB = 2 /* Most significant byte occupying the lowest address */;

/* Table 6. Values for EI_OSABI */

enum ELFOSABI_NONE = 0   /* UNIX System V ABI */;
enum ELFOSABI_SYSV = 0   /* Alias.  */;
enum ELFOSABI_HPUX = 1   /* HP-UX */;
enum ELFOSABI_NETBSD = 2 /* NetBSD.  */;
enum ELFOSABI_GNU = 3    /* Object uses GNU ELF extensions.  */;
enum ELFOSABI_LINUX = ELFOSABI_GNU;
/* Compatibility alias.  */
enum ELFOSABI_SOLARIS = 6      /* Sun Solaris.  */;
enum ELFOSABI_AIX = 7          /* IBM AIX.  */;
enum ELFOSABI_IRIX = 8         /* SGI Irix.  */;
enum ELFOSABI_FREEBSD = 9      /* FreeBSD.  */;
enum ELFOSABI_TRU64 = 10       /* Compaq TRU64 UNIX.  */;
enum ELFOSABI_MODESTO = 11     /* Novell Modesto.  */;
enum ELFOSABI_OPENBSD = 12     /* OpenBSD.  */;
enum ELFOSABI_ARM_AEABI = 64   /* ARM EABI */;
enum ELFOSABI_ARM = 97         /* ARM */;
enum ELFOSABI_STANDALONE = 255 /* Standalone (embedded) application */;

version (ELF_OSABI) {} else {
enum ELF_OSABI = ELFOSABI_NONE;
}

/* Table 7: Special Section Indexes */

enum SHN_UNDEF = 0;
enum SHN_LOPROC = 0xff00;
enum SHN_HIPROC = 0xff1f;
enum SHN_ABS = 0xfff1;
enum SHN_COMMON = 0xfff2;

/* Figure 4-9: Section Types, sh_type */

enum SHT_NULL = 0;
enum SHT_PROGBITS = 1;
enum SHT_SYMTAB = 2;
enum SHT_STRTAB = 3;
enum SHT_RELA = 4;
enum SHT_HASH = 5;
enum SHT_DYNAMIC = 6;
enum SHT_NOTE = 7;
enum SHT_NOBITS = 8;
enum SHT_REL = 9;
enum SHT_SHLIB = 10;
enum SHT_DYNSYM = 11;
enum SHT_LOPROC = 0x70000000;
enum SHT_HIPROC = 0x7fffffff;
enum SHT_LOUSER = 0x80000000;
enum SHT_HIUSER = 0xffffffff;

/* Figure 4-11: Section Attribute Flags, sh_flags */

enum SHF_WRITE = 1;
enum SHF_ALLOC = 2;
enum SHF_EXECINSTR = 4;
enum SHF_MASKPROC = 0xf0000000;

/* Figure 4-16: Symbol Binding, ELF_ST_BIND */

enum STB_LOCAL = 0;
enum STB_GLOBAL = 1;
enum STB_WEAK = 2;
enum STB_LOPROC = 13;
enum STB_HIPROC = 15;

/* Figure 4-17: Symbol Types, ELF_ST_TYPE */

enum STT_NOTYPE = 0;
enum STT_OBJECT = 1;
enum STT_FUNC = 2;
enum STT_SECTION = 3;
enum STT_FILE = 4;
enum STT_LOPROC = 13;
enum STT_HIPROC = 15;

/* Figure 5-2: Segment Types, p_type */

enum PT_NULL = 0;
enum PT_LOAD = 1;
enum PT_DYNAMIC = 2;
enum PT_INTERP = 3;
enum PT_NOTE = 4;
enum PT_SHLIB = 5;
enum PT_PHDR = 6;
enum PT_LOPROC = 0x70000000;
enum PT_HIPROC = 0x7fffffff;

/* Figure 5-3: Segment Flag Bits, p_flags */

enum PF_X = 1                 /* Execute */;
enum PF_W = 2                 /* Write */;
enum PF_R = 4                 /* Read */;
enum PF_MASKPROC = 0xf0000000 /* Unspecified */;

/* Figure 5-10: Dynamic Array Tags, d_tag */

enum DT_NULL = 0            /* d_un=ignored */;
enum DT_NEEDED = 1          /* d_un=d_val */;
enum DT_PLTRELSZ = 2        /* d_un=d_val */;
enum DT_PLTGOT = 3          /* d_un=d_ptr */;
enum DT_HASH = 4            /* d_un=d_ptr */;
enum DT_STRTAB = 5          /* d_un=d_ptr */;
enum DT_SYMTAB = 6          /* d_un=d_ptr */;
enum DT_RELA = 7            /* d_un=d_ptr */;
enum DT_RELASZ = 8          /* d_un=d_val */;
enum DT_RELAENT = 9         /* d_un=d_val */;
enum DT_STRSZ = 10          /* d_un=d_val */;
enum DT_SYMENT = 11         /* d_un=d_val */;
enum DT_INIT = 12           /* d_un=d_ptr */;
enum DT_FINI = 13           /* d_un=d_ptr */;
enum DT_SONAME = 14         /* d_un=d_val */;
enum DT_RPATH = 15          /* d_un=d_val */;
enum DT_SYMBOLIC = 16       /* d_un=ignored */;
enum DT_REL = 17            /* d_un=d_ptr */;
enum DT_RELSZ = 18          /* d_un=d_val */;
enum DT_RELENT = 19         /* d_un=d_val */;
enum DT_PLTREL = 20         /* d_un=d_val */;
enum DT_DEBUG = 21          /* d_un=d_ptr */;
enum DT_TEXTREL = 22        /* d_un=ignored */;
enum DT_JMPREL = 23         /* d_un=d_ptr */;
enum DT_BINDNOW = 24        /* d_un=ignored */;
enum DT_LOPROC = 0x70000000 /* d_un=unspecified */;
enum DT_HIPROC = 0x7fffffff /* d_un= unspecified */;

/* Legal values for note segment descriptor types for core files. */

enum NT_PRSTATUS = 1   /* Contains copy of prstatus struct */;
enum NT_PRFPREG = 2    /* Contains copy of fpregset struct. */;
enum NT_FPREGSET = 2   /* Contains copy of fpregset struct */;
enum NT_PRPSINFO = 3   /* Contains copy of prpsinfo struct */;
enum NT_PRXREG = 4     /* Contains copy of prxregset struct */;
enum NT_TASKSTRUCT = 4 /* Contains copy of task structure */;
enum NT_PLATFORM = 5   /* String from sysinfo(SI_PLATFORM) */;
enum NT_AUXV = 6       /* Contains copy of auxv array */;
enum NT_GWINDOWS = 7   /* Contains copy of gwindows struct */;
enum NT_ASRS = 8       /* Contains copy of asrset struct */;
enum NT_PSTATUS = 10   /* Contains copy of pstatus struct */;
enum NT_PSINFO = 13    /* Contains copy of psinfo struct */;
enum NT_PRCRED = 14    /* Contains copy of prcred struct */;
enum NT_UTSNAME = 15   /* Contains copy of utsname struct */;
enum NT_LWPSTATUS = 16 /* Contains copy of lwpstatus struct */;
enum NT_LWPSINFO = 17  /* Contains copy of lwpinfo struct */;
enum NT_PRFPXREG = 20  /* Contains copy of fprxregset struct */;
enum NT_SIGINFO = 0x53494749;
/* Contains copy of siginfo_t,
 * size might increase
 */
enum NT_FILE = 0x46494c45;
/* Contains information about mapped
 * files
 */
enum NT_PRXFPREG = 0x46e62b7f;
/* Contains copy of user_fxsr_struct */
enum NT_PPC_VMX = 0x100     /* PowerPC Altivec/VMX registers */;
enum NT_PPC_SPE = 0x101     /* PowerPC SPE/EVR registers */;
enum NT_PPC_VSX = 0x102     /* PowerPC VSX registers */;
enum NT_PPC_TAR = 0x103     /* Target Address Register */;
enum NT_PPC_PPR = 0x104     /* Program Priority Register */;
enum NT_PPC_DSCR = 0x105    /* Data Stream Control Register */;
enum NT_PPC_EBB = 0x106     /* Event Based Branch Registers */;
enum NT_PPC_PMU = 0x107     /* Performance Monitor Registers */;
enum NT_PPC_TM_CGPR = 0x108 /* TM checkpointed GPR Registers */;
enum NT_PPC_TM_CFPR = 0x109 /* TM checkpointed FPR Registers */;
enum NT_PPC_TM_CVMX = 0x10a /* TM checkpointed VMX Registers */;
enum NT_PPC_TM_CVSX = 0x10b /* TM checkpointed VSX Registers */;
enum NT_PPC_TM_SPR = 0x10c  /* TM Special Purpose Registers */;
enum NT_PPC_TM_CTAR =                      \
    0x10d /* TM checkpointed Target Address \
           * Register                       \
           */;
enum NT_PPC_TM_CPPR =                        \
    0x10e /* TM checkpointed Program Priority \
           * Register                         \
           */;
enum NT_PPC_TM_CDSCR =                          \
    0x10f /* TM checkpointed Data Stream Control \
           * Register                            \
           */;
enum NT_PPC_PKEY =                                         \
    0x110                         /* Memory Protection Keys \
                                   * registers.             \
                                   */;
enum NT_386_TLS = 0x200          /* i386 TLS slots (struct user_desc) */;
enum NT_386_IOPERM = 0x201       /* x86 io permission bitmap (1=deny) */;
enum NT_X86_XSTATE = 0x202       /* x86 extended state using xsave */;
enum NT_S390_HIGH_GPRS = 0x300   /* s390 upper register halves */;
enum NT_S390_TIMER = 0x301       /* s390 timer register */;
enum NT_S390_TODCMP = 0x302      /* s390 TOD clock comparator register */;
enum NT_S390_TODPREG = 0x303     /* s390 TOD programmable register */;
enum NT_S390_CTRS = 0x304        /* s390 control registers */;
enum NT_S390_PREFIX = 0x305      /* s390 prefix register */;
enum NT_S390_LAST_BREAK = 0x306  /* s390 breaking event address */;
enum NT_S390_SYSTEM_CALL = 0x307 /* s390 system call restart data */;
enum NT_S390_TDB = 0x308         /* s390 transaction diagnostic block */;
enum NT_S390_VXRS_LOW =                                      \
    0x309                       /* s390 vector registers 0-15 \
                                 * upper half.                \
                                 */;
enum NT_S390_VXRS_HIGH = 0x30a /* s390 vector registers 16-31.  */;
enum NT_S390_GS_CB = 0x30b     /* s390 guarded storage registers.  */;
enum NT_S390_GS_BC =                                        \
    0x30c                        /* s390 guarded storage     \
                                  * broadcast control block. \
                                  */;
enum NT_S390_RI_CB = 0x30d      /* s390 runtime instrumentation.  */;
enum NT_ARM_VFP = 0x400         /* ARM VFP/NEON registers */;
enum NT_ARM_TLS = 0x401         /* ARM TLS register */;
enum NT_ARM_HW_BREAK = 0x402    /* ARM hardware breakpoint registers */;
enum NT_ARM_HW_WATCH = 0x403    /* ARM hardware watchpoint registers */;
enum NT_ARM_SYSTEM_CALL = 0x404 /* ARM system call number */;
enum NT_ARM_SVE =                         \
    0x405 /* ARM Scalable Vector Extension \
           * registers                     \
           */;
enum NT_ARM_PAC_MASK =                 \
    0x406 /* ARM pointer authentication \
           * code masks.                \
           */;
enum NT_ARM_PACA_KEYS =                \
    0x407 /* ARM pointer authentication \
           * address keys.              \
           */;
enum NT_ARM_PACG_KEYS =                                    \
    0x408                     /* ARM pointer authentication \
                               * generic key.               \
                               */;
enum NT_VMCOREDD = 0x700     /* Vmcore Device Dump Note.  */;
enum NT_MIPS_DSP = 0x800     /* MIPS DSP ASE registers.  */;
enum NT_MIPS_FP_MODE = 0x801 /* MIPS floating-point mode.  */;
enum NT_MIPS_MSA = 0x802     /* MIPS SIMD registers.  */;

/* Legal values for the note segment descriptor types for object files.  */

enum NT_VERSION = 1 /* Contains a version string.  */;

 /* __INCLUDE_ELF_H */
