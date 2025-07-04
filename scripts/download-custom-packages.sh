#!/bin/bash
set -e

# Sparse clone function
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

# Clone package function
clone_package() {
    local url="$1" target="$2" branch="$3"
    [ -n "$branch" ] && git clone --depth=1 -b "$branch" "$url" "$target" || git clone --depth=1 "$url" "$target"
}

# Clone multiple folders from git repository
clone_folders() {
    local url="$1" branch="$2"
    shift 2
    local temp_dir=$(basename "$url")-temp
    local folders=("$@")

    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$url" "$temp_dir" && \
    cd "$temp_dir" && \
    git sparse-checkout init --cone && \
    git sparse-checkout set "${folders[@]}" && \
    for folder in "${folders[@]}"; do
        [ -d "$folder" ] && mv "$folder" "../package/$(basename "$folder")"
    done && \
    cd .. && rm -rf "$temp_dir"
}

mkdir -p package

# Clone common packages
clone_package "https://github.com/jerrykuku/luci-theme-argon" "package/luci-theme-argon"
clone_package "https://github.com/fw876/helloworld" "package/luci-app-ssr-plus"
clone_package "https://github.com/xiaorouji/openwrt-passwall" "package/luci-app-passwall"
clone_package "https://github.com/linkease/istore" "package/luci-app-store"
clone_package "https://github.com/sirpdboy/luci-app-netspeedtest" "package/luci-app-netspeedtest"

# sbwml/luci-app-mosdns
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/lang/golang

clone_package "https://github.com/sbwml/luci-app-mosdns" "package/mosdns" "v5"
clone_package "https://github.com/sbwml/v2ray-geodata" "package/v2ray-geodata"
clone_package "https://github.com/sbwml/packages_lang_golang" "feeds/packages/lang/golang" "24.x"

# ImmortalWrt specific packages
if [[ "$CONFIG_FILE" == *"imm"* ]]; then
    # Clone adguardhome from coolsnowwolf/luci
    clone_folders "https://github.com/coolsnowwolf/luci" "openwrt-23.05" \
        "applications/luci-app-adguardhome"
fi

git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

# Flippy firmware specific (Amlogic toolbox)
if [[ "$CONFIG_FILE" == *"flippy"* ]]; then
    git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic

    # Configure amlogic package
    config_file="package/luci-app-amlogic/root/etc/config/amlogic"
    sed -i "s|option amlogic_firmware_repo.*|option amlogic_firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" "$config_file"
    sed -i "s|option amlogic_firmware_tag.*|option amlogic_firmware_tag '$RELEASE_TAG'|g" "$config_file"
fi
