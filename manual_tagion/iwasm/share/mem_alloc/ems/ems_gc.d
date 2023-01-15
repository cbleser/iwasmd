module ems_gc;
@nogc nothrow:
extern(C): __gshared:
alias uint8 = ubyte;
alias int8 = char;
alias uint16 = ushort;
alias int16 = short;
alias uint32 = uint;
alias int32 = int;
uint htonl(uint value);
uint ntohl(uint value);
ushort htons(ushort value);
ushort ntohs(ushort value);
alias gc_handle_t = void*;
alias gc_object_t = void*;
alias gc_int64 = long;
alias gc_uint32 = uint;
alias gc_int32 = int;
alias gc_uint16 = ushort;
alias gc_int16 = short;
alias gc_uint8 = ubyte;
alias gc_int8 = byte;
alias gc_size_t = uint;
enum _GC_STAT_INDEX {
    GC_STAT_TOTAL = 0,
    GC_STAT_FREE,
    GC_STAT_HIGHMARK,
}

alias GC_STAT_INDEX = _GC_STAT_INDEX;
gc_handle_t gc_init_with_pool(char* buf, gc_size_t buf_size);
gc_handle_t gc_init_with_struct_and_pool(char* struct_buf, gc_size_t struct_buf_size, char* pool_buf, gc_size_t pool_buf_size);
int gc_destroy_with_pool(gc_handle_t handle);
uint gc_get_heap_struct_size();
int gc_migrate(gc_handle_t handle, char* pool_buf_new, gc_size_t pool_buf_size);
bool gc_is_heap_corrupted(gc_handle_t handle);
void* gc_heap_stats(void* heap, uint* stats, int size);
gc_object_t gc_alloc_vo(void* heap, gc_size_t size);
gc_object_t gc_realloc_vo(void* heap, void* ptr, gc_size_t size);
int gc_free_vo(void* heap, gc_object_t obj);
