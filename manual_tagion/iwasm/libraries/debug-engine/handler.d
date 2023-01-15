module handler;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import bh_platform;
public import handler;
public import debug_engine;
public import packets;
public import utils;
public import wasm_runtime;

/*
 * Note: A moderate MAX_PACKET_SIZE is ok because
 * LLDB queries our buffer size (via qSupported PacketSize)
 * and limits packet sizes accordingly.
 */

version (DEBUG_MAX_PACKET_SIZE) {
enum MAX_PACKET_SIZE = DEBUG_MAX_PACKET_SIZE;
} else {
enum MAX_PACKET_SIZE = (4096);
}

/*
 * Note: It's assumed that MAX_PACKET_SIZE is reasonably large.
 * See GetWorkingDir, WasmCallStack, etc.
 */
static if (MAX_PACKET_SIZE < PATH_MAX || MAX_PACKET_SIZE < (2048 + 1)) {
static assert(0, MAX_PACKET_SIZE is too small);
}

private char* tmpbuf;
private korp_mutex tmpbuf_lock;

int wasm_debug_handler_init() {
    int ret = void;
    tmpbuf = wasm_runtime_malloc(MAX_PACKET_SIZE);
    if (tmpbuf == null) {
        LOG_ERROR("debug-engine: Packet buffer allocation failure");
        return BHT_ERROR;
    }
    ret = os_mutex_init(&tmpbuf_lock);
    if (ret != BHT_OK) {
        wasm_runtime_free(tmpbuf);
        tmpbuf = null;
    }
    return ret;
}

void wasm_debug_handler_deinit() {
    wasm_runtime_free(tmpbuf);
    tmpbuf = null;
    os_mutex_destroy(&tmpbuf_lock);
}

void handle_interrupt(WASMGDBServer* server) {
    wasm_debug_instance_interrupt_all_threads(server.thread.debug_instance);
}

void handle_general_set(WASMGDBServer* server, char* payload) {
    const(char)* name = void;
    char* args = void;

    args = strchr(payload, ':');
    if (args)
        *args++ = '\0';

    name = payload;
    LOG_VERBOSE("%s:%s\n", __FUNCTION__, payload);

    if (!strcmp(name, "StartNoAckMode")) {
        server.noack = true;
        write_packet(server, "OK");
    }
    if (!strcmp(name, "ThreadSuffixSupported")) {
        write_packet(server, "");
    }
    if (!strcmp(name, "ListThreadsInStopReply")) {
        write_packet(server, "");
    }
    if (!strcmp(name, "EnableErrorStrings")) {
        write_packet(server, "OK");
    }
}

private void process_xfer(WASMGDBServer* server, const(char)* name, char* args) {
    const(char)* mode = args;

    args = strchr(args, ':');
    if (args)
        *args++ = '\0';

    if (!strcmp(name, "libraries") && !strcmp(mode, "read")) {
        // TODO: how to get current wasm file name?
        ulong addr = wasm_debug_instance_get_load_addr(
            cast(WASMDebugInstance*)server.thread.debug_instance);
        os_mutex_lock(&tmpbuf_lock);
static if (WASM_ENABLE_LIBC_WASI != 0) {
        char[128] objname = void;
        if (!wasm_debug_instance_get_current_object_name(
                cast(WASMDebugInstance*)server.thread.debug_instance, objname.ptr,
                128)) {
            objname[0] = 0; /* use an empty string */
        }
        snprintf(tmpbuf, MAX_PACKET_SIZE,
                 "l<library-list><library name=\"%s\"><section "
                 ~ "address=\"0x%" PRIx64 ~ "\"/></library></library-list>",
                 objname.ptr, addr);
} else {
        snprintf(tmpbuf, MAX_PACKET_SIZE,
                 "l<library-list><library name=\"%s\"><section "
                 ~ "address=\"0x%" PRIx64 ~ "\"/></library></library-list>",
                 "nobody.wasm", addr);
}
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
}

void process_wasm_local(WASMGDBServer* server, char* args) {
    int frame_index = void;
    int local_index = void;
    char[16] buf = void;
    int size = 16;
    bool ret = void;

    os_mutex_lock(&tmpbuf_lock);
    snprintf(tmpbuf, MAX_PACKET_SIZE, "E01");
    if (sscanf(args, "%" PRId32 ~ ";%" PRId32, &frame_index, &local_index) == 2) {
        ret = wasm_debug_instance_get_local(
            cast(WASMDebugInstance*)server.thread.debug_instance, frame_index,
            local_index, buf.ptr, &size);
        if (ret && size > 0) {
            mem2hex(buf.ptr, tmpbuf, size);
        }
    }
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void process_wasm_global(WASMGDBServer* server, char* args) {
    int frame_index = void;
    int global_index = void;
    char[16] buf = void;
    int size = 16;
    bool ret = void;

    os_mutex_lock(&tmpbuf_lock);
    snprintf(tmpbuf, MAX_PACKET_SIZE, "E01");
    if (sscanf(args, "%" PRId32 ~ ";%" PRId32, &frame_index, &global_index)
        == 2) {
        ret = wasm_debug_instance_get_global(
            cast(WASMDebugInstance*)server.thread.debug_instance, frame_index,
            global_index, buf.ptr, &size);
        if (ret && size > 0) {
            mem2hex(buf.ptr, tmpbuf, size);
        }
    }
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void handle_general_query(WASMGDBServer* server, char* payload) {
    const(char)* name = void;
    char* args = void;
    char[256] triple = void;

    args = strchr(payload, ':');
    if (args)
        *args++ = '\0';
    name = payload;
    LOG_VERBOSE("%s:%s\n", __FUNCTION__, payload);

    if (!strcmp(name, "C")) {
        ulong pid = void, tid = void;
        pid = wasm_debug_instance_get_pid(
            cast(WASMDebugInstance*)server.thread.debug_instance);
        tid = cast(ulong)cast(uintptr_t)wasm_debug_instance_get_tid(
            cast(WASMDebugInstance*)server.thread.debug_instance);

        os_mutex_lock(&tmpbuf_lock);
        snprintf(tmpbuf, MAX_PACKET_SIZE, "QCp%" PRIx64 ~ ".%" PRIx64 ~ "", pid,
                 tid);
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
    if (!strcmp(name, "Supported")) {
        os_mutex_lock(&tmpbuf_lock);
        snprintf(tmpbuf, MAX_PACKET_SIZE,
                 "qXfer:libraries:read+;PacketSize=%" PRIx32 ~ ";",
                 MAX_PACKET_SIZE);
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }

    if (!strcmp(name, "Xfer")) {
        name = args;

        if (!args) {
            LOG_ERROR("payload parse error during handle_general_query");
            return;
        }

        args = strchr(args, ':');

        if (args) {
            *args++ = '\0';
            process_xfer(server, name, args);
        }
    }

    if (!strcmp(name, "HostInfo")) {
        mem2hex("wasm32-wamr-wasi-wasm", triple.ptr,
                strlen("wasm32-wamr-wasi-wasm"));

        os_mutex_lock(&tmpbuf_lock);
        snprintf(tmpbuf, MAX_PACKET_SIZE,
                 "vendor:wamr;ostype:wasi;arch:wasm32;"
                 ~ "triple:%s;endian:little;ptrsize:4;",
                 triple.ptr);
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
    if (!strcmp(name, "ModuleInfo")) {
        write_packet(server, "");
    }
    if (!strcmp(name, "GetWorkingDir")) {
        os_mutex_lock(&tmpbuf_lock);
        if (getcwd(tmpbuf, PATH_MAX))
            write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
    if (!strcmp(name, "QueryGDBServer")) {
        write_packet(server, "");
    }
    if (!strcmp(name, "VAttachOrWaitSupported")) {
        write_packet(server, "");
    }
    if (!strcmp(name, "ProcessInfo")) {
        // Todo: process id parent-pid
        ulong pid = void;
        pid = wasm_debug_instance_get_pid(
            cast(WASMDebugInstance*)server.thread.debug_instance);
        mem2hex("wasm32-wamr-wasi-wasm", triple.ptr,
                strlen("wasm32-wamr-wasi-wasm"));

        os_mutex_lock(&tmpbuf_lock);
        snprintf(tmpbuf, MAX_PACKET_SIZE,
                 "pid:%" PRIx64 ~ ";parent-pid:%" PRIx64
                 ~ ";vendor:wamr;ostype:wasi;arch:wasm32;"
                 ~ "triple:%s;endian:little;ptrsize:4;",
                 pid, pid, triple.ptr);
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
    if (!strcmp(name, "RegisterInfo0")) {
        os_mutex_lock(&tmpbuf_lock);
        snprintf(
            tmpbuf, MAX_PACKET_SIZE,
            "name:pc;alt-name:pc;bitsize:64;offset:0;encoding:uint;format:hex;"
            ~ "set:General Purpose Registers;gcc:16;dwarf:16;generic:pc;");
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
    else if (!strncmp(name, "RegisterInfo", strlen("RegisterInfo"))) {
        write_packet(server, "E45");
    }
    if (!strcmp(name, "StructuredDataPlugins")) {
        write_packet(server, "");
    }

    if (args && (!strcmp(name, "MemoryRegionInfo"))) {
        ulong addr = strtoll(args, null, 16);
        WASMDebugMemoryInfo* mem_info = wasm_debug_instance_get_memregion(
            cast(WASMDebugInstance*)server.thread.debug_instance, addr);
        if (mem_info) {
            char[256] name_buf = void;
            mem2hex(mem_info.name, name_buf.ptr, strlen(mem_info.name));

            os_mutex_lock(&tmpbuf_lock);
            snprintf(tmpbuf, MAX_PACKET_SIZE,
                     "start:%" PRIx64 ~ ";size:%" PRIx64
                     ~ ";permissions:%s;name:%s;",
                     cast(ulong)mem_info.start, mem_info.size,
                     mem_info.permisson, name_buf.ptr);
            write_packet(server, tmpbuf);
            os_mutex_unlock(&tmpbuf_lock);

            wasm_debug_instance_destroy_memregion(
                cast(WASMDebugInstance*)server.thread.debug_instance, mem_info);
        }
    }

    if (!strcmp(name, "WasmData")) {
    }

    if (!strcmp(name, "WasmMem")) {
    }

    if (!strcmp(name, "Symbol")) {
        write_packet(server, "");
    }

    if (args && (!strcmp(name, "WasmCallStack"))) {
        ulong tid = strtoll(args, null, 16);
        ulong[1024 / uint64.sizeof] buf = void;
        uint count = wasm_debug_instance_get_call_stack_pcs(
            cast(WASMDebugInstance*)server.thread.debug_instance,
            cast(korp_tid)cast(uintptr_t)tid, buf.ptr, 1024 / uint64.sizeof);

        if (count > 0) {
            os_mutex_lock(&tmpbuf_lock);
            mem2hex(cast(char*)buf, tmpbuf, count * uint64.sizeof);
            write_packet(server, tmpbuf);
            os_mutex_unlock(&tmpbuf_lock);
        }
        else
            write_packet(server, "");
    }

    if (args && (!strcmp(name, "WasmLocal"))) {
        process_wasm_local(server, args);
    }

    if (args && (!strcmp(name, "WasmGlobal"))) {
        process_wasm_global(server, args);
    }

    if (!strcmp(name, "Offsets")) {
        write_packet(server, "");
    }

    if (!strncmp(name, "ThreadStopInfo", strlen("ThreadStopInfo"))) {
        int prefix_len = strlen("ThreadStopInfo");
        ulong tid_number = strtoll(name + prefix_len, null, 16);
        korp_tid tid = cast(korp_tid)cast(uintptr_t)tid_number;
        uint status = void;

        status = wasm_debug_instance_get_thread_status(
            server.thread.debug_instance, tid);

        send_thread_stop_status(server, status, tid);
    }

    if (!strcmp(name, "WatchpointSupportInfo")) {
        os_mutex_lock(&tmpbuf_lock);
        // Any uint32 is OK for the watchpoint support
        snprintf(tmpbuf, MAX_PACKET_SIZE, "num:32;");
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
    }
}

void send_thread_stop_status(WASMGDBServer* server, uint status, korp_tid tid) {
    int len = 0;
    ulong pc = void;
    korp_tid[20] tids = void;
    char[17] pc_string = void;
    uint tids_count = void, i = 0;
    uint gdb_status = status;
    WASMExecEnv* exec_env = void;
    const(char)* exception = void;

    if (status == 0) {
        os_mutex_lock(&tmpbuf_lock);
        snprintf(tmpbuf, MAX_PACKET_SIZE, "W%02x", status);
        write_packet(server, tmpbuf);
        os_mutex_unlock(&tmpbuf_lock);
        return;
    }
    tids_count = wasm_debug_instance_get_tids(
        cast(WASMDebugInstance*)server.thread.debug_instance, tids.ptr, 20);
    pc = wasm_debug_instance_get_pc(
        cast(WASMDebugInstance*)server.thread.debug_instance);

    if (status == WAMR_SIG_SINGSTEP) {
        gdb_status = WAMR_SIG_TRAP;
    }

    os_mutex_lock(&tmpbuf_lock);
    // TODO: how name a wasm thread?
    len += snprintf(tmpbuf, MAX_PACKET_SIZE, "T%02xthread:%" PRIx64 ~ ";name:%s;",
                    gdb_status, cast(ulong)cast(uintptr_t)tid, "nobody");
    if (tids_count > 0) {
        len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len, "threads:");
        while (i < tids_count) {
            if (i == tids_count - 1)
                len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len,
                                "%" PRIx64 ~ ";", cast(ulong)cast(uintptr_t)tids[i]);
            else
                len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len,
                                "%" PRIx64 ~ ",", cast(ulong)cast(uintptr_t)tids[i]);
            i++;
        }
    }
    mem2hex(cast(void*)&pc, pc_string.ptr, 8);
    pc_string[8 * 2] = '\0';

    exec_env = wasm_debug_instance_get_current_env(
        cast(WASMDebugInstance*)server.thread.debug_instance);
    bh_assert(exec_env);

    exception =
        wasm_runtime_get_exception(wasm_runtime_get_module_inst(exec_env));
    if (exception) {
        /* When exception occurs, use reason:exception so the description can be
         * correctly processed by LLDB */
        uint exception_len = strlen(exception);
        len +=
            snprintf(tmpbuf + len, MAX_PACKET_SIZE - len,
                     "thread-pcs:%" PRIx64 ~ ";00:%s;reason:%s;description:", pc,
                     pc_string.ptr, "exception");
        /* The description should be encoded as HEX */
        for (i = 0; i < exception_len; i++) {
            len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len, "%02x",
                            exception[i]);
        }
        len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len, ";");
    }
    else {
        if (status == WAMR_SIG_TRAP) {
            len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len,
                            "thread-pcs:%" PRIx64 ~ ";00:%s;reason:%s;", pc,
                            pc_string.ptr, "breakpoint");
        }
        else if (status == WAMR_SIG_SINGSTEP) {
            len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len,
                            "thread-pcs:%" PRIx64 ~ ";00:%s;reason:%s;", pc,
                            pc_string.ptr, "trace");
        }
        else if (status > 0) {
            len += snprintf(tmpbuf + len, MAX_PACKET_SIZE - len,
                            "thread-pcs:%" PRIx64 ~ ";00:%s;reason:%s;", pc,
                            pc_string.ptr, "signal");
        }
    }
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void handle_v_packet(WASMGDBServer* server, char* payload) {
    const(char)* name = void;
    char* args = void;

    args = strchr(payload, ';');
    if (args)
        *args++ = '\0';
    name = payload;
    LOG_VERBOSE("%s:%s\n", __FUNCTION__, payload);

    if (!strcmp("Cont?", name))
        write_packet(server, "vCont;c;C;s;S;");

    if (!strcmp("Cont", name)) {
        if (args) {
            if (args[0] == 's' || args[0] == 'c') {
                char* numstring = strchr(args, ':');
                if (numstring) {
                    ulong tid_number = void;
                    korp_tid tid = void;

                    *numstring++ = '\0';
                    tid_number = strtoll(numstring, null, 16);
                    tid = cast(korp_tid)cast(uintptr_t)tid_number;
                    wasm_debug_instance_set_cur_thread(
                        cast(WASMDebugInstance*)server.thread.debug_instance,
                        tid);

                    if (args[0] == 's') {
                        wasm_debug_instance_singlestep(
                            cast(WASMDebugInstance*)server.thread.debug_instance,
                            tid);
                    }
                    else {
                        wasm_debug_instance_continue(
                            cast(WASMDebugInstance*)
                                server.thread.debug_instance);
                    }
                }
            }
        }
    }
}

void handle_threadstop_request(WASMGDBServer* server, char* payload) {
    korp_tid tid = void;
    uint status = void;
    WASMDebugInstance* debug_inst = cast(WASMDebugInstance*)server.thread.debug_instance;
    bh_assert(debug_inst);

    /* According to
       https://sourceware.org/gdb/onlinedocs/gdb/Packets.html#Packets, the "?"
       package should be sent when connection is first established to query the
       reason the target halted */
    bh_assert(debug_inst.current_state == DBG_LAUNCHING);

    /* Waiting for the stop event */
    os_mutex_lock(&debug_inst.wait_lock);
    while (!debug_inst.stopped_thread) {
        os_cond_wait(&debug_inst.wait_cond, &debug_inst.wait_lock);
    }
    os_mutex_unlock(&debug_inst.wait_lock);

    tid = debug_inst.stopped_thread.handle;
    status = cast(uint)debug_inst.stopped_thread.current_status.signal_flag;

    wasm_debug_instance_set_cur_thread(debug_inst, tid);

    send_thread_stop_status(server, status, tid);

    debug_inst.current_state = APP_STOPPED;
    debug_inst.stopped_thread = null;
}

void handle_set_current_thread(WASMGDBServer* server, char* payload) {
    LOG_VERBOSE("%s:%s\n", __FUNCTION__, payload);
    if ('g' == *payload++) {
        ulong tid = strtoll(payload, null, 16);
        if (tid > 0)
            wasm_debug_instance_set_cur_thread(
                cast(WASMDebugInstance*)server.thread.debug_instance,
                cast(korp_tid)cast(uintptr_t)tid);
    }
    write_packet(server, "OK");
}

void handle_get_register(WASMGDBServer* server, char* payload) {
    ulong regdata = void;
    int i = strtol(payload, null, 16);

    if (i != 0) {
        write_packet(server, "E01");
        return;
    }
    regdata = wasm_debug_instance_get_pc(
        cast(WASMDebugInstance*)server.thread.debug_instance);

    os_mutex_lock(&tmpbuf_lock);
    mem2hex(cast(void*)&regdata, tmpbuf, 8);
    tmpbuf[8 * 2] = '\0';
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void handle_get_json_request(WASMGDBServer* server, char* payload) {
    char* args = void;

    args = strchr(payload, ':');
    if (args)
        *args++ = '\0';
    write_packet(server, "");
}

void handle_get_read_binary_memory(WASMGDBServer* server, char* payload) {
    write_packet(server, "");
}

void handle_get_read_memory(WASMGDBServer* server, char* payload) {
    ulong maddr = void, mlen = void;
    bool ret = void;

    os_mutex_lock(&tmpbuf_lock);
    snprintf(tmpbuf, MAX_PACKET_SIZE, "%s", "");
    if (sscanf(payload, "%" SCNx64 ~ ",%" SCNx64, &maddr, &mlen) == 2) {
        char* buff = void;

        if (mlen * 2 > MAX_PACKET_SIZE) {
            LOG_ERROR("Buffer overflow!");
            mlen = MAX_PACKET_SIZE / 2;
        }

        buff = wasm_runtime_malloc(mlen);
        if (buff) {
            ret = wasm_debug_instance_get_mem(
                cast(WASMDebugInstance*)server.thread.debug_instance, maddr,
                buff, &mlen);
            if (ret) {
                mem2hex(buff, tmpbuf, mlen);
            }
            wasm_runtime_free(buff);
        }
    }
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void handle_get_write_memory(WASMGDBServer* server, char* payload) {
    size_t hex_len = void;
    int offset = void, act_len = void;
    ulong maddr = void, mlen = void;
    char* buff = void;
    bool ret = void;

    os_mutex_lock(&tmpbuf_lock);
    snprintf(tmpbuf, MAX_PACKET_SIZE, "%s", "");
    if (sscanf(payload, "%" SCNx64 ~ ",%" SCNx64 ~ ":%n", &maddr, &mlen, &offset)
        == 2) {
        payload += offset;
        hex_len = strlen(payload);
        act_len = hex_len / 2 < mlen ? hex_len / 2 : mlen;

        buff = wasm_runtime_malloc(act_len);
        if (buff) {
            hex2mem(payload, buff, act_len);
            ret = wasm_debug_instance_set_mem(
                cast(WASMDebugInstance*)server.thread.debug_instance, maddr,
                buff, &mlen);
            if (ret) {
                snprintf(tmpbuf, MAX_PACKET_SIZE, "%s", "OK");
            }
            wasm_runtime_free(buff);
        }
    }
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void handle_breakpoint_software_add(WASMGDBServer* server, ulong addr, size_t length) {
    bool ret = wasm_debug_instance_add_breakpoint(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr, length);
    write_packet(server, ret ? "OK" : "EO1");
}

void handle_breakpoint_software_remove(WASMGDBServer* server, ulong addr, size_t length) {
    bool ret = wasm_debug_instance_remove_breakpoint(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr, length);
    write_packet(server, ret ? "OK" : "EO1");
}

void handle_watchpoint_write_add(WASMGDBServer* server, ulong addr, size_t length) {
    bool ret = wasm_debug_instance_watchpoint_write_add(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr, length);
    write_packet(server, ret ? "OK" : "EO1");
}

void handle_watchpoint_write_remove(WASMGDBServer* server, ulong addr, size_t length) {
    bool ret = wasm_debug_instance_watchpoint_write_remove(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr, length);
    write_packet(server, ret ? "OK" : "EO1");
}

void handle_watchpoint_read_add(WASMGDBServer* server, ulong addr, size_t length) {
    bool ret = wasm_debug_instance_watchpoint_read_add(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr, length);
    write_packet(server, ret ? "OK" : "EO1");
}

void handle_watchpoint_read_remove(WASMGDBServer* server, ulong addr, size_t length) {
    bool ret = wasm_debug_instance_watchpoint_read_remove(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr, length);
    write_packet(server, ret ? "OK" : "EO1");
}

void handle_add_break(WASMGDBServer* server, char* payload) {
    int arg_c = void;
    size_t type = void, length = void;
    ulong addr = void;

    if ((arg_c = sscanf(payload, "%zx,%" SCNx64 ~ ",%zx", &type, &addr, &length))
        != 3) {
        LOG_ERROR("Unsupported number of add break arguments %d", arg_c);
        write_packet(server, "");
        return;
    }

    switch (type) {
        case eBreakpointSoftware:
            handle_breakpoint_software_add(server, addr, length);
            break;
        case eWatchpointWrite:
            handle_watchpoint_write_add(server, addr, length);
            break;
        case eWatchpointRead:
            handle_watchpoint_read_add(server, addr, length);
            break;
        case eWatchpointReadWrite:
            handle_watchpoint_write_add(server, addr, length);
            handle_watchpoint_read_add(server, addr, length);
            break;
        default:
            LOG_ERROR("Unsupported breakpoint type %zu", type);
            write_packet(server, "");
            break;
    }
}

void handle_remove_break(WASMGDBServer* server, char* payload) {
    int arg_c = void;
    size_t type = void, length = void;
    ulong addr = void;

    if ((arg_c = sscanf(payload, "%zx,%" SCNx64 ~ ",%zx", &type, &addr, &length))
        != 3) {
        LOG_ERROR("Unsupported number of remove break arguments %d", arg_c);
        write_packet(server, "");
        return;
    }

    switch (type) {
        case eBreakpointSoftware:
            handle_breakpoint_software_remove(server, addr, length);
            break;
        case eWatchpointWrite:
            handle_watchpoint_write_remove(server, addr, length);
            break;
        case eWatchpointRead:
            handle_watchpoint_read_remove(server, addr, length);
            break;
        case eWatchpointReadWrite:
            handle_watchpoint_write_remove(server, addr, length);
            handle_watchpoint_read_remove(server, addr, length);
            break;
        default:
            LOG_ERROR("Unsupported breakpoint type %zu", type);
            write_packet(server, "");
            break;
    }
}

void handle_continue_request(WASMGDBServer* server, char* payload) {
    wasm_debug_instance_continue(
        cast(WASMDebugInstance*)server.thread.debug_instance);
}

void handle_kill_request(WASMGDBServer* server, char* payload) {
    wasm_debug_instance_kill(
        cast(WASMDebugInstance*)server.thread.debug_instance);
}

private void handle_malloc(WASMGDBServer* server, char* payload) {
    char* args = void;
    ulong addr = void, size = void;
    int map_prot = MMAP_PROT_NONE;

    args = strstr(payload, ",");
    if (args) {
        *args++ = '\0';
    }
    else {
        LOG_ERROR("Payload parse error during handle malloc");
        return;
    }

    os_mutex_lock(&tmpbuf_lock);
    snprintf(tmpbuf, MAX_PACKET_SIZE, "%s", "E03");

    size = strtoll(payload, null, 16);
    if (size > 0) {
        while (*args) {
            if (*args == 'r') {
                map_prot |= MMAP_PROT_READ;
            }
            if (*args == 'w') {
                map_prot |= MMAP_PROT_WRITE;
            }
            if (*args == 'x') {
                map_prot |= MMAP_PROT_EXEC;
            }
            args++;
        }
        addr = wasm_debug_instance_mmap(
            cast(WASMDebugInstance*)server.thread.debug_instance, size,
            map_prot);
        if (addr) {
            snprintf(tmpbuf, MAX_PACKET_SIZE, "%" PRIx64, addr);
        }
    }
    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

private void handle_free(WASMGDBServer* server, char* payload) {
    ulong addr = void;
    bool ret = void;

    os_mutex_lock(&tmpbuf_lock);
    snprintf(tmpbuf, MAX_PACKET_SIZE, "%s", "E03");
    addr = strtoll(payload, null, 16);

    ret = wasm_debug_instance_ummap(
        cast(WASMDebugInstance*)server.thread.debug_instance, addr);
    if (ret) {
        snprintf(tmpbuf, MAX_PACKET_SIZE, "%s", "OK");
    }

    write_packet(server, tmpbuf);
    os_mutex_unlock(&tmpbuf_lock);
}

void handle____request(WASMGDBServer* server, char* payload) {
    char* args = void;

    if (payload[0] == 'M') {
        args = payload + 1;
        handle_malloc(server, args);
    }
    if (payload[0] == 'm') {
        args = payload + 1;
        handle_free(server, args);
    }
}

void handle_detach_request(WASMGDBServer* server, char* payload) {
    if (payload != null) {
        write_packet(server, "OK");
    }
    wasm_debug_instance_detach(
        cast(WASMDebugInstance*)server.thread.debug_instance);
}
/*
 * Copyright (C) 2021 Ant Group.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import gdbserver;

int wasm_debug_handler_init();

void wasm_debug_handler_deinit();

void handle_interrupt(WASMGDBServer* server);

void handle_general_set(WASMGDBServer* server, char* payload);

void handle_general_query(WASMGDBServer* server, char* payload);

void handle_v_packet(WASMGDBServer* server, char* payload);

void handle_threadstop_request(WASMGDBServer* server, char* payload);

void handle_set_current_thread(WASMGDBServer* server, char* payload);

void handle_get_register(WASMGDBServer* server, char* payload);

void handle_get_json_request(WASMGDBServer* server, char* payload);

void handle_get_read_binary_memory(WASMGDBServer* server, char* payload);

void handle_get_read_memory(WASMGDBServer* server, char* payload);

void handle_get_write_memory(WASMGDBServer* server, char* payload);

void handle_add_break(WASMGDBServer* server, char* payload);

void handle_remove_break(WASMGDBServer* server, char* payload);

void handle_continue_request(WASMGDBServer* server, char* payload);

void handle_kill_request(WASMGDBServer* server, char* payload);

void handle____request(WASMGDBServer* server, char* payload);

void handle_detach_request(WASMGDBServer* server, char* payload);

void send_thread_stop_status(WASMGDBServer* server, uint status, korp_tid tid);

