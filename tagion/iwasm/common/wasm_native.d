module tagion.iwasm.common.wasm_native;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import tagion.iwasm.common.wasm_runtime_common;
public import tagion.iwasm.share.utils.bh_log;

static if (!HasVersion!"BH_PLATFORM_ZEPHYR" && !HasVersion!"BH_PLATFORM_ALIOS_THINGS" 
    && !HasVersion!"BH_PLATFORM_OPENRTOS" && !HasVersion!"BH_PLATFORM_ESP_IDF") {
enum ENABLE_QUICKSORT = 1;
} 
else {
enum ENABLE_QUICKSORT = 0;
}

enum ENABLE_SORT_DEBUG = 0;

static if (ENABLE_SORT_DEBUG != 0) {
public import core.sys.posix.sys.time;
}

private NativeSymbolsList g_native_symbols_list = null;

uint get_libc_builtin_export_apis(NativeSymbol** p_libc_builtin_apis);

static if (WASM_ENABLE_SPEC_TEST != 0) {
uint get_spectest_export_apis(NativeSymbol** p_libc_builtin_apis);
}

uint get_libc_wasi_export_apis(NativeSymbol** p_libc_wasi_apis);

uint get_wasi_nn_export_apis(NativeSymbol** p_libc_wasi_apis);

uint get_base_lib_export_apis(NativeSymbol** p_base_lib_apis);

uint get_ext_lib_export_apis(NativeSymbol** p_ext_lib_apis);

static if (WASM_ENABLE_LIB_PTHREAD != 0) {
bool lib_pthread_init();

void lib_pthread_destroy();

uint get_lib_pthread_export_apis(NativeSymbol** p_lib_pthread_apis);
}

uint get_libc_emcc_export_apis(NativeSymbol** p_libc_emcc_apis);

uint get_lib_rats_export_apis(NativeSymbol** p_lib_rats_apis);

private bool compare_type_with_signautre(ubyte type, const(char) signature) {
    const(char)[4] num_sig_map = [ 'F', 'f', 'I', 'i' ];

    if (VALUE_TYPE_F64 <= type && type <= VALUE_TYPE_I32
        && signature == num_sig_map[type - VALUE_TYPE_F64]) {
        return true;
    }

static if (WASM_ENABLE_REF_TYPES != 0) {
    if ('r' == signature && type == VALUE_TYPE_EXTERNREF)
        return true;
}

    /* TODO: a v128 parameter */
    return false;
}

private bool check_symbol_signature(const(WASMType)* type, const(char)* signature) {
    const(char)* p = signature, p_end = void;
    char sig = void;
    uint i = 0;

    if (!p || strlen(p) < 2)
        return false;

    p_end = p + strlen(signature);

    if (*p++ != '(')
        return false;

    if (cast(uint)(p_end - p) < cast(uint)(type.param_count + 1))
        /* signatures of parameters, and ')' */
        return false;

    for (i = 0; i < type.param_count; i++) {
        sig = *p++;

        /* a f64/f32/i64/i32/externref parameter */
        if (compare_type_with_signautre(type.types[i], sig))
            continue;

        /* a pointer/string paramter */
        if (type.types[i] != VALUE_TYPE_I32)
            /* pointer and string must be i32 type */
            return false;

        if (sig == '*') {
            /* it is a pointer */
            if (i + 1 < type.param_count
                && type.types[i + 1] == VALUE_TYPE_I32 && *p == '~') {
                /* pointer length followed */
                i++;
                p++;
            }
        }
        else if (sig == '$') {
            /* it is a string */
        }
        else {
            /* invalid signature */
            return false;
        }
    }

    if (*p++ != ')')
        return false;

    if (type.result_count) {
        if (p >= p_end)
            return false;

        /* result types includes: f64,f32,i64,i32,externref */
        if (!compare_type_with_signautre(type.types[i], *p))
            return false;

        p++;
    }

    if (*p != '\0')
        return false;

    return true;
}

static if (ENABLE_QUICKSORT == 0) {
private void sort_symbol_ptr(NativeSymbol* native_symbols, uint n_native_symbols) {
    uint i = void, j = void;
    NativeSymbol temp = void;

    for (i = 0; i < n_native_symbols - 1; i++) {
        for (j = i + 1; j < n_native_symbols; j++) {
            if (strcmp(native_symbols[i].symbol, native_symbols[j].symbol)
                > 0) {
                temp = native_symbols[i];
                native_symbols[i] = native_symbols[j];
                native_symbols[j] = temp;
            }
        }
    }
}
} else {
private void swap_symbol(NativeSymbol* left, NativeSymbol* right) {
    NativeSymbol temp = *left;
    *left = *right;
    *right = temp;
}

private void quick_sort_symbols(NativeSymbol* native_symbols, int left, int right) {
    NativeSymbol base_symbol = void;
    int pin_left = left;
    int pin_right = right;

    if (left >= right) {
        return;
    }

    base_symbol = native_symbols[left];
    while (left < right) {
        while (left < right
               && strcmp(native_symbols[right].symbol, base_symbol.symbol)
                      > 0) {
            right--;
        }

        if (left < right) {
            swap_symbol(&native_symbols[left], &native_symbols[right]);
            left++;
        }

        while (left < right
               && strcmp(native_symbols[left].symbol, base_symbol.symbol) < 0) {
            left++;
        }

        if (left < right) {
            swap_symbol(&native_symbols[left], &native_symbols[right]);
            right--;
        }
    }
    native_symbols[left] = base_symbol;

    quick_sort_symbols(native_symbols, pin_left, left - 1);
    quick_sort_symbols(native_symbols, left + 1, pin_right);
}
} /* end of ENABLE_QUICKSORT */

private void* lookup_symbol(NativeSymbol* native_symbols, uint n_native_symbols, const(char)* symbol, const(char)** p_signature, void** p_attachment) {
    int low = 0, mid = void, ret = void;
    int high = cast(int)n_native_symbols - 1;

    while (low <= high) {
        mid = (low + high) / 2;
        ret = strcmp(symbol, native_symbols[mid].symbol);
        if (ret == 0) {
            *p_signature = native_symbols[mid].signature;
            *p_attachment = native_symbols[mid].attachment;
            return native_symbols[mid].func_ptr;
        }
        else if (ret < 0)
            high = mid - 1;
        else
            low = mid + 1;
    }

    return null;
}

void* wasm_native_resolve_symbol(const(char)* module_name, const(char)* field_name, const(WASMType)* func_type, const(char)** p_signature, void** p_attachment, bool* p_call_conv_raw) {
    NativeSymbolsNode* node = void, node_next = void;
    const(char)* signature = null;
    void* func_ptr = null, attachment = void;

    node = g_native_symbols_list;
    while (node) {
        node_next = node.next;
        if (!strcmp(node.module_name, module_name)) {
            if ((func_ptr =
                     lookup_symbol(node.native_symbols, node.n_native_symbols,
                                   field_name, &signature, &attachment))
                || (field_name[0] == '_'
                    && (func_ptr = lookup_symbol(
                            node.native_symbols, node.n_native_symbols,
                            field_name + 1, &signature, &attachment))))
                break;
        }
        node = node_next;
    }

    if (func_ptr) {
        if (signature && signature[0] != '\0') {
            /* signature is not empty, check its format */
            if (!check_symbol_signature(func_type, signature)) {
static if (WASM_ENABLE_WAMR_COMPILER == 0) {
                /* Output warning except running aot compiler */
                LOG_WARNING("failed to check signature '%s' and resolve "
                            ~ "pointer params for import function (%s %s)\n",
                            signature, module_name, field_name);
}
                return null;
            }
            else
                /* Save signature for runtime to do pointer check and
                   address conversion */
                *p_signature = signature;
        }
        else
            /* signature is empty */
            *p_signature = null;

        *p_attachment = attachment;
        *p_call_conv_raw = node.call_conv_raw;
    }

    return func_ptr;
}

private bool register_natives(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols, bool call_conv_raw) {
    NativeSymbolsNode* node = void;
static if (ENABLE_SORT_DEBUG != 0) {
    timeval start = void;
    timeval end = void;
    c_ulong timer = void;
}

    if (((node = wasm_runtime_malloc(NativeSymbolsNode.sizeof)) == 0))
        return false;
static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    os_printf("Register native, size: %u\n", NativeSymbolsNode.sizeof);
}

    node.module_name = module_name;
    node.native_symbols = native_symbols;
    node.n_native_symbols = n_native_symbols;
    node.call_conv_raw = call_conv_raw;

    /* Add to list head */
    node.next = g_native_symbols_list;
    g_native_symbols_list = node;

static if (ENABLE_SORT_DEBUG != 0) {
    gettimeofday(&start, null);
}

static if (ENABLE_QUICKSORT == 0) {
    sort_symbol_ptr(native_symbols, n_native_symbols);
} else {
    quick_sort_symbols(native_symbols, 0, cast(int)(n_native_symbols - 1));
}

static if (ENABLE_SORT_DEBUG != 0) {
    gettimeofday(&end, null);
    timer =
        1000000 * (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec);
    LOG_ERROR("module_name: %s, nums: %d, sorted used: %ld us", module_name,
              n_native_symbols, timer);
}
    return true;
}

bool wasm_native_register_natives(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols) {
    return register_natives(module_name, native_symbols, n_native_symbols,
                            false);
}

bool wasm_native_register_natives_raw(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols) {
    return register_natives(module_name, native_symbols, n_native_symbols,
                            true);
}

bool wasm_native_unregister_natives(const(char)* module_name, NativeSymbol* native_symbols) {
    NativeSymbolsNode** prevp = void;
    NativeSymbolsNode* node = void;

    prevp = &g_native_symbols_list;
    while ((node = *prevp) != null) {
        if (node.native_symbols == native_symbols
            && !strcmp(node.module_name, module_name)) {
            *prevp = node.next;
            wasm_runtime_free(node);
            return true;
        }
        prevp = &node.next;
    }
    return false;
}

bool wasm_native_init() {
static if (WASM_ENABLE_SPEC_TEST != 0 || WASM_ENABLE_LIBC_BUILTIN != 0     
    || WASM_ENABLE_BASE_LIB != 0 || WASM_ENABLE_LIBC_EMCC != 0      
    || WASM_ENABLE_LIB_RATS != 0 || WASM_ENABLE_WASI_NN != 0        
    || WASM_ENABLE_APP_FRAMEWORK != 0 || WASM_ENABLE_LIBC_WASI != 0 
    || WASM_ENABLE_LIB_PTHREAD != 0) {
    NativeSymbol* native_symbols = void;
    uint n_native_symbols = void;
}

static if (WASM_ENABLE_LIBC_BUILTIN != 0) {
    n_native_symbols = get_libc_builtin_export_apis(&native_symbols);
    if (!wasm_native_register_natives("env", native_symbols, n_native_symbols))
        goto fail;
} /* WASM_ENABLE_LIBC_BUILTIN */

static if (WASM_ENABLE_SPEC_TEST) {
    n_native_symbols = get_spectest_export_apis(&native_symbols);
    if (!wasm_native_register_natives("spectest", native_symbols,
                                      n_native_symbols))
        goto fail;
} /* WASM_ENABLE_SPEC_TEST */

static if (WASM_ENABLE_LIBC_WASI != 0) {
    n_native_symbols = get_libc_wasi_export_apis(&native_symbols);
    if (!wasm_native_register_natives("wasi_unstable", native_symbols,
                                      n_native_symbols))
        goto fail;
    if (!wasm_native_register_natives("wasi_snapshot_preview1", native_symbols,
                                      n_native_symbols))
        goto fail;
}

static if (WASM_ENABLE_BASE_LIB != 0) {
    n_native_symbols = get_base_lib_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
}

static if (WASM_ENABLE_APP_FRAMEWORK != 0) {
    n_native_symbols = get_ext_lib_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
}

static if (WASM_ENABLE_LIB_PTHREAD != 0) {
    if (!lib_pthread_init())
        goto fail;

    n_native_symbols = get_lib_pthread_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
}

static if (WASM_ENABLE_LIBC_EMCC != 0) {
    n_native_symbols = get_libc_emcc_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
} /* WASM_ENABLE_LIBC_EMCC */

static if (WASM_ENABLE_LIB_RATS != 0) {
    n_native_symbols = get_lib_rats_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
} /* WASM_ENABLE_LIB_RATS */

static if (WASM_ENABLE_WASI_NN != 0) {
    n_native_symbols = get_wasi_nn_export_apis(&native_symbols);
    if (!wasm_native_register_natives("wasi_nn", native_symbols,
                                      n_native_symbols))
        return false;
}

    return true;
static if (WASM_ENABLE_SPEC_TEST != 0 || WASM_ENABLE_LIBC_BUILTIN != 0     
    || WASM_ENABLE_BASE_LIB != 0 || WASM_ENABLE_LIBC_EMCC != 0      
    || WASM_ENABLE_LIB_RATS != 0 || WASM_ENABLE_WASI_NN != 0        
    || WASM_ENABLE_APP_FRAMEWORK != 0 || WASM_ENABLE_LIBC_WASI != 0 
    || WASM_ENABLE_LIB_PTHREAD != 0) {
fail:
    wasm_native_destroy();
    return false;
}
}

void wasm_native_destroy() {
    NativeSymbolsNode* node = void, node_next = void;

static if (WASM_ENABLE_LIB_PTHREAD != 0) {
    lib_pthread_destroy();
}

    node = g_native_symbols_list;
    while (node) {
        node_next = node.next;
        wasm_runtime_free(node);
        node = node_next;
    }

    g_native_symbols_list = null;
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import tagion.iwasm.share.utils.bh_common;
public import tagion.iwasm.include.wasm_export;
public import tagion.iwasm.interpreter.wasm;


struct NativeSymbolsNode {
    NativeSymbolsNode* next;
    const(char)* module_name;
    NativeSymbol* native_symbols;
    uint n_native_symbols;
    bool call_conv_raw;
}alias NativeSymbolsList = NativeSymbolsNode*;

/**
 * Lookup global variable of a given import global
 * from libc builtin globals
 *
 * @param module_name the module name of the import global
 * @param global_name the global name of the import global
 * @param global return the global data
 *
 * @param true if success, false otherwise
 */
bool wasm_native_lookup_libc_builtin_global(const(char)* module_name, const(char)* global_name, WASMGlobalImport* global);

/**
 * Resolve native symbol in all libraries, including libc-builtin, libc-wasi,
 * base lib and extension lib, and user registered natives
 * function, which can be auto checked by vm before calling native function
 *
 * @param module_name the module name of the import function
 * @param func_name the function name of the import function
 * @param func_type the function prototype of the import function
 * @param p_signature output the signature if resolve success
 *
 * @return the native function pointer if success, NULL otherwise
 */
void* wasm_native_resolve_symbol(const(char)* module_name, const(char)* field_name, const(WASMType)* func_type, const(char)** p_signature, void** p_attachment, bool* p_call_conv_raw);

bool wasm_native_register_natives(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols);

bool wasm_native_register_natives_raw(const(char)* module_name, NativeSymbol* native_symbols, uint n_native_symbols);

bool wasm_native_unregister_natives(const(char)* module_name, NativeSymbol* native_symbols);

bool wasm_native_init();

void wasm_native_destroy();


