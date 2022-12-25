module ems_alloc;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import ems_gc_internal;

pragma(inline, true) private bool hmu_is_in_heap(void* hmu, gc_uint8* heap_base_addr, gc_uint8* heap_end_addr) {
    gc_uint8* addr = cast(gc_uint8*)hmu;
    return (addr >= heap_base_addr && addr < heap_end_addr) ? true : false;
}

/**
 * Remove a node from the tree it belongs to
 *
 * @param p the node to remove, can not be NULL, can not be the ROOT node
 *        the node will be removed from the tree, and the left, right and
 *        parent pointers of the node @p will be set to be NULL. Other fields
 *        won't be touched. The tree will be re-organized so that the order
 *        conditions are still satisified.
 */
private bool remove_tree_node(gc_heap_t* heap, hmu_tree_node_t* p) {
    hmu_tree_node_t* q = null; hmu_tree_node_t** slot = null; hmu_tree_node_t* parent = void;
    hmu_tree_node_t* root = &heap.kfc_tree_root;
    gc_uint8* base_addr = heap.base_addr;
    gc_uint8* end_addr = base_addr + heap.current_size;

    bh_assert(p);

    parent = p.parent;
    if (!parent || p == root /* p can not be the ROOT node */
        || !hmu_is_in_heap(p, base_addr, end_addr)
        || (parent != root && !hmu_is_in_heap(parent, base_addr, end_addr))) {
        goto fail;
    }

    /* get the slot which holds pointer to node p*/
    if (p == p.parent.right) {
        slot = &p.parent.right;
    }
    else if (p == p.parent.left) {
        /* p should be a child of its parent*/
        slot = &p.parent.left;
    }
    else {
        goto fail;
    }

    /**
     * algorithms used to remove node p
     * case 1: if p has no left child, replace p with its right child
     * case 2: if p has no right child, replace p with its left child
     * case 3: otherwise, find p's predecessor, remove it from the tree
     *         and replace p with it.
     * use predecessor can keep the left <= root < right condition.
     */

    if (!p.left) {
        /* move right child up*/
        *slot = p.right;
        if (p.right) {
            if (!hmu_is_in_heap(p.right, base_addr, end_addr)) {
                goto fail;
            }
            p.right.parent = p.parent;
        }

        p.left = p.right = p.parent = null;
        return true;
    }

    if (!p.right) {
        /* move left child up*/
        *slot = p.left;
        if (!hmu_is_in_heap(p.left, base_addr, end_addr)) {
            goto fail;
        }
        /* p->left can never be NULL unless it is corrupted. */
        p.left.parent = p.parent;

        p.left = p.right = p.parent = null;
        return true;
    }

    /* both left & right exist, find p's predecessor at first*/
    q = p.left;
    if (!hmu_is_in_heap(q, base_addr, end_addr)) {
        goto fail;
    }
    while (q.right) {
        q = q.right;
        if (!hmu_is_in_heap(q, base_addr, end_addr)) {
            goto fail;
        }
    }

    /* remove from the tree*/
    if (!remove_tree_node(heap, q))
        return false;

    *slot = q;
    q.parent = p.parent;
    q.left = p.left;
    q.right = p.right;
    if (q.left) {
        if (!hmu_is_in_heap(q.left, base_addr, end_addr)) {
            goto fail;
        }
        q.left.parent = q;
    }
    if (q.right) {
        if (!hmu_is_in_heap(q.right, base_addr, end_addr)) {
            goto fail;
        }
        q.right.parent = q;
    }

    p.left = p.right = p.parent = null;

    return true;
fail:
    heap.is_heap_corrupted = true;
    return false;
}

private bool unlink_hmu(gc_heap_t* heap, hmu_t* hmu) {
    gc_uint8* base_addr = void, end_addr = void;
    gc_size_t size = void;

    bh_assert(gci_is_heap_valid(heap));
    bh_assert(hmu && cast(gc_uint8*)hmu >= heap.base_addr
              && cast(gc_uint8*)hmu < heap.base_addr + heap.current_size);

    if (hmu_get_ut(hmu) != HMU_FC) {
        heap.is_heap_corrupted = true;
        return false;
    }

    base_addr = heap.base_addr;
    end_addr = base_addr + heap.current_size;
    size = hmu_get_size(hmu);

    if (HMU_IS_FC_NORMAL(size)) {
        uint node_idx = size >> 3;
        hmu_normal_node_t* node_prev = null, node_next = void;
        hmu_normal_node_t* node = heap.kfc_normal_list[node_idx].next;

        while (node) {
            if (!hmu_is_in_heap(node, base_addr, end_addr)) {
                heap.is_heap_corrupted = true;
                return false;
            }
            node_next = get_hmu_normal_node_next(node);
            if (cast(hmu_t*)node == hmu) {
                if (!node_prev) /* list head */
                    heap.kfc_normal_list[node_idx].next = node_next;
                else
                    set_hmu_normal_node_next(node_prev, node_next);
                break;
            }
            node_prev = node;
            node = node_next;
        }

        if (!node) {
            os_printf("[GC_ERROR]couldn't find the node in the normal list\n");
        }
    }
    else {
        if (!remove_tree_node(heap, cast(hmu_tree_node_t*)hmu))
            return false;
    }
    return true;
}

private void hmu_set_free_size(hmu_t* hmu) {
    gc_size_t size = void;
    bh_assert(hmu && hmu_get_ut(hmu) == HMU_FC);

    size = hmu_get_size(hmu);
    *(cast(uint*)(cast(char*)hmu + size) - 1) = size;
}

/**
 * Add free chunk back to KFC
 *
 * @param heap should not be NULL and it should be a valid heap
 * @param hmu should not be NULL and it should be a HMU of length @size inside
 *        @heap hmu should be 8-bytes aligned
 * @param size should be positive and multiple of 8
 *        hmu with size @size will be added into KFC as a new FC.
 */
bool gci_add_fc(gc_heap_t* heap, hmu_t* hmu, gc_size_t size) {
    gc_uint8* base_addr = void, end_addr = void;
    hmu_normal_node_t* np = null;
    hmu_tree_node_t* root = null, tp = null, node = null;
    uint node_idx = void;

    bh_assert(gci_is_heap_valid(heap));
    bh_assert(hmu && cast(gc_uint8*)hmu >= heap.base_addr
              && cast(gc_uint8*)hmu < heap.base_addr + heap.current_size);
    bh_assert((cast(gc_uint32)cast(uintptr_t)hmu_to_obj(hmu) & 7) == 0);
    bh_assert(size > 0
              && (cast(gc_uint8*)hmu) + size
                     <= heap.base_addr + heap.current_size);
    bh_assert(!(size & 7));

    base_addr = heap.base_addr;
    end_addr = base_addr + heap.current_size;

    hmu_set_ut(hmu, HMU_FC);
    hmu_set_size(hmu, size);
    hmu_set_free_size(hmu);

    if (HMU_IS_FC_NORMAL(size)) {
        np = cast(hmu_normal_node_t*)hmu;
        if (!hmu_is_in_heap(np, base_addr, end_addr)) {
            heap.is_heap_corrupted = true;
            return false;
        }

        node_idx = size >> 3;
        set_hmu_normal_node_next(np, heap.kfc_normal_list[node_idx].next);
        heap.kfc_normal_list[node_idx].next = np;
        return true;
    }

    /* big block */
    node = cast(hmu_tree_node_t*)hmu;
    node.size = size;
    node.left = node.right = node.parent = null;

    /* find proper node to link this new node to */
    root = &heap.kfc_tree_root;
    tp = root;
    bh_assert(tp.size < size);
    while (1) {
        if (tp.size < size) {
            if (!tp.right) {
                tp.right = node;
                node.parent = tp;
                break;
            }
            tp = tp.right;
        }
        else { /* tp->size >= size */
            if (!tp.left) {
                tp.left = node;
                node.parent = tp;
                break;
            }
            tp = tp.left;
        }
        if (!hmu_is_in_heap(tp, base_addr, end_addr)) {
            heap.is_heap_corrupted = true;
            return false;
        }
    }
    return true;
}

/**
 * Find a proper hmu for required memory size
 *
 * @param heap should not be NULL and should be a valid heap
 * @param size should cover the header and should be 8 bytes aligned
 *        GC will not be performed here.
 *        Heap extension will not be performed here.
 *
 * @return hmu allocated if success, which will be aligned to 8 bytes,
 *         NULL otherwise
 */
private hmu_t* alloc_hmu(gc_heap_t* heap, gc_size_t size) {
    gc_uint8* base_addr = void, end_addr = void;
    hmu_normal_list_t* normal_head = null;
    hmu_normal_node_t* p = null;
    uint node_idx = 0, init_node_idx = 0;
    hmu_tree_node_t* root = null, tp = null, last_tp = null;
    hmu_t* next = void, rest = void;

    bh_assert(gci_is_heap_valid(heap));
    bh_assert(size > 0 && !(size & 7));

    base_addr = heap.base_addr;
    end_addr = base_addr + heap.current_size;

    if (size < GC_SMALLEST_SIZE)
        size = GC_SMALLEST_SIZE;

    /* check normal list at first*/
    if (HMU_IS_FC_NORMAL(size)) {
        /* find a non-empty slot in normal_node_list with good size*/
        init_node_idx = (size >> 3);
        for (node_idx = init_node_idx; node_idx < HMU_NORMAL_NODE_CNT;
             node_idx++) {
            normal_head = heap.kfc_normal_list + node_idx;
            if (normal_head.next)
                break;
            normal_head = null;
        }

        /* found in normal list*/
        if (normal_head) {
            bh_assert(node_idx >= init_node_idx);

            p = normal_head.next;
            if (!hmu_is_in_heap(p, base_addr, end_addr)) {
                heap.is_heap_corrupted = true;
                return null;
            }
            normal_head.next = get_hmu_normal_node_next(p);
            if ((cast(gc_int32)cast(uintptr_t)hmu_to_obj(p) & 7) != 0) {
                heap.is_heap_corrupted = true;
                return null;
            }

            if (cast(gc_size_t)node_idx != cast(uint)init_node_idx
                /* with bigger size*/
                && (cast(gc_size_t)node_idx << 3) >= size + GC_SMALLEST_SIZE) {
                rest = cast(hmu_t*)((cast(char*)p) + size);
                if (!gci_add_fc(heap, rest, (node_idx << 3) - size)) {
                    return null;
                }
                hmu_mark_pinuse(rest);
            }
            else {
                size = node_idx << 3;
                next = cast(hmu_t*)(cast(char*)p + size);
                if (hmu_is_in_heap(next, base_addr, end_addr))
                    hmu_mark_pinuse(next);
            }

            heap.total_free_size -= size;
            if ((heap.current_size - heap.total_free_size)
                > heap.highmark_size)
                heap.highmark_size =
                    heap.current_size - heap.total_free_size;

            hmu_set_size(cast(hmu_t*)p, size);
            return cast(hmu_t*)p;
        }
    }

    /* need to find a node in tree*/
    root = &heap.kfc_tree_root;

    /* find the best node*/
    bh_assert(root);
    tp = root.right;
    while (tp) {
        if (!hmu_is_in_heap(tp, base_addr, end_addr)) {
            heap.is_heap_corrupted = true;
            return null;
        }

        if (tp.size < size) {
            tp = tp.right;
            continue;
        }

        /* record the last node with size equal to or bigger than given size*/
        last_tp = tp;
        tp = tp.left;
    }

    if (last_tp) {
        bh_assert(last_tp.size >= size);

        /* alloc in last_p*/

        /* remove node last_p from tree*/
        if (!remove_tree_node(heap, last_tp))
            return null;

        if (last_tp.size >= size + GC_SMALLEST_SIZE) {
            rest = cast(hmu_t*)(cast(char*)last_tp + size);
            if (!gci_add_fc(heap, rest, last_tp.size - size))
                return null;
            hmu_mark_pinuse(rest);
        }
        else {
            size = last_tp.size;
            next = cast(hmu_t*)(cast(char*)last_tp + size);
            if (hmu_is_in_heap(next, base_addr, end_addr))
                hmu_mark_pinuse(next);
        }

        heap.total_free_size -= size;
        if ((heap.current_size - heap.total_free_size) > heap.highmark_size)
            heap.highmark_size = heap.current_size - heap.total_free_size;

        hmu_set_size(cast(hmu_t*)last_tp, size);
        return cast(hmu_t*)last_tp;
    }

    return null;
}

/**
 * Find a proper HMU with given size
 *
 * @param heap should not be NULL and should be a valid heap
 * @param size should cover the header and should be 8 bytes aligned
 *
 * Note: This function will try several ways to satisfy the allocation request:
 *   1. Find a proper on available HMUs.
 *   2. GC will be triggered if 1 failed.
 *   3. Find a proper on available HMUS.
 *   4. Return NULL if 3 failed
 *
 * @return hmu allocated if success, which will be aligned to 8 bytes,
 *         NULL otherwise
 */
private hmu_t* alloc_hmu_ex(gc_heap_t* heap, gc_size_t size) {
    bh_assert(gci_is_heap_valid(heap));
    bh_assert(size > 0 && !(size & 7));

    return alloc_hmu(heap, size);
}

private c_ulong g_total_malloc = 0;
private c_ulong g_total_free = 0;

#if BH_ENABLE_GC_VERIFY == 0
gc_object_t gc_alloc_vo(void* vheap, gc_size_t size);
} else {
gc_object_t gc_alloc_vo_internal(void* vheap, gc_size_t size, const(char)* file, int line) {
    gc_heap_t* heap = cast(gc_heap_t*)vheap;
    hmu_t* hmu = null;
    gc_object_t ret = cast(gc_object_t)null;
    gc_size_t tot_size = 0, tot_size_unaligned = void;

    /* hmu header + prefix + obj + suffix */
    tot_size_unaligned = HMU_SIZE + OBJ_PREFIX_SIZE + size + OBJ_SUFFIX_SIZE;
    /* aligned size*/
    tot_size = GC_ALIGN_8(tot_size_unaligned);
    if (tot_size < size)
        /* integer overflow */
        return null;

    if (heap.is_heap_corrupted) {
        os_printf("[GC_ERROR]Heap is corrupted, allocate memory failed.\n");
        return null;
    }

    os_mutex_lock(&heap.lock);

    hmu = alloc_hmu_ex(heap, tot_size);
    if (!hmu)
        goto finish;

    bh_assert(hmu_get_size(hmu) >= tot_size);
    /* the total size allocated may be larger than
       the required size, reset it here */
    tot_size = hmu_get_size(hmu);

    g_total_malloc += tot_size;

    hmu_set_ut(hmu, HMU_VO);
    hmu_unfree_vo(hmu);

static if (BH_ENABLE_GC_VERIFY != 0) {
    hmu_init_prefix_and_suffix(hmu, tot_size, file, line);
}

    ret = hmu_to_obj(hmu);
    if (tot_size > tot_size_unaligned)
        /* clear buffer appended by GC_ALIGN_8() */
        memset(cast(ubyte*)ret + size, 0, tot_size - tot_size_unaligned);

finish:
    os_mutex_unlock(&heap.lock);
    return ret;
}

#if BH_ENABLE_GC_VERIFY == 0
gc_object_t gc_realloc_vo(void* vheap, void* ptr, gc_size_t size);
} else {
gc_object_t gc_realloc_vo_internal(void* vheap, void* ptr, gc_size_t size, const(char)* file, int line) {
    gc_heap_t* heap = cast(gc_heap_t*)vheap;
    hmu_t* hmu = null, hmu_old = null, hmu_next = void;
    gc_object_t ret = cast(gc_object_t)null, obj_old = cast(gc_object_t)ptr;
    gc_size_t tot_size = void, tot_size_unaligned = void, tot_size_old = 0, tot_size_next = void;
    gc_size_t obj_size = void, obj_size_old = void;
    gc_uint8* base_addr = void, end_addr = void;
    hmu_type_t ut = void;

    /* hmu header + prefix + obj + suffix */
    tot_size_unaligned = HMU_SIZE + OBJ_PREFIX_SIZE + size + OBJ_SUFFIX_SIZE;
    /* aligned size*/
    tot_size = GC_ALIGN_8(tot_size_unaligned);
    if (tot_size < size)
        /* integer overflow */
        return null;

    if (heap.is_heap_corrupted) {
        os_printf("[GC_ERROR]Heap is corrupted, allocate memory failed.\n");
        return null;
    }

    if (obj_old) {
        hmu_old = obj_to_hmu(obj_old);
        tot_size_old = hmu_get_size(hmu_old);
        if (tot_size <= tot_size_old)
            /* current node alreay meets requirement */
            return obj_old;
    }

    base_addr = heap.base_addr;
    end_addr = base_addr + heap.current_size;

    os_mutex_lock(&heap.lock);

    if (hmu_old) {
        hmu_next = cast(hmu_t*)(cast(char*)hmu_old + tot_size_old);
        if (hmu_is_in_heap(hmu_next, base_addr, end_addr)) {
            ut = hmu_get_ut(hmu_next);
            tot_size_next = hmu_get_size(hmu_next);
            if (ut == HMU_FC && tot_size <= tot_size_old + tot_size_next) {
                /* current node and next node meets requirement */
                if (!unlink_hmu(heap, hmu_next)) {
                    os_mutex_unlock(&heap.lock);
                    return null;
                }
                hmu_set_size(hmu_old, tot_size);
                memset(cast(char*)hmu_old + tot_size_old, 0,
                       tot_size - tot_size_old);
static if (BH_ENABLE_GC_VERIFY != 0) {
                hmu_init_prefix_and_suffix(hmu_old, tot_size, file, line);
}
                if (tot_size < tot_size_old + tot_size_next) {
                    hmu_next = cast(hmu_t*)(cast(char*)hmu_old + tot_size);
                    tot_size_next = tot_size_old + tot_size_next - tot_size;
                    if (!gci_add_fc(heap, hmu_next, tot_size_next)) {
                        os_mutex_unlock(&heap.lock);
                        return null;
                    }
                }
                os_mutex_unlock(&heap.lock);
                return obj_old;
            }
        }
    }

    hmu = alloc_hmu_ex(heap, tot_size);
    if (!hmu)
        goto finish;

    bh_assert(hmu_get_size(hmu) >= tot_size);
    /* the total size allocated may be larger than
       the required size, reset it here */
    tot_size = hmu_get_size(hmu);
    g_total_malloc += tot_size;

    hmu_set_ut(hmu, HMU_VO);
    hmu_unfree_vo(hmu);

static if (BH_ENABLE_GC_VERIFY != 0) {
    hmu_init_prefix_and_suffix(hmu, tot_size, file, line);
}

    ret = hmu_to_obj(hmu);

finish:

    if (ret) {
        obj_size = tot_size - HMU_SIZE - OBJ_PREFIX_SIZE - OBJ_SUFFIX_SIZE;
        memset(ret, 0, obj_size);
        if (obj_old) {
            obj_size_old =
                tot_size_old - HMU_SIZE - OBJ_PREFIX_SIZE - OBJ_SUFFIX_SIZE;
            bh_memcpy_s(ret, obj_size, obj_old, obj_size_old);
        }
    }

    os_mutex_unlock(&heap.lock);

    if (ret && obj_old)
        gc_free_vo(vheap, obj_old);

    return ret;
}

/**
 * Do some checking to see if given pointer is a possible valid heap
 * @return GC_TRUE if all checking passed, GC_FALSE otherwise
 */
int gci_is_heap_valid(gc_heap_t* heap) {
    if (!heap)
        return GC_FALSE;
    if (heap.heap_id != cast(gc_handle_t)heap)
        return GC_FALSE;

    return GC_TRUE;
}

#if BH_ENABLE_GC_VERIFY == 0
int gc_free_vo(void* vheap, gc_object_t obj);
} else {
int gc_free_vo_internal(void* vheap, gc_object_t obj, const(char)* file, int line) {
    gc_heap_t* heap = cast(gc_heap_t*)vheap;
    gc_uint8* base_addr = void, end_addr = void;
    hmu_t* hmu = null;
    hmu_t* prev = null;
    hmu_t* next = null;
    gc_size_t size = 0;
    hmu_type_t ut = void;
    int ret = GC_SUCCESS;

    if (!obj) {
        return GC_SUCCESS;
    }

    if (heap.is_heap_corrupted) {
        os_printf("[GC_ERROR]Heap is corrupted, free memory failed.\n");
        return GC_ERROR;
    }

    hmu = obj_to_hmu(obj);

    base_addr = heap.base_addr;
    end_addr = base_addr + heap.current_size;

    os_mutex_lock(&heap.lock);

    if (hmu_is_in_heap(hmu, base_addr, end_addr)) {
static if (BH_ENABLE_GC_VERIFY != 0) {
        hmu_verify(heap, hmu);
}
        ut = hmu_get_ut(hmu);
        if (ut == HMU_VO) {
            if (hmu_is_vo_freed(hmu)) {
                bh_assert(0);
                ret = GC_ERROR;
                goto out;
            }

            size = hmu_get_size(hmu);

            g_total_free += size;

            heap.total_free_size += size;

            if (!hmu_get_pinuse(hmu)) {
                prev = cast(hmu_t*)(cast(char*)hmu - *(cast(int*)hmu - 1));

                if (hmu_is_in_heap(prev, base_addr, end_addr)
                    && hmu_get_ut(prev) == HMU_FC) {
                    size += hmu_get_size(prev);
                    hmu = prev;
                    if (!unlink_hmu(heap, prev)) {
                        ret = GC_ERROR;
                        goto out;
                    }
                }
            }

            next = cast(hmu_t*)(cast(char*)hmu + size);
            if (hmu_is_in_heap(next, base_addr, end_addr)) {
                if (hmu_get_ut(next) == HMU_FC) {
                    size += hmu_get_size(next);
                    if (!unlink_hmu(heap, next)) {
                        ret = GC_ERROR;
                        goto out;
                    }
                    next = cast(hmu_t*)(cast(char*)hmu + size);
                }
            }

            if (!gci_add_fc(heap, hmu, size)) {
                ret = GC_ERROR;
                goto out;
            }

            if (hmu_is_in_heap(next, base_addr, end_addr)) {
                hmu_unmark_pinuse(next);
            }
        }
        else {
            ret = GC_ERROR;
            goto out;
        }
        ret = GC_SUCCESS;
        goto out;
    }

out:
    os_mutex_unlock(&heap.lock);
    return ret;
}

void gc_dump_heap_stats(gc_heap_t* heap) {
    os_printf("heap: %p, heap start: %p\n", heap, heap.base_addr);
    os_printf("total free: %" PRIu32 ~ ", current: %" PRIu32
              ~ ", highmark: %" PRIu32 ~ "\n",
              heap.total_free_size, heap.current_size, heap.highmark_size);
    os_printf("g_total_malloc=%lu, g_total_free=%lu, occupied=%lu\n",
              g_total_malloc, g_total_free, g_total_malloc - g_total_free);
}

uint gc_get_heap_highmark_size(gc_heap_t* heap) {
    return heap.highmark_size;
}

void gci_dump(gc_heap_t* heap) {
    hmu_t* cur = null, end = null;
    hmu_type_t ut = void;
    gc_size_t size = void;
    int i = 0, p = void, mark = void;
    char inuse = 'U';

    cur = cast(hmu_t*)heap.base_addr;
    end = cast(hmu_t*)(cast(char*)heap.base_addr + heap.current_size);

    while (cur < end) {
        ut = hmu_get_ut(cur);
        size = hmu_get_size(cur);
        p = hmu_get_pinuse(cur);
        mark = hmu_is_jo_marked(cur);

        if (ut == HMU_VO)
            inuse = 'V';
        else if (ut == HMU_JO)
            inuse = hmu_is_jo_marked(cur) ? 'J' : 'j';
        else if (ut == HMU_FC)
            inuse = 'F';

        if (size == 0 || size > (uint32)(cast(ubyte*)end - cast(ubyte*)cur)) {
            os_printf("[GC_ERROR]Heap is corrupted, heap dump failed.\n");
            heap.is_heap_corrupted = true;
            return;
        }

        os_printf("#%d %08" PRIx32 ~ " %" PRIx32 ~ " %d %d"
                  ~ " %c %" PRId32 ~ "\n",
                  i, (int32)(cast(char*)cur - cast(char*)heap.base_addr), cast(int)ut,
                  p, mark, inuse, cast(int)hmu_obj_size(size));
static if (BH_ENABLE_GC_VERIFY != 0) {
        if (inuse == 'V') {
            gc_object_prefix_t* prefix = cast(gc_object_prefix_t*)(cur + 1);
            os_printf("#%s:%d\n", prefix.file_name, prefix.line_no);
        }
}

        cur = cast(hmu_t*)(cast(char*)cur + size);
        i++;
    }

    if (cur != end) {
        os_printf("[GC_ERROR]Heap is corrupted, heap dump failed.\n");
        heap.is_heap_corrupted = true;
    }
}
