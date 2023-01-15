module wasi_nn_common;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdint;

// The type of the elements in a tensor.
enum _Tensor_type { fp16 = 0, fp32, up8, ip32 }alias tensor_type = _Tensor_type;

// Describes the encoding of the graph. This allows the API to be implemented by
// various backends that encode (i.e., serialize) their graph IR with different
// formats.
enum _Graph_encoding { openvino = 0, onnx, tensorflow, pytorch }alias graph_encoding = _Graph_encoding;

// Define where the graph should be executed.
enum _Execution_target { cpu = 0, gpu, tpu }alias execution_target = _Execution_target;

// Error codes returned by functions in this API.
enum _Error {
    // No error occurred.
    success = 0,
    // Caller module passed an invalid argument.
    invalid_argument,
    // Invalid encoding.
    invalid_encoding,
    // Caller module is missing a memory export.
    missing_memory,
    // Device or resource busy.
    busy,
    // Runtime Error.
    runtime_error,
}alias error = _Error;

// An execution graph for performing inference (i.e., a model).
alias graph = uint;

// Bind a `graph` to the input and output tensors for an inference.
alias graph_execution_context = uint;


