module app_ext_lib_export;
@nogc nothrow:
extern(C): __gshared:
public import lib_export;

version (APP_FRAMEWORK_SENSOR) {
public import sensor_native_api;
}

version (APP_FRAMEWORK_CONNECTION) {
public import connection_native_api;
}

version (APP_FRAMEWORK_WGL) {
public import gui_native_api;
}

/* More header file here */

private NativeSymbol[1] extended_native_symbol_defs = [
#ifdef APP_FRAMEWORK_SENSOR
#include "runtime_sensor.inl"
}

#ifdef APP_FRAMEWORK_CONNECTION
#include "connection.inl"
}

#ifdef APP_FRAMEWORK_WGL
#include "wamr_gui.inl"
}

    /* More inl file here */
];

int get_ext_lib_export_apis(NativeSymbol** p_ext_lib_apis) {
    *p_ext_lib_apis = extended_native_symbol_defs;
    return extended_native_symbol_defs.sizeof / NativeSymbol.sizeof;
}
