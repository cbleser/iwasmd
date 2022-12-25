module libc_uvwasi_wrapper;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import uvwasi;
public import bh_platform;
public import wasm_export;

/* clang-format off */
enum string get_module_inst(string exec_env) = ` \
    wasm_runtime_get_module_inst(exec_env)`;

enum string validate_app_addr(string offset, string size) = ` \
    wasm_runtime_validate_app_addr(module_inst, offset, size)`;

enum string validate_native_addr(string addr, string size) = ` \
    wasm_runtime_validate_native_addr(module_inst, addr, size)`;

enum string addr_app_to_native(string offset) = ` \
    wasm_runtime_addr_app_to_native(module_inst, offset)`;

enum string addr_native_to_app(string ptr) = ` \
    wasm_runtime_addr_native_to_app(module_inst, ptr)`;

enum string module_malloc(string size, string p_native_addr) = ` \
    wasm_runtime_module_malloc(module_inst, size, p_native_addr)`;

enum string module_free(string offset) = ` \
    wasm_runtime_module_free(module_inst, offset)`;
/* clang-format on */

enum wasi_errno_t = uvwasi_errno_t;
enum wasi_fd_t = uvwasi_fd_t;
enum wasi_clockid_t = uvwasi_clockid_t;
enum wasi_timestamp_t = uvwasi_timestamp_t;
enum wasi_filesize_t = uvwasi_filesize_t;
enum wasi_prestat_app_t = uvwasi_prestat_app_t;
enum wasi_filedelta_t = uvwasi_filedelta_t;
enum wasi_whence_t = uvwasi_whence_t;
enum wasi_fdflags_t = uvwasi_fdflags_t;
enum wasi_rights_t = uvwasi_rights_t;
enum wasi_advice_t = uvwasi_advice_t;
enum wasi_lookupflags_t = uvwasi_lookupflags_t;
enum wasi_preopentype_t = uvwasi_preopentype_t;
enum wasi_fdstat_t = uvwasi_fdstat_t;
enum wasi_oflags_t = uvwasi_oflags_t;
enum wasi_dircookie_t = uvwasi_dircookie_t;
enum wasi_filestat_t = uvwasi_filestat_t;
enum wasi_fstflags_t = uvwasi_fstflags_t;
enum wasi_subscription_t = uvwasi_subscription_t;
enum wasi_event_t = uvwasi_event_t;
enum wasi_exitcode_t = uvwasi_exitcode_t;
enum wasi_signal_t = uvwasi_signal_t;
enum wasi_riflags_t = uvwasi_riflags_t;
enum wasi_roflags_t = uvwasi_roflags_t;
enum wasi_siflags_t = uvwasi_siflags_t;
enum wasi_sdflags_t = uvwasi_sdflags_t;
enum wasi_iovec_t = uvwasi_iovec_t;
enum wasi_ciovec_t = uvwasi_ciovec_t;

struct wasi_prestat_app {
    wasi_preopentype_t pr_type;
    uint pr_name_len;
}alias wasi_prestat_app_t = wasi_prestat_app;

struct iovec_app {
    uint buf_offset;
    uint buf_len;
}alias iovec_app_t = iovec_app;

struct WASIContext {
    uvwasi_t uvwasi;
    uint exit_code;
}

void* wasm_runtime_get_wasi_ctx(wasm_module_inst_t module_inst);

private uvwasi_t* get_wasi_ctx(wasm_module_inst_t module_inst) {
    WASIContext* ctx = wasm_runtime_get_wasi_ctx(module_inst);
    if (ctx == null) {
        return null;
    }
    return &ctx.uvwasi;
}

private wasi_errno_t wasi_args_get(wasm_exec_env_t exec_env, uint* argv_offsets, char* argv_buf) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t argc = void, argv_buf_size = void, i = void;
    char** argv = void;
    ulong total_size = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    err = uvwasi_args_sizes_get(uvwasi, &argc, &argv_buf_size);
    if (err)
        return err;

    total_size = sizeof(int32) * (cast(ulong)argc + 1);
    if (total_size >= UINT32_MAX
        || !validate_native_addr(argv_offsets, cast(uint)total_size)
        || argv_buf_size >= UINT32_MAX
        || !validate_native_addr(argv_buf, cast(uint)argv_buf_size))
        return (wasi_errno_t)-1;

    total_size = (char*).sizeof * (cast(ulong)argc + 1);
    if (total_size >= UINT32_MAX
        || ((argv = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    err = uvwasi_args_get(uvwasi, argv, argv_buf);
    if (err) {
        wasm_runtime_free(argv);
        return err;
    }

    for (i = 0; i < argc; i++)
        argv_offsets[i] = addr_native_to_app(argv[i]);

    wasm_runtime_free(argv);
    return 0;
}

private wasi_errno_t wasi_args_sizes_get(wasm_exec_env_t exec_env, uint* argc_app, uint* argv_buf_size_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t argc = void, argv_buf_size = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(argc_app, uint32.sizeof)
        || !validate_native_addr(argv_buf_size_app, uint32.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_args_sizes_get(uvwasi, &argc, &argv_buf_size);
    if (err)
        return err;

    *argc_app = cast(uint)argc;
    *argv_buf_size_app = cast(uint)argv_buf_size;
    return 0;
}

private wasi_errno_t wasi_clock_res_get(wasm_exec_env_t exec_env, wasi_clockid_t clock_id, wasi_timestamp_t* resolution) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!validate_native_addr(resolution, wasi_timestamp_t.sizeof))
        return (wasi_errno_t)-1;

    return uvwasi_clock_res_get(uvwasi, clock_id, resolution);
}

private wasi_errno_t wasi_clock_time_get(wasm_exec_env_t exec_env, wasi_clockid_t clock_id, wasi_timestamp_t precision, wasi_timestamp_t* time) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!validate_native_addr(time, wasi_timestamp_t.sizeof))
        return (wasi_errno_t)-1;

    return uvwasi_clock_time_get(uvwasi, clock_id, precision, time);
}

private wasi_errno_t wasi_environ_get(wasm_exec_env_t exec_env, uint* environ_offsets, char* environ_buf) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t environ_count = void, environ_buf_size = void, i = void;
    ulong total_size = void;
    char** environs = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    err = uvwasi_environ_sizes_get(uvwasi, &environ_count, &environ_buf_size);
    if (err)
        return err;

    if (environ_count == 0)
        return 0;

    total_size = sizeof(int32) * (cast(ulong)environ_count + 1);
    if (total_size >= UINT32_MAX
        || !validate_native_addr(environ_offsets, cast(uint)total_size)
        || environ_buf_size >= UINT32_MAX
        || !validate_native_addr(environ_buf, cast(uint)environ_buf_size))
        return (wasi_errno_t)-1;

    total_size = (char*).sizeof * ((cast(ulong)environ_count + 1));

    if (total_size >= UINT32_MAX
        || ((environs = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    err = uvwasi_environ_get(uvwasi, environs, environ_buf);
    if (err) {
        wasm_runtime_free(environs);
        return err;
    }

    for (i = 0; i < environ_count; i++)
        environ_offsets[i] = addr_native_to_app(environs[i]);

    wasm_runtime_free(environs);
    return 0;
}

private wasi_errno_t wasi_environ_sizes_get(wasm_exec_env_t exec_env, uint* environ_count_app, uint* environ_buf_size_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t environ_count = void, environ_buf_size = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(environ_count_app, uint32.sizeof)
        || !validate_native_addr(environ_buf_size_app, uint32.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_environ_sizes_get(uvwasi, &environ_count, &environ_buf_size);
    if (err)
        return err;

    *environ_count_app = cast(uint)environ_count;
    *environ_buf_size_app = cast(uint)environ_buf_size;
    return 0;
}

private wasi_errno_t wasi_fd_prestat_get(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_prestat_app_t* prestat_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_prestat_t prestat = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(prestat_app, wasi_prestat_app_t.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_fd_prestat_get(uvwasi, fd, &prestat);
    if (err)
        return err;

    prestat_app.pr_type = prestat.pr_type;
    prestat_app.pr_name_len = cast(uint)prestat.u.dir.pr_name_len;
    return 0;
}

private wasi_errno_t wasi_fd_prestat_dir_name(wasm_exec_env_t exec_env, wasi_fd_t fd, char* path, uint path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_prestat_dir_name(uvwasi, fd, path, path_len);
}

private wasi_errno_t wasi_fd_close(wasm_exec_env_t exec_env, wasi_fd_t fd) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_close(uvwasi, fd);
}

private wasi_errno_t wasi_fd_datasync(wasm_exec_env_t exec_env, wasi_fd_t fd) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_datasync(uvwasi, fd);
}

private wasi_errno_t wasi_fd_pread(wasm_exec_env_t exec_env, wasi_fd_t fd, iovec_app_t* iovec_app, uint iovs_len, wasi_filesize_t offset, uint* nread_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_iovec_t* iovec = void, iovec_begin = void;
    ulong total_size = void;
    uvwasi_size_t nread = void;
    uint i = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    total_size = sizeof(iovec_app_t) * cast(ulong)iovs_len;
    if (!validate_native_addr(nread_app, cast(uint)uint32.sizeof)
        || total_size >= UINT32_MAX
        || !validate_native_addr(iovec_app, cast(uint)total_size))
        return (wasi_errno_t)-1;

    total_size = sizeof(wasi_iovec_t) * cast(ulong)iovs_len;
    if (total_size >= UINT32_MAX
        || ((iovec_begin = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    iovec = iovec_begin;
    for (i = 0; i < iovs_len; i++, iovec_app++, iovec++) {
        if (!validate_app_addr(iovec_app.buf_offset, iovec_app.buf_len)) {
            err = (wasi_errno_t)-1;
            goto fail;
        }
        iovec.buf = cast(void*)addr_app_to_native(iovec_app.buf_offset);
        iovec.buf_len = iovec_app.buf_len;
    }

    err = uvwasi_fd_pread(uvwasi, fd, iovec_begin, iovs_len, offset, &nread);
    if (err)
        goto fail;

    *nread_app = cast(uint)nread;

    /* success */
    err = 0;

fail:
    wasm_runtime_free(iovec_begin);
    return err;
}

private wasi_errno_t wasi_fd_pwrite(wasm_exec_env_t exec_env, wasi_fd_t fd, const(iovec_app_t)* iovec_app, uint iovs_len, wasi_filesize_t offset, uint* nwritten_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_ciovec_t* ciovec = void, ciovec_begin = void;
    ulong total_size = void;
    uvwasi_size_t nwritten = void;
    uint i = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    total_size = sizeof(iovec_app_t) * cast(ulong)iovs_len;
    if (!validate_native_addr(nwritten_app, cast(uint)uint32.sizeof)
        || total_size >= UINT32_MAX
        || !validate_native_addr(cast(void*)iovec_app, cast(uint)total_size))
        return (wasi_errno_t)-1;

    total_size = sizeof(wasi_ciovec_t) * cast(ulong)iovs_len;
    if (total_size >= UINT32_MAX
        || ((ciovec_begin = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    ciovec = ciovec_begin;
    for (i = 0; i < iovs_len; i++, iovec_app++, ciovec++) {
        if (!validate_app_addr(iovec_app.buf_offset, iovec_app.buf_len)) {
            err = (wasi_errno_t)-1;
            goto fail;
        }
        ciovec.buf = cast(char*)addr_app_to_native(iovec_app.buf_offset);
        ciovec.buf_len = iovec_app.buf_len;
    }

    err =
        uvwasi_fd_pwrite(uvwasi, fd, ciovec_begin, iovs_len, offset, &nwritten);
    if (err)
        goto fail;

    *nwritten_app = cast(uint)nwritten;

    /* success */
    err = 0;

fail:
    wasm_runtime_free(ciovec_begin);
    return err;
}

private wasi_errno_t wasi_fd_read(wasm_exec_env_t exec_env, wasi_fd_t fd, const(iovec_app_t)* iovec_app, uint iovs_len, uint* nread_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_iovec_t* iovec = void, iovec_begin = void;
    ulong total_size = void;
    uvwasi_size_t nread = void;
    uint i = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    total_size = sizeof(iovec_app_t) * cast(ulong)iovs_len;
    if (!validate_native_addr(nread_app, cast(uint)uint32.sizeof)
        || total_size >= UINT32_MAX
        || !validate_native_addr(cast(void*)iovec_app, cast(uint)total_size))
        return (wasi_errno_t)-1;

    total_size = sizeof(wasi_iovec_t) * cast(ulong)iovs_len;
    if (total_size >= UINT32_MAX
        || ((iovec_begin = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    iovec = iovec_begin;
    for (i = 0; i < iovs_len; i++, iovec_app++, iovec++) {
        if (!validate_app_addr(iovec_app.buf_offset, iovec_app.buf_len)) {
            err = (wasi_errno_t)-1;
            goto fail;
        }
        iovec.buf = cast(void*)addr_app_to_native(iovec_app.buf_offset);
        iovec.buf_len = iovec_app.buf_len;
    }

    err = uvwasi_fd_read(uvwasi, fd, iovec_begin, iovs_len, &nread);
    if (err)
        goto fail;

    *nread_app = cast(uint)nread;

    /* success */
    err = 0;

fail:
    wasm_runtime_free(iovec_begin);
    return err;
}

private wasi_errno_t wasi_fd_renumber(wasm_exec_env_t exec_env, wasi_fd_t from, wasi_fd_t to) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_renumber(uvwasi, from, to);
}

private wasi_errno_t wasi_fd_seek(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_filedelta_t offset, wasi_whence_t whence, wasi_filesize_t* newoffset) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(newoffset, wasi_filesize_t.sizeof))
        return (wasi_errno_t)-1;

    return uvwasi_fd_seek(uvwasi, fd, offset, whence, newoffset);
}

private wasi_errno_t wasi_fd_tell(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_filesize_t* newoffset) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(newoffset, wasi_filesize_t.sizeof))
        return (wasi_errno_t)-1;

    return uvwasi_fd_tell(uvwasi, fd, newoffset);
}

private wasi_errno_t wasi_fd_fdstat_get(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_fdstat_t* fdstat_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_fdstat_t fdstat = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(fdstat_app, wasi_fdstat_t.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_fd_fdstat_get(uvwasi, fd, &fdstat);
    if (err)
        return err;

    memcpy(fdstat_app, &fdstat, wasi_fdstat_t.sizeof);
    return 0;
}

private wasi_errno_t wasi_fd_fdstat_set_flags(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_fdflags_t flags) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_fdstat_set_flags(uvwasi, fd, flags);
}

private wasi_errno_t wasi_fd_fdstat_set_rights(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_rights_t fs_rights_base, wasi_rights_t fs_rights_inheriting) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_fdstat_set_rights(uvwasi, fd, fs_rights_base,
                                       fs_rights_inheriting);
}

private wasi_errno_t wasi_fd_sync(wasm_exec_env_t exec_env, wasi_fd_t fd) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_sync(uvwasi, fd);
}

private wasi_errno_t wasi_fd_write(wasm_exec_env_t exec_env, wasi_fd_t fd, const(iovec_app_t)* iovec_app, uint iovs_len, uint* nwritten_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_ciovec_t* ciovec = void, ciovec_begin = void;
    ulong total_size = void;
    uvwasi_size_t nwritten = void;
    uint i = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    total_size = sizeof(iovec_app_t) * cast(ulong)iovs_len;
    if (!validate_native_addr(nwritten_app, cast(uint)uint32.sizeof)
        || total_size >= UINT32_MAX
        || !validate_native_addr(cast(void*)iovec_app, cast(uint)total_size))
        return (wasi_errno_t)-1;

    total_size = sizeof(wasi_ciovec_t) * cast(ulong)iovs_len;
    if (total_size >= UINT32_MAX
        || ((ciovec_begin = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    ciovec = ciovec_begin;
    for (i = 0; i < iovs_len; i++, iovec_app++, ciovec++) {
        if (!validate_app_addr(iovec_app.buf_offset, iovec_app.buf_len)) {
            err = (wasi_errno_t)-1;
            goto fail;
        }
        ciovec.buf = cast(char*)addr_app_to_native(iovec_app.buf_offset);
        ciovec.buf_len = iovec_app.buf_len;
    }

version (BH_VPRINTF) {} else {
    err = uvwasi_fd_write(uvwasi, fd, ciovec_begin, iovs_len, &nwritten);
} version (BH_VPRINTF) {
    /* redirect stdout/stderr output to BH_VPRINTF function */
    if (fd == 1 || fd == 2) {
        int i = void;
        const(iovec)* iov1 = cast(const(iovec)*)ciovec_begin;

        nwritten = 0;
        for (i = 0; i < cast(int)iovs_len; i++, iov1++) {
            if (iov1.iov_len > 0 && iov1.iov_base) {
                char[16] format = void;

                /* make up format string "%.ns" */
                snprintf(format.ptr, format.sizeof, "%%.%ds", cast(int)iov1.iov_len);
                nwritten += cast(uvwasi_size_t)os_printf(format.ptr, iov1.iov_base);
            }
        }
        err = 0;
    }
    else {
        err = uvwasi_fd_write(uvwasi, fd, ciovec_begin, iovs_len, &nwritten);
    }
} /* end of BH_VPRINTF */

    if (err)
        goto fail;

    *nwritten_app = cast(uint)nwritten;

    /* success */
    err = 0;

fail:
    wasm_runtime_free(ciovec_begin);
    return err;
}

private wasi_errno_t wasi_fd_advise(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_filesize_t offset, wasi_filesize_t len, wasi_advice_t advice) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_advise(uvwasi, fd, offset, len, advice);
}

private wasi_errno_t wasi_fd_allocate(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_filesize_t offset, wasi_filesize_t len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_allocate(uvwasi, fd, offset, len);
}

private wasi_errno_t wasi_path_create_directory(wasm_exec_env_t exec_env, wasi_fd_t fd, const(char)* path, uint path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_create_directory(uvwasi, fd, path, path_len);
}

private wasi_errno_t wasi_path_link(wasm_exec_env_t exec_env, wasi_fd_t old_fd, wasi_lookupflags_t old_flags, const(char)* old_path, uint old_path_len, wasi_fd_t new_fd, const(char)* new_path, uint new_path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_link(uvwasi, old_fd, old_flags, old_path, old_path_len,
                            new_fd, new_path, new_path_len);
}

private wasi_errno_t wasi_path_open(wasm_exec_env_t exec_env, wasi_fd_t dirfd, wasi_lookupflags_t dirflags, const(char)* path, uint path_len, wasi_oflags_t oflags, wasi_rights_t fs_rights_base, wasi_rights_t fs_rights_inheriting, wasi_fdflags_t fs_flags, wasi_fd_t* fd_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_fd_t fd = (wasi_fd_t)-1; /* set fd_app -1 if path open failed */
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(fd_app, wasi_fd_t.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_path_open(uvwasi, dirfd, dirflags, path, path_len, oflags,
                           fs_rights_base, fs_rights_inheriting, fs_flags, &fd);

    *fd_app = fd;
    return err;
}

private wasi_errno_t wasi_fd_readdir(wasm_exec_env_t exec_env, wasi_fd_t fd, void* buf, uint buf_len, wasi_dircookie_t cookie, uint* bufused_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t bufused = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(bufused_app, uint32.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_fd_readdir(uvwasi, fd, buf, buf_len, cookie, &bufused);
    if (err)
        return err;

    *bufused_app = cast(uint)bufused;
    return 0;
}

private wasi_errno_t wasi_path_readlink(wasm_exec_env_t exec_env, wasi_fd_t fd, const(char)* path, uint path_len, char* buf, uint buf_len, uint* bufused_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t bufused = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(bufused_app, uint32.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_path_readlink(uvwasi, fd, path, path_len, buf, buf_len,
                               &bufused);
    if (err)
        return err;

    *bufused_app = cast(uint)bufused;
    return 0;
}

private wasi_errno_t wasi_path_rename(wasm_exec_env_t exec_env, wasi_fd_t old_fd, const(char)* old_path, uint old_path_len, wasi_fd_t new_fd, const(char)* new_path, uint new_path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_rename(uvwasi, old_fd, old_path, old_path_len, new_fd,
                              new_path, new_path_len);
}

private wasi_errno_t wasi_fd_filestat_get(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_filestat_t* filestat) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(filestat, wasi_filestat_t.sizeof))
        return (wasi_errno_t)-1;

    return uvwasi_fd_filestat_get(uvwasi, fd, filestat);
}

private wasi_errno_t wasi_fd_filestat_set_times(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_timestamp_t st_atim, wasi_timestamp_t st_mtim, wasi_fstflags_t fstflags) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_filestat_set_times(uvwasi, fd, st_atim, st_mtim, fstflags);
}

private wasi_errno_t wasi_fd_filestat_set_size(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_filesize_t st_size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_fd_filestat_set_size(uvwasi, fd, st_size);
}

private wasi_errno_t wasi_path_filestat_get(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_lookupflags_t flags, const(char)* path, uint path_len, wasi_filestat_t* filestat) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(filestat, wasi_filestat_t.sizeof))
        return (wasi_errno_t)-1;

    return uvwasi_path_filestat_get(uvwasi, fd, flags, path, path_len,
                                    filestat);
}

private wasi_errno_t wasi_path_filestat_set_times(wasm_exec_env_t exec_env, wasi_fd_t fd, wasi_lookupflags_t flags, const(char)* path, uint path_len, wasi_timestamp_t st_atim, wasi_timestamp_t st_mtim, wasi_fstflags_t fstflags) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_filestat_set_times(uvwasi, fd, flags, path, path_len,
                                          st_atim, st_mtim, fstflags);
}

private wasi_errno_t wasi_path_symlink(wasm_exec_env_t exec_env, const(char)* old_path, uint old_path_len, wasi_fd_t fd, const(char)* new_path, uint new_path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_symlink(uvwasi, old_path, old_path_len, fd, new_path,
                               new_path_len);
}

private wasi_errno_t wasi_path_unlink_file(wasm_exec_env_t exec_env, wasi_fd_t fd, const(char)* path, uint path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_unlink_file(uvwasi, fd, path, path_len);
}

private wasi_errno_t wasi_path_remove_directory(wasm_exec_env_t exec_env, wasi_fd_t fd, const(char)* path, uint path_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_path_remove_directory(uvwasi, fd, path, path_len);
}

private wasi_errno_t wasi_poll_oneoff(wasm_exec_env_t exec_env, const(wasi_subscription_t)* in_, wasi_event_t* out_, uint nsubscriptions, uint* nevents_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    uvwasi_size_t nevents = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    if (!validate_native_addr(cast(void*)in_, wasi_subscription_t.sizeof)
        || !validate_native_addr(out_, wasi_event_t.sizeof)
        || !validate_native_addr(nevents_app, uint32.sizeof))
        return (wasi_errno_t)-1;

    err = uvwasi_poll_oneoff(uvwasi, in_, out_, nsubscriptions, &nevents);
    if (err)
        return err;

    *nevents_app = cast(uint)nevents;
    return 0;
}

private void wasi_proc_exit(wasm_exec_env_t exec_env, wasi_exitcode_t rval) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    WASIContext* wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);
    /* Here throwing exception is just to let wasm app exit,
       the upper layer should clear the exception and return
       as normal */
    wasm_runtime_set_exception(module_inst, "wasi proc exit");
    wasi_ctx.exit_code = rval;
}

private wasi_errno_t wasi_proc_raise(wasm_exec_env_t exec_env, wasi_signal_t sig) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char[32] buf = void;

    snprintf(buf.ptr, buf.sizeof, "%s%d", "wasi proc raise ", sig);
    wasm_runtime_set_exception(module_inst, buf.ptr);
    return 0;
}

private wasi_errno_t wasi_random_get(wasm_exec_env_t exec_env, void* buf, uint buf_len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    return uvwasi_random_get(uvwasi, buf, buf_len);
}

private wasi_errno_t wasi_sock_recv(wasm_exec_env_t exec_env, wasi_fd_t sock, iovec_app_t* ri_data, uint ri_data_len, wasi_riflags_t ri_flags, uint* ro_datalen_app, wasi_roflags_t* ro_flags) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_iovec_t* iovec = void, iovec_begin = void;
    ulong total_size = void;
    uvwasi_size_t ro_datalen = void;
    uint i = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    total_size = sizeof(iovec_app_t) * cast(ulong)ri_data_len;
    if (!validate_native_addr(ro_datalen_app, cast(uint)uint32.sizeof)
        || !validate_native_addr(ro_flags, cast(uint)wasi_roflags_t.sizeof)
        || total_size >= UINT32_MAX
        || !validate_native_addr(ri_data, cast(uint)total_size))
        return (wasi_errno_t)-1;

    total_size = sizeof(wasi_iovec_t) * cast(ulong)ri_data_len;
    if (total_size >= UINT32_MAX
        || ((iovec_begin = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    iovec = iovec_begin;
    for (i = 0; i < ri_data_len; i++, ri_data++, iovec++) {
        if (!validate_app_addr(ri_data.buf_offset, ri_data.buf_len)) {
            err = (wasi_errno_t)-1;
            goto fail;
        }
        iovec.buf = cast(void*)addr_app_to_native(ri_data.buf_offset);
        iovec.buf_len = ri_data.buf_len;
    }

    err = uvwasi_sock_recv(uvwasi, sock, iovec_begin, ri_data_len, ri_flags,
                           &ro_datalen, ro_flags);
    if (err)
        goto fail;

    *cast(uint*)ro_datalen_app = cast(uint)ro_datalen;

    /* success */
    err = 0;

fail:
    wasm_runtime_free(iovec_begin);
    return err;
}

private wasi_errno_t wasi_sock_send(wasm_exec_env_t exec_env, wasi_fd_t sock, const(iovec_app_t)* si_data, uint si_data_len, wasi_siflags_t si_flags, uint* so_datalen_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);
    wasi_ciovec_t* ciovec = void, ciovec_begin = void;
    ulong total_size = void;
    uvwasi_size_t so_datalen = void;
    uint i = void;
    wasi_errno_t err = void;

    if (!uvwasi)
        return (wasi_errno_t)-1;

    total_size = sizeof(iovec_app_t) * cast(ulong)si_data_len;
    if (!validate_native_addr(so_datalen_app, uint32.sizeof)
        || total_size >= UINT32_MAX
        || !validate_native_addr(cast(void*)si_data, cast(uint)total_size))
        return (wasi_errno_t)-1;

    total_size = sizeof(wasi_ciovec_t) * cast(ulong)si_data_len;
    if (total_size >= UINT32_MAX
        || ((ciovec_begin = wasm_runtime_malloc(cast(uint)total_size)) == 0))
        return (wasi_errno_t)-1;

    ciovec = ciovec_begin;
    for (i = 0; i < si_data_len; i++, si_data++, ciovec++) {
        if (!validate_app_addr(si_data.buf_offset, si_data.buf_len)) {
            err = (wasi_errno_t)-1;
            goto fail;
        }
        ciovec.buf = cast(char*)addr_app_to_native(si_data.buf_offset);
        ciovec.buf_len = si_data.buf_len;
    }

    err = uvwasi_sock_send(uvwasi, sock, ciovec_begin, si_data_len, si_flags,
                           &so_datalen);
    if (err)
        goto fail;

    *so_datalen_app = cast(uint)so_datalen;

    /* success */
    err = 0;

fail:
    wasm_runtime_free(ciovec_begin);
    return err;
}

private wasi_errno_t wasi_sock_shutdown(wasm_exec_env_t exec_env, wasi_fd_t sock, wasi_sdflags_t how) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    if (!uvwasi)
        return (wasi_errno_t)-1;

    return uvwasi_sock_shutdown(uvwasi, sock, how);
}

private wasi_errno_t wasi_sched_yield(wasm_exec_env_t exec_env) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uvwasi_t* uvwasi = get_wasi_ctx(module_inst);

    return uvwasi_sched_yield(uvwasi);
}

/* clang-format off */
enum string REG_NATIVE_FUNC(string func_name, string signature) = ` \
    { #func_name, wasi_##func_name, signature, NULL }`;
/* clang-format on */

private NativeSymbol[46] native_symbols_libc_wasi = [
    REG_NATIVE_FUNC(args_get, "(**)i"),
    REG_NATIVE_FUNC(args_sizes_get, "(**)i"),
    REG_NATIVE_FUNC(clock_res_get, "(i*)i"),
    REG_NATIVE_FUNC(clock_time_get, "(iI*)i"),
    REG_NATIVE_FUNC(environ_get, "(**)i"),
    REG_NATIVE_FUNC(environ_sizes_get, "(**)i"),
    REG_NATIVE_FUNC(fd_prestat_get, "(i*)i"),
    REG_NATIVE_FUNC(fd_prestat_dir_name, "(i*~)i"),
    REG_NATIVE_FUNC(fd_close, "(i)i"),
    REG_NATIVE_FUNC(fd_datasync, "(i)i"),
    REG_NATIVE_FUNC(fd_pread, "(i*iI*)i"),
    REG_NATIVE_FUNC(fd_pwrite, "(i*iI*)i"),
    REG_NATIVE_FUNC(fd_read, "(i*i*)i"),
    REG_NATIVE_FUNC(fd_renumber, "(ii)i"),
    REG_NATIVE_FUNC(fd_seek, "(iIi*)i"),
    REG_NATIVE_FUNC(fd_tell, "(i*)i"),
    REG_NATIVE_FUNC(fd_fdstat_get, "(i*)i"),
    REG_NATIVE_FUNC(fd_fdstat_set_flags, "(ii)i"),
    REG_NATIVE_FUNC(fd_fdstat_set_rights, "(iII)i"),
    REG_NATIVE_FUNC(fd_sync, "(i)i"),
    REG_NATIVE_FUNC(fd_write, "(i*i*)i"),
    REG_NATIVE_FUNC(fd_advise, "(iIIi)i"),
    REG_NATIVE_FUNC(fd_allocate, "(iII)i"),
    REG_NATIVE_FUNC(path_create_directory, "(i*~)i"),
    REG_NATIVE_FUNC(path_link, "(ii*~i*~)i"),
    REG_NATIVE_FUNC(path_open, "(ii*~iIIi*)i"),
    REG_NATIVE_FUNC(fd_readdir, "(i*~I*)i"),
    REG_NATIVE_FUNC(path_readlink, "(i*~*~*)i"),
    REG_NATIVE_FUNC(path_rename, "(i*~i*~)i"),
    REG_NATIVE_FUNC(fd_filestat_get, "(i*)i"),
    REG_NATIVE_FUNC(fd_filestat_set_times, "(iIIi)i"),
    REG_NATIVE_FUNC(fd_filestat_set_size, "(iI)i"),
    REG_NATIVE_FUNC(path_filestat_get, "(ii*~*)i"),
    REG_NATIVE_FUNC(path_filestat_set_times, "(ii*~IIi)i"),
    REG_NATIVE_FUNC(path_symlink, "(*~i*~)i"),
    REG_NATIVE_FUNC(path_unlink_file, "(i*~)i"),
    REG_NATIVE_FUNC(path_remove_directory, "(i*~)i"),
    REG_NATIVE_FUNC(poll_oneoff, "(**i*)i"),
    REG_NATIVE_FUNC(proc_exit, "(i)"),
    REG_NATIVE_FUNC(proc_raise, "(i)i"),
    REG_NATIVE_FUNC(random_get, "(*~)i"),
    REG_NATIVE_FUNC(sock_recv, "(i*ii**)i"),
    REG_NATIVE_FUNC(sock_send, "(i*ii*)i"),
    REG_NATIVE_FUNC(sock_shutdown, "(ii)i"),
    REG_NATIVE_FUNC(sched_yield, "()i"),
];

uint get_libc_wasi_export_apis(NativeSymbol** p_libc_wasi_apis) {
    *p_libc_wasi_apis = native_symbols_libc_wasi;
    return native_symbols_libc_wasi.sizeof / NativeSymbol.sizeof;
}
