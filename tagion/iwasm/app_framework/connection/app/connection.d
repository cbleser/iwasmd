module connection;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wa-inc.connection;
public import connection_api;

/* Raw connection structure */
struct _connection {
    /* Next connection */
    _connection* next;

    /* Handle of the connection */
    uint handle;

    /* Callback function called when event on this connection occurs */
    on_connection_event_f on_event;

    /* User data */
    void* user_data;
}alias connection_t = _connection;

/* Raw connections list */
private connection_t* g_conns = null;

connection_t* api_open_connection(const(char)* name, attr_container_t* args, on_connection_event_f on_event, void* user_data) {
    connection_t* conn = void;
    char* args_buffer = cast(char*)args;
    uint handle = void, args_len = attr_container_get_serialize_length(args);

    handle = wasm_open_connection(name, args_buffer, args_len);
    if (handle == -1)
        return null;

    conn = cast(connection_t*)malloc(typeof(*conn).sizeof);
    if (conn == null) {
        wasm_close_connection(handle);
        return null;
    }

    memset(conn, 0, typeof(*conn).sizeof);
    conn.handle = handle;
    conn.on_event = on_event;
    conn.user_data = user_data;

    if (g_conns != null) {
        conn.next = g_conns;
        g_conns = conn;
    }
    else {
        g_conns = conn;
    }

    return conn;
}

void api_close_connection(connection_t* c) {
    connection_t* conn = g_conns, prev = null;

    while (conn) {
        if (conn == c) {
            wasm_close_connection(c.handle);
            if (prev != null)
                prev.next = conn.next;
            else
                g_conns = conn.next;
            free(conn);
            return;
        }
        else {
            prev = conn;
            conn = conn.next;
        }
    }
}

int api_send_on_connection(connection_t* conn, const(char)* data, uint len) {
    return wasm_send_on_connection(conn.handle, data, len);
}

bool api_config_connection(connection_t* conn, attr_container_t* cfg) {
    char* cfg_buffer = cast(char*)cfg;
    uint cfg_len = attr_container_get_serialize_length(cfg);

    return wasm_config_connection(conn.handle, cfg_buffer, cfg_len);
}

void on_connection_data(uint handle, char* buffer, uint len) {
    connection_t* conn = g_conns;

    while (conn != null) {
        if (conn.handle == handle) {
            if (len == 0) {
                conn.on_event(conn, CONN_EVENT_TYPE_DISCONNECT, null, 0,
                               conn.user_data);
            }
            else {
                conn.on_event(conn, CONN_EVENT_TYPE_DATA, buffer, len,
                               conn.user_data);
            }

            return;
        }
        conn = conn.next;
    }
}
