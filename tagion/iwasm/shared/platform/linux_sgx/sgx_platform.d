module sgx_platform;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;
public import sgx_rsrv_mem_mngr;

static if (WASM_ENABLE_SGX_IPFS != 0) {
public import sgx_ipfs;
}

private os_print_function_t print_function = null;

int bh_platform_init() {
    int ret = BHT_OK;

static if (WASM_ENABLE_SGX_IPFS != 0) {
    ret = ipfs_init();
}

    return ret;
}

void bh_platform_destroy() {
static if (WASM_ENABLE_SGX_IPFS != 0) {
    ipfs_destroy();
}
}

void* os_malloc(uint size) {
    return malloc(size);
}

void* os_realloc(void* ptr, uint size) {
    return realloc(ptr, size);
}

void os_free(void* ptr) {
    free(ptr);
}

int os_dumps_proc_mem_info(char* out_, uint size) {
    return -1;
}

int putchar(int c) {
    return 0;
}

int puts(const(char)* s) {
    return 0;
}

void os_set_print_function(os_print_function_t pf) {
    print_function = pf;
}

enum FIXED_BUFFER_SIZE = 4096;

int os_printf(const(char)* message, ...) {
    int bytes_written = 0;

    if (print_function != null) {
        char[FIXED_BUFFER_SIZE] msg = [ '\0' ];
        va_list ap = void;
        va_start(ap, message);
        vsnprintf(msg.ptr, FIXED_BUFFER_SIZE, message, ap);
        va_end(ap);
        bytes_written += print_function(msg.ptr);
    }

    return bytes_written;
}

int os_vprintf(const(char)* format, va_list arg) {
    int bytes_written = 0;

    if (print_function != null) {
        char[FIXED_BUFFER_SIZE] msg = [ '\0' ];
        vsnprintf(msg.ptr, FIXED_BUFFER_SIZE, format, arg);
        bytes_written += print_function(msg.ptr);
    }

    return bytes_written;
}

char* strcpy(char* dest, const(char)* src) {
    const(ubyte)* s = src;
    ubyte* d = dest;

    while ((*d++ = *s++)) {
    }
    return dest;
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    int mprot = 0;
    ulong aligned_size = void, page_size = void;
    void* ret = null;
    sgx_status_t st = 0;

    page_size = getpagesize();
    aligned_size = (size + page_size - 1) & ~(page_size - 1);

    if (aligned_size >= UINT32_MAX)
        return null;

    ret = sgx_alloc_rsrv_mem(aligned_size);
    if (ret == null) {
        os_printf("os_mmap(size=%u, aligned size=%lu, prot=0x%x) failed.", size,
                  aligned_size, prot);
        return null;
    }

    if (prot & MMAP_PROT_READ)
        mprot |= SGX_PROT_READ;
    if (prot & MMAP_PROT_WRITE)
        mprot |= SGX_PROT_WRITE;
    if (prot & MMAP_PROT_EXEC)
        mprot |= SGX_PROT_EXEC;

    st = sgx_tprotect_rsrv_mem(ret, aligned_size, mprot);
    if (st != SGX_SUCCESS) {
        os_printf("os_mmap(size=%u, prot=0x%x) failed to set protect.", size,
                  prot);
        sgx_free_rsrv_mem(ret, aligned_size);
        return null;
    }

    return ret;
}

void os_munmap(void* addr, size_t size) {
    ulong aligned_size = void, page_size = void;

    page_size = getpagesize();
    aligned_size = (size + page_size - 1) & ~(page_size - 1);
    sgx_free_rsrv_mem(addr, aligned_size);
}

int os_mprotect(void* addr, size_t size, int prot) {
    int mprot = 0;
    sgx_status_t st = 0;
    ulong aligned_size = void, page_size = void;

    page_size = getpagesize();
    aligned_size = (size + page_size - 1) & ~(page_size - 1);

    if (prot & MMAP_PROT_READ)
        mprot |= SGX_PROT_READ;
    if (prot & MMAP_PROT_WRITE)
        mprot |= SGX_PROT_WRITE;
    if (prot & MMAP_PROT_EXEC)
        mprot |= SGX_PROT_EXEC;
    st = sgx_tprotect_rsrv_mem(addr, aligned_size, mprot);
    if (st != SGX_SUCCESS)
        os_printf("os_mprotect(addr=0x%" PRIx64 ~ ", size=%u, prot=0x%x) failed.",
                  cast(uintptr_t)addr, size, prot);

    return (st == SGX_SUCCESS ? 0 : -1);
}

void os_dcache_flush() {}
