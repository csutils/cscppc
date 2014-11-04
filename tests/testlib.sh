# test-case library code (needs to be sourced at the beginning of runtest.sh)

# path to the script itself
PATH_TO_SELF="$0"

# path to the directory containing runtest.sh
TEST_SRC_DIR="$1"

# path to a read-write directory that can be used for testing
TEST_DST_DIR="$2"

# path to binaries of the wrappers
PATH_TO_WRAP="$3"

# create $TEST_DST_DIR (if it does not exist already)
mkdir -p "$TEST_DST_DIR" || exit $?

# enter $TEST_DST_DIR
cd "$TEST_DST_DIR" || exit $?

# increase the possibility to catch use-after-free bugs
export MALLOC_PERTURB_=170
