#!/bin/bash

set -e

SCRIPT_PATH=$(dirname $(realpath $0))
SDK_PATH=$SCRIPT_PATH/rplidar_sdk
LPATH=$SCRIPT_PATH/lib

if [ -d $LPATH ]; then
  exit 0
fi

git -C $SDK_PATH apply < $SCRIPT_PATH/clang.patch
git update-index --assume-unchanged $SDK_PATH
make -C $SDK_PATH all

mkdir -p $LPATH
cp $SDK_PATH/output/Linux/Release/libsl_lidar_sdk.a $LPATH

