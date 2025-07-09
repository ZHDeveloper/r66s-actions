#!/bin/bash
set -e

# 下载和解压函数
download_extract() {
    local url="$1" output="$2" extract_path="$3" target_file="$4" dest="$5"

    if wget -q -O "$output" "$url" 2>/dev/null; then
        tar -xzf "$output" -C "$extract_path"
        [ -n "$target_file" ] && [ -n "$dest" ] && {
            mkdir -p "$(dirname "$dest")"
            cp "$extract_path/$target_file" "$dest"
            chmod +x "$dest" 2>/dev/null || true
        }
        rm -rf "$output" "$extract_path"/*
        return 0
    fi
    return 1
}

# 下载文件函数
download_file() {
    local url="$1" output="$2"
    mkdir -p "$(dirname "$output")"
    wget -q -O "$output" "$url" 2>/dev/null || return 1
}

# 下载 AdGuard Home
agh_url=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest 2>/dev/null | \
          grep "browser_download_url.*linux_arm64.tar.gz" | cut -d '"' -f 4)
[ -n "$agh_url" ] && download_extract "$agh_url" "/tmp/agh.tar.gz" "/tmp" "AdGuardHome/AdGuardHome" "files/usr/bin/AdGuardHome" >/dev/null 2>&1

# 下载 OpenClash 核心
mkdir -p files/etc/openclash/core
download_extract "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" \
    "/tmp/clash.tar.gz" "/tmp" "clash" "files/etc/openclash/core/clash_meta" >/dev/null 2>&1

# 并行下载地理位置文件
{
    download_file "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" "files/etc/openclash/GeoIP.dat" >/dev/null 2>&1 &
    download_file "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" "files/etc/openclash/GeoSite.dat" >/dev/null 2>&1 &
    download_file "https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb" "files/etc/openclash/Country.mmdb" >/dev/null 2>&1 &
    wait
}
