module wasi_socket_ext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import stdbool;
public import core.stdc.stddef;
public import core.stdc.stdint;

/*Be a part of <wasi/api.h>*/

version (none) {
extern "C" {
//! #endif

enum ___wasi_sock_type_t {
    SOCKET_DGRAM = 0,
    SOCKET_STREAM,
}alias __wasi_sock_type_t = ___wasi_sock_type_t;

alias __wasi_ip_port_t = ushort;

enum ___wasi_addr_type_t { IPv4 = 0, IPv6 }alias __wasi_addr_type_t = ___wasi_addr_type_t;

/*
 n0.n1.n2.n3
 Example:
  IP Address: 127.0.0.1
  Structure: {n0: 127, n1: 0, n2: 0, n3: 1}
*/
struct __wasi_addr_ip4_t {
    ubyte n0;
    ubyte n1;
    ubyte n2;
    ubyte n3;
}

struct __wasi_addr_ip4_port_t {
    __wasi_addr_ip4_t addr;
    __wasi_ip_port_t port; /* host byte order */
}

/*
 n0:n1:n2:n3:h0:h1:h2:h3, each 16bit value uses host byte order
 Example (little-endian system)
  IP Address fe80::3ba2:893b:4be0:e3dd
  Structure: {
    n0: 0xfe80, n1:0x0, n2: 0x0, n3: 0x0,
    h0: 0x3ba2, h1: 0x893b, h2: 0x4be0, h3: 0xe3dd
  }
*/
struct __wasi_addr_ip6_t {
    ushort n0;
    ushort n1;
    ushort n2;
    ushort n3;
    ushort h0;
    ushort h1;
    ushort h2;
    ushort h3;
}

struct __wasi_addr_ip6_port_t {
    __wasi_addr_ip6_t addr;
    __wasi_ip_port_t port; /* host byte order */
}

struct __wasi_addr_ip_t {
    __wasi_addr_type_t kind;
    union _Addr {
        __wasi_addr_ip4_t ip4;
        __wasi_addr_ip6_t ip6;
    }_Addr addr;
}

struct __wasi_addr_t {
    __wasi_addr_type_t kind;
    union _Addr {
        __wasi_addr_ip4_port_t ip4;
        __wasi_addr_ip6_port_t ip6;
    }_Addr addr;
}

enum ___wasi_address_family_t { INET4 = 0, INET6 }alias __wasi_address_family_t = ___wasi_address_family_t;

struct __wasi_addr_info_t {
    __wasi_addr_t addr;
    __wasi_sock_type_t type;
}

struct __wasi_addr_info_hints_t {
    __wasi_sock_type_t type;
    __wasi_address_family_t family;
    // this is to workaround lack of optional parameters
    ubyte hints_enabled;
}

version (__wasi__) {
/**
 * Reimplement below POSIX APIs with __wasi_sock_XXX functions.
 *
 * Keep sync with
 * <sys/socket.h>
 * <sys/types.h>
 */
enum SO_REUSEADDR = 2;
enum SO_BROADCAST = 6;
enum SO_SNDBUF = 7;
enum SO_RCVBUF = 8;
enum SO_KEEPALIVE = 9;
enum SO_LINGER = 13;
enum SO_REUSEPORT = 15;
enum SO_RCVTIMEO = 20;
enum SO_SNDTIMEO = 21;

enum TCP_NODELAY = 1;
enum TCP_KEEPIDLE = 4;
enum TCP_KEEPINTVL = 5;
enum TCP_QUICKACK = 12;
enum TCP_FASTOPEN_CONNECT = 30;

enum IP_TTL = 2;
enum IP_MULTICAST_TTL = 33;
enum IP_MULTICAST_LOOP = 34;
enum IP_ADD_MEMBERSHIP = 35;
enum IP_DROP_MEMBERSHIP = 36;

enum IPV6_MULTICAST_LOOP = 19;
enum IPV6_JOIN_GROUP = 20;
enum IPV6_LEAVE_GROUP = 21;
enum IPV6_V6ONLY = 26;

struct addrinfo {
    int ai_flags;             /* Input flags.  */
    int ai_family;            /* Protocol family for socket.  */
    int ai_socktype;          /* Socket type.  */
    int ai_protocol;          /* Protocol for socket.  */
    socklen_t ai_addrlen;     /* Length of socket address.  */
    sockaddr* ai_addr; /* Socket address for socket.  */
    char* ai_canonname;       /* Canonical name for service location.  */
    addrinfo* ai_next; /* Pointer to next in list.  */
}

version (__WASI_RIGHTS_SOCK_ACCEPT) {} else {
int accept(int sockfd, sockaddr* addr, socklen_t* addrlen);
}

int bind(int sockfd, const(sockaddr)* addr, socklen_t addrlen);

int connect(int sockfd, const(sockaddr)* addr, socklen_t addrlen);

int listen(int sockfd, int backlog);

ssize_t recvmsg(int sockfd, msghdr* msg, int flags);

ssize_t sendmsg(int sockfd, const(msghdr)* msg, int flags);

ssize_t sendto(int sockfd, const(void)* buf, size_t len, int flags, const(sockaddr)* dest_addr, socklen_t addrlen);

ssize_t recvfrom(int sockfd, void* buf, size_t len, int flags, sockaddr* src_addr, socklen_t* addrlen);

int socket(int domain, int type, int protocol);

int getsockname(int sockfd, sockaddr* addr, socklen_t* addrlen);

int getpeername(int sockfd, sockaddr* addr, socklen_t* addrlen);

int getsockopt(int sockfd, int level, int optname, void* optval, socklen_t* optlen);

int setsockopt(int sockfd, int level, int optname, const(void)* optval, socklen_t optlen);

int getaddrinfo(const(char)* node, const(char)* service, const(addrinfo)* hints, addrinfo** res);

void freeaddrinfo(addrinfo* res);
}

/**
 * __wasi_sock_accept was introduced in wasi-sdk v15. To
 * temporarily maintain backward compatibility with the old
 * wasi-sdk, we explicitly add that implementation here so it works
 * with older versions of the SDK.
 */
version (__WASI_RIGHTS_SOCK_ACCEPT) {} else {
/**
 * Accept a connection on a socket
 * Note: This is similar to `accept`
 */
int __imported_wasi_snapshot_preview1_sock_accept(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_accept(__wasi_fd_t fd, __wasi_fdflags_t flags, __wasi_fd_t* fd_new) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_accept(
        cast(int)fd, cast(int)flags, cast(int)fd_new);
}
}

/**
 * Returns the local address to which the socket is bound.
 *
 * Note: This is similar to `getsockname` in POSIX
 *
 * When successful, the contents of the output buffer consist of an IP address,
 * either IP4 or IP6.
 */
int __imported_wasi_snapshot_preview1_sock_addr_local(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_addr_local(__wasi_fd_t fd, __wasi_addr_t* addr) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_addr_local(
        cast(int)fd, cast(int)addr);
}

/**
 * Returns the remote address to which the socket is connected to.
 *
 * Note: This is similar to `getpeername` in POSIX
 *
 * When successful, the contents of the output buffer consist of an IP address,
 * either IP4 or IP6.
 */
int __imported_wasi_snapshot_preview1_sock_addr_remote(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_addr_remote(__wasi_fd_t fd, __wasi_addr_t* addr) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_addr_remote(
        cast(int)fd, cast(int)addr);
}

/**
 * Resolve a hostname and a service to one or more IP addresses. Service is
 * optional and you can pass empty string in most cases, it is used as a hint
 * for protocol.
 *
 * Note: This is similar to `getaddrinfo` in POSIX
 *
 * When successful, the contents of the output buffer consist of a sequence of
 * IPv4 and/or IPv6 addresses. Each address entry consists of a wasi_addr_t
 * object.
 *
 * This function fills the output buffer as much as possible, truncating the
 * entries that didn't fit into the buffer. A number of available addresses
 * will be returned through the last parameter.
 */
int __imported_wasi_snapshot_preview1_sock_addr_resolve(int arg0, int arg1, int arg2, int arg3, int arg4, int arg5);

pragma(inline, true) private __wasi_errno_t __wasi_sock_addr_resolve(const(char)* host, const(char)* service, __wasi_addr_info_hints_t* hints, __wasi_addr_info_t* addr_info, __wasi_size_t addr_info_size, __wasi_size_t* max_info_size) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_addr_resolve(
        cast(int)host, cast(int)service, cast(int)hints, cast(int)addr_info,
        cast(int)addr_info_size, cast(int)max_info_size);
}

/**
 * Bind a socket
 * Note: This is similar to `bind` in POSIX using PF_INET
 */
int __imported_wasi_snapshot_preview1_sock_bind(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_bind(__wasi_fd_t fd, __wasi_addr_t* addr) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_bind(
        cast(int)fd, cast(int)addr);
}

/**
 * Send data to a specific target
 * Note: This is similar to `sendto` in POSIX
 */
int __imported_wasi_snapshot_preview1_sock_send_to(int arg0, int arg1, int arg2, int arg3, int arg4, int arg5);

pragma(inline, true) private __wasi_errno_t __wasi_sock_send_to(__wasi_fd_t fd, const(__wasi_ciovec_t)* si_data, uint si_data_len, __wasi_siflags_t si_flags, const(__wasi_addr_t)* dest_addr, uint* so_data_len) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_send_to(
        cast(int)fd, cast(int)si_data, cast(int)si_data_len, cast(int)si_flags,
        cast(uint)dest_addr, cast(uint)so_data_len);
}

/**
 * Receives data from a socket
 * Note: This is similar to `recvfrom` in POSIX
 */
int __imported_wasi_snapshot_preview1_sock_recv_from(int arg0, int arg1, int arg2, int arg3, int arg4, int arg5);

pragma(inline, true) private __wasi_errno_t __wasi_sock_recv_from(__wasi_fd_t fd, __wasi_ciovec_t* ri_data, uint ri_data_len, __wasi_riflags_t ri_flags, __wasi_addr_t* src_addr, uint* ro_data_len) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_recv_from(
        cast(int)fd, cast(int)ri_data, cast(int)ri_data_len, cast(int)ri_flags,
        cast(uint)src_addr, cast(uint)ro_data_len);
}

/**
 * Close a socket (this is an alias for `fd_close`)
 * Note: This is similar to `close` in POSIX.
 */
int __imported_wasi_snapshot_preview1_sock_close(int arg0);

pragma(inline, true) private __wasi_errno_t __wasi_sock_close(__wasi_fd_t fd) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_close(
        cast(int)fd);
}

/**
 * Initiate a connection on a socket to the specified address
 * Note: This is similar to `connect` in POSIX
 */

int __imported_wasi_snapshot_preview1_sock_connect(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_connect(__wasi_fd_t fd, __wasi_addr_t* addr) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_connect(
        cast(int)fd, cast(int)addr);
}
/**
 * Retrieve the size of the receive buffer
 * Note: This is similar to `getsockopt` in POSIX for SO_RCVBUF
 */

int __imported_wasi_snapshot_preview1_sock_get_recv_buf_size(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_recv_buf_size(__wasi_fd_t fd, __wasi_size_t* size) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_recv_buf_size(cast(int)fd,
                                                                 cast(int)size);
}
/**
 * Retrieve status of address reuse on a socket
 * Note: This is similar to `getsockopt` in POSIX for SO_REUSEADDR
 */
int __imported_wasi_snapshot_preview1_sock_get_reuse_addr(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_reuse_addr(__wasi_fd_t fd, bool* reuse) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_reuse_addr(cast(int)fd,
                                                              cast(int)reuse);
}

/**
 * Retrieve status of port reuse on a socket
 * Note: This is similar to `getsockopt` in POSIX for SO_REUSEPORT
 */
int __imported_wasi_snapshot_preview1_sock_get_reuse_port(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_reuse_port(__wasi_fd_t fd, bool* reuse) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_reuse_port(cast(int)fd,
                                                              cast(int)reuse);
}

/**
 * Retrieve the size of the send buffer
 * Note: This is similar to `getsockopt` in POSIX for SO_SNDBUF
 */
int __imported_wasi_snapshot_preview1_sock_get_send_buf_size(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_send_buf_size(__wasi_fd_t fd, __wasi_size_t* size) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_send_buf_size(cast(int)fd,
                                                                 cast(int)size);
}

/**
 * Listen for connections on a socket
 * Note: This is similar to `listen`
 */
int __imported_wasi_snapshot_preview1_sock_listen(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_listen(__wasi_fd_t fd, __wasi_size_t backlog) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_listen(
        cast(int)fd, cast(int)backlog);
}

/**
 * Open a socket

 * The first argument to this function is a handle to an
 * address pool. The address pool determines what actions can
 * be performed and at which addresses they can be performed to.

 * The address pool cannot be re-assigned. You will need to close
 * the socket and open a new one to use a different address pool.

 * Note: This is similar to `socket` in POSIX using PF_INET
 */

int __imported_wasi_snapshot_preview1_sock_open(int arg0, int arg1, int arg2, int arg3);

pragma(inline, true) private __wasi_errno_t __wasi_sock_open(__wasi_fd_t fd, __wasi_address_family_t af, __wasi_sock_type_t socktype, __wasi_fd_t* sockfd) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_open(
        cast(int)fd, cast(int)af, cast(int)socktype, cast(int)sockfd);
}

/**
 * Set size of receive buffer
 * Note: This is similar to `setsockopt` in POSIX for SO_RCVBUF
 */
int __imported_wasi_snapshot_preview1_sock_set_recv_buf_size(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_recv_buf_size(__wasi_fd_t fd, __wasi_size_t size) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_recv_buf_size(cast(int)fd,
                                                                 cast(int)size);
}

/**
 * Enable/disable address reuse on a socket
 * Note: This is similar to `setsockopt` in POSIX for SO_REUSEADDR
 */
int __imported_wasi_snapshot_preview1_sock_set_reuse_addr(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_reuse_addr(__wasi_fd_t fd, bool reuse) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_reuse_addr(cast(int)fd,
                                                              cast(int)reuse);
}

/**
 * Enable port reuse on a socket
 * Note: This is similar to `setsockopt` in POSIX for SO_REUSEPORT
 */
int __imported_wasi_snapshot_preview1_sock_set_reuse_port(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_reuse_port(__wasi_fd_t fd, bool reuse) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_reuse_port(cast(int)fd,
                                                              cast(int)reuse);
}

/**
 * Set size of send buffer
 * Note: This is similar to `setsockopt` in POSIX for SO_SNDBUF
 */
int __imported_wasi_snapshot_preview1_sock_set_send_buf_size(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_send_buf_size(__wasi_fd_t fd, __wasi_size_t buf_len) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_send_buf_size(
            cast(int)fd, cast(int)buf_len);
}

int __imported_wasi_snapshot_preview1_sock_get_recv_timeout(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_recv_timeout(__wasi_fd_t fd, ulong* timeout_us) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_recv_timeout(
            cast(int)fd, cast(int)timeout_us);
}

int __imported_wasi_snapshot_preview1_sock_set_recv_timeout(int arg0, long arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_recv_timeout(__wasi_fd_t fd, ulong timeout_us) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_recv_timeout(
            cast(int)fd, cast(long)timeout_us);
}

int __imported_wasi_snapshot_preview1_sock_get_send_timeout(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_send_timeout(__wasi_fd_t fd, ulong* timeout_us) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_send_timeout(
            cast(int)fd, cast(int)timeout_us);
}

int __imported_wasi_snapshot_preview1_sock_set_send_timeout(int arg0, long arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_send_timeout(__wasi_fd_t fd, ulong timeout_us) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_send_timeout(
            cast(int)fd, cast(long)timeout_us);
}

int __imported_wasi_snapshot_preview1_sock_set_keep_alive(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_keep_alive(__wasi_fd_t fd, bool option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_keep_alive(cast(int)fd,
                                                              cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_keep_alive(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_keep_alive(__wasi_fd_t fd, bool* option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_keep_alive(cast(int)fd,
                                                              cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_linger(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_linger(__wasi_fd_t fd, bool is_enabled, int linger_s) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_set_linger(
        cast(int)fd, cast(int)is_enabled, cast(int)linger_s);
}

int __imported_wasi_snapshot_preview1_sock_get_linger(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_linger(__wasi_fd_t fd, bool* is_enabled, int* linger_s) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_get_linger(
        cast(int)fd, cast(int)is_enabled, cast(int)linger_s);
}

int __imported_wasi_snapshot_preview1_sock_set_tcp_keep_idle(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_tcp_keep_idle(__wasi_fd_t fd, uint time_s) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_tcp_keep_idle(
            cast(int)fd, cast(int)time_s);
}

int __imported_wasi_snapshot_preview1_sock_get_tcp_keep_idle(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_tcp_keep_idle(__wasi_fd_t fd, uint* time_s) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_tcp_keep_idle(
            cast(int)fd, cast(int)time_s);
}

int __imported_wasi_snapshot_preview1_sock_set_tcp_keep_intvl(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_tcp_keep_intvl(__wasi_fd_t fd, uint time_s) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_tcp_keep_intvl(
            cast(int)fd, cast(int)time_s);
}

int __imported_wasi_snapshot_preview1_sock_get_tcp_keep_intvl(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_tcp_keep_intvl(__wasi_fd_t fd, uint* time_s) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_tcp_keep_intvl(
            cast(int)fd, cast(int)time_s);
}

int __imported_wasi_snapshot_preview1_sock_set_tcp_fastopen_connect(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_tcp_fastopen_connect(__wasi_fd_t fd, bool option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_tcp_fastopen_connect(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_tcp_fastopen_connect(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_tcp_fastopen_connect(__wasi_fd_t fd, bool* option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_tcp_fastopen_connect(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_ip_multicast_loop(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_ip_multicast_loop(__wasi_fd_t fd, bool ipv6, bool option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_ip_multicast_loop(
            cast(int)fd, cast(int)ipv6, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_ip_multicast_loop(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_ip_multicast_loop(__wasi_fd_t fd, bool ipv6, bool* option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_ip_multicast_loop(
            cast(int)fd, cast(int)ipv6, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_ip_multicast_ttl(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_ip_multicast_ttl(__wasi_fd_t fd, ubyte option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_ip_multicast_ttl(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_ip_multicast_ttl(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_ip_multicast_ttl(__wasi_fd_t fd, ubyte* option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_ip_multicast_ttl(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_ip_add_membership(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_ip_add_membership(__wasi_fd_t fd, __wasi_addr_ip_t* imr_multiaddr, uint imr_interface) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_ip_add_membership(
            cast(int)fd, cast(int)imr_multiaddr, cast(int)imr_interface);
}

int __imported_wasi_snapshot_preview1_sock_set_ip_drop_membership(int arg0, int arg1, int arg2);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_ip_drop_membership(__wasi_fd_t fd, __wasi_addr_ip_t* imr_multiaddr, uint imr_interface) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_ip_drop_membership(
            cast(int)fd, cast(int)imr_multiaddr, cast(int)imr_interface);
}

int __imported_wasi_snapshot_preview1_sock_set_broadcast(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_broadcast(__wasi_fd_t fd, bool option) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_set_broadcast(
        cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_broadcast(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_broadcast(__wasi_fd_t fd, bool* option) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_get_broadcast(
        cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_tcp_no_delay(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_tcp_no_delay(__wasi_fd_t fd, bool option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_tcp_no_delay(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_tcp_no_delay(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_tcp_no_delay(__wasi_fd_t fd, bool* option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_tcp_no_delay(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_tcp_quick_ack(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_tcp_quick_ack(__wasi_fd_t fd, bool option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_set_tcp_quick_ack(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_tcp_quick_ack(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_tcp_quick_ack(__wasi_fd_t fd, bool* option) {
    return cast(__wasi_errno_t)
        __imported_wasi_snapshot_preview1_sock_get_tcp_quick_ack(
            cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_ip_ttl(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_ip_ttl(__wasi_fd_t fd, ubyte option) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_set_ip_ttl(
        cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_ip_ttl(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_ip_ttl(__wasi_fd_t fd, ubyte* option) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_get_ip_ttl(
        cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_set_ipv6_only(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_set_ipv6_only(__wasi_fd_t fd, bool option) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_set_ipv6_only(
        cast(int)fd, cast(int)option);
}

int __imported_wasi_snapshot_preview1_sock_get_ipv6_only(int arg0, int arg1);

pragma(inline, true) private __wasi_errno_t __wasi_sock_get_ipv6_only(__wasi_fd_t fd, bool* option) {
    return cast(__wasi_errno_t)__imported_wasi_snapshot_preview1_sock_get_ipv6_only(
        cast(int)fd, cast(int)option);
}
/**
 * TODO: modify recv() and send()
 * since don't want to re-compile the wasi-libc,
 * we tend to keep original implentations of recv() and send().
 */

version (none) {}
}
}


