module sensor;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import wa-inc.sensor;

public import sensor_api;

struct _sensor {
    _sensor* next;
    char* name;
    uint handle;
    void function(sensor_t, attr_container_t*, void*) sensor_callback;
    void* user_data;
}alias sensor = _sensor;

private sensor_t g_sensors = null;

sensor_t sensor_open(const(char)* name, int index, sensor_event_handler_f sensor_event_handler, void* user_data) {
    uint id = wasm_sensor_open(name, index);
    if (id == -1)
        return null;

    // create local node for holding the user callback
    sensor_t sensor = cast(sensor_t)malloc(_sensor.sizeof);
    if (sensor == null)
        return null;

    memset(sensor, 0, _sensor.sizeof);
    sensor.handle = id;
    sensor.name = strdup(name);
    sensor.user_data = user_data;
    sensor.sensor_callback = sensor_event_handler;

    if (!sensor.name) {
        free(sensor);
        return null;
    }

    if (g_sensors == null) {
        g_sensors = sensor;
    }
    else {
        sensor.next = g_sensors;
        g_sensors = sensor;
    }

    return sensor;
}

bool sensor_config_with_attr_container(sensor_t sensor, attr_container_t* cfg) {
    char* buffer = cast(char*)cfg;
    int len = attr_container_get_serialize_length(cfg);

    return wasm_sensor_config_with_attr_container(sensor.handle, buffer, len);
}

bool sensor_config(sensor_t sensor, int interval, int bit_cfg, int delay) {
    bool ret = wasm_sensor_config(sensor.handle, interval, bit_cfg, delay);
    return ret;
}

bool sensor_close(sensor_t sensor) {
    wasm_sensor_close(sensor.handle);

    // remove local node
    sensor_t s = g_sensors;
    sensor_t prev = null;
    while (s) {
        if (s == sensor) {
            if (prev == null) {
                g_sensors = s.next;
            }
            else {
                prev.next = s.next;
            }
            free(s.name);
            free(s);
            return true;
        }
        else {
            prev = s;
            s = s.next;
        }
    }

    return false;
}

/*
 *
 *  API for native layer to callback for sensor events
 *
 */

void on_sensor_event(uint sensor_id, char* buffer, int len) {
    attr_container_t* sensor_data = cast(attr_container_t*)buffer;

    // lookup the sensor and call the handlers
    sensor_t s = g_sensors;
    sensor_t prev = null;
    while (s) {
        if (s.handle == sensor_id) {
            s.sensor_callback(s, sensor_data, s.user_data);
            break;
        }

        s = s.next;
    }
}
