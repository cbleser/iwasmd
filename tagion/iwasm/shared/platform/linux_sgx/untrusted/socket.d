module socket;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
public import core.sys.posix.sys.types;
public import core.sys.posix.sys.socket;
public import core.stdc.stdint;
public import core.stdc.stddef;
public import netinet/in;
public import arpa/inet;

int ocall_socket(int domain, int type, int protocol) {
    return socket(domain, type, protocol);
}

int ocall_getsockopt(int sockfd, int level, int optname, void* val_buf, uint val_buf_size, void* len_buf) {
    return getsockopt(sockfd, level, optname, val_buf, cast(socklen_t*)len_buf);
}

ssize_t ocall_sendmsg(int sockfd, void* msg_buf, uint msg_buf_size, int flags) {
    msghdr* msg = cast(msghdr*)msg_buf;
    int i = void;
    ssize_t ret = void;

    if (msg.msg_name != null)
        msg.msg_name = msg_buf + cast(uint)cast(uintptr_t)msg.msg_name;

    if (msg.msg_control != null)
        msg.msg_control = msg_buf + cast(uint)cast(uintptr_t)msg.msg_control;

    if (msg.msg_iov != null) {
        msg.msg_iov = msg_buf + cast(uint)cast(uintptr_t)msg.msg_iov;
        for (i = 0; i < msg.msg_iovlen; i++) {
            msg.msg_iov[i].iov_base =
                msg_buf + cast(uint)cast(uintptr_t)msg.msg_iov[i].iov_base;
        }
    }

    return sendmsg(sockfd, msg, flags);
}

ssize_t ocall_recvmsg(int sockfd, void* msg_buf, uint msg_buf_size, int flags) {
    msghdr* msg = cast(msghdr*)msg_buf;
    int i = void;
    ssize_t ret = void;

    if (msg.msg_name != null)
        msg.msg_name = msg_buf + cast(uint)cast(uintptr_t)msg.msg_name;

    if (msg.msg_control != null)
        msg.msg_control = msg_buf + cast(uint)cast(uintptr_t)msg.msg_control;

    if (msg.msg_iov != null) {
        msg.msg_iov = msg_buf + cast(uint)cast(uintptr_t)msg.msg_iov;
        for (i = 0; i < msg.msg_iovlen; i++) {
            msg.msg_iov[i].iov_base =
                msg_buf + cast(uint)cast(uintptr_t)msg.msg_iov[i].iov_base;
        }
    }

    return recvmsg(sockfd, msg, flags);
}

int ocall_shutdown(int sockfd, int how) {
    return shutdown(sockfd, how);
}

int ocall_setsockopt(int sockfd, int level, int optname, void* optval, uint optlen) {
    return setsockopt(sockfd, level, optname, optval, optlen);
}

int ocall_bind(int sockfd, const(void)* addr, uint addrlen) {
    return bind(sockfd, cast(const(sockaddr)*)addr, addrlen);
}

int ocall_getsockname(int sockfd, void* addr, uint* addrlen, uint addr_size) {
    return getsockname(sockfd, cast(sockaddr*)addr, addrlen);
}

int ocall_getpeername(int sockfd, void* addr, uint* addrlen, uint addr_size) {
    return getpeername(sockfd, cast(sockaddr*)addr, addrlen);
}

int ocall_listen(int sockfd, int backlog) {
    return listen(sockfd, backlog);
}

int ocall_accept(int sockfd, void* addr, uint* addrlen, uint addr_size) {
    return accept(sockfd, cast(sockaddr*)addr, addrlen);
}

int ocall_recv(int sockfd, void* buf, size_t len, int flags) {
    return recv(sockfd, buf, len, flags);
}

ssize_t ocall_recvfrom(int sockfd, void* buf, size_t len, int flags, void* src_addr, uint* addrlen, uint addr_size) {
    return recvfrom(sockfd, buf, len, flags, cast(sockaddr*)src_addr,
                    addrlen);
}

int ocall_send(int sockfd, const(void)* buf, size_t len, int flags) {
    return send(sockfd, buf, len, flags);
}

ssize_t ocall_sendto(int sockfd, const(void)* buf, size_t len, int flags, void* dest_addr, uint addrlen) {
    return sendto(sockfd, buf, len, flags, cast(sockaddr*)dest_addr,
                  addrlen);
}

int ocall_connect(int sockfd, void* addr, uint addrlen) {
    return connect(sockfd, cast(const(sockaddr)*)addr, addrlen);
}