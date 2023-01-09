/*===-- llvm-c/Comdat.h - Module Comdat C Interface -------------*- C++ -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This file defines the C interface to COMDAT.                               *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

extern (C):

enum LLVMComdatSelectionKind
{
    LLVMAnyComdatSelectionKind = 0, ///< The linker may choose any COMDAT.
    LLVMExactMatchComdatSelectionKind = 1, ///< The data referenced by the COMDAT must
    ///< be the same.
    LLVMLargestComdatSelectionKind = 2, ///< The linker will choose the largest
    ///< COMDAT.
    LLVMNoDeduplicateComdatSelectionKind = 3, ///< No deduplication is performed.
    LLVMSameSizeComdatSelectionKind = 4 ///< The data referenced by the COMDAT must be
    ///< the same size.
}

/**
 * Return the Comdat in the module with the specified name. It is created
 * if it didn't already exist.
 *
 * @see llvm::Module::getOrInsertComdat()
 */
LLVMComdatRef LLVMGetOrInsertComdat (LLVMModuleRef M, const(char)* Name);

/**
 * Get the Comdat assigned to the given global object.
 *
 * @see llvm::GlobalObject::getComdat()
 */
LLVMComdatRef LLVMGetComdat (LLVMValueRef V);

/**
 * Assign the Comdat to the given global object.
 *
 * @see llvm::GlobalObject::setComdat()
 */
void LLVMSetComdat (LLVMValueRef V, LLVMComdatRef C);

/*
 * Get the conflict resolution selection kind for the Comdat.
 *
 * @see llvm::Comdat::getSelectionKind()
 */
LLVMComdatSelectionKind LLVMGetComdatSelectionKind (LLVMComdatRef C);

/*
 * Set the conflict resolution selection kind for the Comdat.
 *
 * @see llvm::Comdat::setSelectionKind()
 */
void LLVMSetComdatSelectionKind (LLVMComdatRef C, LLVMComdatSelectionKind Kind);

