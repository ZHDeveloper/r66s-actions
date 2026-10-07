#!/bin/bash

set -e

OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"

# 检查必要的环境变量
[[ -z "$FIRMWARE_TYPE" || -z "$GITHUB_REPOSITORY" ]] && {
    echo "错误: 缺少必要环境变量 FIRMWARE_TYPE 或 GITHUB_REPOSITORY"
    exit 1
}

cd "$OPENWRT_PATH"

# 提取源码分支简写
REPO_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
LITE_BRANCH="${REPO_BRANCH#*-}"
[ -z "$LITE_BRANCH" ] && LITE_BRANCH="master"

# 提取目标架构（如 rockchip-armv8 或 armsr-armv8）
DEVICE_TARGET=""
if [[ -n "$CONFIG_FILE" && -f "$GITHUB_WORKSPACE/$CONFIG_FILE" ]]; then
    TARGET_NAME=$(grep -m1 -oP "^CONFIG_TARGET_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE" 2>/dev/null || true)
    if [[ -n "$TARGET_NAME" ]]; then
        SUBTARGET_NAME=$(grep -m1 -oP "^CONFIG_TARGET_${TARGET_NAME}_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE" 2>/dev/null || true)
        DEVICE_TARGET="${TARGET_NAME}-${SUBTARGET_NAME}"
    fi
fi
if [[ -z "$DEVICE_TARGET" ]]; then
    DEVICE_TARGET="${BUILD_TYPE:-generic}"
fi

# 计算工具链 git 变更哈希
TOOLS_HASH=$(git log -1 --format="%h" tools toolchain 2>/dev/null || echo "latest")

# 缓存命名规则（参考 haiibo/build-openwrt 对齐：源码-分支-架构-哈希，防止目标架构间混淆）
CACHE_NAME="${FIRMWARE_TYPE}-${LITE_BRANCH}-${DEVICE_TARGET}-cache-${TOOLS_HASH}"
echo "CACHE_NAME=$CACHE_NAME" >> "$GITHUB_ENV"

# 打包 Toolchain（参考 haiibo/build-openwrt 标准）
if [[ "${REBUILD_TOOLCHAIN:-false}" = 'true' ]]; then
    echo "📦 开始打包工具链缓存: $CACHE_NAME"
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    mkdir -p "$GITHUB_WORKSPACE/output"
    ccache_dir=""
    if [[ -d ".ccache" && $(du -s .ccache 2>/dev/null | cut -f1) -gt 0 ]]; then
        echo "🔍 ccache 目录大小:"
        du -h --max-depth=1 .ccache
        ccache_dir=".ccache"
    fi
    echo "📦 工具链目录大小:"
    du -h --max-depth=1 staging_dir
    tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir
    echo "📁 输出目录内容:"
    ls -lh "$GITHUB_WORKSPACE/output"
    if [[ ! -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]]; then
        echo "❌ 工具链打包失败: 未生成 $CACHE_NAME.tzst"
        exit 1
    fi
    echo "✅ 工具链打包完成: $CACHE_NAME.tzst"
    exit 0
fi

# 下载并部署 Toolchain
MIN_BYTES=$((50 * 1024 * 1024))
TOOLCHAIN_TAG="${TOOLCHAIN_TAG:-toolchain}"

rm -f ./*.tzst

api_header=()
[[ -n "$GITHUB_TOKEN" ]] && api_header=(-H "Authorization: token $GITHUB_TOKEN")
api_url="https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$TOOLCHAIN_TAG"

cache_url=$(curl -sL "${api_header[@]}" "$api_url" 2>/dev/null \
    | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)

# 若指定 Tag 未查到，查询本仓库的所有 Releases
if [[ -z "$cache_url" ]]; then
    cache_url=$(curl -sL "${api_header[@]}" "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" 2>/dev/null \
        | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)
fi

cache_ok=false
if [[ -n "$cache_url" ]]; then
    echo "⬇️ 正在下载工具链缓存: $cache_url"
    if wget -qc -t=3 -T 60 "$cache_url"; then
        tzst_file=$(ls ./*.tzst 2>/dev/null | head -1)
        if [[ -f "$tzst_file" && $(stat -c%s "$tzst_file" 2>/dev/null || echo 0) -ge $MIN_BYTES ]]; then
            if zstd -tq "$tzst_file" 2>/dev/null && tar -I unzstd -xf "$tzst_file" 2>/dev/null; then
                [ -d staging_dir ] && cache_ok=true
            fi
        fi
    fi
fi
rm -f ./*.tzst

if $cache_ok; then
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    echo "✅ 工具链缓存部署成功: $CACHE_NAME"
else
    rm -rf staging_dir
    echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
    echo "⚠️ 工具链缓存不可用（未命中或校验失败），本次将重新编译工具链"
fi
