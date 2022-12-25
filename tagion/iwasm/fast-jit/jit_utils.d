module jit_utils;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_utils;

JitBitmap* jit_bitmap_new(uintptr_t begin_index, uint bitnum) {
    JitBitmap* bitmap = void;

    if ((bitmap = jit_calloc(JitBitmap.map.offsetof + (bitnum + 7) / 8))) {
        bitmap.begin_index = begin_index;
        bitmap.end_index = begin_index + bitnum;
    }

    return bitmap;
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;

version (none) {
extern "C" {
//! #endif

/**
 * A simple fixed size bitmap.
 */
struct JitBitmap {
    /* The first valid bit index.  */
    uintptr_t begin_index;

    /* The last valid bit index plus one.  */
    uintptr_t end_index;

    /* The bitmap.  */
    ubyte[1] map;
}

pragma(inline, true) private void* jit_malloc(uint size) {
    return wasm_runtime_malloc(size);
}

pragma(inline, true) private void* jit_calloc(uint size) {
    void* ret = wasm_runtime_malloc(size);
    if (ret) {
        memset(ret, 0, size);
    }
    return ret;
}

pragma(inline, true) private void jit_free(void* ptr) {
    if (ptr)
        wasm_runtime_free(ptr);
}

/**
 * Create a new bitmap.
 *
 * @param begin_index the first valid bit index
 * @param bitnum maximal bit number of the bitmap.
 *
 * @return the new bitmap if succeeds, NULL otherwise.
 */
JitBitmap* jit_bitmap_new(uintptr_t begin_index, uint bitnum);

/**
 * Delete a bitmap.
 *
 * @param bitmap the bitmap to be deleted
 */
pragma(inline, true) private void jit_bitmap_delete(JitBitmap* bitmap) {
    jit_free(bitmap);
}

/**
 * Check whether the given index is in the range of the bitmap.
 *
 * @param bitmap the bitmap
 * @param n the bit index
 *
 * @return true if the index is in range, false otherwise
 */
pragma(inline, true) private bool jit_bitmap_is_in_range(JitBitmap* bitmap, uint n) {
    return n >= bitmap.begin_index && n < bitmap.end_index;
}

/**
 * Get a bit in the bitmap
 *
 * @param bitmap the bitmap
 * @param n the n-th bit to be get
 *
 * @return value of the bit
 */
pragma(inline, true) private int jit_bitmap_get_bit(JitBitmap* bitmap, uint n) {
    uint idx = n - bitmap.begin_index;
    bh_assert(n >= bitmap.begin_index && n < bitmap.end_index);
    return (bitmap.map[idx / 8] >> (idx % 8)) & 1;
}

/**
 * Set a bit in the bitmap.
 *
 * @param bitmap the bitmap
 * @param n the n-th bit to be set
 */
pragma(inline, true) private void jit_bitmap_set_bit(JitBitmap* bitmap, uint n) {
    uint idx = n - bitmap.begin_index;
    bh_assert(n >= bitmap.begin_index && n < bitmap.end_index);
    bitmap.map[idx / 8] |= 1 << (idx % 8);
}

/**
 * Clear a bit in the bitmap.
 *
 * @param bitmap the bitmap
 * @param n the n-th bit to be cleared
 */
pragma(inline, true) private void jit_bitmap_clear_bit(JitBitmap* bitmap, uint n) {
    uint idx = n - bitmap.begin_index;
    bh_assert(n >= bitmap.begin_index && n < bitmap.end_index);
    bitmap.map[idx / 8] &= ~(1 << (idx % 8));
}

version (none) {}
}
}


