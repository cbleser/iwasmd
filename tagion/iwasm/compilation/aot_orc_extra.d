module aot_orc_extra;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

import tagion.iwasm.llvm.llvm_c.Error;
import tagion.iwasm.llvm.llvm_c.ExternC;
import tagion.iwasm.llvm.llvm_c.LLJIT;
import tagion.iwasm.llvm.llvm_c.Orc;
import tagion.iwasm.llvm.llvm_c.Types;

//LLVM_C_EXTERN_C_BEGIN typedef; LLVMOrcOpaqueLLLazyJITBuilder* LLVMOrcLLLazyJITBuilderRef;
struct LLVMOrcOpaqueLLLazyJIT {
}

alias LLVMOrcLLLazyJITRef = LLVMOrcOpaqueLLLazyJIT*;
version(IWASM_PROBLEM) { 

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
}

