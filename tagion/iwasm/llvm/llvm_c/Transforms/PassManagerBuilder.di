/*===-- llvm-c/Transform/PassManagerBuilder.h - PMB C Interface ---*- C -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to the PassManagerBuilder class.      *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
import tagion.iwasm.llvm.llvm_c.Types;
@nogc nothrow:

extern (C):

struct LLVMOpaquePassManagerBuilder;
alias LLVMPassManagerBuilderRef = LLVMOpaquePassManagerBuilder*;

/**
 * @defgroup LLVMCTransformsPassManagerBuilder Pass manager builder
 * @ingroup LLVMCTransforms
 *
 * @{
 */

/** See llvm::PassManagerBuilder. */
LLVMPassManagerBuilderRef LLVMPassManagerBuilderCreate ();
void LLVMPassManagerBuilderDispose (LLVMPassManagerBuilderRef PMB);

/** See llvm::PassManagerBuilder::OptLevel. */
void LLVMPassManagerBuilderSetOptLevel (
    LLVMPassManagerBuilderRef PMB,
    uint OptLevel);

/** See llvm::PassManagerBuilder::SizeLevel. */
void LLVMPassManagerBuilderSetSizeLevel (
    LLVMPassManagerBuilderRef PMB,
    uint SizeLevel);

/** See llvm::PassManagerBuilder::DisableUnitAtATime. */
void LLVMPassManagerBuilderSetDisableUnitAtATime (
    LLVMPassManagerBuilderRef PMB,
    LLVMBool Value);

/** See llvm::PassManagerBuilder::DisableUnrollLoops. */
void LLVMPassManagerBuilderSetDisableUnrollLoops (
    LLVMPassManagerBuilderRef PMB,
    LLVMBool Value);

/** See llvm::PassManagerBuilder::DisableSimplifyLibCalls */
void LLVMPassManagerBuilderSetDisableSimplifyLibCalls (
    LLVMPassManagerBuilderRef PMB,
    LLVMBool Value);

/** See llvm::PassManagerBuilder::Inliner. */
void LLVMPassManagerBuilderUseInlinerWithThreshold (
    LLVMPassManagerBuilderRef PMB,
    uint Threshold);

/** See llvm::PassManagerBuilder::populateFunctionPassManager. */
void LLVMPassManagerBuilderPopulateFunctionPassManager (
    LLVMPassManagerBuilderRef PMB,
    LLVMPassManagerRef PM);

/** See llvm::PassManagerBuilder::populateModulePassManager. */
void LLVMPassManagerBuilderPopulateModulePassManager (
    LLVMPassManagerBuilderRef PMB,
    LLVMPassManagerRef PM);

/** See llvm::PassManagerBuilder::populateLTOPassManager. */
void LLVMPassManagerBuilderPopulateLTOPassManager (
    LLVMPassManagerBuilderRef PMB,
    LLVMPassManagerRef PM,
    LLVMBool Internalize,
    LLVMBool RunInliner);

/**
 * @}
 */

