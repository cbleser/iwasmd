/*===-- llvm-c/Support.h - C Interface Types declarations ---------*- C -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This file defines types used by the C interface to LLVM.                   *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

extern (C):

/**
 * @defgroup LLVMCSupportTypes Types and Enumerations
 *
 * @{
 */

alias LLVMBool = int;

/* Opaque types. */

/**
 * LLVM uses a polymorphic type hierarchy which C cannot represent, therefore
 * parameters must be passed as base types. Despite the declared types, most
 * of the functions provided operate only on branches of the type hierarchy.
 * The declared parameter names are descriptive and specify which type is
 * required. Additionally, each type hierarchy is documented along with the
 * functions that operate upon it. For more detail, refer to LLVM's C++ code.
 * If in doubt, refer to Core.cpp, which performs parameter downcasts in the
 * form unwrap<RequiredType>(Param).
 */

/**
 * Used to pass regions of memory through LLVM interfaces.
 *
 * @see llvm::MemoryBuffer
 */
struct LLVMOpaqueMemoryBuffer;
alias LLVMMemoryBufferRef = LLVMOpaqueMemoryBuffer*;

/**
 * The top-level container for all LLVM global data. See the LLVMContext class.
 */
struct LLVMOpaqueContext;
alias LLVMContextRef = LLVMOpaqueContext*;

/**
 * The top-level container for all other LLVM Intermediate Representation (IR)
 * objects.
 *
 * @see llvm::Module
 */
struct LLVMOpaqueModule;
alias LLVMModuleRef = LLVMOpaqueModule*;

/**
 * Each value in the LLVM IR has a type, an LLVMTypeRef.
 *
 * @see llvm::Type
 */
struct LLVMOpaqueType;
alias LLVMTypeRef = LLVMOpaqueType*;

/**
 * Represents an individual value in LLVM IR.
 *
 * This models llvm::Value.
 */
struct LLVMOpaqueValue;
alias LLVMValueRef = LLVMOpaqueValue*;

/**
 * Represents a basic block of instructions in LLVM IR.
 *
 * This models llvm::BasicBlock.
 */
struct LLVMOpaqueBasicBlock;
alias LLVMBasicBlockRef = LLVMOpaqueBasicBlock*;

/**
 * Represents an LLVM Metadata.
 *
 * This models llvm::Metadata.
 */
struct LLVMOpaqueMetadata;
alias LLVMMetadataRef = LLVMOpaqueMetadata*;

/**
 * Represents an LLVM Named Metadata Node.
 *
 * This models llvm::NamedMDNode.
 */
struct LLVMOpaqueNamedMDNode;
alias LLVMNamedMDNodeRef = LLVMOpaqueNamedMDNode*;

/**
 * Represents an entry in a Global Object's metadata attachments.
 *
 * This models std::pair<unsigned, MDNode *>
 */
struct LLVMOpaqueValueMetadataEntry;
alias LLVMValueMetadataEntry = LLVMOpaqueValueMetadataEntry;

/**
 * Represents an LLVM basic block builder.
 *
 * This models llvm::IRBuilder.
 */
struct LLVMOpaqueBuilder;
alias LLVMBuilderRef = LLVMOpaqueBuilder*;

/**
 * Represents an LLVM debug info builder.
 *
 * This models llvm::DIBuilder.
 */
struct LLVMOpaqueDIBuilder;
alias LLVMDIBuilderRef = LLVMOpaqueDIBuilder*;

/**
 * Interface used to provide a module to JIT or interpreter.
 * This is now just a synonym for llvm::Module, but we have to keep using the
 * different type to keep binary compatibility.
 */
struct LLVMOpaqueModuleProvider;
alias LLVMModuleProviderRef = LLVMOpaqueModuleProvider*;

/** @see llvm::PassManagerBase */
struct LLVMOpaquePassManager;
alias LLVMPassManagerRef = LLVMOpaquePassManager*;

/** @see llvm::PassRegistry */
struct LLVMOpaquePassRegistry;
alias LLVMPassRegistryRef = LLVMOpaquePassRegistry*;

/**
 * Used to get the users and usees of a Value.
 *
 * @see llvm::Use */
struct LLVMOpaqueUse;
alias LLVMUseRef = LLVMOpaqueUse*;

/**
 * Used to represent an attributes.
 *
 * @see llvm::Attribute
 */
struct LLVMOpaqueAttributeRef;
alias LLVMAttributeRef = LLVMOpaqueAttributeRef*;

/**
 * @see llvm::DiagnosticInfo
 */
struct LLVMOpaqueDiagnosticInfo;
alias LLVMDiagnosticInfoRef = LLVMOpaqueDiagnosticInfo*;

/**
 * @see llvm::Comdat
 */
struct LLVMComdat;
alias LLVMComdatRef = LLVMComdat*;

/**
 * @see llvm::Module::ModuleFlagEntry
 */
struct LLVMOpaqueModuleFlagEntry;
alias LLVMModuleFlagEntry = LLVMOpaqueModuleFlagEntry;

/**
 * @see llvm::JITEventListener
 */
struct LLVMOpaqueJITEventListener;
alias LLVMJITEventListenerRef = LLVMOpaqueJITEventListener*;

/**
 * @see llvm::object::Binary
 */
struct LLVMOpaqueBinary;
alias LLVMBinaryRef = LLVMOpaqueBinary*;

/**
 * @}
 */

