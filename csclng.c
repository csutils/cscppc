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

#include <stddef.h>

const char *wrapper_name = "csclng";

#ifdef PATH_TO_CSCLNG
const char *wrapper_path = PATH_TO_CSCLNG;
#else
const char *wrapper_path = "";
#endif

const char *wrapper_proc_prefix = "[csclng] ";

const char *wrapper_debug_envvar_name = "DEBUG_CSCLNG";

const char *analyzer_name = "clang";

const bool analyzer_is_gcc_compatible = true;

static const char *analyzer_def_arg_list[] = {
    "--analyze",

    /* write error traces to stderr instead of creating .plist files */
    "-Xanalyzer",
    "-analyzer-output=text",

    NULL
};

const char **analyzer_def_argv = analyzer_def_arg_list;

const int analyzer_def_argc =
    sizeof(analyzer_def_arg_list)/
    sizeof(analyzer_def_arg_list[0]);
