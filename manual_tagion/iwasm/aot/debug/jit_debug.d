module jit_debug;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2015 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_log;
public import bh_platform;
public import ......interpreter.wasm_runtime;

public import core.stdc.stdio;
public import core.stdc.assert_;
public import core.sys.posix.fcntl;
public import core.stdc.stdlib;
public import core.sys.posix.unistd;
public import core.stdc.string;
public import core.stdc.errno;
public import stdbool;

/* This must be kept in sync with gdb/gdb/jit.h */
#ifdef __cplusplus
extern "C" {
//! #endif

/* clang-format off */
enum JITAction {
    JIT_NOACTION = 0,
    JIT_REGISTER_FN,
    JIT_UNREGISTER_FN
}
alias JIT_NOACTION = JITAction.JIT_NOACTION;
alias JIT_REGISTER_FN = JITAction.JIT_REGISTER_FN;
alias JIT_UNREGISTER_FN = JITAction.JIT_UNREGISTER_FN;

/* clang-format on */

struct JITCodeEntry {
    JITCodeEntry* next_;
    JITCodeEntry* prev_;
    const(ubyte)* symfile_addr_;
    ulong symfile_size_;
}

struct JITDescriptor {
    uint version_;
    uint action_flag_;
    JITCodeEntry* relevant_entry_;
    JITCodeEntry* first_entry_;
}

/* LLVM has already define this */
static if ((WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0)) {
/**
 * GDB will place breakpoint into this function.
 * To prevent GCC from inlining or removing it we place noinline attribute
 * and inline assembler statement inside.
 */
void __jit_debug_register_code();

void __jit_debug_register_code() {
    int x = void;
    *cast(char*)&x = '\0';
}

/**
 * GDB will inspect contents of this descriptor.
 * Static initialization is necessary to prevent GDB from seeing
 * uninitialized descriptor.
 */

JITDescriptor __jit_debug_descriptor = { 1, JIT_NOACTION, null, null };
} else {
extern void __jit_debug_register_code();
extern JITDescriptor __jit_debug_descriptor;
}

/**
 * Call __jit_debug_register_code indirectly via global variable.
 * This gives the debugger an easy way to inject custom code to
 * handle the events.
 */
void function() __jit_debug_register_code_ptr = __jit_debug_register_code;

version (none) {
}
}

struct WASMJITDebugEngine {
    korp_mutex jit_entry_lock;
    bh_list jit_entry_list;
}

struct WASMJITEntryNode {
    WASMJITEntryNode* next;
    JITCodeEntry* entry;
}

private WASMJITDebugEngine* jit_debug_engine;

private JITCodeEntry* CreateJITCodeEntryInternal(const(ubyte)* symfile_addr, ulong symfile_size) {
    JITCodeEntry* entry = void;

    os_mutex_lock(&jit_debug_engine.jit_entry_lock);

    if (((entry = wasm_runtime_malloc(JITCodeEntry.sizeof)) == 0)) {
        LOG_ERROR("WASM JIT Debug Engine error: failed to allocate memory");
        os_mutex_unlock(&jit_debug_engine.jit_entry_lock);
        return null;
    }
    entry.symfile_addr_ = symfile_addr;
    entry.symfile_size_ = symfile_size;
    entry.prev_ = null;

    entry.next_ = __jit_debug_descriptor.first_entry_;
    if (entry.next_ != null) {
        entry.next_.prev_ = entry;
    }
    __jit_debug_descriptor.first_entry_ = entry;
    __jit_debug_descriptor.relevant_entry_ = entry;

    __jit_debug_descriptor.action_flag_ = JIT_REGISTER_FN;

    (*__jit_debug_register_code_ptr)();

    os_mutex_unlock(&jit_debug_engine.jit_entry_lock);
    return entry;
}

private void DestroyJITCodeEntryInternal(JITCodeEntry* entry) {
    os_mutex_lock(&jit_debug_engine.jit_entry_lock);

    if (entry.prev_ != null) {
        entry.prev_.next_ = entry.next_;
    }
    else {
        __jit_debug_descriptor.first_entry_ = entry.next_;
    }

    if (entry.next_ != null) {
        entry.next_.prev_ = entry.prev_;
    }

    __jit_debug_descriptor.relevant_entry_ = entry;
    __jit_debug_descriptor.action_flag_ = JIT_UNREGISTER_FN;
    (*__jit_debug_register_code_ptr)();

    wasm_runtime_free(entry);

    os_mutex_unlock(&jit_debug_engine.jit_entry_lock);
}

bool jit_debug_engine_init() {
    if (jit_debug_engine) {
        return true;
    }

    if (((jit_debug_engine = wasm_runtime_malloc(WASMJITDebugEngine.sizeof)) == 0)) {
        LOG_ERROR("WASM JIT Debug Engine error: failed to allocate memory");
        return false;
    }
    memset(jit_debug_engine, 0, WASMJITDebugEngine.sizeof);

    if (os_mutex_init(&jit_debug_engine.jit_entry_lock) != 0) {
        wasm_runtime_free(jit_debug_engine);
        jit_debug_engine = null;
        return false;
    }

    bh_list_init(&jit_debug_engine.jit_entry_list);
    return true;
}

void jit_debug_engine_destroy() {
    if (jit_debug_engine) {
        WASMJITEntryNode* node = void, node_next = void;

        /* Destroy all nodes */
        node = bh_list_first_elem(&jit_debug_engine.jit_entry_list);
        while (node) {
            node_next = bh_list_elem_next(node);
            DestroyJITCodeEntryInternal(node.entry);
            bh_list_remove(&jit_debug_engine.jit_entry_list, node);
            wasm_runtime_free(node);
            node = node_next;
        }

        /* Destroy JIT Debug Engine */
        os_mutex_destroy(&jit_debug_engine.jit_entry_lock);
        wasm_runtime_free(jit_debug_engine);
        jit_debug_engine = null;
    }
}

bool jit_code_entry_create(const(ubyte)* symfile_addr, ulong symfile_size) {
    JITCodeEntry* entry = void;
    WASMJITEntryNode* node = void;

    if (((node = wasm_runtime_malloc(WASMJITEntryNode.sizeof)) == 0)) {
        LOG_ERROR("WASM JIT Debug Engine error: failed to allocate memory");
        return false;
    }

    entry = CreateJITCodeEntryInternal(symfile_addr, symfile_size);

    if (!entry) {
        wasm_runtime_free(node);
        return false;
    }

    node.entry = entry;
    os_mutex_lock(&jit_debug_engine.jit_entry_lock);
    bh_list_insert(&jit_debug_engine.jit_entry_list, node);
    os_mutex_unlock(&jit_debug_engine.jit_entry_lock);
    return true;
}

void jit_code_entry_destroy(const(ubyte)* symfile_addr) {
    WASMJITEntryNode* node = void;

    node = bh_list_first_elem(&jit_debug_engine.jit_entry_list);
    while (node) {
        WASMJITEntryNode* next_node = bh_list_elem_next(node);
        if (node.entry.symfile_addr_ == symfile_addr) {
            DestroyJITCodeEntryInternal(node.entry);
            os_mutex_lock(&jit_debug_engine.jit_entry_lock);
            bh_list_remove(&jit_debug_engine.jit_entry_list, node);
            os_mutex_unlock(&jit_debug_engine.jit_entry_lock);
            wasm_runtime_free(node);
        }
        node = next_node;
    }
}
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _JIT_DEBUG_H_
version = _JIT_DEBUG_H_;

#ifdef __cplusplus
extern "C" {
//! #endif

bool jit_debug_engine_init();

void jit_debug_engine_destroy();

bool jit_code_entry_create(const(ubyte)* symfile_addr, ulong symfile_size);

void jit_code_entry_destroy(const(ubyte)* symfile_addr);

version (none) {
}
}

//! #endif
