module connection_wrapper;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import connection_lib;
public import wasm_export;
public import native_interface;
public import connection_native_api;

/* Note:
 *
 * This file is the consumer of connection lib which is implemented by different
 * platforms
 */

uint wasm_open_connection(wasm_exec_env_t exec_env, char* name, char* args_buf, uint len) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    attr_container_t* args = void;

    args = cast(attr_container_t*)args_buf;

    if (connection_impl._open != null)
        return connection_impl._open(module_inst, name, args);

    return -1;
}

void wasm_close_connection(wasm_exec_env_t exec_env, uint handle) {
    if (connection_impl._close != null)
        connection_impl._close(handle);
}

int wasm_send_on_connection(wasm_exec_env_t exec_env, uint handle, char* data, uint len) {
    if (connection_impl._send != null)
        return connection_impl._send(handle, data, len);

    return -1;
}

bool wasm_config_connection(wasm_exec_env_t exec_env, uint handle, char* cfg_buf, uint len) {
    attr_container_t* cfg = void;

    cfg = cast(attr_container_t*)cfg_buf;

    if (connection_impl._config != null)
        return connection_impl._config(handle, cfg);

    return false;
}
