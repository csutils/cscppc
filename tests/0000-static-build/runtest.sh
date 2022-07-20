#!/bin/bash
source "$1/../testlib.sh"
set -x

# decide whether a static build was used
if ! grep STATIC_LINKING:BOOL=ON "${PATH_TO_WRAP}/../CMakeCache.txt"; then
  exit 42
fi

while IFS= read -r file; do
    ldd "$file" 2>&1 | grep -E "statically linked|not a dynamic executable" \
        || { ldd "$file"; exit 1; }
done < <(find "${PATH_TO_WRAP}" -maxdepth 1 -type f -executable)
