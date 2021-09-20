/*
 * Copyright (C) 2018 Red Hat, Inc.
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

#include <stddef.h>

const char *wrapper_name = "csmatch";

#ifdef PATH_TO_CSMATCH
const char *wrapper_path = PATH_TO_CSMATCH;
#else
const char *wrapper_path = "";
#endif

const char *wrapper_proc_prefix = "[csmatch] ";

const char *wrapper_addopts_envvar_name = "CSMATCH_ADD_OPTS";

const char *wrapper_debug_envvar_name = "DEBUG_CSMATCH";

const char *analyzer_name = "smatch";

const char *analyzer_bin_envvar = NULL;

const bool analyzer_is_cxx_ready = false;

const bool analyzer_is_gcc_compatible = true;

static const char *analyzer_def_arg_list[] = {
    "-D_Float128=long double",
    NULL
};

const char **analyzer_def_argv = analyzer_def_arg_list;

const int analyzer_def_argc =
    sizeof(analyzer_def_arg_list)/
    sizeof(analyzer_def_arg_list[0]);

const char **compiler_del_args;
