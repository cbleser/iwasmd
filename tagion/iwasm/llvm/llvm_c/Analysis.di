/*===-- llvm-c/Analysis.h - Analysis Library C Interface --------*- C++ -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to libLLVMAnalysis.a, which           *|
|* implements various analyses of the LLVM IR.                                *|
|*                                                                            *|
|* Many exotic languages can interoperate with C code but have a harder time  *|
|* with C++ due to name mangling. So in addition to C, this interface enables *|
|* tools written in such languages.                                           *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
import tagion.iwasm.llvm.llvm_c.Types;

@nogc nothrow:
extern (C):

/**
 * @defgroup LLVMCAnalysis Analysis
 * @ingroup LLVMC
 *
 * @{
 */

enum LLVMVerifierFailureAction
{
    LLVMAbortProcessAction = 0, /* verifier will print to stderr and abort() */
    LLVMPrintMessageAction = 1, /* verifier will print to stderr and return 1 */
    LLVMReturnStatusAction = 2 /* verifier will just return 1 */
}

/* Verifies that a module is valid, taking the specified action if not.
   Optionally returns a human-readable description of any invalid constructs.
   OutMessage must be disposed with LLVMDisposeMessage. */
LLVMBool LLVMVerifyModule (
    LLVMModuleRef M,
    LLVMVerifierFailureAction Action,
    char** OutMessage);

/* Verifies that a single function is valid, taking the specified action. Useful
   for debugging. */
LLVMBool LLVMVerifyFunction (LLVMValueRef Fn, LLVMVerifierFailureAction Action);

/* Open up a ghostview window that displays the CFG of the current function.
   Useful for debugging. */
void LLVMViewFunctionCFG (LLVMValueRef Fn);
void LLVMViewFunctionCFGOnly (LLVMValueRef Fn);

/**
 * @}
 */

