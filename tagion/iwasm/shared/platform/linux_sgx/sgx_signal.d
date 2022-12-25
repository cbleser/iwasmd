module sgx_signal;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
version (none) {
extern "C" {
//! #endif

/* Signals.  */
enum SIGHUP = 1       /* Hangup (POSIX).  */;
enum SIGINT = 2       /* Interrupt (ANSI).  */;
enum SIGQUIT = 3      /* Quit (POSIX).  */;
enum SIGILL = 4       /* Illegal instruction (ANSI).  */;
enum SIGTRAP = 5      /* Trace trap (POSIX).  */;
enum SIGABRT = 6      /* Abort (ANSI).  */;
enum SIGIOT = 6       /* IOT trap (4.2 BSD).  */;
enum SIGBUS = 7       /* BUS error (4.2 BSD).  */;
enum SIGFPE = 8       /* Floating-point exception (ANSI).  */;
enum SIGKILL = 9      /* Kill, unblockable (POSIX).  */;
enum SIGUSR1 = 10     /* User-defined signal 1 (POSIX).  */;
enum SIGSEGV = 11     /* Segmentation violation (ANSI).  */;
enum SIGUSR2 = 12     /* User-defined signal 2 (POSIX).  */;
enum SIGPIPE = 13     /* Broken pipe (POSIX).  */;
enum SIGALRM = 14     /* Alarm clock (POSIX).  */;
enum SIGTERM = 15     /* Termination (ANSI).  */;
enum SIGSTKFLT = 16   /* Stack fault.  */;
enum SIGCLD = SIGCHLD /* Same as SIGCHLD (System V).  */;
enum SIGCHLD = 17     /* Child status has changed (POSIX).  */;
enum SIGCONT = 18     /* Continue (POSIX).  */;
enum SIGSTOP = 19     /* Stop, unblockable (POSIX).  */;
enum SIGTSTP = 20     /* Keyboard stop (POSIX).  */;
enum SIGTTIN = 21     /* Background read from tty (POSIX).  */;
enum SIGTTOU = 22     /* Background write to tty (POSIX).  */;
enum SIGURG = 23      /* Urgent condition on socket (4.2 BSD).  */;
enum SIGXCPU = 24     /* CPU limit exceeded (4.2 BSD).  */;
enum SIGXFSZ = 25     /* File size limit exceeded (4.2 BSD).  */;
enum SIGVTALRM = 26   /* Virtual alarm clock (4.2 BSD).  */;
enum SIGPROF = 27     /* Profiling alarm clock (4.2 BSD).  */;
enum SIGWINCH = 28    /* Window size change (4.3 BSD, Sun).  */;
enum SIGPOLL = SIGIO  /* Pollable event occurred (System V).  */;
enum SIGIO = 29       /* I/O now possible (4.2 BSD).  */;
enum SIGPWR = 30      /* Power failure restart (System V).  */;
enum SIGSYS = 31      /* Bad system call.  */;
enum SIGUNUSED = 31;

int raise(int sig);

version (none) {}
}
}

 /* end of _SGX_SIGNAL_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import platform_api_vmcore;

version (SGX_DISABLE_WASI) {} else {

enum string TRACE_OCALL_FAIL() = ` os_printf("ocall %s failed!\n", __FUNCTION__)`;

int ocall_raise(int* p_ret, int sig);

int raise(int sig) {
    int ret = void;

    if (ocall_raise(&ret, sig) != SGX_SUCCESS) {
        TRACE_OCALL_FAIL();
        return -1;
    }

    if (ret == -1)
        errno = get_errno();

    return ret;
}

}
