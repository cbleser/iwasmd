module attr_container;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bi-inc.attr_container;

union jvalue {
    bool z;
    byte b;
    ushort c;
    short s;
    int i;
    long j;
    float f = 0;
    double d = 0;
}

pragma(inline, true) private short get_int16(const(char)* buf) {
    short ret = void;
    bh_memcpy_s(&ret, short.sizeof, buf, short.sizeof);
    return ret;
}

pragma(inline, true) private ushort get_uint16(const(char)* buf) {
    return get_int16(buf);
}

pragma(inline, true) private int get_int32(const(char)* buf) {
    int ret = void;
    bh_memcpy_s(&ret, int.sizeof, buf, int.sizeof);
    return ret;
}

pragma(inline, true) private uint get_uint32(const(char)* buf) {
    return get_int32(buf);
}

pragma(inline, true) private long get_int64(const(char)* buf) {
    long ret = void;
    bh_memcpy_s(&ret, long.sizeof, buf, long.sizeof);
    return ret;
}

pragma(inline, true) private ulong get_uint64(const(char)* buf) {
    return get_int64(buf);
}

pragma(inline, true) private void set_int16(char* buf, short v) {
    bh_memcpy_s(buf, short.sizeof, &v, short.sizeof);
}

pragma(inline, true) private void set_uint16(char* buf, ushort v) {
    bh_memcpy_s(buf, ushort.sizeof, &v, ushort.sizeof);
}

pragma(inline, true) private void set_int32(char* buf, int v) {
    bh_memcpy_s(buf, int.sizeof, &v, int.sizeof);
}

pragma(inline, true) private void set_uint32(char* buf, uint v) {
    bh_memcpy_s(buf, uint.sizeof, &v, uint.sizeof);
}

pragma(inline, true) private void set_int64(char* buf, long v) {
    bh_memcpy_s(buf, long.sizeof, &v, long.sizeof);
}

pragma(inline, true) private void set_uint64(char* buf, ulong v) {
    bh_memcpy_s(buf, ulong.sizeof, &v, ulong.sizeof);
}

char* attr_container_get_attr_begin(const(attr_container_t)* attr_cont, uint* p_total_length, ushort* p_attr_num) {
    char* p = cast(char*)attr_cont.buf;
    ushort str_len = void, attr_num = void;
    uint total_length = void;

    /* skip total length */
    total_length = get_uint32(p);
    p += uint.sizeof;
    if (!total_length)
        return null;

    /* tag length */
    str_len = get_uint16(p);
    p += ushort.sizeof;
    if (!str_len)
        return null;

    /* tag content */
    p += str_len;
    if (cast(uint)(p - attr_cont.buf) >= total_length)
        return null;

    /* attribute num */
    attr_num = get_uint16(p);
    p += ushort.sizeof;
    if (cast(uint)(p - attr_cont.buf) >= total_length)
        return null;

    if (p_total_length)
        *p_total_length = total_length;

    if (p_attr_num)
        *p_attr_num = attr_num;

    /* first attribute */
    return p;
}

private char* attr_container_get_attr_next(const(char)* curr_attr) {
    char* p = cast(char*)curr_attr;
    ubyte type = void;

    /* key length and key */
    p += sizeofcast(ushort) + get_uint16(p);
    type = *p++;

    /* Short type to Boolean type */
    if (type >= ATTR_TYPE_SHORT && type <= ATTR_TYPE_BOOLEAN) {
        p += 1 << (type & 3);
        return p;
    }
    /* String type */
    else if (type == ATTR_TYPE_STRING) {
        p += sizeofcast(ushort) + get_uint16(p);
        return p;
    }
    /* ByteArray type */
    else if (type == ATTR_TYPE_BYTEARRAY) {
        p += sizeofcast(uint) + get_uint32(p);
        return p;
    }

    return null;
}

private const(char)* attr_container_find_attr(const(attr_container_t)* attr_cont, const(char)* key) {
    uint total_length = void;
    ushort str_len = void, attr_num = void, i = void;
    const(char)* p = attr_cont.buf;

    if (!key)
        return null;

    if (((p = attr_container_get_attr_begin(attr_cont, &total_length,
                                            &attr_num)) == 0))
        return null;

    for (i = 0; i < attr_num; i++) {
        /* key length */
        if (((str_len = get_uint16(p)) == 0))
            return null;

        if (str_len == strlen(key) + 1
            && memcmp(p + ushort.sizeof, key, str_len) == 0) {
            if (cast(uint)(p + sizeofcast(ushort) + str_len - attr_cont.buf)
                >= total_length)
                return null;
            return p;
        }

        if (((p = attr_container_get_attr_next(p)) == 0))
            return null;
    }

    return null;
}

char* attr_container_get_attr_end(const(attr_container_t)* attr_cont) {
    uint total_length = void;
    ushort attr_num = void, i = void;
    char* p = void;

    if (((p = attr_container_get_attr_begin(attr_cont, &total_length,
                                            &attr_num)) == 0))
        return null;

    for (i = 0; i < attr_num; i++)
        if (((p = attr_container_get_attr_next(p)) == 0))
            return null;

    return p;
}

private char* attr_container_get_msg_end(attr_container_t* attr_cont) {
    char* p = attr_cont.buf;
    return p + get_uint32(p);
}

ushort attr_container_get_attr_num(const(attr_container_t)* attr_cont) {
    ushort str_len = void;
    /* skip total length */
    const(char)* p = attr_cont.buf + uint.sizeof;

    str_len = get_uint16(p);
    /* skip tag length and tag */
    p += sizeofcast(ushort) + str_len;

    /* attribute num */
    return get_uint16(p);
}

private void attr_container_inc_attr_num(attr_container_t* attr_cont) {
    ushort str_len = void, attr_num = void;
    /* skip total length */
    char* p = attr_cont.buf + uint.sizeof;

    str_len = get_uint16(p);
    /* skip tag length and tag */
    p += sizeofcast(ushort) + str_len;

    /* attribute num */
    attr_num = get_uint16(p) + 1;
    set_uint16(p, attr_num);
}

attr_container_t* attr_container_create(const(char)* tag) {
    attr_container_t* attr_cont = void;
    int length = void, tag_length = void;
    char* p = void;

    tag_length = tag ? strlen(tag) + 1 : 1;
    length = attr_container_t.buf.offsetof +
             /* total length + tag length + tag + reserved 100 bytes */
             sizeofcast(uint) + sizeofcast(ushort) + tag_length + 100;

    if (((attr_cont = attr_container_malloc(length)) == 0)) {
        attr_container_printf(
            "Create attr_container failed: allocate memory failed.\r\n");
        return null;
    }

    memset(attr_cont, 0, length);
    p = attr_cont.buf;

    /* total length */
    set_uint32(p, length - attr_container_t.buf.offsetof);
    p += 4;

    /* tag length, tag */
    set_uint16(p, tag_length);
    p += 2;
    if (tag)
        bh_memcpy_s(p, tag_length, tag, tag_length);

    return attr_cont;
}

void attr_container_destroy(const(attr_container_t)* attr_cont) {
    if (attr_cont)
        attr_container_free(cast(char*)attr_cont);
}

private bool check_set_attr(attr_container_t** p_attr_cont, const(char)* key) {
    uint flags = void;

    if (!p_attr_cont || !*p_attr_cont || !key || strlen(key) == 0) {
        attr_container_printf(
            "Set attribute failed: invalid input arguments.\r\n");
        return false;
    }

    flags = get_uint32(cast(char*)*p_attr_cont);
    if (flags & ATTR_CONT_READONLY_SHIFT) {
        attr_container_printf(
            "Set attribute failed: attribute container is readonly.\r\n");
        return false;
    }

    return true;
}

bool attr_container_set_attr(attr_container_t** p_attr_cont, const(char)* key, int type, const(void)* value, int value_length) {
    attr_container_t* attr_cont = void, attr_cont1 = void;
    ushort str_len = void;
    uint total_length = void, attr_len = void;
    char* p = void, p1 = void, attr_end = void, msg_end = void, attr_buf = void;

    if (!check_set_attr(p_attr_cont, key)) {
        return false;
    }

    attr_cont = *p_attr_cont;
    p = attr_cont.buf;
    total_length = get_uint32(p);

    if (((attr_end = attr_container_get_attr_end(attr_cont)) == 0)) {
        attr_container_printf("Set attr failed: get attr end failed.\r\n");
        return false;
    }

    msg_end = attr_container_get_msg_end(attr_cont);

    /* key len + key + '\0' + type */
    attr_len = sizeofcast(ushort) + strlen(key) + 1 + 1;
    if (type >= ATTR_TYPE_SHORT && type <= ATTR_TYPE_BOOLEAN)
        attr_len += 1 << (type & 3);
    else if (type == ATTR_TYPE_STRING)
        attr_len += sizeofcast(ushort) + value_length;
    else if (type == ATTR_TYPE_BYTEARRAY)
        attr_len += sizeofcast(uint) + value_length;

    if (((p = attr_buf = attr_container_malloc(attr_len)) == 0)) {
        attr_container_printf("Set attr failed: allocate memory failed.\r\n");
        return false;
    }

    /* Set the attr buf */
    str_len = cast(ushort)(strlen(key) + 1);
    set_uint16(p, str_len);
    p += ushort.sizeof;
    bh_memcpy_s(p, str_len, key, str_len);
    p += str_len;

    *p++ = type;
    if (type >= ATTR_TYPE_SHORT && type <= ATTR_TYPE_BOOLEAN)
        bh_memcpy_s(p, 1 << (type & 3), value, 1 << (type & 3));
    else if (type == ATTR_TYPE_STRING) {
        set_uint16(p, value_length);
        p += ushort.sizeof;
        bh_memcpy_s(p, value_length, value, value_length);
    }
    else if (type == ATTR_TYPE_BYTEARRAY) {
        set_uint32(p, value_length);
        p += uint.sizeof;
        bh_memcpy_s(p, value_length, value, value_length);
    }

    if ((p = cast(char*)attr_container_find_attr(attr_cont, key))) {
        /* key found */
        p1 = attr_container_get_attr_next(p);

        if (p1 - p == attr_len) {
            bh_memcpy_s(p, attr_len, attr_buf, attr_len);
            attr_container_free(attr_buf);
            return true;
        }

        if (cast(uint)(p1 - p + msg_end - attr_end) >= attr_len) {
            memmove(p, p1, attr_end - p1);
            bh_memcpy_s(p + (attr_end - p1), attr_len, attr_buf, attr_len);
            attr_container_free(attr_buf);
            return true;
        }

        total_length += attr_len + 100;
        if (((attr_cont1 = attr_container_malloc(attr_container_t.buf.offsetof
                                                 + total_length)) == 0)) {
            attr_container_printf(
                "Set attr failed: allocate memory failed.\r\n");
            attr_container_free(attr_buf);
            return false;
        }

        bh_memcpy_s(attr_cont1, p - cast(char*)attr_cont, attr_cont,
                    p - cast(char*)attr_cont);
        bh_memcpy_s(cast(char*)attr_cont1 + cast(uint)(p - cast(char*)attr_cont),
                    attr_end - p1, p1, attr_end - p1);
        bh_memcpy_s(cast(char*)attr_cont1 + cast(uint)(p - cast(char*)attr_cont)
                        + cast(uint)(attr_end - p1),
                    attr_len, attr_buf, attr_len);
        p = attr_cont1.buf;
        set_uint32(p, total_length);
        *p_attr_cont = attr_cont1;
        /* Free original buffer */
        attr_container_free(attr_cont);
        attr_container_free(attr_buf);
        return true;
    }
    else {
        /* key not found */
        if (cast(uint)(msg_end - attr_end) >= attr_len) {
            bh_memcpy_s(attr_end, msg_end - attr_end, attr_buf, attr_len);
            attr_container_inc_attr_num(attr_cont);
            attr_container_free(attr_buf);
            return true;
        }

        total_length += attr_len + 100;
        if (((attr_cont1 = attr_container_malloc(attr_container_t.buf.offsetof
                                                 + total_length)) == 0)) {
            attr_container_printf(
                "Set attr failed: allocate memory failed.\r\n");
            attr_container_free(attr_buf);
            return false;
        }

        bh_memcpy_s(attr_cont1, attr_end - cast(char*)attr_cont, attr_cont,
                    attr_end - cast(char*)attr_cont);
        bh_memcpy_s(cast(char*)attr_cont1
                        + cast(uint)(attr_end - cast(char*)attr_cont),
                    attr_len, attr_buf, attr_len);
        attr_container_inc_attr_num(attr_cont1);
        p = attr_cont1.buf;
        set_uint32(p, total_length);
        *p_attr_cont = attr_cont1;
        /* Free original buffer */
        attr_container_free(attr_cont);
        attr_container_free(attr_buf);
        return true;
    }

    return false;
}

bool attr_container_set_short(attr_container_t** p_attr_cont, const(char)* key, short value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_SHORT, &value,
                                   2);
}

bool attr_container_set_int(attr_container_t** p_attr_cont, const(char)* key, int value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_INT, &value, 4);
}

bool attr_container_set_int64(attr_container_t** p_attr_cont, const(char)* key, long value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_INT64, &value,
                                   8);
}

bool attr_container_set_byte(attr_container_t** p_attr_cont, const(char)* key, byte value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_BYTE, &value, 1);
}

bool attr_container_set_uint16(attr_container_t** p_attr_cont, const(char)* key, ushort value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_UINT16, &value,
                                   2);
}

bool attr_container_set_float(attr_container_t** p_attr_cont, const(char)* key, float value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_FLOAT, &value,
                                   4);
}

bool attr_container_set_double(attr_container_t** p_attr_cont, const(char)* key, double value) {
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_DOUBLE, &value,
                                   8);
}

bool attr_container_set_bool(attr_container_t** p_attr_cont, const(char)* key, bool value) {
    byte value1 = value ? 1 : 0;
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_BOOLEAN, &value1,
                                   1);
}

bool attr_container_set_string(attr_container_t** p_attr_cont, const(char)* key, const(char)* value) {
    if (!value) {
        attr_container_printf("Set attr failed: invald input arguments.\r\n");
        return false;
    }
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_STRING, value,
                                   strlen(value) + 1);
}

bool attr_container_set_bytearray(attr_container_t** p_attr_cont, const(char)* key, const(byte)* value, uint length) {
    if (!value) {
        attr_container_printf("Set attr failed: invald input arguments.\r\n");
        return false;
    }
    return attr_container_set_attr(p_attr_cont, key, ATTR_TYPE_BYTEARRAY, value,
                                   length);
}

private const(char)* attr_container_get_attr(const(attr_container_t)* attr_cont, const(char)* key) {
    const(char)* attr_addr = void;

    if (!attr_cont || !key) {
        attr_container_printf(
            "Get attribute failed: invalid input arguments.\r\n");
        return null;
    }

    if (((attr_addr = attr_container_find_attr(attr_cont, key)) == 0)) {
        attr_container_printf("Get attribute failed: lookup key failed.\r\n");
        return false;
    }

    /* key len + key + '\0' */
    return attr_addr + 2 + strlen(key) + 1;
}

enum string TEMPLATE_ATTR_BUF_TO_VALUE(string attr, string key, string var_name) = `                      \
    do {                                                                     \
        jvalue val;                                                          \
        const char *addr = attr_container_get_attr(attr, key);               \
        uint8_t type;                                                        \
        if (!addr)                                                           \
            return 0;                                                        \
        val.j = 0;                                                           \
        type = *(uint8_t *)addr++;                                           \
        switch (type) {                                                      \
            case ATTR_TYPE_SHORT:                                            \
            case ATTR_TYPE_INT:                                              \
            case ATTR_TYPE_INT64:                                            \
            case ATTR_TYPE_BYTE:                                             \
            case ATTR_TYPE_UINT16:                                           \
            case ATTR_TYPE_FLOAT:                                            \
            case ATTR_TYPE_DOUBLE:                                           \
            case ATTR_TYPE_BOOLEAN:                                          \
                bh_memcpy_s(&val, sizeof(val.var_name), addr,                \
                            1 << (type & 3));                                \
                break;                                                       \
            case ATTR_TYPE_STRING:                                           \
            {                                                                \
                unsigned len = get_uint16(addr);                             \
                addr += 2;                                                   \
                if (len > sizeof(val.var_name))                              \
                    len = sizeof(val.var_name);                              \
                bh_memcpy_s(&val.var_name, sizeof(val.var_name), addr, len); \
                break;                                                       \
            }                                                                \
            case ATTR_TYPE_BYTEARRAY:                                        \
            {                                                                \
                unsigned len = get_uint32(addr);                             \
                addr += 4;                                                   \
                if (len > sizeof(val.var_name))                              \
                    len = sizeof(val.var_name);                              \
                bh_memcpy_s(&val.var_name, sizeof(val.var_name), addr, len); \
                break;                                                       \
            }                                                                \
            default:                                                         \
                bh_assert(0);                                                \
                break;                                                       \
        }                                                                    \
        return val.var_name;                                                 \
    } while (0)`;

short attr_container_get_as_short(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, s);
}

int attr_container_get_as_int(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, i);
}

long attr_container_get_as_int64(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, j);
}

byte attr_container_get_as_byte(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, b);
}

ushort attr_container_get_as_uint16(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, s);
}

float attr_container_get_as_float(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, f);
}

double attr_container_get_as_double(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, d);
}

bool attr_container_get_as_bool(const(attr_container_t)* attr_cont, const(char)* key) {
    TEMPLATE_ATTR_BUF_TO_VALUE(attr_cont, key, z);
}

const(byte)* attr_container_get_as_bytearray(const(attr_container_t)* attr_cont, const(char)* key, uint* array_length) {
    const(char)* addr = attr_container_get_attr(attr_cont, key);
    ubyte type = void;
    uint length = void;

    if (!addr)
        return null;

    if (!array_length) {
        attr_container_printf("Get attribute failed: invalid input arguments.");
        return null;
    }

    type = *cast(ubyte*)addr++;
    switch (type) {
        case ATTR_TYPE_SHORT:
        case ATTR_TYPE_INT:
        case ATTR_TYPE_INT64:
        case ATTR_TYPE_BYTE:
        case ATTR_TYPE_UINT16:
        case ATTR_TYPE_FLOAT:
        case ATTR_TYPE_DOUBLE:
        case ATTR_TYPE_BOOLEAN:
            length = 1 << (type & 3);
            break;
        case ATTR_TYPE_STRING:
            length = get_uint16(addr);
            addr += 2;
            break;
        case ATTR_TYPE_BYTEARRAY:
            length = get_uint32(addr);
            addr += 4;
            break;
        default:
            return null;
    }

    *array_length = length;
    return cast(const(byte)*)addr;
}

char* attr_container_get_as_string(const(attr_container_t)* attr_cont, const(char)* key) {
    uint array_length = void;
    return cast(char*)attr_container_get_as_bytearray(attr_cont, key,
                                                   &array_length);
}

const(char)* attr_container_get_tag(const(attr_container_t)* attr_cont) {
    return attr_cont ? attr_cont.buf + sizeofcast(uint) + ushort.sizeof
                     : null;
}

bool attr_container_contain_key(const(attr_container_t)* attr_cont, const(char)* key) {
    if (!attr_cont || !key || !strlen(key)) {
        attr_container_printf(
            "Check contain key failed: invalid input arguments.\r\n");
        return false;
    }
    return attr_container_find_attr(attr_cont, key) ? true : false;
}

uint attr_container_get_serialize_length(const(attr_container_t)* attr_cont) {
    const(char)* p = void;

    if (!attr_cont) {
        attr_container_printf("Get container serialize length failed: invalid "
                              ~ "input arguments.\r\n");
        return 0;
    }

    p = attr_cont.buf;
    return sizeofcast(ushort) + get_uint32(p);
}

bool attr_container_serialize(char* buf, const(attr_container_t)* attr_cont) {
    const(char)* p = void;
    ushort flags = void;
    uint length = void;

    if (!buf || !attr_cont) {
        attr_container_printf(
            "Container serialize failed: invalid input arguments.\r\n");
        return false;
    }

    p = attr_cont.buf;
    length = sizeofcast(ushort) + get_uint32(p);
    bh_memcpy_s(buf, length, attr_cont, length);
    /* Set readonly */
    flags = get_uint16(cast(const(char)*)attr_cont);
    set_uint16(buf, flags | (1 << ATTR_CONT_READONLY_SHIFT));

    return true;
}

bool attr_container_is_constant(const(attr_container_t)* attr_cont) {
    ushort flags = void;

    if (!attr_cont) {
        attr_container_printf(
            "Container check const: invalid input arguments.\r\n");
        return false;
    }

    flags = get_uint16(cast(const(char)*)attr_cont);
    return (flags & (1 << ATTR_CONT_READONLY_SHIFT)) ? true : false;
}

void attr_container_dump(const(attr_container_t)* attr_cont) {
    uint total_length = void;
    ushort attr_num = void, i = void, type = void;
    const(char)* p = void, tag = void, key = void;
    jvalue value = void;

    if (!attr_cont)
        return;

    tag = attr_container_get_tag(attr_cont);
    if (!tag)
        return;

    attr_container_printf("Attribute container dump:\n");
    attr_container_printf("Tag: %s\n", tag);

    p = attr_container_get_attr_begin(attr_cont, &total_length, &attr_num);
    if (!p)
        return;

    attr_container_printf("Attribute list:\n");
    for (i = 0; i < attr_num; i++) {
        key = p + 2;
        /* Skip key len and key */
        p += 2 + get_uint16(p);
        type = *p++;
        attr_container_printf("  key: %s", key);

        switch (type) {
            case ATTR_TYPE_SHORT:
                bh_memcpy_s(&value.s, short.sizeof, p, short.sizeof);
                attr_container_printf(", type: short, value: 0x%x\n",
                                      value.s & 0xFFFF);
                p += 2;
                break;
            case ATTR_TYPE_INT:
                bh_memcpy_s(&value.i, int.sizeof, p, int.sizeof);
                attr_container_printf(", type: int, value: 0x%x\n", value.i);
                p += 4;
                break;
            case ATTR_TYPE_INT64:
                bh_memcpy_s(&value.j, ulong.sizeof, p, ulong.sizeof);
                attr_container_printf(", type: int64, value: 0x%llx\n",
                                      cast(uint)(value.j));
                p += 8;
                break;
            case ATTR_TYPE_BYTE:
                bh_memcpy_s(&value.b, 1, p, 1);
                attr_container_printf(", type: byte, value: 0x%x\n",
                                      value.b & 0xFF);
                p++;
                break;
            case ATTR_TYPE_UINT16:
                bh_memcpy_s(&value.c, ushort.sizeof, p, ushort.sizeof);
                attr_container_printf(", type: uint16, value: 0x%x\n", value.c);
                p += 2;
                break;
            case ATTR_TYPE_FLOAT:
                bh_memcpy_s(&value.f, float.sizeof, p, float.sizeof);
                attr_container_printf(", type: float, value: %f\n", value.f);
                p += 4;
                break;
            case ATTR_TYPE_DOUBLE:
                bh_memcpy_s(&value.d, double.sizeof, p, double.sizeof);
                attr_container_printf(", type: double, value: %f\n", value.d);
                p += 8;
                break;
            case ATTR_TYPE_BOOLEAN:
                bh_memcpy_s(&value.z, 1, p, 1);
                attr_container_printf(", type: bool, value: 0x%x\n", value.z);
                p++;
                break;
            case ATTR_TYPE_STRING:
                attr_container_printf(", type: string, value: %s\n",
                                      p + ushort.sizeof);
                p += sizeofcast(ushort) + get_uint16(p);
                break;
            case ATTR_TYPE_BYTEARRAY:
                attr_container_printf(", type: byte array, length: %d\n",
                                      get_uint32(p));
                p += sizeofcast(uint) + get_uint32(p);
                break;
            default:
                bh_assert(0);
                break;
        }
    }

    attr_container_printf("\n");
}
