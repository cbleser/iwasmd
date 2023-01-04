module tagion.wasm.common.wasm_c_api_internal;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import tagion.iwasm.include.wasm_c_api;
public import tagion.iwasm.common.wasm_runtime_common;
import tagion.iwasm.share.utils.bh_vector;
 


/* Vectors */
/* we will malloc resource for the vector's data field */
/* we will release resource of data */
/* caller needs to take care resource for the vector itself */
enum DEFAULT_VECTOR_INIT_LENGTH = (64);

//WASM_DECLARE_VEC(instance, *)
//WASM_DECLARE_VEC(module_, *)
//WASM_DECLARE_VEC(store, *)

/* Runtime Environment */
struct wasm_engine_t {
    uint32 ref_count;
    /* list of wasm_module_ex_t */
    Vector modules;
    /* list of stores which are classified according to tids */
    Vector stores_by_tid;
};

import tagion.iwasm.common.wasm_c_api : WASM_DECLARE_VEC;
alias Module=void; /// Dummy type for now
alias wasm_module_vec_t = WASM_DECLARE_VEC!(Module);

alias Instance=void; /// Dummy type for now
alias wasm_instance_vec_t = WASM_DECLARE_VEC!(Instance);

struct wasm_store_t {
    /* maybe should remove the list */
    wasm_module_vec_t *modules;
    wasm_instance_vec_t *instances;
    Vector *foreigns;
};

/* Type Representations */
struct wasm_valtype_t {
    wasm_valkind_t kind;
};

struct wasm_functype_t {
    uint32 extern_kind;
    /* gona to new and delete own */
    wasm_valtype_vec_t *params;
    wasm_valtype_vec_t *results;
};

struct wasm_globaltype_t {
    uint32 extern_kind;
    /* gona to new and delete own */
    wasm_valtype_t *val_type;
    wasm_mutability_t mutability;
};

struct wasm_tabletype_t {
    uint32 extern_kind;
    wasm_valtype_t *val_type;
    wasm_limits_t limits;
};

struct wasm_memorytype_t {
    uint32 extern_kind;
    wasm_limits_t limits;
};

struct wasm_externtype_t {
    uint32 extern_kind;
    /* reservered space */
    uint8[1] data;
};

struct wasm_importtype_t {
    wasm_name_t *module_name;
    wasm_name_t *name;
    wasm_externtype_t *extern_type;
};

struct wasm_exporttype_t {
    wasm_name_t *name;
    wasm_externtype_t *extern_type;
};

/* Runtime Objects */
enum wasm_reference_kind {
    WASM_REF_foreign,
    WASM_REF_func,
    WASM_REF_global,
    WASM_REF_memory,
    WASM_REF_table,
};

struct wasm_host_info {
    void *info;
    void function(void *)finalizer;
};

struct wasm_ref_t {
    wasm_store_t *store;
    wasm_reference_kind kind;
    wasm_host_info host_info;
    uint32 ref_idx_rt;
    WASMModuleInstanceCommon *inst_comm_rt;
};

struct wasm_trap_t {
    wasm_byte_vec_t *message;
    Vector *frames;
};

struct wasm_foreign_t {
    wasm_store_t *store;
    wasm_reference_kind kind;
    wasm_host_info host_info;
    int32 ref_cnt;
    uint32 foreign_idx_rt;
    WASMModuleInstanceCommon *inst_comm_rt;
};

struct wasm_func_t {
    wasm_store_t *store;
    wasm_name_t *module_name;
    wasm_name_t *name;
    uint16 kind;

    wasm_host_info host_info;
    wasm_functype_t *type;

    bool with_env;
    union U {
        wasm_func_callback_t cb;
        struct callback_ext {
            void *env;
            wasm_func_callback_with_env_t cb;
            void function(void *)finalizer;
        } 
callback_ext cb_env;
    } 
U u;
    /*
     * an index in both functions runtime instance lists
     * of interpreter mode and aot mode
     */
    uint16 func_idx_rt;
    WASMModuleInstanceCommon *inst_comm_rt;
    WASMFunctionInstanceCommon *func_comm_rt;
};

struct wasm_global_t {
    wasm_store_t *store;
    wasm_name_t *module_name;
    wasm_name_t *name;
    uint16 kind;

    wasm_host_info host_info;
    wasm_globaltype_t *type;
    wasm_val_t *init;
    /*
     * an index in both global runtime instance lists
     * of interpreter mode and aot mode
     */
    uint16 global_idx_rt;
    WASMModuleInstanceCommon *inst_comm_rt;
};

struct wasm_memory_t {
    wasm_store_t *store;
    wasm_name_t *module_name;
    wasm_name_t *name;
    uint16 kind;

    wasm_host_info host_info;
    wasm_memorytype_t *type;
    /*
     * an index in both memory runtime instance lists
     * of interpreter mode and aot mode
     */
    uint16 memory_idx_rt;
    WASMModuleInstanceCommon *inst_comm_rt;
};

struct wasm_table_t {
    wasm_store_t *store;
    wasm_name_t *module_name;
    wasm_name_t *name;
    uint16 kind;

    wasm_host_info host_info;
    wasm_tabletype_t *type;
    /*
     * an index in both table runtime instance lists
     * of interpreter mode and aot mode
     */
    uint16 table_idx_rt;
    WASMModuleInstanceCommon *inst_comm_rt;
};

struct wasm_extern_t {
    wasm_store_t *store;
    wasm_name_t *module_name;
    wasm_name_t *name;
    wasm_externkind_t kind;
    /* reservered space */
    uint8[1] data;
};

struct wasm_instance_t {
    wasm_store_t *store;
    wasm_extern_vec_t *exports;
    wasm_host_info host_info;
    WASMModuleInstanceCommon *inst_comm_rt;
};

wasm_ref_t*
wasm_ref_new_internal(wasm_store_t *store, wasm_reference_kind kind,
                      uint32 obj_idx_rt,
                      WASMModuleInstanceCommon *inst_comm_rt);

wasm_foreign_t *
wasm_foreign_new_internal(wasm_store_t *store, uint32 foreign_idx_rt,
                          WASMModuleInstanceCommon *inst_comm_rt);

wasm_func_t *
wasm_func_new_internal(wasm_store_t *store, uint16 func_idx_rt,
                       WASMModuleInstanceCommon *inst_comm_rt);

wasm_global_t *
wasm_global_new_internal(wasm_store_t *store, uint16 global_idx_rt,
                         WASMModuleInstanceCommon *inst_comm_rt);

wasm_memory_t *
wasm_memory_new_internal(wasm_store_t *store, uint16 memory_idx_rt,
                         WASMModuleInstanceCommon *inst_comm_rt);

wasm_table_t *
wasm_table_new_internal(wasm_store_t *store, uint16 table_idx_rt,
                        WASMModuleInstanceCommon *inst_comm_rt);
