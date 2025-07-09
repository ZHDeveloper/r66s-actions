#!/bin/bash
set -e

# Set default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Configure LEDE firmware
if [ "$FIRMWARE_TYPE" = "LEDE" ]; then
    if [ -f "package/lean/default-settings/files/zzz-default-settings" ]; then
        # Set IP address to 192.168.100.1
        sed -i 's/192.168.1.1/192.168.100.1/g' package/lean/default-settings/files/zzz-default-settings

        # Ensure IP configuration exists
        if ! grep -q "network.lan.ipaddr" package/lean/default-settings/files/zzz-default-settings; then
            sed -i "2a uci set network.lan.ipaddr='192.168.100.1'" package/lean/default-settings/files/zzz-default-settings
            sed -i "3a uci commit network" package/lean/default-settings/files/zzz-default-settings
        fi

        # Set timezone
        if ! grep -q "CST-8" package/lean/default-settings/files/zzz-default-settings; then
            echo "uci set system.@system[0].timezone='CST-8'" >> package/lean/default-settings/files/zzz-default-settings
            echo "uci set system.@system[0].zonename='Asia/Shanghai'" >> package/lean/default-settings/files/zzz-default-settings
            echo "uci commit system" >> package/lean/default-settings/files/zzz-default-settings
        fi

        # Update banner
        sed -i "s/OpenWrt /OpenWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" package/lean/default-settings/files/zzz-default-settings
    fi
else
    # Configure ImmortalWrt firmware
    sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
    sed -i 's/OpenWrt/ImmortalWrt/g' package/base-files/files/bin/config_generate
    sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate

    # Add timezone configuration
    cat >> package/base-files/files/bin/config_generate << EOF
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
EOF

    # Update banner for ImmortalWrt
    [ -f "package/lean/default-settings/files/zzz-default-settings" ] && \
        sed -i "s/OpenWrt /ImmortalWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ ImmortalWrt /g" package/lean/default-settings/files/zzz-default-settings
fi

# Set default password (password)
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

# Add build timestamp
echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner