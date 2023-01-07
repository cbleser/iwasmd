module tagion.iwasm.config;
@nogc nothrow:
extern (C):
__gshared:

import tagion.iwasm.basic;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/* clang-format off */
static if (!ver.BUILD_TARGET_X86_64
        && !ver.BUILD_TARGET_AMD_64
        && !ver.BUILD_TARGET_AARCH64
        && !ver.BUILD_TARGET_X86_32
        && !ver.BUILD_TARGET_ARM
        && !ver.BUILD_TARGET_ARM_VFP
        && !ver.BUILD_TARGET_THUMB
        && !ver.BUILD_TARGET_THUMB_VFP
        && !ver.BUILD_TARGET_MIPS
        && !ver.BUILD_TARGET_XTENSA
        && !ver.BUILD_TARGET_RISCV64_LP64D
        && !ver.BUILD_TARGET_RISCV64_LP64
        && !ver.BUILD_TARGET_RISCV32_ILP32D
        && !ver.BUILD_TARGET_RISCV32_ILP32
        && !ver.BUILD_TARGET_ARC) {
    /* clang-format on */
    static if (ver.X86_64) {
        version = BUILD_TARGET_X86_64;
    }
    else static if (ver.amd64) {
        version = BUILD_TARGET_AMD_64;
    }
    else static if (ver.__aarch64__) {
        version = BUILD_TARGET_AARCH64;
    }
    else static if (ver.__i386__ || ver.__i386 || ver.i386) {
        version = BUILD_TARGET_X86_32;
    }
    else static if (ver.__thumb__) {
        version = BUILD_TARGET_THUMB;
        enum BUILD_TARGET = "THUMBV4T";
    }
    else static if (ver.__arm__) {
        version = BUILD_TARGET_ARM;
        enum BUILD_TARGET = "ARMV4T";
    }
    else static if (ver.__mips__ || ver.__mips || ver.mips) {
        version = BUILD_TARGET_MIPS;
    }
    else static if (ver.__XTENSA__) {
        version = BUILD_TARGET_XTENSA;
    }
    else static if (ver.__riscv && (__riscv_xlen == 64)) {
        version = BUILD_TARGET_RISCV64_LP64D;
    }
    else static if (ver.__riscv && (__riscv_xlen == 32)) {
        version = BUILD_TARGET_RISCV32_ILP32D;
    }
    else static if (ver.__arc__) {
        version = BUILD_TARGET_ARC;
    }
    else {
        static assert(0, "Build target isn't set");
    }
}

version (BH_DEBUG) {
}
else {
    enum BH_DEBUG = 0;
}

enum MEM_ALLOCATOR_EMS = 0;
enum MEM_ALLOCATOR_TLSF = 1;

/* Default memory allocator */
enum DEFAULT_MEM_ALLOCATOR = MEM_ALLOCATOR_EMS;

version (WASM_ENABLE_INTERP) {
}
else {
    enum WASM_ENABLE_INTERP = 0;
}

version (WASM_ENABLE_AOT) {
}
else {
    enum WASM_ENABLE_AOT = 0;
}

version (WASM_ENABLE_WORD_ALIGN_READ) {
}
else {
    enum WASM_ENABLE_WORD_ALIGN_READ = 0;
}

enum AOT_MAGIC_NUMBER = 0x746f6100;
enum AOT_CURRENT_VERSION = 3;

version (WASM_ENABLE_JIT) {
}
else {
    enum WASM_ENABLE_JIT = 0;
}

version (WASM_ENABLE_LAZY_JIT) {
}
else {
    enum WASM_ENABLE_LAZY_JIT = 0;
}

version (WASM_ORC_JIT_BACKEND_THREAD_NUM) {
}
else {
    /* The number of backend threads created by runtime */
    enum WASM_ORC_JIT_BACKEND_THREAD_NUM = 4;
}

static if (WASM_ORC_JIT_BACKEND_THREAD_NUM < 1) {
    static assert(0, "WASM_ORC_JIT_BACKEND_THREAD_NUM must be greater than 0");
}

version (WASM_ORC_JIT_COMPILE_THREAD_NUM) {
}
else {
    /* The number of compilation threads created by LLVM JIT */
    enum WASM_ORC_JIT_COMPILE_THREAD_NUM = 4;
}

static if (WASM_ORC_JIT_COMPILE_THREAD_NUM < 1) {
    static assert(0, "WASM_ORC_JIT_COMPILE_THREAD_NUM must be greater than 0");
}

static if ((WASM_ENABLE_AOT == 0) && (WASM_ENABLE_JIT != 0)) {
    /* LLVM JIT can only be enabled when AOT is enabled */
    enum WASM_ENABLE_JIT = 0;

    enum WASM_ENABLE_LAZY_JIT = 0;
}

version (WASM_ENABLE_FAST_JIT) {
}
else {
    enum WASM_ENABLE_FAST_JIT = 0;
}

version (WASM_ENABLE_FAST_JIT_DUMP) {
}
else {
    enum WASM_ENABLE_FAST_JIT_DUMP = 0;
}

version (FAST_JIT_DEFAULT_CODE_CACHE_SIZE) {
}
else {
    enum FAST_JIT_DEFAULT_CODE_CACHE_SIZE = 10 * 1024 * 1024;
}

version (WASM_ENABLE_WAMR_COMPILER) {
}
else {
    enum WASM_ENABLE_WAMR_COMPILER = 0;
}

version (WASM_ENABLE_LIBC_BUILTIN) {
}
else {
    enum WASM_ENABLE_LIBC_BUILTIN = 0;
}

version (WASM_ENABLE_LIBC_WASI) {
}
else {
    enum WASM_ENABLE_LIBC_WASI = 0;
}

version (WASM_ENABLE_UVWASI) {
}
else {
    enum WASM_ENABLE_UVWASI = 0;
}

version (WASM_ENABLE_WASI_NN) {
}
else {
    enum WASM_ENABLE_WASI_NN = 0;
}

/* Default disable libc emcc */
version (WASM_ENABLE_LIBC_EMCC) {
}
else {
    enum WASM_ENABLE_LIBC_EMCC = 0;
}

version (WASM_ENABLE_LIB_RATS) {
}
else {
    enum WASM_ENABLE_LIB_RATS = 0;
}

version (WASM_ENABLE_LIB_PTHREAD) {
}
else {
    enum WASM_ENABLE_LIB_PTHREAD = 0;
}

version (WASM_ENABLE_LIB_PTHREAD_SEMAPHORE) {
}
else {
    enum WASM_ENABLE_LIB_PTHREAD_SEMAPHORE = 0;
}

version (WASM_ENABLE_BASE_LIB) {
}
else {
    enum WASM_ENABLE_BASE_LIB = 0;
}

version (WASM_ENABLE_APP_FRAMEWORK) {
}
else {
    enum WASM_ENABLE_APP_FRAMEWORK = 0;
}

/* Bulk memory operation */
version (WASM_ENABLE_BULK_MEMORY) {
}
else {
    enum WASM_ENABLE_BULK_MEMORY = 0;
}

/* Shared memory */
version (WASM_ENABLE_SHARED_MEMORY) {
}
else {
    enum WASM_ENABLE_SHARED_MEMORY = 0;
}

/* Thread manager */
version (WASM_ENABLE_THREAD_MGR) {
}
else {
    enum WASM_ENABLE_THREAD_MGR = 0;
}

/* Source debugging */
version (WASM_ENABLE_DEBUG_INTERP) {
}
else {
    enum WASM_ENABLE_DEBUG_INTERP = 0;
}

static if (WASM_ENABLE_DEBUG_INTERP != 0) {
    version (DEBUG_EXECUTION_MEMORY_SIZE) {
    }
    else {
        /* 0x85000 is the size required by lldb, if this is changed to a smaller value,
 * then the debugger will not be able to evaluate user expressions, other
 * functionality such as breakpoint and stepping are not influenced by this */
        enum DEBUG_EXECUTION_MEMORY_SIZE = 0x85000;
    }
} /* end of WASM_ENABLE_DEBUG_INTERP != 0 */

version (WASM_ENABLE_DEBUG_AOT) {
}
else {
    enum WASM_ENABLE_DEBUG_AOT = 0;
}

/* Custom sections */
version (WASM_ENABLE_LOAD_CUSTOM_SECTION) {
}
else {
    enum WASM_ENABLE_LOAD_CUSTOM_SECTION = 0;
}

/* WASM log system */
version (WASM_ENABLE_LOG) {
}
else {
    enum WASM_ENABLE_LOG = 1;
}

version (WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS) {
}
else {
    static if (ver.BUILD_TARGET_X86_32 || ver.BUILD_TARGET_X86_64
            || ver.BUILD_TARGET_AARCH64) {
        enum WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS = 1;
    }
    else {
        enum WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS = 0;
    }
}

/* WASM Interpreter labels-as-values feature */
version (WASM_ENABLE_LABELS_AS_VALUES) {
}
else {
    version (__GNUC__) {
        enum WASM_ENABLE_LABELS_AS_VALUES = 1;
    }
    else {
        enum WASM_ENABLE_LABELS_AS_VALUES = 0;
    }
}

/* Enable fast interpreter or not */
version (WASM_ENABLE_FAST_INTERP) {
}
else {
    enum WASM_ENABLE_FAST_INTERP = 0;
}

static if (WASM_ENABLE_FAST_INTERP != 0) {
    enum WASM_DEBUG_PREPROCESSOR = 0;
}

/* Enable opcode counter or not */
version (WASM_ENABLE_OPCODE_COUNTER) {
}
else {
    enum WASM_ENABLE_OPCODE_COUNTER = 0;
}

/* Support a module with dependency, other modules */
version (WASM_ENABLE_MULTI_MODULE) {
}
else {
    enum WASM_ENABLE_MULTI_MODULE = 0;
}

/* Enable wasm mini loader or not */
version (WASM_ENABLE_MINI_LOADER) {
}
else {
    enum WASM_ENABLE_MINI_LOADER = 0;
}

/* Disable boundary check with hardware trap or not,
 * enable it by default if it is supported */
version (WASM_DISABLE_HW_BOUND_CHECK) {
}
else {
    enum WASM_DISABLE_HW_BOUND_CHECK = 0;
}

/* Disable native stack access boundary check with hardware
 * trap or not, enable it by default if it is supported */
version (WASM_DISABLE_STACK_HW_BOUND_CHECK) {
}
else {
    enum WASM_DISABLE_STACK_HW_BOUND_CHECK = 0;
}

/* Disable SIMD unless it is manualy enabled somewhere */
version (WASM_ENABLE_SIMD) {
}
else {
    enum WASM_ENABLE_SIMD = 0;
}

/* Memory profiling */
version (WASM_ENABLE_MEMORY_PROFILING) {
}
else {
    enum WASM_ENABLE_MEMORY_PROFILING = 0;
}

/* Memory tracing */
version (WASM_ENABLE_MEMORY_TRACING) {
}
else {
    enum WASM_ENABLE_MEMORY_TRACING = 0;
}

/* Performance profiling */
version (WASM_ENABLE_PERF_PROFILING) {
}
else {
    enum WASM_ENABLE_PERF_PROFILING = 0;
}

/* Dump call stack */
version (WASM_ENABLE_DUMP_CALL_STACK) {
}
else {
    enum WASM_ENABLE_DUMP_CALL_STACK = 0;
}

/* Heap verification */
version (BH_ENABLE_GC_VERIFY) {
}
else {
    enum BH_ENABLE_GC_VERIFY = 0;
}

/* Enable global heap pool if heap verification is enabled */
static if (BH_ENABLE_GC_VERIFY != 0) {
    enum WASM_ENABLE_GLOBAL_HEAP_POOL = 1;
}

/* Global heap pool */
version (WASM_ENABLE_GLOBAL_HEAP_POOL) {
}
else {
    enum WASM_ENABLE_GLOBAL_HEAP_POOL = 0;
}

version (WASM_ENABLE_SPEC_TEST) {
}
else {
    enum WASM_ENABLE_SPEC_TEST = 0;
}

/* Global heap pool size in bytes */
version (WASM_GLOBAL_HEAP_SIZE) {
}
else {
    enum WASM_GLOBAL_HEAP_SIZE = (10 * 1024 * 1024);
}

/* Max app number of all modules */
enum MAX_APP_INSTALLATIONS = 3;

/* Default timer number in one app */
enum DEFAULT_TIMERS_PER_APP = 20;

/* Max timer number in one app */
enum MAX_TIMERS_PER_APP = 30;

/* Max connection number in one app */
enum MAX_CONNECTION_PER_APP = 20;

/* Max resource registration number in one app */
enum RESOURCE_REGISTRATION_NUM_MAX = 16;

/* Max length of resource/event url */
enum RESOUCE_EVENT_URL_LEN_MAX = 256;

/* Default length of queue */
enum DEFAULT_QUEUE_LENGTH = 50;

/* Default watchdog interval in ms */
enum DEFAULT_WATCHDOG_INTERVAL = (3 * 60 * 1000);

/* The max percentage of global heap that app memory space can grow */
enum APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT = 1 / 3;

/* Default min/max heap size of each app */
version (APP_HEAP_SIZE_DEFAULT) {
}
else {
    enum APP_HEAP_SIZE_DEFAULT = (8 * 1024);
}
enum APP_HEAP_SIZE_MIN = (256);
enum APP_HEAP_SIZE_MAX = (512 * 1024 * 1024);

/* Default wasm stack size of each app */
static if (ver.BUILD_TARGET_X86_64 || ver.BUILD_TARGET_AMD_64) {
    enum DEFAULT_WASM_STACK_SIZE = (16 * 1024);
}
else {
    enum DEFAULT_WASM_STACK_SIZE = (12 * 1024);
}
/* Min auxilliary stack size of each wasm thread */
enum WASM_THREAD_AUX_STACK_SIZE_MIN = (256);

/* Default/min native stack size of each app thread */
static if (!(ver.APP_THREAD_STACK_SIZE_DEFAULT
        && ver.APP_THREAD_STACK_SIZE_MIN)) {
    static if (ver.BH_PLATFORM_ZEPHYR || ver.BH_PLATFORM_ALIOS_THINGS
            || ver.BH_PLATFORM_ESP_IDF || ver.BH_PLATFORM_OPENRTOS) {
        enum APP_THREAD_STACK_SIZE_DEFAULT = (6 * 1024);
        enum APP_THREAD_STACK_SIZE_MIN = (4 * 1024);
    }
    else static if (ver.PTHREAD_STACK_DEFAULT && ver.PTHREAD_STACK_MIN) {
        enum APP_THREAD_STACK_SIZE_DEFAULT = PTHREAD_STACK_DEFAULT;
        enum APP_THREAD_STACK_SIZE_MIN = PTHREAD_STACK_MIN;
    }
    else static if (WASM_ENABLE_UVWASI != 0) {
        /* UVWASI requires larger native stack */
        enum APP_THREAD_STACK_SIZE_DEFAULT = (64 * 1024);
        enum APP_THREAD_STACK_SIZE_MIN = (48 * 1024);
    }
    else {
        enum APP_THREAD_STACK_SIZE_DEFAULT = (32 * 1024);
        enum APP_THREAD_STACK_SIZE_MIN = (24 * 1024);
    }
} /* end of !(defined(APP_THREAD_STACK_SIZE_DEFAULT) 
                   && defined(APP_THREAD_STACK_SIZE_MIN)) */

/* Max native stack size of each app thread */
static if (!ver.APP_THREAD_STACK_SIZE_MAX) {
    enum APP_THREAD_STACK_SIZE_MAX = (8 * 1024 * 1024);
}

/* Reserved bytes to the native thread stack boundary, throw native
   stack overflow exception if the guard boudary is reached */
version (WASM_STACK_GUARD_SIZE) {
}
else {
    static if (WASM_ENABLE_UVWASI != 0) {
        /* UVWASI requires larger native stack */
        enum WASM_STACK_GUARD_SIZE = (4096 * 6);
    }
    else {
        enum WASM_STACK_GUARD_SIZE = (1024);
    }
}

/* Guard page count for stack overflow check with hardware trap */
version (STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT) {
}
else {
    enum STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT = 3;
}

/* Default wasm block address cache size and conflict list size */
version (BLOCK_ADDR_CACHE_SIZE) {
}
else {
    enum BLOCK_ADDR_CACHE_SIZE = 64;
}
enum BLOCK_ADDR_CONFLICT_SIZE = 2;

/* Default max thread num per cluster. Can be overwrite by
    wasm_runtime_set_max_thread_num */
enum CLUSTER_MAX_THREAD_NUM = 4;

version (WASM_ENABLE_TAIL_CALL) {
}
else {
    enum WASM_ENABLE_TAIL_CALL = 0;
}

version (WASM_ENABLE_CUSTOM_NAME_SECTION) {
}
else {
    enum WASM_ENABLE_CUSTOM_NAME_SECTION = 0;
}

version (WASM_ENABLE_REF_TYPES) {
}
else {
    enum WASM_ENABLE_REF_TYPES = 0;
}

version (WASM_ENABLE_SGX_IPFS) {
}
else {
    enum WASM_ENABLE_SGX_IPFS = 0;
}

version (WASM_MEM_ALLOC_WITH_USER_DATA) {
}
else {
    enum WASM_MEM_ALLOC_WITH_USER_DATA = 0;
}

version (WASM_ENABLE_WASM_CACHE) {
}
else {
    enum WASM_ENABLE_WASM_CACHE = 0;
}

/* end of _CONFIG_H_ */
