module tagion.iwasm.basic;

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
