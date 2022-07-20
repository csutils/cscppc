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

macro(add_man_page tool)
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${tool}.1
        COMMAND ${A2X} -f manpage ${CMAKE_CURRENT_SOURCE_DIR}/${tool}.adoc
        -D ${CMAKE_CURRENT_BINARY_DIR}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${tool}.adoc
        COMMENT "Generating ${tool}.1 man page...")
    set(man_pages ${man_pages} ${CMAKE_CURRENT_BINARY_DIR}/${tool}.1)

    include(GNUInstallDirs)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${tool}.1
            DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)
endmacro()

# build and install man pages (if asciidoc is available)
find_program(A2X a2x)
if(A2X)
    message(STATUS "a2x found - ${A2X}")
    add_man_page(csclng)
    add_man_page(cscppc)
    add_man_page(csgcca)
    add_man_page(csmatch)
    add_custom_target(doc ALL DEPENDS ${man_pages})
else()
    message(STATUS "a2x not found - documentation will NOT be built")
endif()
