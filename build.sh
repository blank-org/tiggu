#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/Script"

cd "$1"

projectRootFile="./Config/Root.ini"
if [ -f $projectRootFile ]; then
    echo "Root file exists"
    projectRootPath=$(cat $projectRootFile)
else
    echo "Root file does not exist"
    projectRootPath="."
fi

publishLog=$(mktemp)
trap 'rm -f "$publishLog"' EXIT

"$SCRIPT_DIR/publish.sh" prod "$(cat ./Config/Project.ini)" "$projectRootPath" \
    2>&1 | tee "$publishLog"
publishStatus=${PIPESTATUS[0]}

if [ "$publishStatus" -ne 0 ]; then
    echo "Publishing failed with exit code $publishStatus." >&2
    exit "$publishStatus"
fi

if grep -Eiq '(^|[^[:alpha:]])(warning|error)([^[:alpha:]]|$)' "$publishLog"; then
    echo "Publishing failed because warning or error output was detected." >&2
    exit 1
fi

echo "Publishing completed without warnings or errors."
