/*
 * Copyright (C) 2013-2014 Red Hat, Inc.
 *
 * This file is part of cscppc.
 *
 * cscppc is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * cscppc is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with cscppc.  If not, see <http://www.gnu.org/licenses/>.
 */

#define _GNU_SOURCE 

/* for waitid() */
#define _POSIX_C_SOURCE 200809L

#include "cswrap-core.h"
#include "cswrap/cswrap-util.h"

#include <errno.h>
#include <libgen.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define MATCH_PREFIX(str, pref) (!strncmp(str, pref, sizeof(pref) - 1U))

static volatile pid_t pid_compiler;
static volatile pid_t pid_analyzer;

/* print error and return EXIT_FAILURE */
static int fail(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);

    fprintf(stderr, "%s: error: ", wrapper_name);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);

    va_end(ap);
    return EXIT_FAILURE;
}

static int usage(char *argv[])
{
    fprintf(stderr, "Usage:\n\
    export PATH=\"`%s --print-path-to-wrap`:$PATH\"\n\n\
    %s is a compiler wrapper that runs %s in background.  Create a\n\
    symbolic link to %s named as your compiler (gcc, g++, ...) and put it\n\
    to your $PATH.  %s --help prints this text to standard error output.\n",
    wrapper_name, wrapper_name, analyzer_name, wrapper_name, wrapper_name);

    for (; *argv; ++argv)
        if (STREQ("--help", *argv))
            /* if the user really asks for --help, we have succeeded */
            return EXIT_SUCCESS;

    /* wrapper called directly, no argument matched */
    return EXIT_FAILURE;
}

static int handle_args(const int argc, char *argv[])
{
    if (argc == 2 && STREQ("--print-path-to-wrap", argv[1])) {
        printf("%s\n", wrapper_path);
        return EXIT_SUCCESS;
    }

    return usage(argv);
}

void signal_forwarder(int signum)
{
    const int saved_errno = errno;

    if (0 < pid_compiler)
        kill(pid_compiler, signum);

    if (0 < pid_analyzer)
        kill(pid_analyzer, signum);

    errno = saved_errno;
}

bool install_signal_forwarder(void)
{
    static int forwarded_signals[] = {
        SIGINT,
        SIGQUIT,
        SIGTERM
    };

    static int forwarded_signals_cnt =
        sizeof(forwarded_signals)/
        sizeof(forwarded_signals[0]);

    static const struct sigaction sa = {
        .sa_handler = signal_forwarder
    };

    /* install the handler for all forwarded signals */
    int i;
    for (i = 0; i < forwarded_signals_cnt; ++i)
        if (0 != sigaction(forwarded_signals[i], &sa, NULL))
            return false;

    return true;
}

pid_t launch_tool(const char *tool, char **argv)
{
    const pid_t pid = fork();
    if (pid < 0)
        fail("failed to fork() for '%s' (%s)", tool, strerror(errno));

    if (pid != 0)
        /* either fork() failure, or continuation of the parental process */
        return pid;

    execvp(tool, argv);
    fail("failed to exec '%s' (%s)", tool, strerror(errno));
    exit((ENOENT == errno)
            ? /* command not found      */ 0x7F
            : /* command not executable */ 0x7E);
}

int wait_for(const pid_t pid)
{
    for (;;) {
        siginfo_t si;
        while (-1 == waitid(P_ALL, 0, &si, WEXITED))
            if (EINTR != errno)
                return fail("waitid() failed while waiting for %d: %s", pid,
                        strerror(errno));

        switch (si.si_code) {
            case CLD_STOPPED:
            case CLD_CONTINUED:
                /* not yet finished */
                continue;

            default:
                break;
        }

        if (pid_compiler == si.si_pid)
            pid_compiler = 0;

        if (pid_analyzer == si.si_pid)
            pid_analyzer = 0;

        if (pid != si.si_pid)
            continue;

        switch (si.si_code) {
            case CLD_KILLED:
            case CLD_DUMPED:
                /* terminated by a signal */
                return 0x80 + si.si_status;

            case CLD_EXITED:
                /* terminated by a call to _exit() */
            default:
                return si.si_status;
        }
    }
}

bool is_def_inc(const char *arg)
{
    return MATCH_PREFIX(arg, "-D")
        || MATCH_PREFIX(arg, "-I")
        || (analyzer_is_gcc_compatible
                && (STREQ(arg, "-include")
                    || STREQ(arg, "-iquote")
                    || STREQ(arg, "-isystem")));
}

bool is_bare_def_inc(const char *arg)
{
    return STREQ(arg, "-D")
        || STREQ(arg, "-I")
        || (analyzer_is_gcc_compatible
                && (STREQ(arg, "-include")
                    || STREQ(arg, "-iquote")
                    || STREQ(arg, "-isystem")));
}

bool is_input_file_suffix(const char *suffix)
{
    return STREQ(suffix, "c")
        || STREQ(suffix, "C")
        || STREQ(suffix, "cc")
        || STREQ(suffix, "cpp")
        || STREQ(suffix, "cxx");
}

bool is_black_listed_file(const char *name)
{
    return STREQ(name, "conftest.c")
        || STREQ(name, "../test.c")
        || STREQ(name, "_configtest.c")
        || strstr(name, "/CMakeTmp/");
}

bool is_input_file(const char *arg)
{
    const char *suffix = strrchr(arg, '.');
    if (!suffix)
        /* we require the file name to contain at least one dot */
        return false;

    /* skip behind the dot */
    ++suffix;

    /* check for a known input file suffix */
    return is_input_file_suffix(suffix);
}

int /* args remain */ drop_arg(int *pargc, char **argv, const int i)
{
    const int argc = --(*pargc);
    const int args_remain = argc - i;
    char **start = argv + i;
    memmove(start, start + 1, args_remain * sizeof(*argv));
    return args_remain;
}

int translate_args_for_analyzer(int argc, char **argv)
{
    int cnt_files = 0;

    int i;
    for (i = 1; i < argc; ++i) {
        const char *arg = argv[i];
        if (STREQ(arg, "-E"))
            /* preprocessing --> bypass analyzer in order to not break ccache */
            return -1;

        if (is_def_inc(arg)) {
            if (is_bare_def_inc(arg))
                /* bare -D or -I --> we need to take the next arg, too */
                ++i;

            /* pass -D and -I flags directly */
            continue;
        }

        if (is_input_file(arg)) {
            if (is_black_listed_file(arg))
                /* black-listed input file --> do not start analyzer */
                return -1;

            /* pass input file name as it is */
            ++cnt_files;
            continue;
        }

        if (analyzer_is_gcc_compatible) {
            if (STREQ(arg, "-m16") || STREQ(arg, "-m32") || STREQ(arg, "-m64")
                    || STREQ(arg, "-fno-exceptions")
                    || MATCH_PREFIX(arg, "-O")
                    || MATCH_PREFIX(arg, "-std"))
                /* pass -m{16,32,64} and the like directly to the analyzer */
                continue;

            /* -i{nclude,quote,system} are already handled by is_def_inc() */
            goto drop_it;
        }

        /* translate -iquote and -isystem to -I... */
        if ((STREQ(arg, "-iquote") || STREQ(arg, "-isystem"))
                && (0 < drop_arg(&argc, argv, i)))
        {
            char *cpp_arg;
            if (0 < asprintf(&cpp_arg, "-I%s", argv[i]))
                argv[i] = cpp_arg;

            continue;
        }

        /* translate '-include FILE' to --include=FILE */
        if (STREQ(arg, "-include") && (0 < drop_arg(&argc, argv, i))) {
            char *cpp_arg;
            if (0 < asprintf(&cpp_arg, "--include=%s", argv[i]))
                argv[i] = cpp_arg;

            continue;
        }

drop_it:
        /* drop anything else */
        drop_arg(&argc, argv, i--);
    }

    if (!cnt_files)
        /* no input files, giving up... */
        return -1;

    return argc;
}

int num_custom_opts(const char *str)
{
    if (!str || !str[0])
        return 0;

    int num;
    for (num = 1; NULL != (str = strchr(str, ':')); ++num)
        ++str;

    return num;
}

bool read_custom_opts(char **dst, const char *str)
{
    if (!str || !str[0])
        return true;

    /* go through all options separated by ':' */
    for (;;) {
        const char *term = strchr(str, ':');
        if (!term)
            /* this was the last option */
            return (*dst = strdup(str));

        /* allocate memory for the option in the dst array */
        const size_t len = term - str;
        *dst = malloc(len + /* for NUL */ 1);
        if (!*dst)
            return /* OOM */ false;

        /* copy single option to the dst array */
        memcpy(*dst, str, len);
        (*dst)[len] = '\0';

        /* move the cursor and jump to the next option */
        ++dst;
        str = term + 1;
    }
}

void consider_running_analyzer(const int argc_orig, char **const argv_orig)
{
    /* clone the argv array */
    size_t argv_size = (argc_orig + 1) * sizeof(char *);
    char **argv = malloc(argv_size);
    if (!argv)
        /* OOM */
        return;
    memcpy(argv, argv_orig, argv_size);

    /* translate cmd-line args for analyzer */
    const int argc_cmd = translate_args_for_analyzer(argc_orig, argv);
    if (argc_cmd <= 0) {
        /* do not start analyzer */
        free(argv);
        return;
    }

    /* count custom analyzer args (read from env var) */
    const char *var_add_opts = getenv(wrapper_addopts_envvar_name);
    const int argc_custom = num_custom_opts(var_add_opts);

    const int argc_total = argc_cmd + analyzer_def_argc + argc_custom;
    if (argc_orig < argc_total) {
        /* enlarge the argv array */
        argv_size = (argc_total + 1) * sizeof(char *);
        char **argv_new = realloc(argv, argv_size);
        if (!argv_new) {
            /* OOM */
            free(argv);
            return;
        }
        argv = argv_new;
    }

    /* append default analyzer args */
    char **argv_now = argv + argc_cmd;
    memcpy(argv_now, analyzer_def_argv, analyzer_def_argc * sizeof(char *));
    argv_now += analyzer_def_argc - /* terminating NULL */1;

    /* append custom analyzer args (read from env var) if any */
    if (!read_custom_opts(argv_now, var_add_opts)) {
        free(argv);
        return;
    }

    /* make sure that the analyzer process is named analyzer_name */
    argv[0] = (char *) analyzer_name;

    /* make sure there is NULL at the end of argv[] */
    argv[argc_total - 1] = NULL;

    const char *var_debug = getenv(wrapper_debug_envvar_name);
    if (var_debug && *var_debug) {
        /* run-time debugging enabled */
        const pid_t pid = getpid();

        int i;
        for(i = 0; i < argc_total; ++i)
            printf("%s[%d]: argv[%d] = %s\n", wrapper_name, pid, i, argv[i]);
    }

    /* try to start analyzer */
    pid_analyzer = launch_tool(analyzer_name, argv);

    /* FIXME: release also the memory allocated by asprintf() and
       read_custom_opts() */
    free(argv);
}

int run_compiler_and_analyzer(const char *tool, const int argc, char **argv)
{
    if (!install_signal_forwarder())
        return fail("unable to install signal forwarder");

    pid_compiler = launch_tool(tool, argv);
    if (pid_compiler <= 0)
        return EXIT_FAILURE;

    consider_running_analyzer(argc, argv);

    tag_process_name(wrapper_proc_prefix, argc, argv);

    const int status = wait_for(pid_compiler);

    if (0 < pid_analyzer) {
        if (status)
            /* compilation failed --> kill analyzer now! */
            kill(pid_analyzer, SIGTERM);

        /* analyzer was started, wait till it finishes */
        wait_for(pid_analyzer);
    }

    return status;
}

int main(int argc, char *argv[])
{
    int status;
    if (argc < 1)
        return fail("argc < 1");

    /* check which tool we are asked to run via this wrapper */
    char *tool = basename(argv[0]);
    if (STREQ(tool, wrapper_name))
        return handle_args(argc, argv);

    /* duplicate the string as basename() return value is not valid forever */
    tool = strdup(tool);
    if (!tool)
        return fail("strdup() failed");

    /* remove self from $PATH in order to avoid infinite recursion */
    char *path = getenv("PATH");
    status = (remove_self_from_path(tool, path, wrapper_name) && path[0])
        ? run_compiler_and_analyzer(tool, argc, argv)
        : fail("symlink '%s -> %s' not found in $PATH (%s)",
                tool, wrapper_name, path);

    free(tool);
    return status;
}
