module ssp_config;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

 
public import core.stdc.stdlib;

static if (HasVersion!"__FreeBSD__" || HasVersion!"OSX" \
    || (HasVersion!"ANDROID" && __ANDROID_API__ < 28)) {
enum CONFIG_HAS_ARC4RANDOM_BUF = 1;
} else {
enum CONFIG_HAS_ARC4RANDOM_BUF = 0;
}

// On Linux, prefer to use getrandom, though it isn't available in
// GLIBC before 2.25.
static if ((HasVersion!"linux" || HasVersion!"ESP_PLATFORM") \
    && (!HasVersion!"__GLIBC__" || __GLIBC__ > 2      \
        || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 25))) {
enum CONFIG_HAS_GETRANDOM = 1;
} else {
enum CONFIG_HAS_GETRANDOM = 0;
}

version (__CloudABI__) {
enum CONFIG_HAS_CAP_ENTER = 1;
} else {
enum CONFIG_HAS_CAP_ENTER = 0;
}

static if (!HasVersion!"OSX" && !HasVersion!"__FreeBSD__" && !HasVersion!"__EMSCRIPTEN__" \
    && !HasVersion!"ESP_PLATFORM") {
enum CONFIG_HAS_CLOCK_NANOSLEEP = 1;
} else {
enum CONFIG_HAS_CLOCK_NANOSLEEP = 0;
}

static if (!HasVersion!"OSX" && !HasVersion!"__FreeBSD__" && !HasVersion!"ESP_PLATFORM") {
enum CONFIG_HAS_FDATASYNC = 1;
} else {
enum CONFIG_HAS_FDATASYNC = 0;
}

/*
 * For NuttX, CONFIG_HAS_ISATTY is provided by its platform header.
 * (platform_internal.h)
 */
version (__NuttX__) {} else {
version (__CloudABI__) {} else {
enum CONFIG_HAS_ISATTY = 1;
} version (__CloudABI__) {
enum CONFIG_HAS_ISATTY = 0;
}
}

static if (!HasVersion!"OSX" && !HasVersion!"ESP_PLATFORM") {
enum CONFIG_HAS_POSIX_FALLOCATE = 1;
} else {
enum CONFIG_HAS_POSIX_FALLOCATE = 0;
}

static if (!HasVersion!"OSX" && !HasVersion!"ESP_PLATFORM") {
enum CONFIG_HAS_PREADV = 1;
} else {
enum CONFIG_HAS_PREADV = 0;
}

static if (HasVersion!"OSX" || HasVersion!"__CloudABI__") {
enum CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP = 1;
} else {
enum CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP = 0;
}

static if (!HasVersion!"OSX" && !HasVersion!"BH_PLATFORM_LINUX_SGX") {
enum CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK = 1;
} else {
enum CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK = 0;
}

static if (!HasVersion!"OSX" && !HasVersion!"ESP_PLATFORM") {
enum CONFIG_HAS_PWRITEV = 1;
} else {
enum CONFIG_HAS_PWRITEV = 0;
}

version (OSX) {
enum st_atim = st_atimespec;
enum st_ctim = st_ctimespec;
enum st_mtim = st_mtimespec;
}

version (OSX) {
enum CONFIG_TLS_USE_GSBASE = 1;
} else {
enum CONFIG_TLS_USE_GSBASE = 0;
}

static if (!HasVersion!"BH_PLATFORM_LINUX_SGX") {
enum CONFIG_HAS_STD_ATOMIC = 1;
} else {
enum CONFIG_HAS_STD_ATOMIC = 0;
}

static if (!HasVersion!"__NuttX__") {
enum CONFIG_HAS_D_INO = 1;
} else {
enum CONFIG_HAS_D_INO = 0;
}


