module timer_wasm_app;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import bh_platform;

version (none) {
extern "C" {
//! #endif

/* board producer define user_timer */
struct user_timer;;
alias user_timer_t = user_timer*;

/**
 * @typedef on_user_timer_update_f
 *
 * @brief Define the signature of callback function for API api_timer_create().
 *
 * @param timer the timer
 *
 * @see api_timer_create
 */
alias on_user_timer_update_f = void function(user_timer_t timer);

/*
 *****************
 * Timer APIs
 *****************
 */

/**
 * @brief Create timer.
 *
 * @param interval timer interval
 * @param is_period whether the timer is periodic
 * @param auto_start whether start the timer immediately after created
 * @param on_timer_update callback function called when timer expired
 *
 * @return the timer created if success, NULL otherwise
 */
user_timer_t api_timer_create(int interval, bool is_period, bool auto_start, on_user_timer_update_f on_timer_update);

/**
 * @brief Cancel timer.
 *
 * @param timer the timer to cancel
 */
void api_timer_cancel(user_timer_t timer);

/**
 * @brief Restart timer.
 *
 * @param timer the timer to cancel
 * @param interval the timer interval
 */
void api_timer_restart(user_timer_t timer, int interval);

version (none) {}
}
}


