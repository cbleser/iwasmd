module request_response;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import app_manager_export;
public import coap_ext;
public import wasm_export;
public import bh_assert;

extern void module_request_handler(request_t* request, void* user_data);

bool wasm_response_send(wasm_exec_env_t exec_env, char* buffer, int size) {
    if (buffer != null) {
        response_t[1] response = void;

        if (null == unpack_response(buffer, size, response.ptr))
            return false;

        am_send_response(response.ptr);

        return true;
    }

    return false;
}

void wasm_register_resource(wasm_exec_env_t exec_env, char* url) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (url != null) {
        uint mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
        bh_assert(mod_id != ID_NONE);
        am_register_resource(url, &module_request_handler, mod_id);
    }
}

void wasm_post_request(wasm_exec_env_t exec_env, char* buffer, int size) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (buffer != null) {
        request_t[1] req = void;

        if (!unpack_request(buffer, size, req.ptr))
            return;

        // TODO: add permission check, ensure app can't do harm

        // set sender to help dispatch the response to the sender ap
        uint mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
        bh_assert(mod_id != ID_NONE);
        req.sender = mod_id;

        if (req.action == COAP_EVENT) {
            am_publish_event(req.ptr);
            return;
        }

        am_dispatch_request(req.ptr);
    }
}

void wasm_sub_event(wasm_exec_env_t exec_env, char* url) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (url != null) {
        uint mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);

        bh_assert(mod_id != ID_NONE);
        am_register_event(url, mod_id);
    }
}
