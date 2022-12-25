module aot_orc_extra;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import llvm-c.Error;
public import llvm-c.ExternC;
public import llvm-c.LLJIT;
public import llvm-c.Orc;
public import llvm-c.Types;

LLVM_C_EXTERN_C_BEGIN typedef; LLVMOrcOpaqueLLLazyJITBuilder* LLVMOrcLLLazyJITBuilderRef;
alias LLVMOrcLLLazyJITRef = LLVMOrcOpaqueLLLazyJIT*;

// Extra bindings for LLJIT
void LLVMOrcLLJITBuilderSetNumCompileThreads(LLVMOrcLLJITBuilderRef Builder, uint NumCompileThreads);

// Extra bindings for LLLazyJIT
LLVMOrcLLLazyJITBuilderRef LLVMOrcCreateLLLazyJITBuilder();

void LLVMOrcDisposeLLLazyJITBuilder(LLVMOrcLLLazyJITBuilderRef Builder);

void LLVMOrcLLLazyJITBuilderSetJITTargetMachineBuilder(LLVMOrcLLLazyJITBuilderRef Builder, LLVMOrcJITTargetMachineBuilderRef JTMP);

void LLVMOrcLLLazyJITBuilderSetNumCompileThreads(LLVMOrcLLLazyJITBuilderRef Builder, uint NumCompileThreads);

LLVMErrorRef LLVMOrcCreateLLLazyJIT(LLVMOrcLLLazyJITRef* Result, LLVMOrcLLLazyJITBuilderRef Builder);

LLVMErrorRef LLVMOrcDisposeLLLazyJIT(LLVMOrcLLLazyJITRef J);

LLVMErrorRef LLVMOrcLLLazyJITAddLLVMIRModule(LLVMOrcLLLazyJITRef J, LLVMOrcJITDylibRef JD, LLVMOrcThreadSafeModuleRef TSM);

LLVMErrorRef LLVMOrcLLLazyJITLookup(LLVMOrcLLLazyJITRef J, LLVMOrcExecutorAddress* Result, const(char)* Name);

LLVMOrcSymbolStringPoolEntryRef LLVMOrcLLLazyJITMangleAndIntern(LLVMOrcLLLazyJITRef J, const(char)* UnmangledName);

LLVMOrcJITDylibRef LLVMOrcLLLazyJITGetMainJITDylib(LLVMOrcLLLazyJITRef J);

const(char)* LLVMOrcLLLazyJITGetTripleString(LLVMOrcLLLazyJITRef J);

LLVMOrcExecutionSessionRef LLVMOrcLLLazyJITGetExecutionSession(LLVMOrcLLLazyJITRef J);

LLVMOrcIRTransformLayerRef LLVMOrcLLLazyJITGetIRTransformLayer(LLVMOrcLLLazyJITRef J);

LLVMOrcObjectTransformLayerRef LLVMOrcLLLazyJITGetObjTransformLayer(LLVMOrcLLLazyJITRef J);

LLVM_C_EXTERN_C_END

