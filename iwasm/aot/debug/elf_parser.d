module elf_parser;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.stdio;
public import core.stdc.assert_;
public import core.sys.posix.fcntl;
public import core.stdc.stdlib;
public import core.sys.posix.unistd;
public import core.stdc.string;
public import core.stdc.errno;
public import stdbool;

public import elf;

public import aot_runtime;
public import bh_log;
public import elf_parser;

bool is_ELF(void* buf) {
    Elf32_Ehdr* eh = cast(Elf32_Ehdr*)buf;
    if (!strncmp(cast(char*)eh.e_ident, "\177ELF", 4)) {
        LOG_VERBOSE("the buffer is ELF entry!");
        return true;
    }
    LOG_VERBOSE("the buffer is not ELF entry!");
    return false;
}

private bool is64Bit(Elf32_Ehdr* eh) {
    if (eh.e_ident[EI_CLASS] == ELFCLASS64)
        return true;
    else
        return false;
}

private bool is32Bit(Elf32_Ehdr* eh) {
    if (eh.e_ident[EI_CLASS] == ELFCLASS32)
        return true;
    else
        return false;
}

bool is_ELF64(void* buf) {
    Elf64_Ehdr* eh = cast(Elf64_Ehdr*)buf;
    if (!strncmp(cast(char*)eh.e_ident, "\177ELF", 4)) {
        LOG_VERBOSE("the buffer is ELF entry!");
        return true;
    }
    LOG_VERBOSE("the buffer is not ELF entry!");
    return false;
}

private void read_section_header_table(Elf32_Ehdr* eh, Elf32_Shdr** sh_table) {
    uint i = void;
    char* buf = cast(char*)eh;
    buf += eh.e_shoff;
    LOG_VERBOSE("str index = %d count=%d", eh.e_shstrndx, eh.e_shnum);
    for (i = 0; i < eh.e_shnum; i++) {
        sh_table[i] = cast(Elf32_Shdr*)buf;
        buf += eh.e_shentsize;
    }
}

private void read_section_header_table64(Elf64_Ehdr* eh, Elf64_Shdr** sh_table) {
    uint i = void;
    char* buf = cast(char*)eh;
    buf += eh.e_shoff;

    for (i = 0; i < eh.e_shnum; i++) {
        sh_table[i] = cast(Elf64_Shdr*)buf;
        buf += eh.e_shentsize;
    }
}

private char* get_section(Elf32_Ehdr* eh, Elf32_Shdr* section_header) {
    char* buf = cast(char*)eh;
    return buf + section_header.sh_offset;
}

private char* get_section64(Elf64_Ehdr* eh, Elf64_Shdr* section_header) {
    char* buf = cast(char*)eh;
    return buf + section_header.sh_offset;
}

bool get_text_section(void* buf, ulong* offset, ulong* size) {
    bool ret = false;
    uint i = void;
    char* sh_str = void;

    if (is64Bit(buf)) {
        Elf64_Ehdr* eh = cast(Elf64_Ehdr*)buf;
        Elf64_Shdr** sh_table = wasm_runtime_malloc(eh.e_shnum * (Elf64_Shdr*).sizeof);
        if (sh_table) {
            read_section_header_table64(eh, sh_table);
            sh_str = get_section64(eh, sh_table[eh.e_shstrndx]);
            for (i = 0; i < eh.e_shnum; i++) {
                if (!strcmp(sh_str + sh_table[i].sh_name, ".text")) {
                    *offset = sh_table[i].sh_offset;
                    *size = sh_table[i].sh_size;
                    sh_table[i].sh_addr =
                        (Elf64_Addr)(uintptr_t)(cast(char*)buf
                                                + sh_table[i].sh_offset);
                    ret = true;
                    break;
                }
            }
            wasm_runtime_free(sh_table);
        }
    }
    else if (is32Bit(buf)) {
        Elf32_Ehdr* eh = cast(Elf32_Ehdr*)buf;
        Elf32_Shdr** sh_table = wasm_runtime_malloc(eh.e_shnum * (Elf32_Shdr*).sizeof);
        if (sh_table) {
            read_section_header_table(eh, sh_table);
            sh_str = get_section(eh, sh_table[eh.e_shstrndx]);
            for (i = 0; i < eh.e_shnum; i++) {
                if (!strcmp(sh_str + sh_table[i].sh_name, ".text")) {
                    *offset = sh_table[i].sh_offset;
                    *size = sh_table[i].sh_size;
                    sh_table[i].sh_addr =
                        (Elf32_Addr)(uintptr_t)(cast(char*)buf
                                                + sh_table[i].sh_offset);
                    ret = true;
                    break;
                }
            }
            wasm_runtime_free(sh_table);
        }
    }

    return ret;
}
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import stdbool;

version (none) {
extern "C" {
//! #endif

bool is_ELF(void* buf);

bool is_ELF64(void* buf);

bool get_text_section(void* buf, ulong* offset, ulong* size);

version (none) {}
}
}


