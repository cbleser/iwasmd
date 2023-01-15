module wasi_socket_ext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.assert_;
public import core.stdc.errno;
public import netinet/in;
public import core.stdc.stdlib;
public import core.stdc.string;
public import core.sys.posix.sys.socket;
public import wasi/api;
public import wasi_socket_ext;

enum string HANDLE_ERROR(string error) = `              \
    if (error != __WASI_ERRNO_SUCCESS) { \
        errno = error;                   \
        return -1;                       \
    }`;

private void ipv4_addr_to_wasi_ip4_addr(uint addr_num, __wasi_addr_ip4_t* out_) {
    addr_num = ntohl(addr_num);
    out_.n0 = (addr_num & 0xFF000000) >> 24;
    out_.n1 = (addr_num & 0x00FF0000) >> 16;
    out_.n2 = (addr_num & 0x0000FF00) >> 8;
    out_.n3 = (addr_num & 0x000000FF);
}

/* addr_num and port are in network order */
private void ipv4_addr_to_wasi_addr(uint addr_num, ushort port, __wasi_addr_t* out_) {
    out_.kind = IPv4;
    out_.addr.ip4.port = ntohs(port);
    ipv4_addr_to_wasi_ip4_addr(addr_num, &(out_.addr.ip4.addr));
}

private void ipv6_addr_to_wasi_ipv6_addr(ushort* addr, __wasi_addr_ip6_t* out_) {
    out_.n0 = ntohs(addr[0]);
    out_.n1 = ntohs(addr[1]);
    out_.n2 = ntohs(addr[2]);
    out_.n3 = ntohs(addr[3]);
    out_.h0 = ntohs(addr[4]);
    out_.h1 = ntohs(addr[5]);
    out_.h2 = ntohs(addr[6]);
    out_.h3 = ntohs(addr[7]);
}

private void ipv6_addr_to_wasi_addr(ushort* addr, ushort port, __wasi_addr_t* out_) {
    out_.kind = IPv6;
    out_.addr.ip6.port = ntohs(port);
    ipv6_addr_to_wasi_ipv6_addr(addr, &(out_.addr.ip6.addr));
}

private __wasi_errno_t sockaddr_to_wasi_addr(const(sockaddr)* sock_addr, socklen_t addrlen, __wasi_addr_t* wasi_addr) {
    __wasi_errno_t ret = __WASI_ERRNO_SUCCESS;
    if (AF_INET == sock_addr.sa_family) {
        assert(sockaddr_in.sizeof <= addrlen);

        ipv4_addr_to_wasi_addr(
            (cast(sockaddr_in*)sock_addr).sin_addr.s_addr,
            (cast(sockaddr_in*)sock_addr).sin_port, wasi_addr);
    }
    else if (AF_INET6 == sock_addr.sa_family) {
        assert(sockaddr_in6.sizeof <= addrlen);
        ipv6_addr_to_wasi_addr(
            cast(ushort*)(cast(sockaddr_in6*)sock_addr).sin6_addr.s6_addr,
            (cast(sockaddr_in6*)sock_addr).sin6_port, wasi_addr);
    }
    else {
        ret = __WASI_ERRNO_AFNOSUPPORT;
    }

    return ret;
}

private __wasi_errno_t wasi_addr_to_sockaddr(const(__wasi_addr_t)* wasi_addr, sockaddr* sock_addr, socklen_t* addrlen) {
    switch (wasi_addr.kind) {
        case IPv4:
        {
            sockaddr_in sock_addr_in = void;
            uint s_addr = void;

            memset(&sock_addr_in, 0, sock_addr_in.sizeof);

            s_addr = (wasi_addr.addr.ip4.addr.n0 << 24)
                     | (wasi_addr.addr.ip4.addr.n1 << 16)
                     | (wasi_addr.addr.ip4.addr.n2 << 8)
                     | wasi_addr.addr.ip4.addr.n3;

            sock_addr_in.sin_family = AF_INET;
            sock_addr_in.sin_addr.s_addr = htonl(s_addr);
            sock_addr_in.sin_port = htons(wasi_addr.addr.ip4.port);
            memcpy(sock_addr, &sock_addr_in, sock_addr_in.sizeof);

            *addrlen = sock_addr_in.sizeof;
            break;
        }
        case IPv6:
        {
            sockaddr_in6 sock_addr_in6 = void;

            memset(&sock_addr_in6, 0, sock_addr_in6.sizeof);

            ushort* addr_buf = cast(ushort*)sock_addr_in6.sin6_addr.s6_addr;

            addr_buf[0] = htons(wasi_addr.addr.ip6.addr.n0);
            addr_buf[1] = htons(wasi_addr.addr.ip6.addr.n1);
            addr_buf[2] = htons(wasi_addr.addr.ip6.addr.n2);
            addr_buf[3] = htons(wasi_addr.addr.ip6.addr.n3);
            addr_buf[4] = htons(wasi_addr.addr.ip6.addr.h0);
            addr_buf[5] = htons(wasi_addr.addr.ip6.addr.h1);
            addr_buf[6] = htons(wasi_addr.addr.ip6.addr.h2);
            addr_buf[7] = htons(wasi_addr.addr.ip6.addr.h3);

            sock_addr_in6.sin6_family = AF_INET6;
            sock_addr_in6.sin6_port = htons(wasi_addr.addr.ip6.port);
            memcpy(sock_addr, &sock_addr_in6, sock_addr_in6.sizeof);

            *addrlen = sock_addr_in6.sizeof;
            break;
        }
        default:
            return __WASI_ERRNO_AFNOSUPPORT;
    }
    return __WASI_ERRNO_SUCCESS;
}

int accept(int sockfd, sockaddr* addr, socklen_t* addrlen) {
    __wasi_addr_t wasi_addr = void;
    __wasi_fd_t new_sockfd = void;
    __wasi_errno_t error = void;

    memset(&wasi_addr, 0, wasi_addr.sizeof);

    error = __wasi_sock_accept(sockfd, 0, &new_sockfd);
     if(getpeername) {
        return -1;
    }

    return new_sockfd;
}

int bind(int sockfd, const(sockaddr)* addr, socklen_t addrlen) {
    __wasi_addr_t wasi_addr = void;
    __wasi_errno_t error = void;

    memset(&wasi_addr, 0, wasi_addr.sizeof);

    error = sockaddr_to_wasi_addr(addr, addrlen, &wasi_addr);
     error = __wasi_sock_bind(sockfd, &wasi_addr);
     __WASI_ERRNO_SUCCESS = void;
}

int connect(int sockfd, const(sockaddr)* addr, socklen_t addrlen) {
    __wasi_addr_t wasi_addr = void;
    __wasi_errno_t error = void;

    memset(&wasi_addr, 0, wasi_addr.sizeof);

    if (null == addr) {
        HANDLE_ERROR(__WASI_ERRNO_INVAL)
    }

    error = sockaddr_to_wasi_addr(addr, addrlen, &wasi_addr);
     error = __wasi_sock_connect(sockfd, &wasi_addr);
     __WASI_ERRNO_SUCCESS = void;
}

int listen(int sockfd, int backlog) {
    __wasi_errno_t error = __wasi_sock_listen(sockfd, backlog);
     __WASI_ERRNO_SUCCESS = void;
}

ssize_t recvmsg(int sockfd, msghdr* msg, int flags) {
    // Prepare input parameters.
    __wasi_iovec_t* ri_data = null;
    size_t i = 0;
    size_t ro_datalen = 0;
    __wasi_roflags_t ro_flags = 0;

    if (null == msg) {
        HANDLE_ERROR(__WASI_ERRNO_INVAL)
    }

    // Validate flags.
    if (flags != 0) {
        HANDLE_ERROR(__WASI_ERRNO_NOPROTOOPT)
    }

    // __wasi_ciovec_t -> struct iovec
    if (((ri_data = cast(__wasi_iovec_t*)malloc(sizeof(__wasi_iovec_t)
                                             * msg.msg_iovlen)) == 0)) {
        HANDLE_ERROR(__WASI_ERRNO_NOMEM)
    }

    for (i = 0; i < msg.msg_iovlen; i++) {
        ri_data[i].buf = cast(ubyte*)msg.msg_iov[i].iov_base;
        ri_data[i].buf_len = msg.msg_iov[i].iov_len;
    }

    // Perform system call.
    __wasi_errno_t error = __wasi_sock_recv(sockfd, ri_data, msg.msg_iovlen, 0,
                                            &ro_datalen, &ro_flags);
    free(ri_data);
     ro_datalen = void;
}

ssize_t sendmsg(int sockfd, const(msghdr)* msg, int flags) {
    // Prepare input parameters.
    __wasi_ciovec_t* si_data = null;
    size_t so_datalen = 0;
    size_t i = 0;

    if (null == msg) {
        HANDLE_ERROR(__WASI_ERRNO_INVAL)
    }

    // This implementation does not support any flags.
    if (flags != 0) {
        HANDLE_ERROR(__WASI_ERRNO_NOPROTOOPT)
    }

    // struct iovec -> __wasi_ciovec_t
    if (((si_data = cast(__wasi_ciovec_t*)malloc(sizeof(__wasi_ciovec_t)
                                              * msg.msg_iovlen)) == 0)) {
        HANDLE_ERROR(__WASI_ERRNO_NOMEM)
    }

    for (i = 0; i < msg.msg_iovlen; i++) {
        si_data[i].buf = cast(ubyte*)msg.msg_iov[i].iov_base;
        si_data[i].buf_len = msg.msg_iov[i].iov_len;
    }

    // Perform system call.
    __wasi_errno_t error = __wasi_sock_send(sockfd, si_data, msg.msg_iovlen, 0, &so_datalen);
    free(si_data);
     so_datalen = void;
}

ssize_t sendto(int sockfd, const(void)* buf, size_t len, int flags, const(sockaddr)* dest_addr, socklen_t addrlen) {
    // Prepare input parameters.
    __wasi_ciovec_t iov = { buf: cast(ubyte*)buf, buf_len: len };
    uint so_datalen = 0;
    __wasi_addr_t wasi_addr = void;
    __wasi_errno_t error = void;
    size_t si_data_len = 1;
    __wasi_siflags_t si_flags = 0;

    // This implementation does not support any flags.
    if (flags != 0) {
        HANDLE_ERROR(__WASI_ERRNO_NOPROTOOPT)
    }

    error = sockaddr_to_wasi_addr(dest_addr, addrlen, &wasi_addr);
    HANDLE_ERROR(error);

    // Perform system call.
    error = __wasi_sock_send_to(sockfd, &iov, si_data_len, si_flags, &wasi_addr,
                                &so_datalen);
     so_datalen = void;
}

ssize_t recvfrom(int sockfd, void* buf, size_t len, int flags, sockaddr* src_addr, socklen_t* addrlen) {
    // Prepare input parameters.
    __wasi_ciovec_t iov = { buf: cast(ubyte*)buf, buf_len: len };
    uint so_datalen = 0;
    __wasi_addr_t wasi_addr = void;
    __wasi_errno_t error = void;
    size_t si_data_len = 1;
    __wasi_siflags_t si_flags = 0;

    // This implementation does not support any flags.
    if (flags != 0) {
        HANDLE_ERROR(__WASI_ERRNO_NOPROTOOPT)
    }

    if (!src_addr) {
        return recv(sockfd, buf, len, flags);
    }

    // Perform system call.
    error = __wasi_sock_recv_from(sockfd, &iov, si_data_len, si_flags,
                                  &wasi_addr, &so_datalen);
    HANDLE_ERROR(error);

    error = wasi_addr_to_sockaddr(&wasi_addr, src_addr, addrlen);
    HANDLE_ERROR(error);

    return so_datalen;
}

int socket(int domain, int type, int protocol) {
    // the stub of address pool fd
    __wasi_fd_t poolfd = -1;
    __wasi_fd_t sockfd = void;
    __wasi_errno_t error = void;
    __wasi_address_family_t af = void;
    __wasi_sock_type_t socktype = void;

    if (AF_INET == domain) {
        af = INET4;
    }
    else if (AF_INET6 == domain) {
        af = INET6;
    }
    else {
        return __WASI_ERRNO_NOPROTOOPT;
    }

    if (SOCK_DGRAM == type) {
        socktype = SOCKET_DGRAM;
    }
    else if (SOCK_STREAM == type) {
        socktype = SOCKET_STREAM;
    }
    else {
        return __WASI_ERRNO_NOPROTOOPT;
    }

    error = __wasi_sock_open(poolfd, af, socktype, &sockfd);
     sockfd = void;
}

int getsockname(int sockfd, sockaddr* addr, socklen_t* addrlen) {
    __wasi_addr_t wasi_addr = void;
    __wasi_errno_t error = void;

    memset(&wasi_addr, 0, wasi_addr.sizeof);

    error = __wasi_sock_addr_local(sockfd, &wasi_addr);
     error = wasi_addr_to_sockaddr(&wasi_addr, addr, addrlen);
     __WASI_ERRNO_SUCCESS = void;
}

int getpeername(int sockfd, sockaddr* addr, socklen_t* addrlen) {
    __wasi_addr_t wasi_addr = void;
    __wasi_errno_t error = void;

    memset(&wasi_addr, 0, wasi_addr.sizeof);

    error = __wasi_sock_addr_remote(sockfd, &wasi_addr);
     error = wasi_addr_to_sockaddr(&wasi_addr, addr, addrlen);
     __WASI_ERRNO_SUCCESS = void;
}

struct aibuf {
    addrinfo ai;
    union sa {
        sockaddr_in sin;
        sockaddr_in6 sin6;
    }sa sa;
}

private __wasi_errno_t addrinfo_hints_to_wasi_hints(const(addrinfo)* hints, __wasi_addr_info_hints_t* wasi_hints) {
    if (hints) {
        wasi_hints.hints_enabled = 1;

        switch (hints.ai_family) {
            case AF_INET:
                wasi_hints.family = INET4;
                break;
            case AF_INET6:
                wasi_hints.family = INET6;
                break;
            default:
                return __WASI_ERRNO_AFNOSUPPORT;
        }
        switch (hints.ai_socktype) {
            case SOCK_STREAM:
                wasi_hints.type = SOCKET_STREAM;
                break;
            case SOCK_DGRAM:
                wasi_hints.type = SOCKET_DGRAM;
                break;
            default:
                return __WASI_ERRNO_NOTSUP;
        }

        if (hints.ai_protocol != 0) {
            return __WASI_ERRNO_NOTSUP;
        }

        if (hints.ai_flags != 0) {
            return __WASI_ERRNO_NOTSUP;
        }
    }
    else {
        wasi_hints.hints_enabled = 0;
    }

    return __WASI_ERRNO_SUCCESS;
}

private __wasi_errno_t wasi_addr_info_to_addr_info(const(__wasi_addr_info_t)* addr_info, addrinfo* ai) {
    ai.ai_socktype =
        addr_info.type == SOCKET_DGRAM ? SOCK_DGRAM : SOCK_STREAM;
    ai.ai_protocol = 0;
    ai.ai_canonname = null;

    if (addr_info.addr.kind == IPv4) {
        ai.ai_family = AF_INET;
        ai.ai_addrlen = sockaddr_in.sizeof;
    }
    else {
        ai.ai_family = AF_INET6;
        ai.ai_addrlen = sockaddr_in6.sizeof;
    }

    return wasi_addr_to_sockaddr(&addr_info.addr, ai.ai_addr,
                                 &ai.ai_addrlen); // TODO err handling
}

int
getaddrinfo(const(char)* node, const(char)* service, const(addrinfo)* hints,
            addrinfo** res)
{
    __wasi_addr_info_hints_t wasi_hints;
    __wasi_addr_info_t* addr_info = null;
    __wasi_size_t addr_info_size, i;
    __wasi_size_t max_info_size = 16;
    __wasi_errno_t error;
    aibuf* aibuf_res;

    error = addrinfo_hints_to_wasi_hints(hints, &wasi_hints);
    HANDLE_ERROR(error)

    do {
        if (addr_info)
            free(addr_info);

        addr_info_size = max_info_size;
        addr_info = cast(__wasi_addr_info_t*)malloc(addr_info_size
                                                 * __wasi_addr_info_t.sizeof);

        if (!addr_info) {
             error = __wasi_sock_addr_resolve(node, service == null ? "" : service,
                                         &wasi_hints, addr_info, addr_info_size,
                                         &max_info_size);
        if (error != __WASI_ERRNO_SUCCESS) {
            free(addr_info);
            HANDLE_ERROR(error);
        }
    } while (max_info_size > addr_info_size){}

    if (addr_info_size == 0) {
        free(addr_info);
        *res = null;
        return __WASI_ERRNO_SUCCESS;
    }

    aibuf_res =
        cast(aibuf*)calloc(1, addr_info_size * aibuf.sizeof);
    if (!aibuf_res) {
        free(addr_info);
        * res = &aibuf_res[0].ai;

    if (addr_info_size) {
        addr_info_size = max_info_size;
    }

    for (i = 0; i < addr_info_size; i++) {
        addrinfo* ai = &aibuf_res[i].ai;
        ai.ai_addr = cast(sockaddr*)&aibuf_res[i].sa;

        error = wasi_addr_info_to_addr_info(&addr_info[i], ai);
        if (error != __WASI_ERRNO_SUCCESS) {
            free(addr_info);
            free(aibuf_res);
            HANDLE_ERROR(error)
        }
        ai.ai_next = i == addr_info_size - 1 ? null : &aibuf_res[i + 1].ai;
    }

    free(addr_info);

    return __WASI_ERRNO_SUCCESS;
}

void freeaddrinfo(addrinfo* res) {
    /* res is a pointer to a first field in the first element
     * of aibuf array allocated in getaddrinfo, therefore this call
     * frees the memory of the entire array. */
    free(res);
}

private timeval time_us_to_timeval(ulong time_us) {
    timeval tv = void;
    tv.tv_sec = time_us / 1000000UL;
    tv.tv_usec = time_us % 1000000UL;
    return tv;
}

private ulong timeval_to_time_us(timeval tv) {
    return (tv.tv_sec * 1000000UL) + tv.tv_usec;
}

private int get_sol_socket_option(int sockfd, int optname, void* optval, socklen_t* optlen) {
    __wasi_errno_t error = void;
    ulong timeout_us = void;
    bool is_linger_enabled = void;
    int linger_s = void;

    switch (optname) {
        case SO_RCVTIMEO:
            assert(*optlen == timeval.sizeof);
            error = __wasi_sock_get_recv_timeout(sockfd, &timeout_us);
            HANDLE_ERROR(error);
            *cast(timeval*)optval = time_us_to_timeval(timeout_us);
            return error;
        case SO_SNDTIMEO:
            assert(*optlen == timeval.sizeof);
            error = __wasi_sock_get_send_timeout(sockfd, &timeout_us);
            HANDLE_ERROR(error);
            *cast(timeval*)optval = time_us_to_timeval(timeout_us);
            return error;
        case SO_SNDBUF:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_send_buf_size(sockfd, cast(size_t*)optval);
            HANDLE_ERROR(error);
            return error;
        case SO_RCVBUF:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_recv_buf_size(sockfd, cast(size_t*)optval);
            HANDLE_ERROR(error);
            return error;
        case SO_KEEPALIVE:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_keep_alive(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case SO_REUSEADDR:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_reuse_addr(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case SO_REUSEPORT:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_reuse_port(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case SO_LINGER:
            assert(*optlen == linger.sizeof);
            error =
                __wasi_sock_get_linger(sockfd, &is_linger_enabled, &linger_s);
            HANDLE_ERROR(error);
            (cast(linger*)optval).l_onoff = cast(int)is_linger_enabled;
            (cast(linger*)optval).l_linger = linger_s;
            return error;
        case SO_BROADCAST:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_broadcast(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

private int get_ipproto_tcp_option(int sockfd, int optname, void* optval, socklen_t* optlen) {
    __wasi_errno_t error = void;
    switch (optname) {
        case TCP_KEEPIDLE:
            assert(*optlen == uint.sizeof);
            error = __wasi_sock_get_tcp_keep_idle(sockfd, cast(uint*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_KEEPINTVL:
            assert(*optlen == uint.sizeof);
            error = __wasi_sock_get_tcp_keep_intvl(sockfd, cast(uint*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_FASTOPEN_CONNECT:
            assert(*optlen == int.sizeof);
            error =
                __wasi_sock_get_tcp_fastopen_connect(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_NODELAY:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_tcp_no_delay(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_QUICKACK:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_tcp_quick_ack(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

private int get_ipproto_ip_option(int sockfd, int optname, void* optval, socklen_t* optlen) {
    __wasi_errno_t error = void;

    switch (optname) {
        case IP_MULTICAST_LOOP:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_ip_multicast_loop(sockfd, false,
                                                      cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case IP_TTL:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_ip_ttl(sockfd, cast(ubyte*)optval);
            HANDLE_ERROR(error);
            return error;
        case IP_MULTICAST_TTL:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_ip_multicast_ttl(sockfd, cast(ubyte*)optval);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

private int get_ipproto_ipv6_option(int sockfd, int optname, void* optval, socklen_t* optlen) {
    __wasi_errno_t error = void;

    switch (optname) {
        case IPV6_V6ONLY:
            assert(*optlen == int.sizeof);
            error = __wasi_sock_get_ipv6_only(sockfd, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case IPV6_MULTICAST_LOOP:
            assert(*optlen == int.sizeof);
            error =
                __wasi_sock_get_ip_multicast_loop(sockfd, true, cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

int getsockopt(int sockfd, int level, int optname, void* optval, socklen_t* optlen) {
    __wasi_errno_t error = void;

    switch (level) {
        case SOL_SOCKET:
            return get_sol_socket_option(sockfd, optname, optval, optlen);
        case IPPROTO_TCP:
            return get_ipproto_tcp_option(sockfd, optname, optval, optlen);
        case IPPROTO_IP:
            return get_ipproto_ip_option(sockfd, optname, optval, optlen);
        case IPPROTO_IPV6:
            return get_ipproto_ipv6_option(sockfd, optname, optval, optlen);
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

private int set_sol_socket_option(int sockfd, int optname, const(void)* optval, socklen_t optlen) {
    __wasi_errno_t error = void;
    ulong timeout_us = void;

    switch (optname) {
        case SO_RCVTIMEO:
        {
            assert(optlen == timeval.sizeof);
            timeout_us = timeval_to_time_us(*cast(timeval*)optval);
            error = __wasi_sock_set_recv_timeout(sockfd, timeout_us);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_SNDTIMEO:
        {
            assert(optlen == timeval.sizeof);
            timeout_us = timeval_to_time_us(*cast(timeval*)optval);
            error = __wasi_sock_set_send_timeout(sockfd, timeout_us);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_SNDBUF:
        {
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_send_buf_size(sockfd, *cast(size_t*)optval);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_RCVBUF:
        {
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_recv_buf_size(sockfd, *cast(size_t*)optval);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_KEEPALIVE:
        {
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_keep_alive(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_REUSEADDR:
        {
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_reuse_addr(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_REUSEPORT:
        {
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_reuse_port(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_LINGER:
        {
            assert(optlen == linger.sizeof);
            linger* linger_opt = (cast(linger*)optval);
            error = __wasi_sock_set_linger(sockfd, cast(bool)linger_opt.l_onoff,
                                           linger_opt.l_linger);
            HANDLE_ERROR(error);
            return error;
        }
        case SO_BROADCAST:
        {
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_broadcast(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        }
        default:
        {
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
        }
    }
}

private int set_ipproto_tcp_option(int sockfd, int optname, const(void)* optval, socklen_t optlen) {
    __wasi_errno_t error = void;

    switch (optname) {
        case TCP_NODELAY:
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_tcp_no_delay(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_KEEPIDLE:
            assert(optlen == uint.sizeof);
            error = __wasi_sock_set_tcp_keep_idle(sockfd, *cast(uint*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_KEEPINTVL:
            assert(optlen == uint.sizeof);
            error = __wasi_sock_set_tcp_keep_intvl(sockfd, *cast(uint*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_FASTOPEN_CONNECT:
            assert(optlen == int.sizeof);
            error =
                __wasi_sock_set_tcp_fastopen_connect(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case TCP_QUICKACK:
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_tcp_quick_ack(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

private int set_ipproto_ip_option(int sockfd, int optname, const(void)* optval, socklen_t optlen) {
    __wasi_errno_t error = void;
    __wasi_addr_ip_t imr_multiaddr = void;
    ip_mreq* ip_mreq_opt = void;

    switch (optname) {
        case IP_MULTICAST_LOOP:
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_ip_multicast_loop(sockfd, false,
                                                      *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case IP_ADD_MEMBERSHIP:
            assert(optlen == ip_mreq.sizeof);
            ip_mreq_opt = cast(ip_mreq*)optval;
            imr_multiaddr.kind = IPv4;
            ipv4_addr_to_wasi_ip4_addr(ip_mreq_opt.imr_multiaddr.s_addr,
                                       &imr_multiaddr.addr.ip4);
            error = __wasi_sock_set_ip_add_membership(
                sockfd, &imr_multiaddr, ip_mreq_opt.imr_interface.s_addr);
            HANDLE_ERROR(error);
            return error;
        case IP_DROP_MEMBERSHIP:
            assert(optlen == ip_mreq.sizeof);
            ip_mreq_opt = cast(ip_mreq*)optval;
            imr_multiaddr.kind = IPv4;
            ipv4_addr_to_wasi_ip4_addr(ip_mreq_opt.imr_multiaddr.s_addr,
                                       &imr_multiaddr.addr.ip4);
            error = __wasi_sock_set_ip_drop_membership(
                sockfd, &imr_multiaddr, ip_mreq_opt.imr_interface.s_addr);
            HANDLE_ERROR(error);
            return error;
        case IP_TTL:
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_ip_ttl(sockfd, *cast(ubyte*)optval);
            HANDLE_ERROR(error);
            return error;
        case IP_MULTICAST_TTL:
            assert(optlen == int.sizeof);
            error =
                __wasi_sock_set_ip_multicast_ttl(sockfd, *cast(ubyte*)optval);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

private int set_ipproto_ipv6_option(int sockfd, int optname, const(void)* optval, socklen_t optlen) {
    __wasi_errno_t error = void;
    ipv6_mreq* ipv6_mreq_opt = void;
    __wasi_addr_ip_t imr_multiaddr = void;

    switch (optname) {
        case IPV6_V6ONLY:
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_ipv6_only(sockfd, *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case IPV6_MULTICAST_LOOP:
            assert(optlen == int.sizeof);
            error = __wasi_sock_set_ip_multicast_loop(sockfd, true,
                                                      *cast(bool*)optval);
            HANDLE_ERROR(error);
            return error;
        case IPV6_JOIN_GROUP:
            assert(optlen == ipv6_mreq.sizeof);
            ipv6_mreq_opt = cast(ipv6_mreq*)optval;
            imr_multiaddr.kind = IPv6;
            ipv6_addr_to_wasi_ipv6_addr(
                cast(ushort*)ipv6_mreq_opt.ipv6mr_multiaddr.s6_addr,
                &imr_multiaddr.addr.ip6);
            error = __wasi_sock_set_ip_add_membership(
                sockfd, &imr_multiaddr, ipv6_mreq_opt.ipv6mr_interface);
            HANDLE_ERROR(error);
            return error;
        case IPV6_LEAVE_GROUP:
            assert(optlen == ipv6_mreq.sizeof);
            ipv6_mreq_opt = cast(ipv6_mreq*)optval;
            imr_multiaddr.kind = IPv6;
            ipv6_addr_to_wasi_ipv6_addr(
                cast(ushort*)ipv6_mreq_opt.ipv6mr_multiaddr.s6_addr,
                &imr_multiaddr.addr.ip6);
            error = __wasi_sock_set_ip_drop_membership(
                sockfd, &imr_multiaddr, ipv6_mreq_opt.ipv6mr_interface);
            HANDLE_ERROR(error);
            return error;
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}

int setsockopt(int sockfd, int level, int optname, const(void)* optval, socklen_t optlen) {
    __wasi_errno_t error = void;

    switch (level) {
        case SOL_SOCKET:
            return set_sol_socket_option(sockfd, optname, optval, optlen);
        case IPPROTO_TCP:
            return set_ipproto_tcp_option(sockfd, optname, optval, optlen);
        case IPPROTO_IP:
            return set_ipproto_ip_option(sockfd, optname, optval, optlen);
        case IPPROTO_IPV6:
            return set_ipproto_ipv6_option(sockfd, optname, optval, optlen);
        default:
            error = __WASI_ERRNO_NOTSUP;
            HANDLE_ERROR(error);
            return error;
    }
}
