module tagion.iwasm.common.wasm_c_api;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.basic;
public import tagion.iwasm.common.wasm_c_api_internal;

public import tagion.iwasm.share.utils.bh_assert;
public import tagion.iwasm.include.wasm_export;
public import tagion.iwasm.common.wasm_memory;
import tagion.iwasm.share.utils.bh_vector;
static if (ver.WASM_ENABLE_INTERP) {
public import wasm_runtime;
}
static if (ver.WASM_ENABLE_AOT) {
public import aot_runtime;
static if (ver.WASM_ENABLE_JIT && WASM_ENABLE_LAZY_JIT == 0) {
public import aot;
public import aot_llvm;
} /*ver.WASM_ENABLE_JIT && WASM_ENABLE_LAZY_JIT == 0*/
} /*ver.WASM_ENABLE_AOT*/


// Vectors
// size: capacity
// num_elems: current number of elements
// size_of_elem: size of one elemen
struct WASM_DECLARE_VEC(T) { 
//  typedef struct wasm_##name##_vec_t { 
    size_t size; 
    T* data; 
    size_t num_elems; 
    size_t size_of_elem; 
    void *lock; 
} 
//wasm_##name##_vec_t; 
 /+ 
  WASM_API_EXTERN void wasm_##name##_vec_new_empty(own wasm_##name##_vec_t* out); \
  WASM_API_EXTERN void wasm_##name##_vec_new_uninitialized( \
    own wasm_##name##_vec_t* out, size_t); \
  WASM_API_EXTERN void wasm_##name##_vec_new( \
    own wasm_##name##_vec_t* out, \
    size_t, own wasm_##name##_t ptr_or_none const[]); \
  WASM_API_EXTERN void wasm_##name##_vec_copy( \
    own wasm_##name##_vec_t* out, const wasm_##name##_vec_t*); \
  WASM_API_EXTERN void wasm_##name##_vec_delete(own wasm_##name##_vec_t*);
+/

/*
 * Thread Model:
 * - Only one wasm_engine_t in one process
 * - One wasm_store_t is only accessed by one thread. wasm_store_t can't be
 * shared in threads
 * - wasm_module_t can be shared in threads
 * - wasm_instance_t can not be shared in threads
 */

enum string ASSERT_NOT_IMPLEMENTED() = ` bh_assert(!"not implemented")`;
enum string UNREACHABLE() = ` bh_assert(!"unreachable")`;

struct wasm_module_ex_t {
    WASMModuleCommon* module_comm_rt;
    wasm_byte_vec_t* binary;
    korp_mutex lock;
    uint ref_count;
static if (ver.WASM_ENABLE_WASM_CACHE) {
    char[SHA256_DIGEST_LENGTH] hash = 0;
}
}

version (os_thread_local_attribute) {} else {
struct thread_local_stores {
    korp_tid tid;
    uint stores_num;
}
}

private void wasm_module_delete_internal(wasm_module_t*);

private void wasm_instance_delete_internal(wasm_instance_t*);

/* temporarily put stubs here */
private wasm_store_t* wasm_store_copy(const(wasm_store_t)* src) {
    cast(void)src;
    LOG_WARNING("in the stub of %s", __FUNCTION__);
    return null;
}

wasm_module_t* wasm_module_copy(const(wasm_module_t)* src) {
    cast(void)src;
    LOG_WARNING("in the stub of %s", __FUNCTION__);
    return null;
}

wasm_instance_t* wasm_instance_copy(const(wasm_instance_t)* src) {
    cast(void)src;
    LOG_WARNING("in the stub of %s", __FUNCTION__);
    return null;
}

/* ---------------------------------------------------------------------- */
pragma(inline, true) private void* malloc_internal(ulong size) {
    void* mem = null;

    if (size < UINT32_MAX && (mem = wasm_runtime_malloc(cast(uint)size))) {
        memset(mem, 0, size);
    }

    return mem;
}

/* clang-format off */
enum string RETURN_OBJ(string obj, string obj_del_func) = ` \
    return obj;                       \
failed:                               \
    obj_del_func(obj);                \
    return NULL;`;

enum string RETURN_VOID(string obj, string obj_del_func) = ` \
    return;                            \
failed:                                \
    obj_del_func(obj);                 \
    return;`;
/* clang-format on */

/* Vectors */
enum string INIT_VEC(string vector_p, string init_func, Args...) = `                        \
    do {                                                          \
        if (!(vector_p = malloc_internal(sizeof(*(vector_p))))) { \
            goto failed;                                          \
        }                                                         \
                                                                  \
        init_func(vector_p, ##__VA_ARGS__);                       \
        if (vector_p->size && !vector_p->data) {                  \
            LOG_DEBUG("%s failed", #init_func);                   \
            goto failed;                                          \
        }                                                         \
    } while (false)`;

enum string DEINIT_VEC(string vector_p, string deinit_func) = ` \
    if ((vector_p)) {                     \
        deinit_func(vector_p);            \
        wasm_runtime_free(vector_p);      \
        vector_p = NULL;                  \
    }`;

enum string WASM_DEFINE_VEC(string name) = `                                              \
    void wasm_##name##_vec_new_empty(own wasm_##name##_vec_t *out)         \
    {                                                                      \
        wasm_##name##_vec_new_uninitialized(out, 0);                       \
    }                                                                      \
    void wasm_##name##_vec_new_uninitialized(own wasm_##name##_vec_t *out, \
                                             size_t size)                  \
    {                                                                      \
        wasm_##name##_vec_new(out, size, NULL);                            \
    }`;

/* vectors with no ownership management of elements */
enum string WASM_DEFINE_VEC_PLAIN(string name) = `                                       \
    WASM_DEFINE_VEC(name)                                                 \
    void wasm_##name##_vec_new(own wasm_##name##_vec_t *out, size_t size, \
                               own wasm_##name##_t const data[])          \
    {                                                                     \
        if (!out) {                                                       \
            return;                                                       \
        }                                                                 \
                                                                          \
        memset(out, 0, sizeof(wasm_##name##_vec_t));                      \
                                                                          \
        if (!size) {                                                      \
            return;                                                       \
        }                                                                 \
                                                                          \
        if (!bh_vector_init((Vector *)out, size, sizeof(wasm_##name##_t), \
                            true)) {                                      \
            LOG_DEBUG("bh_vector_init failed");                           \
            goto failed;                                                  \
        }                                                                 \
                                                                          \
        if (data) {                                                       \
            uint32 size_in_bytes = 0;                                     \
            size_in_bytes = cast(uint)(size * sizeof(wasm_##name##_t));     \
            bh_memcpy_s(out->data, size_in_bytes, data, size_in_bytes);   \
            out->num_elems = size;                                        \
        }                                                                 \
                                                                          \
        RETURN_VOID(out, wasm_##name##_vec_delete)                        \
    }                                                                     \
    void wasm_##name##_vec_copy(wasm_##name##_vec_t *out,                 \
                                const wasm_##name##_vec_t *src)           \
    {                                                                     \
        if (!src) {                                                       \
            return;                                                       \
        }                                                                 \
        wasm_##name##_vec_new(out, src->size, src->data);                 \
    }                                                                     \
    void wasm_##name##_vec_delete(wasm_##name##_vec_t *v)                 \
    {                                                                     \
        if (v) {                                                          \
            bh_vector_destroy((Vector *)v);                               \
        }                                                                 \
    }`;

/* vectors that own their elements */
enum string WASM_DEFINE_VEC_OWN(string name, string elem_destroy_func) = `                        \
    WASM_DEFINE_VEC(name)                                                   \
    void wasm_##name##_vec_new(own wasm_##name##_vec_t *out, size_t size,   \
                               own wasm_##name##_t *const data[])           \
    {                                                                       \
        if (!out) {                                                         \
            return;                                                         \
        }                                                                   \
                                                                            \
        memset(out, 0, sizeof(wasm_##name##_vec_t));                        \
                                                                            \
        if (!size) {                                                        \
            return;                                                         \
        }                                                                   \
                                                                            \
        if (!bh_vector_init((Vector *)out, size, sizeof(wasm_##name##_t *), \
                            true)) {                                        \
            LOG_DEBUG("bh_vector_init failed");                             \
            goto failed;                                                    \
        }                                                                   \
                                                                            \
        if (data) {                                                         \
            uint32 size_in_bytes = 0;                                       \
            size_in_bytes = cast(uint)(size * sizeof(wasm_##name##_t *));     \
            bh_memcpy_s(out->data, size_in_bytes, data, size_in_bytes);     \
            out->num_elems = size;                                          \
        }                                                                   \
                                                                            \
        RETURN_VOID(out, wasm_##name##_vec_delete)                          \
    }                                                                       \
    void wasm_##name##_vec_copy(own wasm_##name##_vec_t *out,               \
                                const wasm_##name##_vec_t *src)             \
    {                                                                       \
        size_t i = 0;                                                       \
                                                                            \
        if (!out) {                                                         \
            return;                                                         \
        }                                                                   \
        memset(out, 0, sizeof(Vector));                                     \
                                                                            \
        if (!src || !src->size) {                                           \
            return;                                                         \
        }                                                                   \
                                                                            \
        if (!bh_vector_init((Vector *)out, src->size,                       \
                            sizeof(wasm_##name##_t *), true)) {             \
            LOG_DEBUG("bh_vector_init failed");                             \
            goto failed;                                                    \
        }                                                                   \
                                                                            \
        for (i = 0; i != src->num_elems; ++i) {                             \
            if (!(out->data[i] = wasm_##name##_copy(src->data[i]))) {       \
                LOG_DEBUG("wasm_%s_copy failed", #name);                    \
                goto failed;                                                \
            }                                                               \
        }                                                                   \
        out->num_elems = src->num_elems;                                    \
                                                                            \
        RETURN_VOID(out, wasm_##name##_vec_delete)                          \
    }                                                                       \
    void wasm_##name##_vec_delete(wasm_##name##_vec_t *v)                   \
    {                                                                       \
        size_t i = 0;                                                       \
        if (!v) {                                                           \
            return;                                                         \
        }                                                                   \
        for (i = 0; i != v->num_elems && v->data; ++i) {                    \
            elem_destroy_func(*(v->data + i));                              \
        }                                                                   \
        bh_vector_destroy((Vector *)v);                                     \
    }`;

/+
WASM_DEFINE_VEC_PLAIN(val);

WASM_DEFINE_VEC_OWN(exporttype, wasm_exporttype_delete)
WASM_DEFINE_VEC_OWN(extern, wasm_extern_delete)
WASM_DEFINE_VEC_OWN(frame, wasm_frame_delete)
WASM_DEFINE_VEC_OWN(functype, wasm_functype_delete)
WASM_DEFINE_VEC_OWN(importtype, wasm_importtype_delete)
WASM_DEFINE_VEC_OWN(instance, &wasm_instance_delete_internal)
WASM_DEFINE_VEC_OWN(module_, &wasm_module_delete_internal)
WASM_DEFINE_VEC_OWN(store, wasm_store_delete)
WASM_DEFINE_VEC_OWN(valtype, wasm_valtype_delete)
+/

version (NDEBUG) {} else {
enum string WASM_C_DUMP_PROC_MEM() = ` LOG_PROC_MEM()`;
} version (NDEBUG) {
enum string WASM_C_DUMP_PROC_MEM() = ` (void)0`;
}

alias own=void; /// Hack to get it to compile
/* Runtime Environment */
own* wasm_config_new() {
    return null;
}

void wasm_config_delete(own* config) {
    cast(void)config;
}

private void wasm_engine_delete_internal(wasm_engine_t* engine) {
    if (engine) {
        /* clean all created wasm_module_t and their locks */
        uint i = void;

        for (i = 0; i < engine.modules.num_elems; i++) {
            wasm_module_ex_t* module_ = void;
            if (bh_vector_get(&engine.modules, i, &module_)) {
                os_mutex_destroy(&module_.lock);
                wasm_runtime_free(module_);
            }
        }

        bh_vector_destroy(&engine.modules);

version (os_thread_local_attribute) {} else {
        bh_vector_destroy(&engine.stores_by_tid);
}

        wasm_runtime_free(engine);
    }

    wasm_runtime_destroy();
}

private wasm_engine_t* wasm_engine_new_internal(mem_alloc_type_t type, const(MemAllocOption)* opts) {
    wasm_engine_t* engine = null;
    /* init runtime */
    RuntimeInitArgs init_args = { 0 };
    init_args.mem_alloc_type = type;

version (NDEBUG) {} else {
    bh_log_set_verbose_level(BH_LOG_LEVEL_VERBOSE);
} version (NDEBUG) {
    bh_log_set_verbose_level(BH_LOG_LEVEL_WARNING);
}

    WASM_C_DUMP_PROC_MEM();

    if (type == Alloc_With_Pool) {
        if (!opts) {
            return null;
        }

        init_args.mem_alloc_option.pool.heap_buf = opts.pool.heap_buf;
        init_args.mem_alloc_option.pool.heap_size = opts.pool.heap_size;
    }
    else if (type == Alloc_With_Allocator) {
        if (!opts) {
            return null;
        }

        init_args.mem_alloc_option.allocator.malloc_func =
            opts.allocator.malloc_func;
        init_args.mem_alloc_option.allocator.free_func =
            opts.allocator.free_func;
        init_args.mem_alloc_option.allocator.realloc_func =
            opts.allocator.realloc_func;
static if (ver.WASM_MEM_ALLOC_WITH_USER_DATA) {
        init_args.mem_alloc_option.allocator.user_data =
            opts.allocator.user_data;
}
    }
    else {
        init_args.mem_alloc_option.pool.heap_buf = null;
        init_args.mem_alloc_option.pool.heap_size = 0;
    }

    if (!wasm_runtime_full_init(&init_args)) {
        LOG_DEBUG("wasm_runtime_full_init failed");
        goto failed;
    }

    /* create wasm_engine_t */
    if (((engine = malloc_internal(wasm_engine_t.sizeof)) == 0)) {
        goto failed;
    }

    if (!bh_vector_init(&engine.modules, DEFAULT_VECTOR_INIT_SIZE,
                        (wasm_module_ex_t*).sizeof, true))
        goto failed;

version (os_thread_local_attribute) {} else {
    if (!bh_vector_init(&engine.stores_by_tid, DEFAULT_VECTOR_INIT_SIZE,
                        thread_local_stores.sizeof, true))
        goto failed;
}

    engine.ref_count = 1;

    WASM_C_DUMP_PROC_MEM();

    RETURN_OBJ(engine, &wasm_engine_delete_internal);
}

/* global engine instance */
private wasm_engine_t* singleton_engine = null;
version (os_thread_local_attribute) {
/* categorize wasm_store_t as threads*/
private os_thread_local_attribute thread_local_stores_num = 0;
}
version (OS_THREAD_MUTEX_INITIALIZER) {
/**
 * lock for the singleton_engine
 * Note: if the platform has mutex initializer, we use a global lock to
 * lock the operations of the singleton_engine, otherwise when there are
 * operations happening simultaneously in multiple threads, developer
 * must create the lock by himself, and use it to lock the operations
 */
private korp_mutex engine_lock = OS_THREAD_MUTEX_INITIALIZER;
}

own* wasm_engine_new_with_args(mem_alloc_type_t type, const(MemAllocOption)* opts) {
version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_lock(&engine_lock);
}

    if (!singleton_engine)
        singleton_engine = wasm_engine_new_internal(type, opts);
    else
        singleton_engine.ref_count++;

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_unlock(&engine_lock);
}

    return singleton_engine;
}

own* wasm_engine_new() {
    return wasm_engine_new_with_args(Alloc_With_System_Allocator, null);
}

own* wasm_engine_new_with_config(own* config) {
    cast(void)config;
    return wasm_engine_new_with_args(Alloc_With_System_Allocator, null);
}

void wasm_engine_delete(wasm_engine_t* engine) {
    if (!engine)
        return;

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_lock(&engine_lock);
}

    if (!singleton_engine) {
version (OS_THREAD_MUTEX_INITIALIZER) {
        os_mutex_unlock(&engine_lock);
}
        return;
    }

    bh_assert(engine == singleton_engine);
    bh_assert(singleton_engine.ref_count > 0);

    singleton_engine.ref_count--;
    if (singleton_engine.ref_count == 0) {
        wasm_engine_delete_internal(engine);
        singleton_engine = null;
    }

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_unlock(&engine_lock);
}
}

version (os_thread_local_attribute) {} else {
private bool search_thread_local_store_num(Vector* stores_by_tid, korp_tid tid, thread_local_stores* out_ts, uint* out_i) {
    uint i = void;

    for (i = 0; i < stores_by_tid.num_elems; i++) {
        bool ret = bh_vector_get(stores_by_tid, i, out_ts);
        bh_assert(ret);
        cast(void)ret;

        if (out_ts.tid == tid) {
            *out_i = i;
            return true;
        }
    }

    return false;
}
}

private uint retrive_thread_local_store_num(Vector* stores_by_tid, korp_tid tid) {
version (os_thread_local_attribute) {} else {
    uint i = 0;
    thread_local_stores ts = { 0 };
    uint ret = 0;

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_lock(&engine_lock);
}

    if (search_thread_local_store_num(stores_by_tid, tid, &ts, &i))
        ret = ts.stores_num;
    else
        ret = 0;

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_unlock(&engine_lock);
}

    return ret;
} version (os_thread_local_attribute) {
    cast(void)stores_by_tid;
    cast(void)tid;

    return thread_local_stores_num;
}
}

private bool increase_thread_local_store_num(Vector* stores_by_tid, korp_tid tid) {
version (os_thread_local_attribute) {} else {
    uint i = 0;
    thread_local_stores ts = { 0 };
    bool ret = false;

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_lock(&engine_lock);
}

    if (search_thread_local_store_num(stores_by_tid, tid, &ts, &i)) {
        /* just in case if integer overflow */
        if (ts.stores_num + 1 < ts.stores_num) {
            ret = false;
        }
        else {
            ts.stores_num++;
            ret = bh_vector_set(stores_by_tid, i, &ts);
            bh_assert(ret);
        }
    }
    else {
        ts.tid = tid;
        ts.stores_num = 1;
        ret = bh_vector_append(stores_by_tid, &ts);
    }

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_unlock(&engine_lock);
}
    return ret;
} version (os_thread_local_attribute) {
    cast(void)stores_by_tid;
    cast(void)tid;

    /* just in case if integer overflow */
    if (thread_local_stores_num + 1 < thread_local_stores_num)
        return false;

    thread_local_stores_num++;
    return true;
}
}

private bool decrease_thread_local_store_num(Vector* stores_by_tid, korp_tid tid) {
version (os_thread_local_attribute) {} else {
    uint i = 0;
    thread_local_stores ts = { 0 };
    bool ret = false;

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_lock(&engine_lock);
}

    ret = search_thread_local_store_num(stores_by_tid, tid, &ts, &i);
    bh_assert(ret);

    /* just in case if integer overflow */
    if (ts.stores_num - 1 > ts.stores_num) {
        ret = false;
    }
    else {
        ts.stores_num--;
        ret = bh_vector_set(stores_by_tid, i, &ts);
        bh_assert(ret);
    }

version (OS_THREAD_MUTEX_INITIALIZER) {
    os_mutex_unlock(&engine_lock);
}

    return ret;
} version (os_thread_local_attribute) {
    cast(void)stores_by_tid;
    cast(void)tid;

    /* just in case if integer overflow */
    if (thread_local_stores_num - 1 > thread_local_stores_num)
        return false;

    thread_local_stores_num--;
    return true;
}
}

wasm_store_t* wasm_store_new(wasm_engine_t* engine) {
    wasm_store_t* store = null;

    WASM_C_DUMP_PROC_MEM();

    if (!engine || singleton_engine != engine)
        return null;

    if (!retrive_thread_local_store_num(&engine.stores_by_tid,
                                        os_self_thread())) {
        if (!wasm_runtime_init_thread_env()) {
            LOG_ERROR("init thread environment failed");
            return null;
        }

        if (!increase_thread_local_store_num(&engine.stores_by_tid,
                                             os_self_thread())) {
            wasm_runtime_destroy_thread_env();
            return null;
        }

        if (((store = malloc_internal(wasm_store_t.sizeof)) == 0)) {
            decrease_thread_local_store_num(&singleton_engine.stores_by_tid,
                                            os_self_thread());
            wasm_runtime_destroy_thread_env();
            return null;
        }
    }
    else {
        if (!increase_thread_local_store_num(&engine.stores_by_tid,
                                             os_self_thread()))
            return null;

        if (((store = malloc_internal(wasm_store_t.sizeof)) == 0)) {
            decrease_thread_local_store_num(&singleton_engine.stores_by_tid,
                                            os_self_thread());
            return null;
        }
    }

    /* new a vector, and new its data */
    INIT_VEC(store.modules, wasm_module_vec_new_uninitialized,
             DEFAULT_VECTOR_INIT_LENGTH);
    INIT_VEC(store.instances, wasm_instance_vec_new_uninitialized,
             DEFAULT_VECTOR_INIT_LENGTH);

    if (((store.foreigns = malloc_internal(Vector.sizeof)) == 0)
        || !(bh_vector_init(store.foreigns, 24, (wasm_foreign_t*).sizeof,
                            true))) {
        goto failed;
    }

    WASM_C_DUMP_PROC_MEM();

    return store;
failed:
    wasm_store_delete(store);
    return null;
}

void wasm_store_delete(wasm_store_t* store) {
    if (!store) {
        return;
    }

    DEINIT_VEC(store.modules, wasm_module_vec_delete);
    DEINIT_VEC(store.instances, wasm_instance_vec_delete);
    if (store.foreigns) {
        bh_vector_destroy(store.foreigns);
        wasm_runtime_free(store.foreigns);
    }

    wasm_runtime_free(store);

    if (decrease_thread_local_store_num(&singleton_engine.stores_by_tid,
                                        os_self_thread())) {
        if (!retrive_thread_local_store_num(&singleton_engine.stores_by_tid,
                                            os_self_thread())) {
            wasm_runtime_destroy_thread_env();
        }
    }
}

/* Type Representations */
pragma(inline, true) private wasm_valkind_t val_type_rt_2_valkind(ubyte val_type_rt) {
 string WAMR_VAL_TYPE_2_WASM_VAL_KIND(string name) {  
    return format(q{case VALUE_TYPE_%1$s:
        return WASM_%1$s}, name);
	}
    switch (val_type_rt) {

         mixin(WAMR_VAL_TYPE_2_WASM_VAL_KIND("I64"));
         mixin(WAMR_VAL_TYPE_2_WASM_VAL_KIND("F64"));
        mixin(WAMR_VAL_TYPE_2_WASM_VAL_KIND("FUNCREF"));
        default:
            return WASM_ANYREF;
    }
}

private wasm_valtype_t* wasm_valtype_new_internal(ubyte val_type_rt) {
    return wasm_valtype_new(val_type_rt_2_valkind(val_type_rt));
}

wasm_valtype_t* wasm_valtype_new(wasm_valkind_t kind) {
    wasm_valtype_t* val_type = void;

    if (kind > WASM_F64 && WASM_FUNCREF != kind
/+
	#if ver.WASM_ENABLE_REF_TYPES
        && WASM_ANYREF != kind
#endif
	+/
    ) {
        return null;
    }

    if (((val_type = malloc_internal(wasm_valtype_t.sizeof)) == 0)) {
        return null;
    }

    val_type.kind = kind;

    return val_type;
}

void wasm_valtype_delete(wasm_valtype_t* val_type) {
    if (val_type) {
        wasm_runtime_free(val_type);
    }
}

wasm_valtype_t* wasm_valtype_copy(const(wasm_valtype_t)* src) {
    return src ? wasm_valtype_new(src.kind) : null;
}

wasm_valkind_t wasm_valtype_kind(const(wasm_valtype_t)* val_type) {
    return val_type ? val_type.kind : WASM_ANYREF;
}

wasm_functype_t* wasm_functype_new_internal(WASMType* type_rt) {
    wasm_functype_t* type = null;
    wasm_valtype_t* param_type = null, result_type = null;
    uint i = 0;

    if (!type_rt) {
        return null;
    }

    if (((type = malloc_internal(wasm_functype_t.sizeof)) == 0)) {
        return null;
    }

    type.extern_kind = WASM_EXTERN_FUNC;

    /* WASMType->types[0 : type_rt->param_count) -> type->params */
    INIT_VEC(type.params, wasm_valtype_vec_new_uninitialized,
             type_rt.param_count);
    for (i = 0; i < type_rt.param_count; ++i) {
        if (((param_type = wasm_valtype_new_internal(*(type_rt.types + i))) == 0)) {
            goto failed;
        }

        if (!bh_vector_append(cast(Vector*)type.params, &param_type)) {
            LOG_DEBUG("bh_vector_append failed");
            goto failed;
        }
    }

    /* WASMType->types[type_rt->param_count : type_rt->result_count) ->
     * type->results */
    INIT_VEC(type.results, wasm_valtype_vec_new_uninitialized,
             type_rt.result_count);
    for (i = 0; i < type_rt.result_count; ++i) {
        if (((result_type = wasm_valtype_new_internal(
                  *(type_rt.types + type_rt.param_count + i))) == 0)) {
            goto failed;
        }

        if (!bh_vector_append(cast(Vector*)type.results, &result_type)) {
            LOG_DEBUG("bh_vector_append failed");
            goto failed;
        }
    }

    return type;

failed:
    wasm_valtype_delete(param_type);
    wasm_valtype_delete(result_type);
    wasm_functype_delete(type);
    return null;
}

wasm_functype_t* wasm_functype_new(own* params, own* results) {
    wasm_functype_t* type = null;

    if (((type = malloc_internal(wasm_functype_t.sizeof)) == 0)) {
        goto failed;
    }

    type.extern_kind = WASM_EXTERN_FUNC;

    /* take ownership */
    if (((type.params = malloc_internal(wasm_valtype_vec_t.sizeof)) == 0)) {
        goto failed;
    }
    if (params) {
        bh_memcpy_s(type.params, wasm_valtype_vec_t.sizeof, params,
                    wasm_valtype_vec_t.sizeof);
    }

    if (((type.results = malloc_internal(wasm_valtype_vec_t.sizeof)) == 0)) {
        goto failed;
    }
    if (results) {
        bh_memcpy_s(type.results, wasm_valtype_vec_t.sizeof, results,
                    wasm_valtype_vec_t.sizeof);
    }

    return type;

failed:
    wasm_functype_delete(type);
    return null;
}

wasm_functype_t* wasm_functype_copy(const(wasm_functype_t)* src) {
    wasm_functype_t* functype = void;
    wasm_valtype_vec_t params = { 0 }, results = { 0 };

    if (!src) {
        return null;
    }

    wasm_valtype_vec_copy(&params, src.params);
    if (src.params.size && !params.data) {
        goto failed;
    }

    wasm_valtype_vec_copy(&results, src.results);
    if (src.results.size && !results.data) {
        goto failed;
    }

    if (((functype = wasm_functype_new(&params, &results)) == 0)) {
        goto failed;
    }

    return functype;

failed:
    wasm_valtype_vec_delete(&params);
    wasm_valtype_vec_delete(&results);
    return null;
}

void wasm_functype_delete(wasm_functype_t* func_type) {
    if (!func_type) {
        return;
    }

    DEINIT_VEC(func_type.params, wasm_valtype_vec_delete);
    DEINIT_VEC(func_type.results, wasm_valtype_vec_delete);

    wasm_runtime_free(func_type);
}

const(wasm_valtype_vec_t)* wasm_functype_params(const(wasm_functype_t)* func_type) {
    if (!func_type) {
        return null;
    }

    return func_type.params;
}

const(wasm_valtype_vec_t)* wasm_functype_results(const(wasm_functype_t)* func_type) {
    if (!func_type) {
        return null;
    }

    return func_type.results;
}

private bool cmp_val_kind_with_val_type(wasm_valkind_t v_k, ubyte v_t) {
    return (v_k == WASM_I32 && v_t == VALUE_TYPE_I32)
           || (v_k == WASM_I64 && v_t == VALUE_TYPE_I64)
           || (v_k == WASM_F32 && v_t == VALUE_TYPE_F32)
           || (v_k == WASM_F64 && v_t == VALUE_TYPE_F64)
           || (v_k == WASM_ANYREF && v_t == VALUE_TYPE_EXTERNREF)
           || (v_k == WASM_FUNCREF && v_t == VALUE_TYPE_FUNCREF);
}

/*
 *to compare a function type of wasm-c-api with a function type of wasm_runtime
 */
private bool wasm_functype_same_internal(const(wasm_functype_t)* type, const(WASMType)* type_intl) {
    uint i = 0;

    if (!type || !type_intl || type.params.num_elems != type_intl.param_count
        || type.results.num_elems != type_intl.result_count)
        return false;

    for (i = 0; i < type.params.num_elems; i++) {
        wasm_valtype_t* v_t = type.params.data[i];
        if (!cmp_val_kind_with_val_type(wasm_valtype_kind(v_t),
                                        type_intl.types[i]))
            return false;
    }

    for (i = 0; i < type.results.num_elems; i++) {
        wasm_valtype_t* v_t = type.results.data[i];
        if (!cmp_val_kind_with_val_type(
                wasm_valtype_kind(v_t),
                type_intl.types[i + type.params.num_elems]))
            return false;
    }

    return true;
}

wasm_globaltype_t* wasm_globaltype_new(own* val_type, wasm_mutability_t mut) {
    wasm_globaltype_t* global_type = null;

    if (!val_type) {
        return null;
    }

    if (((global_type = malloc_internal(wasm_globaltype_t.sizeof)) == 0)) {
        return null;
    }

    global_type.extern_kind = WASM_EXTERN_GLOBAL;
    global_type.val_type = val_type;
    global_type.mutability = mut;

    return global_type;
}

wasm_globaltype_t* wasm_globaltype_new_internal(ubyte val_type_rt, bool is_mutable) {
    wasm_globaltype_t* globaltype = void;
    wasm_valtype_t* val_type = void;

    if (((val_type = wasm_valtype_new(val_type_rt_2_valkind(val_type_rt))) == 0)) {
        return null;
    }

    if (((globaltype = wasm_globaltype_new(
              val_type, is_mutable ? WASM_VAR : WASM_CONST)) == 0)) {
        wasm_valtype_delete(val_type);
    }

    return globaltype;
}

void wasm_globaltype_delete(wasm_globaltype_t* global_type) {
    if (!global_type) {
        return;
    }

    if (global_type.val_type) {
        wasm_valtype_delete(global_type.val_type);
        global_type.val_type = null;
    }

    wasm_runtime_free(global_type);
}

wasm_globaltype_t* wasm_globaltype_copy(const(wasm_globaltype_t)* src) {
    wasm_globaltype_t* global_type = void;
    wasm_valtype_t* val_type = void;

    if (!src) {
        return null;
    }

    if (((val_type = wasm_valtype_copy(src.val_type)) == 0)) {
        return null;
    }

    if (((global_type = wasm_globaltype_new(val_type, src.mutability)) == 0)) {
        wasm_valtype_delete(val_type);
    }

    return global_type;
}

const(wasm_valtype_t)* wasm_globaltype_content(const(wasm_globaltype_t)* global_type) {
    if (!global_type) {
        return null;
    }

    return global_type.val_type;
}

wasm_mutability_t wasm_globaltype_mutability(const(wasm_globaltype_t)* global_type) {
    if (!global_type) {
        return false;
    }

    return global_type.mutability;
}

private wasm_tabletype_t* wasm_tabletype_new_internal(ubyte val_type_rt, uint init_size, uint max_size) {
    wasm_tabletype_t* table_type = void;
    wasm_limits_t limits = { init_size, max_size };
    wasm_valtype_t* val_type = void;

    if (((val_type = wasm_valtype_new_internal(val_type_rt)) == 0)) {
        return null;
    }

    if (((table_type = wasm_tabletype_new(val_type, &limits)) == 0)) {
        wasm_valtype_delete(val_type);
    }

    return table_type;
}

wasm_tabletype_t* wasm_tabletype_new(own* val_type, const(wasm_limits_t)* limits) {
    wasm_tabletype_t* table_type = null;

    if (!val_type || !limits) {
        return null;
    }

    if (wasm_valtype_kind(val_type) != WASM_FUNCREF
	/+
#if ver.WASM_ENABLE_REF_TYPES
        && wasm_valtype_kind(val_type) != WASM_ANYREF
#endif
	+/
    ) {
        return null;
    }

    if (((table_type = malloc_internal(wasm_tabletype_t.sizeof)) == 0)) {
        return null;
    }

    table_type.extern_kind = WASM_EXTERN_TABLE;
    table_type.val_type = val_type;
    table_type.limits.min = limits.min;
    table_type.limits.max = limits.max;

    return table_type;
}

wasm_tabletype_t* wasm_tabletype_copy(const(wasm_tabletype_t)* src) {
    wasm_tabletype_t* table_type = void;
    wasm_valtype_t* val_type = void;

    if (!src) {
        return null;
    }

    if (((val_type = wasm_valtype_copy(src.val_type)) == 0)) {
        return null;
    }

    if (((table_type = wasm_tabletype_new(val_type, &src.limits)) == 0)) {
        wasm_valtype_delete(val_type);
    }

    return table_type;
}

void wasm_tabletype_delete(wasm_tabletype_t* table_type) {
    if (!table_type) {
        return;
    }

    if (table_type.val_type) {
        wasm_valtype_delete(table_type.val_type);
        table_type.val_type = null;
    }

    wasm_runtime_free(table_type);
}

const(wasm_valtype_t)* wasm_tabletype_element(const(wasm_tabletype_t)* table_type) {
    if (!table_type) {
        return null;
    }

    return table_type.val_type;
}

const(wasm_limits_t)* wasm_tabletype_limits(const(wasm_tabletype_t)* table_type) {
    if (!table_type) {
        return null;
    }

    return &(table_type.limits);
}

private wasm_memorytype_t* wasm_memorytype_new_internal(uint min_pages, uint max_pages) {
    wasm_limits_t limits = { min_pages, max_pages };
    return wasm_memorytype_new(&limits);
}

wasm_memorytype_t* wasm_memorytype_new(const(wasm_limits_t)* limits) {
    wasm_memorytype_t* memory_type = null;

    if (!limits) {
        return null;
    }

    if (((memory_type = malloc_internal(wasm_memorytype_t.sizeof)) == 0)) {
        return null;
    }

    memory_type.extern_kind = WASM_EXTERN_MEMORY;
    memory_type.limits.min = limits.min;
    memory_type.limits.max = limits.max;

    return memory_type;
}

wasm_memorytype_t* wasm_memorytype_copy(const(wasm_memorytype_t)* src) {
    if (!src) {
        return null;
    }

    return wasm_memorytype_new(&src.limits);
}

void wasm_memorytype_delete(wasm_memorytype_t* memory_type) {
    if (memory_type) {
        wasm_runtime_free(memory_type);
    }
}

const(wasm_limits_t)* wasm_memorytype_limits(const(wasm_memorytype_t)* memory_type) {
    if (!memory_type) {
        return null;
    }

    return &(memory_type.limits);
}

wasm_externkind_t wasm_externtype_kind(const(wasm_externtype_t)* extern_type) {
    if (!extern_type) {
        return WASM_EXTERN_FUNC;
    }

    return extern_type.extern_kind;
}

enum string BASIC_FOUR_TYPE_LIST(string V) = ` \
    V(functype)                 \
    V(globaltype)               \
    V(memorytype)               \
    V(tabletype)`;

enum string WASM_EXTERNTYPE_AS_OTHERTYPE(string name) = `                                     \
    wasm_##name##_t *wasm_externtype_as_##name(wasm_externtype_t *extern_type) \
    {                                                                          \
        return (wasm_##name##_t *)extern_type;                                 \
    }`;

//BASIC_FOUR_TYPE_LIST(WASM_EXTERNTYPE_AS_OTHERTYPE);
enum string WASM_OTHERTYPE_AS_EXTERNTYPE(string name) = `                                 \
    wasm_externtype_t *wasm_##name##_as_externtype(wasm_##name##_t *other) \
    {                                                                      \
        return (wasm_externtype_t *)other;                                 \
    }`;

//BASIC_FOUR_TYPE_LIST(WASM_OTHERTYPE_AS_EXTERNTYPE);
enum string WASM_EXTERNTYPE_AS_OTHERTYPE_CONST(string name) = `              \
    const wasm_##name##_t *wasm_externtype_as_##name##_const( \
        const wasm_externtype_t *extern_type)                 \
    {                                                         \
        return (const wasm_##name##_t *)extern_type;          \
    }`;

//BASIC_FOUR_TYPE_LIST(WASM_EXTERNTYPE_AS_OTHERTYPE_CONST);
enum string WASM_OTHERTYPE_AS_EXTERNTYPE_CONST(string name) = `                \
    const wasm_externtype_t *wasm_##name##_as_externtype_const( \
        const wasm_##name##_t *other)                           \
    {                                                           \
        return (const wasm_externtype_t *)other;                \
    }`;

//BASIC_FOUR_TYPE_LIST(WASM_OTHERTYPE_AS_EXTERNTYPE_CONST);
wasm_externtype_t* wasm_externtype_copy(const(wasm_externtype_t)* src) {
    wasm_externtype_t* extern_type = null;

    if (!src) {
        return null;
    }
 string COPY_EXTERNTYPE(string NAME, string name) {
		return format(q{
    case WASM_EXTERN_%1$s:                                             
    {                                                                    
        extern_type = wasm_%2$s_as_externtype(                       
            wasm_##name##_copy(wasm_externtype_as_##name##_const(src))); 
        break;                                                           
    }
		}, NAME, name);

    switch (src.extern_kind) {
        COPY_EXTERNTYPE("FUNC", "functype");
        COPY_EXTERNTYPE("GLOBAL", "globaltype");
        COPY_EXTERNTYPE("MEMORY", "memorytype");
        COPY_EXTERNTYPE("TABLE", "tabletype");
        default:
            LOG_WARNING("%s meets unsupported kind %u", __FUNCTION__,
                        src.extern_kind);
            break;
    }
    return extern_type;
}

void wasm_externtype_delete(wasm_externtype_t* extern_type) {
    if (!extern_type) {
        return;
    }

    switch (wasm_externtype_kind(extern_type)) {
        case WASM_EXTERN_FUNC:
            wasm_functype_delete(wasm_externtype_as_functype(extern_type));
            break;
        case WASM_EXTERN_GLOBAL:
            wasm_globaltype_delete(wasm_externtype_as_globaltype(extern_type));
            break;
        case WASM_EXTERN_MEMORY:
            wasm_memorytype_delete(wasm_externtype_as_memorytype(extern_type));
            break;
        case WASM_EXTERN_TABLE:
            wasm_tabletype_delete(wasm_externtype_as_tabletype(extern_type));
            break;
        default:
            LOG_WARNING("%s meets unsupported type %u", __FUNCTION__,
                        wasm_externtype_kind(extern_type));
            break;
    }
}

own* wasm_importtype_new(own* module_name, own* field_name, own* extern_type) {
    wasm_importtype_t* import_type = null;

    if (!module_name || !field_name || !extern_type) {
        return null;
    }

    if (((import_type = malloc_internal(wasm_importtype_t.sizeof)) == 0)) {
        return null;
    }

    /* take ownership */
    if (((import_type.module_name =
              malloc_internal(wasm_byte_vec_t.sizeof)) == 0)) {
        goto failed;
    }
    bh_memcpy_s(import_type.module_name, wasm_byte_vec_t.sizeof, module_name,
                wasm_byte_vec_t.sizeof);

    if (((import_type.name = malloc_internal(wasm_byte_vec_t.sizeof)) == 0)) {
        goto failed;
    }
    bh_memcpy_s(import_type.name, wasm_byte_vec_t.sizeof, field_name,
                wasm_byte_vec_t.sizeof);

    import_type.extern_type = extern_type;

    return import_type;
failed:
    wasm_importtype_delete(import_type);
    return null;
}

void wasm_importtype_delete(own* import_type) {
    if (!import_type) {
        return;
    }

    DEINIT_VEC(import_type.module_name, wasm_byte_vec_delete);
    DEINIT_VEC(import_type.name, wasm_byte_vec_delete);
    wasm_externtype_delete(import_type.extern_type);
    import_type.extern_type = null;
    wasm_runtime_free(import_type);
}

own* wasm_importtype_copy(const(wasm_importtype_t)* src) {
    wasm_byte_vec_t module_name = { 0 }, name = { 0 };
    wasm_externtype_t* extern_type = null;
    wasm_importtype_t* import_type = null;

    if (!src) {
        return null;
    }

    wasm_byte_vec_copy(&module_name, src.module_name);
    if (src.module_name.size && !module_name.data) {
        goto failed;
    }

    wasm_byte_vec_copy(&name, src.name);
    if (src.name.size && !name.data) {
        goto failed;
    }

    if (((extern_type = wasm_externtype_copy(src.extern_type)) == 0)) {
        goto failed;
    }

    if (((import_type =
              wasm_importtype_new(&module_name, &name, extern_type)) == 0)) {
        goto failed;
    }

    return import_type;

failed:
    wasm_byte_vec_delete(&module_name);
    wasm_byte_vec_delete(&name);
    wasm_externtype_delete(extern_type);
    wasm_importtype_delete(import_type);
    return null;
}

const(wasm_byte_vec_t)* wasm_importtype_module(const(wasm_importtype_t)* import_type) {
    if (!import_type) {
        return null;
    }

    return import_type.module_name;
}

const(wasm_byte_vec_t)* wasm_importtype_name(const(wasm_importtype_t)* import_type) {
    if (!import_type) {
        return null;
    }

    return import_type.name;
}

const(wasm_externtype_t)* wasm_importtype_type(const(wasm_importtype_t)* import_type) {
    if (!import_type) {
        return null;
    }

    return import_type.extern_type;
}

own* wasm_exporttype_new(own* name, own* extern_type) {
    wasm_exporttype_t* export_type = null;

    if (!name || !extern_type) {
        return null;
    }

    if (((export_type = malloc_internal(wasm_exporttype_t.sizeof)) == 0)) {
        return null;
    }

    if (((export_type.name = malloc_internal(wasm_byte_vec_t.sizeof)) == 0)) {
        wasm_exporttype_delete(export_type);
        return null;
    }
    bh_memcpy_s(export_type.name, wasm_byte_vec_t.sizeof, name,
                wasm_byte_vec_t.sizeof);

    export_type.extern_type = extern_type;

    return export_type;
}

wasm_exporttype_t* wasm_exporttype_copy(const(wasm_exporttype_t)* src) {
    wasm_exporttype_t* export_type = void;
    wasm_byte_vec_t name = { 0 };
    wasm_externtype_t* extern_type = null;

    if (!src) {
        return null;
    }

    wasm_byte_vec_copy(&name, src.name);
    if (src.name.size && !name.data) {
        goto failed;
    }

    if (((extern_type = wasm_externtype_copy(src.extern_type)) == 0)) {
        goto failed;
    }

    if (((export_type = wasm_exporttype_new(&name, extern_type)) == 0)) {
        goto failed;
    }

    return export_type;
failed:
    wasm_byte_vec_delete(&name);
    wasm_externtype_delete(extern_type);
    return null;
}

void wasm_exporttype_delete(wasm_exporttype_t* export_type) {
    if (!export_type) {
        return;
    }

    DEINIT_VEC(export_type.name, wasm_byte_vec_delete);

    wasm_externtype_delete(export_type.extern_type);

    wasm_runtime_free(export_type);
}

const(wasm_byte_vec_t)* wasm_exporttype_name(const(wasm_exporttype_t)* export_type) {
    if (!export_type) {
        return null;
    }
    return export_type.name;
}

const(wasm_externtype_t)* wasm_exporttype_type(const(wasm_exporttype_t)* export_type) {
    if (!export_type) {
        return null;
    }
    return export_type.extern_type;
}

/* Runtime Objects */
void wasm_val_delete(wasm_val_t* v) {
    if (v)
        wasm_runtime_free(v);
}

void wasm_val_copy(wasm_val_t* out_, const(wasm_val_t)* src) {
    if (!out_ || !src) {
        return;
    }

    bh_memcpy_s(out_, wasm_val_t.sizeof, src, wasm_val_t.sizeof);
}

bool rt_val_to_wasm_val(const(ubyte)* data, ubyte val_type_rt, wasm_val_t* out_) {
    bool ret = true;
    switch (val_type_rt) {
        case VALUE_TYPE_I32:
            out_.kind = WASM_I32;
            out_.of.i32 = *(cast(int*)data);
            break;
        case VALUE_TYPE_F32:
            out_.kind = WASM_F32;
            out_.of.f32 = *(cast(float32*)data);
            break;
        case VALUE_TYPE_I64:
            out_.kind = WASM_I64;
            out_.of.i64 = *(cast(long*)data);
            break;
        case VALUE_TYPE_F64:
            out_.kind = WASM_F64;
            out_.of.f64 = *(cast(float64*)data);
            break;
static if (ver.WASM_ENABLE_REF_TYPES) {
        case VALUE_TYPE_EXTERNREF:
            out_.kind = WASM_ANYREF;
            if (NULL_REF == *cast(uint*)data) {
                out_.of.ref_ = null;
            }
            else {
                ret = wasm_externref_ref2obj(*cast(uint*)data,
                                             cast(void**)&out_.of.ref_);
            }
            break;
}
        default:
            LOG_WARNING("unexpected value type %d", val_type_rt);
            ret = false;
    }
    return ret;
}

bool wasm_val_to_rt_val(WASMModuleInstanceCommon* inst_comm_rt, ubyte val_type_rt, const(wasm_val_t)* v, ubyte* data) {
    bool ret = true;
    switch (val_type_rt) {
        case VALUE_TYPE_I32:
            bh_assert(WASM_I32 == v.kind);
            *(cast(int*)data) = v.of.i32;
            break;
        case VALUE_TYPE_F32:
            bh_assert(WASM_F32 == v.kind);
            *(cast(float32*)data) = v.of.f32;
            break;
        case VALUE_TYPE_I64:
            bh_assert(WASM_I64 == v.kind);
            *(cast(long*)data) = v.of.i64;
            break;
        case VALUE_TYPE_F64:
            bh_assert(WASM_F64 == v.kind);
            *(cast(float64*)data) = v.of.f64;
            break;
static if (ver.WASM_ENABLE_REF_TYPES) {
        case VALUE_TYPE_EXTERNREF:
            bh_assert(WASM_ANYREF == v.kind);
            ret =
                wasm_externref_obj2ref(inst_comm_rt, v.of.ref_, cast(uint*)data);
            break;
}
        default:
            LOG_WARNING("unexpected value type %d", val_type_rt);
            ret = false;
            break;
    }

    return ret;
}

wasm_ref_t* wasm_ref_new_internal(wasm_store_t* store, wasm_reference_kind kind, uint ref_idx_rt, WASMModuleInstanceCommon* inst_comm_rt) {
    wasm_ref_t* ref_ = void;

    if (!store) {
        return null;
    }

    if (((ref_ = malloc_internal(wasm_ref_t.sizeof)) == 0)) {
        return null;
    }

    ref_.store = store;
    ref_.kind = kind;
    ref_.ref_idx_rt = ref_idx_rt;
    ref_.inst_comm_rt = inst_comm_rt;

    /* workaround */
    if (WASM_REF_foreign == kind) {
        wasm_foreign_t* foreign = void;

        if (!(bh_vector_get(ref_.store.foreigns, ref_.ref_idx_rt, &foreign))
            || !foreign) {
            wasm_runtime_free(ref_);
            return null;
        }

        foreign.ref_cnt++;
    }
    /* others doesn't include ref counters */

    return ref_;
}

own* wasm_ref_copy(const(wasm_ref_t)* src) {
    if (!src)
        return null;

    /* host_info are different in wasm_ref_t(s) */
    return wasm_ref_new_internal(src.store, src.kind, src.ref_idx_rt,
                                 src.inst_comm_rt);
}

enum string DELETE_HOST_INFO(string obj) = `                              \
    if (obj->host_info.info) {                             \
        if (obj->host_info.finalizer) {                    \
            obj->host_info.finalizer(obj->host_info.info); \
        }                                                  \
    }`;

void wasm_ref_delete(own* ref_) {
    if (!ref_ || !ref_.store)
        return;

    DELETE_HOST_INFO(ref_);

    if (WASM_REF_foreign == ref_.kind) {
        wasm_foreign_t* foreign = null;

        if (bh_vector_get(ref_.store.foreigns, ref_.ref_idx_rt, &foreign)
            && foreign) {
            wasm_foreign_delete(foreign);
        }
    }

    wasm_runtime_free(ref_);
}

enum string WASM_DEFINE_REF_BASE(string name) = `                                          \
    bool wasm_##name##_same(const wasm_##name##_t *o1,                      \
                            const wasm_##name##_t *o2)                      \
    {                                                                       \
        return (!o1 && !o2)   ? true                                        \
               : (!o1 || !o2) ? false                                       \
               : (o1->kind != o2->kind)                                     \
                   ? false                                                  \
                   : o1->name##_idx_rt == o2->name##_idx_rt;                \
    }                                                                       \
                                                                            \
    void *wasm_##name##_get_host_info(const wasm_##name##_t *obj)           \
    {                                                                       \
        return obj ? obj->host_info.info : NULL;                            \
    }                                                                       \
                                                                            \
    void wasm_##name##_set_host_info(wasm_##name##_t *obj, void *host_info) \
    {                                                                       \
        if (obj) {                                                          \
            obj->host_info.info = host_info;                                \
            obj->host_info.finalizer = NULL;                                \
        }                                                                   \
    }                                                                       \
                                                                            \
    void wasm_##name##_set_host_info_with_finalizer(                        \
        wasm_##name##_t *obj, void *host_info, void (*finalizer)(void *))   \
    {                                                                       \
        if (obj) {                                                          \
            obj->host_info.info = host_info;                                \
            obj->host_info.finalizer = finalizer;                           \
        }                                                                   \
    }`;

enum string WASM_DEFINE_REF(string name) = `                                                  \
    WASM_DEFINE_REF_BASE(name)                                                 \
                                                                               \
    wasm_ref_t *wasm_##name##_as_ref(wasm_##name##_t *name)                    \
    {                                                                          \
        if (!name) {                                                           \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_ref_new_internal(name->store, WASM_REF_##name,             \
                                     name->name##_idx_rt, name->inst_comm_rt); \
    }                                                                          \
                                                                               \
    const wasm_ref_t *wasm_##name##_as_ref_const(const wasm_##name##_t *name)  \
    {                                                                          \
        if (!name) {                                                           \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_ref_new_internal(name->store, WASM_REF_##name,             \
                                     name->name##_idx_rt, name->inst_comm_rt); \
    }                                                                          \
                                                                               \
    wasm_##name##_t *wasm_ref_as_##name(wasm_ref_t *ref)                       \
    {                                                                          \
        if (!ref || WASM_REF_##name != ref->kind) {                            \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_##name##_new_internal(ref->store, ref->ref_idx_rt,         \
                                          ref->inst_comm_rt);                  \
    }                                                                          \
                                                                               \
    const wasm_##name##_t *wasm_ref_as_##name##_const(const wasm_ref_t *ref)   \
    {                                                                          \
        if (!ref || WASM_REF_##name != ref->kind) {                            \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_##name##_new_internal(ref->store, ref->ref_idx_rt,         \
                                          ref->inst_comm_rt);                  \
    }`;
/+
 WASM_DEFINE_REF(foreign);
 WASM_DEFINE_REF(global);
 WASM_DEFINE_REF(table);
+/
wasm_frame_t* wasm_frame_new(wasm_instance_t* instance, size_t module_offset, uint func_index, size_t func_offset) {
    wasm_frame_t* frame = void;

    if (((frame = malloc_internal(wasm_frame_t.sizeof)) == 0)) {
        return null;
    }

    frame.instance = instance;
    frame.module_offset = cast(uint)module_offset;
    frame.func_index = func_index;
    frame.func_offset = cast(uint)func_offset;
    return frame;
}

own* wasm_frame_copy(const(wasm_frame_t)* src) {
    if (!src) {
        return null;
    }

    return wasm_frame_new(src.instance, src.module_offset, src.func_index,
                          src.func_offset);
}

void wasm_frame_delete(own* frame) {
    if (frame) {
        wasm_runtime_free(frame);
    }
}

wasm_instance_t* wasm_frame_instance(const(wasm_frame_t)* frame) {
    return frame ? frame.instance : null;
}

size_t wasm_frame_module_offset(const(wasm_frame_t)* frame) {
    return frame ? frame.module_offset : 0;
}

uint wasm_frame_func_index(const(wasm_frame_t)* frame) {
    return frame ? frame.func_index : 0;
}

size_t wasm_frame_func_offset(const(wasm_frame_t)* frame) {
    return frame ? frame.func_offset : 0;
}

wasm_trap_t* wasm_trap_new_internal(wasm_store_t* store, WASMModuleInstanceCommon* inst_comm_rt, const(char)* error_info) {
    wasm_trap_t* trap = void;
static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
    wasm_instance_vec_t* instances = void;
    wasm_instance_t* frame_instance = null;
    uint i = void;
}

    if (!singleton_engine)
        return null;

    if (((trap = malloc_internal(wasm_trap_t.sizeof)) == 0)) {
        return null;
    }

    /* fill in message */
    if (strlen(error_info) > 0) {
        if (((trap.message = malloc_internal(wasm_byte_vec_t.sizeof)) == 0)) {
            goto failed;
        }

        wasm_name_new_from_string_nt(trap.message, error_info);
        if (!trap.message.data) {
            goto failed;
        }
    }

    /* fill in frames */
static if (ver.WASM_ENABLE_DUMP_CALL_STACK) {
    trap.frames = (cast(WASMModuleInstance*)inst_comm_rt).frames;

    if (trap.frames) {
        /* fill in instances */
        instances = store.instances;
        bh_assert(instances != null);

        for (i = 0; i < instances.num_elems; i++) {
            if (instances.data[i].inst_comm_rt == inst_comm_rt) {
                frame_instance = instances.data[i];
                break;
            }
        }

        for (i = 0; i < trap.frames.num_elems; i++) {
            ((cast(wasm_frame_t*)trap.frames.data) + i).instance =
                frame_instance;
        }
    }
} /* ver.WASM_ENABLE_DUMP_CALL_STACK */

    return trap;
failed:
    wasm_trap_delete(trap);
    return null;
}

wasm_trap_t* wasm_trap_new(wasm_store_t* store, const(wasm_message_t)* message) {
    wasm_trap_t* trap = void;

    if (!store) {
        return null;
    }

    if (((trap = malloc_internal(wasm_trap_t.sizeof)) == 0)) {
        return null;
    }

    if (message) {
        INIT_VEC(trap.message, wasm_byte_vec_new, message.size,
                 message.data);
    }

    return trap;
failed:
    wasm_trap_delete(trap);
    return null;
}

void wasm_trap_delete(wasm_trap_t* trap) {
    if (!trap) {
        return;
    }

    DEINIT_VEC(trap.message, wasm_byte_vec_delete);
    /* reuse frames of WASMModuleInstance, do not free it here */

    wasm_runtime_free(trap);
}

void wasm_trap_message(const(wasm_trap_t)* trap, own* out_) {
    if (!trap || !out_) {
        return;
    }

    wasm_byte_vec_copy(out_, trap.message);
}

own* wasm_trap_origin(const(wasm_trap_t)* trap) {
    wasm_frame_t* latest_frame = void;

    if (!trap || !trap.frames || !trap.frames.num_elems) {
        return null;
    }

    /* first frame is the latest frame */
    latest_frame = cast(wasm_frame_t*)trap.frames.data;
    return wasm_frame_copy(latest_frame);
}

void wasm_trap_trace(const(wasm_trap_t)* trap, own* out_) {
    uint i = void;

    if (!trap || !out_) {
        return;
    }

    if (!trap.frames || !trap.frames.num_elems) {
        wasm_frame_vec_new_empty(out_);
        return;
    }

    wasm_frame_vec_new_uninitialized(out_, trap.frames.num_elems);
    if (out_.size == 0 || !out_.data) {
        return;
    }

    for (i = 0; i < trap.frames.num_elems; i++) {
        wasm_frame_t* frame = void;

        frame = (cast(wasm_frame_t*)trap.frames.data) + i;

        if (((out_.data[i] =
                  wasm_frame_new(frame.instance, frame.module_offset,
                                 frame.func_index, frame.func_offset)) == 0)) {
            goto failed;
        }
        out_.num_elems++;
    }

    return;
failed:
    for (i = 0; i < out_.num_elems; i++) {
        if (out_.data[i]) {
            wasm_runtime_free(out_.data[i]);
        }
    }

    wasm_runtime_free(out_.data);
}

wasm_foreign_t* wasm_foreign_new_internal(wasm_store_t* store, uint foreign_idx_rt, WASMModuleInstanceCommon* inst_comm_rt) {
    wasm_foreign_t* foreign = null;

    if (!store || !store.foreigns)
        return null;

    if (!(bh_vector_get(store.foreigns, foreign_idx_rt, &foreign))
        || !foreign) {
        return null;
    }

    foreign.ref_cnt++;
    return foreign;
}

own* wasm_foreign_new(wasm_store_t* store) {
    wasm_foreign_t* foreign = void;

    if (!store)
        return null;

    if (((foreign = malloc_internal(wasm_foreign_t.sizeof)) == 0))
        return null;

    foreign.store = store;
    foreign.kind = WASM_REF_foreign;
    foreign.foreign_idx_rt = cast(uint)bh_vector_size(store.foreigns);
    if (!(bh_vector_append(store.foreigns, &foreign))) {
        wasm_runtime_free(foreign);
        return null;
    }

    return foreign;
}

void wasm_foreign_delete(wasm_foreign_t* foreign) {
    if (!foreign)
        return;

    if (foreign.ref_cnt < 1) {
        return;
    }

    foreign.ref_cnt--;
    if (!foreign.ref_cnt) {
        wasm_runtime_free(foreign);
    }
}

pragma(inline, true) wasm_module_t* module_ext_to_module(wasm_module_ex_t* module_ex) {
    return cast(wasm_module_t*)module_ex;
}

pragma(inline, true) wasm_module_ex_t* module_to_module_ext(wasm_module_t* module_) {
    return cast(wasm_module_ex_t*)module_;
}

static if (ver.WASM_ENABLE_INTERP) {
enum string MODULE_INTERP(string module_comm) = ` ((WASMModule *)(*module_comm))`;
}

static if (ver.WASM_ENABLE_AOT) {
enum string MODULE_AOT(string module_comm) = ` ((AOTModule *)(*module_comm))`;
}

static if (ver.WASM_ENABLE_WASM_CACHE) {
wasm_module_ex_t* check_loaded_module(Vector* modules, char* binary_hash) {
    uint i = void;
    wasm_module_ex_t* module_ = null;

    for (i = 0; i < modules.num_elems; i++) {
        bh_vector_get(modules, i, &module_);
        if (!module_) {
            LOG_ERROR("Unexpected failure at %d\n", __LINE__);
            return null;
        }

        if (!module_.ref_count)
            /* deleted */
            continue;

        if (memcmp(module_.hash, binary_hash, SHA256_DIGEST_LENGTH) == 0)
            return module_;
    }
    return null;
}

wasm_module_ex_t* try_reuse_loaded_module(wasm_store_t* store, char* binary_hash) {
    wasm_module_ex_t* cached = null;
    wasm_module_ex_t* ret = null;

    cached = check_loaded_module(&singleton_engine.modules, binary_hash);
    if (!cached)
        goto quit;

    os_mutex_lock(&cached.lock);
    if (!cached.ref_count)
        goto unlock;

    if (!bh_vector_append(cast(Vector*)store.modules, &cached))
        goto unlock;

    cached.ref_count += 1;
    ret = cached;

unlock:
    os_mutex_unlock(&cached.lock);
quit:
    return ret;
}
} /* ver.WASM_ENABLE_WASM_CACHE */

wasm_module_t* wasm_module_new(wasm_store_t* store, const(wasm_byte_vec_t)* binary) {
    char[128] error_buf = 0;
    wasm_module_ex_t* module_ex = null;
static if (ver.WASM_ENABLE_WASM_CACHE) {
    char[SHA256_DIGEST_LENGTH] binary_hash = 0;
}

    bh_assert(singleton_engine);

    if (!store || !binary || binary.size == 0 || binary.size > UINT32_MAX)
        goto quit;

    /* whether the combination of compilation flags are compatable with the
     * package type */
    {
        PackageType pkg_type = void;
        pkg_type =
            get_package_type(cast(ubyte*)binary.data, cast(uint)binary.size);
        bool result = false;
static if (ver.WASM_ENABLE_INTERP) {
        result = (pkg_type == Wasm_Module_Bytecode);
}

static if (ver.WASM_ENABLE_AOT) {
        result = result || (pkg_type == Wasm_Module_AoT);
}
        if (!result) {
            LOG_VERBOSE("current building isn't compatiable with the module,"
                        ~ "may need recompile");
            goto quit;
        }
    }

static if (ver.WASM_ENABLE_WASM_CACHE) {
    /* if cached */
    SHA256(cast(void*)binary.data, binary.num_elems, cast(ubyte*)binary_hash);
    module_ex = try_reuse_loaded_module(store, binary_hash.ptr);
    if (module_ex)
        return module_ext_to_module(module_ex);
}

    WASM_C_DUMP_PROC_MEM();

    module_ex = malloc_internal(wasm_module_ex_t.sizeof);
    if (!module_ex)
        goto quit;

    module_ex.binary = malloc_internal(wasm_byte_vec_t.sizeof);
    if (!module_ex.binary)
        goto free_module;

    wasm_byte_vec_copy(module_ex.binary, binary);
    if (!module_ex.binary.data)
        goto free_binary;

    module_ex.module_comm_rt = wasm_runtime_load(
        cast(ubyte*)module_ex.binary.data, cast(uint)module_ex.binary.size,
        error_buf.ptr, cast(uint)error_buf.sizeof);
    if (!(module_ex.module_comm_rt)) {
        LOG_ERROR(error_buf.ptr);
        goto free_vec;
    }

    /* append it to a watching list in store */
    if (!bh_vector_append(cast(Vector*)store.modules, &module_ex))
        goto unload;

    if (os_mutex_init(&module_ex.lock) != BHT_OK)
        goto remove_last;

    if (!bh_vector_append(&singleton_engine.modules, &module_ex))
        goto destroy_lock;

static if (ver.WASM_ENABLE_WASM_CACHE) {
    bh_memcpy_s(module_ex.hash, typeof(module_ex.hash).sizeof, binary_hash.ptr,
                binary_hash.sizeof);
}

    module_ex.ref_count = 1;

    WASM_C_DUMP_PROC_MEM();

    return module_ext_to_module(module_ex);

destroy_lock:
    os_mutex_destroy(&module_ex.lock);
remove_last:
    bh_vector_remove(cast(Vector*)store.modules,
                     cast(uint)(store.modules.num_elems - 1), null);
unload:
    wasm_runtime_unload(module_ex.module_comm_rt);
free_vec:
    wasm_byte_vec_delete(module_ex.binary);
free_binary:
    wasm_runtime_free(module_ex.binary);
free_module:
    wasm_runtime_free(module_ex);
quit:
    LOG_ERROR("%s failed", __FUNCTION__);
    return null;
}

bool wasm_module_validate(wasm_store_t* store, const(wasm_byte_vec_t)* binary) {
    WASMModuleCommon* module_rt = void;
    char[128] error_buf = 0;

    bh_assert(singleton_engine);

    if (!store || !binary || binary.size > UINT32_MAX) {
        LOG_ERROR("%s failed", __FUNCTION__);
        return false;
    }

    if ((module_rt = wasm_runtime_load(cast(ubyte*)binary.data,
                                       cast(uint)binary.size, error_buf.ptr, 128))) {
        wasm_runtime_unload(module_rt);
        return true;
    }
    else {
        LOG_VERBOSE(error_buf.ptr);
        return false;
    }
}

void wasm_module_delete_internal(wasm_module_t* module_) {
    wasm_module_ex_t* module_ex = void;

    if (!module_) {
        return;
    }

    module_ex = module_to_module_ext(module_);

    os_mutex_lock(&module_ex.lock);

    /* N -> N-1 -> 0 -> UINT32_MAX */
    module_ex.ref_count--;
    if (module_ex.ref_count > 0) {
        os_mutex_unlock(&module_ex.lock);
        return;
    }

    DEINIT_VEC(module_ex.binary, wasm_byte_vec_delete);

    if (module_ex.module_comm_rt) {
        wasm_runtime_unload(module_ex.module_comm_rt);
        module_ex.module_comm_rt = null;
    }

static if (ver.WASM_ENABLE_WASM_CACHE) {
    memset(module_ex.hash, 0, typeof(module_ex.hash).sizeof);
}

    os_mutex_unlock(&module_ex.lock);
}

void wasm_module_delete(wasm_module_t* module_) {
    /* the module will be released when releasing the store */
    cast(void)module_;
}

void wasm_module_imports(const(wasm_module_t)* module_, own* out_) {
    uint i = void, import_func_count = 0, import_memory_count = 0, import_global_count = 0, import_table_count = 0, import_count = 0;
    wasm_byte_vec_t module_name = { 0 }, name = { 0 };
    wasm_externtype_t* extern_type = null;
    wasm_importtype_t* import_type = null;

    if (!module_ || !out_) {
        return;
    }

    if ((cast(const(wasm_module_ex_t)*)(module_)).ref_count == 0)
        return;

static if (ver.WASM_ENABLE_INTERP) {
    if ((*module_).module_type == Wasm_Module_Bytecode) {
        import_func_count = MODULE_INTERP(module_).import_function_count;
        import_global_count = MODULE_INTERP(module_).import_global_count;
        import_memory_count = MODULE_INTERP(module_).import_memory_count;
        import_table_count = MODULE_INTERP(module_).import_table_count;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if ((*module_).module_type == Wasm_Module_AoT) {
        import_func_count = MODULE_AOT(module_).import_func_count;
        import_global_count = MODULE_AOT(module_).import_global_count;
        import_memory_count = MODULE_AOT(module_).import_memory_count;
        import_table_count = MODULE_AOT(module_).import_table_count;
    }
}

    import_count = import_func_count + import_global_count + import_table_count
                   + import_memory_count;

    wasm_importtype_vec_new_uninitialized(out_, import_count);
    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!out_.data) {
        return;
    }

    for (i = 0; i != import_count; ++i) {
        char* module_name_rt = null, field_name_rt = null;

        memset(&module_name, 0, wasm_val_vec_t.sizeof);
        memset(&name, 0, wasm_val_vec_t.sizeof);
        extern_type = null;
        import_type = null;

        if (i < import_func_count) {
            wasm_functype_t* type = null;
            WASMType* type_rt = null;

static if (ver.WASM_ENABLE_INTERP) {
            if ((*module_).module_type == Wasm_Module_Bytecode) {
                WASMImport* import_ = MODULE_INTERP(module_).import_functions + i;
                module_name_rt = import_.u.names.module_name;
                field_name_rt = import_.u.names.field_name;
                type_rt = import_.u.function_.func_type;
            }
}

static if (ver.WASM_ENABLE_AOT) {
            if ((*module_).module_type == Wasm_Module_AoT) {
                AOTImportFunc* import_ = MODULE_AOT(module_).import_funcs + i;
                module_name_rt = import_.module_name;
                field_name_rt = import_.func_name;
                type_rt = import_.func_type;
            }
}

            if (!module_name_rt || !field_name_rt || !type_rt) {
                continue;
            }

            if (((type = wasm_functype_new_internal(type_rt)) == 0)) {
                goto failed;
            }

            extern_type = wasm_functype_as_externtype(type);
        }
        else if (i < import_func_count + import_global_count) {
            wasm_globaltype_t* type = null;
            ubyte val_type_rt = 0;
            bool mutability_rt = 0;

static if (ver.WASM_ENABLE_INTERP) {
            if ((*module_).module_type == Wasm_Module_Bytecode) {
                WASMImport* import_ = MODULE_INTERP(module_).import_globals
                                     + (i - import_func_count);
                module_name_rt = import_.u.names.module_name;
                field_name_rt = import_.u.names.field_name;
                val_type_rt = import_.u.global.type;
                mutability_rt = import_.u.global.is_mutable;
            }
}

static if (ver.WASM_ENABLE_AOT) {
            if ((*module_).module_type == Wasm_Module_AoT) {
                AOTImportGlobal* import_ = MODULE_AOT(module_).import_globals
                                          + (i - import_func_count);
                module_name_rt = import_.module_name;
                field_name_rt = import_.global_name;
                val_type_rt = import_.type;
                mutability_rt = import_.is_mutable;
            }
}

            if (!module_name_rt || !field_name_rt) {
                continue;
            }

            if (((type = wasm_globaltype_new_internal(val_type_rt,
                                                      mutability_rt)) == 0)) {
                goto failed;
            }

            extern_type = wasm_globaltype_as_externtype(type);
        }
        else if (i < import_func_count + import_global_count
                         + import_memory_count) {
            wasm_memorytype_t* type = null;
            uint min_page = 0, max_page = 0;

static if (ver.WASM_ENABLE_INTERP) {
            if ((*module_).module_type == Wasm_Module_Bytecode) {
                WASMImport* import_ = MODULE_INTERP(module_).import_memories
                    + (i - import_func_count - import_global_count);
                module_name_rt = import_.u.names.module_name;
                field_name_rt = import_.u.names.field_name;
                min_page = import_.u.memory.init_page_count;
                max_page = import_.u.memory.max_page_count;
            }
}

static if (ver.WASM_ENABLE_AOT) {
            if ((*module_).module_type == Wasm_Module_AoT) {
                AOTImportMemory* import_ = MODULE_AOT(module_).import_memories
                    + (i - import_func_count - import_global_count);
                module_name_rt = import_.module_name;
                field_name_rt = import_.memory_name;
                min_page = import_.mem_init_page_count;
                max_page = import_.mem_max_page_count;
            }
}

            if (!module_name_rt || !field_name_rt) {
                continue;
            }

            if (((type = wasm_memorytype_new_internal(min_page, max_page)) == 0)) {
                goto failed;
            }

            extern_type = wasm_memorytype_as_externtype(type);
        }
        else {
            wasm_tabletype_t* type = null;
            ubyte elem_type_rt = 0;
            uint min_size = 0, max_size = 0;

static if (ver.WASM_ENABLE_INTERP) {
            if ((*module_).module_type == Wasm_Module_Bytecode) {
                WASMImport* import_ = MODULE_INTERP(module_).import_tables
                    + (i - import_func_count - import_global_count
                       - import_memory_count);
                module_name_rt = import_.u.names.module_name;
                field_name_rt = import_.u.names.field_name;
                elem_type_rt = import_.u.table.elem_type;
                min_size = import_.u.table.init_size;
                max_size = import_.u.table.max_size;
            }
}

static if (ver.WASM_ENABLE_AOT) {
            if ((*module_).module_type == Wasm_Module_AoT) {
                AOTImportTable* import_ = MODULE_AOT(module_).import_tables
                    + (i - import_func_count - import_global_count
                       - import_memory_count);
                module_name_rt = import_.module_name;
                field_name_rt = import_.table_name;
                elem_type_rt = import_.elem_type;
                min_size = import_.table_init_size;
                max_size = import_.table_max_size;
            }
}

            if (!module_name_rt || !field_name_rt) {
                continue;
            }

            if (((type = wasm_tabletype_new_internal(elem_type_rt, min_size,
                                                     max_size)) == 0)) {
                goto failed;
            }

            extern_type = wasm_tabletype_as_externtype(type);
        }

        bh_assert(extern_type);

        wasm_name_new_from_string(&module_name, module_name_rt);
        if (strlen(module_name_rt) && !module_name.data) {
            goto failed;
        }

        wasm_name_new_from_string(&name, field_name_rt);
        if (strlen(field_name_rt) && !name.data) {
            goto failed;
        }

        if (((import_type =
                  wasm_importtype_new(&module_name, &name, extern_type)) == 0)) {
            goto failed;
        }

        if (!bh_vector_append(cast(Vector*)out_, &import_type)) {
            goto failed_importtype_new;
        }

        continue;

    failed:
        wasm_byte_vec_delete(&module_name);
        wasm_byte_vec_delete(&name);
        wasm_externtype_delete(extern_type);
    failed_importtype_new:
        wasm_importtype_delete(import_type);
    }
}

void wasm_module_exports(const(wasm_module_t)* module_, wasm_exporttype_vec_t* out_) {
    uint i = void, export_count = 0;
    wasm_byte_vec_t name = { 0 };
    wasm_externtype_t* extern_type = null;
    wasm_exporttype_t* export_type = null;

    if (!module_ || !out_) {
        return;
    }

    if ((cast(const(wasm_module_ex_t)*)(module_)).ref_count == 0)
        return;

static if (ver.WASM_ENABLE_INTERP) {
    if ((*module_).module_type == Wasm_Module_Bytecode) {
        export_count = MODULE_INTERP(module_).export_count;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if ((*module_).module_type == Wasm_Module_AoT) {
        export_count = MODULE_AOT(module_).export_count;
    }
}

    wasm_exporttype_vec_new_uninitialized(out_, export_count);
    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!out_.data) {
        return;
    }

    for (i = 0; i != export_count; i++) {
        WASMExport* export_ = null;
static if (ver.WASM_ENABLE_INTERP) {
        if ((*module_).module_type == Wasm_Module_Bytecode) {
            export_ = MODULE_INTERP(module_).exports + i;
        }
}

static if (ver.WASM_ENABLE_AOT) {
        if ((*module_).module_type == Wasm_Module_AoT) {
            export_ = MODULE_AOT(module_).exports + i;
        }
}

        if (!export_) {
            continue;
        }

        /* byte* -> wasm_byte_vec_t */
        wasm_name_new_from_string(&name, export_.name);
        if (strlen(export_.name) && !name.data) {
            goto failed;
        }

        /* WASMExport -> (WASMType, (uint8, bool)) -> (wasm_functype_t,
         * wasm_globaltype_t) -> wasm_externtype_t*/
        switch (export_.kind) {
            case EXPORT_KIND_FUNC:
            {
                wasm_functype_t* type = null;
                WASMType* type_rt = void;

                if (!wasm_runtime_get_export_func_type(*module_, export_,
                                                       &type_rt)) {
                    goto failed;
                }

                if (((type = wasm_functype_new_internal(type_rt)) == 0)) {
                    goto failed;
                }

                extern_type = wasm_functype_as_externtype(type);
                break;
            }
            case EXPORT_KIND_GLOBAL:
            {
                wasm_globaltype_t* type = null;
                ubyte val_type_rt = 0;
                bool mutability_rt = 0;

                if (!wasm_runtime_get_export_global_type(
                        *module_, export_, &val_type_rt, &mutability_rt)) {
                    goto failed;
                }

                if (((type = wasm_globaltype_new_internal(val_type_rt,
                                                          mutability_rt)) == 0)) {
                    goto failed;
                }

                extern_type = wasm_globaltype_as_externtype(type);
                break;
            }
            case EXPORT_KIND_MEMORY:
            {
                wasm_memorytype_t* type = null;
                uint min_page = 0, max_page = 0;

                if (!wasm_runtime_get_export_memory_type(
                        *module_, export_, &min_page, &max_page)) {
                    goto failed;
                }

                if (((type =
                          wasm_memorytype_new_internal(min_page, max_page)) == 0)) {
                    goto failed;
                }

                extern_type = wasm_memorytype_as_externtype(type);
                break;
            }
            case EXPORT_KIND_TABLE:
            {
                wasm_tabletype_t* type = null;
                ubyte elem_type_rt = 0;
                uint min_size = 0, max_size = 0;

                if (!wasm_runtime_get_export_table_type(
                        *module_, export_, &elem_type_rt, &min_size, &max_size)) {
                    goto failed;
                }

                if (((type = wasm_tabletype_new_internal(elem_type_rt, min_size,
                                                         max_size)) == 0)) {
                    goto failed;
                }

                extern_type = wasm_tabletype_as_externtype(type);
                break;
            }
            default:
            {
                LOG_WARNING("%s meets unsupported type %u", __FUNCTION__,
                            export_.kind);
                break;
            }
        }

        if (((export_type = wasm_exporttype_new(&name, extern_type)) == 0)) {
            goto failed;
        }

        if (!(bh_vector_append(cast(Vector*)out_, &export_type))) {
            goto failed_exporttype_new;
        }
    }

    return;

failed:
    wasm_byte_vec_delete(&name);
    wasm_externtype_delete(extern_type);
failed_exporttype_new:
    wasm_exporttype_delete(export_type);
    wasm_exporttype_vec_delete(out_);
}

static if (WASM_ENABLE_JIT == 0 || ver.WASM_ENABLE_LAZY_JIT) {
void wasm_module_serialize(wasm_module_t* module_, own* out_) {
    cast(void)module_;
    cast(void)out_;
    LOG_ERROR("only supported serialization in JIT with eager compilation");
}

own* wasm_module_deserialize(wasm_store_t* module_, const(wasm_byte_vec_t)* binary) {
    cast(void)module_;
    cast(void)binary;
    LOG_ERROR("only supported deserialization in JIT with eager compilation");
    return null;
}
} else {

extern ubyte* aot_emit_aot_file_buf(AOTCompContext* comp_ctx, AOTCompData* comp_data, uint* p_aot_file_size);
void wasm_module_serialize(wasm_module_t* module_, own* out_) {
    wasm_module_ex_t* module_ex = void;
    AOTCompContext* comp_ctx = void;
    AOTCompData* comp_data = void;
    ubyte* aot_file_buf = null;
    uint aot_file_size = 0;

    if (!module_ || !out_)
        return;

    if ((cast(const(wasm_module_ex_t)*)(module_)).ref_count == 0)
        return;

    module_ex = module_to_module_ext(module_);
    comp_ctx = (cast(WASMModule*)(module_ex.module_comm_rt)).comp_ctx;
    comp_data = (cast(WASMModule*)(module_ex.module_comm_rt)).comp_data;
    bh_assert(comp_ctx != null && comp_data != null);

    aot_file_buf = aot_emit_aot_file_buf(comp_ctx, comp_data, &aot_file_size);
    if (!aot_file_buf)
        return;

    wasm_byte_vec_new(out_, aot_file_size, cast(wasm_byte_t*)aot_file_buf);
    wasm_runtime_free(aot_file_buf);
    return;
}

own* wasm_module_deserialize(wasm_store_t* store, const(wasm_byte_vec_t)* binary) {
    return wasm_module_new(store, binary);
}
}

wasm_module_t* wasm_module_obtain(wasm_store_t* store, wasm_shared_module_t* shared_module) {
    wasm_module_ex_t* module_ex = null;

    if (!store || !shared_module)
        return null;

    module_ex = cast(wasm_module_ex_t*)shared_module;

    os_mutex_lock(&module_ex.lock);

    /* deleting the module... */
    if (module_ex.ref_count == 0) {
        LOG_WARNING("wasm_module_obtain re-enter a module under deleting.");
        os_mutex_unlock(&module_ex.lock);
        return null;
    }

    /* add it to a watching list in store */
    if (!bh_vector_append(cast(Vector*)store.modules, &module_ex)) {
        os_mutex_unlock(&module_ex.lock);
        return null;
    }

    module_ex.ref_count++;
    os_mutex_unlock(&module_ex.lock);

    return cast(wasm_module_t*)shared_module;
}

wasm_shared_module_t* wasm_module_share(wasm_module_t* module_) {
    wasm_module_ex_t* module_ex = null;

    if (!module_)
        return null;

    module_ex = cast(wasm_module_ex_t*)module_;

    os_mutex_lock(&module_ex.lock);

    /* deleting the module... */
    if (module_ex.ref_count == 0) {
        LOG_WARNING("wasm_module_share re-enter a module under deleting.");
        os_mutex_unlock(&module_ex.lock);
        return null;
    }

    module_ex.ref_count++;

    os_mutex_unlock(&module_ex.lock);

    return cast(wasm_shared_module_t*)module_;
}

void wasm_shared_module_delete(own* shared_module) {
    wasm_module_delete_internal(cast(wasm_module_t*)shared_module);
}

wasm_func_t* wasm_func_new_basic(wasm_store_t* store, const(wasm_functype_t)* type, wasm_func_callback_t func_callback) {
    wasm_func_t* func = null;

    if (!type) {
        goto failed;
    }

    if (((func = malloc_internal(wasm_func_t.sizeof)) == 0)) {
        goto failed;
    }

    func.store = store;
    func.kind = WASM_EXTERN_FUNC;
    func.func_idx_rt = (uint16)-1;
    func.with_env = false;
    func.u.cb = func_callback;

    if (((func.type = wasm_functype_copy(type)) == 0)) {
        goto failed;
    }

    RETURN_OBJ(func, wasm_func_delete);
}

wasm_func_t* wasm_func_new_with_env_basic(wasm_store_t* store, const(wasm_functype_t)* type, wasm_func_callback_with_env_t callback, void* env, void function(void*) finalizer) {
    wasm_func_t* func = null;

    if (!type) {
        goto failed;
    }

    if (((func = malloc_internal(wasm_func_t.sizeof)) == 0)) {
        goto failed;
    }

    func.store = store;
    func.kind = WASM_EXTERN_FUNC;
    func.func_idx_rt = (uint16)-1;
    func.with_env = true;
    func.u.cb_env.cb = callback;
    func.u.cb_env.env = env;
    func.u.cb_env.finalizer = finalizer;

    if (((func.type = wasm_functype_copy(type)) == 0)) {
        goto failed;
    }

    RETURN_OBJ(func, wasm_func_delete);
}

wasm_func_t* wasm_func_new(wasm_store_t* store, const(wasm_functype_t)* type, wasm_func_callback_t callback) {
    bh_assert(singleton_engine);
    if (!callback) {
        return null;
    }
    return wasm_func_new_basic(store, type, callback);
}

wasm_func_t* wasm_func_new_with_env(wasm_store_t* store, const(wasm_functype_t)* type, wasm_func_callback_with_env_t callback, void* env, void function(void*) finalizer) {
    bh_assert(singleton_engine);
    if (!callback) {
        return null;
    }
    return wasm_func_new_with_env_basic(store, type, callback, env, finalizer);
}

wasm_func_t* wasm_func_new_internal(wasm_store_t* store, ushort func_idx_rt, WASMModuleInstanceCommon* inst_comm_rt) {
    wasm_func_t* func = null;
    WASMType* type_rt = null;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return null;
    }

    func = malloc_internal(wasm_func_t.sizeof);
    if (!func) {
        goto failed;
    }

    func.kind = WASM_EXTERN_FUNC;

static if (ver.WASM_ENABLE_INTERP) {
    if (inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        bh_assert(func_idx_rt
                  < (cast(WASMModuleInstance*)inst_comm_rt).e.function_count);
        WASMFunctionInstance* func_interp = (cast(WASMModuleInstance*)inst_comm_rt).e.functions + func_idx_rt;
        type_rt = func_interp.is_import_func
                      ? func_interp.u.func_import.func_type
                      : func_interp.u.func.func_type;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (inst_comm_rt.module_type == Wasm_Module_AoT) {
        /* use same index to trace the function type in AOTFuncType **func_types
         */
        AOTModule* module_aot = cast(AOTModule*)(cast(AOTModuleInstance*)inst_comm_rt).module_;
        if (func_idx_rt < module_aot.import_func_count) {
            type_rt = (module_aot.import_funcs + func_idx_rt).func_type;
        }
        else {
            type_rt =
                module_aot.func_types[module_aot.func_type_indexes
                                           [func_idx_rt
                                            - module_aot.import_func_count]];
        }
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!type_rt) {
        goto failed;
    }

    func.type = wasm_functype_new_internal(type_rt);
    if (!func.type) {
        goto failed;
    }

    /* will add name information when processing "exports" */
    func.store = store;
    func.module_name = null;
    func.name = null;
    func.func_idx_rt = func_idx_rt;
    func.inst_comm_rt = inst_comm_rt;
    return func;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_func_delete(func);
    return null;
}

void wasm_func_delete(wasm_func_t* func) {
    if (!func) {
        return;
    }

    if (func.type) {
        wasm_functype_delete(func.type);
        func.type = null;
    }

    if (func.with_env) {
        if (func.u.cb_env.finalizer) {
            func.u.cb_env.finalizer(func.u.cb_env.env);
            func.u.cb_env.finalizer = null;
            func.u.cb_env.env = null;
        }
    }

     wasm_runtime_free(func);
}

own* wasm_func_copy(const(wasm_func_t)* func) {
    wasm_func_t* cloned = null;

    if (!func) {
        return null;
    }

    if (!(cloned = func.with_env ? wasm_func_new_with_env_basic(
                       func.store, func.type, func.u.cb_env.cb,
                       func.u.cb_env.env, func.u.cb_env.finalizer)
                                  : wasm_func_new_basic(func.store, func.type,
                                                        func.u.cb))) {
        goto failed;
    }

    cloned.func_idx_rt = func.func_idx_rt;
    cloned.inst_comm_rt = func.inst_comm_rt;

    RETURN_OBJ(cloned, &wasm_func_delete);
}

own* wasm_func_type(const(wasm_func_t)* func) {
    if (!func) {
        return null;
    }
    return wasm_functype_copy(func.type);
}

bool params_to_argv(const(wasm_val_vec_t)* params, const(wasm_valtype_vec_t)* param_defs, uint* argv, uint* ptr_argc) {
    size_t i = 0;

    if (!param_defs.num_elems) {
        return true;
    }

    if (!params || !params.num_elems || !params.size || !params.data) {
        LOG_ERROR("the parameter params is invalid");
        return false;
    }

    *ptr_argc = 0;
    for (i = 0; i < param_defs.num_elems; ++i) {
        const(wasm_val_t)* param = params.data + i;
        bh_assert((*(param_defs.data + i)).kind == param.kind);

        switch (param.kind) {
            case WASM_I32:
                *cast(int*)argv = param.of.i32;
                argv += 1;
                *ptr_argc += 1;
                break;
            case WASM_I64:
                *cast(long*)argv = param.of.i64;
                argv += 2;
                *ptr_argc += 2;
                break;
            case WASM_F32:
                *cast(float32*)argv = param.of.f32;
                argv += 1;
                *ptr_argc += 1;
                break;
            case WASM_F64:
                *cast(float64*)argv = param.of.f64;
                argv += 2;
                *ptr_argc += 2;
                break;
static if (ver.WASM_ENABLE_REF_TYPES) {
            case WASM_ANYREF:
                *cast(uintptr_t*)argv = cast(uintptr_t)param.of.ref_;
                argv += uintptr_t.sizeof / uint32.sizeof;
                *ptr_argc += 1;
                break;
}
            default:
                LOG_WARNING("unexpected parameter val type %d", param.kind);
                return false;
        }
    }

    return true;
}

bool argv_to_results(const(uint)* argv, const(wasm_valtype_vec_t)* result_defs, wasm_val_vec_t* results) {
    size_t i = 0, argv_i = 0;
    wasm_val_t* result = void;

    if (!result_defs.num_elems) {
        return true;
    }

    if (!results || !results.size || !results.data) {
        LOG_ERROR("the parameter results is invalid");
        return false;
    }

    for (i = 0, result = results.data, argv_i = 0; i < result_defs.num_elems;
         i++, result++) {
        switch (result_defs.data[i].kind) {
            case WASM_I32:
            {
                result.kind = WASM_I32;
                result.of.i32 = *cast(int*)(argv + argv_i);
                argv_i += 1;
                break;
            }
            case WASM_I64:
            {
                result.kind = WASM_I64;
                result.of.i64 = *cast(long*)(argv + argv_i);
                argv_i += 2;
                break;
            }
            case WASM_F32:
            {
                result.kind = WASM_F32;
                result.of.f32 = *cast(float32*)(argv + argv_i);
                argv_i += 1;
                break;
            }
            case WASM_F64:
            {
                result.kind = WASM_F64;
                result.of.f64 = *cast(float64*)(argv + argv_i);
                argv_i += 2;
                break;
            }
static if (ver.WASM_ENABLE_REF_TYPES) {
            case WASM_ANYREF:
            {
                result.kind = WASM_ANYREF;
                result.of.ref_ =
                    cast(wasm_ref_t*)(*cast(uintptr_t*)(argv + argv_i));
                argv_i += uintptr_t.sizeof / uint32.sizeof;
                break;
            }
}
            default:
                LOG_WARNING("%s meets unsupported type: %d", __FUNCTION__,
                            result_defs.data[i].kind);
                return false;
        }
    }

    return true;
}

wasm_trap_t* wasm_func_call(const(wasm_func_t)* func, const(wasm_val_vec_t)* params, wasm_val_vec_t* results) {
    /* parameters count as if all are uint32 */
    /* a int64 or float64 parameter means 2 */
    uint argc = 0;
    /* a parameter list and a return value list */
    uint[32] argv_buf = 0; uint* argv = argv_buf;
    WASMFunctionInstanceCommon* func_comm_rt = null;
    WASMExecEnv* exec_env = null;
    size_t param_count = void, result_count = void, alloc_count = void;

    if (!func) {
        return null;
    }

    if (!func.inst_comm_rt) {
        wasm_name_t message = { 0 };
        wasm_trap_t* trap = void;

        wasm_name_new_from_string(&message, "failed to call unlinked function");
        trap = wasm_trap_new(func.store, &message);
        wasm_byte_vec_delete(&message);

        return trap;
    }

    bh_assert(func.type);

static if (ver.WASM_ENABLE_INTERP) {
    if (func.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        func_comm_rt = (cast(WASMModuleInstance*)func.inst_comm_rt).e.functions
                       + func.func_idx_rt;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (func.inst_comm_rt.module_type == Wasm_Module_AoT) {
        if (((func_comm_rt = func.func_comm_rt) == 0)) {
            AOTModuleInstance* inst_aot = cast(AOTModuleInstance*)func.inst_comm_rt;
            AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;
            uint export_i = 0, export_func_j = 0;

            for (; export_i < module_aot.export_count; ++export_i) {
                AOTExport* export_ = module_aot.exports + export_i;
                if (export_.kind == EXPORT_KIND_FUNC) {
                    if (export_.index == func.func_idx_rt) {
                        func_comm_rt =
                            cast(AOTFunctionInstance*)inst_aot.export_functions
                            + export_func_j;
                        (cast(wasm_func_t*)func).func_comm_rt = func_comm_rt;
                        break;
                    }
                    export_func_j++;
                }
            }
        }
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!func_comm_rt) {
        goto failed;
    }

    param_count = wasm_func_param_arity(func);
    result_count = wasm_func_result_arity(func);

    alloc_count = (param_count > result_count) ? param_count : result_count;
    if (alloc_count > cast(size_t)argv_buf.sizeof / uint64.sizeof) {
        if (((argv = malloc_internal(sizeof(uint64) * alloc_count)) == 0)) {
            goto failed;
        }
    }

    /* copy parametes */
    if (param_count
        && !params_to_argv(params, wasm_functype_params(func.type), argv,
                           &argc)) {
        goto failed;
    }

    exec_env = wasm_runtime_get_exec_env_singleton(func.inst_comm_rt);
    if (!exec_env) {
        goto failed;
    }

    wasm_runtime_set_exception(func.inst_comm_rt, null);
    if (!wasm_runtime_call_wasm(exec_env, func_comm_rt, argc, argv)) {
        if (wasm_runtime_get_exception(func.inst_comm_rt)) {
            LOG_DEBUG(wasm_runtime_get_exception(func.inst_comm_rt));
            goto failed;
        }
    }

    /* copy results */
    if (result_count) {
        if (!argv_to_results(argv, wasm_functype_results(func.type),
                             results)) {
            goto failed;
        }
        results.num_elems = result_count;
        results.size = result_count;
    }

    if (argv != argv_buf.ptr)
        wasm_runtime_free(argv);
    return null;

failed:
    if (argv != argv_buf.ptr)
        wasm_runtime_free(argv);

    return wasm_trap_new_internal(
        func.store, func.inst_comm_rt,
        wasm_runtime_get_exception(func.inst_comm_rt));
}

size_t wasm_func_param_arity(const(wasm_func_t)* func) {
    if (!func || !func.type || !func.type.params) {
        return 0;
    }
    return func.type.params.num_elems;
}

size_t wasm_func_result_arity(const(wasm_func_t)* func) {
    if (!func || !func.type || !func.type.results) {
        return 0;
    }
    return func.type.results.num_elems;
}

wasm_global_t* wasm_global_new(wasm_store_t* store, const(wasm_globaltype_t)* global_type, const(wasm_val_t)* init) {
    wasm_global_t* global = null;

    bh_assert(singleton_engine);

    if (!global_type || !init) {
        goto failed;
    }

    global = malloc_internal(wasm_global_t.sizeof);
    if (!global) {
        goto failed;
    }

    global.store = store;
    global.kind = WASM_EXTERN_GLOBAL;
    global.type = wasm_globaltype_copy(global_type);
    if (!global.type) {
        goto failed;
    }

    global.init = malloc_internal(wasm_val_t.sizeof);
    if (!global.init) {
        goto failed;
    }

    wasm_val_copy(global.init, init);
    /* TODO: how to check if above is failed */

    return global;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return null;
}

/* almost same with wasm_global_new */
wasm_global_t* wasm_global_copy(const(wasm_global_t)* src) {
    wasm_global_t* global = null;

    if (!src) {
        return null;
    }

    global = malloc_internal(wasm_global_t.sizeof);
    if (!global) {
        goto failed;
    }

    global.kind = WASM_EXTERN_GLOBAL;
    global.type = wasm_globaltype_copy(src.type);
    if (!global.type) {
        goto failed;
    }

    global.init = malloc_internal(wasm_val_t.sizeof);
    if (!global.init) {
        goto failed;
    }

    wasm_val_copy(global.init, src.init);

    global.global_idx_rt = src.global_idx_rt;
    global.inst_comm_rt = src.inst_comm_rt;

    return global;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return null;
}

void wasm_global_delete(wasm_global_t* global) {
    if (!global) {
        return;
    }

    if (global.init) {
        wasm_val_delete(global.init);
        global.init = null;
    }

    if (global.type) {
        wasm_globaltype_delete(global.type);
        global.type = null;
    }

     wasm_runtime_free(global);
}

static if (ver.WASM_ENABLE_INTERP) {
bool interp_global_set(const(WASMModuleInstance)* inst_interp, ushort global_idx_rt, const(wasm_val_t)* v) {
    const(WASMGlobalInstance)* global_interp = inst_interp.e.globals + global_idx_rt;
    ubyte val_type_rt = global_interp.type;
static if (ver.WASM_ENABLE_MULTI_MODULE) {
    ubyte* data = global_interp.import_global_inst
                      ? global_interp.import_module_inst.global_data
                            + global_interp.import_global_inst.data_offset
                      : inst_interp.global_data + global_interp.data_offset;
} else {
    ubyte* data = inst_interp.global_data + global_interp.data_offset;
}

    return wasm_val_to_rt_val(cast(WASMModuleInstanceCommon*)inst_interp,
                              val_type_rt, v, data);
}

bool interp_global_get(const(WASMModuleInstance)* inst_interp, ushort global_idx_rt, wasm_val_t* out_) {
    WASMGlobalInstance* global_interp = inst_interp.e.globals + global_idx_rt;
    ubyte val_type_rt = global_interp.type;
static if (ver.WASM_ENABLE_MULTI_MODULE) {
    ubyte* data = global_interp.import_global_inst
                      ? global_interp.import_module_inst.global_data
                            + global_interp.import_global_inst.data_offset
                      : inst_interp.global_data + global_interp.data_offset;
} else {
    ubyte* data = inst_interp.global_data + global_interp.data_offset;
}

    return rt_val_to_wasm_val(data, val_type_rt, out_);
}
}

static if (ver.WASM_ENABLE_AOT) {
bool aot_global_set(const(AOTModuleInstance)* inst_aot, ushort global_idx_rt, const(wasm_val_t)* v) {
    AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;
    ubyte val_type_rt;
    uint data_offset ;
    void* data;

    if (global_idx_rt < module_aot.import_global_count) {
        data_offset = module_aot.import_globals[global_idx_rt].data_offset;
        val_type_rt = module_aot.import_globals[global_idx_rt].type;
    }
    else {
        data_offset =
            module_aot.globals[global_idx_rt - module_aot.import_global_count]
                .data_offset;
        val_type_rt =
            module_aot.globals[global_idx_rt - module_aot.import_global_count]
                .type;
    }

    data = cast(void*)(inst_aot.global_data + data_offset);
    return wasm_val_to_rt_val(cast(WASMModuleInstanceCommon*)inst_aot, val_type_rt,
                              v, data);
}

bool aot_global_get(const(AOTModuleInstance)* inst_aot, ushort global_idx_rt, wasm_val_t* out_) {
    AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;
    ubyte val_type_rt = 0;
    uint data_offset = 0;
    ubyte* data = null;

    if (global_idx_rt < module_aot.import_global_count) {
        data_offset = module_aot.import_globals[global_idx_rt].data_offset;
        val_type_rt = module_aot.import_globals[global_idx_rt].type;
    }
    else {
        data_offset =
            module_aot.globals[global_idx_rt - module_aot.import_global_count]
                .data_offset;
        val_type_rt =
            module_aot.globals[global_idx_rt - module_aot.import_global_count]
                .type;
    }

    data = inst_aot.global_data + data_offset;
    return rt_val_to_wasm_val(data, val_type_rt, out_);
}
}

void wasm_global_set(wasm_global_t* global, const(wasm_val_t)* v) {
    if (!global || !v || !global.inst_comm_rt) {
        return;
    }

static if (ver.WASM_ENABLE_INTERP) {
    if (global.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        cast(void)interp_global_set(cast(WASMModuleInstance*)global.inst_comm_rt,
                                global.global_idx_rt, v);
        return;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (global.inst_comm_rt.module_type == Wasm_Module_AoT) {
        cast(void)aot_global_set(cast(AOTModuleInstance*)global.inst_comm_rt,
                             global.global_idx_rt, v);
        return;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    UNREACHABLE();
}

void wasm_global_get(const(wasm_global_t)* global, wasm_val_t* out_) {
    if (!global || !out_) {
        return;
    }

    if (!global.inst_comm_rt) {
        return;
    }

    memset(out_, 0, wasm_val_t.sizeof);

static if (ver.WASM_ENABLE_INTERP) {
    if (global.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        cast(void)interp_global_get(cast(WASMModuleInstance*)global.inst_comm_rt,
                                global.global_idx_rt, out_);
        return;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (global.inst_comm_rt.module_type == Wasm_Module_AoT) {
        cast(void)aot_global_get(cast(AOTModuleInstance*)global.inst_comm_rt,
                             global.global_idx_rt, out_);
        return;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    UNREACHABLE();
}

wasm_global_t* wasm_global_new_internal(wasm_store_t* store, ushort global_idx_rt, WASMModuleInstanceCommon* inst_comm_rt) {
    wasm_global_t* global = null;
    ubyte val_type_rt = 0;
    bool is_mutable = 0;
    bool init = false;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return null;
    }

    global = malloc_internal(wasm_global_t.sizeof);
    if (!global) {
        goto failed;
    }

    global.store = store;
    global.kind = WASM_EXTERN_GLOBAL;

static if (ver.WASM_ENABLE_INTERP) {
    if (inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        WASMGlobalInstance* global_interp = (cast(WASMModuleInstance*)inst_comm_rt).e.globals + global_idx_rt;
        val_type_rt = global_interp.type;
        is_mutable = global_interp.is_mutable;
        init = true;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (inst_comm_rt.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* inst_aot = cast(AOTModuleInstance*)inst_comm_rt;
        AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;

        init = true;

        if (global_idx_rt < module_aot.import_global_count) {
            AOTImportGlobal* global_import_aot = module_aot.import_globals + global_idx_rt;
            val_type_rt = global_import_aot.type;
            is_mutable = global_import_aot.is_mutable;
        }
        else {
            AOTGlobal* global_aot = module_aot.globals
                + (global_idx_rt - module_aot.import_global_count);
            val_type_rt = global_aot.type;
            is_mutable = global_aot.is_mutable;
        }
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!init) {
        goto failed;
    }

    global.type = wasm_globaltype_new_internal(val_type_rt, is_mutable);
    if (!global.type) {
        goto failed;
    }

    global.init = malloc_internal(wasm_val_t.sizeof);
    if (!global.init) {
        goto failed;
    }

static if (ver.WASM_ENABLE_INTERP) {
    if (inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        interp_global_get(cast(WASMModuleInstance*)inst_comm_rt, global_idx_rt,
                          global.init);
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (inst_comm_rt.module_type == Wasm_Module_AoT) {
        aot_global_get(cast(AOTModuleInstance*)inst_comm_rt, global_idx_rt,
                       global.init);
    }
}

    global.inst_comm_rt = inst_comm_rt;
    global.global_idx_rt = global_idx_rt;

    return global;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return null;
}

wasm_globaltype_t* wasm_global_type(const(wasm_global_t)* global) {
    if (!global) {
        return null;
    }
    return wasm_globaltype_copy(global.type);
}

wasm_table_t* wasm_table_new_basic(wasm_store_t* store, const(wasm_tabletype_t)* type) {
    wasm_table_t* table = null;

    if (((table = malloc_internal(wasm_table_t.sizeof)) == 0)) {
        goto failed;
    }

    table.store = store;
    table.kind = WASM_EXTERN_TABLE;

    if (((table.type = wasm_tabletype_copy(type)) == 0)) {
        goto failed;
    }

    RETURN_OBJ(table, wasm_table_delete);
}

wasm_table_t* wasm_table_new_internal(wasm_store_t* store, ushort table_idx_rt, WASMModuleInstanceCommon* inst_comm_rt) {
    wasm_table_t* table = null;
    ubyte val_type_rt = 0;
    uint init_size = 0, max_size = 0;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return null;
    }

    if (((table = malloc_internal(wasm_table_t.sizeof)) == 0)) {
        goto failed;
    }

    table.store = store;
    table.kind = WASM_EXTERN_TABLE;

    if (!wasm_runtime_get_table_inst_elem_type(
            inst_comm_rt, table_idx_rt, &val_type_rt, &init_size, &max_size)) {
        /*
         * a wrong combination of module filetype and compilation flags
         * leads to below branch
         */
        goto failed;
    }

    if (((table.type =
              wasm_tabletype_new_internal(val_type_rt, init_size, max_size)) == 0)) {
        goto failed;
    }

    table.inst_comm_rt = inst_comm_rt;
    table.table_idx_rt = table_idx_rt;

    RETURN_OBJ(table, wasm_table_delete);
}

/* will not actually apply this new table into the runtime */
wasm_table_t* wasm_table_new(wasm_store_t* store, const(wasm_tabletype_t)* table_type, wasm_ref_t* init) {
    wasm_table_t* table = void;
    cast(void)init;

    bh_assert(singleton_engine);

    if ((table = wasm_table_new_basic(store, table_type))) {
        table.store = store;
    }

    return table;
}

wasm_table_t* wasm_table_copy(const(wasm_table_t)* src) {
    wasm_table_t* table = void;

    if (((table = wasm_table_new_basic(src.store, src.type)) == 0)) {
        return null;
    }

    table.table_idx_rt = src.table_idx_rt;
    table.inst_comm_rt = src.inst_comm_rt;
    return table;
}

void wasm_table_delete(wasm_table_t* table) {
    if (!table) {
        return;
    }

    if (table.type) {
        wasm_tabletype_delete(table.type);
        table.type = null;
    }

     wasm_runtime_free(table);
}

wasm_tabletype_t* wasm_table_type(const(wasm_table_t)* table) {
    if (!table) {
        return null;
    }
    return wasm_tabletype_copy(table.type);
}

own* wasm_table_get(const(wasm_table_t)* table, wasm_table_size_t index) {
    uint ref_idx = NULL_REF;

    if (!table || !table.inst_comm_rt) {
        return null;
    }

static if (ver.WASM_ENABLE_INTERP) {
    if (table.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        WASMTableInstance* table_interp = (cast(WASMModuleInstance*)table.inst_comm_rt)
                .tables[table.table_idx_rt];
        if (index >= table_interp.cur_size) {
            return null;
        }
        ref_idx = table_interp.elems[index];
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (table.inst_comm_rt.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* inst_aot = cast(AOTModuleInstance*)table.inst_comm_rt;
        AOTTableInstance* table_aot = inst_aot.tables[table.table_idx_rt];
        if (index >= table_aot.cur_size) {
            return null;
        }
        ref_idx = table_aot.elems[index];
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (ref_idx == NULL_REF) {
        return null;
    }

if ((ver.WASM_ENABLE_REF_TYPES) &&
     (table.type.val_type.kind == WASM_ANYREF)) {
        void* externref_obj = void;
        if (!wasm_externref_ref2obj(ref_idx, &externref_obj)) {
            return null;
        }

        return externref_obj;
    }
    else
    {
        return wasm_ref_new_internal(table.store, WASM_REF_func, ref_idx,
                                     table.inst_comm_rt);
    }
}

bool wasm_table_set(wasm_table_t* table, wasm_table_size_t index, own* ref_) {
    uint* p_ref_idx = null;
    uint function_count = 0;

    if (!table || !table.inst_comm_rt) {
        return false;
    }

    if (ref_
/+
	#if ver.WASM_ENABLE_REF_TYPES
        && !(WASM_REF_foreign == ref_.kind
             && WASM_ANYREF == table.type.val_type.kind)
#endif
	+/
        && !(WASM_REF_func == ref_.kind
             && WASM_FUNCREF == table.type.val_type.kind)) {
        return false;
    }

static if (ver.WASM_ENABLE_INTERP) {
    if (table.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        WASMTableInstance* table_interp = (cast(WASMModuleInstance*)table.inst_comm_rt)
                .tables[table.table_idx_rt];

        if (index >= table_interp.cur_size) {
            return false;
        }

        p_ref_idx = table_interp.elems + index;
        function_count =
            (cast(WASMModuleInstance*)table.inst_comm_rt).e.function_count;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (table.inst_comm_rt.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* inst_aot = cast(AOTModuleInstance*)table.inst_comm_rt;
        AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;
        AOTTableInstance* table_aot = inst_aot.tables[table.table_idx_rt];

        if (index >= table_aot.cur_size) {
            return false;
        }

        p_ref_idx = table_aot.elems + index;
        function_count = module_aot.func_count;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!p_ref_idx) {
        return false;
    }

 if (!(ver.WASM_ENABLE_REF_TYPES) &&
     (table.type.val_type.kind == WASM_ANYREF)) {
        return wasm_externref_obj2ref(table.inst_comm_rt, ref_, p_ref_idx);
    }
    else
    {
        if (ref_) {
            if (NULL_REF != ref_.ref_idx_rt) {
                if (ref_.ref_idx_rt >= function_count) {
                    return false;
                }
            }
            *p_ref_idx = ref_.ref_idx_rt;
            wasm_ref_delete(ref_);
        }
        else {
            *p_ref_idx = NULL_REF;
        }
    }

    return true;
}

wasm_table_size_t wasm_table_size(const(wasm_table_t)* table) {
    if (!table || !table.inst_comm_rt) {
        return 0;
    }

static if (ver.WASM_ENABLE_INTERP) {
    if (table.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        WASMTableInstance* table_interp = (cast(WASMModuleInstance*)table.inst_comm_rt)
                .tables[table.table_idx_rt];
        return table_interp.cur_size;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (table.inst_comm_rt.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* inst_aot = cast(AOTModuleInstance*)table.inst_comm_rt;
        AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;

        if (table.table_idx_rt < module_aot.import_table_count) {
            AOTImportTable* table_aot = module_aot.import_tables + table.table_idx_rt;
            return table_aot.table_init_size;
        }
        else {
            AOTTable* table_aot = module_aot.tables
                + (table.table_idx_rt - module_aot.import_table_count);
            return table_aot.table_init_size;
        }
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return 0;
}

bool wasm_table_grow(wasm_table_t* table, wasm_table_size_t delta, own* init) {
    cast(void)table;
    cast(void)delta;
    cast(void)init;
    LOG_WARNING("Calling wasm_table_grow() by host is not supported."
                ~ "Only allow growing a table via the opcode table.grow");
    return false;
}

wasm_memory_t* wasm_memory_new_basic(wasm_store_t* store, const(wasm_memorytype_t)* type) {
    wasm_memory_t* memory = null;

    if (!type) {
        goto failed;
    }

    if (((memory = malloc_internal(wasm_memory_t.sizeof)) == 0)) {
        goto failed;
    }

    memory.store = store;
    memory.kind = WASM_EXTERN_MEMORY;
    memory.type = wasm_memorytype_copy(type);

    RETURN_OBJ(memory, wasm_memory_delete);
}

wasm_memory_t* wasm_memory_new(wasm_store_t* store, const(wasm_memorytype_t)* type) {
    bh_assert(singleton_engine);
    return wasm_memory_new_basic(store, type);
}

wasm_memory_t* wasm_memory_copy(const(wasm_memory_t)* src) {
    wasm_memory_t* dst = null;

    if (!src) {
        return null;
    }

    if (((dst = wasm_memory_new_basic(src.store, src.type)) == 0)) {
        goto failed;
    }

    dst.memory_idx_rt = src.memory_idx_rt;
    dst.inst_comm_rt = src.inst_comm_rt;

    RETURN_OBJ(dst, wasm_memory_delete);
}

wasm_memory_t* wasm_memory_new_internal(wasm_store_t* store, ushort memory_idx_rt, WASMModuleInstanceCommon* inst_comm_rt) {
    wasm_memory_t* memory = null;
    uint min_pages = 0, max_pages = 0;
    bool init_flag = false;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return null;
    }

    if (((memory = malloc_internal(wasm_memory_t.sizeof)) == 0)) {
        goto failed;
    }

    memory.store = store;
    memory.kind = WASM_EXTERN_MEMORY;

static if (ver.WASM_ENABLE_INTERP) {
    if (inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        WASMMemoryInstance* memory_interp = (cast(WASMModuleInstance*)inst_comm_rt).memories[memory_idx_rt];
        min_pages = memory_interp.cur_page_count;
        max_pages = memory_interp.max_page_count;
        init_flag = true;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (inst_comm_rt.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* inst_aot = cast(AOTModuleInstance*)inst_comm_rt;
        AOTModule* module_aot = cast(AOTModule*)inst_aot.module_;

        if (memory_idx_rt < module_aot.import_memory_count) {
            min_pages = module_aot.import_memories.mem_init_page_count;
            max_pages = module_aot.import_memories.mem_max_page_count;
        }
        else {
            min_pages = module_aot.memories.mem_init_page_count;
            max_pages = module_aot.memories.mem_max_page_count;
        }
        init_flag = true;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!init_flag) {
        goto failed;
    }

    if (((memory.type = wasm_memorytype_new_internal(min_pages, max_pages)) == 0)) {
        goto failed;
    }

    memory.inst_comm_rt = inst_comm_rt;
    memory.memory_idx_rt = memory_idx_rt;

    RETURN_OBJ(memory, wasm_memory_delete);
}

void wasm_memory_delete(wasm_memory_t* memory) {
    if (!memory) {
        return;
    }

    if (memory.type) {
        wasm_memorytype_delete(memory.type);
        memory.type = null;
    }

     wasm_runtime_free(memory);
}

wasm_memorytype_t* wasm_memory_type(const(wasm_memory_t)* memory) {
    if (!memory) {
        return null;
    }

    return wasm_memorytype_copy(memory.type);
}

byte_t* wasm_memory_data(wasm_memory_t* memory) {
    WASMModuleInstanceCommon* module_inst_comm = void;

    if (!memory || !memory.inst_comm_rt) {
        return null;
    }

    module_inst_comm = memory.inst_comm_rt;
static if (ver.WASM_ENABLE_INTERP) {
    if (module_inst_comm.module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
        WASMMemoryInstance* memory_inst = module_inst.memories[memory.memory_idx_rt];
        return cast(byte_t*)memory_inst.memory_data;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (module_inst_comm.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* module_inst = cast(AOTModuleInstance*)module_inst_comm;
        AOTMemoryInstance* memory_inst = (cast(AOTMemoryInstance**)
                 module_inst.memories)[memory.memory_idx_rt];
        return cast(byte_t*)memory_inst.memory_data;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return null;
}

size_t wasm_memory_data_size(const(wasm_memory_t)* memory) {
    WASMModuleInstanceCommon* module_inst_comm = void;

    if (!memory || !memory.inst_comm_rt) {
        return 0;
    }

    module_inst_comm = memory.inst_comm_rt;
static if (ver.WASM_ENABLE_INTERP) {
    if (module_inst_comm.module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
        WASMMemoryInstance* memory_inst = module_inst.memories[memory.memory_idx_rt];
        return memory_inst.cur_page_count * memory_inst.num_bytes_per_page;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (module_inst_comm.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* module_inst = cast(AOTModuleInstance*)module_inst_comm;
        AOTMemoryInstance* memory_inst = (cast(AOTMemoryInstance**)
                 module_inst.memories)[memory.memory_idx_rt];
        return memory_inst.cur_page_count * memory_inst.num_bytes_per_page;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return 0;
}

wasm_memory_pages_t wasm_memory_size(const(wasm_memory_t)* memory) {
    WASMModuleInstanceCommon* module_inst_comm = void;

    if (!memory || !memory.inst_comm_rt) {
        return 0;
    }

    module_inst_comm = memory.inst_comm_rt;
static if (ver.WASM_ENABLE_INTERP) {
    if (module_inst_comm.module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_inst_comm;
        WASMMemoryInstance* memory_inst = module_inst.memories[memory.memory_idx_rt];
        return memory_inst.cur_page_count;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (module_inst_comm.module_type == Wasm_Module_AoT) {
        AOTModuleInstance* module_inst = cast(AOTModuleInstance*)module_inst_comm;
        AOTMemoryInstance* memory_inst = (cast(AOTMemoryInstance**)
                 module_inst.memories)[memory.memory_idx_rt];
        return memory_inst.cur_page_count;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return 0;
}

bool wasm_memory_grow(wasm_memory_t* memory, wasm_memory_pages_t delta) {
    cast(void)memory;
    cast(void)delta;
    LOG_WARNING("Calling wasm_memory_grow() by host is not supported."
                ~ "Only allow growing a memory via the opcode memory.grow");
    return false;
}

static if (ver.WASM_ENABLE_INTERP) {
bool interp_link_func(const(wasm_instance_t)* inst, const(WASMModule)* module_interp, ushort func_idx_rt, wasm_func_t* import_) {
    WASMImport* imported_func_interp = null;

    bh_assert(inst && module_interp && import_);
    bh_assert(func_idx_rt < module_interp.import_function_count);
    bh_assert(WASM_EXTERN_FUNC == import_.kind);

    imported_func_interp = module_interp.import_functions + func_idx_rt;
    bh_assert(imported_func_interp);

    /* type comparison */
    if (!wasm_functype_same_internal(
            import_.type, imported_func_interp.u.function_.func_type))
        return false;

    imported_func_interp.u.function_.call_conv_wasm_c_api = true;
    /* only set func_ptr_linked to avoid unlink warning during instantiation,
       func_ptr_linked, with_env and env will be stored in module instance's
       c_api_func_imports later and used when calling import function */
    if (import_.with_env)
        imported_func_interp.u.function_.func_ptr_linked = import_.u.cb_env.cb;
    else
        imported_func_interp.u.function_.func_ptr_linked = import_.u.cb;
    import_.func_idx_rt = func_idx_rt;

    return true;
}

bool interp_link_global(const(WASMModule)* module_interp, ushort global_idx_rt, wasm_global_t* import_) {
    WASMImport* imported_global_interp = null;

    bh_assert(module_interp && import_);
    bh_assert(global_idx_rt < module_interp.import_global_count);
    bh_assert(WASM_EXTERN_GLOBAL == import_.kind);

    imported_global_interp = module_interp.import_globals + global_idx_rt;
    bh_assert(imported_global_interp);

    if (!cmp_val_kind_with_val_type(wasm_valtype_kind(import_.type.val_type),
                                    imported_global_interp.u.global.type))
        return false;

    /* set init value */
    switch (wasm_valtype_kind(import_.type.val_type)) {
        case WASM_I32:
            imported_global_interp.u.global.global_data_linked.i32 =
                import_.init.of.i32;
            break;
        case WASM_I64:
            imported_global_interp.u.global.global_data_linked.i64 =
                import_.init.of.i64;
            break;
        case WASM_F32:
            imported_global_interp.u.global.global_data_linked.f32 =
                import_.init.of.f32;
            break;
        case WASM_F64:
            imported_global_interp.u.global.global_data_linked.f64 =
                import_.init.of.f64;
            break;
        default:
            return false;
    }

    import_.global_idx_rt = global_idx_rt;
    imported_global_interp.u.global.is_linked = true;
    return true;
}

uint interp_link(const(wasm_instance_t)* inst, const(WASMModule)* module_interp, wasm_extern_t** imports) {
    uint i = 0;
    uint import_func_i = 0;
    uint import_global_i = 0;

    bh_assert(inst && module_interp && imports);

    for (i = 0; i < module_interp.import_count; ++i) {
        wasm_extern_t* import_ = imports[i];
        WASMImport* import_rt = module_interp.imports + i;

        switch (import_rt.kind) {
            case IMPORT_KIND_FUNC:
            {
                if (!interp_link_func(inst, module_interp, import_func_i,
                                      wasm_extern_as_func(import_))) {
                    LOG_WARNING("link #%d function failed", import_func_i);
                    goto failed;
                }
                import_func_i++;
                break;
            }
            case IMPORT_KIND_GLOBAL:
            {
                if (!interp_link_global(module_interp, import_global_i,
                                        wasm_extern_as_global(import_))) {
                    LOG_WARNING("link #%d global failed", import_global_i);
                    goto failed;
                }
                import_global_i++;
                break;
            }
            case IMPORT_KIND_MEMORY:
            case IMPORT_KIND_TABLE:
            default:
                ASSERT_NOT_IMPLEMENTED();
                LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                            import_rt.kind);
                goto failed;
        }
    }

    return i;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    return cast(uint)-1;
}

bool interp_process_export(wasm_store_t* store, const(WASMModuleInstance)* inst_interp, wasm_extern_vec_t* externals) {
    WASMExport* exports = null;
    WASMExport* export_ = null;
    wasm_extern_t* external = null;
    uint export_cnt = 0;
    uint i = 0;

    bh_assert(store && inst_interp && inst_interp.module_ && externals);

    exports = inst_interp.module_.exports;
    export_cnt = inst_interp.module_.export_count;

    for (i = 0; i < export_cnt; ++i) {
        export_ = exports + i;

        switch (export_.kind) {
            case EXPORT_KIND_FUNC:
            {
                wasm_func_t* func = void;
                if (((func = wasm_func_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_interp)) == 0)) {
                    goto failed;
                }

                external = wasm_func_as_extern(func);
                break;
            }
            case EXPORT_KIND_GLOBAL:
            {
                wasm_global_t* global = void;
                if (((global = wasm_global_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_interp)) == 0)) {
                    goto failed;
                }

                external = wasm_global_as_extern(global);
                break;
            }
            case EXPORT_KIND_TABLE:
            {
                wasm_table_t* table = void;
                if (((table = wasm_table_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_interp)) == 0)) {
                    goto failed;
                }

                external = wasm_table_as_extern(table);
                break;
            }
            case EXPORT_KIND_MEMORY:
            {
                wasm_memory_t* memory = void;
                if (((memory = wasm_memory_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_interp)) == 0)) {
                    goto failed;
                }

                external = wasm_memory_as_extern(memory);
                break;
            }
            default:
                LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                            export_.kind);
                goto failed;
        }

        if (!bh_vector_append(cast(Vector*)externals, &external)) {
            goto failed;
        }
    }

    return true;

failed:
    wasm_extern_delete(external);
    return false;
}
} /* WASM_ENABLE_INTERP */

static if (ver.WASM_ENABLE_AOT) {
bool aot_link_func(const(wasm_instance_t)* inst, const(AOTModule)* module_aot, uint import_func_idx_rt, wasm_func_t* import_) {
    AOTImportFunc* import_aot_func = null;

    bh_assert(inst && module_aot && import_);

    import_aot_func = module_aot.import_funcs + import_func_idx_rt;
    bh_assert(import_aot_func);

    /* type comparison */
    if (!wasm_functype_same_internal(import_.type, import_aot_func.func_type))
        return false;

    import_aot_func.call_conv_wasm_c_api = true;
    /* only set func_ptr_linked to avoid unlink warning during instantiation,
       func_ptr_linked, with_env and env will be stored in module instance's
       c_api_func_imports later and used when calling import function */
    if (import_.with_env)
        import_aot_func.func_ptr_linked = import_.u.cb_env.cb;
    else
        import_aot_func.func_ptr_linked = import_.u.cb;
    import_.func_idx_rt = import_func_idx_rt;

    return true;
}

bool aot_link_global(const(AOTModule)* module_aot, ushort global_idx_rt, wasm_global_t* import_) {
    AOTImportGlobal* import_aot_global = null;
    const(wasm_valtype_t)* val_type = null;

    bh_assert(module_aot && import_);

    import_aot_global = module_aot.import_globals + global_idx_rt;
    bh_assert(import_aot_global);

    val_type = wasm_globaltype_content(import_.type);
    bh_assert(val_type);

    if (!cmp_val_kind_with_val_type(wasm_valtype_kind(val_type),
                                    import_aot_global.type))
        return false;

    switch (wasm_valtype_kind(val_type)) {
        case WASM_I32:
            import_aot_global.global_data_linked.i32 = import_.init.of.i32;
            break;
        case WASM_I64:
            import_aot_global.global_data_linked.i64 = import_.init.of.i64;
            break;
        case WASM_F32:
            import_aot_global.global_data_linked.f32 = import_.init.of.f32;
            break;
        case WASM_F64:
            import_aot_global.global_data_linked.f64 = import_.init.of.f64;
            break;
        default:
            goto failed;
    }

    import_.global_idx_rt = global_idx_rt;
    return true;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    return false;
}

uint aot_link(const(wasm_instance_t)* inst, const(AOTModule)* module_aot, wasm_extern_t** imports) {
    uint i = 0;
    uint import_func_i = 0;
    uint import_global_i = 0;
    wasm_extern_t* import_ = null;
    wasm_func_t* func = null;
    wasm_global_t* global = null;

    bh_assert(inst && module_aot && imports);

    while (import_func_i < module_aot.import_func_count
           || import_global_i < module_aot.import_global_count) {
        import_ = imports[i++];

        bh_assert(import_);

        switch (wasm_extern_kind(import_)) {
            case WASM_EXTERN_FUNC:
                bh_assert(import_func_i < module_aot.import_func_count);
                func = wasm_extern_as_func(cast(wasm_extern_t*)import_);
                if (!aot_link_func(inst, module_aot, import_func_i, func)) {
                    LOG_WARNING("link #%d function failed", import_func_i);
                    goto failed;
                }
                import_func_i++;

                break;
            case WASM_EXTERN_GLOBAL:
                bh_assert(import_global_i < module_aot.import_global_count);
                global = wasm_extern_as_global(cast(wasm_extern_t*)import_);
                if (!aot_link_global(module_aot, import_global_i, global)) {
                    LOG_WARNING("link #%d global failed", import_global_i);
                    goto failed;
                }
                import_global_i++;

                break;
            case WASM_EXTERN_MEMORY:
            case WASM_EXTERN_TABLE:
            default:
                ASSERT_NOT_IMPLEMENTED();
                goto failed;
        }
    }

    return i;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    return cast(uint)-1;
}

bool aot_process_export(wasm_store_t* store, const(AOTModuleInstance)* inst_aot, wasm_extern_vec_t* externals) {
    uint i = void;
    wasm_extern_t* external = null;
    AOTModule* module_aot = null;

    bh_assert(store && inst_aot && externals);

    module_aot = cast(AOTModule*)inst_aot.module_;
    bh_assert(module_aot);

    for (i = 0; i < module_aot.export_count; ++i) {
        AOTExport* export_ = module_aot.exports + i;

        switch (export_.kind) {
            case EXPORT_KIND_FUNC:
            {
                wasm_func_t* func = null;
                if (((func = wasm_func_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_aot)) == 0)) {
                    goto failed;
                }

                external = wasm_func_as_extern(func);
                break;
            }
            case EXPORT_KIND_GLOBAL:
            {
                wasm_global_t* global = null;
                if (((global = wasm_global_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_aot)) == 0)) {
                    goto failed;
                }

                external = wasm_global_as_extern(global);
                break;
            }
            case EXPORT_KIND_TABLE:
            {
                wasm_table_t* table = void;
                if (((table = wasm_table_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_aot)) == 0)) {
                    goto failed;
                }

                external = wasm_table_as_extern(table);
                break;
            }
            case EXPORT_KIND_MEMORY:
            {
                wasm_memory_t* memory = void;
                if (((memory = wasm_memory_new_internal(
                          store, export_.index,
                          cast(WASMModuleInstanceCommon*)inst_aot)) == 0)) {
                    goto failed;
                }

                external = wasm_memory_as_extern(memory);
                break;
            }
            default:
                LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                            export_.kind);
                goto failed;
        }

        if (((external.name = malloc_internal(wasm_byte_vec_t.sizeof)) == 0)) {
            goto failed;
        }

        wasm_name_new_from_string(external.name, export_.name);
        if (strlen(export_.name) && !external.name.data) {
            goto failed;
        }

        if (!bh_vector_append(cast(Vector*)externals, &external)) {
            goto failed;
        }
    }

    return true;

failed:
    wasm_extern_delete(external);
    return false;
}
} /* WASM_ENABLE_AOT */

wasm_instance_t* wasm_instance_new(wasm_store_t* store, const(wasm_module_t)* module_, const(wasm_extern_vec_t)* imports, own** trap) {
    return wasm_instance_new_with_args(store, module_, imports, trap,
                                       KILOBYTE(32), KILOBYTE(32));
}

wasm_instance_t* wasm_instance_new_with_args(wasm_store_t* store, const(wasm_module_t)* module_, const(wasm_extern_vec_t)* imports, own** trap, const(uint) stack_size, const(uint) heap_size) {
    char[128] sub_error_buf = 0;
    char[256] error_buf = 0;
    bool import_count_verified = false;
    wasm_instance_t* instance = null;
    WASMModuleInstance* inst_rt = void;
    CApiFuncImport* func_import = null; CApiFuncImport** p_func_imports = null;
    uint i = 0, import_count = 0, import_func_count = 0;
    ulong total_size = void;
    bool processed = false;

    bh_assert(singleton_engine);

    if (!module_) {
        return null;
    }

    WASM_C_DUMP_PROC_MEM();

    instance = malloc_internal(wasm_instance_t.sizeof);
    if (!instance) {
        snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                 "Failed to malloc instance");
        goto failed;
    }

    /* link module and imports */
    if (imports && imports.num_elems) {
static if (ver.WASM_ENABLE_INTERP) {
        if ((*module_).module_type == Wasm_Module_Bytecode) {
            import_count = MODULE_INTERP(module_).import_count;

            if (import_count) {
                uint actual_link_import_count = interp_link(instance, MODULE_INTERP(module_),
                                cast(wasm_extern_t**)imports.data);
                /* make sure a complete import list */
                if (cast(int)import_count < 0
                    || import_count != actual_link_import_count) {
                    snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                             "Failed to validate imports");
                    goto failed;
                }
            }
            import_count_verified = true;
        }
}

static if (ver.WASM_ENABLE_AOT) {
        if ((*module_).module_type == Wasm_Module_AoT) {
            import_count = MODULE_AOT(module_).import_func_count
                           + MODULE_AOT(module_).import_global_count
                           + MODULE_AOT(module_).import_memory_count
                           + MODULE_AOT(module_).import_table_count;

            if (import_count) {
                import_count = aot_link(instance, MODULE_AOT(module_),
                                        cast(wasm_extern_t**)imports.data);
                if (cast(int)import_count < 0) {
                    snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                             "Failed to validate imports");
                    goto failed;
                }
            }
            import_count_verified = true;
        }
}

        /*
         * a wrong combination of module filetype and compilation flags
         * also leads to below branch
         */
        if (!import_count_verified) {
            snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                     "Failed to verify import count");
            goto failed;
        }
    }

    instance.inst_comm_rt = wasm_runtime_instantiate(
        *module_, stack_size, heap_size, sub_error_buf.ptr, sub_error_buf.sizeof);
    if (!instance.inst_comm_rt) {
        goto failed;
    }

    if (!wasm_runtime_create_exec_env_singleton(instance.inst_comm_rt)) {
        snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                 "Failed to create exec env singleton");
        goto failed;
    }

    inst_rt = cast(WASMModuleInstance*)instance.inst_comm_rt;
static if (ver.WASM_ENABLE_INTERP) {
    if (instance.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        p_func_imports = &inst_rt.e.c_api_func_imports;
        import_func_count = inst_rt.module_.import_function_count;
    }
}
static if (ver.WASM_ENABLE_AOT) {
    if (instance.inst_comm_rt.module_type == Wasm_Module_AoT) {
        p_func_imports =
            &(cast(AOTModuleInstanceExtra*)inst_rt.e).c_api_func_imports;
        import_func_count = (cast(AOTModule*)inst_rt.module_).import_func_count;
    }
}
    bh_assert(p_func_imports);

    /* create the c-api func import list */
    total_size = cast(ulong)sizeof(CApiFuncImport) * import_func_count;
    if (total_size > 0
        && ((*p_func_imports = func_import = malloc_internal(total_size)) == 0)) {
        snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                 "Failed to create wasm-c-api func imports");
        goto failed;
    }

    /* fill in c-api func import list */
    for (i = 0; i < import_count; i++) {
        wasm_func_t* func_host = void;
        wasm_extern_t* in_ = void;

        in_ = imports.data[i];
        if (wasm_extern_kind(in_) != WASM_EXTERN_FUNC)
            continue;

        func_host = wasm_extern_as_func(in_);

        func_import.with_env_arg = func_host.with_env;
        if (func_host.with_env) {
            func_import.func_ptr_linked = func_host.u.cb_env.cb;
            func_import.env_arg = func_host.u.cb_env.env;
        }
        else {
            func_import.func_ptr_linked = func_host.u.cb;
            func_import.env_arg = null;
        }

        func_import++;
    }
    bh_assert(cast(uint)(func_import - *p_func_imports) == import_func_count);

    /* fill with inst */
    for (i = 0; imports && imports.data && i < cast(uint)import_count; ++i) {
        wasm_extern_t* import_ = imports.data[i];
        switch (import_.kind) {
            case WASM_EXTERN_FUNC:
                wasm_extern_as_func(import_).inst_comm_rt =
                    instance.inst_comm_rt;
                break;
            case WASM_EXTERN_GLOBAL:
                wasm_extern_as_global(import_).inst_comm_rt =
                    instance.inst_comm_rt;
                break;
            case WASM_EXTERN_MEMORY:
                wasm_extern_as_memory(import_).inst_comm_rt =
                    instance.inst_comm_rt;
                break;
            case WASM_EXTERN_TABLE:
                wasm_extern_as_table(import_).inst_comm_rt =
                    instance.inst_comm_rt;
                break;
            default:
                snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                         "Unknown import kind");
                goto failed;
        }
    }

    /* build the exports list */
static if (ver.WASM_ENABLE_INTERP) {
    if (instance.inst_comm_rt.module_type == Wasm_Module_Bytecode) {
        uint export_cnt = (cast(WASMModuleInstance*)instance.inst_comm_rt)
                                .module_.export_count;

        INIT_VEC(instance.exports, wasm_extern_vec_new_uninitialized,
                 export_cnt);

        if (!interp_process_export(store,
                                   cast(WASMModuleInstance*)instance.inst_comm_rt,
                                   instance.exports)) {
            snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                     "Interpreter failed to process exports");
            goto failed;
        }

        processed = true;
    }
}

static if (ver.WASM_ENABLE_AOT) {
    if (instance.inst_comm_rt.module_type == Wasm_Module_AoT) {
        uint export_cnt = (cast(AOTModuleInstance*)instance.inst_comm_rt).export_func_count
            + (cast(AOTModuleInstance*)instance.inst_comm_rt).export_global_count
            + (cast(AOTModuleInstance*)instance.inst_comm_rt).export_table_count
            + (cast(AOTModuleInstance*)instance.inst_comm_rt)
                  .export_memory_count;

        INIT_VEC(instance.exports, wasm_extern_vec_new_uninitialized,
                 export_cnt);

        if (!aot_process_export(store,
                                cast(AOTModuleInstance*)instance.inst_comm_rt,
                                instance.exports)) {
            snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                     "AOT failed to process exports");
            goto failed;
        }

        processed = true;
    }
}

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!processed) {
        snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                 "Incorrect filetype and compilation flags");
        goto failed;
    }

    /* add it to a watching list in store */
    if (!bh_vector_append(cast(Vector*)store.instances, &instance)) {
        snprintf(sub_error_buf.ptr, sub_error_buf.sizeof,
                 "Failed to add to store instances");
        goto failed;
    }

    WASM_C_DUMP_PROC_MEM();

    return instance;

failed:
    snprintf(error_buf.ptr, error_buf.sizeof, "%s failed: %s", __FUNCTION__,
             sub_error_buf.ptr);
    if (trap != null) {
        wasm_message_t message = { 0 };
        wasm_name_new_from_string(&message, error_buf.ptr);
        *trap = wasm_trap_new(store, &message);
        wasm_byte_vec_delete(&message);
    }
    LOG_DEBUG(error_buf.ptr);
    wasm_instance_delete_internal(instance);
    return null;
}

void wasm_instance_delete_internal(wasm_instance_t* instance) {
    if (!instance) {
        return;
    }

    DEINIT_VEC(instance.exports, wasm_extern_vec_delete);

    if (instance.inst_comm_rt) {
        wasm_runtime_deinstantiate(instance.inst_comm_rt);
        instance.inst_comm_rt = null;
    }
    wasm_runtime_free(instance);
}

void wasm_instance_delete(wasm_instance_t* inst) {
    DELETE_HOST_INFO(inst);
    /* will release instance when releasing the store */
}

void wasm_instance_exports(const(wasm_instance_t)* instance, own* out_) {
    if (!instance || !out_) {
        return;
    }
    wasm_extern_vec_copy(out_, instance.exports);
}

wasm_extern_t* wasm_extern_copy(const(wasm_extern_t)* src) {
    wasm_extern_t* dst = null;

    if (!src) {
        return null;
    }

    switch (wasm_extern_kind(src)) {
        case WASM_EXTERN_FUNC:
            dst = wasm_func_as_extern(
                wasm_func_copy(wasm_extern_as_func_const(src)));
            break;
        case WASM_EXTERN_GLOBAL:
            dst = wasm_global_as_extern(
                wasm_global_copy(wasm_extern_as_global_const(src)));
            break;
        case WASM_EXTERN_MEMORY:
            dst = wasm_memory_as_extern(
                wasm_memory_copy(wasm_extern_as_memory_const(src)));
            break;
        case WASM_EXTERN_TABLE:
            dst = wasm_table_as_extern(
                wasm_table_copy(wasm_extern_as_table_const(src)));
            break;
        default:
            LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                        src.kind);
            break;
    }

    if (!dst) {
        goto failed;
    }

    return dst;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_extern_delete(dst);
    return null;
}

void wasm_extern_delete(wasm_extern_t* external) {
    if (!external) {
        return;
    }

    if (external.name) {
        wasm_byte_vec_delete(external.name);
        wasm_runtime_free(external.name);
        external.name = null;
    }

    switch (wasm_extern_kind(external)) {
        case WASM_EXTERN_FUNC:
            wasm_func_delete(wasm_extern_as_func(external));
            break;
        case WASM_EXTERN_GLOBAL:
            wasm_global_delete(wasm_extern_as_global(external));
            break;
        case WASM_EXTERN_MEMORY:
            wasm_memory_delete(wasm_extern_as_memory(external));
            break;
        case WASM_EXTERN_TABLE:
            wasm_table_delete(wasm_extern_as_table(external));
            break;
        default:
            LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                        external.kind);
            break;
    }
}

wasm_externkind_t wasm_extern_kind(const(wasm_extern_t)* external) {
    if (!external) {
        return WASM_ANYREF;
    }

    return external.kind;
}

own* wasm_extern_type(const(wasm_extern_t)* external) {
    if (!external) {
        return null;
    }

    switch (wasm_extern_kind(external)) {
        case WASM_EXTERN_FUNC:
            return wasm_functype_as_externtype(
                wasm_func_type(wasm_extern_as_func_const(external)));
        case WASM_EXTERN_GLOBAL:
            return wasm_globaltype_as_externtype(
                wasm_global_type(wasm_extern_as_global_const(external)));
        case WASM_EXTERN_MEMORY:
            return wasm_memorytype_as_externtype(
                wasm_memory_type(wasm_extern_as_memory_const(external)));
        case WASM_EXTERN_TABLE:
            return wasm_tabletype_as_externtype(
                wasm_table_type(wasm_extern_as_table_const(external)));
        default:
            LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                        external.kind);
            break;
    }
    return null;
}

enum string BASIC_FOUR_LIST(string V) = ` \
    V(func)                \
    V(global)              \
    V(memory)              \
    V(table)`;

enum string WASM_EXTERN_AS_OTHER(string name) = `                                  \
    wasm_##name##_t *wasm_extern_as_##name(wasm_extern_t *external) \
    {                                                               \
        return (wasm_##name##_t *)external;                         \
    }`;

//BASIC_FOUR_LIST(WASM_EXTERN_AS_OTHER)
enum string WASM_OTHER_AS_EXTERN(string name) = `                                 \
    wasm_extern_t *wasm_##name##_as_extern(wasm_##name##_t *other) \
    {                                                              \
        return (wasm_extern_t *)other;                             \
    }`;

//BASIC_FOUR_LIST(WASM_OTHER_AS_EXTERN)
enum string WASM_EXTERN_AS_OTHER_CONST(string name) = `                  \
    const wasm_##name##_t *wasm_extern_as_##name##_const( \
        const wasm_extern_t *external)                    \
    {                                                     \
        return (const wasm_##name##_t *)external;         \
    }`;

//BASIC_FOUR_LIST(WASM_EXTERN_AS_OTHER_CONST)
enum string WASM_OTHER_AS_EXTERN_CONST(string name) = `                \
    const wasm_extern_t *wasm_##name##_as_extern_const( \
        const wasm_##name##_t *other)                   \
    {                                                   \
        return (const wasm_extern_t *)other;            \
    }`;
}
//BASIC_FOUR_LIST(WASM_OTHER_AS_EXTERN_CONST)

