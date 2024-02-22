#!/bin/bash

#change working directory to the first argument

cd "$1"

projectRootFile="./Config/Root.ini"
if [ -f $projectRootFile ]; then
    echo "Root file exists"
    projectRootPath=$(cat $projectRootFile)
else
    echo "Root file does not exist"
    projectRootPath="."
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

$SCRIPT_DIR/publish.sh prod $(cat ./Config/Project.ini) $projectRootPath
