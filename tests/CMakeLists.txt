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

# run test-cases
file(GLOB runtests "${CMAKE_CURRENT_SOURCE_DIR}/*/runtest.sh")
foreach(runtest ${runtests})
    get_filename_component(test_src_dir "${runtest}" PATH)
    get_filename_component(test_name "${test_src_dir}" NAME)

    # for each of them run: runtest.sh PATH_TO_CSWRAP TEST_DST_DIR TEST_SRC_DIR
    add_test("${test_name}" "${runtest}" "${test_src_dir}"
        "${CMAKE_CURRENT_BINARY_DIR}/${test_name}/"
        "${CMAKE_BINARY_DIR}/src")
endforeach()
