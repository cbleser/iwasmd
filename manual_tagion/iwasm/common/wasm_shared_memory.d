module wasm_shared_memory;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_log;
public import wasm_shared_memory;

private bh_list shared_memory_list_head;
private bh_list* shared_memory_list = &shared_memory_list_head;
private korp_mutex shared_memory_list_lock;

/* clang-format off */
enum {
    S_WAITING,
    S_NOTIFIED
}
/* clang-format on */

struct AtomicWaitInfo {
    korp_mutex wait_list_lock;
    bh_list wait_list_head;
    bh_list* wait_list;
}

struct AtomicWaitNode {
    bh_list_link l;
    ubyte status;
    korp_mutex wait_lock;
    korp_cond wait_cond;
}

/* Atomic wait map */
private HashMap* wait_map;

private uint wait_address_hash(void* address);

private bool wait_address_equal(void* h1, void* h2);

private void destroy_wait_info(void* wait_info);

bool wasm_shared_memory_init() {
    if (os_mutex_init(&shared_memory_list_lock) != 0)
        return false;
    /* wait map not exists, create new map */
    if (((wait_map = bh_hash_map_create(32, true, cast(HashFunc)wait_address_hash,
                                        cast(KeyEqualFunc)wait_address_equal, null,
                                        &destroy_wait_info)) == 0)) {
        os_mutex_destroy(&shared_memory_list_lock);
        return false;
    }

    return true;
}

void wasm_shared_memory_destroy() {
    os_mutex_destroy(&shared_memory_list_lock);
    if (wait_map) {
        bh_hash_map_destroy(wait_map);
    }
}

private WASMSharedMemNode* search_module(WASMModuleCommon* module_) {
    WASMSharedMemNode* node = void;

    os_mutex_lock(&shared_memory_list_lock);
    node = bh_list_first_elem(shared_memory_list);

    while (node) {
        if (module_ == node.module_) {
            os_mutex_unlock(&shared_memory_list_lock);
            return node;
        }
        node = bh_list_elem_next(node);
    }

    os_mutex_unlock(&shared_memory_list_lock);
    return null;
}

WASMSharedMemNode* wasm_module_get_shared_memory(WASMModuleCommon* module_) {
    return search_module(module_);
}

int shared_memory_inc_reference(WASMModuleCommon* module_) {
    WASMSharedMemNode* node = search_module(module_);
    if (node) {
        os_mutex_lock(&node.lock);
        node.ref_count++;
        os_mutex_unlock(&node.lock);
        return node.ref_count;
    }
    return -1;
}

int shared_memory_dec_reference(WASMModuleCommon* module_) {
    WASMSharedMemNode* node = search_module(module_);
    uint ref_count = 0;
    if (node) {
        os_mutex_lock(&node.lock);
        ref_count = --node.ref_count;
        os_mutex_unlock(&node.lock);
        if (ref_count == 0) {
            os_mutex_lock(&shared_memory_list_lock);
            bh_list_remove(shared_memory_list, node);
            os_mutex_unlock(&shared_memory_list_lock);

            os_mutex_destroy(&node.lock);
            wasm_runtime_free(node);
        }
        return ref_count;
    }

    return -1;
}

WASMMemoryInstanceCommon* shared_memory_get_memory_inst(WASMSharedMemNode* node) {
    return node.memory_inst;
}

WASMSharedMemNode* shared_memory_set_memory_inst(WASMModuleCommon* module_, WASMMemoryInstanceCommon* memory) {
    WASMSharedMemNode* node = void;
    bh_list_status ret = void;

    if (((node = wasm_runtime_malloc(WASMSharedMemNode.sizeof)) == 0))
        return null;

    node.module_ = module_;
    node.memory_inst = memory;
    node.ref_count = 1;
    if (os_mutex_init(&node.lock) != 0) {
        wasm_runtime_free(node);
        return null;
    }

    os_mutex_lock(&shared_memory_list_lock);
    ret = bh_list_insert(shared_memory_list, node);
    bh_assert(ret == BH_LIST_SUCCESS);
    os_mutex_unlock(&shared_memory_list_lock);

    cast(void)ret;
    return node;
}

/* Atomics wait && notify APIs */
private uint wait_address_hash(void* address) {
    return cast(uint)cast(uintptr_t)address;
}

private bool wait_address_equal(void* h1, void* h2) {
    return h1 == h2 ? true : false;
}

private bool is_wait_node_exists(bh_list* wait_list, AtomicWaitNode* node) {
    AtomicWaitNode* curr = void;
    curr = bh_list_first_elem(wait_list);

    while (curr) {
        if (curr == node) {
            return true;
        }
        curr = bh_list_elem_next(curr);
    }

    return false;
}

private uint notify_wait_list(bh_list* wait_list, uint count) {
    AtomicWaitNode* node = void, next = void;
    uint i = void, notify_count = count;

    if ((count == UINT32_MAX) || (count > wait_list.len))
        notify_count = wait_list.len;

    node = bh_list_first_elem(wait_list);
    if (!node)
        return 0;

    for (i = 0; i < notify_count; i++) {
        bh_assert(node);
        next = bh_list_elem_next(node);

        node.status = S_NOTIFIED;
        /* wakeup */
        os_cond_signal(&node.wait_cond);

        node = next;
    }

    return notify_count;
}

private AtomicWaitInfo* acquire_wait_info(void* address, bool create) {
    AtomicWaitInfo* wait_info = null;
    bh_list_status ret = void;

    os_mutex_lock(&shared_memory_list_lock);

    if (address)
        wait_info = cast(AtomicWaitInfo*)bh_hash_map_find(wait_map, address);

    if (!create) {
        os_mutex_unlock(&shared_memory_list_lock);
        return wait_info;
    }

    /* No wait info on this address, create new info */
    if (!wait_info) {
        if (((wait_info = cast(AtomicWaitInfo*)wasm_runtime_malloc(
                  AtomicWaitInfo.sizeof)) == 0)) {
            goto fail1;
        }
        memset(wait_info, 0, AtomicWaitInfo.sizeof);

        /* init wait list */
        wait_info.wait_list = &wait_info.wait_list_head;
        ret = bh_list_init(wait_info.wait_list);
        bh_assert(ret == BH_LIST_SUCCESS);

        /* init wait list lock */
        if (0 != os_mutex_init(&wait_info.wait_list_lock)) {
            goto fail2;
        }

        if (!bh_hash_map_insert(wait_map, address, cast(void*)wait_info)) {
            goto fail3;
        }
    }

    os_mutex_unlock(&shared_memory_list_lock);

    bh_assert(wait_info);
    cast(void)ret;
    return wait_info;

fail3:
    os_mutex_destroy(&wait_info.wait_list_lock);

fail2:
    wasm_runtime_free(wait_info);

fail1:
    os_mutex_unlock(&shared_memory_list_lock);

    return null;
}

private void destroy_wait_info(void* wait_info) {
    AtomicWaitNode* node = void, next = void;

    if (wait_info) {

        node = bh_list_first_elem((cast(AtomicWaitInfo*)wait_info).wait_list);

        while (node) {
            next = bh_list_elem_next(node);
            os_mutex_destroy(&node.wait_lock);
            os_cond_destroy(&node.wait_cond);
            wasm_runtime_free(node);
            node = next;
        }

        os_mutex_destroy(&(cast(AtomicWaitInfo*)wait_info).wait_list_lock);
        wasm_runtime_free(wait_info);
    }
}

private void release_wait_info(HashMap* wait_map_, AtomicWaitInfo* wait_info, void* address) {
    os_mutex_lock(&shared_memory_list_lock);

    if (wait_info.wait_list.len == 0) {
        bh_hash_map_remove(wait_map_, address, null, null);
        destroy_wait_info(wait_info);
    }

    os_mutex_unlock(&shared_memory_list_lock);
}

uint wasm_runtime_atomic_wait(WASMModuleInstanceCommon* module_, void* address, ulong expect, long timeout, bool wait64) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_;
    AtomicWaitInfo* wait_info = void;
    AtomicWaitNode* wait_node = void;
    bool check_ret = void, is_timeout = void;

    bh_assert(module_.module_type == Wasm_Module_Bytecode
              || module_.module_type == Wasm_Module_AoT);

    /* Currently we have only one memory instance */
    if (!module_inst.memories[0].is_shared) {
        wasm_runtime_set_exception(module_, "expected shared memory");
        return -1;
    }

    if (cast(ubyte*)address < module_inst.memories[0].memory_data
        || cast(ubyte*)address + (wait64 ? 8 : 4)
               > module_inst.memories[0].memory_data_end) {
        wasm_runtime_set_exception(module_, "out of bounds memory access");
        return -1;
    }

    /* acquire the wait info, create new one if not exists */
    wait_info = acquire_wait_info(address, true);

    if (!wait_info) {
        wasm_runtime_set_exception(module_, "failed to acquire wait_info");
        return -1;
    }

    os_mutex_lock(&wait_info.wait_list_lock);

    if ((!wait64 && *cast(uint*)address != cast(uint)expect)
        || (wait64 && *cast(ulong*)address != expect)) {
        os_mutex_unlock(&wait_info.wait_list_lock);
        return 1;
    }
    else {
        bh_list_status ret = void;

        if (((wait_node = wasm_runtime_malloc(AtomicWaitNode.sizeof)) == 0)) {
            wasm_runtime_set_exception(module_, "failed to create wait node");
            os_mutex_unlock(&wait_info.wait_list_lock);
            return -1;
        }
        memset(wait_node, 0, AtomicWaitNode.sizeof);

        if (0 != os_mutex_init(&wait_node.wait_lock)) {
            wasm_runtime_free(wait_node);
            os_mutex_unlock(&wait_info.wait_list_lock);
            return -1;
        }

        if (0 != os_cond_init(&wait_node.wait_cond)) {
            os_mutex_destroy(&wait_node.wait_lock);
            wasm_runtime_free(wait_node);
            os_mutex_unlock(&wait_info.wait_list_lock);
            return -1;
        }

        wait_node.status = S_WAITING;

        ret = bh_list_insert(wait_info.wait_list, wait_node);
        bh_assert(ret == BH_LIST_SUCCESS);
        cast(void)ret;
    }

    os_mutex_unlock(&wait_info.wait_list_lock);

    /* condition wait start */
    os_mutex_lock(&wait_node.wait_lock);

    os_cond_reltimedwait(&wait_node.wait_cond, &wait_node.wait_lock,
                         timeout < 0 ? BHT_WAIT_FOREVER
                                     : cast(ulong)timeout / 1000);

    os_mutex_unlock(&wait_node.wait_lock);

    /* Check the wait node status */
    os_mutex_lock(&wait_info.wait_list_lock);
    check_ret = is_wait_node_exists(wait_info.wait_list, wait_node);
    bh_assert(check_ret);

    is_timeout = wait_node.status == S_WAITING ? true : false;

    bh_list_remove(wait_info.wait_list, wait_node);
    os_mutex_destroy(&wait_node.wait_lock);
    os_cond_destroy(&wait_node.wait_cond);
    wasm_runtime_free(wait_node);
    os_mutex_unlock(&wait_info.wait_list_lock);

    release_wait_info(wait_map, wait_info, address);

    cast(void)check_ret;
    return is_timeout ? 2 : 0;
}

uint wasm_runtime_atomic_notify(WASMModuleInstanceCommon* module_, void* address, uint count) {
    WASMModuleInstance* module_inst = cast(WASMModuleInstance*)module_;
    uint notify_result = void;
    AtomicWaitInfo* wait_info = void;

    bh_assert(module_.module_type == Wasm_Module_Bytecode
              || module_.module_type == Wasm_Module_AoT);

    if (cast(ubyte*)address < module_inst.memories[0].memory_data
        || cast(ubyte*)address + 4 > module_inst.memories[0].memory_data_end) {
        wasm_runtime_set_exception(module_, "out of bounds memory access");
        return -1;
    }

    wait_info = acquire_wait_info(address, false);

    /* Nobody wait on this address */
    if (!wait_info)
        return 0;

    os_mutex_lock(&wait_info.wait_list_lock);
    notify_result = notify_wait_list(wait_info.wait_list, count);
    os_mutex_unlock(&wait_info.wait_list_lock);

    return notify_result;
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_common;
static if (WASM_ENABLE_INTERP != 0) {
public import wasm_runtime;
}
static if (WASM_ENABLE_AOT != 0) {
public import aot_runtime;
}

version (none) {
extern "C" {
//! #endif

struct WASMSharedMemNode {
    bh_list_link l;
    /* Lock */
    korp_mutex lock;
    /* The module reference */
    WASMModuleCommon* module_;
    /* The memory information */
    WASMMemoryInstanceCommon* memory_inst;

    /* reference count */
    uint ref_count;
}

bool wasm_shared_memory_init();

void wasm_shared_memory_destroy();

WASMSharedMemNode* wasm_module_get_shared_memory(WASMModuleCommon* module_);

int shared_memory_inc_reference(WASMModuleCommon* module_);

int shared_memory_dec_reference(WASMModuleCommon* module_);

WASMMemoryInstanceCommon* shared_memory_get_memory_inst(WASMSharedMemNode* node);

WASMSharedMemNode* shared_memory_set_memory_inst(WASMModuleCommon* module_, WASMMemoryInstanceCommon* memory);

uint wasm_runtime_atomic_wait(WASMModuleInstanceCommon* module_, void* address, ulong expect, long timeout, bool wait64);

uint wasm_runtime_atomic_notify(WASMModuleInstanceCommon* module_, void* address, uint count);

version (none) {}
}
}

 /* end of _WASM_SHARED_MEMORY_H */
