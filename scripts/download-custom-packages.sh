#!/bin/bash
set -e

# 统一的 git 克隆函数
git_clone() {
    local url="$1" target="$2" branch="${3:-}" folders=("${@:4}")

    if [ ${#folders[@]} -gt 0 ]; then
        # 稀疏克隆指定文件夹
        local temp_dir=$(basename "$url")-temp
        git clone --depth=1 ${branch:+-b "$branch"} --single-branch --filter=blob:none --sparse "$url" "$temp_dir" >/dev/null 2>&1
        cd "$temp_dir"
        git sparse-checkout init --cone >/dev/null 2>&1
        git sparse-checkout set "${folders[@]}" >/dev/null 2>&1
        for folder in "${folders[@]}"; do
            [ -d "$folder" ] && mv "$folder" "../package/$(basename "$folder")"
        done
        cd .. && rm -rf "$temp_dir"
    else
        # 常规克隆
        git clone --depth=1 ${branch:+-b "$branch"} "$url" "$target" >/dev/null 2>&1
    fi
}

# 清理冲突的软件包
clean_conflicts() {
    find ./ -name Makefile | grep -E "(v2ray-geodata|mosdns)" | xargs rm -f 2>/dev/null || true
    rm -rf feeds/packages/net/{mosdns,v2ray-geodata} feeds/luci/applications/luci-app-mosdns feeds/packages/lang/golang 2>/dev/null || true
}

mkdir -p package

# 首先清理冲突的软件包
clean_conflicts

# 克隆通用软件包
git_clone "https://github.com/jerrykuku/luci-theme-argon" "package/luci-theme-argon"
git_clone "https://github.com/fw876/helloworld" "package/luci-app-ssr-plus"
git_clone "https://github.com/xiaorouji/openwrt-passwall" "package/luci-app-passwall"
git_clone "https://github.com/linkease/istore" "package/luci-app-store"

# sbwml 软件包
git_clone "https://github.com/sbwml/luci-app-mosdns" "package/mosdns" "v5"
git_clone "https://github.com/sbwml/v2ray-geodata" "package/v2ray-geodata"
git_clone "https://github.com/sbwml/packages_lang_golang" "feeds/packages/lang/golang" "24.x"

# OpenClash 软件包
git_clone "https://github.com/vernesong/OpenClash" "" "master" "luci-app-openclash"

# 固件特定软件包
if [[ "$FIRMWARE_TYPE" == "ImmortalWrt" ]]; then
    git_clone "https://github.com/coolsnowwolf/luci" "" "openwrt-23.05" "applications/luci-app-adguardhome"
fi

if [[ "$CONFIG_FILE" == *"flippy"* ]]; then
    git_clone "https://github.com/ophub/luci-app-amlogic" "" "main" "luci-app-amlogic"

    # 配置 amlogic 软件包
    config_file="package/luci-app-amlogic/root/etc/config/amlogic"
    sed -i "s|option amlogic_firmware_repo.*|option amlogic_firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" "$config_file"
    sed -i "s|option amlogic_firmware_tag.*|option amlogic_firmware_tag '$RELEASE_TAG'|g" "$config_file"
fi
