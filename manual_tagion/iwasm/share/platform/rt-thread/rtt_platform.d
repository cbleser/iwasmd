module rtt_platform;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2021, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

struct os_malloc_list {
    void* real_;
    void* used;
    rt_list_t node;
}alias os_malloc_list_t = os_malloc_list;

int bh_platform_init() {
    return 0;
}

void bh_platform_destroy() {}

void* os_malloc(uint size) {
    void* buf_origin = void;
    void* buf_fixed = void;
    rt_ubase_t* addr_field = void;

    buf_origin = rt_malloc(size + 8 + rt_ubase_t.sizeof);
    buf_fixed = buf_origin + (void*).sizeof;
    if (cast(rt_ubase_t)buf_fixed & 0x7) {
        buf_fixed = cast(void*)((rt_ubase_t)(buf_fixed + 8) & (~7));
    }

    addr_field = buf_fixed - rt_ubase_t.sizeof;
    *addr_field = cast(rt_ubase_t)buf_origin;

    return buf_fixed;
}

void* os_realloc(void* ptr, uint size) {

    void* mem_origin = void;
    void* mem_new = void;
    void* mem_new_fixed = void;
    rt_ubase_t* addr_field = void;

    if (!ptr) {
        return RT_NULL;
    }

    addr_field = ptr - rt_ubase_t.sizeof;
    mem_origin = cast(void*)(*addr_field);
    mem_new = rt_realloc(mem_origin, size + 8 + rt_ubase_t.sizeof);

    if (mem_origin != mem_new) {
        mem_new_fixed = mem_new + rt_ubase_t.sizeof;
        if (cast(rt_ubase_t)mem_new_fixed & 0x7) {
            mem_new_fixed = cast(void*)((rt_ubase_t)(mem_new_fixed + 8) & (~7));
        }

        addr_field = mem_new_fixed - rt_ubase_t.sizeof;
        *addr_field = cast(rt_ubase_t)mem_new;

        return mem_new_fixed;
    }

    return ptr;
}

void os_free(void* ptr) {
    void* mem_origin = void;
    rt_ubase_t* addr_field = void;

    if (ptr) {
        addr_field = ptr - rt_ubase_t.sizeof;
        mem_origin = cast(void*)(*addr_field);

        rt_free(mem_origin);
    }
}

int os_dumps_proc_mem_info(char* out_, uint size) {
    return -1;
}

private char[RT_CONSOLEBUF_SIZE * 2] wamr_vprint_buf = 0;

int os_printf(const(char)* format, ...) {
    va_list ap = void;
    va_start(ap, format);
    rt_size_t len = vsnprintf(wamr_vprint_buf.ptr, sizeof(wamr_vprint_buf).ptr - 1, format, ap);
    wamr_vprint_buf[len] = 0x00;
    rt_kputs(wamr_vprint_buf.ptr);
    va_end(ap);
    return 0;
}

int os_vprintf(const(char)* format, va_list ap) {
    rt_size_t len = vsnprintf(wamr_vprint_buf.ptr, sizeof(wamr_vprint_buf).ptr - 1, format, ap);
    wamr_vprint_buf[len] = 0;
    rt_kputs(wamr_vprint_buf.ptr);
    return 0;
}

ulong os_time_get_boot_microsecond() {
    ulong ret = rt_tick_get() * 1000;
    ret /= RT_TICK_PER_SECOND;
    return ret;
}

korp_tid os_self_thread() {
    return rt_thread_self();
}

ubyte* os_thread_get_stack_boundary() {
    rt_thread_t tid = rt_thread_self();
    return tid.stack_addr;
}

int os_mutex_init(korp_mutex* mutex) {
    return rt_mutex_init(mutex, "wamr0", RT_IPC_FLAG_FIFO);
}

int os_mutex_destroy(korp_mutex* mutex) {
    return rt_mutex_detach(mutex);
}

int os_mutex_lock(korp_mutex* mutex) {
    return rt_mutex_take(mutex, RT_WAITING_FOREVER);
}

int os_mutex_unlock(korp_mutex* mutex) {
    return rt_mutex_release(mutex);
}

/*
 * functions below was not implement
 */

int os_cond_init(korp_cond* cond) {
    return 0;
}

int os_cond_destroy(korp_cond* cond) {
    return 0;
}

int os_cond_wait(korp_cond* cond, korp_mutex* mutex) {
    return 0;
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    return rt_malloc(size);
}

void os_munmap(void* addr, size_t size) {
    rt_free(addr);
}

int os_mprotect(void* addr, size_t size, int prot) {
    return 0;
}

void os_dcache_flush() {}
