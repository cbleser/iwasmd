module win_socket;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

/* link with Ws2_32.lib */
#pragma comment(lib, "ws2_32.lib")

private bool is_winsock_inited = false;

int init_winsock() {
    WSADATA wsaData = void;

    if (!is_winsock_inited) {
        if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
            os_printf("winsock init failed");
            return BHT_ERROR;
        }

        is_winsock_inited = true;
    }

    return BHT_OK;
}

void deinit_winsock() {
    if (is_winsock_inited) {
        WSACleanup();
    }
}

int os_socket_create(bh_socket_t* sock, bool is_ipv4, bool is_tcp) {
    int af = void;

    if (!sock) {
        return BHT_ERROR;
    }

    if (is_ipv4) {
        af = AF_INET;
    }
    else {
        errno = ENOSYS;
        return BHT_ERROR;
    }

    if (is_tcp) {
        *sock = socket(af, SOCK_STREAM, IPPROTO_TCP);
    }
    else {
        *sock = socket(af, SOCK_DGRAM, 0);
    }

    return (*sock == -1) ? BHT_ERROR : BHT_OK;
}

int os_socket_bind(bh_socket_t socket, const(char)* host, int* port) {
    sockaddr_in addr = void;
    int socklen = void, ret = void;

    assert(host);
    assert(port);

    addr.sin_addr.s_addr = inet_addr(host);
    addr.sin_port = htons(*port);
    addr.sin_family = AF_INET;

    ret = bind(socket, cast(sockaddr*)&addr, addr.sizeof);
    if (ret < 0) {
        goto fail;
    }

    socklen = addr.sizeof;
    if (getsockname(socket, cast(void*)&addr, &socklen) == -1) {
        os_printf("getsockname failed with error %d\n", WSAGetLastError());
        goto fail;
    }

    *port = ntohs(addr.sin_port);

    return BHT_OK;

fail:
    return BHT_ERROR;
}

int os_socket_settimeout(bh_socket_t socket, ulong timeout_us) {
    DWORD tv = (DWORD)(timeout_us / 1000UL);

    if (setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, cast(const(char)*)&tv,
                   tv.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_listen(bh_socket_t socket, int max_client) {
    if (listen(socket, max_client) != 0) {
        os_printf("socket listen failed with error %d\n", WSAGetLastError());
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_accept(bh_socket_t server_sock, bh_socket_t* sock, void* addr, uint* addrlen) {
    sockaddr addr_tmp = void;
    uint len = sockaddr.sizeof;

    *sock = accept(server_sock, cast(sockaddr*)&addr_tmp, &len);

    if (*sock < 0) {
        os_printf("socket accept failed with error %d\n", WSAGetLastError());
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_recv(bh_socket_t socket, void* buf, uint len) {
    return recv(socket, buf, len, 0);
}

int os_socket_recv_from(bh_socket_t socket, void* buf, uint len, int flags, bh_sockaddr_t* src_addr) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_send(bh_socket_t socket, const(void)* buf, uint len) {
    return send(socket, buf, len, 0);
}

int os_socket_send_to(bh_socket_t socket, const(void)* buf, uint len, int flags, const(bh_sockaddr_t)* dest_addr) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_close(bh_socket_t socket) {
    closesocket(socket);
    return BHT_OK;
}

int os_socket_shutdown(bh_socket_t socket) {
    shutdown(socket, SD_BOTH);
    return BHT_OK;
}

int os_socket_inet_network(bool is_ipv4, const(char)* cp, bh_ip_addr_buffer_t* out_) {
    if (!cp)
        return BHT_ERROR;

    if (is_ipv4) {
        if (inet_pton(AF_INET, cp, &out_.ipv4) != 1) {
            return BHT_ERROR;
        }
        /* Note: ntohl(INADDR_NONE) == INADDR_NONE */
        out_.ipv4 = ntohl(out_.ipv4);
    }
    else {
        if (inet_pton(AF_INET6, cp, out_.ipv6) != 1) {
            return BHT_ERROR;
        }
        for (int i = 0; i < 8; i++) {
            out_.ipv6[i] = ntohs(out_.ipv6[i]);
        }
    }

    return BHT_OK;
}

int os_socket_addr_resolve(const(char)* host, const(char)* service, ubyte* hint_is_tcp, ubyte* hint_is_ipv4, bh_addr_info_t* addr_info, size_t addr_info_size, size_t* max_info_size) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_addr_local(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_send_timeout(bh_socket_t socket, ulong timeout_us) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_send_timeout(bh_socket_t socket, ulong* timeout_us) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_recv_timeout(bh_socket_t socket, ulong timeout_us) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_recv_timeout(bh_socket_t socket, ulong* timeout_us) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_addr_remote(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_send_buf_size(bh_socket_t socket, size_t bufsiz) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_send_buf_size(bh_socket_t socket, size_t* bufsiz) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_recv_buf_size(bh_socket_t socket, size_t bufsiz) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_recv_buf_size(bh_socket_t socket, size_t* bufsiz) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_keep_alive(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_keep_alive(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_reuse_addr(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_reuse_addr(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_reuse_port(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_reuse_port(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_linger(bh_socket_t socket, bool is_enabled, int linger_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_linger(bh_socket_t socket, bool* is_enabled, int* linger_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_tcp_no_delay(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_tcp_no_delay(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_tcp_quick_ack(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_tcp_quick_ack(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_tcp_keep_idle(bh_socket_t socket, uint time_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_tcp_keep_idle(bh_socket_t socket, uint* time_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_tcp_keep_intvl(bh_socket_t socket, uint time_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_tcp_keep_intvl(bh_socket_t socket, uint* time_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_tcp_fastopen_connect(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_tcp_fastopen_connect(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool* is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_ip_add_membership(bh_socket_t socket, bh_ip_addr_buffer_t* imr_multiaddr, uint imr_interface, bool is_ipv6) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_ip_drop_membership(bh_socket_t socket, bh_ip_addr_buffer_t* imr_multiaddr, uint imr_interface, bool is_ipv6) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_ip_ttl(bh_socket_t socket, ubyte ttl_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_ip_ttl(bh_socket_t socket, ubyte* ttl_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_ip_multicast_ttl(bh_socket_t socket, ubyte ttl_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_ip_multicast_ttl(bh_socket_t socket, ubyte* ttl_s) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_ipv6_only(bh_socket_t socket, bool option) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_ipv6_only(bh_socket_t socket, bool* option) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_set_broadcast(bh_socket_t socket, bool is_enabled) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_get_broadcast(bh_socket_t socket, bool* is_enabled) {
    errno = ENOSYS;
    return BHT_ERROR;
}
