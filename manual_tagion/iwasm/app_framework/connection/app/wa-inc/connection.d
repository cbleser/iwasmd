module connection;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bi-inc.attr_container;

version (none) {
extern "C" {
//! #endif

struct _connection;;
alias connection_t = _connection;

/* Connection event type */
enum _Conn_event_type_t {
    /* Data is received */
    CONN_EVENT_TYPE_DATA = 1,
    /* Connection is disconnected */
    CONN_EVENT_TYPE_DISCONNECT
}alias conn_event_type_t = _Conn_event_type_t;

/*
 * @typedef on_connection_event_f
 *
 * @param conn the connection that the event belongs to
 * @param type event type
 * @param data the data received for CONN_EVENT_TYPE_DATA event
 * @param len length of the data in byte
 * @param user_data user data
 */
alias on_connection_event_f = void function(connection_t* conn, conn_event_type_t type, const(char)* data, uint len, void* user_data);

/*
 *****************
 * Connection API's
 *****************
 */

/*
 * @brief Open a connection.
 *
 * @param name name of the connection, "TCP", "UDP" or "UART"
 * @param args connection arguments, such as: ip:127.0.0.1, port:8888
 * @param on_event callback function called when event occurs
 * @param user_data user data
 *
 * @return the connection or NULL means fail
 */
connection_t* api_open_connection(const(char)* name, attr_container_t* args, on_connection_event_f on_event, void* user_data);

/*
 * @brief Close a connection.
 *
 * @param conn connection
 */
void api_close_connection(connection_t* conn);

/*
 * Send data to the connection in non-blocking manner which returns immediately
 *
 * @param conn the connection
 * @param data data buffer to be sent
 * @param len length of the data in byte
 *
 * @return actual length sent, or -1 if fail(maybe underlying buffer is full)
 */
int api_send_on_connection(connection_t* conn, const(char)* data, uint len);

/*
 * @brief Configure connection.
 *
 * @param conn the connection
 * @param cfg configurations
 *
 * @return true if success, false otherwise
 */
bool api_config_connection(connection_t* conn, attr_container_t* cfg);

version (none) {}
}
}


