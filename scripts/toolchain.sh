#!/bin/bash

set -e

OPENWRT_PATH="${OPENWRT_PATH:-$GITHUB_WORKSPACE/openwrt}"

# 检查必要的环境变量
if [[ -z "$FIRMWARE_TYPE" || -z "$GITHUB_REPOSITORY" ]]; then
    echo "错误: 缺少必要环境变量 FIRMWARE_TYPE 或 GITHUB_REPOSITORY"
    exit 1
fi

cd "$OPENWRT_PATH"

# 提取源码分支简写
REPO_BRANCH=$(git branch --show-current 2>/dev/null || true)
if [[ -z "$REPO_BRANCH" ]]; then
    REPO_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
fi
LITE_BRANCH="${REPO_BRANCH#*-}"
[ -z "$LITE_BRANCH" ] && LITE_BRANCH="master"

# 提取目标架构（如 rockchip-armv8 或 armsr-armv8）
DEVICE_TARGET=""
if [[ -n "$CONFIG_FILE" && -f "$GITHUB_WORKSPACE/$CONFIG_FILE" ]]; then
    TARGET_NAME=$(grep -oP "^CONFIG_TARGET_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE" 2>/dev/null | head -1 || true)
    if [[ -n "$TARGET_NAME" ]]; then
        SUBTARGET_NAME=$(grep -oP "^CONFIG_TARGET_${TARGET_NAME}_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE" 2>/dev/null | head -1 || true)
        DEVICE_TARGET="${TARGET_NAME}-${SUBTARGET_NAME}"
    fi
fi
if [[ -z "$DEVICE_TARGET" ]]; then
    DEVICE_TARGET="${BUILD_TYPE:-generic}"
fi

# 计算工具链 git 变更哈希
TOOLS_HASH=$(git log -1 --pretty=format:"%h" tools toolchain 2>/dev/null || git log --pretty=tformat:"%h" -n1 tools toolchain)

# 缓存命名规则（参考 haiibo/build-openwrt 对齐：源码-分支-架构-哈希，防止目标架构间混淆）
CACHE_NAME="${FIRMWARE_TYPE}-${LITE_BRANCH}-${DEVICE_TARGET}-cache-${TOOLS_HASH}"
echo "CACHE_NAME=$CACHE_NAME" >> "$GITHUB_ENV"

mkdir -p "$GITHUB_WORKSPACE/output"

# 打包 Toolchain（参考 haiibo/build-openwrt 标准）
if [[ "${REBUILD_TOOLCHAIN:-false}" = 'true' ]]; then
    echo "📦 开始打包工具链缓存..."
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
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

# 1. 优先在本仓库指定 Tag 查找对应工具链
cache_url=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$TOOLCHAIN_TAG" 2>/dev/null \
    | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)

# 若指定 Tag 未查到，查询本仓库的所有 Releases
if [[ -z "$cache_url" ]]; then
    cache_url=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" 2>/dev/null \
        | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME" | head -1)
fi

# 兼容旧命名查询
if [[ -z "$cache_url" ]]; then
    cache_url=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" 2>/dev/null \
        | awk -F '"' '/download_url/{print $4}' | grep "$FIRMWARE_TYPE-toolchain-cache-$TOOLS_HASH" | head -1)
fi

# 2. 若本仓库无缓存，参考 haiibo，尝试从 haiibo/toolchain-cache 公共源获取加速
from_fallback=false
if [[ -z "$cache_url" ]]; then
    haiibo_pattern="${DEVICE_TARGET}-cache-${TOOLS_HASH}"
    cache_url=$(curl -sL "https://api.github.com/repos/haiibo/toolchain-cache/releases" 2>/dev/null \
        | awk -F '"' '/download_url/{print $4}' | grep -E "$haiibo_pattern|$CACHE_NAME" | head -1)
    if [[ -n "$cache_url" ]]; then
        from_fallback=true
        echo "🌐 命中 haiibo/toolchain-cache 公共缓存源"
    fi
fi

cache_ok=false
if [[ -n "$cache_url" ]]; then
    echo "⬇️ 正在下载工具链缓存: $cache_url"
    wget -qc -t=3 -T 60 "$cache_url" || rm -f ./*.tzst

    # 体积下限校验（低于 50MB 视为坏包/截断）
    if [ -e ./*.tzst ] && [ "$(stat -c%s ./*.tzst 2>/dev/null || echo 0)" -ge "$MIN_BYTES" ]; then
        # zstd 完整性校验（存在 zstd CLI 时执行）
        if command -v zstd >/dev/null 2>&1; then
            zstd -tq ./*.tzst 2>/dev/null || rm -f ./*.tzst
        fi
        if [ -e ./*.tzst ]; then
            if tar -I unzstd -xf ./*.tzst 2>/dev/null || tar -xf ./*.tzst 2>/dev/null; then
                if [ -d staging_dir ]; then
                    cache_ok=true
                    if $from_fallback; then
                        cp ./*.tzst "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst"
                        echo "OUTPUT_RELEASE=true" >> "$GITHUB_ENV"
                    fi
                fi
            fi
        fi
    else
        rm -f ./*.tzst
    fi
fi

if $cache_ok; then
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    rm -f ./*.tzst
    echo "✅ 工具链缓存部署成功: $CACHE_NAME"
else
    # 未命中或包损坏：清理 staging_dir 避免残缺文件污染后续编译
    rm -rf staging_dir ./*.tzst
    echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
    echo "⚠️ 工具链缓存不可用（未命中或校验失败），本次将重新编译工具链"
fi
