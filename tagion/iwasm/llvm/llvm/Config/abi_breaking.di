/*===------- llvm/Config/abi-breaking.h - llvm configuration -------*- C -*-===*/
/*                                                                            */
/* Part of the LLVM Project, under the Apache License v2.0 with LLVM          */
/* Exceptions.                                                                */
/* See https://llvm.org/LICENSE.txt for license information.                  */
/* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    */
/*                                                                            */
/*===----------------------------------------------------------------------===*/

/* This file controls the C++ ABI break introduced in LLVM public header. */

extern (C):

/* Define to enable checks that alter the LLVM C++ ABI */
enum LLVM_ENABLE_ABI_BREAKING_CHECKS = 0;

/* Define to enable reverse iteration of unordered llvm containers */
enum LLVM_ENABLE_REVERSE_ITERATION = 0;

/* Allow selectively disabling link-time mismatch checking so that header-only
   ADT content from LLVM can be used without linking libSupport. */

// ABI_BREAKING_CHECKS protection: provides link-time failure when clients build
// mismatch with LLVM

// Use pragma with MSVC

// Win32 w/o #pragma detect_mismatch
// FIXME: Implement checks without weak.

// GCC on AIX does not support visibility attributes. Symbols are not
// exported by default on AIX.

// _MSC_VER

// LLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING

