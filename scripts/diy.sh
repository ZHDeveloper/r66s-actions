#!/bin/bash
set -e

# Detect firmware type
FIRMWARE_TYPE="immortalwrt"
[[ "$CONFIG_FILE" == *"lede"* ]] && FIRMWARE_TYPE="lede"

# Basic configuration
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Set hostname and banner
if [ "$FIRMWARE_TYPE" = "lede" ]; then
    [ -f "package/lean/default-settings/files/zzz-default-settings" ] && \
        sed -i "s/OpenWrt /OpenWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" package/lean/default-settings/files/zzz-default-settings
else
    sed -i 's/OpenWrt/ImmortalWrt/g' package/base-files/files/bin/config_generate
    [ -f "package/lean/default-settings/files/zzz-default-settings" ] && \
        sed -i "s/OpenWrt /ImmortalWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ ImmortalWrt /g" package/lean/default-settings/files/zzz-default-settings
fi

# Set default password and banner
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow
echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner

# Network optimization
cat >> package/base-files/files/etc/sysctl.conf << EOF
# Custom settings
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

cat >> package/base-files/files/etc/sysctl.d/10-default.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# Timezone configuration
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/system.@system\[0\].timezone/d" package/base-files/files/bin/config_generate
cat >> package/base-files/files/bin/config_generate << EOF
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
EOF


