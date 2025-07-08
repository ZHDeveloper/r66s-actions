#!/bin/bash

set -e

# 环境变量设置
OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"

# 生成工具链缓存文件名
cd $OPENWRT_PATH
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="$FIRMWARE_TYPE-toolchain-cache-$TOOLS_HASH"
echo "CACHE_NAME=$CACHE_NAME" >> $GITHUB_ENV

# 打包Toolchain
if [[ $REBUILD_TOOLCHAIN = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    [ -d ".ccache" ] && ccache=".ccache"
    tar -I zstdmt -cf $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst staging_dir/host* staging_dir/tool* $ccache
    [ -e $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst ] || exit 1
    exit 0
fi

[ -d $GITHUB_WORKSPACE/output ] || mkdir $GITHUB_WORKSPACE/output

# 下载并部署Toolchain
cache_url=$(curl -sL api.github.com/repos/$GITHUB_REPOSITORY/releases | awk -F '"' '/download_url/{print $4}' | grep $CACHE_NAME)

if [[ $cache_url ]]; then
    wget -qc -t=3 $cache_url
    if [ -e *.tzst ]; then
        tar -I unzstd -xf *.tzst || tar -xf *.tzst
        sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    fi
else
    echo "REBUILD_TOOLCHAIN=true" >> $GITHUB_ENV
fi