module runtime_sensor;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;
public import bi-inc.attr_container;
public import wasm_export;
public import sensor_native_api;

struct _sys_sensor;
alias sensor_obj_t = _sys_sensor*;

struct _sensor_client {
    _sensor_client* next;
    uint client_id; // the app id
    uint interval;
    int bit_cfg;
    uint delay;
    void function(void* client, uint, attr_container_t*) client_callback;
}alias sensor_client_t = _sensor_client;

struct _sys_sensor {
    _sys_sensor* next;
    char* name;
    int sensor_instance;
    char* description;
    uint sensor_id;
    sensor_client_t* clients;
    /* app, sensor mgr and app mgr may access the clients at the same time,
       so need a lock to protect the clients */
    korp_mutex lock;
    uint last_read;
    uint read_interval;
    uint default_interval;

    /* TODO: may support other type return value, such as 'cbor' */
    attr_container_t* function(void*) read;
    bool function(void*, void*) config;

}alias sys_sensor_t = _sys_sensor;

sensor_obj_t add_sys_sensor(char* name, char* description, int instance, uint default_interval, void* read_func, void* config_func);
sensor_obj_t find_sys_sensor(const(char)* name, int instance);
sensor_obj_t find_sys_sensor_id(uint sensor_id);
void refresh_read_interval(sensor_obj_t sensor);
void sensor_cleanup_callback(uint module_id);
uint check_sensor_timers();
void reschedule_sensor_read();

bool init_sensor_framework();
void start_sensor_framework();
void exit_sensor_framework();

 /* LIB_EXTENSION_RUNTIME_SENSOR_H_ */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import runtime_sensor;
public import app_manager_export;
public import module_wasm_app;
public import bh_platform;

private sys_sensor_t* g_sys_sensors = null;
private uint g_sensor_id_max = 0;

private sensor_client_t* find_sensor_client(sys_sensor_t* sensor, uint client_id, bool remove_if_found);

void function() rechedule_sensor_callback = null;

/*
 *  API for the applications to call - don't call it from the runtime
 *
 */

private void sensor_event_cleaner(sensor_event_data_t* sensor_event) {
    if (sensor_event.data != null) {
        if (sensor_event.data_fmt == FMT_ATTR_CONTAINER)
            attr_container_destroy(sensor_event.data);
        else
            wasm_runtime_free(sensor_event.data);
    }

    wasm_runtime_free(sensor_event);
}

private void wasm_sensor_callback(void* client, uint sensor_id, void* user_data) {
    attr_container_t* sensor_data = cast(attr_container_t*)user_data;
    attr_container_t* sensor_data_clone = void;
    int sensor_data_len = void;
    sensor_event_data_t* sensor_event = void;
    bh_message_t msg = void;
    sensor_client_t* c = cast(sensor_client_t*)client;

    module_data* module_ = module_data_list_lookup_id(c.client_id);
    if (module_ == null)
        return;

    if (sensor_data == null)
        return;

    sensor_data_len = attr_container_get_serialize_length(sensor_data);
    sensor_data_clone =
        cast(attr_container_t*)wasm_runtime_malloc(sensor_data_len);
    if (sensor_data_clone == null)
        return;

    /* multiple sensor clients may use/free the sensor data, so make a copy */
    bh_memcpy_s(sensor_data_clone, sensor_data_len, sensor_data,
                sensor_data_len);

    sensor_event =
        cast(sensor_event_data_t*)wasm_runtime_malloc(typeof(*sensor_event).sizeof);
    if (sensor_event == null) {
        wasm_runtime_free(sensor_data_clone);
        return;
    }

    memset(sensor_event, 0, typeof(*sensor_event).sizeof);
    sensor_event.sensor_id = sensor_id;
    sensor_event.data = sensor_data_clone;
    sensor_event.data_fmt = FMT_ATTR_CONTAINER;

    msg = bh_new_msg(SENSOR_EVENT_WASM, sensor_event, typeof(*sensor_event).sizeof,
                     &sensor_event_cleaner);
    if (!msg) {
        sensor_event_cleaner(sensor_event);
        return;
    }

    bh_post_msg2(module_.queue, msg);
}

bool wasm_sensor_config(wasm_exec_env_t exec_env, uint sensor, uint interval, int bit_cfg, uint delay) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    attr_container_t* attr_cont = void;
    sensor_client_t* c = void;
    sensor_obj_t s = find_sys_sensor_id(sensor);
    if (s == null)
        return false;

    uint mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
    bh_assert(mod_id != ID_NONE);

    os_mutex_lock(&s.lock);

    c = find_sensor_client(s, mod_id, false);
    if (c == null) {
        os_mutex_unlock(&s.lock);
        return false;
    }

    c.interval = interval;
    c.bit_cfg = bit_cfg;
    c.delay = delay;

    os_mutex_unlock(&s.lock);

    if (s.config != null) {
        attr_cont = attr_container_create("config sensor");
        attr_container_set_int(&attr_cont, "interval", cast(int)interval);
        attr_container_set_int(&attr_cont, "bit_cfg", bit_cfg);
        attr_container_set_int(&attr_cont, "delay", cast(int)delay);
        s.config(s, attr_cont);
        attr_container_destroy(attr_cont);
    }

    refresh_read_interval(s);

    reschedule_sensor_read();

    return true;
}

uint wasm_sensor_open(wasm_exec_env_t exec_env, char* name, int instance) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);

    if (name != null) {
        sensor_client_t* c = void;
        sys_sensor_t* s = find_sys_sensor(name, instance);
        if (s == null)
            return (uint32)-1;

        uint mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
        bh_assert(mod_id != ID_NONE);

        os_mutex_lock(&s.lock);

        c = find_sensor_client(s, mod_id, false);
        if (c) {
            // the app already opened this sensor
            os_mutex_unlock(&s.lock);
            return (uint32)-1;
        }

        sensor_client_t* client = cast(sensor_client_t*)wasm_runtime_malloc(sensor_client_t.sizeof);
        if (client == null) {
            os_mutex_unlock(&s.lock);
            return (uint32)-1;
        }

        memset(client, 0, sensor_client_t.sizeof);
        client.client_id = mod_id;
        client.client_callback = cast(void*)wasm_sensor_callback;
        client.interval = s.default_interval;
        client.next = s.clients;
        s.clients = client;

        os_mutex_unlock(&s.lock);

        refresh_read_interval(s);

        reschedule_sensor_read();

        return s.sensor_id;
    }

    return (uint32)-1;
}

bool wasm_sensor_config_with_attr_container(wasm_exec_env_t exec_env, uint sensor, char* buffer, int len) {
    if (buffer != null) {
        attr_container_t* cfg = cast(attr_container_t*)buffer;
        sensor_obj_t s = find_sys_sensor_id(sensor);
        if (s == null)
            return false;

        if (s.config == null)
            return false;

        return s.config(s, cfg);
    }

    return false;
}

bool wasm_sensor_close(wasm_exec_env_t exec_env, uint sensor) {
    wasm_module_inst_t module_inst = get_module_inst(exec_env);
    uint mod_id = app_manager_get_module_id(Module_WASM_App, module_inst);
    uint client_id = mod_id;
    sensor_obj_t s = find_sys_sensor_id(sensor);
    sensor_client_t* c = void;

    bh_assert(mod_id != ID_NONE);

    if (s == null)
        return false;

    os_mutex_lock(&s.lock);
    if ((c = find_sensor_client(s, client_id, true)) != null)
        wasm_runtime_free(c);
    os_mutex_unlock(&s.lock);

    refresh_read_interval(s);

    reschedule_sensor_read();

    return true;
}

/*
 *
 * sensor framework API - don't expose to the applications
 *
 */
void set_sensor_reshceduler(void function() callback) {
    rechedule_sensor_callback = callback;
}

// used for other threads to wakeup the sensor read thread
void reschedule_sensor_read() {
    if (rechedule_sensor_callback)
        rechedule_sensor_callback();
}

void refresh_read_interval(sensor_obj_t sensor) {
    sensor_client_t* c = void;
    uint interval = sensor.default_interval;
    os_mutex_lock(&sensor.lock);

    c = sensor.clients;
    if (c)
        interval = c.interval;

    while (c) {
        if (c.interval < interval)
            interval = c.interval;
        c = c.next;
    }

    os_mutex_unlock(&sensor.lock);

    sensor.read_interval = interval;
}

sensor_obj_t add_sys_sensor(char* name, char* description, int instance, uint default_interval, void* read_func, void* config_func) {
    sys_sensor_t* s = cast(sys_sensor_t*)wasm_runtime_malloc(sys_sensor_t.sizeof);
    if (s == null)
        return null;

    memset(s, 0, typeof(*s).sizeof);
    s.name = bh_strdup(name);
    s.sensor_instance = instance;
    s.default_interval = default_interval;

    if (!s.name) {
        wasm_runtime_free(s);
        return null;
    }

    if (description) {
        s.description = bh_strdup(description);
        if (!s.description) {
            wasm_runtime_free(s.name);
            wasm_runtime_free(s);
            return null;
        }
    }

    g_sensor_id_max++;
    if (g_sensor_id_max == UINT32_MAX)
        g_sensor_id_max++;
    s.sensor_id = g_sensor_id_max;

    s.read = read_func;
    s.config = config_func;

    if (g_sys_sensors == null) {
        g_sys_sensors = s;
    }
    else {
        s.next = g_sys_sensors;
        g_sys_sensors = s;
    }

    if (os_mutex_init(&s.lock) != 0) {
        if (s.description) {
            wasm_runtime_free(s.description);
        }
        wasm_runtime_free(s.name);
        wasm_runtime_free(s);
    }

    return s;
}

sensor_obj_t find_sys_sensor(const(char)* name, int instance) {
    sys_sensor_t* s = g_sys_sensors;
    while (s) {
        if (strcmp(s.name, name) == 0 && s.sensor_instance == instance)
            return s;

        s = s.next;
    }
    return null;
}

sensor_obj_t find_sys_sensor_id(uint sensor_id) {
    sys_sensor_t* s = g_sys_sensors;
    while (s) {
        if (s.sensor_id == sensor_id)
            return s;

        s = s.next;
    }
    return null;
}

sensor_client_t* find_sensor_client(sys_sensor_t* sensor, uint client_id, bool remove_if_found) {
    sensor_client_t* prev = null, c = sensor.clients;

    while (c) {
        sensor_client_t* next = c.next;
        if (c.client_id == client_id) {
            if (remove_if_found) {
                if (prev)
                    prev.next = next;
                else
                    sensor.clients = next;
            }
            return c;
        }
        else {
            prev = c;
            c = c.next;
        }
    }

    return null;
}

// return the milliseconds to next check
uint check_sensor_timers() {
    uint ms_to_next_check = UINT32_MAX;
    uint now = cast(uint)bh_get_tick_ms();

    sys_sensor_t* s = g_sys_sensors;
    while (s) {
        uint last_read = s.last_read;
        uint elpased_ms = bh_get_elpased_ms(&last_read);

        if (s.read_interval <= 0 || s.clients == null) {
            s = s.next;
            continue;
        }

        if (elpased_ms >= s.read_interval) {
            attr_container_t* data = s.read(s);
            if (data) {
                sensor_client_t* client = s.clients;
                while (client) {
                    client.client_callback(client, s.sensor_id, data);
                    client = client.next;
                }
                attr_container_destroy(data);
            }

            s.last_read = now;

            if (s.read_interval < ms_to_next_check)
                ms_to_next_check = s.read_interval;
        }
        else {
            uint remaining = s.read_interval - elpased_ms;
            if (remaining < ms_to_next_check)
                ms_to_next_check = remaining;
        }

        s = s.next;
    }

    return ms_to_next_check;
}

void sensor_cleanup_callback(uint module_id) {
    sys_sensor_t* s = g_sys_sensors;

    while (s) {
        sensor_client_t* c = void;
        os_mutex_lock(&s.lock);
        if ((c = find_sensor_client(s, module_id, true)) != null) {
            wasm_runtime_free(c);
        }
        os_mutex_unlock(&s.lock);
        s = s.next;
    }
}
