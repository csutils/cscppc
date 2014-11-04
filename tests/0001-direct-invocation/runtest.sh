#!/bin/bash
source "$1/../testlib.sh"
set -x

WRAPS="cscppc csclng csclng++"

export PATH="${PATH_TO_WRAP}:${PATH}"

# direct invocation without valid arguments should fail
for wrap in $WRAPS; do
    "$wrap"                                     && exit 1
    "$wrap" foo bar                             && exit 1
    "$PATH_TO_WRAP/$wrap"                       && exit 1
    "$PATH_TO_WRAP/$wrap" foo bar               && exit 1
done

# valid arguments --help and --print-path-to-wrap should succeed
for wrap in $WRAPS; do
    "$wrap" --help                              || exit $?
    "$wrap" --print-path-to-wrap                || exit $?
    "$PATH_TO_WRAP/$wrap" --help                || exit $?
    "$PATH_TO_WRAP/$wrap" --print-path-to-wrap  || exit $?
done

BIN="${PWD}/bin"
mkdir -p "$BIN"

# this should not cause an infinite loop
for wrap in $WRAPS; do
    ln -fs "$PATH_TO_WRAP/$wrap" "$BIN"
    PATH="$BIN" "$wrap" && exit 1
done

# non-existing compiler
for wrap in $WRAPS; do
    ln -fs "$PATH_TO_WRAP/$wrap" "${BIN}/invalid"
    PATH="${BIN}:." invalid 2> cswrap-error-output.txt && exit 1
    printf "%s: error: failed to exec 'invalid' (No such file or directory)\n" \
        "$wrap" | diff -u - cswrap-error-output.txt || exit $?
done

# non-existing compiler
for wrap in $WRAPS; do
    ln -fs "$PATH_TO_WRAP/$wrap" "${BIN}/invalid"
    PATH="$BIN" invalid 2> cswrap-error-output.txt && exit 1
    printf "%s: error: symlink 'invalid -> %s' not found in \$PATH ()\n" \
        "$wrap" "$wrap" | diff -u - cswrap-error-output.txt || exit $?
done
