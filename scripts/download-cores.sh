#!/bin/bash
set -e

download_file() {
    local url="$1" output="$2"
    wget -q -O "$output" "$url" 2>/dev/null || return 1
}

# Download AdGuard Home
agh_url=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | \
          grep "browser_download_url.*linux_arm64.tar.gz" | cut -d '"' -f 4)

if [ -n "$agh_url" ] && download_file "$agh_url" "/tmp/agh.tar.gz"; then
    tar -xzf /tmp/agh.tar.gz -C /tmp/ && \
    mkdir -p files/usr/bin/AdGuardHome && \
    cp /tmp/AdGuardHome/AdGuardHome files/usr/bin/AdGuardHome/ && \
    chmod +x files/usr/bin/AdGuardHome/AdGuardHome
    rm -rf /tmp/agh.tar.gz /tmp/AdGuardHome
fi

# Download OpenClash core and geo files
mkdir -p files/etc/openclash/core files/etc/openclash

# OpenClash core
if download_file "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" "/tmp/clash.tar.gz"; then
    tar -xzf /tmp/clash.tar.gz -C /tmp/ && \
    cp /tmp/clash files/etc/openclash/core/clash_meta && \
    chmod +x files/etc/openclash/core/clash_meta
    rm -rf /tmp/clash.tar.gz /tmp/clash
fi

# Geo files
download_file "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" "files/etc/openclash/GeoIP.dat" &
download_file "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" "files/etc/openclash/GeoSite.dat" &
download_file "https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb" "files/etc/openclash/Country.mmdb" &
wait
