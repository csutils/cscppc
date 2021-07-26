# Copyright (C) 2014 - 2021 Red Hat, Inc.
#
# This file is part of cscppc.
#
# cscppc is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# cscppc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cscppc.  If not, see <http://www.gnu.org/licenses/>.

cmake_minimum_required(VERSION 2.8.12)
project(cscppc C)
enable_testing()

# make sure that waitid() is available
include(CheckFunctionExists)
check_function_exists(waitid HAVE_WAITID_FUNCTION)
if(HAVE_WAITID_FUNCTION)
else()
    message(FATAL_ERROR "
required waitid() function not found")
endif()

# create csclng++.c from csclng.c
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/csclng++.c
    COMMAND sed -e 's/csclng/csclng++/g' -e 's/clang/clang++/g'
    ${CMAKE_CURRENT_SOURCE_DIR}/csclng.c >
    ${CMAKE_CURRENT_BINARY_DIR}/csclng++.c
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/csclng.c
    COMMENT "Generating csclng++.c source file...")
add_definitions(-iquote ${CMAKE_CURRENT_SOURCE_DIR})

# compile and install executables
add_executable(cscppc cscppc.c cswrap-core.c cswrap/cswrap-util.c)
add_executable(csclng csclng.c cswrap-core.c cswrap/cswrap-util.c)
add_executable(csgcca csgcca.c cswrap-core.c cswrap/cswrap-util.c)
add_executable(csclng++ ${CMAKE_CURRENT_BINARY_DIR}/csclng++.c
    cswrap-core.c cswrap/cswrap-util.c)
add_executable(csmatch csmatch.c cswrap-core.c cswrap/cswrap-util.c)
install(TARGETS cscppc csclng csclng++ csgcca csmatch DESTINATION bin)

# install data files
add_subdirectory(data)

# build and install man pages (if asciidoc is available)
add_subdirectory(doc)

# run test-cases
file(GLOB runtests "${CMAKE_CURRENT_SOURCE_DIR}/tests/*/runtest.sh")
foreach(runtest ${runtests})
    get_filename_component(test_src_dir "${runtest}" PATH)
    get_filename_component(test_name "${test_src_dir}" NAME)

    # for each of them run: runtest.sh PATH_TO_CSWRAP TEST_DST_DIR TEST_SRC_DIR
    add_test("${test_name}" "${runtest}" "${test_src_dir}"
        "${CMAKE_CURRENT_BINARY_DIR}/tests/${test_name}/"
        "${CMAKE_CURRENT_BINARY_DIR}")
endforeach()
