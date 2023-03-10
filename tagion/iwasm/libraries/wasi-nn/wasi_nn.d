module wasi_nn;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import wasi_nn_common;

/**
 * Following definition from:
 * [Aug 10th, 2022]
 * https://github.com/WebAssembly/wasi-nn/blob/e5e1a6c31f424c7cd63026cd270e9746775675a0/wasi-nn.wit.md
 */

/* The graph initialization data. */

// This consists of an array of buffers because implementing backends may encode
// their graph IR in parts (e.g., OpenVINO stores its IR and weights
// separately).
struct _Graph_builder {
    ubyte* buf;
    uint size;
}alias graph_builder = _Graph_builder;

struct _Graph_builder_array {
    graph_builder* buf;
    uint size;
}alias graph_builder_array = _Graph_builder_array;

/* The dimensions of a tensor. */

// The array length matches the tensor rank and each element in the array
// describes the size of each dimension.
struct _Tensor_dimensions {
    uint* buf;
    uint size;
}alias tensor_dimensions = _Tensor_dimensions;

/* The tensor data. */

// Initially conceived as a sparse representation, each empty cell would be
// filled with zeros and the array length must match the product of all of the
// dimensions and the number of bytes in the type (e.g., a 2x2 tensor with
// 4-byte f32 elements would have a data array of length 16). Naturally, this
// representation requires some knowledge of how to lay out data in
// memory--e.g., using row-major ordering--and could perhaps be improved.
alias tensor_data = ubyte*;

/* A tensor. */

struct _Tensor {
    // Describe the size of the tensor (e.g., 2x2x2x2 -> [2, 2, 2, 2]). To
    // represent a tensor containing a single value, use `[1]` for the tensor
    // dimensions.
    tensor_dimensions* dimensions;
    // Describe the type of element in the tensor (e.g., f32).
    tensor_type type;
    // Contains the tensor data.
    tensor_data data;
}alias tensor = _Tensor;

/**
 * @brief Load an opaque sequence of bytes to use for inference.
 *
 * @param builder   Model builder.
 * @param encoding  Model encoding.
 * @param target    Execution target.
 * @param graph     Graph.
 * @return error    Execution status.
 */
error load(graph_builder_array* builder, graph_encoding encoding, execution_target target, graph* graph);

/**
 * @brief Create an execution instance of a loaded graph.
 *
 * @param graph     Graph.
 * @param ctx       Execution context.
 * @return error    Execution status.
 */
error init_execution_context(graph graph, graph_execution_context* ctx);

/**
 * @brief Define the inputs to use for inference.
 *
 * @param ctx       Execution context.
 * @param index     Input tensor index.
 * @param tensor    Input tensor.
 * @return error    Execution status.
 */
error set_input(graph_execution_context ctx, uint index, tensor* tensor);

/**
 * @brief Compute the inference on the given inputs.
 *
 * @param ctx       Execution context.
 * @return error    Execution status.
 */
error compute(graph_execution_context ctx);

/**
 * @brief Extract the outputs after inference.
 *
 * @param ctx                   Execution context.
 * @param index                 Output tensor index.
 * @param output_tensor         Buffer where output tensor with index `index` is
 * copied.
 * @param output_tensor_size    Pointer to `output_tensor` maximum size.
 *                              After the function call it is updated with the
 * copied number of bytes.
 * @return error                Execution status.
 */
error get_output(graph_execution_context ctx, uint index, tensor_data output_tensor, uint* output_tensor_size);


