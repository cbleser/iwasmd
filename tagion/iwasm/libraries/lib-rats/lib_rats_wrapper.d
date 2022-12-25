module lib_rats_wrapper;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2022 Intel Corporation
 * Copyright (c) 2020-2021 Alibaba Cloud
 *
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.stdio;
public import core.stdc.stdlib;
public import librats/api;
public import core.stdc.string;
public import openssl/sha;

public import sgx_quote_3;
public import wasm_export;
public import bh_common;
public import lib_rats_common;

private int librats_collect_wrapper(wasm_exec_env_t exec_env, char** evidence_json, const(char)* buffer, uint buffer_size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    wasm_module_t module_ = wasm_runtime_get_module(module_inst);
    char* wasm_module_hash = wasm_runtime_get_module_hash(module_);

    char* json = void, str_ret = void;
    uint str_ret_offset = void;
    ubyte[SHA256_DIGEST_LENGTH] final_hash = void;

    SHA256_CTX sha256 = void;
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, wasm_module_hash, SHA256_DIGEST_LENGTH);
    if (buffer != null)
        SHA256_Update(&sha256, buffer, buffer_size);
    SHA256_Final(final_hash.ptr, &sha256);

    int ret_code = librats_collect_evidence_to_json(final_hash.ptr, &json);
    if (ret_code != 0) {
        return ret_code;
    }

    uint json_size = strlen(json) + 1;
    str_ret_offset = module_malloc(json_size, cast(void**)&str_ret);
    if (!str_ret_offset) {
        free(json);
        return cast(int)RATS_ATTESTER_ERR_NO_MEM;
    }
    bh_memcpy_s(str_ret, json_size, json, json_size);
    *(cast(int*)evidence_json) = str_ret_offset;
    free(json);

    return 0;
}

private int librats_verify_wrapper(wasm_exec_env_t exec_env, const(char)* evidence_json, uint evidence_size, const(ubyte)* hash, uint hash_size) {
    return librats_verify_evidence_from_json(evidence_json, hash);
}

private int librats_parse_evidence_wrapper(wasm_exec_env_t exec_env, const(char)* evidence_json, uint json_size, rats_sgx_evidence_t* evidence, uint evidence_size) {
    attestation_evidence_t att_ev = void;

    if (get_evidence_from_json(evidence_json, &att_ev) != 0) {
        return -1;
    }

    // Only supports parsing sgx evidence currently
    if (strcmp(att_ev.type, "sgx_ecdsa") != 0) {
        return -1;
    }

    sgx_quote3_t* quote_ptr = cast(sgx_quote3_t*)att_ev.ecdsa.quote;
    bh_memcpy_s(evidence.quote, att_ev.ecdsa.quote_len, att_ev.ecdsa.quote,
                att_ev.ecdsa.quote_len);
    evidence.quote_size = att_ev.ecdsa.quote_len;
    bh_memcpy_s(evidence.user_data, SGX_REPORT_DATA_SIZE,
                quote_ptr.report_body.report_data.d, SGX_REPORT_DATA_SIZE);
    bh_memcpy_s(evidence.mr_enclave, sgx_measurement_t.sizeof,
                quote_ptr.report_body.mr_enclave.m, sgx_measurement_t.sizeof);
    bh_memcpy_s(evidence.mr_signer, sgx_measurement_t.sizeof,
                quote_ptr.report_body.mr_signer.m, sgx_measurement_t.sizeof);
    evidence.product_id = quote_ptr.report_body.isv_prod_id;
    evidence.security_version = quote_ptr.report_body.isv_svn;
    evidence.att_flags = quote_ptr.report_body.attributes.flags;
    evidence.att_xfrm = quote_ptr.report_body.attributes.flags;

    return 0;
}

/* clang-format off */
enum string REG_NATIVE_FUNC(string func_name, string signature) = ` \
    { #func_name, func_name##_wrapper, signature, NULL }`;
/* clang-format on */

private NativeSymbol[3] native_symbols_lib_rats = [
    REG_NATIVE_FUNC(librats_collect, "(**~)i"),
    REG_NATIVE_FUNC(librats_verify, "(*~*~)i"),
    REG_NATIVE_FUNC(librats_parse_evidence, "(*~*~)i")
];

uint get_lib_rats_export_apis(NativeSymbol** p_lib_rats_apis) {
    *p_lib_rats_apis = native_symbols_lib_rats;
    return native_symbols_lib_rats.sizeof / NativeSymbol.sizeof;
}
/*
 * Copyright (c) 2022 Intel Corporation
 * Copyright (c) 2020-2021 Alibaba Cloud
 *
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import core.stdc.stdint;
public import core.stdc.string;

public import lib_rats_common;

version (none) {
extern "C" {
//! #endif

int librats_collect(char** evidence_json, const(char)* buffer, uint buffer_size);

int librats_verify(const(char)* evidence_json, uint evidence_size, const(ubyte)* hash, uint hash_size);

int librats_parse_evidence(const(char)* evidence_json, uint json_size, rats_sgx_evidence_t* evidence, uint evidence_size);

enum string librats_collect(string evidence_json, string buffer) = ` \
    librats_collect(evidence_json, buffer, buffer ? strlen(buffer) + 1 : 0)`;

enum string librats_verify(string evidence_json, string hash) = `                             \
    librats_verify(evidence_json,                                       \
                   evidence_json ? strlen(evidence_json) + 1 : 0, hash, \
                   hash ? strlen((const char *)hash) + 1 : 0)`;

enum string librats_parse_evidence(string evidence_json, string evidence) = `                   \
    librats_parse_evidence(evidence_json,                                 \
                           evidence_json ? strlen(evidence_json) + 1 : 0, \
                           evidence, sizeof(rats_sgx_evidence_t))`;

version (none) {}
}
}


