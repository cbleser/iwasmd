module random;
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
public import random;

static if (CONFIG_HAS_ARC4RANDOM_BUF) {

void random_buf(void* buf, size_t len) {
    arc4random_buf(buf, len);
}

} else static if (CONFIG_HAS_GETRANDOM) {

version (BH_PLATFORM_LINUX_SGX) {} else {
public import sys/random;
}

void random_buf(void* buf, size_t len) {
    for (;;) {
        ssize_t x = getrandom(buf, len, 0);
        if (x < 0) {
            if (errno == EINTR)
                continue;
            os_printf("getrandom failed: %s", strerror(errno));
            abort();
        }
        if (cast(size_t)x == len)
            return;
        buf = cast(void*)(cast(ubyte*)buf + x);
        len -= cast(size_t)x;
    }
}

} else {

private int urandom;

private void open_urandom() {
    urandom = open("/dev/urandom", O_RDONLY);
    if (urandom < 0) {
        os_printf("Failed to open /dev/urandom\n");
        abort();
    }
}

void random_buf(void* buf, size_t len) {
    static pthread_once_t open_once = PTHREAD_ONCE_INIT;
    pthread_once(&open_once, &open_urandom);

    if (cast(size_t)read(urandom, buf, len) != len) {
        os_printf("Short read on /dev/urandom\n");
        abort();
    }
}

}

// Calculates a random number within the range [0, upper - 1] without
// any modulo bias.
//
// The function below repeatedly obtains a random number from
// arc4random() until it lies within the range [2^k % upper, 2^k). As
// this range has length k * upper, we can safely obtain a number
// without any modulo bias.
uintmax_t random_uniform(uintmax_t upper) {
    // Compute 2^k % upper
    //      == (2^k - upper) % upper
    //      == -upper % upper.
    uintmax_t lower = -upper % upper;
    for (;;) {
        uintmax_t value = void;
        random_buf(&value, value.sizeof);
        if (value >= lower)
            return value % upper;
    }
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

 
void random_buf(void*, size_t);
uintmax_t random_uniform(uintmax_t);


