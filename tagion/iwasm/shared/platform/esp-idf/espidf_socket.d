module espidf_socket;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

public import arpa/inet;

private void textual_addr_to_sockaddr(const(char)* textual, int port, sockaddr_in* out_) {
    assert(textual);

    out_.sin_family = AF_INET;
    out_.sin_port = htons(port);
    out_.sin_addr.s_addr = inet_addr(textual);
}

private int sockaddr_to_bh_sockaddr(const(sockaddr)* sockaddr, socklen_t socklen, bh_sockaddr_t* bh_sockaddr) {
    switch (sockaddr.sa_family) {
        case AF_INET:
        {
            sockaddr_in* addr = cast(sockaddr_in*)sockaddr;

            assert(socklen >= sockaddr_in.sizeof);

            bh_sockaddr.port = ntohs(addr.sin_port);
            bh_sockaddr.addr_bufer.ipv4 = ntohl(addr.sin_addr.s_addr);
            bh_sockaddr.is_ipv4 = true;
            return BHT_OK;
        }
        default:
            errno = EAFNOSUPPORT;
            return BHT_ERROR;
    }
}

int os_socket_create(bh_socket_t* sock, bool is_ipv4, bool is_tcp) {
    if (!sock) {
        return BHT_ERROR;
    }

    if (is_tcp) {
        *sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    }
    else {
        *sock = socket(AF_INET, SOCK_DGRAM, 0);
    }

    return (*sock == -1) ? BHT_ERROR : BHT_OK;
}

int os_socket_bind(bh_socket_t socket, const(char)* host, int* port) {
    sockaddr_in addr = void;
    socklen_t socklen = void;
    int ret = void;

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
        goto fail;
    }

    *port = ntohs(addr.sin_port);

    return BHT_OK;

fail:
    return BHT_ERROR;
}

int os_socket_settimeout(bh_socket_t socket, ulong timeout_us) {
    timeval tv = void;
    tv.tv_sec = timeout_us / 1000000UL;
    tv.tv_usec = timeout_us % 1000000UL;

    if (setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, cast(const(char)*)&tv,
                   tv.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_listen(bh_socket_t socket, int max_client) {
    if (listen(socket, max_client) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_accept(bh_socket_t server_sock, bh_socket_t* sock, void* addr, uint* addrlen) {
    sockaddr addr_tmp = void;
    uint len = sockaddr.sizeof;

    *sock = accept(server_sock, cast(sockaddr*)&addr_tmp, &len);

    if (*sock < 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_connect(bh_socket_t socket, const(char)* addr, int port) {
    sockaddr_in addr_in = { 0 };
    socklen_t addr_len = sockaddr_in.sizeof;
    int ret = 0;

    textual_addr_to_sockaddr(addr, port, &addr_in);

    ret = connect(socket, cast(sockaddr*)&addr_in, addr_len);
    if (ret == -1) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_recv(bh_socket_t socket, void* buf, uint len) {
    return recv(socket, buf, len, 0);
}

int os_socket_send(bh_socket_t socket, const(void)* buf, uint len) {
    return send(socket, buf, len, 0);
}

int os_socket_close(bh_socket_t socket) {
    close(socket);
    return BHT_OK;
}

int os_socket_shutdown(bh_socket_t socket) {
    shutdown(socket, O_RDWR);
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

int os_socket_addr_remote(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    sockaddr_in addr = void;
    socklen_t addr_len = addr.sizeof;

    if (getpeername(socket, &addr, &addr_len) == -1) {
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr, addr_len,
                                   sockaddr);
}

int os_socket_addr_local(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    sockaddr_in addr = void;
    socklen_t addr_len = addr.sizeof;

    if (getsockname(socket, &addr, &addr_len) == -1) {
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr, addr_len,
                                   sockaddr);
}
