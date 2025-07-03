#!/bin/bash

set -e

# Detect firmware type
detect_firmware_type() {
    if [[ "$CONFIG_FILE" == *"lede"* ]]; then
        echo "lede"
    else
        echo "immortalwrt"
    fi
}

FIRMWARE_TYPE=$(detect_firmware_type)

# Set IP address
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate

# Set default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Set hostname and banner based on firmware type
if [ "$FIRMWARE_TYPE" = "lede" ]; then
    sed -i 's/OpenWrt/OpenWrt/g' package/base-files/files/bin/config_generate
    if [ -f "package/lean/default-settings/files/zzz-default-settings" ]; then
        sed -i "s/OpenWrt /OpenWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" package/lean/default-settings/files/zzz-default-settings
    fi
else
    sed -i 's/OpenWrt/ImmortalWrt/g' package/base-files/files/bin/config_generate
    if [ -f "package/lean/default-settings/files/zzz-default-settings" ]; then
        sed -i "s/OpenWrt /ImmortalWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ ImmortalWrt /g" package/lean/default-settings/files/zzz-default-settings
    fi
fi

# Set default password to 'password'
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner

echo "# Custom settings" >> package/base-files/files/etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> package/base-files/files/etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> package/base-files/files/etc/sysctl.conf

echo 'net.core.default_qdisc=fq' >> package/base-files/files/etc/sysctl.d/10-default.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> package/base-files/files/etc/sysctl.d/10-default.conf

sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/system.@system\[0\].timezone/d" package/base-files/files/bin/config_generate
echo "uci set system.@system[0].timezone='CST-8'" >> package/base-files/files/bin/config_generate
echo "uci set system.@system[0].zonename='Asia/Shanghai'" >> package/base-files/files/bin/config_generate
echo "uci commit system" >> package/base-files/files/bin/config_generate

# 设置自动扩展 overlay 脚本权限
[ -f "files/usr/bin/auto-expand-overlay" ] && chmod +x files/usr/bin/auto-expand-overlay
[ -f "files/etc/init.d/auto-expand-overlay" ] && chmod +x files/etc/init.d/auto-expand-overlay
[ -f "files/etc/uci-defaults/99-auto-expand-overlay" ] && chmod +x files/etc/uci-defaults/99-auto-expand-overlay

chmod +x "$GITHUB_WORKSPACE/scripts/download-custom-packages.sh"
"$GITHUB_WORKSPACE/scripts/download-custom-packages.sh"

chmod +x "$GITHUB_WORKSPACE/scripts/download-cores.sh"
"$GITHUB_WORKSPACE/scripts/download-cores.sh"
