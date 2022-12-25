module zephyr_platform;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

/* function pointers for executable memory management */
private exec_mem_alloc_func_t exec_mem_alloc_func = null;
private exec_mem_free_func_t exec_mem_free_func = null;

static if (WASM_ENABLE_AOT != 0) {
version (CONFIG_ARM_MPU) {
/**
 * This function will allow execute from sram region.
 * This is needed for AOT code because by default all soc will
 * disable the execute from SRAM.
 */
private void disable_mpu_rasr_xn() {
    uint index = void;
    /* Kept the max index as 8 (irrespective of soc) because the sram
       would most likely be set at index 2. */
    for (index = 0U; index < 8; index++) {
        MPU.RNR = index;
        if (MPU.RASR & MPU_RASR_XN_Msk) {
            MPU.RASR |= ~MPU_RASR_XN_Msk;
        }
    }
}
} /* end of CONFIG_ARM_MPU */
}

private int _stdout_hook_iwasm(int c) {
    printk("%c", cast(char)c);
    return 1;
}

int os_thread_sys_init();

void os_thread_sys_destroy();

int bh_platform_init() {
    extern void __stdout_hook_install(int function(int) hook);
    /* Enable printf() in Zephyr */
    __stdout_hook_install(&_stdout_hook_iwasm);

static if (WASM_ENABLE_AOT != 0) {
version (CONFIG_ARM_MPU) {
    /* Enable executable memory support */
    disable_mpu_rasr_xn();
}
}

    return os_thread_sys_init();
}

void bh_platform_destroy() {
    os_thread_sys_destroy();
}

void* os_malloc(uint size) {
    return null;
}

void* os_realloc(void* ptr, uint size) {
    return null;
}

void os_free(void* ptr) {}

int os_dumps_proc_mem_info(char* out_, uint size) {
    return -1;
}

version (none) {
struct out_context {
    int count;
};

alias out_func_t = int function(int c, void* ctx);

private int char_out(int c, void* ctx) {
    out_context* out_ctx = cast(out_context*)ctx;
    out_ctx.count++;
    return _stdout_hook_iwasm(c);
}

int os_vprintf(const(char)* fmt, va_list ap) {
version (none) {
    out_context ctx = { 0 };
    cbvprintf(&char_out, &ctx, fmt, ap);
    return ctx.count;
} else {
    vprintk(fmt, ap);
    return 0;
}
}
}

int os_printf(const(char)* format, ...) {
    int ret = 0;
    va_list ap = void;

    va_start(ap, format);
version (BH_VPRINTF) {} else {
    ret += vprintf(format, ap);
} version (BH_VPRINTF) {
    ret += BH_VPRINTF(format, ap);
}
    va_end(ap);

    return ret;
}

int os_vprintf(const(char)* format, va_list ap) {
version (BH_VPRINTF) {} else {
    return vprintf(format, ap);
} version (BH_VPRINTF) {
    return BH_VPRINTF(format, ap);
}
}

static if (KERNEL_VERSION_NUMBER <= 0x020400) { /* version 2.4.0 */
void abort() {
    int i = 0;
    os_printf("%d\n", 1 / i);
}
}

static if (KERNEL_VERSION_NUMBER <= 0x010E01) { /* version 1.14.1 */
size_t strspn(const(char)* s, const(char)* accept) {
    os_printf("## unimplemented function %s called", __FUNCTION__);
    return 0;
}

size_t strcspn(const(char)* s, const(char)* reject) {
    os_printf("## unimplemented function %s called", __FUNCTION__);
    return 0;
}
}

void* os_mmap(void* hint, size_t size, int prot, int flags) {
    if (cast(ulong)size >= UINT32_MAX)
        return null;
    if (exec_mem_alloc_func)
        return exec_mem_alloc_func(cast(uint)size);
    else
        return BH_MALLOC(size);
}

void os_munmap(void* addr, size_t size) {
    if (exec_mem_free_func)
        exec_mem_free_func(addr);
    else
        BH_FREE(addr);
}

int os_mprotect(void* addr, size_t size, int prot) {
    return 0;
}

void os_dcache_flush() {
static if (HasVersion!"CONFIG_CPU_CORTEX_M7" && HasVersion!"CONFIG_ARM_MPU") {
    uint key = void;
    key = irq_lock();
    SCB_CleanDCache();
    irq_unlock(key);
} else static if (HasVersion!"CONFIG_SOC_CVF_EM7D" && HasVersion!"CONFIG_ARC_MPU" \
    && HasVersion!"CONFIG_CACHE_FLUSHING") {
    __asm__ __volatile__("sync");
    z_arc_v2_aux_reg_write(_ARC_V2_DC_FLSH, BIT(0));
    __asm__ __volatile__("sync");
}
}

void set_exec_mem_alloc_func(exec_mem_alloc_func_t alloc_func, exec_mem_free_func_t free_func) {
    exec_mem_alloc_func = alloc_func;
    exec_mem_free_func = free_func;
}
