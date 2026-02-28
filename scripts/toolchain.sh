#!/bin/bash

set -e

OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"

# 检查必要的环境变量
if [[ -z "$FIRMWARE_TYPE" || -z "$GITHUB_REPOSITORY" ]]; then
    exit 1
fi

# 生成工具链缓存文件名
cd "$OPENWRT_PATH"
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="$FIRMWARE_TYPE-toolchain-cache-$TOOLS_HASH"
echo "CACHE_NAME=$CACHE_NAME" >> "$GITHUB_ENV"

mkdir -p "$GITHUB_WORKSPACE/output"

# 打包 Toolchain
if [[ $REBUILD_TOOLCHAIN = 'true' ]]; then
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    ccache_dir=$([ -d ".ccache" ] && echo ".ccache" || echo "")
    tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir
    [[ -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]] || exit 1
    exit 0
fi

# 下载并部署 Toolchain
cache_url=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" \
    | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)

if [[ -n "$cache_url" ]] && wget -qc -t=3 "$cache_url"; then
    if [ -e *.tzst ]; then
        tar -I unzstd -xf *.tzst || tar -xf *.tzst
        sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    else
        echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
    fi
else
    echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
fi