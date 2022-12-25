module str;
@nogc nothrow:
extern(C): __gshared:
// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

public import ssp_config;
public import bh_platform;
public import str;

private char* bh_strndup(const(char)* s, size_t n) {
    size_t l = strnlen(s, n);
    char* s1 = wasm_runtime_malloc((uint32)(l + 1));

    if (!s1)
        return null;
    bh_memcpy_s(s1, (uint32)(l + 1), s, cast(uint)l);
    s1[l] = 0;
    return s1;
}

char* str_nullterminate(const(char)* s, size_t len) {
    /* Copy string */
    char* ret = bh_strndup(s, len);

    if (ret == null)
        return null;

    /* Ensure that it contains no null bytes within */
    if (strlen(ret) != len) {
        wasm_runtime_free(ret);
        errno = EILSEQ;
        return null;
    }
    return ret;
}
// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

 
public import ssp_config;

char* str_nullterminate(const(char)*, size_t);


