module sgx_socket;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _SGX_SOCKET_H
version = _SGX_SOCKET_H;

public import sgx_file;

#ifdef __cplusplus
extern "C" {
//! #endif

/* For setsockopt(2) */
enum SOL_SOCKET = 1;

enum SO_DEBUG = 1;
enum SO_REUSEADDR = 2;
enum SO_TYPE = 3;
enum SO_ERROR = 4;
enum SO_DONTROUTE = 5;
enum SO_BROADCAST = 6;
enum SO_SNDBUF = 7;
enum SO_RCVBUF = 8;
enum SO_SNDBUFFORCE = 32;
enum SO_RCVBUFFORCE = 33;
enum SO_KEEPALIVE = 9;
enum SO_OOBINLINE = 10;
enum SO_NO_CHECK = 11;
enum SO_PRIORITY = 12;
enum SO_LINGER = 13;
enum SO_BSDCOMPAT = 14;
enum SO_REUSEPORT = 15;
enum SO_PASSCRED = 16;
enum SO_PEERCRED = 17;
enum SO_RCVLOWAT = 18;
enum SO_SNDLOWAT = 19;
enum SO_RCVTIMEO_OLD = 20;
enum SO_SNDTIMEO_OLD = 21;

/* User-settable options (used with setsockopt) */
enum TCP_NODELAY = 1               /* Don't delay send to coalesce packets  */;
enum TCP_MAXSEG = 2                /* Set maximum segment size  */;
enum TCP_CORK = 3                  /* Control sending of partial frames  */;
enum TCP_KEEPIDLE = 4              /* Start keeplives after this period */;
enum TCP_KEEPINTVL = 5             /* Interval between keepalives */;
enum TCP_KEEPCNT = 6               /* Number of keepalives before death */;
enum TCP_SYNCNT = 7                /* Number of SYN retransmits */;
enum TCP_LINGER2 = 8               /* Life time of orphaned FIN-WAIT-2 state */;
enum TCP_DEFER_ACCEPT = 9          /* Wake up listener only when data arrive */;
enum TCP_WINDOW_CLAMP = 10         /* Bound advertised window */;
enum TCP_INFO = 11                 /* Information about this connection. */;
enum TCP_QUICKACK = 12             /* Bock/reenable quick ACKs.  */;
enum TCP_CONGESTION = 13           /* Congestion control algorithm.  */;
enum TCP_MD5SIG = 14               /* TCP MD5 Signature (RFC2385) */;
enum TCP_COOKIE_TRANSACTIONS = 15  /* TCP Cookie Transactions */;
enum TCP_THIN_LINEAR_TIMEOUTS = 16 /* Use linear timeouts for thin streams*/;
enum TCP_THIN_DUPACK = 17          /* Fast retrans. after 1 dupack */;
enum TCP_USER_TIMEOUT = 18         /* How long for loss retry before timeout */;
enum TCP_REPAIR = 19               /* TCP sock is under repair right now */;
enum TCP_REPAIR_QUEUE = 20         /* Set TCP queue to repair */;
enum TCP_QUEUE_SEQ = 21            /* Set sequence number of repaired queue. */;
enum TCP_REPAIR_OPTIONS = 22       /* Repair TCP connection options */;
enum TCP_FASTOPEN = 23             /* Enable FastOpen on listeners */;
enum TCP_TIMESTAMP = 24            /* TCP time stamp */;
enum TCP_NOTSENT_LOWAT =                                                    \
    25                       /* Limit number of unsent bytes in write queue. \
                              */;
enum TCP_CC_INFO = 26       /* Get Congestion Control (optional) info.  */;
enum TCP_SAVE_SYN = 27      /* Record SYN headers for new connections.  */;
enum TCP_SAVED_SYN = 28     /* Get SYN headers recorded for connection.  */;
enum TCP_REPAIR_WINDOW = 29 /* Get/set window parameters.  */;
enum TCP_FASTOPEN_CONNECT = 30   /* Attempt FastOpen with connect.  */;
enum TCP_ULP = 31                /* Attach a ULP to a TCP connection.  */;
enum TCP_MD5SIG_EXT = 32         /* TCP MD5 Signature with extensions.  */;
enum TCP_FASTOPEN_KEY = 33       /* Set the key for Fast Open (cookie).  */;
enum TCP_FASTOPEN_NO_COOKIE = 34 /* Enable TFO without a TFO cookie.  */;
enum TCP_ZEROCOPY_RECEIVE = 35;
enum TCP_INQ = 36 /* Notify bytes available to read as a cmsg on read.  */;
enum TCP_CM_INQ = TCP_INQ;
enum TCP_TX_DELAY = 37 /* Delay outgoing packets by XX usec.  */;

/* Standard well-defined IP protocols.  */
enum IPPROTO_IP = 0        /* Dummy protocol for TCP.  */;
enum IPPROTO_ICMP = 1      /* Internet Control Message Protocol.  */;
enum IPPROTO_IGMP = 2      /* Internet Group Management Protocol. */;
enum IPPROTO_IPIP = 4      /* IPIP tunnels (older KA9Q tunnels use 94).  */;
enum IPPROTO_TCP = 6       /* Transmission Control Protocol.  */;
enum IPPROTO_EGP = 8       /* Exterior Gateway Protocol.  */;
enum IPPROTO_PUP = 12      /* PUP protocol.  */;
enum IPPROTO_UDP = 17      /* User Datagram Protocol.  */;
enum IPPROTO_IDP = 22      /* XNS IDP protocol.  */;
enum IPPROTO_TP = 29       /* SO Transport Protocol Class 4.  */;
enum IPPROTO_DCCP = 33     /* Datagram Congestion Control Protocol.  */;
enum IPPROTO_IPV6 = 41     /* IPv6 header.  */;
enum IPPROTO_RSVP = 46     /* Reservation Protocol.  */;
enum IPPROTO_GRE = 47      /* General Routing Encapsulation.  */;
enum IPPROTO_ESP = 50      /* encapsulating security payload.  */;
enum IPPROTO_AH = 51       /* authentication header.  */;
enum IPPROTO_MTP = 92      /* Multicast Transport Protocol.  */;
enum IPPROTO_BEETPH = 94   /* IP option pseudo header for BEET.  */;
enum IPPROTO_ENCAP = 98    /* Encapsulation Header.  */;
enum IPPROTO_PIM = 103     /* Protocol Independent Multicast.  */;
enum IPPROTO_COMP = 108    /* Compression Header Protocol.  */;
enum IPPROTO_SCTP = 132    /* Stream Control Transmission Protocol.  */;
enum IPPROTO_UDPLITE = 136 /* UDP-Lite protocol.  */;
enum IPPROTO_MPLS = 137    /* MPLS in IP.  */;
enum IPPROTO_RAW = 255     /* Raw IP packets.  */;

enum IP_ROUTER_ALERT = 5 /* bool */;
enum IP_PKTINFO = 8      /* bool */;
enum IP_PKTOPTIONS = 9;
enum IP_PMTUDISC = 10     /* obsolete name? */;
enum IP_MTU_DISCOVER = 10 /* int; see below */;
enum IP_RECVERR = 11      /* bool */;
enum IP_RECVTTL = 12      /* bool */;
enum IP_RECVTOS = 13      /* bool */;
enum IP_MTU = 14          /* int */;
enum IP_FREEBIND = 15;
enum IP_IPSEC_POLICY = 16;
enum IP_XFRM_POLICY = 17;
enum IP_PASSSEC = 18;
enum IP_TRANSPARENT = 19;
enum IP_MULTICAST_ALL = 49 /* bool */;

/* TProxy original addresses */
enum IP_ORIGDSTADDR = 20;
enum IP_RECVORIGDSTADDR = IP_ORIGDSTADDR;
enum IP_MINTTL = 21;
enum IP_NODEFRAG = 22;
enum IP_CHECKSUM = 23;
enum IP_BIND_ADDRESS_NO_PORT = 24;
enum IP_RECVFRAGSIZE = 25;
enum IP_PMTUDISC_DONT = 0;
enum IP_PMTUDISC_WANT = 1;
enum IP_PMTUDISC_DO = 2;
enum IP_PMTUDISC_PROBE = 3;
enum IP_PMTUDISC_INTERFACE = 4;
enum IP_PMTUDISC_OMIT = 5;
enum IP_MULTICAST_IF = 32;
enum IP_MULTICAST_TTL = 33;
enum IP_MULTICAST_LOOP = 34;
enum IP_ADD_MEMBERSHIP = 35;
enum IP_DROP_MEMBERSHIP = 36;
enum IP_UNBLOCK_SOURCE = 37;
enum IP_BLOCK_SOURCE = 38;
enum IP_ADD_SOURCE_MEMBERSHIP = 39;
enum IP_DROP_SOURCE_MEMBERSHIP = 40;
enum IP_MSFILTER = 41;
enum IP_MULTICAST_ALL = 49;
enum IP_UNICAST_IF = 50;

enum IPV6_ADDRFORM = 1;
enum IPV6_2292PKTINFO = 2;
enum IPV6_2292HOPOPTS = 3;
enum IPV6_2292DSTOPTS = 4;
enum IPV6_2292RTHDR = 5;
enum IPV6_2292PKTOPTIONS = 6;
enum IPV6_CHECKSUM = 7;
enum IPV6_2292HOPLIMIT = 8;

enum SCM_SRCRT = IPV6_RXSRCRT;

enum IPV6_NEXTHOP = 9;
enum IPV6_AUTHHDR = 10;
enum IPV6_UNICAST_HOPS = 16;
enum IPV6_MULTICAST_IF = 17;
enum IPV6_MULTICAST_HOPS = 18;
enum IPV6_MULTICAST_LOOP = 19;
enum IPV6_JOIN_GROUP = 20;
enum IPV6_LEAVE_GROUP = 21;
enum IPV6_ROUTER_ALERT = 22;
enum IPV6_MTU_DISCOVER = 23;
enum IPV6_MTU = 24;
enum IPV6_RECVERR = 25;
enum IPV6_V6ONLY = 26;
enum IPV6_JOIN_ANYCAST = 27;
enum IPV6_LEAVE_ANYCAST = 28;
enum IPV6_MULTICAST_ALL = 29;
enum IPV6_ROUTER_ALERT_ISOLATE = 30;
enum IPV6_IPSEC_POLICY = 34;
enum IPV6_XFRM_POLICY = 35;
enum IPV6_HDRINCL = 36;

/* Advanced API (RFC3542) (1).  */
enum IPV6_RECVPKTINFO = 49;
enum IPV6_PKTINFO = 50;
enum IPV6_RECVHOPLIMIT = 51;
enum IPV6_HOPLIMIT = 52;
enum IPV6_RECVHOPOPTS = 53;
enum IPV6_HOPOPTS = 54;
enum IPV6_RTHDRDSTOPTS = 55;
enum IPV6_RECVRTHDR = 56;
enum IPV6_RTHDR = 57;
enum IPV6_RECVDSTOPTS = 58;
enum IPV6_DSTOPTS = 59;
enum IPV6_RECVPATHMTU = 60;
enum IPV6_PATHMTU = 61;
enum IPV6_DONTFRAG = 62;

/* Advanced API (RFC3542) (2).  */
enum IPV6_RECVTCLASS = 66;
enum IPV6_TCLASS = 67;

enum IPV6_AUTOFLOWLABEL = 70;

/* RFC5014.  */
enum IPV6_ADDR_PREFERENCES = 72;

/* RFC5082.  */
enum IPV6_MINHOPCOUNT = 73;

enum IPV6_ORIGDSTADDR = 74;
enum IPV6_RECVORIGDSTADDR = IPV6_ORIGDSTADDR;
enum IPV6_TRANSPARENT = 75;
enum IPV6_UNICAST_IF = 76;
enum IPV6_RECVFRAGSIZE = 77;
enum IPV6_FREEBIND = 78;

enum SOCK_STREAM = 1;
enum SOCK_DGRAM = 2;

enum MSG_OOB = 0x0001;
enum MSG_PEEK = 0x0002;
enum MSG_DONTROUTE = 0x0004;
enum MSG_CTRUNC = 0x0008;
enum MSG_PROXY = 0x0010;
enum MSG_TRUNC = 0x0020;
enum MSG_DONTWAIT = 0x0040;
enum MSG_EOR = 0x0080;
enum MSG_WAITALL = 0x0100;
enum MSG_FIN = 0x0200;
enum MSG_SYN = 0x0400;
enum MSG_CONFIRM = 0x0800;
enum MSG_RST = 0x1000;
enum MSG_ERRQUEUE = 0x2000;
enum MSG_NOSIGNAL = 0x4000;
enum MSG_MORE = 0x8000;
enum MSG_WAITFORONE = 0x10000;
enum MSG_BATCH = 0x40000;
enum MSG_FASTOPEN = 0x20000000;
enum MSG_CMSG_CLOEXEC = 0x40000000;

enum SHUT_RD = 0;
enum SHUT_WR = 1;
enum SHUT_RDWR = 2;

/* Address families.  */
enum AF_INET = 2   /* IP protocol family.  */;
enum AF_INET6 = 10 /* IP version 6.  */;

/* Standard well-defined IP protocols.  */
enum IPPROTO_TCP = 6 /* Transmission Control Protocol.  */;

/* Types of sockets.  */
enum SOCK_DGRAM = \
    2 /* Connectionless, unreliable datagrams of fixed maximum length.  */;

struct msghdr {
    void* msg_name;
    socklen_t msg_namelen;
    iovec* msg_iov;
    int msg_iovlen;
    void* msg_control;
    socklen_t msg_controllen;
    int msg_flags;
};

/* Internet address.  */
struct in_addr {
    uint s_addr;
};
alias in_addr_t = in_addr;

/* Structure describing an Internet socket address.  */
enum __SOCK_SIZE__ = 16 /* sizeof(struct sockaddr)	*/;
struct sockaddr_in {
    ushort sin_family;
    ushort sin_port;       /* Port number.  */
    in_addr sin_addr; /* Internet address.  */

    /* Pad to size of `struct sockaddr'. */
    uint[__SOCK_SIZE__ - sizeofcast(ushort) - sizeofcast(ushort)
                       - in_addr.sizeof] char__pad;
};

/* Structure used to manipulate the SO_LINGER option.  */
struct linger {
    int l_onoff;  /* Nonzero to linger on close.  */
    int l_linger; /* Time to linger.  */
};

/* Structure describing a generic socket address.  */
struct sockaddr {
    uint sa_family; /* Common data: address family and length.  */
    char[14] sa_data = 0;             /* Address data.  */
};

uint ntohl(uint value);

uint htonl(uint value);

ushort htons(ushort value);

int socket(int domain, int type, int protocol);

int getsockopt(int sockfd, int level, int optname, void* optval, socklen_t* optlen);

int setsockopt(int sockfd, int level, int optname, const(void)* optval, socklen_t optlen);

ssize_t sendmsg(int sockfd, const(msghdr)* msg, int flags);

ssize_t recvmsg(int sockfd, msghdr* msg, int flags);

int shutdown(int sockfd, int how);

version (none) {
}
}

//! #endif /* end of _SGX_SOCKET_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;
public import platform_api_extension;

version (SGX_DISABLE_WASI) {} else {

enum string TRACE_OCALL_FAIL() = ` os_printf("ocall %s failed!\n", __FUNCTION__)`;

/** OCALLs prototypes **/
int ocall_accept(int* p_ret, int sockfd, void* addr, uint* addrlen, uint addr_size);

int ocall_bind(int* p_ret, int sockfd, const(void)* addr, uint addrlen);

int ocall_close(int* p_ret, int fd);

int ocall_connect(int* p_ret, int sockfd, void* addr, uint addrlen);

int ocall_fcntl_long(int* p_ret, int fd, int cmd, c_long arg);

int ocall_getsockname(int* p_ret, int sockfd, void* addr, uint* addrlen, uint addr_size);

int ocall_getpeername(int* p_ret, int sockfd, void* addr, uint* addrlen, uint addr_size);

int ocall_getsockopt(int* p_ret, int sockfd, int level, int optname, void* val_buf, uint val_buf_size, void* len_buf);

int ocall_listen(int* p_ret, int sockfd, int backlog);

int ocall_recv(int* p_ret, int sockfd, void* buf, size_t len, int flags);

int ocall_recvfrom(ssize_t* p_ret, int sockfd, void* buf, size_t len, int flags, void* src_addr, uint* addrlen, uint addr_size);

int ocall_recvmsg(ssize_t* p_ret, int sockfd, void* msg_buf, uint msg_buf_size, int flags);

int ocall_send(int* p_ret, int sockfd, const(void)* buf, size_t len, int flags);

int ocall_sendto(ssize_t* p_ret, int sockfd, const(void)* buf, size_t len, int flags, void* dest_addr, uint addrlen);

int ocall_sendmsg(ssize_t* p_ret, int sockfd, void* msg_buf, uint msg_buf_size, int flags);

int ocall_setsockopt(int* p_ret, int sockfd, int level, int optname, void* optval, uint optlen);

int ocall_shutdown(int* p_ret, int sockfd, int how);

int ocall_socket(int* p_ret, int domain, int type, int protocol);
/** OCALLs prototypes end **/

/** In-enclave implementation of POSIX functions **/
private bool is_little_endian() {
    c_long i = 0x01020304;
    ubyte* c = cast(ubyte*)&i;
    return (*c == 0x04) ? true : false;
}

private void swap32(ubyte* pData) {
    ubyte value = *pData;
    *pData = *(pData + 3);
    *(pData + 3) = value;

    value = *(pData + 1);
    *(pData + 1) = *(pData + 2);
    *(pData + 2) = value;
}

private void swap16(ubyte* pData) {
    ubyte value = *pData;
    *(pData) = *(pData + 1);
    *(pData + 1) = value;
}

uint htonl(uint value) {
    uint ret = void;
    if (is_little_endian()) {
        ret = value;
        swap32(cast(ubyte*)&ret);
        return ret;
    }

    return value;
}

uint ntohl(uint value) {
    return htonl(value);
}

ushort htons(ushort value) {
    ushort ret = void;
    if (is_little_endian()) {
        ret = value;
        swap16(cast(ubyte*)&ret);
        return ret;
    }

    return value;
}

private ushort ntohs(ushort value) {
    return htons(value);
}

/* Coming from musl, under MIT license */
private int hexval(uint c) {
    if (c - '0' < 10)
        return c - '0';
    c |= 32;
    if (c - 'a' < 6)
        return c - 'a' + 10;
    return -1;
}

/* Coming from musl, under MIT license */
private int inet_pton(int af, const(char)* s, void* a0) {
    ushort[8] ip = void;
    ubyte* a = a0;
    int i = void, j = void, v = void, d = void, brk = -1, need_v4 = 0;

    if (af == AF_INET) {
        for (i = 0; i < 4; i++) {
            for (v = j = 0; j < 3 && isdigit(s[j]); j++)
                v = 10 * v + s[j] - '0';
            if (j == 0 || (j > 1 && s[0] == '0') || v > 255)
                return 0;
            a[i] = v;
            if (s[j] == 0 && i == 3)
                return 1;
            if (s[j] != '.')
                return 0;
            s += j + 1;
        }
        return 0;
    }
    else if (af != AF_INET6) {
        errno = EAFNOSUPPORT;
        return -1;
    }

    if (*s == ':' && *++s != ':')
        return 0;

    for (i = 0;; i++) {
        if (s[0] == ':' && brk < 0) {
            brk = i;
            ip[i & 7] = 0;
            if (!*++s)
                break;
            if (i == 7)
                return 0;
            continue;
        }
        for (v = j = 0; j < 4 && (d = hexval(s[j])) >= 0; j++)
            v = 16 * v + d;
        if (j == 0)
            return 0;
        ip[i & 7] = v;
        if (!s[j] && (brk >= 0 || i == 7))
            break;
        if (i == 7)
            return 0;
        if (s[j] != ':') {
            if (s[j] != '.' || (i < 6 && brk < 0))
                return 0;
            need_v4 = 1;
            i++;
            break;
        }
        s += j + 1;
    }
    if (brk >= 0) {
        memmove(ip.ptr + brk + 7 - i, ip.ptr + brk, 2 * (i + 1 - brk));
        for (j = 0; j < 7 - i; j++)
            ip[brk + j] = 0;
    }
    for (j = 0; j < 8; j++) {
        *a++ = ip[j] >> 8;
        *a++ = ip[j];
    }
    if (need_v4 && inet_pton(AF_INET, cast(void*)s, a - 4) <= 0)
        return 0;
    return 1;
}

private int inet_addr(const(char)* p) {
    in_addr a = void;
    if (!inet_pton(AF_INET, p, &a))
        return -1;
    return a.s_addr;
}
/** In-enclave implementation of POSIX functions end **/

private int textual_addr_to_sockaddr(const(char)* textual, int port, sockaddr_in* out_) {
    assert(textual);

    out_.sin_family = AF_INET;
    out_.sin_port = htons(port);
    out_.sin_addr.s_addr = inet_addr(textual);

    return BHT_OK;
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

private int bh_sockaddr_to_sockaddr(const(bh_sockaddr_t)* bh_sockaddr, sockaddr* sockaddr, socklen_t* socklen) {
    if (bh_sockaddr.is_ipv4) {
        sockaddr_in* addr = cast(sockaddr_in*)sockaddr;
        addr.sin_port = htons(bh_sockaddr.port);
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(bh_sockaddr.addr_bufer.ipv4);
        *socklen = typeof(*addr).sizeof;
        return BHT_OK;
    }
    else {
        errno = EAFNOSUPPORT;
        return BHT_ERROR;
    }
}

private int os_socket_setbooloption(bh_socket_t socket, int level, int optname, bool is_enabled) {
    int option = cast(int)is_enabled;
    int ret = void;

    if (ocall_setsockopt(&ret, &socket, level, optname, &option, option.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return BHT_ERROR;
    }

    if (ret != 0) {
        errno = get_errno();
        return BHT_ERROR;
    }

    return BHT_OK;
}

private int os_socket_getbooloption(bh_socket_t socket, int level, int optname, bool* is_enabled) {
    assert(is_enabled);

    int optval = void;
    socklen_t optval_size = optval.sizeof;
    int ret = void;
    if (ocall_getsockopt(&ret, &socket, level, optname, &optval, optval_size,
                         &optval_size)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return BHT_ERROR;
    }

    if (ret != 0) {
        errno = get_errno();
        return BHT_ERROR;
    }

    *is_enabled = cast(bool)optval;
    return BHT_OK;
}

int socket(int domain, int type, int protocol) {
    int ret = void;

    if (ocall_socket(&ret, domain, type, protocol) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int getsockopt(int sockfd, int level, int optname, void* optval, socklen_t* optlen) {
    int ret = void;
    uint val_buf_size = *optlen;

    if (ocall_getsockopt(&ret, sockfd, level, optname, optval, val_buf_size,
                         cast(void*)optlen)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int setsockopt(int sockfd, int level, int optname, const(void)* optval, socklen_t optlen) {
    int ret = void;

    if (ocall_setsockopt(&ret, sockfd, level, optname, cast(void*)optval, optlen)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

ssize_t sendmsg(int sockfd, const(msghdr)* msg, int flags) {
    ssize_t ret = void;
    int i = void;
    char* p = void;
    msghdr* msg1 = void;

    ulong total_size = sizeofcast(msghdr) + cast(ulong)msg.msg_namelen
                        + cast(ulong)msg.msg_controllen;

    total_size += iovec.sizeof * (msg.msg_iovlen);

    for (i = 0; i < msg.msg_iovlen; i++) {
        total_size += msg.msg_iov[i].iov_len;
    }

    if (total_size >= UINT32_MAX)
        return -1;

    msg1 = BH_MALLOC(cast(uint)total_size);

    if (msg1 == null)
        return -1;

    p = cast(char*)cast(uintptr_t)msghdr.sizeof;

    if (msg.msg_name != null) {
        msg1.msg_name = p;
        memcpy(cast(uintptr_t)p + cast(char*)msg1, msg.msg_name,
               cast(size_t)msg.msg_namelen);
        p += msg.msg_namelen;
    }

    if (msg.msg_control != null) {
        msg1.msg_control = p;
        memcpy(cast(uintptr_t)p + cast(char*)msg1, msg.msg_control,
               cast(size_t)msg.msg_control);
        p += msg.msg_controllen;
    }

    if (msg.msg_iov != null) {
        msg1.msg_iov = cast(iovec*)p;
        p += cast(uintptr_t)(iovec.sizeof * (msg.msg_iovlen));

        for (i = 0; i < msg.msg_iovlen; i++) {
            msg1.msg_iov[i].iov_base = p;
            msg1.msg_iov[i].iov_len = msg.msg_iov[i].iov_len;
            memcpy(cast(uintptr_t)p + cast(char*)msg1, msg.msg_iov[i].iov_base,
                   cast(size_t)(msg.msg_iov[i].iov_len));
            p += msg.msg_iov[i].iov_len;
        }
    }

    if (ocall_sendmsg(&ret, sockfd, cast(void*)msg1, cast(uint)total_size, flags)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

ssize_t recvmsg(int sockfd, msghdr* msg, int flags) {
    ssize_t ret = void;
    int i = void;
    char* p = void;
    msghdr* msg1 = void;

    ulong total_size = sizeofcast(msghdr) + cast(ulong)msg.msg_namelen
                        + cast(ulong)msg.msg_controllen;

    total_size += iovec.sizeof * (msg.msg_iovlen);

    for (i = 0; i < msg.msg_iovlen; i++) {
        total_size += msg.msg_iov[i].iov_len;
    }

    if (total_size >= UINT32_MAX)
        return -1;

    msg1 = BH_MALLOC(cast(uint)total_size);

    if (msg1 == null)
        return -1;

    memset(msg1, 0, total_size);

    p = cast(char*)cast(uintptr_t)msghdr.sizeof;

    if (msg.msg_name != null) {
        msg1.msg_name = p;
        p += msg.msg_namelen;
    }

    if (msg.msg_control != null) {
        msg1.msg_control = p;
        p += msg.msg_controllen;
    }

    if (msg.msg_iov != null) {
        msg1.msg_iov = cast(iovec*)p;
        p += cast(uintptr_t)(iovec.sizeof * (msg.msg_iovlen));

        for (i = 0; i < msg.msg_iovlen; i++) {
            msg1.msg_iov[i].iov_base = p;
            msg1.msg_iov[i].iov_len = msg.msg_iov[i].iov_len;
            p += msg.msg_iov[i].iov_len;
        }
    }

    if (ocall_recvmsg(&ret, sockfd, cast(void*)msg1, cast(uint)total_size, flags)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    p = cast(char*)cast(uintptr_t)(msghdr.sizeof);

    if (msg1.msg_name != null) {
        memcpy(msg.msg_name, cast(uintptr_t)p + cast(char*)msg1,
               cast(size_t)msg1.msg_namelen);
        p += msg1.msg_namelen;
    }

    if (msg1.msg_control != null) {
        memcpy(msg.msg_control, cast(uintptr_t)p + cast(char*)msg1,
               cast(size_t)msg1.msg_control);
        p += msg.msg_controllen;
    }

    if (msg1.msg_iov != null) {
        p += cast(uintptr_t)(iovec.sizeof * (msg1.msg_iovlen));

        for (i = 0; i < msg1.msg_iovlen; i++) {
            memcpy(msg.msg_iov[i].iov_base, cast(uintptr_t)p + cast(char*)msg1,
                   cast(size_t)(msg1.msg_iov[i].iov_len));
            p += msg1.msg_iov[i].iov_len;
        }
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int shutdown(int sockfd, int how) {
    int ret = void;

    if (ocall_shutdown(&ret, sockfd, how) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int os_socket_accept(bh_socket_t server_sock, bh_socket_t* sock, void* addr, uint* addrlen) {
    sockaddr addr_tmp = void;
    uint len = sockaddr.sizeof;

    if (ocall_accept(sock, server_sock, &addr_tmp, &len, len) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (*sock < 0) {
        errno = get_errno();
        return BHT_ERROR;
    }

    return BHT_OK;
}
int os_socket_bind(bh_socket_t socket, const(char)* host, int* port) {
    sockaddr_in addr = void;
    linger ling = void;
    uint socklen = void;
    int ret = void;

    assert(host);
    assert(port);

    ling.l_onoff = 1;
    ling.l_linger = 0;

    if (ocall_fcntl_long(&ret, &socket, F_SETFD, FD_CLOEXEC) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret < 0) {
        goto fail;
    }

    if (ocall_setsockopt(&ret, &socket, SOL_SOCKET, SO_LINGER, &ling,
                         ling.sizeof)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret < 0) {
        goto fail;
    }

    addr.sin_addr.s_addr = inet_addr(host);
    addr.sin_port = htons(*port);
    addr.sin_family = AF_INET;

    if (ocall_bind(&ret, &socket, &addr, addr.sizeof) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret < 0) {
        goto fail;
    }

    socklen = addr.sizeof;

    if (ocall_getsockname(&ret, &socket, cast(void*)&addr, &socklen, socklen)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1) {
        goto fail;
    }

    *port = ntohs(addr.sin_port);

    return BHT_OK;

fail:
    errno = get_errno();
    return BHT_ERROR;
}

int os_socket_close(bh_socket_t socket) {
    int ret = void;

    if (ocall_close(&ret, &socket) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int os_socket_connect(bh_socket_t socket, const(char)* addr, int port) {
    sockaddr_in addr_in = { 0 };
    socklen_t addr_len = sockaddr_in.sizeof;
    int ret = 0;

    if ((ret = textual_addr_to_sockaddr(addr, port, &addr_in)) < 0) {
        return ret;
    }

    if (ocall_connect(&ret, &socket, &addr_in, addr_len) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
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
        if (ocall_socket(sock, af, SOCK_STREAM, IPPROTO_TCP) != SGX_SUCCESS) {
            TRACE_OCALL_FAIL();
            return -1;
        }
    }
    else {
        if (ocall_socket(sock, af, SOCK_DGRAM, 0) != SGX_SUCCESS) {
            TRACE_OCALL_FAIL();
            return -1;
        }
    }

    if (*sock == -1) {
        errno = get_errno();
        return BHT_ERROR;
    }

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

int os_socket_listen(bh_socket_t socket, int max_client) {
    int ret = void;

    if (ocall_listen(&ret, &socket, max_client) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int os_socket_recv(bh_socket_t socket, void* buf, uint len) {
    int ret = void;

    if (ocall_recv(&ret, &socket, buf, len, 0) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        errno = ENOSYS;
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int os_socket_recv_from(bh_socket_t socket, void* buf, uint len, int flags, bh_sockaddr_t* src_addr) {
    sockaddr_in addr = void;
    socklen_t addr_len = addr.sizeof;
    ssize_t ret = void;

    if (ocall_recvfrom(&ret, &socket, buf, len, flags, &addr, &addr_len,
                       addr_len)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        errno = ENOSYS;
        return -1;
    }

    if (ret < 0) {
        errno = get_errno();
        return ret;
    }

    if (src_addr && addr_len > 0) {
        if (sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr, addr_len,
                                    src_addr)
            == BHT_ERROR) {
            return -1;
        }
    }

    return ret;
}

int os_socket_send(bh_socket_t socket, const(void)* buf, uint len) {
    int ret = void;

    if (ocall_send(&ret, &socket, buf, len, 0) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        errno = ENOSYS;
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

int os_socket_send_to(bh_socket_t socket, const(void)* buf, uint len, int flags, const(bh_sockaddr_t)* dest_addr) {
    sockaddr_in addr = void;
    socklen_t addr_len = void;
    ssize_t ret = void;

    if (bh_sockaddr_to_sockaddr(dest_addr, cast(sockaddr*)&addr, &addr_len)
        == BHT_ERROR) {
        return -1;
    }

    if (ocall_sendto(&ret, &socket, buf, len, flags, cast(sockaddr*)&addr,
                     addr_len)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        errno = ENOSYS;
        return -1;
    }

    if (ret == -1) {
        errno = get_errno();
    }

    return ret;
}

int os_socket_shutdown(bh_socket_t socket) {
    return shutdown(&socket, O_RDWR);
}

int os_socket_addr_resolve(const(char)* host, const(char)* service, ubyte* hint_is_tcp, ubyte* hint_is_ipv4, bh_addr_info_t* addr_info, size_t addr_info_size, size_t* max_info_size) {
    errno = ENOSYS;

    return BHT_ERROR;
}

int os_socket_addr_local(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    sockaddr_in addr = void;
    socklen_t addr_len = addr.sizeof;
    int ret = void;

    if (ocall_getsockname(&ret, &socket, cast(sockaddr*)&addr, &addr_len,
                          addr_len)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return BHT_ERROR;
    }

    if (ret != BHT_OK) {
        errno = get_errno();
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr, addr_len,
                                   sockaddr);
}

int os_socket_addr_remote(bh_socket_t socket, bh_sockaddr_t* sockaddr) {
    sockaddr_in addr = void;
    socklen_t addr_len = addr.sizeof;
    int ret = void;

    if (ocall_getpeername(&ret, &socket, cast(void*)&addr, &addr_len, addr_len)
        != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret != BHT_OK) {
        errno = get_errno();
        return BHT_ERROR;
    }

    return sockaddr_to_bh_sockaddr(cast(sockaddr*)&addr, addr_len,
                                   sockaddr);
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
    return os_socket_setbooloption(&socket, SOL_SOCKET, SO_KEEPALIVE,
                                   is_enabled);
}

int os_socket_get_keep_alive(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, SOL_SOCKET, SO_KEEPALIVE,
                                   is_enabled);
}

int os_socket_set_reuse_addr(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(&socket, SOL_SOCKET, SO_REUSEADDR,
                                   is_enabled);
}

int os_socket_get_reuse_addr(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, SOL_SOCKET, SO_REUSEADDR,
                                   is_enabled);
}

int os_socket_set_reuse_port(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(&socket, SOL_SOCKET, SO_REUSEPORT,
                                   is_enabled);
}

int os_socket_get_reuse_port(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, SOL_SOCKET, SO_REUSEPORT,
                                   is_enabled);
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
    return os_socket_setbooloption(&socket, IPPROTO_TCP, TCP_NODELAY,
                                   is_enabled);
}

int os_socket_get_tcp_no_delay(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, IPPROTO_TCP, TCP_NODELAY,
                                   is_enabled);
}

int os_socket_set_tcp_quick_ack(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(&socket, IPPROTO_TCP, TCP_QUICKACK,
                                   is_enabled);
}

int os_socket_get_tcp_quick_ack(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, IPPROTO_TCP, TCP_QUICKACK,
                                   is_enabled);
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
    return os_socket_setbooloption(&socket, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
                                   is_enabled);
}

int os_socket_get_tcp_fastopen_connect(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
                                   is_enabled);
}

int os_socket_set_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool is_enabled) {
    if (ipv6) {
        return os_socket_setbooloption(&socket, IPPROTO_IPV6,
                                       IPV6_MULTICAST_LOOP, is_enabled);
    }
    else {
        return os_socket_setbooloption(&socket, IPPROTO_IP, IP_MULTICAST_LOOP,
                                       is_enabled);
    }
}

int os_socket_get_ip_multicast_loop(bh_socket_t socket, bool ipv6, bool* is_enabled) {
    if (ipv6) {
        return os_socket_getbooloption(&socket, IPPROTO_IPV6,
                                       IPV6_MULTICAST_LOOP, is_enabled);
    }
    else {
        return os_socket_getbooloption(&socket, IPPROTO_IP, IP_MULTICAST_LOOP,
                                       is_enabled);
    }
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

int os_socket_set_ipv6_only(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(&socket, IPPROTO_IPV6, IPV6_V6ONLY,
                                   is_enabled);
}

int os_socket_get_ipv6_only(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, IPPROTO_IPV6, IPV6_V6ONLY,
                                   is_enabled);
}

int os_socket_set_broadcast(bh_socket_t socket, bool is_enabled) {
    return os_socket_setbooloption(&socket, SOL_SOCKET, SO_BROADCAST,
                                   is_enabled);
}

int os_socket_get_broadcast(bh_socket_t socket, bool* is_enabled) {
    return os_socket_getbooloption(&socket, SOL_SOCKET, SO_BROADCAST,
                                   is_enabled);
}

}
