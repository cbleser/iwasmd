module timer;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import core.stdc.stdlib;
public import core.stdc.string;

public import wa-inc.timer_wasm_app;
public import timer_api;

static if (1) {
public import core.stdc.stdio;
} else {
enum printf = (...);
}

struct user_timer {
    user_timer* next;
    int timer_id;
    void function(user_timer_t) user_timer_callback;
}

user_timer* g_timers = null;

user_timer_t api_timer_create(int interval, bool is_period, bool auto_start, on_user_timer_update_f on_timer_update) {

    int timer_id = wasm_create_timer(interval, is_period, auto_start);

    // TODO
    user_timer* timer = cast(user_timer*)malloc(user_timer.sizeof);
    if (timer == null) {
        // TODO: remove the timer_id
        printf("### api_timer_create malloc faild!!! \n");
        return null;
    }

    memset(timer, 0, typeof(*timer).sizeof);
    timer.timer_id = timer_id;
    timer.user_timer_callback = on_timer_update;

    if (g_timers == null)
        g_timers = timer;
    else {
        timer.next = g_timers;
        g_timers = timer;
    }

    return timer;
}

void api_timer_cancel(user_timer_t timer) {
    user_timer_t t = g_timers, prev = null;

    wasm_timer_cancel(timer.timer_id);

    while (t) {
        if (t == timer) {
            if (prev == null) {
                g_timers = t.next;
                free(t);
            }
            else {
                prev.next = t.next;
                free(t);
            }
            return;
        }
        else {
            prev = t;
            t = t.next;
        }
    }
}

void api_timer_restart(user_timer_t timer, int interval) {
    wasm_timer_restart(timer.timer_id, interval);
}

void on_timer_callback(int timer_id) {
    user_timer* t = g_timers;

    while (t) {
        if (t.timer_id == timer_id) {
            t.user_timer_callback(t);
            break;
        }
        t = t.next;
    }
}
