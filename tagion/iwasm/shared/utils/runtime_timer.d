module runtime_timer;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef LIB_BASE_RUNTIME_TIMER_H_
version = LIB_BASE_RUNTIME_TIMER_H_;

public import bh_platform;

#ifdef __cplusplus
extern "C" {
//! #endif

ulong bh_get_tick_ms();
uint bh_get_elpased_ms(uint* last_system_clock);

struct _timer_ctx;;
alias timer_ctx_t = _timer_ctx*;
alias timer_callback_f = void function(uint id, uint owner);
alias check_timer_expiry_f = void function(timer_ctx_t ctx);

timer_ctx_t create_timer_ctx(timer_callback_f timer_handler, check_timer_expiry_f, int prealloc_num, uint owner);
void destroy_timer_ctx(timer_ctx_t);
uint timer_ctx_get_owner(timer_ctx_t ctx);

uint sys_create_timer(timer_ctx_t ctx, int interval, bool is_period, bool auto_start);
bool sys_timer_destroy(timer_ctx_t ctx, uint timer_id);
bool sys_timer_cancel(timer_ctx_t ctx, uint timer_id);
bool sys_timer_restart(timer_ctx_t ctx, uint timer_id, int interval);
void cleanup_app_timers(timer_ctx_t ctx);
uint check_app_timers(timer_ctx_t ctx);
uint get_expiry_ms(timer_ctx_t ctx);

version (none) {
}
}
//! #endif /* LIB_BASE_RUNTIME_TIMER_H_ */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import runtime_timer;

static if (1) {
enum string PRINT(...) = ` (void)0`;
} else {
enum PRINT = printf;
}

struct _app_timer {
    _app_timer* next;
    uint id;
    uint interval;
    ulong expiry;
    bool is_periodic;
}alias app_timer_t = _app_timer;

struct _timer_ctx {
    app_timer_t* app_timers;
    app_timer_t* idle_timers;
    app_timer_t* free_timers;
    uint max_timer_id;
    int pre_allocated;
    uint owner;

    /* mutex and condition */
    korp_cond cond;
    korp_mutex mutex;

    timer_callback_f timer_callback;
    check_timer_expiry_f refresh_checker;
};

ulong bh_get_tick_ms() {
    return os_time_get_boot_microsecond() / 1000;
}

uint bh_get_elpased_ms(uint* last_system_clock) {
    uint elpased_ms = void;
    /* attention: the bh_get_tick_ms() return 64 bits integer, but
       the bh_get_elpased_ms() is designed to use 32 bits clock count */
    uint now = cast(uint)bh_get_tick_ms();

    /* system clock overrun */
    if (now < *last_system_clock) {
        PRINT("system clock overrun!\n");
        elpased_ms = now + (UINT32_MAX - *last_system_clock) + 1;
    }
    else {
        elpased_ms = now - *last_system_clock;
    }

    *last_system_clock = now;
    return elpased_ms;
}

private app_timer_t* remove_timer_from(timer_ctx_t ctx, uint timer_id, bool active_list) {
    app_timer_t** head = void; app_timer_t* prev = void, t = void;

    os_mutex_lock(&ctx.mutex);

    if (active_list)
        head = &ctx.app_timers;
    else
        head = &ctx.idle_timers;

    t = *head;
    prev = null;

    while (t) {
        if (t.id == timer_id) {
            if (prev == null) {
                *head = t.next;
                PRINT("removed timer [%d] at head from list %d\n", t.id,
                      active_list);
            }
            else {
                prev.next = t.next;
                PRINT("removed timer [%d] after [%d] from list %d\n", t.id,
                      prev.id, active_list);
            }
            os_mutex_unlock(&ctx.mutex);

            if (active_list && prev == null && ctx.refresh_checker)
                ctx.refresh_checker(ctx);
            return t;
        }
        else {
            prev = t;
            t = t.next;
        }
    }

    os_mutex_unlock(&ctx.mutex);
    return null;
}

private app_timer_t* remove_timer(timer_ctx_t ctx, uint timer_id, bool* active) {
    app_timer_t* t = remove_timer_from(ctx, timer_id, true);

    if (t) {
        if (active)
            *active = true;
        return t;
    }

    if (active)
        *active = false;
    return remove_timer_from(ctx, timer_id, false);
}

private void reschedule_timer(timer_ctx_t ctx, app_timer_t* timer) {
    app_timer_t* t = void;
    app_timer_t* prev = null;

    os_mutex_lock(&ctx.mutex);

    t = ctx.app_timers;
    timer.next = null;
    timer.expiry = bh_get_tick_ms() + timer.interval;

    while (t) {
        if (timer.expiry < t.expiry) {
            if (prev == null) {
                timer.next = ctx.app_timers;
                ctx.app_timers = timer;
                PRINT("rescheduled timer [%d] at head\n", timer.id);
            }
            else {
                timer.next = t;
                prev.next = timer;
                PRINT("rescheduled timer [%d] after [%d]\n", timer.id,
                      prev.id);
            }

            goto out;
        }
        else {
            prev = t;
            t = t.next;
        }
    }

    if (prev) {
        /* insert to the list end */
        prev.next = timer;
        PRINT("rescheduled timer [%d] at end, after [%d]\n", timer.id,
              prev.id);
    }
    else {
        /* insert at the begin */
        bh_assert(ctx.app_timers == null);
        ctx.app_timers = timer;
        PRINT("rescheduled timer [%d] as first\n", timer.id);
    }

out:
    os_mutex_unlock(&ctx.mutex);

    /* ensure the refresh_checker() is called out of the lock */
    if (prev == null && ctx.refresh_checker)
        ctx.refresh_checker(ctx);
}

private void release_timer(timer_ctx_t ctx, app_timer_t* t) {
    if (ctx.pre_allocated) {
        os_mutex_lock(&ctx.mutex);
        t.next = ctx.free_timers;
        ctx.free_timers = t;
        PRINT("recycle timer :%d\n", t.id);
        os_mutex_unlock(&ctx.mutex);
    }
    else {
        PRINT("destroy timer :%d\n", t.id);
        BH_FREE(t);
    }
}

void release_timer_list(app_timer_t** p_list) {
    app_timer_t* t = *p_list;

    while (t) {
        app_timer_t* next = t.next;
        PRINT("destroy timer list:%d\n", t.id);
        BH_FREE(t);
        t = next;
    }

    *p_list = null;
}

/*
 * API exposed
 */

timer_ctx_t create_timer_ctx(timer_callback_f timer_handler, check_timer_expiry_f expiery_checker, int prealloc_num, uint owner) {
    timer_ctx_t ctx = cast(timer_ctx_t)BH_MALLOC(_timer_ctx.sizeof);

    if (ctx == null)
        return null;

    memset(ctx, 0, _timer_ctx.sizeof);

    ctx.timer_callback = timer_handler;
    ctx.pre_allocated = prealloc_num;
    ctx.refresh_checker = expiery_checker;
    ctx.owner = owner;

    while (prealloc_num > 0) {
        app_timer_t* timer = cast(app_timer_t*)BH_MALLOC(app_timer_t.sizeof);

        if (timer == null)
            goto cleanup;

        memset(timer, 0, typeof(*timer).sizeof);
        timer.next = ctx.free_timers;
        ctx.free_timers = timer;
        prealloc_num--;
    }

    if (os_cond_init(&ctx.cond) != 0)
        goto cleanup;

    if (os_mutex_init(&ctx.mutex) != 0) {
        os_cond_destroy(&ctx.cond);
        goto cleanup;
    }

    PRINT("timer ctx created. pre-alloc: %d\n", ctx.pre_allocated);
    return ctx;

cleanup:
    if (ctx) {
        release_timer_list(&ctx.free_timers);
        BH_FREE(ctx);
    }
    PRINT("timer ctx create failed\n");
    return null;
}

void destroy_timer_ctx(timer_ctx_t ctx) {
    while (ctx.free_timers) {
        void* tmp = ctx.free_timers;
        ctx.free_timers = ctx.free_timers.next;
        BH_FREE(tmp);
    }

    cleanup_app_timers(ctx);

    os_cond_destroy(&ctx.cond);
    os_mutex_destroy(&ctx.mutex);
    BH_FREE(ctx);
}

uint timer_ctx_get_owner(timer_ctx_t ctx) {
    return ctx.owner;
}

void add_idle_timer(timer_ctx_t ctx, app_timer_t* timer) {
    os_mutex_lock(&ctx.mutex);
    timer.next = ctx.idle_timers;
    ctx.idle_timers = timer;
    os_mutex_unlock(&ctx.mutex);
}

uint sys_create_timer(timer_ctx_t ctx, int interval, bool is_period, bool auto_start) {
    app_timer_t* timer = void;

    if (ctx.pre_allocated) {
        if (ctx.free_timers == null) {
            return (uint32)-1;
        }
        else {
            timer = ctx.free_timers;
            ctx.free_timers = timer.next;
        }
    }
    else {
        timer = cast(app_timer_t*)BH_MALLOC(app_timer_t.sizeof);
        if (timer == null)
            return (uint32)-1;
    }

    memset(timer, 0, typeof(*timer).sizeof);

    ctx.max_timer_id++;
    if (ctx.max_timer_id == (uint32)-1)
        ctx.max_timer_id++;
    timer.id = ctx.max_timer_id;
    timer.interval = cast(uint)interval;
    timer.is_periodic = is_period;

    if (auto_start)
        reschedule_timer(ctx, timer);
    else
        add_idle_timer(ctx, timer);

    return timer.id;
}

bool sys_timer_cancel(timer_ctx_t ctx, uint timer_id) {
    bool from_active = void;
    app_timer_t* t = remove_timer(ctx, timer_id, &from_active);

    if (t == null)
        return false;

    add_idle_timer(ctx, t);

    PRINT("sys_timer_stop called\n");
    return from_active;
}

bool sys_timer_destroy(timer_ctx_t ctx, uint timer_id) {
    bool from_active = void;
    app_timer_t* t = remove_timer(ctx, timer_id, &from_active);

    if (t == null)
        return false;

    release_timer(ctx, t);

    PRINT("sys_timer_destroy called\n");
    return true;
}

bool sys_timer_restart(timer_ctx_t ctx, uint timer_id, int interval) {
    app_timer_t* t = remove_timer(ctx, timer_id, null);

    if (t == null)
        return false;

    t.interval = cast(uint)interval;

    reschedule_timer(ctx, t);

    PRINT("sys_timer_restart called\n");
    return true;
}

/*
 * API called by the timer manager from another thread or the kernel timer
 * handler
 */

/**
 * lookup the app queue by the module name
 * post a timeout message to the app queue
 */
private void handle_expired_timers(timer_ctx_t ctx, app_timer_t* expired) {
    while (expired) {
        app_timer_t* t = expired;
        ctx.timer_callback(t.id, ctx.owner);

        /* get next expired timer first, since the following
           operation may change expired->next */
        expired = expired.next;
        if (t.is_periodic) {
            /* if it is repeating, then reschedule it; */
            reschedule_timer(ctx, t);
        }
        else {
            /* else move it to idle list */
            add_idle_timer(ctx, t);
        }
    }
}

uint get_expiry_ms(timer_ctx_t ctx) {
    uint ms_to_next_expiry = void;
    ulong now = bh_get_tick_ms();

    os_mutex_lock(&ctx.mutex);
    if (ctx.app_timers == null)
        ms_to_next_expiry = (uint32)-1;
    else if (ctx.app_timers.expiry >= now)
        ms_to_next_expiry = (uint32)(ctx.app_timers.expiry - now);
    else
        ms_to_next_expiry = 0;
    os_mutex_unlock(&ctx.mutex);

    return ms_to_next_expiry;
}

uint check_app_timers(timer_ctx_t ctx) {
    app_timer_t* t = void, expired = null, expired_end = null;
    ulong now = bh_get_tick_ms();

    os_mutex_lock(&ctx.mutex);

    t = ctx.app_timers;
    while (t) {
        if (now >= t.expiry) {
            ctx.app_timers = t.next;

            /* append t to the end of expired list */
            t.next = null;
            if (!expired_end) {
                expired = expired_end = t;
            }
            else {
                expired_end.next = t;
                expired_end = t;
            }

            t = ctx.app_timers;
        }
        else {
            break;
        }
    }
    os_mutex_unlock(&ctx.mutex);

    handle_expired_timers(ctx, expired);
    return get_expiry_ms(ctx);
}

void cleanup_app_timers(timer_ctx_t ctx) {
    os_mutex_lock(&ctx.mutex);

    release_timer_list(&ctx.app_timers);
    release_timer_list(&ctx.idle_timers);

    os_mutex_unlock(&ctx.mutex);
}
