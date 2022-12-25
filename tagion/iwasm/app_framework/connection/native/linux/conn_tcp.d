module conn_tcp;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef CONN_LINUX_TCP_H_
version = CONN_LINUX_TCP_H_;

public import bh_platform;

#ifdef __cplusplus
extern "C" {
//! #endif

int tcp_open(char* address, ushort port);

int tcp_send(int sock, const(char)* data, int size);

int tcp_recv(int sock, char* buffer, int buf_size);

version (none) {
}
}

//! #endif
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import conn_tcp;

public import core.sys.posix.sys.socket;
public import core.sys.posix.netdb;
public import arpa/inet;
public import core.sys.posix.fcntl;
public import core.sys.posix.unistd;

int tcp_open(char* address, ushort port) {
    int sock = void, ret = void;
    sockaddr_in servaddr = void;

    memset(&servaddr, 0, servaddr.sizeof);
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = inet_addr(address);
    servaddr.sin_port = htons(port);

    sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == -1)
        return -1;

    ret = connect(sock, cast(sockaddr*)&servaddr, servaddr.sizeof);
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

int tcp_send(int sock, const(char)* data, int size) {
    return send(sock, data, size, 0);
}

int tcp_recv(int sock, char* buffer, int buf_size) {
    return recv(sock, buffer, buf_size, 0);
}
