module aot_emit_aot_file;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import aot_compiler;
public import ...aot.aot_runtime;

enum string PUT_U64_TO_ADDR(string addr, string value) = `        \
    do {                                    \
        union {                             \
            uint64 val;                     \
            uint32 parts[2];                \
        } u;                                \
        u.val = (value);                    \
        ((uint32 *)(addr))[0] = u.parts[0]; \
        ((uint32 *)(addr))[1] = u.parts[1]; \
    } while (0)`;

enum string CHECK_SIZE(string size) = `                                   \
    do {                                                   \
        if (size == (uint32)-1) {                          \
            aot_set_last_error("get symbol size failed."); \
            return (uint32)-1;                             \
        }                                                  \
    } while (0)`;

private bool check_utf8_str(const(ubyte)* str, uint len) {
    /* The valid ranges are taken from page 125, below link
       https://www.unicode.org/versions/Unicode9.0.0/ch03.pdf */
    const(ubyte)* p = str, p_end = str + len;
    ubyte chr = void;

    while (p < p_end) {
        chr = *p;
        if (chr < 0x80) {
            p++;
        }
        else if (chr >= 0xC2 && chr <= 0xDF && p + 1 < p_end) {
            if (p[1] < 0x80 || p[1] > 0xBF) {
                return false;
            }
            p += 2;
        }
        else if (chr >= 0xE0 && chr <= 0xEF && p + 2 < p_end) {
            if (chr == 0xE0) {
                if (p[1] < 0xA0 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            else if (chr == 0xED) {
                if (p[1] < 0x80 || p[1] > 0x9F || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            else if (chr >= 0xE1 && chr <= 0xEF) {
                if (p[1] < 0x80 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            p += 3;
        }
        else if (chr >= 0xF0 && chr <= 0xF4 && p + 3 < p_end) {
            if (chr == 0xF0) {
                if (p[1] < 0x90 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            else if (chr >= 0xF1 && chr <= 0xF3) {
                if (p[1] < 0x80 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            else if (chr == 0xF4) {
                if (p[1] < 0x80 || p[1] > 0x8F || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            p += 4;
        }
        else {
            return false;
        }
    }
    return (p == p_end);
}

/* Internal function in object file */
struct AOTObjectFunc {
    char* func_name;
    ulong text_offset;
}

/* Symbol table list node */
struct AOTSymbolNode {
    AOTSymbolNode* next;
    uint str_len;
    char* symbol;
}

struct AOTSymbolList {
    AOTSymbolNode* head;
    AOTSymbolNode* end;
    uint len;
}

/* AOT object data */
struct AOTObjectData {
    LLVMMemoryBufferRef mem_buf;
    LLVMBinaryRef binary;

    AOTTargetInfo target_info;

    void* text;
    uint text_size;

    /* literal data and size */
    void* literal;
    uint literal_size;

    AOTObjectDataSection* data_sections;
    uint data_sections_count;

    AOTObjectFunc* funcs;
    uint func_count;

    AOTSymbolList symbol_list;
    AOTRelocationGroup* relocation_groups;
    uint relocation_group_count;
}

version (none) {
private void dump_buf(ubyte* buf, uint size, char* title) {
    int i = void;
    printf("------ %s -------", title);
    for (i = 0; i < size; i++) {
        if ((i % 16) == 0)
            printf("\n");
        printf("%02x ", cast(ubyte)buf[i]);
    }
    printf("\n\n");
}
}

private bool is_32bit_binary(const(AOTObjectData)* obj_data) {
    /* bit 1: 0 is 32-bit, 1 is 64-bit */
    return obj_data.target_info.bin_type & 2 ? false : true;
}

private bool is_little_endian_binary(const(AOTObjectData)* obj_data) {
    /* bit 0: 0 is little-endian, 1 is big-endian */
    return obj_data.target_info.bin_type & 1 ? false : true;
}

private bool str_starts_with(const(char)* str, const(char)* prefix) {
    size_t len_pre = strlen(prefix), len_str = strlen(str);
    return (len_str >= len_pre) && !memcmp(str, prefix, len_pre);
}

private uint get_file_header_size() {
    /* magic number (4 bytes) + version (4 bytes) */
    return sizeof(uint32) + uint32.sizeof;
}

private uint get_string_size(AOTCompContext* comp_ctx, const(char)* s) {
    /* string size (2 bytes) + string content */
    return cast(uint)sizeof(uint16) + cast(uint)strlen(s) +
           /* emit string with '\0' only in XIP mode */
           (comp_ctx.is_indirect_mode ? 1 : 0);
}

private uint get_target_info_section_size() {
    return AOTTargetInfo.sizeof;
}

private uint get_mem_init_data_size(AOTMemInitData* mem_init_data) {
    /* init expr type (4 bytes) + init expr value (8 bytes)
       + byte count (4 bytes) + bytes */
    uint total_size = (uint32)(sizeof(uint32) + sizeof(uint64)
                                 + sizeof(uint32) + mem_init_data.byte_count);

    /* bulk_memory enabled:
        is_passive (4 bytes) + memory_index (4 bytes)
       bulk memory disabled:
        placeholder (4 bytes) + placeholder (4 bytes)
    */
    total_size += (sizeof(uint32) + uint32.sizeof);

    return total_size;
}

private uint get_mem_init_data_list_size(AOTMemInitData** mem_init_data_list, uint mem_init_data_count) {
    AOTMemInitData** mem_init_data = mem_init_data_list;
    uint size = 0, i = void;

    for (i = 0; i < mem_init_data_count; i++, mem_init_data++) {
        size = align_uint(size, 4);
        size += get_mem_init_data_size(*mem_init_data);
    }
    return size;
}

private uint get_import_memory_size(AOTCompData* comp_data) {
    /* currently we only emit import_memory_count = 0 */
    return uint32.sizeof;
}

private uint get_memory_size(AOTCompData* comp_data) {
    /* memory_count + count * (memory_flags + num_bytes_per_page +
                               init_page_count + max_page_count) */
    return (uint32)(sizeofcast(uint)
                    + comp_data.memory_count * sizeof(uint32) * 4);
}

private uint get_mem_info_size(AOTCompData* comp_data) {
    /* import_memory_size + memory_size
       + init_data_count + init_data_list */
    return get_import_memory_size(comp_data) + get_memory_size(comp_data)
           + cast(uint)sizeof(uint32)
           + get_mem_init_data_list_size(comp_data.mem_init_data_list,
                                         comp_data.mem_init_data_count);
}

private uint get_table_init_data_size(AOTTableInitData* table_init_data) {
    /*
     * mode (4 bytes), elem_type (4 bytes), do not need is_dropped field
     *
     * table_index(4 bytes) + init expr type (4 bytes) + init expr value (8
     * bytes)
     * + func index count (4 bytes) + func indexes
     */
    return (uint32)(sizeof(uint32) * 2 + sizeof(uint32) + sizeof(uint32)
                    + sizeof(uint64) + sizeof(uint32)
                    + sizeof(uint32) * table_init_data.func_index_count);
}

private uint get_table_init_data_list_size(AOTTableInitData** table_init_data_list, uint table_init_data_count) {
    /*
     * ------------------------------
     * | table_init_data_count
     * ------------------------------
     * |                     | U32 mode
     * | AOTTableInitData[N] | U32 elem_type
     * |                     | U32 table_index
     * |                     | U32 offset.init_expr_type
     * |                     | U64 offset.u.i64
     * |                     | U32 func_index_count
     * |                     | U32[func_index_count]
     * ------------------------------
     */
    AOTTableInitData** table_init_data = table_init_data_list;
    uint size = 0, i = void;

    size = cast(uint)uint32.sizeof;

    for (i = 0; i < table_init_data_count; i++, table_init_data++) {
        size = align_uint(size, 4);
        size += get_table_init_data_size(*table_init_data);
    }
    return size;
}

private uint get_import_table_size(AOTCompData* comp_data) {
    /*
     * ------------------------------
     * | import_table_count
     * ------------------------------
     * |                  | U32 table_init_size
     * |                  | ----------------------
     * | AOTImpotTable[N] | U32 table_init_size
     * |                  | ----------------------
     * |                  | U32 possible_grow (convenient than U8)
     * ------------------------------
     */
    return (uint32)(sizeofcast(uint)
                    + comp_data.import_table_count * (sizeof(uint32) * 3));
}

private uint get_table_size(AOTCompData* comp_data) {
    /*
     * ------------------------------
     * | table_count
     * ------------------------------
     * |             | U32 elem_type
     * | AOTTable[N] | U32 table_flags
     * |             | U32 table_init_size
     * |             | U32 table_max_size
     * |             | U32 possible_grow (convenient than U8)
     * ------------------------------
     */
    return (uint32)(sizeofcast(uint)
                    + comp_data.table_count * (sizeof(uint32) * 5));
}

private uint get_table_info_size(AOTCompData* comp_data) {
    /*
     * ------------------------------
     * | import_table_count
     * ------------------------------
     * |
     * | AOTImportTable[import_table_count]
     * |
     * ------------------------------
     * | table_count
     * ------------------------------
     * |
     * | AOTTable[table_count]
     * |
     * ------------------------------
     * | table_init_data_count
     * ------------------------------
     * |
     * | AOTTableInitData*[table_init_data_count]
     * |
     * ------------------------------
     */
    return get_import_table_size(comp_data) + get_table_size(comp_data)
           + get_table_init_data_list_size(comp_data.table_init_data_list,
                                           comp_data.table_init_data_count);
}

private uint get_func_type_size(AOTFuncType* func_type) {
    /* param count + result count + types */
    return cast(uint)sizeof(uint32) * 2 + func_type.param_count
           + func_type.result_count;
}

private uint get_func_types_size(AOTFuncType** func_types, uint func_type_count) {
    AOTFuncType** func_type = func_types;
    uint size = 0, i = void;

    for (i = 0; i < func_type_count; i++, func_type++) {
        size = align_uint(size, 4);
        size += get_func_type_size(*func_type);
    }
    return size;
}

private uint get_func_type_info_size(AOTCompData* comp_data) {
    /* func type count + func type list */
    return cast(uint)sizeof(uint32)
           + get_func_types_size(comp_data.func_types,
                                 comp_data.func_type_count);
}

private uint get_import_global_size(AOTCompContext* comp_ctx, AOTImportGlobal* import_global) {
    /* type (1 byte) + is_mutable (1 byte) + module_name + global_name */
    uint size = cast(uint)sizeof(uint8) * 2
                  + get_string_size(comp_ctx, import_global.module_name);
    size = align_uint(size, 2);
    size += get_string_size(comp_ctx, import_global.global_name);
    return size;
}

private uint get_import_globals_size(AOTCompContext* comp_ctx, AOTImportGlobal* import_globals, uint import_global_count) {
    AOTImportGlobal* import_global = import_globals;
    uint size = 0, i = void;

    for (i = 0; i < import_global_count; i++, import_global++) {
        size = align_uint(size, 2);
        size += get_import_global_size(comp_ctx, import_global);
    }
    return size;
}

private uint get_import_global_info_size(AOTCompContext* comp_ctx, AOTCompData* comp_data) {
    /* import global count + import globals */
    return cast(uint)sizeof(uint32)
           + get_import_globals_size(comp_ctx, comp_data.import_globals,
                                     comp_data.import_global_count);
}

private uint get_global_size(AOTGlobal* global) {
    if (global.init_expr.init_expr_type != INIT_EXPR_TYPE_V128_CONST)
        /* type (1 byte) + is_mutable (1 byte)
           + init expr type (2 byes) + init expr value (8 byes) */
        return sizeof(uint8) * 2 + sizeof(uint16) + uint64.sizeof;
    else
        /* type (1 byte) + is_mutable (1 byte)
           + init expr type (2 byes) + v128 value (16 byes) */
        return sizeof(uint8) * 2 + sizeof(uint16) + sizeof(uint64) * 2;
}

private uint get_globals_size(AOTGlobal* globals, uint global_count) {
    AOTGlobal* global = globals;
    uint size = 0, i = void;

    for (i = 0; i < global_count; i++, global++) {
        size = align_uint(size, 4);
        size += get_global_size(global);
    }
    return size;
}

private uint get_global_info_size(AOTCompData* comp_data) {
    /* global count + globals */
    return cast(uint)sizeof(uint32)
           + get_globals_size(comp_data.globals, comp_data.global_count);
}

private uint get_import_func_size(AOTCompContext* comp_ctx, AOTImportFunc* import_func) {
    /* type index (2 bytes) + module_name + func_name */
    uint size = cast(uint)sizeof(uint16)
                  + get_string_size(comp_ctx, import_func.module_name);
    size = align_uint(size, 2);
    size += get_string_size(comp_ctx, import_func.func_name);
    return size;
}

private uint get_import_funcs_size(AOTCompContext* comp_ctx, AOTImportFunc* import_funcs, uint import_func_count) {
    AOTImportFunc* import_func = import_funcs;
    uint size = 0, i = void;

    for (i = 0; i < import_func_count; i++, import_func++) {
        size = align_uint(size, 2);
        size += get_import_func_size(comp_ctx, import_func);
    }
    return size;
}

private uint get_import_func_info_size(AOTCompContext* comp_ctx, AOTCompData* comp_data) {
    /* import func count + import funcs */
    return cast(uint)sizeof(uint32)
           + get_import_funcs_size(comp_ctx, comp_data.import_funcs,
                                   comp_data.import_func_count);
}

private uint get_object_data_sections_size(AOTCompContext* comp_ctx, AOTObjectDataSection* data_sections, uint data_sections_count) {
    AOTObjectDataSection* data_section = data_sections;
    uint size = 0, i = void;

    for (i = 0; i < data_sections_count; i++, data_section++) {
        /* name + size + data */
        size = align_uint(size, 2);
        size += get_string_size(comp_ctx, data_section.name);
        size = align_uint(size, 4);
        size += cast(uint)uint32.sizeof;
        size += data_section.size;
    }
    return size;
}

private uint get_object_data_section_info_size(AOTCompContext* comp_ctx, AOTObjectData* obj_data) {
    /* data sections count + data sections */
    return cast(uint)sizeof(uint32)
           + get_object_data_sections_size(comp_ctx, obj_data.data_sections,
                                           obj_data.data_sections_count);
}

private uint get_init_data_section_size(AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint size = 0;

    size += get_mem_info_size(comp_data);

    size = align_uint(size, 4);
    size += get_table_info_size(comp_data);

    size = align_uint(size, 4);
    size += get_func_type_info_size(comp_data);

    size = align_uint(size, 4);
    size += get_import_global_info_size(comp_ctx, comp_data);

    size = align_uint(size, 4);
    size += get_global_info_size(comp_data);

    size = align_uint(size, 4);
    size += get_import_func_info_size(comp_ctx, comp_data);

    /* func count + start func index */
    size = align_uint(size, 4);
    size += cast(uint)sizeof(uint32) * 2;

    /* aux data/heap/stack data */
    size += sizeof(uint32) * 7;

    size += get_object_data_section_info_size(comp_ctx, obj_data);
    return size;
}

private uint get_text_section_size(AOTObjectData* obj_data) {
    return (sizeof(uint32) + obj_data.literal_size + obj_data.text_size + 3)
           & ~3;
}

private uint get_func_section_size(AOTCompData* comp_data, AOTObjectData* obj_data) {
    /* text offsets + function type indexs */
    uint size = 0;

    if (is_32bit_binary(obj_data))
        size = cast(uint)sizeof(uint32) * comp_data.func_count;
    else
        size = cast(uint)sizeof(uint64) * comp_data.func_count;

    size += cast(uint)sizeof(uint32) * comp_data.func_count;
    return size;
}

private uint get_export_size(AOTCompContext* comp_ctx, AOTExport* export_) {
    /* export index + export kind + 1 byte padding + export name */
    return cast(uint)sizeof(uint32) + sizeof(uint8) + 1
           + get_string_size(comp_ctx, export_.name);
}

private uint get_exports_size(AOTCompContext* comp_ctx, AOTExport* exports, uint export_count) {
    AOTExport* export_ = exports;
    uint size = 0, i = void;

    for (i = 0; i < export_count; i++, export_ ++) {
        size = align_uint(size, 4);
        size += get_export_size(comp_ctx, export_);
    }
    return size;
}

private uint get_export_section_size(AOTCompContext* comp_ctx, AOTCompData* comp_data) {
    /* export count + exports */
    return cast(uint)sizeof(uint32)
           + get_exports_size(comp_ctx, comp_data.wasm_module.exports,
                              comp_data.wasm_module.export_count);
}

private uint get_relocation_size(AOTRelocation* relocation, bool is_32bin) {
    /* offset + addend + relocation type + symbol name */
    uint size = 0;
    if (is_32bin)
        size = sizeof(uint32) * 2; /* offset and addend */
    else
        size = sizeof(uint64) * 2;  /* offset and addend */
    size += cast(uint)uint32.sizeof; /* relocation type */
    size += cast(uint)uint32.sizeof; /* symbol name index */
    return size;
}

private uint get_relocations_size(AOTRelocation* relocations, uint relocation_count, bool is_32bin) {
    AOTRelocation* relocation = relocations;
    uint size = 0, i = void;

    for (i = 0; i < relocation_count; i++, relocation++) {
        size = align_uint(size, 4);
        size += get_relocation_size(relocation, is_32bin);
    }
    return size;
}

private uint get_relocation_group_size(AOTRelocationGroup* relocation_group, bool is_32bin) {
    uint size = 0;
    /* section name index + relocation count + relocations */
    size += cast(uint)uint32.sizeof;
    size += cast(uint)uint32.sizeof;
    size += get_relocations_size(relocation_group.relocations,
                                 relocation_group.relocation_count, is_32bin);
    return size;
}

private uint get_relocation_groups_size(AOTRelocationGroup* relocation_groups, uint relocation_group_count, bool is_32bin) {
    AOTRelocationGroup* relocation_group = relocation_groups;
    uint size = 0, i = void;

    for (i = 0; i < relocation_group_count; i++, relocation_group++) {
        size = align_uint(size, 4);
        size += get_relocation_group_size(relocation_group, is_32bin);
    }
    return size;
}

/* return the index (in order of insertion) of the symbol,
   create if not exits, -1 if failed */
private uint get_relocation_symbol_index(const(char)* symbol_name, bool* is_new, AOTSymbolList* symbol_list) {
    AOTSymbolNode* sym = void;
    uint index = 0;

    sym = symbol_list.head;
    while (sym) {
        if (!strcmp(sym.symbol, symbol_name)) {
            if (is_new)
                *is_new = false;
            return index;
        }

        sym = sym.next;
        index++;
    }

    /* Not found in symbol_list, add it */
    sym = wasm_runtime_malloc(AOTSymbolNode.sizeof);
    if (!sym) {
        return (uint32)-1;
    }

    memset(sym, 0, AOTSymbolNode.sizeof);
    sym.symbol = cast(char*)symbol_name;
    sym.str_len = cast(uint)strlen(symbol_name);

    if (!symbol_list.head) {
        symbol_list.head = symbol_list.end = sym;
    }
    else {
        symbol_list.end.next = sym;
        symbol_list.end = sym;
    }
    symbol_list.len++;

    if (is_new)
        *is_new = true;
    return index;
}

private uint get_relocation_symbol_size(AOTCompContext* comp_ctx, AOTRelocation* relocation, AOTSymbolList* symbol_list) {
    uint size = 0, index = 0;
    bool is_new = false;

    index = get_relocation_symbol_index(relocation.symbol_name, &is_new,
                                        symbol_list);
    CHECK_SIZE(index);

    if (is_new) {
        size += get_string_size(comp_ctx, relocation.symbol_name);
        size = align_uint(size, 2);
    }

    relocation.symbol_index = index;
    return size;
}

private uint get_relocations_symbol_size(AOTCompContext* comp_ctx, AOTRelocation* relocations, uint relocation_count, AOTSymbolList* symbol_list) {
    AOTRelocation* relocation = relocations;
    uint size = 0, curr_size = void, i = void;

    for (i = 0; i < relocation_count; i++, relocation++) {
        curr_size =
            get_relocation_symbol_size(comp_ctx, relocation, symbol_list);
        CHECK_SIZE(curr_size);

        size += curr_size;
    }
    return size;
}

private uint get_relocation_group_symbol_size(AOTCompContext* comp_ctx, AOTRelocationGroup* relocation_group, AOTSymbolList* symbol_list) {
    uint size = 0, index = 0, curr_size = void;
    bool is_new = false;

    index = get_relocation_symbol_index(relocation_group.section_name, &is_new,
                                        symbol_list);
    CHECK_SIZE(index);

    if (is_new) {
        size += get_string_size(comp_ctx, relocation_group.section_name);
        size = align_uint(size, 2);
    }

    relocation_group.name_index = index;

    curr_size = get_relocations_symbol_size(
        comp_ctx, relocation_group.relocations,
        relocation_group.relocation_count, symbol_list);
    CHECK_SIZE(curr_size);
    size += curr_size;

    return size;
}

private uint get_relocation_groups_symbol_size(AOTCompContext* comp_ctx, AOTRelocationGroup* relocation_groups, uint relocation_group_count, AOTSymbolList* symbol_list) {
    AOTRelocationGroup* relocation_group = relocation_groups;
    uint size = 0, curr_size = void, i = void;

    for (i = 0; i < relocation_group_count; i++, relocation_group++) {
        curr_size = get_relocation_group_symbol_size(comp_ctx, relocation_group,
                                                     symbol_list);
        CHECK_SIZE(curr_size);
        size += curr_size;
    }
    return size;
}

private uint get_symbol_size_from_symbol_list(AOTCompContext* comp_ctx, AOTSymbolList* symbol_list) {
    AOTSymbolNode* sym = void;
    uint size = 0;

    sym = symbol_list.head;
    while (sym) {
        /* (uint16)str_len + str */
        size += get_string_size(comp_ctx, sym.symbol);
        size = align_uint(size, 2);
        sym = sym.next;
    }

    return size;
}

private uint get_relocation_section_symbol_size(AOTCompContext* comp_ctx, AOTObjectData* obj_data) {
    AOTRelocationGroup* relocation_groups = obj_data.relocation_groups;
    uint relocation_group_count = obj_data.relocation_group_count;
    uint string_count = 0, symbol_table_size = 0;

    /* section size will be calculated twice,
       get symbol size from symbol list directly in the second calculation */
    if (obj_data.symbol_list.len > 0) {
        symbol_table_size =
            get_symbol_size_from_symbol_list(comp_ctx, &obj_data.symbol_list);
    }
    else {
        symbol_table_size = get_relocation_groups_symbol_size(
            comp_ctx, relocation_groups, relocation_group_count,
            &obj_data.symbol_list);
    }
    CHECK_SIZE(symbol_table_size);
    string_count = obj_data.symbol_list.len;

    /* string_count + string_offsets + total_string_len
       + [str (string_len + str)] */
    return (uint32)(sizeof(uint32) + sizeof(uint32) * string_count
                    + sizeof(uint32) + symbol_table_size);
}

private uint get_relocation_section_size(AOTCompContext* comp_ctx, AOTObjectData* obj_data) {
    AOTRelocationGroup* relocation_groups = obj_data.relocation_groups;
    uint relocation_group_count = obj_data.relocation_group_count;
    uint symbol_table_size = 0;

    symbol_table_size = get_relocation_section_symbol_size(comp_ctx, obj_data);
    CHECK_SIZE(symbol_table_size);
    symbol_table_size = align_uint(symbol_table_size, 4);

    /* relocation group count + symbol_table + relocation groups */
    return cast(uint)sizeof(uint32) + symbol_table_size
           + get_relocation_groups_size(relocation_groups,
                                        relocation_group_count,
                                        is_32bit_binary(obj_data));
}

private uint get_native_symbol_list_size(AOTCompContext* comp_ctx) {
    uint len = 0;
    AOTNativeSymbol* sym = null;

    sym = bh_list_first_elem(&comp_ctx.native_symbols);

    while (sym) {
        len = align_uint(len, 2);
        len += get_string_size(comp_ctx, sym.symbol);
        sym = bh_list_elem_next(sym);
    }

    return len;
}

private uint get_name_section_size(AOTCompData* comp_data);

private uint get_custom_sections_size(AOTCompContext* comp_ctx, AOTCompData* comp_data);

private uint get_aot_file_size(AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint size = 0;
    uint size_custom_section = 0;

    /* aot file header */
    size += get_file_header_size();

    /* target info section */
    size = align_uint(size, 4);
    /* section id + section size */
    size += cast(uint)sizeof(uint32) * 2;
    size += get_target_info_section_size();

    /* init data section */
    size = align_uint(size, 4);
    /* section id + section size */
    size += cast(uint)sizeof(uint32) * 2;
    size += get_init_data_section_size(comp_ctx, comp_data, obj_data);

    /* text section */
    size = align_uint(size, 4);
    /* section id + section size */
    size += cast(uint)sizeof(uint32) * 2;
    size += get_text_section_size(obj_data);

    /* function section */
    size = align_uint(size, 4);
    /* section id + section size */
    size += cast(uint)sizeof(uint32) * 2;
    size += get_func_section_size(comp_data, obj_data);

    /* export section */
    size = align_uint(size, 4);
    /* section id + section size */
    size += cast(uint)sizeof(uint32) * 2;
    size += get_export_section_size(comp_ctx, comp_data);

    /* relocation section */
    size = align_uint(size, 4);
    /* section id + section size */
    size += cast(uint)sizeof(uint32) * 2;
    size += get_relocation_section_size(comp_ctx, obj_data);

    if (get_native_symbol_list_size(comp_ctx) > 0) {
        /* emit only when there are native symbols */
        size = align_uint(size, 4);
        /* section id + section size + sub section id + symbol count */
        size += cast(uint)sizeof(uint32) * 4;
        size += get_native_symbol_list_size(comp_ctx);
    }

    if (comp_ctx.enable_aux_stack_frame) {
        /* custom name section */
        size = align_uint(size, 4);
        /* section id + section size + sub section id */
        size += cast(uint)sizeof(uint32) * 3;
        size += (comp_data.aot_name_section_size =
                     get_name_section_size(comp_data));
    }

    size_custom_section = get_custom_sections_size(comp_ctx, comp_data);
    if (size_custom_section > 0) {
        size = align_uint(size, 4);
        size += size_custom_section;
    }

    return size;
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

private void exchange_uint128(ubyte* pData) {
    /* swap high 64bit and low 64bit */
    ulong value = *cast(ulong*)pData;
    *cast(ulong*)pData = *cast(ulong*)(pData + 8);
    *cast(ulong*)(pData + 8) = value;
    /* exchange high 64bit */
    exchange_uint64(pData);
    /* exchange low 64bit */
    exchange_uint64(pData + 8);
}

union ___ue {
    int a;
    char b = 0;
}private ___ue __ue = { a: 1 };

enum string is_little_endian() = ` (__ue.b == 1)`;

enum string CHECK_BUF(string length) = `                       \
    do {                                        \
        if (buf + offset + length > buf_end) {  \
            aot_set_last_error("buf overflow"); \
            return false;                       \
        }                                       \
    } while (0)`;

enum string EMIT_U8(string v) = `                           \
    do {                                     \
        CHECK_BUF(1);                        \
        *(uint8 *)(buf + offset) = (uint8)v; \
        offset++;                            \
    } while (0)`;

enum string EMIT_U16(string v) = `                       \
    do {                                  \
        uint16 t = (uint16)v;             \
        CHECK_BUF(2);                     \
        if (!is_little_endian())          \
            exchange_uint16((uint8 *)&t); \
        *(uint16 *)(buf + offset) = t;    \
        offset += (uint32)sizeof(uint16); \
    } while (0)`;

enum string EMIT_U32(string v) = `                       \
    do {                                  \
        uint32 t = (uint32)v;             \
        CHECK_BUF(4);                     \
        if (!is_little_endian())          \
            exchange_uint32((uint8 *)&t); \
        *(uint32 *)(buf + offset) = t;    \
        offset += (uint32)sizeof(uint32); \
    } while (0)`;

enum string EMIT_U64(string v) = `                       \
    do {                                  \
        uint64 t = (uint64)v;             \
        CHECK_BUF(8);                     \
        if (!is_little_endian())          \
            exchange_uint64((uint8 *)&t); \
        PUT_U64_TO_ADDR(buf + offset, t); \
        offset += (uint32)sizeof(uint64); \
    } while (0)`;

enum string EMIT_V128(string v) = `                         \
    do {                                     \
        uint64 *t = (uint64 *)v.i64x2;       \
        CHECK_BUF(16);                       \
        if (!is_little_endian())             \
            exchange_uint128((uint8 *)t);    \
        PUT_U64_TO_ADDR(buf + offset, t[0]); \
        offset += (uint32)sizeof(uint64);    \
        PUT_U64_TO_ADDR(buf + offset, t[1]); \
        offset += (uint32)sizeof(uint64);    \
    } while (0)`;

enum string EMIT_BUF(string v, string len) = `              \
    do {                              \
        CHECK_BUF(len);               \
        memcpy(buf + offset, v, len); \
        offset += len;                \
    } while (0)`;

enum string EMIT_STR(string s) = `                                   \
    do {                                              \
        uint32 str_len = (uint32)strlen(s);           \
        if (str_len > INT16_MAX) {                    \
            aot_set_last_error("emit string failed: " \
                               "string too long");    \
            return false;                             \
        }                                             \
        if (comp_ctx->is_indirect_mode)               \
            /* emit '\0' only in XIP mode */          \
            str_len++;                                \
        EMIT_U16(str_len);                            \
        EMIT_BUF(s, str_len);                         \
    } while (0)`;

private bool read_leb(ubyte** p_buf, const(ubyte)* buf_end, uint maxbits, bool sign, ulong* p_result) {
    const(ubyte)* buf = *p_buf;
    ulong result = 0;
    uint shift = 0;
    uint offset = 0, bcnt = 0;
    ulong byte_ = void;

    while (true) {
        /* uN or SN must not exceed ceil(N/7) bytes */
        if (bcnt + 1 > (maxbits + 6) / 7) {
            aot_set_last_error("integer representation too long");
            return false;
        }

        if (buf + offset + 1 > buf_end) {
            aot_set_last_error("unexpected end of section or function");
            return false;
        }
        byte_ = buf[offset];
        offset += 1;
        result |= ((byte_ & 0x7f) << shift);
        shift += 7;
        bcnt += 1;
        if ((byte_ & 0x80) == 0) {
            break;
        }
    }

    if (!sign && maxbits == 32 && shift >= maxbits) {
        /* The top bits set represent values > 32 bits */
        if ((cast(ubyte)byte_) & 0xf0)
            goto fail_integer_too_large;
    }
    else if (sign && maxbits == 32) {
        if (shift < maxbits) {
            /* Sign extend, second highest bit is the sign bit */
            if (cast(ubyte)byte_ & 0x40)
                result |= (~(cast(ulong)0)) << shift;
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = (cast(ubyte)byte_) & 0x8;
            int top_bits = (cast(ubyte)byte_) & 0xf0;
            if ((sign_bit_set && top_bits != 0x70)
                || (!sign_bit_set && top_bits != 0))
                goto fail_integer_too_large;
        }
    }
    else if (sign && maxbits == 64) {
        if (shift < maxbits) {
            /* Sign extend, second highest bit is the sign bit */
            if (cast(ubyte)byte_ & 0x40)
                result |= (~(cast(ulong)0)) << shift;
        }
        else {
            /* The top bits should be a sign-extension of the sign bit */
            bool sign_bit_set = (cast(ubyte)byte_) & 0x1;
            int top_bits = (cast(ubyte)byte_) & 0xfe;

            if ((sign_bit_set && top_bits != 0x7e)
                || (!sign_bit_set && top_bits != 0))
                goto fail_integer_too_large;
        }
    }

    *p_buf += offset;
    *p_result = result;
    return true;

fail_integer_too_large:
    aot_set_last_error("integer too large");
    return false;
}

enum string read_leb_uint32(string p, string p_end, string res) = `                         \
    do {                                                       \
        uint64 res64;                                          \
        if (!read_leb((uint8 **)&p, p_end, 32, false, &res64)) \
            goto fail;                                         \
        res = (uint32)res64;                                   \
    } while (0)`;

private uint get_name_section_size(AOTCompData* comp_data) {
    const(ubyte)* p = comp_data.name_section_buf, p_end = comp_data.name_section_buf_end;
    ubyte* buf = void, buf_end = void;
    uint name_type = void, subsection_size = void;
    uint previous_name_type = 0;
    uint num_func_name = void;
    uint func_index = void;
    uint previous_func_index = ~0U;
    uint func_name_len = void;
    uint name_index = void;
    int i = 0;
    uint name_len = void;
    uint offset = 0;
    uint max_aot_buf_size = 0;

    if (p >= p_end) {
        aot_set_last_error("unexpected end");
        return 0;
    }

    max_aot_buf_size = 4 * (uint32)(p_end - p);
    if (((buf = comp_data.aot_name_section_buf =
              wasm_runtime_malloc(max_aot_buf_size)) == 0)) {
        aot_set_last_error("allocate memory for custom name section failed.");
        return 0;
    }
    buf_end = buf + max_aot_buf_size;

    read_leb_uint32(p, p_end, name_len);
    offset = align_uint(offset, 4);
    EMIT_U32(name_len);

    if (name_len == 0 || p + name_len > p_end) {
        aot_set_last_error("unexpected end");
        return 0;
    }

    if (!check_utf8_str(p, name_len)) {
        aot_set_last_error("invalid UTF-8 encoding");
        return 0;
    }

    if (memcmp(p, "name", 4) != 0) {
        aot_set_last_error("invalid custom name section");
        return 0;
    }
    EMIT_BUF(p, name_len);
    p += name_len;

    while (p < p_end) {
        read_leb_uint32(p, p_end, name_type);
        if (i != 0) {
            if (name_type == previous_name_type) {
                aot_set_last_error("duplicate sub-section");
                return 0;
            }
            if (name_type < previous_name_type) {
                aot_set_last_error("out-of-order sub-section");
                return 0;
            }
        }
        previous_name_type = name_type;
        read_leb_uint32(p, p_end, subsection_size);
        switch (name_type) {
            case SUB_SECTION_TYPE_FUNC:
                if (subsection_size) {
                    offset = align_uint(offset, 4);
                    EMIT_U32(name_type);
                    EMIT_U32(subsection_size);

                    read_leb_uint32(p, p_end, num_func_name);
                    EMIT_U32(num_func_name);

                    for (name_index = 0; name_index < num_func_name;
                         name_index++) {
                        read_leb_uint32(p, p_end, func_index);
                        offset = align_uint(offset, 4);
                        EMIT_U32(func_index);
                        if (func_index == previous_func_index) {
                            aot_set_last_error("duplicate function name");
                            return 0;
                        }
                        if (func_index < previous_func_index
                            && previous_func_index != ~0U) {
                            aot_set_last_error("out-of-order function index ");
                            return 0;
                        }
                        previous_func_index = func_index;
                        read_leb_uint32(p, p_end, func_name_len);
                        offset = align_uint(offset, 2);
                        EMIT_U16(func_name_len);
                        EMIT_BUF(p, func_name_len);
                        p += func_name_len;
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

    return offset;
fail:
    return 0;
}

private uint get_custom_sections_size(AOTCompContext* comp_ctx, AOTCompData* comp_data) {
static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
    uint size = 0, i = void;

    for (i = 0; i < comp_ctx.custom_sections_count; i++) {
        const(char)* section_name = comp_ctx.custom_sections_wp[i];
        const(ubyte)* content = null;
        uint length = 0;

        content = wasm_loader_get_custom_section(comp_data.wasm_module,
                                                 section_name, &length);
        if (!content) {
            LOG_WARNING("Can't find custom section [%s], ignore it",
                        section_name);
            continue;
        }

        size = align_uint(size, 4);
        /* section id + section size + sub section id */
        size += cast(uint)sizeof(uint32) * 3;
        /* section name and len */
        size += get_string_size(comp_ctx, section_name);
        /* section content */
        size += length;
    }

    return size;
} else {
    return 0;
}
}

private bool aot_emit_file_header(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset;
    uint aot_curr_version = AOT_CURRENT_VERSION;

    EMIT_U8('\0');
    EMIT_U8('a');
    EMIT_U8('o');
    EMIT_U8('t');

    EMIT_U32(aot_curr_version);

    *p_offset = offset;
    return true;
}

private bool aot_emit_target_info_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset;
    uint section_size = get_target_info_section_size();
    AOTTargetInfo* target_info = &obj_data.target_info;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_TARGET_INFO);
    EMIT_U32(section_size);

    EMIT_U16(target_info.bin_type);
    EMIT_U16(target_info.abi_type);
    EMIT_U16(target_info.e_type);
    EMIT_U16(target_info.e_machine);
    EMIT_U32(target_info.e_version);
    EMIT_U32(target_info.e_flags);
    EMIT_U32(target_info.reserved);
    EMIT_BUF(target_info.arch, typeof(target_info.arch).sizeof);

    if (offset - *p_offset != section_size + sizeof(uint32) * 2) {
        aot_set_last_error("emit target info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_mem_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void;
    AOTMemInitData** init_datas = comp_data.mem_init_data_list;

    *p_offset = offset = align_uint(offset, 4);

    /* Emit import memory count, only emit 0 currently.
       TODO: emit the actual import memory count and
             the full import memory info. */
    EMIT_U32(0);

    /* Emit memory count */
    EMIT_U32(comp_data.memory_count);
    /* Emit memory items */
    for (i = 0; i < comp_data.memory_count; i++) {
        EMIT_U32(comp_data.memories[i].memory_flags);
        EMIT_U32(comp_data.memories[i].num_bytes_per_page);
        EMIT_U32(comp_data.memories[i].mem_init_page_count);
        EMIT_U32(comp_data.memories[i].mem_max_page_count);
    }

    /* Emit mem init data count */
    EMIT_U32(comp_data.mem_init_data_count);
    /* Emit mem init data items */
    for (i = 0; i < comp_data.mem_init_data_count; i++) {
        offset = align_uint(offset, 4);
static if (WASM_ENABLE_BULK_MEMORY != 0) {
        if (comp_ctx.enable_bulk_memory) {
            EMIT_U32(init_datas[i].is_passive);
            EMIT_U32(init_datas[i].memory_index);
        }
        else
}
        {
            /* emit two placeholder to keep the same size */
            EMIT_U32(0);
            EMIT_U32(0);
        }
        EMIT_U32(init_datas[i].offset.init_expr_type);
        EMIT_U64(init_datas[i].offset.u.i64);
        EMIT_U32(init_datas[i].byte_count);
        EMIT_BUF(init_datas[i].bytes, init_datas[i].byte_count);
    }

    if (offset - *p_offset != get_mem_info_size(comp_data)) {
        aot_set_last_error("emit memory info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_table_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void, j = void;
    AOTTableInitData** init_datas = comp_data.table_init_data_list;

    *p_offset = offset = align_uint(offset, 4);

    /* Emit import table count */
    EMIT_U32(comp_data.import_table_count);
    /* Emit table items */
    for (i = 0; i < comp_data.import_table_count; i++) {
        /* TODO:
         * EMIT_STR(comp_data->import_tables[i].module_name );
         * EMIT_STR(comp_data->import_tables[i].table_name);
         */
        EMIT_U32(comp_data.import_tables[i].elem_type);
        EMIT_U32(comp_data.import_tables[i].table_init_size);
        EMIT_U32(comp_data.import_tables[i].table_max_size);
        EMIT_U32(comp_data.import_tables[i].possible_grow & 0x000000FF);
    }

    /* Emit table count */
    EMIT_U32(comp_data.table_count);
    /* Emit table items */
    for (i = 0; i < comp_data.table_count; i++) {
        EMIT_U32(comp_data.tables[i].elem_type);
        EMIT_U32(comp_data.tables[i].table_flags);
        EMIT_U32(comp_data.tables[i].table_init_size);
        EMIT_U32(comp_data.tables[i].table_max_size);
        EMIT_U32(comp_data.tables[i].possible_grow & 0x000000FF);
    }

    /* Emit table init data count */
    EMIT_U32(comp_data.table_init_data_count);
    /* Emit table init data items */
    for (i = 0; i < comp_data.table_init_data_count; i++) {
        offset = align_uint(offset, 4);
        EMIT_U32(init_datas[i].mode);
        EMIT_U32(init_datas[i].elem_type);
        EMIT_U32(init_datas[i].table_index);
        EMIT_U32(init_datas[i].offset.init_expr_type);
        EMIT_U64(init_datas[i].offset.u.i64);
        EMIT_U32(init_datas[i].func_index_count);
        for (j = 0; j < init_datas[i].func_index_count; j++)
            EMIT_U32(init_datas[i].func_indexes[j]);
    }

    if (offset - *p_offset != get_table_info_size(comp_data)) {
        aot_set_last_error("emit table info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_func_type_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void;
    AOTFuncType** func_types = comp_data.func_types;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(comp_data.func_type_count);

    for (i = 0; i < comp_data.func_type_count; i++) {
        offset = align_uint(offset, 4);
        EMIT_U32(func_types[i].param_count);
        EMIT_U32(func_types[i].result_count);
        EMIT_BUF(func_types[i].types,
                 func_types[i].param_count + func_types[i].result_count);
    }

    if (offset - *p_offset != get_func_type_info_size(comp_data)) {
        aot_set_last_error("emit function type info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_import_global_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void;
    AOTImportGlobal* import_global = comp_data.import_globals;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(comp_data.import_global_count);

    for (i = 0; i < comp_data.import_global_count; i++, import_global++) {
        offset = align_uint(offset, 2);
        EMIT_U8(import_global.type);
        EMIT_U8(import_global.is_mutable);
        EMIT_STR(import_global.module_name);
        offset = align_uint(offset, 2);
        EMIT_STR(import_global.global_name);
    }

    if (offset - *p_offset
        != get_import_global_info_size(comp_ctx, comp_data)) {
        aot_set_last_error("emit import global info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_global_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void;
    AOTGlobal* global = comp_data.globals;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(comp_data.global_count);

    for (i = 0; i < comp_data.global_count; i++, global++) {
        offset = align_uint(offset, 4);
        EMIT_U8(global.type);
        EMIT_U8(global.is_mutable);
        EMIT_U16(global.init_expr.init_expr_type);
        if (global.init_expr.init_expr_type != INIT_EXPR_TYPE_V128_CONST)
            EMIT_U64(global.init_expr.u.i64);
        else
            EMIT_V128(global.init_expr.u.v128);
    }

    if (offset - *p_offset != get_global_info_size(comp_data)) {
        aot_set_last_error("emit global info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_import_func_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void;
    AOTImportFunc* import_func = comp_data.import_funcs;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(comp_data.import_func_count);

    for (i = 0; i < comp_data.import_func_count; i++, import_func++) {
        offset = align_uint(offset, 2);
        EMIT_U16(import_func.func_type_index);
        EMIT_STR(import_func.module_name);
        offset = align_uint(offset, 2);
        EMIT_STR(import_func.func_name);
    }

    if (offset - *p_offset != get_import_func_info_size(comp_ctx, comp_data)) {
        aot_set_last_error("emit import function info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_object_data_section_info(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTObjectData* obj_data) {
    uint offset = *p_offset, i = void;
    AOTObjectDataSection* data_section = obj_data.data_sections;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(obj_data.data_sections_count);

    for (i = 0; i < obj_data.data_sections_count; i++, data_section++) {
        offset = align_uint(offset, 2);
        EMIT_STR(data_section.name);
        offset = align_uint(offset, 4);
        EMIT_U32(data_section.size);
        EMIT_BUF(data_section.data, data_section.size);
    }

    if (offset - *p_offset
        != get_object_data_section_info_size(comp_ctx, obj_data)) {
        aot_set_last_error("emit object data section info failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_init_data_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint section_size = get_init_data_section_size(comp_ctx, comp_data, obj_data);
    uint offset = *p_offset;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_INIT_DATA);
    EMIT_U32(section_size);

    if (!aot_emit_mem_info(buf, buf_end, &offset, comp_ctx, comp_data, obj_data)
        || !aot_emit_table_info(buf, buf_end, &offset, comp_ctx, comp_data,
                                obj_data)
        || !aot_emit_func_type_info(buf, buf_end, &offset, comp_data, obj_data)
        || !aot_emit_import_global_info(buf, buf_end, &offset, comp_ctx,
                                        comp_data, obj_data)
        || !aot_emit_global_info(buf, buf_end, &offset, comp_data, obj_data)
        || !aot_emit_import_func_info(buf, buf_end, &offset, comp_ctx,
                                      comp_data, obj_data))
        return false;

    offset = align_uint(offset, 4);
    EMIT_U32(comp_data.func_count);
    EMIT_U32(comp_data.start_func_index);

    EMIT_U32(comp_data.aux_data_end_global_index);
    EMIT_U32(comp_data.aux_data_end);
    EMIT_U32(comp_data.aux_heap_base_global_index);
    EMIT_U32(comp_data.aux_heap_base);
    EMIT_U32(comp_data.aux_stack_top_global_index);
    EMIT_U32(comp_data.aux_stack_bottom);
    EMIT_U32(comp_data.aux_stack_size);

    if (!aot_emit_object_data_section_info(buf, buf_end, &offset, comp_ctx,
                                           obj_data))
        return false;

    if (offset - *p_offset != section_size + sizeof(uint32) * 2) {
        aot_set_last_error("emit init data section failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_text_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint section_size = get_text_section_size(obj_data);
    uint offset = *p_offset;
    ubyte placeholder = 0;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_TEXT);
    EMIT_U32(section_size);
    EMIT_U32(obj_data.literal_size);
    if (obj_data.literal_size > 0)
        EMIT_BUF(obj_data.literal, obj_data.literal_size);
    EMIT_BUF(obj_data.text, obj_data.text_size);

    while (offset & 3)
        EMIT_BUF(&placeholder, 1);

    if (offset - *p_offset != section_size + sizeof(uint32) * 2) {
        aot_set_last_error("emit text section failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_func_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint section_size = get_func_section_size(comp_data, obj_data);
    uint i = void, offset = *p_offset;
    AOTObjectFunc* func = obj_data.funcs;
    AOTFunc** funcs = comp_data.funcs;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_FUNCTION);
    EMIT_U32(section_size);

    for (i = 0; i < obj_data.func_count; i++, func++) {
        if (is_32bit_binary(obj_data))
            EMIT_U32(func.text_offset);
        else
            EMIT_U64(func.text_offset);
    }

    for (i = 0; i < comp_data.func_count; i++)
        EMIT_U32(funcs[i].func_type_index);

    if (offset - *p_offset != section_size + sizeof(uint32) * 2) {
        aot_set_last_error("emit function section failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_export_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint section_size = get_export_section_size(comp_ctx, comp_data);
    AOTExport* export_ = comp_data.wasm_module.exports;
    uint export_count = comp_data.wasm_module.export_count;
    uint i = void, offset = *p_offset;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_EXPORT);
    EMIT_U32(section_size);
    EMIT_U32(export_count);

    for (i = 0; i < export_count; i++, export_ ++) {
        offset = align_uint(offset, 4);
        EMIT_U32(export_.index);
        EMIT_U8(export_.kind);
        EMIT_U8(0);
        EMIT_STR(export_.name);
    }

    if (offset - *p_offset != section_size + sizeof(uint32) * 2) {
        aot_set_last_error("emit export section failed.");
        return false;
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_relocation_symbol_table(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint symbol_offset = 0, total_string_len = 0;
    uint offset = *p_offset;
    AOTSymbolNode* sym = void;

    EMIT_U32(obj_data.symbol_list.len);

    /* emit symbol offsets */
    sym = cast(AOTSymbolNode*)(obj_data.symbol_list.head);
    while (sym) {
        EMIT_U32(symbol_offset);
        /* string_len + str[0 .. string_len - 1] */
        symbol_offset += get_string_size(comp_ctx, sym.symbol);
        symbol_offset = align_uint(symbol_offset, 2);
        sym = sym.next;
    }

    /* emit total string len */
    total_string_len = symbol_offset;
    EMIT_U32(total_string_len);

    /* emit symbols */
    sym = cast(AOTSymbolNode*)(obj_data.symbol_list.head);
    while (sym) {
        EMIT_STR(sym.symbol);
        offset = align_uint(offset, 2);
        sym = sym.next;
    }

    *p_offset = offset;
    return true;
}

private bool aot_emit_relocation_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx, AOTCompData* comp_data, AOTObjectData* obj_data) {
    uint section_size = get_relocation_section_size(comp_ctx, obj_data);
    uint i = void, offset = *p_offset;
    AOTRelocationGroup* relocation_group = obj_data.relocation_groups;

    if (section_size == (uint32)-1)
        return false;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_RELOCATION);
    EMIT_U32(section_size);

    aot_emit_relocation_symbol_table(buf, buf_end, &offset, comp_ctx, comp_data,
                                     obj_data);

    offset = align_uint(offset, 4);
    EMIT_U32(obj_data.relocation_group_count);

    /* emit each relocation group */
    for (i = 0; i < obj_data.relocation_group_count; i++, relocation_group++) {
        AOTRelocation* relocation = relocation_group.relocations;
        uint j = void;

        offset = align_uint(offset, 4);
        EMIT_U32(relocation_group.name_index);
        offset = align_uint(offset, 4);
        EMIT_U32(relocation_group.relocation_count);

        /* emit each relocation */
        for (j = 0; j < relocation_group.relocation_count; j++, relocation++) {
            offset = align_uint(offset, 4);
            if (is_32bit_binary(obj_data)) {
                EMIT_U32(relocation.relocation_offset);
                EMIT_U32(relocation.relocation_addend);
            }
            else {
                EMIT_U64(relocation.relocation_offset);
                EMIT_U64(relocation.relocation_addend);
            }
            EMIT_U32(relocation.relocation_type);
            EMIT_U32(relocation.symbol_index);
        }
    }

    if (offset - *p_offset != section_size + sizeof(uint32) * 2) {
        aot_set_last_error("emit relocation section failed.");
        return false;
    }

    *p_offset = offset;
    return true;
}

private bool aot_emit_native_symbol(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompContext* comp_ctx) {
    uint offset = *p_offset;
    AOTNativeSymbol* sym = null;

    if (bh_list_length(&comp_ctx.native_symbols) == 0)
        /* emit only when there are native symbols */
        return true;

    *p_offset = offset = align_uint(offset, 4);

    EMIT_U32(AOT_SECTION_TYPE_CUSTOM);
    /* sub section id + symbol count + symbol list */
    EMIT_U32(sizeof(uint32) * 2 + get_native_symbol_list_size(comp_ctx));
    EMIT_U32(AOT_CUSTOM_SECTION_NATIVE_SYMBOL);
    EMIT_U32(bh_list_length(&comp_ctx.native_symbols));

    sym = bh_list_first_elem(&comp_ctx.native_symbols);

    while (sym) {
        offset = align_uint(offset, 2);
        EMIT_STR(sym.symbol);
        sym = bh_list_elem_next(sym);
    }

    *p_offset = offset;

    return true;
}

private bool aot_emit_name_section(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTCompContext* comp_ctx) {
    if (comp_ctx.enable_aux_stack_frame) {
        uint offset = *p_offset;

        *p_offset = offset = align_uint(offset, 4);

        EMIT_U32(AOT_SECTION_TYPE_CUSTOM);
        /* sub section id + name section size */
        EMIT_U32(sizeof(uint32) * 1 + comp_data.aot_name_section_size);
        EMIT_U32(AOT_CUSTOM_SECTION_NAME);
        bh_memcpy_s(cast(ubyte*)(buf + offset), (uint32)(buf_end - buf),
                    comp_data.aot_name_section_buf,
                    cast(uint)comp_data.aot_name_section_size);
        offset += comp_data.aot_name_section_size;

        *p_offset = offset;
    }

    return true;
}

private bool aot_emit_custom_sections(ubyte* buf, ubyte* buf_end, uint* p_offset, AOTCompData* comp_data, AOTCompContext* comp_ctx) {
static if (WASM_ENABLE_LOAD_CUSTOM_SECTION != 0) {
    uint offset = *p_offset, i = void;

    for (i = 0; i < comp_ctx.custom_sections_count; i++) {
        const(char)* section_name = comp_ctx.custom_sections_wp[i];
        const(ubyte)* content = null;
        uint length = 0;

        content = wasm_loader_get_custom_section(comp_data.wasm_module,
                                                 section_name, &length);
        if (!content) {
            /* Warning has been reported during calculating size */
            continue;
        }

        offset = align_uint(offset, 4);
        EMIT_U32(AOT_SECTION_TYPE_CUSTOM);
        /* sub section id + content */
        EMIT_U32(sizeof(uint32) * 1 + get_string_size(comp_ctx, section_name)
                 + length);
        EMIT_U32(AOT_CUSTOM_SECTION_RAW);
        EMIT_STR(section_name);
        bh_memcpy_s(cast(ubyte*)(buf + offset), (uint32)(buf_end - buf), content,
                    length);
        offset += length;
    }

    *p_offset = offset;
}

    return true;
}

alias U32 = uint;
alias I32 = int;
alias U16 = ushort;
alias U8 = ubyte;

struct coff_hdr {
    U16 u16Machine;
    U16 u16NumSections;
    U32 u32DateTimeStamp;
    U32 u32SymTblPtr;
    U32 u32NumSymbols;
    U16 u16PeHdrSize;
    U16 u16Characs;
}

enum E_TYPE_REL = 1;
enum E_TYPE_XIP = 4;

enum IMAGE_FILE_MACHINE_AMD64 = 0x8664;
enum IMAGE_FILE_MACHINE_I386 = 0x014c;
enum IMAGE_FILE_MACHINE_IA64 = 0x0200;

enum AOT_COFF32_BIN_TYPE = 4 /* 32-bit little endian */;
enum AOT_COFF64_BIN_TYPE = 6 /* 64-bit little endian */;

enum EI_NIDENT = 16;

alias elf32_word = uint;
alias elf32_sword = int;
alias elf32_half = ushort;
alias elf32_off = uint;
alias elf32_addr = uint;

struct elf32_ehdr {
    ubyte[EI_NIDENT] e_ident; /* ident bytes */
    elf32_half e_type;                /* file type */
    elf32_half e_machine;             /* target machine */
    elf32_word e_version;             /* file version */
    elf32_addr e_entry;               /* start address */
    elf32_off e_phoff;                /* phdr file offset */
    elf32_off e_shoff;                /* shdr file offset */
    elf32_word e_flags;               /* file flags */
    elf32_half e_ehsize;              /* sizeof ehdr */
    elf32_half e_phentsize;           /* sizeof phdr */
    elf32_half e_phnum;               /* number phdrs */
    elf32_half e_shentsize;           /* sizeof shdr */
    elf32_half e_shnum;               /* number shdrs */
    elf32_half e_shstrndx;            /* shdr string index */
}

struct elf32_rel {
    elf32_addr r_offset;
    elf32_word r_info;
}elf32_rel elf32_rel;

struct elf32_rela {
    elf32_addr r_offset;
    elf32_word r_info;
    elf32_sword r_addend;
}elf32_rela elf32_rela;

alias elf64_word = uint;
alias elf64_sword = int;
alias elf64_xword = ulong;
alias elf64_sxword = long;
alias elf64_half = ushort;
alias elf64_off = ulong;
alias elf64_addr = ulong;

struct elf64_ehdr {
    ubyte[EI_NIDENT] e_ident; /* ident bytes */
    elf64_half e_type;                /* file type */
    elf64_half e_machine;             /* target machine */
    elf64_word e_version;             /* file version */
    elf64_addr e_entry;               /* start address */
    elf64_off e_phoff;                /* phdr file offset */
    elf64_off e_shoff;                /* shdr file offset */
    elf64_word e_flags;               /* file flags */
    elf64_half e_ehsize;              /* sizeof ehdr */
    elf64_half e_phentsize;           /* sizeof phdr */
    elf64_half e_phnum;               /* number phdrs */
    elf64_half e_shentsize;           /* sizeof shdr */
    elf64_half e_shnum;               /* number shdrs */
    elf64_half e_shstrndx;            /* shdr string index */
}

struct elf64_rel {
    elf64_addr r_offset;
    elf64_xword r_info;
}

struct elf64_rela {
    elf64_addr r_offset;
    elf64_xword r_info;
    elf64_sxword r_addend;
}

enum string SET_TARGET_INFO(string f, string v, string type, string little) = `     \
    do {                                        \
        type tmp = elf_header->v;               \
        if ((little && !is_little_endian())     \
            || (!little && is_little_endian())) \
            exchange_##type((uint8 *)&tmp);     \
        obj_data->target_info.f = tmp;          \
    } while (0)`;

private bool aot_resolve_target_info(AOTCompContext* comp_ctx, AOTObjectData* obj_data) {
    LLVMBinaryType bin_type = LLVMBinaryGetType(obj_data.binary);
    const(ubyte)* elf_buf = cast(ubyte*)LLVMGetBufferStart(obj_data.mem_buf);
    uint elf_size = cast(uint)LLVMGetBufferSize(obj_data.mem_buf);

    if (bin_type != LLVMBinaryTypeCOFF && bin_type != LLVMBinaryTypeELF32L
        && bin_type != LLVMBinaryTypeELF32B && bin_type != LLVMBinaryTypeELF64L
        && bin_type != LLVMBinaryTypeELF64B
        && bin_type != LLVMBinaryTypeMachO32L
        && bin_type != LLVMBinaryTypeMachO32B
        && bin_type != LLVMBinaryTypeMachO64L
        && bin_type != LLVMBinaryTypeMachO64B) {
        aot_set_last_error("invaid llvm binary bin_type.");
        return false;
    }

    obj_data.target_info.bin_type = bin_type - LLVMBinaryTypeELF32L;

    if (bin_type == LLVMBinaryTypeCOFF) {
        coff_hdr* coff_header = void;

        if (!elf_buf || elf_size < coff_hdr.sizeof) {
            aot_set_last_error("invalid coff_hdr buffer.");
            return false;
        }
        coff_header = cast(coff_hdr*)elf_buf;

        /* Emit eXecute In Place file type while in indirect mode */
        if (comp_ctx.is_indirect_mode)
            obj_data.target_info.e_type = E_TYPE_XIP;
        else
            obj_data.target_info.e_type = E_TYPE_REL;

        obj_data.target_info.e_machine = coff_header.u16Machine;
        obj_data.target_info.e_version = 1;
        obj_data.target_info.e_flags = 0;

        if (coff_header.u16Machine == IMAGE_FILE_MACHINE_AMD64
            || coff_header.u16Machine == IMAGE_FILE_MACHINE_IA64)
            obj_data.target_info.bin_type = AOT_COFF64_BIN_TYPE;
        else if (coff_header.u16Machine == IMAGE_FILE_MACHINE_I386)
            obj_data.target_info.bin_type = AOT_COFF32_BIN_TYPE;
    }
    else if (bin_type == LLVMBinaryTypeELF32L
             || bin_type == LLVMBinaryTypeELF32B) {
        elf32_ehdr* elf_header = void;
        bool is_little_bin = bin_type == LLVMBinaryTypeELF32L;

        if (!elf_buf || elf_size < elf32_ehdr.sizeof) {
            aot_set_last_error("invalid elf32 buffer.");
            return false;
        }

        elf_header = cast(elf32_ehdr*)elf_buf;

        /* Emit eXecute In Place file type while in indirect mode */
        if (comp_ctx.is_indirect_mode)
            elf_header.e_type = E_TYPE_XIP;

        SET_TARGET_INFO(e_type, e_type, uint16, is_little_bin);
        SET_TARGET_INFO(e_machine, e_machine, uint16, is_little_bin);
        SET_TARGET_INFO(e_version, e_version, uint32, is_little_bin);
        SET_TARGET_INFO(e_flags, e_flags, uint32, is_little_bin);
    }
    else if (bin_type == LLVMBinaryTypeELF64L
             || bin_type == LLVMBinaryTypeELF64B) {
        elf64_ehdr* elf_header = void;
        bool is_little_bin = bin_type == LLVMBinaryTypeELF64L;

        if (!elf_buf || elf_size < elf64_ehdr.sizeof) {
            aot_set_last_error("invalid elf64 buffer.");
            return false;
        }

        elf_header = cast(elf64_ehdr*)elf_buf;

        /* Emit eXecute In Place file type while in indirect mode */
        if (comp_ctx.is_indirect_mode)
            elf_header.e_type = E_TYPE_XIP;

        SET_TARGET_INFO(e_type, e_type, uint16, is_little_bin);
        SET_TARGET_INFO(e_machine, e_machine, uint16, is_little_bin);
        SET_TARGET_INFO(e_version, e_version, uint32, is_little_bin);
        SET_TARGET_INFO(e_flags, e_flags, uint32, is_little_bin);
    }
    else if (bin_type == LLVMBinaryTypeMachO32L
             || bin_type == LLVMBinaryTypeMachO32B) {
        /* TODO: parse file type of Mach-O 32 */
        aot_set_last_error("invaid llvm binary bin_type.");
        return false;
    }
    else if (bin_type == LLVMBinaryTypeMachO64L
             || bin_type == LLVMBinaryTypeMachO64B) {
        /* TODO: parse file type of Mach-O 64 */
        aot_set_last_error("invaid llvm binary bin_type.");
        return false;
    }

    bh_assert(typeof(obj_data.target_info.arch).sizeof
              == typeof(comp_ctx.target_arch).sizeof);
    bh_memcpy_s(obj_data.target_info.arch, typeof(obj_data.target_info.arch).sizeof,
                comp_ctx.target_arch, typeof(comp_ctx.target_arch).sizeof);

    return true;
}

private bool aot_resolve_text(AOTObjectData* obj_data) {
static if (WASM_ENABLE_DEBUG_AOT != 0) {
    LLVMBinaryType bin_type = LLVMBinaryGetType(obj_data.binary);
    if (bin_type == LLVMBinaryTypeELF32L || bin_type == LLVMBinaryTypeELF64L) {
        obj_data.text = cast(char*)LLVMGetBufferStart(obj_data.mem_buf);
        obj_data.text_size = cast(uint)LLVMGetBufferSize(obj_data.mem_buf);
    }
    else
}
    {
        LLVMSectionIteratorRef sec_itr = void;
        char* name = void;

        if (((sec_itr = LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
            aot_set_last_error("llvm get section iterator failed.");
            return false;
        }
        while (
            !LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary, sec_itr)) {
            if ((name = cast(char*)LLVMGetSectionName(sec_itr))
                && !strcmp(name, ".text")) {
                obj_data.text = cast(char*)LLVMGetSectionContents(sec_itr);
                obj_data.text_size = cast(uint)LLVMGetSectionSize(sec_itr);
                break;
            }
            LLVMMoveToNextSection(sec_itr);
        }
        LLVMDisposeSectionIterator(sec_itr);
    }

    return true;
}

private bool aot_resolve_literal(AOTObjectData* obj_data) {
    LLVMSectionIteratorRef sec_itr = void;
    char* name = void;

    if (((sec_itr = LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
        aot_set_last_error("llvm get section iterator failed.");
        return false;
    }
    while (!LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary, sec_itr)) {
        if ((name = cast(char*)LLVMGetSectionName(sec_itr))
            && !strcmp(name, ".literal")) {
            obj_data.literal = cast(char*)LLVMGetSectionContents(sec_itr);
            obj_data.literal_size = cast(uint)LLVMGetSectionSize(sec_itr);
            break;
        }
        LLVMMoveToNextSection(sec_itr);
    }
    LLVMDisposeSectionIterator(sec_itr);

    return true;
}

private bool get_relocations_count(LLVMSectionIteratorRef sec_itr, uint* p_count);

private bool is_data_section(LLVMSectionIteratorRef sec_itr, char* section_name) {
    uint relocation_count = 0;

    return (!strcmp(section_name, ".data") || !strcmp(section_name, ".sdata")
            || !strcmp(section_name, ".rodata")
            /* ".rodata.cst4/8/16/.." */
            || !strncmp(section_name, ".rodata.cst", strlen(".rodata.cst"))
            /* ".rodata.strn.m" */
            || !strncmp(section_name, ".rodata.str", strlen(".rodata.str"))
            || (!strcmp(section_name, ".rdata")
                && get_relocations_count(sec_itr, &relocation_count)
                && relocation_count > 0));
}

private bool get_object_data_sections_count(AOTObjectData* obj_data, uint* p_count) {
    LLVMSectionIteratorRef sec_itr = void;
    char* name = void;
    uint count = 0;

    if (((sec_itr = LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
        aot_set_last_error("llvm get section iterator failed.");
        return false;
    }
    while (!LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary, sec_itr)) {
        if ((name = cast(char*)LLVMGetSectionName(sec_itr))
            && (is_data_section(sec_itr, name))) {
            count++;
        }
        LLVMMoveToNextSection(sec_itr);
    }
    LLVMDisposeSectionIterator(sec_itr);

    *p_count = count;
    return true;
}

private bool aot_resolve_object_data_sections(AOTObjectData* obj_data) {
    LLVMSectionIteratorRef sec_itr = void;
    char* name = void;
    AOTObjectDataSection* data_section = void;
    uint sections_count = void;
    uint size = void;

    if (!get_object_data_sections_count(obj_data, &sections_count)) {
        return false;
    }

    if (sections_count > 0) {
        size = cast(uint)sizeof(AOTObjectDataSection) * sections_count;
        if (((data_section = obj_data.data_sections =
                  wasm_runtime_malloc(size)) == 0)) {
            aot_set_last_error("allocate memory for data sections failed.");
            return false;
        }
        memset(obj_data.data_sections, 0, size);
        obj_data.data_sections_count = sections_count;

        if (((sec_itr = LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
            aot_set_last_error("llvm get section iterator failed.");
            return false;
        }
        while (
            !LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary, sec_itr)) {
            if ((name = cast(char*)LLVMGetSectionName(sec_itr))
                && (is_data_section(sec_itr, name))) {
                data_section.name = name;
                data_section.data = cast(ubyte*)LLVMGetSectionContents(sec_itr);
                data_section.size = cast(uint)LLVMGetSectionSize(sec_itr);
                data_section++;
            }
            LLVMMoveToNextSection(sec_itr);
        }
        LLVMDisposeSectionIterator(sec_itr);
    }

    return true;
}

private bool aot_resolve_functions(AOTCompContext* comp_ctx, AOTObjectData* obj_data) {
    AOTObjectFunc* func = void;
    LLVMSymbolIteratorRef sym_itr = void;
    char* name = void, prefix = AOT_FUNC_PREFIX;
    uint func_index = void, total_size = void;

    /* allocate memory for aot function */
    obj_data.func_count = comp_ctx.comp_data.func_count;
    if (obj_data.func_count) {
        total_size = cast(uint)sizeof(AOTObjectFunc) * obj_data.func_count;
        if (((obj_data.funcs = wasm_runtime_malloc(total_size)) == 0)) {
            aot_set_last_error("allocate memory for functions failed.");
            return false;
        }
        memset(obj_data.funcs, 0, total_size);
    }

    if (((sym_itr = LLVMObjectFileCopySymbolIterator(obj_data.binary)) == 0)) {
        aot_set_last_error("llvm get symbol iterator failed.");
        return false;
    }

    while (!LLVMObjectFileIsSymbolIteratorAtEnd(obj_data.binary, sym_itr)) {
        if ((name = cast(char*)LLVMGetSymbolName(sym_itr))
            && str_starts_with(name, prefix)) {
            func_index = cast(uint)atoi(name + strlen(prefix));
            if (func_index < obj_data.func_count) {
                func = obj_data.funcs + func_index;
                func.func_name = name;
                func.text_offset = LLVMGetSymbolAddress(sym_itr);
            }
        }
        LLVMMoveToNextSymbol(sym_itr);
    }
    LLVMDisposeSymbolIterator(sym_itr);

    return true;
}

private bool get_relocations_count(LLVMSectionIteratorRef sec_itr, uint* p_count) {
    uint relocation_count = 0;
    LLVMRelocationIteratorRef rel_itr = void;

    if (((rel_itr = LLVMGetRelocations(sec_itr)) == 0)) {
        aot_set_last_error("llvm get relocations failed.");
        LLVMDisposeSectionIterator(sec_itr);
        return false;
    }

    while (!LLVMIsRelocationIteratorAtEnd(sec_itr, rel_itr)) {
        relocation_count++;
        LLVMMoveToNextRelocation(rel_itr);
    }
    LLVMDisposeRelocationIterator(rel_itr);

    *p_count = relocation_count;
    return true;
}

private bool aot_resolve_object_relocation_group(AOTObjectData* obj_data, AOTRelocationGroup* group, LLVMSectionIteratorRef rel_sec) {
    LLVMRelocationIteratorRef rel_itr = void;
    AOTRelocation* relocation = group.relocations;
    uint size = void;
    bool is_binary_32bit = is_32bit_binary(obj_data);
    bool is_binary_little_endian = is_little_endian_binary(obj_data);
    bool has_addend = str_starts_with(group.section_name, ".rela");
    ubyte* rela_content = null;

    /* calculate relocations count and allocate memory */
    if (!get_relocations_count(rel_sec, &group.relocation_count))
        return false;
    if (group.relocation_count == 0) {
        aot_set_last_error("invalid relocations count");
        return false;
    }
    size = cast(uint)sizeof(AOTRelocation) * group.relocation_count;
    if (((relocation = group.relocations = wasm_runtime_malloc(size)) == 0)) {
        aot_set_last_error("allocate memory for relocations failed.");
        return false;
    }
    memset(group.relocations, 0, size);

    if (has_addend) {
        ulong rela_content_size = void;
        /* LLVM doesn't provide C API to get relocation addend. So we have to
         * parse it manually. */
        rela_content = cast(ubyte*)LLVMGetSectionContents(rel_sec);
        rela_content_size = LLVMGetSectionSize(rel_sec);
        if (is_binary_32bit)
            size = cast(uint)elf32_rela.sizeof * group.relocation_count;
        else
            size = cast(uint)elf64_rela.sizeof * group.relocation_count;
        if (rela_content_size != cast(ulong)size) {
            aot_set_last_error("invalid relocation section content.");
            return false;
        }
    }

    /* pares each relocation */
    if (((rel_itr = LLVMGetRelocations(rel_sec)) == 0)) {
        aot_set_last_error("llvm get relocations failed.");
        return false;
    }
    while (!LLVMIsRelocationIteratorAtEnd(rel_sec, rel_itr)) {
        ulong offset = LLVMGetRelocationOffset(rel_itr);
        ulong type = LLVMGetRelocationType(rel_itr);
        LLVMSymbolIteratorRef rel_sym = LLVMGetRelocationSymbol(rel_itr);

        if (!rel_sym) {
            aot_set_last_error("llvm get relocation symbol failed.");
            goto fail;
        }

        /* parse relocation addend from reloction content */
        if (has_addend) {
            if (is_binary_32bit) {
                int addend = (int32)((cast(elf32_rela*)rela_content).r_addend);
                if (is_binary_little_endian != is_little_endian())
                    exchange_uint32(cast(ubyte*)&addend);
                relocation.relocation_addend = cast(long)addend;
                rela_content += elf32_rela.sizeof;
            }
            else {
                long addend = (int64)((cast(elf64_rela*)rela_content).r_addend);
                if (is_binary_little_endian != is_little_endian())
                    exchange_uint64(cast(ubyte*)&addend);
                relocation.relocation_addend = addend;
                rela_content += elf64_rela.sizeof;
            }
        }

        /* set relocation fields */
        relocation.relocation_offset = offset;
        relocation.relocation_type = cast(uint)type;
        relocation.symbol_name = cast(char*)LLVMGetSymbolName(rel_sym);

        /* for ".LCPIxxx", ".LJTIxxx", ".LBBxxx" and switch lookup table
         * relocation, transform the symbol name to real section name and set
         * addend to the offset of the symbol in the real section */
        if (relocation.symbol_name
            && (str_starts_with(relocation.symbol_name, ".LCPI")
                || str_starts_with(relocation.symbol_name, ".LJTI")
                || str_starts_with(relocation.symbol_name, ".LBB")
                || str_starts_with(relocation.symbol_name,
                                   ".Lswitch.table."))) {
            /* change relocation->relocation_addend and
               relocation->symbol_name */
            LLVMSectionIteratorRef contain_section = void;
            if (((contain_section =
                      LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
                aot_set_last_error("llvm get section iterator failed.");
                goto fail;
            }
            LLVMMoveToContainingSection(contain_section, rel_sym);
            if (LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary,
                                                     contain_section)) {
                LLVMDisposeSectionIterator(contain_section);
                aot_set_last_error("llvm get containing section failed.");
                goto fail;
            }
            relocation.relocation_addend += LLVMGetSymbolAddress(rel_sym);
            relocation.symbol_name =
                cast(char*)LLVMGetSectionName(contain_section);
            LLVMDisposeSectionIterator(contain_section);
        }

        LLVMDisposeSymbolIterator(rel_sym);
        LLVMMoveToNextRelocation(rel_itr);
        relocation++;
    }
    LLVMDisposeRelocationIterator(rel_itr);
    return true;

fail:
    LLVMDisposeRelocationIterator(rel_itr);
    return false;
}

private bool is_relocation_section_name(char* section_name) {
    return (!strcmp(section_name, ".rela.text")
            || !strcmp(section_name, ".rel.text")
            || !strcmp(section_name, ".rela.literal")
            || !strcmp(section_name, ".rela.data")
            || !strcmp(section_name, ".rel.data")
            || !strcmp(section_name, ".rela.sdata")
            || !strcmp(section_name, ".rel.sdata")
            || !strcmp(section_name, ".rela.rodata")
            || !strcmp(section_name, ".rel.rodata")
            /* ".rela.rodata.cst4/8/16/.." */
            || !strncmp(section_name, ".rela.rodata.cst",
                        strlen(".rela.rodata.cst"))
            /* ".rel.rodata.cst4/8/16/.." */
            || !strncmp(section_name, ".rel.rodata.cst",
                        strlen(".rel.rodata.cst")));
}

private bool is_relocation_section(LLVMSectionIteratorRef sec_itr) {
    uint count = 0;
    char* name = cast(char*)LLVMGetSectionName(sec_itr);
    if (name) {
        if (is_relocation_section_name(name))
            return true;
        else if ((!strcmp(name, ".text") || !strcmp(name, ".rdata"))
                 && get_relocations_count(sec_itr, &count) && count > 0)
            return true;
    }
    return false;
}

private bool get_relocation_groups_count(AOTObjectData* obj_data, uint* p_count) {
    uint count = 0;
    LLVMSectionIteratorRef sec_itr = void;

    if (((sec_itr = LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
        aot_set_last_error("llvm get section iterator failed.");
        return false;
    }
    while (!LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary, sec_itr)) {
        if (is_relocation_section(sec_itr)) {
            count++;
        }
        LLVMMoveToNextSection(sec_itr);
    }
    LLVMDisposeSectionIterator(sec_itr);

    *p_count = count;
    return true;
}

private bool aot_resolve_object_relocation_groups(AOTObjectData* obj_data) {
    LLVMSectionIteratorRef sec_itr = void;
    AOTRelocationGroup* relocation_group = void;
    uint group_count = void;
    char* name = void;
    uint size = void;

    /* calculate relocation groups count and allocate memory */
    if (!get_relocation_groups_count(obj_data, &group_count))
        return false;

    if (0 == (obj_data.relocation_group_count = group_count))
        return true;

    size = cast(uint)sizeof(AOTRelocationGroup) * group_count;
    if (((relocation_group = obj_data.relocation_groups =
              wasm_runtime_malloc(size)) == 0)) {
        aot_set_last_error("allocate memory for relocation groups failed.");
        return false;
    }

    memset(obj_data.relocation_groups, 0, size);

    /* resolve each relocation group */
    if (((sec_itr = LLVMObjectFileCopySectionIterator(obj_data.binary)) == 0)) {
        aot_set_last_error("llvm get section iterator failed.");
        return false;
    }
    while (!LLVMObjectFileIsSectionIteratorAtEnd(obj_data.binary, sec_itr)) {
        if (is_relocation_section(sec_itr)) {
            name = cast(char*)LLVMGetSectionName(sec_itr);
            relocation_group.section_name = name;
            if (!aot_resolve_object_relocation_group(obj_data, relocation_group,
                                                     sec_itr)) {
                LLVMDisposeSectionIterator(sec_itr);
                return false;
            }
            relocation_group++;
        }
        LLVMMoveToNextSection(sec_itr);
    }
    LLVMDisposeSectionIterator(sec_itr);

    return true;
}

private void destroy_relocation_groups(AOTRelocationGroup* relocation_groups, uint relocation_group_count) {
    uint i = void;
    AOTRelocationGroup* relocation_group = relocation_groups;

    for (i = 0; i < relocation_group_count; i++, relocation_group++)
        if (relocation_group.relocations)
            wasm_runtime_free(relocation_group.relocations);
    wasm_runtime_free(relocation_groups);
}

private void destroy_relocation_symbol_list(AOTSymbolList* symbol_list) {
    AOTSymbolNode* elem = void;

    elem = symbol_list.head;
    while (elem) {
        AOTSymbolNode* next = elem.next;
        wasm_runtime_free(elem);
        elem = next;
    }
}

private void aot_obj_data_destroy(AOTObjectData* obj_data) {
    if (obj_data.binary)
        LLVMDisposeBinary(obj_data.binary);
    if (obj_data.mem_buf)
        LLVMDisposeMemoryBuffer(obj_data.mem_buf);
    if (obj_data.funcs)
        wasm_runtime_free(obj_data.funcs);
    if (obj_data.data_sections)
        wasm_runtime_free(obj_data.data_sections);
    if (obj_data.relocation_groups)
        destroy_relocation_groups(obj_data.relocation_groups,
                                  obj_data.relocation_group_count);
    if (obj_data.symbol_list.len)
        destroy_relocation_symbol_list(&obj_data.symbol_list);
    wasm_runtime_free(obj_data);
}

private AOTObjectData* aot_obj_data_create(AOTCompContext* comp_ctx) {
    char* err = null;
    AOTObjectData* obj_data = void;
    LLVMTargetRef target = LLVMGetTargetMachineTarget(comp_ctx.target_machine);

    bh_print_time("Begin to emit object file to buffer");

    if (((obj_data = wasm_runtime_malloc(AOTObjectData.sizeof)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        return false;
    }
    memset(obj_data, 0, AOTObjectData.sizeof);

    bh_print_time("Begin to emit object file");
    if (comp_ctx.external_llc_compiler || comp_ctx.external_asm_compiler) {
static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
        aot_set_last_error("external toolchain not supported on Windows");
        goto fail;
} else {
        /* Generate a temp file name */
        int ret = void;
        char[64] obj_file_name = void;

        if (!aot_generate_tempfile_name("wamrc-obj", "o", obj_file_name.ptr,
                                        obj_file_name.sizeof)) {
            goto fail;
        }

        if (!aot_emit_object_file(comp_ctx, obj_file_name.ptr)) {
            goto fail;
        }

        /* create memory buffer from object file */
        ret = LLVMCreateMemoryBufferWithContentsOfFile(
            obj_file_name.ptr, &obj_data.mem_buf, &err);
        /* remove temp object file */
        unlink(obj_file_name.ptr);

        if (ret != 0) {
            if (err) {
                LLVMDisposeMessage(err);
                err = null;
            }
            aot_set_last_error("create mem buffer with file failed.");
            goto fail;
        }
} /* end of defined(_WIN32) || defined(_WIN32_) */
    }
    else if (!strncmp(LLVMGetTargetName(target), "arc", 3)) {
static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
        aot_set_last_error("emit object file on Windows is unsupported.");
        goto fail;
} else {
        /* Emit to assmelby file instead for arc target
           as it cannot emit to object file */
        char* file_name = "wasm-XXXXXX"; char[128] buf = void;
        int fd = void, ret = void;

        if ((fd = mkstemp(file_name)) <= 0) {
            aot_set_last_error("make temp file failed.");
            goto fail;
        }

        /* close and remove temp file */
        close(fd);
        unlink(file_name);

        snprintf(buf.ptr, buf.sizeof, "%s%s", file_name, ".s");
        if (LLVMTargetMachineEmitToFile(comp_ctx.target_machine,
                                        comp_ctx.module_, buf.ptr, LLVMAssemblyFile,
                                        &err)
            != 0) {
            if (err) {
                LLVMDisposeMessage(err);
                err = null;
            }
            aot_set_last_error("emit elf to object file failed.");
            goto fail;
        }

        /* call arc gcc to compile assembly file to object file */
        /* TODO: get arc gcc from environment variable firstly
                 and check whether the toolchain exists actually */
        snprintf(buf.ptr, buf.sizeof, "%s%s%s%s%s%s",
                 "/opt/zephyr-sdk/arc-zephyr-elf/bin/arc-zephyr-elf-gcc ",
                 "-mcpu=arcem -o ", file_name, ".o -c ", file_name, ".s");
        /* TODO: use try..catch to handle possible exceptions */
        ret = system(buf.ptr);
        /* remove temp assembly file */
        snprintf(buf.ptr, buf.sizeof, "%s%s", file_name, ".s");
        unlink(buf.ptr);

        if (ret != 0) {
            aot_set_last_error("failed to compile asm file to obj file "
                               ~ "with arc gcc toolchain.");
            goto fail;
        }

        /* create memory buffer from object file */
        snprintf(buf.ptr, buf.sizeof, "%s%s", file_name, ".o");
        ret = LLVMCreateMemoryBufferWithContentsOfFile(buf.ptr, &obj_data.mem_buf,
                                                       &err);
        /* remove temp object file */
        snprintf(buf.ptr, buf.sizeof, "%s%s", file_name, ".o");
        unlink(buf.ptr);

        if (ret != 0) {
            if (err) {
                LLVMDisposeMessage(err);
                err = null;
            }
            aot_set_last_error("create mem buffer with file failed.");
            goto fail;
        }
} /* end of defined(_WIN32) || defined(_WIN32_) */
    }
    else {
        if (LLVMTargetMachineEmitToMemoryBuffer(
                comp_ctx.target_machine, comp_ctx.module_, LLVMObjectFile,
                &err, &obj_data.mem_buf)
            != 0) {
            if (err) {
                LLVMDisposeMessage(err);
                err = null;
            }
            aot_set_last_error("llvm emit to memory buffer failed.");
            goto fail;
        }
    }

    if (((obj_data.binary = LLVMCreateBinary(obj_data.mem_buf, null, &err)) == 0)) {
        if (err) {
            LLVMDisposeMessage(err);
            err = null;
        }
        aot_set_last_error("llvm create binary failed.");
        goto fail;
    }

    bh_print_time("Begin to resolve object file info");

    /* resolve target info/text/relocations/functions */
    if (!aot_resolve_target_info(comp_ctx, obj_data)
        || !aot_resolve_text(obj_data) || !aot_resolve_literal(obj_data)
        || !aot_resolve_object_data_sections(obj_data)
        || !aot_resolve_object_relocation_groups(obj_data)
        || !aot_resolve_functions(comp_ctx, obj_data))
        goto fail;

    return obj_data;

fail:
    aot_obj_data_destroy(obj_data);
    return null;
}

ubyte* aot_emit_aot_file_buf(AOTCompContext* comp_ctx, AOTCompData* comp_data, uint* p_aot_file_size) {
    AOTObjectData* obj_data = aot_obj_data_create(comp_ctx);
    ubyte* aot_file_buf = void, buf = void, buf_end = void;
    uint aot_file_size = void, offset = 0;

    if (!obj_data)
        return null;

    aot_file_size = get_aot_file_size(comp_ctx, comp_data, obj_data);

    if (((buf = aot_file_buf = wasm_runtime_malloc(aot_file_size)) == 0)) {
        aot_set_last_error("allocate memory failed.");
        goto fail1;
    }

    memset(aot_file_buf, 0, aot_file_size);
    buf_end = buf + aot_file_size;

    if (!aot_emit_file_header(buf, buf_end, &offset, comp_data, obj_data)
        || !aot_emit_target_info_section(buf, buf_end, &offset, comp_data,
                                         obj_data)
        || !aot_emit_init_data_section(buf, buf_end, &offset, comp_ctx,
                                       comp_data, obj_data)
        || !aot_emit_text_section(buf, buf_end, &offset, comp_data, obj_data)
        || !aot_emit_func_section(buf, buf_end, &offset, comp_data, obj_data)
        || !aot_emit_export_section(buf, buf_end, &offset, comp_ctx, comp_data,
                                    obj_data)
        || !aot_emit_relocation_section(buf, buf_end, &offset, comp_ctx,
                                        comp_data, obj_data)
        || !aot_emit_native_symbol(buf, buf_end, &offset, comp_ctx)
        || !aot_emit_name_section(buf, buf_end, &offset, comp_data, comp_ctx)
        || !aot_emit_custom_sections(buf, buf_end, &offset, comp_data,
                                     comp_ctx))
        goto fail2;

version (none) {
    dump_buf(buf, offset, "sections");
}

    if (offset != aot_file_size) {
        aot_set_last_error("emit aot file failed.");
        goto fail2;
    }

    *p_aot_file_size = aot_file_size;

    aot_obj_data_destroy(obj_data);
    return aot_file_buf;

fail2:
    wasm_runtime_free(aot_file_buf);

fail1:
    aot_obj_data_destroy(obj_data);
    return null;
}

bool aot_emit_aot_file(AOTCompContext* comp_ctx, AOTCompData* comp_data, const(char)* file_name) {
    ubyte* aot_file_buf = void;
    uint aot_file_size = void;
    bool ret = false;
    FILE* file = void;

    bh_print_time("Begin to emit AOT file");

    if (((aot_file_buf =
              aot_emit_aot_file_buf(comp_ctx, comp_data, &aot_file_size)) == 0)) {
        return false;
    }

    /* write buffer to file */
    if (((file = fopen(file_name, "wb")) == 0)) {
        aot_set_last_error("open or create aot file failed.");
        goto fail1;
    }
    if (!fwrite(aot_file_buf, aot_file_size, 1, file)) {
        aot_set_last_error("write to aot file failed.");
        goto fail2;
    }

    ret = true;

fail2:
    fclose(file);

fail1:
    wasm_runtime_free(aot_file_buf);

    return ret;
}
