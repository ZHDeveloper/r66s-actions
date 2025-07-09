#!/bin/bash
set -e

# 环境设置
OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"
: "${FIRMWARE_TYPE:?}" >/dev/null 2>&1
: "${GITHUB_REPOSITORY:?}" >/dev/null 2>&1

# 生成工具链缓存名称
cd "$OPENWRT_PATH"
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="$FIRMWARE_TYPE-toolchain-cache-$TOOLS_HASH"
echo "CACHE_NAME=$CACHE_NAME" >> $GITHUB_ENV

# 打包工具链函数
package_toolchain() {
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    mkdir -p "$GITHUB_WORKSPACE/output"

    # 如果存在则包含 .ccache
    local files="staging_dir/host* staging_dir/tool*"
    [ -d ".ccache" ] && files="$files .ccache"

    tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" $files || exit 1
}

# 如果需要重建则打包工具链
[[ $REBUILD_TOOLCHAIN = 'true' ]] && {
    package_toolchain
    exit 0
}

# 下载和部署工具链
download_toolchain() {
    local cache_url
    cache_url=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" | \
                awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)

    [ -n "$cache_url" ] && wget -qc -t=3 "$cache_url" >/dev/null 2>&1 && \
    ls *.tzst >/dev/null 2>&1 && {
        tar -I unzstd -xf *.tzst >/dev/null 2>&1 || tar -xf *.tzst >/dev/null 2>&1
        sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
        return 0
    }

    echo "REBUILD_TOOLCHAIN=true" >> $GITHUB_ENV
    return 1
}

# 创建输出目录并尝试下载现有工具链
mkdir -p "$GITHUB_WORKSPACE/output"
download_toolchain