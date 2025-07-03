#!/bin/bash

set -e

# Download AdGuard Home
{
    agh_url=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | \
              grep "browser_download_url.*linux_arm64.tar.gz" | cut -d '"' -f 4)
    [ -n "$agh_url" ] && \
    wget -q -O /tmp/agh.tar.gz "$agh_url" && \
    tar -xzf /tmp/agh.tar.gz -C /tmp/ && \
    mkdir -p files/usr/bin && \
    cp /tmp/AdGuardHome/AdGuardHome files/usr/bin/ && \
    chmod +x files/usr/bin/AdGuardHome && \
    rm -rf /tmp/agh.tar.gz /tmp/AdGuardHome
} || true

# Download OpenClash core
{
    wget -q -O /tmp/clash.tar.gz "https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz" && \
    tar -xzf /tmp/clash.tar.gz -C /tmp/ && \
    mkdir -p files/etc/openclash/core && \
    cp /tmp/clash files/etc/openclash/core/clash_meta && \
    chmod +x files/etc/openclash/core/clash_meta && \
    rm -rf /tmp/clash.tar.gz /tmp/clash
} || true

# Download geo files
{
    mkdir -p files/etc/openclash && \
    wget -q -O files/etc/openclash/GeoIP.dat "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" && \
    wget -q -O files/etc/openclash/GeoSite.dat "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat" && \
    wget -q -O files/etc/openclash/Country.mmdb "https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb"
} || true
