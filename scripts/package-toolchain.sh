#!/bin/bash

set -e

# 环境变量设置
OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-$GITHUB_REPOSITORY}"

# 检查必要的环境变量
if [[ -z "$FIRMWARE_TYPE" ]]; then
    exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
    exit 1
fi

# 生成工具链缓存文件名
cd $OPENWRT_PATH
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="$FIRMWARE_TYPE-toolchain-cache-$TOOLS_HASH"
echo "CACHE_NAME=$CACHE_NAME" >> $GITHUB_ENV

# 打包Toolchain
if [[ $REBUILD_TOOLCHAIN = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile

    # 检查 .ccache 目录并设置变量
    ccache_dir=""
    [ -d ".ccache" ] && ccache_dir=".ccache"

    # 创建输出目录
    mkdir -p $GITHUB_WORKSPACE/output

    # 打包工具链，处理 ccache 目录
    if [[ -n "$ccache_dir" ]]; then
        tar -I zstdmt -cf $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst staging_dir/host* staging_dir/tool* $ccache_dir
    else
        tar -I zstdmt -cf $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst staging_dir/host* staging_dir/tool*
    fi

    # 检查打包是否成功
    if [[ ! -e $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst ]]; then
        exit 1
    fi

    exit 0
fi

# 创建输出目录
mkdir -p $GITHUB_WORKSPACE/output

# 下载并部署Toolchain
cache_url=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)

if [[ -n "$cache_url" ]]; then
    cd $OPENWRT_PATH
    if wget -qc -t=3 "$cache_url"; then
        if [ -e *.tzst ]; then
            tar -I unzstd -xf *.tzst || tar -xf *.tzst
            sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
        else
            echo "REBUILD_TOOLCHAIN=true" >> $GITHUB_ENV
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >> $GITHUB_ENV
    fi
else
    echo "REBUILD_TOOLCHAIN=true" >> $GITHUB_ENV
fi