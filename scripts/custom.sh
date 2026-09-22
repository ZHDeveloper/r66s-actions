#!/bin/bash
set -e

# Configure git to use GITHUB_TOKEN for HTTPS authentication (scoped to current repository only)
if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPOSITORY" ]; then
    git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}".insteadOf "https://github.com/${GITHUB_REPOSITORY}"
fi

# ── Helper functions ──────────────────────────────────────────────────────────

# Safe download with timeout, retry and non-zero exit code on failure
safe_download() {
    local url="$1" output="$2"
    mkdir -p "$(dirname "$output")"
    echo "Downloading: $url -> $output"
    if ! curl -fsSL --connect-timeout 15 --retry 3 --retry-delay 2 "$url" -o "$output"; then
        echo "Error: Failed to download $url" >&2
        return 1
    fi
}

# Sparse clone: clone only specified subdirectories and move them to package/
git_sparse_clone() {
    local branch="$1" repourl="$2"
    shift 2
    local repodir="temp_$(basename "$repourl" .git)_$$"

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" "$repodir"
    (
        cd "$repodir"
        git sparse-checkout init --cone
        git sparse-checkout set "$@"
        for item in "$@"; do
            if [ -e "$item" ]; then
                cp -rf "$item" ../package/
            fi
        done
    )
    rm -rf "$repodir"
}

# Clone a package repository (with optional branch)
clone_package() {
    local url="$1" target="$2" branch="$3"
    [ -n "$branch" ] && git clone --depth=1 -b "$branch" "$url" "$target" || git clone --depth=1 "$url" "$target"
}

# ── Custom packages ───────────────────────────────────────────────────────────

# Remove conflicting feed packages before installing custom ones
find feeds/ -maxdepth 4 -type d \( -name "mosdns" -o -name "luci-app-mosdns" -o -name "v2ray-geodata" -o -name "luci-app-openclash" -o -name "luci-app-passwall" -o -name "*adguardhome*" \) -exec rm -rf {} + 2>/dev/null || true
rm -rf feeds/packages/net/{xray-core,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls} 2>/dev/null || true

mkdir -p package

clone_package "https://github.com/sbwml/luci-app-mosdns" "package/mosdns" "v5"
clone_package "https://github.com/sbwml/v2ray-geodata" "package/v2ray-geodata"
clone_package "https://github.com/fw876/helloworld" "package/luci-app-ssr-plus"
clone_package "https://github.com/Openwrt-Passwall/openwrt-passwall" "package/luci-app-passwall"
clone_package "https://github.com/Openwrt-Passwall/openwrt-passwall-packages" "package/passwall-packages"

git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto
git_sparse_clone master https://github.com/linkease/nas-packages network/services/ddnsto

if [[ "$FIRMWARE_TYPE" == "ImmortalWrt" ]]; then
    # 替换 golang 为 27.x 分支 (Go 1.27.1, 满足 Xray-core 等新包要求)
    rm -rf feeds/packages/lang/golang
    clone_package "https://github.com/sbwml/packages_lang_golang" "feeds/packages/lang/golang" "27.x"

    # 修复 containerd 等旧包在 Go 1.27+ 下的 linkname 校验拦截 (runtime.sched_getaffinity)
    [ -f feeds/packages/utils/containerd/Makefile ] && sed -i 's/PREFIX=""/PREFIX="" EXTRA_LDFLAGS="-checklinkname=0"/g' feeds/packages/utils/containerd/Makefile
    [ -f feeds/packages/lang/golang/golang-package.mk ] && sed -i 's/GO_PKG_DEFAULT_LDFLAGS=/GO_PKG_DEFAULT_LDFLAGS= -checklinkname=0/g' feeds/packages/lang/golang/golang-package.mk

    # 替换 rust 为 LEDE 最新版预编译支持并清理临时目录避免冲突
    rm -rf feeds/packages/lang/rust
    git_sparse_clone master https://github.com/coolsnowwolf/packages lang/rust
    cp -a package/rust feeds/packages/lang/
    rm -rf package/rust
fi

git_sparse_clone openwrt-23.05 https://github.com/coolsnowwolf/luci applications/luci-app-adguardhome
git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

if [[ "$BUILD_TYPE" == "flippy" ]]; then
    git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
    config_file="package/luci-app-amlogic/root/etc/config/amlogic"
    if [ -f "$config_file" ]; then
        sed -i "s|option amlogic_firmware_repo.*|option amlogic_firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" "$config_file"
        sed -i "s|option amlogic_firmware_tag.*|option amlogic_firmware_tag '$RELEASE_TAG'|g" "$config_file"
    fi
fi

# ── Download binary cores ─────────────────────────────────────────────────────

# AdGuard Home
mkdir -p files/usr/bin/AdGuardHome
safe_download "https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_arm64.tar.gz" "AdGuardHome.tar.gz"
tar -xzf AdGuardHome.tar.gz -C files/usr/bin/AdGuardHome --strip-components=1 --wildcards '*/AdGuardHome'
rm -f AdGuardHome.tar.gz
chmod +x files/usr/bin/AdGuardHome/AdGuardHome

# OpenClash core and geo files
mkdir -p files/etc/openclash/core
safe_download "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" "clash_meta.tar.gz"
tar -xzf clash_meta.tar.gz -C files/etc/openclash/core/
if [ -f files/etc/openclash/core/clash ]; then
    mv -f files/etc/openclash/core/clash files/etc/openclash/core/clash_meta
fi
rm -f clash_meta.tar.gz
chmod +x files/etc/openclash/core/clash_meta

safe_download "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" "files/etc/openclash/GeoIP.dat"
safe_download "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" "files/etc/openclash/GeoSite.dat"
safe_download "https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb" "files/etc/openclash/Country.mmdb"

# ── DIY customizations ────────────────────────────────────────────────────────

# Set default theme
if [ -f feeds/luci/collections/luci/Makefile ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
fi

# OpenWrt 标准开机默认配置（uci-defaults）
mkdir -p files/etc/uci-defaults
if [ -f "$GITHUB_WORKSPACE/scripts/99-custom-settings" ]; then
    cp -f "$GITHUB_WORKSPACE/scripts/99-custom-settings" files/etc/uci-defaults/99-custom-settings
elif [ -f "../scripts/99-custom-settings" ]; then
    cp -f "../scripts/99-custom-settings" files/etc/uci-defaults/99-custom-settings
fi
chmod +x files/etc/uci-defaults/99-custom-settings

# TTYD: 保持密码验证（如需免密可将下面的注释解开）
if [ -f feeds/packages/utils/ttyd/files/ttyd.config ]; then
    sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config
fi
if [ -f feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po ]; then
    sed -i 's/\"终端\"/\"TTYD 终端\"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po
fi

# Add build timestamp
mkdir -p package/base-files/files/etc
echo "Built on $(TZ=Asia/Shanghai date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner
