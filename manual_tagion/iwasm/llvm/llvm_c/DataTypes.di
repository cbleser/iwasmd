/*===-- include/llvm-c/DataTypes.h - Define fixed size types ------*- C -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This file contains definitions to figure out the size of _HOST_ data types.*|
|* This file is important because different host OS's define different macros,*|
|* which makes portability tough.  This file exports the following            *|
|* definitions:                                                               *|
|*                                                                            *|
|*   [u]int(32|64)_t : typedefs for signed and unsigned 32/64 bit system types*|
|*   [U]INT(8|16|32|64)_(MIN|MAX) : Constants for the min and max values.     *|
|*                                                                            *|
|* No library is required when using these functions.                         *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*/

/* Please leave this file C-compatible. */

extern (C):

/* Note that <inttypes.h> includes <stdint.h>, if this is a C99 system. */

// GCC is strict about defining large constants: they must have LL modifier.

/* _MSC_VER */

/* _WIN64 */

/* _MSC_VER */

/* Set defaults for constants which we cannot find. */

/* LLVM_C_DATATYPES_H */
