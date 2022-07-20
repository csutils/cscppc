#!/bin/bash
source "$1/../testlib.sh"
set -x

COMPILERS="cc gcc g++"

mkdir -p tools
PATH="$PWD/tools:$PATH"

WRAPPERS="cscppc csclng csclng++"
for wrap in $WRAPPERS; do
    mkdir -p $wrap
    PATH="$PWD/$wrap:$PATH"
done

export PATH

# create faked compilers and analyzers
printf '#!/bin/sh
tool="$(basename "$0")"
printf "%%s\\n" "$*" > "${tool}-args.txt"\n' \
    | tee tools/{cc,gcc,g++,cppcheck,clang{,++}}                    || exit $?
chmod 0755 tools/{cc,gcc,g++,cppcheck,clang{,++}}                   || exit $?

# create symlinks to wrappers
ln -fs "$PATH_TO_WRAP/cscppc"   cscppc/cc                           || exit $?
ln -fs "$PATH_TO_WRAP/csclng"   csclng/gcc                          || exit $?
ln -fs "$PATH_TO_WRAP/csclng++" csclng++/g++                        || exit $?

# run the wrappers through valgrind if available
EXEC_PREFIX=
if [[ "$HAS_SANITIZERS" -eq 1 ]] && valgrind --version; then
    EXEC_PREFIX="valgrind -q --undef-value-errors=no --error-exitcode=7"
    printf "%s " "$EXEC_PREFIX" >> tools/g++
    printf "%s " "$EXEC_PREFIX" >> tools/gcc
fi

# chain the compilers
echo 'gcc "$@"' >> tools/g++                                        || exit $?
echo 'cc "$@"'  >> tools/gcc                                        || exit $?

lookup() {
    for j in $(<$2); do
        test "$1" = "$j" && return 0
    done
    return 1
}

single_check() {
    { set +x; } 2>/dev/null
    trap "echo FAILED" EXIT
    trap "trap EXIT; set -x" RETURN
    analyzers="$1"
    shift
    with_args="$1"
    shift
    without_args="$1"
    shift
    rm -f *-args.txt
    echo "$*" > full-args.txt

    # run the whole chain with the given args
    $EXEC_PREFIX g++ "$@"                                           || exit $?

    # check that all _compilers_ got the full list of args
    for i in $COMPILERS; do
        diff -u full-args.txt "$i-args.txt"                         || exit $?
    done

    for analyzer in $analyzers; do
        for i in $with_args; do
            lookup "$i" "${analyzer}-args.txt"                      || exit $?
        done

        for i in $without_args; do
            lookup "$i" "${analyzer}-args.txt"                      && exit 1
            true
        done
    done
}

# basic invocation
single_check "cppcheck"      "test.c --inline-suppr --quiet" "--analyze" test.c
single_check "clang++ clang" "test.c --analyze" "--inline-suppr --quiet" test.c

# dropping unrelated flags
single_check "cppcheck"      "a.c b.cc c.C d.cpp e.cxx" "-g -O0 --Wall -Wextra" -g a.c b.cc -O0 c.C d.cpp e.cxx --Wall -Wextra
single_check "clang clang++" "a.c b.cc -O0 c.C d.cpp e.cxx" "-g --Wall -Wextra" -g a.c b.cc -O0 c.C d.cpp e.cxx --Wall -Wextra

# passing -D and -I to the analyzer
single_check "cppcheck clang++ clang" "a.c -DTRACE -D SSLTRACE -I/usr/include-glib-2.0 -I /usr/include/nss3" "-g -Wall" a.c -g -DTRACE -D SSLTRACE -O0 -I/usr/include-glib-2.0 -I /usr/include/nss3 -Wall

# passing -m{16,32,64} and -std=... to clang
single_check "clang++ clang" "-m16 -m32 -m64 a.c -std=gnu99" "-g" -m16 -m32 -m64 a.c -std=gnu99 -g
single_check "cppcheck" "a.c" "-m16 -m32 -m64 -g -std=gnu99"      -m16 -m32 -m64 a.c -std=gnu99 -g

# passing -include, -iquote, and -isystem to clang
single_check "clang++ clang" "-include cstddef x.cc -isystem /usr/local/include -iquote ../.." "-I" -include cstddef x.cc -isystem /usr/local/include -iquote ../..

# translating -include, -iquote, and -isystem for cppcheck
single_check "cppcheck" "--include=cstddef x.cc -I/usr/local/include -I../.." "-include -isystem -iquote" -include cstddef x.cc -isystem /usr/local/include -iquote ../..

# adding custom flags
CSCLNG_ADD_OPTS="-Wall" CSCPPC_ADD_OPTS="--enable=all:--inconclusive" single_check "cppcheck"      "a.c --enable=all --inconclusive" "-Wall" a.c
CSCLNG_ADD_OPTS="-Wall" CSCPPC_ADD_OPTS="--enable=all:--inconclusive" single_check "clang clang++" "a.c -Wall" "--enable=all --inconclusive" a.c
