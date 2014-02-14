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

#include <bits/wordsize.h>
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

#define STREQ(a, b) (!strcmp(a, b))
#define MATCH_PREFIX(str, pref) (!strncmp(str, pref, sizeof(pref) - 1U))

static const char wname[] = "cscppc";

static const char *cppcheck_def_argv[] = {
    "-D__GNUC__",
    "-D__STDC__",
#if __WORDSIZE == 32
    "-D__i386__",
    "-D__WORDSIZE=32",
#elif __WORDSIZE == 64
    "-D__x86_64__",
    "-D__WORDSIZE=64",
#else
#error "Unknown word size"
#endif
    "--inline-suppr",
    "--quiet",
    "--template={file}:{line}: {severity}: {id}: {message}",
    "--suppressions-list=/usr/share/cscppc/default.supp",
    NULL
};

static const size_t cppcheck_def_argc =
    sizeof(cppcheck_def_argv)/
    sizeof(cppcheck_def_argv[0]);

static volatile pid_t pid_compiler;
static volatile pid_t pid_cppcheck;

/* print error and return EXIT_FAILURE */
static int fail(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);

    fprintf(stderr, "%s: error: ", wname);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);

    va_end(ap);
    return EXIT_FAILURE;
}

static int usage(char *argv[])
{
    fprintf(stderr, "Usage:\n\
    %s is a compiler wrapper that runs cppcheck in background.  Create a\n\
    symbolic link to %s named as your compiler (gcc, g++, ...) and put it\n\
    to your $PATH.  %s --help prints this text to standard error output.\n",
    wname, wname, wname);

    for (; *argv; ++argv)
        if (STREQ("--help", *argv))
            /* if the user really asks for --help, we have succeeded */
            return EXIT_SUCCESS;

    /* wrapper called directly, no argument matched */
    return EXIT_FAILURE;
}

bool remove_self_from_path(const char *tool, char *path)
{
    if (!path)
        return false;

    bool found = false;

    /* go through all paths in $PATH */
    while (*path) {
        char *term = strchr(path, ':');
        if (term)
            /* temporarily replace the separator by zero */
            *term = '\0';

        /* concatenate dirname and basename */
        char *raw_path;
        if (-1 == asprintf(&raw_path, "%s/%s", path, tool))
            return false;

        /* compare the canonicalized basename with wname */
        char *exec_path = realpath(raw_path, NULL);
        const bool self = exec_path && !strcmp(wname, basename(exec_path));
        free(exec_path);
        free(raw_path);

        /* jump to the next path in $PATH */
        char *const next = (term)
            ? (term + 1)
            : (path + strlen(path));

        if (self) {
            /* remove self from $PATH */
            memmove(path, next, 1U + strlen(next));
            found = true;
            continue;
        }

        if (term)
            /* restore the original separator */
            *term = ':';

        /* move the cursor */
        path = next;
    }

    return found;
}

void signal_forwarder(int signum)
{
    const int saved_errno = errno;

    if (pid_compiler)
        kill(pid_compiler, signum);

    if (pid_cppcheck)
        kill(pid_cppcheck, signum);

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
    if (pid != 0)
        /* either fork() failure, or continuation of the parental process */
        return pid;

    execvp(tool, argv);
    exit((ENOENT == errno)
            ? /* command not found      */ 0x7F
            : /* command not executable */ 0x7E);
}

int wait_for(volatile pid_t *ppid)
{
    const pid_t pid = *ppid;

    int status;
    while (-1 == waitpid(pid, &status, 0))
        if (EINTR != errno)
            return fail("waitpid(%d) failed: %s", pid, strerror(errno));

    *ppid = (pid_t) 0;

    if (WIFEXITED(status))
        /* propagate the exit status of the child */
        return WEXITSTATUS(status);

    if (WIFSIGNALED(status))
        /* child signalled to die */
        return 0x80 + WTERMSIG(status);

    return fail("waitpid(%d) returned unexpected status: %d", pid, status);
}

bool is_def_inc(const char *arg)
{
    return MATCH_PREFIX(arg, "-D")
        || MATCH_PREFIX(arg, "-I");
}

bool is_bare_def_inc(const char *arg)
{
    return STREQ(arg, "-D")
        || STREQ(arg, "-I");
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

bool is_input_file(const char *arg, bool *black_listed)
{
    const char *suffix = strrchr(arg, '.');
    if (!suffix)
        /* we require the file name to contain at least one dot */
        return false;

    /* skip behind the dot */
    ++suffix;
    if (!is_input_file_suffix(suffix))
        /* not a know input file suffix */
        return false;

    *black_listed = is_black_listed_file(arg);
    return true;
}

int /* args remain */ drop_arg(int *pargc, char **argv, const int i)
{
    const int argc = --(*pargc);
    const int args_remain = argc - i;
    char **start = argv + i;
    memmove(start, start + 1, args_remain * sizeof(*argv));
    return args_remain;
}

int translate_args_for_cppcheck(int argc, char **argv)
{
    int cnt_files = 0;

    int i;
    for (i = 1; i < argc; ++i) {
        const char *arg = argv[i];
        if (STREQ(arg, "-E"))
            /* preprocessing --> bypass cppcheck in order to not break ccache */
            return -1;

        if (is_def_inc(arg)) {
            if (is_bare_def_inc(arg))
                /* bare -D or -I --> we need to take the next arg, too */
                if (argc <= ++i)
                    /* ... but there is not next arg --> bail out now! */
                    break;

            /* pass -D and -I flags directly */
            continue;
        }

        bool black_listed = false;
        if (is_input_file(arg, &black_listed)) {
            if (black_listed)
                /* black-listed input file --> do not start cppcheck */
                return -1;

            /* pass input file name as it is */
            ++cnt_files;
            continue;
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

        /* drop anything else */
        drop_arg(&argc, argv, i--);
    }

    if (!cnt_files)
        /* no input files, giving up... */
        return -1;

    return argc;
}

void consider_running_cppcheck(const int argc_orig, char **const argv_orig)
{
    /* translate cmd-line args for cppcheck */
    char **argv = argv_orig;
    const int argc_cmd = translate_args_for_cppcheck(argc_orig, argv);
    if (argc_cmd <= 0)
        /* do not start cppcheck */
        return;

    const int argc_total = argc_cmd + cppcheck_def_argc;
    if (argc_orig < argc_total) {
        /* allocate argv on heap */
        const size_t argv_size = sizeof(char *) * argc_total;
        char **argv_dup = malloc(argv_size);
        if (!argv_dup)
            /* OOM */
            return;

        memcpy(argv_dup, argv, argv_size);
        argv = argv_dup;
    }

    /* append default cppcheck args */
    memcpy(argv + argc_cmd, cppcheck_def_argv, sizeof cppcheck_def_argv);

    /* make sure the cppcheck process is named cppcheck */
    argv[0] = "cppcheck";

    const char *var_debug = getenv("DEBUG_CPPCHECK_GCC");
    if (var_debug && *var_debug) {
        const pid_t pid = getpid();

        int i;
        for(i = 0; i < argc_total; ++i)
            printf("cscppc[%d]: argv[%d] = %s\n", pid, i, argv[i]);
    }

    /* try to start cppcheck */
    pid_cppcheck = launch_tool("cppcheck", argv);
    if (pid_cppcheck <= 0)
        fail("failed to launch cppcheck (%s)", strerror(errno));

    if (argv_orig != argv)
        /* FIXME: release also the memory allocated by asprintf() */
        free(argv);
}

int run_compiler_and_cppcheck(const char *tool, const int argc, char **argv)
{
    if (!install_signal_forwarder())
        return fail("unable to install signal forwarder");

    pid_compiler = launch_tool(tool, argv);
    if (pid_compiler <= 0)
        return fail("failed to launch %s (%s)", tool, strerror(errno));

    consider_running_cppcheck(argc, argv);

    const int status = wait_for(&pid_compiler);

    if (0 < pid_cppcheck) {
        if (status)
            /* compilation failed --> kill cppcheck now! */
            kill(pid_cppcheck, SIGTERM);

        /* cppcheck was started, wait till it finishes */
        wait_for(&pid_cppcheck);
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
    if (STREQ(tool, wname))
        return usage(argv);

    /* duplicate the string as basename() return value is not valid forever */
    tool = strdup(tool);
    if (!tool)
        return fail("strdup() failed");

    /* remove self from $PATH in order to avoid infinite recursion */
    char *path = getenv("PATH");
    status = (remove_self_from_path(tool, path))
        ? run_compiler_and_cppcheck(tool, argc, argv)
        : fail("symlink '%s -> %s' not found in $PATH (%s)", tool, wname, path);

    free(tool);
    return status;
}
