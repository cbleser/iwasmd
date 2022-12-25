module ems_kfc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import ems_gc_internal;

private gc_handle_t gc_init_internal(gc_heap_t* heap, char* base_addr, gc_size_t heap_max_size) {
    hmu_tree_node_t* root = null, q = null;
    int ret = void;

    memset(heap, 0, sizeof *heap);

    ret = os_mutex_init(&heap.lock);
    if (ret != BHT_OK) {
        os_printf("[GC_ERROR]failed to init lock\n");
        return null;
    }

    /* init all data structures*/
    heap.current_size = heap_max_size;
    heap.base_addr = cast(gc_uint8*)base_addr;
    heap.heap_id = cast(gc_handle_t)heap;

    heap.total_free_size = heap.current_size;
    heap.highmark_size = 0;

    root = &heap.kfc_tree_root;
    memset(root, 0, sizeof *root);
    root.size = sizeof *root;
    hmu_set_ut(&root.hmu_header, HMU_FC);
    hmu_set_size(&root.hmu_header, sizeof *root);

    q = cast(hmu_tree_node_t*)heap.base_addr;
    memset(q, 0, sizeof *q);
    hmu_set_ut(&q.hmu_header, HMU_FC);
    hmu_set_size(&q.hmu_header, heap.current_size);

    hmu_mark_pinuse(&q.hmu_header);
    root.right = q;
    q.parent = root;
    q.size = heap.current_size;

    bh_assert(root.size <= HMU_FC_NORMAL_MAX_SIZE);

    return heap;
}

gc_handle_t gc_init_with_pool(char* buf, gc_size_t buf_size) {
    char* buf_end = buf + buf_size;
    char* buf_aligned = cast(char*)((cast(uintptr_t)buf + 7) & cast(uintptr_t)~7);
    char* base_addr = buf_aligned + gc_heap_t.sizeof;
    gc_heap_t* heap = cast(gc_heap_t*)buf_aligned;
    gc_size_t heap_max_size = void;

    if (buf_size < APP_HEAP_SIZE_MIN) {
        os_printf("[GC_ERROR]heap init buf size (%" PRIu32 ~ ") < %" PRIu32 ~ "\n",
                  buf_size, cast(uint)APP_HEAP_SIZE_MIN);
        return null;
    }

    base_addr =
        cast(char*)((cast(uintptr_t)base_addr + 7) & cast(uintptr_t)~7) + GC_HEAD_PADDING;
    heap_max_size = (uint32)(buf_end - base_addr) & cast(uint)~7;

static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    os_printf("Heap created, total size: %u\n", buf_size);
    os_printf("   heap struct size: %u\n", gc_heap_t.sizeof);
    os_printf("   actual heap size: %u\n", heap_max_size);
    os_printf("   padding bytes: %u\n",
              buf_size - sizeof(gc_heap_t) - heap_max_size);
}
    return gc_init_internal(heap, base_addr, heap_max_size);
}

gc_handle_t gc_init_with_struct_and_pool(char* struct_buf, gc_size_t struct_buf_size, char* pool_buf, gc_size_t pool_buf_size) {
    gc_heap_t* heap = cast(gc_heap_t*)struct_buf;
    char* base_addr = pool_buf + GC_HEAD_PADDING;
    char* pool_buf_end = pool_buf + pool_buf_size;
    gc_size_t heap_max_size = void;

    if (((cast(uintptr_t)struct_buf) & 7) != 0) {
        os_printf("[GC_ERROR]heap init struct buf not 8-byte aligned\n");
        return null;
    }

    if (struct_buf_size < gc_handle_t.sizeof) {
        os_printf("[GC_ERROR]heap init struct buf size (%" PRIu32 ~ ") < %zu\n",
                  struct_buf_size, gc_handle_t.sizeof);
        return null;
    }

    if (((cast(uintptr_t)pool_buf) & 7) != 0) {
        os_printf("[GC_ERROR]heap init pool buf not 8-byte aligned\n");
        return null;
    }

    if (pool_buf_size < APP_HEAP_SIZE_MIN) {
        os_printf("[GC_ERROR]heap init buf size (%" PRIu32 ~ ") < %u\n",
                  pool_buf_size, APP_HEAP_SIZE_MIN);
        return null;
    }

    heap_max_size = (uint32)(pool_buf_end - base_addr) & cast(uint)~7;

static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    os_printf("Heap created, total size: %u\n",
              struct_buf_size + pool_buf_size);
    os_printf("   heap struct size: %u\n", gc_heap_t.sizeof);
    os_printf("   actual heap size: %u\n", heap_max_size);
    os_printf("   padding bytes: %u\n", pool_buf_size - heap_max_size);
}
    return gc_init_internal(heap, base_addr, heap_max_size);
}

int gc_destroy_with_pool(gc_handle_t handle) {
    gc_heap_t* heap = cast(gc_heap_t*)handle;
    int ret = GC_SUCCESS;

static if (BH_ENABLE_GC_VERIFY != 0) {
    hmu_t* cur = cast(hmu_t*)heap.base_addr;
    hmu_t* end = cast(hmu_t*)(cast(char*)heap.base_addr + heap.current_size);

    if (!heap.is_heap_corrupted
        && cast(hmu_t*)(cast(char*)cur + hmu_get_size(cur)) != end) {
        os_printf("Memory leak detected:\n");
        gci_dump(heap);
        ret = GC_ERROR;
    }
}

    os_mutex_destroy(&heap.lock);
    memset(heap, 0, gc_heap_t.sizeof);
    return ret;
}

uint gc_get_heap_struct_size() {
    return gc_heap_t.sizeof;
}

private void adjust_ptr(ubyte** p_ptr, intptr_t offset) {
    if (*p_ptr)
        *p_ptr += offset;
}

int gc_migrate(gc_handle_t handle, char* pool_buf_new, gc_size_t pool_buf_size) {
    gc_heap_t* heap = cast(gc_heap_t*)handle;
    char* base_addr_new = pool_buf_new + GC_HEAD_PADDING;
    char* pool_buf_end = pool_buf_new + pool_buf_size;
    intptr_t offset = cast(ubyte*)base_addr_new - cast(ubyte*)heap.base_addr;
    hmu_t* cur = null, end = null;
    hmu_tree_node_t* tree_node = void;
    gc_size_t heap_max_size = void, size = void;

    if (((cast(uintptr_t)pool_buf_new) & 7) != 0) {
        os_printf("[GC_ERROR]heap migrate pool buf not 8-byte aligned\n");
        return GC_ERROR;
    }

    heap_max_size = (uint32)(pool_buf_end - base_addr_new) & cast(uint)~7;

    if (pool_buf_end < base_addr_new || heap_max_size < heap.current_size) {
        os_printf("[GC_ERROR]heap migrate invlaid pool buf size\n");
        return GC_ERROR;
    }

    if (offset == 0)
        return 0;

    if (heap.is_heap_corrupted) {
        os_printf("[GC_ERROR]Heap is corrupted, heap migrate failed.\n");
        return GC_ERROR;
    }

    heap.base_addr = cast(ubyte*)base_addr_new;
    adjust_ptr(cast(ubyte**)&heap.kfc_tree_root.left, offset);
    adjust_ptr(cast(ubyte**)&heap.kfc_tree_root.right, offset);
    adjust_ptr(cast(ubyte**)&heap.kfc_tree_root.parent, offset);

    cur = cast(hmu_t*)heap.base_addr;
    end = cast(hmu_t*)(cast(char*)heap.base_addr + heap.current_size);

    while (cur < end) {
        size = hmu_get_size(cur);

        if (size <= 0 || size > (uint32)(cast(ubyte*)end - cast(ubyte*)cur)) {
            os_printf("[GC_ERROR]Heap is corrupted, heap migrate failed.\n");
            heap.is_heap_corrupted = true;
            return GC_ERROR;
        }

        if (hmu_get_ut(cur) == HMU_FC && !HMU_IS_FC_NORMAL(size)) {
            tree_node = cast(hmu_tree_node_t*)cur;
            adjust_ptr(cast(ubyte**)&tree_node.left, offset);
            adjust_ptr(cast(ubyte**)&tree_node.right, offset);
            if (tree_node.parent != &heap.kfc_tree_root)
                /* The root node belongs to heap structure,
                   it is fixed part and isn't changed. */
                adjust_ptr(cast(ubyte**)&tree_node.parent, offset);
        }
        cur = cast(hmu_t*)(cast(char*)cur + size);
    }

    if (cur != end) {
        os_printf("[GC_ERROR]Heap is corrupted, heap migrate failed.\n");
        heap.is_heap_corrupted = true;
        return GC_ERROR;
    }

    return 0;
}

bool gc_is_heap_corrupted(gc_handle_t handle) {
    gc_heap_t* heap = cast(gc_heap_t*)handle;

    return heap.is_heap_corrupted ? true : false;
}

static if (BH_ENABLE_GC_VERIFY != 0) {
void gci_verify_heap(gc_heap_t* heap) {
    hmu_t* cur = null, end = null;

    bh_assert(heap && gci_is_heap_valid(heap));
    cur = cast(hmu_t*)heap.base_addr;
    end = cast(hmu_t*)(heap.base_addr + heap.current_size);
    while (cur < end) {
        hmu_verify(heap, cur);
        cur = cast(hmu_t*)(cast(gc_uint8*)cur + hmu_get_size(cur));
    }
    bh_assert(cur == end);
}
}

void* gc_heap_stats(void* heap_arg, uint* stats, int size) {
    int i = void;
    gc_heap_t* heap = cast(gc_heap_t*)heap_arg;

    for (i = 0; i < size; i++) {
        switch (i) {
            case GC_STAT_TOTAL:
                stats[i] = heap.current_size;
                break;
            case GC_STAT_FREE:
                stats[i] = heap.total_free_size;
                break;
            case GC_STAT_HIGHMARK:
                stats[i] = heap.highmark_size;
                break;
            default:
                break;
        }
    }
    return heap;
}
