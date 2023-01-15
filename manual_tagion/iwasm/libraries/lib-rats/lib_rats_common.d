module lib_rats_common;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2022 Intel Corporation
 * Copyright (c) 2020-2021 Alibaba Cloud
 *
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdint;
public import core.stdc.stddef;

version (none) {
extern "C" {
//! #endif

enum SGX_QUOTE_MAX_SIZE = 8192;
enum SGX_USER_DATA_SIZE = 64;
enum SGX_MEASUREMENT_SIZE = 32;

/* clang-format off */
struct rats_sgx_evidence {
    ubyte[SGX_QUOTE_MAX_SIZE] quote;          /* The quote of the Enclave */
    uint quote_size;                        /* The size of the quote */
    ubyte[SGX_USER_DATA_SIZE] user_data;      /* The custom data in the quote */
    uint product_id;                        /* Product ID of the Enclave */
    ubyte[SGX_MEASUREMENT_SIZE] mr_enclave;   /* The MRENCLAVE of the Enclave */
    uint security_version;                  /* Security Version of the Enclave */
    ubyte[SGX_MEASUREMENT_SIZE] mr_signer;    /* The MRSIGNER of the Enclave */
    ulong att_flags;                         /* Flags of the Enclave in attributes */
    ulong att_xfrm;                          /* XSAVE Feature Request Mask */
}alias rats_sgx_evidence_t = rats_sgx_evidence;
/* clang-format on */

version (none) {}
}
}


