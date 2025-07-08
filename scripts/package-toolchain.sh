#!/bin/bash

set -e

# 环境变量设置
OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"
CACHE_NAME="${CACHE_NAME:-$FIRMWARE_TYPE-toolchain}"

# 打包Toolchain
if [[ $REBUILD_TOOLCHAIN = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    [ -d ".ccache" ] && (ccache=".ccache"; ls -alh .ccache)
    du -h --max-depth=1 ./staging_dir
    du -h --max-depth=1 ./ --exclude=staging_dir
    tar -I zstdmt -cf $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst staging_dir/host* staging_dir/tool* $ccache
    ls -lh $GITHUB_WORKSPACE/output
    [ -e $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst ] || exit 1
    exit 0
fi

[ -d $GITHUB_WORKSPACE/output ] || mkdir $GITHUB_WORKSPACE/output