/*===-- llvm-c/TargetMachine.h - Target Machine Library C Interface - C++ -*-=*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to the Target and TargetMachine       *|
|* classes, which can be used to generate assembly or object files.           *|
|*                                                                            *|
|* Many exotic languages can interoperate with C code but have a harder time  *|
|* with C++ due to name mangling. So in addition to C, this interface enables *|
|* tools written in such languages.                                           *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

extern (C):

struct LLVMOpaqueTargetMachine;
alias LLVMTargetMachineRef = LLVMOpaqueTargetMachine*;
struct LLVMTarget;
alias LLVMTargetRef = LLVMTarget*;

enum LLVMCodeGenOptLevel
{
    LLVMCodeGenLevelNone = 0,
    LLVMCodeGenLevelLess = 1,
    LLVMCodeGenLevelDefault = 2,
    LLVMCodeGenLevelAggressive = 3
}

enum LLVMRelocMode
{
    LLVMRelocDefault = 0,
    LLVMRelocStatic = 1,
    LLVMRelocPIC = 2,
    LLVMRelocDynamicNoPic = 3,
    LLVMRelocROPI = 4,
    LLVMRelocRWPI = 5,
    LLVMRelocROPI_RWPI = 6
}

enum LLVMCodeModel
{
    LLVMCodeModelDefault = 0,
    LLVMCodeModelJITDefault = 1,
    LLVMCodeModelTiny = 2,
    LLVMCodeModelSmall = 3,
    LLVMCodeModelKernel = 4,
    LLVMCodeModelMedium = 5,
    LLVMCodeModelLarge = 6
}

enum LLVMCodeGenFileType
{
    LLVMAssemblyFile = 0,
    LLVMObjectFile = 1
}

/** Returns the first llvm::Target in the registered targets list. */
LLVMTargetRef LLVMGetFirstTarget ();
/** Returns the next llvm::Target given a previous one (or null if there's none) */
LLVMTargetRef LLVMGetNextTarget (LLVMTargetRef T);

/*===-- Target ------------------------------------------------------------===*/
/** Finds the target corresponding to the given name and stores it in \p T.
  Returns 0 on success. */
LLVMTargetRef LLVMGetTargetFromName (const(char)* Name);

/** Finds the target corresponding to the given triple and stores it in \p T.
  Returns 0 on success. Optionally returns any error in ErrorMessage.
  Use LLVMDisposeMessage to dispose the message. */
LLVMBool LLVMGetTargetFromTriple (
    const(char)* Triple,
    LLVMTargetRef* T,
    char** ErrorMessage);

/** Returns the name of a target. See llvm::Target::getName */
const(char)* LLVMGetTargetName (LLVMTargetRef T);

/** Returns the description  of a target. See llvm::Target::getDescription */
const(char)* LLVMGetTargetDescription (LLVMTargetRef T);

/** Returns if the target has a JIT */
LLVMBool LLVMTargetHasJIT (LLVMTargetRef T);

/** Returns if the target has a TargetMachine associated */
LLVMBool LLVMTargetHasTargetMachine (LLVMTargetRef T);

/** Returns if the target as an ASM backend (required for emitting output) */
LLVMBool LLVMTargetHasAsmBackend (LLVMTargetRef T);

/*===-- Target Machine ----------------------------------------------------===*/
/** Creates a new llvm::TargetMachine. See llvm::Target::createTargetMachine */
LLVMTargetMachineRef LLVMCreateTargetMachine (
    LLVMTargetRef T,
    const(char)* Triple,
    const(char)* CPU,
    const(char)* Features,
    LLVMCodeGenOptLevel Level,
    LLVMRelocMode Reloc,
    LLVMCodeModel CodeModel);

/** Dispose the LLVMTargetMachineRef instance generated by
  LLVMCreateTargetMachine. */
void LLVMDisposeTargetMachine (LLVMTargetMachineRef T);

/** Returns the Target used in a TargetMachine */
LLVMTargetRef LLVMGetTargetMachineTarget (LLVMTargetMachineRef T);

/** Returns the triple used creating this target machine. See
  llvm::TargetMachine::getTriple. The result needs to be disposed with
  LLVMDisposeMessage. */
char* LLVMGetTargetMachineTriple (LLVMTargetMachineRef T);

/** Returns the cpu used creating this target machine. See
  llvm::TargetMachine::getCPU. The result needs to be disposed with
  LLVMDisposeMessage. */
char* LLVMGetTargetMachineCPU (LLVMTargetMachineRef T);

/** Returns the feature string used creating this target machine. See
  llvm::TargetMachine::getFeatureString. The result needs to be disposed with
  LLVMDisposeMessage. */
char* LLVMGetTargetMachineFeatureString (LLVMTargetMachineRef T);

/** Create a DataLayout based on the targetMachine. */
LLVMTargetDataRef LLVMCreateTargetDataLayout (LLVMTargetMachineRef T);

/** Set the target machine's ASM verbosity. */
void LLVMSetTargetMachineAsmVerbosity (
    LLVMTargetMachineRef T,
    LLVMBool VerboseAsm);

/** Emits an asm or object file for the given module to the filename. This
  wraps several c++ only classes (among them a file stream). Returns any
  error in ErrorMessage. Use LLVMDisposeMessage to dispose the message. */
LLVMBool LLVMTargetMachineEmitToFile (
    LLVMTargetMachineRef T,
    LLVMModuleRef M,
    char* Filename,
    LLVMCodeGenFileType codegen,
    char** ErrorMessage);

/** Compile the LLVM IR stored in \p M and store the result in \p OutMemBuf. */
LLVMBool LLVMTargetMachineEmitToMemoryBuffer (
    LLVMTargetMachineRef T,
    LLVMModuleRef M,
    LLVMCodeGenFileType codegen,
    char** ErrorMessage,
    LLVMMemoryBufferRef* OutMemBuf);

/*===-- Triple ------------------------------------------------------------===*/
/** Get a triple for the host machine as a string. The result needs to be
  disposed with LLVMDisposeMessage. */
char* LLVMGetDefaultTargetTriple ();

/** Normalize a target triple. The result needs to be disposed with
  LLVMDisposeMessage. */
char* LLVMNormalizeTargetTriple (const(char)* triple);

/** Get the host CPU as a string. The result needs to be disposed with
  LLVMDisposeMessage. */
char* LLVMGetHostCPUName ();

/** Get the host CPU's features as a string. The result needs to be disposed
  with LLVMDisposeMessage. */
char* LLVMGetHostCPUFeatures ();

/** Adds the target-specific analysis passes to the pass manager. */
void LLVMAddAnalysisPasses (LLVMTargetMachineRef T, LLVMPassManagerRef PM);

