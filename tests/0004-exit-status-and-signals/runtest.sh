#!/bin/bash
source "$1/../testlib.sh"
set -x

COMPILERS="cc-true cc-fail cc-slow"
TOOLS="cppcheck $COMPILERS"

mkdir -p tool wrap
export PATH="$PWD/wrap:$PWD/tool:$PATH"

# create faked compilers and analyzers
for i in $TOOLS; do
    printf '#!/bin/bash
echo "$$" > "$(basename "$0").pid"\n' > tool/$i     || exit $?
    chmod 0755 tool/$i                              || exit $?
done
echo "sleep 1"  >> "tool/cppcheck"                  || exit $?
echo "true"     >> "tool/cc-true"                   || exit $?
echo "false"    >> "tool/cc-fail"                   || exit $?
echo 'sleep 64 &
trap "kill $!" EXIT
wait $!' >> "tool/cc-slow"                          || exit $?

# create symlinks to cscppc
for i in $COMPILERS; do
    ln -fs "$PATH_TO_WRAP/cscppc" wrap/$i           || exit $?
done

# successful compilation
rm -f *.pid
"cc-true" "test.c"                                  || exit $?
test 0 -lt "$(<cc-true.pid)"                        || exit $?
test 0 -lt "$(<cppcheck.pid)"                       || exit $?

# failed compilation
rm -f *.pid
"cc-fail" "test.c"                                  && exit 1
test 0 -lt "$(<cc-fail.pid)"                        || exit $?

# compiler/analyzer not found
rm -f *.pid
mkdir -p empty
PATH="$PWD/wrap:$PWD/empty" "cc-fail" "test.c"      && exit 1
test -e "cc-fail.pid"                               && exit 1
test -e "cppcheck.pid"                              && exit 1

install_killer() {
    while sleep .1; do
        pid="$(<$1.pid)"
        test 0 -lt "$pid" || continue
        kill "$pid"
        exit $?
    done
}

# compiler killed
rm -f *.pid
install_killer cc-slow &
pid_killer="$!"
"cc-slow" test.c
test 143 = "$?"                                     || exit $?
wait "$pid_killer"                                  || exit $?

# analyzer killed
rm -f *.pid
cp -af "tool/cc-slow" "tool/cppcheck"
install_killer cppcheck &
pid_killer="$!"
"cc-true" test.c                                    || exit $?
wait "$pid_killer"                                  || exit $?

# wrapper killed
rm -f *.pid
"cc-slow" test.c &
sleep 2
kill "$!"                                           || exit $?
wait "$!"
test 143 = "$?"                                     || exit $?
test 0 -lt "$(<cc-slow.pid)"                        || exit $?
test 0 -lt "$(<cppcheck.pid)"                       || exit $?
