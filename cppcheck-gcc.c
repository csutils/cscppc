/*
 * Copyright (C) 2013 Red Hat, Inc.
 *
 * This file is part of cppcheck-gcc.
 *
 * cppcheck-gcc is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * cppcheck-gcc is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with cppcheck-gcc.  If not, see <http://www.gnu.org/licenses/>.
 */

#define _GNU_SOURCE 

#include <errno.h>
#include <libgen.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

char wname[] = "cppcheck-gcc";

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

int run_compiler_and_cppcheck(const char *tool, char **argv)
{
    /* TODO */
    execvp(tool, argv);
    return fail("failed to launch %s (%s)", tool, strerror(errno));
}

int main(int argc, char *argv[])
{
    int status;
    if (argc < 1)
        return fail("argc < 1");

    /* check which tool we are asked to run via this wrapper */
    char *tool = strdup(basename(argv[0]));
    if (!tool)
        return fail("strdup() failed");

    /* remove self from $PATH in order to avoid infinite recursion */
    char *path = getenv("PATH");
    status = (remove_self_from_path(tool, path))
        ? run_compiler_and_cppcheck(tool, argv)
        : fail("symlink '%s -> %s' not found in $PATH (%s)", tool, wname, path);

    free(tool);
    return status;
}
