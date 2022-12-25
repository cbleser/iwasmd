module attr_container;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdint;
public import core.stdc.stdio;
public import core.stdc.stdlib;
public import core.stdc.string;
public import core.stdc.stddef;
public import stdbool;
public import bh_platform;

version (none) {
extern "C" {
//! #endif

/* Attribute type */
enum {
    ATTR_TYPE_BEGIN = 1,
    ATTR_TYPE_SHORT = ATTR_TYPE_BEGIN,
    ATTR_TYPE_INT,
    ATTR_TYPE_INT64,
    ATTR_TYPE_BYTE,
    ATTR_TYPE_UINT16,
    ATTR_TYPE_FLOAT,
    ATTR_TYPE_DOUBLE,
    ATTR_TYPE_BOOLEAN,
    ATTR_TYPE_STRING,
    ATTR_TYPE_BYTEARRAY,
    ATTR_TYPE_END = ATTR_TYPE_BYTEARRAY
};

enum ATTR_CONT_READONLY_SHIFT = 2;

struct attr_container {
    /* container flag:
     * bit0, bit1 denote the implemenation algorithm, 00: buffer, 01: link list
     * bit2 denotes the readonly flag: 1 is readonly and attr cannot be set
     */
    char[2] flags = 0;
    /**
     * Buffer format
     * for buffer implementation:
     *   buf length (4 bytes)
     *   tag length (2 bytes)
     *   tag
     *   attr num (2bytes)
     *   attr[0..n-1]:
     *     attr key length (2 bytes)
     *     attr type (1byte)
     *     attr value (length depends on attr type)
     */
    char[1] buf = 0;
}alias attr_container_t = attr_container;

/**
 * Create attribute container
 *
 * @param tag tag of current attribute container
 *
 * @return the created attribute container, NULL if failed
 */
attr_container_t* attr_container_create(const(char)* tag);

/**
 * Destroy attribute container
 *
 * @param attr_cont the attribute container to destroy
 */
void attr_container_destroy(const(attr_container_t)* attr_cont);

/**
 * Set short attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_short(attr_container_t** p_attr_cont, const(char)* key, short value);

/**
 * Set int attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_int(attr_container_t** p_attr_cont, const(char)* key, int value);

/**
 * Set int64 attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_int64(attr_container_t** p_attr_cont, const(char)* key, long value);

/**
 * Set byte attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_byte(attr_container_t** p_attr_cont, const(char)* key, byte value);

/**
 * Set uint16 attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_uint16(attr_container_t** p_attr_cont, const(char)* key, ushort value);

/**
 * Set float attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_float(attr_container_t** p_attr_cont, const(char)* key, float value);

/**
 * Set double attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_double(attr_container_t** p_attr_cont, const(char)* key, double value);

/**
 * Set bool attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_bool(attr_container_t** p_attr_cont, const(char)* key, bool value);

/**
 * Set string attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the attribute value
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_string(attr_container_t** p_attr_cont, const(char)* key, const(char)* value);

/**
 * Set bytearray attribute in attribute container
 *
 * @param p_attr_cont pointer to attribute container to set attribute, and
 * return the new attribute container if it is re-created
 * @param key the attribute key
 * @param value the bytearray buffer
 * @param length the bytearray length
 *
 * @return true if success, false otherwise
 */
bool attr_container_set_bytearray(attr_container_t** p_attr_cont, const(char)* key, const(byte)* value, uint length);

/**
 * Get tag of current attribute container
 *
 * @param attr_cont the attribute container
 *
 * @return tag of current attribute container
 */
const(char)* attr_container_get_tag(const(attr_container_t)* attr_cont);

/**
 * Get attribute number of current attribute container
 *
 * @param attr_cont the attribute container
 *
 * @return attribute number of current attribute container
 */
ushort attr_container_get_attr_num(const(attr_container_t)* attr_cont);

/**
 * Whether the attribute container contains an attribute key.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return true if key is contained in message, false otherwise
 */
bool attr_container_contain_key(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as short value,
 * return 0 if attribute isn't found in message.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the short value of the attribute, 0 if key isn't found
 */
short attr_container_get_as_short(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as int value,
 * return 0 if attribute isn't found in message.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the int value of the attribute, 0 if key isn't found
 */
int attr_container_get_as_int(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as int64 value,
 * return 0 if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the long value of the attribute, 0 if key isn't found
 */
long attr_container_get_as_int64(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as byte value,
 * return 0 if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the byte value of the attribute, 0 if key isn't found
 */
byte attr_container_get_as_byte(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as uint16 value,
 * return 0 if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the char value of the attribute, 0 if key isn't found
 */
ushort attr_container_get_as_uint16(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as float value,
 * return 0 if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the float value of the attribute, 0 if key isn't found
 */
float attr_container_get_as_float(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as double value,
 * return 0 if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the double value of the attribute, 0 if key isn't found
 */
double attr_container_get_as_double(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as bool value,
 * return false if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the bool value of the attribute, 0 if key isn't found
 */
bool attr_container_get_as_bool(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as string value,
 * return NULL if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the string value of the attribute, NULL if key isn't found
 */
char* attr_container_get_as_string(const(attr_container_t)* attr_cont, const(char)* key);

/**
 * Get attribute from attribute container and return it as bytearray value,
 * return 0 if attribute isn't found in attribute container.
 *
 * @param attr_cont the attribute container
 * @param key the attribute key
 *
 * @return the bytearray value of the attribute, NULL if key isn't found
 */
const(byte)* attr_container_get_as_bytearray(const(attr_container_t)* attr_cont, const(char)* key, uint* array_length);

/**
 * Get the buffer size of attribute container
 *
 * @param attr_cont the attribute container
 *
 * @return the buffer size of attribute container
 */
uint attr_container_get_serialize_length(const(attr_container_t)* attr_cont);

/**
 * Serialize attribute container to a buffer
 *
 * @param buf the buffer to receive the serialized data
 * @param attr_cont the attribute container to be serialized
 *
 * @return true if success, false otherwise
 */
bool attr_container_serialize(char* buf, const(attr_container_t)* attr_cont);

/**
 * Whether the attribute container is const, or set attribute isn't supported
 *
 * @param attr_cont the attribute container
 *
 * @return true if const, false otherwise
 */
bool attr_container_is_constant(const(attr_container_t)* attr_cont);

void attr_container_dump(const(attr_container_t)* attr_cont);

version (attr_container_malloc) {} else {
enum attr_container_malloc = WA_MALLOC;
}

version (attr_container_free) {} else {
enum attr_container_free = WA_FREE;
}

version (attr_container_printf) {} else {
enum attr_container_printf = printf;
}

version (none) {}
} /* end of extern "C" */
}

 /* end of _ATTR_CONTAINER_H_ */
