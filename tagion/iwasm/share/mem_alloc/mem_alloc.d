module tagion.iwasm.share.mem_alloc.mem_alloc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


alias mem_allocator_t = void*;

/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

static if (DEFAULT_MEM_ALLOCATOR == MEM_ALLOCATOR_EMS) {

public import ems.ems_gc;

mem_allocator_t mem_allocator_create(void* mem, uint size) {
    return gc_init_with_pool(cast(char*)mem, size);
}

mem_allocator_t mem_allocator_create_with_struct_and_pool(void* struct_buf, uint struct_buf_size, void* pool_buf, uint pool_buf_size) {
    return gc_init_with_struct_and_pool(cast(char*)struct_buf, struct_buf_size,
                                        pool_buf, pool_buf_size);
}

int mem_allocator_destroy(mem_allocator_t allocator) {
    return gc_destroy_with_pool(cast(gc_handle_t)allocator);
}

uint mem_allocator_get_heap_struct_size() {
    return gc_get_heap_struct_size();
}

void* mem_allocator_malloc(mem_allocator_t allocator, uint size) {
    return gc_alloc_vo(cast(gc_handle_t)allocator, size);
}

void* mem_allocator_realloc(mem_allocator_t allocator, void* ptr, uint size) {
    return gc_realloc_vo(cast(gc_handle_t)allocator, ptr, size);
}

void mem_allocator_free(mem_allocator_t allocator, void* ptr) {
    if (ptr)
        gc_free_vo(cast(gc_handle_t)allocator, ptr);
}

int mem_allocator_migrate(mem_allocator_t allocator, char* pool_buf_new, uint pool_buf_size) {
    return gc_migrate(cast(gc_handle_t)allocator, pool_buf_new, pool_buf_size);
}

bool mem_allocator_is_heap_corrupted(mem_allocator_t allocator) {
    return gc_is_heap_corrupted(cast(gc_handle_t)allocator);
}

bool mem_allocator_get_alloc_info(mem_allocator_t allocator, void* mem_alloc_info) {
    gc_heap_stats(cast(gc_handle_t)allocator, mem_alloc_info, 3);
    return true;
}

} 
else { /* else of DEFAULT_MEM_ALLOCATOR */

public import tlsf.tlsf;

struct mem_allocator_tlsf {
    tlsf_t tlsf;
    korp_mutex lock;
}

mem_allocator_t mem_allocator_create(void* mem, uint size) {
    mem_allocator_tlsf* allocator_tlsf = void;
    tlsf_t tlsf = void;
    char* mem_aligned = cast(char*)((cast(uintptr_t)mem + 3) & ~3);

    if (size < 1024) {
        printf("Create mem allocator failed: pool size must be "
               ~ "at least 1024 bytes.\n");
        return null;
    }

    size -= mem_aligned - cast(char*)mem;
    mem = cast(void*)mem_aligned;

    tlsf = tlsf_create_with_pool(mem, size);
    if (!tlsf) {
        printf("Create mem allocator failed: tlsf_create_with_pool failed.\n");
        return null;
    }

    allocator_tlsf = tlsf_malloc(tlsf, mem_allocator_tlsf.sizeof);
    if (!allocator_tlsf) {
        printf("Create mem allocator failed: tlsf_malloc failed.\n");
        tlsf_destroy(tlsf);
        return null;
    }

    allocator_tlsf.tlsf = tlsf;

    if (os_mutex_init(&allocator_tlsf.lock)) {
        printf("Create mem allocator failed: tlsf_malloc failed.\n");
        tlsf_free(tlsf, allocator_tlsf);
        tlsf_destroy(tlsf);
        return null;
    }

    return allocator_tlsf;
}

void mem_allocator_destroy(mem_allocator_t allocator) {
    mem_allocator_tlsf* allocator_tlsf = cast(mem_allocator_tlsf*)allocator;
    tlsf_t tlsf = allocator_tlsf.tlsf;

    os_mutex_destroy(&allocator_tlsf.lock);
    tlsf_free(tlsf, allocator_tlsf);
    tlsf_destroy(tlsf);
}

void* mem_allocator_malloc(mem_allocator_t allocator, uint size) {
    void* ret = void;
    mem_allocator_tlsf* allocator_tlsf = cast(mem_allocator_tlsf*)allocator;

    if (size == 0)
        /* tlsf doesn't allow to allocate 0 byte */
        size = 1;

    os_mutex_lock(&allocator_tlsf.lock);
    ret = tlsf_malloc(allocator_tlsf.tlsf, size);
    os_mutex_unlock(&allocator_tlsf.lock);
    return ret;
}

void* mem_allocator_realloc(mem_allocator_t allocator, void* ptr, uint size) {
    void* ret = void;
    mem_allocator_tlsf* allocator_tlsf = cast(mem_allocator_tlsf*)allocator;

    if (size == 0)
        /* tlsf doesn't allow to allocate 0 byte */
        size = 1;

    os_mutex_lock(&allocator_tlsf.lock);
    ret = tlsf_realloc(allocator_tlsf.tlsf, ptr, size);
    os_mutex_unlock(&allocator_tlsf.lock);
    return ret;
}

void mem_allocator_free(mem_allocator_t allocator, void* ptr) {
    if (ptr) {
        mem_allocator_tlsf* allocator_tlsf = cast(mem_allocator_tlsf*)allocator;
        os_mutex_lock(&allocator_tlsf.lock);
        tlsf_free(allocator_tlsf.tlsf, ptr);
        os_mutex_unlock(&allocator_tlsf.lock);
    }
}

int mem_allocator_migrate(mem_allocator_t allocator, mem_allocator_t allocator_old) {
    return tlsf_migrate(cast(mem_allocator_tlsf*)allocator,
                        cast(mem_allocator_tlsf*)allocator_old);
}

} /* end of DEFAULT_MEM_ALLOCATOR */
