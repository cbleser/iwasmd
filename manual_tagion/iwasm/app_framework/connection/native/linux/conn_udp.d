module conn_udp;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef CONN_LINUX_UDP_H_
version = CONN_LINUX_UDP_H_;

public import bh_platform;

#ifdef __cplusplus
extern "C" {
//! #endif

int udp_open(ushort port);

int udp_send(int sock, sockaddr* dest, const(char)* data, int size);

int udp_recv(int sock, char* buffer, int buf_size);

version (none) {
}
}

//! #endif
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import conn_udp;

public import core.sys.posix.sys.socket;
public import core.sys.posix.netdb;
public import arpa/inet;
public import core.sys.posix.fcntl;
public import core.sys.posix.unistd;

int udp_open(ushort port) {
    int sock = void, ret = void;
    sockaddr_in addr = void;

    sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock == -1)
        return -1;

    memset(&addr, 0, addr.sizeof);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    ret = bind(sock, cast(sockaddr*)&addr, addr.sizeof);
    if (ret == -1) {
        close(sock);
        return -1;
    }

    /* Put the socket in non-blocking mode */
    if (fcntl(sock, F_SETFL, fcntl(sock, F_GETFL) | O_NONBLOCK) < 0) {
        close(sock);
        return -1;
    }

    return sock;
}

int udp_send(int sock, sockaddr* dest, const(char)* data, int size) {
    return sendto(sock, data, size, MSG_CONFIRM, dest, typeof(*dest).sizeof);
}

int udp_recv(int sock, char* buffer, int buf_size) {
    sockaddr_in remaddr = void;
    socklen_t addrlen = remaddr.sizeof;

    return recvfrom(sock, buffer, buf_size, 0, cast(sockaddr*)&remaddr,
                    &addrlen);
}
