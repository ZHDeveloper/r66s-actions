#!/bin/bash
set -e

# Configure git to use GITHUB_TOKEN for HTTPS authentication
if [ -n "$GITHUB_TOKEN" ]; then
    git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

# ── Helper functions ──────────────────────────────────────────────────────────

# Sparse clone: clone only specified subdirectories and move them to package/
git_sparse_clone() {
    local branch="$1" repourl="$2"
    shift 2
    local repodir=$(basename "$repourl")

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" && \
    cd "$repodir" && \
    git sparse-checkout init --cone && \
    git sparse-checkout set "$@" && \
    mv -f "$@" ../package/ && \
    cd .. && rm -rf "$repodir"
}

# Clone a package repository (with optional branch)
clone_package() {
    local url="$1" target="$2" branch="$3"
    [ -n "$branch" ] && git clone --depth=1 -b "$branch" "$url" "$target" || git clone --depth=1 "$url" "$target"
}

# ── Custom packages ───────────────────────────────────────────────────────────

# Remove conflicting feed packages before installing custom ones
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/lang/golang
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-passwall
# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

mkdir -p package

clone_package "https://github.com/sbwml/luci-app-mosdns" "package/mosdns" "v5"
clone_package "https://github.com/sbwml/v2ray-geodata" "package/v2ray-geodata"
clone_package "https://github.com/sbwml/packages_lang_golang" "feeds/packages/lang/golang"
clone_package "https://github.com/fw876/helloworld" "package/luci-app-ssr-plus"
clone_package "https://github.com/Openwrt-Passwall/openwrt-passwall" "package/luci-app-passwall"
clone_package "https://github.com/Openwrt-Passwall/openwrt-passwall" "package/passwall-luci"
clone_package "https://github.com/Openwrt-Passwall/openwrt-passwall-packages" "package/passwall-packages"

git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto
git_sparse_clone master https://github.com/linkease/nas-packages network/services/ddnsto

if [[ "$FIRMWARE_TYPE" == "ImmortalWrt" ]]; then
    git_sparse_clone openwrt-23.05 https://github.com/coolsnowwolf/luci applications/luci-app-adguardhome
fi

git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

if [[ "$CONFIG_FILE" == *"flippy"* ]]; then
    git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
    config_file="package/luci-app-amlogic/root/etc/config/amlogic"
    sed -i "s|option amlogic_firmware_repo.*|option amlogic_firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" "$config_file"
    sed -i "s|option amlogic_firmware_tag.*|option amlogic_firmware_tag '$RELEASE_TAG'|g" "$config_file"
fi

# ── Download binary cores ─────────────────────────────────────────────────────

# AdGuard Home
[ -d files/usr/bin/AdGuardHome ] || mkdir -p files/usr/bin/AdGuardHome
wget -qO- https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_arm64.tar.gz \
    | tar xOz > files/usr/bin/AdGuardHome/AdGuardHome
chmod +x files/usr/bin/AdGuardHome/AdGuardHome

# OpenClash core and geo files
[ -d files/etc/openclash/core ] || mkdir -p files/etc/openclash/core
wget -qO- https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz \
    | tar xOz > files/etc/openclash/core/clash_meta
wget -qO- https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat    > files/etc/openclash/GeoIP.dat
wget -qO- https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat  > files/etc/openclash/GeoSite.dat
wget -qO- https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb   > files/etc/openclash/Country.mmdb
chmod +x files/etc/openclash/core/clash_meta

# ── DIY customizations ────────────────────────────────────────────────────────

# Set default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Set default IP
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
[ -f "package/base-files/luci2/bin/config_generate" ] && \
    sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/luci2/bin/config_generate

# Set default hostname
sed -i "s/hostname='.*'/hostname='OpenWrt'/g" package/base-files/files/bin/config_generate
[ -f "package/base-files/luci2/bin/config_generate" ] && \
    sed -i "s/hostname='.*'/hostname='OpenWrt'/g" package/base-files/luci2/bin/config_generate

# Set default password
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' \
    package/base-files/files/etc/shadow

# Configure ttyd auto-login
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config
sed -i 's/\"终端\"/\"TTYD 终端\"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po

# Add build timestamp
echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner

# Kernel version (LEDE only)
if [[ "$FIRMWARE_TYPE" == "LEDE" ]]; then
    sed -i "s/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.12/g" target/linux/rockchip/Makefile
    sed -i "s/KERNEL_TESTING_PATCHVER:=*.*/KERNEL_TESTING_PATCHVER:=6.12/g" target/linux/rockchip/Makefile
fi

# ── Rust bootstrap 兼容修复（使用系统 LLVM，避免从源码编译 LLVM 导致超时）──
if [ -f feeds/packages/lang/rust/Makefile ]; then
    # 禁用 CI 预编译 LLVM 下载（URL 已失效），改用系统已安装的 LLVM（link-shared）
    sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=if-unchanged/g' \
        feeds/packages/lang/rust/Makefile
    # 追加 link-shared 参数，直接链接系统 LLVM，跳过 LLVM 自行编译
    sed -i '/--set=llvm\.download-ci-llvm/a\        --set=llvm.link-shared=true \\' \
        feeds/packages/lang/rust/Makefile || true
    # 模板文件中的 download-ci-llvm
    find feeds/packages/lang/rust -type f \( -name "*.toml" -o -name "*.template" \) -print0 2>/dev/null \
        | xargs -0 -I{} sed -i \
            -e 's/download-ci-llvm = true/download-ci-llvm = "if-unchanged"/g' \
            -e 's/download-ci-llvm = false/download-ci-llvm = "if-unchanged"/g' \
            "{}" || true
fi