module refcount;
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

 
public import bh_platform;
public import locking;

enum string PRODUCES(...) = ` LOCKS_SHARED(__VA_ARGS__) NO_LOCK_ANALYSIS`;
enum string CONSUMES(...) = ` UNLOCKS(__VA_ARGS__) NO_LOCK_ANALYSIS`;

static if (CONFIG_HAS_STD_ATOMIC != 0) {

public import stdatomic;

/* Simple reference counter. */
LOCKABLE refcount {
    atomic_uint count = void;
}{}

/* Initialize the reference counter. */
pragma(inline, true) private void refcount_init(refcount* r, uint count); PRODUCES* r {
    atomic_init(&r.count, count);
}

/* Increment the reference counter. */
pragma(inline, true) private void refcount_acquire(refcount* r); PRODUCES* r {
    atomic_fetch_add_explicit(&r.count, 1, memory_order_acquire);
}

/* Decrement the reference counter, returning whether the reference
   dropped to zero. */
pragma(inline, true) private bool refcount_release(refcount* r); CONSUMES* r {
    int old = cast(int)atomic_fetch_sub_explicit(&r.count, 1, memory_order_release);
    bh_assert(old != 0 && "Reference count becoming negative");
    return old == 1;
}

} else version (BH_PLATFORM_LINUX_SGX) {

public import sgx_spinlock;

/* Simple reference counter. */
struct refcount {
    sgx_spinlock_t lock;
    uint count;
};

/* Initialize the reference counter. */
pragma(inline, true) private void refcount_init(refcount* r, uint count) {
    r.lock = SGX_SPINLOCK_INITIALIZER;
    r.count = count;
}

/* Increment the reference counter. */
pragma(inline, true) private void refcount_acquire(refcount* r) {
    sgx_spin_lock(&r.lock);
    r.count++;
    sgx_spin_unlock(&r.lock);
}

/* Decrement the reference counter, returning whether the reference
   dropped to zero. */
pragma(inline, true) private bool refcount_release(refcount* r) {
    int old = void;
    sgx_spin_lock(&r.lock);
    old = cast(int)r.count;
    r.count--;
    sgx_spin_unlock(&r.lock);
    bh_assert(old != 0 && "Reference count becoming negative");
    return old == 1;
}

} else { /* else of CONFIG_HAS_STD_ATOMIC */
static assert(0, "Reference counter isn't implemented");
} /* end of CONFIG_HAS_STD_ATOMIC */

 /* end of REFCOUNT_H */
