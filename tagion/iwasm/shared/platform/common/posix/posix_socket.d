module posix_socket;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

public import arpa/inet;
public import core.sys.posix.netdb;
public import netinet/tcp;
public import netinet/in;

private bool textual_addr_to_sockaddr(const(char)* textual, int port, sockaddr* out_, socklen_t* out_len) {
    sockaddr_in* v4 = void;
version (IPPROTO_IPV6) {
    sockaddr_in6* v6 = void;
}

    assert(textual);

    v4 = cast(sockaddr_in*)out_;
    if (inet_pton(AF_INET, textual, &v4.sin_addr.s_addr) == 1) {
        v4.sin_family = AF_INET;
        v4.sin_port = htons(port);
        *out_len = sockaddr_in.sizeof;
        return true;
    }

version (IPPROTO_IPV6) {
    v6 = cast(sockaddr_in6*)out_;
    if (inet_pton(AF_INET6, textual, &v6.sin6_addr.s6_addr) == 1) {
        v6.sin6_family = AF_INET6;
        v6.sin6_port = htons(port);
        *out_len = sockaddr_in6.sizeof;
        return true;
    }
}

    return false;
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
version (IPPROTO_IPV6) {
        case AF_INET6:
        {
            sockaddr_in6* addr = cast(sockaddr_in6*)sockaddr;
            size_t i = void;

            assert(socklen >= sockaddr_in6.sizeof);

            bh_sockaddr.port = ntohs(addr.sin6_port);

            for (i = 0; i < sizeof(bh_sockaddr.addr_bufer.ipv6)
                                / typeof(bh_sockaddr.addr_bufer.ipv6[0]).sizeof;
                 i++) {
                ushort part_addr = addr.sin6_addr.s6_addr[i * 2]
                                   | (addr.sin6_addr.s6_addr[i * 2 + 1] << 8);
                bh_sockaddr.addr_bufer.ipv6[i] = ntohs(part_addr);
            }

            bh_sockaddr.is_ipv4 = false;
            return BHT_OK;
        }
}
        default:
            errno = EAFNOSUPPORT;
            return BHT_ERROR;
    }
}

private void bh_sockaddr_to_sockaddr(const(bh_sockaddr_t)* bh_sockaddr, sockaddr_storage* sockaddr, socklen_t* socklen) {
    if (bh_sockaddr.is_ipv4) {
        sockaddr_in* addr = cast(sockaddr_in*)sockaddr;
        addr.sin_port = htons(bh_sockaddr.port);
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(bh_sockaddr.addr_bufer.ipv4);
        *socklen = typeof(*addr).sizeof;
    }
version (IPPROTO_IPV6) {
    else {
        sockaddr_in6* addr = cast(sockaddr_in6*)sockaddr;
        size_t i = void;
        addr.sin6_port = htons(bh_sockaddr.port);
        addr.sin6_family = AF_INET6;

        for (i = 0; i < sizeof(bh_sockaddr.addr_bufer.ipv6)
                            / typeof(bh_sockaddr.addr_bufer.ipv6[0]).sizeof;
             i++) {
            ushort part_addr = htons(bh_sockaddr.addr_bufer.ipv6[i]);
            addr.sin6_addr.s6_addr[i * 2] = 0xff & part_addr;
            addr.sin6_addr.s6_addr[i * 2 + 1] = (0xff00 & part_addr) >> 8;
        }

        *socklen = typeof(*addr).sizeof;
    }
}
}

int os_socket_create(bh_socket_t* sock, bool is_ipv4, bool is_tcp) {
    int af = is_ipv4 ? AF_INET : AF_INET6;

    if (!sock) {
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
    sockaddr_storage addr = { 0 };
    linger ling = void;
    socklen_t socklen = void;
    int ret = void;

    assert(host);
    assert(port);

    ling.l_onoff = 1;
    ling.l_linger = 0;

    if (!textual_addr_to_sockaddr(host, *port, cast(sockaddr*)&addr,
                                  &socklen)) {
        goto fail;
    }

    if (addr.ss_family == AF_INET) {
        *port = ntohs((cast(sockaddr_in*)&addr).sin_port);
    }
    else {
version (IPPROTO_IPV6) {
        *port = ntohs((cast(sockaddr_in6*)&addr).sin6_port);
} else {
        goto fail;
}
    }

    ret = fcntl(socket, F_SETFD, FD_CLOEXEC);
    if (ret < 0) {
        goto fail;
    }

    ret = setsockopt(socket, SOL_SOCKET, SO_LINGER, &ling, ling.sizeof);
    if (ret < 0) {
        goto fail;
    }

    ret = bind(socket, cast(sockaddr*)&addr, socklen);
    if (ret < 0) {
        goto fail;
    }

    socklen = addr.sizeof;
    if (getsockname(socket, cast(void*)&addr, &socklen) == -1) {
        goto fail;
    }

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
    *sock = accept(server_sock, addr, addrlen);

    if (*sock < 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_connect(bh_socket_t socket, const(char)* addr, int port) {
    sockaddr_storage addr_in = { 0 };
    socklen_t addr_len = void;
    int ret = 0;

    if (!textual_addr_to_sockaddr(addr, port, cast(sockaddr*)&addr_in,
                                  &addr_len)) {
        return BHT_ERROR;
    }

    ret = connect(socket, cast(sockaddr*)&addr_in, addr_len);
    if (ret == -1) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_recv(bh_socket_t socket, void* buf, uint len) {
    return recv(socket, buf, len, 0);
}

int os_socket_recv_from(bh_socket_t socket, void* buf, uint len, int flags, bh_sockaddr_t* src_addr) {
    sockaddr_storage sock_addr = { 0 };
    socklen_t socklen = sock_addr.sizeof;
    int ret = void;

    ret = recvfrom(socket, buf, len, flags, cast(sockaddr*)&sock_addr,
                   &socklen);

    if (ret < 0) {
        return ret;
    }

    if (src_addr && socklen > 0) {
        if (sockaddr_to_bh_sockaddr(cast(sockaddr*)&sock_addr, socklen,
                                    src_addr)
            == BHT_ERROR) {
            return -1;
        }
    }

    return ret;
}

int os_socket_send(bh_socket_t socket, const(void)* buf, uint len) {
    return send(socket, buf, len, 0);
}

int os_socket_send_to(bh_socket_t socket, const(void)* buf, uint len, int flags, const(bh_sockaddr_t)* dest_addr) {
    sockaddr_storage sock_addr = { 0 };
    socklen_t socklen = 0;

    bh_sockaddr_to_sockaddr(dest_addr, &sock_addr, &socklen);

    return sendto(socket, buf, len, flags, cast(const(sockaddr)*)&sock_addr,
                  socklen);
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
version (IPPROTO_IPV6) {
        if (inet_pton(AF_INET6, cp, out_.ipv6) != 1) {
            return BHT_ERROR;
        }
        for (int i = 0; i < 8; i++) {
            out_.ipv6[i] = ntohs(out_.ipv6[i]);
        }
} else {
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
}
    }

    return BHT_OK;
}

private int getaddrinfo_error_to_errno(int error) {
    switch (error) {
        case EAI_AGAIN:
            return EAGAIN;
        case EAI_FAIL:
            return EFAULT;
        case EAI_MEMORY:
            return ENOMEM;
        case EAI_SYSTEM:
            return errno;
        default:
            return EINVAL;
    }
}

private int is_addrinfo_supported(addrinfo* info) {
    return
        // Allow only IPv4 and IPv6
        (info.ai_family == AF_INET || info.ai_family == AF_INET6)
        // Allow only UDP and TCP
        && (info.ai_socktype == SOCK_DGRAM || info.ai_socktype == SOCK_STREAM)
        && (info.ai_protocol == IPPROTO_TCP
            || info.ai_protocol == IPPROTO_UDP);
}

int os_socket_addr_resolve(const(char)* host, const(char)* service, ubyte* hint_is_tcp, ubyte* hint_is_ipv4, bh_addr_info_t* addr_info, size_t addr_info_size, size_t* max_info_size) {
    addrinfo hints = { 0 }; addrinfo* res = void, result = void;
    int hints_enabled = hint_is_tcp || hint_is_ipv4;
    int ret = void;
    size_t pos = 0;

    if (hints_enabled) {
        if (hint_is_ipv4) {
            hints.ai_family = *hint_is_ipv4 ? AF_INET : AF_INET6;
        }
        if (hint_is_tcp) {
            hints.ai_socktype = *hint_is_tcp ? SOCK_STREAM : SOCK_DGRAM;
        }
    }

    ret = getaddrinfo(host, strlen(service) == 0 ? null : service,
                      hints_enabled ? &hints : null, &result);
    if (ret != BHT_OK) {
        errno = getaddrinfo_error_to_errno(ret);
        return BHT_ERROR;
    }

    res = result;
    while (res) {
        if (addr_info_size > pos) {
            if (!is_addrinfo_supported(res)) {
                res = res.ai_next;
                continue;
            }

            ret = sockaddr_to_bh_sockaddr(res.ai_addr,
                                          sockaddr_in.sizeof,
                                          &addr_info[pos].sockaddr);

            if (ret == BHT_ERROR) {
                freeaddrinfo(result);
                return BHT_ERROR;
            }

            addr_info[pos].is_tcp = res.ai_socktype == SOCK_STREAM;
        }

        pos++;
        res = res.ai_next;
    }

    *max_info_size = pos;
    freeaddrinfo(result);

    return BHT_OK;
}

private int os_socket_setbooloption(bh_socket_t socket, int level, int optname, bool is_enabled) {
    int option = cast(int)is_enabled;
    if (setsockopt(socket, level, optname, &option, option.sizeof) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

private int os_socket_getbooloption(bh_socket_t socket, int level, int optname, bool* is_enabled) {
    assert(is_enabled);

    int optval = void;
    socklen_t optval_size = optval.sizeof;
    if (getsockopt(socket, level, optname, &optval, &optval_size) != 0) {
        return BHT_ERROR;
    }
    *is_enabled = cast(bool)optval;
    return BHT_OK;
}

int os_socket_set_send_buf_size(bh_socket_t socket, size_t bufsiz) {
    int buf_size_int = cast(int)bufsiz;
    if (setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &buf_size_int,
                   buf_size_int.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_get_send_buf_size(bh_socket_t socket, size_t* bufsiz) {
    assert(bufsiz);

    int buf_size_int = void;
    socklen_t bufsiz_len = buf_size_int.sizeof;
    if (getsockopt(socket, SOL_SOCKET, SO_SNDBUF, &buf_size_int, &bufsiz_len)
        != 0) {
        return BHT_ERROR;
    }
    *bufsiz = cast(size_t)buf_size_int;

    return BHT_OK;
}

int os_socket_set_recv_buf_size(bh_socket_t socket, size_t bufsiz) {
    int buf_size_int = cast(int)bufsiz;
    if (setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &buf_size_int,
                   buf_size_int.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_get_recv_buf_size(bh_socket_t socket, size_t* bufsiz) {
    assert(bufsiz);

    int buf_size_int = void;
    socklen_t bufsiz_len = buf_size_int.sizeof;
    if (getsockopt(socket, SOL_SOCKET, SO_RCVBUF, &buf_size_int, &bufsiz_len)
        != 0) {
        return BHT_ERROR;
    }
    *bufsiz = cast(size_t)buf_size_int;

    return BHT_OK;
}

int os_socket_set_keep_alive(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_KEEPALIVE,
                                   is_enabled);
}

int os_socket_get_keep_alive(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_KEEPALIVE,
                                   is_enabled);
}

int os_socket_set_reuse_addr(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_REUSEADDR,
                                   is_enabled);
}

int os_socket_get_reuse_addr(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_REUSEADDR,
                                   is_enabled);
}

int os_socket_set_reuse_port(bh_socket_t socket, bool is_enabled) {
version (SO_REUSEPORT) { /* NuttX doesn't have SO_REUSEPORT */
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_REUSEPORT,
                                   is_enabled);
} else {
    errno = ENOTSUP;
    return BHT_ERROR;
} /* defined(SO_REUSEPORT) */
}

int os_socket_get_reuse_port(bh_socket_t socket, bool* is_enabled) {
version (SO_REUSEPORT) { /* NuttX doesn't have SO_REUSEPORT */
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_REUSEPORT,
                                   is_enabled);
} else {
    errno = ENOTSUP;
    return BHT_ERROR;
} /* defined(SO_REUSEPORT) */
}

int os_socket_set_linger(bh_socket_t socket, bool is_enabled, int linger_s) {
    linger linger_opts = { l_onoff: cast(int)is_enabled,
                                  l_linger: linger_s };
    if (setsockopt(socket, SOL_SOCKET, SO_LINGER, &linger_opts,
                   linger_opts.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_get_linger(bh_socket_t socket, bool* is_enabled, int* linger_s) {
    assert(is_enabled);
    assert(linger_s);

    linger linger_opts = void;
    socklen_t linger_opts_len = linger_opts.sizeof;
    if (getsockopt(socket, SOL_SOCKET, SO_LINGER, &linger_opts,
                   &linger_opts_len)
        != 0) {
        return BHT_ERROR;
    }
    *linger_s = linger_opts.l_linger;
    *is_enabled = cast(bool)linger_opts.l_onoff;
    return BHT_OK;
}

int os_socket_set_tcp_no_delay(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(socket, IPPROTO_TCP, TCP_NODELAY,
                                   is_enabled);
}

int os_socket_get_tcp_no_delay(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(socket, IPPROTO_TCP, TCP_NODELAY,
                                   is_enabled);
}

int os_socket_set_tcp_quick_ack(bh_socket_t socket, bool is_enabled) {
version (TCP_QUICKACK) {
    return os_socket_setbooloption(socket, IPPROTO_TCP, TCP_QUICKACK,
                                   is_enabled);
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_get_tcp_quick_ack(bh_socket_t socket, bool* is_enabled) {
version (TCP_QUICKACK) {
    return os_socket_getbooloption(socket, IPPROTO_TCP, TCP_QUICKACK,
                                   is_enabled);
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_set_tcp_keep_idle(bh_socket_t socket, uint time_s) {
    int time_s_int = cast(int)time_s;
version (TCP_KEEPIDLE) {
    if (setsockopt(socket, IPPROTO_TCP, TCP_KEEPIDLE, &time_s_int,
                   time_s_int.sizeof)
        != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
} else version (TCP_KEEPALIVE) {
    if (setsockopt(socket, IPPROTO_TCP, TCP_KEEPALIVE, &time_s_int,
                   time_s_int.sizeof)
        != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_get_tcp_keep_idle(bh_socket_t socket, uint* time_s) {
    assert(time_s);
    int time_s_int = void;
    socklen_t time_s_len = time_s_int.sizeof;
version (TCP_KEEPIDLE) {
    if (getsockopt(socket, IPPROTO_TCP, TCP_KEEPIDLE, &time_s_int, &time_s_len)
        != 0) {
        return BHT_ERROR;
    }
    *time_s = cast(uint)time_s_int;
    return BHT_OK;
} else version (TCP_KEEPALIVE) {
    if (getsockopt(socket, IPPROTO_TCP, TCP_KEEPALIVE, &time_s_int, &time_s_len)
        != 0) {
        return BHT_ERROR;
    }
    *time_s = cast(uint)time_s_int;
    return BHT_OK;
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_set_tcp_keep_intvl(bh_socket_t socket, uint time_s) {
    int time_s_int = cast(int)time_s;
version (TCP_KEEPINTVL) {
    if (setsockopt(socket, IPPROTO_TCP, TCP_KEEPINTVL, &time_s_int,
                   time_s_int.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_get_tcp_keep_intvl(bh_socket_t socket, uint* time_s) {
version (TCP_KEEPINTVL) {
    assert(time_s);
    int time_s_int = void;
    socklen_t time_s_len = time_s_int.sizeof;
    if (getsockopt(socket, IPPROTO_TCP, TCP_KEEPINTVL, &time_s_int, &time_s_len)
        != 0) {
        return BHT_ERROR;
    }
    *time_s = cast(uint)time_s_int;
    return BHT_OK;
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_set_tcp_fastopen_connect(bh_socket_t socket, bool is_enabled) {
version (TCP_FASTOPEN_CONNECT) {
    return os_socket_setbooloption(socket, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
                                   is_enabled);
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_get_tcp_fastopen_connect(bh_socket_t socket, bool* is_enabled) {
version (TCP_FASTOPEN_CONNECT) {
    return os_socket_getbooloption(socket, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
                                   is_enabled);
} else {
    errno = ENOSYS;

    return BHT_ERROR;
}
}

int os_socket_set_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool is_enabled) {
    if (ipv6) {
version (IPPROTO_IPV6) {
        return os_socket_setbooloption(socket, IPPROTO_IPV6,
                                       IPV6_MULTICAST_LOOP, is_enabled);
} else {
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
}
    }
    else {
        return os_socket_setbooloption(socket, IPPROTO_IP, IP_MULTICAST_LOOP,
                                       is_enabled);
    }
}

int os_socket_get_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool* is_enabled) {
    if (ipv6) {
version (IPPROTO_IPV6) {
        return os_socket_getbooloption(socket, IPPROTO_IPV6,
                                       IPV6_MULTICAST_LOOP, is_enabled);
} else {
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
}
    }
    else {
        return os_socket_getbooloption(socket, IPPROTO_IP, IP_MULTICAST_LOOP,
                                       is_enabled);
    }
}

int os_socket_set_ip_add_membership(bh_socket_t socket, bh_ip_addr_buffer_t* imr_multiaddr, uint imr_interface, bool is_ipv6) {
    assert(imr_multiaddr);
    if (is_ipv6) {
version (IPPROTO_IPV6) {
        ipv6_mreq mreq = void;
        for (int i = 0; i < 8; i++) {
            (cast(ushort*)mreq.ipv6mr_multiaddr.s6_addr)[i] =
                imr_multiaddr.ipv6[i];
        }
        mreq.ipv6mr_interface = imr_interface;
        if (setsockopt(socket, IPPROTO_IPV6, IPV6_JOIN_GROUP, &mreq,
                       mreq.sizeof)
            != 0) {
            return BHT_ERROR;
        }
} else {
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
}
    }
    else {
        ip_mreq mreq = void;
        mreq.imr_multiaddr.s_addr = imr_multiaddr.ipv4;
        mreq.imr_interface.s_addr = imr_interface;
        if (setsockopt(socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq,
                       mreq.sizeof)
            != 0) {
            return BHT_ERROR;
        }
    }

    return BHT_OK;
}

int os_socket_set_ip_drop_membership(bh_socket_t socket, bh_ip_addr_buffer_t* imr_multiaddr, uint imr_interface, bool is_ipv6) {
    assert(imr_multiaddr);
    if (is_ipv6) {
version (IPPROTO_IPV6) {
        ipv6_mreq mreq = void;
        for (int i = 0; i < 8; i++) {
            (cast(ushort*)mreq.ipv6mr_multiaddr.s6_addr)[i] =
                imr_multiaddr.ipv6[i];
        }
        mreq.ipv6mr_interface = imr_interface;
        if (setsockopt(socket, IPPROTO_IPV6, IPV6_LEAVE_GROUP, &mreq,
                       mreq.sizeof)
            != 0) {
            return BHT_ERROR;
        }
} else {
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
}
    }
    else {
        ip_mreq mreq = void;
        mreq.imr_multiaddr.s_addr = imr_multiaddr.ipv4;
        mreq.imr_interface.s_addr = imr_interface;
        if (setsockopt(socket, IPPROTO_IP, IP_DROP_MEMBERSHIP, &mreq,
                       mreq.sizeof)
            != 0) {
            return BHT_ERROR;
        }
    }

    return BHT_OK;
}

int os_socket_set_ip_ttl(bh_socket_t socket, ubyte ttl_s) {
    if (setsockopt(socket, IPPROTO_IP, IP_TTL, &ttl_s, ttl_s.sizeof) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_get_ip_ttl(bh_socket_t socket, ubyte* ttl_s) {
    socklen_t opt_len = ttl_s.sizeof;
    if (getsockopt(socket, IPPROTO_IP, IP_TTL, ttl_s, &opt_len) != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_set_ip_multicast_ttl(bh_socket_t socket, ubyte ttl_s) {
    if (setsockopt(socket, IPPROTO_IP, IP_MULTICAST_TTL, &ttl_s, ttl_s.sizeof)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_get_ip_multicast_ttl(bh_socket_t socket, ubyte* ttl_s) {
    socklen_t opt_len = ttl_s.sizeof;
    if (getsockopt(socket, IPPROTO_IP, IP_MULTICAST_TTL, ttl_s, &opt_len)
        != 0) {
        return BHT_ERROR;
    }

    return BHT_OK;
}

int os_socket_set_ipv6_only(bh_socket_t socket, bool is_enabled) {
version (IPPROTO_IPV6) {
    return os_socket_setbooloption(socket, IPPROTO_IPV6, IPV6_V6ONLY,
                                   is_enabled);
} else {
    errno = EAFNOSUPPORT;
    return BHT_ERROR;
}
}

int os_socket_get_ipv6_only(bh_socket_t socket, bool* is_enabled) {
version (IPPROTO_IPV6) {
    return os_socket_getbooloption(socket, IPPROTO_IPV6, IPV6_V6ONLY,
                                   is_enabled);
} else {
    errno = EAFNOSUPPORT;
    return BHT_ERROR;
}
}

int os_socket_set_broadcast(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(socket, SOL_SOCKET, SO_BROADCAST,
                                   is_enabled);
}

int os_socket_get_broadcast(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(socket, SOL_SOCKET, SO_BROADCAST,
                                   is_enabled);
}

int os_socket_set_send_timeout(bh_socket_t socket, ulong timeout_us) {
    timeval tv = void;
    tv.tv_sec = timeout_us / 1000000UL;
    tv.tv_usec = timeout_us % 1000000UL;
    if (setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &tv, tv.sizeof) != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
}

int os_socket_get_send_timeout(bh_socket_t socket, ulong* timeout_us) {
    timeval tv = void;
    socklen_t tv_len = tv.sizeof;
    if (getsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &tv, &tv_len) != 0) {
        return BHT_ERROR;
    }
    *timeout_us = (tv.tv_sec * 1000000UL) + tv.tv_usec;
    return BHT_OK;
}

int os_socket_set_recv_timeout(bh_socket_t socket, ulong timeout_us) {
    timeval tv = void;
    tv.tv_sec = timeout_us / 1000000UL;
    tv.tv_usec = timeout_us % 1000000UL;
    if (setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, tv.sizeof) != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
}

int os_socket_get_recv_timeout(bh_socket_t socket, ulong* timeout_us) {
    timeval tv = void;
    socklen_t tv_len = tv.sizeof;
    if (getsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, &tv_len) != 0) {
        return BHT_ERROR;
    }
    *timeout_us = (tv.tv_sec * 1000000UL) + tv.tv_usec;
    return BHT_OK;
}

int os_socket_addr_local(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    sockaddr_storage addr_storage = { 0 };
    socklen_t addr_len = addr_storage.sizeof;
    int ret = void;

    ret = getsockname(socket, cast(sockaddr*)&addr_storage, &addr_len);

    if (ret != BHT_OK) {
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr_storage, addr_len,
                                   sockaddr);
}

int os_socket_addr_remote(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    sockaddr_storage addr_storage = { 0 };
    socklen_t addr_len = addr_storage.sizeof;
    int ret = void;

    ret = getpeername(socket, cast(sockaddr*)&addr_storage, &addr_len);

    if (ret != BHT_OK) {
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr_storage, addr_len,
                                   sockaddr);
}
