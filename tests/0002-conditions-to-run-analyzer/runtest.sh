#!/bin/bash
source "$1/../testlib.sh"
set -x

mkdir -p tools
PATH="$PWD/tools:$PATH"

WRAPPERS="cscppc csclng csclng++"
for wrap in $WRAPPERS; do
    mkdir -p $wrap
    PATH="$PWD/$wrap:$PATH"
done

export PATH

# create faked compilers and analyzers
printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*"\n' \
    | tee tools/{cc,gcc,g++,cppcheck,clang{,++}}                    || exit $?
chmod 0755 tools/{cc,gcc,g++,cppcheck,clang{,++}}                   || exit $?

# create symlinks to wrappers
ln -fs "$PATH_TO_WRAP/cscppc"   cscppc/cc                           || exit $?
ln -fs "$PATH_TO_WRAP/csclng"   csclng/gcc                          || exit $?
ln -fs "$PATH_TO_WRAP/csclng++" csclng++/g++                        || exit $?

# chain the compilers
echo 'gcc "$@"' >> tools/g++                                        || exit $?
echo 'cc "$@"'  >> tools/gcc                                        || exit $?

look_for_tool() {
    grep "^$1" "$2" > /dev/null
}

all_compilers_in() {
    look_for_tool "cc"  "$1" || return $?
    look_for_tool "gcc" "$1" || return $?
    look_for_tool "g++" "$1"
}

all_analyzers_in() {
    look_for_tool "cppcheck" "$1" || return $?
    look_for_tool "clang"    "$1" || return $?
    look_for_tool "clang++"  "$1"
}

no_analyzers_in() {
    look_for_tool "cppcheck" "$1" && return 1
    look_for_tool "clang"    "$1" && return 1
    look_for_tool "clang++"  "$1" && return 1
    return 0
}

single_check() {
    { set +x; } 2>/dev/null
    trap "set -x" RETURN
    with_analyzers="$1"
    shift
    g++ "$@" > output.txt               || exit $?
    all_compilers_in output.txt         || exit $?
    if test "yes" == "$with_analyzers"; then
        chk=all_analyzers_in
    else
        chk=no_analyzers_in
    fi
    if "$chk" output.txt; then
        return 0
    else
        set -x
        cat output.txt
        exit 1
    fi
}

single_check no
single_check no --version
single_check no -E main.c
single_check no -c conftest.c
single_check no -c ../test.c
single_check no -c _configtest.c
single_check no -c ../CMakeTmp/xxx.c
single_check no -c test.java

single_check yes -c main.c
single_check yes -c main.C
single_check yes -c main.cc
single_check yes -c main.cpp
single_check yes -c main.cxx
single_check yes main.c main.C main.cc main.cpp main.cxx
