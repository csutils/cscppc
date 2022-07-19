# Copyright (C) 2014 - 2022 Red Hat, Inc.
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
message(STATUS "User-provided flags: ${CMAKE_C_FLAGS}")

# set flags
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")

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
add_definitions(-iquote ${CMAKE_SOURCE_DIR})

# compile the common code base only once (as a static library)
add_library(cswrap STATIC cswrap-core.c ../cswrap/src/cswrap-util.c)
link_libraries(cswrap)

# compile and install executables
add_executable(cscppc cscppc.c)
add_executable(csclng csclng.c)
add_executable(csclng++ ${CMAKE_CURRENT_BINARY_DIR}/csclng++.c)
add_executable(csgcca csgcca.c)
add_executable(csmatch csmatch.c)

include(GNUInstallDirs)
install(TARGETS cscppc csclng csclng++ csgcca csmatch
        DESTINATION ${CMAKE_INSTALL_BINDIR})
