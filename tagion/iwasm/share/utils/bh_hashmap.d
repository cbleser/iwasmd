module tagion.iwasm.share.utils.bh_hashmap;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


import tagion.iwasm.app_framework.base.app.bh_platform;


/* Maximum initial size of hash map */
enum HASH_MAP_MAX_SIZE = 65536;



/* Hash function: to get the hash value of key. */
alias HashFunc = uint function(const(void)* key);

/* Key equal function: to check whether two keys are equal. */
alias KeyEqualFunc = bool function(void* key1, void* key2);

/* Key destroy function: to destroy the key, auto called
   for each key when the hash map is destroyed. */
alias KeyDestroyFunc = void function(void* key);

/* Value destroy function: to destroy the value, auto called
   for each value when the hash map is destroyed. */
alias ValueDestroyFunc = void function(void* value);

/* traverse callback function:
   auto called when traverse every hash element */
alias TraverseCallbackFunc = void function(void* key, void* value, void* user_data);

/**
 * Create a hash map.
 *
 * @param size: the initial size of the hash map
 * @param use_lock whether to lock the hash map when operating on it
 * @param hash_func hash function of the key, must be specified
 * @param key_equal_func key equal function, check whether two keys
 *                       are equal, must be specified
 * @param key_destroy_func key destroy function, called for each key if not NULL
 *                         when the hash map is destroyed
 * @param value_destroy_func value destroy function, called for each value if
 *                           not NULL when the hash map is destroyed
 *
 * @return the hash map created, NULL if failed
 */
HashMap* bh_hash_map_create(uint size, bool use_lock, HashFunc hash_func, KeyEqualFunc key_equal_func, KeyDestroyFunc key_destroy_func, ValueDestroyFunc value_destroy_func);

/**
 * Insert an element to the hash map
 *
 * @param map the hash map to insert element
 * @key the key of the element
 * @value the value of the element
 *
 * @return true if success, false otherwise
 * Note: fail if key is NULL or duplicated key exists in the hash map,
 */
bool bh_hash_map_insert(HashMap* map, void* key, void* value);

/**
 * Find an element in the hash map
 *
 * @param map the hash map to find element
 * @key the key of the element
 *
 * @return the value of the found element if success, NULL otherwise
 */
void* bh_hash_map_find(HashMap* map, void* key);

/**
 * Update an element in the hash map with new value
 *
 * @param map the hash map to update element
 * @key the key of the element
 * @value the new value of the element
 * @p_old_value if not NULL, copies the old value to it
 *
 * @return true if success, false otherwise
 * Note: the old value won't be destroyed by value destroy function,
 *       it will be copied to p_old_value for user to process.
 */
bool bh_hash_map_update(HashMap* map, void* key, void* value, void** p_old_value);

/**
 * Remove an element from the hash map
 *
 * @param map the hash map to remove element
 * @key the key of the element
 * @p_old_key if not NULL, copies the old key to it
 * @p_old_value if not NULL, copies the old value to it
 *
 * @return true if success, false otherwise
 * Note: the old key and old value won't be destroyed by key destroy
 *       function and value destroy function, they will be copied to
 *       p_old_key and p_old_value for user to process.
 */
bool bh_hash_map_remove(HashMap* map, void* key, void** p_old_key, void** p_old_value);

/**
 * Destroy the hashmap
 *
 * @param map the hash map to destroy
 *
 * @return true if success, false otherwise
 * Note: the key destroy function and value destroy function will be
 *       called to destroy each element's key and value if they are
 *       not NULL.
 */
bool bh_hash_map_destroy(HashMap* map);

/**
 * Get the structure size of HashMap
 *
 * @param map the hash map to calculate
 *
 * @return the memory space occupied by HashMap structure
 */
uint bh_hash_map_get_struct_size(HashMap* hashmap);

/**
 * Get the structure size of HashMap Element
 *
 * @return the memory space occupied by HashMapElem structure
 */
uint bh_hash_map_get_elem_struct_size();

/**
 * Traverse the hash map and call the callback function
 *
 * @param map the hash map to traverse
 * @param callback the function to be called for every element
 * @param user_data the argument to be passed to the callback function
 *
 * @return true if success, false otherwise
 * Note: if the hash map has lock, the map will be locked during traverse,
 *       keep the callback function as simple as possible.
 */
bool bh_hash_map_traverse(HashMap* map, TraverseCallbackFunc callback, void* user_data);


//! #endif /* endof WASM_HASHMAP_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


struct HashMapElem {
    void* key;
    void* value;
    HashMapElem* next;
}

struct HashMap {
    /* size of element array */
    uint size;
    /* lock for elements */
    korp_mutex* lock;
    /* hash function of key */
    HashFunc hash_func;
    /* key equal function */
    KeyEqualFunc key_equal_func;
    KeyDestroyFunc key_destroy_func;
    ValueDestroyFunc value_destroy_func;
    HashMapElem*[1] elements;
};

HashMap* bh_hash_map_create(uint size, bool use_lock, HashFunc hash_func, KeyEqualFunc key_equal_func, KeyDestroyFunc key_destroy_func, ValueDestroyFunc value_destroy_func) {
    HashMap* map = void;
    ulong total_size = void;

    if (size > HASH_MAP_MAX_SIZE) {
        LOG_ERROR("HashMap create failed: size is too large.\n");
        return null;
    }

    if (!hash_func || !key_equal_func) {
        LOG_ERROR("HashMap create failed: hash function or key equal function "
                  ~ " is NULL.\n");
        return null;
    }

    total_size = HashMap.elements.offsetof
                 + (HashMapElem*).sizeof * cast(ulong)size
                 + (use_lock ? korp_mutex.sizeof : 0);

    if (total_size >= UINT32_MAX || ((map = BH_MALLOC(cast(uint)total_size)) == 0)) {
        LOG_ERROR("HashMap create failed: alloc memory failed.\n");
        return null;
    }

    memset(map, 0, cast(uint)total_size);

    if (use_lock) {
        map.lock = cast(korp_mutex*)(cast(ubyte*)map + HashMap.elements.offsetof
                                   + (HashMapElem*).sizeof * size);
        if (os_mutex_init(map.lock)) {
            LOG_ERROR("HashMap create failed: init map lock failed.\n");
            BH_FREE(map);
            return null;
        }
    }

    map.size = size;
    map.hash_func = hash_func;
    map.key_equal_func = key_equal_func;
    map.key_destroy_func = key_destroy_func;
    map.value_destroy_func = value_destroy_func;
    return map;
}

bool bh_hash_map_insert(HashMap* map, void* key, void* value) {
    uint index = void;
    HashMapElem* elem = void;

    if (!map || !key) {
        LOG_ERROR("HashMap insert elem failed: map or key is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    elem = map.elements[index];
    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            LOG_ERROR("HashMap insert elem failed: duplicated key found.\n");
            goto fail;
        }
        elem = elem.next;
    }

    if (((elem = BH_MALLOC(HashMapElem.sizeof)) == 0)) {
        LOG_ERROR("HashMap insert elem failed: alloc memory failed.\n");
        goto fail;
    }

    elem.key = key;
    elem.value = value;
    elem.next = map.elements[index];
    map.elements[index] = elem;

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return true;

fail:
    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return false;
}

void* bh_hash_map_find(HashMap* map, void* key) {
    uint index = void;
    HashMapElem* elem = void;
    void* value = void;

    if (!map || !key) {
        LOG_ERROR("HashMap find elem failed: map or key is NULL.\n");
        return null;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    elem = map.elements[index];

    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            value = elem.value;
            if (map.lock) {
                os_mutex_unlock(map.lock);
            }
            return value;
        }
        elem = elem.next;
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return null;
}

bool bh_hash_map_update(HashMap* map, void* key, void* value, void** p_old_value) {
    uint index = void;
    HashMapElem* elem = void;

    if (!map || !key) {
        LOG_ERROR("HashMap update elem failed: map or key is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    elem = map.elements[index];

    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            if (p_old_value)
                *p_old_value = elem.value;
            elem.value = value;
            if (map.lock) {
                os_mutex_unlock(map.lock);
            }
            return true;
        }
        elem = elem.next;
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return false;
}

bool bh_hash_map_remove(HashMap* map, void* key, void** p_old_key, void** p_old_value) {
    uint index = void;
    HashMapElem* elem = void, prev = void;

    if (!map || !key) {
        LOG_ERROR("HashMap remove elem failed: map or key is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    index = map.hash_func(key) % map.size;
    prev = elem = map.elements[index];

    while (elem) {
        if (map.key_equal_func(elem.key, key)) {
            if (p_old_key)
                *p_old_key = elem.key;
            if (p_old_value)
                *p_old_value = elem.value;

            if (elem == map.elements[index])
                map.elements[index] = elem.next;
            else
                prev.next = elem.next;

            BH_FREE(elem);

            if (map.lock) {
                os_mutex_unlock(map.lock);
            }
            return true;
        }

        prev = elem;
        elem = elem.next;
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }
    return false;
}

bool bh_hash_map_destroy(HashMap* map) {
    uint index = void;
    HashMapElem* elem = void, next = void;

    if (!map) {
        LOG_ERROR("HashMap destroy failed: map is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    for (index = 0; index < map.size; index++) {
        elem = map.elements[index];
        while (elem) {
            next = elem.next;

            if (map.key_destroy_func) {
                map.key_destroy_func(elem.key);
            }
            if (map.value_destroy_func) {
                map.value_destroy_func(elem.value);
            }
            BH_FREE(elem);

            elem = next;
        }
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
        os_mutex_destroy(map.lock);
    }
    BH_FREE(map);
    return true;
}

uint bh_hash_map_get_struct_size(HashMap* hashmap) {
    uint size = cast(uint)cast(uintptr_t)HashMap.elements.offsetof
                  + cast(uint)(HashMapElem*).sizeof * hashmap.size;

    if (hashmap.lock) {
        size += cast(uint)korp_mutex.sizeof;
    }

    return size;
}

uint bh_hash_map_get_elem_struct_size() {
    return cast(uint)HashMapElem.sizeof;
}

bool bh_hash_map_traverse(HashMap* map, TraverseCallbackFunc callback, void* user_data) {
    uint index = void;
    HashMapElem* elem = void, next = void;

    if (!map || !callback) {
        LOG_ERROR("HashMap traverse failed: map or callback is NULL.\n");
        return false;
    }

    if (map.lock) {
        os_mutex_lock(map.lock);
    }

    for (index = 0; index < map.size; index++) {
        elem = map.elements[index];
        while (elem) {
            next = elem.next;
            callback(elem.key, elem.value, user_data);
            elem = next;
        }
    }

    if (map.lock) {
        os_mutex_unlock(map.lock);
    }

    return true;
}
