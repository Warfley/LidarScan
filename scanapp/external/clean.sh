#!/bin/bash

set -e

SCRIPT_PATH=$(dirname $(realpath $0))
SDK_PATH=$SCRIPT_PATH/rplidar_sdk
IPATH=$SCRIPT_PATH/include
LPATH=$SCRIPT_PATH/lib

make -C $SDK_PATH clean
git -C $SDK_PATH reset --hard
git -C $SDK_PATH clean -xdff
rm $IPATH
rm -rf $LPATH
