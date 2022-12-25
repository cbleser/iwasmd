module sensor_mgr_ref;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_platform;
public import runtime_sensor;
public import bi-inc.attr_container;
public import module_wasm_app;
public import wasm_export;

/*
 *
 *   One reference implementation for sensor manager
 *
 *
 */
private korp_cond cond;
private korp_mutex mutex;
private bool sensor_check_thread_run = true;

void app_mgr_sensor_event_callback(module_data* m_data, bh_message_t msg) {
    uint[3] argv = void;
    wasm_function_inst_t func_onSensorEvent = void;

    bh_assert(SENSOR_EVENT_WASM == bh_message_type(msg));
    wasm_data* wasm_app_data = cast(wasm_data*)m_data.internal_data;
    wasm_module_inst_t inst = wasm_app_data.wasm_module_inst;

    sensor_event_data_t* payload = cast(sensor_event_data_t*)bh_message_payload(msg);
    if (payload == null)
        return;

    func_onSensorEvent =
        wasm_runtime_lookup_function(inst, "_on_sensor_event", "(i32i32i32)");
    if (!func_onSensorEvent)
        func_onSensorEvent = wasm_runtime_lookup_function(
            inst, "on_sensor_event", "(i32i32i32)");
    if (!func_onSensorEvent) {
        printf("Cannot find function on_sensor_event\n");
    }
    else {
        int sensor_data_offset = void;
        uint sensor_data_len = void;

        if (payload.data_fmt == FMT_ATTR_CONTAINER) {
            sensor_data_len =
                attr_container_get_serialize_length(payload.data);
        }
        else {
            printf("Unsupported sensor data format: %d\n", payload.data_fmt);
            return;
        }

        sensor_data_offset =
            wasm_runtime_module_dup_data(inst, payload.data, sensor_data_len);
        if (sensor_data_offset == 0) {
            const(char)* exception = wasm_runtime_get_exception(inst);
            if (exception) {
                printf("Got exception running wasm code: %s\n", exception);
                wasm_runtime_clear_exception(inst);
            }
            return;
        }

        argv[0] = payload.sensor_id;
        argv[1] = cast(uint)sensor_data_offset;
        argv[2] = sensor_data_len;

        if (!wasm_runtime_call_wasm(wasm_app_data.exec_env, func_onSensorEvent,
                                    3, argv.ptr)) {
            const(char)* exception = wasm_runtime_get_exception(inst);
            bh_assert(exception);
            printf(":Got exception running wasm code: %s\n", exception);
            wasm_runtime_clear_exception(inst);
            wasm_runtime_module_free(inst, sensor_data_offset);
            return;
        }

        wasm_runtime_module_free(inst, sensor_data_offset);
    }
}

private void thread_sensor_check(void* arg) {
    while (sensor_check_thread_run) {
        uint ms_to_expiry = check_sensor_timers();
        if (ms_to_expiry == UINT32_MAX)
            ms_to_expiry = 5000;
        os_mutex_lock(&mutex);
        os_cond_reltimedwait(&cond, &mutex, ms_to_expiry * 1000);
        os_mutex_unlock(&mutex);
    }
}

private void cb_wakeup_thread() {
    os_cond_signal(&cond);
}

void set_sensor_reshceduler(void function() callback);

bool init_sensor_framework() {
    /* init the mutext and conditions */
    if (os_cond_init(&cond) != 0) {
        return false;
    }

    if (os_mutex_init(&mutex) != 0) {
        os_cond_destroy(&cond);
        return false;
    }

    set_sensor_reshceduler(&cb_wakeup_thread);

    wasm_register_msg_callback(SENSOR_EVENT_WASM,
                               &app_mgr_sensor_event_callback);

    wasm_register_cleanup_callback(sensor_cleanup_callback);

    return true;
}

void start_sensor_framework() {
    korp_tid tid = void;

    os_thread_create(&tid, cast(void*)thread_sensor_check, null,
                     BH_APPLET_PRESERVED_STACK_SIZE);
}

void exit_sensor_framework() {
    sensor_check_thread_run = false;
    reschedule_sensor_read();

    // todo: wait the sensor thread termination
}
