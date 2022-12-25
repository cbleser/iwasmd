module packets;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_platform;
public import packets;
public import gdbserver;

void write_data_raw(WASMGDBServer* gdbserver, const(ubyte)* data, ssize_t len) {
    ssize_t nwritten = void;

    nwritten = os_socket_send(gdbserver.socket_fd, data, len);
    if (nwritten < 0) {
        LOG_ERROR("Write error\n");
        exit(-2);
    }
}

void write_hex(WASMGDBServer* gdbserver, c_ulong hex) {
    char[32] buf = void;
    size_t len = void;

    len = snprintf(buf.ptr, sizeof(buf).ptr - 1, "%02lx", hex);
    write_data_raw(gdbserver, cast(ubyte*)buf, len);
}

void write_packet_bytes(WASMGDBServer* gdbserver, const(ubyte)* data, size_t num_bytes) {
    ubyte checksum = void;
    size_t i = void;

    write_data_raw(gdbserver, cast(ubyte*)"$", 1);
    for (i = 0, checksum = 0; i < num_bytes; ++i)
        checksum += data[i];
    write_data_raw(gdbserver, cast(ubyte*)data, num_bytes);
    write_data_raw(gdbserver, cast(ubyte*)"#", 1);
    write_hex(gdbserver, checksum);
}

void write_packet(WASMGDBServer* gdbserver, const(char)* data) {
    LOG_VERBOSE("send replay:%s", data);
    write_packet_bytes(gdbserver, cast(const(ubyte)*)data, strlen(data));
}

void write_binary_packet(WASMGDBServer* gdbserver, const(char)* pfx, const(ubyte)* data, ssize_t num_bytes) {
    ubyte* buf = void;
    ssize_t pfx_num_chars = strlen(pfx);
    ssize_t buf_num_bytes = 0, total_size = void;
    int i = void;

    total_size = 2 * num_bytes + pfx_num_chars;
    buf = wasm_runtime_malloc(total_size);
    if (!buf) {
        LOG_ERROR("Failed to allocate memory for binary packet");
        return;
    }

    memset(buf, 0, total_size);
    memcpy(buf, pfx, pfx_num_chars);
    buf_num_bytes += pfx_num_chars;

    for (i = 0; i < num_bytes; ++i) {
        ubyte b = data[i];
        switch (b) {
            case '#':
            case '$':
            case '}':
            case '*':
                buf[buf_num_bytes++] = '}';
                buf[buf_num_bytes++] = b ^ 0x20;
                break;
            default:
                buf[buf_num_bytes++] = b;
                break;
        }
    }
    write_packet_bytes(gdbserver, buf, buf_num_bytes);
    wasm_runtime_free(buf);
}
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import gdbserver;

void write_data_raw(WASMGDBServer* gdbserver, const(ubyte)* data, ssize_t len);

void write_packet(WASMGDBServer* gdbserver, const(char)* data);


