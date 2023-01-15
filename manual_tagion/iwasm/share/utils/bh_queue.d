module bh_queue;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_QUEUE_H
version = _BH_QUEUE_H;

#ifdef __cplusplus
extern "C" {
//! #endif

public import bh_platform;

struct bh_queue_node;;
alias bh_message_t = bh_queue_node*;
struct bh_queue;;


alias bh_queue_handle_msg_callback = void function(void* message, void* arg);

enum bh_queue_malloc = BH_MALLOC;
enum bh_queue_free = BH_FREE;

enum bh_queue_mutex = korp_mutex;
enum bh_queue_cond = korp_cond;

enum bh_queue_mutex_init = os_mutex_init;
enum bh_queue_mutex_destroy = os_mutex_destroy;
enum bh_queue_mutex_lock = os_mutex_lock;
enum bh_queue_mutex_unlock = os_mutex_unlock;

enum bh_queue_cond_init = os_cond_init;
enum bh_queue_cond_destroy = os_cond_destroy;
enum bh_queue_cond_wait = os_cond_wait;
enum bh_queue_cond_timedwait = os_cond_reltimedwait;
enum bh_queue_cond_signal = os_cond_signal;
enum bh_queue_cond_broadcast = os_cond_broadcast;

alias bh_msg_cleaner = void function(void* msg);

bh_queue* bh_queue_create();

void bh_queue_destroy(bh_queue* queue);

char* bh_message_payload(bh_message_t message);
uint bh_message_payload_len(bh_message_t message);
int bh_message_type(bh_message_t message);

bh_message_t bh_new_msg(ushort tag, void* body, uint len, void* handler);
void bh_free_msg(bh_message_t msg);
bool bh_post_msg(bh_queue* queue, ushort tag, void* body, uint len);
bool bh_post_msg2(bh_queue* queue, bh_message_t msg);

bh_message_t bh_get_msg(bh_queue* queue, ulong timeout_us);

uint bh_queue_get_message_count(bh_queue* queue);

void bh_queue_enter_loop_run(bh_queue* queue, bh_queue_handle_msg_callback handle_cb, void* arg);
void bh_queue_exit_loop_run(bh_queue* queue);

version (none) {
}
}

//! #endif /* #ifndef _BH_QUEUE_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_queue;

struct bh_queue_node {
    bh_queue_node* next;
    bh_queue_node* prev;
    ushort tag;
    uint len;
    void* body;
    bh_msg_cleaner msg_cleaner;
}

struct bh_queue {
    bh_queue_mutex queue_lock;
    bh_queue_cond queue_wait_cond;
    uint cnt;
    uint max;
    uint drops;
    bh_queue_node* head;
    bh_queue_node* tail;

    bool exit_loop_run;
};

char* bh_message_payload(bh_message_t message) {
    return message.body;
}

uint bh_message_payload_len(bh_message_t message) {
    return message.len;
}

int bh_message_type(bh_message_t message) {
    return message.tag;
}

bh_queue* bh_queue_create() {
    int ret = void;
    bh_queue* queue = bh_queue_malloc(bh_queue.sizeof);

    if (queue) {
        memset(queue, 0, bh_queue.sizeof);
        queue.max = DEFAULT_QUEUE_LENGTH;

        ret = bh_queue_mutex_init(&queue.queue_lock);
        if (ret != 0) {
            bh_queue_free(queue);
            return null;
        }

        ret = bh_queue_cond_init(&queue.queue_wait_cond);
        if (ret != 0) {
            bh_queue_mutex_destroy(&queue.queue_lock);
            bh_queue_free(queue);
            return null;
        }
    }

    return queue;
}

void bh_queue_destroy(bh_queue* queue) {
    bh_queue_node* node = void;

    if (!queue)
        return;

    bh_queue_mutex_lock(&queue.queue_lock);
    while (queue.head) {
        node = queue.head;
        queue.head = node.next;

        bh_free_msg(node);
    }
    bh_queue_mutex_unlock(&queue.queue_lock);

    bh_queue_cond_destroy(&queue.queue_wait_cond);
    bh_queue_mutex_destroy(&queue.queue_lock);
    bh_queue_free(queue);
}

bool bh_post_msg2(bh_queue* queue, bh_queue_node* msg) {
    if (queue.cnt >= queue.max) {
        queue.drops++;
        bh_free_msg(msg);
        return false;
    }

    bh_queue_mutex_lock(&queue.queue_lock);

    if (queue.cnt == 0) {
        bh_assert(queue.head == null);
        bh_assert(queue.tail == null);
        queue.head = queue.tail = msg;
        msg.next = msg.prev = null;
        queue.cnt = 1;

        bh_queue_cond_signal(&queue.queue_wait_cond);
    }
    else {
        msg.next = null;
        msg.prev = queue.tail;
        queue.tail.next = msg;
        queue.tail = msg;
        queue.cnt++;
    }

    bh_queue_mutex_unlock(&queue.queue_lock);

    return true;
}

bool bh_post_msg(bh_queue* queue, ushort tag, void* body, uint len) {
    bh_queue_node* msg = bh_new_msg(tag, body, len, null);
    if (msg == null) {
        queue.drops++;
        if (len != 0 && body)
            BH_FREE(body);
        return false;
    }

    if (!bh_post_msg2(queue, msg)) {
        // bh_post_msg2 already freed the msg for failure
        return false;
    }

    return true;
}

bh_queue_node* bh_new_msg(ushort tag, void* body, uint len, void* handler) {
    bh_queue_node* msg = cast(bh_queue_node*)bh_queue_malloc(bh_queue_node.sizeof);
    if (msg == null)
        return null;
    memset(msg, 0, bh_queue_node.sizeof);
    msg.len = len;
    msg.body = body;
    msg.tag = tag;
    msg.msg_cleaner = cast(bh_msg_cleaner)handler;

    return msg;
}

void bh_free_msg(bh_queue_node* msg) {
    if (msg.msg_cleaner) {
        msg.msg_cleaner(msg.body);
        bh_queue_free(msg);
        return;
    }

    // note: sometime we just use the payload pointer for a integer value
    //       len!=0 is the only indicator about the body is an allocated buffer.
    if (msg.body && msg.len)
        bh_queue_free(msg.body);

    bh_queue_free(msg);
}

bh_message_t bh_get_msg(bh_queue* queue, ulong timeout_us) {
    bh_queue_node* msg = null;
    bh_queue_mutex_lock(&queue.queue_lock);

    if (queue.cnt == 0) {
        bh_assert(queue.head == null);
        bh_assert(queue.tail == null);

        if (timeout_us == 0) {
            bh_queue_mutex_unlock(&queue.queue_lock);
            return null;
        }

        bh_queue_cond_timedwait(&queue.queue_wait_cond, &queue.queue_lock,
                                timeout_us);
    }

    if (queue.cnt == 0) {
        bh_assert(queue.head == null);
        bh_assert(queue.tail == null);
    }
    else if (queue.cnt == 1) {
        bh_assert(queue.head == queue.tail);

        msg = queue.head;
        queue.head = queue.tail = null;
        queue.cnt = 0;
    }
    else {
        msg = queue.head;
        queue.head = queue.head.next;
        queue.head.prev = null;
        queue.cnt--;
    }

    bh_queue_mutex_unlock(&queue.queue_lock);

    return msg;
}

uint bh_queue_get_message_count(bh_queue* queue) {
    if (!queue)
        return 0;

    return queue.cnt;
}

void bh_queue_enter_loop_run(bh_queue* queue, bh_queue_handle_msg_callback handle_cb, void* arg) {
    if (!queue)
        return;

    while (!queue.exit_loop_run) {
        bh_queue_node* message = bh_get_msg(queue, BHT_WAIT_FOREVER);

        if (message) {
            handle_cb(message, arg);
            bh_free_msg(message);
        }
    }
}

void bh_queue_exit_loop_run(bh_queue* queue) {
    if (queue) {
        queue.exit_loop_run = true;
        bh_queue_cond_signal(&queue.queue_wait_cond);
    }
}
