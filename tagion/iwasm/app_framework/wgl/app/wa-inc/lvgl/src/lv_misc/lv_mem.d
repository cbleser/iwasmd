module lv_mem;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/**
 * @file lv_mem.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
version (LV_CONF_INCLUDE_SIMPLE) {
public import lv_conf;
} else {
public import .........lv_conf;
}

public import core.stdc.stdint;
public import core.stdc.stddef;
public import lv_log;

/*********************
 *      DEFINES
 *********************/
// Check windows
version (__WIN64) {
version = LV_MEM_ENV64;
}

// Check GCC
version (__GNUC__) {
static if (HasVersion!"__x86_64__" || HasVersion!"__ppc64__") {
version = LV_MEM_ENV64;
}
}

/**********************
 *      TYPEDEFS
 **********************/

/**
 * Heap information structure.
 */
struct _Lv_mem_monitor_t {
    uint total_size; /**< Total heap size */
    uint free_cnt;
    uint free_size; /**< Size of available memory */
    uint free_biggest_size;
    uint used_cnt;
    ubyte used_pct; /**< Percentage used */
    ubyte frag_pct; /**< Amount of fragmentation */
}alias lv_mem_monitor_t = _Lv_mem_monitor_t;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Initiaize the dyn_mem module (work memory and other variables)
 */
void lv_mem_init();

/**
 * Allocate a memory dynamically
 * @param size size of the memory to allocate in bytes
 * @return pointer to the allocated memory
 */
void* lv_mem_alloc(uint size);

/**
 * Free an allocated data
 * @param data pointer to an allocated memory
 */
void lv_mem_free(const(void)* data);

/**
 * Reallocate a memory with a new size. The old content will be kept.
 * @param data pointer to an allocated memory.
 * Its content will be copied to the new memory block and freed
 * @param new_size the desired new size in byte
 * @return pointer to the new memory
 */
void* lv_mem_realloc(void* data_p, uint new_size);

/**
 * Join the adjacent free memory blocks
 */
void lv_mem_defrag();

/**
 * Give information about the work memory of dynamic allocation
 * @param mon_p pointer to a dm_mon_p variable,
 *              the result of the analysis will be stored here
 */
void lv_mem_monitor(lv_mem_monitor_t* mon_p);

/**
 * Give the size of an allocated memory
 * @param data pointer to an allocated memory
 * @return the size of data memory in bytes
 */
uint lv_mem_get_size(const(void)* data);

/**********************
 *      MACROS
 **********************/

/**
 * Halt on NULL pointer
 * p pointer to a memory
 */
static if (LV_USE_LOG == 0) {
enum string lv_mem_assert(string p) = `                                                                                               \
    {                                                                                                                  \
        if(p == NULL)                                                                                                  \
            while(1)                                                                                                   \
                ;                                                                                                      \
    }`;
} else {
enum string lv_mem_assert(string p) = `                                                                                               \
    {                                                                                                                  \
        if(p == NULL) {                                                                                                \
            LV_LOG_ERROR("Out of memory!");                                                                            \
            while(1)                                                                                                   \
                ;                                                                                                      \
        }                                                                                                              \
    }`;
}
version (none) {}
} /* extern "C" */
}

 /*LV_MEM_H*/
