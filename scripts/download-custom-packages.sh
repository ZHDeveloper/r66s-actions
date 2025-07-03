#!/bin/bash
set -e

detect_firmware_type() {
    if [[ "$CONFIG_FILE" == *"lede"* ]]; then
        echo "lede"
    else
        echo "immortalwrt"
    fi
}

git_sparse_clone() {
    local branch="$1" repourl="$2"
    shift 2
    local repodir=$(basename "$repourl")

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" || return 1
    cd "$repodir" || return 1
    git sparse-checkout init --cone || { cd ..; rm -rf "$repodir"; return 1; }
    git sparse-checkout set "$@" || { cd ..; rm -rf "$repodir"; return 1; }
    mv -f "$@" ../package/ || { cd ..; rm -rf "$repodir"; return 1; }
    cd .. && rm -rf "$repodir"
}

rm -rf feeds/packages/net/mosdns feeds/luci/themes/luci-theme-argon feeds/luci/applications/luci-app-mosdns

mkdir -p package
firmware_type=$(detect_firmware_type)

clone_package() {
    local url="$1"
    local target="$2"
    local branch="$3"

    if [ -n "$branch" ]; then
        git clone --depth=1 -b "$branch" "$url" "$target" || return 1
    else
        git clone --depth=1 "$url" "$target" || return 1
    fi
}

clone_package "https://github.com/fw876/helloworld" "package/luci-app-ssr-plus"
clone_package "https://github.com/xiaorouji/openwrt-passwall" "package/luci-app-passwall"
clone_package "https://github.com/sbwml/luci-app-mosdns" "package/luci-app-mosdns" "v5"
clone_package "https://github.com/linkease/istore" "package/luci-app-store"
clone_package "https://github.com/sirpdboy/luci-app-netspeedtest" "package/luci-app-netspeedtest"

if [ "$firmware_type" = "lede" ]; then
    clone_package "https://github.com/jerrykuku/luci-theme-argon" "package/luci-theme-argon" "18.06"
    clone_package "https://github.com/kongfl888/luci-app-adguardhome" "package/luci-app-adguardhome"
else
    clone_package "https://github.com/jerrykuku/luci-theme-argon" "package/luci-theme-argon"
    clone_package "https://github.com/sirpdboy/luci-app-adguardhome" "package/luci-app-adguardhome"
fi

git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash
