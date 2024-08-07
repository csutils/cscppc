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
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -pedantic")

# enable sanitizers
option(SANITIZERS "Compile with ASan and UBSan" OFF)
if (SANITIZERS)
    # enable ASan and UBSan
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address,undefined")
    # recommended for better error traces
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-omit-frame-pointer")
    # make UBSan reports fatal
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-sanitize-recover=all")
endif()

# link to libc statically
option(STATIC_LINKING "Link to libc statically" OFF)
if(STATIC_LINKING)
    set(STATIC_FLAG "-static")

    # unfortunately, CMAKE_REQUIRED_LINK_OPTIONS was introduced in CMake 3.14
    # so we have to abuse CMAKE_EXE_LINKER_FLAGS instead.
    set(CMAKE_EXE_LINKER_FLAGS_BAK "${CMAKE_EXE_LINKER_FLAGS}")

    # check that the compiler supports generation of static PIE executables
    include(CheckCCompilerFlag)
    set(CMAKE_EXE_LINKER_FLAGS "-static-pie")
    check_c_compiler_flag(-static-pie HAVE_STATIC_PIE)
    if(HAVE_STATIC_PIE)
        set(CMAKE_POSITION_INDEPENDENT_CODE ON)
        set(STATIC_FLAG "-static-pie")
    endif()

    set(CMAKE_EXE_LINKER_FLAGS "${STATIC_FLAG} ${CMAKE_EXE_LINKER_FLAGS_BAK}")
endif()

# make sure that waitid() is available
include(CheckFunctionExists)
check_function_exists(waitid HAVE_WAITID_FUNCTION)
if(NOT HAVE_WAITID_FUNCTION)
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

# use automatic detection of installation directories
include(GNUInstallDirs)

# compile and install executables
macro(add_cs_executable name sources)
    add_executable(${name} ${sources})

    # get the suffix of the PATH_TO_CSXXX variable
    string(TOUPPER ${name} name_upper)
    string(REGEX REPLACE "\\+\\+$" "" name_upper ${name_upper})

    if(PATH_TO_${name_upper})
        set(def -DPATH_TO_${name_upper}=${PATH_TO_${name_upper}})
        target_compile_definitions(cswrap PRIVATE ${def})
        target_compile_definitions(${name} PRIVATE ${def})
    endif()

    install(TARGETS ${name} DESTINATION ${CMAKE_INSTALL_BINDIR})
endmacro()

add_cs_executable(cscppc cscppc.c)
add_cs_executable(csclng csclng.c)
add_cs_executable(csclng++ ${CMAKE_CURRENT_BINARY_DIR}/csclng++.c)
add_cs_executable(csgcca csgcca.c)
add_cs_executable(csmatch csmatch.c)
