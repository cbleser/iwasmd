module tagion.iwasm.basic;

enum DEFAULT_MEM_ALLOCATOR=0;
enum  MEM_ALLOCATOR_EMS=0;

import core.sys.posix.pthread;
alias korp_tid=pthread_t;
alias korp_mutex=pthread_mutex_t;

import core.stdc.stdio;
alias os_printf=printf;

import std.format;
struct ver {
    template opDispatch(string M) {
        enum code = format(q{
                version(%s) enum opDispatch = true;
                else         enum opDispatch = false;
            },M);
        mixin(code);
    }
}

/*
`uintptr_t`
`WASM_ENABLE_FAST_JIT`
`WASM_ENABLE_MULTI_MODULE`
`WASM_ENABLE_MULTI_MODULE`
`WASM_ENABLE_MULTI_MODULE`
`WASM_ENABLE_MULTI_MODULE`
`WASM_ENABLE_FAST_JIT`
`WASM_ENABLE_CUSTOM_NAME_SECTION`
`WASM_ENABLE_FAST_INTERP`
`WASM_ENABLE_FAST_JIT`
`WASM_ENABLE_JIT`
`WASM_ENABLE_FAST_JIT`
`WASM_ENABLE_FAST_JIT`
`WASM_ENABLE_BULK_MEMORY`
`WASM_ENABLE_LIBC_WASI`
`WASM_ENABLE_DEBUG_INTERP`
`WASM_ENABLE_LOAD_CUSTOM_SECTION`
`WASM_ENABLE_FAST_JIT`
`WASM_ENABLE_BULK_MEMORY`
*/
