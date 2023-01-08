module jit_utils;
@nogc nothrow:
extern(C): __gshared:
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* This header is separate from features.h so that the compiler can
   include it implicitly at the start of every compilation.  It must
   not itself include <features.h> or any other header that includes
   <features.h> because the implicit include comes before any feature
   test macros that may be defined in a source file before it first
   explicitly includes a system header.  GCC knows the name of this
   header in order to preinclude it.  */
/* glibc's intent is to support the IEC 559 math functionality, real
   and complex.  If the GCC (4.9 and later) predefined macros
   specifying compiler intent are available, use them to determine
   whether the overall intent is to support these features; otherwise,
   presume an older compiler has intent to support these features and
   define these macros by default.  */
/* wchar_t uses Unicode 10.0.0.  Version 10.0 of the Unicode Standard is
   synchronized with ISO/IEC 10646:2017, fifth edition, plus
   the following additions from Amendment 1 to the fifth edition:
   - 56 emoji characters
   - 285 hentaigana
   - 3 additional Zanabazar Square characters */
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
//#include "bh_platform.h"
import core.stdc.string : memset, memcpy;
import core.stdc.stdint : uintptr_t;
import tagion.iwasm.share.utils.bh_assert;
import tagion.iwasm.fast_jit.jit_ir;
import tagion.iwasm.fast_jit.jit_frame;
import tagion.iwasm.common.wasm_memory;
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
pragma(inline, true) void* jit_malloc(size_t size) {
    return wasm_runtime_malloc(size);
}
T* jit_malloc(T)(size_t size) {
    return cast(T*)wasm_runtime_malloc(cast(uint)size);
}
 T* jit_calloc(T)(size_t size) {
    auto ret = wasm_runtime_malloc(cast(uint)size);
    if (ret) {
        memset(ret, 0, size);
    }
    return cast(T*)ret;
}
pragma(inline, true) JitInsn* jit_calloc(size_t size) {
	return jit_calloc!JitInsn(size);
}
pragma(inline, true) JitInsn** jit_calloc_ref(size_t size) {
	return jit_calloc!(JitInsn*)(size);
}
pragma(inline, true) uint* jit_calloc_reg(size_t size) {
	return jit_calloc!(uint)(size);
}
pragma(inline, true) ubyte* jit_calloc_buffer(size_t size) {
	return jit_calloc!(ubyte)(size);
}
pragma(inline, true) JitIncomingInsn** jit_calloc_list(size_t size) {
	return jit_calloc!(JitIncomingInsn*)(size);
}
pragma(inline, true) JitIncomingInsn* jit_calloc_incoming(size_t size) {
	return jit_calloc!(JitIncomingInsn)(size);
}
pragma(inline, true) JitValue* jit_calloc_value(size_t size) {
	return jit_calloc!(JitValue)(size);
}
pragma(inline, true) JitMemRegs* jit_calloc_memregs(size_t size) {
	return jit_calloc!(JitMemRegs)(size);
}
pragma(inline, true) JitTableRegs* jit_calloc_tableregs(size_t size) {
	return jit_calloc!(JitTableRegs)(size);
}
pragma(inline, true) JitFrame* jit_calloc_frame(size_t size) {
	return jit_calloc!(JitFrame)(size);
}
pragma(inline, true) JitBlock* jit_calloc_block(size_t size) {
	return jit_calloc!(JitBlock)(size);
}
/*
 * Reallocate a memory block with the new_size.
 * TODO: replace this with imported jit_realloc when it's available.
 */
T* jit_realloc(T)(void* ptr, size_t new_size, size_t old_size) {
    void* new_ptr = jit_malloc(new_size);
    if (new_ptr) {
        bh_assert(new_size > old_size);
        if (ptr) {
            memcpy(new_ptr, ptr, old_size);
            memset(cast(ubyte*) new_ptr + old_size, 0, new_size - old_size);
            jit_free(ptr);
        }
        else
            memset(new_ptr, 0, new_size);
    }
    return cast(T*)new_ptr;
}

JitInsn* jit_realloc(JitInsn* ptr, size_t new_size, size_t old_size) {
 	return jit_realloc!JitInsn(ptr, new_size, old_size);
}

ubyte* jit_realloc_buffer(ubyte* ptr, size_t new_size, size_t old_size) {
 	return jit_realloc!ubyte(ptr, new_size, old_size);
}

uint* jit_realloc_reg(uint* ptr, size_t new_size, size_t old_size) {
 	return jit_realloc!uint(ptr, new_size, old_size);
}


pragma(inline, true) void jit_free(void* ptr) {
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
pragma(inline, true) void jit_bitmap_delete(JitBitmap* bitmap) {
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
pragma(inline, true) bool jit_bitmap_is_in_range(JitBitmap* bitmap, uint n) {
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
pragma(inline, true) int jit_bitmap_get_bit(JitBitmap* bitmap, uint n) {
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
pragma(inline, true) void jit_bitmap_set_bit(JitBitmap* bitmap, uint n) {
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
pragma(inline, true) void jit_bitmap_clear_bit(JitBitmap* bitmap, uint n) {
    uint idx = n - bitmap.begin_index;
    bh_assert(n >= bitmap.begin_index && n < bitmap.end_index);
    bitmap.map[idx / 8] &= ~(1 << (idx % 8));
}
