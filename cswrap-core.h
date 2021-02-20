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

#ifndef CSWRAP_CORE_H
#define CSWRAP_CORE_H

#include <stdbool.h>

extern const char *wrapper_name;

extern const char *wrapper_path;

extern const char *wrapper_proc_prefix;

extern const char *wrapper_addopts_envvar_name;

extern const char *wrapper_debug_envvar_name;

extern const char *analyzer_name;

extern const bool analyzer_is_cxx_ready;

extern const bool analyzer_is_gcc_compatible;

extern const char **analyzer_def_argv;

extern const int analyzer_def_argc;

extern const char **compiler_del_args;

#endif /* CSWRAP_CORE_H */
