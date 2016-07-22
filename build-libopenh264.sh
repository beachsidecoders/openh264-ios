#!/bin/sh
#
# openh264 project ios build script
#
# portions based on chebur/pjsip build script (https://github.com/chebur/pjsip/blob/master/openh264.sh)
#
# usage 
#   ./build-libpopenh264.sh
#
# options
#   -s [full path to openh264 source directory]
#   -o [full path to openh264 output directory]
#
# license
# The MIT License (MIT)
# 
# Copyright (c) 2016 Beachside Coders LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# see http://stackoverflow.com/a/3915420/318790
function realpath { echo $(cd $(dirname "$1"); pwd)/$(basename "$1"); }
__FILE__=`realpath "$0"`
__DIR__=`dirname "${__FILE__}"`

# set -x

IOS_SDK_VERSION=`xcrun -sdk iphoneos --show-sdk-version`
DEVELOPER=`xcode-select -print-path`
IOS_DEPLOYMENT_VERSION="9.0"

# default
H264_SRC_DIR=${__DIR__}/openh264
H264_OUTPUT_DIR=${__DIR__}/libopenh264

while getopts s:o: opt; do
  case $opt in
    s)
      H264_SRC_DIR=$OPTARG
      ;;
    o)
      H264_OUTPUT_DIR=$OPTARG
      ;;
  esac
done

H264_LOG_DIR=${H264_OUTPUT_DIR}/log
H264_INCLUDE_OUTPUT_DIR=${H264_OUTPUT_DIR}/include
H264_LIB_OUTPUT_DIR=${H264_OUTPUT_DIR}/lib
H264_BUILD_DIR=${__DIR__}/build


function prepare_build () {
  echo "Preparing build..."

  # remove old output
  if [ -d ${H264_LOG_DIR} ]; then
      rm -rf ${H264_LOG_DIR}
  fi

  if [ -d ${H264_INCLUDE_OUTPUT_DIR} ]; then
      rm -rf ${H264_INCLUDE_OUTPUT_DIR}
  fi

  if [ -d ${H264_LIB_OUTPUT_DIR} ]; then
      rm -rf ${H264_LIB_OUTPUT_DIR}
  fi

  if [ -d ${H264_BUILD_DIR} ]; then
      rm -rf ${H264_BUILD_DIR}
  fi

  # create output
  if [ ! -d ${H264_OUTPUT_DIR} ]; then
      mkdir ${H264_OUTPUT_DIR}
  fi

  # create log directory
  if [ ! -d ${H264_LOG_DIR} ]; then
      mkdir ${H264_LOG_DIR}
  fi

  # create build directory
  if [ ! -d ${H264_BUILD_DIR} ]; then
      mkdir ${H264_BUILD_DIR}
  fi
}

function build_arch () {
  ARCH=$1

  pushd . > /dev/null
  cd ${H264_SRC_DIR}

  PREFIX="${H264_BUILD_DIR}/openh264-${ARCH}"

  if [ ! -d ${PREFIX} ]; then
      mkdir ${PREFIX}
  fi

  cp Makefile Makefile.bak
  
  # modify makefile prefix
  SED_SRC="^PREFIX=.*"
  SED_DST="PREFIX=${PREFIX}"
  SED_DST="${SED_DST//\//\\/}"
  sed -i.deleteme "s/${SED_SRC}/${SED_DST}/" "Makefile"
  rm Makefile.deleteme

  echo "Building ${ARCH}..."

  make OS=ios ARCH=${ARCH} SDK_MIN=${IOS_DEPLOYMENT_VERSION} V=No >> "${H264_LOG_DIR}/${ARCH}.log" 2>&1
  make OS=ios ARCH=${ARCH} SDK_MIN=${IOS_DEPLOYMENT_VERSION} V=No install >> "${H264_LOG_DIR}/${ARCH}.log" 2>&1
  make OS=ios ARCH=${ARCH} SDK_MIN=${IOS_DEPLOYMENT_VERSION} V=No clean >> "${H264_LOG_DIR}/${ARCH}.log" 2>&1

  mv Makefile.bak Makefile

  popd > /dev/null
}

function build_openh264 () {
  build_arch "armv7"
  build_arch "armv7s"
  build_arch "arm64"
  build_arch "i386"
  build_arch "x86_64"
}

function lipo_libs () {
  echo "Lipo libs..."

  if [ ! -d ${H264_LIB_OUTPUT_DIR} ]; then
      mkdir ${H264_LIB_OUTPUT_DIR}
  fi

  # libopenh264.a
  xcrun -sdk iphoneos lipo -arch armv7  ${H264_BUILD_DIR}/openh264-armv7/lib/libopenh264.a \
                           -arch armv7s ${H264_BUILD_DIR}/openh264-armv7s/lib/libopenh264.a \
                           -arch arm64  ${H264_BUILD_DIR}/openh264-arm64/lib/libopenh264.a \
                           -arch i386   ${H264_BUILD_DIR}/openh264-i386/lib/libopenh264.a \
                           -arch x86_64 ${H264_BUILD_DIR}/openh264-x86_64/lib/libopenh264.a \
                           -create -output ${H264_LIB_OUTPUT_DIR}/libopenh264.a
}

function copy_include () {
  if [ ! -d ${H264_INCLUDE_OUTPUT_DIR} ]; then
    mkdir ${H264_INCLUDE_OUTPUT_DIR}
  fi

  cp -r ${H264_BUILD_DIR}/openh264-arm64/include/wels ${H264_INCLUDE_OUTPUT_DIR}
}

function package_openh264 () {
  lipo_libs
  copy_include
}

function clean_up_build () {
  echo "Cleaning up..."

  if [ -d ${H264_BUILD_DIR} ]; then
      rm -rf ${H264_BUILD_DIR}
  fi
}

echo "Build openh264..."
prepare_build
build_openh264
package_openh264
clean_up_build
echo "Done."

