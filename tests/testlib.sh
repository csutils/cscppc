# test-case library code (needs to be sourced at the beginning of runtest.sh)

# path to the script itself
PATH_TO_SELF="$0"

# path to the directory containing runtest.sh
TEST_SRC_DIR="$1"

# path to a read-write directory that can be used for testing
TEST_DST_DIR="$2"

# path to binaries of the wrappers
PATH_TO_WRAP="$3"

# sanitizer build is used
grep -q "SANITIZERS:BOOL=ON" "$PATH_TO_WRAP/../CMakeCache.txt"
HAS_SANITIZERS="$?"

if [[ "$HAS_SANITIZERS" -eq 0 ]]; then
    # make UBSan print whole stack traces
    export UBSAN_OPTIONS="print_stacktrace=1"

    # disable LSan because the fork&exec machinery in 0003-translation-of-args
    # test produces incomplete stack traces making the leak suppression of
    # these deliberate leaks useless on some distributions (Arch, Ubuntu, ...)
    export ASAN_OPTIONS="detect_leaks=0"
fi

# create $TEST_DST_DIR (if it does not exist already)
mkdir -p "$TEST_DST_DIR" || exit $?

# enter $TEST_DST_DIR
cd "$TEST_DST_DIR" || exit $?

# increase the possibility to catch use-after-free bugs
export MALLOC_PERTURB_=170
