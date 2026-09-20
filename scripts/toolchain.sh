#!/bin/bash

set -e

OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"
BUILD_TYPE="${BUILD_TYPE:-common}"

# 检查必要的环境变量
if [[ -z "$FIRMWARE_TYPE" || -z "$GITHUB_REPOSITORY" ]]; then
    echo "Error: FIRMWARE_TYPE and GITHUB_REPOSITORY are required." >&2
    exit 1
fi

# 生成包含架构/构建类型的工具链缓存文件名，避免多 Matrix 并发冲突
cd "$OPENWRT_PATH"
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="${FIRMWARE_TYPE}-${BUILD_TYPE}-toolchain-${TOOLS_HASH}"
echo "CACHE_NAME=$CACHE_NAME" >> "$GITHUB_ENV"

mkdir -p "$GITHUB_WORKSPACE/output"

# 打包 Toolchain
if [[ "$REBUILD_TOOLCHAIN" == 'true' ]]; then
    echo "Packing toolchain cache: $CACHE_NAME.tzst"
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile 2>/dev/null || true
    ccache_dir=$([ -d ".ccache" ] && echo ".ccache" || echo "")
    tar -I "zstdmt -3" -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir
    [[ -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]] || exit 1
    echo "Toolchain cache generated successfully."
    exit 0
fi

# 下载并部署 Toolchain
AUTH_HEADER=()
if [[ -n "$GITHUB_TOKEN" ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

echo "Searching for cached toolchain: $CACHE_NAME"
cache_url=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" \
    | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME\.tzst" | head -1)

if [[ -n "$cache_url" ]]; then
    echo "Found cache at: $cache_url. Downloading..."
    if wget -qc -t=3 -T=30 "$cache_url" -O "$CACHE_NAME.tzst"; then
        echo "Extracting toolchain cache..."
        if tar -I unzstd -xf "$CACHE_NAME.tzst" || tar -xf "$CACHE_NAME.tzst"; then
            sed -i 's/ $(tool.*\/stamp-compile)//' Makefile 2>/dev/null || true
            rm -f "$CACHE_NAME.tzst"
            echo "Toolchain cache deployed successfully."
            exit 0
        fi
    fi
fi

echo "No valid toolchain cache found. Triggering full rebuild..."
echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"