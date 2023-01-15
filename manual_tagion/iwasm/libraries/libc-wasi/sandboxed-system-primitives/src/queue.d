module queue;
@nogc nothrow:
extern(C): __gshared:
// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

 
// LIST: Double-linked list.

enum string LIST_HEAD(string name, string type) = ` \
    struct name {             \
        struct type *l_first; \
    }`;

/* clang-format off */
enum string LIST_HEAD_INITIALIZER(string head) = ` \
    { NULL }`;
/* clang-format on */

enum string LIST_ENTRY(string type) = `      \
    struct {                  \
        struct type *l_next;  \
        struct type **l_prev; \
    }`;

enum string LIST_FOREACH(string var, string head, string field) = ` \
    for ((var) = (head)->l_first; (var) != NULL; (var) = (var)->field.l_next)`;

enum string LIST_INIT(string head) = `         \
    do {                        \
        (head)->l_first = NULL; \
    } while (0)`;

enum string LIST_INSERT_HEAD(string head, string element, string field) = `                        \
    do {                                                              \
        (element)->field.l_next = (head)->l_first;                    \
        if ((head)->l_first != NULL)                                  \
            (head)->l_first->field.l_prev = &(element)->field.l_next; \
        (head)->l_first = (element);                                  \
        (element)->field.l_prev = &(head)->l_first;                   \
    } while (0)`;

enum string LIST_REMOVE(string element, string field) = `                                          \
    do {                                                                     \
        if ((element)->field.l_next != NULL)                                 \
            (element)->field.l_next->field.l_prev = (element)->field.l_prev; \
        *(element)->field.l_prev = (element)->field.l_next;                  \
    } while (0)`;

// TAILQ: Double-linked list with tail pointer.

enum string TAILQ_HEAD(string name, string type) = ` \
    struct name {              \
        struct type *t_first;  \
        struct type **t_last;  \
    }`;

enum string TAILQ_ENTRY(string type) = `     \
    struct {                  \
        struct type *t_next;  \
        struct type **t_prev; \
    }`;

enum string TAILQ_EMPTY(string head) = ` ((head)->t_first == NULL)`;
enum string TAILQ_FIRST(string head) = ` ((head)->t_first)`;
enum string TAILQ_FOREACH(string var, string head, string field) = ` \
    for ((var) = (head)->t_first; (var) != NULL; (var) = (var)->field.t_next)`;
enum string TAILQ_INIT(string head) = `                   \
    do {                                   \
        (head)->t_first = NULL;            \
        (head)->t_last = &(head)->t_first; \
    } while (0)`;
enum string TAILQ_INSERT_TAIL(string head, string elm, string field) = `    \
    do {                                       \
        (elm)->field.t_next = NULL;            \
        (elm)->field.t_prev = (head)->t_last;  \
        *(head)->t_last = (elm);               \
        (head)->t_last = &(elm)->field.t_next; \
    } while (0)`;
enum string TAILQ_REMOVE(string head, string element, string field) = `                                   \
    do {                                                                     \
        if ((element)->field.t_next != NULL)                                 \
            (element)->field.t_next->field.t_prev = (element)->field.t_prev; \
        else                                                                 \
            (head)->t_last = (element)->field.t_prev;                        \
        *(element)->field.t_prev = (element)->field.t_next;                  \
    } while (0)`;


