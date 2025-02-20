#!/bin/bash

TTY=$1

echo "Opening terminal for $TTY"
stty -F $TTY 115200
tail -f $TTY &
PID=$!
function cleanup() {
    kill $PID
}
trap cleanup EXIT
echo "help" > $TTY
cat > $TTY
cleanup
