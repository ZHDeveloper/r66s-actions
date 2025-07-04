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

# Clean conflicts and prepare
rm -rf feeds/packages/net/mosdns 
rm -rf feeds/packages/lang/golang
rm -rf feeds/luci/themes/luci-theme-argon 
rm -rf feeds/luci/applications/luci-app-mosdns
mkdir -p package

# Clone common packages
clone_package "https://github.com/sbwml/packages_lang_golang" "packages/lang/golang"
clone_package "https://github.com/jerrykuku/luci-theme-argon" "package/luci-theme-argon"
clone_package "https://github.com/fw876/helloworld" "package/luci-app-ssr-plus"
clone_package "https://github.com/xiaorouji/openwrt-passwall" "package/luci-app-passwall"
clone_package "https://github.com/sbwml/luci-app-mosdns" "package/luci-app-mosdns" "v5"
clone_package "https://github.com/linkease/istore" "package/luci-app-store"
clone_package "https://github.com/sirpdboy/luci-app-netspeedtest" "package/luci-app-netspeedtest"
clone_package "https://github.com/kongfl888/luci-app-adguardhome" "package/luci-app-adguardhome"
git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

# Flippy firmware specific (Amlogic toolbox)
if [[ "$CONFIG_FILE" == *"flippy"* ]]; then
    git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic

    # Configure amlogic package
    config_file="package/luci-app-amlogic/root/etc/config/amlogic"
    sed -i "s|option amlogic_firmware_repo.*|option amlogic_firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" "$config_file"
    sed -i "s|option amlogic_firmware_tag.*|option amlogic_firmware_tag '$RELEASE_TAG'|g" "$config_file"
fi
