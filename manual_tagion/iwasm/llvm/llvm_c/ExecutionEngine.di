/*===-- llvm-c/ExecutionEngine.h - ExecutionEngine Lib C Iface --*- C++ -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to libLLVMExecutionEngine.o, which    *|
|* implements various analyses of the LLVM IR.                                *|
|*                                                                            *|
|* Many exotic languages can interoperate with C code but have a harder time  *|
|* with C++ due to name mangling. So in addition to C, this interface enables *|
|* tools written in such languages.                                           *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

import core.stdc.inttypes;
import tagion.iwasm.llvm.llvm_c.Types;
import tagion.iwasm.llvm.llvm_c.TargetMachine;
import tagion.iwasm.llvm.llvm_c.Target;
@nogc nothrow:
extern (C):

/**
 * @defgroup LLVMCExecutionEngine Execution Engine
 * @ingroup LLVMC
 *
 * @{
 */

void LLVMLinkInMCJIT ();
void LLVMLinkInInterpreter ();

struct LLVMOpaqueGenericValue;
alias LLVMGenericValueRef = LLVMOpaqueGenericValue*;
struct LLVMOpaqueExecutionEngine;
alias LLVMExecutionEngineRef = LLVMOpaqueExecutionEngine*;
struct LLVMOpaqueMCJITMemoryManager;
alias LLVMMCJITMemoryManagerRef = LLVMOpaqueMCJITMemoryManager*;

struct LLVMMCJITCompilerOptions
{
    uint OptLevel;
    LLVMCodeModel CodeModel;
    LLVMBool NoFramePointerElim;
    LLVMBool EnableFastISel;
    LLVMMCJITMemoryManagerRef MCJMM;
}

/*===-- Operations on generic values --------------------------------------===*/

LLVMGenericValueRef LLVMCreateGenericValueOfInt (
    LLVMTypeRef Ty,
    ulong N,
    LLVMBool IsSigned);

LLVMGenericValueRef LLVMCreateGenericValueOfPointer (void* P);

LLVMGenericValueRef LLVMCreateGenericValueOfFloat (LLVMTypeRef Ty, double N);

uint LLVMGenericValueIntWidth (LLVMGenericValueRef GenValRef);

ulong LLVMGenericValueToInt (LLVMGenericValueRef GenVal, LLVMBool IsSigned);

void* LLVMGenericValueToPointer (LLVMGenericValueRef GenVal);

double LLVMGenericValueToFloat (LLVMTypeRef TyRef, LLVMGenericValueRef GenVal);

void LLVMDisposeGenericValue (LLVMGenericValueRef GenVal);

/*===-- Operations on execution engines -----------------------------------===*/

LLVMBool LLVMCreateExecutionEngineForModule (
    LLVMExecutionEngineRef* OutEE,
    LLVMModuleRef M,
    char** OutError);

LLVMBool LLVMCreateInterpreterForModule (
    LLVMExecutionEngineRef* OutInterp,
    LLVMModuleRef M,
    char** OutError);

LLVMBool LLVMCreateJITCompilerForModule (
    LLVMExecutionEngineRef* OutJIT,
    LLVMModuleRef M,
    uint OptLevel,
    char** OutError);

void LLVMInitializeMCJITCompilerOptions (
    LLVMMCJITCompilerOptions* Options,
    size_t SizeOfOptions);

/**
 * Create an MCJIT execution engine for a module, with the given options. It is
 * the responsibility of the caller to ensure that all fields in Options up to
 * the given SizeOfOptions are initialized. It is correct to pass a smaller
 * value of SizeOfOptions that omits some fields. The canonical way of using
 * this is:
 *
 * LLVMMCJITCompilerOptions options;
 * LLVMInitializeMCJITCompilerOptions(&options, sizeof(options));
 * ... fill in those options you care about
 * LLVMCreateMCJITCompilerForModule(&jit, mod, &options, sizeof(options),
 *                                  &error);
 *
 * Note that this is also correct, though possibly suboptimal:
 *
 * LLVMCreateMCJITCompilerForModule(&jit, mod, 0, 0, &error);
 */
LLVMBool LLVMCreateMCJITCompilerForModule (
    LLVMExecutionEngineRef* OutJIT,
    LLVMModuleRef M,
    LLVMMCJITCompilerOptions* Options,
    size_t SizeOfOptions,
    char** OutError);

void LLVMDisposeExecutionEngine (LLVMExecutionEngineRef EE);

void LLVMRunStaticConstructors (LLVMExecutionEngineRef EE);

void LLVMRunStaticDestructors (LLVMExecutionEngineRef EE);

int LLVMRunFunctionAsMain (
    LLVMExecutionEngineRef EE,
    LLVMValueRef F,
    uint ArgC,
    const(char*)* ArgV,
    const(char*)* EnvP);

LLVMGenericValueRef LLVMRunFunction (
    LLVMExecutionEngineRef EE,
    LLVMValueRef F,
    uint NumArgs,
    LLVMGenericValueRef* Args);

void LLVMFreeMachineCodeForFunction (LLVMExecutionEngineRef EE, LLVMValueRef F);

void LLVMAddModule (LLVMExecutionEngineRef EE, LLVMModuleRef M);

LLVMBool LLVMRemoveModule (
    LLVMExecutionEngineRef EE,
    LLVMModuleRef M,
    LLVMModuleRef* OutMod,
    char** OutError);

LLVMBool LLVMFindFunction (
    LLVMExecutionEngineRef EE,
    const(char)* Name,
    LLVMValueRef* OutFn);

void* LLVMRecompileAndRelinkFunction (
    LLVMExecutionEngineRef EE,
    LLVMValueRef Fn);

LLVMTargetDataRef LLVMGetExecutionEngineTargetData (LLVMExecutionEngineRef EE);
LLVMTargetMachineRef LLVMGetExecutionEngineTargetMachine (
    LLVMExecutionEngineRef EE);

void LLVMAddGlobalMapping (
    LLVMExecutionEngineRef EE,
    LLVMValueRef Global,
    void* Addr);

void* LLVMGetPointerToGlobal (LLVMExecutionEngineRef EE, LLVMValueRef Global);

ulong LLVMGetGlobalValueAddress (LLVMExecutionEngineRef EE, const(char)* Name);

ulong LLVMGetFunctionAddress (LLVMExecutionEngineRef EE, const(char)* Name);

/// Returns true on error, false on success. If true is returned then the error
/// message is copied to OutStr and cleared in the ExecutionEngine instance.
LLVMBool LLVMExecutionEngineGetErrMsg (
    LLVMExecutionEngineRef EE,
    char** OutError);

/*===-- Operations on memory managers -------------------------------------===*/

alias LLVMMemoryManagerAllocateCodeSectionCallback = ubyte* function (
    void* Opaque,
    uintptr_t Size,
    uint Alignment,
    uint SectionID,
    const(char)* SectionName);
alias LLVMMemoryManagerAllocateDataSectionCallback = ubyte* function (
    void* Opaque,
    uintptr_t Size,
    uint Alignment,
    uint SectionID,
    const(char)* SectionName,
    LLVMBool IsReadOnly);
alias LLVMMemoryManagerFinalizeMemoryCallback = int function (
    void* Opaque,
    char** ErrMsg);
alias LLVMMemoryManagerDestroyCallback = void function (void* Opaque);

/**
 * Create a simple custom MCJIT memory manager. This memory manager can
 * intercept allocations in a module-oblivious way. This will return NULL
 * if any of the passed functions are NULL.
 *
 * @param Opaque An opaque client object to pass back to the callbacks.
 * @param AllocateCodeSection Allocate a block of memory for executable code.
 * @param AllocateDataSection Allocate a block of memory for data.
 * @param FinalizeMemory Set page permissions and flush cache. Return 0 on
 *   success, 1 on error.
 */
LLVMMCJITMemoryManagerRef LLVMCreateSimpleMCJITMemoryManager (
    void* Opaque,
    LLVMMemoryManagerAllocateCodeSectionCallback AllocateCodeSection,
    LLVMMemoryManagerAllocateDataSectionCallback AllocateDataSection,
    LLVMMemoryManagerFinalizeMemoryCallback FinalizeMemory,
    LLVMMemoryManagerDestroyCallback Destroy);

void LLVMDisposeMCJITMemoryManager (LLVMMCJITMemoryManagerRef MM);

/*===-- JIT Event Listener functions -------------------------------------===*/

LLVMJITEventListenerRef LLVMCreateGDBRegistrationListener ();
LLVMJITEventListenerRef LLVMCreateIntelJITEventListener ();
LLVMJITEventListenerRef LLVMCreateOProfileJITEventListener ();
LLVMJITEventListenerRef LLVMCreatePerfJITEventListener ();

/**
 * @}
 */

