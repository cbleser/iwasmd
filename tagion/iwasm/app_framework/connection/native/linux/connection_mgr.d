module connection_mgr;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/*
 * Note:
 * This file implements the linux version connection library which is
 * defined in connection_lib.h.
 * It also provides a reference implementation of connections manager.
 */

public import connection_lib;
public import bh_platform;
public import app_manager_export;
public import module_wasm_app;
public import conn_tcp;
public import conn_udp;
public import conn_uart;

public import core.sys.posix.unistd;
public import sys/epoll;
public import core.sys.posix.sys.types;
public import arpa/inet;
public import core.sys.posix.fcntl;

enum MAX_EVENTS = 10;
enum IO_BUF_SIZE = 256;

private bool polling_thread_run = true;

/* Connection type */
enum conn_type {
    CONN_TYPE_TCP,
    CONN_TYPE_UDP,
    CONN_TYPE_UART,
    CONN_TYPE_UNKNOWN
}
alias CONN_TYPE_TCP = conn_type.CONN_TYPE_TCP;
alias CONN_TYPE_UDP = conn_type.CONN_TYPE_UDP;
alias CONN_TYPE_UART = conn_type.CONN_TYPE_UART;
alias CONN_TYPE_UNKNOWN = conn_type.CONN_TYPE_UNKNOWN;
alias conn_type_t = conn_type;

/* Sys connection */
struct sys_connection {
    /* Next connection */
    sys_connection* next;

    /* Type */
    conn_type_t type;

    /* Handle to interact with wasm app */
    uint handle;

    /* Underlying connection ID, may be socket fd */
    int fd;

    /* Module id that the connection belongs to */
    uint module_id;

    /* Argument, such as dest addr for udp */
    void* arg;
}alias sys_connection_t = sys_connection;

/* Epoll instance */
private int epollfd;

/* Connections list */
private sys_connection_t* g_connections = null;

/* Max handle */
private uint g_handle_max = 0;

/* Lock to protect g_connections and g_handle_max */
private korp_mutex g_lock;

/* Epoll events */
private epoll_event[MAX_EVENTS] epoll_events;

/* Buffer to receive data */
private char[IO_BUF_SIZE] io_buf = 0;

private uint _conn_open(wasm_module_inst_t module_inst, const(char)* name, attr_container_t* args);
private void _conn_close(uint handle);
private int _conn_send(uint handle, const(char)* data, int len);
private bool _conn_config(uint handle, attr_container_t* cfg);

/* clang-format off */
/*
 * Platform implementation of connection library
 */
connection_interface_t connection_impl = {
    _open: _conn_open,
    _close: _conn_close,
    _send: _conn_send,
    _config: _conn_config
};
/* clang-format on */

private void add_connection(sys_connection_t* conn) {
    os_mutex_lock(&g_lock);

    g_handle_max++;
    if (g_handle_max == -1)
        g_handle_max++;
    conn.handle = g_handle_max;

    if (g_connections) {
        conn.next = g_connections;
        g_connections = conn;
    }
    else {
        g_connections = conn;
    }

    os_mutex_unlock(&g_lock);
}

enum string FREE_CONNECTION(string conn) = `             \
    do {                                  \
        if (conn->arg)                    \
            wasm_runtime_free(conn->arg); \
        wasm_runtime_free(conn);          \
    } while (0)`;

private int get_app_conns_num(uint module_id) {
    sys_connection_t* conn = void;
    int num = 0;

    os_mutex_lock(&g_lock);

    conn = g_connections;
    while (conn) {
        if (conn.module_id == module_id)
            num++;
        conn = conn.next;
    }

    os_mutex_unlock(&g_lock);

    return num;
}

private sys_connection_t* find_connection(uint handle, bool remove_found) {
    sys_connection_t* conn = void, prev = null;

    os_mutex_lock(&g_lock);

    conn = g_connections;
    while (conn) {
        if (conn.handle == handle) {
            if (remove_found) {
                if (prev != null) {
                    prev.next = conn.next;
                }
                else {
                    g_connections = conn.next;
                }
            }
            os_mutex_unlock(&g_lock);
            return conn;
        }
        else {
            prev = conn;
            conn = conn.next;
        }
    }

    os_mutex_unlock(&g_lock);

    return null;
}

private void cleanup_connections(uint module_id) {
    sys_connection_t* conn = void, prev = null;

    os_mutex_lock(&g_lock);

    conn = g_connections;
    while (conn) {
        if (conn.module_id == module_id) {
            epoll_ctl(epollfd, EPOLL_CTL_DEL, conn.fd, null);
            close(conn.fd);

            if (prev != null) {
                prev.next = conn.next;
                FREE_CONNECTION(conn);
                conn = prev.next;
            }
            else {
                g_connections = conn.next;
                FREE_CONNECTION(conn);
                conn = g_connections;
            }
        }
        else {
            prev = conn;
            conn = conn.next;
        }
    }

    os_mutex_unlock(&g_lock);
}

private conn_type_t get_conn_type(const(char)* name) {
    if (strcmp(name, "TCP") == 0)
        return CONN_TYPE_TCP;
    if (strcmp(name, "UDP") == 0)
        return CONN_TYPE_UDP;
    if (strcmp(name, "UART") == 0)
        return CONN_TYPE_UART;

    return CONN_TYPE_UNKNOWN;
}

/* --- connection lib function --- */
private uint _conn_open(wasm_module_inst_t module_inst, const(char)* name, attr_container_t* args) {
    int fd = void;
    sys_connection_t* conn = void;
    epoll_event ev = void;
    uint module_id = app_manager_get_module_id(Module_WASM_App, module_inst);
    bh_assert(module_id != ID_NONE);

    if (get_app_conns_num(module_id) >= MAX_CONNECTION_PER_APP)
        return -1;

    conn = cast(sys_connection_t*)wasm_runtime_malloc(typeof(*conn).sizeof);
    if (conn == null)
        return -1;

    memset(conn, 0, typeof(*conn).sizeof);
    conn.module_id = module_id;
    conn.type = get_conn_type(name);

    /* Generate a handle and add to list */
    add_connection(conn);

    if (conn.type == CONN_TYPE_TCP) {
        char* address = void;
        ushort port = void;

        /* Check and parse connection parameters */
        if (!attr_container_contain_key(args, "address")
            || !attr_container_contain_key(args, "port"))
            goto fail;

        address = attr_container_get_as_string(args, "address");
        port = attr_container_get_as_uint16(args, "port");

        /* Connect to TCP server */
        if (!address || (fd = tcp_open(address, port)) == -1)
            goto fail;
    }
    else if (conn.type == CONN_TYPE_UDP) {
        ushort port = void;

        /* Check and parse connection parameters */
        if (!attr_container_contain_key(args, "bind port"))
            goto fail;
        port = attr_container_get_as_uint16(args, "bind port");

        /* Bind port */
        if ((fd = udp_open(port)) == -1)
            goto fail;
    }
    else if (conn.type == CONN_TYPE_UART) {
        char* device = void;
        int baud = void;

        /* Check and parse connection parameters */
        if (!attr_container_contain_key(args, "device")
            || !attr_container_contain_key(args, "baudrate"))
            goto fail;
        device = attr_container_get_as_string(args, "device");
        baud = attr_container_get_as_int(args, "baudrate");

        /* Open device */
        if (!device || (fd = uart_open(device, baud)) == -1)
            goto fail;
    }
    else {
        goto fail;
    }

    conn.fd = fd;

    /* Set current connection as event data */
    ev.events = EPOLLIN;
    ev.data.ptr = conn;

    /* Monitor incoming data */
    if (epoll_ctl(epollfd, EPOLL_CTL_ADD, fd, &ev) == -1) {
        close(fd);
        goto fail;
    }

    return conn.handle;

fail:
    find_connection(conn.handle, true);
    wasm_runtime_free(conn);
    return -1;
}

/* --- connection lib function --- */
private void _conn_close(uint handle) {
    sys_connection_t* conn = find_connection(handle, true);

    if (conn != null) {
        epoll_ctl(epollfd, EPOLL_CTL_DEL, conn.fd, null);
        close(conn.fd);
        FREE_CONNECTION(conn);
    }
}

/* --- connection lib function --- */
private int _conn_send(uint handle, const(char)* data, int len) {
    sys_connection_t* conn = find_connection(handle, false);

    if (conn == null)
        return -1;

    if (conn.type == CONN_TYPE_TCP)
        return tcp_send(conn.fd, data, len);

    if (conn.type == CONN_TYPE_UDP) {
        sockaddr* addr = cast(sockaddr*)conn.arg;
        return udp_send(conn.fd, addr, data, len);
    }

    if (conn.type == CONN_TYPE_UART)
        return uart_send(conn.fd, data, len);

    return -1;
}

/* --- connection lib function --- */
private bool _conn_config(uint handle, attr_container_t* cfg) {
    sys_connection_t* conn = find_connection(handle, false);

    if (conn == null)
        return false;

    if (conn.type == CONN_TYPE_UDP) {
        char* address = void;
        ushort port = void;
        sockaddr_in* addr = void;

        /* Parse remote address/port */
        if (!attr_container_contain_key(cfg, "address")
            || !attr_container_contain_key(cfg, "port"))
            return false;
        if (((address = attr_container_get_as_string(cfg, "address")) == 0))
            return false;
        port = attr_container_get_as_uint16(cfg, "port");

        if (conn.arg == null) {
            addr = cast(sockaddr_in*)wasm_runtime_malloc(typeof(*addr).sizeof);
            if (addr == null)
                return false;

            memset(addr, 0, typeof(*addr).sizeof);
            addr.sin_family = AF_INET;
            addr.sin_addr.s_addr = inet_addr(address);
            addr.sin_port = htons(port);

            /* Set remote address as connection arg */
            conn.arg = addr;
        }
        else {
            addr = cast(sockaddr_in*)conn.arg;
            addr.sin_addr.s_addr = inet_addr(address);
            addr.sin_port = htons(port);
        }

        return true;
    }

    return false;
}

/* --- connection manager reference implementation ---*/

struct connection_event {
    uint handle;
    char* data;
    uint len;
}alias connection_event_t = connection_event;

private void connection_event_cleaner(connection_event_t* conn_event) {
    if (conn_event.data != null)
        wasm_runtime_free(conn_event.data);
    wasm_runtime_free(conn_event);
}

private void post_msg_to_module(sys_connection_t* conn, char* data, uint len) {
    module_data* module_ = module_data_list_lookup_id(conn.module_id);
    char* data_copy = null;
    connection_event_t* conn_data_event = void;
    bh_message_t msg = void;

    if (module_ == null)
        return;

    conn_data_event =
        cast(connection_event_t*)wasm_runtime_malloc(typeof(*conn_data_event).sizeof);
    if (conn_data_event == null)
        return;

    if (len > 0) {
        data_copy = cast(char*)wasm_runtime_malloc(len);
        if (data_copy == null) {
            wasm_runtime_free(conn_data_event);
            return;
        }
        bh_memcpy_s(data_copy, len, data, len);
    }

    memset(conn_data_event, 0, typeof(*conn_data_event).sizeof);
    conn_data_event.handle = conn.handle;
    conn_data_event.data = data_copy;
    conn_data_event.len = len;

    msg = bh_new_msg(CONNECTION_EVENT_WASM, conn_data_event,
                     typeof(*conn_data_event).sizeof, &connection_event_cleaner);
    if (!msg) {
        connection_event_cleaner(conn_data_event);
        return;
    }

    bh_post_msg2(module_.queue, msg);
}

private void* polling_thread_routine(void* arg) {
    while (polling_thread_run) {
        int i = void, n = void;

        n = epoll_wait(epollfd, epoll_events.ptr, MAX_EVENTS, -1);

        if (n == -1 && errno != EINTR)
            continue;

        for (i = 0; i < n; i++) {
            sys_connection_t* conn = cast(sys_connection_t*)epoll_events[i].data.ptr;

            if (conn.type == CONN_TYPE_TCP) {
                int count = tcp_recv(conn.fd, io_buf.ptr, IO_BUF_SIZE);
                if (count <= 0) {
                    /* Connection is closed by peer */
                    post_msg_to_module(conn, null, 0);
                    _conn_close(conn.handle);
                }
                else {
                    /* Data is received */
                    post_msg_to_module(conn, io_buf.ptr, count);
                }
            }
            else if (conn.type == CONN_TYPE_UDP) {
                int count = udp_recv(conn.fd, io_buf.ptr, IO_BUF_SIZE);
                if (count > 0)
                    post_msg_to_module(conn, io_buf.ptr, count);
            }
            else if (conn.type == CONN_TYPE_UART) {
                int count = uart_recv(conn.fd, io_buf.ptr, IO_BUF_SIZE);
                if (count > 0)
                    post_msg_to_module(conn, io_buf.ptr, count);
            }
        }
    }

    return null;
}

void app_mgr_connection_event_callback(module_data* m_data, bh_message_t msg) {
    uint[3] argv = void;
    wasm_function_inst_t func_on_conn_data = void;
    bh_assert(CONNECTION_EVENT_WASM == bh_message_type(msg));
    wasm_data* wasm_app_data = cast(wasm_data*)m_data.internal_data;
    wasm_module_inst_t inst = wasm_app_data.wasm_module_inst;
    connection_event_t* conn_event = cast(connection_event_t*)bh_message_payload(msg);
    int data_offset = void;

    if (conn_event == null)
        return;

    func_on_conn_data = wasm_runtime_lookup_function(
        inst, "_on_connection_data", "(i32i32i32)");
    if (!func_on_conn_data)
        func_on_conn_data = wasm_runtime_lookup_function(
            inst, "on_connection_data", "(i32i32i32)");
    if (!func_on_conn_data) {
        printf("Cannot find function on_connection_data\n");
        return;
    }

    /* 0 len means connection closed */
    if (conn_event.len == 0) {
        argv[0] = conn_event.handle;
        argv[1] = 0;
        argv[2] = 0;
        if (!wasm_runtime_call_wasm(wasm_app_data.exec_env, func_on_conn_data,
                                    3, argv.ptr)) {
            const(char)* exception = wasm_runtime_get_exception(inst);
            bh_assert(exception);
            printf(":Got exception running wasm code: %s\n", exception);
            wasm_runtime_clear_exception(inst);
            return;
        }
    }
    else {
        data_offset = wasm_runtime_module_dup_data(inst, conn_event.data,
                                                   conn_event.len);
        if (data_offset == 0) {
            const(char)* exception = wasm_runtime_get_exception(inst);
            if (exception) {
                printf("Got exception running wasm code: %s\n", exception);
                wasm_runtime_clear_exception(inst);
            }
            return;
        }

        argv[0] = conn_event.handle;
        argv[1] = cast(uint)data_offset;
        argv[2] = conn_event.len;
        if (!wasm_runtime_call_wasm(wasm_app_data.exec_env, func_on_conn_data,
                                    3, argv.ptr)) {
            const(char)* exception = wasm_runtime_get_exception(inst);
            bh_assert(exception);
            printf(":Got exception running wasm code: %s\n", exception);
            wasm_runtime_clear_exception(inst);
            wasm_runtime_module_free(inst, data_offset);
            return;
        }
        wasm_runtime_module_free(inst, data_offset);
    }
}

bool init_connection_framework() {
    korp_tid tid = void;

    epollfd = epoll_create(MAX_EVENTS);
    if (epollfd == -1)
        return false;

    if (os_mutex_init(&g_lock) != 0) {
        close(epollfd);
        return false;
    }

    if (!wasm_register_cleanup_callback(&cleanup_connections)) {
        goto fail;
    }

    if (!wasm_register_msg_callback(CONNECTION_EVENT_WASM,
                                    &app_mgr_connection_event_callback)) {
        goto fail;
    }

    if (os_thread_create(&tid, &polling_thread_routine, null,
                         BH_APPLET_PRESERVED_STACK_SIZE)
        != 0) {
        goto fail;
    }

    return true;

fail:
    os_mutex_destroy(&g_lock);
    close(epollfd);
    return false;
}

void exit_connection_framework() {
    polling_thread_run = false;
}
