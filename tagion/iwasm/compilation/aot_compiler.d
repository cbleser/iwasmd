module tagion.iwasm.compilation.aot_compiler;
@nogc nothrow:
extern(C): __gshared:
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* This header is separate from features.h so that the compiler can
   include it implicitly at the start of every compilation.  It must
   not itself include <features.h> or any other header that includes
   <features.h> because the implicit include comes before any feature
   test macros that may be defined in a source file before it first
   explicitly includes a system header.  GCC knows the name of this
   header in order to preinclude it.  */
/* glibc's intent is to support the IEC 559 math functionality, real
   and complex.  If the GCC (4.9 and later) predefined macros
   specifying compiler intent are available, use them to determine
   whether the overall intent is to support these features; otherwise,
   presume an older compiler has intent to support these features and
   define these macros by default.  */
/* wchar_t uses Unicode 10.0.0.  Version 10.0 of the Unicode Standard is
   synchronized with ISO/IEC 10646:2017, fifth edition, plus
   the following additions from Amendment 1 to the fifth edition:
   - 56 emoji characters
   - 285 hentaigana
   - 3 additional Zanabazar Square characters */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
import tagion.iwasm.compilation.aot;
import tagion.iwasm.compilation.aot_llvm;
alias IntCond = AOTIntCond;
alias FloatCond = AOTFloatCond;
enum IntArithmetic {
    INT_ADD = 0,
    INT_SUB,
    INT_MUL,
    INT_DIV_S,
    INT_DIV_U,
    INT_REM_S,
    INT_REM_U
}
alias INT_ADD = IntArithmetic.INT_ADD;
alias INT_SUB = IntArithmetic.INT_SUB;
alias INT_MUL = IntArithmetic.INT_MUL;
alias INT_DIV_S = IntArithmetic.INT_DIV_S;
alias INT_DIV_U = IntArithmetic.INT_DIV_U;
alias INT_REM_S = IntArithmetic.INT_REM_S;
alias INT_REM_U = IntArithmetic.INT_REM_U;

enum V128Arithmetic {
    V128_ADD= 0,
    V128_SUB,
    V128_MUL,
    V128_DIV,
    V128_NEG,
    V128_MIN,
    V128_MAX,
}

alias V128_ADD = V128Arithmetic.V128_ADD;
alias V128_SUB = V128Arithmetic.V128_SUB;
alias V128_MUL = V128Arithmetic.V128_MUL;
alias V128_DIV = V128Arithmetic.V128_DIV;
alias V128_NEG = V128Arithmetic.V128_NEG;
alias V128_MIN = V128Arithmetic.V128_MIN;
alias V128_MAX = V128Arithmetic.V128_MAX;

enum IntBitwise {
    INT_AND = 0,
    INT_OR,
    INT_XOR,
}
alias INT_AND = IntBitwise.INT_AND;
alias INT_OR = IntBitwise.INT_OR;
alias INT_XOR = IntBitwise.INT_XOR;

enum V128Bitwise {
    V128_NOT,
    V128_AND,
    V128_ANDNOT,
    V128_OR,
    V128_XOR,
    V128_BITSELECT,
}
alias V128_NOT = V128Bitwise.V128_NOT;
alias V128_AND = V128Bitwise.V128_AND;
alias V128_ANDNOT = V128Bitwise.V128_ANDNOT;
alias V128_OR = V128Bitwise.V128_OR;
alias V128_XOR = V128Bitwise.V128_XOR;
alias V128_BITSELECT = V128Bitwise.V128_BITSELECT;

enum IntShift {
    INT_SHL = 0,
    INT_SHR_S,
    INT_SHR_U,
    INT_ROTL,
    INT_ROTR
}
alias INT_SHL = IntShift.INT_SHL;
alias INT_SHR_S = IntShift.INT_SHR_S;
alias INT_SHR_U = IntShift.INT_SHR_U;
alias INT_ROTL = IntShift.INT_ROTL;
alias INT_ROTR = IntShift.INT_ROTR;

enum FloatMath {
    FLOAT_ABS = 0,
    FLOAT_NEG,
    FLOAT_CEIL,
    FLOAT_FLOOR,
    FLOAT_TRUNC,
    FLOAT_NEAREST,
    FLOAT_SQRT
}
alias FLOAT_ABS = FloatMath.FLOAT_ABS;
alias FLOAT_NEG = FloatMath.FLOAT_NEG;
alias FLOAT_CEIL = FloatMath.FLOAT_CEIL;
alias FLOAT_FLOOR = FloatMath.FLOAT_FLOOR;
alias FLOAT_TRUNC = FloatMath.FLOAT_TRUNC;
alias FLOAT_NEAREST = FloatMath.FLOAT_NEAREST;
alias FLOAT_SQRT = FloatMath.FLOAT_SQRT;

enum FloatArithmetic {
    FLOAT_ADD = 0,
    FLOAT_SUB,
    FLOAT_MUL,
    FLOAT_DIV,
    FLOAT_MIN,
    FLOAT_MAX,
}
alias FLOAT_ADD = FloatArithmetic.FLOAT_ADD;
alias FLOAT_SUB = FloatArithmetic.FLOAT_SUB;
alias FLOAT_MUL = FloatArithmetic.FLOAT_MUL;
alias FLOAT_DIV = FloatArithmetic.FLOAT_DIV;
alias FLOAT_MIN = FloatArithmetic.FLOAT_MIN;
alias FLOAT_MAX = FloatArithmetic.FLOAT_MAX;

pragma(inline, true) private bool check_type_compatible(ubyte src_type, ubyte dst_type) {
    if (src_type == dst_type) {
        return true;
    }
    /* ext i1 to i32 */
    if (src_type == VALUE_TYPE_I1 && dst_type == VALUE_TYPE_I32) {
        return true;
    }
    /* i32 <==> func.ref, i32 <==> extern.ref */
    if (src_type == VALUE_TYPE_I32
        && (dst_type == VALUE_TYPE_EXTERNREF
            || dst_type == VALUE_TYPE_FUNCREF)) {
        return true;
    }
    if (dst_type == VALUE_TYPE_I32
        && (src_type == VALUE_TYPE_FUNCREF
            || src_type == VALUE_TYPE_EXTERNREF)) {
        return true;
    }
    return false;
}
bool aot_compile_wasm(AOTCompContext* comp_ctx);
bool aot_emit_llvm_file(AOTCompContext* comp_ctx, const(char)* file_name);
bool aot_emit_aot_file(AOTCompContext* comp_ctx, AOTCompData* comp_data, const(char)* file_name);
ubyte* aot_emit_aot_file_buf(AOTCompContext* comp_ctx, AOTCompData* comp_data, uint* p_aot_file_size);
bool aot_emit_object_file(AOTCompContext* comp_ctx, char* file_name);
char* aot_generate_tempfile_name(const(char)* prefix, const(char)* extension, char* buffer, uint len);
import tagion.iwasm.compilation.aot_emit_compare;
import tagion.iwasm.compilation.aot_emit_conversion;
import tagion.iwasm.compilation.aot_emit_memory;
import tagion.iwasm.compilation.aot_emit_variable;
import tagion.iwasm.compilation.aot_emit_const;
import tagion.iwasm.compilation.aot_emit_exception;
import tagion.iwasm.compilation.aot_emit_numberic;
import tagion.iwasm.compilation.aot_emit_control;
import tagion.iwasm.compilation.aot_emit_function;
import tagion.iwasm.compilation.aot_emit_parametric;
import tagion.iwasm.compilation.aot_emit_table;
import tagion.iwasm.compilation.simd.simd_access_lanes;
import tagion.iwasm.compilation.simd.simd_bitmask_extracts;
import tagion.iwasm.compilation.simd.simd_bit_shifts;
import tagion.iwasm.compilation.simd.simd_bitwise_ops;
import tagion.iwasm.compilation.simd.simd_bool_reductions;
import tagion.iwasm.compilation.simd.simd_comparisons;
import tagion.iwasm.compilation.simd.simd_conversions;
import tagion.iwasm.compilation.simd.simd_construct_values;
import tagion.iwasm.compilation.simd.simd_conversions;
import tagion.iwasm.compilation.simd.simd_floating_point;
import tagion.iwasm.compilation.simd.simd_int_arith;
import tagion.iwasm.compilation.simd.simd_load_store;
import tagion.iwasm.compilation.simd.simd_sat_int_arith;
import tagion.iwasm.aot.aot_runtime;
import tagion.iwasm.interpreter.wasm_opcode;
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/*
 *	ISO C99 Standard: 7.5 Errors	<errno.h>
 */
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* These are defined by the user (or the compiler)
   to specify the desired environment:

   __STRICT_ANSI__	ISO Standard C.
   _ISOC99_SOURCE	Extensions to ISO C89 from ISO C99.
   _ISOC11_SOURCE	Extensions to ISO C99 from ISO C11.
   _ISOC2X_SOURCE	Extensions to ISO C99 from ISO C2X.
   __STDC_WANT_LIB_EXT2__
			Extensions to ISO C99 from TR 27431-2:2010.
   __STDC_WANT_IEC_60559_BFP_EXT__
			Extensions to ISO C11 from TS 18661-1:2014.
   __STDC_WANT_IEC_60559_FUNCS_EXT__
			Extensions to ISO C11 from TS 18661-4:2015.
   __STDC_WANT_IEC_60559_TYPES_EXT__
			Extensions to ISO C11 from TS 18661-3:2015.
   __STDC_WANT_IEC_60559_EXT__
			ISO C2X interfaces defined only in Annex F.

   _POSIX_SOURCE	IEEE Std 1003.1.
   _POSIX_C_SOURCE	If ==1, like _POSIX_SOURCE; if >=2 add IEEE Std 1003.2;
			if >=199309L, add IEEE Std 1003.1b-1993;
			if >=199506L, add IEEE Std 1003.1c-1995;
			if >=200112L, all of IEEE 1003.1-2004
			if >=200809L, all of IEEE 1003.1-2008
   _XOPEN_SOURCE	Includes POSIX and XPG things.  Set to 500 if
			Single Unix conformance is wanted, to 600 for the
			sixth revision, to 700 for the seventh revision.
   _XOPEN_SOURCE_EXTENDED XPG things and X/Open Unix extensions.
   _LARGEFILE_SOURCE	Some more functions for correct standard I/O.
   _LARGEFILE64_SOURCE	Additional functionality from LFS for large files.
   _FILE_OFFSET_BITS=N	Select default filesystem interface.
   _ATFILE_SOURCE	Additional *at interfaces.
   _DYNAMIC_STACK_SIZE_SOURCE Select correct (but non compile-time constant)
			MINSIGSTKSZ, SIGSTKSZ and PTHREAD_STACK_MIN.
   _GNU_SOURCE		All of the above, plus GNU extensions.
   _DEFAULT_SOURCE	The default set of features (taking precedence over
			__STRICT_ANSI__).

   _FORTIFY_SOURCE	Add security hardening to many library functions.
			Set to 1 or 2; 2 performs stricter checks than 1.

   _REENTRANT, _THREAD_SAFE
			Obsolete; equivalent to _POSIX_C_SOURCE=199506L.

   The `-ansi' switch to the GNU C compiler, and standards conformance
   options such as `-std=c99', define __STRICT_ANSI__.  If none of
   these are defined, or if _DEFAULT_SOURCE is defined, the default is
   to have _POSIX_SOURCE set to one and _POSIX_C_SOURCE set to
   200809L, as well as enabling miscellaneous functions from BSD and
   SVID.  If more than one of these are defined, they accumulate.  For
   example __STRICT_ANSI__, _POSIX_SOURCE and _POSIX_C_SOURCE together
   give you ISO C, 1003.1, and 1003.2, but nothing else.

   These are defined by this file and are used by the
   header files to decide what to declare or define:

   __GLIBC_USE (F)	Define things from feature set F.  This is defined
			to 1 or 0; the subsequent macros are either defined
			or undefined, and those tests should be moved to
			__GLIBC_USE.
   __USE_ISOC11		Define ISO C11 things.
   __USE_ISOC99		Define ISO C99 things.
   __USE_ISOC95		Define ISO C90 AMD1 (C95) things.
   __USE_ISOCXX11	Define ISO C++11 things.
   __USE_POSIX		Define IEEE Std 1003.1 things.
   __USE_POSIX2		Define IEEE Std 1003.2 things.
   __USE_POSIX199309	Define IEEE Std 1003.1, and .1b things.
   __USE_POSIX199506	Define IEEE Std 1003.1, .1b, .1c and .1i things.
   __USE_XOPEN		Define XPG things.
   __USE_XOPEN_EXTENDED	Define X/Open Unix things.
   __USE_UNIX98		Define Single Unix V2 things.
   __USE_XOPEN2K        Define XPG6 things.
   __USE_XOPEN2KXSI     Define XPG6 XSI things.
   __USE_XOPEN2K8       Define XPG7 things.
   __USE_XOPEN2K8XSI    Define XPG7 XSI things.
   __USE_LARGEFILE	Define correct standard I/O things.
   __USE_LARGEFILE64	Define LFS things with separate names.
   __USE_FILE_OFFSET64	Define 64bit interface as default.
   __USE_MISC		Define things from 4.3BSD or System V Unix.
   __USE_ATFILE		Define *at interfaces and AT_* constants for them.
   __USE_DYNAMIC_STACK_SIZE Define correct (but non compile-time constant)
			MINSIGSTKSZ, SIGSTKSZ and PTHREAD_STACK_MIN.
   __USE_GNU		Define GNU extensions.
   __USE_FORTIFY_LEVEL	Additional security measures used, according to level.

   The macros `__GNU_LIBRARY__', `__GLIBC__', and `__GLIBC_MINOR__' are
   defined by this file unconditionally.  `__GNU_LIBRARY__' is provided
   only for compatibility.  All new code should use the other symbols
   to test for features.

   All macros listed above as possibly being defined by this file are
   explicitly undefined if they are not explicitly defined.
   Feature-test macros that are not defined by the user or compiler
   but are implied by the other feature-test macros defined (or by the
   lack of any definitions) are defined by the file.

   ISO C feature test macros depend on the definition of the macro
   when an affected header is included, not when the first system
   header is included, and so they are handled in
   <bits/libc-header-start.h>, which does not have a multiple include
   guard.  Feature test macros that can be handled from the first
   system header included are handled here.  */
/* Undefine everything, so we get a clean slate.  */
/* Suppress kernel-name space pollution unless user expressedly asks
   for it.  */
/* Convenience macro to test the version of gcc.
   Use like this:
   #if __GNUC_PREREQ (2,8)
   ... code requiring gcc 2.8 or later ...
   #endif
   Note: only works for GCC 2.0 and later, because __GNUC_MINOR__ was
   added in 2.0.  */
/* Similarly for clang.  Features added to GCC after version 4.2 may
   or may not also be available in clang, and clang's definitions of
   __GNUC(_MINOR)__ are fixed at 4 and 2 respectively.  Not all such
   features can be queried via __has_extension/__has_feature.  */
/* Whether to use feature set F.  */
/* _BSD_SOURCE and _SVID_SOURCE are deprecated aliases for
   _DEFAULT_SOURCE.  If _DEFAULT_SOURCE is present we do not
   issue a warning; the expectation is that the source is being
   transitioned to use the new macro.  */
/* If _GNU_SOURCE was defined by the user, turn on all the other features.  */
/* If nothing (other than _GNU_SOURCE and _DEFAULT_SOURCE) is defined,
   define _DEFAULT_SOURCE.  */
/* This is to enable the ISO C2X extension.  */
/* This is to enable the ISO C11 extension.  */
/* This is to enable the ISO C99 extension.  */
/* This is to enable the ISO C90 Amendment 1:1995 extension.  */
/* If none of the ANSI/POSIX macros are defined, or if _DEFAULT_SOURCE
   is defined, use POSIX.1-2008 (or another version depending on
   _XOPEN_SOURCE).  */
/* Some C libraries once required _REENTRANT and/or _THREAD_SAFE to be
   defined in all multithreaded code.  GNU libc has not required this
   for many years.  We now treat them as compatibility synonyms for
   _POSIX_C_SOURCE=199506L, which is the earliest level of POSIX with
   comprehensive support for multithreaded code.  Using them never
   lowers the selected level of POSIX conformance, only raises it.  */
/* Features part to handle 64-bit time_t support.
   Copyright (C) 2021-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* We need to know the word size in order to check the time size.  */
/* Determine the wordsize from the preprocessor defines.  */
/* Both x86-64 and x32 use the 64-bit system call interface.  */
/* Bit size of the time_t type at glibc build time, x86-64 and x32 case.
   Copyright (C) 2018-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* Determine the wordsize from the preprocessor defines.  */
/* Both x86-64 and x32 use the 64-bit system call interface.  */
/* For others, time size is word size.  */
/* The function 'gets' existed in C89, but is impossible to use
   safely.  It has been removed from ISO C11 and ISO C++14.  Note: for
   compatibility with various implementations of <cstdio>, this test
   must consider only the value of __cplusplus when compiling C++.  */
/* GNU formerly extended the scanf functions with modified format
   specifiers %as, %aS, and %a[...] that allocate a buffer for the
   input using malloc.  This extension conflicts with ISO C99, which
   defines %a as a standalone format specifier that reads a floating-
   point number; moreover, POSIX.1-2008 provides the same feature
   using the modifier letter 'm' instead (%ms, %mS, %m[...]).

   We now follow C99 unless GNU extensions are active and the compiler
   is specifically in C89 or C++98 mode (strict or not).  For
   instance, with GCC, -std=gnu11 will have C99-compliant scanf with
   or without -D_GNU_SOURCE, but -std=c89 -D_GNU_SOURCE will have the
   old extension.  */
/* Get definitions of __STDC_* predefined macros, if the compiler has
   not preincluded this header automatically.  */
/* Copyright (C) 1991-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* This macro indicates that the installed library is the GNU C Library.
   For historic reasons the value now is 6 and this will stay from now
   on.  The use of this variable is deprecated.  Use __GLIBC__ and
   __GLIBC_MINOR__ now (see below) when you want to test for a specific
   GNU C library version and use the values in <gnu/lib-names.h> to get
   the sonames of the shared libraries.  */
/* Major and minor version number of the GNU C library package.  Use
   these macros to test for features in specific releases.  */
/* This is here only because every header file already includes this one.  */
/* Copyright (C) 1992-2022 Free Software Foundation, Inc.
   Copyright The GNU Toolchain Authors.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* We are almost always included from features.h. */
/* The GNU libc does not support any K&R compilers or the traditional mode
   of ISO C compilers anymore.  Check for some of the combinations not
   supported anymore.  */
/* Some user header file might have defined this before.  */
/* Compilers that lack __has_attribute may object to
       #if defined __has_attribute && __has_attribute (...)
   even though they do not need to evaluate the right-hand side of the &&.
   Similarly for __has_builtin, etc.  */
/* All functions, except those with callbacks or those that
   synchronize memory, are leaf functions.  */
/* GCC can always grok prototypes.  For C++ programs we add throw()
   to help it optimize the function calls.  But this only works with
   gcc 2.8.x and egcs.  For gcc 3.4 and up we even mark C functions
   as non-throwing using a function attribute since programs can use
   the -fexceptions options for C code as well.  */
/* These two macros are not used in glibc anymore.  They are kept here
   only because some other projects expect the macros to be defined.  */
/* For these things, GCC behaves the ANSI way normally,
   and the non-ANSI way under -traditional.  */
/* This is not a typedef so `const __ptr_t' does the right thing.  */
/* C++ needs to know that types and declarations are C, not C++.  */
/* Fortify support.  */
/* Use __builtin_dynamic_object_size at _FORTIFY_SOURCE=3 when available.  */
/* Compile time conditions to choose between the regular, _chk and _chk_warn
   variants.  These conditions should get evaluated to constant and optimized
   away.  */
/* Length is known to be safe at compile time if the __L * __S <= __OBJSZ
   condition can be folded to a constant and if it is true.  The -1 check is
   redundant because since it implies that __glibc_safe_len_cond is true.  */
/* Conversely, we know at compile time that the length is unsafe if the
   __L * __S <= __OBJSZ condition can be folded to a constant and if it is
   false.  */
/* Fortify function f.  __f_alias, __f_chk and __f_chk_warn must be
   declared.  */
/* Fortify function f, where object size argument passed to f is the number of
   elements and not total size.  */
/* Support for flexible arrays.
   Headers that should use flexible arrays only if they're "real"
   (e.g. only if they won't affect .sizeof) should test
   #if __glibc_c99_flexarr_available.  */
/* __asm__ ("xyz") is used throughout the headers to rename functions
   at the assembly language level.  This is wrapped by the __REDIRECT
   macro, in order to support compilers that can do this some other
   way.  When compilers don't support asm-names at all, we have to do
   preprocessor tricks instead (which don't have exactly the right
   semantics, but it's the best we can do).

   Example:
   int __REDIRECT(setpgrp, (__pid_t pid, __pid_t pgrp), setpgid); */
/*
#elif __SOME_OTHER_COMPILER__

# define __REDIRECT(name, proto, alias) name proto; 	_Pragma("let " #name " = " #alias)
)
*/
/* GCC and clang have various useful declarations that can be made with
   the '__attribute__' syntax.  All of the ways we use this do fine if
   they are omitted for compilers that don't understand it.  */
/* At some point during the gcc 2.96 development the `malloc' attribute
   for functions was introduced.  We don't want to use it unconditionally
   (although this would be possible) since it generates warnings.  */
/* Tell the compiler which arguments to an allocation function
   indicate the size of the allocation.  */
/* Tell the compiler which argument to an allocation function
   indicates the alignment of the allocation.  */
/* At some point during the gcc 2.96 development the `pure' attribute
   for functions was introduced.  We don't want to use it unconditionally
   (although this would be possible) since it generates warnings.  */
/* This declaration tells the compiler that the value is constant.  */
/* At some point during the gcc 3.1 development the `used' attribute
   for functions was introduced.  We don't want to use it unconditionally
   (although this would be possible) since it generates warnings.  */
/* Since version 3.2, gcc allows marking deprecated functions.  */
/* Since version 4.5, gcc also allows one to specify the message printed
   when a deprecated function is used.  clang claims to be gcc 4.2, but
   may also support this feature.  */
/* At some point during the gcc 2.8 development the `format_arg' attribute
   for functions was introduced.  We don't want to use it unconditionally
   (although this would be possible) since it generates warnings.
   If several `format_arg' attributes are given for the same function, in
   gcc-3.0 and older, all but the last one are ignored.  In newer gccs,
   all designated arguments are considered.  */
/* At some point during the gcc 2.97 development the `strfmon' format
   attribute for functions was introduced.  We don't want to use it
   unconditionally (although this would be possible) since it
   generates warnings.  */
/* The nonnull function attribute marks pointer parameters that
   must not be NULL.  This has the name __nonnull in glibc,
   and __attribute_nonnull__ in files shared with Gnulib to avoid
   collision with a different __nonnull in DragonFlyBSD 5.9.  */
/* The returns_nonnull function attribute marks the return type of the function
   as always being non-null.  */
/* If fortification mode, we warn about unused results of certain
   function calls which can lead to problems.  */
/* Forces a function to be always inlined.  */
/* The Linux kernel defines __always_inline in stddef.h (283d7573), and
   it conflicts with this definition.  Therefore undefine it first to
   allow either header to be included first.  */
/* Associate error messages with the source location of the call site rather
   than with the source location inside the function.  */
/* GCC 4.3 and above with -std=c99 or -std=gnu99 implements ISO C99
   inline semantics, unless -fgnu89-inline is used.  Using __GNUC_STDC_INLINE__
   or __GNUC_GNU_INLINE is not a good enough check for gcc because gcc versions
   older than 4.3 may define these macros and still not guarantee GNU inlining
   semantics.

   clang++ identifies itself as gcc-4.2, but has support for GNU inlining
   semantics, that can be checked for by using the __GNUC_STDC_INLINE_ and
   __GNUC_GNU_INLINE__ macro definitions.  */
/* GCC 4.3 and above allow passing all anonymous arguments of an
   __extern_always_inline function to some other vararg function.  */
/* It is possible to compile containing GCC extensions even if GCC is
   run in pedantic mode if the uses are carefully marked using the
   `__extension__' keyword.  But this is not generally available before
   version 2.8.  */
/* __restrict is known in EGCS 1.2 and above, and in clang.
   It works also in C++ mode (outside of arrays), but only when spelled
   as '__restrict', not 'restrict'.  */
/* ISO C99 also allows to declare arrays as non-overlapping.  The syntax is
     array_name[restrict]
   GCC 3.1 and clang support this.
   This syntax is not usable in C++ mode.  */
/* Describes a char array whose address can safely be passed as the first
   argument to strncpy and strncat, as the char array is not necessarily
   a NUL-terminated string.  */
/* Undefine (also defined in libc-symbols.h).  */
/* Copies attributes from the declaration or type referenced by
   the argument.  */
/* Gnulib avoids including these, as they don't work on non-glibc or
   older glibc platforms.  */
/* Determine the wordsize from the preprocessor defines.  */
/* Both x86-64 and x32 use the 64-bit system call interface.  */
/* Properties of long double type.  ldbl-96 version.
   Copyright (C) 2016-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License  published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* long double is distinct from double, so there is nothing to
   define here.  */
/* __glibc_macro_warning (MESSAGE) issues warning MESSAGE.  This is
   intended for use in preprocessor macros.

   Note: MESSAGE must be a _single_ string; concatenation of string
   literals is not supported.  */
/* Generic selection (ISO C11) is a C-only feature, available in GCC
   since version 4.9.  Previous versions do not provide generic
   selection, even though they might set __STDC_VERSION__ to 201112L,
   when in -std=c11 mode.  Thus, we must check for !defined __GNUC__
   when testing __STDC_VERSION__ for generic selection support.
   On the other hand, Clang also defines __GNUC__, so a clang-specific
   check is required to enable the use of generic selection.  */
/* Designates a 1-based positional argument ref-index of pointer type
   that can be used to access size-index elements of the pointed-to
   array according to access mode, or at least one element when
   size-index is not provided:
     access (access-mode, <ref-index> [, <size-index>])  */
/* For _FORTIFY_SOURCE == 3 we use __builtin_dynamic_object_size, which may
   use the access attribute to get object sizes from function definition
   arguments, so we can't use them on functions we fortify.  Drop the object
   size hints for such functions.  */
/* Designates dealloc as a function to call to deallocate objects
   allocated by the declared function.  */
/* Specify that a function such as setjmp or vfork may return
   twice.  */
/* If we don't have __REDIRECT, prototypes will be missing if
   __USE_FILE_OFFSET64 but not __USE_LARGEFILE[64]. */
/* Decide whether we can define 'extern inline' functions in headers.  */
/* This is here only because every header file already includes this one.
   Get the definitions of all the appropriate `__stub_FUNCTION' symbols.
   <gnu/stubs.h> contains `#define __stub_FUNCTION' when FUNCTION is a stub
   that will always return failure (and set errno to ENOSYS).  */
/* This file is automatically generated.
   This file selects the right generated file of `__stub_FUNCTION' macros
   based on the architecture being compiled for.  */
/* This file is automatically generated.
   It defines a symbol `__stub_FUNCTION' for each function
   in the C library which is a stub, meaning it will fail
   every time called, usually setting errno to ENOSYS.  */
/* The system-specific definitions of the E* constants, as macros.  */
/* Error constants.  Linux specific version.
   Copyright (C) 1996-2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */
/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * This error code is special: arch syscall entry code will return
 * -ENOSYS if users try to call a syscall that doesn't exist.  To keep
 * failures of syscalls that really do exist distinguishable from
 * failures due to attempts to use a nonexistent syscall, syscall
 * implementations should refrain from returning -ENOSYS.
 */
/* for robust mutexes */
/* Older Linux headers do not define these constants.  */
/* When included from assembly language, this header only provides the
   E* constants.  */

/* The error code set by various library functions.  */
extern int* __errno_location();

private bool read_leb(const(ubyte)* buf, const(ubyte)* buf_end, uint* p_offset, uint maxbits, bool sign, ulong* p_result) {
    ulong result = 0;
    uint shift = 0;
    uint bcnt = 0;
    ulong byte_ = void;
    while (true) {
        do { if (buf + 1 > buf_end) { aot_set_last_error("read leb failed: unexpected end."); return false; } } while (0);
        byte_ = buf[*p_offset];
        *p_offset += 1;
        result |= ((byte_ & 0x7f) << shift);
        shift += 7;
        if ((byte_ & 0x80) == 0) {
            break;
        }
        bcnt += 1;
    }
    if (bcnt > (maxbits + 6) / 7) {
        aot_set_last_error("read leb failed: "
                           ~ "integer representation too long");
        return false;
    }
    if (sign && (shift < maxbits) && (byte_ & 0x40)) {
        /* Sign extend */
        result |= (~(cast(ulong)0)) << shift;
    }
    *p_result = result;
    return true;
}
/**
 * Since Wamrc uses a full feature Wasm loader,
 * add a post-validator here to run checks according
 * to options, like enable_tail_call, enable_ref_types,
 * and so on.
 */
private bool aot_validate_wasm(AOTCompContext* comp_ctx) {
    if (!comp_ctx.enable_ref_types) {
        /* Doesn't support multiple tables unless enabling reference type */
        if (comp_ctx.comp_data.import_table_count
                + comp_ctx.comp_data.table_count
            > 1) {
            aot_set_last_error("multiple tables");
            return false;
        }
    }
    return true;
}
private bool aot_compile_func(AOTCompContext* comp_ctx, uint func_index) {
    AOTFuncContext* func_ctx = comp_ctx.func_ctxes[func_index];
    ubyte* frame_ip = func_ctx.aot_func.code; ubyte opcode = void; ubyte* p_f32 = void, p_f64 = void;
    ubyte* frame_ip_end = frame_ip + func_ctx.aot_func.code_size;
    ubyte* param_types = null;
    ubyte* result_types = null;
    ubyte value_type = void;
    ushort param_count = void;
    ushort result_count = void;
    uint br_depth = void; uint* br_depths = void; uint br_count = void;
    uint func_idx = void, type_idx = void, mem_idx = void, local_idx = void, global_idx = void, i = void;
    uint bytes = 4, align_ = void, offset = void;
    uint type_index = void;
    bool sign = true;
    int i32_const = void;
    long i64_const = void;
    float32 f32_const = void;
    float64 f64_const = void;
    AOTFuncType* func_type = null;
    /* Start to translate the opcodes */
    LLVMPositionBuilderAtEnd(
        comp_ctx.builder,
        func_ctx.block_stack.block_list_head.llvm_entry_block);
    while (frame_ip < frame_ip_end) {
        opcode = *frame_ip++;
        switch (opcode) {
            case WASM_OP_UNREACHABLE:
                if (!aot_compile_op_unreachable(comp_ctx, func_ctx, &frame_ip))
                    return false;
                break;
            case WASM_OP_NOP:
                break;
            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
            case WASM_OP_IF:
            {
                value_type = *frame_ip++;
                if (value_type == VALUE_TYPE_I32 || value_type == VALUE_TYPE_I64
                    || value_type == VALUE_TYPE_F32
                    || value_type == VALUE_TYPE_F64
                    || value_type == VALUE_TYPE_V128
                    || value_type == VALUE_TYPE_VOID
                    || value_type == VALUE_TYPE_FUNCREF
                    || value_type == VALUE_TYPE_EXTERNREF) {
                    param_count = 0;
                    param_types = null;
                    if (value_type == VALUE_TYPE_VOID) {
                        result_count = 0;
                        result_types = null;
                    }
                    else {
                        result_count = 1;
                        result_types = &value_type;
                    }
                }
                else {
                    frame_ip--;
                    do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; type_index = cast(uint)res64; } while (0);
                    func_type = comp_ctx.comp_data.func_types[type_index];
                    param_count = func_type.param_count;
                    param_types = func_type.types;
                    result_count = func_type.result_count;
                    result_types = func_type.types + param_count;
                }
                if (!aot_compile_op_block(
                        comp_ctx, func_ctx, &frame_ip, frame_ip_end,
                        cast(uint)(LABEL_TYPE_BLOCK + opcode - WASM_OP_BLOCK),
                        param_count, param_types, result_count, result_types))
                    return false;
                break;
            }
            case EXT_OP_BLOCK:
            case EXT_OP_LOOP:
            case EXT_OP_IF:
            {
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; type_index = cast(uint)res64; } while (0);
                func_type = comp_ctx.comp_data.func_types[type_index];
                param_count = func_type.param_count;
                param_types = func_type.types;
                result_count = func_type.result_count;
                result_types = func_type.types + param_count;
                if (!aot_compile_op_block(
                        comp_ctx, func_ctx, &frame_ip, frame_ip_end,
                        cast(uint)(LABEL_TYPE_BLOCK + opcode - EXT_OP_BLOCK),
                        param_count, param_types, result_count, result_types))
                    return false;
                break;
            }
            case WASM_OP_ELSE:
                if (!aot_compile_op_else(comp_ctx, func_ctx, &frame_ip))
                    return false;
                break;
            case WASM_OP_END:
                if (!aot_compile_op_end(comp_ctx, func_ctx, &frame_ip))
                    return false;
                break;
            case WASM_OP_BR:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; br_depth = cast(uint)res64; } while (0);
                if (!aot_compile_op_br(comp_ctx, func_ctx, br_depth, &frame_ip))
                    return false;
                break;
            case WASM_OP_BR_IF:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; br_depth = cast(uint)res64; } while (0);
                if (!aot_compile_op_br_if(comp_ctx, func_ctx, br_depth,
                                          &frame_ip))
                    return false;
                break;
            case WASM_OP_BR_TABLE:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; br_count = cast(uint)res64; } while (0);
                if (((br_depths = wasm_runtime_malloc(cast(uint)uint32.sizeof
                                                      * (br_count + 1))) == 0)) {
                    aot_set_last_error("allocate memory failed.");
                    goto fail;
                }
                for (i = 0; i <= br_count; i++)
                    br_depths[i] = *frame_ip++;
                if (!aot_compile_op_br_table(comp_ctx, func_ctx, br_depths,
                                             br_count, &frame_ip)) {
                    wasm_runtime_free(br_depths);
                    return false;
                }
                wasm_runtime_free(br_depths);
                break;
            case EXT_OP_BR_TABLE_CACHE:
            {
                BrTableCache* node = bh_list_first_elem(
                    comp_ctx.comp_data.wasm_module.br_table_cache_list);
                BrTableCache* node_next = void;
                ubyte* p_opcode = frame_ip - 1;
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; br_count = cast(uint)res64; } while (0);
                while (node) {
                    node_next = bh_list_elem_next(node);
                    if (node.br_table_op_addr == p_opcode) {
                        br_depths = node.br_depths;
                        if (!aot_compile_op_br_table(comp_ctx, func_ctx,
                                                     br_depths, br_count,
                                                     &frame_ip)) {
                            return false;
                        }
                        break;
                    }
                    node = node_next;
                }
                bh_assert(node);
                break;
            }
            case WASM_OP_RETURN:
                if (!aot_compile_op_return(comp_ctx, func_ctx, &frame_ip))
                    return false;
                break;
            case WASM_OP_CALL:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; func_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_call(comp_ctx, func_ctx, func_idx, false))
                    return false;
                break;
            case WASM_OP_CALL_INDIRECT:
            {
                uint tbl_idx = void;
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; type_idx = cast(uint)res64; } while (0);
                {
                    frame_ip++;
                    tbl_idx = 0;
                }
                if (!aot_compile_op_call_indirect(comp_ctx, func_ctx, type_idx,
                                                  tbl_idx))
                    return false;
                break;
            }
            case WASM_OP_DROP:
                if (!aot_compile_op_drop(comp_ctx, func_ctx, true))
                    return false;
                break;
            case WASM_OP_DROP_64:
                if (!aot_compile_op_drop(comp_ctx, func_ctx, false))
                    return false;
                break;
            case WASM_OP_SELECT:
                if (!aot_compile_op_select(comp_ctx, func_ctx, true))
                    return false;
                break;
            case WASM_OP_SELECT_64:
                if (!aot_compile_op_select(comp_ctx, func_ctx, false))
                    return false;
                break;
            case WASM_OP_GET_LOCAL:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; local_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_get_local(comp_ctx, func_ctx, local_idx))
                    return false;
                break;
            case WASM_OP_SET_LOCAL:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; local_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_set_local(comp_ctx, func_ctx, local_idx))
                    return false;
                break;
            case WASM_OP_TEE_LOCAL:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; local_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_tee_local(comp_ctx, func_ctx, local_idx))
                    return false;
                break;
            case WASM_OP_GET_GLOBAL:
            case WASM_OP_GET_GLOBAL_64:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; global_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_get_global(comp_ctx, func_ctx, global_idx))
                    return false;
                break;
            case WASM_OP_SET_GLOBAL:
            case WASM_OP_SET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_AUX_STACK:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; global_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_set_global(
                        comp_ctx, func_ctx, global_idx,
                        opcode == WASM_OP_SET_GLOBAL_AUX_STACK ? true : false))
                    return false;
                break;
            case WASM_OP_I32_LOAD:
                bytes = 4;
                sign = true;
                goto op_i32_load;
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
                bytes = 1;
                sign = (opcode == WASM_OP_I32_LOAD8_S) ? true : false;
                goto op_i32_load;
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
                bytes = 2;
                sign = (opcode == WASM_OP_I32_LOAD16_S) ? true : false;
            op_i32_load:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_i32_load(comp_ctx, func_ctx, align_, offset,
                                             bytes, sign, false))
                    return false;
                break;
            case WASM_OP_I64_LOAD:
                bytes = 8;
                sign = true;
                goto op_i64_load;
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
                bytes = 1;
                sign = (opcode == WASM_OP_I64_LOAD8_S) ? true : false;
                goto op_i64_load;
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
                bytes = 2;
                sign = (opcode == WASM_OP_I64_LOAD16_S) ? true : false;
                goto op_i64_load;
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
                bytes = 4;
                sign = (opcode == WASM_OP_I64_LOAD32_S) ? true : false;
            op_i64_load:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_i64_load(comp_ctx, func_ctx, align_, offset,
                                             bytes, sign, false))
                    return false;
                break;
            case WASM_OP_F32_LOAD:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_f32_load(comp_ctx, func_ctx, align_, offset))
                    return false;
                break;
            case WASM_OP_F64_LOAD:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_f64_load(comp_ctx, func_ctx, align_, offset))
                    return false;
                break;
            case WASM_OP_I32_STORE:
                bytes = 4;
                goto op_i32_store;
            case WASM_OP_I32_STORE8:
                bytes = 1;
                goto op_i32_store;
            case WASM_OP_I32_STORE16:
                bytes = 2;
            op_i32_store:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_i32_store(comp_ctx, func_ctx, align_, offset,
                                              bytes, false))
                    return false;
                break;
            case WASM_OP_I64_STORE:
                bytes = 8;
                goto op_i64_store;
            case WASM_OP_I64_STORE8:
                bytes = 1;
                goto op_i64_store;
            case WASM_OP_I64_STORE16:
                bytes = 2;
                goto op_i64_store;
            case WASM_OP_I64_STORE32:
                bytes = 4;
            op_i64_store:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_i64_store(comp_ctx, func_ctx, align_, offset,
                                              bytes, false))
                    return false;
                break;
            case WASM_OP_F32_STORE:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_f32_store(comp_ctx, func_ctx, align_,
                                              offset))
                    return false;
                break;
            case WASM_OP_F64_STORE:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; align_ = cast(uint)res64; } while (0);
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; offset = cast(uint)res64; } while (0);
                if (!aot_compile_op_f64_store(comp_ctx, func_ctx, align_,
                                              offset))
                    return false;
                break;
            case WASM_OP_MEMORY_SIZE:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; mem_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_memory_size(comp_ctx, func_ctx))
                    return false;
                cast(void)mem_idx;
                break;
            case WASM_OP_MEMORY_GROW:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; mem_idx = cast(uint)res64; } while (0);
                if (!aot_compile_op_memory_grow(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_CONST:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, true, &res64)) return false; frame_ip += off; i32_const = cast(int)res64; } while (0);
                if (!aot_compile_op_i32_const(comp_ctx, func_ctx, i32_const))
                    return false;
                break;
            case WASM_OP_I64_CONST:
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 64, true, &res64)) return false; frame_ip += off; i64_const = cast(long)res64; } while (0);
                if (!aot_compile_op_i64_const(comp_ctx, func_ctx, i64_const))
                    return false;
                break;
            case WASM_OP_F32_CONST:
                p_f32 = cast(ubyte*)&f32_const;
                for (i = 0; i < float32.sizeof; i++)
                    *p_f32++ = *frame_ip++;
                if (!aot_compile_op_f32_const(comp_ctx, func_ctx, f32_const))
                    return false;
                break;
            case WASM_OP_F64_CONST:
                p_f64 = cast(ubyte*)&f64_const;
                for (i = 0; i < float64.sizeof; i++)
                    *p_f64++ = *frame_ip++;
                if (!aot_compile_op_f64_const(comp_ctx, func_ctx, f64_const))
                    return false;
                break;
            case WASM_OP_I32_EQZ:
            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
                if (!aot_compile_op_i32_compare(
                        comp_ctx, func_ctx, INT_EQZ + opcode - WASM_OP_I32_EQZ))
                    return false;
                break;
            case WASM_OP_I64_EQZ:
            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
                if (!aot_compile_op_i64_compare(
                        comp_ctx, func_ctx, INT_EQZ + opcode - WASM_OP_I64_EQZ))
                    return false;
                break;
            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
                if (!aot_compile_op_f32_compare(
                        comp_ctx, func_ctx, FLOAT_EQ + opcode - WASM_OP_F32_EQ))
                    return false;
                break;
            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
                if (!aot_compile_op_f64_compare(
                        comp_ctx, func_ctx, FLOAT_EQ + opcode - WASM_OP_F64_EQ))
                    return false;
                break;
            case WASM_OP_I32_CLZ:
                if (!aot_compile_op_i32_clz(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_CTZ:
                if (!aot_compile_op_i32_ctz(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_POPCNT:
                if (!aot_compile_op_i32_popcnt(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
                if (!aot_compile_op_i32_arithmetic(
                        comp_ctx, func_ctx, INT_ADD + opcode - WASM_OP_I32_ADD,
                        &frame_ip))
                    return false;
                break;
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
                if (!aot_compile_op_i32_bitwise(
                        comp_ctx, func_ctx, INT_SHL + opcode - WASM_OP_I32_AND))
                    return false;
                break;
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
                if (!aot_compile_op_i32_shift(
                        comp_ctx, func_ctx, INT_SHL + opcode - WASM_OP_I32_SHL))
                    return false;
                break;
            case WASM_OP_I64_CLZ:
                if (!aot_compile_op_i64_clz(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I64_CTZ:
                if (!aot_compile_op_i64_ctz(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I64_POPCNT:
                if (!aot_compile_op_i64_popcnt(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
                if (!aot_compile_op_i64_arithmetic(
                        comp_ctx, func_ctx, INT_ADD + opcode - WASM_OP_I64_ADD,
                        &frame_ip))
                    return false;
                break;
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
                if (!aot_compile_op_i64_bitwise(
                        comp_ctx, func_ctx, INT_SHL + opcode - WASM_OP_I64_AND))
                    return false;
                break;
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
                if (!aot_compile_op_i64_shift(
                        comp_ctx, func_ctx, INT_SHL + opcode - WASM_OP_I64_SHL))
                    return false;
                break;
            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
                if (!aot_compile_op_f32_math(comp_ctx, func_ctx,
                                             FLOAT_ABS + opcode
                                                 - WASM_OP_F32_ABS))
                    return false;
                break;
            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
                if (!aot_compile_op_f32_arithmetic(comp_ctx, func_ctx,
                                                   FLOAT_ADD + opcode
                                                       - WASM_OP_F32_ADD))
                    return false;
                break;
            case WASM_OP_F32_COPYSIGN:
                if (!aot_compile_op_f32_copysign(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
                if (!aot_compile_op_f64_math(comp_ctx, func_ctx,
                                             FLOAT_ABS + opcode
                                                 - WASM_OP_F64_ABS))
                    return false;
                break;
            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
                if (!aot_compile_op_f64_arithmetic(comp_ctx, func_ctx,
                                                   FLOAT_ADD + opcode
                                                       - WASM_OP_F64_ADD))
                    return false;
                break;
            case WASM_OP_F64_COPYSIGN:
                if (!aot_compile_op_f64_copysign(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_WRAP_I64:
                if (!aot_compile_op_i32_wrap_i64(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
                sign = (opcode == WASM_OP_I32_TRUNC_S_F32) ? true : false;
                if (!aot_compile_op_i32_trunc_f32(comp_ctx, func_ctx, sign,
                                                  false))
                    return false;
                break;
            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
                sign = (opcode == WASM_OP_I32_TRUNC_S_F64) ? true : false;
                if (!aot_compile_op_i32_trunc_f64(comp_ctx, func_ctx, sign,
                                                  false))
                    return false;
                break;
            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
                sign = (opcode == WASM_OP_I64_EXTEND_S_I32) ? true : false;
                if (!aot_compile_op_i64_extend_i32(comp_ctx, func_ctx, sign))
                    return false;
                break;
            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
                sign = (opcode == WASM_OP_I64_TRUNC_S_F32) ? true : false;
                if (!aot_compile_op_i64_trunc_f32(comp_ctx, func_ctx, sign,
                                                  false))
                    return false;
                break;
            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
                sign = (opcode == WASM_OP_I64_TRUNC_S_F64) ? true : false;
                if (!aot_compile_op_i64_trunc_f64(comp_ctx, func_ctx, sign,
                                                  false))
                    return false;
                break;
            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
                sign = (opcode == WASM_OP_F32_CONVERT_S_I32) ? true : false;
                if (!aot_compile_op_f32_convert_i32(comp_ctx, func_ctx, sign))
                    return false;
                break;
            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
                sign = (opcode == WASM_OP_F32_CONVERT_S_I64) ? true : false;
                if (!aot_compile_op_f32_convert_i64(comp_ctx, func_ctx, sign))
                    return false;
                break;
            case WASM_OP_F32_DEMOTE_F64:
                if (!aot_compile_op_f32_demote_f64(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
                sign = (opcode == WASM_OP_F64_CONVERT_S_I32) ? true : false;
                if (!aot_compile_op_f64_convert_i32(comp_ctx, func_ctx, sign))
                    return false;
                break;
            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
                sign = (opcode == WASM_OP_F64_CONVERT_S_I64) ? true : false;
                if (!aot_compile_op_f64_convert_i64(comp_ctx, func_ctx, sign))
                    return false;
                break;
            case WASM_OP_F64_PROMOTE_F32:
                if (!aot_compile_op_f64_promote_f32(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_REINTERPRET_F32:
                if (!aot_compile_op_i32_reinterpret_f32(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I64_REINTERPRET_F64:
                if (!aot_compile_op_i64_reinterpret_f64(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_F32_REINTERPRET_I32:
                if (!aot_compile_op_f32_reinterpret_i32(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_F64_REINTERPRET_I64:
                if (!aot_compile_op_f64_reinterpret_i64(comp_ctx, func_ctx))
                    return false;
                break;
            case WASM_OP_I32_EXTEND8_S:
                if (!aot_compile_op_i32_extend_i32(comp_ctx, func_ctx, 8))
                    return false;
                break;
            case WASM_OP_I32_EXTEND16_S:
                if (!aot_compile_op_i32_extend_i32(comp_ctx, func_ctx, 16))
                    return false;
                break;
            case WASM_OP_I64_EXTEND8_S:
                if (!aot_compile_op_i64_extend_i64(comp_ctx, func_ctx, 8))
                    return false;
                break;
            case WASM_OP_I64_EXTEND16_S:
                if (!aot_compile_op_i64_extend_i64(comp_ctx, func_ctx, 16))
                    return false;
                break;
            case WASM_OP_I64_EXTEND32_S:
                if (!aot_compile_op_i64_extend_i64(comp_ctx, func_ctx, 32))
                    return false;
                break;
            case WASM_OP_MISC_PREFIX:
            {
                uint opcode1 = void;
                do { uint off = 0; ulong res64 = void; if (!read_leb(frame_ip, frame_ip_end, &off, 32, false, &res64)) return false; frame_ip += off; opcode1 = cast(uint)res64; } while (0);
                opcode = cast(uint)opcode1;
                switch (opcode) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                        sign = (opcode == WASM_OP_I32_TRUNC_SAT_S_F32) ? true
                                                                       : false;
                        if (!aot_compile_op_i32_trunc_f32(comp_ctx, func_ctx,
                                                          sign, true))
                            return false;
                        break;
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        sign = (opcode == WASM_OP_I32_TRUNC_SAT_S_F64) ? true
                                                                       : false;
                        if (!aot_compile_op_i32_trunc_f64(comp_ctx, func_ctx,
                                                          sign, true))
                            return false;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        sign = (opcode == WASM_OP_I64_TRUNC_SAT_S_F32) ? true
                                                                       : false;
                        if (!aot_compile_op_i64_trunc_f32(comp_ctx, func_ctx,
                                                          sign, true))
                            return false;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        sign = (opcode == WASM_OP_I64_TRUNC_SAT_S_F64) ? true
                                                                       : false;
                        if (!aot_compile_op_i64_trunc_f64(comp_ctx, func_ctx,
                                                          sign, true))
                            return false;
                        break;
                    default:
                        aot_set_last_error("unsupported opcode");
                        return false;
                }
                break;
            }
            default:
                aot_set_last_error("unsupported opcode");
                return false;
        }
    }
    /* Move func_return block to the bottom */
    if (func_ctx.func_return_block) {
        LLVMBasicBlockRef last_block = LLVMGetLastBasicBlock(func_ctx.func);
        if (last_block != func_ctx.func_return_block)
            LLVMMoveBasicBlockAfter(func_ctx.func_return_block, last_block);
    }
    /* Move got_exception block to the bottom */
    if (func_ctx.got_exception_block) {
        LLVMBasicBlockRef last_block = LLVMGetLastBasicBlock(func_ctx.func);
        if (last_block != func_ctx.got_exception_block)
            LLVMMoveBasicBlockAfter(func_ctx.got_exception_block, last_block);
    }
    return true;
fail:
    return false;
}
private bool veriy_module(AOTCompContext* comp_ctx) {
    char* msg = null;
    bool ret = void;
    ret = LLVMVerifyModule(comp_ctx.module_, LLVMPrintMessageAction, &msg);
    if (!ret && msg) {
        if (msg[0] != '\0') {
            aot_set_last_error(msg);
            LLVMDisposeMessage(msg);
            return false;
        }
        LLVMDisposeMessage(msg);
    }
    return true;
}
/* Check whether the target supports hardware atomic instructions */
private bool aot_require_lower_atomic_pass(AOTCompContext* comp_ctx) {
    bool ret = false;
    if (!strncmp(comp_ctx.target_arch, "riscv", 5)) {
        char* feature = LLVMGetTargetMachineFeatureString(comp_ctx.target_machine);
        if (feature) {
            if (!strstr(feature, "+a")) {
                ret = true;
            }
            LLVMDisposeMessage(feature);
        }
    }
    return ret;
}
/* Check whether the target needs to expand switch to if/else */
private bool aot_require_lower_switch_pass(AOTCompContext* comp_ctx) {
    bool ret = false;
    /* IR switch/case will cause .rodata relocation on riscv/xtensa */
    if (!strncmp(comp_ctx.target_arch, "riscv", 5)
        || !strncmp(comp_ctx.target_arch, "xtensa", 6)) {
        ret = true;
    }
    return ret;
}
private bool apply_passes_for_indirect_mode(AOTCompContext* comp_ctx) {
    LLVMPassManagerRef common_pass_mgr = void;
    if (((common_pass_mgr = LLVMCreatePassManager()) == 0)) {
        aot_set_last_error("create pass manager failed");
        return false;
    }
    aot_add_expand_memory_op_pass(common_pass_mgr);
    if (aot_require_lower_atomic_pass(comp_ctx))
        LLVMAddLowerAtomicPass(common_pass_mgr);
    if (aot_require_lower_switch_pass(comp_ctx))
        LLVMAddLowerSwitchPass(common_pass_mgr);
    LLVMRunPassManager(common_pass_mgr, comp_ctx.module_);
    LLVMDisposePassManager(common_pass_mgr);
    return true;
}
bool aot_compile_wasm(AOTCompContext* comp_ctx) {
    uint i = void;
    if (!aot_validate_wasm(comp_ctx)) {
        return false;
    }
    bh_print_time("Begin to compile WASM bytecode to LLVM IR");
    for (i = 0; i < comp_ctx.func_ctx_count; i++) {
        if (!aot_compile_func(comp_ctx, i)) {
            return false;
        }
    }
    /* Disable LLVM module verification for jit mode to speedup
       the compilation process */
    if (!comp_ctx.is_jit_mode) {
        bh_print_time("Begin to verify LLVM module");
        if (!veriy_module(comp_ctx)) {
            return false;
        }
    }
    /* Run IR optimization before feeding in ORCJIT and AOT codegen */
    if (comp_ctx.optimize) {
        /* Run passes for AOT/JIT mode.
           TODO: Apply these passes in the do_ir_transform callback of
           TransformLayer when compiling each jit function, so as to
           speedup the launch process. Now there are two issues in the
           JIT: one is memory leak in do_ir_transform, the other is
           possible core dump. */
        bh_print_time("Begin to run llvm optimization passes");
        aot_apply_llvm_new_pass_manager(comp_ctx, comp_ctx.module_);
        /* Run specific passes for AOT indirect mode in last since general
           optimization may create some intrinsic function calls like
           llvm.memset, so let's remove these function calls here. */
        if (!comp_ctx.is_jit_mode && comp_ctx.is_indirect_mode) {
            bh_print_time("Begin to run optimization passes "
                          ~ "for indirect mode");
            if (!apply_passes_for_indirect_mode(comp_ctx)) {
                return false;
            }
        }
        bh_print_time("Finish llvm optimization passes");
    }
    if (comp_ctx.is_jit_mode) {
        LLVMErrorRef err = void;
        LLVMOrcJITDylibRef orc_main_dylib = void;
        LLVMOrcThreadSafeModuleRef orc_thread_safe_module = void;
        orc_main_dylib = LLVMOrcLLLazyJITGetMainJITDylib(comp_ctx.orc_jit);
        if (!orc_main_dylib) {
            aot_set_last_error(
                "failed to get orc orc_jit main dynmaic library");
            return false;
        }
        orc_thread_safe_module = LLVMOrcCreateNewThreadSafeModule(
            comp_ctx.module_, comp_ctx.orc_thread_safe_context);
        if (!orc_thread_safe_module) {
            aot_set_last_error("failed to create thread safe module");
            return false;
        }
        if ((err = LLVMOrcLLLazyJITAddLLVMIRModule(
                 comp_ctx.orc_jit, orc_main_dylib, orc_thread_safe_module))) {
            /* If adding the ThreadSafeModule fails then we need to clean it up
               by ourselves, otherwise the orc orc_jit will manage the memory.
             */
            LLVMOrcDisposeThreadSafeModule(orc_thread_safe_module);
            aot_handle_llvm_errmsg("failed to addIRModule", err);
            return false;
        }
    }
    return true;
}
char* aot_generate_tempfile_name(const(char)* prefix, const(char)* extension, char* buffer, uint len) {
    int fd = void, name_len = void;
    name_len = snprintf(buffer, len, "%s-XXXXXX", prefix);
    if ((fd = mkstemp(buffer)) <= 0) {
        aot_set_last_error("make temp file failed.");
        return null;
    }
    /* close and remove temp file */
    close(fd);
    unlink(buffer);
    /* Check if buffer length is enough */
    /* name_len + '.' + extension + '\0' */
    if (name_len + 1 + strlen(extension) + 1 > len) {
        aot_set_last_error("temp file name too long.");
        return null;
    }
    snprintf(buffer + name_len, len - name_len, ".%s", extension);
    return buffer;
}
bool aot_emit_llvm_file(AOTCompContext* comp_ctx, const(char)* file_name) {
    char* err = null;
    bh_print_time("Begin to emit LLVM IR file");
    if (LLVMPrintModuleToFile(comp_ctx.module_, file_name, &err) != 0) {
        if (err) {
            LLVMDisposeMessage(err);
            err = null;
        }
        aot_set_last_error("emit llvm ir to file failed.");
        return false;
    }
    return true;
}
bool aot_emit_object_file(AOTCompContext* comp_ctx, char* file_name) {
    char* err = null;
    LLVMCodeGenFileType file_type = LLVMObjectFile;
    LLVMTargetRef target = LLVMGetTargetMachineTarget(comp_ctx.target_machine);
    bh_print_time("Begin to emit object file");
    if (comp_ctx.external_llc_compiler || comp_ctx.external_asm_compiler) {
        char[1024] cmd = void;
        int ret = void;
        if (comp_ctx.external_llc_compiler) {
            char[64] bc_file_name = void;
            if (!aot_generate_tempfile_name("wamrc-bc", "bc", bc_file_name.ptr,
                                            bc_file_name.sizeof)) {
                return false;
            }
            if (LLVMWriteBitcodeToFile(comp_ctx.module_, bc_file_name.ptr) != 0) {
                aot_set_last_error("emit llvm bitcode file failed.");
                return false;
            }
            snprintf(cmd.ptr, cmd.sizeof, "%s %s -o %s %s",
                     comp_ctx.external_llc_compiler,
                     comp_ctx.llc_compiler_flags ? comp_ctx.llc_compiler_flags
                                                  : "-O3 -c",
                     file_name, bc_file_name.ptr);
            LOG_VERBOSE("invoking external LLC compiler:\n\t%s", cmd.ptr);
            ret = system(cmd.ptr);
            /* remove temp bitcode file */
            unlink(bc_file_name.ptr);
            if (ret != 0) {
                aot_set_last_error("failed to compile LLVM bitcode to obj file "
                                   ~ "with external LLC compiler.");
                return false;
            }
        }
        else if (comp_ctx.external_asm_compiler) {
            char[64] asm_file_name = void;
            if (!aot_generate_tempfile_name("wamrc-asm", "s", asm_file_name.ptr,
                                            asm_file_name.sizeof)) {
                return false;
            }
            if (LLVMTargetMachineEmitToFile(comp_ctx.target_machine,
                                            comp_ctx.module_, asm_file_name.ptr,
                                            LLVMAssemblyFile, &err)
                != 0) {
                if (err) {
                    LLVMDisposeMessage(err);
                    err = null;
                }
                aot_set_last_error("emit elf to assembly file failed.");
                return false;
            }
            snprintf(cmd.ptr, cmd.sizeof, "%s %s -o %s %s",
                     comp_ctx.external_asm_compiler,
                     comp_ctx.asm_compiler_flags ? comp_ctx.asm_compiler_flags
                                                  : "-O3 -c",
                     file_name, asm_file_name.ptr);
            LOG_VERBOSE("invoking external ASM compiler:\n\t%s", cmd.ptr);
            ret = system(cmd.ptr);
            /* remove temp assembly file */
            unlink(asm_file_name.ptr);
            if (ret != 0) {
                aot_set_last_error("failed to compile Assembly file to obj "
                                   ~ "file with external ASM compiler.");
                return false;
            }
        }
        return true;
    }
    if (!strncmp(LLVMGetTargetName(target), "arc", 3))
        /* Emit to assmelby file instead for arc target
           as it cannot emit to object file */
        file_type = LLVMAssemblyFile;
    if (LLVMTargetMachineEmitToFile(comp_ctx.target_machine, comp_ctx.module_,
                                    file_name, file_type, &err)
        != 0) {
        if (err) {
            LLVMDisposeMessage(err);
            err = null;
        }
        aot_set_last_error("emit elf to object file failed.");
        return false;
    }
    return true;
}
