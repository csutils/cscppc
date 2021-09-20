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

#include "cswrap-core.h"

#include <bits/wordsize.h>
#include <stddef.h>

const char *wrapper_name = "cscppc";

#ifdef PATH_TO_CSCPPC
const char *wrapper_path = PATH_TO_CSCPPC;
#else
const char *wrapper_path = "";
#endif

const char *wrapper_proc_prefix = "[cscppc] ";

const char *wrapper_addopts_envvar_name = "CSCPPC_ADD_OPTS";

const char *wrapper_debug_envvar_name = "DEBUG_CSCPPC";

const char *analyzer_name = "cppcheck";

const char *analyzer_bin_envvar = NULL;

const bool analyzer_is_cxx_ready = true;

const bool analyzer_is_gcc_compatible = false;

static const char *analyzer_def_arg_list[] = {
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
    "-D__CPPCHECK__",
    "--inline-suppr",
    "--quiet",
    "--template={file}:{line}: {severity}: {id}(CWE-{cwe}): {message}",
    "--suppressions-list=/usr/share/cscppc/default.supp",
    NULL
};

const char **analyzer_def_argv = analyzer_def_arg_list;

const int analyzer_def_argc =
    sizeof(analyzer_def_arg_list)/
    sizeof(analyzer_def_arg_list[0]);

const char **compiler_del_args;
