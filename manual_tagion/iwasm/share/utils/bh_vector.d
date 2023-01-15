module tagion.iwasm.share.utils.bh_vector;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


public import tagion.iwasm.app_framework.base.app.bh_platform;


enum DEFAULT_VECTOR_INIT_SIZE = 8;

struct Vector {
    /* max element number */
    size_t max_elems;
    /* vector data allocated */
    ubyte* data;
    /* current element num */
    size_t num_elems;
    /* size of each element */
    size_t size_elem;
    void* lock;
}

/**
 * Initialize vector
 *
 * @param vector the vector to init
 * @param init_length the initial length of the vector
 * @param size_elem size of each element
 *
 * @return true if success, false otherwise
 */
bool bh_vector_init(Vector* vector, size_t init_length, size_t size_elem, bool use_lock);

/**
 * Set element of vector
 *
 * @param vector the vector to set
 * @param index the index of the element to set
 * @param elem_buf the element buffer which stores the element data
 *
 * @return true if success, false otherwise
 */
bool bh_vector_set(Vector* vector, uint index, const(void)* elem_buf);

/**
 * Get element of vector
 *
 * @param vector the vector to get
 * @param index the index of the element to get
 * @param elem_buf the element buffer to store the element data,
 *                 whose length must be no less than element size
 *
 * @return true if success, false otherwise
 */
bool bh_vector_get(Vector* vector, uint index, void* elem_buf);

/**
 * Insert element of vector
 *
 * @param vector the vector to insert
 * @param index the index of the element to insert
 * @param elem_buf the element buffer which stores the element data
 *
 * @return true if success, false otherwise
 */
bool bh_vector_insert(Vector* vector, uint index, const(void)* elem_buf);

/**
 * Append element to the end of vector
 *
 * @param vector the vector to append
 * @param elem_buf the element buffer which stores the element data
 *
 * @return true if success, false otherwise
 */
bool bh_vector_append(Vector* vector, const(void)* elem_buf);

/**
 * Remove element from vector
 *
 * @param vector the vector to remove element
 * @param index the index of the element to remove
 * @param old_elem_buf if not NULL, copies the element data to the buffer
 *
 * @return true if success, false otherwise
 */
bool bh_vector_remove(Vector* vector, uint index, void* old_elem_buf);

/**
 * Return the size of the vector
 *
 * @param vector the vector to get size
 *
 * @return return the size of the vector
 */
size_t bh_vector_size(const(Vector)* vector);

/**
 * Destroy the vector
 *
 * @param vector the vector to destroy
 *
 * @return true if success, false otherwise
 */
bool bh_vector_destroy(Vector* vector);


//! #endif /* endof _WASM_VECTOR_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import tagion.iwasm.share.utils.bh_vector;

private ubyte* alloc_vector_data(size_t length, size_t size_elem) {
    ulong total_size = (cast(ulong)size_elem) * length;
    ubyte* data = void;

    if (length > UINT32_MAX || size_elem > UINT32_MAX
        || total_size > UINT32_MAX) {
        return null;
    }

    if ((data = BH_MALLOC(cast(uint)total_size))) {
        memset(data, 0, cast(uint)total_size);
    }

    return data;
}

/**
 * every caller of `extend_vector` must provide
 * a thread-safe environment.
 */
private bool extend_vector(Vector* vector, size_t length) {
    ubyte* data = void;

    if (length <= vector.max_elems)
        return true;

    if (length < vector.size_elem * 3 / 2)
        length = vector.size_elem * 3 / 2;

    if (((data = alloc_vector_data(length, vector.size_elem)) == 0)) {
        return false;
    }

    bh_memcpy_s(data, cast(uint)(vector.size_elem * length), vector.data,
                cast(uint)(vector.size_elem * vector.max_elems));
    BH_FREE(vector.data);

    vector.data = data;
    vector.max_elems = length;
    return true;
}

bool bh_vector_init(Vector* vector, size_t init_length, size_t size_elem, bool use_lock) {
    if (!vector) {
        LOG_ERROR("Init vector failed: vector is NULL.\n");
        return false;
    }

    if (init_length == 0) {
        init_length = 4;
    }

    if (((vector.data = alloc_vector_data(init_length, size_elem)) == 0)) {
        LOG_ERROR("Init vector failed: alloc memory failed.\n");
        return false;
    }

    vector.size_elem = size_elem;
    vector.max_elems = init_length;
    vector.num_elems = 0;
    vector.lock = null;

    if (use_lock) {
        if (((vector.lock = BH_MALLOC(korp_mutex.sizeof)) == 0)) {
            LOG_ERROR("Init vector failed: alloc locker failed.\n");
            bh_vector_destroy(vector);
            return false;
        }

        if (BHT_OK != os_mutex_init(vector.lock)) {
            LOG_ERROR("Init vector failed: init locker failed.\n");

            BH_FREE(vector.lock);
            vector.lock = null;

            bh_vector_destroy(vector);
            return false;
        }
    }

    return true;
}

bool bh_vector_set(Vector* vector, uint index, const(void)* elem_buf) {
    if (!vector || !elem_buf) {
        LOG_ERROR("Set vector elem failed: vector or elem buf is NULL.\n");
        return false;
    }

    if (index >= vector.num_elems) {
        LOG_ERROR("Set vector elem failed: invalid elem index.\n");
        return false;
    }

    if (vector.lock)
        os_mutex_lock(vector.lock);
    bh_memcpy_s(vector.data + vector.size_elem * index,
                cast(uint)vector.size_elem, elem_buf, cast(uint)vector.size_elem);
    if (vector.lock)
        os_mutex_unlock(vector.lock);
    return true;
}

bool bh_vector_get(Vector* vector, uint index, void* elem_buf) {
    if (!vector || !elem_buf) {
        LOG_ERROR("Get vector elem failed: vector or elem buf is NULL.\n");
        return false;
    }

    if (index >= vector.num_elems) {
        LOG_ERROR("Get vector elem failed: invalid elem index.\n");
        return false;
    }

    if (vector.lock)
        os_mutex_lock(vector.lock);
    bh_memcpy_s(elem_buf, cast(uint)vector.size_elem,
                vector.data + vector.size_elem * index,
                cast(uint)vector.size_elem);
    if (vector.lock)
        os_mutex_unlock(vector.lock);
    return true;
}

bool bh_vector_insert(Vector* vector, uint index, const(void)* elem_buf) {
    size_t i = void;
    ubyte* p = void;
    bool ret = false;

    if (!vector || !elem_buf) {
        LOG_ERROR("Insert vector elem failed: vector or elem buf is NULL.\n");
        goto just_return;
    }

    if (index >= vector.num_elems) {
        LOG_ERROR("Insert vector elem failed: invalid elem index.\n");
        goto just_return;
    }

    if (vector.lock)
        os_mutex_lock(vector.lock);

    if (!extend_vector(vector, vector.num_elems + 1)) {
        LOG_ERROR("Insert vector elem failed: extend vector failed.\n");
        goto unlock_return;
    }

    p = vector.data + vector.size_elem * vector.num_elems;
    for (i = vector.num_elems - 1; i > index; i--) {
        bh_memcpy_s(p, cast(uint)vector.size_elem, p - vector.size_elem,
                    cast(uint)vector.size_elem);
        p -= vector.size_elem;
    }

    bh_memcpy_s(p, cast(uint)vector.size_elem, elem_buf,
                cast(uint)vector.size_elem);
    vector.num_elems++;
    ret = true;

unlock_return:
    if (vector.lock)
        os_mutex_unlock(vector.lock);
just_return:
    return ret;
}

bool bh_vector_append(Vector* vector, const(void)* elem_buf) {
    bool ret = false;

    if (!vector || !elem_buf) {
        LOG_ERROR("Append vector elem failed: vector or elem buf is NULL.\n");
        goto just_return;
    }

    /* make sure one more slot is used by the thread who allocas it */
    if (vector.lock)
        os_mutex_lock(vector.lock);

    if (!extend_vector(vector, vector.num_elems + 1)) {
        LOG_ERROR("Append ector elem failed: extend vector failed.\n");
        goto unlock_return;
    }

    bh_memcpy_s(vector.data + vector.size_elem * vector.num_elems,
                cast(uint)vector.size_elem, elem_buf, cast(uint)vector.size_elem);
    vector.num_elems++;
    ret = true;

unlock_return:
    if (vector.lock)
        os_mutex_unlock(vector.lock);
just_return:
    return ret;
}

bool bh_vector_remove(Vector* vector, uint index, void* old_elem_buf) {
    uint i = void;
    ubyte* p = void;

    if (!vector) {
        LOG_ERROR("Remove vector elem failed: vector is NULL.\n");
        return false;
    }

    if (index >= vector.num_elems) {
        LOG_ERROR("Remove vector elem failed: invalid elem index.\n");
        return false;
    }

    if (vector.lock)
        os_mutex_lock(vector.lock);
    p = vector.data + vector.size_elem * index;

    if (old_elem_buf) {
        bh_memcpy_s(old_elem_buf, cast(uint)vector.size_elem, p,
                    cast(uint)vector.size_elem);
    }

    for (i = index; i < vector.num_elems - 1; i++) {
        bh_memcpy_s(p, cast(uint)vector.size_elem, p + vector.size_elem,
                    cast(uint)vector.size_elem);
        p += vector.size_elem;
    }

    vector.num_elems--;
    if (vector.lock)
        os_mutex_unlock(vector.lock);
    return true;
}

size_t bh_vector_size(const(Vector)* vector) {
    return vector ? vector.num_elems : 0;
}

bool bh_vector_destroy(Vector* vector) {
    if (!vector) {
        LOG_ERROR("Destroy vector elem failed: vector is NULL.\n");
        return false;
    }

    if (vector.data)
        BH_FREE(vector.data);

    if (vector.lock) {
        os_mutex_destroy(vector.lock);
        BH_FREE(vector.lock);
    }

    memset(vector, 0, Vector.sizeof);
    return true;
}
