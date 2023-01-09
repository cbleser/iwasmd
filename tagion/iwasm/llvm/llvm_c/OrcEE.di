/*===-- llvm-c/OrcEE.h - OrcV2 C bindings ExecutionEngine utils -*- C++ -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header declares the C interface to ExecutionEngine based utils, e.g.  *|
|* RTDyldObjectLinkingLayer (based on RuntimeDyld) in Orc.                    *|
|*                                                                            *|
|* Many exotic languages can interoperate with C code but have a harder time  *|
|* with C++ due to name mangling. So in addition to C, this interface enables *|
|* tools written in such languages.                                           *|
|*                                                                            *|
|* Note: This interface is experimental. It is *NOT* stable, and may be       *|
|*       changed without warning. Only C API usage documentation is           *|
|*       provided. See the C++ documentation for all higher level ORC API     *|
|*       details.                                                             *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

extern (C):

/**
 * Create a RTDyldObjectLinkingLayer instance using the standard
 * SectionMemoryManager for memory management.
 */
LLVMOrcObjectLayerRef LLVMOrcCreateRTDyldObjectLinkingLayerWithSectionMemoryManager (
    LLVMOrcExecutionSessionRef ES);

/**
 * Add the given listener to the given RTDyldObjectLinkingLayer.
 *
 * Note: Layer must be an RTDyldObjectLinkingLayer instance or
 * behavior is undefined.
 */
void LLVMOrcRTDyldObjectLinkingLayerRegisterJITEventListener (
    LLVMOrcObjectLayerRef RTDyldObjLinkingLayer,
    LLVMJITEventListenerRef Listener);

/* LLVM_C_ORCEE_H */
