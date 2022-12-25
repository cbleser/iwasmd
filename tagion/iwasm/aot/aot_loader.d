module aot_loader;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_runtime;
public import bh_common;
public import bh_log;
public import aot_reloc;
public import ...common.wasm_runtime_common;
public import ...common.wasm_native;
public import ...compilation.aot;

static if (WASM_ENABLE_DEBUG_AOT != 0) {
public import debug.elf_parser;
public import debug.jit_debug;
}

enum YMM_PLT_PREFIX = "__ymm@";
enum XMM_PLT_PREFIX = "__xmm@";
enum REAL_PLT_PREFIX = "__real@";

private void set_error_buf(char* error_buf, uint error_buf_size, const(char)* string) {
    if (error_buf != null) {
        snprintf(error_buf, error_buf_size, "AOT module load failed: %s",
                 string);
    }
}

private void set_error_buf_v(char* error_buf, uint error_buf_size, const(char)* format, ...) {
    va_list args = void;
    char[128] buf = void;

    if (error_buf != null) {
        va_start(args, format);
        vsnprintf(buf.ptr, buf.sizeof, format, args);
        va_end(args);
        snprintf(error_buf, error_buf_size, "AOT module load failed: %s", buf.ptr);
    }
}

enum string exchange_uint8(string p_data) = ` (void)0`;

private void exchange_uint16(ubyte* p_data) {
    ubyte value = *p_data;
    *p_data = *(p_data + 1);
    *(p_data + 1) = value;
}

private void exchange_uint32(ubyte* p_data) {
    ubyte value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;

    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

private void exchange_uint64(ubyte* pData) {
    uint value = void;

    value = *cast(uint*)pData;
    *cast(uint*)pData = *cast(uint*)(pData + 4);
    *cast(uint*)(pData + 4) = value;
    exchange_uint32(pData);
    exchange_uint32(pData + 4);
}

union ___ue {
    int a;
    char b = 0;
}private ___ue __ue = { a: 1 };

enum string is_little_endian() = ` (__ue.b == 1)`;

private bool check_buf(const(ubyte)* buf, const(ubyte)* buf_end, uint length, char* error_buf, uint error_buf_size) {
    if (cast(uintptr_t)buf + length < cast(uintptr_t)buf
        || cast(uintptr_t)buf + length > cast(uintptr_t)buf_end) {
        set_error_buf(error_buf, error_buf_size, "unexpect end");
        return false;
    }
    return true;
}

enum string CHECK_BUF(string buf, string buf_end, string length) = `                                    \
    do {                                                                   \
        if (!check_buf(buf, buf_end, length, error_buf, error_buf_size)) { \
            goto fail;                                                     \
        }                                                                  \
    } while (0)`;

private ubyte* align_ptr(const(ubyte)* p, uint b) {
    uintptr_t v = cast(uintptr_t)p;
    uintptr_t m = b - 1;
    return cast(ubyte*)((v + m) & ~m);
}

pragma(inline, true) private ulong GET_U64_FROM_ADDR(uint* addr) {
    union _U {
        ulong val = void;
        uint[2] parts = void;
    }_U u = void;
    u.parts[0] = addr[0];
    u.parts[1] = addr[1];
    return u.val;
}

static if ((WASM_ENABLE_WORD_ALIGN_READ != 0)) {

pragma(inline, true) private ubyte GET_U8_FROM_ADDR(const(ubyte)* p) {
    ubyte res = 0;
    bh_assert(p);

    const(ubyte)* p_aligned = align_ptr(p, 4);
    p_aligned = (p_aligned > p) ? p_aligned - 4 : p_aligned;

    uint buf32 = *cast(const(uint)*)p_aligned;
    const(ubyte)* pbuf = cast(const(ubyte)*)&buf32;

    res = *cast(ubyte*)(pbuf + (p - p_aligned));

    return res;
}

pragma(inline, true) private ushort GET_U16_FROM_ADDR(const(ubyte)* p) {
    ushort res = 0;
    bh_assert(p);

    const(ubyte)* p_aligned = align_ptr(p, 4);
    p_aligned = (p_aligned > p) ? p_aligned - 4 : p_aligned;

    uint buf32 = *cast(const(uint)*)p_aligned;
    const(ubyte)* pbuf = cast(const(ubyte)*)&buf32;

    res = *cast(ushort*)(pbuf + (p - p_aligned));

    return res;
}

enum string TEMPLATE_READ(string p, string p_end, string res, string type) = `              \
    do {                                                \
        if (sizeof(type) != sizeof(uint64))             \
            p = (uint8 *)align_ptr(p, sizeof(type));    \
        else                                            \
            /* align 4 bytes if type is uint64 */       \
            p = (uint8 *)align_ptr(p, sizeof(uint32));  \
        CHECK_BUF(p, p_end, sizeof(type));              \
        if (sizeof(type) == sizeof(uint8))              \
            res = GET_U8_FROM_ADDR(p);                  \
        else if (sizeof(type) == sizeof(uint16))        \
            res = GET_U16_FROM_ADDR(p);                 \
        else if (sizeof(type) == sizeof(uint32))        \
            res = *(type *)p;                           \
        else                                            \
            res = (type)GET_U64_FROM_ADDR((uint32 *)p); \
        if (!is_little_endian())                        \
            exchange_##type((uint8 *)&res);             \
        p += sizeof(type);                              \
    } while (0)`;

enum string read_byte_array(string p, string p_end, string addr, string len) = ` \
    do {                                     \
        CHECK_BUF(p, p_end, len);            \
        bh_memcpy_wa(addr, len, p, len);     \
        p += len;                            \
    } while (0)`;

enum string read_string(string p, string p_end, string str) = `                                      \
    do {                                                                \
        if (!(str = load_string((uint8 **)&p, p_end, module,            \
                                is_load_from_file_buf, true, error_buf, \
                                error_buf_size)))                       \
            goto fail;                                                  \
    } while (0)`;

} else { /* else of (WASM_ENABLE_WORD_ALIGN_READ != 0) */

enum string TEMPLATE_READ(string p, string p_end, string res, string type) = `              \
    do {                                                \
        if (sizeof(type) != sizeof(uint64))             \
            p = (uint8 *)align_ptr(p, sizeof(type));    \
        else                                            \
            /* align 4 bytes if type is uint64 */       \
            p = (uint8 *)align_ptr(p, sizeof(uint32));  \
        CHECK_BUF(p, p_end, sizeof(type));              \
        if (sizeof(type) != sizeof(uint64))             \
            res = *(type *)p;                           \
        else                                            \
            res = (type)GET_U64_FROM_ADDR((uint32 *)p); \
        if (!is_little_endian())                        \
            exchange_##type((uint8 *)&res);             \
        p += sizeof(type);                              \
    } while (0)`;

enum string read_byte_array(string p, string p_end, string addr, string len) = ` \
    do {                                     \
        CHECK_BUF(p, p_end, len);            \
        bh_memcpy_s(addr, len, p, len);      \
        p += len;                            \
    } while (0)`;

enum string read_string(string p, string p_end, string str) = `                                \
    do {                                                          \
        if (!(str = load_string((uint8 **)&p, p_end, module,      \
                                is_load_from_file_buf, error_buf, \
                                error_buf_size)))                 \
            goto fail;                                            \
    } while (0)`;

} /* end of (WASM_ENABLE_WORD_ALIGN_READ != 0) */

enum string read_uint8(string p, string p_end, string res) = ` TEMPLATE_READ(p, p_end, res, uint8)`;
enum string read_uint16(string p, string p_end, string res) = ` TEMPLATE_READ(p, p_end, res, uint16)`;
enum string read_uint32(string p, string p_end, string res) = ` TEMPLATE_READ(p, p_end, res, uint32)`;
enum string read_uint64(string p, string p_end, string res) = ` TEMPLATE_READ(p, p_end, res, uint64)`;

/* Legal values for bin_type */
enum BIN_TYPE_ELF32L = 0 /* 32-bit little endian */;
enum BIN_TYPE_ELF32B = 1 /* 32-bit big endian */;
enum BIN_TYPE_ELF64L = 2 /* 64-bit little endian */;
enum BIN_TYPE_ELF64B = 3 /* 64-bit big endian */;
enum BIN_TYPE_COFF32 = 4 /* 32-bit little endian */;
enum BIN_TYPE_COFF64 = 6 /* 64-bit little endian */;

/* Legal values for e_type (object file type). */
enum E_TYPE_NONE = 0 /* No file type */;
enum E_TYPE_REL = 1  /* Relocatable file */;
enum E_TYPE_EXEC = 2 /* Executable file */;
enum E_TYPE_DYN = 3  /* Shared object file */;
enum E_TYPE_XIP = 4  /* eXecute In Place file */;

/* Legal values for e_machine (architecture).  */
enum E_MACHINE_386 = 3             /* Intel 80386 */;
enum E_MACHINE_MIPS = 8            /* MIPS R3000 big-endian */;
enum E_MACHINE_MIPS_RS3_LE = 10    /* MIPS R3000 little-endian */;
enum E_MACHINE_ARM = 40            /* ARM/Thumb */;
enum E_MACHINE_AARCH64 = 183       /* AArch64 */;
enum E_MACHINE_ARC = 45            /* Argonaut RISC Core */;
enum E_MACHINE_IA_64 = 50          /* Intel Merced */;
enum E_MACHINE_MIPS_X = 51         /* Stanford MIPS-X */;
enum E_MACHINE_X86_64 = 62         /* AMD x86-64 architecture */;
enum E_MACHINE_ARC_COMPACT = 93    /* ARC International ARCompact */;
enum E_MACHINE_ARC_COMPACT2 = 195  /* Synopsys ARCompact V2 */;
enum E_MACHINE_XTENSA = 94         /* Tensilica Xtensa Architecture */;
enum E_MACHINE_RISCV = 243         /* RISC-V 32/64 */;
enum E_MACHINE_WIN_I386 = 0x14c    /* Windows i386 architecture */;
enum E_MACHINE_WIN_X86_64 = 0x8664 /* Windows x86-64 architecture */;

/* Legal values for e_version */
enum E_VERSION_CURRENT = 1 /* Current version */;

private void* loader_malloc(ulong size, char* error_buf, uint error_buf_size) {
    void* mem = void;

    if (size >= UINT32_MAX || ((mem = wasm_runtime_malloc(cast(uint)size)) == 0)) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return null;
    }

    memset(mem, 0, cast(uint)size);
    return mem;
}

private char* const_str_set_insert(const(ubyte)* str, int len, AOTModule* module_, WASM_ENABLE_WORD_ALIGN_READ);
                     bool is_vram_word_align; bool* error_buf, set = module_.const_str_set;
    char* c_str, value;

    /* Create const string set if it isn't created */
    if (!set
        && ((set = module_.const_str_set = bh_hash_map_create(
                 32, false, cast(HashFunc)wasm_string_hash,
                 cast(KeyEqualFunc)wasm_string_equal, null, wasm_runtime_free)) == 0)) {
        set_error_buf(error_buf, error_buf_size,
                      "create const string set failed");
        return null;
    }

    /* Lookup const string set, use the string if found */
    if (((c_str = loader_malloc(cast(uint)len + 1, error_buf, error_buf_size)) == 0)) {
        return null;
    }
static if ((WASM_ENABLE_WORD_ALIGN_READ != 0)) {
    if (is_vram_word_align) {
        bh_memcpy_wa(c_str, (uint32)(len + 1), str, cast(uint)len);
    }
    else
}
    {
        bh_memcpy_s(c_str, (uint32)(len + 1), str, cast(uint)len);
    }
    c_str[len] = '\0';

    if ((value = bh_hash_map_find(set, c_str))) {
        wasm_runtime_free(c_str);
        return value;
    }

    if (!bh_hash_map_insert(set, c_str, c_str)) {
        set_error_buf(error_buf, error_buf_size,
                      "insert string to hash map failed");
        wasm_runtime_free(c_str);
        return null;
    }

    return c_str;
}

private char* load_string(ubyte** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, WASM_ENABLE_WORD_ALIGN_READ);
            bool is_vram_word_align; bool* error_buf, p = *p_buf;
    const(ubyte)* p_end = buf_end;
    char* str;
    ushort str_len;

    read_uint16(p, p_end, str_len);
    CHECK_BUF(p, p_end, str_len);

    if (str_len == 0) {
        str = "";
    }
static if ((WASM_ENABLE_WORD_ALIGN_READ != 0)) {
    else if(is_vram_word_align) {
        if (((str = const_str_set_insert(cast(ubyte*)p, str_len, module_,
                                         is_vram_word_align, error_buf,
                                         error_buf_size)) == 0)) {
            goto fail;
        }
    }
}
    else if = {
        /* The string is terminated with '\0', use it directly */
        str = cast(char*)p;
    };
    else if(is_load_from_file_buf) {
        /* As the file buffer can be referred to after loading,
           we use the 2 bytes of size to adjust the string:
           move string 2 byte backward and then append '\0' */
        str = cast(char*)(p - 2);
        bh_memmove_s(str, (uint32)(str_len + 1), p, cast(uint)str_len);
        str[str_len] = '\0';
    }
    else {
        /* Load from sections, the file buffer cannot be reffered to
           after loading, we must create another string and insert it
           into const string set */
        if (((str = const_str_set_insert(cast(ubyte*)p, str_len, module_,
#if (WASM_ENABLE_WORD_ALIGN_READ != 0)
                                         is_vram_word_align,
#endif
                                         error_buf, error_buf_size)) == 0)) {
            goto fail;
        }
    }
    p += str_len;

    *p_buf = p;
    return str;
fail:
    return null;
}

private bool get_aot_file_target(AOTTargetInfo* target_info, char* target_buf, uint target_buf_size, char* error_buf, uint error_buf_size) {
    char* machine_type = null;
    switch (target_info.e_machine) {
        case E_MACHINE_X86_64:
        case E_MACHINE_WIN_X86_64:
            machine_type = "x86_64";
            break;
        case E_MACHINE_386:
        case E_MACHINE_WIN_I386:
            machine_type = "i386";
            break;
        case E_MACHINE_ARM:
        case E_MACHINE_AARCH64:
            machine_type = target_info.arch;
            break;
        case E_MACHINE_MIPS:
            machine_type = "mips";
            break;
        case E_MACHINE_XTENSA:
            machine_type = "xtensa";
            break;
        case E_MACHINE_RISCV:
            machine_type = "riscv";
            break;
        case E_MACHINE_ARC_COMPACT:
        case E_MACHINE_ARC_COMPACT2:
            machine_type = "arc";
            break;
        default:
            set_error_buf_v(error_buf, error_buf_size,
                            "unknown machine type %d", target_info.e_machine);
            return false;
    }
    if (strncmp(target_info.arch, machine_type, strlen(machine_type))) {
        set_error_buf_v(
            error_buf, error_buf_size,
            "machine type (%s) isn't consistent with target type (%s)",
            machine_type, target_info.arch);
        return false;
    }
    snprintf(target_buf, target_buf_size, "%s", target_info.arch);
    return true;
}

private bool check_machine_info(AOTTargetInfo* target_info, char* error_buf, uint error_buf_size) {
    char[32] target_expected = void, target_got = void;

    get_current_target(target_expected.ptr, target_expected.sizeof);

    if (!get_aot_file_target(target_info, target_got.ptr, target_got.sizeof,
                             error_buf, error_buf_size))
        return false;

    if (strncmp(target_expected.ptr, target_got.ptr, strlen(target_expected.ptr))) {
        set_error_buf_v(error_buf, error_buf_size,
                        "invalid target type, expected %s but got %s",
                        target_expected.ptr, target_got.ptr);
        return false;
    }

    return true;
}

private bool load_target_info_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    AOTTargetInfo target_info = void;
    const(ubyte)* p = buf, p_end = buf_end;
    bool is_target_little_endian = void, is_target_64_bit = void;

    read_uint16(p, p_end, target_info.bin_type);
    read_uint16(p, p_end, target_info.abi_type);
    read_uint16(p, p_end, target_info.e_type);
    read_uint16(p, p_end, target_info.e_machine);
    read_uint32(p, p_end, target_info.e_version);
    read_uint32(p, p_end, target_info.e_flags);
    read_uint32(p, p_end, target_info.reserved);
    read_byte_array(p, p_end, target_info.arch, typeof(target_info.arch).sizeof);

    if (p != buf_end) {
        set_error_buf(error_buf, error_buf_size, "invalid section size");
        return false;
    }

    /* Check target endian type */
    is_target_little_endian = target_info.bin_type & 1 ? false : true;
    if (is_little_endian() != is_target_little_endian) {
        set_error_buf_v(error_buf, error_buf_size,
                        "invalid target endian type, expected %s but got %s",
                        is_little_endian() ? "little endian" : "big endian",
                        is_target_little_endian ? "little endian"
                                                : "big endian");
        return false;
    }

    /* Check target bit width */
    is_target_64_bit = target_info.bin_type & 2 ? true : false;
    if (((void*).sizeof == 8 ? true : false) != is_target_64_bit) {
        set_error_buf_v(error_buf, error_buf_size,
                        "invalid target bit width, expected %s but got %s",
                        (void*).sizeof == 8 ? "64-bit" : "32-bit",
                        is_target_64_bit ? "64-bit" : "32-bit");
        return false;
    }

    /* Check target elf file type */
    if (target_info.e_type != E_TYPE_REL && target_info.e_type != E_TYPE_XIP) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid object file type, "
                      ~ "expected relocatable or XIP file type but got others");
        return false;
    }

    /* Check machine info */
    if (!check_machine_info(&target_info, error_buf, error_buf_size)) {
        return false;
    }

    if (target_info.e_version != E_VERSION_CURRENT) {
        set_error_buf(error_buf, error_buf_size, "invalid elf file version");
        return false;
    }

    return true;
fail:
    return false;
}

private void* get_native_symbol_by_name(const(char)* name) {
    void* func = null;
    uint symnum = 0;
    SymbolMap* sym = null;

    sym = get_target_symbol_map(&symnum);

    while (symnum--) {
        if (strcmp(sym.symbol_name, name) == 0) {
            func = sym.symbol_addr;
            break;
        }
        sym++;
    }

    return func;
}

private bool str2uint32(const(char)* buf, uint* p_res);

private bool str2uint64(const(char)* buf, ulong* p_res);

private bool load_native_symbol_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint cnt = void;
    int i = void;
    const(char)* symbol = void;

    read_uint32(p, p_end, cnt);

    if (cnt > 0) {
        module_.native_symbol_list = wasm_runtime_malloc(cnt * (void*).sizeof);
        if (module_.native_symbol_list == null) {
            set_error_buf(error_buf, error_buf_size,
                          "malloc native symbol list failed");
            goto fail;
        }

        for (i = cnt - 1; i >= 0; i--) {
            read_string(p, p_end, symbol);
            if (!strncmp(symbol, "f32#", 4) || !strncmp(symbol, "i32#", 4)) {
                uint u32 = void;
                /* Resolve the raw int bits of f32 const */
                if (!str2uint32(symbol + 4, &u32)) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "resolve symbol %s failed", symbol);
                    goto fail;
                }
                *cast(uint*)(&module_.native_symbol_list[i]) = u32;
            }
            else if (!strncmp(symbol, "f64#", 4)
                     || !strncmp(symbol, "i64#", 4)) {
                ulong u64 = void;
                /* Resolve the raw int bits of f64 const */
                if (!str2uint64(symbol + 4, &u64)) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "resolve symbol %s failed", symbol);
                    goto fail;
                }
                *cast(ulong*)(&module_.native_symbol_list[i]) = u64;
            }
            else if (!strncmp(symbol, "__ignore", 8)) {
                /* Padding bytes to make f64 on 8-byte aligned address,
                   or it is the second 32-bit slot in 32-bit system */
                continue;
            }
            else {
                module_.native_symbol_list[i] =
                    get_native_symbol_by_name(symbol);
                if (module_.native_symbol_list[i] == null) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "missing native symbol: %s", symbol);
                    goto fail;
                }
            }
        }
    }

    return true;
fail:
    return false;
}

private bool load_name_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint* aux_func_indexes = void;
    const(char)** aux_func_names = void;
    uint name_type = void, subsection_size = void;
    uint previous_name_type = 0;
    uint num_func_name = void;
    uint func_index = void;
    uint previous_func_index = ~0U;
    uint name_index = void;
    int i = 0;
    uint name_len = void;
    ulong size = void;

    if (p >= p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }

    read_uint32(p, p_end, name_len);

    if (name_len != 4 || p + name_len > p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }

    if (memcmp(p, "name", 4) != 0) {
        set_error_buf(error_buf, error_buf_size, "invalid custom name section");
        return false;
    }
    p += name_len;

    while (p < p_end) {
        read_uint32(p, p_end, name_type);
        if (i != 0) {
            if (name_type == previous_name_type) {
                set_error_buf(error_buf, error_buf_size,
                              "duplicate sub-section");
                return false;
            }
            if (name_type < previous_name_type) {
                set_error_buf(error_buf, error_buf_size,
                              "out-of-order sub-section");
                return false;
            }
        }
        previous_name_type = name_type;
        read_uint32(p, p_end, subsection_size);
        CHECK_BUF(p, p_end, subsection_size);
        switch (name_type) {
            case SUB_SECTION_TYPE_FUNC:
                if (subsection_size) {
                    read_uint32(p, p_end, num_func_name);
                    if (num_func_name
                        > module_.import_func_count + module_.func_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "function name count out of bounds");
                        return false;
                    }
                    module_.aux_func_name_count = num_func_name;

                    /* Allocate memory */
                    size = sizeof(uint32) * cast(ulong)module_.aux_func_name_count;
                    if (((aux_func_indexes = module_.aux_func_indexes =
                              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
                        return false;
                    }
                    size =
                        (char**).sizeof * cast(ulong)module_.aux_func_name_count;
                    if (((aux_func_names = module_.aux_func_names =
                              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
                        return false;
                    }

                    for (name_index = 0; name_index < num_func_name;
                         name_index++) {
                        read_uint32(p, p_end, func_index);
                        if (name_index != 0
                            && func_index == previous_func_index) {
                            set_error_buf(error_buf, error_buf_size,
                                          "duplicate function name");
                            return false;
                        }
                        if (name_index != 0
                            && func_index < previous_func_index) {
                            set_error_buf(error_buf, error_buf_size,
                                          "out-of-order function index ");
                            return false;
                        }
                        if (func_index
                            >= module_.import_func_count + module_.func_count) {
                            set_error_buf(error_buf, error_buf_size,
                                          "function index out of bounds");
                            return false;
                        }
                        previous_func_index = func_index;
                        *(aux_func_indexes + name_index) = func_index;
                        read_string(p, p_end, *(aux_func_names + name_index));
version (none) {
                        LOG_DEBUG("func_index %u -> aux_func_name = %s\n",
                               func_index, *(aux_func_names + name_index));
}
                    }
                }
                break;
            case SUB_SECTION_TYPE_MODULE: /* TODO: Parse for module subsection
                                           */
            case SUB_SECTION_TYPE_LOCAL:  /* TODO: Parse for local subsection */
            default:
                p = p + subsection_size;
                break;
        }
        i++;
    }

    return true;
fail:
    return false;
} else {
    return true;
} /* WASM_ENABLE_CUSTOM_NAME_SECTION != 0 */
}

private bool load_custom_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint sub_section_type = void;

    read_uint32(p, p_end, sub_section_type);
    buf = p;

    switch (sub_section_type) {
        case AOT_CUSTOM_SECTION_NATIVE_SYMBOL:
            if (!load_native_symbol_section(buf, buf_end, module_,
                                            is_load_from_file_buf, error_buf,
                                            error_buf_size))
                goto fail;
            break;
        case AOT_CUSTOM_SECTION_NAME:
            if (!load_name_section(buf, buf_end, module_, is_load_from_file_buf,
                                   error_buf, error_buf_size))
                goto fail;
            break;
static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
        case AOT_CUSTOM_SECTION_RAW:
        {
            const(char)* section_name = void;
            WASMCustomSection* section = void;

            if (p >= p_end) {
                set_error_buf(error_buf, error_buf_size, "unexpected end");
                goto fail;
            }

            read_string(p, p_end, section_name);

            section = loader_malloc(WASMCustomSection.sizeof, error_buf,
                                    error_buf_size);
            if (!section) {
                goto fail;
            }

            section.name_addr = cast(char*)section_name;
            section.name_len = cast(uint)strlen(section_name);
            section.content_addr = cast(ubyte*)p;
            section.content_len = (uint32)(p_end - p);

            section.next = module_.custom_section_list;
            module_.custom_section_list = section;
            LOG_VERBOSE("Load custom section [%s] success.", section_name);
            break;
        }
} /* end of WASM_ENABLE_LOAD_CUSTOM_SECTION != 0 */
        default:
            break;
    }

    return true;
fail:
    return false;
}

private void destroy_import_memories(AOTImportMemory* import_memories) {
    wasm_runtime_free(import_memories);
}

private void destroy_mem_init_data_list(AOTMemInitData** data_list, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (data_list[i])
            wasm_runtime_free(data_list[i]);
    wasm_runtime_free(data_list);
}

private bool load_mem_init_data_list(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTMemInitData** data_list = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = (AOTMemInitData*).sizeof * cast(ulong)module_.mem_init_data_count;
    if (((module_.mem_init_data_list = data_list =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each memory data segment */
    for (i = 0; i < module_.mem_init_data_count; i++) {
        uint init_expr_type = void, byte_count = void;
        ulong init_expr_value = void;
        uint is_passive = void;
        uint memory_index = void;

        read_uint32(buf, buf_end, is_passive);
        read_uint32(buf, buf_end, memory_index);
        read_uint32(buf, buf_end, init_expr_type);
        read_uint64(buf, buf_end, init_expr_value);
        read_uint32(buf, buf_end, byte_count);
        size = AOTMemInitData.bytes.offsetof + cast(ulong)byte_count;
        if (((data_list[i] = loader_malloc(size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

static if (WASM_ENABLE_BULK_MEMORY != 0) {
        /* is_passive and memory_index is only used in bulk memory mode */
        data_list[i].is_passive = cast(bool)is_passive;
        data_list[i].memory_index = memory_index;
}
        data_list[i].offset.init_expr_type = cast(ubyte)init_expr_type;
        data_list[i].offset.u.i64 = cast(long)init_expr_value;
        data_list[i].byte_count = byte_count;
        read_byte_array(buf, buf_end, data_list[i].bytes,
                        data_list[i].byte_count);
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_memory_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    uint i = void;
    ulong total_size = void;
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.import_memory_count);
    /* We don't support import_memory_count > 0 currently */
    bh_assert(module_.import_memory_count == 0);

    read_uint32(buf, buf_end, module_.memory_count);
    total_size = sizeof(AOTMemory) * cast(ulong)module_.memory_count;
    if (((module_.memories =
              loader_malloc(total_size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    for (i = 0; i < module_.memory_count; i++) {
        read_uint32(buf, buf_end, module_.memories[i].memory_flags);
        read_uint32(buf, buf_end, module_.memories[i].num_bytes_per_page);
        read_uint32(buf, buf_end, module_.memories[i].mem_init_page_count);
        read_uint32(buf, buf_end, module_.memories[i].mem_max_page_count);
    }

    read_uint32(buf, buf_end, module_.mem_init_data_count);

    /* load memory init data list */
    if (module_.mem_init_data_count > 0
        && !load_mem_init_data_list(&buf, buf_end, module_, error_buf,
                                    error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private void destroy_import_tables(AOTImportTable* import_tables) {
    wasm_runtime_free(import_tables);
}

private void destroy_tables(AOTTable* tables) {
    wasm_runtime_free(tables);
}

private void destroy_table_init_data_list(AOTTableInitData** data_list, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (data_list[i])
            wasm_runtime_free(data_list[i]);
    wasm_runtime_free(data_list);
}

private bool load_import_table_list(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTImportTable* import_table = void;
    ulong size = void;
    uint i = void, possible_grow = void;

    /* Allocate memory */
    size = sizeof(AOTImportTable) * cast(ulong)module_.import_table_count;
    if (((module_.import_tables = import_table =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* keep sync with aot_emit_table_info() aot_emit_aot_file */
    for (i = 0; i < module_.import_table_count; i++, import_table++) {
        read_uint32(buf, buf_end, import_table.elem_type);
        read_uint32(buf, buf_end, import_table.table_init_size);
        read_uint32(buf, buf_end, import_table.table_max_size);
        read_uint32(buf, buf_end, possible_grow);
        import_table.possible_grow = (possible_grow & 0x1);
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_table_list(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTTable* table = void;
    ulong size = void;
    uint i = void, possible_grow = void;

    /* Allocate memory */
    size = sizeof(AOTTable) * cast(ulong)module_.table_count;
    if (((module_.tables = table =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each table data segment */
    for (i = 0; i < module_.table_count; i++, table++) {
        read_uint32(buf, buf_end, table.elem_type);
        read_uint32(buf, buf_end, table.table_flags);
        read_uint32(buf, buf_end, table.table_init_size);
        read_uint32(buf, buf_end, table.table_max_size);
        read_uint32(buf, buf_end, possible_grow);
        table.possible_grow = (possible_grow & 0x1);
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_table_init_data_list(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTTableInitData** data_list = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = (AOTTableInitData*).sizeof * cast(ulong)module_.table_init_data_count;
    if (((module_.table_init_data_list = data_list =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each table data segment */
    for (i = 0; i < module_.table_init_data_count; i++) {
        uint mode = void, elem_type = void;
        uint table_index = void, init_expr_type = void, func_index_count = void;
        ulong init_expr_value = void, size1 = void;

        read_uint32(buf, buf_end, mode);
        read_uint32(buf, buf_end, elem_type);
        read_uint32(buf, buf_end, table_index);
        read_uint32(buf, buf_end, init_expr_type);
        read_uint64(buf, buf_end, init_expr_value);
        read_uint32(buf, buf_end, func_index_count);

        size1 = sizeof(uint32) * cast(ulong)func_index_count;
        size = AOTTableInitData.func_indexes.offsetof + size1;
        if (((data_list[i] = loader_malloc(size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        data_list[i].mode = mode;
        data_list[i].elem_type = elem_type;
        data_list[i].is_dropped = false;
        data_list[i].table_index = table_index;
        data_list[i].offset.init_expr_type = cast(ubyte)init_expr_type;
        data_list[i].offset.u.i64 = cast(long)init_expr_value;
        data_list[i].func_index_count = func_index_count;
        read_byte_array(buf, buf_end, data_list[i].func_indexes,
                        cast(uint)size1);
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_table_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.import_table_count);
    if (module_.import_table_count > 0
        && !load_import_table_list(&buf, buf_end, module_, error_buf,
                                   error_buf_size))
        return false;

    read_uint32(buf, buf_end, module_.table_count);
    if (module_.table_count > 0
        && !load_table_list(&buf, buf_end, module_, error_buf, error_buf_size))
        return false;

    read_uint32(buf, buf_end, module_.table_init_data_count);

    /* load table init data list */
    if (module_.table_init_data_count > 0
        && !load_table_init_data_list(&buf, buf_end, module_, error_buf,
                                      error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private void destroy_func_types(AOTFuncType** func_types, uint count) {
    uint i = void;
    for (i = 0; i < count; i++)
        if (func_types[i])
            wasm_runtime_free(func_types[i]);
    wasm_runtime_free(func_types);
}

private bool load_func_types(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTFuncType** func_types = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = (AOTFuncType*).sizeof * cast(ulong)module_.func_type_count;
    if (((module_.func_types = func_types =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each function type */
    for (i = 0; i < module_.func_type_count; i++) {
        uint param_count = void, result_count = void;
        uint param_cell_num = void, ret_cell_num = void;
        ulong size1 = void;

        read_uint32(buf, buf_end, param_count);
        read_uint32(buf, buf_end, result_count);

        if (param_count > UINT16_MAX || result_count > UINT16_MAX) {
            set_error_buf(error_buf, error_buf_size,
                          "param count or result count too large");
            return false;
        }

        size1 = cast(ulong)param_count + cast(ulong)result_count;
        size = AOTFuncType.types.offsetof + size1;
        if (((func_types[i] = loader_malloc(size, error_buf, error_buf_size)) == 0)) {
            return false;
        }

        func_types[i].param_count = cast(ushort)param_count;
        func_types[i].result_count = cast(ushort)result_count;
        read_byte_array(buf, buf_end, func_types[i].types, cast(uint)size1);

        param_cell_num = wasm_get_cell_num(func_types[i].types, param_count);
        ret_cell_num =
            wasm_get_cell_num(func_types[i].types + param_count, result_count);
        if (param_cell_num > UINT16_MAX || ret_cell_num > UINT16_MAX) {
            set_error_buf(error_buf, error_buf_size,
                          "param count or result count too large");
            return false;
        }

        func_types[i].param_cell_num = cast(ushort)param_cell_num;
        func_types[i].ret_cell_num = cast(ushort)ret_cell_num;
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_func_type_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.func_type_count);

    /* load function type */
    if (module_.func_type_count > 0
        && !load_func_types(&buf, buf_end, module_, error_buf, error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private void destroy_import_globals(AOTImportGlobal* import_globals) {
    wasm_runtime_free(import_globals);
}

private bool load_import_globals(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTImportGlobal* import_globals = void;
    ulong size = void;
    uint i = void, data_offset = 0;
static if (WASM_ENABLE_LIBC_BUILTIN != 0) {
    WASMGlobalImport tmp_global = void;
}

    /* Allocate memory */
    size = sizeof(AOTImportGlobal) * cast(ulong)module_.import_global_count;
    if (((module_.import_globals = import_globals =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each import global */
    for (i = 0; i < module_.import_global_count; i++) {
        buf = cast(ubyte*)align_ptr(buf, 2);
        read_uint8(buf, buf_end, import_globals[i].type);
        read_uint8(buf, buf_end, import_globals[i].is_mutable);
        read_string(buf, buf_end, import_globals[i].module_name);
        read_string(buf, buf_end, import_globals[i].global_name);

static if (WASM_ENABLE_LIBC_BUILTIN != 0) {
        if (wasm_native_lookup_libc_builtin_global(
                import_globals[i].module_name, import_globals[i].global_name,
                &tmp_global)) {
            if (tmp_global.type != import_globals[i].type
                || tmp_global.is_mutable != import_globals[i].is_mutable) {
                set_error_buf(error_buf, error_buf_size,
                              "incompatible import type");
                return false;
            }
            import_globals[i].global_data_linked =
                tmp_global.global_data_linked;
        }
}

        import_globals[i].size = wasm_value_type_size(import_globals[i].type);
        import_globals[i].data_offset = data_offset;
        data_offset += import_globals[i].size;
        module_.global_data_size += import_globals[i].size;
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_import_global_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.import_global_count);

    /* load import globals */
    if (module_.import_global_count > 0
        && !load_import_globals(&buf, buf_end, module_, is_load_from_file_buf,
                                error_buf, error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private void destroy_globals(AOTGlobal* globals) {
    wasm_runtime_free(globals);
}

private bool load_globals(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTGlobal* globals = void;
    ulong size = void;
    uint i = void, data_offset = 0;
    AOTImportGlobal* last_import_global = void;

    /* Allocate memory */
    size = sizeof(AOTGlobal) * cast(ulong)module_.global_count;
    if (((module_.globals = globals =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    if (module_.import_global_count > 0) {
        last_import_global =
            &module_.import_globals[module_.import_global_count - 1];
        data_offset =
            last_import_global.data_offset + last_import_global.size;
    }

    /* Create each global */
    for (i = 0; i < module_.global_count; i++) {
        ushort init_expr_type = void;

        read_uint8(buf, buf_end, globals[i].type);
        read_uint8(buf, buf_end, globals[i].is_mutable);
        read_uint16(buf, buf_end, init_expr_type);

        if (init_expr_type != INIT_EXPR_TYPE_V128_CONST) {
            read_uint64(buf, buf_end, globals[i].init_expr.u.i64);
        }
        else {
            ulong* i64x2 = cast(ulong*)globals[i].init_expr.u.v128.i64x2;
            CHECK_BUF(buf, buf_end, sizeof(uint64) * 2);
            wasm_runtime_read_v128(buf, &i64x2[0], &i64x2[1]);
            buf += sizeof(uint64) * 2;
        }

        globals[i].init_expr.init_expr_type = cast(ubyte)init_expr_type;

        globals[i].size = wasm_value_type_size(globals[i].type);
        globals[i].data_offset = data_offset;
        data_offset += globals[i].size;
        module_.global_data_size += globals[i].size;
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_global_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.global_count);

    /* load globals */
    if (module_.global_count > 0
        && !load_globals(&buf, buf_end, module_, error_buf, error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private void destroy_import_funcs(AOTImportFunc* import_funcs) {
    wasm_runtime_free(import_funcs);
}

private bool load_import_funcs(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(char)* module_name = void, field_name = void;
    const(ubyte)* buf = *p_buf;
    AOTImportFunc* import_funcs = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = sizeof(AOTImportFunc) * cast(ulong)module_.import_func_count;
    if (((module_.import_funcs = import_funcs =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each import func */
    for (i = 0; i < module_.import_func_count; i++) {
        read_uint16(buf, buf_end, import_funcs[i].func_type_index);
        if (import_funcs[i].func_type_index >= module_.func_type_count) {
            set_error_buf(error_buf, error_buf_size, "unknown type");
            return false;
        }
        import_funcs[i].func_type =
            module_.func_types[import_funcs[i].func_type_index];
        read_string(buf, buf_end, import_funcs[i].module_name);
        read_string(buf, buf_end, import_funcs[i].func_name);

        module_name = import_funcs[i].module_name;
        field_name = import_funcs[i].func_name;
        import_funcs[i].func_ptr_linked = wasm_native_resolve_symbol(
            module_name, field_name, import_funcs[i].func_type,
            &import_funcs[i].signature, &import_funcs[i].attachment,
            &import_funcs[i].call_conv_raw);

static if (WASM_ENABLE_LIBC_WASI != 0) {
        if (!strcmp(import_funcs[i].module_name, "wasi_unstable")
            || !strcmp(import_funcs[i].module_name, "wasi_snapshot_preview1"))
            module_.import_wasi_api = true;
}
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_import_func_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.import_func_count);

    /* load import funcs */
    if (module_.import_func_count > 0
        && !load_import_funcs(&buf, buf_end, module_, is_load_from_file_buf,
                              error_buf, error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private void destroy_object_data_sections(AOTObjectDataSection* data_sections, uint data_section_count) {
    uint i = void;
    AOTObjectDataSection* data_section = data_sections;
    for (i = 0; i < data_section_count; i++, data_section++)
        if (data_section.data)
            os_munmap(data_section.data, data_section.size);
    wasm_runtime_free(data_sections);
}

private bool load_object_data_sections(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTObjectDataSection* data_sections = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = sizeof(AOTObjectDataSection) * cast(ulong)module_.data_section_count;
    if (((module_.data_sections = data_sections =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each data section */
    for (i = 0; i < module_.data_section_count; i++) {
        int map_prot = MMAP_PROT_READ | MMAP_PROT_WRITE;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64" \
    || HasVersion!"BUILD_TARGET_RISCV64_LP64D"                       \
    || HasVersion!"BUILD_TARGET_RISCV64_LP64") {
        /* aot code and data in x86_64 must be in range 0 to 2G due to
           relocation for R_X86_64_32/32S/PC32 */
        int map_flags = MMAP_MAP_32BIT;
} else {
        int map_flags = MMAP_MAP_NONE;
}

        read_string(buf, buf_end, data_sections[i].name);
        read_uint32(buf, buf_end, data_sections[i].size);

        /* Allocate memory for data */
        if (data_sections[i].size > 0
            && ((data_sections[i].data = os_mmap(null, data_sections[i].size,
                                                 map_prot, map_flags)) == 0)) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
            return false;
        }
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
static if (!HasVersion!"BH_PLATFORM_LINUX_SGX" && !HasVersion!"BH_PLATFORM_WINDOWS" \
    && !HasVersion!"BH_PLATFORM_DARWIN") {
        /* address must be in the first 2 Gigabytes of
           the process address space */
        bh_assert(cast(uintptr_t)data_sections[i].data < INT32_MAX);
}
}

        read_byte_array(buf, buf_end, data_sections[i].data,
                        data_sections[i].size);
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_object_data_sections_info(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;

    read_uint32(buf, buf_end, module_.data_section_count);

    /* load object data sections */
    if (module_.data_section_count > 0
        && !load_object_data_sections(&buf, buf_end, module_,
                                      is_load_from_file_buf, error_buf,
                                      error_buf_size))
        return false;

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_init_data_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;

    if (!load_memory_info(&p, p_end, module_, error_buf, error_buf_size)
        || !load_table_info(&p, p_end, module_, error_buf, error_buf_size)
        || !load_func_type_info(&p, p_end, module_, error_buf, error_buf_size)
        || !load_import_global_info(&p, p_end, module_, is_load_from_file_buf,
                                    error_buf, error_buf_size)
        || !load_global_info(&p, p_end, module_, error_buf, error_buf_size)
        || !load_import_func_info(&p, p_end, module_, is_load_from_file_buf,
                                  error_buf, error_buf_size))
        return false;

    /* load function count and start function index */
    read_uint32(p, p_end, module_.func_count);
    read_uint32(p, p_end, module_.start_func_index);

    /* check start function index */
    if (module_.start_func_index != (uint32)-1
        && (module_.start_func_index
            >= module_.import_func_count + module_.func_count)) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid start function index");
        return false;
    }

    read_uint32(p, p_end, module_.aux_data_end_global_index);
    read_uint32(p, p_end, module_.aux_data_end);
    read_uint32(p, p_end, module_.aux_heap_base_global_index);
    read_uint32(p, p_end, module_.aux_heap_base);
    read_uint32(p, p_end, module_.aux_stack_top_global_index);
    read_uint32(p, p_end, module_.aux_stack_bottom);
    read_uint32(p, p_end, module_.aux_stack_size);

    if (!load_object_data_sections_info(&p, p_end, module_,
                                        is_load_from_file_buf, error_buf,
                                        error_buf_size))
        return false;

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid init data section size");
        return false;
    }

    return true;
fail:
    return false;
}

private bool load_text_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    ubyte* plt_base = void;

    if (module_.func_count > 0 && buf_end == buf) {
        set_error_buf(error_buf, error_buf_size, "invalid code size");
        return false;
    }

    /* The layout is: literal size + literal + code (with plt table) */
    read_uint32(buf, buf_end, module_.literal_size);

    /* literal data is at beginning of the text section */
    module_.literal = cast(ubyte*)buf;
    module_.code = cast(void*)(buf + module_.literal_size);
    module_.code_size = (uint32)(buf_end - cast(ubyte*)module_.code);

static if (WASM_ENABLE_DEBUG_AOT != 0) {
    module_.elf_size = module_.code_size;

    if (is_ELF(module_.code)) {
        /* Now code points to an ELF object, we pull it down to .text section */
        ulong offset = void;
        ulong size = void;
        char* code_buf = module_.code;
        module_.elf_hdr = code_buf;
        if (!get_text_section(code_buf, &offset, &size)) {
            set_error_buf(error_buf, error_buf_size,
                          "get text section of ELF failed");
            return false;
        }
        module_.code = code_buf + offset;
        module_.code_size -= cast(uint)offset;
    }
}

    if ((module_.code_size > 0) && !module_.is_indirect_mode) {
        plt_base = cast(ubyte*)buf_end - get_plt_table_size();
        init_plt_table(plt_base);
    }
    return true;
fail:
    return false;
}

private bool load_function_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;
    uint i = void;
    ulong size = void, text_offset = void;
static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
    RUNTIME_FUNCTION* rtl_func_table = void;
    AOTUnwindInfo* unwind_info = void;
    uint unwind_info_offset = module_.code_size - AOTUnwindInfo.sizeof;
    uint unwind_code_offset = unwind_info_offset - PLT_ITEM_SIZE;
}

static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
    unwind_info = cast(AOTUnwindInfo*)(cast(ubyte*)module_.code + module_.code_size
                                    - AOTUnwindInfo.sizeof);
    unwind_info.Version = 1;
    unwind_info.Flags = UNW_FLAG_NHANDLER;
    *cast(uint*)&unwind_info.UnwindCode[0] = unwind_code_offset;

    size = sizeof(RUNTIME_FUNCTION) * cast(ulong)module_.func_count;
    if (size > 0
        && ((rtl_func_table = module_.rtl_func_table =
                 loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }
}

    size = (void*).sizeof * cast(ulong)module_.func_count;
    if (size > 0
        && ((module_.func_ptrs =
                 loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    for (i = 0; i < module_.func_count; i++) {
        if ((void*).sizeof == 8) {
            read_uint64(p, p_end, text_offset);
        }
        else {
            uint text_offset32 = void;
            read_uint32(p, p_end, text_offset32);
            text_offset = text_offset32;
        }
        if (text_offset >= module_.code_size) {
            set_error_buf(error_buf, error_buf_size,
                          "invalid function code offset");
            return false;
        }
        module_.func_ptrs[i] = cast(ubyte*)module_.code + text_offset;
static if (HasVersion!"BUILD_TARGET_THUMB" || HasVersion!"BUILD_TARGET_THUMB_VFP") {
        /* bits[0] of thumb function address must be 1 */
        module_.func_ptrs[i] = cast(void*)(cast(uintptr_t)module_.func_ptrs[i] | 1);
}
static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
        rtl_func_table[i].BeginAddress = cast(DWORD)text_offset;
        if (i > 0) {
            rtl_func_table[i - 1].EndAddress = rtl_func_table[i].BeginAddress;
        }
        rtl_func_table[i].UnwindInfoAddress = cast(DWORD)unwind_info_offset;
}
    }

static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
    if (module_.func_count > 0) {
        uint plt_table_size = module_.is_indirect_mode ? 0 : get_plt_table_size();
        rtl_func_table[module_.func_count - 1].EndAddress =
            (DWORD)(module_.code_size - plt_table_size);

        if (!RtlAddFunctionTable(rtl_func_table, module_.func_count,
                                 cast(DWORD64)cast(uintptr_t)module_.code)) {
            set_error_buf(error_buf, error_buf_size,
                          "add dynamic function table failed");
            return false;
        }
        module_.rtl_func_table_registered = true;
    }
}

    /* Set start function when function pointers are resolved */
    if (module_.start_func_index != (uint32)-1) {
        if (module_.start_func_index >= module_.import_func_count)
            module_.start_function =
                module_.func_ptrs[module_.start_func_index
                                  - module_.import_func_count];
        else
            /* TODO: fix start function can be import function issue */
            module_.start_function = null;
    }
    else {
        module_.start_function = null;
    }

    size = sizeof(uint32) * cast(ulong)module_.func_count;
    if (size > 0
        && ((module_.func_type_indexes =
                 loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    for (i = 0; i < module_.func_count; i++) {
        read_uint32(p, p_end, module_.func_type_indexes[i]);
        if (module_.func_type_indexes[i] >= module_.func_type_count) {
            set_error_buf(error_buf, error_buf_size, "unknown type");
            return false;
        }
    }

    if (p != buf_end) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid function section size");
        return false;
    }

    return true;
fail:
    return false;
}

private void destroy_exports(AOTExport* exports) {
    wasm_runtime_free(exports);
}

private bool load_exports(const(ubyte)** p_buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf = *p_buf;
    AOTExport* exports = void;
    ulong size = void;
    uint i = void;

    /* Allocate memory */
    size = sizeof(AOTExport) * cast(ulong)module_.export_count;
    if (((module_.exports = exports =
              loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        return false;
    }

    /* Create each export */
    for (i = 0; i < module_.export_count; i++) {
        read_uint32(buf, buf_end, exports[i].index);
        read_uint8(buf, buf_end, exports[i].kind);
        read_string(buf, buf_end, exports[i].name);
version (none) { /* TODO: check kind and index */
        if (export_funcs[i].index >=
              module_.func_count + module_.import_func_count) {
            set_error_buf(error_buf, error_buf_size,
                          "function index is out of range");
            return false;
        }
}
    }

    *p_buf = buf;
    return true;
fail:
    return false;
}

private bool load_export_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf_end;

    /* load export functions */
    read_uint32(p, p_end, module_.export_count);
    if (module_.export_count > 0
        && !load_exports(&p, p_end, module_, is_load_from_file_buf, error_buf,
                         error_buf_size))
        return false;

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "invalid export section size");
        return false;
    }

    return true;
fail:
    return false;
}

private void* get_data_section_addr(AOTModule* module_, const(char)* section_name, uint* p_data_size) {
    uint i = void;
    AOTObjectDataSection* data_section = module_.data_sections;

    for (i = 0; i < module_.data_section_count; i++, data_section++) {
        if (!strcmp(data_section.name, section_name)) {
            if (p_data_size)
                *p_data_size = data_section.size;
            return data_section.data;
        }
    }

    return null;
}

private void* resolve_target_sym(const(char)* symbol, int* p_index) {
    uint i = void, num = 0;
    SymbolMap* target_sym_map = void;

    if (((target_sym_map = get_target_symbol_map(&num)) == 0))
        return null;

    for (i = 0; i < num; i++) {
        if (!strcmp(target_sym_map[i].symbol_name, symbol)
static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
            /* In Win32, the symbol name of function added by
               LLVMAddFunction() is prefixed by '_', ignore it */
            || (strlen(symbol) > 1 && symbol[0] == '_'
                && !strcmp(target_sym_map[i].symbol_name, symbol + 1))
#endif
        ) {
            *p_index = cast(int)i;
            return target_sym_map[i].symbol_addr;
        }}
    }
    return null;
}

private bool is_literal_relocation(const(char)* reloc_sec_name) {
    return !strcmp(reloc_sec_name, ".rela.literal");
}

private bool str2uint32(const(char)* buf, uint* p_res) {
    uint res = 0, val = void;
    const(char)* buf_end = buf + 8;
    char ch = void;

    while (buf < buf_end) {
        ch = *buf++;
        if (ch >= '0' && ch <= '9')
            val = ch - '0';
        else if (ch >= 'a' && ch <= 'f')
            val = ch - 'a' + 0xA;
        else if (ch >= 'A' && ch <= 'F')
            val = ch - 'A' + 0xA;
        else
            return false;
        res = (res << 4) | val;
    }
    *p_res = res;
    return true;
}

private bool str2uint64(const(char)* buf, ulong* p_res) {
    ulong res = 0, val = void;
    const(char)* buf_end = buf + 16;
    char ch = void;

    while (buf < buf_end) {
        ch = *buf++;
        if (ch >= '0' && ch <= '9')
            val = ch - '0';
        else if (ch >= 'a' && ch <= 'f')
            val = ch - 'a' + 0xA;
        else if (ch >= 'A' && ch <= 'F')
            val = ch - 'A' + 0xA;
        else
            return false;
        res = (res << 4) | val;
    }
    *p_res = res;
    return true;
}

private bool do_text_relocation(AOTModule* module_, AOTRelocationGroup* group, char* error_buf, uint error_buf_size) {
    bool is_literal = is_literal_relocation(group.section_name);
    ubyte* aot_text = is_literal ? module_.literal : module_.code;
    uint aot_text_size = is_literal ? module_.literal_size : module_.code_size;
    uint i = void, func_index = void, symbol_len = void;
version (BH_PLATFORM_WINDOWS) {
    uint ymm_plt_index = 0, xmm_plt_index = 0;
    uint real_plt_index = 0, float_plt_index = 0, j = void;
}
    char[128] symbol_buf = 0; char* symbol = void, p = void;
    void* symbol_addr = void;
    AOTRelocation* relocation = group.relocations;

    if (group.relocation_count > 0 && !aot_text) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid text relocation count");
        return false;
    }

    for (i = 0; i < group.relocation_count; i++, relocation++) {
        int symbol_index = -1;
        symbol_len = cast(uint)strlen(relocation.symbol_name);
        if (symbol_len + 1 <= symbol_buf.sizeof)
            symbol = symbol_buf;
        else {
            if (((symbol = loader_malloc(symbol_len + 1, error_buf,
                                         error_buf_size)) == 0)) {
                return false;
            }
        }
        bh_memcpy_s(symbol, symbol_len, relocation.symbol_name, symbol_len);
        symbol[symbol_len] = '\0';

        if (!strncmp(symbol, AOT_FUNC_PREFIX, strlen(AOT_FUNC_PREFIX))) {
            p = symbol + strlen(AOT_FUNC_PREFIX);
            if (*p == '\0'
                || (func_index = cast(uint)atoi(p)) > module_.func_count) {
                set_error_buf_v(error_buf, error_buf_size,
                                "invalid import symbol %s", symbol);
                goto check_symbol_fail;
            }
            symbol_addr = module_.func_ptrs[func_index];
        }
        else if (!strcmp(symbol, ".text")) {
            symbol_addr = module_.code;
        }
        else if (!strcmp(symbol, ".data") || !strcmp(symbol, ".sdata")
                 || !strcmp(symbol, ".rdata")
                 || !strcmp(symbol, ".rodata")
                 /* ".rodata.cst4/8/16/.." */
                 || !strncmp(symbol, ".rodata.cst", strlen(".rodata.cst"))
                 /* ".rodata.strn.m" */
                 || !strncmp(symbol, ".rodata.str", strlen(".rodata.str"))) {
            symbol_addr = get_data_section_addr(module_, symbol, null);
            if (!symbol_addr) {
                set_error_buf_v(error_buf, error_buf_size,
                                "invalid data section (%s)", symbol);
                goto check_symbol_fail;
            }
        }
        else if (!strcmp(symbol, ".literal")) {
            symbol_addr = module_.literal;
        }
version (BH_PLATFORM_WINDOWS) {
        /* Relocation for symbols which start with "__ymm@", "__xmm@" or
           "__real@" and end with the ymm value, xmm value or real value.
           In Windows PE file, the data is stored in some individual ".rdata"
           sections. We simply create extra plt data, parse the values from
           the symbols and stored them into the extra plt data. */
        else if (!strcmp(group->section_name, ".text")
                 && !strncmp(symbol, YMM_PLT_PREFIX, strlen(YMM_PLT_PREFIX))
                 && strlen(symbol) == strlen(YMM_PLT_PREFIX) + 64) {
            char[17] ymm_buf = 0;

            symbol_addr = module_.extra_plt_data + ymm_plt_index * 32;
            for (j = 0; j < 4; j++) {
                bh_memcpy_s(ymm_buf.ptr, ymm_buf.sizeof,
                            symbol + strlen(YMM_PLT_PREFIX) + 48 - 16 * j, 16);
                if (!str2uint64(ymm_buf.ptr,
                                cast(ulong*)(cast(ubyte*)symbol_addr + 8 * j))) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "resolve symbol %s failed", symbol);
                    goto check_symbol_fail;
                }
            }
            ymm_plt_index++;
        }
        else if (!strcmp(group->section_name, ".text")
                 && !strncmp(symbol, XMM_PLT_PREFIX, strlen(XMM_PLT_PREFIX))
                 && strlen(symbol) == strlen(XMM_PLT_PREFIX) + 32) {
            char[17] xmm_buf = 0;

            symbol_addr = module_.extra_plt_data + module_.ymm_plt_count * 32
                          + xmm_plt_index * 16;
            for (j = 0; j < 2; j++) {
                bh_memcpy_s(xmm_buf.ptr, xmm_buf.sizeof,
                            symbol + strlen(XMM_PLT_PREFIX) + 16 - 16 * j, 16);
                if (!str2uint64(xmm_buf.ptr,
                                cast(ulong*)(cast(ubyte*)symbol_addr + 8 * j))) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "resolve symbol %s failed", symbol);
                    goto check_symbol_fail;
                }
            }
            xmm_plt_index++;
        }
        else if (!strcmp(group->section_name, ".text")
                 && !strncmp(symbol, REAL_PLT_PREFIX, strlen(REAL_PLT_PREFIX))
                 && strlen(symbol) == strlen(REAL_PLT_PREFIX) + 16) {
            char[17] real_buf = 0;

            symbol_addr = module_.extra_plt_data + module_.ymm_plt_count * 32
                          + module_.xmm_plt_count * 16 + real_plt_index * 8;
            bh_memcpy_s(real_buf.ptr, real_buf.sizeof,
                        symbol + strlen(REAL_PLT_PREFIX), 16);
            if (!str2uint64(real_buf.ptr, cast(ulong*)symbol_addr)) {
                set_error_buf_v(error_buf, error_buf_size,
                                "resolve symbol %s failed", symbol);
                goto check_symbol_fail;
            }
            real_plt_index++;
        }
        else if (!strcmp(group->section_name, ".text")
                 && !strncmp(symbol, REAL_PLT_PREFIX, strlen(REAL_PLT_PREFIX))
                 && strlen(symbol) == strlen(REAL_PLT_PREFIX) + 8) {
            char[9] float_buf = 0;

            symbol_addr = module_.extra_plt_data + module_.ymm_plt_count * 32
                          + module_.xmm_plt_count * 16
                          + module_.real_plt_count * 8 + float_plt_index * 4;
            bh_memcpy_s(float_buf.ptr, float_buf.sizeof,
                        symbol + strlen(REAL_PLT_PREFIX), 8);
            if (!str2uint32(float_buf.ptr, cast(uint*)symbol_addr)) {
                set_error_buf_v(error_buf, error_buf_size,
                                "resolve symbol %s failed", symbol);
                goto check_symbol_fail;
            }
            float_plt_index++;
        }
} /* end of defined(BH_PLATFORM_WINDOWS) */
        else if (((symbol_addr = resolve_target_sym(symbol, &symbol_index)) == 0)) {
            set_error_buf_v(error_buf, error_buf_size,
                            "resolve symbol %s failed", symbol);
            goto check_symbol_fail;
        }

        if (symbol != symbol_buf.ptr)
            wasm_runtime_free(symbol);

        if (!apply_relocation(
                module_, aot_text, aot_text_size, relocation.relocation_offset,
                relocation.relocation_addend, relocation.relocation_type,
                symbol_addr, symbol_index, error_buf, error_buf_size))
            return false;
    }

    return true;

check_symbol_fail:
    if (symbol != symbol_buf.ptr)
        wasm_runtime_free(symbol);
    return false;
}

private bool do_data_relocation(AOTModule* module_, AOTRelocationGroup* group, char* error_buf, uint error_buf_size) {
    ubyte* data_addr = void;
    uint data_size = 0, i = void;
    AOTRelocation* relocation = group.relocations;
    void* symbol_addr = void;
    char* symbol = void, data_section_name = void;

    if (!strncmp(group.section_name, ".rela.", 6)) {
        data_section_name = group.section_name + strlen(".rela");
    }
    else if (!strncmp(group.section_name, ".rel.", 5)) {
        data_section_name = group.section_name + strlen(".rel");
    }
    else if (!strcmp(group.section_name, ".rdata")) {
        data_section_name = group.section_name;
    }
    else {
        set_error_buf(error_buf, error_buf_size,
                      "invalid data relocation section name");
        return false;
    }

    data_addr = get_data_section_addr(module_, data_section_name, &data_size);

    if (group.relocation_count > 0 && !data_addr) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid data relocation count");
        return false;
    }

    for (i = 0; i < group.relocation_count; i++, relocation++) {
        symbol = relocation.symbol_name;
        if (!strcmp(symbol, ".text")) {
            symbol_addr = module_.code;
        }
        else {
            set_error_buf_v(error_buf, error_buf_size,
                            "invalid relocation symbol %s", symbol);
            return false;
        }

        if (!apply_relocation(
                module_, data_addr, data_size, relocation.relocation_offset,
                relocation.relocation_addend, relocation.relocation_type,
                symbol_addr, -1, error_buf, error_buf_size))
            return false;
    }

    return true;
}

private bool validate_symbol_table(ubyte* buf, ubyte* buf_end, uint* offsets, uint count, char* error_buf, uint error_buf_size) {
    uint i = void, str_len_addr = 0;
    ushort str_len = void;

    for (i = 0; i < count; i++) {
        if (offsets[i] != str_len_addr)
            return false;

        read_uint16(buf, buf_end, str_len);
        str_len_addr += cast(uint)sizeof(uint16) + str_len;
        str_len_addr = align_uint(str_len_addr, 2);
        buf += str_len;
        buf = cast(ubyte*)align_ptr(buf, 2);
    }

    if (buf == buf_end)
        return true;
fail:
    return false;
}

private bool load_relocation_section(const(ubyte)* buf, const(ubyte)* buf_end, AOTModule* module_, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    AOTRelocationGroup* groups = null, group = void;
    uint symbol_count = 0;
    uint group_count = 0, i = void, j = void;
    ulong size = void;
    uint* symbol_offsets = void; uint total_string_len = void;
    ubyte* symbol_buf = void, symbol_buf_end = void;
    int map_prot = void, map_flags = void;
    bool ret = false;
    char** symbols = null;

    read_uint32(buf, buf_end, symbol_count);

    symbol_offsets = cast(uint*)buf;
    for (i = 0; i < symbol_count; i++) {
        CHECK_BUF(buf, buf_end, uint32.sizeof);
        buf += uint32.sizeof;
    }

    read_uint32(buf, buf_end, total_string_len);
    symbol_buf = cast(ubyte*)buf;
    symbol_buf_end = symbol_buf + total_string_len;

    if (!validate_symbol_table(symbol_buf, symbol_buf_end, symbol_offsets,
                               symbol_count, error_buf, error_buf_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "validate symbol table failed");
        goto fail;
    }

    if (symbol_count > 0) {
        symbols = loader_malloc(cast(ulong)sizeof(*symbols) * symbol_count,
                                error_buf, error_buf_size);
        if (symbols == null) {
            goto fail;
        }
    }

version (BH_PLATFORM_WINDOWS) {
    buf = symbol_buf_end;
    read_uint32(buf, buf_end, group_count);

    for (i = 0; i < group_count; i++) {
        uint name_index = void, relocation_count = void;
        ushort group_name_len = void;
        ubyte* group_name = void;

        /* section name address is 4 bytes aligned. */
        buf = cast(ubyte*)align_ptr(buf, uint32.sizeof);
        read_uint32(buf, buf_end, name_index);

        if (name_index >= symbol_count) {
            set_error_buf(error_buf, error_buf_size,
                          "symbol index out of range");
            goto fail;
        }

        group_name = symbol_buf + symbol_offsets[name_index];
        group_name_len = *cast(ushort*)group_name;
        group_name += uint16.sizeof;

        read_uint32(buf, buf_end, relocation_count);

        for (j = 0; j < relocation_count; j++) {
            AOTRelocation relocation = { 0 };
            uint symbol_index = void, offset32 = void;
            int addend32 = void;
            ushort symbol_name_len = void;
            ubyte* symbol_name = void;

            if ((void*).sizeof == 8) {
                read_uint64(buf, buf_end, relocation.relocation_offset);
                read_uint64(buf, buf_end, relocation.relocation_addend);
            }
            else {
                read_uint32(buf, buf_end, offset32);
                relocation.relocation_offset = cast(ulong)offset32;
                read_uint32(buf, buf_end, addend32);
                relocation.relocation_addend = cast(long)addend32;
            }
            read_uint32(buf, buf_end, relocation.relocation_type);
            read_uint32(buf, buf_end, symbol_index);

            if (symbol_index >= symbol_count) {
                set_error_buf(error_buf, error_buf_size,
                              "symbol index out of range");
                goto fail;
            }

            symbol_name = symbol_buf + symbol_offsets[symbol_index];
            symbol_name_len = *cast(ushort*)symbol_name;
            symbol_name += uint16.sizeof;

            char[128] group_name_buf = 0;
            char[128] symbol_name_buf = 0;
            memcpy(group_name_buf.ptr, group_name, group_name_len);
            memcpy(symbol_name_buf.ptr, symbol_name, symbol_name_len);

            if ((group_name_len == strlen(".text")
                 || (module_.is_indirect_mode
                     && group_name_len == strlen(".text") + 1))
                && !strncmp(group_name, ".text", strlen(".text"))) {
                if ((symbol_name_len == strlen(YMM_PLT_PREFIX) + 64
                     || (module_.is_indirect_mode
                         && symbol_name_len == strlen(YMM_PLT_PREFIX) + 64 + 1))
                    && !strncmp(symbol_name, YMM_PLT_PREFIX,
                                strlen(YMM_PLT_PREFIX))) {
                    module_.ymm_plt_count++;
                }
                else if ((symbol_name_len == strlen(XMM_PLT_PREFIX) + 32
                          || (module_.is_indirect_mode
                              && symbol_name_len
                                     == strlen(XMM_PLT_PREFIX) + 32 + 1))
                         && !strncmp(symbol_name, XMM_PLT_PREFIX,
                                     strlen(XMM_PLT_PREFIX))) {
                    module_.xmm_plt_count++;
                }
                else if ((symbol_name_len == strlen(REAL_PLT_PREFIX) + 16
                          || (module_.is_indirect_mode
                              && symbol_name_len
                                     == strlen(REAL_PLT_PREFIX) + 16 + 1))
                         && !strncmp(symbol_name, REAL_PLT_PREFIX,
                                     strlen(REAL_PLT_PREFIX))) {
                    module_.real_plt_count++;
                }
                else if ((symbol_name_len >= strlen(REAL_PLT_PREFIX) + 8
                          || (module_.is_indirect_mode
                              && symbol_name_len
                                     == strlen(REAL_PLT_PREFIX) + 8 + 1))
                         && !strncmp(symbol_name, REAL_PLT_PREFIX,
                                     strlen(REAL_PLT_PREFIX))) {
                    module_.float_plt_count++;
                }
            }
        }
    }

    /* Allocate memory for extra plt data */
    size = sizeof(uint64) * 4 * module_.ymm_plt_count
           + sizeof(uint64) * 2 * module_.xmm_plt_count
           + sizeof(uint64) * module_.real_plt_count
           + sizeof(uint32) * module_.float_plt_count;
    if (size > 0) {
        map_prot = MMAP_PROT_READ | MMAP_PROT_WRITE | MMAP_PROT_EXEC;
        /* aot code and data in x86_64 must be in range 0 to 2G due to
           relocation for R_X86_64_32/32S/PC32 */
        map_flags = MMAP_MAP_32BIT;

        if (size > UINT32_MAX
            || ((module_.extra_plt_data =
                     os_mmap(null, cast(uint)size, map_prot, map_flags)) == 0)) {
            set_error_buf(error_buf, error_buf_size, "mmap memory failed");
            goto fail;
        }
        module_.extra_plt_data_size = cast(uint)size;
    }
} /* end of defined(BH_PLATFORM_WINDOWS) */

    buf = symbol_buf_end;
    read_uint32(buf, buf_end, group_count);

    /* Allocate memory for relocation groups */
    size = sizeof(AOTRelocationGroup) * cast(ulong)group_count;
    if (size > 0
        && ((groups = loader_malloc(size, error_buf, error_buf_size)) == 0)) {
        goto fail;
    }

    /* Load each relocation group */
    for (i = 0, group = groups; i < group_count; i++, group++) {
        AOTRelocation* relocation = void;
        uint name_index = void;

        /* section name address is 4 bytes aligned. */
        buf = cast(ubyte*)align_ptr(buf, uint32.sizeof);
        read_uint32(buf, buf_end, name_index);

        if (name_index >= symbol_count) {
            set_error_buf(error_buf, error_buf_size,
                          "symbol index out of range");
            goto fail;
        }

        if (symbols[name_index] == null) {
            ubyte* name_addr = symbol_buf + symbol_offsets[name_index];

            read_string(name_addr, buf_end, symbols[name_index]);
        }
        group.section_name = symbols[name_index];

        read_uint32(buf, buf_end, group.relocation_count);

        /* Allocate memory for relocations */
        size = sizeof(AOTRelocation) * cast(ulong)group.relocation_count;
        if (((group.relocations = relocation =
                  loader_malloc(size, error_buf, error_buf_size)) == 0)) {
            ret = false;
            goto fail;
        }

        /* Load each relocation */
        for (j = 0; j < group.relocation_count; j++, relocation++) {
            uint symbol_index = void;

            if ((void*).sizeof == 8) {
                read_uint64(buf, buf_end, relocation.relocation_offset);
                read_uint64(buf, buf_end, relocation.relocation_addend);
            }
            else {
                uint offset32 = void, addend32 = void;
                read_uint32(buf, buf_end, offset32);
                relocation.relocation_offset = cast(ulong)offset32;
                read_uint32(buf, buf_end, addend32);
                relocation.relocation_addend = cast(ulong)addend32;
            }
            read_uint32(buf, buf_end, relocation.relocation_type);
            read_uint32(buf, buf_end, symbol_index);

            if (symbol_index >= symbol_count) {
                set_error_buf(error_buf, error_buf_size,
                              "symbol index out of range");
                goto fail;
            }

            if (symbols[symbol_index] == null) {
                ubyte* symbol_addr = symbol_buf + symbol_offsets[symbol_index];

                read_string(symbol_addr, buf_end, symbols[symbol_index]);
            }
            relocation.symbol_name = symbols[symbol_index];
        }

        if (!strcmp(group.section_name, ".rel.text")
            || !strcmp(group.section_name, ".rela.text")
            || !strcmp(group.section_name, ".rela.literal")
#ifdef BH_PLATFORM_WINDOWS
            || !strcmp(group.section_name, ".text")
}
        ) {
static if (!HasVersion!"BH_PLATFORM_LINUX" && !HasVersion!"BH_PLATFORM_LINUX_SGX" \
    && !HasVersion!"BH_PLATFORM_DARWIN" && !HasVersion!"BH_PLATFORM_WINDOWS") {
            if (module_.is_indirect_mode) {
                set_error_buf(error_buf, error_buf_size,
                              "cannot apply relocation to text section "
                              ~ "for aot file generated with "
                              ~ "\"--enable-indirect-mode\" flag");
                goto fail;
            }
}
            if (!do_text_relocation(module_, group, error_buf, error_buf_size))
                goto fail;
        }
        else {
            if (!do_data_relocation(module_, group, error_buf, error_buf_size))
                goto fail;
        }
    }

    /* Set read only for AOT code and some data sections */
    map_prot = MMAP_PROT_READ | MMAP_PROT_EXEC;

    if (module_.code) {
        /* The layout is: literal size + literal + code (with plt table) */
        ubyte* mmap_addr = module_.literal - uint32.sizeof;
        uint total_size = sizeof(uint32) + module_.literal_size + module_.code_size;
        os_mprotect(mmap_addr, total_size, map_prot);
    }

    map_prot = MMAP_PROT_READ;

version (BH_PLATFORM_WINDOWS) {
    if (module_.extra_plt_data) {
        os_mprotect(module_.extra_plt_data, module_.extra_plt_data_size,
                    map_prot);
    }
}

    for (i = 0; i < module_.data_section_count; i++) {
        AOTObjectDataSection* data_section = module_.data_sections + i;
        if (!strcmp(data_section.name, ".rdata")
            || !strcmp(data_section.name, ".rodata")
            /* ".rodata.cst4/8/16/.." */
            || !strncmp(data_section.name, ".rodata.cst",
                        strlen(".rodata.cst"))
            /* ".rodata.strn.m" */
            || !strncmp(data_section.name, ".rodata.str",
                        strlen(".rodata.str"))) {
            os_mprotect(data_section.data, data_section.size, map_prot);
        }
    }

    ret = true;

fail:
    if (symbols) {
        wasm_runtime_free(symbols);
    }
    if (groups) {
        for (i = 0, group = groups; i < group_count; i++, group++)
            if (group.relocations)
                wasm_runtime_free(group.relocations);
        wasm_runtime_free(groups);
    }

    cast(void)map_flags;
    return ret;
}

private bool load_from_sections(AOTModule* module_, AOTSection* sections, bool is_load_from_file_buf, char* error_buf, uint error_buf_size) {
    AOTSection* section = sections;
    const(ubyte)* buf = void, buf_end = void;
    uint last_section_type = (uint32)-1, section_type = void;
    uint i = void, func_index = void, func_type_index = void;
    AOTFuncType* func_type = void;
    AOTExport* exports = void;

    while (section) {
        buf = section.section_body;
        buf_end = buf + section.section_body_size;
        /* Check sections */
        section_type = cast(uint)section.section_type;
        if ((last_section_type == (uint32)-1
             && section_type != AOT_SECTION_TYPE_TARGET_INFO)
            || (last_section_type != (uint32)-1
                && (section_type != last_section_type + 1
                    && section_type != AOT_SECTION_TYPE_CUSTOM))) {
            set_error_buf(error_buf, error_buf_size, "invalid section order");
            return false;
        }
        last_section_type = section_type;
        switch (section_type) {
            case AOT_SECTION_TYPE_TARGET_INFO:
                if (!load_target_info_section(buf, buf_end, module_, error_buf,
                                              error_buf_size))
                    return false;
                break;
            case AOT_SECTION_TYPE_INIT_DATA:
                if (!load_init_data_section(buf, buf_end, module_,
                                            is_load_from_file_buf, error_buf,
                                            error_buf_size))
                    return false;
                break;
            case AOT_SECTION_TYPE_TEXT:
                if (!load_text_section(buf, buf_end, module_, error_buf,
                                       error_buf_size))
                    return false;
                break;
            case AOT_SECTION_TYPE_FUNCTION:
                if (!load_function_section(buf, buf_end, module_, error_buf,
                                           error_buf_size))
                    return false;
                break;
            case AOT_SECTION_TYPE_EXPORT:
                if (!load_export_section(buf, buf_end, module_,
                                         is_load_from_file_buf, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case AOT_SECTION_TYPE_RELOCATION:
                if (!load_relocation_section(buf, buf_end, module_,
                                             is_load_from_file_buf, error_buf,
                                             error_buf_size))
                    return false;
                break;
            case AOT_SECTION_TYPE_CUSTOM:
                if (!load_custom_section(buf, buf_end, module_,
                                         is_load_from_file_buf, error_buf,
                                         error_buf_size))
                    return false;
                break;
            default:
                set_error_buf(error_buf, error_buf_size,
                              "invalid aot section type");
                return false;
        }

        section = section.next;
    }

    if (last_section_type != AOT_SECTION_TYPE_RELOCATION
        && last_section_type != AOT_SECTION_TYPE_CUSTOM) {
        set_error_buf(error_buf, error_buf_size, "section missing");
        return false;
    }

    /* Resolve malloc and free function */
    module_.malloc_func_index = (uint32)-1;
    module_.free_func_index = (uint32)-1;
    module_.retain_func_index = (uint32)-1;

    exports = module_.exports;
    for (i = 0; i < module_.export_count; i++) {
        if (exports[i].kind == EXPORT_KIND_FUNC
            && exports[i].index >= module_.import_func_count) {
            if (!strcmp(exports[i].name, "malloc")) {
                func_index = exports[i].index - module_.import_func_count;
                func_type_index = module_.func_type_indexes[func_index];
                func_type = module_.func_types[func_type_index];
                if (func_type.param_count == 1 && func_type.result_count == 1
                    && func_type.types[0] == VALUE_TYPE_I32
                    && func_type.types[1] == VALUE_TYPE_I32) {
                    bh_assert(module_.malloc_func_index == (uint32)-1);
                    module_.malloc_func_index = func_index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                exports[i].name, exports[i].index);
                }
            }
            else if (!strcmp(exports[i].name, "__new")) {
                func_index = exports[i].index - module_.import_func_count;
                func_type_index = module_.func_type_indexes[func_index];
                func_type = module_.func_types[func_type_index];
                if (func_type.param_count == 2 && func_type.result_count == 1
                    && func_type.types[0] == VALUE_TYPE_I32
                    && func_type.types[1] == VALUE_TYPE_I32
                    && func_type.types[2] == VALUE_TYPE_I32) {
                    uint j = void;
                    WASMExport* export_tmp = void;

                    bh_assert(module_.malloc_func_index == (uint32)-1);
                    module_.malloc_func_index = func_index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                exports[i].name, exports[i].index);

                    /* resolve retain function.
                        If not find, reset malloc function index */
                    export_tmp = module_.exports;
                    for (j = 0; j < module_.export_count; j++, export_tmp++) {
                        if ((export_tmp.kind == EXPORT_KIND_FUNC)
                            && (!strcmp(export_tmp.name, "__retain")
                                || !strcmp(export_tmp.name, "__pin"))) {
                            func_index =
                                export_tmp.index - module_.import_func_count;
                            func_type_index =
                                module_.func_type_indexes[func_index];
                            func_type = module_.func_types[func_type_index];
                            if (func_type.param_count == 1
                                && func_type.result_count == 1
                                && func_type.types[0] == VALUE_TYPE_I32
                                && func_type.types[1] == VALUE_TYPE_I32) {
                                bh_assert(module_.retain_func_index
                                          == (uint32)-1);
                                module_.retain_func_index = export_tmp.index;
                                LOG_VERBOSE("Found retain function, name: %s, "
                                            ~ "index: %u",
                                            export_tmp.name,
                                            export_tmp.index);
                                break;
                            }
                        }
                    }
                    if (j == module_.export_count) {
                        module_.malloc_func_index = (uint32)-1;
                        LOG_VERBOSE("Can't find retain function,"
                                    ~ "reset malloc function index to -1");
                    }
                }
            }
            else if ((!strcmp(exports[i].name, "free"))
                     || (!strcmp(exports[i].name, "__release"))
                     || (!strcmp(exports[i].name, "__unpin"))) {
                func_index = exports[i].index - module_.import_func_count;
                func_type_index = module_.func_type_indexes[func_index];
                func_type = module_.func_types[func_type_index];
                if (func_type.param_count == 1 && func_type.result_count == 0
                    && func_type.types[0] == VALUE_TYPE_I32) {
                    bh_assert(module_.free_func_index == (uint32)-1);
                    module_.free_func_index = func_index;
                    LOG_VERBOSE("Found free function, name: %s, index: %u",
                                exports[i].name, exports[i].index);
                }
            }
        }
    }

    /* Flush data cache before executing AOT code,
     * otherwise unpredictable behavior can occur. */
    os_dcache_flush();

static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    wasm_runtime_dump_module_mem_consumption(cast(WASMModuleCommon*)module_);
}

static if (WASM_ENABLE_DEBUG_AOT != 0) {
    if (!jit_code_entry_create(module_.elf_hdr, module_.elf_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "create jit code entry failed");
        return false;
    }
}
    return true;
}

private AOTModule* create_module(char* error_buf, uint error_buf_size) {
    AOTModule* module_ = loader_malloc(AOTModule.sizeof, error_buf, error_buf_size);

    if (!module_) {
        return null;
    }

    module_.module_type = Wasm_Module_AoT;

    return module_;
}

AOTModule* aot_load_from_sections(AOTSection* section_list, char* error_buf, uint error_buf_size) {
    AOTModule* module_ = create_module(error_buf, error_buf_size);

    if (!module_)
        return null;

    if (!load_from_sections(module_, section_list, false, error_buf,
                            error_buf_size)) {
        aot_unload(module_);
        return null;
    }

    LOG_VERBOSE("Load module from sections success.\n");
    return module_;
}

private void destroy_sections(AOTSection* section_list, bool destroy_aot_text) {
    AOTSection* section = section_list, next = void;
    while (section) {
        next = section.next;
        if (destroy_aot_text && section.section_type == AOT_SECTION_TYPE_TEXT
            && section.section_body)
            os_munmap(cast(ubyte*)section.section_body,
                      section.section_body_size);
        wasm_runtime_free(section);
        section = next;
    }
}

private bool resolve_execute_mode(const(ubyte)* buf, uint size, bool* p_mode, char* error_buf, uint error_buf_size) {
    const(ubyte)* p = buf, p_end = buf + size;
    uint section_type = void;
    uint section_size = 0;
    ushort e_type = 0;

    p += 8;
    while (p < p_end) {
        read_uint32(p, p_end, section_type);
        if (section_type <= AOT_SECTION_TYPE_SIGANATURE
            || section_type == AOT_SECTION_TYPE_TARGET_INFO) {
            read_uint32(p, p_end, section_size);
            CHECK_BUF(p, p_end, section_size);
            if (section_type == AOT_SECTION_TYPE_TARGET_INFO) {
                p += 4;
                read_uint16(p, p_end, e_type);
                if (e_type == E_TYPE_XIP) {
                    *p_mode = true;
                }
                else {
                    *p_mode = false;
                }
                break;
            }
        }
        else if (section_type > AOT_SECTION_TYPE_SIGANATURE) {
            set_error_buf(error_buf, error_buf_size,
                          "resolve execute mode failed");
            break;
        }
        p += section_size;
    }
    return true;
fail:
    return false;
}

private bool create_sections(AOTModule* module_, const(ubyte)* buf, uint size, AOTSection** p_section_list, char* error_buf, uint error_buf_size) {
    AOTSection* section_list = null, section_list_end = null, section = void;
    const(ubyte)* p = buf, p_end = buf + size;
    bool destroy_aot_text = false;
    bool is_indirect_mode = false;
    uint section_type = void;
    uint section_size = void;
    ulong total_size = void;
    ubyte* aot_text = void;

    if (!resolve_execute_mode(buf, size, &is_indirect_mode, error_buf,
                              error_buf_size)) {
        goto fail;
    }

    module_.is_indirect_mode = is_indirect_mode;

    p += 8;
    while (p < p_end) {
        read_uint32(p, p_end, section_type);
        if (section_type < AOT_SECTION_TYPE_SIGANATURE
            || section_type == AOT_SECTION_TYPE_CUSTOM) {
            read_uint32(p, p_end, section_size);
            CHECK_BUF(p, p_end, section_size);

            if (((section = loader_malloc(AOTSection.sizeof, error_buf,
                                          error_buf_size)) == 0)) {
                goto fail;
            }

            memset(section, 0, AOTSection.sizeof);
            section.section_type = cast(int)section_type;
            section.section_body = cast(ubyte*)p;
            section.section_body_size = section_size;

            if (section_type == AOT_SECTION_TYPE_TEXT) {
                if ((section_size > 0) && !module_.is_indirect_mode) {
                    int map_prot = MMAP_PROT_READ | MMAP_PROT_WRITE | MMAP_PROT_EXEC;
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64" \
    || HasVersion!"BUILD_TARGET_RISCV64_LP64D"                       \
    || HasVersion!"BUILD_TARGET_RISCV64_LP64") {
                    /* aot code and data in x86_64 must be in range 0 to 2G due
                       to relocation for R_X86_64_32/32S/PC32 */
                    int map_flags = MMAP_MAP_32BIT;
} else {
                    int map_flags = MMAP_MAP_NONE;
}
                    total_size =
                        cast(ulong)section_size + aot_get_plt_table_size();
                    total_size = (total_size + 3) & ~(cast(ulong)3);
                    if (total_size >= UINT32_MAX
                        || ((aot_text = os_mmap(null, cast(uint)total_size,
                                                map_prot, map_flags)) == 0)) {
                        wasm_runtime_free(section);
                        set_error_buf(error_buf, error_buf_size,
                                      "mmap memory failed");
                        goto fail;
                    }
static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
static if (!HasVersion!"BH_PLATFORM_LINUX_SGX" && !HasVersion!"BH_PLATFORM_WINDOWS" \
    && !HasVersion!"BH_PLATFORM_DARWIN") {
                    /* address must be in the first 2 Gigabytes of
                       the process address space */
                    bh_assert(cast(uintptr_t)aot_text < INT32_MAX);
}
}
                    bh_memcpy_s(aot_text, cast(uint)total_size,
                                section.section_body, cast(uint)section_size);
                    section.section_body = aot_text;
                    destroy_aot_text = true;

                    if (cast(uint)total_size > section.section_body_size) {
                        memset(aot_text + cast(uint)section_size, 0,
                               cast(uint)total_size - section_size);
                        section.section_body_size = cast(uint)total_size;
                    }
                }
            }

            if (!section_list)
                section_list = section_list_end = section;
            else {
                section_list_end.next = section;
                section_list_end = section;
            }

            p += section_size;
        }
        else {
            set_error_buf(error_buf, error_buf_size, "invalid section id");
            goto fail;
        }
    }

    if (!section_list) {
        set_error_buf(error_buf, error_buf_size, "create section list failed");
        return false;
    }

    *p_section_list = section_list;
    return true;
fail:
    if (section_list)
        destroy_sections(section_list, destroy_aot_text);
    return false;
}

private bool load(const(ubyte)* buf, uint size, AOTModule* module_, char* error_buf, uint error_buf_size) {
    const(ubyte)* buf_end = buf + size;
    const(ubyte)* p = buf, p_end = buf_end;
    uint magic_number = void, version_ = void;
    AOTSection* section_list = null;
    bool ret = void;

    read_uint32(p, p_end, magic_number);
    if (magic_number != AOT_MAGIC_NUMBER) {
        set_error_buf(error_buf, error_buf_size, "magic header not detected");
        return false;
    }

    read_uint32(p, p_end, version_);
    if (version_ != AOT_CURRENT_VERSION) {
        set_error_buf(error_buf, error_buf_size, "unknown binary version");
        return false;
    }

    if (!create_sections(module_, buf, size, &section_list, error_buf,
                         error_buf_size))
        return false;

    ret = load_from_sections(module_, section_list, true, error_buf,
                             error_buf_size);
    if (!ret) {
        /* If load_from_sections() fails, then aot text is destroyed
           in destroy_sections() */
        destroy_sections(section_list, module_.is_indirect_mode ? false : true);
        /* aot_unload() won't destroy aot text again */
        module_.code = null;
    }
    else {
        /* If load_from_sections() succeeds, then aot text is set to
           module->code and will be destroyed in aot_unload() */
        destroy_sections(section_list, false);
    }
    return ret;
fail:
    return false;
}

AOTModule* aot_load_from_aot_file(const(ubyte)* buf, uint size, char* error_buf, uint error_buf_size) {
    AOTModule* module_ = create_module(error_buf, error_buf_size);

    if (!module_)
        return null;

    if (!load(buf, size, module_, error_buf, error_buf_size)) {
        aot_unload(module_);
        return null;
    }

    LOG_VERBOSE("Load module success.\n");
    return module_;
}

void aot_unload(AOTModule* module_) {
    if (module_.import_memories)
        destroy_import_memories(module_.import_memories);

    if (module_.memories)
        wasm_runtime_free(module_.memories);

    if (module_.mem_init_data_list)
        destroy_mem_init_data_list(module_.mem_init_data_list,
                                   module_.mem_init_data_count);

    if (module_.native_symbol_list)
        wasm_runtime_free(module_.native_symbol_list);

    if (module_.import_tables)
        destroy_import_tables(module_.import_tables);

    if (module_.tables)
        destroy_tables(module_.tables);

    if (module_.table_init_data_list)
        destroy_table_init_data_list(module_.table_init_data_list,
                                     module_.table_init_data_count);

    if (module_.func_types)
        destroy_func_types(module_.func_types, module_.func_type_count);

    if (module_.import_globals)
        destroy_import_globals(module_.import_globals);

    if (module_.globals)
        destroy_globals(module_.globals);

    if (module_.import_funcs)
        destroy_import_funcs(module_.import_funcs);

    if (module_.exports)
        destroy_exports(module_.exports);

    if (module_.func_type_indexes)
        wasm_runtime_free(module_.func_type_indexes);

    if (module_.func_ptrs)
        wasm_runtime_free(module_.func_ptrs);

    if (module_.const_str_set)
        bh_hash_map_destroy(module_.const_str_set);

    if (module_.code && !module_.is_indirect_mode) {
        /* The layout is: literal size + literal + code (with plt table) */
        ubyte* mmap_addr = module_.literal - uint32.sizeof;
        uint total_size = sizeof(uint32) + module_.literal_size + module_.code_size;
        os_munmap(mmap_addr, total_size);
    }

version (BH_PLATFORM_WINDOWS) {
    if (module_.extra_plt_data) {
        os_munmap(module_.extra_plt_data, module_.extra_plt_data_size);
    }
}

static if (HasVersion!"OS_ENABLE_HW_BOUND_CHECK" && HasVersion!"BH_PLATFORM_WINDOWS") {
    if (module_.rtl_func_table) {
        if (module_.rtl_func_table_registered)
            RtlDeleteFunctionTable(module_.rtl_func_table);
        wasm_runtime_free(module_.rtl_func_table);
    }
}

    if (module_.data_sections)
        destroy_object_data_sections(module_.data_sections,
                                     module_.data_section_count);
static if (WASM_ENABLE_DEBUG_AOT != 0) {
    jit_code_entry_destroy(module_.elf_hdr);
}

static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    if (module_.aux_func_indexes) {
        wasm_runtime_free(module_.aux_func_indexes);
    }
    if (module_.aux_func_names) {
        wasm_runtime_free(cast(void*)module_.aux_func_names);
    }
}

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
    wasm_runtime_destroy_custom_sections(module_.custom_section_list);
}

    wasm_runtime_free(module_);
}

uint aot_get_plt_table_size() {
    return get_plt_table_size();
}

static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
const(ubyte)* aot_get_custom_section(const(AOTModule)* module_, const(char)* name, uint* len) {
    WASMCustomSection* section = module_.custom_section_list;

    while (section) {
        if (strcmp(section.name_addr, name) == 0) {
            if (len) {
                *len = section.content_len;
            }
            return section.content_addr;
        }

        section = section.next;
    }

    return null;
}
} /* end of WASM_ENABLE_LOAD_CUSTOM_SECTION */
