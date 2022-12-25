module libc_emcc_wrapper;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2020 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_common;
public import bh_log;
public import wasm_export;
public import ...interpreter.wasm;
static if (!HasVersion!"_DEFAULT_SOURCE" && !HasVersion!"BH_PLATFORM_LINUX_SGX") {
public import sys.syscall;
}

/* clang-format off */
enum string get_module_inst(string exec_env) = ` \
    wasm_runtime_get_module_inst(exec_env)`;

enum string validate_app_addr(string offset, string size) = ` \
    wasm_runtime_validate_app_addr(module_inst, offset, size)`;

enum string validate_app_str_addr(string offset) = ` \
    wasm_runtime_validate_app_str_addr(module_inst, offset)`;

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

extern bool wasm_runtime_call_indirect(wasm_exec_env_t exec_env, uint element_idx, uint argc, uint* argv);

private void invoke_viiii_wrapper(wasm_exec_env_t exec_env, uint elem_idx, int arg0, int arg1, int arg2, int arg3) {
    uint[4] argv = void;
    bool ret = void;

    argv[0] = arg0;
    argv[1] = arg1;
    argv[2] = arg2;
    argv[3] = arg3;
    ret = wasm_runtime_call_indirect(exec_env, elem_idx, 4, argv.ptr);
    cast(void)ret;
}

private void invoke_viii_wrapper(wasm_exec_env_t exec_env, uint elem_idx, int arg0, int arg1, int arg2) {
    uint[4] argv = void;
    bool ret = void;

    argv[0] = arg0;
    argv[1] = arg1;
    argv[2] = arg2;
    ret = wasm_runtime_call_indirect(exec_env, elem_idx, 3, argv.ptr);
    cast(void)ret;
}

private void invoke_vii_wrapper(wasm_exec_env_t exec_env, uint elem_idx, int arg0, int arg1) {
    uint[4] argv = void;
    bool ret = void;

    argv[0] = arg0;
    argv[1] = arg1;
    ret = wasm_runtime_call_indirect(exec_env, elem_idx, 2, argv.ptr);
    cast(void)ret;
}

private void invoke_vi_wrapper(wasm_exec_env_t exec_env, uint elem_idx, int arg0) {
    uint[4] argv = void;
    bool ret = void;

    argv[0] = arg0;
    ret = wasm_runtime_call_indirect(exec_env, elem_idx, 1, argv.ptr);
    cast(void)ret;
}

private int invoke_iii_wrapper(wasm_exec_env_t exec_env, uint elem_idx, int arg0, int arg1) {
    uint[4] argv = void;
    bool ret = void;

    argv[0] = arg0;
    argv[1] = arg1;
    ret = wasm_runtime_call_indirect(exec_env, elem_idx, 2, argv.ptr);
    return ret ? argv[0] : 0;
}

private int invoke_ii_wrapper(wasm_exec_env_t exec_env, uint elem_idx, int arg0) {
    uint[4] argv = void;
    bool ret = void;

    argv[0] = arg0;
    ret = wasm_runtime_call_indirect(exec_env, elem_idx, 1, argv.ptr);
    return ret ? argv[0] : 0;
}

struct timespec_emcc {
    int tv_sec;
    int tv_nsec;
}

struct stat_emcc {
    uint st_dev;
    int __st_dev_padding;
    uint __st_ino_truncated;
    uint st_mode;
    uint st_nlink;
    uint st_uid;
    uint st_gid;
    uint st_rdev;
    int __st_rdev_padding;
    long st_size;
    int st_blksize;
    int st_blocks;
    timespec_emcc st_atim;
    timespec_emcc st_mtim;
    timespec_emcc st_ctim;
    long st_ino;
}

private int open_wrapper(wasm_exec_env_t exec_env, const(char)* pathname, int flags, int mode) {
    if (pathname == null)
        return -1;
    return open(pathname, flags, mode);
}

private int __sys_read_wrapper(wasm_exec_env_t exec_env, int fd, void* buf, uint count) {
    return read(fd, buf, count);
}

private void statbuf_native2app(const(stat)* statbuf_native, stat_emcc* statbuf_app) {
    statbuf_app.st_dev = cast(uint)statbuf_native.st_dev;
    statbuf_app.__st_ino_truncated = cast(uint)statbuf_native.st_ino;
    statbuf_app.st_mode = cast(uint)statbuf_native.st_mode;
    statbuf_app.st_nlink = cast(uint)statbuf_native.st_nlink;
    statbuf_app.st_uid = cast(uint)statbuf_native.st_uid;
    statbuf_app.st_gid = cast(uint)statbuf_native.st_gid;
    statbuf_app.st_rdev = cast(uint)statbuf_native.st_rdev;
    statbuf_app.st_size = cast(long)statbuf_native.st_size;
    statbuf_app.st_blksize = cast(uint)statbuf_native.st_blksize;
    statbuf_app.st_blocks = cast(uint)statbuf_native.st_blocks;
    statbuf_app.st_ino = cast(long)statbuf_native.st_ino;
    statbuf_app.st_atim.tv_sec = cast(int)statbuf_native.st_atim.tv_sec;
    statbuf_app.st_atim.tv_nsec = cast(int)statbuf_native.st_atim.tv_nsec;
    statbuf_app.st_mtim.tv_sec = cast(int)statbuf_native.st_mtim.tv_sec;
    statbuf_app.st_mtim.tv_nsec = cast(int)statbuf_native.st_mtim.tv_nsec;
    statbuf_app.st_ctim.tv_sec = cast(int)statbuf_native.st_ctim.tv_sec;
    statbuf_app.st_ctim.tv_nsec = cast(int)statbuf_native.st_ctim.tv_nsec;
}

private int __sys_stat64_wrapper(wasm_exec_env_t exec_env, const(char)* pathname, stat_emcc* statbuf_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int ret = void;
    stat statbuf = void;

    if (!validate_native_addr(cast(void*)statbuf_app, stat_emcc.sizeof))
        return -1;

    if (pathname == null)
        return -1;

    ret = stat(pathname, &statbuf);
    if (ret == 0)
        statbuf_native2app(&statbuf, statbuf_app);
    return ret;
}

private int __sys_fstat64_wrapper(wasm_exec_env_t exec_env, int fd, stat_emcc* statbuf_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    int ret = void;
    stat statbuf = void;

    if (!validate_native_addr(cast(void*)statbuf_app, stat_emcc.sizeof))
        return -1;

    if (fd <= 0)
        return -1;

    ret = fstat(fd, &statbuf);
    if (ret == 0)
        statbuf_native2app(&statbuf, statbuf_app);
    return ret;
}

private int mmap_wrapper(wasm_exec_env_t exec_env, void* addr, int length, int prot, int flags, int fd, long offset) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint buf_offset = void;
    char* buf = void;
    int size_read = void;

    buf_offset = module_malloc(length, cast(void**)&buf);
    if (buf_offset == 0)
        return -1;

    if (fd <= 0)
        return -1;

    if (lseek(fd, offset, SEEK_SET) == -1)
        return -1;

    size_read = read(fd, buf, length);
    cast(void)size_read;
    return buf_offset;
}

private int munmap_wrapper(wasm_exec_env_t exec_env, uint buf_offset, int length) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    module_free(buf_offset);
    return 0;
}

private int __munmap_wrapper(wasm_exec_env_t exec_env, uint buf_offset, int length) {
    return munmap_wrapper(exec_env, buf_offset, length);
}

private int getentropy_wrapper(wasm_exec_env_t exec_env, void* buffer, uint length) {
    if (buffer == null)
        return -1;
static if (HasVersion!"_DEFAULT_SOURCE" || HasVersion!"BH_PLATFORM_LINUX_SGX") {
    return getentropy(buffer, length);
} else {
    return syscall(SYS_getrandom, buffer, length, 0);
}
}

private int setjmp_wrapper(wasm_exec_env_t exec_env, void* jmp_buf) {
    os_printf("setjmp() called\n");
    return 0;
}

private void longjmp_wrapper(wasm_exec_env_t exec_env, void* jmp_buf, int val) {
    os_printf("longjmp() called\n");
}

static if (!HasVersion!"BH_PLATFORM_LINUX_SGX") {
private FILE*[32] file_list = 0;

private int get_free_file_slot() {
    uint i = void;

    for (i = 0; i < file_list.sizeof / (FILE*).sizeof; i++) {
        if (file_list[i] == null)
            return cast(int)i;
    }
    return -1;
}

private int fopen_wrapper(wasm_exec_env_t exec_env, const(char)* pathname, const(char)* mode) {
    FILE* file = void;
    int file_id = void;

    if (pathname == null || mode == null)
        return 0;

    if ((file_id = get_free_file_slot()) == -1)
        return 0;

    file = fopen(pathname, mode);
    if (!file)
        return 0;

    file_list[file_id] = file;
    return file_id + 1;
}

private uint fread_wrapper(wasm_exec_env_t exec_env, void* ptr, uint size, uint nmemb, int file_id) {
    FILE* file = void;

    file_id = file_id - 1;
    if (cast(uint)file_id >= file_list.sizeof / (FILE*).sizeof) {
        return 0;
    }
    if ((file = file_list[file_id]) == null) {
        return 0;
    }
    return cast(uint)fread(ptr, size, nmemb, file);
}

private int fseeko_wrapper(wasm_exec_env_t exec_env, int file_id, long offset, int whence) {
    FILE* file = void;

    file_id = file_id - 1;
    if (cast(uint)file_id >= file_list.sizeof / (FILE*).sizeof) {
        return -1;
    }
    if ((file = file_list[file_id]) == null) {
        return -1;
    }
    return cast(uint)fseek(file, offset, whence);
}

private uint emcc_fwrite_wrapper(wasm_exec_env_t exec_env, const(void)* ptr, uint size, uint nmemb, int file_id) {
    FILE* file = void;

    file_id = file_id - 1;
    if (cast(uint)file_id >= file_list.sizeof / (FILE*).sizeof) {
        return 0;
    }
    if ((file = file_list[file_id]) == null) {
        return 0;
    }
    return cast(uint)fwrite(ptr, size, nmemb, file);
}

private int feof_wrapper(wasm_exec_env_t exec_env, int file_id) {
    FILE* file = void;

    file_id = file_id - 1;
    if (cast(uint)file_id >= file_list.sizeof / (FILE*).sizeof)
        return 1;
    if ((file = file_list[file_id]) == null)
        return 1;
    return feof(file);
}

private int fclose_wrapper(wasm_exec_env_t exec_env, int file_id) {
    FILE* file = void;

    file_id = file_id - 1;
    if (cast(uint)file_id >= file_list.sizeof / (FILE*).sizeof)
        return -1;
    if ((file = file_list[file_id]) == null)
        return -1;
    file_list[file_id] = null;
    return fclose(file);
}

private int __sys_mkdir_wrapper(wasm_exec_env_t exec_env, const(char)* pathname, int mode) {
    if (!pathname)
        return -1;
    return mkdir(pathname, mode);
}

private int __sys_rmdir_wrapper(wasm_exec_env_t exec_env, const(char)* pathname) {
    if (!pathname)
        return -1;
    return rmdir(pathname);
}

private int __sys_unlink_wrapper(wasm_exec_env_t exec_env, const(char)* pathname) {
    if (!pathname)
        return -1;
    return unlink(pathname);
}

private uint __sys_getcwd_wrapper(wasm_exec_env_t exec_env, char* buf, uint size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    char* ret = void;

    if (!buf)
        return -1;

    ret = getcwd(buf, size);
    return ret ? addr_native_to_app(ret) : 0;
}

public import core.sys.posix.sys.utsname;

struct utsname_app {
    char[64] sysname = 0;
    char[64] nodename = 0;
    char[64] release = 0;
    char[64] version_ = 0;
    char[64] machine = 0;
    char[64] domainname = 0;
};

private int __sys_uname_wrapper(wasm_exec_env_t exec_env, utsname_app* uname_app) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    utsname uname_native = { 0 };
    uint length = void;

    if (!validate_native_addr(uname_app, utsname_app.sizeof))
        return -1;

    if (uname(&uname_native) != 0) {
        return -1;
    }

    memset(uname_app, 0, utsname_app.sizeof);

    length = strlen(uname_native.sysname);
    if (length > sizeof(uname_app.sysname) - 1)
        length = sizeof(uname_app.sysname) - 1;
    bh_memcpy_s(uname_app.sysname, typeof(uname_app.sysname).sizeof,
                uname_native.sysname, length);

    length = strlen(uname_native.nodename);
    if (length > sizeof(uname_app.nodename) - 1)
        length = sizeof(uname_app.nodename) - 1;
    bh_memcpy_s(uname_app.nodename, typeof(uname_app.nodename).sizeof,
                uname_native.nodename, length);

    length = strlen(uname_native.release);
    if (length > sizeof(uname_app.release) - 1)
        length = sizeof(uname_app.release) - 1;
    bh_memcpy_s(uname_app.release, typeof(uname_app.release).sizeof,
                uname_native.release, length);

    length = strlen(uname_native.version_);
    if (length > sizeof(uname_app.version_) - 1)
        length = sizeof(uname_app.version_) - 1;
    bh_memcpy_s(uname_app.version_, typeof(uname_app.version_).sizeof,
                uname_native.version_, length);

version (_GNU_SOURCE) {
    length = strlen(uname_native.domainname);
    if (length > sizeof(uname_app.domainname) - 1)
        length = sizeof(uname_app.domainname) - 1;
    bh_memcpy_s(uname_app.domainname, typeof(uname_app.domainname).sizeof,
                uname_native.domainname, length);
}

    return 0;
}

private void emscripten_notify_memory_growth_wrapper(wasm_exec_env_t exec_env, int i) {
    cast(void)i;
}

private void emscripten_thread_sleep_wrapper(wasm_exec_env_t exec_env, double timeout_ms) {
    ulong ms = cast(ulong)timeout_ms;
    ulong sec = ms / 1000, us = (ms % 1000) * 1000;

    if (sec > 0)
        sleep(sec);
    if (us > 0)
        usleep(us);
}

} /* end of BH_PLATFORM_LINUX_SGX */

/* clang-format off */
enum string REG_NATIVE_FUNC(string func_name, string signature) = ` \
    { #func_name, func_name##_wrapper, signature, NULL }`;
/* clang-format off */

private NativeSymbol[30] native_symbols_libc_emcc = [
    REG_NATIVE_FUNC(invoke_viiii, "(iiiii)"),
    REG_NATIVE_FUNC(invoke_viii, "(iiii)"),
    REG_NATIVE_FUNC(invoke_vii, "(iii)"),
    REG_NATIVE_FUNC(invoke_vi, "(ii)"),
    REG_NATIVE_FUNC(invoke_iii, "(iii)i"),
    REG_NATIVE_FUNC(invoke_ii, "(ii)i"),
    REG_NATIVE_FUNC(open, "($ii)i"),
    REG_NATIVE_FUNC(__sys_read, "(i*~)i"),
    REG_NATIVE_FUNC(__sys_stat64, "($*)i"),
    REG_NATIVE_FUNC(__sys_fstat64, "(i*)i"),
    REG_NATIVE_FUNC(mmap, "(*iiiiI)i"),
    REG_NATIVE_FUNC(munmap, "(ii)i"),
    REG_NATIVE_FUNC(__munmap, "(ii)i"),
    REG_NATIVE_FUNC(getentropy, "(*~)i"),
    REG_NATIVE_FUNC(setjmp, "(*)i"),
    REG_NATIVE_FUNC(longjmp, "(*i)"),
#if !defined(BH_PLATFORM_LINUX_SGX)
    REG_NATIVE_FUNC(fopen, "($$)i"),
    REG_NATIVE_FUNC(fread, "(*iii)i"),
    REG_NATIVE_FUNC(fseeko, "(iIi)i"),
    REG_NATIVE_FUNC(emcc_fwrite, "(*iii)i"),
    REG_NATIVE_FUNC(feof, "(i)i"),
    REG_NATIVE_FUNC(fclose, "(i)i"),
    REG_NATIVE_FUNC(__sys_mkdir, "($i)i"),
    REG_NATIVE_FUNC(__sys_rmdir, "($)i"),
    REG_NATIVE_FUNC(__sys_unlink, "($)i"),
    REG_NATIVE_FUNC(__sys_getcwd, "(*~)i"),
    REG_NATIVE_FUNC(__sys_uname, "(*)i"),
    REG_NATIVE_FUNC(emscripten_notify_memory_growth, "(i)"),
    REG_NATIVE_FUNC(emscripten_thread_sleep, "(F)"),
#endif /* end of BH_PLATFORM_LINUX_SGX */
];

uint get_libc_emcc_export_apis(NativeSymbol** p_libc_emcc_apis) {
    *p_libc_emcc_apis = native_symbols_libc_emcc;
    return native_symbols_libc_emcc.sizeof / NativeSymbol.sizeof;
}
