#!/bin/bash

set -e

RESULT=0

for TEST in $@; do
    TESTNAME=$(basename $TEST)
    echo [TESTING: $TESTNAME] Running Test...
    if ! $TEST; then
        echo [TESTING: $TESTNAME] Failure: See test output for further information
        RESULT=$((RESULT+1))
    else
        echo [TESTING: $TESTNAME] Success
    fi
done

if [ $RESULT == 0 ]; then
    echo [SUMMARY] All tests succeeded
    exit 0;
fi

echo [SUMMARY] $RESULT tests failed. See output for further information
exit 1

