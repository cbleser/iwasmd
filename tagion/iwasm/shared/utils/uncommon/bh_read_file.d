module bh_read_file;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_FILE_H
version = _BH_FILE_H;

public import bh_platform;

#ifdef __cplusplus
extern "C" {
//! #endif

char* bh_read_file_to_buffer(const(char)* filename, uint* ret_size);

version (none) {
}
}

//! #endif /* end of _BH_FILE_H */
public import bh_read_file;

public import core.sys.posix.sys.stat;
public import core.sys.posix.fcntl;
static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {
public import io;
} else {
public import core.sys.posix.unistd;
}

static if (HasVersion!"Windows" || HasVersion!"_WIN32_") {

static if (HasVersion!"Windows" && !HasVersion!"_SH_DENYNO") {
enum _SH_DENYNO = 0x40;
}

char* bh_read_file_to_buffer(const(char)* filename, uint* ret_size) {
    char* buffer = void;
    int file = void;
    uint file_size = void, buf_size = void, read_size = void;
    stat stat_buf = void;

    if (!filename || !ret_size) {
        printf("Read file to buffer failed: invalid filename or ret size.\n");
        return null;
    }

    if (_sopen_s(&file, filename, _O_RDONLY | _O_BINARY, _SH_DENYNO, 0)) {
        printf("Read file to buffer failed: open file %s failed.\n", filename);
        return null;
    }

    if (fstat(file, &stat_buf) != 0) {
        printf("Read file to buffer failed: fstat file %s failed.\n", filename);
        _close(file);
        return null;
    }
    file_size = cast(uint)stat_buf.st_size;

    /* At lease alloc 1 byte to avoid malloc failed */
    buf_size = file_size > 0 ? file_size : 1;

    if (((buffer = cast(char*)BH_MALLOC(buf_size)) == 0)) {
        printf("Read file to buffer failed: alloc memory failed.\n");
        _close(file);
        return null;
    }
static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    printf("Read file, total size: %u\n", file_size);
}

    read_size = _read(file, buffer, file_size);
    _close(file);

    if (read_size < file_size) {
        printf("Read file to buffer failed: read file content failed.\n");
        BH_FREE(buffer);
        return null;
    }

    *ret_size = file_size;
    return buffer;
}
} else { /* else of defined(_WIN32) || defined(_WIN32_) */
char* bh_read_file_to_buffer(const(char)* filename, uint* ret_size) {
    char* buffer = void;
    int file = void;
    uint file_size = void, buf_size = void, read_size = void;
    stat stat_buf = void;

    if (!filename || !ret_size) {
        printf("Read file to buffer failed: invalid filename or ret size.\n");
        return null;
    }

    if ((file = open(filename, O_RDONLY, 0)) == -1) {
        printf("Read file to buffer failed: open file %s failed.\n", filename);
        return null;
    }

    if (fstat(file, &stat_buf) != 0) {
        printf("Read file to buffer failed: fstat file %s failed.\n", filename);
        close(file);
        return null;
    }

    file_size = cast(uint)stat_buf.st_size;

    /* At lease alloc 1 byte to avoid malloc failed */
    buf_size = file_size > 0 ? file_size : 1;

    if (((buffer = BH_MALLOC(buf_size)) == 0)) {
        printf("Read file to buffer failed: alloc memory failed.\n");
        close(file);
        return null;
    }
static if (WASM_ENABLE_MEMORY_TRACING != 0) {
    printf("Read file, total size: %u\n", file_size);
}

    read_size = cast(uint)read(file, buffer, file_size);
    close(file);

    if (read_size < file_size) {
        printf("Read file to buffer failed: read file content failed.\n");
        BH_FREE(buffer);
        return null;
    }

    *ret_size = file_size;
    return buffer;
}
} /* end of defined(_WIN32) || defined(_WIN32_) */
